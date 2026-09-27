// Monkey Money — Show-Master cockpit (phone/tablet). Regie, players, tools,
// question pool and settings — every tool is a bottom sheet.
import { html, render, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { connect, decode, cx, fmtMM, fmtNum, haptic, DIFF } from "../lib/core.js";
import { Monkey, Money, TimerBar } from "../lib/ui.js";

const params = new URLSearchParams(location.search);
const SOUNDS = [["applaus_gross", "👏 Applaus"], ["trommelwirbel", "🥁 Trommelwirbel"], ["falsch", "❌ Fail"], ["dreiklang_tief", "😮 Ohhh!"], ["kaching", "💰 Kassen-Kling"], ["slime", "🦗 Grillen"], ["muenzregen", "🎊 Münzregen"], ["jingle_sax", "🎷 Sax"], ["buzzer_airhorn", "📯 Airhorn"]];
const JOKERS = [["bananen-split", "🍌 Bananen-Split"], ["ueberziehungskredit", "⏳ Überziehungskredit"], ["goldene-banane", "✨ Goldene Banane"], ["schmiergeld", "🤫 Schmiergeld"], ["rueckgaberecht", "↩️ Rückgaberecht"], ["bananentresor", "🛡️ Bananentresor"], ["portfolio-umschichtung", "🔄 Portfolio-Umschichtung"]];
const SEGMENTS = [["doppelter-zaster", "💰 Doppelter Zaster"], ["halbe-miete", "⏱️ Halbe Miete"], ["banana-bailout", "🪂 Banana Bailout"], ["dividende", "📈 Dividende"], ["insider-tipp", "🕵️ Insider-Tipp"], ["inflation", "🎈 Inflation"], ["affentheater", "🎭 Affentheater"], ["boersen-roulette", "📊 Börsen-Roulette"], ["umarmungs-bonus", "🤗 Umarmungs-Bonus"], ["steuerpruefung", "🧾 Steuerprüfung"], ["blackout", "🌑 Blackout"], ["tausch-boerse", "🔁 Tausch-Börse"], ["affe-wuerfelt", "🎲 Der Affe würfelt"], ["kompliment-konto", "💬 Kompliment-Konto"]];
const RULES = [["sr1", "🎰 Vabanque-Finale"], ["sr2", "🦅 Pleitegeier"], ["sr3", "🤫 Notariats-Runde"], ["sr4", "📦 Affensteuer"], ["sr5", "🤠 Kopfgeld"], ["sr6", "🔔 Kapitalismus-Gong"], ["sr7", "🍌 Bananenschale"]];

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
  const cmd = c => { conn.current && conn.current.send({ t: "gm", cmd: c }); haptic(); };
  return html`<div class="gm">
    ${view ? html`<${Cockpit} view=${view} cmd=${cmd} say=${say} />` : html`<${Login} code0=${code0} err=${err} onGo=${(code, pin) => start({ t: "hello", roomCode: code, role: "gm", gmPin: pin })} />`}
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

function Cockpit({ view, cmd, say }) {
  const [tab, setTab] = useState("regie");
  const [sheet, setSheet] = useState(null);
  const ctx = { view, cmd, say, open: setSheet, close: () => setSheet(null) };
  const st = view.stage;
  return html`<div class="cockpit">
    <header class="gm-top">
      <div><b>🎬 Raum ${view.roomCode}</b><small>${st.sectionLabel} · ${phaseName(st.phase)}</small></div>
      <span class="chip">PIN ${view.gmPin}</span>
    </header>
    <main class="gm-main">
      ${tab === "regie" && html`<${Regie} ...${ctx} />`}
      ${tab === "spieler" && html`<${Spieler} ...${ctx} />`}
      ${tab === "tools" && html`<${Tools} ...${ctx} />`}
      ${tab === "fragen" && html`<${Fragen} ...${ctx} />`}
      ${tab === "settings" && html`<${Settings} ...${ctx} />`}
    </main>
    <nav class="gm-tabs">${TABS.map(([id, e, l]) => html`<button class=${cx(tab === id && "on")} onClick=${() => setTab(id)}><span>${e}</span><small>${l}</small></button>`)}</nav>
    ${sheet && html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && setSheet(null)}><div class="p-sheet gm-sheet pop-in">${sheet}</div></div>`}
  </div>`;
}

function phaseName(p) {
  return { lobby: "Lobby", intro: "Opening", "kategorie-wahl": "Kategorie-Wahl", erklaerkarte: "Erklärkarte", frage: "Frage läuft", aufloesung: "Auflösung", zwischenstand: "Zwischenstand", rad: "Glücksrad", halbzeit: "Halbzeit", pause: "Pause", highlights: "Highlights", siegerehrung: "Siegerehrung", ende: "Abspann", brettspiel: "Brettspiel" }[p] || p;
}

// ---------- Regie ----------
function Regie({ view, cmd, open, close, say }) {
  const st = view.stage;
  const scene = decode(st.scene);
  const q = view.spickzettel;
  const players = st.players;
  const wall = scene.wall;
  return html`<div class="gm-stack">
    <div class="card gm-main-card">
      <div class="gm-actions">
        <button class="btn big block" disabled=${!st.canAdvance && !st.paused} onClick=${() => cmd(st.paused ? { resume: {} } : { flowNext: {} })}>${st.paused ? "▶ Weiter" : st.advanceLabel || "Weiter"} ▶</button>
        <div class="gm-row">
          <button class="btn ghost small" onClick=${() => cmd(st.paused ? { resume: {} } : { pause: { text: null, dauerMs: null } })}>${st.paused ? "▶ Fortsetzen" : "⏸ Pause"}</button>
          <button class="btn ghost small" onClick=${() => { cmd({ timerExtend: { ms: 15000 } }); say("+15 s"); }}>⏳ +15 s (${view.timerExtensionsLeft})</button>
          <button class="btn ghost small" onClick=${() => { cmd({ hintGlobal: {} }); say("Tipp für alle"); }}>💡 Tipp</button>
          ${st.phase === "intro" && html`<button class="btn ghost small" onClick=${() => cmd({ flowSkipOpening: {} })}>⏭ Opening</button>`}
        </div>
      </div>
      ${view.empfehlung && html`<p class="gm-tip">🧠 ${view.empfehlung}</p>`}
      <div class="drama"><small>Drama</small><div class="drama-bar"><i style=${`width:${Math.min(100, view.dramaScore)}%`}></i></div></div>
    </div>
    ${scene.kind === "kategorieWahl" && html`<div class="card gm-block"><h3>🗂️ Kategorie festlegen</h3><div class="gm-grid">${scene.optionen.map(o => html`<button class="pick" onClick=${() => cmd({ kategoriePick: { _0: o.id } })}>${o.emoji} ${o.label} <small>${o.count}</small></button>`)}</div></div>`}
    ${q && html`<div class="card gm-block spick">
      <div class="spick-head"><span class="chip">${(DIFF[q.schwierigkeit] || [q.schwierigkeit])[0]}</span><span class="chip">${q.kategorie}</span></div>
      <p class="spick-q">${q.text}</p>
      <div class="spick-a">✔ ${q.korrekt}</div>
      ${q.erklaerung && html`<p class="muted small">${q.erklaerung}</p>`}
      ${q.tipps.length > 0 && html`<ul class="spick-tips">${q.tipps.map(t => html`<li>💡 ${t}</li>`)}</ul>`}
      ${wall && wall.deadline && html`<${TimerBar} deadline=${wall.deadline} total=${wall.timerMs} />`}
    </div>`}
    <div class="card gm-block">
      <h3>Antworten ${wall ? `(${wall.answered.length}/${players.length})` : ""}</h3>
      <ul class="gm-answers">${players.map(p => { const a = view.antworten[p.id]; const ok = q && a && a === q.korrekt;
        return html`<li class=${cx(a && (ok ? "ok" : "no"))}><${Monkey} wire=${p.avatar} anim="none" size=${34} /><b>${p.name}</b><span>${a || (wall && wall.answered.includes(p.id) ? "✔ eingeloggt" : "…")}</span>
          <button class="mini-btn" onClick=${() => open(html`<${Whisper} view=${view} cmd=${cmd} pid=${p.id} close=${close} />`)}>🤫</button></li>`; })}</ul>
    </div>
    ${view.vote && html`<div class="card gm-block"><h3>🗳️ ${view.vote.frage}</h3>${view.vote.optionen.map((o, i) => html`<p>${o}: <b>${Object.values(view.vote.stimmen).filter(v => v === i).length}</b></p>`)}</div>`}
    <div class="card gm-block"><h3>📜 Logbuch</h3><ul class="gm-log">${view.log.slice(-12).reverse().map(l => html`<li><small>${new Date(l.at).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })}</small> ${l.text}</li>`)}</ul></div>
  </div>`;
}

// ---------- sheets ----------
function Picks({ items, value, set, multi }) {
  return html`<div class="gm-grid">${items.map(([v, l]) => html`<button class=${cx("pick", (multi ? value.includes(v) : value === v) && "on")} onClick=${() => set(v)}>${l}</button>`)}</div>`;
}
function PlayerPick({ view, value, set, filter }) {
  return html`<div class="gm-players">${view.stage.players.filter(filter || (() => true)).map(p => html`<button class=${cx("pp", value === p.id && "on")} onClick=${() => set(p.id)}><${Monkey} wire=${p.avatar} anim="none" size=${40} /><small>${p.name}</small></button>`)}</div>`;
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

// ---------- tabs ----------
function Spieler({ view, cmd, open, close }) {
  const full = Object.fromEntries(view.players.map(p => [p.id, p]));
  return html`<div class="gm-stack">${view.stage.players.map(p => { const f = full[p.id] || {};
    return html`<div class=${cx("card gm-player", !p.connected && "off")}>
      <${Monkey} wire=${p.avatar} anim="none" size=${54} />
      <div class="gp-info"><b>${p.platz}. ${p.name}</b><${Money} value=${p.balance} /><small class="muted">${f.stats ? `${f.stats.richtig} richtig · ${f.stats.falsch} falsch` : ""}${p.streak >= 2 ? ` · 🔥${p.streak}` : ""}${f.isBot ? " · Bot" : ""}${!p.connected ? " · offline" : ""}</small></div>
      <div class="gp-btns">
        <button class="mini-btn" onClick=${() => open(html`<${Whisper} view=${view} cmd=${cmd} pid=${p.id} close=${close} />`)}>🤫</button>
        <button class="mini-btn" onClick=${() => open(html`<${Confirm} title="Rauswerfen?" text=${p.name + " verlässt den Raum."} label="Rauswerfen" onYes=${() => cmd({ kick: { _0: p.id } })} close=${close} />`)}>🚪</button>
      </div>
    </div>`; })}
    <div class="gm-row"><button class="btn ghost small" onClick=${() => open(html`<${Score} view=${view} cmd=${cmd} close=${close} />`)}>🏦 Punkte ±</button><button class="btn ghost small" onClick=${() => open(html`<${Boost} view=${view} cmd=${cmd} close=${close} />`)}>🐒 Boost</button><button class="btn ghost small" onClick=${() => open(html`<${Punish} view=${view} cmd=${cmd} close=${close} />`)}>⚖️ Pranger</button><button class="btn ghost small" onClick=${() => open(html`<${Gift} view=${view} cmd=${cmd} close=${close} />`)}>🎁 Joker</button></div>
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
  const pool = new Set(view.settings.kategorienPool || []);
  const toggle = id => { const n = new Set(pool.size ? pool : view.kategorien.map(k => k.id)); n.has(id) ? n.delete(id) : n.add(id); set({ kategorienPool: [...n] }); };
  const [open, setOpen] = useState(null);
  return html`<div class="gm-stack">
    <p class="gm-tip">📚 ${view.poolInfo}</p>
    <div class="gm-grid">${view.fragenSets.map(s => html`<button class=${cx("pick", s.aktiv && "on")} onClick=${() => set({ fragenSet: s.id })}>${s.emoji} ${s.name} <small>${fmtNum(s.anzahl)}</small></button>`)}</div>
    <div class="card gm-block"><h3>Kategorien</h3>${view.kategorien.map(k => html`<div class="kat-line">
      <button class=${cx("pick", k.gewaehlt && "on")} onClick=${() => toggle(k.id)}>${k.emoji} ${k.name} <small>${k.anzahl}</small></button>
      ${k.unter.length > 0 && html`<button class="mini-btn" onClick=${() => setOpen(open === k.id ? null : k.id)}><span class=${cx("chev", open === k.id && "up")}>›</span></button>`}
      ${open === k.id && html`<div class="gm-grid sub">${k.unter.map(u => html`<button class=${cx("pick", u.gewaehlt && "on")} onClick=${() => toggle(u.id)}>${u.name} <small>${u.anzahl}</small></button>`)}</div>`}
    </div>`)}</div>
    ${view.regal.length > 0 && html`<div class="card gm-block"><h3>🗄️ Als Nächstes</h3><ol class="gm-log">${view.regal.slice(0, 8).map(q => html`<li>${q.text} <small class="muted">· ${q.korrekt}</small></li>`)}</ol></div>`}
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
    <div class="card gm-block"><h3>Ablauf</h3>
      ${Seg("modus", [["quick", "Quick"], ["klassik", "Klassik"], ["marathon", "Marathon"]])}
      ${Seg("tempo", [["zackig", "Zackig"], ["normal", "Normal"], ["gemuetlich", "Gemütlich"]])}
      ${Seg("teams", [["aus", "Keine Teams"], ["2er", "2er"], ["2v2v2v2", "4 Lager"], ["frei", "Frei"]])}
      <h4>Timer pro Frage</h4>
      <div class="seg">${[["auto", "Auto"], ["aus", "Aus"], ["15", "15 s"], ["30", "30 s"], ["60", "1 min"], ["120", "2 min"]].map(([v, l]) => html`<button class=${cx(timer === v && "on")} onClick=${() => set(v === "aus" ? { timerAus: true } : v === "auto" ? { timerAus: false, fragenZeit: null } : { timerAus: false, fragenZeit: Number(v) })}>${l}</button>`)}</div>
      ${Tog("jokerAn", "Joker")}${Tog("radAn", "Glücksrad")}${Tog("autoTipp", "Auto-Tipps")}${Tog("familienModus", "Familien-Modus")}${Tog("alkoholEdition", "18+ Trinkspiel-Edition")}${Tog("v2Formate", "Neue Formate")}${Tog("allInErlaubt", "All-In erlaubt")}${Tog("musik", "Musik auf der Bühne")}
      <label class="toggle"><span><b>Auto-Regie</b><small>Das iPad hilft beim Moderieren</small></span><input type="checkbox" checked=${!!s.autoGm} onChange=${e => cmd({ autoGmSet: { _0: e.target.checked } })} /><i></i></label>
      ${Seg("kategorienWahl", [["voting", "Kategorie: Voting"], ["gm", "Kategorie: Regie"], ["aus", "Keine Wahl"]])}
    </div>
    <div class="card gm-block"><h3>✨ Special Rules ${!lobby && html`<small class="muted">(nur Lobby)</small>`}</h3><div class="gm-grid">${RULES.map(([id, l]) => html`<button class=${cx("pick", rules.has(id) && "on")} disabled=${!lobby} onClick=${() => { const n = new Set(rules); n.has(id) ? n.delete(id) : n.add(id); set({ specialRules: [...n] }); }}>${l}</button>`)}</div></div>
  </div>`;
}

render(html`<${App} />`, document.getElementById("app"));
