import SwiftUI
import Combine

/// Shared couple bucket list — dreams to fulfill together. Reminders-style
/// list with a progress header, open/done sections and a compose sheet.
struct BucketListView: View {
    @Environment(AppState.self) private var appState

    private enum Filter: String, CaseIterable, Identifiable {
        case all, open, done
        var id: String { rawValue }
        var labelKey: String { "memories.bucket.filter.\(rawValue)" }
    }

    @State private var items: [BucketItem] = []
    @State private var loading = true
    @State private var showCompose = false
    @State private var filter: Filter = .all
    @State private var celebrationDate: Date?
    @State private var celebrationTask: Task<Void, Never>?

    private var openItems: [BucketItem] { items.filter { !$0.done } }
    private var doneItems: [BucketItem] { items.filter { $0.done } }

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("memories.bucket.empty.title"), systemImage: "sparkles")
                } description: {
                    Text(L10n.t("memories.bucket.empty.subtitle"))
                } actions: {
                    Button(L10n.t("common.add")) { showCompose = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("memories.bucket.progress",
                                    ["done": String(doneItems.count), "total": String(items.count)]))
                            .font(.headline)
                        ProgressView(value: Double(doneItems.count), total: Double(max(items.count, 1)))
                            .tint(Color.accentColor)
                    }
                    .padding(.vertical, 4)

                    Picker(L10n.t("memories.bucket.title"), selection: $filter.animation(.snappy)) {
                        ForEach(Filter.allCases) { f in
                            Text(L10n.t(f.labelKey)).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if let hint = filteredEmptyHint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                }

                if filter != .done, !openItems.isEmpty {
                    Section(L10n.t("memories.bucket.openSection")) {
                        ForEach(openItems) { item in row(item) }
                    }
                }
                if filter != .open, !doneItems.isEmpty {
                    Section(L10n.t("memories.bucket.doneSection")) {
                        ForEach(doneItems) { item in row(item) }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("memories.bucket.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Label(L10n.t("common.add"), systemImage: "plus")
                }
            }
        }
        .overlay {
            if let started = celebrationDate {
                FloatingHeartsView(emojis: ["✨", "🌠", "💜", "🎉", "💫"], count: 16, startedAt: started)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .refreshable { await loadItems() }
        .sheet(isPresented: $showCompose) {
            BucketComposeSheet { item in insert(item) }
        }
        .task { await loadItems() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
    }

    /// Hint text when the chosen filter has nothing to show (but the list isn't empty).
    private var filteredEmptyHint: String? {
        switch filter {
        case .all: return nil
        case .open: return openItems.isEmpty ? L10n.t("memories.bucket.emptyOpen") : nil
        case .done: return doneItems.isEmpty ? L10n.t("memories.bucket.emptyDone") : nil
        }
    }

    // MARK: Row

    private func row(_ item: BucketItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.done ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t(item.done ? "memories.bucket.doneSection" : "memories.bucket.openSection"))

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle(item))
                    .font(.body)
                    .foregroundStyle(item.done ? Color.secondary : Color.primary)
                    .strikethrough(item.done, color: .secondary)
                if item.done, let doneAt = item.doneAt {
                    Text(doneAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label(L10n.t("common.delete"), systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                shareToChat(item)
            } label: {
                Label(L10n.t("memories.bucket.share"), systemImage: "paperplane")
            }
        }
    }

    private func rowTitle(_ item: BucketItem) -> String {
        if let emoji = item.emoji, !emoji.isEmpty { return "\(emoji) \(item.text)" }
        return item.text
    }

    /// Posts the item into the couple chat — completed dreams as a little
    /// celebration message, open ones as a teaser.
    private func shareToChat(_ item: BucketItem) {
        guard let api = appState.api else { return }
        let key = item.done ? "memories.bucket.shareDone" : "memories.bucket.shareOpen"
        let text = L10n.t(key, ["item": rowTitle(item)])
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                Haptics.shared.success()
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("memories.bucket.shareSent"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    // MARK: Actions

    private func loadItems() async {
        guard let api = appState.api else { return }
        do {
            items = try await api.bucket()
        } catch {
            appState.handleAPIError(error)
        }
        loading = false
    }

    private func toggle(_ item: BucketItem) {
        guard let api = appState.api else { return }
        let newDone = !item.done
        Haptics.shared.tap()
        withAnimation(.snappy) {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].done = newDone
                items[idx].doneAt = newDone ? Date() : nil
            }
        }
        if newDone { celebrateDone() }
        Task {
            do {
                let updated = try await api.updateBucketItem(id: item.id, done: newDone)
                apply(updated)
            } catch {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].done = item.done
                    items[idx].doneAt = item.doneAt
                }
                appState.handleAPIError(error)
            }
        }
    }

    private func deleteItem(_ item: BucketItem) {
        guard let api = appState.api else { return }
        withAnimation(.snappy) { items.removeAll { $0.id == item.id } }
        Task {
            do {
                try await api.deleteBucketItem(id: item.id)
            } catch {
                insert(item)
                appState.handleAPIError(error)
            }
        }
    }

    private func celebrateDone() {
        SoundEngine.shared.play(.tada)
        Haptics.shared.success()
        appState.notify(L10n.t("memories.bucket.completed"), style: .love)
        celebrationDate = Date()
        celebrationTask?.cancel()
        celebrationTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { celebrationDate = nil }
        }
    }

    // MARK: Realtime

    private func insert(_ item: BucketItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        withAnimation(.snappy) { items.append(item) }
    }

    private func apply(_ item: BucketItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .bucketAdded:
            if let item = event.decode(BucketItemResponse.self)?.item { insert(item) }
        case .bucketUpdated:
            if let item = event.decode(BucketItemResponse.self)?.item { apply(item) }
        case .bucketDeleted:
            if let id = event.decode(IdPayload.self)?.id {
                withAnimation(.snappy) { items.removeAll { $0.id == id } }
            }
        default:
            break
        }
    }
}

// MARK: - Compose

private struct BucketComposeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onAdded: (BucketItem) -> Void

    private static let emojis = [
        "🌟", "🌍", "✈️", "🏝️", "🎢", "🌌", "🏔️", "💃", "🍣",
        "🎡", "🛶", "🐘", "🌅", "🎪", "🏕️", "🚐", "💍", "🎭"
    ]

    @State private var text = ""
    @State private var emoji = "🌟"
    @State private var adding = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("memories.bucket.placeholder"), text: $text, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focused)
                        .submitLabel(.done)
                }
                Section(L10n.t("memories.bucket.pickEmoji")) {
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }
            .navigationTitle(L10n.t("memories.bucket.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        add()
                    } label: {
                        if adding { ProgressView() } else { Text(L10n.t("common.add")) }
                    }
                    .disabled(adding || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let api = appState.api, !adding else { return }
        adding = true
        Task {
            do {
                let item = try await api.addBucketItem(text: trimmed, emoji: emoji)
                SoundEngine.shared.play(.pop)
                onAdded(item)
                dismiss()
            } catch {
                adding = false
                appState.handleAPIError(error)
            }
        }
    }
}
