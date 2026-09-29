// Stage effects: scene transitions (curtain / wipe / iris / slide), a cheap
// beat clock for choreographies, bursts and FLIP helpers, plus the stage's
// low-cost timers (CSS-driven arcs/fuses that re-render at most once a second)
// and FitBox (scales a widget down so it never runs into the podium).
import { html, useState, useEffect, useLayoutEffect, useRef } from "../vendor/preact-htm.js";
import { serverNow, cx } from "../lib/core.js";

export const reducedMotion = () => !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
export const TRANSITION_MS = 640;
/** The latest scene switch (read synchronously by entering scenes to time their own entrance). */
export const lastSwitch = { at: 0, variant: null };

const isQ = k => k === "frage" || k === "aufloesung";
function variantFor(from, to) {
  if (isQ(from) && isQ(to)) return "slide";
  if (from === "lobby" || ["intro", "zwischenstand", "siegerehrung", "highlights", "ende"].includes(to)) return "curtain";
  if (to === "rad" || to === "pause" || from === "rad") return "iris";
  return "wipe";
}

/**
 * Keeps the previous scene on screen for a moment with an exit animation while
 * the next one enters. `k` identifies a scene (same k → the scene morphs in place),
 * `data` is what `render` needs; the leaving layer is rendered with its last data.
 */
export function SceneSwitch({ k, kind, data, render }) {
  const st = useRef(null);
  if (!st.current) st.current = { k, kind, data, leaving: null, id: 0, variant: null };
  const s = st.current;
  if (s.k !== k) {
    if (!reducedMotion()) {
      s.leaving = { k: s.k, kind: s.kind, data: s.data };
      s.variant = variantFor(s.kind, kind);
      s.id++;
      lastSwitch.at = Date.now(); lastSwitch.variant = s.variant;
    } else s.leaving = null;
    s.k = k; s.kind = kind;
  }
  s.data = data;
  const [, force] = useState(0);
  useEffect(() => {
    if (!s.leaving) return;
    const id = s.id;
    const t = setTimeout(() => { if (st.current.id === id) { st.current.leaving = null; force(x => x + 1); } }, TRANSITION_MS);
    return () => clearTimeout(t);
  }, [s.id]);
  const L = s.leaving;
  return html`<div class=${cx("scene-switch", L && "switching", L && "v-" + s.variant)}>
    ${L && html`<div class="scene-layer leaving" key=${L.k}>${render(L.data)}</div>`}
    <div class=${cx("scene-layer", L && "entering")} key=${k}>${render(data)}</div>
    ${L && s.variant !== "slide" && html`<${Wipe} variant=${s.variant} key=${"w" + s.id} />`}
  </div>`;
}

function Wipe({ variant }) {
  if (variant === "curtain") return html`<div class="fx-wipe curtain"><i class="c-l"></i><i class="c-r"></i><b class="c-logo">🐵</b></div>`;
  if (variant === "iris") return html`<div class="fx-wipe iris"><i></i></div>`;
  return html`<div class="fx-wipe band"><i><b>🍌</b></i></div>`;
}

/**
 * Re-render only at the given beat offsets (ms after `at`, server clock).
 * Returns the elapsed ms (or -1 when `at` is null). Cheap: one timer per beat.
 */
export function useBeats(at, beats) {
  const [, force] = useState(0);
  const t = at == null ? -1 : serverNow() - at;
  useEffect(() => {
    if (at == null) return;
    const now = serverNow() - at;
    let next = Infinity;
    for (const b of beats) if (b > now && b < next) next = b;
    if (next === Infinity) return;
    const id = setTimeout(() => force(x => x + 1), next - now + 8);
    return () => clearTimeout(id);
  });
  return t;
}

/** A shiny starburst (rays + ring) — mount it to play. */
export function Burst({ class: klass, color }) {
  return html`<span class=${cx("fx-burst", klass)} style=${color ? `--bc:${color}` : ""}><i class="rays"></i><i class="ring"></i><i class="ring r2"></i></span>`;
}

/** A few flying coins (pure CSS). */
export function CoinPop({ n = 6 }) {
  return html`<span class="fx-coins">${Array.from({ length: n }, (_, i) => html`<i style=${`--a:${(i / n) * 360 + 20}deg;--d:${i * 40}ms`}>🪙</i>`)}</span>`;
}

/**
 * FLIP for a list: `from` maps id → previous index. Rows render in their final
 * order; on mount each row is pushed back to its old slot and, after `delay`,
 * glides to its new place. Rows need `data-id` and live in `ref`.
 */
export function useFlip(ref, from, delay, deps = []) {
  useEffect(() => {
    const box = ref.current;
    if (!box || reducedMotion()) return;
    const rows = [...box.querySelectorAll("[data-flip]")];
    const tops = rows.map(r => r.offsetTop);
    let moved = false;
    rows.forEach((r, i) => {
      const old = from[r.dataset.flip];
      if (old == null || old === i || old < 0 || old >= rows.length) return;
      moved = true;
      r.style.transition = "none";
      r.style.transform = `translateY(${tops[old] - tops[i]}px)`;
      r.style.zIndex = old > i ? 3 : 1;
    });
    if (!moved) return;
    const t = setTimeout(() => {
      rows.forEach(r => { r.style.transition = "transform 0.9s cubic-bezier(.5, 0, .2, 1)"; r.style.transform = ""; });
    }, delay);
    return () => clearTimeout(t);
  }, deps);
}


// ---------- cheap timers ----------
/**
 * Remaining ms until `deadline` (server clock). Re-renders only on whole-second
 * boundaries — never per frame. Returns 0 without a deadline.
 */
export function useSecondsLeft(deadline, active = true) {
  const [, force] = useState(0);
  const remain = deadline ? deadline - serverNow() : 0;
  useEffect(() => {
    if (!deadline || !active) return;
    const r = deadline - serverNow();
    if (r <= -50) return;
    const next = r > 0 ? (r % 1000 || 1000) : 60;
    const id = setTimeout(() => force(x => x + 1), next + 6);
    return () => clearTimeout(id);
  });
  return remain;
}

/** Whole seconds left (1 Hz) — the stage's replacement for the per-frame Countdown. */
export function Secs({ deadline, paused }) {
  const r = useSecondsLeft(deadline, !paused);
  if (!deadline) return null;
  return html`<span class="countdown">${Math.max(0, Math.ceil(r / 1000))}</span>`;
}

/** First sight of a deadline → total length and how far in we already are (stable per deadline). */
function useTiming(deadline, total) {
  const ref = useRef({ deadline: null });
  if (deadline && ref.current.deadline !== deadline) {
    const rem = Math.max(0, deadline - serverNow());
    const tot = Math.max(1000, total || rem);
    ref.current = { deadline, tot, ago: Math.max(0, Math.min(tot, tot - rem)) };
  }
  return ref.current;
}

/**
 * Countdown ring: the arc drains via a CSS animation (no re-render per frame),
 * the number updates once a second. Levels: calm → warn (≤10 s or ⅓) → hot (≤5 s).
 */
export function StageTimer({ deadline, total, size = 150, paused, label, class: klass }) {
  const tm = useTiming(deadline, total);
  const remain = useSecondsLeft(deadline, !paused);
  if (!deadline) return null;
  const rem = Math.max(0, remain);
  const secs = Math.ceil(rem / 1000);
  const frac = rem / tm.tot;
  const lvl = rem <= 0 ? "done" : rem <= 5000 ? "hot" : rem <= 10000 || frac < 0.34 ? "warn" : "calm";
  const anim = `--dur:${tm.tot}ms;animation-delay:-${tm.ago}ms`;
  return html`<div class=${cx("st-timer", "lvl-" + lvl, paused && "paused", klass)} style=${`--size:${size}px`}>
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <circle class="st-track" cx="50" cy="50" r="44" />
      <circle class="st-ticks" cx="50" cy="50" r="36" />
      <circle class="st-glow" key=${"g" + deadline} cx="50" cy="50" r="44" style=${anim} />
      <circle class="st-arc" key=${"a" + deadline} cx="50" cy="50" r="44" style=${anim} />
    </svg>
    <div class="st-core"><b class="st-secs" key=${secs}>${secs}</b>${label && html`<small>${label}</small>`}</div>
  </div>`;
}

/** A draining fuse bar (CSS-driven). Used on the question card and the explain card. */
export function StageBar({ deadline, total, paused, class: klass }) {
  const tm = useTiming(deadline, total);
  const remain = useSecondsLeft(deadline, !paused);
  if (!deadline) return null;
  const hot = remain <= 5000;
  return html`<div class=${cx("stage-bar", hot && "hot", paused && "paused", klass)}>
    <i key=${deadline} style=${`--dur:${tm.tot}ms;animation-delay:-${tm.ago}ms`}></i>
  </div>`;
}

// ---------- FitBox ----------
/**
 * Takes the space its parent flex column leaves and scales its content down
 * (never up) when the content would overflow — widgets of any size stay clear
 * of the podium. Measures on resize/content change only (ResizeObserver).
 */
export function FitBox({ children, class: klass, min = 0.5, center = false }) {
  const outer = useRef(), inner = useRef();
  const [k, setK] = useState(1);
  useLayoutEffect(() => {
    const o = outer.current, i = inner.current;
    if (!o || !i) return;
    let raf = 0;
    const measure = () => {
      raf = 0;
      const H = o.clientHeight, W = o.clientWidth;
      const h = i.offsetHeight, w = Math.max(i.offsetWidth, i.scrollWidth);
      let s = 1;
      if (H > 20 && h > H + 1) s = Math.min(s, H / h);
      if (W > 20 && w > W + 1) s = Math.min(s, W / w);
      s = Math.max(min, Math.floor(s * 100) / 100);
      setK(prev => (Math.abs(prev - s) >= 0.01 ? s : prev));
    };
    measure();
    if (typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(() => { if (!raf) raf = requestAnimationFrame(measure); });
    ro.observe(o); ro.observe(i);
    return () => { ro.disconnect(); if (raf) cancelAnimationFrame(raf); };
  }, []);
  return html`<div class=${cx("fit", center && "fit-center", k < 1 && "fit-scaled", klass)} ref=${outer}>
    <div class="fit-in" ref=${inner} style=${k < 1 ? `transform:scale(${k})` : ""}>${children}</div>
  </div>`;
}

/** Remembers the first time a key was shown on this stage (module-wide, survives re-mounts). */
const firstSeen = new Map();
export function seenAt(key) {
  if (!firstSeen.has(key)) {
    firstSeen.set(key, Date.now());
    if (firstSeen.size > 80) firstSeen.delete(firstSeen.keys().next().value);
  }
  return firstSeen.get(key);
}
