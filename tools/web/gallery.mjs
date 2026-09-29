// Phone gallery at iPhone SE (320×568), iPhone (390×844) and Pro Max (430×932):
//   prompts — the real phone app with a mocked WebSocket: every prompt kind
//             (open / pending / locked), long texts, 2 vs 8 options, joker dock
//             vs result card, keyboard open on text inputs, landscape.
//   uebung  — the Übungsmodus flow against the real practice endpoints.
//   gm      — the Show-Master cockpit: every tab, sheets, Regie during a question.
// Every state gets automatic layout checks (horizontal overflow, off-screen
// elements, tap targets < 44 px, tiny fonts, joker dock covering content).
// Per case a contact sheet (all widths side by side) is written to OUT/sheets.
//   env -u NODE_OPTIONS MM_SERVER=… PORT=8444 node tools/web/gallery.mjs outDir [sections=prompts,uebung,gm] [filter]
import { startServer, launch, watchConsole, sleep, api } from "./lib.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const OUT = process.argv[2] || "/tmp/mm-gallery";
const SECTIONS = (process.argv[3] || "prompts,uebung,gm").split(",");
const FILTER = process.argv[4] ? new RegExp(process.argv[4]) : null;
const PORT = Number(process.env.PORT || 8444);
const SIZES = (process.env.SIZES || "320x568,390x844,430x932").split(",").map(s => s.split("x").map(Number));
mkdirSync(`${OUT}/sheets`, { recursive: true });
const srv = await startServer(PORT);
const browser = await launch();
const errors = [];
const issues = [];
const t0 = Date.now();
const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s]`, ...a);
const sheets = new Map(); // case → [{w, h, file}]
const BASE = `http://127.0.0.1:${PORT}`;

// ---------- layout checks ----------
async function audit(page, name) {
  const r = await page.evaluate(() => {
    const W = innerWidth, out = { hOverflow: 0, off: [], small: [], tiny: [], covered: [] };
    const se = document.scrollingElement;
    out.hOverflow = Math.max(0, se.scrollWidth - se.clientWidth);
    const vis = el => { const s = getComputedStyle(el); if (s.visibility === "hidden" || s.display === "none" || Number(s.opacity) === 0) return false; const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
    const label = el => (el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/).slice(0, 2).join(".") : el.tagName.toLowerCase()) + (el.textContent ? ` "${el.textContent.trim().slice(0, 24)}"` : "");
    const skip = el => el.closest(".rain, .fx-ripple, .flash, .rev-burst, .jokers, .j-strip, .kt-bars, .sheet-veil:not(:last-child), [aria-hidden=true], .buzz-ring, .buzz-wrap, .tap-plus");
    for (const el of document.querySelectorAll("button, a, input, select, [role=switch], .p-opt, .vote-card, .ord-t, .p-question, .chip, h2, p")) {
      if (!vis(el) || skip(el)) continue;
      const b = el.getBoundingClientRect();
      if (b.right > W + 1 || b.left < -1) out.off.push(label(el) + ` [${Math.round(b.left)}…${Math.round(b.right)}]`);
      if (el.matches("button, a, input, select, [role=switch]") && !el.disabled && (b.width < 43.5 || b.height < 43.5) && !el.closest(".kt-bars"))
        out.small.push(label(el) + ` ${Math.round(b.width)}×${Math.round(b.height)}`);
    }
    // Tiny text: any visible element with its own text below 12 px; body copy below 15 px.
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const seen = new Set();
    while (walker.nextNode()) {
      const t = walker.currentNode; const el = t.parentElement;
      if (!el || seen.has(el) || !t.textContent.trim() || !vis(el) || skip(el)) continue;
      seen.add(el);
      const fs = parseFloat(getComputedStyle(el).fontSize);
      if (fs < 11.5) out.tiny.push(label(el) + ` ${fs}px`);
      else if (el.matches("p, li, .p-sub, .p-opt-text, .rev-detail, .u-erkl, .idle-sub, .ord-t") && fs < 14.5) out.tiny.push(label(el) + ` ${fs}px (body)`);
    }
    // Joker dock covering the last content line when scrolled to the bottom.
    const dock = document.querySelector(".jokers, .gm-dock");
    if (dock && vis(dock)) {
      se.scrollTop = se.scrollHeight;
      const d = dock.getBoundingClientRect();
      const main = document.querySelector(".g-main, .gm-main");
      if (main) for (const el of main.querySelectorAll("button, .p-locked-note, .rev-detail, .rev-grid, .ranking li:last-child, .gm-log li:last-child")) {
        if (!vis(el)) continue;
        const b = el.getBoundingClientRect();
        if (b.bottom > d.top + 2 && b.top < d.bottom) out.covered.push(label(el));
      }
      se.scrollTop = 0;
    }
    return out;
  });
  const bad = [];
  if (r.hOverflow) bad.push(`horizontal overflow ${r.hOverflow}px`);
  if (r.off.length) bad.push(`off-screen: ${r.off.slice(0, 4).join(", ")}`);
  if (r.small.length) bad.push(`small targets: ${r.small.slice(0, 5).join(", ")}${r.small.length > 5 ? ` (+${r.small.length - 5})` : ""}`);
  if (r.tiny.length) bad.push(`tiny text: ${r.tiny.slice(0, 5).join(", ")}${r.tiny.length > 5 ? ` (+${r.tiny.length - 5})` : ""}`);
  if (r.covered.length) bad.push(`covered by dock: ${r.covered.slice(0, 4).join(", ")}`);
  for (const b of bad) issues.push(`${name}: ${b}`);
  return bad;
}

async function snap(page, kase, w, h, { full = false } = {}) {
  const file = `${OUT}/${kase}-${w}.png`;
  await page.screenshot({ path: file, fullPage: full });
  const bad = await audit(page, `${kase}@${w}`);
  if (!sheets.has(kase)) sheets.set(kase, []);
  sheets.get(kase).push({ w, h, file, bad });
  return file;
}

async function writeSheets() {
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
  const { readFileSync } = await import("node:fs");
  for (const [kase, list] of sheets) {
    const imgs = list.map(x => `<figure><img src="data:image/png;base64,${readFileSync(x.file).toString("base64")}" /><figcaption>${x.w}${x.bad.length ? " ⚠ " + x.bad.length : ""}</figcaption></figure>`).join("");
    await page.setContent(`<html><body style="margin:0;background:#333;font:14px sans-serif;color:#fff"><h3 style="margin:6px 10px">${kase}</h3><div style="display:flex;gap:12px;align-items:flex-start;padding:0 10px 10px">${imgs}</div>
      <style>figure{margin:0}img{display:block;border:1px solid #000}figcaption{padding:2px 0}</style></body></html>`);
    await sleep(80);
    await page.screenshot({ path: `${OUT}/sheets/${kase}.png`, fullPage: true });
  }
  await page.close();
}

// ---------- mocked phone views ----------
const now = () => Date.now();
const av = (a, f) => `${a}.${f}`;
const P = (id, name, avatar, balance, platz, extra = {}) => ({ id, name, avatar, balance, connected: true, matsch: false, clown: false, streak: 0, platz, ...extra });
const ME = P("p1", "Tester", av("don-bananas", "blau"), 1250, 2, { streak: 3 });
const PLAYERS = [P("p2", "Kokos 🤖", av("gitti-giro", "gruen"), 1840, 1), ME, P("p3", "Banana Joe 🤖", av("schnarch-schorsch", "gelb"), 900, 3), P("p4", "Prof. Pavian mit sehr langem Namen", av("baron-von-bananenstein", "lila"), 420, 4),
  P("p5", "Splitter", av("kiki-krawall", "rot"), 380, 5), P("p6", "Glitzer-Gabi", av("glitzer-gina", "pink"), 300, 6), P("p7", "Astro-Anton", av("astro-astrid", "tuerkis"), 150, 7), P("p8", "DJ Dosenbier", av("dj-trommelfell", "orange"), 90, 8)];
const J = (id, name, emoji, ladungen, preis, kaufbar, nutzbar) => ({ id, name, emoji, ladungen, preis, kaufbar, nutzbar, beschreibung: "Streicht die Hälfte der falschen Antworten. Einmal pro Runde." });
const JOKERS = [J("bananen-split", "Bananen-Split", "🍌", 1, 0, false, true), J("ueberziehungskredit", "Überziehungskredit", "⏳", 0, 150, true, true), J("goldene-banane", "Goldene Banane", "✨", 1, 0, false, false),
  J("schmiergeld", "Schmiergeld", "🤫", 0, 30, true, true), J("rueckgaberecht", "Rückgaberecht", "↩️", 0, 40, true, false), J("bananentresor", "Bananentresor", "🛡️", 0, 100, false, false), J("portfolio-umschichtung", "Portfolio-Umschichtung", "🔄", 0, 60, true, false)];
function view(prompt, over = {}) {
  return { roomCode: "TEST", phase: "frage", me: ME, prompt, jokers: JOKERS, statusText: "", paused: false, serverTime: now(), rueckenwind: 1, moments: [], ranking: PLAYERS.slice(0, 5),
    sectionLabel: "Runde 2/7 · Bananen-Basics", ohneScreen: false, jackpotGlas: 750, jackpotAktiv: true, jackpotHinweis: "Strafen landen im Glas — die Jackpot-Frage räumt es ab.", progress: 0.34,
    stats: { richtig: 4, falsch: 2, laengsteSerie: 3 }, ...over };
}
const opt = (id, text, x = {}) => ({ id, text, removed: false, ...x });
const LONGQ = "Welcher deutsche Fußballverein gewann in der Saison 1977/78 als Aufsteiger direkt die Meisterschaft der Bundesliga und schrieb damit Geschichte, die bis heute unerreicht geblieben ist?";
const dl = s => now() + s * 1000;
const CASES = [
  { id: "idle-lobby", v: () => view({ idle: { title: "Du bist drin! 🎉", subtitle: "Warte, bis der Show-Master startet" } }, { phase: "lobby", jokers: [] }) },
  { id: "idle-frage", v: () => view({ idle: { title: "Schau auf die Bühne …", subtitle: "Gleich kommt deine Frage" } }) },
  { id: "idle-standings", v: () => view({ idle: { title: "Zwischenstand", subtitle: "Diese Runde: +350 MM" } }, { phase: "zwischenstand", ranking: PLAYERS }) },
  { id: "choice-4", v: () => view({ choice: { question: "Zu welchem Online-Modehändler gehört der Slogan ‚Schrei vor Glück'?", options: ["Amazon", "About You", "bonprix", "Zalando"].map((t, i) => opt(i, t)), deadline: dl(20), secondTry: false } }), tap: ".p-opt >> nth=3" },
  { id: "choice-long", v: () => view({ choice: { question: LONGQ, options: ["1. FC Kaiserslautern (Pfalz)", "1. FC Köln — der Effzeh vom Geißbockheim", "Borussia Mönchengladbach", "Hamburger Sportverein von 1887 e. V."].map((t, i) => opt(i, t)), deadline: dl(20), secondTry: false, hint: "Die Stadt liegt am Rhein." } }), tap: ".p-opt >> nth=1" },
  { id: "choice-2", v: () => view({ choice: { question: "Wahr oder falsch: Bananen sind botanisch gesehen Beeren.", options: [opt(0, "Wahr"), opt(1, "Falsch")], deadline: dl(15), secondTry: false } }), tap: ".p-opt >> nth=0" },
  { id: "choice-8", v: () => view({ choice: { question: "Welche Stadt ist die Hauptstadt von Australien?", options: ["Sydney", "Canberra", "Melbourne", "Perth", "Brisbane", "Adelaide", "Darwin", "Hobart"].map((t, i) => opt(i, t, i === 5 ? { removed: true } : {})), deadline: dl(25), secondTry: false } }), tap: ".p-opt >> nth=1" },
  { id: "multiChoice", v: () => view({ multiChoice: { question: "Welche ZWEI dieser Tiere sind Säugetiere?", options: ["Delfin", "Hai", "Fledermaus", "Pinguin", "Krokodil", "Lachs"].map((t, i) => opt(i, t)), chosen: [], required: 2, locked: false, deadline: dl(25) } }), tap: [".p-opt >> nth=0", ".p-opt >> nth=2"] },
  { id: "buzzer", v: () => view({ buzzer: { question: "🎵 Welcher Song läuft gerade?", armed: true, pressed: false, hint: "80er-Jahre" } }) },
  { id: "number", v: () => view({ number: { question: "Wie hoch ist die Zugspitze (in Metern)?", min: 500, max: 5000, step: 1, log: false, unit: "m", locked: false, deadline: dl(30) } }) },
  { id: "order", v: () => view({ order: { question: "Sortiere nach Erscheinungsjahr — das älteste nach oben!", items: ["Der Herr der Ringe: Die Gefährten", "Titanic", "Jurassic Park", "Avatar – Aufbruch nach Pandora", "Der König der Löwen"].map((t, i) => ({ id: i, text: t })), order: [], locked: false, deadline: dl(40) } }) },
  { id: "wager", v: () => view({ wager: { title: "Wie viel setzt du?", subtitle: "Alles oder Banane — das Finale!", min: 0, max: 1250, step: 50, locked: false, deadline: dl(20) } }) },
  { id: "text", v: () => view({ text: { question: "Erfinde eine falsche Antwort: Was ist ein ‚Kladderadatsch'?", placeholder: "Deine Lüge …", maxLength: 40, deadline: dl(45) } }) },
  { id: "tapFrenzy", v: () => view({ tapFrenzy: { title: "🥥 Schüttel die Kokosnuss!", count: 37, deadline: dl(10), active: true } }) },
  { id: "chips", v: () => view({ chips: { question: "Welche Aktie steigt am stärksten? Verteile deine Chips!", options: ["Bananen AG", "Kokos Holding", "Lianen & Söhne Logistik GmbH", "Dschungel-Tech"].map((t, i) => opt(i, t)), total: 10, placed: [3, 0, 2, 0], locked: false, deadline: dl(30) } }) },
  { id: "pickPlayer", v: () => view({ pickPlayer: { title: "Bei wem klaust du?", subtitle: "250 MM (max. 25 % des Kontos)", candidates: PLAYERS.filter(p => p.id !== "p1").slice(0, 5), deadline: dl(15) } }), tap: ".pick-card >> nth=1" },
  { id: "pickPlayer-2", v: () => view({ pickPlayer: { title: "🔮 In wessen Seele blickst du?", subtitle: "Nacht 1: Kokos ist Dorfbewohner\nNacht 2: Splitter ist Werwolf", candidates: PLAYERS.filter(p => p.id !== "p1").slice(0, 2), deadline: dl(15) } }) },
  { id: "bank", v: () => view({ bank: { question: "Wie viele Beine hat eine Spinne?", options: ["6", "8", "10", "12"].map((t, i) => opt(i, t)), pot: 400, banked: 150, deadline: dl(15) } }) },
  { id: "cheer", v: () => view({ cheer: { title: "🥁 ANFEUERN!", subtitle: "Kokos hält die Stinkbanane — trommeln!", taps: 12 } }) },
  { id: "confirm", v: () => view({ confirm: { title: "🤗 Umarmungs-Bonus", subtitle: "Umarme deinen linken Nachbarn und tippe dann hier", button: "Umarmt!", done: false, deadline: dl(20) } }), tap: ".p-confirm .btn" },
  { id: "binary", v: () => view({ binary: { title: "📊 Börsen-Roulette", subtitle: "Long = mehr Gewinn, mehr Risiko", a: "long", b: "short", deadline: dl(15) } }), tap: ".bin-btn >> nth=0" },
  { id: "binary-arrows", v: () => view({ binary: { title: "Höher oder tiefer?", subtitle: "Aktuell: 1.250 m — die nächste Zahl ist …", a: "⬆️ Höher", b: "⬇️ Tiefer", deadline: dl(15) } }) },
  { id: "binary-risk", v: () => view({ binary: { title: "Turm 1 · Stufe 3/8 · Risiko 35 %", subtitle: "Weiter klettern oder abspringen?", a: "weiter", b: "runter", deadline: dl(12) } }) },
  { id: "vote-4", v: () => view({ vote: { title: "Welche Kategorie?", options: [["gaming", "Gaming", "🎮", 2], ["sport", "Sport", "⚽", 1], ["musik", "Musik", "🎵", 0], ["geschichte", "Geschichte", "🏛️", 3]].map(([id, label, emoji, count]) => ({ id, label, emoji, count })), deadline: dl(15) } }, { phase: "kategorie-wahl" }), tap: ".vote-card >> nth=1" },
  { id: "vote-3", v: () => view({ vote: { title: "Pause machen?", options: [["0", "Ja", null, 3], ["1", "Nein", null, 1], ["2", "Nur 5 Minuten, dann weiter", null, 0]].map(([id, label, emoji, count]) => ({ id, label, emoji, count })), chosen: "0", deadline: dl(20) } }) },
  { id: "reveal-ok", v: () => view({ reveal: { title: "Richtig!", correct: true, delta: 575, detail: "Du: Zalando · Richtig: Zalando · +75 Speed", streak: 4, speedBonus: 75 } }, { phase: "aufloesung", haptic: "success", flash: "gruen", ergebnis: { richtig: true, delta: 575, speedBonus: 75, platzVorher: 3, platzNachher: 2, balance: 1250, richtigText: "Zalando", antwortMs: 3400, streak: 4, streakFaktor: 1.5 } }) },
  { id: "reveal-nope", v: () => view({ reveal: { title: "Falsch", correct: false, delta: -200, detail: "Du: Amazon · Richtig: Zalando", streak: 0 } }, { phase: "aufloesung", haptic: "error", ergebnis: { richtig: false, delta: -200, platzVorher: 2, platzNachher: 3, balance: 1050, richtigText: "Hamburger Sportverein von 1887 e. V. (Rekordmeister der ersten Stunde)", antwortMs: 8100, streak: 0, streakFaktor: 1 } }) },
  { id: "reveal-meh", v: () => view({ reveal: { title: "Keine Wertung", delta: 0, detail: "Die Frage wurde annulliert", streak: 0 } }, { phase: "aufloesung" }) },
  { id: "explain", v: () => view({ explain: { title: "🏦 Affenbank", text: "Beantworte Fragen, der Pott wächst — aber nur gebankte Bananen zählen.", regeln: ["Jede richtige Antwort lässt den Pott wachsen", "BANK! sichert den Pott für dich", "Eine falsche Antwort — und der Pott verbrennt", "Nach drei Durchgängen ist Schluss"], gewinn: "Gebanktes Geld gehört dir", ready: false, streik: false, deadline: dl(25) } }, { phase: "erklaerkarte" }) },
  { id: "actions-mine", v: () => view({ actions: { title: "Du bist dran!", lines: ["🏠 Bananen-Allee · 2 Häuser", "💰 1.250 MM · 3 Straßen", "Letzter Wurf: 🎲 4 + 🎲 2"], buttons: [{ id: "wuerfeln", label: "🎲 Würfeln", style: "primary", enabled: true }, { id: "kaufen", label: "🏠 Kaufen (200)", style: "secondary", enabled: true }, { id: "aufgeben", label: "🏳️ Aufgeben", style: "danger", enabled: true }], deadline: dl(30) } }, { phase: "brettspiel", sectionLabel: "Bananopoly", jokers: [] }) },
  { id: "actions-wait", v: () => view({ actions: { title: "Kokos ist dran", lines: ["Kokos kauft die Lianen-Straße", "🧾 Du: 1.250 MM · 3 Straßen"], buttons: [] } }, { phase: "brettspiel", sectionLabel: "Bananopoly", jokers: [] }) },
  { id: "cards-mine", v: () => view({ cards: { title: "Du bist dran! Oben: 🔴 7 · Farbe rot", cards: ["🔴 3", "🔴 ⛔", "🟡 7", "🟢 2", "🔵 +2", "⚫ Wild", "⚫ Wild +4", "🟡 🔄", "🟢 9"].map((t, i) => opt(i, t, { removed: ![0, 1, 2, 5, 6].includes(i) })), buttons: [{ id: "ziehen", label: "Karte ziehen", style: "secondary", enabled: true }, { id: "banane", label: "🍌 BANANE!", style: "danger", enabled: true }], deadline: dl(30), hint: "9 Karten" } }, { phase: "brettspiel", sectionLabel: "Bananen-UNO", jokers: [] }) },
  { id: "cards-wait", v: () => view({ cards: { title: "Kokos ist dran · Oben: 🟢 ⛔", cards: ["🔴 3", "🟡 7", "🔵 +2", "⚫ Wild"].map((t, i) => opt(i, t, { removed: true })), buttons: [], hint: "4 Karten" } }, { phase: "brettspiel", sectionLabel: "Bananen-UNO", jokers: [] }) },
  { id: "cards-color", v: () => view({ actions: { title: "Welche Farbe?", lines: [], buttons: ["rot", "gelb", "gruen", "blau"].map(c => ({ id: c, label: { rot: "🔴", gelb: "🟡", gruen: "🟢", blau: "🔵" }[c] + " " + c[0].toUpperCase() + c.slice(1), style: "primary", enabled: true })), deadline: dl(15) } }, { phase: "brettspiel", sectionLabel: "Bananen-UNO", jokers: [] }) },
  { id: "feedback", v: () => view({ feedback: { questions: ["Wie hat dir die Show gefallen?", "Welches Minispiel war das beste?"], done: false } }, { phase: "ende", jokers: [] }) },
];

async function promptGallery() {
  const state = { ws: null, view: null, actions: [] };
  for (const [w, h] of SIZES) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    await ctx.addInitScript(() => { localStorage.setItem("mm:session", JSON.stringify({ code: "TEST", token: "tok" })); localStorage.setItem("mm:name", JSON.stringify("Tester")); });
    const page = await ctx.newPage();
    watchConsole(page, `phone${w}`, errors);
    await page.routeWebSocket(/\/ws$/, ws => {
      state.ws = ws;
      ws.onMessage(raw => {
        const m = JSON.parse(String(raw));
        if (m.t === "hello") { ws.send(JSON.stringify({ t: "welcome", sessionToken: "tok" })); if (state.view) ws.send(JSON.stringify({ t: "player", view: state.view })); }
        else if (m.t === "ping") ws.send(JSON.stringify({ t: "pong", t0: m.t0, serverTime: Date.now() }));
        else if (m.t === "action") state.actions.push(m.action);
      });
    });
    const push = v => { state.view = v; state.ws && state.ws.send(JSON.stringify({ t: "player", view: v })); };
    state.view = CASES[0].v();
    await page.goto(`${BASE}/j/TEST`);
    await sleep(1200);
    for (const c of CASES) {
      if (FILTER && !FILTER.test(c.id)) continue;
      push(c.v());
      await sleep(950);
      await snap(page, c.id, w, h);
      if (c.tap) {
        for (const t of [].concat(c.tap)) { await page.click(t).catch(e => issues.push(`${c.id}@${w}: tap ${t} failed ${e.message.split("\n")[0]}`)); await sleep(120); }
        if (c.id === "multiChoice") { await page.click(".p-choice .btn.green"); }
        await sleep(250);
        await snap(page, c.id + "-pending", w, h);
      }
    }
    // Interactions that need more than one tap.
    if (!FILTER || FILTER.test("order")) {
      push(CASES.find(c => c.id === "order").v());
      await sleep(900);
      // Drag the last item to the top with touch-like pointer events.
      const items = await page.$$(".order-list li");
      if (items.length) {
        const handle = await items[items.length - 1].$(".ord-grip") || items[items.length - 1];
        const a = await handle.boundingBox(), b = await items[0].boundingBox();
        await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
        await page.mouse.down();
        for (let k = 1; k <= 12; k++) { await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2 - ((a.y - b.y + 10) * k) / 12); await sleep(30); }
        await snap(page, "order-dragging", w, h);
        await page.mouse.up();
        await sleep(400);
        const txt = await page.$$eval(".order-list .ord-t", els => els.map(e => e.textContent));
        if (!/König der Löwen/.test(txt[0] || "")) issues.push(`order-drag@${w}: drag did not reorder (${txt[0]})`);
        await snap(page, "order-dragged", w, h);
        const sentOrder = state.actions.filter(a => a.type === "order").pop();
        if (!sentOrder) issues.push(`order-drag@${w}: no order action sent`);
      }
    }
    if (!FILTER || FILTER.test("text")) {
      // Keyboard: shrink the viewport like iOS does and focus the input — it must stay visible.
      push(CASES.find(c => c.id === "text").v());
      await sleep(900);
      await page.setViewportSize({ width: w, height: Math.round(h * 0.56) });
      await page.focus(".text-in");
      await page.keyboard.type("Ein Schuhputz-Roboter");
      await sleep(700);
      const vis = await page.evaluate(() => { const r = document.querySelector(".text-in").getBoundingClientRect(); const vv = window.visualViewport; const H = vv ? vv.height : innerHeight; return r.top >= 0 && r.bottom <= H; });
      if (!vis) issues.push(`text-keyboard@${w}: input not visible with keyboard open`);
      await snap(page, "text-keyboard", w, h);
      await page.setViewportSize({ width: w, height: h });
      await sleep(300);
    }
    if (!FILTER || FILTER.test("joker")) {
      push(CASES.find(c => c.id === "reveal-ok").v());
      await sleep(2600);
      await snap(page, "reveal-ok-settled", w, h);
      push(CASES.find(c => c.id === "choice-4").v());
      await sleep(800);
      await page.click(".joker >> nth=0");
      await sleep(600);
      await snap(page, "joker-sheet", w, h);
      await page.click(".p-sheet .btn.ghost");
      await sleep(300);
      await page.click(".g-me");
      await sleep(600);
      await snap(page, "menu", w, h);
      await page.click(".p-sheet .btn:not(.ghost)");
      await sleep(300);
    }
    if (w === 390 && (!FILTER || FILTER.test("landscape"))) {
      await page.setViewportSize({ width: 844, height: 390 });
      for (const id of ["choice-4", "order", "binary-arrows", "reveal-ok", "cards-mine"]) {
        push(CASES.find(c => c.id === id).v());
        await sleep(900);
        await snap(page, "landscape-" + id, 844, 390);
      }
      await page.setViewportSize({ width: w, height: h });
    }
    await ctx.close();
    log("prompts done", w);
  }
}

// ---------- Übungsmodus ----------
async function uebungGallery() {
  for (const [w, h] of SIZES) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    const page = await ctx.newPage();
    watchConsole(page, `uebung${w}`, errors);
    await page.goto(`${BASE}/uebung`);
    await sleep(1400);
    await snap(page, "u1-start", w, h);
    await page.click(".u-kat[data-id=sport]").catch(e => issues.push(`uebung@${w}: no category card (${e.message.split("\n")[0]})`));
    await page.click(".u-tier[data-id=medium]").catch(() => issues.push(`uebung@${w}: no tier chip`));
    await sleep(300);
    await snap(page, "u2-start-picked", w, h);
    await page.click(".u-go");
    await sleep(1300);
    await snap(page, "u3-question", w, h);
    // Answer a few questions: first one right (from the result), rest random.
    for (let i = 0; i < 5; i++) {
      await page.waitForSelector(".u-q .p-opt:not([disabled])", { timeout: 5000 }).catch(() => {});
      await page.click(`.u-q .p-opt >> nth=${i % 2}`).catch(() => {});
      await sleep(900);
      if (i === 0) await snap(page, "u4-feedback", w, h);
      const wrong = await page.$(".u-fb.nope");
      if (wrong && !(await page.$(".u-shot-wrong"))) { await page.evaluate(() => document.body.classList.add("u-shot-wrong")); await snap(page, "u5-feedback-wrong", w, h); }
      await page.click(".u-next").catch(() => {});
      await sleep(700);
    }
    await page.click(".u-end").catch(() => issues.push(`uebung@${w}: no end button`));
    await sleep(1200);
    await snap(page, "u6-summary", w, h);
    const review = await page.$(".u-review-go:not([disabled])");
    if (review) {
      await review.click();
      await sleep(1000);
      await snap(page, "u7-review", w, h);
      await page.click(".u-q .p-opt >> nth=0").catch(() => {});
      await sleep(900);
      await snap(page, "u8-review-feedback", w, h);
    } else issues.push(`uebung@${w}: no review button`);
    await page.goto(`${BASE}/uebung`);
    await sleep(1200);
    await snap(page, "u9-start-history", w, h);
    await ctx.close();
    log("uebung done", w);
  }
}

// ---------- GM cockpit ----------
async function gmGallery() {
  await api(PORT, "/api/host/start", { modus: "klassik", patch: { tempo: "zackig" } });
  const stage = await browser.newPage({ viewport: { width: 1194, height: 834 } });
  watchConsole(stage, "stage", errors);
  await stage.goto(`${BASE}/stage`);
  await sleep(1500);
  await api(PORT, "/api/host/bots", { add: 5 });
  await sleep(800);
  const code = await api(PORT, "/api/dev/code");
  const pin = await api(PORT, "/api/dev/pin");
  const pages = [];
  for (const [w, h] of SIZES) {
    const gm = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    watchConsole(gm, `gm${w}`, errors);
    await gm.goto(`${BASE}/gm?code=${code}`);
    await sleep(600);
    await snap(gm, "g0-login", w, h);
    await gm.fill('input[placeholder="PIN"]', String(pin));
    await gm.click("text=Regie übernehmen");
    await sleep(1000);
    pages.push([gm, w, h]);
  }
  const each = async fn => { for (const [p, w, h] of pages) await fn(p, w, h); };
  await each((p, w, h) => snap(p, "g1-regie-lobby", w, h));
  for (const [t, n] of [["Spieler", "g2-spieler"], ["Werkzeuge", "g3-tools"], ["Fragen", "g4-fragen"], ["Setup", "g5-setup"]]) {
    await each(async (p, w, h) => { await p.click(`.gm-tabs >> text=${t}`); await sleep(400); await snap(p, n, w, h); });
  }
  await each(async (p, w, h) => {
    await p.click(".gm-tabs >> text=Fragen"); await sleep(300);
    await p.evaluate(() => { const el = document.querySelector(".kt-tree"); if (el) window.scrollTo(0, el.getBoundingClientRect().top + scrollY - 80); });
    await sleep(300); await snap(p, "g4b-fragen-tree", w, h);
    await p.click(".kt-tabs >> text=Fragen durchsuchen"); await sleep(900);
    await p.click(".kt-browser .kt-q-head >> nth=0"); await sleep(300);
    await snap(p, "g4c-fragen-browser", w, h);
  });
  await each(async (p, w, h) => { await p.click(".gm-tabs >> text=Werkzeuge"); await p.click(".tool:has-text('Punkte')"); await sleep(400); await snap(p, "g6-sheet-punkte", w, h); await p.click(".gm-sheet-x"); await sleep(200); });
  await each(async (p, w, h) => { await p.click(".gm-dock-pause"); await sleep(400); await snap(p, "g7-sheet-pause", w, h); await p.click(".gm-sheet-x"); await sleep(200); });
  await each(async (p, w, h) => { await p.click(".gm-tabs >> text=Spieler"); await p.click(".gm-add"); await sleep(400); await snap(p, "g8-sheet-bots", w, h); await p.click(".gm-sheet-x"); await sleep(200); await p.click(".gm-tabs >> text=Regie"); });
  await stage.click(".start-btn").catch(() => {});
  for (let i = 0; i < 14 && (await api(PORT, "/api/dev/stage")).phase !== "frage"; i++) { await api(PORT, "/api/dev/next"); await sleep(400); }
  await sleep(600);
  await each((p, w, h) => snap(p, "g9-regie-frage", w, h));
  await each(async (p, w, h) => { await p.evaluate(() => { const el = document.querySelector(".gm-ablauf"); if (el) window.scrollTo(0, el.getBoundingClientRect().top + scrollY - 70); }); await sleep(250); await snap(p, "g9b-regie-ablauf", w, h); await p.evaluate(() => window.scrollTo(0, 0)); });
  await each(async (p, w, h) => { await p.click('.gm-act:has-text("Aus Katalog")').catch(() => {}); await sleep(900); await snap(p, "g10-pick-sheet", w, h); await p.click(".gm-sheet-x").catch(() => {}); await sleep(200); });
  for (let i = 0; i < 20 && (await api(PORT, "/api/dev/stage")).phase !== "aufloesung"; i++) await sleep(1000);
  await sleep(1200);
  await each((p, w, h) => snap(p, "g11-regie-aufloesung", w, h));
  for (let i = 0; i < 20 && (await api(PORT, "/api/dev/stage")).phase !== "zwischenstand"; i++) { await api(PORT, "/api/dev/next"); await sleep(600); }
  await sleep(600);
  await each((p, w, h) => snap(p, "g12-regie-zwischenstand", w, h));
}

try {
  if (SECTIONS.includes("prompts")) await promptGallery();
  if (SECTIONS.includes("uebung")) await uebungGallery();
  if (SECTIONS.includes("gm")) await gmGallery();
  await writeSheets();
} finally {
  await browser.close();
  srv.stop();
}
const errs = [...new Set(errors)].filter(e => !/WebSocket|ERR_CONNECTION_REFUSED|Failed to load resource/.test(e));
writeFileSync(`${OUT}/issues.txt`, issues.join("\n") + "\n");
console.log(issues.length ? `LAYOUT ISSUES (${issues.length}):\n` + issues.join("\n") : "no layout issues");
console.log(errs.length ? "CONSOLE ERRORS:\n" + errs.join("\n") : "no console errors");
console.log(sheets.size, "cases, sheets in", `${OUT}/sheets`);
