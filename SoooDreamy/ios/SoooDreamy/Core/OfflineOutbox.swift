import Foundation

/// Identifies one authenticated chat context. Entries never cross server,
/// couple, or member boundaries when the user switches profiles.
struct OutboxScope: Codable, Hashable {
    let profileID: UUID
    let coupleID: String
    let memberID: String
}

/// Durable text operation. `clientMessageID` is also sent to the server,
/// where it is the idempotency key for lost-response retries.
struct PendingChatText: Codable, Hashable, Identifiable {
    var id: String { clientMessageID }

    let clientMessageID: String
    let scope: OutboxScope
    let text: String
    let createdAt: Date
    var attemptCount: Int
    var lastAttemptAt: Date?
}

/// Pure, migration-friendly state machine covered by Linux Swift tests.
struct OfflineOutboxState: Codable, Hashable {
    static let currentVersion = 1
    static let maximumEntries = 200

    var version = currentVersion
    private(set) var pending: [PendingChatText] = []

    mutating func enqueue(_ entry: PendingChatText) {
        guard !pending.contains(where: { $0.clientMessageID == entry.clientMessageID }) else { return }
        pending.append(entry)
        pending.sort { $0.createdAt < $1.createdAt }
        if pending.count > Self.maximumEntries {
            pending.removeFirst(pending.count - Self.maximumEntries)
        }
    }

    mutating func markAttempt(clientMessageID: String, at: Date) {
        guard let index = pending.firstIndex(where: { $0.clientMessageID == clientMessageID }) else { return }
        pending[index].attemptCount += 1
        pending[index].lastAttemptAt = at
    }

    mutating func remove(clientMessageID: String) {
        pending.removeAll { $0.clientMessageID == clientMessageID }
    }

    func entries(for scope: OutboxScope) -> [PendingChatText] {
        pending.filter { $0.scope == scope }.sorted { $0.createdAt < $1.createdAt }
    }
}

/// Atomic JSON persistence for the outbox. The default lives in Application
/// Support; tests inject a temporary URL. Every mutation reaches disk before
/// returning, so an app kill after enqueue cannot discard the draft.
final class OfflineOutboxStore: @unchecked Sendable {
    static let shared = OfflineOutboxStore()

    private let fileURL: URL
    private let lock = NSLock()
    private var state: OfflineOutboxState

    init(fileURL: URL = OfflineOutboxStore.defaultFileURL()) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(OfflineOutboxState.self, from: data),
           decoded.version == OfflineOutboxState.currentVersion {
            state = decoded
        } else {
            state = OfflineOutboxState()
        }
    }

    @discardableResult
    func enqueue(text: String, scope: OutboxScope, clientMessageID: String = UUID().uuidString,
                 createdAt: Date = Date()) -> PendingChatText {
        let entry = PendingChatText(clientMessageID: clientMessageID, scope: scope, text: text,
                                    createdAt: createdAt, attemptCount: 0, lastAttemptAt: nil)
        withMutation { $0.enqueue(entry) }
        return entry
    }

    func entries(for scope: OutboxScope) -> [PendingChatText] {
        lock.sdWithLock { state.entries(for: scope) }
    }

    func markAttempt(clientMessageID: String, at: Date = Date()) {
        withMutation { $0.markAttempt(clientMessageID: clientMessageID, at: at) }
    }

    func remove(clientMessageID: String) {
        withMutation { $0.remove(clientMessageID: clientMessageID) }
    }

    private func withMutation(_ mutate: (inout OfflineOutboxState) -> Void) {
        lock.sdWithLock {
            mutate(&state)
            persistLocked()
        }
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SoooDreamy", isDirectory: true)
            .appendingPathComponent("offline-outbox-v1.json")
    }
}

private extension NSLock {
    func sdWithLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
