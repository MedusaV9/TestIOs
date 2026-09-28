// Catalogue + Show-Master check: mode screen catalogue (start patch), lobby
// drawer catalogue (toggle + ban → settings), GM Fragen tab (catalogue +
// browser, type toggle, ban), GM Regie during a question (timer shift,
// replace from catalogue) and after the reveal, players tab + bot sheet.
//   env -u NODE_OPTIONS node tools/web/gm.mjs [outDir]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-gm";
mkdirSync(OUT, { recursive: true });
const PORT = Number(process.env.PORT || 8125);
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
const results = [];
const shot = (p, n) => p.screenshot({ path: `${OUT}/${n}.png` });
// The phone body has a fixed background, so instead of fullPage shots scroll to sections.
async function shotAt(p, n, sel) { await p.evaluate(s => { const el = document.querySelector(s); if (el) window.scrollTo(0, el.getBoundingClientRect().top + window.scrollY - 70); }, sel); await sleep(250); await shot(p, n); }
const check = (name, ok, info = "") => { results.push([ok ? "PASS" : "FAIL", name, info]); console.log(ok ? "✅" : "❌", name, info); };
const gmView = () => api(PORT, "/api/dev/gm");
async function until(fn, ms = 4000) { const t = Date.now(); while (Date.now() - t < ms) { const v = await fn(); if (v) return v; await sleep(150); } return null; }
async function phase() { return (await api(PORT, "/api/dev/stage")).phase; }
async function toPhase(p, ms = 40000) { const t = Date.now(); while (Date.now() - t < ms) { if ((await phase()) === p) return true; await sleep(400); } return false; }

try {
  // ---------- stage: mode screen catalogue ----------
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1500);
  await stage.click("text=Neue Show starten");
  await sleep(600);
  await shot(stage, "20-modes-katalog-entry");
  await stage.click(".modes .kt-entry");
  await sleep(600);
  await shot(stage, "21-modes-katalog-overlay");
  await stage.click('.kt-filters .kt-chip.tier[data-id="ultrahard"]');
  await stage.click('.kt-filters .kt-cat[data-id="sport"] .kt-sw');
  await sleep(300);
  await shot(stage, "22-modes-katalog-toggled");
  await stage.click(".kt-overlay .kt-done");
  await sleep(300);
  const summary = await stage.textContent(".modes .kt-entry small");
  check("mode screen summary shows filter", /Stufe aus/.test(summary) && /Kategorie aus/.test(summary), summary);
  await stage.click("text=Lobby öffnen");
  await sleep(1200);
  let v = await gmView();
  check("start patch applied (schwierigkeitenAus/kategorienAus)", v.settings.schwierigkeitenAus.includes("ultrahard") && v.settings.kategorienAus.includes("sport"), JSON.stringify([v.settings.schwierigkeitenAus, v.settings.kategorienAus]));
  await api(PORT, "/api/host/bots", { add: 4 });
  await sleep(1500);

  // ---------- stage: lobby drawer catalogue ----------
  await stage.click("text=Einstellungen ändern");
  await sleep(600);
  await shot(stage, "23-drawer-katalog-entry");
  await stage.click(".drawer .kt-entry");
  await sleep(1200);
  await shot(stage, "24-lobby-katalog-overlay");
  await stage.click('.kt-filters .kt-cat[data-id="sport"] .kt-sw'); // sport back on
  await stage.click('.kt-filters .kt-cat[data-id="musik"] .kt-sw'); // musik off
  v = await until(async () => { const g = await gmView(); return g.settings.kategorienAus.includes("musik") && !g.settings.kategorienAus.includes("sport") ? g : null; });
  check("lobby toggle arrives (musik aus, sport an)", !!v, v ? JSON.stringify(v.settings.kategorienAus) : "");
  await stage.click('.kt-filters .kt-cat[data-id="gaming"] .kt-row-main');
  await sleep(300);
  const firstQ = await stage.getAttribute(".kt-browser .kt-q", "data-id");
  await stage.click(`.kt-browser .kt-q[data-id="${firstQ}"] .kt-ban`);
  v = await until(async () => { const g = await gmView(); return g.settings.fragenAus.includes(firstQ) ? g : null; });
  check("lobby ban arrives (fragenAus)", !!v, firstQ);
  await stage.click(`.kt-browser .kt-q[data-id="${firstQ}"] .kt-q-head`);
  await sleep(500);
  await shot(stage, "25-lobby-katalog-ban-expanded");
  await stage.fill(".kt-browser .kt-search input", "Pokémon");
  await sleep(900);
  await shot(stage, "26-lobby-katalog-search");
  await stage.click(".kt-overlay .kt-done");
  await stage.click(".drawer header .icon-btn");
  await sleep(300);
  await shot(stage, "27-lobby");

  // ---------- GM ----------
  const code = await api(PORT, "/api/dev/code");
  const pin = await api(PORT, "/api/dev/pin");
  const gm = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(gm, "gm", errors);
  await gm.goto(`http://127.0.0.1:${PORT}/gm?code=${code}`);
  await sleep(600);
  await gm.fill('input[placeholder="PIN"]', String(pin));
  await gm.click("text=Regie übernehmen");
  await sleep(1000);
  await shot(gm, "30-gm-regie-lobby");
  await gm.click(".gm-tabs >> text=Fragen");
  await sleep(700);
  await shot(gm, "31-gm-fragen");
  await shotAt(gm, "31b-gm-fragen-katalog", ".kt-sum");
  await shotAt(gm, "31c-gm-fragen-tree", ".kt-tree");
  await gm.click('.kt-filters .kt-chip[data-id="schaetz"]');
  v = await until(async () => { const g = await gmView(); return g.settings.typenAus.includes("schaetz") ? g : null; });
  check("GM type toggle arrives (typenAus schaetz)", !!v);
  await gm.click('.kt-filters .kt-cat[data-id="gaming"] .kt-row-main');
  await sleep(300);
  await shot(gm, "32-gm-fragen-tree-open");
  await gm.click(".kt-tabs >> text=Fragen durchsuchen");
  await sleep(1000);
  const gq = await gm.getAttribute(".kt-browser .kt-q:not(.banned)", "data-id");
  await gm.click(`.kt-browser .kt-q[data-id="${gq}"] .kt-q-head`);
  await sleep(300);
  await gm.click(`.kt-browser .kt-q[data-id="${gq}"] .kt-ban`);
  v = await until(async () => { const g = await gmView(); return g.settings.fragenAus.includes(gq) ? g : null; });
  check("GM ban arrives (questionBan)", !!v, gq);
  await sleep(300);
  await shot(gm, "33-gm-fragen-browser");
  await gm.click(".gm-tabs >> text=Spieler");
  await sleep(400);
  await shot(gm, "34-gm-spieler");
  await gm.click(".gm-add");
  await sleep(400);
  await shot(gm, "35-gm-bot-sheet");
  await gm.click(".gm-sheet-x");

  // ---------- show: question on the wall ----------
  await stage.click(".start-btn");
  await gm.click(".gm-tabs >> text=Regie");
  for (let i = 0; i < 12 && (await phase()) !== "frage"; i++) { await api(PORT, "/api/dev/next"); await sleep(400); }
  check("reached a question", (await phase()) === "frage");
  // Bots answer within seconds and a fully answered question reveals itself — replace right away.
  const before = (await gmView()).aktuelleFrageId;
  await gm.click('.gm-act:has-text("Aus Katalog")');
  await gm.waitForSelector(".gm-sheet .kt-q .kt-pick", { timeout: 4000 });
  await shot(gm, "41-gm-pick-sheet");
  const pickId = await gm.getAttribute(".gm-sheet .kt-q:not(.banned):not(.out)", "data-id");
  await gm.click(`.gm-sheet .kt-q[data-id="${pickId}"] .kt-pick`);
  v = await until(async () => { const g = await gmView(); return g.aktuelleFrageId === pickId ? g : null; }, 5000);
  check("questionReplace with catalogue pick", !!v, `${before} → ${pickId}`);
  if (!v) { const g = await gmView(); console.log("phase", g.stage.phase, "log:", g.log.slice(-4).map(l => l.text).join(" | ")); }
  await shot(gm, "40-gm-regie-frage");
  const dl = s => { const sc = s.scene.frage; return sc && sc.wall ? sc.wall.deadline : null; };
  const d0 = dl(await api(PORT, "/api/dev/stage"));
  await gm.click('.gm-shift button:has-text("+15")');
  const d1 = await until(async () => { const d = dl(await api(PORT, "/api/dev/stage")); return d && d0 && d - d0 >= 14000 ? d : null; });
  check("timerShift +15 s moves the deadline", !!d1, `${d0} → ${d1}`);
  await sleep(2500);
  await shot(gm, "42-gm-regie-answers-live");
  await shotAt(gm, "40b-gm-regie-antworten", ".gm-answers");
  await shotAt(gm, "40c-gm-regie-regal", ".gm-regal");
  await gm.click(".gm-regal-head");
  await sleep(300);
  await shotAt(gm, "40d-gm-regal-open", ".gm-regal");
  const ok = await toPhase("aufloesung", 60000);
  check("reached the reveal", ok);
  await sleep(1500);
  await gm.evaluate(() => window.scrollTo(0, 0));
  await shot(gm, "43-gm-regie-aufloesung");
  await shotAt(gm, "43b-gm-reveal-card", ".reveal");
  await shot(stage, "44-stage-aufloesung");
  // Pause sheet: custom text + duration.
  await gm.click(".gm-dock-pause");
  await gm.fill(".gm-sheet .text-in", "Kurz Luft holen");
  await gm.click('.gm-sheet .seg button:has-text("3 min")');
  await shot(gm, "45-gm-pause-sheet");
  await gm.click('.gm-sheet .btn:has-text("Pause starten")');
  const pv = await until(async () => { const st = await api(PORT, "/api/dev/stage"); return st.paused ? st : null; });
  check("pause with text arrives", !!pv && JSON.stringify(pv.scene).includes("Kurz Luft holen"), pv ? Object.keys(pv.scene)[0] : "");
  await sleep(500);
  await shot(gm, "46-gm-paused");
} finally {
  await browser.close();
  srv.stop();
}
console.log(errors.length ? "ERRORS:\n" + [...new Set(errors)].join("\n") : "no console errors");
console.log(`${results.filter(r => r[0] === "PASS").length}/${results.length} checks passed`);
