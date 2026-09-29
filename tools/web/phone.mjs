// Phone-controller check at iPhone size (390×844): join flow, every prompt the
// show throws at the phone (before/after answering), result cards (right and
// wrong), standings, joker sheet, me-menu, reconnect overlay and the
// "Show beendet" screen. Console errors are reported per page.
//   node tools/web/phone.mjs [outDir] [maxSeconds=420] [formats]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-phone";
const MAX = Number(process.argv[3] || 420) * 1000;
const FORMATS = process.argv[4] || process.env.FORMATS || "bananen-basics,bananen-tresor,kokosnuss-shake,taschendieb,pixel-dschungel,song-snippet,alles-oder-banane";
mkdirSync(OUT, { recursive: true });
const PORT = Number(process.env.PORT || 8126);
let srv = await startServer(PORT);
const browser = await launch();
const errors = [];
const t0 = Date.now();
const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s]`, ...a);
const shots = [];
let n = 0;
const shot = async (page, name) => { const f = `${OUT}/${String(++n).padStart(2, "0")}-${name}.png`; await page.screenshot({ path: f }); shots.push(f); log("shot", f); };

try {
  await api(PORT, "/api/host/start", { modus: process.env.MODUS || "klassik", patch: { tempo: "zackig" } });
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`http://127.0.0.1:${PORT}/stage`);
  await sleep(1500);
  const code = await api(PORT, "/api/dev/code");

  const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  watchConsole(phone, "phone", errors);
  await phone.goto(`http://127.0.0.1:${PORT}/j/${code}`);
  await sleep(900);
  await shot(phone, "join-empty");
  await phone.fill(".name-in", "Tester");
  await phone.click(".j-arrow >> nth=1");
  await phone.click(".swatch >> nth=3");
  await sleep(500);
  await shot(phone, "join-filled");
  await phone.click("text=Rein da!");
  await sleep(1200);
  await api(PORT, "/api/host/bots", { add: 3 });
  await sleep(1200);
  await shot(phone, "lobby");
  // Me-menu with sound toggle.
  await phone.click(".g-me");
  await sleep(500);
  await shot(phone, "menu");
  await phone.click("text=Zurück ins Spiel");
  await sleep(300);

  await api(PORT, "/api/dev/next");
  await sleep(500);
  if (FORMATS) await api(PORT, `/api/dev/formats?ids=${FORMATS}&fragen=1`);

  const seen = new Set();
  let last = "", since = Date.now(), jokerShot = false, stuck = 0;
  const want = async (key, fn) => { if (seen.has(key)) return false; seen.add(key); if (fn) await fn(); return true; };
  while (Date.now() - t0 < MAX) {
    const v = await api(PORT, "/api/dev/stage");
    const st = await phone.evaluate(() => {
      const g = document.querySelector(".game");
      const pk = g ? [...g.classList].find(c => c.startsWith("pk-")) : null;
      const ph = g ? [...g.classList].find(c => c.startsWith("ph-")) : null;
      const rev = document.querySelector(".p-reveal");
      return { pk, ph, rev: rev ? [...rev.classList].find(c => ["ok", "nope", "meh"].includes(c)) : null, locked: !!document.querySelector(".p-locked-note") };
    });
    const pk = st.pk || "none";
    if (pk === "pk-reveal") {
      await want(`reveal-${st.rev}`, async () => { await sleep(2200); await shot(phone, `result-${st.rev}`); });
    } else if (pk === "pk-idle") {
      await want(`idle-${st.ph}`, async () => { await sleep(800); await shot(phone, `wait-${st.ph}`); });
    } else if (pk !== "none" && !st.locked) {
      if (await want(`q-${pk}`, async () => { await sleep(700); await shot(phone, `${pk}-open`); })) {
        // Answer it (optimistic lock) and capture the locked state right away.
        const did = await phone.evaluate(() => {
          const pick = sel => { const els = [...document.querySelectorAll(sel)].filter(e => !e.disabled); return els[Math.floor(Math.random() * els.length)]; };
          const el = pick(".p-opt:not(.dim):not(.chosen)") || pick(".vote-card:not(.on)") || pick(".bin-btn:not(.on)") || pick(".pick-card:not(.on)")
            || pick(".p-number .btn") || pick(".p-order .btn.green") || pick(".p-chips .btn.green") || pick(".p-confirm .btn.green") || pick(".p-explain .btn.green");
          if (el) { el.click(); return true; }
          const t = document.querySelector(".tap-btn.armed, .buzz-btn.armed");
          if (t) { for (let i = 0; i < 6; i++) t.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true })); return true; }
          return false;
        });
        if (did) { await sleep(120); await shot(phone, `${pk}-locked`); }
        if (!jokerShot && (await phone.$(".joker"))) { jokerShot = true; await phone.click(".joker >> nth=0"); await sleep(500); await shot(phone, "joker-sheet"); await phone.click(".p-sheet .btn.ghost"); await sleep(300); }
      }
    }
    // Keep playing: answer whatever is open.
    await phone.evaluate(() => {
      if (Math.random() < 0.4) return;
      const pick = sel => { const els = [...document.querySelectorAll(sel)].filter(e => !e.disabled); return els[Math.floor(Math.random() * els.length)]; };
      const el = pick(".p-opt:not(.dim):not(.chosen)") || pick(".vote-card:not(.on)") || pick(".bin-btn:not(.on)") || pick(".pick-card:not(.on)")
        || pick(".p-number .btn") || pick(".p-order .btn.green") || pick(".p-chips .btn.green") || pick(".p-confirm .btn.green") || pick(".p-explain .btn.green") || pick(".p-feedback .btn.green") || pick(".hand-card:not(.off)");
      if (el) { el.click(); return; }
      const t = document.querySelector(".tap-btn.armed, .buzz-btn.armed");
      if (t) for (let i = 0; i < 5; i++) t.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    });
    const sig = v.phase + v.seq;
    if (sig !== last) { last = sig; since = Date.now(); stuck = 0; }
    else if (Date.now() - since > 7000 && v.canAdvance) { log("advance", v.phase, v.advanceLabel); await api(PORT, "/api/dev/next"); since = Date.now(); }
    if (v.phase === "ende") { await sleep(1500); await shot(phone, "ende"); break; }
    await sleep(500);
  }

  // Connection loss: kill the server → reconnect overlay; bring up a fresh
  // server (new room) → "Show beendet".
  srv.stop();
  await sleep(700);
  await shot(phone, "offline-bar");
  await sleep(3200);
  await shot(phone, "offline-overlay");
  srv = await startServer(PORT);
  await api(PORT, "/api/host/start", { modus: "quick" });
  await sleep(6500);
  await shot(phone, "show-beendet");
  log("seen", [...seen].join(" "));
} finally {
  await browser.close();
  srv.stop();
}
const phoneErrors = [...new Set(errors)].filter(e => e.startsWith("[phone]") && !/WebSocket|ERR_CONNECTION_REFUSED|Failed to load resource/.test(e));
const other = [...new Set(errors)].filter(e => !e.startsWith("[phone]"));
console.log(phoneErrors.length ? "PHONE ERRORS:\n" + phoneErrors.join("\n") : "no phone console errors");
if (other.length) console.log("other pages:\n" + other.slice(0, 20).join("\n"));
console.log(shots.length, "screenshots in", OUT);
