// Contact sheet for the emoji font: renders every drawn emoji big + a few UI-like text lines.
//   node tools/trailer/emoji/sheet.mjs OUT.png [font.ttf] [shapes-x.json ...]
// Without shapes files every shapes-*.json is shown. The font is loaded via @font-face, so the
// sheet also proves the font passes Chromium's font sanitizer (OTS).
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch } from "../../web/lib.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const [out = "/projects/sandbox/shots/emoji-sheet.png", fontFile = path.join(here, "MMEmoji.ttf"), ...files] = process.argv.slice(2);
const shapeFiles = files.length ? files : readdirSync(here).filter(f => /^shapes-.*\.json$/.test(f)).map(f => path.join(here, f));
const items = [];
for (const f of shapeFiles) {
  const data = JSON.parse(readFileSync(path.isAbsolute(f) ? f : path.join(here, f), "utf8"));
  for (const [k, v] of Object.entries(data)) items.push({ ch: String.fromCodePoint(parseInt(k.replace("U+", ""), 16)), name: v.name, file: path.basename(f) });
}
const font = readFileSync(fontFile).toString("base64");
const html = `<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: "SheetEmoji"; src: url(data:font/ttf;base64,${font}); }
body { margin: 0; padding: 24px; background: #221048; color: #fff; font: 16px "Outfit", "Noto Sans", sans-serif; }
.grid { display: grid; grid-template-columns: repeat(10, 1fr); gap: 10px; }
.cell { background: #2f1a63; border-radius: 12px; padding: 8px 4px; text-align: center; }
.cell b { display: block; font: 76px/1.1 "SheetEmoji"; }
.cell.light { background: #f4f1ff; color: #222; }
.cell small { font-size: 11px; opacity: .8; }
.line { font: 700 30px "Noto Sans", "SheetEmoji"; margin: 18px 0 6px; }
</style><body>
<div class="line">${items.slice(0, 12).map(i => i.ch).join(" ")} · Runde 1/3 · 1.250 ${items[0] ? items[0].ch : ""} MM</div>
<div class="grid">${items.map((i, n) => `<div class="cell ${n % 7 === 3 ? "light" : ""}"><b>${i.ch}</b><small>${i.name}<br>U+${i.ch.codePointAt(0).toString(16).toUpperCase()}</small></div>`).join("")}</div>
<script>document.fonts.ready.then(() => { document.body.dataset.ok = [...document.fonts].map(f => f.family + ":" + f.status).join(","); });</script>`;
const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 400 } });
const errors = [];
page.on("console", m => m.type() === "error" && errors.push(m.text()));
await page.setContent(html);
await page.waitForFunction(() => document.body.dataset.ok !== undefined);
await page.evaluate(() => document.fonts.load('76px "SheetEmoji"'));
const status = await page.evaluate(() => [...document.fonts].map(f => f.family + ":" + f.status).join(","));
await page.screenshot({ path: out, fullPage: true });
await browser.close();
console.log(`${out}: ${items.length} emoji, font ${status}${errors.length ? " errors: " + errors.join(" | ") : ""}`);
