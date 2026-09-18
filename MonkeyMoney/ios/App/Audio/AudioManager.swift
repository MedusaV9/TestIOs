import Foundation
import AVFoundation
import Combine

/// Music beds (crossfaded loops) and sound effects for the stage. Files live
/// in the bundle folders Audio/Music, Audio/SFX, Audio/Songs, Audio/Beds.
final class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    @Published var musicEnabled = true { didSet { if !musicEnabled { stopMusic() } } }
    @Published var sfxEnabled = true
    @Published var volume: Float = 0.8 { didSet { current?.volume = volume * duckFactor } }

    private var current: AVAudioPlayer?
    private var currentCue: String?
    private var fading: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []
    private var snippetPlayer: AVAudioPlayer?
    private var lastSfxAt: [String: Date] = [:]
    private var duckFactor: Float = 1
    private var duckTimer: Timer?
    private var pendingMusic: DispatchWorkItem?
    private var roundRobin: [String: Int] = [:]

    override init() {
        super.init()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    private func url(_ folder: String, _ name: String, ext: String = "m4a") -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio/\(folder)") ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    /// Switch the music bed (no-op when the same cue is already playing).
    func playMusic(_ cue: String?, loop: Bool = true) {
        pendingMusic?.cancel()
        pendingMusic = nil
        guard musicEnabled else { return }
        guard let cue = cue else { stopMusic(); return }
        if cue == currentCue, current?.isPlaying == true { return }
        guard let u = url("Music", cue), let p = try? AVAudioPlayer(contentsOf: u) else { return }
        p.numberOfLoops = loop ? -1 : 0
        p.volume = 0
        p.prepareToPlay()
        p.play()
        let old = current
        current = p
        currentCue = cue
        crossfade(from: old, to: p)
    }

    /// Start a bed after a beat (e.g. the ceremony fanfare) — cancelled by the next `playMusic`.
    func playMusic(_ cue: String?, afterMs delay: Int) {
        pendingMusic?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.playMusic(cue) }
        pendingMusic = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay) / 1000, execute: item)
    }

    private func crossfade(from old: AVAudioPlayer?, to new: AVAudioPlayer) {
        fading?.stop()
        fading = old
        var step = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            step += 1
            let f = Float(min(1, Double(step) / 20))
            new.volume = self.volume * self.duckFactor * f
            old?.volume = self.volume * self.duckFactor * (1 - f)
            if step >= 20 { t.invalidate(); old?.stop(); if self.fading === old { self.fading = nil } }
        }
    }

    func stopMusic() {
        pendingMusic?.cancel()
        pendingMusic = nil
        current?.stop()
        current = nil
        currentCue = nil
    }

    /// Lower the bed to `factor` (0 = real silence); restores after `ms` when given.
    func duck(to factor: Float, forMs ms: Int? = nil) {
        duckTimer?.invalidate()
        duckFactor = max(0, min(1, factor))
        current?.volume = volume * duckFactor
        if let ms = ms {
            duckTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000, repeats: false) { [weak self] _ in self?.duck(to: 1) }
        }
    }

    func duck(_ on: Bool) { duck(to: on ? 0.35 : 1) }

    /// One-shot effect (rate limited per id so spam taps do not stack).
    func sfx(_ id: String, rateLimitMs: Int = 120, gain: Float = 1) {
        guard sfxEnabled else { return }
        if let last = lastSfxAt[id], Date().timeIntervalSince(last) * 1000 < Double(rateLimitMs) { return }
        lastSfxAt[id] = Date()
        guard let u = url("SFX", id), let p = try? AVAudioPlayer(contentsOf: u) else { return }
        p.volume = min(1, (volume + 0.15) * gain)
        p.delegate = self
        p.play()
        sfxPlayers.append(p)
        if sfxPlayers.count > 12 { sfxPlayers.removeFirst() }
    }

    /// Round-robin over sound variants (coin 1/2/3, card 1/2/3 …) — never the same twice in a row.
    func sfxVariant(_ family: String, _ variants: [String], gain: Float = 1) {
        guard !variants.isEmpty else { return }
        let i = (roundRobin[family] ?? -1) + 1
        roundRobin[family] = i
        sfx(variants[i % variants.count], gain: gain)
    }

    /// Song snippet for the music formats (Audio/Songs/<songId>/<snippet>.m4a).
    func playSnippet(songId: String, snippet: String) {
        guard let u = url("Songs/\(songId)", snippet), let p = try? AVAudioPlayer(contentsOf: u) else { return }
        snippetPlayer?.stop()
        p.volume = 1
        p.play()
        snippetPlayer = p
        duck(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + p.duration + 0.2) { [weak self] in self?.duck(false) }
    }

    func stopSnippet() {
        snippetPlayer?.stop()
        snippetPlayer = nil
        duck(false)
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        sfxPlayers.removeAll { $0 === player }
    }
}
