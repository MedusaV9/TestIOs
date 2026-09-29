#!/usr/bin/env node
// Frame renderer for the trailer composition (tools/trailer/compose/index.html).
//
//   env -u NODE_OPTIONS node tools/trailer/render.mjs --out /projects/sandbox/trailer/frames-draft
//   … --from 9 --to 12.5            partial range (frame numbers stay global: 00270.jpg …)
//   … --every 5                     preview: every 5th frame only
//   … --sheet /path/sheet.png       contact sheet, one frame per 0.5 s (with or without --out)
//   … --at 0.9,2.4,13 --prefix /path/look    single full-res frames → look-0.90.jpg …
//   --quality 92  --port 0  --fps 30 (default from edit.json)
//   --footage DIR                   serve DIR as the footage root instead of /projects/sandbox/trailer/footage
//                                   (e.g. a hard-link snapshot: cp -al footage /tmp/foot-snap, so a re-recording
//                                   cannot delete frames mid-render)
//
// A tiny static server serves the repo root at /, /projects/sandbox/trailer at /trailer/ and any
// file below /projects/sandbox at /fs/<absolute path> (for {"still": "/abs/path.png"} clips).
// Frame i is rendered at t = i / fps via window.renderAt(t) (deterministic; see compose/main.js).
import http from "node:http";
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch } from "../web/lib.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "../..");
const TRAILER = "/projects/sandbox/trailer";
const SANDBOX = "/projects/sandbox";

const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(`--${k}`); return i < 0 ? d : argv[i + 1]; };
const flag = k => argv.includes(`--${k}`);
const OUT = opt("out"), SHEET = opt("sheet"), AT = opt("at"), PREFIX = opt("prefix", "/projects/sandbox/shots/compose/frame");
const FOOTAGE = opt("footage") ? path.resolve(opt("footage")) : null;
const QUALITY = +opt("quality", 92), EVERY = Math.max(1, +opt("every", 1));
if (!OUT && !SHEET && !AT) { console.error("usage: render.mjs --out DIR [--from s --to s --every N] [--sheet out.png] [--at t1,t2 --prefix p]"); process.exit(2); }

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".ttf": "font/ttf", ".otf": "font/otf", ".woff2": "font/woff2", ".m4a": "audio/mp4", ".mp4": "video/mp4" };
function resolveUrl(u) {
  const p = decodeURIComponent(new URL(u, "http://x").pathname);
  let f;
  if (FOOTAGE && p.startsWith("/trailer/footage/")) return path.resolve(path.join(FOOTAGE, p.slice(17))).startsWith(FOOTAGE + "/") ? path.resolve(path.join(FOOTAGE, p.slice(17))) : null;
  if (p.startsWith("/trailer/")) f = path.join(TRAILER, p.slice(9));
  else if (p.startsWith("/fs/")) f = path.resolve("/", p.slice(4));
  else f = path.join(REPO, p);
  f = path.resolve(f);
  if (!(f.startsWith(REPO + "/") || f.startsWith(TRAILER + "/") || f.startsWith(SANDBOX + "/"))) return null;
  return f;
}
const missing = new Set();
function serve() {
  const srv = http.createServer((req, res) => {
    const f = resolveUrl(req.url);
    if (!f || !existsSync(f) || !statSync(f).isFile()) { missing.add(req.url); res.writeHead(404); res.end("not found"); return; }
    res.writeHead(200, { "Content-Type": MIME[path.extname(f).toLowerCase()] || "application/octet-stream", "Cache-Control": "max-age=3600" });
    createReadStream(f).pipe(res);
  });
  return new Promise(r => srv.listen(+opt("port", 0), "127.0.0.1", () => r(srv)));
}

const t0 = Date.now();
const srv = await serve();
const port = srv.address().port;
const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
const errors = [];
page.on("console", m => { if ((m.type() === "error" || m.type() === "warning") && !/^Failed to load resource/.test(m.text())) errors.push(m.text()); });
page.on("pageerror", e => errors.push(String(e)));
page.on("response", r => { if (r.status() >= 400 && !/events\.json|index\.json/.test(r.url())) errors.push(`HTTP ${r.status()} ${r.url()}`); });
await page.goto(`http://127.0.0.1:${port}/tools/trailer/compose/index.html`);
const info = await page.evaluate(() => window.__ready);
const fps = +opt("fps", info.fps), total = Math.round(info.duration * fps);
const used = info.clips.reduce((m, c) => (m[c.kind] = (m[c.kind] || 0) + 1, m), {});
console.log(`composition ready in ${((Date.now() - t0) / 1000).toFixed(1)}s — ${info.duration}s @ ${fps} fps = ${total} frames; clips: ${JSON.stringify(used)}${FOOTAGE ? ` (footage from ${FOOTAGE})` : ""}`);
for (const c of info.clips) if (c.kind !== "footage") console.log(`  ${c.name.padEnd(18)} ${c.kind}${c.src ? " " + c.src : ""}`); else console.log(`  ${c.name.padEnd(18)} footage ${c.page} ${c.from?.toFixed(2)}→${c.to?.toFixed(2)}`);

const renderAt = async t => { await page.evaluate(tt => window.renderAt(tt), t); };
const shot = async (t, file, quality = QUALITY) => { await renderAt(t); return page.screenshot({ type: "jpeg", quality, path: file }); };

// warm-up: touch every scene once so lazily-created layers/masks are decoded before the timed pass
for (let t = 0; t < info.duration; t += 1.0) await renderAt(t);

if (AT) {
  mkdirSync(path.dirname(PREFIX), { recursive: true });
  for (const s of AT.split(",").map(Number)) { const f = `${PREFIX}-${s.toFixed(2)}.jpg`; await shot(Math.round(s * fps) / fps, f); console.log("wrote", f); }
}

if (OUT) {
  mkdirSync(OUT, { recursive: true });
  const from = Math.max(0, Math.round(+opt("from", 0) * fps)), to = Math.min(total, Math.round(+opt("to", info.duration) * fps));
  const tr = Date.now(); let n = 0;
  for (let i = from; i < to; i++) {
    if ((i - from) % EVERY) continue;
    await shot(i / fps, path.join(OUT, String(i).padStart(5, "0") + ".jpg")); n++;
    if (n % 60 === 0) process.stdout.write(`  ${n} frames (${((Date.now() - tr) / n).toFixed(0)} ms/frame)\n`);
  }
  const sec = (Date.now() - tr) / 1000;
  console.log(`rendered ${n} frames to ${OUT} in ${sec.toFixed(1)}s (${((sec * 1000) / Math.max(1, n)).toFixed(0)} ms/frame)`);
  writeFileSync(path.join(OUT, "render.json"), JSON.stringify({ fps, width: 1920, height: 1080, from, to, every: EVERY, frames: n, seconds: sec, clips: info.clips }, null, 1));
}

if (SHEET) {
  const thumbs = [];
  for (let s = 0; s < info.duration; s += 0.5) {
    await renderAt(Math.round(s * fps) / fps);
    thumbs.push({ s, b64: (await page.screenshot({ type: "jpeg", quality: 70 })).toString("base64") });
  }
  const sp = await browser.newPage({ viewport: { width: 2240, height: 800 }, deviceScaleFactor: 1 });
  await sp.setContent(`<body style="margin:0;background:#111;color:#ddd;font:600 15px sans-serif;display:grid;grid-template-columns:repeat(7,316px);gap:4px;padding:4px">` +
    thumbs.map(x => `<div><img style="width:316px;display:block" src="data:image/jpeg;base64,${x.b64}"><div style="padding:2px 4px">${x.s.toFixed(1)} s</div></div>`).join("") + `</body>`);
  await sp.evaluate(() => Promise.all([...document.images].map(i => i.decode())));
  mkdirSync(path.dirname(SHEET), { recursive: true });
  await sp.screenshot({ path: SHEET, fullPage: true });
  console.log("wrote sheet", SHEET);
}

if (errors.length) console.log("page messages:\n  " + [...new Set(errors)].slice(0, 20).join("\n  "));
const miss = [...missing].filter(u => !/events\.json|index\.json|favicon/.test(u));
if (miss.length) console.log(`missing files (${miss.length}):\n  ` + miss.slice(0, 20).join("\n  "));
console.log(`total ${((Date.now() - t0) / 1000).toFixed(1)}s`);
await browser.close();
srv.close();
