// Synthetic test frames for encode.mjs: moving gradient, big frame number,
// timestamp and a 12-bit barcode (bottom-left, MSB first) that verify.mjs decodes.
//   env -u NODE_OPTIONS node tools/trailer/encoder/test/gen-frames.mjs --out DIR [--count 150] [--fps 30] [--width 1280] [--height 720] [--quality 0.9]
import { mkdirSync, readdirSync, rmSync } from "node:fs";
import path from "node:path";
import { launch } from "../../../web/lib.mjs";
import { start, receiveFile, sendJSON } from "../server.mjs";

const arg = (k, d) => { const i = process.argv.indexOf(`--${k}`); return i > 0 ? process.argv[i + 1] : d; };
const OUT = path.resolve(arg("out", "/projects/sandbox/shots/enc/frames"));
const COUNT = Number(arg("count", 150)), FPS = Number(arg("fps", 30));
const W = Number(arg("width", 1280)), H = Number(arg("height", 720)), Q = Number(arg("quality", 0.9));

mkdirSync(OUT, { recursive: true });
for (const f of readdirSync(OUT)) if (/^\d+\.jpe?g$/i.test(f)) rmSync(path.join(OUT, f));

const srv = await start({
  async handle(req, res, url, p) {
    if (p === "/") { res.writeHead(200, { "Content-Type": "text/html" }); res.end("<!doctype html><title>gen</title>"); return true; }
    const m = /^\/save\/(\d+\.jpg)$/.exec(p);
    if (req.method === "POST" && m) { sendJSON(res, { bytes: await receiveFile(req, path.join(OUT, m[1])) }); return true; }
    return false;
  },
});
const browser = await launch();
const t0 = Date.now();
try {
  const page = await browser.newPage();
  await page.goto(srv.url + "/");
  const bytes = await page.evaluate(async ({ COUNT, FPS, W, H, Q }) => {
    const c = document.createElement("canvas"); c.width = W; c.height = H;
    const g = c.getContext("2d");
    let total = 0;
    for (let i = 0; i < COUNT; i++) {
      const t = i / FPS, s = H / 720;
      const grad = g.createLinearGradient(0, 0, W, H);
      grad.addColorStop(0, `hsl(${(i * 4) % 360} 80% 45%)`);
      grad.addColorStop(0.5, `hsl(${(i * 4 + 120) % 360} 80% 55%)`);
      grad.addColorStop(1, `hsl(${(i * 4 + 240) % 360} 80% 40%)`);
      g.fillStyle = grad; g.fillRect(0, 0, W, H);
      // moving ball + sweeping bar
      g.fillStyle = "rgba(255,255,255,0.35)";
      g.beginPath(); g.arc(((i * 12 * s) % (W + 200 * s)) - 100 * s, H * 0.3, 90 * s, 0, 2 * Math.PI); g.fill();
      g.fillStyle = "#000a"; g.fillRect(0, H - 14 * s, W, 14 * s);
      g.fillStyle = "#ffd400"; g.fillRect(0, H - 14 * s, (W * (i + 1)) / COUNT, 14 * s);
      // big frame number + time
      g.textAlign = "center"; g.textBaseline = "middle";
      g.lineWidth = 12 * s; g.strokeStyle = "#000"; g.fillStyle = "#fff";
      g.font = `bold ${300 * s}px sans-serif`;
      g.strokeText(String(i).padStart(3, "0"), W / 2, H * 0.48); g.fillText(String(i).padStart(3, "0"), W / 2, H * 0.48);
      g.font = `bold ${64 * s}px monospace`; g.lineWidth = 6 * s;
      const label = `t=${t.toFixed(3)}s  frame ${i}`;
      g.strokeText(label, W / 2, H * 0.78); g.fillText(label, W / 2, H * 0.78);
      // barcode: 12 blocks of 32px (scaled), white = 1
      const B = Math.round(32 * s), y = H - 14 * s - B - 8 * s;
      g.fillStyle = "#808080"; g.fillRect(0, y - 8 * s, 12 * B + 16 * s, B + 16 * s);
      for (let k = 0; k < 12; k++) { g.fillStyle = (i >> (11 - k)) & 1 ? "#fff" : "#000"; g.fillRect(8 * s + k * B, y, B, B); }
      const blob = await new Promise(r => c.toBlob(r, "image/jpeg", Q));
      const r = await fetch(`/save/${String(i).padStart(5, "0")}.jpg`, { method: "POST", body: blob });
      total += (await r.json()).bytes;
    }
    return total;
  }, { COUNT, FPS, W, H, Q });
  console.log(`generated ${COUNT} frames ${W}x${H} → ${OUT} (${(bytes / 1048576).toFixed(1)} MiB, ${((Date.now() - t0) / 1000).toFixed(1)} s)`);
} finally {
  await browser.close();
  await srv.close();
}
