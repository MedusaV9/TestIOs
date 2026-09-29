// Sound direction for the stage — the web port of SoundRegie.swift. It turns
// *transitions* of the stage view into dramaturgy (stingers, the reveal
// three-beat, the ceremony drum roll, wheel ticks, moment effects).
import { audio } from "../lib/audio.js";
import { decode, serverNow, Wheel } from "../lib/core.js";

export const REVEAL_TENSION_MS = 1750;
export const REVEAL_SILENCE_MS = 650;
export const REVEAL_FANFARE_MS = REVEAL_TENSION_MS + REVEAL_SILENCE_MS;
export const CEREMONY_ROLL_MS = 2500;
/** Reveal choreography (ms after the reveal starts) — shared by the sound and the picture. */
export const REVEAL_BEAT = {
  dimFrom: 750,                          // wrong options start to go dark one after another
  slam: REVEAL_FANFARE_MS,               // the correct answer slams in
  votes: REVEAL_FANFARE_MS + 350,        // vote bars grow, pickers appear
  money: REVEAL_FANFARE_MS + 850,        // delta chips land on the podium, money counts up
  extras: REVEAL_FANFARE_MS + 1600,      // ⚡ fastest, streak stamps, rank arrows, crown
  moments: REVEAL_FANFARE_MS + 2000,     // banner ticker may speak again
};
/** When each wrong option dims (index in `order`). */
export function dimTimes(n) {
  if (n <= 0) return [];
  const span = REVEAL_BEAT.slam - 300 - REVEAL_BEAT.dimFrom;
  const step = Math.min(420, span / n);
  return Array.from({ length: n }, (_, i) => Math.round(REVEAL_BEAT.dimFrom + i * step));
}
/** Category roulette: a light runs over the cards and lands on the winner. */
export const ROULETTE_MS = 1900;
export function rouletteSteps(n, winner) {
  if (n <= 1 || winner < 0) return [];
  const S = 2 * n + winner;
  return Array.from({ length: S + 1 }, (_, k) => ({ t: Math.round(ROULETTE_MS * (1 - Math.sqrt(1 - k / S))), idx: k % n }));
}
export const STANDINGS_FLIP_MS = 1100;
export const CEREMONY_SILENCE_MS = 800;

const PRELOAD = ["frage_ein", "reveal", "trommelwirbel", "riser", "richtig", "falsch", "applaus_kurz", "applaus_mittel", "applaus_gross", "kaching",
  "muenze1", "muenze2", "muenze3", "muenzregen", "impact_holz", "impact_glocke", "karte1", "karte2", "karte3", "drop", "joker", "dreiklang",
  "dreiklang_tief", "karten_mischen", "jingle_hit", "jingle_hit2", "tick", "tick_schnell", "confirm", "tap", "tap2", "powerup", "phaser", "scroll", "impact_soft"];

export class Regie {
  constructor() { this.reset(); }

  reset() {
    this.cancel();
    this.lastPhase = null; this.lastQuestionKey = null; this.lastRevealKey = null; this.lastWallRevealed = false;
    this.lastBombPasses = 0; this.lastExploded = null; this.lastAnswered = 0; this.allInKey = null; this.lastGewinner = null; this.lastBankedTotal = 0; this.lastMomentId = 0;
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
    else if (scene.kind === "kategorieWahl") this.rouletteBeats(scene);
    if (phaseChanged && !this.first && scene.kind === "zwischenstand") this.standingsBeats(scene);
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
      this.lastAnswered = wall ? wall.answered.length : 0;
      if (!this.first) { audio.duck(0.45, 900); audio.sfx("frage_ein", { gain: 0.9 }); }
    }
    const revealedNow = wall ? wall.revealed : false;
    if (revealedNow && !this.lastWallRevealed && !this.first) {
      if (extra.kind === "bankPot") audio.sfx(extra.verdict === "waechst" ? "richtig" : extra.verdict === "haelt" ? "impact_soft" : "falsch", { gain: 0.8 });
      else if (extra.kind === "bomb" && extra.passes <= this.lastBombPasses) audio.sfx("falsch", { gain: 0.8 });
    }
    this.lastWallRevealed = revealedNow;
    // Lock-ins: a soft click per answer, a chord when everybody is in.
    if (wall && !wall.revealed) {
      const n = wall.answered.length;
      if (n > this.lastAnswered && !this.first) audio.sfx("tap2", { gain: 0.55, rateLimitMs: 90 });
      this.lastAnswered = n;
      const online = view.players.filter(p => p.connected).length;
      if (n > 0 && n >= online && this.allInKey !== key) {
        this.allInKey = key;
        if (!this.first) this.later(120, () => audio.sfx("confirm", { gain: 0.8 }));
      }
    }
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
    // Wrong options go dark one after another — a dry tick each.
    if (wall && wall.options && wall.correctIndex != null) {
      const wrong = wall.options.filter(o => !o.removed && o.id !== wall.correctIndex).length;
      for (const t of dimTimes(wrong)) this.later(t, () => audio.sfx("tap", { gain: 0.4, rateLimitMs: 60 }));
    }
    this.later(REVEAL_BEAT.slam, () => {
      if (correct === 0) { audio.sfx("falsch"); audio.sfx("dreiklang_tief", { gain: 0.6 }); }
      else {
        audio.sfx("richtig");
        if (scene.sectionKind === "jackpot" || everyone || maxDelta >= 750) audio.sfx("applaus_gross", { gain: 0.9 });
        else if (correct > 1) audio.sfx("applaus_mittel", { gain: 0.85 });
        else audio.sfx("applaus_kurz", { gain: 0.8 });
      }
      audio.duck(0.3);
    });
    // Money lands on the podium.
    this.later(REVEAL_BEAT.money, () => {
      if (maxDelta >= 750) audio.sfx("muenzregen");
      else if (maxDelta >= 250) audio.sfx("kaching");
      else if (maxDelta > 0) audio.variant("muenze", ["muenze1", "muenze2", "muenze3"], { gain: 0.9 });
    });
    // Extras: fastest, streak milestone, rank climbs, new leader.
    const r = scene.reveal;
    if (r) {
      const E = REVEAL_BEAT.extras;
      if (r.schnellster && r.antwortAnzahl >= 2) this.later(E, () => audio.sfx("phaser", { gain: 0.55 }));
      if (r.eintraege.some(e => e.richtig === true && (e.streak === 3 || e.streak === 5))) this.later(E + 180, () => audio.sfx("powerup", { gain: 0.8 }));
      if (r.eintraege.some(e => e.platzNachher < e.platzVorher)) this.later(E + 90, () => audio.sfx("scroll", { gain: 0.6 }));
      if (r.fuehrungswechsel) this.later(E + 380, () => { audio.sfx("impact_glocke", { gain: 0.8 }); audio.sfx("jingle_hit2", { gain: 0.8 }); });
    }
  }

  // ---------- category roulette / standings ----------
  rouletteBeats(s) {
    if (!s.gewinner) { this.lastGewinner = null; return; }
    if (s.gewinner === this.lastGewinner) return;
    this.lastGewinner = s.gewinner;
    if (this.first) return;
    const steps = rouletteSteps(s.optionen.length, s.optionen.findIndex(o => o.id === s.gewinner));
    steps.forEach((st, i) => this.later(st.t, () => i === steps.length - 1 ? (audio.sfx("impact_glocke"), audio.sfx("applaus_kurz", { gain: 0.6 })) : audio.sfx("impact_holz", { gain: 0.55, rateLimitMs: 40 })));
  }
  standingsBeats(s) {
    const entries = s.entries || [];
    if (entries.some((e, i) => e.platzVorher && e.platzVorher > i + 1)) this.later(STANDINGS_FLIP_MS, () => audio.sfx("scroll", { gain: 0.65 }));
    if (entries.length > 1 && entries[0].platzVorher > 1) this.later(STANDINGS_FLIP_MS + 700, () => { audio.sfx("impact_glocke", { gain: 0.75 }); audio.sfx("jingle_hit2", { gain: 0.7 }); });
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
