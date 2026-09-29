// Writes tools/trailer/compose/audio.json (the encoder's cue list) from the beat grid + shot list in edit.json.
//   env -u NODE_OPTIONS node tools/trailer/compose/make-audio.mjs
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const DIR = path.dirname(fileURLToPath(import.meta.url)) + "/";
const edit = JSON.parse(readFileSync(DIR + "edit.json", "utf8"));
const P = 60 / edit.beat.bpm, T0 = edit.beat.t0, INS = edit.beat.insert || { after: 1e9, beats: 0 };
const bt = n => T0 + (n >= INS.after ? n + INS.beats : n) * P;
const sc = Object.fromEntries(edit.scenes.map(s => [s.id, s]));
const M = "MonkeyMoney/ios/Resources/Audio/Music/", S = "MonkeyMoney/ios/Resources/Audio/SFX/";
const r3 = x => Math.round(x * 1000) / 1000;
const cues = [];
const cue = (src, at, o = {}) => { if (at < 0) { o = { ...o, offset: r3((o.offset || 0) - at) }; at = 0; } cues.push({ src: (src.includes("/") ? src : S + src + ".m4a"), at: r3(at), ...o }); };

// music: theme_main, source drop (7.150 s) on the S2 cut; second segment puts the closing stab (77.49 s) on the S9 cut
const x1 = sc.S6.in;
cue(M + "theme_main.m4a", 0, { offset: 4.9504, dur: r3(x1 + 0.12), gain: 0.8, fadeIn: 0.05, fadeOut: 0.2 });
cue(M + "theme_main.m4a", x1 - 0.05, { offset: r3(68.054 - 0.05), gain: 0.8, fadeIn: 0.1 });

// S1 cold open
cue("karte2", 0.18, { gain: 0.35 });                              // leaves part
cue("riser", bt(-3) - 1.57, { gain: 0.6, fadeIn: 0.35 });          // riser peak on the logo slam
cue("impact_glocke", bt(-3), { gain: 0.85 });
cue("jingle_hit2", bt(-1) + 0.05, { gain: 0.35 });                 // logo shine
// S2 setup
cue("impact_soft", sc.S2.in, { gain: 0.55 });
cue("karte1", bt(1) - 0.05, { gain: 0.5 }); cue("karte2", bt(2) - 0.02, { gain: 0.5 });   // phones slide in
cue("buzzer_boing", bt(3), { gain: 0.3 });                          // monkey hop
cue("richtig", bt(4), { gain: 0.5 });                               // "keine App nötig"
// S3 beat cuts
const cards = ["karte3", "karte1", "karte2"], onset = { karte1: 0.15, karte2: 0.06, karte3: 0.08 };
edit.slots["S3.cuts"].forEach((c, i) => {
  const k = cards[i % 3]; cue(k, c.at - onset[k], { gain: 0.5 });
  if (!c.keepLabel) cue("impact_holz", c.at, { gain: 0.3 });
  if (c.money) { cue("muenzregen", c.at + P * 0.5 - 0.03, { gain: 0.7 }); cue("impact_soft", c.at + P * 0.5, { gain: 0.45 }); }
});
// S4 format wall
cue("impact_soft", sc.S4.in, { gain: 0.5 });
cue("karten_mischen", sc.S4.in - 0.16, { gain: 0.5, dur: 1.4, fadeOut: 0.3 });       // tiles flipping
cue("impact_glocke", bt(20), { gain: 0.65 }); cue("jingle_hit", bt(20), { gain: 0.4 }); // "33"
// S5 questions
cue("trommelwirbel", bt(27) - 1.37, { gain: 0.55 });                // roll ends on the counter slam
cue("impact_soft", sc.S5.in, { gain: 0.45 });
cue("scroll", sc.S5.in + 0.03, { gain: 0.3, fadeOut: 0.3 });        // odometer ticking
cue("jingle_hit", bt(27), { gain: 0.45 });
cue("chip1", bt(28), { gain: 0.5 }); cue("chip2", bt(29), { gain: 0.5 }); cue("chips_stapel", bt(30), { gain: 0.5 });
cue("phaser", bt(31), { gain: 0.5 }); for (const d of [0, 0.09, 0.2]) cue("glitch", bt(31) + d, { gain: 0.45 });
// S6 show modes
cue("impact_soft", sc.S6.in, { gain: 0.5 });
cue("karte1", sc.S6.in + 0.02, { gain: 0.4 }); cue("karte3", sc.S6.in + 0.24, { gain: 0.4 }); cue("karte2", sc.S6.in + 0.5, { gain: 0.4 });
for (let i = 0; i < 7; i += 2) cue(i % 4 ? "chip2" : "chip1", bt(36) + i * 0.09, { gain: 0.3 });
// S7 game master
cue("impact_soft", sc.S7.in, { gain: 0.45 });
cue("impact_glocke", bt(40), { gain: 0.5 });
["error", "powerup", "bong", "chip2"].forEach((s, i) => { cue("tap2", bt(41 + i) - 0.02, { gain: 0.45 }); cue(s, bt(41 + i) + 0.05, { gain: 0.4 }); });
// S8 climax
const s8 = edit.slots["S8.cuts"], cele = edit.slots["S8.celebrate"].at;
cue("impact_holz", s8[0].at, { gain: 0.4 }); cue("scroll", s8[0].at, { gain: 0.45, dur: 0.85, fadeOut: 0.1 });   // wheel ticks
cue("dreiklang", s8[1].at - 0.05, { gain: 0.45 });
cue("trommelwirbel", cele - 1.37, { gain: 0.6 });
cue("karte3", s8[2].at - 0.08, { gain: 0.4 }); cue("karte1", s8[3].at - 0.15, { gain: 0.4 });
cue("impact_glocke", cele, { gain: 0.9 }); cue("jingle_hit", cele, { gain: 0.5 }); cue("muenzregen", cele + 0.05, { gain: 0.55 });
cue("applaus_jubel", cele, { gain: 0.3, dur: 3.2, fadeOut: 1.2 });
// S9 end card
cue("impact_soft", sc.S9.in, { gain: 0.5 });
cue("applaus_gross", sc.S9.in, { gain: 0.25, fadeIn: 0.3, fadeOut: 1.2, dur: edit.duration - sc.S9.in });
cue("impact_holz", bt(56), { gain: 0.35 });
cue("jingle_hit2", bt(58), { gain: 0.3 });

cues.sort((a, b) => a.at - b.at);
const out = { _doc: "Audio cue list for tools/trailer/encode.mjs (--audio). Generated from the beat grid in edit.json (139.89 BPM, beat 0 = 2.2 s). Times in trailer seconds; src relative to the repo root.",
  duration: edit.duration, sampleRate: 48000, master: { gain: 0.9, fadeOut: 0.6 }, cues };
writeFileSync(DIR + "audio.json", JSON.stringify(out, null, 1).replace(/\{\n\s+"src"/g, '{ "src"').replace(/,\n\s+"(at|offset|dur|gain|fadeIn|fadeOut)"/g, ', "$1"').replace(/\n\s+\}/g, " }"));
console.log(cues.length, "cues");
for (const c of cues) console.log(c.at.toFixed(3).padStart(7), c.src.split("/").pop());
