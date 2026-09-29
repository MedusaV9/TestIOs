// Monkey Money — Show-Master cockpit (phone/tablet). Regie, players, tools,
// question catalogue and settings — every tool is a bottom sheet.
import { html, render, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { connect, decode, cx, fmtNum, fmtDelta, haptic, useNow, serverNow, MONKEYS, COLORS, colorHex, avatarParts } from "../lib/core.js";
import { Monkey, Money, TimerBar } from "../lib/ui.js";
import { Katalog, Answers, TIER_META, TYPE_META, katalogSummary } from "../lib/katalog.js";

const params = new URLSearchParams(location.search);
const SOUNDS = [["applaus_gross", "👏 Applaus"], ["trommelwirbel", "🥁 Trommelwirbel"], ["falsch", "❌ Fail"], ["dreiklang_tief", "😮 Ohhh!"], ["kaching", "💰 Kassen-Kling"], ["slime", "🦗 Grillen"], ["muenzregen", "🎊 Münzregen"], ["jingle_sax", "🎷 Sax"], ["buzzer_airhorn", "📯 Airhorn"]];
const JOKERS = [["bananen-split", "🍌 Bananen-Split"], ["ueberziehungskredit", "⏳ Überziehungskredit"], ["goldene-banane", "✨ Goldene Banane"], ["schmiergeld", "🤫 Schmiergeld"], ["rueckgaberecht", "↩️ Rückgaberecht"], ["bananentresor", "🛡️ Bananentresor"], ["portfolio-umschichtung", "🔄 Portfolio-Umschichtung"]];
const SEGMENTS = [["doppelter-zaster", "💰 Doppelter Zaster"], ["halbe-miete", "⏱️ Halbe Miete"], ["banana-bailout", "🪂 Banana Bailout"], ["dividende", "📈 Dividende"], ["insider-tipp", "🕵️ Insider-Tipp"], ["inflation", "🎈 Inflation"], ["affentheater", "🎭 Affentheater"], ["boersen-roulette", "📊 Börsen-Roulette"], ["umarmungs-bonus", "🤗 Umarmungs-Bonus"], ["steuerpruefung", "🧾 Steuerprüfung"], ["blackout", "🌑 Blackout"], ["tausch-boerse", "🔁 Tausch-Börse"], ["affe-wuerfelt", "🎲 Der Affe würfelt"], ["kompliment-konto", "💬 Kompliment-Konto"]];
const RULES = [["sr1", "🎰 Vabanque-Finale"], ["sr2", "🦅 Pleitegeier"], ["sr3", "🤫 Notariats-Runde"], ["sr4", "📦 Affensteuer"], ["sr5", "🤠 Kopfgeld"], ["sr6", "🔔 Kapitalismus-Gong"], ["sr7", "🍌 Bananenschale"]];
const MIXES = [["locker", "🍌 Locker"], ["ausgewogen", "⚖️ Ausgewogen"], ["knifflig", "🧠 Knifflig"]];
// Bot personas (mirrors ShowHost.personas).
const PERSONAS = [["Kokos", "gitti-giro", "gruen", "Streberin · 85 %"], ["Splitter", "kiki-krawall", "rot", "Chaotin · 60 %"], ["Banana Joe", "schnarch-schorsch", "gelb", "Gemütlich · 55 %"], ["Prof. Pavian", "baron-von-bananenstein", "lila", "Besserwisser · 75 %"], ["Chaos-Kalle", "kahuna-kalle", "tuerkis", "Zocker · 50 %"], ["Glitzer-Gabi", "glitzer-gina", "pink", "Diva · 65 %"], ["Astro-Anton", "astro-astrid", "blau", "Nerd · 70 %"], ["DJ Dosenbier", "dj-trommelfell", "orange", "Party · 45 %"]];
const QUESTION_PHASES = ["erklaerkarte", "frage"];

function App() {
  const saved = (() => { try { return JSON.parse(localStorage.getItem("mm:gm")); } catch (_) { return null; } })();
  const code0 = (params.get("code") || "").toUpperCase();
  const [view, setView] = useState(null);
  const [err, setErr] = useState(null);
  const [online, setOnline] = useState(true);
  const [toast, setToast] = useState(null);
  const conn = useRef(null);
  const hello = useRef(null);
  const tt = useRef();
  const say = t => { setToast(t); clearTimeout(tt.current); tt.current = setTimeout(() => setToast(null), 2400); };
  const start = h => {
    hello.current = h; setErr(null);
    if (conn.current) { conn.current.reconnect(); return; }
    conn.current = connect({
      hello: () => hello.current, onStatus: setOnline,
      onMessage: m => {
        if (m.t === "welcome") { localStorage.setItem("mm:gm", JSON.stringify({ code: hello.current.roomCode, token: m.sessionToken })); hello.current = { ...hello.current, sessionToken: m.sessionToken }; }
        else if (m.t === "gm") setView(m.view);
        else if (m.t === "error") { setErr(m.message); if (m.code === "pin" || m.code === "room") { localStorage.removeItem("mm:gm"); setView(null); conn.current.close(); conn.current = null; } }
      },
    });
  };
  useEffect(() => { if (saved && saved.code === code0) start({ t: "hello", roomCode: code0, role: "gm", sessionToken: saved.token }); }, []);
  const cmd = c => { const ok = conn.current && conn.current.send({ t: "gm", cmd: c }); haptic(); if (!ok) say("⚠️ Keine Verbindung"); return ok; };
  return html`<div class="gm">
    ${view ? html`<${Cockpit} view=${view} cmd=${cmd} say=${say} online=${online} />` : html`<${Login} code0=${code0} err=${err} onGo=${(code, pin) => start({ t: "hello", roomCode: code, role: "gm", gmPin: pin })} />`}
    ${!online && view && html`<div class="p-offline">Verbindung weg …</div>`}
    ${toast && html`<div class="p-toast pop-in">${toast}</div>`}
  </div>`;
}

function Login({ code0, err, onGo }) {
  const [code, setCode] = useState(code0);
  const [pin, setPin] = useState("");
  return html`<div class="gm-login">
    <div class="j-logo">🎬 <span>SHOW</span><b>MASTER</b></div>
    <p class="muted">Die PIN steht in der Lobby auf dem iPad („Show-Master · Code zeigen“).</p>
    <input class="code-in" maxlength="4" placeholder="RAUM" value=${code} onInput=${e => setCode(e.target.value.toUpperCase().replace(/[^A-Z]/g, ""))} />
    <input class="code-in" inputmode="numeric" maxlength="4" placeholder="PIN" value=${pin} onInput=${e => setPin(e.target.value.replace(/\D/g, ""))} onKeyDown=${e => e.key === "Enter" && onGo(code, pin)} />
    ${err && html`<p class="j-err">${err}</p>`}
    <button class="btn big block" disabled=${code.length !== 4 || pin.length !== 4} onClick=${() => onGo(code, pin)}>🎬 Regie übernehmen</button>
  </div>`;
}

const TABS = [["regie", "🎬", "Regie"], ["spieler", "🐒", "Spieler"], ["tools", "🧰", "Werkzeuge"], ["fragen", "📚", "Fragen"], ["settings", "⚙️", "Setup"]];
const PHASE = {
  lobby: ["Lobby", "#9b6bff"], intro: ["Opening", "#9b6bff"], "kategorie-wahl": ["Kategorie-Wahl", "#2ed3c6"], erklaerkarte: ["Erklärkarte", "#4d8bff"], frage: ["Frage läuft", "#2bd98a"],
  aufloesung: ["Auflösung", "#ffc93c"], zwischenstand: ["Zwischenstand", "#ff8a3d"], rad: ["Glücksrad", "#ff6bd6"], halbzeit: ["Halbzeit", "#ff8a3d"], pause: ["Pause", "#ff4d6d"],
  highlights: ["Highlights", "#ffc93c"], siegerehrung: ["Siegerehrung", "#ffc93c"], ende: ["Abspann", "#9b6bff"], brettspiel: ["Brettspiel", "#2ed3c6"],
};
const phaseName = p => (PHASE[p] || [p])[0];

function Cockpit({ view, cmd, say, online }) {
  const [tab, setTab] = useState("regie");
  const [sheet, setSheet] = useState(null);
  const viewRef = useRef(view);
  viewRef.current = view;
  const ctx = { view, viewRef, cmd, say, open: (el, tall) => setSheet({ el, tall }), close: () => setSheet(null) };
  const st = view.stage;
  const scene = decode(st.scene);
  const wall = scene.wall;
  const next = () => cmd(st.paused ? { resume: {} } : { flowNext: {} });
  const wv = !st.paused && WAIT_PHASES.includes(st.phase) ? st.weiter : null;
  useEffect(() => { document.body.classList.toggle("gm-noscroll", !!sheet); }, [sheet]);
  return html`<div class="cockpit">
    <header class="gm-top">
      <div class="gm-top-l">
        <b>🎬 ${view.roomCode}</b>
        <small>${st.sectionLabel || "—"}</small>
      </div>
      <div class="gm-top-r">
        <span class="gm-phase" style=${`--c:${(PHASE[st.phase] || [0, "#9b6bff"])[1]}`}>${st.paused ? "⏸ Pausiert" : phaseName(st.phase)}</span>
        ${wall && wall.deadline && !wall.revealed && html`<${Clock} deadline=${wall.deadline} paused=${st.paused} />`}
        <span class=${cx("gm-dot", online ? "on" : "off")} title=${online ? "verbunden" : "offline"}></span>
      </div>
    </header>
    <main class="gm-main">
      ${tab === "regie" && html`<${Regie} ...${ctx} />`}
      ${tab === "spieler" && html`<${Spieler} ...${ctx} />`}
      ${tab === "tools" && html`<${Tools} ...${ctx} />`}
      ${tab === "fragen" && html`<${Fragen} ...${ctx} />`}
      ${tab === "settings" && html`<${Settings} ...${ctx} />`}
    </main>
    <div class="gm-dock">
      <div class="gm-dock-row">
        <button class=${cx("gm-dock-pause", st.paused && "on")} aria-label=${st.paused ? "Fortsetzen" : "Pause"} onClick=${() => st.paused ? cmd({ resume: {} }) : ctx.open(html`<${PauseSheet} cmd=${cmd} close=${ctx.close} />`)}>${st.paused ? "▶" : "⏸"}</button>
        <button class=${cx("btn big gm-next", st.paused && "green")} disabled=${!st.canAdvance && !st.paused} onClick=${next}>${st.paused ? "▶ Fortsetzen" : (st.advanceLabel || "Weiter") + " ▶"}${wv && html`<span class=${cx("gm-next-vote", wv.anzahl >= wv.noetig && "all")} aria-label=${`${wv.anzahl} von ${wv.noetig} Spielern wollen weiter`}>👍 ${wv.anzahl}/${wv.noetig}</span>`}</button>
      </div>
      <nav class="gm-tabs">${TABS.map(([id, e, l]) => html`<button class=${cx(tab === id && "on")} onClick=${() => { setTab(id); window.scrollTo(0, 0); }}><span>${e}</span><small>${l}</small></button>`)}</nav>
    </div>
    ${sheet && html`<div class="sheet-veil gm-veil" onClick=${e => e.target === e.currentTarget && setSheet(null)}>
      <div class=${cx("p-sheet gm-sheet", sheet.tall && "tall")}>
        <div class="gm-sheet-bar"><i></i><button class="gm-sheet-x" aria-label="Schließen" onClick=${() => setSheet(null)}>×</button></div>
        <div class="gm-sheet-body">${sheet.el}</div>
      </div></div>`}
  </div>`;
}

function Clock({ deadline, paused }) {
  const now = useNow(250, !paused);
  const s = Math.max(0, Math.ceil((deadline - now) / 1000));
  return html`<span class=${cx("gm-clock", s <= 5 && "hot")}>⏱ ${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}</span>`;
}

// ---------- Regie ----------
// All show modes (mirrors Core/Rules/Settings.swift `Modus`): id → [emoji, label, one-liner].
const MODES = [
  ["quick", "⚡", "Quick", "4 Runden · ~15–20 min · Ein-Tap-Start"],
  ["klassik", "🎩", "Klassik", "6 Runden + Jackpot + Finale · ~40 min"],
  ["marathon", "🏃", "Marathon", "9+ Runden · Halbzeit · alle Formate · ~70 min"],
  ["blitz", "🌩️", "Blitz", "3 Blitzrunden + Mini-Finale · ~10 min"],
  ["party", "🎉", "Party", "6 Party-Runden · wenig Wissen, viel Chaos · ~30 min"],
  ["profi", "🎓", "Profi", "6 Wissensrunden + Jackpot · knifflig, ohne Glücksrad"],
  ["eigen", "🛠️", "Eigene Show", "Du baust die Playlist: Formate, Reihenfolge, Fragenzahl"],
];
const MODUS = Object.fromEntries(MODES.map(([id, e, l]) => [id, `${e} ${l}`]));
const WAIT_PHASES = ["zwischenstand", "halbzeit", "highlights"];
let lastRounds = 0; // remembered across tab switches (jackpot/finale labels carry no round count)
/** Compact run-of-show: round dots from "Runde n/m · Format", section + question numbers, overall progress. */
function Ablauf({ st, scene }) {
  const label = st.sectionLabel || "";
  const m = /^Runde\s+(\d+)\s*\/\s*(\d+)\s*(?:·\s*(.+))?$/.exec(label);
  const cardN = scene.kind === "erklaerkarte" || scene.kind === "zwischenstand" ? scene.rundenNummer || (scene._0 && scene._0.rundenNummer) : null;
  const cardT = scene.kind === "erklaerkarte" || scene.kind === "zwischenstand" ? scene.rundenGesamt || (scene._0 && scene._0.rundenGesamt) : null;
  const round = m ? Number(m[1]) : cardN || 0;
  const rounds = m ? Number(m[2]) : cardT || lastRounds;
  if (rounds) lastRounds = rounds;
  const special = !m && /Jackpot|Finale/i.test(label);
  const format = m ? m[3] : special ? label : null;
  const wall = scene.wall;
  const pct = Math.round((st.progress || 0) * 100);
  const lobby = st.phase === "lobby";
  const ex = scene.kind === "erklaerkarte" ? scene._0 || scene : null;
  const done = special ? rounds : Math.max(0, round - 1);
  return html`<div class="card gm-block gm-ablauf">
    <div class="gm-block-head"><h3>🧭 Ablauf</h3><span class="chip">${MODUS[st.modus] || st.modus}</span></div>
    ${lobby ? html`<p class="gm-ab-now"><b>Show startet gleich</b><small>Die Runden werden beim Start aus den Einstellungen geplant.</small></p>` : html`
      ${rounds > 0 && html`<div class="gm-ab-dots" role="img" aria-label=${special ? `Alle ${rounds} Runden gespielt` : `Runde ${round} von ${rounds}`}>
        ${Array.from({ length: Math.min(rounds, 16) }, (_, i) => html`<i class=${cx(i < done && "done", !special && i === round - 1 && "now")}>${i + 1}</i>`)}
        ${special && html`<i class="now special">${/Jackpot/i.test(label) ? "💰" : "🐊"}</i>`}
      </div>`}
      <p class="gm-ab-now">
        <b>${special ? format : rounds ? `Runde ${round || "–"} von ${rounds}` : label || "Show"}</b>
        <small>${[!special && format, wall && wall.gesamt ? `Frage ${wall.nummer}/${wall.gesamt}` : null, ex && ex.name ? `gleich: ${ex.emoji || ""} ${ex.name}` : null, phaseName(st.phase)].filter(Boolean).join(" · ")}</small>
      </p>
      <div class="gm-ab-bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow=${pct} aria-label="Fortschritt der Show"><i style=${`width:${pct}%`}></i><span>${pct} %</span></div>`}
  </div>`;
}

function Regie(ctx) {
  const { view, cmd, open, close } = ctx;
  const st = view.stage;
  const scene = decode(st.scene);
  // While a question runs the live cards come first; the run-of-show card follows them.
  const live = !!view.spickzettel && ["erklaerkarte", "frage", "aufloesung"].includes(st.phase);
  const wv = !st.paused && WAIT_PHASES.includes(st.phase) ? st.weiter : null;
  return html`<div class="gm-stack">
    ${view.empfehlung && html`<p class="gm-tip">🧠 ${view.empfehlung}</p>`}
    ${wv && html`<${WeiterCard} view=${view} w=${wv} cmd=${cmd} />`}
    ${!live && html`<${Ablauf} st=${st} scene=${scene} />`}
    ${scene.kind === "kategorieWahl" && html`<div class="card gm-block"><h3>🗂️ Kategorie festlegen</h3><div class="gm-grid">${scene.optionen.map(o => html`<button class="pick" onClick=${() => cmd({ kategoriePick: { _0: o.id } })}>${o.emoji} ${o.label} <small>${o.count}</small></button>`)}</div></div>`}
    ${view.spickzettel && html`<${LiveQuestion} ...${ctx} scene=${scene} />`}
    ${scene.kind === "aufloesung" && scene.reveal && html`<${RevealCard} view=${view} r=${scene.reveal} deltas=${scene.deltas} />`}
    ${live && html`<${Ablauf} st=${st} scene=${scene} />`}
    <${AnswersCard} ...${ctx} scene=${scene} />
    ${view.vote && html`<div class="card gm-block"><h3>🗳️ ${view.vote.frage}</h3>${view.vote.optionen.map((o, i) => { const n = Object.values(view.vote.stimmen).filter(v => v === i).length; const all = Object.keys(view.vote.stimmen).length || 1;
      return html`<div class="gm-dist"><span>${o}</span><i style=${`width:${(n / all) * 100}%`}></i><b>${n}</b></div>`; })}</div>`}
    <div class="card gm-block">
      <div class="gm-block-head"><h3>🎛️ Regie</h3><div class="drama" title="Drama-Score"><small>Drama</small><div class="drama-bar"><i style=${`width:${Math.min(100, view.dramaScore)}%`}></i></div></div></div>
      <div class="gm-btn-grid">
        <button class="gm-act" onClick=${() => open(html`<${PauseSheet} cmd=${cmd} close=${close} />`)}><span>⏸</span>Pause mit Text</button>
        <button class="gm-act" onClick=${() => { cmd({ hintGlobal: {} }); ctx.say("💡 Tipp für alle"); }}><span>💡</span>Tipp für alle</button>
        <button class="gm-act" onClick=${() => open(html`<${Whisper} view=${view} cmd=${cmd} close=${close} />`)}><span>🤫</span>Flüstern</button>
        ${st.phase === "intro" ? html`<button class="gm-act" onClick=${() => cmd({ flowSkipOpening: {} })}><span>⏭</span>Opening überspringen</button>`
          : html`<button class="gm-act" onClick=${() => open(html`<${Broken} cmd=${cmd} close=${close} />`)}><span>🔴</span>Frage kaputt</button>`}
      </div>
    </div>
    ${view.regal.length > 0 && html`<${RegalCard} ...${ctx} />`}
    <div class="card gm-block"><h3>📜 Logbuch</h3><ul class="gm-log">${view.log.slice(-12).reverse().map(l => html`<li><small>${new Date(l.at).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })}</small> ${l.text}</li>`)}</ul></div>
  </div>`;
}

/** "👍 Weiter" skip vote of the phones: who is ready (n/m) + the manual next right beside it. */
function WeiterCard({ view, w, cmd }) {
  const st = view.stage;
  const full = Object.fromEntries(view.players.map(p => [p.id, p]));
  const ready = new Set(w.spieler || []);
  const humans = st.players.filter(p => p.connected !== false && !(full[p.id] || {}).isBot);
  humans.sort((a, b) => (ready.has(b.id) - ready.has(a.id)) || a.platz - b.platz);
  const all = w.anzahl >= w.noetig;
  const pct = w.noetig ? Math.round((w.anzahl / w.noetig) * 100) : 0;
  return html`<div class=${cx("card gm-block gm-weiter", all && "all")}>
    <div class="gm-block-head"><h3>👍 Weiter-Abstimmung</h3><span class="gm-wv-count" key=${w.anzahl}><b>${w.anzahl}</b>/${w.noetig}</span></div>
    <div class="gm-wv-bar" role="progressbar" aria-valuemin="0" aria-valuemax=${w.noetig} aria-valuenow=${w.anzahl} aria-label="Spieler, die weiter wollen"><i style=${`width:${pct}%`}></i></div>
    <ul class="gm-wv-list">${humans.map(p => { const on = ready.has(p.id);
      return html`<li class=${cx(on && "on")} key=${p.id}><${Monkey} wire=${p.avatar} anim="none" size=${28} /><span>${p.name}</span><i class="gm-wv-st" aria-label=${on ? "bereit" : "wartet"}>${on ? html`<i class="ck"></i>` : "…"}</i></li>`; })}</ul>
    <div class="gm-wv-foot">
      <small class="muted">${all ? "Alle bereit — die Bühne geht gleich von selbst weiter." : "Tippen alle auf „Weiter“, geht's automatisch weiter."}</small>
      <button class="gm-act gm-wv-next" disabled=${!st.canAdvance} onClick=${() => cmd({ flowNext: {} })}><span>⏭</span>${all ? "Sofort" : "Nicht warten"}</button>
    </div>
  </div>`;
}

function QMeta({ q }) {
  const tm = TIER_META[q.schwierigkeit] || { emoji: "", name: q.schwierigkeit, c: "#fff" };
  const ty = TYPE_META[q.typ] || { emoji: "❔", name: q.typ };
  return html`<div class="spick-head"><span class="chip tier" style=${`--c:${tm.c}`}>${tm.emoji} ${tm.name}</span><span class="chip">${ty.emoji} ${ty.name}</span><span class="chip cat">${q.kategorie}</span></div>`;
}

function LiveQuestion({ view, viewRef, cmd, open, close, say, scene }) {
  const q = view.spickzettel;
  const st = view.stage;
  const wall = scene.wall;
  const inQ = QUESTION_PHASES.includes(st.phase);
  const opts = (wall && wall.options) || [];
  const total = opts.reduce((a, o) => a + (o.count || 0), 0);
  const isRight = (o, i) => (wall && wall.correctIndex != null ? wall.correctIndex === i : o.text === q.korrekt);
  const id = view.aktuelleFrageId || q.id;
  const banned = (view.settings.fragenAus || []).includes(id);
  const pick = () => open(html`<${PickSheet} view=${view} cmd=${cmd} title="🔄 Frage tauschen" hint="Die gewählte Frage ersetzt die laufende — der Timer startet neu." typ=${q.typ} onPick=${x => { cmd({ questionReplace: { frageId: x.id } }); close();
    setTimeout(() => say(viewRef.current.aktuelleFrageId === x.id ? "🔄 Frage getauscht" : "⚠️ Frage passt nicht (Format/Typ, schon gespielt oder Familien-Modus)"), 1200); }} />`, true);
  return html`<div class="card gm-block spick">
    <div class="gm-block-head"><h3>${st.phase === "frage" ? "🟢 Läuft gerade" : st.phase === "erklaerkarte" ? "🔵 Gleich dran" : "📋 Letzte Frage"}${wall && wall.nummer ? html` <small class="muted">${wall.nummer}/${wall.gesamt}</small>` : ""}</h3>${wall && wall.wert ? html`<span class="chip gold">💰 ${fmtNum(wall.wert)}</span>` : ""}</div>
    <${QMeta} q=${q} />
    <p class="spick-q">${q.text}</p>
    ${opts.length > 0 ? html`<div class="gm-opts">${opts.map((o, i) => { const n = o.count || 0; const ok = isRight(o, i);
      return html`<div class=${cx("gm-opt", ok && "ok", o.removed && "removed")}><i style=${`width:${total ? (n / total) * 100 : 0}%`}></i><span class="gm-opt-l">${String.fromCharCode(65 + i)}</span><span class="gm-opt-t">${o.text}${ok ? " ✔" : ""}</span><b>${n || ""}</b></div>`; })}</div>`
      : html`<div class="spick-a">✔ ${q.korrekt}</div>`}
    ${opts.length > 0 && !opts.some((o, i) => isRight(o, i)) && html`<div class="spick-a">✔ ${q.korrekt}</div>`}
    ${q.erklaerung && html`<p class="muted small">${q.erklaerung}</p>`}
    ${q.tipps.length > 0 && html`<details class="spick-tips"><summary>💡 ${q.tipps.length} Tipps</summary><ul>${q.tipps.map(t => html`<li>${t}</li>`)}</ul></details>`}
    ${wall && wall.deadline && !wall.revealed && html`<div class="gm-timer">
      <${TimerBar} deadline=${wall.deadline} total=${wall.timerMs} paused=${st.paused} />
      <div class="gm-shift">${[-10, -5, 5, 15, 30].map(s => html`<button class=${cx(s < 0 && "minus")} onClick=${() => { cmd({ timerShift: { ms: s * 1000 } }); say(`⏱ ${s > 0 ? "+" : "−"}${Math.abs(s)} s`); }}>${s > 0 ? "+" : "−"}${Math.abs(s)} s</button>`)}</div>
    </div>`}
    ${inQ && html`<div class="gm-btn-grid">
      ${st.phase === "frage" && html`<button class="gm-act" onClick=${() => open(html`<${Confirm} title="⏭ Frage überspringen?" text="Die Frage wird annulliert (keine Punkte) und es geht mit der nächsten weiter." label="Überspringen" onYes=${() => { cmd({ questionSkip: {} }); say("⏭ Übersprungen"); }} close=${close} />`)}><span>⏭</span>Überspringen</button>`}
      <button class="gm-act" onClick=${() => { cmd({ questionReplace: {} }); say("🔄 Neue Zufallsfrage"); }}><span>🎲</span>Tauschen (Zufall)</button>
      <button class="gm-act" onClick=${pick}><span>📚</span>Aus Katalog wählen</button>
      <button class=${cx("gm-act", banned ? "on" : "danger")} onClick=${() => { cmd(banned ? { questionUnban: { frageId: id } } : { questionBan: { frageId: id } }); say(banned ? "✅ Wieder zugelassen" : "🚫 Gebannt — kommt nie wieder"); }}><span>${banned ? "↩️" : "🚫"}</span>${banned ? "Bann aufheben" : "Frage bannen"}</button>
    </div>`}
  </div>`;
}

function RevealCard({ view, r, deltas }) {
  const byId = Object.fromEntries(view.stage.players.map(p => [p.id, p]));
  const fast = r.schnellster && byId[r.schnellster];
  const list = [...(r.eintraege || [])].sort((a, b) => a.platzNachher - b.platzNachher);
  return html`<div class="card gm-block reveal">
    <h3>📣 Auflösung</h3>
    <div class="gm-kpis">
      <div class="kpi"><b>${r.richtigAnzahl}<small>/${r.antwortAnzahl || list.length}</small></b><span>richtig</span></div>
      <div class="kpi"><b>${fast ? html`<${Monkey} wire=${fast.avatar} anim="none" size=${26} />` : "—"}${r.schnellsterMs ? (r.schnellsterMs / 1000).toFixed(1) + " s" : ""}</b><span>${fast ? "⚡ " + fast.name : "Schnellster"}</span></div>
      <div class=${cx("kpi", r.fuehrungswechsel && "hot")}><b>${r.fuehrungswechsel ? "👑" : "—"}</b><span>${r.fuehrungswechsel ? "Führungswechsel!" : "Führung bleibt"}</span></div>
    </div>
    ${r.richtigText && html`<div class="spick-a">✔ ${r.richtigText}</div>`}
    <ul class="gm-deltas">${list.map(e => { const p = byId[e.playerId] || { name: e.playerId }; const d = (deltas && deltas[e.playerId]) ?? e.delta; const mv = e.platzVorher - e.platzNachher;
      return html`<li class=${cx(e.richtig === true && "ok", e.richtig === false && "no")}><span class="pl">${e.platzNachher}.</span><${Monkey} wire=${p.avatar} anim="none" size=${28} /><b>${p.name}</b>
        <small>${e.antwortMs > 0 ? (e.antwortMs / 1000).toFixed(1) + " s" : ""}${e.streak >= 2 ? ` · 🔥${e.streak}` : ""}</small>
        <span class=${cx("mv", mv > 0 && "up", mv < 0 && "down")}>${mv > 0 ? "▲" + mv : mv < 0 ? "▼" + -mv : ""}</span><em class=${cx(d > 0 && "plus", d < 0 && "minus")}>${d ? fmtDelta(d) : "±0"}</em></li>`; })}</ul>
  </div>`;
}

function AnswersCard({ view, cmd, open, close, scene }) {
  const players = view.stage.players;
  const wall = scene.wall;
  const det = view.antwortenDetail || {};
  const answered = new Set((wall && wall.answered) || []);
  const clean = d => (d && !(d.ms > 0) ? { ...d, ms: null } : d); // 0 ms = unknown (e.g. after a replace)
  const rows = players.map(p => ({ p, d: clean(det[p.id]), done: !!det[p.id] || answered.has(p.id) || !!view.antworten[p.id] }));
  rows.sort((a, b) => (b.done - a.done) || ((a.d && a.d.ms != null ? a.d.ms : 1e9) - (b.d && b.d.ms != null ? b.d.ms : 1e9)) || a.p.platz - b.p.platz);
  const n = rows.filter(r => r.done).length;
  const right = rows.filter(r => r.d && r.d.richtig === true).length;
  return html`<div class="card gm-block">
    <div class="gm-block-head"><h3>🙋 Antworten <small class="muted">${n}/${players.length}</small></h3>${rows.some(r => r.d && r.d.richtig != null) && html`<span class="chip green">✅ ${right}</span>`}</div>
    <ul class="gm-answers">${rows.map(({ p, d, done }, i) => {
      const cls = d && d.richtig === true ? "ok" : d && d.richtig === false ? "no" : done ? "in" : "";
      const text = d ? d.text : view.antworten[p.id] || (done ? "eingeloggt" : "…");
      return html`<li class=${cls} key=${p.id}>
        <span class="rk">${done && d && d.ms != null ? i + 1 : ""}</span>
        <${Monkey} wire=${p.avatar} anim="none" size=${34} />
        <span class="who"><b>${p.name}</b><small>${text}</small></span>
        ${d && d.ms != null && html`<span class="ms">${(d.ms / 1000).toFixed(1)} s</span>`}
        <span class="st">${cls === "ok" ? "✅" : cls === "no" ? "❌" : done ? "🔒" : "⏳"}</span>
        <button class="mini-btn" aria-label="Flüstern" onClick=${() => open(html`<${Whisper} view=${view} cmd=${cmd} pid=${p.id} close=${close} />`)}>🤫</button>
      </li>`; })}</ul>
  </div>`;
}

function RegalCard({ view, cmd, open, close, say }) {
  const [exp, setExp] = useState(null);
  const bans = new Set(view.settings.fragenAus || []);
  return html`<div class="card gm-block">
    <div class="gm-block-head"><h3>🗄️ Als Nächstes</h3><small class="muted">${view.regal.length} Fragen</small></div>
    <ol class="gm-regal">${view.regal.slice(0, 8).map((q, i) => { const can = q.tauschbar !== false && q.index != null; const isOpen = exp === q.id; const banned = bans.has(q.id);
      return html`<li class=${cx(isOpen && "open", banned && "banned")} key=${q.id + i}>
        <button class="gm-regal-head" onClick=${() => setExp(isOpen ? null : q.id)}>
          <span class="n">${i + 1}</span>
          <span class="t"><${QMeta} q=${q} /><span class="qt">${q.text}</span><small class="ok">✔ ${q.korrekt}</small></span>
        </button>
        ${isOpen && html`<div class="gm-regal-body">
          <${Answers} x=${{ typ: q.typ, korrekt: q.korrekt, antworten: q.antworten }} />
          ${q.erklaerung && html`<p class="muted small">${q.erklaerung}</p>`}
        </div>`}
        <div class="gm-regal-acts">
          <button disabled=${!can} onClick=${() => { cmd({ regalSwap: { index: q.index } }); say("🎲 Getauscht"); }}>🎲 Tauschen</button>
          <button disabled=${!can} onClick=${() => open(html`<${PickSheet} view=${view} cmd=${cmd} title=${`🗄️ Frage ${i + 1} ersetzen`} hint=${q.text} typ=${q.typ} onPick=${x => { cmd({ regalSwap: { index: q.index, frageId: x.id } }); say("📚 Ersetzt"); close(); }} />`, true)}>📚 Wählen</button>
          <button class="danger" onClick=${() => { if (banned) { cmd({ questionUnban: { frageId: q.id } }); say("✅ Wieder zugelassen"); return; } cmd({ questionBan: { frageId: q.id } }); if (can) cmd({ regalSwap: { index: q.index } }); say(can ? "🚫 Gebannt & ersetzt" : "🚫 Gebannt"); }}>${banned ? "↩️ Zulassen" : "🚫 Bannen"}</button>
        </div>
        ${!can && html`<small class="muted gm-regal-lock">🔒 schon in der Runde vergeben</small>`}
      </li>`; })}</ol>
  </div>`;
}

// ---------- sheets ----------
function Picks({ items, value, set, multi }) {
  return html`<div class="gm-grid">${items.map(([v, l]) => html`<button class=${cx("pick", (multi ? value.includes(v) : value === v) && "on")} onClick=${() => set(v)}>${l}</button>`)}</div>`;
}
function PlayerPick({ view, value, set, filter }) {
  return html`<div class="gm-players">${view.stage.players.filter(filter || (() => true)).map(p => html`<button class=${cx("pp", value === p.id && "on")} onClick=${() => set(p.id)}><${Monkey} wire=${p.avatar} anim="none" size=${40} /><small>${p.name}</small></button>`)}</div>`;
}

function PickSheet({ view, cmd, title, hint, typ, onPick }) {
  return html`<h2>${title}</h2>${hint && html`<p class="muted small gm-pick-hint">${hint}</p>`}
    <${Katalog} katalog=${view.katalog} settings=${view.settings} only="browse" compact pin=${view.gmPin}
      onPatch=${p => cmd({ settingsSet: { _0: p } })} onBan=${(id, on) => cmd(on ? { questionBan: { frageId: id } } : { questionUnban: { frageId: id } })}
      onPick=${onPick} pickLabel="🎯 Diese Frage einsetzen" initialFilter=${typ ? { typ } : null} />`;
}

function PauseSheet({ cmd, close }) {
  const [text, setText] = useState("");
  const [dauer, setDauer] = useState(null);
  const go = () => { cmd({ pause: { text: text.trim() || null, dauerMs: dauer } }); close(); };
  return html`<h2>⏸ Pause</h2>
    <${Picks} items=${["Kurze Pause 🍌", "Getränke holen 🍻", "Pizza ist da 🍕", "Gleich geht's weiter!", "Technik-Pause 🔧"].map(x => [x, x])} value=${text} set=${setText} />
    <input class="text-in" placeholder="Eigener Text auf der Bühne …" value=${text} maxlength="80" onInput=${e => setText(e.target.value)} />
    <h4 class="gm-h4">Dauer</h4>
    <div class="seg">${[[null, "Offen"], [60000, "1 min"], [180000, "3 min"], [300000, "5 min"], [600000, "10 min"]].map(([v, l]) => html`<button class=${cx(dauer === v && "on")} onClick=${() => setDauer(v)}>${l}</button>`)}</div>
    <button class="btn block" onClick=${go}>⏸ Pause starten</button>`;
}

function Whisper({ view, cmd, pid: pid0, close }) {
  const [pid, setPid] = useState(pid0 || null);
  const [text, setText] = useState("");
  const q = view.spickzettel;
  const quick = q ? [...q.tipps.map((t, i) => [t, `💡 Tipp ${i + 1}`]), [`Die Antwort ist: ${q.korrekt}`, `✔ Antwort verraten`]] : [];
  return html`<h2>🤫 Flüster-Tipp</h2><${PlayerPick} view=${view} value=${pid} set=${setPid} />
    ${quick.length > 0 && html`<${Picks} items=${quick} value=${text} set=${setText} />`}
    <input class="text-in" placeholder="… oder eigenen Text" value=${text} onInput=${e => setText(e.target.value)} />
    <button class="btn green block" disabled=${!pid || !text.trim()} onClick=${() => { cmd({ whisper: { playerId: pid, text: text.trim() } }); close(); }}>Flüstern</button>`;
}

function Score({ view, cmd, close }) {
  const [pid, setPid] = useState(null);
  const [amt, setAmt] = useState(100);
  const [grund, setGrund] = useState("Lacher des Abends");
  return html`<h2>🏦 Punkte ±</h2><${PlayerPick} view=${view} value=${pid} set=${setPid} />
    <div class="gm-amount">${[-250, -50].map(d => html`<button class="btn ghost small" onClick=${() => setAmt(amt + d)}>${d}</button>`)}<b>${fmtNum(amt)}</b>${[50, 250].map(d => html`<button class="btn ghost small" onClick=${() => setAmt(amt + d)}>+${d}</button>`)}</div>
    <${Picks} items=${["Bester Fehlversuch", "Lacher des Abends", "Fairplay", "Schummelei", "Regie"].map(x => [x, x])} value=${grund} set=${setGrund} />
    <button class="btn green block" disabled=${!pid || !amt} onClick=${() => { cmd({ scoreAdjust: { playerId: pid, delta: amt, grund } }); close(); }}>Buchen</button>`;
}

function Boost({ view, cmd, close }) {
  const [pid, setPid] = useState(null);
  const [art, setArt] = useState("x2");
  const [grund, setGrund] = useState("Comeback-Bonus");
  return html`<h2>🐒 Aufholjagd-Boost</h2><p class="muted small">Nie für Platz 1–2, einmal pro Spieler und Runde.</p>
    <${PlayerPick} view=${view} value=${pid} set=${setPid} filter=${p => p.platz > 2} />
    <${Picks} items=${[["x2", "×2 nächste Frage"], ["plus300", "+300 MM"], ["joker", "Gratis-Joker"]]} value=${art} set=${setArt} />
    <${Picks} items=${["Mut-Buzzer", "Comeback-Bonus", "Pech gehabt"].map(x => [x, x])} value=${grund} set=${setGrund} />
    <button class="btn green block" disabled=${!pid} onClick=${() => { cmd({ boost: { playerId: pid, art, grund } }); close(); }}>Boosten</button>`;
}

function Punish({ view, cmd, close }) {
  const [pid, setPid] = useState(null);
  const [s, setS] = useState("bananensteuer");
  return html`<h2>⚖️ Pranger</h2><${PlayerPick} view=${view} value=${pid} set=${setPid} />
    <${Picks} items=${[["bananensteuer", "🍌 Bananen-Steuer −100"], ["clown", "🤡 Clownsnase"], ["erdbeben", "📳 Handy-Erdbeben"]]} value=${s} set=${setS} />
    <button class="btn red block" disabled=${!pid} onClick=${() => { cmd({ punish: { playerId: pid, strafe: s } }); close(); }}>Bestrafen</button>`;
}

function Gift({ view, cmd, close }) {
  const [ziel, setZiel] = useState("alle");
  const [j, setJ] = useState("bananen-split");
  return html`<h2>🎁 Joker schenken</h2><p class="muted small">Budget: ${view.jokerBudget}</p>
    <div class="gm-row"><button class=${cx("pick", ziel === "alle" && "on")} onClick=${() => setZiel("alle")}>👥 Alle</button></div>
    <${PlayerPick} view=${view} value=${ziel} set=${setZiel} />
    <${Picks} items=${JOKERS} value=${j} set=${setJ} />
    <button class="btn green block" onClick=${() => { cmd({ jokerGrant: { ziel, jokerId: j } }); close(); }}>Schenken</button>`;
}

function Rig({ cmd, close }) {
  const [seg, setSeg] = useState(null);
  return html`<h2>🎯 Gezinktes Rad</h2><p class="muted small">Das Rad landet garantiert auf diesem Feld.</p>
    <${Picks} items=${SEGMENTS} value=${seg} set=${setSeg} />
    <button class="btn block" disabled=${!seg} onClick=${() => { cmd({ wheelSpin: { rigTarget: seg } }); close(); }}>Drehen</button>`;
}

function VoteSheet({ cmd, close }) {
  const [f, setF] = useState("Pause machen?");
  const [o, setO] = useState("Ja, Nein");
  const [d, setD] = useState(20000);
  return html`<h2>🗳️ Abstimmung</h2><input class="text-in" value=${f} onInput=${e => setF(e.target.value)} /><input class="text-in" value=${o} onInput=${e => setO(e.target.value)} />
    <${Picks} items=${[[20000, "20 s"], [45000, "45 s"], [90000, "90 s"]]} value=${d} set=${setD} />
    <button class="btn block" onClick=${() => { const opts = o.split(",").map(x => x.trim()).filter(Boolean); if (f.trim() && opts.length >= 2) { cmd({ voteStart: { frage: f.trim(), optionen: opts, dauerMs: d, bindend: false } }); close(); } }}>Starten</button>`;
}

function Broken({ cmd, close }) {
  const [g, setG] = useState("Frage fehlerhaft");
  const [r, setR] = useState("grantAll");
  return html`<h2>🔴 Frage fehlerhaft</h2><${Picks} items=${["Frage fehlerhaft", "Antwort veraltet", "Technik"].map(x => [x, x])} value=${g} set=${setG} />
    <${Picks} items=${[["grantAll", "Allen den Fragenwert"], ["annul", "Frage annullieren"]]} value=${r} set=${setR} />
    <button class="btn red block" onClick=${() => { cmd({ questionMarkBroken: { grund: g, refund: r } }); close(); }}>Anwenden</button>`;
}

function Confirm({ title, text, label, onYes, close }) {
  return html`<h2>${title}</h2><p class="muted">${text}</p><button class="btn red block" onClick=${() => { onYes(); close(); }}>${label}</button><button class="btn ghost block" onClick=${close}>Abbrechen</button>`;
}

function LookSheet({ player, cmd, close }) {
  const wire = typeof player.avatar === "string" ? player.avatar : `${player.avatar.affe}.${player.avatar.farbe}${player.avatar.extras && player.avatar.extras.length ? "." + player.avatar.extras.join("+") : ""}`;
  const cur = avatarParts(wire);
  const [affe, setAffe] = useState(cur.affe);
  const [farbe, setFarbe] = useState(cur.farbe);
  const extras = String(wire).split(".")[2] ? String(wire).split(".")[2].split("+") : [];
  return html`<h2>🎨 Look für ${player.name}</h2>
    <div class="gm-look-prev"><${Monkey} wire=${`${affe}.${farbe}${extras.length ? "." + extras.join("+") : ""}`} anim="idle" size=${110} /></div>
    <div class="gm-colors">${COLORS.map(([id]) => html`<button class=${cx("gm-color", farbe === id && "on")} style=${`--c:${colorHex(id)}`} aria-label=${id} onClick=${() => setFarbe(id)}></button>`)}</div>
    <div class="gm-monkeys">${MONKEYS.map(([id, name]) => html`<button class=${cx("pp", affe === id && "on")} onClick=${() => setAffe(id)}><${Monkey} wire=${`${id}.${farbe}`} anim="none" size=${40} /><small>${name}</small></button>`)}</div>
    <button class="btn green block" onClick=${() => { cmd({ lookSet: { playerId: player.id, avatar: { affe, farbe, extras } } }); close(); }}>Übernehmen</button>`;
}

function BotSheet({ view, viewRef, cmd, say, close }) {
  const taken = new Set(view.stage.players.map(p => p.name.replace(/\s*🤖$/, "")));
  const add = ([name, affe]) => {
    const before = viewRef.current.stage.players.length;
    cmd({ botAdd: { name, persona: affe } });
    close();
    setTimeout(() => { if (viewRef.current.stage.players.length <= before) say("⚠️ Bot kam nicht an — Raum voll oder nur über die Bühne (⚙️ → Bot dazu)"); else say(`🤖 ${name} sitzt am Pult`); }, 1600);
  };
  return html`<h2>🤖 Bot hinzufügen</h2><p class="muted small">Bots spielen wie echte Affen mit — praktisch zum Auffüllen.</p>
    <div class="gm-bots">${PERSONAS.map(p => html`<button class="gm-bot" disabled=${taken.has(p[0])} onClick=${() => add(p)}><${Monkey} wire=${`${p[1]}.${p[2]}`} anim="none" size=${44} /><b>${p[0]}</b><small>${p[3]}</small></button>`)}</div>`;
}

// ---------- tabs ----------
function Spieler({ view, viewRef, cmd, open, close, say }) {
  const full = Object.fromEntries(view.players.map(p => [p.id, p]));
  const lobby = view.stage.phase === "lobby";
  const removeBot = p => {
    cmd({ botRemove: { _0: p.id } });
    // Fallback: a bot is an ordinary player, kicking removes it too.
    setTimeout(() => { if (viewRef.current.stage.players.some(x => x.id === p.id)) cmd({ kick: { _0: p.id } }); }, 1200);
    say(`🤖 ${p.name} geht`);
  };
  return html`<div class="gm-stack">
    <div class="gm-row gm-quick">
      <button class="gm-act" onClick=${() => open(html`<${Score} view=${view} cmd=${cmd} close=${close} />`)}><span>🏦</span>Punkte ±</button>
      <button class="gm-act" onClick=${() => open(html`<${Boost} view=${view} cmd=${cmd} close=${close} />`)}><span>🐒</span>Boost</button>
      <button class="gm-act" onClick=${() => open(html`<${Punish} view=${view} cmd=${cmd} close=${close} />`)}><span>⚖️</span>Pranger</button>
      <button class="gm-act" onClick=${() => open(html`<${Gift} view=${view} cmd=${cmd} close=${close} />`)}><span>🎁</span>Joker</button>
    </div>
    ${view.stage.players.map(p => { const f = full[p.id] || {};
      return html`<div class=${cx("card gm-player", !p.connected && "off")} key=${p.id}>
        <span class="gp-rank">${p.platz}</span>
        <${Monkey} wire=${p.avatar} anim="none" size=${50} />
        <div class="gp-info"><b>${p.name}</b><${Money} value=${p.balance} /><small class="muted">${f.stats ? `${f.stats.richtig} ✅ · ${f.stats.falsch} ❌` : ""}${p.streak >= 2 ? ` · 🔥${p.streak}` : ""}${f.isBot ? " · Bot" : ""}${!p.connected ? " · offline" : ""}</small></div>
        <div class="gp-btns">
          <button class="mini-btn" aria-label="Flüstern" onClick=${() => open(html`<${Whisper} view=${view} cmd=${cmd} pid=${p.id} close=${close} />`)}>🤫</button>
          <button class="mini-btn" aria-label="Look ändern" onClick=${() => open(html`<${LookSheet} player=${f.id ? f : p} cmd=${cmd} close=${close} />`)}>🎨</button>
          ${f.isBot ? html`<button class="mini-btn" aria-label="Bot entfernen" onClick=${() => removeBot(p)}>🗑</button>`
            : html`<button class="mini-btn" aria-label="Rauswerfen" onClick=${() => open(html`<${Confirm} title="Rauswerfen?" text=${p.name + " verlässt den Raum."} label="Rauswerfen" onYes=${() => cmd({ kick: { _0: p.id } })} close=${close} />`)}>🚪</button>`}
        </div>
      </div>`; })}
    <button class="gm-add" onClick=${() => open(html`<${BotSheet} view=${view} viewRef=${viewRef} cmd=${cmd} say=${say} close=${close} />`)}>🤖 Bot hinzufügen</button>
    ${lobby && view.settings.teams !== "aus" && html`<button class="btn ghost block" onClick=${() => cmd({ teamsShuffle: {} })}>👥 Teams neu mischen</button>`}
  </div>`;
}

function Tools({ view, cmd, open, close, say }) {
  const T = (e, l, fn, hint) => html`<button class="tool" onClick=${fn}><span>${e}</span><b>${l}</b>${hint && html`<small>${hint}</small>`}</button>`;
  return html`<div class="gm-stack">
    <div class="tool-grid">
      ${T("🏦", "Punkte ±", () => open(html`<${Score} view=${view} cmd=${cmd} close=${close} />`))}
      ${T("🤫", "Flüstern", () => open(html`<${Whisper} view=${view} cmd=${cmd} close=${close} />`))}
      ${T("🐒", "Boost", () => open(html`<${Boost} view=${view} cmd=${cmd} close=${close} />`))}
      ${T("⚖️", "Pranger", () => open(html`<${Punish} view=${view} cmd=${cmd} close=${close} />`))}
      ${T("🎁", "Joker schenken", () => open(html`<${Gift} view=${view} cmd=${cmd} close=${close} />`), `Budget ${view.jokerBudget}`)}
      ${T("🎡", "Rad drehen", () => cmd({ wheelSpin: { rigTarget: null } }))}
      ${view.canRig && T("🎯", "Rad zinken", () => open(html`<${Rig} cmd=${cmd} close=${close} />`))}
      ${T("⏳", "+15 s Zeit", () => { cmd({ timerExtend: { ms: 15000 } }); say("+15 s"); }, `${view.timerExtensionsLeft} übrig`)}
      ${T("⏸", "Pause", () => open(html`<${PauseSheet} cmd=${cmd} close=${close} />`))}
      ${T("🔁", "Zugabe", () => cmd({ encore: {} }), `${view.encoresLeft} übrig`)}
      ${T("🌡️", "Stimmung", () => cmd({ moodPoll: {} }), `${view.moodPollsLeft} übrig`)}
      ${T("🗳️", "Abstimmung", () => open(html`<${VoteSheet} cmd=${cmd} close=${close} />`))}
      ${T("🔴", "Frage kaputt", () => open(html`<${Broken} cmd=${cmd} close=${close} />`))}
      ${T("🚪", "Minispiel abbrechen", () => open(html`<${Confirm} title="Notausgang" text="Das laufende Minispiel wird abgebrochen, Punkte bleiben." label="Überspringen" onYes=${() => cmd({ gameSkip: { keepPoints: true } })} close=${close} />`))}
      ${T("💬", "Feedback", () => cmd({ feedbackCollect: {} }))}
      ${T("👥", "Teams mischen", () => cmd({ teamsShuffle: {} }))}
      ${T("🔁", "Revanche", () => open(html`<${Confirm} title="Revanche" text="Gleiche Affen, neues Geld — zurück in die Lobby." label="Revanche!" onYes=${() => cmd({ revanche: {} })} close=${close} />`))}
      ${T("⏹", "Show beenden", () => open(html`<${Confirm} title="Show beenden" text="Die Show endet sofort mit dem Abspann." label="Beenden" onYes=${() => cmd({ ende: {} })} close=${close} />`))}
    </div>
    <div class="card gm-block"><h3>🔊 Soundboard</h3><div class="gm-grid">${SOUNDS.map(([id, l]) => html`<button class="pick" onClick=${() => { cmd({ soundPlay: { _0: id } }); say(l); }}>${l}</button>`)}</div></div>
  </div>`;
}

function Fragen({ view, cmd }) {
  const set = patch => cmd({ settingsSet: { _0: patch } });
  const s = view.settings;
  return html`<div class="gm-stack">
    <div class="card gm-block">
      <div class="gm-block-head"><h3>🎁 Fragen-Set</h3></div>
      <div class="gm-sets">${view.fragenSets.map(q => html`<button class=${cx("gm-set", q.aktiv && "on")} onClick=${() => set({ fragenSet: q.id })}><span>${q.emoji}</span><b>${q.name}</b><small>${fmtNum(q.anzahl)}</small></button>`)}</div>
      <h4 class="gm-h4">Mischung</h4>
      <div class="seg">${MIXES.map(([id, l]) => html`<button class=${cx(s.fragenMix === id && "on")} onClick=${() => set({ fragenMix: id })}>${l}</button>`)}</div>
      <p class="muted small">📚 ${view.poolInfo}</p>
    </div>
    <${Katalog} katalog=${view.katalog} settings=${s} compact pin=${view.gmPin} onPatch=${set}
      onBan=${(id, on) => cmd(on ? { questionBan: { frageId: id } } : { questionUnban: { frageId: id } })} />
  </div>`;
}

function Settings({ view, cmd }) {
  const s = view.settings;
  const set = patch => cmd({ settingsSet: { _0: patch } });
  const lobby = view.stage.phase === "lobby";
  const lock = k => !lobby && view.lobbyOnlySettings.includes(k);
  const Tog = (k, l) => html`<label class=${cx("toggle", lock(k) && "locked")}><span><b>${l}</b>${lock(k) && html`<small>nur in der Lobby</small>`}</span><input type="checkbox" disabled=${lock(k)} checked=${!!s[k]} onChange=${e => set({ [k]: e.target.checked })} /><i></i></label>`;
  const Seg = (k, items) => html`<div class="seg">${items.map(([v, l]) => html`<button class=${cx(s[k] === v && "on")} disabled=${lock(k)} onClick=${() => set({ [k]: v })}>${l}</button>`)}</div>`;
  const timer = s.timerAus ? "aus" : s.fragenZeit ? String(s.fragenZeit) : "auto";
  const rules = new Set(s.specialRules || []);
  return html`<div class="gm-stack">
    ${view.katalog && html`<p class="gm-tip">📚 ${katalogSummary(view.katalog, s)}</p>`}
    <div class="card gm-block"><h3>Ablauf</h3>
      <h4>Show-Modus${lock("modus") ? html` <small class="muted">· nur in der Lobby</small>` : ""}</h4>
      <div class="gm-modes" role="radiogroup" aria-label="Show-Modus">${MODES.map(([v, e, l]) => html`<button class=${cx("gm-mode", s.modus === v && "on")} data-mode=${v} role="radio" aria-checked=${s.modus === v} disabled=${lock("modus")} onClick=${() => s.modus !== v && set({ modus: v })}>
        <span aria-hidden="true">${e}</span><b>${l}</b></button>`)}</div>
      ${(() => { const m = MODES.find(x => x[0] === s.modus); return m ? html`<p class="gm-mode-sub"><b>${m[1]} ${m[2]}</b> · ${m[3]}</p>` : null; })()}
      <h4>Tempo & Teams</h4>
      ${Seg("tempo", [["zackig", "Zackig"], ["normal", "Normal"], ["gemuetlich", "Gemütlich"]])}
      ${Seg("teams", [["aus", "Keine Teams"], ["2er", "2er"], ["2v2v2v2", "4 Lager"], ["frei", "Frei"]])}
      <h4>Timer pro Frage</h4>
      <div class="seg">${[["auto", "Auto"], ["aus", "Aus"], ["15", "15 s"], ["30", "30 s"], ["60", "1 min"], ["120", "2 min"]].map(([v, l]) => html`<button class=${cx(timer === v && "on")} onClick=${() => set(v === "aus" ? { timerAus: true } : v === "auto" ? { timerAus: false, fragenZeit: null } : { timerAus: false, fragenZeit: Number(v) })}>${l}</button>`)}</div>
      ${Tog("jokerAn", "Joker")}${Tog("radAn", "Glücksrad")}${Tog("autoTipp", "Auto-Tipps")}${Tog("familienModus", "Familien-Modus")}${Tog("alkoholEdition", "18+ Trinkspiel-Edition")}${Tog("v2Formate", "Neue Formate")}${Tog("allInErlaubt", "All-In erlaubt")}${Tog("musik", "Musik auf der Bühne")}
      <label class="toggle"><span><b>Auto-Regie</b><small>Das iPad hilft beim Moderieren</small></span><input type="checkbox" checked=${!!s.autoGm} onChange=${e => cmd({ autoGmSet: { _0: e.target.checked } })} /><i></i></label>
      ${Seg("kategorienWahl", [["voting", "Kategorie: Voting"], ["gm", "Kategorie: Regie"], ["aus", "Keine Wahl"]])}
    </div>
    <div class="card gm-block"><h3>✨ Special Rules ${!lobby && html`<small class="muted">(nur Lobby)</small>`}</h3><div class="gm-grid">${RULES.map(([id, l]) => html`<button class=${cx("pick", rules.has(id) && "on")} disabled=${!lobby} onClick=${() => { const n = new Set(rules); n.has(id) ? n.delete(id) : n.add(id); set({ specialRules: [...n] }); }}>${l}</button>`)}</div></div>
    <p class="muted small center">PIN ${view.gmPin} · Raum ${view.roomCode}</p>
  </div>`;
}

render(html`<${App} />`, document.getElementById("app"));
