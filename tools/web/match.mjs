// Full-show browser run: the stage (iPad viewport) opens a show from the menu,
// one phone joins through the real join page and plays, bots fill the room.
// Every new scene is screenshotted on stage and phone; console errors and the
// stage's sound log are reported at the end.
//   node tools/web/match.mjs [outDir] [modus=klassik] [maxSeconds=1500] [bots=4]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-match";
const MODUS = process.argv[3] || "klassik";
const MAX = Number(process.argv[4] || 1500) * 1000;
const BOTS = Number(process.argv[5] || 4);
mkdirSync(OUT, { recursive: true });
const PORT = Number(process.env.PORT || 8124);
const FORMATS = process.env.FORMATS || "";
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
const t0 = Date.now();
const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s]`, ...a);

try {
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1200);
  await stage.mouse.click(10, 10); // unlock audio
  await stage.click("text=Neue Show starten");
  await sleep(500);
  await stage.click(`.mode-card[data-mode="${MODUS}"]`);
  await stage.click("text=Zackig");
  await stage.click("text=Lobby öffnen");
  await sleep(1000);
  const code = await api(PORT, "/api/dev/code");

  const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(phone, "phone", errors);
  await phone.goto(`http://127.0.0.1:${PORT}/j/${code}`);
  await sleep(800);
  await phone.fill(".name-in", "Tester");
  await phone.screenshot({ path: `${OUT}/phone-000-join.png` });
  await phone.click("text=Rein da!");
  await sleep(1000);
  const pin = await api(PORT, "/api/dev/pin");
  const gm = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(gm, "gm", errors);
  await gm.goto(`http://127.0.0.1:${PORT}/gm?code=${code}`);
  await sleep(600);
  await gm.fill('input[placeholder="PIN"]', String(pin));
  await gm.click("text=Regie übernehmen");
  await sleep(800);
  await gm.screenshot({ path: `${OUT}/gm-000-lobby.png` });
  await api(PORT, "/api/host/bots", { add: BOTS });
  await sleep(1500);
  await stage.screenshot({ path: `${OUT}/stage-000-lobby.png` });
  await phone.screenshot({ path: `${OUT}/phone-001-lobby.png` });
  await stage.click(".start-btn");
  if (FORMATS) { await sleep(500); await api(PORT, `/api/dev/formats?ids=${FORMATS}&fragen=2`); log("formats", FORMATS); }

  const seen = new Set(), pseen = new Set();
  let n = 1, last = "", since = Date.now();
  while (Date.now() - t0 < MAX) {
    const v = await api(PORT, "/api/dev/stage");
    const kind = Object.keys(v.scene)[0];
    const body = v.scene[kind];
    let key = kind;
    if (kind === "frage" || kind === "aufloesung") key = `${kind}-${body.minigameId}-${Object.keys(body.extra)[0]}`;
    if (kind === "rad") key += "-" + body._0.subphase;
    if (!seen.has(key)) {
      seen.add(key);
      n++;
      log("scene", key);
      await sleep(kind === "aufloesung" ? 3000 : kind === "siegerehrung" ? 5200 : 900);
      await stage.screenshot({ path: `${OUT}/stage-${String(n).padStart(3, "0")}-${key}.png` });
      if (["frage-bananen-basics-none", "aufloesung-bananen-basics-none", "zwischenstand"].includes(key)) await gm.screenshot({ path: `${OUT}/gm-${String(n).padStart(3, "0")}-${key}.png` });
    }
    // Phone plays along.
    const pk = await phone.evaluate(() => { const g = document.querySelector(".game"); return g ? [...g.classList].find(c => c.startsWith("pk-")) : null; });
    if (pk && !pseen.has(pk)) { pseen.add(pk); await sleep(300); await phone.screenshot({ path: `${OUT}/phone-${String(n).padStart(3, "0")}-${pk}.png` }); }
    await phone.evaluate(() => {
      const pick = sel => { const els = [...document.querySelectorAll(sel)].filter(e => !e.disabled); return els[Math.floor(Math.random() * els.length)]; };
      const tap = el => el && el.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true })) && el.click();
      if (Math.random() < 0.5) return;
      const el = pick(".p-opt:not(.dim):not(.chosen)") || pick(".vote-card:not(.on)") || pick(".bin-btn:not(.on)") || pick(".pick-card:not(.on)")
        || pick(".p-main .btn.green") || pick(".p-number .btn") || pick(".hand-card:not(.off)");
      if (el) { el.click(); return; }
      const t = document.querySelector(".tap-btn.armed, .buzz-btn.armed");
      if (t) for (let i = 0; i < 5; i++) tap(t);
    });
    const sig = v.phase + v.seq;
    if (sig !== last) { last = sig; since = Date.now(); }
    else if (Date.now() - since > 9000 && v.canAdvance) { const b = await stage.$(".next-btn"); if (b) { log("advance", v.advanceLabel); await b.click(); } since = Date.now(); }
    if (v.phase === "ende") { await sleep(1500); await stage.screenshot({ path: `${OUT}/stage-999-ende.png` }); await phone.screenshot({ path: `${OUT}/phone-999-ende.png` }); break; }
    await sleep(600);
  }
  const audioLog = await stage.evaluate(() => window.__mmAudio || []);
  writeFileSync(`${OUT}/audio-log.json`, JSON.stringify(audioLog, null, 1));
  const kinds = {};
  for (const a of audioLog) kinds[a.kind + ":" + a.id] = (kinds[a.kind + ":" + a.id] || 0) + 1;
  log("audio events", audioLog.length, "distinct", Object.keys(kinds).length, "decode errors", audioLog.filter(a => a.kind === "error").length);
  log(Object.entries(kinds).sort((a, b) => b[1] - a[1]).slice(0, 40).map(([k, c]) => `${k}×${c}`).join("  "));
} finally {
  await browser.close();
  srv.stop();
}
console.log(errors.length ? "ERRORS:\n" + [...new Set(errors)].join("\n") : "no console errors");
