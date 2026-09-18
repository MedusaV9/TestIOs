import Foundation

/// Reusable core for "everyone answers the same multiple-choice question"
/// formats. Handles answers, deadlines (+400 ms grace), jokers (50:50, remove
/// one, second try), hints, device-shuffle (Affentheater) and the standard
/// wall/prompt/GM views. Formats embed it and add their own twist.
public struct ChoiceCore: Codable, Equatable, Sendable {
    public struct Answer: Codable, Equatable, Sendable {
        public var index: Int
        public var at: Millis
        public var secondTry: Bool
        public var wrongFirst: Int?
    }

    public var question: Question
    public var options: [String]
    public var correctIndex: Int
    public var startedAt: Millis
    public var deadline: Millis
    public var timerMs: Int
    public var answers: [PlayerId: Answer]
    public var removed: [PlayerId: [Int]]
    public var globalRemoved: [Int]
    public var secondTryOpen: [PlayerId: Millis]
    public var hintLevel: Int
    public var whisper: [PlayerId: String]
    public var deviceOrder: [PlayerId: [Int]]
    public var insiderId: PlayerId?
    public var insiderVorsprungMs: Int
    public var finishedAt: Millis?
    public var blackout: Bool
    public var frozen: [PlayerId: Bool]

    public static let graceMs = 400
    public static let secondTryWindowMs = 3000

    public init(question: Question, ctx: MinigameContext, timerMs: Int? = nil) {
        self.question = question
        options = question.choiceOptions
        correctIndex = question.correctIndex ?? 0
        startedAt = ctx.now
        let t = timerMs ?? ctx.timerMs(for: question)
        self.timerMs = t
        deadline = ctx.now + t
        answers = [:]
        removed = [:]
        globalRemoved = []
        secondTryOpen = [:]
        hintLevel = 0
        whisper = [:]
        deviceOrder = [:]
        insiderId = ctx.mods.insiderId
        insiderVorsprungMs = ctx.mods.insiderVorsprungMs
        finishedAt = nil
        blackout = ctx.mods.blackout
        frozen = [:]
        var rng = ctx.rng
        if ctx.mods.geraeteMischung {
            for p in ctx.players {
                deviceOrder[p] = rng.shuffled(Array(0..<options.count))
            }
        }
    }

    public var isTwoOption: Bool { options.count <= 2 }

    public func hasAnswered(_ p: PlayerId) -> Bool { answers[p] != nil && secondTryOpen[p] == nil }

    public func isCorrect(_ p: PlayerId) -> Bool? {
        guard let a = answers[p] else { return nil }
        return a.index == correctIndex
    }

    /// Question visible to this player yet? (insider sees earlier; others wait
    /// `insiderVorsprungMs` — implemented by shifting the effective start).
    public func visible(for p: PlayerId, now: Millis) -> Bool {
        guard let insider = insiderId, insider != p else { return true }
        return now >= startedAt + insiderVorsprungMs
    }

    public mutating func answer(_ p: PlayerId, index: Int, now: Millis, allowLate: Bool = true) -> Bool {
        guard index >= 0, index < options.count else { return false }
        guard now <= deadline + Self.graceMs || !allowLate else { return false }
        if now > deadline + Self.graceMs { return false }
        if let open = secondTryOpen[p] {
            // Second try after a wrong first answer (Rückgaberecht).
            guard now <= open + Self.secondTryWindowMs + Self.graceMs else { return false }
            guard let first = answers[p], index != first.index else { return false }
            answers[p] = Answer(index: index, at: now, secondTry: true, wrongFirst: first.index)
            secondTryOpen[p] = nil
            return true
        }
        guard answers[p] == nil else { return false }
        if (removed[p] ?? []).contains(index) || globalRemoved.contains(index) { return false }
        answers[p] = Answer(index: index, at: now, secondTry: false, wrongFirst: nil)
        return true
    }

    /// Remove `count` wrong options for one player (50:50) or globally.
    public mutating func removeWrong(for p: PlayerId?, count: Int, rng: inout SeededRandom) {
        let already = p.map { removed[$0] ?? [] } ?? globalRemoved
        var wrong = options.indices.filter { $0 != correctIndex && !already.contains($0) && !globalRemoved.contains($0) }
        wrong = rng.shuffled(wrong)
        let take = Array(wrong.prefix(count))
        if let p = p {
            removed[p, default: []].append(contentsOf: take)
        } else {
            globalRemoved.append(contentsOf: take)
        }
    }

    /// Open the second-try window for a player whose first answer was wrong.
    public mutating func openSecondTry(for p: PlayerId, now: Millis) -> Bool {
        guard let a = answers[p], a.index != correctIndex, !a.secondTry else { return false }
        secondTryOpen[p] = now
        removed[p, default: []].append(a.index)
        // Extend the deadline so the window is usable.
        deadline = max(deadline, now + Self.secondTryWindowMs)
        return true
    }

    public mutating func extend(ms: Int) { deadline += ms; timerMs += ms }
    public mutating func shift(ms: Int) { deadline += ms; startedAt += ms }

    public func allAnswered(connected: Set<PlayerId>, players: [PlayerId]) -> Bool {
        let active = players.filter { connected.contains($0) && !(frozen[$0] ?? false) }
        if active.isEmpty { return true }
        return active.allSatisfy { hasAnswered($0) }
    }

    /// Finished when everyone answered or the deadline (+grace) passed.
    public func finished(now: Millis, ctx: MinigameContext) -> Bool {
        if finishedAt != nil { return true }
        if now > deadline + Self.graceMs { return true }
        return allAnswered(connected: ctx.connected, players: ctx.players) && secondTryOpen.isEmpty
    }

    public func answeredAfterMs(_ p: PlayerId) -> Int? {
        answers[p].map { max(0, $0.at - startedAt) }
    }

    // MARK: Views

    public func options(for p: PlayerId?) -> [ChoiceOption] {
        let order = p.flatMap { deviceOrder[$0] } ?? Array(options.indices)
        return order.map { i in
            ChoiceOption(id: i, text: options[i], removed: (p.map { removed[$0] ?? [] } ?? []).contains(i) || globalRemoved.contains(i))
        }
    }

    public func wall(ctx: MinigameContext, revealed: Bool, extraAnswered: [PlayerId] = []) -> QuestionWall {
        let counts = revealed ? Dictionary(grouping: answers.values, by: { $0.index }).mapValues { $0.count } : [:]
        var opts = options(for: nil)
        for i in opts.indices { opts[i].count = counts[opts[i].id] }
        let kat = ctx.catalog.categories.first { $0.id == question.kat }
        return QuestionWall(
            text: question.displayText,
            kategorie: question.kat,
            kategorieName: kat?.name ?? question.kat,
            kategorieEmoji: kat?.emoji ?? "❓",
            schwierigkeit: question.schw,
            wert: Int(Double(question.value) * ctx.mods.wertFaktor),
            options: blackout && !revealed ? nil : opts,
            answered: Array(answers.keys.filter { hasAnswered($0) }) + extraAnswered,
            deadline: revealed ? nil : deadline,
            timerMs: timerMs,
            revealed: revealed,
            correctIndex: revealed ? correctIndex : nil,
            answersByPlayer: revealed ? answers.mapValues { $0.index } : [:],
            image: question.bild,
            pixelLevel: nil,
            erklaerung: revealed ? question.erkl : nil,
            tipp: hintLevel > 0 && hintLevel <= question.tipps.count ? question.tipps[hintLevel - 1] : nil,
            nummer: ctx.fragenNummer,
            gesamt: ctx.fragenGesamt,
            blackout: blackout && !revealed,
            goldenFor: Array(ctx.mods.goldeneBanane)
        )
    }

    public func prompt(for p: PlayerId, ctx: MinigameContext, revealed: Bool, delta: Int? = nil, hint: String? = nil) -> PlayerPrompt {
        if revealed {
            let correct = isCorrect(p)
            let title = correct == true ? "RICHTIG!" : (correct == false ? "FALSCH!" : "ZU LANGSAM")
            return .reveal(title: title, correct: correct, delta: delta ?? 0,
                           detail: "Richtig war: \(options[correctIndex])", streak: 0, speedBonus: nil)
        }
        guard visible(for: p, now: ctx.now) else {
            return .idle(title: "Gleich geht's los …", subtitle: "Jemand hat einen Insider-Tipp …")
        }
        let chosen = answers[p]?.index
        return .choice(question: question.displayText, options: options(for: p), chosen: chosen, deadline: deadline,
                       secondTry: secondTryOpen[p] != nil,
                       hint: hint ?? whisper[p] ?? (hintLevel > 0 && hintLevel <= question.tipps.count ? question.tipps[hintLevel - 1] : nil))
    }

    public func gmInfo(ctx: MinigameContext) -> (question: GmQuestionInfo?, answers: [PlayerId: String]) {
        let info = GmQuestionInfo(id: question.id, text: question.text, kategorie: ctx.catalog.categoryName(question.kat),
                                  schwierigkeit: question.schw, korrekt: options.indices.contains(correctIndex) ? options[correctIndex] : "?",
                                  erklaerung: question.erkl, tipps: question.tipps, typ: question.typ)
        var ans: [PlayerId: String] = [:]
        for (p, a) in answers {
            let t = options.indices.contains(a.index) ? options[a.index] : "?"
            ans[p] = "\(t) (\(String(format: "%.1f", Double(max(0, a.at - startedAt)) / 1000)) s)\(a.index == correctIndex ? " ✅" : " ❌")"
        }
        return (info, ans)
    }

    /// Standard outcomes with speed bonus for question formats.
    public func standardOutcomes(ctx: MinigameContext, speed: Bool) -> [PlayerId: Outcome] {
        var out: [PlayerId: Outcome] = [:]
        for p in ctx.players {
            guard let a = answers[p] else {
                out[p] = Outcome(correct: nil, timerMs: timerMs)
                continue
            }
            let after = max(0, a.at - startedAt)
            let correct = a.index == correctIndex
            let bonus = speed && correct && !a.secondTry ? Money.speedBonus(value: question.value, answeredAfterMs: after, timerMs: timerMs) : 0
            out[p] = Outcome(correct: correct, answeredAfterMs: after, timerMs: timerMs, speedBonus: bonus, countsForStreak: true,
                             detail: a.secondTry ? "2. Versuch" : nil)
        }
        return out
    }

    /// Standard scores: base value (+speed) for correct answers, second try pays 50 %.
    public func standardScores(ctx: MinigameContext, speed: Bool, lossFree: Bool = true) -> [PlayerId: Int] {
        var s: [PlayerId: Int] = [:]
        let wert = Int(Double(question.value) * ctx.mods.wertFaktor)
        for p in ctx.players {
            guard let a = answers[p] else { s[p] = 0; continue }
            if a.index == correctIndex {
                let after = max(0, a.at - startedAt)
                var win = wert + (speed ? Money.speedBonus(value: wert, answeredAfterMs: after, timerMs: timerMs) : 0)
                if a.secondTry { win = win / 2 }
                s[p] = win
            } else {
                s[p] = 0
            }
        }
        return s
    }

    /// Handle joker-driven GM actions common to all MC formats.
    public mutating func applyGm(_ action: GmMinigameAction, ctx: inout MinigameContext) {
        switch action {
        case .timerExtend(let ms): extend(ms: ms)
        case .timerShift(let ms): shift(ms: ms)
        case .forceFinish: finishedAt = ctx.now
        case .removeOption(let p): removeWrong(for: p, count: 1, rng: &ctx.rng)
        case .fiftyFifty(let p): removeWrong(for: p, count: max(0, options.count - 2), rng: &ctx.rng)
        case .secondTry(let p): _ = openSecondTry(for: p, now: ctx.now)
        case .skipQuestion: finishedAt = ctx.now
        }
    }
}

/// Helpers for question formats.
public enum FormatHelpers {
    /// Pick the questions of the round that fit a content kind (fallback to any).
    public static func fitting(_ questions: [Question], kind: ContentKind) -> [Question] {
        switch kind {
        case .fragen(let types):
            let fit = questions.filter { types.contains($0.typ) }
            return fit.isEmpty ? questions : fit
        default: return questions
        }
    }

    public static func first(_ questions: [Question], kind: ContentKind) -> Question {
        fitting(questions, kind: kind).first ?? questions.first ?? Question.fallback(0)
    }

    public static func places(_ values: [PlayerId: Int]) -> [PlayerId: Int] {
        let sorted = values.sorted { $0.value > $1.value }
        var places: [PlayerId: Int] = [:]
        var lastValue: Int?
        var lastPlace = 0
        for (i, (p, v)) in sorted.enumerated() {
            if v == lastValue { places[p] = lastPlace } else { lastPlace = i + 1; places[p] = lastPlace; lastValue = v }
        }
        return places
    }
}
