// Quick visual check: menu → mode choice → lobby with bots, screenshots into OUT.
//   node tools/web/shoot.mjs [outDir]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-shots";
mkdirSync(OUT, { recursive: true });
const PORT = 8123;
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
try {
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1800);
  await stage.screenshot({ path: `${OUT}/01-menu.png` });
  await stage.click("text=Neue Show starten");
  await sleep(700);
  await stage.screenshot({ path: `${OUT}/02-modes.png` });
  await stage.click("text=Lobby öffnen");
  await sleep(1200);
  await api(PORT, "/api/host/bots", { add: 4 });
  await sleep(2200);
  await stage.screenshot({ path: `${OUT}/03-lobby.png` });
  const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(phone, "phone", errors);
  const code = await api(PORT, "/api/dev/code");
  await phone.goto(`http://127.0.0.1:${PORT}/j/${code}`);
  await sleep(1200);
  await phone.screenshot({ path: `${OUT}/04-join.png` });
} finally {
  await browser.close();
  srv.stop();
}
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "no console errors");
