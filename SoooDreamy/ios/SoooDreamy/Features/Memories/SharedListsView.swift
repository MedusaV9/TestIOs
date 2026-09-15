import SwiftUI
import Combine

/// Gemeinsame Listen — shopping, movies, travel ideas … every mutation is
/// broadcast as `list_added` / `list_updated` (whole list) / `list_deleted`,
/// so both phones stay in sync while ticking things off together.
struct SharedListsView: View {
    @Environment(AppState.self) private var appState

    @State private var lists: [SharedList] = []
    @State private var loading = true
    @State private var showCompose = false
    @State private var deleteCandidate: SharedList?

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if lists.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("lists.empty.title"), systemImage: "checklist")
                } description: {
                    Text(L10n.t("lists.empty.subtitle"))
                } actions: {
                    Button(L10n.t("lists.new.placeholder")) { showCompose = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(lists) { list in
                    NavigationLink {
                        SharedListDetailView(listId: list.id, lists: $lists)
                    } label: {
                        listRow(list)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteCandidate = list
                        } label: {
                            Label(L10n.t("common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("lists.title"))
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
        .sheet(isPresented: $showCompose) {
            SharedListComposeSheet { list in upsert(list) }
        }
        .refreshable { await load() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            handleServerEvent(event)
        }
        .confirmationDialog(L10n.t("lists.deleteConfirm"),
                            isPresented: Binding(get: { deleteCandidate != nil },
                                                 set: { if !$0 { deleteCandidate = nil } }),
                            titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let list = deleteCandidate { delete(list) }
            }
        }
    }

    // MARK: Rows

    private func listRow(_ list: SharedList) -> some View {
        HStack(spacing: 12) {
            Text(list.emoji ?? "📝")
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(teaser(for: list))
                    .font(.footnote)
                    .foregroundStyle(list.items.isEmpty || list.openCount > 0 ? Color.secondary : Color.green)
            }
            Spacer()
            if !list.items.isEmpty {
                ListProgressRing(done: list.items.count - list.openCount, total: list.items.count)
            }
        }
        .padding(.vertical, 2)
    }

    private func teaser(for list: SharedList) -> String {
        if list.items.isEmpty { return L10n.t("lists.itemsEmpty") }
        if list.openCount == 0 { return L10n.t("lists.allDone") }
        return L10n.t("lists.itemsOpen", ["open": String(list.openCount),
                                          "total": String(list.items.count)])
    }

    // MARK: Data

    private func load() async {
        guard let api = appState.api else { return }
        if let loaded = try? await api.sharedLists() {
            lists = loaded
        }
        loading = false
    }

    private func upsert(_ list: SharedList) {
        withAnimation(.snappy) {
            if let idx = lists.firstIndex(where: { $0.id == list.id }) {
                lists[idx] = list
            } else {
                lists.insert(list, at: 0)
            }
        }
    }

    private func delete(_ list: SharedList) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteSharedList(id: list.id)
                withAnimation(.snappy) { lists.removeAll { $0.id == list.id } }
                Haptics.shared.tap()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func handleServerEvent(_ event: ServerEvent) {
        switch event.type {
        case .listAdded, .listUpdated:
            if let list = event.decode(SharedListResponse.self)?.list { upsert(list) }
        case .listDeleted:
            if let payload = event.decode(IdPayload.self) {
                withAnimation(.snappy) { lists.removeAll { $0.id == payload.id } }
            }
        default:
            break
        }
    }
}

// MARK: - Compose

private struct SharedListComposeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onCreated: (SharedList) -> Void

    private static let emojis = ["📝", "🛒", "🎬", "✈️", "🎁", "🍽️", "🏡", "🎵", "📚", "🎮", "🧳", "🌱"]

    @State private var name = ""
    @State private var emoji = "📝"
    @State private var creating = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("lists.new.placeholder"), text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { create() }
                }
                Section {
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }
            .navigationTitle(L10n.t("lists.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        if creating { ProgressView() } else { Text(L10n.t("common.add")) }
                    }
                    .disabled(creating || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        guard let api = appState.api, !creating else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        creating = true
        Task {
            do {
                let list = try await api.addSharedList(name: trimmed, emoji: emoji)
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                onCreated(list)
                dismiss()
            } catch {
                creating = false
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Progress ring

private struct ListProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: total > 0 ? Double(done) / Double(total) : 0)
                .stroke(done == total ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(width: 30, height: 30)
        .animation(.snappy, value: done)
        .accessibilityLabel("\(done)/\(total)")
    }
}

// MARK: - Detail (one list, checkable items)

struct SharedListDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let listId: String
    @Binding var lists: [SharedList]

    @State private var newItemText = ""
    @State private var adding = false
    @State private var showRename = false
    @State private var renameText = ""

    private var list: SharedList? {
        lists.first { $0.id == listId }
    }

    var body: some View {
        List {
            if let list {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        TextField(L10n.t("lists.item.placeholder"), text: $newItemText)
                            .submitLabel(.done)
                            .onSubmit { addItem() }
                        if adding { ProgressView() }
                    }
                }

                let open = list.items.filter { !$0.done }
                let done = list.items.filter(\.done)

                if list.items.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.t("lists.itemsEmpty"), systemImage: "checklist.unchecked")
                    } description: {
                        Text(L10n.t("lists.item.placeholder"))
                    }
                    .listRowBackground(Color.clear)
                }
                if !open.isEmpty {
                    Section("\(L10n.t("lists.section.open")) · \(open.count)") {
                        ForEach(open) { item in itemRow(item) }
                    }
                }
                if !done.isEmpty {
                    Section("\(L10n.t("lists.section.done")) · \(done.count)") {
                        ForEach(done) { item in itemRow(item) }
                    }
                }
            }
        }
        .navigationTitle("\(list?.emoji ?? "📝") \(list?.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    renameText = list?.name ?? ""
                    showRename = true
                } label: {
                    Label(L10n.t("lists.rename.title"), systemImage: "pencil")
                }
            }
        }
        .alert(L10n.t("lists.rename.title"), isPresented: $showRename) {
            TextField(L10n.t("lists.new.placeholder"), text: $renameText)
            Button(L10n.t("common.save")) { rename() }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .onChange(of: list == nil) { _, gone in
            // The partner deleted this list while we had it open.
            if gone { dismiss() }
        }
    }

    // MARK: Items

    private func itemRow(_ item: SharedListItem) -> some View {
        Button {
            toggle(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.done ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(item.text)
                    .foregroundStyle(item.done ? Color.secondary : Color.primary)
                    .strikethrough(item.done, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label(L10n.t("common.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: Mutations

    private func addItem() {
        guard let api = appState.api, !adding else { return }
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        adding = true
        Task {
            do {
                let updated = try await api.addListItem(listId: listId, text: text)
                upsert(updated)
                newItemText = ""
                SoundEngine.shared.play(.click)
                Haptics.shared.tap()
            } catch {
                appState.handleAPIError(error)
            }
            adding = false
        }
    }

    private func upsert(_ updated: SharedList) {
        withAnimation(.snappy) {
            if let idx = lists.firstIndex(where: { $0.id == updated.id }) {
                lists[idx] = updated
            } else {
                lists.insert(updated, at: 0)
            }
        }
    }

    private func toggle(_ item: SharedListItem) {
        guard let api = appState.api else { return }
        let newDone = !item.done
        Task {
            do {
                let updated = try await api.setListItemDone(listId: listId, itemId: item.id, done: newDone)
                upsert(updated)
                if newDone {
                    SoundEngine.shared.play(.success)
                    Haptics.shared.success()
                    if updated.openCount == 0 { SoundEngine.shared.play(.tada) }
                } else {
                    Haptics.shared.tap()
                }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func deleteItem(_ item: SharedListItem) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteListItem(listId: listId, itemId: item.id)
                if let idx = lists.firstIndex(where: { $0.id == listId }) {
                    withAnimation(.snappy) { lists[idx].items.removeAll { $0.id == item.id } }
                }
                Haptics.shared.tap()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func rename() {
        guard let api = appState.api else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let list else { return }
        Task {
            do {
                let updated = try await api.renameSharedList(id: list.id, name: name, emoji: list.emoji)
                upsert(updated)
                Haptics.shared.success()
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}
