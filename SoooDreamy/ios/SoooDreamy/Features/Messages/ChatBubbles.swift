import SwiftUI
import UIKit

// MARK: - Bubble styling

/// Messages-style bubbles: accent for my messages, secondary fill for the
/// partner's. Shared by text, voice, photo and typing bubbles.
enum ChatBubbleShape {
    static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let received = Color(uiColor: .secondarySystemFill)
    static let mine = Color.accentColor

    static func fill(isMine: Bool) -> Color { isMine ? mine : received }
    static func text(isMine: Bool) -> Color { isMine ? .white : .primary }
    static func secondaryText(isMine: Bool) -> Color { isMine ? .white.opacity(0.75) : .secondary }
}

/// The fixed reaction palette; double-tap sends the quick heart.
enum ChatReactions {
    static let palette = ["❤️", "😂", "😮", "🥺", "🔥", "👍"]
    static let quick = "❤️"
}

// MARK: - Row

struct ChatMessageRow: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let isMine: Bool
    let onReact: (String) -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onForward: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 48)
                bubbleColumn
            } else {
                MemberAvatar(member: appState.partner, size: 28)
                bubbleColumn
                Spacer(minLength: 48)
            }
        }
        .id(message.id)
    }

    private var isLocal: Bool { message.id.hasPrefix("local-") }

    private var deleteAction: (() -> Void)? {
        guard isMine, !isLocal else { return nil }
        return onDelete
    }

    private var editAction: (() -> Void)? {
        guard isMine, !isLocal, message.type == .text || message.type == .letter else { return nil }
        return onEdit
    }

    private var forwardAction: (() -> Void)? {
        guard message.type == .letter, !isLocal else { return nil }
        return onForward
    }

    /// Received sealed letters get no reaction affordances until opened.
    private var isSealedLetter: Bool {
        guard message.type == .letter, !isMine, message.openWhen != nil else { return false }
        return !OpenedLettersStore.shared.isOpened(message.id, coupleId: appState.couple?.id)
    }

    private var bubbleColumn: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            bubble
            if !isSealedLetter {
                ChatReactionChips(message: message, myMemberId: appState.memberId, onToggle: onReact)
            }
            if isLocal {
                Label(L10n.t("chat.queued"), systemImage: "clock.arrow.circlepath")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.t("chat.queuedA11y"))
            }
        }
    }

    @ViewBuilder private var bubble: some View {
        switch message.type {
        case .text:
            ChatTextBubble(message: message, isMine: isMine, onReact: onReact,
                           onEdit: editAction, onDelete: deleteAction)
        case .voice:
            ChatVoiceBubble(message: message, isMine: isMine, onReact: onReact, onDelete: deleteAction)
        case .letter:
            ChatLetterBubble(message: message, isMine: isMine, onReact: onReact,
                             onEdit: editAction, onDelete: deleteAction, onForward: forwardAction)
        case .photo:
            ChatPhotoBubble(message: message, isMine: isMine, onReact: onReact, onDelete: deleteAction)
        }
    }
}

// MARK: - Text bubble

struct ChatTextBubble: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let isMine: Bool
    let onReact: (String) -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.text ?? "")
                .font(.body)
                .foregroundStyle(ChatBubbleShape.text(isMine: isMine))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
            ChatTimestampText(date: message.createdAt, isMine: isMine,
                              read: chatReadReceipt(for: message, isMine: isMine, partner: appState.partner),
                              edited: message.editedAt != nil)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(ChatBubbleShape.fill(isMine: isMine), in: ChatBubbleShape.shape)
        .frame(maxWidth: 300, alignment: isMine ? .trailing : .leading)
        .contentShape(ChatBubbleShape.shape)
        .onTapGesture(count: 2) { onReact(ChatReactions.quick) }
        .contextMenu {
            ChatReactMenu(onReact: onReact)
            Button {
                UIPasteboard.general.string = message.text
                appState.notify(L10n.t("chat.copied"), style: .success)
            } label: {
                Label(L10n.t("chat.copy"), systemImage: "doc.on.doc")
            }
            ChatPinButton(message: message)
            if let onEdit { ChatEditButton(onEdit: onEdit) }
            if let onDelete { ChatDeleteButton(onDelete: onDelete) }
        }
    }
}

// MARK: - Photo bubble

struct ChatPhotoBubble: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let isMine: Bool
    let onReact: (String) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var thumbFailed = false
    @State private var showViewer = false
    @Namespace private var zoom

    private var imagePath: String? {
        guard let photoId = message.photoId else { return nil }
        return thumbFailed ? "/api/photos/\(photoId)/raw" : "/api/photos/\(photoId)/thumb/raw"
    }

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            photoArea
                .matchedTransitionSource(id: message.id, in: zoom)
            if let caption = message.text, !caption.isEmpty {
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(ChatBubbleShape.text(isMine: isMine))
                    .multilineTextAlignment(isMine ? .trailing : .leading)
            }
            ChatTimestampText(date: message.createdAt, isMine: isMine,
                              read: chatReadReceipt(for: message, isMine: isMine, partner: appState.partner))
        }
        .padding(6)
        .background(ChatBubbleShape.fill(isMine: isMine), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(count: 2) { onReact(ChatReactions.quick) }
        .onTapGesture { showViewer = true }
        .contextMenu {
            ChatReactMenu(onReact: onReact)
            ChatPinButton(message: message)
            if let onDelete { ChatDeleteButton(onDelete: onDelete) }
        }
        .accessibilityLabel(L10n.t("chat.photoMessage"))
        .fullScreenCover(isPresented: $showViewer) {
            ChatPhotoViewer(message: message)
                .navigationTransition(.zoom(sourceID: message.id, in: zoom))
        }
    }

    @ViewBuilder private var photoArea: some View {
        Group {
            if let path = imagePath {
                AuthenticatedAsyncImage(api: appState.api, path: path) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        if thumbFailed {
                            placeholder(icon: "photo.badge.exclamationmark")
                        } else {
                            placeholder(icon: nil).onAppear { thumbFailed = true }
                        }
                    default:
                        placeholder(icon: nil)
                    }
                }
            } else {
                placeholder(icon: "photo")
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func placeholder(icon: String?) -> some View {
        ZStack {
            Color.tertiaryCardBackground
            if let icon {
                Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

/// Fullscreen viewer for one photo message.
struct ChatPhotoViewer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let message: Message

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let photoId = message.photoId {
                    AuthenticatedAsyncImage(api: appState.api, path: "/api/photos/\(photoId)/raw") { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            ContentUnavailableView(L10n.t("chat.photoFailed"), systemImage: "photo.badge.exclamationmark")
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label(L10n.t("chat.readerClose"), systemImage: "xmark")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaBar(edge: .bottom) {
                if let caption = message.text, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        // Black media stage — dark chrome like the Photos viewer, scoped to
        // this cover instead of forcing a scheme on the whole scene.
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Letter bubble

struct ChatLetterBubble: View {
    @Environment(AppState.self) private var appState
    let message: Message
    let isMine: Bool
    let onReact: (String) -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onForward: (() -> Void)? = nil

    @State private var unsealing = false
    @State private var celebrating = false
    @State private var showReader = false

    private var isSealed: Bool {
        guard !isMine, message.openWhen != nil else { return false }
        return !OpenedLettersStore.shared.isOpened(message.id, coupleId: appState.couple?.id)
    }

    var body: some View {
        Group {
            if isSealed {
                SealedLetterCard(message: message, unsealing: unsealing, onOpen: unseal)
                    .transition(.scale(scale: 1.1).combined(with: .opacity))
            } else {
                openCard
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .overlay {
            if celebrating {
                FloatingHeartsView(emojis: ["💌", "💖", "✨", "💜"], count: 12)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showReader) {
            LetterReaderView(message: message, senderName: senderName)
        }
        .sensoryFeedback(.success, trigger: unsealing) { _, new in new }
    }

    private var senderName: String {
        isMine ? (appState.me?.name ?? L10n.t("chat.you")) : appState.partnerName
    }

    private func unseal() {
        guard !unsealing else { return }
        unsealing = true
        celebrating = true
        SoundEngine.shared.play(.tada)
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.spring(response: 0.55)) {
                OpenedLettersStore.shared.markOpened(message.id, coupleId: appState.couple?.id)
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            celebrating = false
            unsealing = false
        }
    }

    private var openCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("chat.letterBadge"), systemImage: "envelope.open.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            if let token = message.openWhen {
                Label(LetterSeal.sentence(for: token), systemImage: "lock.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let title = message.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            Text(message.text ?? "")
                .font(.body)
                .lineLimit(8)
            HStack {
                Spacer()
                ChatTimestampText(date: message.createdAt, isMine: isMine, tinted: false,
                                  read: chatReadReceipt(for: message, isMine: isMine, partner: appState.partner),
                                  edited: message.editedAt != nil)
            }
        }
        .padding(14)
        .frame(maxWidth: 300)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(count: 2) { onReact(ChatReactions.quick) }
        .onTapGesture { showReader = true }
        .contextMenu {
            ChatReactMenu(onReact: onReact)
            Button {
                let parts = [message.title, message.text].compactMap { $0 }.filter { !$0.isEmpty }
                UIPasteboard.general.string = parts.joined(separator: "\n\n")
                appState.notify(L10n.t("chat.copied"), style: .success)
            } label: {
                Label(L10n.t("chat.copy"), systemImage: "doc.on.doc")
            }
            Button {
                showReader = true
            } label: {
                Label(L10n.t("chat.read"), systemImage: "book")
            }
            ChatPinButton(message: message)
            if let onForward {
                Button {
                    onForward()
                } label: {
                    Label(L10n.t("chat.forwardLetter"), systemImage: "arrowshape.turn.up.right")
                }
            }
            if let onEdit { ChatEditButton(onEdit: onEdit) }
            if let onDelete { ChatDeleteButton(onDelete: onDelete) }
        }
    }
}

// MARK: - Timestamp & receipts

/// nil → no receipt (partner's message or optimistic temp) · false → sent ·
/// true → partner's `lastReadAt` covers this message.
func chatReadReceipt(for message: Message, isMine: Bool, partner: Member?) -> Bool? {
    guard isMine, !message.id.hasPrefix("local-") else { return nil }
    guard let readAt = partner?.lastReadAt else { return false }
    return readAt >= message.createdAt
}

struct ChatTimestampText: View {
    let date: Date
    let isMine: Bool
    /// False when the bubble has a neutral background (letters).
    var tinted: Bool = true
    var read: Bool? = nil
    var edited: Bool = false

    private var color: Color {
        tinted ? ChatBubbleShape.secondaryText(isMine: isMine) : .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            if edited {
                Text(L10n.t("chat.edited"))
                    .italic()
            }
            Text(date.formatted(date: .omitted, time: .shortened))
            if let read {
                ChatReadReceiptMark(read: read, tinted: tinted && isMine)
            }
        }
        .font(.caption2)
        .foregroundStyle(color)
    }
}

/// One checkmark = sent, two = read by the partner.
struct ChatReadReceiptMark: View {
    let read: Bool
    var tinted = true

    var body: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "checkmark")
            if read {
                Image(systemName: "checkmark").offset(x: 4)
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(read ? (tinted ? Color.white : Color.accentColor) : (tinted ? Color.white.opacity(0.6) : Color.secondary))
        .padding(.trailing, read ? 4 : 0)
        .accessibilityLabel(L10n.t(read ? "chat.receipt.read" : "chat.receipt.sent"))
    }
}

// MARK: - Context-menu rows

struct ChatDeleteButton: View {
    let onDelete: () -> Void
    var body: some View {
        Button(role: .destructive, action: onDelete) {
            Label(L10n.t("chat.deleteMessage"), systemImage: "trash")
        }
    }
}

struct ChatEditButton: View {
    let onEdit: () -> Void
    var body: some View {
        Button(action: onEdit) {
            Label(L10n.t("chat.editMessage"), systemImage: "pencil")
        }
    }
}

/// "Reagieren …" submenu for bubble context menus.
struct ChatReactMenu: View {
    let onReact: (String) -> Void

    var body: some View {
        Menu {
            ForEach(ChatReactions.palette, id: \.self) { emoji in
                Button {
                    onReact(emoji)
                } label: {
                    Text(emoji)
                }
                .accessibilityLabel(L10n.t("chat.reactWith", ["emoji": emoji]))
            }
        } label: {
            Label(L10n.t("chat.react"), systemImage: "face.smiling")
        }
    }
}

/// Reaction chips under a bubble; tapping toggles that emoji for me.
struct ChatReactionChips: View {
    let message: Message
    let myMemberId: String?
    let onToggle: (String) -> Void

    private struct Entry: Identifiable {
        let emoji: String
        let count: Int
        let mine: Bool
        var id: String { emoji }
    }

    private var entries: [Entry] {
        guard let reactions = message.reactions else { return [] }
        return reactions
            .filter { !$0.value.isEmpty }
            .sorted { a, b in
                let ia = ChatReactions.palette.firstIndex(of: a.key) ?? Int.max
                let ib = ChatReactions.palette.firstIndex(of: b.key) ?? Int.max
                if ia != ib { return ia < ib }
                return a.key < b.key
            }
            .map { emoji, ids in
                Entry(emoji: emoji, count: ids.count, mine: myMemberId.map { ids.contains($0) } ?? false)
            }
    }

    @ViewBuilder var body: some View {
        if !entries.isEmpty {
            HStack(spacing: 5) {
                ForEach(entries) { entry in
                    Button {
                        onToggle(entry.emoji)
                    } label: {
                        HStack(spacing: 3) {
                            Text(entry.emoji).font(.caption)
                            if entry.count > 1 {
                                Text("\(entry.count)")
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 7)
                        .background(entry.mine ? Color.accentColor.opacity(0.18) : Color.tertiaryCardBackground, in: Capsule())
                        .overlay {
                            if entry.mine {
                                Capsule().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("chat.reactWith", ["emoji": entry.emoji]))
                    .accessibilityAddTraits(entry.mine ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Edit sheet

struct MessageEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let message: Message
    let onSave: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("chat.inputPlaceholder"), text: $draft, axis: .vertical)
                        .lineLimit(2...10)
                        .focused($focused)
                } footer: {
                    Text(L10n.t("chat.editHint"))
                }
            }
            .navigationTitle(L10n.t("chat.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save")) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || draft.trimmingCharacters(in: .whitespacesAndNewlines) == message.text)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            draft = message.text ?? ""
            focused = true
        }
    }
}

// MARK: - Photo picker (send an existing gallery photo)

struct ChatPhotoPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onSent: (Message) -> Void

    @State private var photos: [Photo] = []
    @State private var loading = true
    @State private var selected: Photo?
    @State private var caption = ""
    @State private var sending = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if photos.isEmpty {
                    ContentUnavailableView(L10n.t("chat.photoPicker.emptyTitle"), systemImage: "photo.on.rectangle",
                                           description: Text(L10n.t("chat.photoPicker.emptyBody")))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(photos) { photo in
                                Button {
                                    withAnimation(.snappy) { selected = photo }
                                } label: {
                                    RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .overlay(alignment: .topTrailing) {
                                            if selected?.id == photo.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.white, Color.accentColor)
                                                    .padding(6)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(photo.caption ?? L10n.t("memories.gallery.title"))
                                .accessibilityAddTraits(selected?.id == photo.id ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("chat.sendPhoto"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if selected != nil {
                    HStack(spacing: 8) {
                        TextField(L10n.t("chat.photoPicker.caption"), text: $caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .capsule)
                        Button {
                            send()
                        } label: {
                            Group {
                                if sending { ProgressView().tint(.white) } else { Image(systemName: "arrow.up").font(.body.weight(.bold)) }
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(sending)
                        .accessibilityLabel(L10n.t("common.send"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }
        }
        .task {
            guard let api = appState.api else { loading = false; return }
            photos = (try? await api.photos()) ?? []
            loading = false
        }
    }

    private func send() {
        guard let api = appState.api, let photo = selected, !sending else { return }
        sending = true
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let message = try await api.sendPhotoMessage(photoId: photo.id, text: text.isEmpty ? nil : text)
                SoundEngine.shared.play(.pop)
                onSent(message)
                dismiss()
            } catch {
                appState.handleAPIError(error)
                sending = false
            }
        }
    }
}
