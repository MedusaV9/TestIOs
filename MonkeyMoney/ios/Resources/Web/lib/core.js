// Monkey Money — shared web core: server clock, WebSocket session, Swift-enum
// decoding, formatting. Used by the stage (iPad), the phones and the cockpit.
import { useState, useEffect, useRef } from "../vendor/preact-htm.js";

export const MONKEYS = [
  ["don-bananas", "Don Bananas", "der Pate"], ["gitti-giro", "Gitti Giro", "die Buchhalterin"], ["kiki-krawall", "Kiki Krawall", "das Chaos-Äffchen"],
  ["baron-von-bananenstein", "Baron von Bananenstein", "der Adlige"], ["oma-zinseszins", "Oma Zinseszins", "die Sparfüchsin"], ["pumper-paule", "Pumper-Paule", "der Gym-Gorilla"],
  ["schnarch-schorsch", "Schnarch-Schorsch", "der Gemütliche"], ["glitzer-gina", "Glitzer-Gina", "die Diva"], ["dj-trommelfell", "DJ Trommelfell", "der Beat-Affe"],
  ["astro-astrid", "Astro-Astrid", "die Raumfahrerin"], ["kommissar-kokosnuss", "Kommissar Kokosnuss", "der Detektiv"], ["iro-ines", "Iro-Ines", "die Punkerin"],
  ["abraka-dieter", "Abraka-Dieter", "der Zauberer"], ["kahuna-kalle", "Kahuna-Kalle", "der Surfer"],
];
export const COLORS = [["gelb", "#FFD34E"], ["rot", "#FF4D6D"], ["gruen", "#5BE08A"], ["blau", "#4D8BFF"], ["lila", "#9B6BFF"], ["orange", "#FF8A3D"], ["tuerkis", "#2ED3C6"], ["pink", "#FF6BD6"]];

/** The four lianas (answer colours) — the same on stage and phone. */
export const OPTION_STYLE = [
  { c: "#FFC93C", d: "#B7860B", e: "🍌", l: "A" },
  { c: "#C98A4B", d: "#7A4A1E", e: "🥥", l: "B" },
  { c: "#FF4D6D", d: "#A3173A", e: "🐒", l: "C" },
  { c: "#2BD98A", d: "#0F7A4A", e: "🌴", l: "D" },
  { c: "#4D8BFF", d: "#1F4BB0", e: "💎", l: "E" },
  { c: "#9B6BFF", d: "#5A2FC0", e: "🎩", l: "F" },
  { c: "#2ED3C6", d: "#137E76", e: "🌊", l: "G" },
  { c: "#FF6BD6", d: "#A8248A", e: "🔥", l: "H" },
];

export function colorHex(token) {
  if (token && token.startsWith("hex") && token.length === 9) return "#" + token.slice(3);
  const c = COLORS.find(c => c[0] === token);
  return c ? c[1] : COLORS[0][1];
}

export function avatarParts(wire) {
  const p = String(wire || "don-bananas.gelb").split(".");
  return { affe: MONKEYS.some(m => m[0] === p[0]) ? p[0] : "don-bananas", farbe: p[1] || "gelb", extras: (p[2] || "").split("+").filter(e => e && !e.startsWith("lv")) };
}

// ---------- formatting ----------
const nf = new Intl.NumberFormat("de-DE");
export const fmtNum = n => nf.format(Math.round(Number(n || 0) * 100) / 100);
export const fmtMM = n => `${nf.format(Math.round(Number(n || 0)))} MM`;
export const fmtDelta = n => (n >= 0 ? "+" : "−") + nf.format(Math.abs(Math.round(n)));
export const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const cx = (...a) => a.filter(Boolean).join(" ");

/** Decode a Swift enum value (`{"choice": {...}}`, `{"lobby": {"_0": {...}}}`) → {kind, ...payload}. */
export function decode(v) {
  if (!v || typeof v !== "object") return { kind: String(v || "none") };
  const kind = Object.keys(v)[0];
  let body = v[kind] || {};
  if (body && typeof body === "object" && "_0" in body && Object.keys(body).length === 1) body = body._0;
  return Object.assign({ kind }, body);
}

// ---------- server clock ----------
const clock = { offset: 0, samples: [] };
export const serverNow = () => Date.now() + clock.offset;
function addSample(t0, serverTime) {
  const rtt = Date.now() - t0;
  clock.samples.push(serverTime + rtt / 2 - Date.now());
  if (clock.samples.length > 9) clock.samples.shift();
  const s = [...clock.samples].sort((a, b) => a - b);
  clock.offset = s[Math.floor(s.length / 2)];
}
export function syncFromView(serverTime) {
  // Before the first pong, align on the view's timestamp.
  if (!clock.samples.length && serverTime) clock.offset = serverTime - Date.now();
}

/** Re-render every `ms` (for timers and countdowns). */
export function useNow(ms = 250, active = true) {
  const [now, setNow] = useState(serverNow());
  useEffect(() => {
    if (!active) return;
    const id = setInterval(() => setNow(serverNow()), ms);
    return () => clearInterval(id);
  }, [ms, active]);
  return now;
}

/** requestAnimationFrame clock (smooth rings/wheels). */
export function useFrame(active = true) {
  const [t, setT] = useState(serverNow());
  useEffect(() => {
    if (!active) return;
    let raf;
    const loop = () => { setT(serverNow()); raf = requestAnimationFrame(loop); };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [active]);
  return t;
}

/** Remember when a key was first seen (client-side choreography, e.g. reveal beats). */
export function useSince(key) {
  const ref = useRef({ key: undefined, at: 0 });
  if (ref.current.key !== key) ref.current = { key, at: serverNow() };
  return ref.current.at;
}

/** Persistent WebSocket with reconnect + hello replay + ping clock sync. */
export function connect({ hello, onMessage, onStatus }) {
  let ws, alive = false, retry = 600, pingTimer, closedByUs = false;
  const url = (location.protocol === "https:" ? "wss://" : "ws://") + location.host + "/ws";
  function open() {
    ws = new WebSocket(url);
    ws.onopen = () => {
      alive = true; retry = 600; onStatus && onStatus(true);
      const h = hello(); if (h) ws.send(JSON.stringify(h));
      send({ t: "ping", t0: Date.now() });
      pingTimer = setInterval(() => send({ t: "ping", t0: Date.now() }), 3000);
    };
    ws.onclose = () => {
      alive = false; onStatus && onStatus(false); clearInterval(pingTimer);
      if (!closedByUs) setTimeout(open, retry);
      retry = Math.min(5000, retry * 1.5);
    };
    ws.onerror = () => { try { ws.close(); } catch (_) {} };
    ws.onmessage = ev => {
      let msg; try { msg = JSON.parse(ev.data); } catch (_) { return; }
      if (msg.t === "pong") { addSample(msg.t0, msg.serverTime); return; }
      if (msg.view && msg.view.serverTime) syncFromView(msg.view.serverTime);
      onMessage(msg);
    };
  }
  function send(obj) { if (alive && ws && ws.readyState === 1) { ws.send(JSON.stringify(obj)); return true; } return false; }
  open();
  return { send, get alive() { return alive; }, close() { closedByUs = true; try { ws.close(); } catch (_) {} }, reconnect() { try { ws.close(); } catch (_) {} } };
}

export async function api(path, body) {
  const r = await fetch(path, body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (!r.ok) throw new Error(await r.text().catch(() => r.statusText));
  const t = await r.text();
  try { return JSON.parse(t); } catch (_) { return t; }
}

export function deviceToken() {
  let t = localStorage.getItem("mm:device");
  if (!t) { t = Math.random().toString(36).slice(2) + Date.now().toString(36); localStorage.setItem("mm:device", t); }
  return t;
}

export function haptic(kind) {
  if (!navigator.vibrate) return;
  try {
    if (kind === "success") navigator.vibrate([30, 40, 60]);
    else if (kind === "error") navigator.vibrate([120, 60, 120]);
    else if (kind === "heavy") navigator.vibrate(60);
    else navigator.vibrate(14);
  } catch (_) {}
}

export const DIFF = { easy: ["Leicht", 1], medium: ["Mittel", 2], hard: ["Schwer", 3], ultrahard: ["ULTRAHARD", 4] };

/** Wheel light chase — mirrors Core/Rules/Wheel.swift exactly. */
export const Wheel = {
  laps: 3,
  steps: (n, result) => Math.max(1, 3 * Math.max(1, n) + Math.max(0, result)),
  progress(elapsed, duration) {
    if (duration <= 0 || elapsed <= 0) return 0;
    if (elapsed >= duration) return 1;
    const p = elapsed / duration;
    return 1 - Math.pow(1 - p, 3);
  },
  step(elapsed, duration, n, result) {
    const total = Wheel.steps(n, result);
    if (duration <= 0 || elapsed <= 0) return 0;
    if (elapsed >= duration) return total;
    return Math.min(total, Math.floor(Wheel.progress(elapsed, duration) * total));
  },
};


// ---------- phone feedback bridge ----------
// Prompts call `feel(kind)` (tap | lock | correct | wrong | heavy | error) and
// `notify(text)`; the phone app plugs in sound, visual pulse and toasts via
// `setFeedback`. Without a plugged-in handler (stage, cockpit) only `haptic` runs.
const fxBridge = { feel: null, say: null };
export function setFeedback(o) { Object.assign(fxBridge, o || {}); }
export function feel(kind = "tap") {
  if (kind !== "tick") haptic(kind === "lock" || kind === "correct" ? "success" : kind === "wrong" || kind === "error" ? "error" : kind === "heavy" ? "heavy" : undefined);
  if (fxBridge.feel) { try { fxBridge.feel(kind); } catch (_) {} }
}
export function notify(text) { if (fxBridge.say) fxBridge.say(text); }

/** Optimistic commit: `commit(action, value)` sends, shows a pending state
 *  right away, resends while the server hasn't confirmed and rolls back after
 *  `tries` attempts. `confirmed` = the server echo (truthy once accepted). */
export function useCommit(send, confirmed, { every = 1800, tries = 3 } = {}) {
  const [pend, setPend] = useState(null);
  const seen = useRef(confirmed);
  useEffect(() => {
    const changed = seen.current !== confirmed;
    seen.current = confirmed;
    if (pend && changed && confirmed != null && confirmed !== false) setPend(null);
  }, [confirmed]);
  useEffect(() => {
    if (!pend) return;
    const t = setTimeout(() => {
      if (pend.n < tries) { send(pend.action); setPend({ ...pend, n: pend.n + 1 }); }
      else { setPend(null); feel("error"); notify("⚠️ Antwort nicht angekommen — bitte nochmal tippen"); }
    }, every);
    return () => clearTimeout(t);
  }, [pend]);
  const commit = (action, value = true) => { const ok = send(action); setPend({ action, value, n: 1, at: Date.now() }); feel("lock"); return ok; };
  return [pend, commit, () => setPend(null)];
}
