// Phone feedback: tiny synthesized WebAudio clicks (iOS Safari has no
// navigator.vibrate), a visual pulse as haptic stand-in and touch ripples.
// Audio unlocks on the first user gesture; mute is persisted.
const KEY = "mm:mute";
let ctx = null, master = null;
let muted = (() => { try { return localStorage.getItem(KEY) === "1"; } catch (_) { return false; } })();
const reduced = () => window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;

function ensure() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return null;
  try {
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.55;
    master.connect(ctx.destination);
  } catch (_) { ctx = null; }
  return ctx;
}

/** Call from a user gesture (pointerdown) — iOS only starts audio then. */
export function unlock() {
  const c = ensure();
  if (!c) return;
  if (c.state === "suspended") c.resume().catch(() => {});
  // Play one silent sample so Safari fully unlocks the context.
  try { const b = c.createBuffer(1, 1, 22050), s = c.createBufferSource(); s.buffer = b; s.connect(c.destination); s.start(0); } catch (_) {}
}

export const isMuted = () => muted;
export function setMuted(v) { muted = !!v; try { localStorage.setItem(KEY, muted ? "1" : "0"); } catch (_) {} }

function tone(freq, { at = 0, dur = 0.08, type = "sine", vol = 0.2, to = null, attack = 0.005 } = {}) {
  const c = ctx;
  const t = c.currentTime + at;
  const o = c.createOscillator(), g = c.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (to) o.frequency.exponentialRampToValueAtTime(to, t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g); g.connect(master);
  o.start(t); o.stop(t + dur + 0.02);
}

const SOUNDS = {
  tap: () => tone(1250, { dur: 0.035, type: "triangle", vol: 0.12 }),
  lock: () => { tone(660, { dur: 0.08, type: "triangle", vol: 0.22 }); tone(990, { at: 0.07, dur: 0.14, type: "triangle", vol: 0.22 }); },
  correct: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, { at: i * 0.075, dur: 0.18, type: "triangle", vol: 0.2 })),
  wrong: () => { tone(330, { dur: 0.18, type: "sawtooth", vol: 0.09, to: 220 }); tone(220, { at: 0.16, dur: 0.3, type: "sawtooth", vol: 0.09, to: 140 }); },
  heavy: () => tone(180, { dur: 0.16, type: "square", vol: 0.12, to: 90 }),
  error: () => { tone(260, { dur: 0.1, type: "square", vol: 0.08 }); tone(260, { at: 0.14, dur: 0.1, type: "square", vol: 0.08 }); },
  coin: () => { tone(1320, { dur: 0.06, type: "square", vol: 0.06 }); tone(1760, { at: 0.06, dur: 0.12, type: "square", vol: 0.06 }); },
  tick: () => tone(1800, { dur: 0.02, type: "sine", vol: 0.06 }),
  online: () => { tone(880, { dur: 0.07, vol: 0.12 }); tone(1320, { at: 0.08, dur: 0.12, vol: 0.12 }); },
};

export function play(kind) {
  if (muted || !SOUNDS[kind]) return;
  const c = ensure();
  if (!c || c.state !== "running") return;
  try { SOUNDS[kind](); } catch (_) {}
}

/** Visual stand-in for vibration: a short edge glow / shake of the app shell. */
export function pulse(kind) {
  const root = document.documentElement;
  const cls = "fx-" + (kind === "correct" ? "ok" : kind === "wrong" || kind === "error" ? "bad" : kind === "lock" ? "lock" : kind === "heavy" ? "heavy" : "tap");
  if (cls === "fx-tap") return; // taps get the ripple only
  root.classList.remove("fx-ok", "fx-bad", "fx-lock", "fx-heavy");
  void root.offsetWidth; // restart the animation
  root.classList.add(cls);
  clearTimeout(pulse.t);
  pulse.t = setTimeout(() => root.classList.remove(cls), 700);
}

/** Everything a tap/lock/result should feel like. */
export function fx(kind) { play(kind); pulse(kind); }

/** Touch ripples on every button + audio unlock + click sound. */
export function installTouch() {
  document.addEventListener("pointerdown", e => {
    unlock();
    const b = e.target.closest && e.target.closest("button, .btn, a.chip");
    if (!b || b.disabled) return;
    play("tap");
    if (reduced()) return;
    const r = b.getBoundingClientRect();
    const d = Math.max(r.width, r.height) * 2.2;
    // The ripple lives in a clipping layer, so it never widens the page (horizontal scroll on small phones).
    const clip = document.createElement("span");
    clip.className = "fx-ripple-clip";
    const s = document.createElement("span");
    s.className = "fx-ripple";
    s.style.cssText = `width:${d}px;height:${d}px;left:${e.clientX - r.left - d / 2}px;top:${e.clientY - r.top - d / 2}px`;
    if (getComputedStyle(b).position === "static") b.style.position = "relative";
    clip.appendChild(s);
    b.appendChild(clip);
    setTimeout(() => clip.remove(), 620);
  }, { passive: true, capture: true });
  // iOS Safari only applies :active (press states) when a touchstart listener exists.
  document.addEventListener("touchstart", () => {}, { passive: true });
  // No pinch zoom / double-tap zoom / long-press callouts during the show.
  document.addEventListener("gesturestart", e => e.preventDefault());
  document.addEventListener("dblclick", e => e.preventDefault(), { passive: false });
  document.addEventListener("contextmenu", e => { if (!e.target.closest("input, textarea")) e.preventDefault(); });
}
