import Foundation

/// Search over everything the couple has collected — pure data + filtering,
/// no SwiftUI, so behaviour is unit-tested on Linux. `SearchView` renders it.
enum SearchScope: String, CaseIterable, Identifiable {
    case all, memories, chat
    var id: String { rawValue }
    var titleKey: String { "search.scope.\(rawValue)" }
}

enum SearchKind: String, CaseIterable, Identifiable {
    case moments, journal, photos, videos, songs, lists, bucket, coupons, chat
    var id: String { rawValue }
    var titleKey: String { "search.kind.\(rawValue)" }

    var symbol: String {
        switch self {
        case .moments: return "calendar.badge.clock"
        case .journal: return "book.pages"
        case .photos: return "photo.on.rectangle.angled"
        case .videos: return "film.stack"
        case .songs: return "music.note"
        case .lists: return "checklist"
        case .bucket: return "sparkles"
        case .coupons: return "ticket.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        }
    }


    var inMemories: Bool { self != .chat }
}

struct SearchHit: Identifiable, Hashable {
    enum Target: Hashable {
        case memories(MemoriesRoute)
        case chat(messageId: String)
    }

    let id: String
    let kind: SearchKind
    let title: String
    let subtitle: String?
    let date: Date?
    let target: Target
    /// Everything a query is matched against (title, subtitle, extra fields).
    let haystack: String
}

/// All searchable text of the couple, built once per visit and filtered on device.
struct SearchCorpus {
    private(set) var entries: [SearchHit] = []

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    func hits(matching query: String, scope: SearchScope) -> [SearchHit] {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return [] }
        return entries
            .filter { hit in
                switch scope {
                case .all: return true
                case .memories: return hit.kind.inMemories
                case .chat: return hit.kind == .chat
                }
            }
            .filter { hit in terms.allSatisfy { hit.haystack.localizedStandardContains($0) } }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    mutating func append(_ hit: SearchHit) { entries.append(hit) }
}
