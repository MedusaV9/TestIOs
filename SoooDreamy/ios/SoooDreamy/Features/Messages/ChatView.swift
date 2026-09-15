import SwiftUI
import Combine

/// "Nachrichten" — the couple chat. System navigation bar with the partner
/// in the principal slot, day-grouped bubbles, typing indicator, pinned
/// banner, and a Liquid Glass composer with voice notes, letters, photos
/// and quick touches.
struct ChatView: View {
    @Environment(AppState.self) private var appState

    @State private var model = ChatModel()
    @State private var draft = ""
    @State private var showVoiceRecorder = false
    @State private var showLetterComposer = false
    @State private var showPhotoPicker = false
    @State private var showTouchStudio = false
    @State private var editingMessage: Message?
    @State private var forwardingLetter: Message?
    @State private var nearBottom = true
    @State private var searchQuery = ""
    @State private var searchPresented = false
    @State private var pinnedJumpTarget: String?
    @State private var touchSends = 0
    @FocusState private var inputFocused: Bool

    private static let bottomAnchorID = "chat.bottomAnchor"

    var body: some View {
        NavigationStack {
            messageArea
                .background(Color.systemBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        partnerTitle
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showLetterComposer = true
                            } label: {
                                Label(L10n.t("chat.letterTitle"), systemImage: "envelope")
                            }
                            Button {
                                showVoiceRecorder = true
                            } label: {
                                Label(L10n.t("chat.voiceTitle"), systemImage: "mic")
                            }
                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label(L10n.t("chat.sendPhoto"), systemImage: "photo")
                            }
                            Button {
                                showTouchStudio = true
                            } label: {
                                Label(L10n.t("chat.sendHaptic"), systemImage: "hand.tap")
                            }
                        } label: {
                            Label(L10n.t("common.more"), systemImage: "ellipsis")
                        }
                    }
                }
                .searchable(text: $searchQuery, isPresented: $searchPresented,
                            placement: .navigationBarDrawer(displayMode: .automatic),
                            prompt: L10n.t("chat.searchPlaceholder"))
                .searchToolbarBehavior(.minimize)
                .safeAreaBar(edge: .bottom) {
                    if !searchPresented {
                        composer
                    }
                }
        }
        .onAppear {
            model.configure(appState)
            appState.markChatRead()
            Task { await model.loadInitial() }
        }
        .onDisappear { model.stopTyping() }
        .onChange(of: appState.servers.activeProfileID) {
            model.reset()
            Task { await model.loadInitial() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            model.handle(event)
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderSheet { message in model.acceptSent(message) }
        }
        .sheet(isPresented: $showLetterComposer) {
            LetterComposeView { message in model.acceptSent(message) }
        }
        .sheet(isPresented: $showPhotoPicker) {
            ChatPhotoPickerSheet { message in model.acceptSent(message) }
        }
        .sheet(isPresented: $showTouchStudio) {
            TouchStudioView()
        }
        .sheet(item: $editingMessage) { message in
            MessageEditSheet(message: message) { newText in
                model.editMessage(message, newText: newText)
            }
        }
        .sheet(item: $forwardingLetter) { letter in
            LetterComposeView(initialTitle: letter.title ?? "", initialText: letter.text ?? "") { message in
                model.acceptSent(message)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: touchSends)
    }

    // MARK: Title

    private var partnerTitle: some View {
        HStack(spacing: 10) {
            MemberAvatar(member: appState.partner, size: 32, showPresence: true)
            VStack(alignment: .leading, spacing: 0) {
                Text(appState.partnerName)
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(appState.partner?.online == true ? Color.green : Color.secondary)
                    .contentTransition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if appState.socket.state != .connected { return L10n.t("conn.offline") }
        if appState.partnerTyping { return L10n.t("chat.typingShort") }
        if appState.partner?.online == true { return L10n.t("presence.online") }
        if let lastSeen = appState.partner?.lastSeenAt {
            return L10n.t("presence.lastSeen", ["time": L10n.relativeShort(lastSeen)])
        }
        return L10n.t("presence.offline")
    }

    // MARK: Search filtering

    private var searchText: String { searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isFiltering: Bool { searchPresented && !searchText.isEmpty }

    private var displaySections: [ChatDaySection] {
        guard isFiltering else { return model.sections }
        let query = searchText
        return model.sections.compactMap { section in
            let matches = section.messages.filter { message in
                (message.text ?? "").localizedCaseInsensitiveContains(query)
                    || (message.title ?? "").localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : ChatDaySection(id: section.id, messages: matches)
        }
    }

    // MARK: Message area

    @ViewBuilder private var messageArea: some View {
        if model.initialLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.messages.isEmpty {
            ContentUnavailableView(L10n.t("chat.emptyTitle"),
                                   systemImage: "bubble.left.and.bubble.right",
                                   description: Text(L10n.t("chat.emptySubtitle", ["name": appState.partnerName])))
        } else if isFiltering && displaySections.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            messageList
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6, pinnedViews: [.sectionHeaders]) {
                    ForEach(displaySections) { section in
                        Section {
                            ForEach(section.messages) { message in
                                ChatMessageRow(message: message,
                                               isMine: message.senderId == appState.memberId,
                                               onReact: { emoji in model.toggleReaction(on: message, emoji: emoji) },
                                               onEdit: { editingMessage = message },
                                               onDelete: { model.deleteMessage(message) },
                                               onForward: { forwardingLetter = message })
                            }
                        } header: {
                            ChatDateChip(day: section.id)
                        }
                    }
                    if appState.partnerTyping && !isFiltering {
                        ChatTypingRow()
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                        .onAppear { withAnimation(.snappy) { nearBottom = true } }
                        .onDisappear { withAnimation(.snappy) { nearBottom = false } }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .animation(.spring(response: 0.35), value: model.messages)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await model.loadOlder() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isFiltering {
                    ChatPinnedBanner(messages: model.messages) { messageId in jumpToPinned(messageId) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !nearBottom && !isFiltering {
                    Button {
                        scrollToBottom(proxy)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(L10n.t("chat.jumpLatest"))
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .onChange(of: model.messages.last?.id) {
                if nearBottom || model.messages.last?.senderId == appState.memberId {
                    scrollToBottom(proxy)
                }
            }
            .onChange(of: appState.partnerTyping) {
                if appState.partnerTyping && nearBottom { scrollToBottom(proxy) }
            }
            .onChange(of: inputFocused) {
                if inputFocused { scrollToBottom(proxy) }
            }
            .onChange(of: pinnedJumpTarget) {
                guard let target = pinnedJumpTarget else { return }
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo(target, anchor: .center) }
                pinnedJumpTarget = nil
            }
            // Search results hand over a message id before switching tabs.
            .onChange(of: appState.chatJumpTarget, initial: true) {
                guard let target = appState.chatJumpTarget else { return }
                appState.chatJumpTarget = nil
                jumpToPinned(target)
            }
        }
    }

    private func jumpToPinned(_ messageId: String) {
        if model.messages.contains(where: { $0.id == messageId }) {
            pinnedJumpTarget = messageId
        } else {
            appState.notify(L10n.t("chat.pinnedNotLoaded"), style: .info)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.35)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    // MARK: Composer

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var composer: some View {
        VStack(spacing: 8) {
            if trimmedDraft.isEmpty && appState.partner != nil {
                quickTouches
            }
            GlassEffectContainer(spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label(L10n.t("chat.sendPhoto"), systemImage: "photo")
                        }
                        Button {
                            showLetterComposer = true
                        } label: {
                            Label(L10n.t("chat.letterTitle"), systemImage: "envelope")
                        }
                        Button {
                            showTouchStudio = true
                        } label: {
                            Label(L10n.t("chat.sendHaptic"), systemImage: "hand.tap")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .accessibilityLabel(L10n.t("chat.attachA11y"))

                    HStack(alignment: .bottom, spacing: 6) {
                        TextField(L10n.t("chat.inputPlaceholder"), text: $draft, axis: .vertical)
                            .lineLimit(1...5)
                            .focused($inputFocused)
                            .onChange(of: draft) {
                                if draft.isEmpty { model.stopTyping() } else { model.noteTyping() }
                            }
                            .onSubmit { sendDraft() }
                            .submitLabel(.send)
                        if trimmedDraft.isEmpty {
                            Button {
                                showVoiceRecorder = true
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.body)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L10n.t("chat.micA11y"))
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))

                    if !trimmedDraft.isEmpty {
                        Button {
                            sendDraft()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityLabel(L10n.t("chat.sendA11y"))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.snappy, value: trimmedDraft.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    /// One-tap touches (heartbeat, kiss, hug …) straight from the chat.
    private var quickTouches: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TouchKind.allCases) { kind in
                        Button {
                            touchSends += 1
                            appState.sendTouch(kind)
                        } label: {
                            Label {
                                Text(L10n.t(kind.titleKey))
                                    .font(.footnote.weight(.medium))
                            } icon: {
                                Text(kind.emoji)
                            }
                            .padding(.horizontal, 2)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 4, for: .scrollContent)
    }

    private func sendDraft() {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        draft = ""
        Task {
            let ok = await model.sendText(text)
            if !ok && draft.isEmpty { draft = text }
        }
    }
}

// MARK: - Date chip

struct ChatDateChip: View {
    let day: Date

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return L10n.t("chat.today") }
        if cal.isDateInYesterday(day) { return L10n.t("chat.yesterday") }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .glassEffect(.regular, in: .capsule)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

// MARK: - Typing indicator

struct ChatTypingRow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            MemberAvatar(member: appState.partner, size: 28)
            HStack(spacing: 8) {
                ChatTypingDots()
                Text(L10n.t("chat.typing", ["name": appState.partnerName]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background(ChatBubbleShape.received, in: ChatBubbleShape.shape)
            Spacer(minLength: 44)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityLabel(L10n.t("chat.typing", ["name": appState.partnerName]))
    }
}

struct ChatTypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    let wave = max(0, sin(t * 5.2 - Double(i) * 0.85))
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: -4 * CGFloat(wave))
                        .opacity(0.45 + 0.55 * wave)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
