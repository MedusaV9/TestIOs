// Host-flow check: menu → mode choice → lobby with bots → start → settings
// drawer → save to slot 1 → back to menu (autosave) → saves screen → load →
// paused resume. Plus join page, cockpit tabs and practice mode.
//   node tools/web/shoot.mjs [outDir]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-shots";
mkdirSync(OUT, { recursive: true });
const PORT = Number(process.env.PORT || 8123);
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
const shot = (p, n) => p.screenshot({ path: `${OUT}/${n}.png` });
try {
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1800);
  await shot(stage, "01-menu");
  await stage.click("text=Neue Show starten");
  await sleep(700);
  await shot(stage, "02-modes");
  await stage.click("text=Lobby öffnen");
  await sleep(1200);
  await api(PORT, "/api/host/bots", { add: 4 });
  await sleep(2200);
  await shot(stage, "03-lobby");
  await stage.click("text=Einstellungen ändern");
  await sleep(600);
  await shot(stage, "04-drawer-lobby");
  await stage.click(".drawer header .icon-btn");
  const code = await api(PORT, "/api/dev/code");
  const pin = await api(PORT, "/api/dev/pin");

  const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(phone, "phone", errors);
  await phone.goto(`http://127.0.0.1:${PORT}/j/${code}`);
  await sleep(1200);
  await shot(phone, "05-join");
  const gm = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(gm, "gm", errors);
  await gm.goto(`http://127.0.0.1:${PORT}/gm?code=${code}`);
  await sleep(600);
  await shot(gm, "06-gm-login");
  await gm.fill('input[placeholder="PIN"]', String(pin));
  await gm.click("text=Regie übernehmen");
  await sleep(900);
  for (const t of ["Spieler", "Werkzeuge", "Fragen", "Setup"]) { await gm.click(`.gm-tabs >> text=${t}`); await sleep(400); await shot(gm, `07-gm-${t}`); }
  await gm.click(`.gm-tabs >> text=Werkzeuge`);
  await gm.click(".tool:has-text('Punkte')");
  await sleep(400);
  await shot(gm, "08-gm-sheet");

  await stage.click(".start-btn");
  await sleep(4000);
  await stage.click(".controls .icon-btn[title=Einstellungen]");
  await sleep(600);
  await shot(stage, "09-drawer-show");
  await stage.click("text=💾 Slot 1");
  await sleep(600);
  await stage.click("text=Zurück ins Menü");
  await sleep(400);
  await shot(stage, "10-ask");
  await stage.click(".ask .btn.red");
  await sleep(1800);
  await shot(stage, "11-menu-resume");
  const st = await api(PORT, "/api/host/state");
  console.log("after close: active", st.active, "autosave", !!st.autosave, "slot1", !!st.slots[0]);
  await stage.click("text=Spielstände");
  await sleep(600);
  await shot(stage, "12-saves");
  await stage.click(".save-card:has-text('Slot 1') >> text=Laden");
  await sleep(2500);
  await shot(stage, "13-loaded");
  const st2 = await api(PORT, "/api/host/state");
  const v = await api(PORT, "/api/dev/stage");
  console.log("after load: active", st2.active, "phase", v.phase, "paused", v.paused, "players", v.players.length);
  const u = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true });
  watchConsole(u, "uebung", errors);
  await u.goto(`http://127.0.0.1:${PORT}/uebung`);
  await sleep(1200);
  await shot(u, "14a-uebung-start");
  await u.click(".u-go");
  await u.waitForSelector(".u-q .p-opt", { timeout: 5000 });
  await u.click(".u-q .p-opt");
  await sleep(800);
  await shot(u, "14-uebung");
} finally {
  await browser.close();
  srv.stop();
}
console.log(errors.length ? "ERRORS:\n" + [...new Set(errors)].join("\n") : "no console errors");
