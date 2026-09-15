import SwiftUI

/// The classic "36 questions to fall in love" — one phone between the two
/// of you. Pick a set (3 × 12 questions), read each question out loud and
/// both answer. The finish screen suggests the famous 4 minutes of eye
/// contact with a built-in countdown.
struct Questions36View: View {
    @Environment(AppState.self) private var appState

    private enum Stage {
        case setup, deck, finish
    }

    private static let eyeContactSeconds = 240

    /// Last chosen question set survives app restarts.
    private static let setKey = "sooodreamy.q36.set"

    private static var storedSet: Int {
        let value = UserDefaults.standard.integer(forKey: setKey)
        return (1...3).contains(value) ? value : 1
    }

    @State private var stage: Stage = .setup
    @State private var selectedSet = Questions36View.storedSet
    @State private var index = 0
    @State private var goingForward = true
    @State private var sharing = false

    // Eye-contact countdown
    @State private var remaining = Questions36View.eyeContactSeconds
    @State private var timerRunning = false
    @State private var timerDone = false
    @State private var timerTask: Task<Void, Never>?

    private var info: GameInfo? { GameCatalog.info(.questions36) }
    private var accent: Color { info?.tint ?? .blue }

    var body: some View {
        ScrollView {
            content
                .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .overlay {
            if timerDone {
                FloatingHeartsView(emojis: ["💜", "💖", "✨", "🥹"], count: 22)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(L10n.t("games.card.questions36.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if stage != .setup {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        restart()
                    } label: {
                        Label(L10n.t("games.q36.again"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    // MARK: Data

    private var questions: [Question36] {
        ContentPack.questions36
            .filter { $0.set == selectedSet }
            .sorted { $0.id < $1.id }
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .setup: setupScreen
        case .deck: deckScreen
        case .finish: finishScreen
        }
    }

    // MARK: Setup

    @ViewBuilder
    private var setupScreen: some View {
        if let info {
            GameStartCard(info: info, rules: L10n.t("games.q36.intro"), starting: false, onStart: startDeck) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L10n.t("games.q36.set", ["n": ""]), selection: $selectedSet) {
                        Text("🌱 " + L10n.t("games.q36.set", ["n": "1"])).tag(1)
                        Text("🌊 " + L10n.t("games.q36.set", ["n": "2"])).tag(2)
                        Text("🔥 " + L10n.t("games.q36.set", ["n": "3"])).tag(3)
                    }
                    .pickerStyle(.segmented)
                    Text(L10n.t("games.q36.set\(selectedSet)"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: selectedSet) { _, set in
                    UserDefaults.standard.set(set, forKey: Self.setKey)
                }
                .sensoryFeedback(.selection, trigger: selectedSet)
            }
        }
    }

    private func startDeck() {
        index = 0
        goingForward = true
        stage = .deck
        SoundEngine.shared.play(.pop)
        Haptics.shared.tap()
    }

    // MARK: Deck

    private var deckScreen: some View {
        VStack(spacing: 14) {
            GameHeaderBar(title: L10n.t("games.q36.progress", ["n": String(index + 1), "total": String(questions.count)]),
                          progress: Double(index + 1) / Double(max(questions.count, 1)),
                          tint: accent)
            questionCard
            deckControls
            if appState.api != nil, index < questions.count {
                GameShareButton(sharing: sharing, shared: false) { shareToChat() }
            }
            Text(L10n.t("games.q36.swipeHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var questionCard: some View {
        if index < questions.count {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.title)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                Text(questions[index].text.resolved(L10n.lang))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(L10n.t("games.q36.set", ["n": String(selectedSet)]) + " · " + String(questions[index].id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
            .cardSurface(padding: 20)
            .id(index)
            .transition(cardTransition)
            .gesture(swipeGesture)
        }
    }

    private var cardTransition: AnyTransition {
        if goingForward {
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity))
        }
        return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                           removal: .move(edge: .trailing).combined(with: .opacity))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width < -50 {
                    goNext()
                } else if value.translation.width > 50 {
                    goBack()
                }
            }
    }

    private var deckControls: some View {
        HStack(spacing: 12) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.glass)
            .disabled(index == 0)
            .accessibilityLabel(L10n.t("common.back"))
            Button {
                goNext()
            } label: {
                Text(index >= questions.count - 1 ? L10n.t("common.done") : L10n.t("games.next"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .controlSize(.large)
    }

    /// Posts the current question into the couple chat ("💫 36 Questions — question 7: …").
    private func shareToChat() {
        guard let api = appState.api, index < questions.count, !sharing else { return }
        let question = questions[index]
        sharing = true
        let header = L10n.t("games.q36.shareHeader", ["n": String(question.id)])
        let text = header + "\n" + question.text.resolved(L10n.lang)
        Task {
            do {
                try await api.sendMessage(type: .text, text: text)
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            sharing = false
        }
    }

    private func goNext() {
        Haptics.shared.tap()
        if index >= questions.count - 1 {
            stage = .finish
            SoundEngine.shared.play(.sparkle)
            return
        }
        goingForward = true
        withAnimation(.snappy) {
            index += 1
        }
        SoundEngine.shared.play(.pop)
    }

    private func goBack() {
        guard index > 0 else { return }
        goingForward = false
        withAnimation(.snappy) {
            index -= 1
        }
        Haptics.shared.tap()
    }

    // MARK: Finish + eye-contact timer

    private var finishScreen: some View {
        GameResultCard(title: L10n.t("games.q36.finishTitle"),
                       subtitle: L10n.t("games.q36.eyeContact"),
                       emoji: timerDone ? "🥹" : "👀") {
            timerRing
            if timerDone {
                Text(L10n.t("games.q36.timerDone"))
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)
            }
            timerButtons
        }
    }

    /// Clock-app style countdown ring.
    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: timerProgress)
            Text(timeString)
                .font(.system(size: 44, weight: .light))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: 190, height: 190)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeString)
    }

    private var timerProgress: Double {
        Double(Self.eyeContactSeconds - remaining) / Double(Self.eyeContactSeconds)
    }

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var timerButtons: some View {
        HStack(spacing: 10) {
            Button {
                toggleTimer()
            } label: {
                Label(timerLabel, systemImage: timerRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(remaining == 0)
            Button {
                resetTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.glass)
            .accessibilityLabel(L10n.t("common.retry"))
        }
        .controlSize(.large)
    }

    private var timerLabel: String {
        if timerRunning {
            return L10n.t("games.q36.timerPause")
        }
        if remaining < Self.eyeContactSeconds && remaining > 0 {
            return L10n.t("games.q36.timerResume")
        }
        return L10n.t("games.q36.timerStart")
    }

    private func toggleTimer() {
        if timerRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    private func startTimer() {
        guard remaining > 0 else { return }
        timerRunning = true
        Haptics.shared.tap()
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                tick()
                if remaining <= 0 { return }
            }
        }
    }

    private func pauseTimer() {
        timerRunning = false
        timerTask?.cancel()
        Haptics.shared.tap()
    }

    private func resetTimer() {
        timerTask?.cancel()
        timerRunning = false
        timerDone = false
        remaining = Self.eyeContactSeconds
        Haptics.shared.tap()
    }

    private func tick() {
        guard timerRunning, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 {
            timerRunning = false
            timerDone = true
            SoundEngine.shared.play(.tada)
            Haptics.shared.success()
        }
    }

    private func restart() {
        resetTimer()
        stage = .setup
        index = 0
    }
}
