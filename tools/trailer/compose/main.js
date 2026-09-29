// Monkey Money trailer composition (1920×1080, 30 fps, 28 s).
// Deterministic: all motion is CSS keyframes placed on the trailer clock by absolute animation-delay
// (fill-mode both) and seeked by window.renderAt(t); JS-driven parts (counters, orbit, particles,
// footage frames) are pure functions of t. No Date.now / Math.random / rAF-driven motion.
import { ICONS, COIN_FACE, COIN_EDGE, dataUrl } from "./icons.js";
import { Fx } from "./fx.js";

const W = 1920, H = 1080;
const RES = "MonkeyMoney/ios/Resources/";
const E = {
  out: "cubic-bezier(.16,1,.3,1)", back: "cubic-bezier(.34,1.56,.64,1)", back2: "cubic-bezier(.25,1.9,.45,1)",
  inout: "cubic-bezier(.65,0,.35,1)", in: "cubic-bezier(.6,0,.9,.35)", lin: "linear", soft: "cubic-bezier(.4,0,.2,1)",
  sine: "cubic-bezier(.37,0,.63,1)",
};
let EDIT, DATA, P, T0;
const scenes = [], updaters = [], players = [], decodes = [];
let fx, bgfx;
const SVG_TEXT = {};

// ---------------------------------------------------------------- utils
function h(tag, cls = "", style = {}, html = "") {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  for (const [k, v] of Object.entries(style)) { if (k.startsWith("--")) el.style.setProperty(k, String(v)); else el.style[k] = v; }
  if (html) el.innerHTML = html;
  return el;
}
const put = (parent, ...kids) => { for (const k of kids) if (k) parent.appendChild(k); return parent; };
/** A(el, [name, dur, at, ease, iterations, direction], …) — at = absolute trailer seconds. */
function A(el, ...list) {
  const s = list.map(([n, d, at, e = E.out, it = 1, dir = "normal"]) => `${n} ${d}s ${e} ${at}s ${it} ${dir} both`).join(", ");
  el.style.animation = el.style.animation ? `${el.style.animation}, ${s}` : s;
  return el;
}
const bt = n => T0 + n * P;
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const easeOutExpo = x => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x));
const easeOutCubic = x => 1 - Math.pow(1 - x, 3);
const easeOutBack = x => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
function url(p) {
  if (!p || /^(data:|https?:|blob:)/.test(p)) return p;
  if (p.startsWith("/projects/sandbox/trailer/")) return "/trailer/" + p.slice(26);
  if (p.startsWith("/")) return "/fs" + p;
  return "/" + p; // repo-relative
}
const fmt = n => String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
const fill = s => String(s).replace(/\{(\w+)\}/g, (_, k) => (k === "modeCount" ? DATA.modes.length : DATA[k] ?? ""));
const monkeyUrl = (id, mood) => url(`${RES}Monkeys/${id}_${mood}.png`);
function monkeyImg(id, mood, style) { const im = h("img", "monkey", style); im.src = monkeyUrl(id, mood); decodes.push(im); return im; }
const T = id => (EDIT.text && EDIT.text[id]) || {};
const slot = k => EDIT.slots[k];

let glyphCanvas;
function hasGlyph(ch) {
  glyphCanvas ||= Object.assign(document.createElement("canvas"), { width: 96, height: 96 });
  const x = glyphCanvas.getContext("2d", { willReadFrequently: true });
  x.clearRect(0, 0, 96, 96); x.font = `64px "MM Emoji Trailer"`; x.textBaseline = "middle"; x.fillStyle = "#000"; x.fillText(ch, 8, 48);
  const d = x.getImageData(0, 0, 96, 96).data; let n = 0;
  for (let i = 3; i < d.length; i += 4) if (d[i] > 60) n++;
  return n > 40;
}
const EMOJI_ICON = { "⚡": "bolt", "🪂": "parachute", "🐑": "sheep", "↕️": "updown", "🍌": "banana", "💰": "moneybag", "🎩": "hat", "🎓": "cap", "🎉": "party", "🌩️": "storm", "🛠️": "tools", "🏃": "runner" };
function monogram(name) {
  const skip = new Set(["der", "die", "das", "am", "oder", "gegen", "von"]);
  const w = name.replace(/[?'’!]/g, "").split(/[\s-]+/).filter(x => x && !skip.has(x.toLowerCase()));
  return (w.length > 1 ? w[0][0] + w[1][0] : w[0].slice(0, 2)).toUpperCase();
}

// ---------------------------------------------------------------- footage / clips
const FOOT = { pages: {}, events: [] };
async function loadJSON(u) { try { const r = await fetch(u); return r.ok ? await r.json() : null; } catch { return null; } }
async function loadFootage() {
  const cfg = EDIT.footage || {};
  if (cfg.prefer === false) return;
  const root = cfg.root || "/projects/sandbox/trailer/footage";
  const ev = await loadJSON(url(`${root}/events.json`));
  FOOT.events = Array.isArray(ev) ? ev : ev?.events || [];
  const pages = new Set();
  const visit = o => { if (!o || typeof o !== "object") return; if (Array.isArray(o)) return o.forEach(visit); if (typeof o.page === "string") pages.add(o.page); Object.values(o).forEach(visit); };
  visit(EDIT.slots);
  for (const p of pages) {
    const idx = await loadJSON(url(`${root}/${p}/index.json`));
    if (idx?.frames?.length) { idx.base = `${root}/${p}/`; idx.frames.sort((a, b) => a.t - b.t); FOOT.pages[p] = idx; }
  }
}
function resolveFrom(spec) {
  if (spec.from != null) return spec.from;
  if (spec.what || spec.cmd) { // anchor on a recorded action: detail.what contains `what` / detail.cmd equals `cmd`
    const pg = spec.scenePage || spec.page;
    const hits = FOOT.events.filter(e => (!pg || e.page === pg) && e.detail && (!spec.what || String(e.detail.what || "").includes(spec.what)) && (!spec.cmd || e.detail.cmd === spec.cmd));
    const ev = hits[spec.nth || 0];
    return ev ? ev.t + (spec.offset || 0) : null;
  }
  if (!spec.scene) return null;
  const pg = spec.scenePage || spec.page;
  const same = FOOT.events.filter(e => e.scene === spec.scene && (!e.page || e.page === pg));
  const any = FOOT.events.filter(e => e.scene === spec.scene);
  const ev = (same.length ? same : any)[spec.nth || 0];
  return ev ? ev.t + (spec.offset || 0) : null;
}
function resolveClip(spec, dur) {
  if (spec?.preferStill && spec.still) return { kind: "still", src: spec.still }; // footage exists but this take is weak
  if (spec?.page && FOOT.pages[spec.page]) {
    const from = resolveFrom(spec);
    if (from != null) {
      const speed = spec.speed ?? 1;
      return { kind: "footage", idx: FOOT.pages[spec.page], from, to: spec.to ?? from + dur * speed, speed, hold: !!spec.hold };
    }
  }
  if (spec?.still) return { kind: "still", src: spec.still };
  return { kind: "none" };
}
/** Source aspect (w/h) of a clip slot: footage size, else the slot's "aspect", else 16:9. */
function clipAspect(spec) {
  if (spec?.page && FOOT.pages[spec.page] && resolveFrom(spec) != null) return FOOT.pages[spec.page].w / FOOT.pages[spec.page].h;
  return spec?.aspect || 16 / 9;
}
/** Taps recorded in events.json (page actions with x/y) inside [from,to], mapped to trailer time. */
function eventTaps(page, idx, from, to, at, speed) {
  // event x/y are CSS px; index w/h are device px (phones/GM are 390×844 CSS recorded @2x = 780×1688)
  const dsf = idx.dsf || (idx.h > idx.w && idx.w >= 600 ? 2 : 1), cw = idx.w / dsf, ch = idx.h / dsf;
  return FOOT.events.filter(e => e.page === page && e.t >= from && e.t <= to && e.detail && e.detail.action === "tap" && e.detail.x != null)
    .map(e => [e.detail.x / cw, e.detail.y / ch, at + (e.t - from) / speed]);
}
const frameFile = f => (typeof f.f === "number" ? String(f.f).padStart(6, "0") + ".jpg" : f.f);
function frameAt(idx, t) {
  const f = idx.frames; let lo = 0, hi = f.length - 1;
  if (t <= f[0].t) return f[0];
  while (lo < hi) { const m = (lo + hi + 1) >> 1; if (f[m].t <= t) lo = m; else hi = m - 1; }
  return f[lo];
}
const clipLog = [];
/** Image/footage layer filling its parent. box = parent size in px (needed for the still-spin crop). */
function clipEl(spec, tIn, tOut, box, name = "") {
  spec = spec || {};
  const wrap = h("div", "clip"), inner = h("div", "fill"), img = h("img");
  const [fx0, fy0] = spec.focus || [0.5, 0.5];
  img.style.objectFit = spec.fit || "cover";
  img.style.objectPosition = `${fx0 * 100}% ${fy0 * 100}%`;
  put(wrap, put(inner, img));
  if (spec.zoom) {
    inner.style.transformOrigin = `${fx0 * 100}% ${fy0 * 100}%`;
    inner.style.setProperty("--z0", spec.zoom[0]); inner.style.setProperty("--z1", spec.zoom[1]);
    A(inner, ["pushIn", tOut - tIn, tIn, E.lin]);
  }
  // segments: [{at, from|scene…, speed, still}] = several source ranges cut together inside one layer
  if (spec.segments) {
    const segs = spec.segments.map((g, k) => {
      const at = g.at ?? tIn, end = k + 1 < spec.segments.length ? spec.segments[k + 1].at : tOut;
      const sub = { page: spec.page, still: spec.still, ...g };
      return { at, end, r: resolveClip(sub, end - at), still: sub.still };
    });
    const foot = segs.some(g => g.r.kind === "footage");
    wrap.taps = [];
    for (const g of segs) {
      clipLog.push({ name: `${name}@${g.at.toFixed(2)}`, kind: g.r.kind, src: g.r.src, page: spec.page, from: g.r.from, to: g.r.to });
      if (g.r.kind === "still") { const pre = new Image(); pre.src = url(g.r.src); decodes.push(pre); }
      if (g.r.kind === "footage" && spec.autoTaps !== false) wrap.taps.push(...eventTaps(spec.page, g.r.idx, g.r.from, g.r.to, g.at, g.r.speed));
    }
    if (!foot) wrap.taps = (spec.taps || []).slice();
    const first = segs[0];
    if (first.r.kind === "still") { img.src = url(first.r.src); decodes.push(img); }
    const pl = { tIn, tOut, img, cur: null, async update(t) {
      let g = segs[0]; for (const x of segs) if (t >= x.at) g = x;
      let src;
      if (g.r.kind === "footage") { const m = clamp(g.r.from + (t - g.at) * g.r.speed, g.r.from, g.r.to); src = url(g.r.idx.base + frameFile(frameAt(g.r.idx, m))); }
      else if (g.r.kind === "still") src = url(g.r.src);
      if (src && src !== pl.cur) { pl.cur = src; img.src = src; try { await img.decode(); } catch (_) {} }
    } };
    players.push(pl);
    return wrap;
  }
  const r = resolveClip(spec, tOut - tIn);
  clipLog.push({ name, kind: r.kind, src: r.src, page: spec.page, from: r.from, to: r.to });
  wrap.taps = r.kind === "footage" ? (spec.autoTaps ?? /^(phone|gm)/.test(spec.page) ? eventTaps(spec.page, r.idx, r.from, r.to, tIn, r.speed) : []) : (spec.taps || []).slice();
  if (r.kind === "still") {
    img.src = url(r.src); decodes.push(img);
    if (spec.spin && box) {
      const layers = [0, 1, 2].map(k => { const sp = h("div", "spin", { opacity: k ? 0.32 / k : 1 }); const im = h("img"); im.src = img.src; im.style.objectFit = img.style.objectFit; im.style.objectPosition = img.style.objectPosition; decodes.push(im); put(sp, im); return sp; });
      layers.slice().reverse().forEach(l => put(inner, l));
      const s = spec.spin, dur = tOut - tIn;
      updaters.push({ t0: tIn - 0.05, t1: tOut + 0.05, run(t) {
        if (!img.naturalWidth) return;
        const sc = Math.max(box.w / img.naturalWidth, box.h / img.naturalHeight), dw = img.naturalWidth * sc, dh = img.naturalHeight * sc;
        const ox = (box.w - dw) * fx0, oy = (box.h - dh) * fy0, cx = ox + s.cx * dw, cy = oy + s.cy * dh, R = s.r * dw;
        const u = clamp((t - tIn) / dur), a = s.deg * easeOutCubic(u), w = (3 * Math.pow(1 - u, 2) * s.deg) / dur; // deg/s
        layers.forEach((l, k) => { l.style.clipPath = `circle(${R}px at ${cx}px ${cy}px)`; l.style.transformOrigin = `${cx}px ${cy}px`; l.style.transform = `rotate(${a - k * w * 0.014}deg)`; });
      } });
    }
  } else if (r.kind === "footage") {
    const pl = { tIn, tOut, img, r, cur: null, async update(t) {
      const m = r.hold ? r.from : clamp(r.from + (t - tIn) * r.speed, r.from, r.to);
      const f = frameAt(r.idx, m), src = url(r.idx.base + frameFile(f));
      if (src !== pl.cur) { pl.cur = src; img.src = src; try { await img.decode(); } catch (_) {} }
    } };
    players.push(pl);
  }
  return wrap;
}

// ---------------------------------------------------------------- building blocks
function scene(id, pre = 0, post = 0) {
  const sc = EDIT.scenes.find(s => s.id === id);
  const el = h("div", "scene"); el.dataset.id = id;
  const rec = { id, in: sc.in, out: sc.out, pre, post, el };
  scenes.push(rec);
  return rec;
}
function nest(parent, n) { const out = []; let p = parent; for (let i = 0; i < n; i++) { const d = h("div", "fill"); p.appendChild(d); out.push(d); p = d; } return out; }
function flashLayerAdd(t, o = 0.85, d = 0.4, color) {
  const f = h("div", "flash", { "--fo": o }); if (color) f.style.background = color;
  A(f, ["flashK", d, t - 0.02, E.out]); put(document.getElementById("flashes"), f);
}
function streak(t, dir = 1) { const s = h("div", "streaks", { scale: dir < 0 ? "-1 1" : "1 1" }); A(s, ["streakK", 0.28, t - 0.04, E.out]); put(document.getElementById("flashes"), s); }
function shock(parent, x, y, t, color, size = 400) {
  const s = h("div", "shock", { left: x + "px", top: y + "px", width: size + "px", height: size + "px", margin: `${-size / 2}px 0 0 ${-size / 2}px` });
  if (color) s.style.borderColor = color;
  A(s, ["shockK", 0.7, t, E.out]); put(parent, s); return s;
}
function beams(parent, specs) {
  for (const b of specs) {
    const el = h("div", "beam" + (b.top ? " top" : ""), { left: b.x - 130 + "px", "--r0": b.r0 + "deg", "--r1": b.r1 + "deg", opacity: b.o ?? 1, width: (b.w || 260) + "px" });
    if (b.color) el.style.background = b.color;
    A(el, ["sway", b.d || 2.4, b.phase ?? -1, E.sine, "infinite", "alternate"]);
    if (b.fadeAt != null) A(el, ["fadeIn", 0.5, b.fadeAt, E.soft]);
    put(parent, el);
  }
}
function leaf(parent, bx, by, s, r, flip = false, style = {}) {
  const el = h("div", "leaf", { left: bx - 40 + "px", top: by - 560 + "px", transformOrigin: "40px 560px", transform: `${flip ? "scaleX(-1) " : ""}scale(${s}) rotate(${r}deg)`, ...style });
  put(parent, el); return el;
}
function glowBlob(parent, x, y, w, hh, color, o = 1) { return put(parent, h("div", "glow", { left: x - w / 2 + "px", top: y - hh / 2 + "px", width: w + "px", height: hh + "px", background: color, opacity: o })).lastChild; }
function iconSvg(key) { return ICONS[key] || ICONS.banana; }
function phone(w) {
  const hh = Math.round(w * 844 / 390) + 26, el = h("div", "phone", { width: w + 26 + "px", height: hh + "px" });
  const screen = h("div", "screen"); put(el, screen, h("div", "island"), h("div", "btn-side"));
  return { el, screen, w: w, h: hh - 26, W: w + 26, H: hh, fill(clip) { put(screen, clip, h("div", "glare", { borderRadius: "52px" })); } };
}
function tap(parent, x, y, t) {
  const el = h("div", "tap", { left: x + "px", top: y + "px" });
  const r1 = h("div", "ring"), r2 = h("div", "ring", { borderWidth: "4px" }), f = h("div", "finger");
  A(r1, ["tapRing", 0.55, t, E.out]); A(r2, ["tapRing", 0.7, t + 0.08, E.out]); A(f, ["tapFinger", 0.62, t - 0.2, E.soft]);
  put(el, r1, r2, f); put(parent, el); return el;
}
function logo(scale = 1) {
  const g = h("div", "logo", { left: "50%", top: "50%", transform: "translate(-50%, -50%)", scale });
  const l1 = h("div", "l1", {}, `MONKEY<span class="shine">MONKEY</span>`);
  const l2 = h("div", "l2", {}, `<span class="g">MONEY</span><span class="shine">MONEY</span>`);
  put(g, l1, l2); return { g, l1, l2 };
}
function coin3d(size) {
  const outer = h("div", "abs", { width: size + "px", height: size + "px", perspective: "900px" });
  const body = h("div", "fill p3d");
  const face = dataUrl(COIN_FACE), edge = dataUrl(COIN_EDGE);
  const im = (src, tf) => { const i = h("img", "fill", { width: "100%", height: "100%", transform: tf }); i.src = src; decodes.push(i); return i; };
  for (let k = 1; k <= 7; k++) put(body, im(edge, `translateZ(${-k * 2.2}px)`));
  const front = im(face, "translateZ(0.5px)"), back = im(face, "translateZ(-16px) rotateY(180deg)");
  put(body, back, front); put(outer, body);
  return { outer, body };
}
function label(parent, cut, tIn) {
  const el = h("div", "label");
  const c = h("div", "coin", {}, iconSvg(cut.icon));
  const txt = h("div", "", { display: "flex", flexDirection: "column" });
  const k = h("div", "kick", {}, cut.kicker || ""), n = h("div", "name", {}, cut.label);
  put(txt, k, n); put(el, c, txt);
  const bd = h("div", "labelBd"); A(bd, ["fadeIn", 0.2, tIn - 0.02, E.out]); put(parent, bd);
  A(c, ["popIn", 0.42, tIn, E.out], ["spinZ", 0.42, tIn, E.out]);
  A(n, ["wipeInL", 0.3, tIn + 0.03, E.out]);
  A(k, ["riseIn", 0.3, tIn + 0.1, E.out]);
  put(parent, el); return el;
}

// ---------------------------------------------------------------- S1 cold open
function buildS1() {
  const S = scene("S1", 0, 0.02), R = S.el, t0 = S.in;
  const [cam] = nest(R, 1);
  // light through the seam + sweeping spotlights
  const core = glowBlob(cam, 960, 540, 900, 700, "radial-gradient(circle, rgba(255,214,120,.9), rgba(255,160,60,.35) 45%, transparent 70%)", 1);
  A(core, ["fadeIn", 0.6, 0.05, E.soft]);
  const halo = glowBlob(cam, 960, 520, 1500, 1000, "radial-gradient(circle, rgba(140,80,255,.55), transparent 65%)");
  A(halo, ["fadeIn", 0.8, 0.2, E.soft]);
  const bl = h("div", "fill"); put(cam, bl);
  beams(bl, [{ x: 360, r0: -32, r1: 18, d: 1.6, phase: -0.3, fadeAt: 0.15 }, { x: 760, r0: 26, r1: -20, d: 1.3, phase: -0.9, fadeAt: 0.2 }, { x: 1160, r0: -24, r1: 22, d: 1.4, phase: -0.2, fadeAt: 0.2 }, { x: 1560, r0: 30, r1: -16, d: 1.7, phase: -1.1, fadeAt: 0.15 },
    { x: 960, top: true, r0: -30, r1: 30, d: 1.5, phase: -0.75, o: 0.9, fadeAt: 0.3 }]);
  // coin (behind logo), logo, tagline
  const coinWrap = h("div", "abs", { left: 960 - 105 + "px", top: 205 + "px", width: "210px", height: "210px", "--fx": "0px", "--fy": "260px" });
  const cn = coin3d(210); put(coinWrap, cn.outer);
  A(coinWrap, ["coinFly", 0.6, bt(-3) - 0.6, E.out]);
  A(cn.body, ["coinSpin", 0.85, bt(-3) - 0.6, "cubic-bezier(.2,.7,.3,1)"]);
  const coinGlow = glowBlob(coinWrap, 105, 105, 420, 420, "radial-gradient(circle, rgba(255,214,90,.75), rgba(255,160,40,.25) 40%, transparent 68%)"); coinWrap.insertBefore(coinGlow, coinWrap.firstChild);
  const coinFloat = h("div", "fill"); put(coinFloat, coinWrap); A(coinFloat, ["floatY", 0.86, bt(-3), E.sine, "infinite", "alternate"]);
  const lg = logo(1); lg.g.style.top = "590px";
  A(lg.l1, ["slamInB", 0.5, bt(-3), E.out]); A(lg.l2, ["slamInB", 0.5, bt(-3) + 0.06, E.out]);
  lg.l1.querySelector(".shine").style.animation = `shineK 0.55s ${E.inout} ${bt(-1) + 0.05}s 1 normal both`;
  lg.l2.querySelector(".shine").style.animation = `shineK 0.55s ${E.inout} ${bt(-1) + 0.12}s 1 normal both`;
  const tag = h("div", "caption", { left: "50%", top: "870px", transform: "translate(-50%, 0)", fontSize: "64px", letterSpacing: "0.04em", position: "absolute" }, fill(T("S1").tagline));
  const rule1 = h("div", "abs", { left: "300px", top: "905px", width: "260px", height: "4px", background: "linear-gradient(90deg,transparent,#FFC93C)", transformOrigin: "100% 50%" });
  const rule2 = h("div", "abs", { left: "1360px", top: "905px", width: "260px", height: "4px", background: "linear-gradient(90deg,#FFC93C,transparent)", transformOrigin: "0 50%" });
  A(tag, ["riseIn", 0.4, bt(-2), E.out]); A(rule1, ["fadeIn", 0.4, bt(-2) + 0.1]); A(rule2, ["fadeIn", 0.4, bt(-2) + 0.1]);
  const group = h("div", "fill"); put(group, coinFloat, lg.g, tag, rule1, rule2); put(cam, group);
  A(group, ["flyTo", 0.2, S.out - 0.19, E.in]); group.style.setProperty("--ts", 1.35); group.style.setProperty("--to", 0);
  shock(cam, 960, 560, bt(-3) + 0.02, null, 520);
  A(cam, ["shake", 0.38, bt(-3), E.lin]);
  // leaves: three parallax depths per side, closed over the frame, parting from the centre seam
  // leaves.svg is a fan (fronds from -75° to +5°) around its stem base; [bx, by, scale, rotate]
  const layers = [
    { px: 760, dur: 0.66, f: "brightness(.8) saturate(1.05)", leaves: [[-20, 540, 2.75, 40], [-30, 250, 2.2, 62], [-30, 850, 2.2, 16], [-60, 1130, 2.0, -4]] },
    { px: 1000, dur: 0.62, f: "brightness(.55) blur(1.5px)", leaves: [[-60, -60, 2.5, 80], [-60, 1140, 2.5, 0], [-80, 560, 2.3, 44]] },
    { px: 1400, dur: 0.58, f: "brightness(.34) blur(5px)", leaves: [[-160, 540, 3.4, 40], [-160, 120, 2.8, 70]] },
  ];
  const partAt = 0.26;
  layers.forEach((L, li) => {
    for (const side of [-1, 1]) {
      const c = h("div", "fill", { "--px": side * L.px + "px", "--py": (li - 1) * 30 + "px" });
      for (const [bx, by, sc, r] of L.leaves) leaf(c, side < 0 ? bx : W - bx, by, sc, r, side > 0, { filter: L.f });
      A(c, ["leafPartL", L.dur, partAt + li * 0.025, "cubic-bezier(.75,0,.25,1)"]);
      put(cam, c);
    }
  });
  put(cam, group);
  fx.sparkBurst(bt(-3), 960, 560, 34, 1);
  flashLayerAdd(bt(-3), 0.75, 0.45);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S2 setup
function buildS2() {
  const S = scene("S2", 0, 0.12), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  put(cam, h("div", "floor"));
  glowBlob(cam, 360, 520, 800, 800, "radial-gradient(circle, rgba(255,107,214,.35), transparent 65%)");
  glowBlob(cam, 1560, 520, 800, 800, "radial-gradient(circle, rgba(95,196,255,.30), transparent 65%)");
  beams(cam, [{ x: 520, top: true, r0: -16, r1: 10, d: 2.2, o: 0.6 }, { x: 1400, top: true, r0: 14, r1: -12, d: 2.6, o: 0.6 }]);
  leaf(cam, -30, 1130, 1.25, 30, false, { filter: "brightness(.55)" }); leaf(cam, W + 30, 1130, 1.25, 30, true, { filter: "brightness(.55)" });
  // stage device
  const sl = slot("S2.tv") || {}, asp = clipAspect(sl);
  const sh = asp > 1.6 ? 600 : 640, sw = Math.round(sh * asp);
  const dev = h("div", "device", { width: sw + 36 + "px", height: sh + 36 + "px", left: 960 - (sw + 36) / 2 + "px", top: 520 - (sh + 36) / 2 + "px" });
  const scr = h("div", "screen"); put(dev, scr); put(scr, clipEl(sl, t0, t1, { w: sw, h: sh }, "S2.tv"), h("div", "glare"));
  const devTilt = h("div", "fill p3d", { "--rx0": "9deg", "--rx1": "4deg", "--ry0": "-13deg", "--ry1": "-5deg" }); put(devTilt, dev);
  A(devTilt, ["tilt3d", t1 - t0, t0, E.lin]);
  const devIn = h("div", "fill"); put(devIn, devTilt); A(devIn, ["rise3d", 0.55, t0, E.back]);
  A(devIn, ["zoomThrough", 0.2, t1 - 0.14, E.in]);
  put(cam, devIn);
  // phones
  const mk = (key, side, at) => {
    const ph = phone(290), s = slot(key);
    const ce = clipEl(s, t0, t1, { w: ph.w, h: ph.h }, key); ph.fill(ce);
    for (const [x, y, tt] of ce.taps) tap(ph.screen, x * ph.w, y * ph.h, tt);
    const cx = side < 0 ? 250 : W - 250;
    const pos = h("div", "abs", { left: cx - ph.W / 2 + "px", top: 575 - ph.H / 2 + "px", width: ph.W + "px", height: ph.H + "px",
      transform: `perspective(1600px) rotateY(${-side * 16}deg) rotateZ(${side * 6}deg)` });
    put(pos, ph.el);
    const mv = h("div", "fill", { "--fx": side * 700 + "px", "--fy": "140px", "--fr": side * 30 + "deg", "--fs": 0.9 }); put(mv, pos);
    A(mv, ["flyFrom", 0.42, at, E.back], ["flyTo", 0.16, t1 - 0.13, E.in]);
    mv.style.setProperty("--tx", side * 900 + "px"); mv.style.setProperty("--to", 1);
    const bl = h("div", "fill"); put(bl, mv); A(bl, ["glow", 0.3, at + 0.18]);
    put(cam, bl);
    streak(at, -side);
    return { cx, ph };
  };
  const pl = mk("S2.phoneL", -1, bt(1)), pr = mk("S2.phoneR", 1, bt(2));
  // monkeys hop from the phones onto the stage (x: linear drift, y: up then down → arc)
  (slot("S2.monkeys") || []).slice(0, 2).forEach((m, i) => {
    const from = i ? pr.cx : pl.cx, at = bt(3 + i), tx = 960 + (i ? 200 : -200), dur = 0.5;
    const ox = h("div", "abs", { left: from - 70 + "px", top: "400px", width: "140px", height: "187px", "--dx0": "0px", "--dx1": tx - from + "px" });
    const up = h("div", "fill", { "--dy0": "0px", "--dy1": "-230px" }), down = h("div", "fill", { "--dy0": "0px", "--dy1": "250px" });
    const im = monkeyImg(m, "jubel", { width: "140px", height: "187px" });
    put(ox, put(up, im)); put(down, ox);
    A(ox, ["drift", dur, at, E.lin], ["fadeIn", 0.08, at], ["fadeOut", 0.1, at + dur - 0.06]);
    A(up, ["drift", dur / 2, at, E.out]); A(down, ["drift", dur / 2, at + dur / 2, E.in]);
    A(im, ["popIn", 0.3, at, E.out], ["spinZ", dur, at, E.lin]);
    put(cam, down);
    fx.sparkBurst(at + dur - 0.04, tx, 640, 16, 0.7);
  });
  // captions
  const tx = T("S2");
  const top = h("div", "title t-cream", { position: "absolute", left: "50%", top: "86px", transform: "translate(-50%, 0)", fontSize: "88px", whiteSpace: "nowrap" }, fill(tx.top));
  A(top, ["dropIn", 0.4, t0 + 0.12, E.back], ["fadeOut", 0.12, t1 - 0.1]);
  const row = h("div", "abs", { left: "50%", top: "900px", transform: "translate(-50%, 0)", display: "flex", alignItems: "center", gap: "30px" });
  const cap = h("div", "caption", { fontSize: "64px", fontWeight: 900 }, fill(tx.bottom));
  const stamp = h("div", "pill", { fontSize: "56px", background: "linear-gradient(180deg,#6ff0ae,#2BD98A 50%,#17b56c)", color: "#04241a", boxShadow: "0 6px 0 #0f7a4a, 0 0 40px rgba(43,217,138,.6)", rotate: "-4deg" },
    `<svg viewBox="0 0 100 100" width="54" height="54"><path d="M18 52 L40 74 L84 26" fill="none" stroke="#04241a" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/></svg>${fill(tx.stamp)}`);
  put(row, cap, stamp);
  A(cap, ["wipeInL", 0.34, bt(2), E.out]); A(stamp, ["slamSmall", 0.4, bt(4), E.out]);
  A(row, ["fadeOut", 0.12, t1 - 0.1]);
  put(cam, top, row);
  shock(cam, 1330, 945, bt(4) + 0.03, "rgba(43,217,138,.9)", 260);
  flashLayerAdd(t0, 0.7, 0.35);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S3 / S8 fast cuts
function screenCard(parent, spec, tIn, tOut, k, name, strong = 1) {
  const cw = 1776, ch = 999;
  const card = h("div", "screencard", { left: (W - cw) / 2 + "px", top: (H - ch) / 2 + "px", width: cw + "px", height: ch + "px" });
  put(card, clipEl(spec, tIn, tOut, { w: cw, h: ch }, name));
  const side = k % 2 ? -1 : 1;
  const tilt = h("div", "fill p3d", { "--rx0": `${2 * strong}deg`, "--rx1": "0deg", "--ry0": `${side * 6 * strong}deg`, "--ry1": `${-side * 1.5}deg`, "--rz0": `${-side * 1.2 * strong}deg`, "--rz1": "0deg" });
  put(tilt, card); A(tilt, ["tilt3d", tOut - tIn + 0.15, tIn, E.out]);
  const whip = h("div", "fill", { "--wx": side * 520 * strong + "px" }); put(whip, tilt);
  A(whip, ["whipIn", 0.18, tIn, E.out]);
  const bump = h("div", "fill"); put(bump, whip);
  const beatsIn = Math.round((tOut - tIn) / P);
  if (beatsIn >= 2) A(bump, ["pulse", 0.22, tIn + P, E.out]);
  put(parent, bump);
  return { card, cw, ch };
}
function buildS3() {
  const S = scene("S3", 0, 0), R = S.el;
  const cuts = slot("S3.cuts");
  const bg = h("div", "fill"); put(R, bg);
  glowBlob(bg, 960, 540, 1800, 1100, "radial-gradient(circle, rgba(123,63,255,.45), transparent 70%)");
  let labelHost = null;
  const shots = h("div", "fill"), labels = h("div", "fill"); put(R, shots, labels);
  cuts.forEach((c, i) => {
    const tIn = c.at, tOut = i + 1 < cuts.length ? cuts[i + 1].at : S.out;
    const shot = h("div", "fill"); shot.dataset.in = tIn; shot.dataset.out = tOut;
    const [cam] = nest(shot, 1);
    const sc = screenCard(cam, c.clip, tIn, tOut, i, `S3.cuts[${i}]`);
    put(sc.card, h("div", "scrim"));
    if (c.phone) {
      const ph = phone(300);
      const ce = clipEl({ taps: c.taps, ...c.phone }, tIn, tOut, { w: ph.w, h: ph.h }, `S3.cuts[${i}].phone`); ph.fill(ce);
      for (const [x, y, tt] of ce.taps) tap(ph.screen, x * ph.w, y * ph.h, tt);
      const pos = h("div", "abs", { left: 1440 + "px", top: 170 + "px", transform: "perspective(1600px) rotateY(-14deg) rotateZ(5deg)" });
      put(pos, ph.el);
      const mv = h("div", "fill", { "--fx": "0px", "--fy": "900px", "--fr": "12deg", "--fs": 1 }); put(mv, pos);
      A(mv, ["flyFrom", 0.3, tIn + 0.02, E.back]);
      put(cam, mv);
    }
    if (c.money) {
      const m = h("div", "money t-gold", { left: "50%", top: "360px", transform: "translate(-50%, -50%)" }, c.money);
      A(m, ["slamSmall", 0.4, tIn + P * 0.5, E.out], ["flyTo", 0.3, tOut - 0.26, E.in]);
      m.style.setProperty("--ty", "-200px"); m.style.setProperty("--to", 0);
      put(document.getElementById("over"), m); // above the #fx canvas so the coin burst flies behind the number
      fx.moneyBurst(tIn + P * 0.5, 960, 470, 70);
      shock(cam, 960, 380, tIn + P * 0.5, null, 360);
    }
    if (!c.keepLabel) { labelHost = h("div", "fill"); labelHost.dataset.in = tIn; labelHost.dataset.out = tOut; label(labelHost, c, tIn + 0.04); }
    else labelHost.dataset.out = tOut;
    put(shots, shot);
    if (!c.keepLabel) put(labels, labelHost);
    flashLayerAdd(tIn, 0.32, 0.25); streak(tIn, i % 2 ? 1 : -1);
  });
  // shots/labels only show inside their own window
  updaters.push({ t0: S.in - 1, t1: S.out + 1, run(t) { for (const el of R.querySelectorAll(":scope > div > [data-in]")) el.style.display = t >= +el.dataset.in && t < +el.dataset.out ? "" : "none"; } });
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S4 format wall
function buildS4() {
  const S = scene("S4", 0, 0.02), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  const rays = h("div", "rays", { opacity: 0.55 }); A(rays, ["spinZ", 40, -5, E.lin, "infinite"]); put(cam, rays);
  beams(cam, [{ x: 300, r0: -20, r1: 14, d: 2.1, o: 0.5 }, { x: 1620, r0: 18, r1: -16, d: 2.4, o: 0.5 }]);
  const cam2 = put(cam, h("div", "fill")).lastChild;
  const view = h("div", "fill", { perspective: "1700px", perspectiveOrigin: "50% 45%" });
  const plane = h("div", "fill p3d", { "--rx0": "24deg", "--rx1": "12deg", "--ry0": "-16deg", "--ry1": "9deg", "--rz0": "-5deg", "--rz1": "-2deg" });
  // tilt3d uses its own perspective; neutralise by animating a wrapper instead
  const wall = h("div", "abs p3d", { left: "0", top: "0", width: W + "px", height: H + "px" });
  put(plane, wall); put(view, plane); put(cam2, view);
  A(plane, ["tilt3d", t1 - t0, t0, E.lin]);
  const rows = [6, 7, 7, 7, 6], tw = 250, th = 128, gap = 22;
  const pal = [["#7C4DFF", "#3b1c8c"], ["#FF6BD6", "#8a1f74"], ["#2BD98A", "#0f6b50"], ["#5FC4FF", "#1d4f99"], ["#FFC93C", "#a0600a"], ["#FF4D6D", "#8a1330"], ["#2ED3C6", "#0d6b66"]];
  const fmts = DATA.formats;
  let idx = 0; const tiles = [];
  rows.forEach((n, r) => {
    const rw = n * tw + (n - 1) * gap, x0 = (W - rw) / 2, y = (H - (rows.length * th + (rows.length - 1) * gap)) / 2 + r * (th + gap) - 10;
    for (let c = 0; c < n && idx < fmts.length; c++, idx++) {
      const f = fmts[idx], [c1, c2] = pal[idx % pal.length];
      const tile = h("div", "tile", { left: x0 + c * (tw + gap) + "px", top: y + "px", "--c1": c1, "--c2": c2 });
      let ico;
      if (hasGlyph(f.emoji)) ico = h("div", "ico emoji", {}, f.emoji);
      else if (EMOJI_ICON[f.emoji]) ico = h("div", "ico", {}, iconSvg(EMOJI_ICON[f.emoji]).replace("<svg ", '<svg width="50" height="50" '));
      else ico = h("div", "ico mono", {}, monogram(f.name));
      put(tile, ico, h("div", "nm", {}, f.name));
      const cx = x0 + c * (tw + gap) + tw / 2 - W / 2, cy = y + th / 2 - H / 2;
      tiles.push({ tile, d: Math.hypot(cx / 1.6, cy), c: x0 + c * (tw + gap) });
      put(wall, tile);
    }
  });
  const order = tiles.slice().sort((a, b) => a.d - b.d);
  const flipAt = [];
  order.forEach((o, k) => { const at = t0 + 0.06 + k * 0.034; flipAt.push(at + 0.2); A(o.tile, ["tileFlip", 0.55, at, E.out]); });
  tiles.forEach(o => A(o.tile, ["glow", 0.5, bt(21) + (o.c / W) * 0.6, E.soft]));
  A(view, ["dimBlur", 0.35, bt(20) - 0.1, E.soft]);
  // counter
  const plate = glowBlob(cam, 960, 520, 1200, 700, "radial-gradient(closest-side, rgba(13,8,34,.92), rgba(13,8,34,.6) 60%, transparent 100%)");
  plate.style.filter = "blur(10px)"; plate.style.mixBlendMode = "normal"; A(plate, ["fadeIn", 0.3, bt(20) - 0.15]);
  put(cam, plate);
  const cnt = h("div", "title t-gold", { position: "absolute", left: "50%", top: "400px", transform: "translate(-50%, -50%)", fontSize: "330px" }, "0");
  const cntWrap = h("div", "fill"); put(cntWrap, cnt);
  A(cnt, ["fadeIn", 0.2, t0 + 0.15], ["counterSlam", 0.45, bt(20), E.out]); A(cntWrap, ["glow", 0.45, bt(20)]);
  const lab = h("div", "title t-cream", { position: "absolute", left: "50%", top: "660px", transform: "translate(-50%, -50%)", fontSize: "132px", whiteSpace: "nowrap" }, fill(T("S4").label));
  A(lab, ["wipeInR", 0.36, bt(20) + 0.04, E.out]);
  put(cam, cntWrap, lab);
  A(cam, ["zoomThrough", 0.2, t1 - 0.17, E.in]);
  updaters.push({ t0, t1: t1 + 0.1, run(t) { cnt.textContent = String(flipAt.filter(a => a <= t).length); } });
  shock(cam, 960, 420, bt(20) + 0.02, null, 600);
  flashLayerAdd(bt(20), 0.8, 0.45); flashLayerAdd(t0, 0.6, 0.3);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S5 questions
function buildS5() {
  const S = scene("S5", 0, 0.02), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  glowBlob(cam, 960, 420, 1600, 900, "radial-gradient(circle, rgba(95,196,255,.28), transparent 65%)");
  beams(cam, [{ x: 420, top: true, r0: -12, r1: 14, d: 2.6, o: 0.55 }, { x: 1500, top: true, r0: 12, r1: -14, d: 2.2, o: 0.55 }]);
  const cam2 = put(cam, h("div", "fill")).lastChild;
  const back = h("div", "fill"), mid = h("div", "fill"), front = h("div", "fill");
  put(cam2, back, mid, front);
  // odometer
  const N = DATA.questionCount, digits = fmt(N).split("");
  const odo = h("div", "odo", { fontSize: "250px" });
  const cols = [];
  digits.forEach(ch => {
    if (ch === ".") { put(odo, h("div", "sep", {}, '<span class="dg">.</span>')); return; }
    const col = h("div", "col"), strip = h("div", "strip", {}, Array.from({ length: 11 }, (_, i) => `<span class="dg">${i % 10}</span>`).join(""));
    put(col, strip); put(odo, col); cols.push(strip);
  });
  const line = h("div", "abs", { left: "50%", top: "390px", transform: "translate(-50%, -50%)", display: "flex", alignItems: "baseline", gap: "40px" });
  const fr = h("div", "title t-cream", { fontSize: "150px" }, fill(T("S5").label));
  put(line, odo, fr); const lineWrap = h("div", "fill"); put(mid, put(lineWrap, line));
  A(line, ["slamSmall", 0.4, t0, E.out]); A(lineWrap, ["counterSlam", 0.45, bt(27), E.out]); lineWrap.style.transformOrigin = "960px 390px";
  const rollEnd = bt(27) - 0.02;
  updaters.push({ t0: t0 - 0.1, t1: t1 + 0.1, run(t) {
    const v = N * easeOutExpo(clamp((t - t0) / (rollEnd - t0)));
    const places = cols.length; let carry = v - Math.floor(v); // odometer: a column only turns while all lower ones show 9
    for (let k = 0; k < places; k++) {
      const d = Math.floor(v / Math.pow(10, k)) % 10;
      cols[places - 1 - k].style.transform = `translateY(${-(d + carry)}em)`;
      if (d !== 9) carry = 0;
    }
  } });
  // orbit of category icons
  const cats = DATA.categories, orbs = cats.map((c, i) => {
    const o = h("div", "orb", { "--c": c.farbe === "#111111" ? "#3b3b52" : c.farbe, color: "#fff" }, (SVG_TEXT[c.icon] || "").replace("<svg ", '<svg width="76" height="76" '));
    return { o, base: (i / cats.length) * Math.PI * 2 };
  });
  updaters.push({ t0: t0 - 0.1, t1: t1 + 0.1, run(t) {
    const cx = 960, cy = 395;
    orbs.forEach((b, i) => {
      const e = easeOutBack(clamp((t - t0 - 0.05 - i * 0.03) / 0.65));
      const out = clamp((t - (t1 - 0.2)) / 0.2);
      const a = b.base + 0.55 * (t - t0) + 0.6, rad = Math.max(0, e) * (1 + out * 0.8);
      const x = cx + Math.cos(a) * 840 * rad, y = cy + Math.sin(a) * 250 * rad, d = Math.sin(a);
      const s = (0.68 + 0.42 * (d + 1) / 2) * Math.min(1, Math.max(0, e) * 1.2);
      b.o.style.left = x + "px"; b.o.style.top = y + "px"; b.o.style.transform = `scale(${s})`;
      b.o.style.opacity = String((0.45 + 0.55 * (d + 1) / 2) * (1 - out));
      b.o.style.filter = d < -0.2 ? `blur(${(-d - 0.2) * 3}px) brightness(.75)` : "";
      const host = d > 0 ? front : back; if (b.o.parentNode !== host) host.appendChild(b.o);
    });
  } });
  // lines
  const tx = T("S5");
  const l1 = h("div", "abs", { left: "50%", top: "770px", transform: "translate(-50%, -50%)", display: "flex", gap: "34px", alignItems: "center" });
  tx.line.map(fill).forEach((s, i) => {
    if (i) { const dot = h("div", "caption", { fontSize: "72px", color: "#FFC93C" }, "·"); A(dot, ["popIn", 0.3, bt(26) + i * 0.2]); put(l1, dot); }
    const p = h("div", "caption", { fontSize: "76px", fontWeight: 900 }, s.replace(/^(\d+)/, '<span style="color:#FFC93C">$1</span>'));
    A(p, ["riseIn", 0.35, bt(26) + i * P * 0.5, E.out]); put(l1, p);
  });
  put(front, l1);
  const l2 = h("div", "abs", { left: "50%", top: "905px", transform: "translate(-50%, -50%)", display: "flex", gap: "22px", alignItems: "center" });
  const [von, bis] = String(tx.range || "von leicht bis").split(/\s+leicht\s+/);
  const vonEl = h("div", "caption", { fontSize: "56px" }, von || "von"); put(l2, vonEl); A(vonEl, ["fadeIn", 0.3, bt(27)]);
  DATA.difficulties.forEach((d, i) => {
    if (i === DATA.difficulties.length - 1) { const b = h("div", "caption", { fontSize: "56px" }, bis || "bis"); A(b, ["fadeIn", 0.3, bt(27)]); put(l2, b); }
    const p = h("div", "pill diff", { "--c": d.color }, d.name);
    const lit = h("div", "lit", {}, d.name); put(p, lit);
    const pw = h("div", "", {}), pg = h("div", "", {}); put(l2, put(pw, put(pg, p)));
    A(pw, ["riseIn", 0.3, bt(27) + i * 0.04, E.out]);
    A(lit, ["popIn", 0.3, bt(28 + i), E.out]);
    if (d.glitch) {
      A(p, ["glitch", 0.28, bt(28 + i) + 0.02, E.lin, 2]); A(pg, ["glitch", 0.24, bt(28 + i) + 0.85, E.lin, 1]);
      const g2 = h("div", "lit", { background: "transparent", boxShadow: "none", color: "#00e5ff", mixBlendMode: "screen" }, d.name);
      A(g2, ["glitchClip", 0.3, bt(28 + i), "steps(6)", 3], ["fadeIn", 0.05, bt(28 + i)]); put(p, g2);
    }
  });
  put(front, l2);
  A(cam2, ["shake", 0.3, bt(31), E.lin]);
  A(cam, ["zoomThrough", 0.18, t1 - 0.15, E.in]);
  flashLayerAdd(t0, 0.6, 0.3); flashLayerAdd(bt(27), 0.5, 0.35); flashLayerAdd(bt(31), 0.35, 0.2, "radial-gradient(circle, rgba(255,77,109,.9), transparent 70%)");
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S6 show modes
function buildS6() {
  const S = scene("S6", 0, 0.02), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  glowBlob(cam, 960, 700, 1900, 900, "radial-gradient(circle, rgba(255,107,214,.30), transparent 65%)");
  put(cam, h("div", "floor"));
  beams(cam, [{ x: 260, r0: -26, r1: 10, d: 1.8, o: 0.7 }, { x: 960, top: true, r0: -24, r1: 24, d: 2.0, o: 0.6 }, { x: 1660, r0: 24, r1: -12, d: 1.9, o: 0.7 }]);
  const title = h("div", "title", { position: "absolute", left: "50%", top: "160px", transform: "translate(-50%, -50%)", fontSize: "150px", whiteSpace: "nowrap" });
  const tt = fill(T("S6").title), m = tt.match(/^(\d+)\s*(.*)$/);
  title.innerHTML = m ? `<span class="t-gold">${m[1]}</span> <span class="t-cream">${m[2]}</span>` : `<span class="t-cream">${tt}</span>`;
  A(title, ["slamIn", 0.45, t0 + 0.02, E.out], ["flyTo", 0.18, t1 - 0.16, E.in]); title.style.setProperty("--ty", "-300px");
  const hand = h("div", "fill"); put(cam, hand, title);
  const order = slot("S6.order") || [], rank = m => (order.indexOf(m.id) + 1 || 99);
  const modes = DATA.modes.slice().sort((a, b) => rank(a) - rank(b)), n = modes.length, mid = (n - 1) / 2;
  modes.forEach((md, i) => {
    const k = i - mid, x = 960 + k * 240 - 135, y = 385 + k * k * 10;
    const card = h("div", "card", { left: x + "px", top: y + "px", "--c": md.color, rotate: k * 4 + "deg" });
    const big = h("div", "big", {}, hasGlyph(md.emoji) && !md.icon ? `<span class="emoji" style="font-size:100px">${md.emoji}</span>` : iconSvg(md.icon));
    const mn = h("div", "min", {}, md.minutes);
    put(card, big, h("div", "nm", {}, md.name), mn);
    const fan = h("div", "fill", { "--fx": -k * 240 + "px", "--fy": "520px", "--fr": -k * 4 + "deg" }); put(fan, card);
    const at = t0 + 0.14 + i * 0.07;
    A(fan, ["cardFan", 0.5, at, E.back]);
    A(mn, ["popIn", 0.3, at + 0.35, E.out]);
    A(big, ["popIn", 0.35, at + 0.12, E.out]);
    A(card, ["bump", 0.34, bt(36) + i * 0.09, E.out], ["glow", 0.4, bt(36) + i * 0.09]);
    fan.style.setProperty("--tx", "0px"); fan.style.setProperty("--ty", "-1300px"); fan.style.setProperty("--tr", k * 14 + "deg");
    A(fan, ["flyTo", 0.22, t1 - 0.2 + Math.abs(k) * 0.01, E.in]);
    put(hand, fan);
  });
  flashLayerAdd(t0, 0.85, 0.4); streak(t0, 1);
  shock(cam, 960, 160, t0 + 0.05, null, 420);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S7 Game-Master
function buildS7() {
  const S = scene("S7", 0, 0.02), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  glowBlob(cam, 560, 560, 1100, 1100, "radial-gradient(circle, rgba(255,201,60,.30), rgba(255,107,214,.18) 40%, transparent 68%)");
  beams(cam, [{ x: 560, top: true, r0: -14, r1: 14, d: 2.4, o: 0.8, w: 420 }, { x: 1500, r0: 20, r1: -16, d: 2.0, o: 0.5 }]);
  leaf(cam, -60, 1150, 1.4, 24, false, { filter: "brightness(.5) blur(1px)" });
  const s = slot("S7.gm") || {};
  const ph = phone(420);
  const ce = clipEl(s, t0, t1, { w: ph.w, h: ph.h }, "S7.gm"); ph.fill(ce);
  const taps = ce.taps;
  taps.forEach(([x, y, tt]) => tap(ph.screen, x * ph.w, y * ph.h, tt));
  const px = 520, py = 548;
  const tilt = h("div", "abs p3d", { left: px - ph.W / 2 + "px", top: py - ph.H / 2 + "px", width: ph.W + "px", height: ph.H + "px", "--rx0": "8deg", "--rx1": "2deg", "--ry0": "22deg", "--ry1": "10deg", "--rz0": "-5deg", "--rz1": "-2deg" });
  put(tilt, ph.el); A(tilt, ["tilt3d", t1 - t0, t0, E.out]);
  const rise = h("div", "fill"); put(rise, tilt); A(rise, ["rise3d", 0.5, t0, E.back], ["flyTo", 0.2, t1 - 0.18, E.in]);
  rise.style.setProperty("--tx", "-700px"); rise.style.setProperty("--to", 1);
  put(cam, rise);
  const tx = T("S7");
  const pre = h("div", "title t-cream", { position: "absolute", left: "930px", top: "150px", fontSize: "88px", whiteSpace: "nowrap" }, fill(tx.pre));
  const ttl = h("div", "title t-gold", { position: "absolute", left: "925px", top: "250px", fontSize: "140px", whiteSpace: "nowrap", transformOrigin: "0 50%" }, fill(tx.title));
  A(pre, ["wipeInR", 0.32, t0 + 0.12, E.out]); A(ttl, ["slamSmall", 0.42, bt(40), E.out]);
  const texts = h("div", "fill"); put(texts, pre, ttl); put(cam, texts);
  A(texts, ["flyTo", 0.18, t1 - 0.16, E.in]); texts.style.setProperty("--tx", "600px"); texts.style.setProperty("--to", 0);
  shock(cam, 1370, 330, bt(40) + 0.03, null, 420);
  (tx.chips || []).forEach((c, i) => {
    const at = bt(41 + i), cx = 935 + (i % 2) * 150, cy = 480 + i * 132;
    const chip = h("div", "chip", { left: cx + "px", top: cy + "px", "--c": c.color }, `<div class="ci">${iconSvg(c.icon)}</div>${c.text}`);
    const near = taps.slice().sort((a, b) => Math.abs(a[2] - at) - Math.abs(b[2] - at))[0];
    const tp = near && Math.abs(near[2] - at) < 0.6 ? [px - ph.W / 2 + 13 + near[0] * ph.w, py - ph.H / 2 + 13 + near[1] * ph.h] : [px, py];
    const fly = h("div", "fill", { "--fx": tp[0] - (cx + 200) + "px", "--fy": tp[1] - (cy + 60) + "px", "--fs": 0.2, "--fr": "-12deg" });
    put(fly, chip); A(fly, ["flyFrom", 0.42, at, E.back]);
    A(chip, ["glow", 0.5, at + 0.35]);
    put(texts, fly);
    fx.sparkBurst(at + 0.3, cx + 220, cy + 60, 10, 0.5);
  });
  flashLayerAdd(t0, 0.7, 0.35);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S8 climax
function buildS8() {
  const S = scene("S8", 0, 0), R = S.el, t0 = S.in, t1 = S.out;
  const cuts = slot("S8.cuts"), cele = (slot("S8.celebrate") || {}).at || bt(51);
  cuts.forEach((c, i) => {
    const tIn = c.at, tOut = i + 1 < cuts.length ? cuts[i + 1].at : cele;
    const shot = h("div", "fill"); shot.dataset.in = tIn; shot.dataset.out = tOut;
    const [cam] = nest(shot, 1);
    const sc = screenCard(cam, c.clip, tIn, tOut, i + 1, `S8.cuts[${i}]`, 1.3);
    if (c.kicker) {
      const k = h("div", "pill", { position: "absolute", left: "120px", top: "90px", fontSize: "58px", background: "linear-gradient(180deg,#ffd964,#FFC93C 45%,#FF9F1C)", color: "#1A1208", boxShadow: "0 6px 0 #b7780b, 0 14px 30px rgba(0,0,0,.45)" }, c.kicker);
      A(k, ["wipeInL", 0.22, tIn + 0.02, E.out]); put(cam, k);
    }
    A(cam, ["shake", 0.25, tIn, E.lin]);
    put(R, shot);
    flashLayerAdd(tIn, 0.45, 0.22); streak(tIn, i % 2 ? 1 : -1);
  });
  // celebration
  const cel = h("div", "fill"); cel.dataset.in = cele; cel.dataset.out = t1 + 0.01;
  const cam = put(cel, h("div", "fill")).lastChild;
  const last = cuts[cuts.length - 1];
  const blurBg = h("div", "fill", { filter: "blur(14px) brightness(.45) saturate(1.2)", scale: "1.1" });
  put(blurBg, clipEl((slot("S8.celebrate") || {}).bg || last.clip, cele, t1, { w: W, h: H }, "S8.celebrate.bg")); put(cam, blurBg);
  const rays = h("div", "rays", { opacity: 0.9 }); A(rays, ["spinZ", 9, cele - 3, E.lin, "infinite"], ["popIn", 0.5, cele, E.out]); put(cam, rays);
  glowBlob(cam, 960, 470, 1500, 900, "radial-gradient(circle, rgba(255,201,60,.5), transparent 62%)");
  const cam2 = put(cel, h("div", "fill")).lastChild;
  const jp = h("div", "title t-gold", { position: "absolute", left: "50%", top: "420px", transform: "translate(-50%, -50%)", fontSize: "300px", whiteSpace: "nowrap" }, fill(T("S8").slam));
  A(jp, ["slamIn", 0.5, cele, E.out]);
  const jpWrap = h("div", "fill", { transformOrigin: "960px 420px" }); put(jpWrap, jp); put(cam2, jpWrap); A(jpWrap, ["pulse", P, bt(52), E.out, 3]);
  shock(cam2, 960, 420, cele + 0.02, null, 700); shock(cam2, 960, 420, cele + 0.14, "rgba(255,107,214,.8)", 500);
  const ms = slot("S8.monkeys") || [];
  ms.forEach((m, i) => {
    const x = 60 + i * (1800 / Math.max(1, ms.length - 1)) - 150 + (i === 0 ? 40 : i === ms.length - 1 ? -40 : 0);
    const mk = monkeyImg(m, "jubel", { left: x + "px", top: 1080 - 400 + 70 + (i % 2) * 30 + "px", "--r0": (i % 2 ? 20 : -20) + "deg", transformOrigin: "50% 100%" });
    const hop = h("div", "fill"); put(hop, mk);
    A(mk, ["jumpIn", 0.5, cele + 0.1 + (i % 4) * 0.06, E.out]);
    A(hop, ["jump", P, bt(52) + (i % 2) * P * 0.5, E.soft, 4]);
    put(cam2, hop);
  });
  A(cam2, ["shake", 0.4, cele, E.lin]);
  fx.confetti(cele, 1.3, t1 + 0.1, 0.4); // carries over the cut into S9, then clears before the tagline
  flashLayerAdd(cele, 1, 0.5);
  put(R, cel);
  updaters.push({ t0: t0 - 1, t1: t1 + 1, run(t) { for (const el of R.querySelectorAll(":scope > [data-in]")) el.style.display = t >= +el.dataset.in && t < +el.dataset.out ? "" : "none"; } });
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- S9 end card
function buildS9() {
  const S = scene("S9", 0, 0.1), R = S.el, t0 = S.in, t1 = S.out;
  const [cam] = nest(R, 1);
  glowBlob(cam, 960, 420, 1500, 900, "radial-gradient(circle, rgba(255,201,60,.32), rgba(123,63,255,.25) 45%, transparent 68%)");
  const rays = h("div", "rays", { opacity: 0.35, top: "40%" }); A(rays, ["spinZ", 30, -10, E.lin, "infinite"]); put(cam, rays);
  beams(cam, [{ x: 420, r0: -24, r1: 12, d: 2.2, o: 0.7 }, { x: 1500, r0: 22, r1: -14, d: 2.4, o: 0.7 }]);
  put(cam, h("div", "floor"));
  leaf(cam, -40, 1120, 1.3, 26, false, { filter: "brightness(.55)" }); leaf(cam, W + 40, 1120, 1.3, 26, true, { filter: "brightness(.55)" });
  leaf(cam, -140, 1180, 2.2, 40, false, { filter: "brightness(.28) blur(5px)" }); leaf(cam, W + 140, 1180, 2.2, 40, true, { filter: "brightness(.28) blur(5px)" });
  // logo + coin
  const cWrap = h("div", "abs", { left: 960 - 80 + "px", top: "70px", width: "160px", height: "160px" });
  const cn = coin3d(160); put(cWrap, cn.outer); A(cn.body, ["coinSpin", 0.8, t0, "cubic-bezier(.2,.7,.3,1)"]); A(cWrap, ["popIn", 0.4, t0, E.out]);
  const lg = logo(1); lg.g.style.top = "400px";
  A(lg.g, ["slamInB", 0.5, t0, E.out]);
  const lgHold = h("div", "fill", { scale: 0.8, transformOrigin: "960px 400px" }); put(lgHold, lg.g);
  lg.l1.querySelector(".shine").style.animation = `shineK 0.6s ${E.inout} ${bt(58)}s 1 normal both`;
  lg.l2.querySelector(".shine").style.animation = `shineK 0.6s ${E.inout} ${bt(58) + 0.08}s 1 normal both`;
  put(cam, cWrap, lgHold);
  shock(cam, 960, 400, t0 + 0.02, null, 560);
  const tx = T("S9");
  const tl = h("div", "abs", { left: "50%", top: "735px", transform: "translate(-50%, -50%)", display: "flex", gap: "40px", whiteSpace: "nowrap" });
  const a = h("div", "title t-cream", { fontSize: "118px" }, fill(tx.tagline[0])), b = h("div", "title t-gold", { fontSize: "118px" }, fill(tx.tagline[1]));
  A(a, ["wipeInL", 0.34, bt(55), E.out]); A(b, ["slamSmall", 0.4, bt(56), E.out]);
  put(tl, a, b); put(cam, tl);
  const small = h("div", "caption", { position: "absolute", left: "50%", top: "905px", transform: "translate(-50%, -50%)", fontSize: "52px", fontWeight: 700, color: "rgba(255,246,227,.9)" }, fill(tx.small));
  A(small, ["riseIn", 0.4, bt(57), E.out]); put(cam, small);
  (slot("S9.monkeys") || []).forEach((m, i) => {
    const mk = monkeyImg(m, "jubel", { left: (i ? W - 330 : 30) + "px", top: "600px", "--r0": (i ? 25 : -25) + "deg", transformOrigin: "50% 100%" });
    A(mk, ["jumpIn", 0.5, bt(55 + i), E.out]);
    const hop = h("div", "fill"); put(hop, mk); A(hop, ["jump", P, bt(56 + i), E.soft, 3]);
    put(cam, hop);
  });
  A(cam, ["shake", 0.3, t0, E.lin]);
  fx.bananaRain(t0 + 0.05, t1, false, true); bgfx.bananaRain(t0 + 0.05, t1, true); // front layer stays off the logo/tagline
  flashLayerAdd(t0, 1, 0.5); flashLayerAdd(bt(58), 0.35, 0.3);
  put(document.getElementById("scenes"), R);
}

// ---------------------------------------------------------------- init / render
async function init() {
  const q = new URLSearchParams(location.search);
  [EDIT, DATA] = await Promise.all([loadJSON("edit.json"), loadJSON("data.json")]);
  P = 60 / EDIT.beat.bpm; T0 = EDIT.beat.t0;
  DATA.formatCount = DATA.formats.length;
  await loadFootage();
  const st = document.getElementById("stage");
  put(st, h("div", "night"), Object.assign(h("canvas", "", {}), { id: "bgfx", width: W, height: H }), Object.assign(h("div", "fill"), { id: "scenes" }),
    Object.assign(h("canvas", "", {}), { id: "fx", width: W, height: H }), Object.assign(h("div", "fill"), { id: "over" }), Object.assign(h("div", "fill"), { id: "flashes" }), h("div", "vignette"), Object.assign(h("div", ""), { id: "black" }));
  const blk = document.getElementById("black");
  A(blk, ["blackOut", 0.3, 0.0, E.soft], ["toBlack", 0.3, EDIT.duration - 0.3, E.lin]);
  await Promise.all(["500", "600", "700", "800", "900"].map(w => document.fonts.load(`${w} 100px Outfit`)).concat([document.fonts.load("700 50px Poppins"), document.fonts.load("600 50px Poppins")]));
  await Promise.all(DATA.categories.map(async c => { const r = await fetch(url(c.icon)); SVG_TEXT[c.icon] = r.ok ? await r.text() : ""; }));
  bgfx = new Fx(document.getElementById("bgfx"), 11); fx = new Fx(document.getElementById("fx"), 7);
  bgfx.fireflies(0, EDIT.duration, 46);
  await Promise.all([fx.ready(), bgfx.ready()]);
  buildS1(); buildS2(); buildS3(); buildS4(); buildS5(); buildS6(); buildS7(); buildS8(); buildS9();
  await Promise.all(decodes.map(i => i.decode().catch(() => console.warn("decode failed", i.src))));
  window.__clips = clipLog;
  if (q.has("t")) await renderAt(+q.get("t"));
  else await renderAt(0);
  if (q.has("play")) { const start = performance.now(); const loop = async () => { await renderAt(((performance.now() - start) / 1000) % EDIT.duration); requestAnimationFrame(loop); }; loop(); }
}

async function renderAt(t) {
  for (const s of scenes) s.el.style.display = t >= s.in - s.pre && t < s.out + s.post ? "" : "none";
  for (const u of updaters) if (t >= u.t0 && t <= u.t1) u.run(t);
  for (const a of document.getAnimations()) { a.pause(); a.currentTime = t * 1000; }
  await Promise.all(players.filter(p => t >= p.tIn - 0.05 && t <= p.tOut + 0.05).map(p => p.update(t)));
  bgfx.draw(t); fx.draw(t);
  await document.fonts.ready;
}
window.renderAt = renderAt;
window.__ready = init().then(() => ({ duration: EDIT.duration, fps: EDIT.fps, width: EDIT.width, height: EDIT.height, clips: clipLog }));
