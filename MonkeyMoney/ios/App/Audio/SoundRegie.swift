import Foundation

/// The show's sound director. It watches the stream of stage views and turns
/// *transitions* into a dramaturgy — never "a sound per state update":
/// · phase stingers (page flip on a new question, card slide, wheel stinger)
/// · the reveal three-beat: zap + drum roll over a silenced bed → real silence
///   → richtig/falsch, applause tier and money clink graded by the payout
/// · the ceremony: long drum roll → silence → fanfare + cheers, then the bed
/// · the wheel's running light (one wooden tick per step) and the landing bell
/// · moment effects (joker, join, punishments) exactly once per moment.
final class SoundRegie {
    static let revealTensionMs = 1750
    static let revealSilenceMs = 650
    static var revealFanfareMs: Int { revealTensionMs + revealSilenceMs }
    static let ceremonyRollMs = 2500
    static let ceremonySilenceMs = 800

    private let audio: AudioManager
    private var lastPhase: Phase?
    private var lastQuestionKey: String?
    private var lastRevealKey: String?
    private var lastWallRevealed = false
    private var lastBombPasses = 0
    private var lastExploded: PlayerId?
    private var lastBankedTotal = 0
    private var lastMomentId = 0
    private var first = true
    private var scheduled: [DispatchWorkItem] = []
    private var bedHoldUntil: Date?
    private var chaseTimer: Timer?
    private var lastChaseStep = -1
    private var chaseWheel: WheelView?

    init(audio: AudioManager) { self.audio = audio }

    /// Forget everything (new show) — the next view is treated as a reconnect.
    func reset() {
        cancelScheduled()
        stopChase()
        lastPhase = nil
        lastQuestionKey = nil
        lastRevealKey = nil
        lastWallRevealed = false
        lastBombPasses = 0
        lastBankedTotal = 0
        bedHoldUntil = nil
        first = true
    }

    // MARK: Update

    func update(_ view: StageView, musicOn: Bool) {
        let phaseChanged = view.phase != lastPhase
        if phaseChanged {
            // A GM skip must never drop a late fanfare into the next phase.
            cancelScheduled()
            if view.phase != .rad { stopChase() }
            if view.phase != .aufloesung { audio.duck(to: 1) }
        }
        updateBed(view, musicOn: musicOn, phaseChanged: phaseChanged)
        if phaseChanged, !first { phaseStinger(view) }
        switch view.scene {
        case .frage(let wall, let extra, let minigameId, _, let title):
            questionBeats(wall: wall, extra: extra, minigameId: minigameId, title: title)
        case .aufloesung(let wall, let extra, let deltas, let minigameId, let kind):
            revealBeat(wall: wall, extra: extra, deltas: deltas, minigameId: minigameId, kind: kind)
        case .rad(let wheel):
            wheelBeats(wheel)
        default:
            break
        }
        momentEffects(view)
        lastPhase = view.phase
        first = false
    }

    // MARK: Music bed

    private func updateBed(_ view: StageView, musicOn: Bool, phaseChanged: Bool) {
        let bed = musicOn ? view.audio?.music : nil
        if view.phase == .siegerehrung, phaseChanged, !first {
            // Ceremony: silence under the drum roll, the bed enters with the fanfare.
            audio.stopMusic()
            bedHoldUntil = Date().addingTimeInterval(Double(Self.ceremonyRollMs + Self.ceremonySilenceMs) / 1000)
            audio.playMusic(bed, afterMs: Self.ceremonyRollMs + Self.ceremonySilenceMs)
            return
        }
        if let hold = bedHoldUntil, Date() < hold { return }
        bedHoldUntil = nil
        audio.playMusic(bed)
    }

    // MARK: Phase stingers

    private func phaseStinger(_ view: StageView) {
        switch view.phase {
        case .intro:
            audio.sfx("jingle_hit")
        case .kategorieWahl:
            audio.sfx("karten_mischen", gain: 0.8)
        case .erklaerkarte, .highlights:
            audio.sfxVariant("karte", ["karte1", "karte2", "karte3"], gain: 0.9)
        case .zwischenstand, .halbzeit:
            audio.duck(to: 0.45, forMs: 1600)
            audio.sfx("applaus_kurz", gain: 0.8)
        case .rad:
            audio.duck(to: 0.6, forMs: 1200)
            audio.sfx("dreiklang")
        case .siegerehrung:
            audio.sfx("trommelwirbel_lang")
            schedule(afterMs: Self.ceremonyRollMs + Self.ceremonySilenceMs) { [audio] in
                audio.sfx("jingle_sax")
                audio.sfx("applaus_jubel")
                audio.sfx("muenzregen", gain: 0.8)
            }
        case .brettspiel:
            audio.sfx("karten_mischen", gain: 0.6)
        default:
            break
        }
    }

    // MARK: Question phase

    private func questionBeats(wall: QuestionWall?, extra: StageExtra, minigameId: String, title: String) {
        let key = "\(minigameId)|\(wall?.nummer ?? 0)|\(wall?.text.prefix(24) ?? "")"
        if key != lastQuestionKey {
            lastQuestionKey = key
            lastWallRevealed = wall?.revealed ?? false
            if !first {
                audio.duck(to: 0.45, forMs: 900)
                audio.sfx("frage_ein", gain: 0.9)
            }
        }
        // Rapid-fire formats reveal inside the question phase (Affenbank beat, bomb pass).
        let revealedNow = wall?.revealed ?? false
        if revealedNow, !lastWallRevealed, !first {
            switch extra {
            case .bankPot(_, _, _, _, _, let verdict, _, _, _, _, _):
                audio.sfx(verdict == "waechst" ? "richtig" : (verdict == "haelt" ? "impact_soft" : "falsch"), gain: 0.8)
            case .bomb(_, _, let passes, _, _) where passes <= lastBombPasses:
                audio.sfx("falsch", gain: 0.8)
            default:
                break
            }
        }
        lastWallRevealed = revealedNow
        switch extra {
        case .bomb(_, _, let passes, let exploded, _):
            // A pass is the whoosh of the banana flying on; the explosion splatters.
            if passes > lastBombPasses, !first { audio.sfx("klau", gain: 0.7) }
            lastBombPasses = passes
            if exploded != nil, lastExploded == nil, !first {
                audio.sfx("slime")
                audio.sfx("impact_soft", gain: 0.9)
                audio.sfx("dreiklang_tief", gain: 0.7)
            }
            lastExploded = exploded
        case .bankPot(_, _, _, let banked, _, _, _, _, _, _, let gongFor):
            let total = banked.values.reduce(0, +)
            if total > lastBankedTotal, !first { audio.sfx(gongFor.isEmpty ? "kaching" : "impact_glocke") }
            lastBankedTotal = total
        default:
            lastExploded = nil
        }
    }

    // MARK: Reveal three-beat

    private func revealBeat(wall: QuestionWall?, extra: StageExtra, deltas: [PlayerId: Int], minigameId: String, kind: SectionKind) {
        let key = "\(minigameId)|\(wall?.nummer ?? 0)|\(wall?.text.prefix(24) ?? "")|\(deltas.count)"
        guard key != lastRevealKey else { return }
        lastRevealKey = key
        guard !first else { return }
        // Beat 1: paparazzi zap + tension over a silenced bed.
        audio.duck(to: 0)
        audio.sfx("reveal", gain: 0.8)
        audio.sfxVariant("spannung", ["trommelwirbel", "riser"], gain: 0.9)
        // Beat 2: real silence. Beat 3: the fanfare, graded by the outcome.
        let correct: Int
        if let w = wall, let ci = w.correctIndex, w.options != nil {
            correct = w.answersByPlayer.values.filter { $0 == ci }.count
        } else {
            correct = deltas.values.filter { $0 > 0 }.count
        }
        let maxDelta = deltas.values.max() ?? 0
        let everyone = !deltas.isEmpty && correct >= deltas.count
        schedule(afterMs: Self.revealFanfareMs) { [audio] in
            if correct == 0 {
                audio.sfx("falsch")
                audio.sfx("dreiklang_tief", gain: 0.6)
            } else {
                audio.sfx("richtig")
                if kind == .jackpot || everyone || maxDelta >= 750 { audio.sfx("applaus_gross", gain: 0.9) }
                else if correct > 1 { audio.sfx("applaus_mittel", gain: 0.85) }
                else { audio.sfx("applaus_kurz", gain: 0.8) }
                if maxDelta >= 750 { audio.sfx("muenzregen") }
                else if maxDelta >= 250 { audio.sfx("kaching") }
                else if maxDelta > 0 { audio.sfxVariant("muenze", ["muenze1", "muenze2", "muenze3"], gain: 0.9) }
            }
            // Bed comes back softly under the explanation.
            audio.duck(to: 0.3)
        }
    }

    // MARK: Wheel

    private func wheelBeats(_ wheel: WheelView) {
        chaseWheel = wheel
        if wheel.subphase == "dreht" {
            startChase()
        } else {
            stopChase()
        }
    }

    private func startChase() {
        guard chaseTimer == nil else { return }
        lastChaseStep = -1
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.chaseTick() }
        RunLoop.main.add(t, forMode: .common)
        chaseTimer = t
    }

    private func stopChase() {
        chaseTimer?.invalidate()
        chaseTimer = nil
    }

    private func chaseTick() {
        guard let w = chaseWheel, let start = w.spinStartedAt, let result = w.resultIndex, !w.face.isEmpty else { return }
        let elapsed = ServerClock.now() - start
        let total = Wheel.chaseSteps(segments: w.face.count, resultIndex: result)
        let step = Wheel.chaseStep(elapsedMs: elapsed, durationMs: w.spinDurationMs, segments: w.face.count, resultIndex: result)
        guard step != lastChaseStep else { return }
        lastChaseStep = step
        if step >= total {
            audio.sfx("impact_glocke")
            if w.face.indices.contains(result), w.face[result].klasse == .gold { audio.sfx("jingle_hit") }
            stopChase()
        } else {
            audio.sfx("impact_holz", rateLimitMs: 45, gain: 0.65)
        }
    }

    // MARK: Moments

    private func momentEffects(_ view: StageView) {
        let fresh = view.moments.filter { $0.id > lastMomentId }
        if let last = fresh.last { lastMomentId = last.id }
        guard !first else { return }
        for m in fresh {
            switch m.art {
            case "join": audio.sfx("drop", gain: 0.9)
            case "joker": audio.sfx("joker")
            case "sound": audio.sfx(m.text)
            case "streik", "pranger", "strafe", "geier": audio.sfx("falsch", gain: 0.8)
            case "rueckenwind", "bailout", "boost", "kopfgeld", "gong": audio.sfx("powerup")
            case "steuer", "affe", "shot", "kompliment", "umarmung", "tausch": audio.sfxVariant("muenze", ["muenze1", "muenze2", "muenze3"], gain: 0.8)
            case "ultrahard": audio.sfx("riser", gain: 0.8)
            case "shake", "finale": audio.sfx("trommelwirbel", gain: 0.8)
            case "jackpot" where view.phase != .aufloesung: audio.sfx("kaching")
            default: break
            }
        }
    }

    // MARK: Scheduling

    private func schedule(afterMs ms: Int, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(ms) / 1000, execute: item)
    }

    private func cancelScheduled() {
        for s in scheduled { s.cancel() }
        scheduled = []
    }
}
