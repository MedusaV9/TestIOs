// Spiele-Abend check: open a game night from the menu, seat bots (and one
// pass-and-play seat on the iPad), start every board game, screenshot the how-to
// and the running board, then abort and continue with the next game.
//   node tools/web/boards.mjs [outDir]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-boards";
mkdirSync(OUT, { recursive: true });
const PORT = Number(process.env.PORT || 8125);
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
try {
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1200);
  await stage.click("text=Spiele-Abend");
  await sleep(1200);
  await api(PORT, "/api/host/bots", { add: 3 });
  await sleep(1500);
  await stage.screenshot({ path: `${OUT}/00-lobby.png` });
  const games = await stage.$$eval(".game-card b", els => els.map(e => e.textContent));
  let i = 0;
  for (const name of games) {
    i++;
    await stage.click(`.game-card:has-text("${name}")`);
    await sleep(500);
    const seat = await stage.$(".seat-input input");
    if (seat) { await seat.fill("Oma"); await stage.keyboard.press("Enter"); }
    await stage.screenshot({ path: `${OUT}/${i}a-sheet.png` });
    const go = await stage.$(".sheet .btn:not(.ghost):not([disabled])");
    if (!go) { console.log("not startable:", name); await stage.click(".sheet .btn.ghost"); continue; }
    await go.click();
    await sleep(2500);
    await stage.screenshot({ path: `${OUT}/${i}b-howto.png` });
    // Skip the how-to, let bots play a bit; answer local-seat prompts with the first button.
    for (let k = 0; k < 3; k++) { const n = await stage.$(".next-btn"); if (n) await n.click(); await sleep(400); }
    for (let t = 0; t < 14; t++) {
      await sleep(1000);
      await stage.evaluate(() => { const b = document.querySelector(".local-seat button:not([disabled])"); if (b) b.click(); });
    }
    await stage.screenshot({ path: `${OUT}/${i}c-play.png` });
    const v = await api(PORT, "/api/dev/stage");
    console.log(name, "→", v.phase, JSON.stringify(v.scene).slice(0, 80));
    const abort = await stage.$("text=Spiel abbrechen");
    if (abort) await abort.click();
    await sleep(1500);
  }
} finally {
  await browser.close();
  srv.stop();
}
console.log(errors.length ? "ERRORS:\n" + [...new Set(errors)].join("\n") : "no console errors");
