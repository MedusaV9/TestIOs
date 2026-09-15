import SwiftUI
import Combine

// MARK: - Daily word logic + persistence

/// Tile / key evaluation. Raw values are ordered so a key on the on-screen
/// keyboard always shows its best-known state (correct beats present beats
/// absent).
enum WordleMark: Int {
    case absent = 0
    case present = 1
    case correct = 2
}

/// Pure logic + storage for the daily Liebes-Wordle so the hub card and the
/// game screen read exactly the same state.
enum WordleDaily {
    static let maxGuesses = 6
    static let wordLength = 5

    static func words(lang: String) -> [String] {
        lang == "de" ? ContentPack.wordleWordsDE : ContentPack.wordleWordsEN
    }

    /// Allowed-guess dictionary (the solution pool doubles as dictionary).
    static func dictionary(lang: String) -> Set<String> {
        lang == "de" ? dictionaryDE : dictionaryEN
    }

    private static let dictionaryDE = Set(ContentPack.wordleWordsDE)
    private static let dictionaryEN = Set(ContentPack.wordleWordsEN)

    /// Deterministic daily solution — same DJB2-style hash as
    /// `ContentPack.dailyQuestion(dateKey:coupleId:)`, so both partners
    /// derive the identical word for the day.
    static func solution(coupleId: String, dateKey: String, lang: String) -> String {
        let list = words(lang: lang)
        guard !list.isEmpty else { return lang == "de" ? "LIEBE" : "HEART" }
        let seed = (dateKey + coupleId).unicodeScalars.reduce(5381 as UInt64) {
            ($0 << 5) &+ $0 &+ UInt64($1.value)
        }
        return list[Int(seed % UInt64(list.count))]
    }

    // MARK: Scoring (standard Wordle two-pass algorithm)

    /// Pass 1 marks exact-position greens and counts the solution's leftover
    /// letters; pass 2 hands out yellows limited by those remaining counts,
    /// so duplicate letters are never over-rewarded.
    static func score(guess: String, solution: String) -> [WordleMark] {
        let guessChars = Array(guess)
        let solutionChars = Array(solution)
        var marks = [WordleMark](repeating: .absent, count: guessChars.count)
        guard guessChars.count == solutionChars.count else { return marks }
        var remaining: [Character: Int] = [:]
        for index in 0..<guessChars.count {
            if guessChars[index] == solutionChars[index] {
                marks[index] = .correct
            } else {
                remaining[solutionChars[index], default: 0] += 1
            }
        }
        for index in 0..<guessChars.count where marks[index] != .correct {
            let letter = guessChars[index]
            if let available = remaining[letter], available > 0 {
                marks[index] = .present
                remaining[letter] = available - 1
            }
        }
        return marks
    }

    /// Outcome of a completed duel day — the verdict rule of the daily duel:
    /// a win beats a loss, two wins are ranked by row count. Equal wins and
    /// shared defeats both land on `.tie` (that's how the record counts them).
    enum DuelOutcome {
        case meWin, partnerWin, tie
    }

    static func duelOutcome(mine: WordleResult, partner: WordleResult) -> DuelOutcome {
        if mine.win && !partner.win { return .meWin }
        if partner.win && !mine.win { return .partnerWin }
        if mine.win && partner.win {
            if mine.rows < partner.rows { return .meWin }
            if mine.rows > partner.rows { return .partnerWin }
        }
        return .tie
    }

    /// Spoiler-free 🟩🟨⬛ rows for a full board — used for chat sharing and
    /// as the duel `grid` payload (also for boards restored from storage).
    static func emojiGrid(guesses: [String], solution: String) -> String {
        guesses.map { guess in
            score(guess: guess, solution: solution).map { mark -> String in
                switch mark {
                case .correct: return "🟩"
                case .present: return "🟨"
                case .absent: return "⬛"
                }
            }
            .joined()
        }
        .joined(separator: "\n")
    }

    // MARK: Board persistence (per couple + day + language)

    static func storageKey(coupleId: String, dateKey: String, lang: String) -> String {
        "sooodreamy.wordle.\(coupleId).\(dateKey).\(lang)"
    }

    static func loadGuesses(coupleId: String, dateKey: String, lang: String) -> [String] {
        let key = storageKey(coupleId: coupleId, dateKey: dateKey, lang: lang)
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func saveGuesses(_ guesses: [String], coupleId: String, dateKey: String, lang: String) {
        let key = storageKey(coupleId: coupleId, dateKey: dateKey, lang: lang)
        UserDefaults.standard.set(guesses, forKey: key)
    }

    /// True once today's puzzle is solved or all six guesses are used —
    /// the hub card reads this for its ✓ overlay.
    static func isFinished(coupleId: String, dateKey: String, lang: String) -> Bool {
        let guesses = loadGuesses(coupleId: coupleId, dateKey: dateKey, lang: lang)
        guard !guesses.isEmpty else { return false }
        if guesses.count >= maxGuesses { return true }
        return guesses.last == solution(coupleId: coupleId, dateKey: dateKey, lang: lang)
    }

    // MARK: Duel submission flag (server is idempotent; this just avoids re-sends)

    private static func submittedKey(coupleId: String, dateKey: String, lang: String) -> String {
        "sooodreamy.wordle.submitted.\(coupleId).\(dateKey).\(lang)"
    }

    static func isSubmitted(coupleId: String, dateKey: String, lang: String) -> Bool {
        UserDefaults.standard.bool(forKey: submittedKey(coupleId: coupleId, dateKey: dateKey, lang: lang))
    }

    static func markSubmitted(coupleId: String, dateKey: String, lang: String) {
        UserDefaults.standard.set(true, forKey: submittedKey(coupleId: coupleId, dateKey: dateKey, lang: lang))
    }

    // MARK: Hard mode 💪 (client-side preference + per-day record)

    private static let hardModeKey = "sooodreamy.wordle.hardMode"

    static var hardMode: Bool {
        UserDefaults.standard.bool(forKey: hardModeKey)
    }

    static func setHardMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: hardModeKey)
    }

    /// Whether a specific day's board was played in hard mode — written at
    /// the first guess (the toggle is locked from then on) so the end-card
    /// pill and the share asterisk survive a restore.
    private static func hardKey(coupleId: String, dateKey: String, lang: String) -> String {
        "sooodreamy.wordle.hard.\(coupleId).\(dateKey).\(lang)"
    }

    static func wasHardMode(coupleId: String, dateKey: String, lang: String) -> Bool {
        UserDefaults.standard.bool(forKey: hardKey(coupleId: coupleId, dateKey: dateKey, lang: lang))
    }

    static func markHardMode(coupleId: String, dateKey: String, lang: String) {
        UserDefaults.standard.set(true, forKey: hardKey(coupleId: coupleId, dateKey: dateKey, lang: lang))
    }

    // MARK: Simple local stats (no streaks, just counters)

    private static let playedKey = "sooodreamy.wordle.stats.played"
    private static let wonKey = "sooodreamy.wordle.stats.won"

    static var gamesPlayed: Int {
        UserDefaults.standard.integer(forKey: playedKey)
    }

    static var gamesWon: Int {
        UserDefaults.standard.integer(forKey: wonKey)
    }

    static func recordFinish(won: Bool) {
        UserDefaults.standard.set(gamesPlayed + 1, forKey: playedKey)
        if won {
            UserDefaults.standard.set(gamesWon + 1, forKey: wonKey)
        }
    }
}

// MARK: - Screen

/// Liebes-Wordle — the daily couple Wordle. Grid + on-screen keyboard are
/// game content (green/yellow/grey tiles); everything around them is
/// system chrome: header bar, button toggle for hard mode, result card,
/// duel rows and a record link.
struct WordleView: View {
    @Environment(AppState.self) private var appState

    @State private var guesses: [String] = []
    @State private var currentGuess = ""
    @State private var flippedRows: Set<Int> = []
    @State private var shakePhase: CGFloat = 0
    @State private var endVisible = false
    @State private var celebrate = false
    @State private var bounceRow: Int?
    @State private var sendingShare = false
    @State private var shared = false
    @State private var duelSharing = false
    @State private var duelShared = false
    @State private var restored = false
    @State private var dateKey = SharedDates.todayKey()
    @State private var day: WordleDayResponse?
    @State private var submitFailed = false
    @State private var hardMode = WordleDaily.hardMode

    // MARK: Derived state

    private var lang: String { L10n.lang }

    private var coupleId: String { appState.couple?.id ?? "" }

    private var solution: String {
        WordleDaily.solution(coupleId: coupleId, dateKey: dateKey, lang: lang)
    }

    private var didWin: Bool {
        guesses.last == solution
    }

    private var finished: Bool {
        didWin || guesses.count >= WordleDaily.maxGuesses
    }

    /// Whether THIS board runs under hard-mode rules. An empty board follows
    /// the live preference; once a guess exists the per-day flag is the
    /// truth (immune to preference flips via the other language's board).
    private var hardModeActive: Bool {
        guesses.isEmpty ? hardMode : boardWasHard
    }

    /// Per-day record — read for validation, the end-card pill and the
    /// share asterisk (survives restore).
    private var boardWasHard: Bool {
        WordleDaily.wasHardMode(coupleId: coupleId, dateKey: dateKey, lang: lang)
    }

    /// Best-known state per keyboard letter across all submitted guesses.
    private var keyMarks: [String: WordleMark] {
        var marks: [String: WordleMark] = [:]
        for guess in guesses {
            let rowMarks = WordleDaily.score(guess: guess, solution: solution)
            for (index, character) in guess.enumerated() {
                let key = String(character)
                let mark = rowMarks[index]
                if let existing = marks[key], existing.rawValue >= mark.rawValue { continue }
                marks[key] = mark
            }
        }
        return marks
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                grid
                if finished && endVisible {
                    endCard
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    keyboard
                }
                duelSection
                recordLink
            }
            .padding(Brand.screenInset)
            .padding(.bottom, 12)
        }
        .groupedScreenBackground()
        .overlay {
            if celebrate {
                FloatingHeartsView(emojis: ["💘", "💚", "💛", "✨", "💞"])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(L10n.t("games.wordle.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !finished {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: Binding(get: { hardModeActive }, set: { _ in toggleHardMode() })) {
                        Label(L10n.t("games.wordle.hard.toggle"), systemImage: "flame")
                    }
                    .toggleStyle(.button)
                    .disabled(!guesses.isEmpty)
                }
            }
        }
        .onAppear {
            restore()
            // A board finished late yesterday may still be waiting for its submit.
            submitOrphanedYesterday()
            // Retries a today-submit that failed earlier.
            submitResultIfNeeded()
            loadDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            receiveDuelEvent(event)
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        dateKey = SharedDates.todayKey()
        guesses = WordleDaily.loadGuesses(coupleId: coupleId, dateKey: dateKey, lang: lang)
        flippedRows = Set(0..<guesses.count)
        endVisible = finished
        hardMode = WordleDaily.hardMode
    }

    // MARK: Header

    private var header: some View {
        GameHeaderBar(title: L10n.t("games.wordle.daily"),
                      subtitle: "\(min(guesses.count, WordleDaily.maxGuesses))/\(WordleDaily.maxGuesses)"
                          + (hardModeActive ? " · " + L10n.t("games.wordle.hard.pill") : ""),
                      progress: Double(guesses.count) / Double(WordleDaily.maxGuesses),
                      tint: .green)
    }

    private func toggleHardMode() {
        guard guesses.isEmpty else { return }
        hardMode.toggle()
        WordleDaily.setHardMode(hardMode)
        Haptics.shared.tap()
    }

    // MARK: Grid

    private var grid: some View {
        VStack(spacing: 6) {
            if !finished, appState.partner != nil {
                Text(L10n.t("games.wordle.sameWordHint", ["name": appState.partnerName]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
            }
            ForEach(0..<WordleDaily.maxGuesses, id: \.self) { row in
                gridRow(row)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func gridRow(_ row: Int) -> some View {
        if row < guesses.count {
            submittedRow(row)
        } else if row == guesses.count && !finished {
            activeRow
        } else {
            placeholderRow
        }
    }

    private func submittedRow(_ row: Int) -> some View {
        let letters = Array(guesses[row])
        let marks = WordleDaily.score(guess: guesses[row], solution: solution)
        let revealed = flippedRows.contains(row)
        return HStack(spacing: 6) {
            ForEach(0..<WordleDaily.wordLength, id: \.self) { column in
                WordleTileView(letter: String(letters[column]),
                               mark: marks[column],
                               revealed: revealed,
                               delay: Double(column) * 0.18)
            }
        }
        .scaleEffect(bounceRow == row ? 1.08 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.35), value: bounceRow)
    }

    private var activeRow: some View {
        let letters = Array(currentGuess)
        return HStack(spacing: 6) {
            ForEach(0..<WordleDaily.wordLength, id: \.self) { column in
                WordleTileView(letter: column < letters.count ? String(letters[column]) : "",
                               mark: nil,
                               revealed: false,
                               delay: 0)
            }
        }
        .modifier(WordleShakeEffect(animatableData: shakePhase))
    }

    private var placeholderRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<WordleDaily.wordLength, id: \.self) { _ in
                WordleTileView(letter: "", mark: nil, revealed: false, delay: 0)
            }
        }
    }

    // MARK: Keyboard

    private var keyboardRows: [[String]] {
        if lang == "de" {
            return [["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"],
                    ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                    ["Y", "X", "C", "V", "B", "N", "M"]]
        }
        return [["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
                ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                ["Z", "X", "C", "V", "B", "N", "M"]]
    }

    private var keyboard: some View {
        VStack(spacing: 7) {
            keyRow(keyboardRows[0])
            keyRow(keyboardRows[1])
                .padding(.horizontal, 16)
            HStack(spacing: 5) {
                enterKey
                keyRow(keyboardRows[2])
                backspaceKey
            }
        }
        .padding(.top, 6)
    }

    private func keyRow(_ letters: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(letters, id: \.self) { letter in
                letterKey(letter)
            }
        }
    }

    private func letterKey(_ letter: String) -> some View {
        let mark = keyMarks[letter]
        return Button {
            tapLetter(letter)
        } label: {
            Text(letter)
                .font(.callout.weight(.semibold))
                .foregroundStyle(keyTextColor(mark))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(keyFillColor(mark), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(letter)
    }

    private var enterKey: some View {
        Button(action: submitGuess) {
            Image(systemName: "return")
                .font(.body.weight(.semibold))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .accessibilityLabel(L10n.t("common.send"))
    }

    private var backspaceKey: some View {
        Button(action: tapBackspace) {
            Image(systemName: "delete.left")
                .font(.body.weight(.semibold))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .accessibilityLabel(L10n.t("common.delete"))
    }

    private func keyFillColor(_ mark: WordleMark?) -> Color {
        switch mark {
        case .correct: return Color.green
        case .present: return Color.yellow
        case .absent: return Color.secondary.opacity(0.35)
        case nil: return Color.tertiaryCardBackground
        }
    }

    private func keyTextColor(_ mark: WordleMark?) -> Color {
        switch mark {
        case .correct, .present: return .white
        case .absent: return .secondary
        case nil: return .primary
        }
    }

    // MARK: Input

    private func tapLetter(_ letter: String) {
        guard !finished, currentGuess.count < WordleDaily.wordLength else { return }
        currentGuess += letter
        Haptics.shared.tap()
    }

    private func tapBackspace() {
        guard !finished, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        Haptics.shared.tap()
    }

    private func submitGuess() {
        guard !finished else { return }
        guard currentGuess.count == WordleDaily.wordLength else {
            rejectGuess(messageKey: "games.wordle.tooShort")
            return
        }
        guard WordleDaily.dictionary(lang: lang).contains(currentGuess) else {
            rejectGuess(messageKey: "games.wordle.notInList")
            return
        }
        if hardModeActive, let hint = hardModeViolation(for: currentGuess) {
            rejectGuess(text: hint)
            return
        }
        let guess = currentGuess
        currentGuess = ""
        let row = guesses.count
        if row == 0 && hardMode {
            // Lock the board's mode in with the first guess.
            WordleDaily.markHardMode(coupleId: coupleId, dateKey: dateKey, lang: lang)
        }
        guesses.append(guess)
        WordleDaily.saveGuesses(guesses, coupleId: coupleId, dateKey: dateKey, lang: lang)
        flippedRows.insert(row)
        Haptics.shared.tap()
        if guess == solution {
            finishGame(won: true, row: row)
        } else if guesses.count >= WordleDaily.maxGuesses {
            finishGame(won: false, row: row)
        } else {
            SoundEngine.shared.play(.pop)
        }
    }

    private func rejectGuess(messageKey: String) {
        rejectGuess(text: L10n.t(messageKey))
    }

    private func rejectGuess(text: String) {
        Haptics.shared.warning()
        appState.notify(text, style: .info)
        withAnimation(.linear(duration: 0.45)) {
            shakePhase += 1
        }
    }

    /// First hard-mode violation for the candidate, or nil. Constraints are
    /// re-derived from the per-row `score` results: greens pin their exact
    /// position, yellows demand at least one occurrence anywhere (classic
    /// simple rule — deliberately not count-aware). A letter that later went
    /// green satisfies its earlier yellow demand via the position check.
    private func hardModeViolation(for candidate: String) -> String? {
        let candidateChars = Array(candidate)
        var pinned: [Int: Character] = [:]
        var required: Set<Character> = []
        for guess in guesses {
            let marks = WordleDaily.score(guess: guess, solution: solution)
            for (index, letter) in Array(guess).enumerated() {
                switch marks[index] {
                case .correct: pinned[index] = letter
                case .present: required.insert(letter)
                case .absent: break
                }
            }
        }
        for index in 0..<candidateChars.count {
            if let letter = pinned[index], candidateChars[index] != letter {
                return L10n.t("games.wordle.hard.keepGreen", ["letter": String(letter), "n": String(index + 1)])
            }
        }
        for letter in required.sorted() where !candidateChars.contains(letter) {
            return L10n.t("games.wordle.hard.useYellow", ["letter": String(letter)])
        }
        return nil
    }

    private func finishGame(won: Bool, row: Int) {
        WordleDaily.recordFinish(won: won)
        submitResultIfNeeded()
        Task {
            // Let the row finish its flip reveal first.
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.snappy) {
                endVisible = true
            }
            if won {
                celebrate = true
                SoundEngine.shared.play(.win)
                Haptics.shared.success()
                bounceRow = row
                try? await Task.sleep(nanoseconds: 700_000_000)
                bounceRow = nil
                try? await Task.sleep(nanoseconds: 3_800_000_000)
                withAnimation(.easeOut(duration: 0.6)) {
                    celebrate = false
                }
            } else {
                SoundEngine.shared.play(.lose)
            }
        }
    }

    // MARK: End card

    private var endCard: some View {
        GameResultCard(title: didWin ? praiseText : L10n.t("games.wordle.lossTitle"),
                       subtitle: didWin ? statsLine : L10n.t("games.wordle.lossBody"),
                       emoji: didWin ? "💘" : "🫂") {
            if boardWasHard {
                GamePhaseLabel(text: L10n.t("games.wordle.hard.pill"), systemImage: "flame.fill", tint: .orange)
            }
            if !didWin {
                VStack(spacing: 4) {
                    Text(L10n.t("games.wordle.solutionLabel"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(solution)
                        .font(.title2.weight(.bold))
                        .kerning(4)
                }
                Text(statsLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(action: shareToChat) {
                HStack(spacing: 8) {
                    if sendingShare {
                        ProgressView()
                    } else {
                        Label(shared ? L10n.t("games.wordle.sharedDone")
                                     : L10n.t("games.wordle.share", ["name": appState.partnerName]),
                              systemImage: shared ? "checkmark" : "paperplane")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(sendingShare || shared || appState.api == nil)
            Text(L10n.t("games.wordle.newWord"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var praiseText: String {
        L10n.t("games.wordle.praise\(min(max(guesses.count, 1), 6))")
    }

    private var statsLine: String {
        L10n.t("games.wordle.stats", ["played": String(WordleDaily.gamesPlayed),
                                      "won": String(WordleDaily.gamesWon)])
    }

    // MARK: Share to chat

    /// Spoiler-free 🟩🟨⬛ rows — sent to chat and submitted as the duel grid.
    private var emojiGrid: String {
        WordleDaily.emojiGrid(guesses: guesses, solution: solution)
    }

    /// Classic emoji summary — header + result grid for the chat. Hard-mode
    /// boards get the classic asterisk ("4/6*"); the duel submit payload is
    /// deliberately untouched (grid + rows only, no shape change).
    private var shareText: String {
        let hardSuffix = boardWasHard ? "*" : ""
        let scoreText = (didWin ? "\(guesses.count)/6" : "X/6") + hardSuffix
        let header = L10n.t("games.wordle.shareTitle", ["date": displayDate, "score": scoreText])
        return header + "\n" + emojiGrid
    }

    private var displayDate: String {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3 else { return dateKey }
        if lang == "de" {
            return "\(parts[2]).\(parts[1])."
        }
        return "\(parts[1])/\(parts[2])"
    }

    private func shareToChat() {
        guard let api = appState.api, !sendingShare else { return }
        let text = shareText
        sendingShare = true
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: text)
                shared = true
                SoundEngine.shared.play(.chime)
                Haptics.shared.success()
                appState.notify(L10n.t("games.wordle.shared", ["name": appState.partnerName]), style: .love)
            } catch {
                appState.handleAPIError(error)
            }
            sendingShare = false
        }
    }

    // MARK: Duel networking

    private func loadDay() {
        guard let api = appState.api else { return }
        let requestedDateKey = dateKey
        let requestedLang = lang
        Task {
            guard let response = try? await api.wordleDay(dateKey: requestedDateKey, lang: requestedLang) else { return }
            applyDay(response)
        }
    }

    /// Single choke point for `day` updates: drops responses for other
    /// days/languages and never lets a stale fetch regress a state that
    /// already knows my own result (e.g. a slow GET finishing after the
    /// submit round-trip already delivered `mine`).
    @discardableResult
    private func applyDay(_ response: WordleDayResponse) -> Bool {
        guard response.dateKey == dateKey else { return false }
        if let responseLang = response.lang, responseLang != lang { return false }
        if day?.mine != nil && response.mine == nil { return false }
        day = response
        return true
    }

    /// Fire-and-forget submission of the finished board for today. On failure
    /// the local flag stays unset (next `onAppear` or the retry button tries
    /// again); a `bad_datekey` rejection is terminal, so we mark it submitted
    /// to stop retrying. The server is idempotent — a duplicate submit just
    /// echoes the stored result.
    private func submitResultIfNeeded() {
        guard finished, !guesses.isEmpty else { return }
        guard let api = appState.api else { return }
        guard !WordleDaily.isSubmitted(coupleId: coupleId, dateKey: dateKey, lang: lang) else { return }
        submitFailed = false
        let submittedDateKey = dateKey
        let rows = guesses.count
        let win = didWin
        let grid = emojiGrid
        let submittedLang = lang
        let submittedCoupleId = coupleId
        Task {
            do {
                let response = try await api.submitWordle(dateKey: submittedDateKey, rows: rows,
                                                          win: win, grid: grid, lang: submittedLang)
                WordleDaily.markSubmitted(coupleId: submittedCoupleId, dateKey: submittedDateKey, lang: submittedLang)
                applyDay(response)
            } catch {
                if Self.isBadDateKey(error) {
                    WordleDaily.markSubmitted(coupleId: submittedCoupleId, dateKey: submittedDateKey, lang: submittedLang)
                } else {
                    submitFailed = true
                }
            }
        }
    }

    /// A board finished late yesterday but never submitted (app killed,
    /// offline, …) would be orphaned because `restore()` targets today.
    /// Checks yesterday's storage for both languages and submits with THAT
    /// dateKey — the server accepts ±1 day.
    private func submitOrphanedYesterday() {
        guard let api = appState.api else { return }
        guard let yesterday = yesterdayKey() else { return }
        for boardLang in ["de", "en"] {
            submitStoredBoard(api: api, dateKey: yesterday, lang: boardLang)
        }
    }

    private func submitStoredBoard(api: API, dateKey boardDateKey: String, lang boardLang: String) {
        let boardCoupleId = coupleId
        guard !WordleDaily.isSubmitted(coupleId: boardCoupleId, dateKey: boardDateKey, lang: boardLang) else { return }
        let boardGuesses = WordleDaily.loadGuesses(coupleId: boardCoupleId, dateKey: boardDateKey, lang: boardLang)
        guard !boardGuesses.isEmpty else { return }
        let boardSolution = WordleDaily.solution(coupleId: boardCoupleId, dateKey: boardDateKey, lang: boardLang)
        let won = boardGuesses.last == boardSolution
        guard won || boardGuesses.count >= WordleDaily.maxGuesses else { return }
        let grid = WordleDaily.emojiGrid(guesses: boardGuesses, solution: boardSolution)
        Task {
            do {
                _ = try await api.submitWordle(dateKey: boardDateKey, rows: boardGuesses.count,
                                               win: won, grid: grid, lang: boardLang)
                WordleDaily.markSubmitted(coupleId: boardCoupleId, dateKey: boardDateKey, lang: boardLang)
            } catch {
                // Too old by now — stop retrying forever. Other errors stay
                // unmarked and get another chance on the next appear.
                if Self.isBadDateKey(error) {
                    WordleDaily.markSubmitted(coupleId: boardCoupleId, dateKey: boardDateKey, lang: boardLang)
                }
            }
        }
    }

    private func yesterdayKey() -> String? {
        guard let date = SharedDates.calendar.date(byAdding: .day, value: -1, to: Date()) else {
            return nil
        }
        return SharedDates.todayKey(date)
    }

    private static func isBadDateKey(_ error: Error) -> Bool {
        if case APIError.http(_, let code, _) = error, code == "bad_datekey" {
            return true
        }
        return false
    }

    private func receiveDuelEvent(_ event: ServerEvent) {
        guard event.type == .wordleResult,
              let response = event.decode(WordleDayResponse.self) else { return }
        let partnerWasFinished = day?.partnerFinished ?? false
        guard applyDay(response) else { return }
        if !partnerWasFinished && response.partnerFinished {
            SoundEngine.shared.play(.chime)
            Haptics.shared.tap()
        }
    }

    // MARK: Duel section

    @ViewBuilder
    private var duelSection: some View {
        if appState.partner != nil, let day,
           day.dateKey == dateKey, (day.lang ?? lang) == lang {
            if let mine = day.mine, let partnerResult = day.partner {
                duelCard(mine: mine, partner: partnerResult)
            } else if !day.partnerFinished {
                duelStatusRow(systemImage: "hourglass",
                              text: L10n.t("games.wordle.duel.stillSolving", ["name": appState.partnerName]),
                              spinning: true)
            } else if !finished {
                duelStatusRow(systemImage: "bolt.fill",
                              text: L10n.t("games.wordle.duel.teaser", ["name": appState.partnerName]),
                              spinning: false)
            } else if submitFailed {
                // My submit failed — offer a retry instead of an eternal spinner.
                retryCard
            } else {
                // I just finished, partner too — my submit round-trip is in flight.
                duelStatusRow(systemImage: "arrow.triangle.2.circlepath",
                              text: L10n.t("games.wordle.duel.revealing"), spinning: true)
            }
        }
    }

    /// Small always-available entry into the running duel record.
    private var recordLink: some View {
        NavigationLink {
            WordleRecordView()
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: "chart.bar.fill", tint: .blue, size: 36)
                Text(L10n.t("games.wordle.record.button"))
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
                DisclosureChevron()
            }
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var retryCard: some View {
        HStack(spacing: 12) {
            Label(L10n.t("games.wordle.duel.sendFailed"), systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L10n.t("games.wordle.duel.retry"), action: submitResultIfNeeded)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .cardSurface(padding: 12)
    }

    private func duelStatusRow(systemImage: String, text: String, spinning: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if spinning {
                ProgressView()
            }
        }
        .cardSurface(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private func duelCard(mine: WordleResult, partner: WordleResult) -> some View {
        VStack(spacing: 14) {
            Label(L10n.t("games.wordle.duel.title"), systemImage: "bolt.fill")
                .font(.headline)
            HStack(alignment: .top, spacing: 14) {
                duelColumn(name: appState.me?.name ?? L10n.t("common.you"), result: mine)
                Divider()
                duelColumn(name: appState.partnerName, result: partner)
            }
            Text(verdictText(mine: mine, partner: partner))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if appState.api != nil {
                GameShareButton(sharing: duelSharing, shared: duelShared) {
                    shareDuelToChat(mine: mine, partner: partner)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 16)
    }

    private func shareDuelToChat(mine: WordleResult, partner: WordleResult) {
        guard let api = appState.api, !duelSharing, !duelShared else { return }
        duelSharing = true
        let myName = appState.me?.name ?? L10n.t("common.you")
        let myScore = mine.win ? "\(mine.rows)/6" : "X/6"
        let partnerScore = partner.win ? "\(partner.rows)/6" : "X/6"
        let header = L10n.t("games.wordle.duel.shareTitle", ["date": displayDate])
        let text = header + "\n"
            + "\(myName) \(myScore) · \(appState.partnerName) \(partnerScore)" + "\n"
            + verdictText(mine: mine, partner: partner)
        Task {
            do {
                _ = try await api.sendMessage(type: .text, text: text)
                duelShared = true
                SoundEngine.shared.play(.pop)
                Haptics.shared.success()
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
            duelSharing = false
        }
    }

    private func duelColumn(name: String, result: WordleResult) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            emojiGridView(result.grid)
            Text(result.win ? "\(result.rows)/6" : "X/6")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(result.win ? Color.green : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func emojiGridView(_ grid: String) -> some View {
        VStack(spacing: 2) {
            ForEach(Array(grid.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                Text(String(line))
                    .font(.footnote)
                    .kerning(1)
            }
        }
    }

    /// Duel verdict: a win always beats a loss; two wins are ranked by row
    /// count (fewer wins, equal is a tie); two losses share the blame.
    private func verdictText(mine: WordleResult, partner: WordleResult) -> String {
        if mine.win && !partner.win {
            return L10n.t("games.wordle.duel.iWin")
        }
        if partner.win && !mine.win {
            return L10n.t("games.wordle.duel.partnerWins", ["name": appState.partnerName])
        }
        if mine.win && partner.win {
            if mine.rows < partner.rows {
                return L10n.t("games.wordle.duel.iWin")
            }
            if mine.rows > partner.rows {
                return L10n.t("games.wordle.duel.partnerWins", ["name": appState.partnerName])
            }
            return L10n.t("games.wordle.duel.tie")
        }
        return L10n.t("games.wordle.duel.bothLost")
    }
}

// MARK: - Tile

/// One board tile — game content: green correct, yellow present, grey
/// absent, neutral fill while typing. Colour-blind cue in the corner.
private struct WordleTileView: View {
    let letter: String
    let mark: WordleMark?
    let revealed: Bool
    let delay: Double

    private static let size: CGFloat = 50

    var body: some View {
        ZStack {
            unrevealedFace
                .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .opacity(revealed ? 0 : 1)
            revealedFace
                .rotation3DEffect(.degrees(revealed ? 0 : -180), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .opacity(revealed ? 1 : 0)
        }
        .frame(width: Self.size, height: Self.size)
        .animation(.easeInOut(duration: 0.5).delay(delay), value: revealed)
        .accessibilityLabel(letter.isEmpty ? "" : letter)
    }

    private var unrevealedFace: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.tertiaryCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(letter.isEmpty ? Color.separator : Color.secondary, lineWidth: 1.5)
            }
            .overlay {
                Text(letter)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
            }
    }

    private var revealedFace: some View {
        let resolvedMark = mark ?? .absent
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor(resolvedMark))
            .overlay {
                Text(letter)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                // Colorblind-friendly secondary cue on top of the colors.
                if let icon = cueIcon(resolvedMark) {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(4)
                }
            }
    }

    private func fillColor(_ mark: WordleMark) -> Color {
        switch mark {
        case .correct: return Color.green
        case .present: return Color.yellow
        case .absent: return Color.secondary
        }
    }

    private func cueIcon(_ mark: WordleMark) -> String? {
        switch mark {
        case .correct: return "checkmark"
        case .present: return "arrow.left.arrow.right"
        case .absent: return nil
        }
    }
}

// MARK: - Row shake (invalid guess)

private struct WordleShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakes: Double = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = Double(animatableData) * .pi * shakes * 2
        let offset = travel * CGFloat(sin(angle))
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
