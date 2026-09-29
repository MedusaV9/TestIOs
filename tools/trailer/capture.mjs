// Trailer footage recorder: plays one scripted "Eigene Show" end to end and
// records every page continuously (CDP screencast → JPEG frames on a shared
// clock), plus an event timeline and full-res stills per scene.
//
//   env -u NODE_OPTIONS node tools/trailer/capture.mjs
//     OUT=/projects/sandbox/trailer/footage   output dir (wiped at start)
//     MM_SERVER=…/mm-dev-server               dev server binary (default: .build-web)
//     PORT=8571                               first port to try (8571–8579)
//     TOUCH=phone1,phone2,gm                  pages that show a touch dot on taps ("" = none)
//     PLAYLIST=bananen-basics:3,affenzahn:4,…  rounds of the "Eigene Show" (default: the trailer playlist)
//     BROWSERS=1                              all pages in one Chromium (default: one per page, see browserFor)
//     MAXSEC=720                              hard stop
//
// Output: <OUT>/<page>/<000000>.jpg + index.json {w,h,frames:[{f,t}]} for
// stage, phone1, phone2, gm · events.json [{t,page,scene,detail}] · stills/
// <t>-<page>-<scene>.png · audio.json (stage sound log on the same clock) ·
// summary.json. t = seconds since the stage recording started.
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { getPriority as osGetPriority, setPriority as osPriority } from "node:os";
import path from "node:path";

const DEFAULT_SERVER = "/projects/sandbox/.build-web/debug/mm-dev-server";
if (!process.env.MM_SERVER && existsSync(DEFAULT_SERVER)) process.env.MM_SERVER = DEFAULT_SERVER;
const { startServer, chromium, chromePath, sleep, api } = await import("../web/lib.mjs");

const OUT = process.env.OUT || "/projects/sandbox/trailer/footage";
const MAXSEC = Number(process.env.MAXSEC || 720);
const TOUCH = new Set((process.env.TOUCH ?? "phone1,phone2,gm").split(",").map(s => s.trim()).filter(Boolean));
const PLAYLIST = (process.env.PLAYLIST || "bananen-basics:3,affenzahn:4,letzter-affe:5,herdentrieb:3,bananen-tresor:3,affenschaukel:3")
  .split(",").map(x => x.trim().split(":")).filter(([id]) => id).map(([id, n]) => ({ id, fragen: Number(n) || 3 }));
const PATCH = {
  tempo: "zackig",
  eigenePlaylist: PLAYLIST,
  eigenerJackpot: true,
  radAn: true,
  typenAus: ["emoji"],
};
// [label, persona] — persona picks the bot brain + monkey (bot_n answers after 2.5 s + n·1.3 s).
const BOTS = [["Kokos", "Kokos"], ["Banana Joe", "Banana Joe"], ["Splitter", "Splitter"], ["Mango", "Prof. Pavian"]];
const PAGES = ["stage", "phone1", "phone2", "gm"];

// ---------- output ----------
rmSync(OUT, { recursive: true, force: true });
for (const d of [...PAGES, "stills"]) mkdirSync(path.join(OUT, d), { recursive: true });

let T0 = Date.now() / 1000; // reset when the stage recording starts
const now = () => Date.now() / 1000 - T0;
const tt = () => now().toFixed(1).padStart(5, " ");
const log = (...a) => console.log(`[${tt()}]`, ...a);
const events = [];
let stageScene = "boot";
function ev(page, scene, detail = {}) {
  const e = { t: +now().toFixed(3), page, scene, detail };
  events.push(e);
  if (detail.type !== "sub") log(page.padEnd(6), scene, JSON.stringify(detail).slice(0, 140));
  return e;
}
const act = (page, action, extra = {}) => ev(page, stageScene, { type: "action", action, ...extra });
const errors = [];
const rand = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[Math.floor(Math.random() * arr.length)];

// ---------- server + browser ----------
async function freePort() {
  const first = Number(process.env.PORT || 8571);
  for (let p = first; p <= 8579; p++) {
    try { await fetch(`http://127.0.0.1:${p}/healthz`, { signal: AbortSignal.timeout(400) }); } catch (_) { return p; }
  }
  throw new Error("no free port in 8571–8579");
}
const PORT = await freePort();
const BASE = `http://127.0.0.1:${PORT}`;
const STORE = `/tmp/mm-trailer-${PORT}`;
rmSync(STORE, { recursive: true, force: true }); // fresh: no autosave card, no stale profiles
const srv = await startServer(PORT, [`storage=${STORE}`]);
// Show timing lives on the server queue: keep it (and this process, which acks the frames) ahead of the renderers.
function renicePid(pid, nice) { let n = 0; try { for (const t of readdirSync(`/proc/${pid}/task`)) { try { osPriority(Number(t), nice); n++; } catch (_) {} } } catch (_) {} return n; }
const niced = [renicePid(srv.proc.pid, -6), renicePid(process.pid, -3)];
setInterval(() => renicePid(srv.proc.pid, -6), 5000).unref();
// Rendering is CPU-bound (software GL): one Chromium per page gives every page its own GPU
// process, and a real 2× screen for the handhelds — with one shared browser the screencast
// only delivers DIP-sized (390×844) phone frames. BROWSERS=1 keeps everything in one browser.
const ONE_BROWSER = process.env.BROWSERS === "1";
const BASE_ARGS = ["--autoplay-policy=no-user-gesture-required", "--no-sandbox", "--disable-background-timer-throttling",
  "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows", "--hide-scrollbars"];
const browsers = {};
async function browserFor(name) {
  const key = ONE_BROWSER ? "all" : name;
  if (!browsers[key]) {
    const hidpi = !ONE_BROWSER && name !== "stage";
    browsers[key] = await chromium.launch({ executablePath: chromePath(), args: [...BASE_ARGS, `--mm-trailer=${key}`, ...(hidpi ? ["--force-device-scale-factor=2"] : [])] });
  }
  return browsers[key];
}
// The stage is the hero shot: the handheld browsers run at a lower CPU priority (every thread of the process tree).
function deprioritize(key, nice = 8) {
  try {
    const ps = {};
    for (const d of readdirSync("/proc")) {
      if (!/^\d+$/.test(d)) continue;
      try { const st = readFileSync(`/proc/${d}/stat`, "utf8"); ps[d] = { ppid: st.slice(st.lastIndexOf(")") + 2).split(" ")[1], cmd: readFileSync(`/proc/${d}/cmdline`, "utf8") }; } catch (_) {}
    }
    const roots = Object.keys(ps).filter(p => ps[p].cmd.includes(`--mm-trailer=${key}`) && !ps[p].cmd.includes("--type="));
    const tree = new Set(roots);
    for (let grew = true; grew;) { grew = false; for (const [p, v] of Object.entries(ps)) if (!tree.has(p) && tree.has(v.ppid)) { tree.add(p); grew = true; } }
    let n = 0;
    for (const p of tree) for (const t of readdirSync(`/proc/${p}/task`)) { try { if (nice > 0 || osGetPriority(Number(t)) > nice) { osPriority(Number(t), nice); n++; } } catch (_) {} }
    return n;
  } catch (_) { return 0; }
}
log("server", BASE, "bin", process.env.MM_SERVER || "(repo build)", ONE_BROWSER ? "· one browser" : "· one browser per page", "· reniced server/node threads", niced.join("/"));

// ---------- recorder ----------
function jpegSize(b) {
  for (let i = 2; i < b.length - 9;) {
    if (b[i] !== 0xff) { i++; continue; }
    const m = b[i + 1];
    if (m >= 0xc0 && m <= 0xc3) return { w: b.readUInt16BE(i + 7), h: b.readUInt16BE(i + 5) };
    i += 2 + b.readUInt16BE(i + 2);
  }
  return null;
}
class Recorder {
  constructor(name, page, max) { Object.assign(this, { name, page, max, frames: [], size: null, writes: 0, inflight: new Set() }); }
  async start() {
    this.cdp = await this.page.context().newCDPSession(this.page);
    this.cdp.on("Page.screencastFrame", ({ data, metadata, sessionId }) => {
      this.cdp.send("Page.screencastFrameAck", { sessionId }).catch(() => {});
      const f = this.frames.length;
      const ts = metadata && metadata.timestamp ? metadata.timestamp : Date.now() / 1000;
      this.frames.push({ f, t: +(ts - T0).toFixed(4) });
      const buf = Buffer.from(data, "base64");
      if (!this.size) this.size = jpegSize(buf);
      const p = writeFile(path.join(OUT, this.name, `${String(f).padStart(6, "0")}.jpg`), buf).catch(e => errors.push(`[rec ${this.name}] ${e.message}`));
      this.inflight.add(p);
      p.finally(() => this.inflight.delete(p));
    });
    await this.cdp.send("Page.startScreencast", { format: "jpeg", quality: 92, maxWidth: this.max.w, maxHeight: this.max.h, everyNthFrame: 1 });
    this.startedAt = now();
    log("rec", this.name, "started");
  }
  async stop() {
    try { await this.cdp.send("Page.stopScreencast"); } catch (_) {}
    await sleep(300);
    await Promise.all([...this.inflight]);
    const sz = this.size || { w: this.max.w, h: this.max.h };
    writeFileSync(path.join(OUT, this.name, "index.json"), JSON.stringify({ w: sz.w, h: sz.h, frames: this.frames }));
    const fr = this.frames;
    const span = fr.length > 1 ? fr[fr.length - 1].t - fr[0].t : 0;
    const gaps = fr.slice(1).map((x, i) => x.t - fr[i].t).sort((a, b) => a - b);
    return { page: this.name, w: sz.w, h: sz.h, frames: fr.length, from: fr.length ? fr[0].t : null, to: fr.length ? fr[fr.length - 1].t : null,
      fps: span ? +(fr.length / span).toFixed(1) : 0, medianFps: gaps.length ? +(1 / gaps[Math.floor(gaps.length / 2)]).toFixed(1) : 0,
      longestGap: gaps.length ? +gaps[gaps.length - 1].toFixed(2) : 0 };
  }
}

// ---------- stills (one queue per page so screenshots never overlap) ----------
const stillQ = {};
const stillCount = {};
function still(name, page, scene, delayMs = 0, guard = null) {
  const q = stillQ[name] || Promise.resolve();
  stillQ[name] = q.then(async () => {
    if (delayMs) await sleep(delayMs);
    if (guard && !guard()) return;
    const file = `${now().toFixed(2).padStart(7, "0")}-${name}-${scene.replace(/[^\w.-]+/g, "_")}.png`;
    try { await page.screenshot({ path: path.join(OUT, "stills", file) }); ev(name, scene, { type: "still", file }); } catch (e) { errors.push(`[still ${name}] ${e.message}`); }
  });
  return stillQ[name];
}
const stillOnce = (name, page, scene, delayMs, limit = 1, guard = null) => {
  const k = `${name}|${scene}`;
  stillCount[k] = (stillCount[k] || 0) + 1;
  if (stillCount[k] <= limit) still(name, page, scene, delayMs, guard);
};

// ---------- page setup ----------
const TOUCH_JS = () => {
  const css = "position:fixed;width:46px;height:46px;margin:-23px 0 0 -23px;border-radius:50%;pointer-events:none;z-index:2147483647;"
    + "background:rgba(255,255,255,.42);box-shadow:0 0 0 3px rgba(255,255,255,.75),0 0 18px rgba(0,0,0,.35);transform:scale(.55);opacity:0;"
    + "transition:transform .12s ease-out,opacity .12s ease-out";
  let dot = null;
  addEventListener("pointerdown", e => {
    if (!e.isTrusted) return;
    const d = document.createElement("div");
    d.style.cssText = css + `;left:${e.clientX}px;top:${e.clientY}px`;
    document.documentElement.appendChild(d);
    requestAnimationFrame(() => { d.style.transform = "scale(1)"; d.style.opacity = "1"; });
    dot = d;
  }, true);
  addEventListener("pointerup", () => {
    const d = dot; dot = null; if (!d) return;
    setTimeout(() => { d.style.transition = "transform .4s ease-out,opacity .4s ease-out"; d.style.transform = "scale(1.5)"; d.style.opacity = "0"; }, 60);
    setTimeout(() => d.remove(), 600);
  }, true);
};
// Keep a handle on the page's WebSocket so scripted GM commands (bot seats, fallbacks) go out on the GM's own session.
const WS_JS = () => {
  const Orig = window.WebSocket;
  window.WebSocket = class extends Orig { constructor(...a) { super(...a); window.__mmWs = this; } };
};
const MOBILE = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };
async function openPage(name, opts, init = []) {
  const ctx = await (await browserFor(name)).newContext(opts);
  for (const s of init) await ctx.addInitScript(s.fn, s.arg);
  if (TOUCH.has(name)) await ctx.addInitScript(TOUCH_JS);
  const page = await ctx.newPage();
  page.on("console", m => { if (m.type() === "error") errors.push(`[${name}] ${m.text()}`); });
  page.on("pageerror", e => errors.push(`[${name}] ${e.message}`));
  const dsf = opts.deviceScaleFactor || 1;
  const rec = new Recorder(name, page, { w: opts.viewport.width * dsf, h: opts.viewport.height * dsf });
  return { page, rec };
}
async function tap(name, page, sel, what, opt = {}) {
  const loc = typeof sel === "string" ? page.locator(sel).first() : sel;
  try {
    await loc.scrollIntoViewIfNeeded({ timeout: 2500 });
    const box = await loc.boundingBox();
    await loc.click({ delay: opt.delay ?? 130, timeout: opt.timeout ?? 3000 });
    act(name, "tap", { what, x: box ? Math.round(box.x + box.width / 2) : null, y: box ? Math.round(box.y + box.height / 2) : null, ...(opt.detail || {}) });
    return true;
  } catch (e) { errors.push(`[${name}] tap ${what}: ${e.message.split("\n")[0]}`); return false; }
}
// Fast tap for time-critical answers: one evaluate finds the target (fn runs in the page and
// returns an element), then a raw mouse press on its centre — no actionability round trips.
async function fastTap(name, page, fn, arg, what, detail = {}) {
  const hit = await page.evaluate(([src, a]) => {
    const el = (0, eval)(src)(a);
    if (!el) return null;
    // Only press where the element really is on top (the phone's joker dock is fixed over the page bottom).
    const probe = () => {
      const r = el.getBoundingClientRect();
      for (const fy of [0.5, 0.3, 0.7]) {
        const x = r.x + r.width / 2, y = r.y + r.height * fy;
        if (y < 0 || y > innerHeight) continue;
        const h = document.elementFromPoint(x, y);
        if (h && (h === el || el.contains(h))) return { x, y };
      }
      return null;
    };
    let p = probe();
    if (!p) { el.scrollIntoView({ block: "center" }); p = probe(); }
    const label = (el.querySelector(".p-opt-text, .bin-t, b") || el).textContent.trim();
    const data = el.dataset.pick || null;
    if (!p) { el.click(); return { dom: true, label, data }; }
    return { ...p, label, data };
  }, [fn.toString(), arg]).catch(() => null);
  if (!hit) return false;
  if (!hit.dom) await page.mouse.click(hit.x, hit.y, { delay: 110 });
  act(name, "tap", { what, x: hit.dom ? null : Math.round(hit.x), y: hit.dom ? null : Math.round(hit.y), label: hit.label, ...(hit.dom ? { via: "dom-click (covered)" } : {}), ...detail, ...(hit.data ? { pick: hit.data } : {}) });
  return true;
}
async function smoothTo(page, sel, block = "center") {
  try { await page.evaluate(([s, b]) => { const el = document.querySelector(s); if (el) el.scrollIntoView({ behavior: "smooth", block: b }); }, [sel, block]); await sleep(650); } catch (_) {}
}
const scrollTop = page => page.evaluate(() => window.scrollTo({ top: 0, behavior: "smooth" })).catch(() => {});

// ---------- scene key (same naming as tools/web/match.mjs) ----------
function sceneOf(v) {
  const kind = Object.keys(v.scene || { none: {} })[0];
  const body = v.scene[kind] || {};
  let key = kind;
  if (kind === "frage" || kind === "aufloesung") key = `${kind}-${body.minigameId}-${Object.keys(body.extra || {})[0]}`;
  if (kind === "rad") key += "-" + (body._0 && body._0.subphase);
  const ex = body.extra ? body.extra[Object.keys(body.extra)[0]] || {} : {};
  return { kind, body, key, ex, sub: kind === "rad" ? body._0 && body._0.subphase : null };
}
const slug = s => String(s || "").toLowerCase().replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const beatOf = label => /Jackpot/i.test(label) ? "jackpot" : /Finale/i.test(label) ? "finale" : (/Runde\s+(\d+)/.exec(label || "") || [])[1] ? "runde-" + /Runde\s+(\d+)/.exec(label)[1] : "";

let done = false;
let gmBusy = false;
let stage, phone1, phone2, gm;
const recs = [];

async function gmView() { return api(PORT, "/api/dev/gm"); }
async function gmCmd(cmd) {
  try { return await gm.page.evaluate(c => { const ws = window.__mmWs; if (!ws || ws.readyState !== 1) return false; ws.send(JSON.stringify({ t: "gm", cmd: c })); return true; }, cmd); } catch (_) { return false; }
}
let lastAdvance = 0;
// Skip a waiting phase with flowNext (the command behind the GM's / stage's "Weiter ▶").
// Sent from here (dev console) right after a fresh phase check: a press on the GM page can
// land seconds late under CPU load and then hits the NEXT phase — e.g. "Auflösen" on a
// freshly started format, which ends the whole round after one question.
// Under load the server answers late, so the phase may end by itself before a flowNext
// arrives — which then hits the next phase. Only skip when the phase end (server deadline,
// or the earliest possible reveal end) is safely further away than the current poll latency.
const latency = [];
const pushLatency = ms => { latency.push(ms); if (latency.length > 30) latency.shift(); };
const guardMs = () => { const a = latency.slice().sort((x, y) => x - y); const p90 = a.length ? a[Math.floor(a.length * 0.9)] : 200; return Math.max(1800, 2 * p90 + 600); };
function phaseEnd(sc, startEst) {
  const b = sc.body || {};
  const d = b.deadline ?? (b._0 && (b._0.deadline ?? b._0.interactionEndsAt)) ?? null;
  if (d) return d;
  if (sc.kind === "aufloesung") return startEst + 8000; // Dur.aufloesung 9.5 s × tempo 0.85 (round-based / with explanation: longer)
  if (sc.kind === "rad") return startEst + (sc.sub === "erklaert" ? 4200 : 1500);
  if (sc.kind === "frage") return (b.wall && b.wall.deadline) || null;
  return null;
}
async function advance(expectKey, label, startEst) {
  lastAdvance = now();
  const t = Date.now();
  const v = await api(PORT, "/api/dev/stage").catch(() => null);
  pushLatency(Date.now() - t);
  if (!v || !v.scene) return false;
  const sc = sceneOf(v);
  if (sc.key !== expectKey || !v.canAdvance || v.paused) return false;
  const end = phaseEnd(sc, startEst);
  const left = end ? end - Date.now() : Infinity;
  if (left < guardMs()) return "late";
  await api(PORT, "/api/dev/next");
  act("gm", "flowNext", { label, via: "dev", msLeft: Number.isFinite(left) ? Math.round(left) : null });
  return true;
}

// ---------- phone players ----------
const norm = s => String(s || "").replace(/\s+/g, " ").trim().toLowerCase();
const num = s => { const m = /-?[\d.]+(?:,\d+)?/.exec(String(s || "").replace(/\s/g, "")); if (!m) return null; const x = Number(m[0].replace(/\./g, "").replace(",", ".")); return Number.isFinite(x) ? x : null; };
// The right answer comes from the cheat sheet in the GM cockpit (gm page DOM) — /api/dev/gm
// builds the whole GM view (~300 ms on the server queue) and would slow the show down.
const korrektCache = new Map();
async function korrektFor(q) {
  if (korrektCache.has(q)) return korrektCache.get(q);
  const p = gm.page.evaluate(() => {
    const c = document.querySelector(".spick");
    if (!c) return null;
    const ok = c.querySelector(".gm-opt.ok .gm-opt-t"), a = c.querySelector(".spick-a");
    const k = ok ? ok.textContent.replace(/\s*✔\s*$/, "") : a ? a.textContent.replace(/^\s*✔\s*/, "") : null;
    return { q: ((c.querySelector(".spick-q") || {}).textContent || "").trim(), k: k && k.trim() };
  }).catch(() => null).then(r => (r && r.k && (!q || norm(r.q) === norm(q)) ? r.k : null));
  korrektCache.set(q, p);
  const k = await p;
  if (k == null) korrektCache.delete(q);
  return k;
}
const READ_PHONE = () => {
  const g = document.querySelector(".game");
  const txt = s => { const el = document.querySelector(s); return el ? el.textContent.trim() : ""; };
  if (!g) return { pk: document.querySelector(".join") ? "join" : null };
  const cls = [...g.classList];
  const pk = (cls.find(c => c.startsWith("pk-")) || "pk-none").slice(3);
  const ph = (cls.find(c => c.startsWith("ph-")) || "ph-none").slice(3);
  const rev = document.querySelector(".p-reveal");
  return { pk, ph, q: txt(".p-question"), title: txt(".p-title"), sub: txt(".p-sub"), rev: rev ? ["ok", "nope", "meh"].find(c => rev.classList.contains(c)) || "" : "",
    locked: !!document.querySelector(".p-locked-note, .p-locked"), sheet: !!document.querySelector(".p-sheet") };
};
const ACTIONABLE = new Set(["choice", "multiChoice", "bank", "vote", "binary", "number", "wager", "order", "chips", "pickPlayer", "confirm", "explain", "buzzer", "tapFrenzy", "cheer"]);

// What the phone needs to know before it taps (fetched while the "thinking" delay runs).
async function planFor(st, due) {
  const plan = {};
  try {
    if (["choice", "bank", "number", "binary"].includes(st.pk)) {
      const q = st.pk === "binary" ? null : st.q;
      while (!done && Date.now() < due - 150) { const k = await korrektFor(q); if (k != null) { plan.spick = { korrekt: k }; break; } await sleep(250); }
    }
    if (["number", "binary"].includes(st.pk)) plan.ex = sceneOf(await api(PORT, "/api/dev/stage")).ex;
  } catch (_) {}
  return plan;
}
// In-page pickers for fastTap (serialised, so they must be self-contained).
const PICK_OPT = ({ want, good }) => {
  const norm = s => String(s || "").replace(/\s+/g, " ").trim().toLowerCase();
  const opts = [...document.querySelectorAll(".p-opt")].filter(e => !e.disabled);
  if (!opts.length) return null;
  const right = want == null ? -1 : opts.findIndex(e => norm((e.querySelector(".p-opt-text") || e).textContent) === norm(want));
  const others = opts.map((_, k) => k).filter(k => k !== right);
  const i = right >= 0 && (good || !others.length) ? right : others[Math.floor(Math.random() * others.length)];
  opts[i].dataset.pick = right < 0 ? "unknown" : i === right ? "right" : "wrong";
  return opts[i];
};
const PICK_NTH = ({ sel, i }) => { const els = [...document.querySelectorAll(sel)].filter(e => !e.disabled); return els.length ? els[i == null ? Math.floor(Math.random() * els.length) : Math.min(i, els.length - 1)] : null; };
const PICK_BIN = ({ want, good }) => {
  const btns = [...document.querySelectorAll(".bin-btn")].filter(e => !e.disabled);
  if (!btns.length) return null;
  const dirOf = b => /\bup\b/.test(b.className) || /höher|mehr|hoch/i.test(b.textContent) ? "up" : /\bdown\b/.test(b.className) || /tiefer|weniger|niedriger|runter/i.test(b.textContent) ? "down" : null;
  let el = btns[Math.floor(Math.random() * btns.length)];
  if (want) { const hit = btns.find(b => dirOf(b) === want); const miss = btns.find(b => dirOf(b) && dirOf(b) !== want); if (hit && miss) el = good ? hit : miss; }
  el.dataset.pick = want ? (dirOf(el) === want ? "right" : "wrong") : "unknown";
  return el;
};

async function answer(P, st, plan) {
  const { name, page } = P;
  const good = Math.random() < P.skill;
  const s = plan.spick;
  switch (st.pk) {
    case "choice": case "bank":
      return fastTap(name, page, PICK_OPT, { want: s ? s.korrekt : null, good }, "answer", { kind: st.pk, korrekt: s ? s.korrekt : null });
    case "multiChoice": {
      const need = Number((/Wähle\s+(\d+)/.exec(await page.locator(".p-need").first().textContent().catch(() => "")) || [])[1] || 2);
      for (let k = 0; k < need; k++) { await fastTap(name, page, () => { const o = [...document.querySelectorAll(".p-opt:not(.chosen)")].filter(e => !e.disabled); return o[Math.floor(Math.random() * o.length)]; }, null, "multi-option"); await sleep(rand(250, 500)); }
      return fastTap(name, page, PICK_NTH, { sel: ".p-choice .btn.green", i: 0 }, "einloggen");
    }
    case "vote": return fastTap(name, page, PICK_NTH, { sel: ".vote-card", i: P.voteBias }, "vote", { kind: "vote" });
    case "binary": {
      const k = s ? num(s.korrekt) : null;
      const want = k != null && plan.ex && plan.ex.anchor != null ? (k > plan.ex.anchor ? "up" : "down") : null;
      return fastTap(name, page, PICK_BIN, { want, good }, "binary", { kind: "binary", korrekt: s ? s.korrekt : null, anchor: plan.ex ? plan.ex.anchor : null });
    }
    case "number": {
      const nl = plan.ex || {};
      const range = page.locator(".p-number input[type=range]").first();
      const box = await range.boundingBox().catch(() => null);
      const k = s ? num(s.korrekt) : null;
      if (box && nl.min != null && nl.max != null) {
        const target = k != null ? k * (1 + (good ? rand(-0.06, 0.06) : rand(-0.45, 0.45))) : rand(nl.min, nl.max);
        const tv = Math.min(nl.max, Math.max(nl.min, target));
        const f = nl.log ? (Math.log(tv) - Math.log(nl.min)) / (Math.log(nl.max) - Math.log(nl.min)) : (tv - nl.min) / (nl.max - nl.min);
        // Drag the thumb from the middle to the guess (a visible slide), then fine-tune with a stepper tap.
        const y = box.y + box.height / 2, x0 = box.x + box.width / 2, x1 = box.x + 10 + Math.min(1, Math.max(0, f)) * (box.width - 20);
        await page.mouse.move(x0, y); await page.mouse.down();
        for (let i = 1; i <= 12; i++) { await page.mouse.move(x0 + ((x1 - x0) * i) / 12, y); await sleep(35); }
        await page.mouse.up();
        act(name, "slide", { kind: "number", target: Math.round(tv), korrekt: s ? s.korrekt : null, x: Math.round(x1), y: Math.round(y) });
        await sleep(rand(350, 600));
        await fastTap(name, page, PICK_NTH, { sel: ".stepper .st-btn", i: Math.random() < 0.5 ? 1 : 2 }, "stepper");
        await sleep(rand(300, 500));
      }
      return fastTap(name, page, PICK_NTH, { sel: ".p-number .btn.green", i: 0 }, "tipp-abgeben", { kind: "number" });
    }
    case "wager": {
      await fastTap(name, page, PICK_NTH, { sel: ".quick-bets .qb", i: good ? 1 : 2 }, "quick-bet");
      await sleep(400);
      return fastTap(name, page, PICK_NTH, { sel: ".p-number .btn.big", i: 0 }, "setzen");
    }
    case "order": return fastTap(name, page, PICK_NTH, { sel: ".btn.green", i: 0 }, "order-lock");
    case "chips": {
      for (let i = 0; i < 3; i++) { await fastTap(name, page, PICK_NTH, { sel: ".cl-btn.plus", i: null }, "chip+"); await sleep(250); }
      return fastTap(name, page, PICK_NTH, { sel: ".p-chips .btn.green", i: 0 }, "chips-lock");
    }
    case "pickPlayer": return fastTap(name, page, PICK_NTH, { sel: ".pick-card", i: 0 }, "pick-player");
    case "confirm": return fastTap(name, page, PICK_NTH, { sel: ".p-confirm .btn.green", i: 0 }, "confirm");
    case "explain": return fastTap(name, page, PICK_NTH, { sel: ".p-explain .btn.green", i: 0 }, "bereit");
    case "buzzer": return fastTap(name, page, PICK_NTH, { sel: ".buzz-btn.armed", i: 0 }, "buzz");
    case "tapFrenzy": case "cheer": {
      const n = Math.floor(rand(8, 16));
      for (let i = 0; i < n; i++) { if (!(await fastTap(name, page, PICK_NTH, { sel: ".tap-btn.armed", i: 0 }, "tap-tap"))) break; await sleep(rand(50, 120)); }
      return true;
    }
  }
  return false;
}

async function phoneAgent(P) {
  let lastKey = null, lastPhase = null, seen = new Set(), tapped = {}, sheetSince = 0;
  while (!done) {
    let st;
    try { st = await P.page.evaluate(READ_PHONE); } catch (_) { await sleep(300); continue; }
    if (!st || !st.pk || st.pk === "join") { await sleep(250); continue; }
    const phaseKey = `${st.ph}/${st.pk}${st.rev ? "-" + st.rev : ""}`;
    if (phaseKey !== lastPhase) {
      lastPhase = phaseKey;
      ev(P.name, phaseKey, { type: "phase", q: (st.q || st.title || "").slice(0, 80) });
      if (!seen.has(phaseKey)) { seen.add(phaseKey); still(P.name, P.page, phaseKey, st.pk === "reveal" ? 1600 : 700); }
    }
    // A sheet we didn't script (joker info, …) would block every later answer: close it.
    if (st.sheet) {
      sheetSince = sheetSince || Date.now();
      if (Date.now() - sheetSince > 900) {
        still(P.name, P.page, "sheet-offen");
        await fastTap(P.name, P.page, () => [...document.querySelectorAll(".p-sheet button")].find(b => /Schließen|Zurück|Abbrechen/.test(b.textContent)) || document.querySelector(".p-sheet .btn.ghost"), null, "Sheet schließen");
        sheetSince = 0;
        lastKey = null; // answer the prompt the sheet was covering
        await sleep(400);
      }
    } else sheetSince = 0;
    const key = `${st.pk}|${st.q}|${st.title}|${st.sub}`;
    if (ACTIONABLE.has(st.pk) && !st.locked && !st.sheet && key !== lastKey) {
      lastKey = key;
      const [a, b] = st.pk === "explain" || st.pk === "vote" || st.pk === "confirm" ? P.quick : P.delay;
      const due = Date.now() + rand(a, b) * 1000;
      const plan = await planFor(st, due);
      while (!done && Date.now() < due) await sleep(40);
      const again = await P.page.evaluate(READ_PHONE).catch(() => null);
      if (again && `${again.pk}|${again.q}|${again.title}|${again.sub}` === key && !again.locked) {
        const ok = await answer(P, again, plan).catch(e => { errors.push(`[${P.name}] answer ${st.pk}: ${e.message.split("\n")[0]}`); return false; });
        tapped[st.pk] = (tapped[st.pk] || 0) + 1;
        if (ok && tapped[st.pk] <= 2) still(P.name, P.page, `${st.pk}-getippt`, 250);
        // Didn't take (tap landed elsewhere)? Try once more on the next pass.
        if (["choice", "bank", "vote", "binary", "number"].includes(st.pk)) {
          await sleep(700);
          const after = await P.page.evaluate(READ_PHONE).catch(() => null);
          if (after && `${after.pk}|${after.q}|${after.title}|${after.sub}` === key && !after.locked && !after.sheet && !P.retried?.[key]) { P.retried = { ...(P.retried || {}), [key]: 1 }; lastKey = null; act(P.name, "retry", { kind: st.pk }); }
        }
      }
    }
    await sleep(90);
  }
}

// ---------- GM scripted moments ----------
async function gmPart1() { // Fragen tab: toggle a category, ban a question (during the long herd round)
  gmBusy = true;
  const g = gm.page;
  try {
    await sleep(1500);
    await tap("gm", g, ".gm-tabs button:has-text('Fragen')", "tab Fragen");
    await sleep(1300);
    still("gm", g, "fragen-tab");
    await smoothTo(g, ".kt-filters .kt-cat");
    await sleep(500);
    const ids = await g.$$eval(".kt-filters .kt-cat", els => els.map(e => [e.dataset.id, e.classList.contains("off")]));
    const cat = (ids.find(([id, off]) => id === "sport" && !off) || ids.find(([, off]) => !off) || [])[0];
    if (cat) {
      await smoothTo(g, `.kt-filters .kt-cat[data-id="${cat}"]`);
      await tap("gm", g, `.kt-filters .kt-cat[data-id="${cat}"] .kt-sw`, `Kategorie ${cat} aus`, { detail: { cmd: "settingsSet", kategorieAus: cat } });
      await sleep(1300);
      still("gm", g, "kategorie-aus");
    }
    await smoothTo(g, ".kt-tabs", "start");
    await tap("gm", g, ".kt-tabs button:has-text('Fragen durchsuchen')", "Fragen durchsuchen");
    await sleep(1400);
    const q = g.locator(".kt-browser .kt-q:not(.banned)").first();
    const qid = await q.getAttribute("data-id").catch(() => null);
    if (qid) {
      await smoothTo(g, `.kt-browser .kt-q[data-id="${qid}"]`);
      await tap("gm", g, `.kt-browser .kt-q[data-id="${qid}"] .kt-q-head`, "Frage aufklappen");
      await sleep(1100);
      await tap("gm", g, `.kt-browser .kt-q[data-id="${qid}"] .kt-ban`, "Frage bannen", { detail: { cmd: "questionBan", frageId: qid } });
      await sleep(1200);
      still("gm", g, "frage-gebannt");
      await sleep(600);
    }
    await scrollTop(g);
    await sleep(700);
    await tap("gm", g, ".gm-tabs button:has-text('Regie')", "tab Regie");
    await sleep(600);
  } catch (e) { errors.push(`[gm] part1 ${e.message}`); }
  gmBusy = false;
}
async function gmPart2() { // +15 s on the running estimate question
  gmBusy = true;
  const g = gm.page;
  try {
    await sleep(1400);
    await smoothTo(g, ".gm-shift");
    await sleep(300);
    await tap("gm", g, ".gm-shift button:has-text('+15')", "+15 s", { detail: { cmd: "timerShift", ms: 15000 } });
    await sleep(700);
    still("gm", g, "timer-plus15");
    still("stage", stage.page, "timer-plus15", 150);
    await sleep(1200);
    await scrollTop(g);
  } catch (e) { errors.push(`[gm] part2 ${e.message}`); }
  gmBusy = false;
}
async function gmPart3() { // pause with a text, then resume
  gmBusy = true;
  const g = gm.page;
  try {
    await sleep(2600);
    await tap("gm", g, ".gm-dock-pause", "Pause-Sheet");
    await sleep(900);
    await tap("gm", g, ".gm-sheet .pick:has-text('Kurze Pause')", "Text: Kurze Pause");
    await sleep(700);
    still("gm", g, "pause-sheet");
    await sleep(500);
    await tap("gm", g, ".gm-sheet .btn:has-text('Pause starten')", "Pause starten", { detail: { cmd: "pause" } });
    for (let i = 0; i < 20 && !(await api(PORT, "/api/dev/stage")).paused; i++) await sleep(150);
    await sleep(1500);
    still("gm", g, "pausiert");
    still("stage", stage.page, "pause");
    await sleep(2600);
    await tap("gm", g, ".gm-next.green", "Fortsetzen", { timeout: 6000, detail: { cmd: "resume" } }); // .green = the cockpit shows the pause → the press sends resume
    await sleep(800);
    if ((await api(PORT, "/api/dev/stage")).paused) { await gmCmd({ resume: {} }); act("gm", "resume", { via: "ws" }); }
  } catch (e) { errors.push(`[gm] part3 ${e.message}`); }
  gmBusy = false;
}

// ---------- show flow ----------
function holdFor(sc, n, label) {
  switch (sc.kind) {
    // Holds are measured from when the scene shows up here; reveals keep their money count-up (~5 s).
    case "intro": return 4.0;
    case "erklaerkarte": return n === 1 ? 4.2 : 3.3;
    case "kategorieWahl": return 4.0;
    case "aufloesung":
      if (/affenzahn|letzter-affe|herdentrieb|affenschaukel/.test(sc.key)) return 6.0;
      if (/Jackpot/i.test(label)) return 5.6;
      return 4.7;
    case "zwischenstand": return /Runde 6\//.test(label) ? 4.6 : 4.0;
    case "rad": return sc.sub === "erklaert" ? 3.3 : sc.sub === "interaktion" ? 4.2 : sc.sub === "fertig" ? 1.6 : null;
    case "highlights": return 4.6;
    case "halbzeit": return 4.0;
    default: return null; // frage (resolves itself), lobby, pause (GM), siegerehrung/ende (handled below)
  }
}
const STILL_DELAY = { intro: 2500, erklaerkarte: 1600, kategorieWahl: 2200, frage: 1500, aufloesung: 2900, zwischenstand: 2600, rad: 1800, highlights: 2500, pause: 1500, halbzeit: 1500, siegerehrung: 1200, ende: 2600 };

// Health: event-loop lag of this process and the slowest stage poll (logged when > 1 s).
const lag = { max: 0, last: Date.now() };
const slowest = { api: 0 };
setInterval(() => { const d = Date.now() - lag.last - 200; if (d > lag.max) lag.max = d; lag.last = Date.now(); }, 200).unref();
async function runShow() {
  const counts = {};
  const trig = new Set();
  let inst = null; // current scene instance
  let lastSig = "", sigSince = Date.now(), lastSub = "";
  let podiumAt = null, creditsAt = null, lastPollStart = Date.now();
  while (!done) {
    if (now() > MAXSEC) { log("MAXSEC reached"); break; }
    let v;
    const tq = Date.now();
    try { v = await api(PORT, "/api/dev/stage"); } catch (_) { await sleep(300); continue; }
    const apiMs = Date.now() - tq;
    pushLatency(apiMs);
    const prevPoll = lastPollStart;
    lastPollStart = tq;
    if (apiMs > slowest.api) slowest.api = apiMs;
    if (apiMs > 1500) log("slow /api/dev/stage", apiMs, "ms · event-loop lag", lag.max, "ms");
    if (!v || !v.scene) { await sleep(200); continue; }
    const sc = sceneOf(v);
    const label = v.sectionLabel || "";
    if (!inst || inst.key !== sc.key) {
      counts[sc.key] = (counts[sc.key] || 0) + 1;
      inst = { key: sc.key, kind: sc.kind, start: now(), startEst: prevPoll, paused: 0, n: counts[sc.key] }; // startEst: earliest possible server-side start
      stageScene = sc.key;
      ev("stage", sc.key, { type: "scene", phase: v.phase, section: label, beat: beatOf(label), n: inst.n, advance: v.advanceLabel || null,
        ...(sc.kind === "kategorieWahl" ? { optionen: (sc.body.optionen || []).map(o => o.label) } : {}),
        ...(sc.kind === "erklaerkarte" && sc.body._0 ? { format: sc.body._0.name || sc.body._0.titel || null } : {}),
        ...(sc.kind === "aufloesung" && sc.body.reveal && sc.body.reveal.eintraege ? { answers: sc.body.reveal.eintraege.map(e => ({ name: ((v.players || []).find(p => p.id === e.playerId) || {}).name || e.playerId, ms: e.antwortMs ?? null, richtig: e.richtig ?? null, delta: e.delta })) } : {}),
        ...(sc.kind === "aufloesung" && sc.body.deltas && !sc.body.reveal ? { deltas: Object.fromEntries(Object.entries(sc.body.deltas).map(([id, d]) => [((v.players || []).find(p => p.id === id) || {}).name || id, d])) } : {}) });
      const myInst = inst;
      const fmt = slug((label.split("·")[1] || "").trim());
      const sk = sc.kind === "erklaerkarte" ? `${sc.key}-${fmt || beatOf(label)}` : /Jackpot|Finale/i.test(label) && sc.kind !== "siegerehrung" && sc.kind !== "ende" ? `${sc.key}-${beatOf(label)}` : sc.key;
      if (sc.kind !== "siegerehrung") stillOnce("stage", stage.page, sk, STILL_DELAY[sc.kind] ?? 1500, 2, () => inst === myInst);
      if (sc.kind === "frage" && counts[sc.key] === 1) stillOnce("gm", gm.page, `regie-${sc.key}`, 2600, 1);
      if (sc.kind === "aufloesung" && counts[sc.key] === 1) stillOnce("gm", gm.page, `regie-${sc.key}`, 2200, 1);
      // Scripted GM moments.
      if (sc.key === "frage-herdentrieb-herde" && !trig.has(1)) { trig.add(1); gmPart1(); }
      if (sc.key === "frage-bananen-tresor-numberLine" && !trig.has(2)) { trig.add(2); gmPart2(); }
      if (sc.key === "aufloesung-bananen-tresor-numberLine" && !trig.has(3)) { trig.add(3); gmPart3(); }
    }
    // Sub-beats inside multi-question formats (speed podium per question, survival hits …).
    const subSig = sc.ex && (sc.ex.nummer != null || sc.ex.phase) ? `${sc.ex.nummer}|${sc.ex.phase}` : "";
    if (subSig && subSig !== lastSub) {
      lastSub = subSig;
      ev("stage", sc.key, { type: "sub", nummer: sc.ex.nummer, sub: sc.ex.phase || null });
      if (sc.ex.phase && sc.ex.phase !== "frage") stillOnce("stage", stage.page, `${sc.key}-${sc.ex.phase}`, 1300, 1);
    }
    if (v.paused) inst.paused += 0.15;
    const sig = v.phase + v.seq;
    if (sig !== lastSig) { lastSig = sig; sigSince = Date.now(); }
    const elapsed = now() - inst.start - inst.paused;
    const hold = holdFor(sc, inst.n, label);
    const free = !gmBusy && !v.paused && v.canAdvance && !inst.natural && now() - lastAdvance > 1.4;
    const adv = async () => {
      const r = await advance(sc.key, v.advanceLabel, inst.startEst);
      if (r === "late") { inst.natural = true; ev("stage", sc.key, { type: "info", note: "too close to the phase end for a safe skip — runs out naturally", guardMs: guardMs() }); }
      return r;
    };
    if (free && hold != null && elapsed >= hold) await adv();
    else if (free && sc.kind === "frage" && Date.now() - sigSince > 28000) { log("stuck in frage → resolve"); await adv(); }
    // Ceremony: wait for the full podium (gold), let awards + confetti play, then the credits podium.
    if (sc.kind === "siegerehrung") {
      if (!podiumAt && (await stage.page.$(".ceremony.st-3"))) { podiumAt = now(); ev("stage", sc.key, { type: "podium" }); still("stage", stage.page, "siegerehrung-podium", 1800); still("phone1", phone1.page, "siegerehrung", 500); still("gm", gm.page, "siegerehrung", 500); }
      if (podiumAt && free && now() - podiumAt >= 6.5) await adv();
    }
    if (sc.kind === "ende") {
      if (!creditsAt && (await stage.page.$(".credits .cp"))) { creditsAt = now(); ev("stage", sc.key, { type: "podium", credits: true }); still("stage", stage.page, "ende-podium", 2200); still("phone1", phone1.page, "ende", 1500); still("phone2", phone2.page, "ende", 1500); }
      if (creditsAt && now() - creditsAt >= 5.0) break;
    }
    await sleep(150);
  }
}

// Mode screen "Eigene Show": tap the formats into the playlist and step the question counts —
// purely for the footage; the start request is patched with PATCH either way.
async function buildPlaylist() {
  const p = stage.page;
  if (!(await p.$(".es-card[data-format]"))) { act("stage", "playlist-builder-missing"); return; }
  for (const item of PATCH.eigenePlaylist) {
    const sel = `.es-lib .es-card[data-format="${item.id}"]`;
    if (!(await p.$(sel))) await tap("stage", p, '.es-fchip[data-art="alle"]', "Filter Alle");
    const hidden = await p.evaluate(s => {
      const el = document.querySelector(s); if (!el) return false;
      let box = el.parentElement; while (box && box !== document.body && !/(auto|scroll)/.test(getComputedStyle(box).overflowY)) box = box.parentElement;
      const r = el.getBoundingClientRect(), c = box && box !== document.body ? box.getBoundingClientRect() : { top: 0, bottom: innerHeight };
      return r.top < c.top || r.bottom > c.bottom;
    }, sel).catch(() => false);
    if (hidden) await smoothTo(p, sel, "nearest");
    await fastTap("stage", p, PICK_NTH, { sel, i: 0 }, `+ ${item.id}`, { playlist: item.id });
    await sleep(420);
  }
  await sleep(300);
  for (let i = 0; i < PATCH.eigenePlaylist.length; i++) {
    const cur = await p.evaluate(k => { const r = document.querySelectorAll(".es-rows .es-row")[k]; const b = r && r.querySelector(".es-step b"); return b ? Number(b.textContent) : null; }, i).catch(() => null);
    if (cur == null) continue;
    const d = PATCH.eigenePlaylist[i].fragen - cur;
    for (let k = 0; k < Math.abs(d); k++) {
      await fastTap("stage", p, ({ i, up }) => { const r = document.querySelectorAll(".es-rows .es-row")[i]; return r ? r.querySelectorAll(".es-step .es-sb")[up ? 1 : 0] : null; }, { i, up: d > 0 }, d > 0 ? "Frage +" : "Frage −", { row: i });
      await sleep(170);
    }
    await sleep(200);
  }
  const shown = await p.evaluate(() => [...document.querySelectorAll(".es-rows .es-row")].map(r => `${(r.querySelector(".es-r-name b") || {}).textContent}×${(r.querySelector(".es-step b") || {}).textContent}`)).catch(() => []);
  act("stage", "playlist-built", { rows: shown });
  await sleep(700);
  still("stage", p, "modes-playlist");
  await sleep(900);
}

// ---------- the script ----------
const t0wall = Date.now();
let summary = null;
try {
  // 1. Stage: menu → mode choice (all 7 modes) → "Eigene Show" + Zackig → lobby.
  stage = await openPage("stage", { viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  recs.push(stage.rec);
  await stage.page.route("**/api/host/start", async route => {
    let body = {};
    try { body = JSON.parse(route.request().postData() || "{}"); } catch (_) {}
    body.modus = "eigen";
    body.patch = { ...(body.patch || {}), ...PATCH };
    await route.continue({ postData: JSON.stringify(body) });
  });
  await stage.page.goto(`${BASE}/stage`);
  await stage.page.waitForSelector("text=Neue Show starten", { timeout: 15000 });
  await sleep(500);
  T0 = Date.now() / 1000;
  await stage.rec.start();
  ev("stage", "menu", { type: "scene", phase: "menu" });
  still("stage", stage.page, "menu", 1200);
  await sleep(2600);
  await stage.page.mouse.click(8, 8); // unlock audio
  await tap("stage", stage.page, "text=Neue Show starten", "Neue Show starten");
  await stage.page.waitForSelector('.mode-card[data-mode="eigen"]', { timeout: 8000 });
  ev("stage", "modes", { type: "scene", phase: "modes", count: await stage.page.locator(".mode-card").count() });
  still("stage", stage.page, "modes", 1300);
  await sleep(3200);
  await tap("stage", stage.page, '.mode-card[data-mode="eigen"]', "Modus Eigene Show");
  await sleep(1100);
  await buildPlaylist();
  await tap("stage", stage.page, ".mode-options .seg button:has-text('Zackig')", "Tempo Zackig");
  await sleep(900);
  still("stage", stage.page, "modes-eigen");
  await sleep(600);
  await tap("stage", stage.page, "text=Lobby öffnen", "Lobby öffnen");
  await stage.page.waitForSelector(".lobby", { timeout: 10000 });
  const code = String(await api(PORT, "/api/dev/code")).trim();
  const pin = String(await api(PORT, "/api/dev/pin")).trim();
  let s0 = (await gmView()).settings;
  const settingsOk = s => s.modus === "eigen" && (s.eigenePlaylist || []).length === PATCH.eigenePlaylist.length;
  ev("stage", "lobby", { type: "scene", phase: "lobby", code, settingsOk: settingsOk(s0) });
  still("stage", stage.page, "lobby-leer", 1500);

  // 2. GM logs in (visible PIN typing), phones join, bots pop in.
  const monkey0 = { fn: () => { if (!localStorage.getItem("mm:look")) localStorage.setItem("mm:look", JSON.stringify({ affeId: "don-bananas", farbe: "gelb" })); } };
  [gm, phone1, phone2] = await Promise.all([
    openPage("gm", MOBILE, [{ fn: WS_JS }]),
    openPage("phone1", MOBILE, [monkey0]),
    openPage("phone2", MOBILE, [monkey0]),
  ]);
  recs.push(phone1.rec, phone2.rec, gm.rec);
  if (!ONE_BROWSER) log("threads reniced — phones +4:", ["phone1", "phone2"].map(k => deprioritize(k, 4)).join("/"), "· stage −4:", deprioritize("stage", -4));
  await Promise.all([
    (async () => { await gm.page.goto(`${BASE}/gm?code=${code}`); await gm.page.waitForSelector('input[placeholder="PIN"]'); await sleep(300); await gm.rec.start(); })(),
    (async () => { await phone1.page.goto(`${BASE}/j/${code}`); await phone1.page.waitForSelector(".name-in"); await sleep(300); await phone1.rec.start(); })(),
    (async () => { await phone2.page.goto(`${BASE}/j/${code}`); await phone2.page.waitForSelector(".name-in"); await sleep(300); await phone2.rec.start(); })(),
  ]);
  const gmLogin = (async () => {
    const g = gm.page;
    await sleep(700);
    await g.locator('input[placeholder="PIN"]').click();
    await g.locator('input[placeholder="PIN"]').pressSequentially(pin, { delay: 170 });
    act("gm", "type", { what: "PIN" });
    await sleep(500);
    await tap("gm", g, "text=Regie übernehmen", "Regie übernehmen");
    await g.waitForSelector(".cockpit", { timeout: 8000 });
    still("gm", g, "regie-lobby", 900);
    await sleep(1200);
    if (!settingsOk((await gmView()).settings)) { await gmCmd({ settingsSet: { _0: PATCH } }); act("gm", "settingsSet", { via: "ws", fallback: true }); }
    await tap("gm", g, ".gm-tabs button:has-text('Spieler')", "tab Spieler");
  })();
  const join = async (P, name, how) => {
    const p = P.page;
    still(P.name, p, "join-leer", 200);
    await sleep(500);
    await how(p);
    await sleep(500);
    await p.locator(".name-in").first().click();
    await p.locator(".name-in").first().pressSequentially(name, { delay: 150 });
    act(P.name, "type", { what: "name", name });
    await sleep(600);
    still(P.name, p, "join-fertig");
    await sleep(300);
    await tap(P.name, p, "text=Rein da!", "Rein da!", { detail: { join: name } });
    await p.waitForSelector(".game", { timeout: 8000 });
    ev(P.name, "joined", { type: "action", action: "join", name });
    still(P.name, p, "lobby", 1500);
  };
  const joinLena = join({ name: "phone1", page: phone1.page }, "Lena", async p => {
    for (let i = 0; i < 3; i++) { await tap("phone1", p, ".j-arrow >> nth=0", "Affe zurück"); await sleep(650); }
    await tap("phone1", p, '.swatch[aria-label="pink"]', "Farbe pink");
  });
  await sleep(2600);
  const joinTarik = join({ name: "phone2", page: phone2.page }, "Tarik", async p => {
    await tap("phone2", p, '.j-thumb[aria-label="Pumper-Paule"]', "Affe Pumper-Paule");
    await sleep(700);
    await tap("phone2", p, '.swatch[aria-label="blau"]', "Farbe blau");
  });
  await Promise.all([gmLogin, joinLena, joinTarik]);
  await sleep(900);
  for (const [label, persona] of BOTS) {
    const before = (await api(PORT, "/api/dev/stage")).players.length;
    if (!(await gmCmd({ botAdd: { name: label, persona } }))) await api(PORT, "/api/host/bots", { add: 1 });
    act("gm", "botAdd", { name: label, persona });
    await sleep(600);
    if ((await api(PORT, "/api/dev/stage")).players.length <= before) { await api(PORT, "/api/host/bots", { add: 1 }); act("gm", "botAdd", { name: label, via: "host-api-fallback" }); await sleep(300); }
  }
  const players = (await api(PORT, "/api/dev/stage")).players.map(p => p.name);
  ev("stage", "lobby", { type: "info", players });
  await sleep(1400);
  still("stage", stage.page, "lobby-voll");
  still("gm", gm.page, "spieler-lobby");
  await sleep(1600);
  s0 = (await gmView()).settings;
  ev("stage", "lobby", { type: "info", settings: { modus: s0.modus, tempo: s0.tempo, radAn: s0.radAn, typenAus: s0.typenAus, eigenerJackpot: s0.eigenerJackpot, playlist: s0.eigenePlaylist.map(x => `${x.id}×${x.fragen}`) } });

  // 3. Start; phones play along, GM steers.
  const agents = [
    phoneAgent({ name: "phone1", page: phone1.page, skill: 0.97, delay: [1.0, 1.6], quick: [0.9, 1.5], voteBias: 0 }),
    phoneAgent({ name: "phone2", page: phone2.page, skill: 0.55, delay: [1.5, 2.5], quick: [1.2, 2.1] }),
  ];
  await tap("gm", gm.page, ".gm-tabs button:has-text('Regie')", "tab Regie");
  await sleep(500);
  await tap("stage", stage.page, ".start-btn", "Show starten!");
  await runShow();
  done = true;
  await Promise.all(agents);
  await Promise.all(Object.values(stillQ));

  // Stage sound log on the shared clock (for sound design in the edit).
  try {
    const audio = await stage.page.evaluate(() => window.__mmAudio || []);
    writeFileSync(path.join(OUT, "audio.json"), JSON.stringify(audio.map(a => ({ ...a, t: +((a.t / 1000) - T0).toFixed(3) })), null, 1));
  } catch (_) {}
} catch (e) {
  errors.push(`[script] ${e.stack || e.message}`);
  console.error(e);
} finally {
  done = true;
  const stats = [];
  for (const r of recs) { try { stats.push(await r.stop()); } catch (e) { errors.push(`[rec] ${e.message}`); } }
  writeFileSync(path.join(OUT, "events.json"), JSON.stringify(events, null, 1));
  const scenes = events.filter(e => e.page === "stage" && e.detail.type === "scene").map(e => ({ t: e.t, scene: e.scene, section: e.detail.section || "" }));
  summary = { duration: +now().toFixed(1), wall: +((Date.now() - t0wall) / 1000).toFixed(1), port: PORT, pages: stats, scenes, errors: [...new Set(errors)] };
  writeFileSync(path.join(OUT, "summary.json"), JSON.stringify(summary, null, 1));
  for (const b of Object.values(browsers)) await b.close().catch(() => {});
  srv.stop();
  console.log("\n==== footage", OUT);
  console.log("duration", summary.duration, "s (recorded) · wall", summary.wall, "s");
  for (const s of stats) console.log(`${s.page.padEnd(6)} ${s.w}×${s.h} frames=${s.frames} fps=${s.fps} (median ${s.medianFps}) longest gap ${s.longestGap}s  t ${s.from}→${s.to}`);
  console.log("scenes:");
  for (const s of scenes) console.log(`  ${s.t.toFixed(1).padStart(6)}  ${s.scene}  ${s.section}`);
  console.log(summary.errors.length ? "ERRORS:\n" + summary.errors.slice(0, 40).join("\n") : "no errors");
}
