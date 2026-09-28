// Stage effects: scene transitions (curtain / wipe / iris / slide), a cheap
// beat clock for choreographies, bursts and FLIP helpers.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { serverNow, cx } from "../lib/core.js";

export const reducedMotion = () => !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
export const TRANSITION_MS = 640;

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
