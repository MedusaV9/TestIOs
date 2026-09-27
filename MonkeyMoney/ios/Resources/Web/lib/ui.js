// Shared UI pieces: monkey puppets (inline SVG), timers, money counters,
// confetti, QR codes.
import { html, useState, useEffect, useRef, useMemo } from "../vendor/preact-htm.js";
import { avatarParts, colorHex, serverNow, useFrame, fmtNum, cx } from "./core.js";

// ---------- monkeys ----------
const svgCache = new Map();
const cosmeticCache = new Map();
function fetchText(url, cache) {
  if (!cache.has(url)) cache.set(url, fetch(url).then(r => (r.ok ? r.text() : "")).catch(() => ""));
  return cache.get(url);
}
function lighten(hex, amt = 70) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.min(255, (n >> 16) + amt), g = Math.min(255, ((n >> 8) & 255) + amt), b = Math.min(255, (n & 255) + amt);
  return `rgb(${r},${g},${b})`;
}
const resolved = new Map();
async function monkeyMarkup(affe, extras) {
  const key = affe + "|" + extras.join("+");
  if (resolved.has(key)) return resolved.get(key);
  let svg = await fetchText(`/monkeys/${affe}.svg`, svgCache);
  if (extras.length) {
    const layers = await Promise.all(extras.map(e => fetchText(`/cosmetics/${e}.svg`, cosmeticCache)));
    const inner = layers.map(t => {
      const m = t.match(/<svg[^>]*>([\s\S]*)<\/svg>/);
      return m ? `<g class="cosmetic">${m[1]}</g>` : "";
    }).join("");
    svg = svg.replace(/<\/svg>\s*$/, inner + "</svg>");
  }
  resolved.set(key, svg);
  return svg;
}

/** A monkey puppet. face: neutral|jubel|frust|denk · anim: idle|jubel|frust|denk|walk|none */
export function Monkey({ wire, face = "neutral", anim = "idle", size, class: klass, style, delay = 0 }) {
  const { affe, farbe, extras } = avatarParts(wire);
  const key = affe + "|" + extras.join("+");
  const [markup, setMarkup] = useState(resolved.get(key) || "");
  useEffect(() => {
    let alive = true;
    monkeyMarkup(affe, extras).then(m => alive && setMarkup(m));
    return () => { alive = false; };
  }, [key]);
  const fell = colorHex(farbe);
  const withFace = markup.replace("<svg ", `<svg data-gesicht="${face}" `);
  const st = `--fell:${fell};--fell-hell:${lighten(fell)};--delay:${delay}ms;${size ? `width:${size}px;height:${size * 4 / 3}px;` : ""}${style || ""}`;
  return html`<div class=${cx("monkey", `anim-${anim}`, klass)} style=${st} dangerouslySetInnerHTML=${{ __html: withFace }}></div>`;
}

// ---------- timers ----------
/** Circular countdown. `total` ms if known (else inferred from first sight). */
export function TimerRing({ deadline, total, size = 120, stroke = 10, label = true, paused }) {
  const first = useRef({ deadline: null, total: 0 });
  const now = useFrame(!!deadline && !paused);
  if (!deadline) return null;
  if (first.current.deadline !== deadline) first.current = { deadline, total: total || Math.max(1000, deadline - serverNow()) };
  const tot = total || first.current.total;
  const remain = Math.max(0, deadline - now);
  const frac = Math.max(0, Math.min(1, remain / tot));
  const r = (size - stroke) / 2, c = 2 * Math.PI * r;
  const secs = Math.ceil(remain / 1000);
  const hot = remain < 5000;
  return html`<div class=${cx("timer-ring", hot && "hot", remain === 0 && "done")} style=${`width:${size}px;height:${size}px`}>
    <svg viewBox=${`0 0 ${size} ${size}`}>
      <circle cx=${size / 2} cy=${size / 2} r=${r} class="track" stroke-width=${stroke} />
      <circle cx=${size / 2} cy=${size / 2} r=${r} class="bar" stroke-width=${stroke}
        stroke-dasharray=${c} stroke-dashoffset=${c * (1 - frac)} transform=${`rotate(-90 ${size / 2} ${size / 2})`} />
    </svg>
    ${label && html`<b key=${secs} class="secs">${secs}</b>`}
  </div>`;
}

export function TimerBar({ deadline, total, paused }) {
  const first = useRef({ deadline: null, total: 0 });
  const now = useFrame(!!deadline && !paused);
  if (!deadline) return null;
  if (first.current.deadline !== deadline) first.current = { deadline, total: total || Math.max(1000, deadline - serverNow()) };
  const remain = Math.max(0, deadline - now);
  const frac = Math.max(0, Math.min(1, remain / (total || first.current.total)));
  return html`<div class=${cx("timer-bar", remain < 5000 && "hot")}><i style=${`transform:scaleX(${frac})`}></i></div>`;
}

export function Countdown({ deadline }) {
  const now = useFrame(!!deadline);
  if (!deadline) return null;
  return html`<span class="countdown">${Math.max(0, Math.ceil((deadline - now) / 1000))}</span>`;
}

// ---------- money ----------
/** Counts smoothly to `value`; flashes up/down. */
export function Money({ value, suffix = " MM", duration = 900, class: klass }) {
  const [shown, setShown] = useState(value);
  const [dir, setDir] = useState("");
  const from = useRef(value);
  useEffect(() => {
    const start = from.current;
    if (start === value) return;
    setDir(value > start ? "up" : "down");
    const t0 = performance.now();
    let raf;
    const step = t => {
      const k = Math.min(1, (t - t0) / duration), e = 1 - Math.pow(1 - k, 3);
      const v = Math.round(start + (value - start) * e);
      setShown(v);
      from.current = v;
      if (k < 1) raf = requestAnimationFrame(step); else setTimeout(() => setDir(""), 400);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [value]);
  return html`<span class=${cx("money", dir, klass)}>${fmtNum(shown)}${suffix}</span>`;
}

// ---------- confetti ----------
export function Confetti({ burst = 0, count = 160, colors, rain = false }) {
  const ref = useRef();
  useEffect(() => {
    const cv = ref.current;
    if (!cv || !burst) return;
    const ctx = cv.getContext("2d");
    const W = (cv.width = cv.offsetWidth * 1), H = (cv.height = cv.offsetHeight * 1);
    const pal = colors || ["#FFC93C", "#FF4D6D", "#2BD98A", "#4D8BFF", "#9B6BFF", "#FFF6E3", "#FF8A3D"];
    const parts = Array.from({ length: count }, () => ({
      x: rain ? Math.random() * W : W / 2 + (Math.random() - 0.5) * W * 0.3,
      y: rain ? -20 - Math.random() * H * 0.5 : H * 0.55,
      vx: rain ? (Math.random() - 0.5) * 2 : (Math.random() - 0.5) * 22,
      vy: rain ? 2 + Math.random() * 4 : -12 - Math.random() * 18,
      w: 8 + Math.random() * 10, h: 5 + Math.random() * 8,
      r: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.3,
      c: pal[Math.floor(Math.random() * pal.length)], banana: Math.random() < 0.12,
    }));
    let raf, t0 = performance.now();
    const loop = t => {
      const age = t - t0;
      ctx.clearRect(0, 0, W, H);
      for (const p of parts) {
        p.vy += 0.35; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.r += p.vr;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r);
        if (p.banana) { ctx.font = "26px serif"; ctx.fillText("🍌", -13, 9); }
        else { ctx.fillStyle = p.c; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.r * 2))); }
        ctx.restore();
      }
      if (age < 5200) raf = requestAnimationFrame(loop); else ctx.clearRect(0, 0, W, H);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [burst]);
  return html`<canvas class="confetti" ref=${ref}></canvas>`;
}

// ---------- QR ----------
export function QR({ text, size = 240, dark = "#1A1208", light = "#FFF6E3" }) {
  const svg = useMemo(() => {
    if (!text || typeof window.qrcode !== "function") return "";
    const qr = window.qrcode(0, "M");
    qr.addData(text);
    qr.make();
    const n = qr.getModuleCount(), q = 2, total = n + q * 2;
    let d = "";
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (qr.isDark(r, c)) d += `M${c + q},${r + q}h1v1h-1z`;
    return `<svg viewBox="0 0 ${total} ${total}" shape-rendering="crispEdges"><rect width="${total}" height="${total}" rx="1.5" fill="${light}"/><path d="${d}" fill="${dark}"/></svg>`;
  }, [text, dark, light]);
  return html`<div class="qr" style=${`width:${size}px;height:${size}px`} dangerouslySetInnerHTML=${{ __html: svg }}></div>`;
}

/** Pixelated picture for Pixel-Dschungel: level 0 = blocks, maxLevel = sharp. */
export function PixelImage({ src, level, maxLevel = 8, class: klass }) {
  const ref = useRef();
  const img = useRef(null);
  const [loaded, setLoaded] = useState(0);
  useEffect(() => {
    const i = new Image();
    i.onload = () => { img.current = i; setLoaded(x => x + 1); };
    i.src = src;
  }, [src]);
  useEffect(() => {
    const cv = ref.current, i = img.current;
    if (!cv || !i) return;
    const S = 512;
    cv.width = S; cv.height = S;
    const ctx = cv.getContext("2d");
    const blocks = [6, 9, 13, 18, 26, 38, 56, 90, 512][Math.max(0, Math.min(8, Math.round((level / maxLevel) * 8)))];
    const tmp = document.createElement("canvas");
    tmp.width = blocks; tmp.height = blocks;
    const t = tmp.getContext("2d");
    t.imageSmoothingEnabled = true;
    const side = Math.min(i.width, i.height);
    t.drawImage(i, (i.width - side) / 2, (i.height - side) / 2, side, side, 0, 0, blocks, blocks);
    ctx.imageSmoothingEnabled = blocks >= 512;
    ctx.clearRect(0, 0, S, S);
    ctx.drawImage(tmp, 0, 0, blocks, blocks, 0, 0, S, S);
  }, [loaded, level]);
  return html`<canvas class=${cx("pixel-img", klass)} ref=${ref}></canvas>`;
}

export function Stars({ n, max = 4 }) {
  return html`<span class="stars">${Array.from({ length: max }, (_, i) => html`<svg class=${i < n ? "on" : ""} viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3l-5.9 3.3 1.3-6.6-4.9-4.6 6.6-.8z"/></svg>`)}</span>`;
}
