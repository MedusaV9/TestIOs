// Sound direction for the stage — the web port of SoundRegie.swift. It turns
// *transitions* of the stage view into dramaturgy (stingers, the reveal
// three-beat, the ceremony drum roll, wheel ticks, moment effects).
import { audio } from "../lib/audio.js";
import { decode, serverNow, Wheel } from "../lib/core.js";

export const REVEAL_TENSION_MS = 1750;
export const REVEAL_SILENCE_MS = 650;
export const REVEAL_FANFARE_MS = REVEAL_TENSION_MS + REVEAL_SILENCE_MS;
export const CEREMONY_ROLL_MS = 2500;
export const CEREMONY_SILENCE_MS = 800;

const PRELOAD = ["frage_ein", "reveal", "trommelwirbel", "riser", "richtig", "falsch", "applaus_kurz", "applaus_mittel", "applaus_gross", "kaching",
  "muenze1", "muenze2", "muenze3", "muenzregen", "impact_holz", "impact_glocke", "karte1", "karte2", "karte3", "drop", "joker", "dreiklang",
  "dreiklang_tief", "karten_mischen", "jingle_hit", "tick", "tick_schnell", "confirm", "tap", "powerup"];

export class Regie {
  constructor() { this.reset(); }

  reset() {
    this.cancel();
    this.lastPhase = null; this.lastQuestionKey = null; this.lastRevealKey = null; this.lastWallRevealed = false;
    this.lastBombPasses = 0; this.lastExploded = null; this.lastBankedTotal = 0; this.lastMomentId = 0;
    this.first = true; this.bedHoldUntil = 0; this.lastSnippetAt = null; this.lastTickSec = null;
    this.stopChase();
  }

  cancel() { for (const t of this.timers || []) clearTimeout(t); this.timers = []; }
  later(ms, fn) { this.timers.push(setTimeout(fn, ms)); }

  update(view, musicSettingOn = true) {
    if (!view) return;
    if (this.first) audio.preload(PRELOAD);
    const scene = decode(view.scene);
    const phaseChanged = view.phase !== this.lastPhase;
    if (phaseChanged) {
      this.cancel();
      if (view.phase !== "rad") this.stopChase();
      if (view.phase !== "aufloesung") audio.duck(1);
    }
    this.bed(view, scene, musicSettingOn, phaseChanged);
    if (phaseChanged && !this.first) this.stinger(view);
    if (scene.kind === "frage") this.questionBeats(scene, view);
    else if (scene.kind === "aufloesung") this.revealBeat(scene);
    else if (scene.kind === "rad") this.wheelBeats(scene);
    this.moments(view);
    this.lastPhase = view.phase;
    this.first = false;
  }

  bed(view, scene, on, phaseChanged) {
    const extra = scene.extra ? decode(scene.extra) : null;
    const songPlaying = scene.kind === "frage" && extra && extra.kind === "song";
    const cue = on && !songPlaying && !view.paused ? (view.audio && view.audio.music) : null;
    if (view.phase === "siegerehrung" && phaseChanged && !this.first) {
      audio.stopMusic();
      this.bedHoldUntil = Date.now() + CEREMONY_ROLL_MS + CEREMONY_SILENCE_MS;
      audio.playMusic(cue, { afterMs: CEREMONY_ROLL_MS + CEREMONY_SILENCE_MS });
      return;
    }
    if (Date.now() < this.bedHoldUntil) return;
    audio.playMusic(cue);
  }

  stinger(view) {
    switch (view.phase) {
      case "intro": audio.sfx("jingle_hit"); break;
      case "kategorie-wahl": audio.sfx("karten_mischen", { gain: 0.8 }); break;
      case "erklaerkarte": case "highlights": audio.variant("karte", ["karte1", "karte2", "karte3"], { gain: 0.9 }); break;
      case "zwischenstand": case "halbzeit": audio.duck(0.45, 1600); audio.sfx("applaus_kurz", { gain: 0.8 }); break;
      case "rad": audio.duck(0.6, 1200); audio.sfx("dreiklang"); break;
      case "siegerehrung":
        audio.sfx("trommelwirbel_lang");
        this.later(CEREMONY_ROLL_MS + CEREMONY_SILENCE_MS, () => { audio.sfx("jingle_sax"); audio.sfx("applaus_jubel"); audio.sfx("muenzregen", { gain: 0.8 }); });
        break;
      case "brettspiel": audio.sfx("karten_mischen", { gain: 0.6 }); break;
      case "pause": audio.sfx("bong", { gain: 0.8 }); break;
      default: break;
    }
  }

  questionBeats(scene, view) {
    const wall = scene.wall;
    const extra = decode(scene.extra);
    const key = `${scene.minigameId}|${wall ? wall.nummer : 0}|${wall ? wall.text.slice(0, 24) : ""}`;
    if (key !== this.lastQuestionKey) {
      this.lastQuestionKey = key;
      this.lastWallRevealed = wall ? wall.revealed : false;
      this.lastTickSec = null;
      if (!this.first) { audio.duck(0.45, 900); audio.sfx("frage_ein", { gain: 0.9 }); }
    }
    const revealedNow = wall ? wall.revealed : false;
    if (revealedNow && !this.lastWallRevealed && !this.first) {
      if (extra.kind === "bankPot") audio.sfx(extra.verdict === "waechst" ? "richtig" : extra.verdict === "haelt" ? "impact_soft" : "falsch", { gain: 0.8 });
      else if (extra.kind === "bomb" && extra.passes <= this.lastBombPasses) audio.sfx("falsch", { gain: 0.8 });
    }
    this.lastWallRevealed = revealedNow;
    // Last five seconds tick (only for real question timers).
    if (wall && wall.deadline && !wall.revealed && !view.paused) {
      const remain = wall.deadline - serverNow();
      const sec = Math.ceil(remain / 1000);
      if (remain > 0 && sec <= 5 && sec !== this.lastTickSec) { this.lastTickSec = sec; audio.sfx(sec <= 2 ? "tick_schnell" : "tick", { gain: 0.5, rateLimitMs: 300 }); }
    }
    if (extra.kind === "bomb") {
      if (extra.passes > this.lastBombPasses && !this.first) audio.sfx("klau", { gain: 0.7 });
      this.lastBombPasses = extra.passes;
      if (extra.exploded && !this.lastExploded && !this.first) { audio.sfx("slime"); audio.sfx("impact_soft", { gain: 0.9 }); audio.sfx("dreiklang_tief", { gain: 0.7 }); }
      this.lastExploded = extra.exploded || null;
    } else if (extra.kind === "bankPot") {
      const total = Object.values(extra.banked || {}).reduce((a, b) => a + b, 0);
      if (total > this.lastBankedTotal && !this.first) audio.sfx((extra.gongFor || []).length ? "impact_glocke" : "kaching");
      this.lastBankedTotal = total;
    } else if (extra.kind === "song") {
      if (extra.playAt && extra.playAt !== this.lastSnippetAt) {
        this.lastSnippetAt = extra.playAt;
        const delay = Math.max(0, extra.playAt - serverNow());
        if (!String(extra.snippet).startsWith("video")) this.later(delay, () => audio.playSnippet(extra.songId, extra.snippet));
      }
    } else {
      this.lastExploded = null;
    }
  }

  revealBeat(scene) {
    const wall = scene.wall;
    const deltas = scene.deltas || {};
    const key = `${scene.minigameId}|${wall ? wall.nummer : 0}|${wall ? wall.text.slice(0, 24) : ""}|${Object.keys(deltas).length}`;
    if (key === this.lastRevealKey) return;
    this.lastRevealKey = key;
    audio.stopSnippet();
    if (this.first) return;
    audio.duck(0);
    audio.sfx("reveal", { gain: 0.8 });
    audio.variant("spannung", ["trommelwirbel", "riser"], { gain: 0.9 });
    let correct;
    if (wall && wall.correctIndex != null && wall.options) correct = Object.values(wall.answersByPlayer || {}).filter(v => v === wall.correctIndex).length;
    else correct = Object.values(deltas).filter(v => v > 0).length;
    const vals = Object.values(deltas);
    const maxDelta = vals.length ? Math.max(...vals) : 0;
    const everyone = vals.length > 0 && correct >= vals.length;
    this.later(REVEAL_FANFARE_MS, () => {
      if (correct === 0) { audio.sfx("falsch"); audio.sfx("dreiklang_tief", { gain: 0.6 }); }
      else {
        audio.sfx("richtig");
        if (scene.sectionKind === "jackpot" || everyone || maxDelta >= 750) audio.sfx("applaus_gross", { gain: 0.9 });
        else if (correct > 1) audio.sfx("applaus_mittel", { gain: 0.85 });
        else audio.sfx("applaus_kurz", { gain: 0.8 });
        if (maxDelta >= 750) audio.sfx("muenzregen");
        else if (maxDelta >= 250) audio.sfx("kaching");
        else if (maxDelta > 0) audio.variant("muenze", ["muenze1", "muenze2", "muenze3"], { gain: 0.9 });
      }
      audio.duck(0.3);
    });
  }

  // ---------- wheel ----------
  wheelBeats(w) {
    this.chaseWheel = w;
    if (w.subphase === "dreht") this.startChase(); else this.stopChase();
  }
  startChase() {
    if (this.chaseRaf) return;
    this.lastChaseStep = -1;
    const loop = () => {
      this.chaseRaf = requestAnimationFrame(loop);
      const w = this.chaseWheel;
      if (!w || !w.spinStartedAt || w.resultIndex == null || !w.face.length) return;
      const n = w.face.length, total = Wheel.steps(n, w.resultIndex);
      const step = Wheel.step(serverNow() - w.spinStartedAt, w.spinDurationMs, n, w.resultIndex);
      if (step === this.lastChaseStep) return;
      this.lastChaseStep = step;
      if (step >= total) {
        audio.sfx("impact_glocke");
        if (w.face[w.resultIndex] && w.face[w.resultIndex].klasse === "gold") audio.sfx("jingle_hit");
        this.stopChase();
      } else audio.sfx("impact_holz", { rateLimitMs: 45, gain: 0.65 });
    };
    this.chaseRaf = requestAnimationFrame(loop);
  }
  stopChase() { if (this.chaseRaf) cancelAnimationFrame(this.chaseRaf); this.chaseRaf = null; }

  moments(view) {
    const fresh = (view.moments || []).filter(m => m.id > this.lastMomentId);
    if (fresh.length) this.lastMomentId = fresh[fresh.length - 1].id;
    if (this.first) return;
    for (const m of fresh) {
      switch (m.art) {
        case "join": audio.sfx("drop", { gain: 0.9 }); break;
        case "joker": audio.sfx("joker"); break;
        case "sound": audio.sfx(m.text); break;
        case "streik": case "pranger": case "strafe": case "geier": audio.sfx("falsch", { gain: 0.8 }); break;
        case "rueckenwind": case "bailout": case "boost": case "kopfgeld": case "gong": audio.sfx("powerup"); break;
        case "steuer": case "affe": case "shot": case "kompliment": case "umarmung": case "tausch": audio.variant("muenze", ["muenze1", "muenze2", "muenze3"], { gain: 0.8 }); break;
        case "ultrahard": audio.sfx("riser", { gain: 0.8 }); break;
        case "shake": case "finale": audio.sfx("trommelwirbel", { gain: 0.8 }); break;
        case "jackpot": if (view.phase !== "aufloesung") audio.sfx("kaching"); break;
        default: break;
      }
    }
  }
}
