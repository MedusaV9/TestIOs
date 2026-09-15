import AVFoundation
import Foundation

/// v2.0 sound engine. Every sound stays ORIGINAL, procedurally synthesized —
/// no third-party audio assets (see docs/CREDITS.md for the rationale).
/// What changed vs 1.x: stereo voices with cent-detune (warmth), real
/// attack/decay envelopes, inharmonic bell spectra instead of plain sines,
/// a feedback-echo tail for the dreamy space, and soft-knee saturation
/// instead of a hard clip. Volumes are soft by default and adjustable per
/// category in Settings. Mixes politely with the user's music.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "sooodreamy.soundsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sooodreamy.soundsEnabled") }
    }

    // MARK: Categories (per-category volume, v2.0)

    enum Category: String, CaseIterable, Identifiable {
        case moments, chat, games, ui

        var id: String { rawValue }

        /// "Soft by default" — tuned so nothing ever startles.
        var defaultVolume: Double {
            switch self {
            case .moments: return 0.65
            case .chat: return 0.5
            case .games: return 0.6
            case .ui: return 0.35
            }
        }

        var titleKey: String { "settings.soundvol.\(rawValue)" }

        var icon: String {
            switch self {
            case .moments: return "heart.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .games: return "gamecontroller.fill"
            case .ui: return "wand.and.stars"
            }
        }

        /// Representative sound for the volume-slider preview.
        var previewSound: Sound {
            switch self {
            case .moments: return .heartbeat
            case .chat: return .pop
            case .games: return .tada
            case .ui: return .chime
            }
        }
    }

    static func volume(for category: Category) -> Double {
        UserDefaults.standard.object(forKey: "sooodreamy.soundVolume.\(category.rawValue)") as? Double
            ?? category.defaultVolume
    }

    static func setVolume(_ value: Double, for category: Category) {
        UserDefaults.standard.set(min(1, max(0, value)), forKey: "sooodreamy.soundVolume.\(category.rawValue)")
    }

    // MARK: Sounds

    enum Sound: CaseIterable {
        case heartbeat, chime, pop, whoosh, tada, sparkle
        // v2.0 additions
        case click, success, letterSeal, unlock, win, lose, vibe

        var category: Category {
            switch self {
            case .heartbeat, .sparkle, .whoosh, .vibe: return .moments
            case .pop, .letterSeal: return .chat
            case .tada, .win, .lose: return .games
            case .chime, .click, .success, .unlock: return .ui
            }
        }
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private var started = false

    private init() {}

    func prepare() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        engine.mainMixerNode.outputVolume = 0.9
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func play(_ sound: Sound) {
        guard Self.enabled else { return }
        prepare()
        guard started else { return }
        if !engine.isRunning {
            try? engine.start()
            guard engine.isRunning else { return }
        }
        let buffer = buffers[sound] ?? Self.makeBuffer(sound, format: format)
        buffers[sound] = buffer
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = Float(Self.volume(for: sound.category))
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    func play(for kind: TouchKind) {
        switch kind {
        case .heartbeat: play(.heartbeat)
        case .kiss: play(.pop)
        case .hug: play(.whoosh)
        case .missyou: play(.sparkle)
        case .tickle: play(.sparkle)
        case .thinking: play(.chime)
        }
    }

    // MARK: Synthesis

    /// Renders one sound into a fresh stereo buffer. All numbers below are
    /// sound design, tuned by ear-math: frequencies are real notes, bell
    /// spectra use inharmonic partial ratios (~tuned percussion), and every
    /// envelope has a real attack so nothing clicks.
    private static func makeBuffer(_ sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let duration: Double
        switch sound {
        case .heartbeat: duration = 1.4
        case .chime: duration = 1.7
        case .pop: duration = 0.22
        case .whoosh: duration = 0.75
        case .tada: duration = 1.7
        case .sparkle: duration = 0.9
        case .click: duration = 0.08
        case .success: duration = 0.7
        case .letterSeal: duration = 0.7
        case .unlock: duration = 0.8
        case .win: duration = 2.0
        case .lose: duration = 1.0
        case .vibe: duration = 1.3
        }
        let frames = Int(duration * sr)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)

        /// Attack-then-exponential-decay envelope.
        func env(_ t: Double, attack: Double, decay: Double) -> Double {
            t < attack ? t / max(attack, 1e-4) : exp(-(t - attack) * decay)
        }

        /// Layered partial voice, detuned between channels for width.
        /// `partials`: (ratio, relative amp); higher partials decay faster.
        func tone(start: Double, freq: Double, length: Double, amp: Double,
                  attack: Double = 0.006, decay: Double = 5,
                  partials: [(Double, Double)] = [(1, 1)],
                  detuneCents: Double = 3, pan: Double = 0) {
            let s0 = Int(start * sr)
            let n = Int(length * sr)
            let lGain = sqrt(0.5 * (1 - pan))
            let rGain = sqrt(0.5 * (1 + pan))
            let detune = pow(2, detuneCents / 1200)
            for i in 0..<n {
                let idx = s0 + i
                guard idx < frames else { break }
                let t = Double(i) / sr
                var vL = 0.0, vR = 0.0
                for (p, (ratio, pAmp)) in partials.enumerated() {
                    let pDecay = decay * (1 + 0.55 * Double(p))     // brights die first
                    let e = env(t, attack: attack, decay: pDecay)
                    vL += pAmp * e * sin(2 * .pi * freq * ratio / detune * t)
                    vR += pAmp * e * sin(2 * .pi * freq * ratio * detune * t)
                }
                left[idx] += Float(amp * vL * lGain * 2)
                right[idx] += Float(amp * vR * rGain * 2)
            }
        }

        /// Dreamy glass bell — inharmonic spectrum of struck idiophones.
        func bell(start: Double, freq: Double, amp: Double, decay: Double = 5,
                  detuneCents: Double = 3, pan: Double = 0) {
            tone(start: start, freq: freq, length: min(2.2, duration - start), amp: amp,
                 attack: 0.004, decay: decay,
                 partials: [(1, 1), (2.0, 0.5), (2.99, 0.28), (4.16, 0.16), (5.43, 0.08)],
                 detuneCents: detuneCents, pan: pan)
        }

        /// Pitch glide (pops, thumps): freq sweeps `from`→`to` over `length`.
        func glide(start: Double, from: Double, to: Double, length: Double,
                   amp: Double, decay: Double) {
            let s0 = Int(start * sr)
            let n = Int(length * sr)
            var phase = 0.0
            for i in 0..<n {
                let idx = s0 + i
                guard idx < frames else { break }
                let t = Double(i) / sr
                let x = t / length
                let f = from + (to - from) * x
                phase += 2 * .pi * f / sr
                let v = env(t, attack: 0.002, decay: decay) * sin(phase)
                left[idx] += Float(amp * v)
                right[idx] += Float(amp * v)
            }
        }

        /// Filtered noise with an animated low-pass (opening → closing) and
        /// decorrelated channels — air, paper, waves.
        func noise(start: Double, length: Double, amp: Double,
                   lpFrom: Double = 0.04, lpPeak: Double = 0.22, lpTo: Double = 0.04) {
            let s0 = Int(start * sr)
            let n = Int(length * sr)
            var stateL: UInt64 = 0x9E3779B97F4A7C15
            var stateR: UInt64 = 0xD1B54A32D192ED03
            var lpL = 0.0, lpR = 0.0
            for i in 0..<n {
                let idx = s0 + i
                guard idx < frames else { break }
                let x = Double(i) / Double(n)
                // low-pass coefficient sweeps: closed → open → closed
                let k = x < 0.4 ? lpFrom + (lpPeak - lpFrom) * (x / 0.4)
                                : lpPeak + (lpTo - lpPeak) * ((x - 0.4) / 0.6)
                stateL = stateL &* 6364136223846793005 &+ 1442695040888963407
                stateR = stateR &* 6364136223846793005 &+ 1442695040888963407
                let wL = (Double((stateL >> 33) & 0xFFFFFF) / Double(0xFFFFFF)) * 2 - 1
                let wR = (Double((stateR >> 33) & 0xFFFFFF) / Double(0xFFFFFF)) * 2 - 1
                lpL += k * (wL - lpL)
                lpR += k * (wR - lpR)
                let e = sin(.pi * x)
                left[idx] += Float(amp * e * lpL)
                right[idx] += Float(amp * e * lpR)
            }
        }

        /// Feedback delay over the whole buffer — the "dreamy" tail.
        func echo(delay: Double, feedback: Float) {
            let d = Int(delay * sr)
            guard d > 0 else { return }
            for i in d..<frames {
                left[i] += feedback * left[i - d]
                right[i] += feedback * right[i - d]
            }
        }

        switch sound {
        case .heartbeat:
            // Two warm lub-dubs: pitch-dropping thumps + a felt "skin" tap.
            for beat in [0.0, 0.72] {
                glide(start: beat, from: 64, to: 45, length: 0.20, amp: 0.85, decay: 15)
                noise(start: beat, length: 0.05, amp: 0.10, lpFrom: 0.03, lpPeak: 0.08, lpTo: 0.02)
                glide(start: beat + 0.17, from: 52, to: 40, length: 0.18, amp: 0.55, decay: 17)
            }

        case .chime:
            // E5 glass bell with a fifth shimmering in — the app's signature.
            bell(start: 0.00, freq: 659.25, amp: 0.20, decay: 4.5, detuneCents: 3, pan: -0.15)
            bell(start: 0.12, freq: 987.77, amp: 0.13, decay: 5.0, detuneCents: 4, pan: 0.2)
            echo(delay: 0.26, feedback: 0.32)

        case .pop:
            // Bubble kiss: fast pitch drop + a breath of air.
            glide(start: 0, from: 640, to: 90, length: 0.06, amp: 0.7, decay: 38)
            noise(start: 0, length: 0.03, amp: 0.08, lpFrom: 0.3, lpPeak: 0.4, lpTo: 0.2)

        case .whoosh:
            // A hug of air with a low warm swell underneath.
            noise(start: 0, length: 0.75, amp: 0.32)
            tone(start: 0.05, freq: 88, length: 0.6, amp: 0.10, attack: 0.2, decay: 4,
                 partials: [(1, 1), (2, 0.2)], detuneCents: 5)

        case .tada:
            // Rising C-major bell arpeggio with fairy dust on top.
            for (i, f) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
                bell(start: Double(i) * 0.08, freq: f, amp: 0.14, decay: 4,
                     detuneCents: 3, pan: Double(i) * 0.12 - 0.18)
            }
            bell(start: 0.42, freq: 2093.0, amp: 0.05, decay: 8, pan: 0.3)
            bell(start: 0.52, freq: 2637.0, amp: 0.04, decay: 9, pan: -0.3)
            echo(delay: 0.24, feedback: 0.3)

        case .sparkle:
            // Three tiny glass stars, ascending.
            bell(start: 0.00, freq: 1318.5, amp: 0.10, decay: 8, pan: -0.25)
            bell(start: 0.09, freq: 1760.0, amp: 0.09, decay: 8, pan: 0.25)
            bell(start: 0.18, freq: 2217.5, amp: 0.08, decay: 7, pan: 0)
            echo(delay: 0.13, feedback: 0.28)

        case .click:
            // Barely-there UI tick.
            glide(start: 0, from: 1900, to: 1400, length: 0.02, amp: 0.16, decay: 90)

        case .success:
            // Gentle two-note confirm (E5 → B5).
            tone(start: 0.00, freq: 659.25, length: 0.35, amp: 0.14, decay: 7,
                 partials: [(1, 1), (2, 0.3)])
            tone(start: 0.11, freq: 987.77, length: 0.45, amp: 0.13, decay: 6,
                 partials: [(1, 1), (2, 0.25)])

        case .letterSeal:
            // Paper slide + wax press + a tiny bell kiss.
            noise(start: 0, length: 0.16, amp: 0.16, lpFrom: 0.12, lpPeak: 0.3, lpTo: 0.05)
            glide(start: 0.14, from: 150, to: 70, length: 0.12, amp: 0.4, decay: 22)
            bell(start: 0.3, freq: 1567.98, amp: 0.06, decay: 8)

        case .unlock:
            // Vault open: two quick metallic bells, upward (G5 → D6).
            bell(start: 0.00, freq: 783.99, amp: 0.12, decay: 7, detuneCents: 5)
            bell(start: 0.10, freq: 1174.66, amp: 0.11, decay: 6, detuneCents: 5)
            echo(delay: 0.15, feedback: 0.22)

        case .win:
            // A little fanfare: G-major lift with shimmer rain.
            for (i, f) in [392.0, 493.88, 587.33, 783.99].enumerated() {
                bell(start: Double(i) * 0.1, freq: f, amp: 0.15, decay: 3.4,
                     detuneCents: 4, pan: Double(i) * 0.12 - 0.18)
            }
            for (i, f) in [1567.98, 1975.53, 2349.32].enumerated() {
                bell(start: 0.55 + Double(i) * 0.07, freq: f, amp: 0.05, decay: 7,
                     pan: Double(i) * 0.25 - 0.25)
            }
            echo(delay: 0.27, feedback: 0.32)

        case .lose:
            // Sympathetic descending sigh (A4 → F4) — soft, never mocking.
            tone(start: 0.00, freq: 440.0, length: 0.4, amp: 0.12, attack: 0.02, decay: 6,
                 partials: [(1, 1), (2, 0.2)])
            tone(start: 0.22, freq: 349.23, length: 0.6, amp: 0.11, attack: 0.02, decay: 5,
                 partials: [(1, 1), (2, 0.15)])

        case .vibe:
            // Warm pad swell for incoming custom vibrations: detuned A-minor
            // triad breathing in and out.
            tone(start: 0, freq: 220.0, length: 1.25, amp: 0.10, attack: 0.3, decay: 3.2,
                 partials: [(1, 1), (2, 0.3)], detuneCents: 7, pan: -0.1)
            tone(start: 0.05, freq: 329.63, length: 1.2, amp: 0.08, attack: 0.32, decay: 3.2,
                 partials: [(1, 1), (2, 0.25)], detuneCents: 6, pan: 0.15)
            tone(start: 0.1, freq: 440.0, length: 1.1, amp: 0.07, attack: 0.35, decay: 3.4,
                 partials: [(1, 1)], detuneCents: 8, pan: 0)
            bell(start: 0.5, freq: 1760.0, amp: 0.04, decay: 8, pan: 0.2)
            echo(delay: 0.3, feedback: 0.25)
        }

        // Soft-knee saturation (analog-ish, no hard clipping artifacts).
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let outL = buffer.floatChannelData![0]
        let outR = buffer.floatChannelData![1]
        let norm = Float(tanh(1.6))
        for i in 0..<frames {
            outL[i] = tanhf(1.6 * left[i]) / norm * 0.92
            outR[i] = tanhf(1.6 * right[i]) / norm * 0.92
        }
        return buffer
    }
}
