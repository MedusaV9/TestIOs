// Canvas particle systems. Every particle's parameters come from a seeded PRNG at build time and its
// state is a closed-form function of t (ballistic + drag), so any frame renders identically in isolation.
import { ICONS, COIN_FACE, dataUrl } from "./icons.js";

function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const PAL = ["#FFC93C", "#FFD43B", "#2BD98A", "#FF6BD6", "#5FC4FF", "#FF4D6D", "#9A72FF", "#FFF6E3"];
const W = 1920, H = 1080;

function canvasSprite(w, h, paint) { const c = document.createElement("canvas"); c.width = w; c.height = h; paint(c.getContext("2d"), w, h); return c; }
async function svgSprite(svg, size) { const im = new Image(size, size); im.src = dataUrl(svg); await im.decode(); return canvasSprite(size, size, x => x.drawImage(im, 0, 0, size, size)); }

export class Fx {
  constructor(canvas, seed) {
    this.c = canvas; this.x = canvas.getContext("2d"); this.r = rng(seed); this.sys = []; this.sp = {};
    this._ready = this.load();
  }
  ready() { return this._ready; }
  async load() {
    this.sp.banana = await svgSprite(ICONS.banana, 160);
    this.sp.coin = await svgSprite(COIN_FACE, 128);
    this.sp.glow = canvasSprite(64, 64, (x, w) => { const g = x.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(0.25, "rgba(255,240,200,.6)"); g.addColorStop(1, "rgba(255,200,120,0)"); x.fillStyle = g; x.fillRect(0, 0, w, w); });
    this.sp.star = canvasSprite(96, 96, x => {
      const g = x.createRadialGradient(48, 48, 0, 48, 48, 48); g.addColorStop(0, "rgba(255,250,220,.9)"); g.addColorStop(0.3, "rgba(255,210,90,.35)"); g.addColorStop(1, "rgba(255,200,60,0)");
      x.fillStyle = g; x.fillRect(0, 0, 96, 96); x.fillStyle = "#FFF8DC"; x.beginPath();
      for (let i = 0; i < 8; i++) { const a = (i / 8) * Math.PI * 2 - Math.PI / 2, r = i % 2 ? 7 : 44; x.lineTo(48 + Math.cos(a) * r, 48 + Math.sin(a) * r); }
      x.closePath(); x.fill();
    });
    this.sp.note = canvasSprite(150, 80, x => {
      const g = x.createLinearGradient(0, 0, 150, 80); g.addColorStop(0, "#7af5b8"); g.addColorStop(1, "#17b56c");
      x.fillStyle = "#1A1208"; x.beginPath(); x.roundRect(0, 0, 150, 80, 10); x.fill();
      x.fillStyle = g; x.beginPath(); x.roundRect(4, 4, 142, 72, 7); x.fill();
      x.strokeStyle = "rgba(4,36,26,.55)"; x.lineWidth = 3; x.beginPath(); x.roundRect(12, 12, 126, 56, 5); x.stroke();
      x.fillStyle = "#FFD43B"; x.beginPath(); x.arc(75, 40, 19, 0, Math.PI * 2); x.fill(); x.strokeStyle = "#1A1208"; x.lineWidth = 3; x.stroke();
      x.fillStyle = "#04241a"; x.font = "900 22px Outfit, sans-serif"; x.textAlign = "center"; x.textBaseline = "middle"; x.fillText("MM", 75, 41);
    });
  }
  add(t0, t1, draw) { this.sys.push({ t0, t1, draw }); }
  draw(t) {
    const x = this.x; x.setTransform(1, 0, 0, 1, 0, 0); x.clearRect(0, 0, W, H);
    for (const s of this.sys) if (t >= s.t0 && t <= s.t1) { x.save(); s.draw(x, t); x.restore(); }
  }
  blit(x, img, px, py, size, rot = 0, sx = 1, alpha = 1) {
    if (alpha <= 0.003) return;
    const k = size / Math.max(img.width, img.height);
    x.globalAlpha = Math.min(1, alpha); x.setTransform(k * sx, 0, 0, k, px, py);
    if (rot) { const c = Math.cos(rot), s = Math.sin(rot); x.setTransform(k * sx * c, k * sx * s, -k * s, k * c, px, py); }
    x.drawImage(img, -img.width / 2, -img.height / 2);
  }

  /** Radial burst of golden star sparkles. */
  sparkBurst(t0, cx, cy, n, scale = 1) {
    const r = this.r, P = [];
    for (let i = 0; i < n; i++) P.push({ a: r() * Math.PI * 2, v: (260 + r() * 900) * scale, L: 0.35 + r() * 0.45, s: (26 + r() * 46) * scale, rot: r() * 3 });
    this.add(t0, t0 + 0.85, (x, t) => {
      x.globalCompositeOperation = "lighter"; const tau = t - t0;
      for (const p of P) { if (tau > p.L) continue; const u = tau / p.L, d = p.v * p.L * (1 - (1 - u) * (1 - u)) / 2;
        this.blit(x, this.sp.star, cx + Math.cos(p.a) * d, cy + Math.sin(p.a) * d, p.s * (1 - u * 0.5), p.rot + u * 2, 1, 1 - u); }
    });
  }
  /** Coins, Monkey-Money notes and bananas shooting up and raining down. */
  moneyBurst(t0, cx, cy, n) {
    const r = this.r, P = [];
    for (let i = 0; i < n; i++) {
      const k = r(), a = -Math.PI / 2 + (r() - 0.5) * 2.3, v = 900 + r() * 1300;
      P.push({ img: k < 0.45 ? "coin" : k < 0.82 ? "note" : "banana", vx: Math.cos(a) * v * 1.25, vy: Math.sin(a) * v, rot: r() * 6, w: (r() - 0.5) * 16, f: 4 + r() * 10, fp: r() * 6, s: 62 + r() * 60, d: r() * 0.08 });
    }
    this.add(t0, t0 + 1.6, (x, t) => {
      for (const p of P) { const tau = t - t0 - p.d; if (tau < 0) continue;
        const px = cx + p.vx * tau * 0.9, py = cy + p.vy * tau + 1300 * tau * tau;
        this.blit(x, this.sp[p.img], px, py, p.s, p.rot + p.w * tau, Math.cos(p.fp + p.f * tau), 1 - Math.max(0, tau - 1.1) / 0.4); }
    });
  }
  /** Confetti cannons from both bottom corners + a centre burst. */
  confetti(t0, len = 1.3, fadeAt = Infinity, fadeLen = 0.4) {
    const r = this.r, P = [];
    const em = [{ x: -30, y: 1110, a: -1.05, sp: 0.28, n: 150, v: [1900, 3300] }, { x: 1950, y: 1110, a: -2.09, sp: 0.28, n: 150, v: [1900, 3300] }, { x: 960, y: 430, a: 0, sp: Math.PI, n: 130, v: [500, 1500] }];
    for (const e of em) for (let i = 0; i < e.n; i++) {
      const a = e.a + (r() - 0.5) * 2 * e.sp, v = e.v[0] + r() * (e.v[1] - e.v[0]);
      P.push({ x: e.x, y: e.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, c: PAL[(r() * PAL.length) | 0], w: 12 + r() * 10, h: 20 + r() * 16, rot: r() * 6, wr: (r() - 0.5) * 14, f: 5 + r() * 9, fp: r() * 6, fl: r() * 6, d: r() * 0.12 });
    }
    const k = 1.7, g = 1500;
    this.add(t0, Math.min(t0 + len + 2.5, fadeAt + fadeLen), (x, t) => {
      const fade = 1 - Math.min(1, Math.max(0, (t - fadeAt) / fadeLen));
      for (const p of P) { const tau = t - t0 - p.d; if (tau < 0) continue;
        const e = 1 - Math.exp(-k * tau), px = p.x + (p.vx / k) * e + Math.sin(p.fl + tau * 3) * 26 * Math.min(1, tau), py = p.y + (g / k) * tau + ((p.vy - g / k) / k) * e;
        if (py > H + 60) continue;
        const c = Math.cos(p.rot + p.wr * tau), s = Math.sin(p.rot + p.wr * tau), fy = Math.cos(p.fp + p.f * tau);
        x.globalAlpha = fade; x.setTransform(c, s, -s * fy, c * fy, px, py); x.fillStyle = p.c; x.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
        x.fillStyle = "rgba(255,255,255,.28)"; x.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * 0.3);
      }
    });
  }
  /** Banana (and coin) rain; back = smaller, dimmer layer for the background canvas; edges = keep the centre column clear. */
  bananaRain(t0, t1, back = false, edges = false) {
    const r = this.r, M = back ? 26 : edges ? 18 : 30, P = [], span = t1 - t0 + 0.8;
    for (let i = 0; i < M; i++) {
      const ts = t0 - 0.9 + (i + r() * 0.9) * (span / M), u = r();
      P.push({ ts, x: edges ? (i % 2 ? 40 + u * 260 : W - 40 - u * 260) : 80 + u * 1760, vy: (back ? 260 : 420) + r() * 360, g: back ? 420 : 820, sw: 20 + r() * 50, sf: 1 + r() * 2, sp: r() * 6, rot: r() * 6, w: (r() - 0.5) * 5, s: back ? 60 + r() * 40 : 100 + r() * 70, img: r() < 0.24 ? "coin" : "banana" });
    }
    this.add(t0, t1 + 0.05, (x, t) => {
      for (const p of P) { const tau = t - p.ts; if (tau < 0) continue;
        const py = -140 + p.vy * tau + 0.5 * p.g * tau * tau; if (py > H + 160) continue;
        const px = p.x + Math.sin(p.sp + tau * p.sf) * p.sw;
        this.blit(x, this.sp[p.img], px, py, p.img === "coin" ? p.s * 0.6 : p.s, p.rot + p.w * tau, p.img === "coin" ? Math.cos(p.sp + tau * 6) : 1, back ? 0.55 : 1); }
    });
  }
  /** Ambient drifting fireflies / dust. */
  fireflies(t0, t1, n) {
    const r = this.r, P = [];
    for (let i = 0; i < n; i++) P.push({ x: r() * W, y: r() * H, a: 30 + r() * 70, f: 0.3 + r() * 0.8, p: r() * 6, s: 10 + r() * 22, tw: 1.5 + r() * 3, vy: 8 + r() * 25 });
    this.add(t0, t1, (x, t) => {
      x.globalCompositeOperation = "lighter";
      for (const p of P) { const px = (p.x + Math.sin(p.p + t * p.f) * p.a + W) % W, py = ((p.y - t * p.vy + Math.cos(p.p + t * p.f * 0.7) * p.a * 0.5) % H + H) % H;
        this.blit(x, this.sp.glow, px, py, p.s, 0, 1, 0.25 + 0.5 * (0.5 + 0.5 * Math.sin(p.p * 3 + t * p.tw))); }
    });
  }
}
