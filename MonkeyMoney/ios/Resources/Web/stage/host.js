// Host screens on the stage: main menu, mode choice, saves, leaderboards,
// how-to, the lobby and the settings drawer.
import { html, useState, useEffect } from "../vendor/preact-htm.js";
import { api, cx, fmtMM, fmtNum, decode } from "../lib/core.js";
import { audio } from "../lib/audio.js";
import { Monkey, QR } from "../lib/ui.js";
import { StageCtx } from "./ctx.js";
import { Katalog, katalogSummary, applyFilterPatch, filterOf } from "../lib/katalog.js";

// ---------- question catalogue (full-screen overlay + entry button) ----------
export function KatalogEntry({ katalog, settings, onOpen }) {
  return html`<button class="kt-entry" onClick=${onOpen}>
    <span class="kt-entry-ico">📚</span>
    <span class="kt-entry-txt"><b>Fragen-Katalog</b><small>${katalog ? katalogSummary(katalog, settings) : "Kategorien, Stufen, Typen & einzelne Fragen"}</small></span>
    <span class="kt-entry-go">›</span>
  </button>`;
}

export function KatalogOverlay({ katalog, settings, onPatch, local, close }) {
  return html`<div class="kt-overlay" onClick=${e => e.stopPropagation()}>
    <header>
      <div><h2>📚 Fragen-Katalog</h2><p>${local ? "Gilt für die neue Show — du kannst alles später in der Lobby ändern." : "Änderungen gelten sofort, auch mitten in der Show."}</p></div>
      <button class="btn green kt-done" onClick=${close}>✔ Fertig</button>
    </header>
    <div class="kt-overlay-body"><${Katalog} katalog=${katalog} settings=${settings} onPatch=${onPatch} local=${local} wide /></div>
  </div>`;
}

export function Logo({ size = 1, edition }) {
  return html`<div class="logo" style=${`--s:${size}`}>
    <div class="logo-hat">🎩</div>
    <div class="logo-line l1">MONKEY</div>
    <div class="logo-line l2">MONEY</div>
    <div class="logo-plaque">${edition ? "⚔️ " + edition.toUpperCase() : "QUIZ · PLAY · WIN"}</div>
    <span class="logo-coin c1">🍌</span><span class="logo-coin c2">🪙</span><span class="logo-coin c3">💰</span>
  </div>`;
}

async function hostCall(path, body) {
  try { await api(path, body); } catch (e) { StageCtx.toast("⚠️ " + e.message); }
  return StageCtx.refreshHost();
}

// ---------- main menu ----------
export function MenuScreen({ host, go }) {
  const auto = host.autosave;
  const dancers = [["don-bananas.gelb", 0], ["kiki-krawall.rot", 300], ["glitzer-gina.pink", 600], ["astro-astrid.blau", 150], ["dj-trommelfell.orange", 450], ["kahuna-kalle.tuerkis", 750]];
  return html`<div class="menu">
    <div class="menu-dancers left">${dancers.slice(0, 3).map(([w, d], i) => html`<${Monkey} wire=${w} anim="dance" delay=${d} size=${150 - i * 18} class=${"dancer d" + i} />`)}</div>
    <div class="menu-center">
      <${Logo} size=${1.25} edition=${host.edition} />
      <div class="menu-buttons">
        ${auto && html`<button class="resume-card rise-in" onClick=${() => hostCall("/api/host/load", { slot: 0 })}>
          <span class="resume-play">▶</span>
          <span class="resume-text"><b>Weiterspielen</b><small>${auto.label}</small></span>
          <span class="resume-faces">${auto.players.slice(0, 4).map(p => html`<${Monkey} wire=${p.avatar} anim="none" size=${46} />`)}</span>
        </button>`}
        <button class="btn big block" onClick=${() => go("modes")}>🎬 Neue Show starten</button>
        <div class="menu-row">
          <button class="btn green block" onClick=${() => hostCall("/api/host/start", { modus: "quick", spielModus: "spieleabend" })}>🎲 Spiele-Abend</button>
          <button class="btn violet block" onClick=${() => go("saves")}>💾 Spielstände</button>
        </div>
        <div class="menu-row">
          <button class="btn ghost block small" onClick=${() => go("boards")}>🏆 Bestenlisten</button>
          <button class="btn ghost block small" onClick=${() => go("howto")}>❓ So geht's</button>
        </div>
      </div>
    </div>
    <div class="menu-dancers right">${dancers.slice(3).map(([w, d], i) => html`<${Monkey} wire=${w} anim="dance" delay=${d} size=${150 - i * 18} class=${"dancer d" + i} />`)}</div>
    <footer class="menu-foot">
      <span>🧠 ${fmtNum(host.questionCount)} Fragen</span><span>🎮 ${(host.formate || []).length || 33} Formate</span><span>🎲 6 Brettspiele</span><span>👤 ${host.profileCount} Profile</span>
      <span class="muted">Gleiches WLAN · Handys scannen · los geht's</span>
    </footer>
  </div>`;
}

// ---------- mode choice ----------
const MODE_ART_KNOWN = { quick: ["⚡", "#2bd98a"], klassik: ["🎩", "#ffc93c"], marathon: ["🏃", "#ff6bd6"], blitz: ["🌩️", "#5fc4ff"], party: ["🎉", "#ff8a3d"], profi: ["🎓", "#b18cff"], eigen: ["🛠️", "#9be15d"] };
/** Emoji + accent colour of a mode — unknown ids get the server emoji and a neutral gold. */
const modeArt = m => MODE_ART_KNOWN[m.id] || [m.emoji || "🎬", "#ffc93c"];
export function ModeScreen({ host, back }) {
  const [modus, setModus] = useState("klassik");
  const [set, setSet] = useState(host.defaults[modus].fragenSet);
  const [tempo, setTempo] = useState("normal");
  const [familie, setFamilie] = useState(false);
  const [filt, setFilt] = useState(filterOf(null));
  const [katOpen, setKatOpen] = useState(false);
  const league = !!host.edition;
  const start = () => {
    const patch = { fragenSet: set, tempo, familienModus: familie };
    for (const [k, v] of Object.entries(filt)) if (v.length) patch[k] = v;
    return hostCall("/api/host/start", { modus, patch });
  };
  return html`<div class="modes">
    <header class="screen-head"><button class="btn ghost small" onClick=${back}>‹ Zurück</button><h1>Welche Show heute?</h1><span></span></header>
    <div class="mode-cards">
      ${host.modes.map((m, i) => html`<button class=${cx("mode-card", modus === m.id && "on")} data-mode=${m.id} style=${`--accent:${modeArt(m)[1]};animation-delay:${i * 90}ms`} onClick=${() => setModus(m.id)}>
        <span class="mode-emoji">${modeArt(m)[0]}</span>
        <h2>${m.title}</h2>
        <p>${m.subtitle}</p>
        ${modus === m.id && html`<span class="mode-check">✔️</span>`}
      </button>`)}
    </div>
    <div class="mode-options card">
      ${!league && html`<div class="opt-block"><h4>Fragen-Set</h4><div class="chip-row">${host.questionSets.filter(q => q.id !== "eigen").map(q => html`
        <button class=${cx("pick", set === q.id && "on")} onClick=${() => setSet(q.id)}>${q.emoji} ${q.name} <small>${fmtNum(q.anzahl)}</small></button>`)}</div></div>`}
      <div class="opt-inline">
        <div class="opt-block"><h4>Tempo</h4><div class="seg">${host.tempos.map(t => html`<button class=${cx(tempo === t.id && "on")} onClick=${() => setTempo(t.id)}>${t.label}</button>`)}</div></div>
        <div class="opt-block"><h4>Publikum</h4><div class="seg"><button class=${cx(!familie && "on")} onClick=${() => setFamilie(false)}>🍻 Erwachsene</button><button class=${cx(familie && "on")} onClick=${() => setFamilie(true)}>👨‍👩‍👧 Familie & Kinder</button></div></div>
      </div>
      <${KatalogEntry} katalog=${host.katalog} settings=${filt} onOpen=${() => setKatOpen(true)} />
    </div>
    <div class="mode-go"><button class="btn big" onClick=${start}>🚪 Lobby öffnen</button><p class="muted">Alles andere (Teams, Joker, Timer, Special Rules …) stellst du in der Lobby ein.</p></div>
    ${katOpen && html`<${KatalogOverlay} katalog=${host.katalog} settings=${filt} local onPatch=${p => setFilt(f => applyFilterPatch(f, p))} close=${() => setKatOpen(false)} />`}
  </div>`;
}

// ---------- saves ----------
export function SavesScreen({ host, back }) {
  const all = [host.autosave && { ...host.autosave, auto: true }, ...host.slots.map((s, i) => s || { id: i + 1, empty: true })].filter(Boolean);
  return html`<div class="saves">
    <header class="screen-head"><button class="btn ghost small" onClick=${back}>‹ Zurück</button><h1>💾 Spielstände</h1><span></span></header>
    <div class="save-grid">${all.map((s, i) => html`<div class=${cx("save-card card rise-in", s.empty && "empty")} style=${`animation-delay:${i * 70}ms`}>
      <h3>${s.auto ? "⏱ Autosave" : `Slot ${s.id}`}</h3>
      ${s.empty ? html`<p class="muted">Leer — während der Show über ⚙️ speichern.</p>` : html`
        <p>${s.label}</p><p class="muted">${new Date(s.savedAt).toLocaleString("de-DE")}</p>
        <div class="save-faces">${s.players.slice(0, 6).map(p => html`<div class="save-face"><${Monkey} wire=${p.avatar} anim="none" size=${54} /><small>${p.name}</small></div>`)}</div>
        <div class="menu-row"><button class="btn green small" onClick=${() => hostCall("/api/host/load", { slot: s.id })}>▶ Laden</button><button class="btn ghost small" onClick=${() => hostCall("/api/host/delete", { slot: s.id })}>🗑 Löschen</button></div>`}
    </div>`)}</div>
  </div>`;
}

// ---------- leaderboards ----------
export function BoardsScreen({ back }) {
  const [b, setB] = useState(null);
  useEffect(() => { api("/api/boards").then(setB).catch(() => setB({})); }, []);
  const col = (title, list) => html`<div class="board card"><h3>${title}</h3>${list && list.length ? html`<ol>${list.map((e, i) => html`<li><span class="rank">${i + 1}</span><${Monkey} wire=${e.avatar} anim="none" size=${40} /><span class="n">${e.name}</span><b>${e.anzeige}</b></li>`)}</ol>` : html`<p class="muted">Noch niemand — spielt mit Profil, dann wandert ihr hier rein.</p>`}</div>`;
  return html`<div class="boards">
    <header class="screen-head"><button class="btn ghost small" onClick=${back}>‹ Zurück</button><h1>🏆 Bestenlisten</h1><span></span></header>
    ${!b ? html`<p class="muted center">Lade …</p>` : html`<div class="board-grid">${col("💰 Money-Boss", b.moneyBoss)}${col("⚡ Blitz-Buzzer", b.blitzBuzzer)}${col("🚀 Comeback-König", b.comebackKoenig)}</div>`}
  </div>`;
}

export function HowtoScreen({ back }) {
  const steps = [
    ["📺", "Das iPad ist die Bühne", "Stell es so auf, dass alle es sehen. Es ist Server, Moderator und Spielstand in einem — Internet braucht ihr nicht."],
    ["📱", "Handys sind die Buzzer", "QR-Code in der Lobby scannen, Namen und Affen wählen, fertig. Nichts installieren — es läuft im Browser."],
    ["🎬", "Show-Master (optional)", "Ein Handy kann Regie führen: Antworten sehen, Tipps flüstern, Joker schenken, das Rad zinken. Ohne Show-Master moderiert das iPad selbst."],
    ["💰", "Monkey Money gewinnen", "Jede Runde ist ein anderes Format. Richtig und schnell bringt Geld, Joker retten euch, das Glücksrad mischt alles auf."],
    ["🐊", "Finale & Siegerehrung", "Im Lianen-Finale entscheidet sich alles. Danach gibt es Podest, Awards und eine Revanche auf Knopfdruck."],
  ];
  return html`<div class="howto">
    <header class="screen-head"><button class="btn ghost small" onClick=${back}>‹ Zurück</button><h1>❓ So funktioniert's</h1><span></span></header>
    <div class="howto-steps">${steps.map(([e, t, d], i) => html`<div class="howto-step card rise-in" style=${`animation-delay:${i * 90}ms`}><span class="howto-n">${i + 1}</span><span class="howto-e">${e}</span><h3>${t}</h3><p class="muted">${d}</p></div>`)}</div>
  </div>`;
}

// ---------- lobby ----------
export function LobbyScene({ view, lobby, host }) {
  const [showGm, setShowGm] = useState(false);
  const [pendingGame, setPendingGame] = useState(null);
  const s = lobby.settings;
  const spieleabend = s.spielModus === "spieleabend";
  const players = view.players;
  const slots = Math.max(8, Math.min(lobby.maxPlayers, players.length + (players.length < lobby.maxPlayers ? 1 : 0)));
  const code = view.roomCode;
  const setName = (host.questionSets.find(q => q.id === s.fragenSet) || {}).name || "Eigene Auswahl";
  const cmd = StageCtx.cmd;
  return html`<div class="lobby">
    <header class="lobby-head">
      <button class="btn ghost small" onClick=${() => StageCtx.ask("Lobby schließen und zurück ins Menü?", () => hostCall("/api/host/close", {}))}>‹ Menü</button>
      <div class="brand big"><span class="brand-mark">🐵</span><span class="brand-word">MONKEY<b>MONEY</b></span>${host.edition && html`<span class="chip gold">${host.edition}</span>`}</div>
      <div class="lobby-head-r">
        <button class="btn ghost small" onClick=${() => hostCall("/api/host/bots", { add: 1 })}>🤖 Bot</button>
        <button class="btn ghost small" onClick=${() => StageCtx.openDrawer()}>⚙️ Einstellungen</button>
      </div>
    </header>
    <div class="lobby-body">
      <section class="join-card card">
        <h2>Scannen & mitspielen!</h2>
        <div class="qr-wrap"><${QR} text=${lobby.joinURL} size=${280} /><span class="qr-banana">🍌</span></div>
        <div class="join-url">${lobby.joinURL.replace(/^https?:\/\//, "")}</div>
        <div class="room-code">${code.split("").map((c, i) => html`<span style=${`animation-delay:${i * 80}ms`}>${c}</span>`)}</div>
        <p class="muted small">Gleiches WLAN wie das iPad · Kamera auf den Code</p>
      </section>
      <section class="bande">
        <div class="bande-head"><h2>Die Affen-Bande</h2><span class="chip">${players.length} / ${lobby.maxPlayers}</span></div>
        <div class="bande-grid" style=${`--cols:${slots > 8 ? 6 : 4}`}>
          ${Array.from({ length: slots }, (_, i) => {
            const p = players[i];
            if (!p) return html`<div class="seat empty" key=${"e" + i}><div class="seat-ghost">?</div><span>Platz frei</span></div>`;
            return html`<div class="seat" key=${p.id}>
              <div class="seat-drop"><${Monkey} wire=${p.avatar} anim=${p.connected ? "idle" : "none"} face=${p.connected ? "jubel" : "frust"} size=${118} delay=${i * 170} /></div>
              <div class="seat-plate"><b>${p.name}</b>${!p.connected && html`<small>offline</small>`}</div>
              <button class="seat-kick" title="Rauswerfen" onClick=${() => StageCtx.ask(p.name + " rauswerfen?", () => cmd({ kick: { _0: p.id } }))}>×</button>
            </div>`;
          })}
        </div>
      </section>
      <section class="lobby-side">
        <div class="card show-card">
          <h3>${spieleabend ? "🎲 Spiele-Abend" : { quick: "⚡ Quick Cash", klassik: "🎩 Klassik-Show", marathon: "🏃 Marathon" }[s.modus]}</h3>
          <div class="chip-row">
            <span class="chip">📚 ${setName}</span>
            ${host.katalog && html`<span class="chip">🧠 ${katalogSummary(host.katalog, s).split(" · ")[0].replace(" Fragen aktiv", " aktiv")}</span>`}
            <span class="chip">⏱ ${s.timerAus ? "Timer aus" : s.fragenZeit ? s.fragenZeit + " s pro Frage" : { zackig: "Zackig", normal: "Normal", gemuetlich: "Gemütlich" }[s.tempo]}</span>
            ${s.familienModus && html`<span class="chip green">👨‍👩‍👧 Familie</span>`}
            ${s.teams !== "aus" && html`<span class="chip">👥 Teams ${s.teams}</span>`}
            ${s.jokerAn && html`<span class="chip">🃏 Joker</span>`}
            ${s.radAn && html`<span class="chip">🎡 Glücksrad</span>`}
            ${(s.specialRules || []).length > 0 && html`<span class="chip gold">✨ ${s.specialRules.length} Special Rules</span>`}
          </div>
          <button class="btn ghost small block" onClick=${() => StageCtx.openDrawer()}>Einstellungen ändern</button>
        </div>
        <div class="card gm-card">
          <div class="gm-head"><h3>🎬 Show-Master</h3><button class="btn ghost small" onClick=${() => setShowGm(!showGm)}>${showGm ? "Ausblenden" : "Code zeigen"}</button></div>
          ${showGm ? html`<div class="gm-reveal"><${QR} text=${lobby.gmURL} size=${150} dark="#2a1466" /><div><p class="muted">PIN</p><div class="gm-pin">${lobby.gmPin}</div></div></div>`
            : html`<p class="muted small">${view.gmOnline ? "✅ Show-Master ist verbunden." : "Optional: ein Handy führt Regie. Ohne Show-Master moderiert das iPad."}</p>`}
        </div>
      </section>
    </div>
    <footer class="lobby-foot">
      ${spieleabend ? html`<div class="games-row">${lobby.boardgames.map(g => html`<button class=${cx("game-card", !g.startbar && "off")} onClick=${() => setPendingGame(g)}>
          <span class="g-emoji">${g.emoji}</span><b>${g.name}</b><small>${g.minSpieler}–${g.maxSpieler} Spieler</small></button>`)}</div>`
        : html`<button class=${cx("btn big start-btn", lobby.canStart && "ready")} disabled=${!lobby.canStart} onClick=${() => cmd({ flowNext: {} })}>
          ${lobby.canStart ? "🎬 Show starten!" : lobby.startHint}</button>`}
    </footer>
    ${pendingGame && html`<${GameSheet} g=${pendingGame} close=${() => setPendingGame(null)} />`}
  </div>`;
}

function GameSheet({ g, close }) {
  const [variante, setVariante] = useState(g.varianten[0] || "");
  const [seats, setSeats] = useState([]);
  const [draft, setDraft] = useState("");
  const start = () => {
    const optionen = { variante };
    if (!g.phonesOnly) optionen.lokaleSitze = seats;
    StageCtx.cmd({ boardgameStart: { id: g.id, optionen } });
    close();
  };
  return html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && close()}><div class="sheet card pop-in">
    <h2>${g.emoji} ${g.name}</h2><p class="muted">${g.untertitel}</p>
    <ol class="rules">${g.howto.map(l => html`<li>${l}</li>`)}</ol>
    ${g.varianten.length > 0 && html`<div class="seg">${g.varianten.map(v => html`<button class=${cx(variante === v && "on")} onClick=${() => setVariante(v)}>${v === "kurz" ? "Kurze Partie" : v === "klassisch" ? "Klassisch" : v}</button>`)}</div>`}
    ${!g.phonesOnly && html`<div class="seat-input"><input value=${draft} placeholder="iPad-Sitz (Name)" onInput=${e => setDraft(e.target.value)} onKeyDown=${e => { if (e.key === "Enter" && draft.trim()) { setSeats([...seats, draft.trim()]); setDraft(""); } }} />
      <button class="btn ghost small" onClick=${() => { if (draft.trim()) { setSeats([...seats, draft.trim()]); setDraft(""); } }}>+ Sitz</button>
      ${seats.map(n => html`<span class="chip" onClick=${() => setSeats(seats.filter(x => x !== n))}>📱 ${n} ×</span>`)}</div>`}
    <p class="muted small">${g.hinweis}</p>
    <div class="menu-row"><button class="btn" disabled=${!g.startbar && seats.length === 0} onClick=${start}>▶ Los geht's</button><button class="btn ghost" onClick=${close}>Abbrechen</button></div>
  </div></div>`;
}

// ---------- settings drawer ----------
export function SettingsDrawer({ view, host, close }) {
  const scene = decode(view.scene);
  const inLobby = scene.kind === "lobby";
  const s = (inLobby ? scene.settings : host.settings) || {};
  const set = patch => StageCtx.cmd({ settingsSet: { _0: patch } });
  const [katOpen, setKatOpen] = useState(false);
  const katPatch = patch => { set(patch); setTimeout(() => StageCtx.refreshHost(), 250); setTimeout(() => StageCtx.refreshHost(), 900); };
  const toggle = (k, label, hint) => html`<label class="toggle"><span><b>${label}</b>${hint && html`<small>${hint}</small>`}</span><input type="checkbox" checked=${!!s[k]} onChange=${e => set({ [k]: e.target.checked })} /><i></i></label>`;
  const rules = new Set(s.specialRules || []);
  const timerVal = s.timerAus ? "aus" : s.fragenZeit ? String(s.fragenZeit) : "auto";
  const setTimer = v => set(v === "aus" ? { timerAus: true } : v === "auto" ? { timerAus: false, fragenZeit: null } : { timerAus: false, fragenZeit: Number(v) });
  return html`<div class="drawer-veil" onClick=${e => e.target === e.currentTarget && close()}>
    <aside class="drawer">
      <header><h2>⚙️ Einstellungen</h2><button class="icon-btn" onClick=${close}>×</button></header>
      <div class="drawer-body">
        <section><h4>Ton (dieses Gerät)</h4>
          <label class="toggle"><span><b>Musik</b></span><input type="checkbox" checked=${audio.musicOn} onChange=${e => audio.setMusicOn(e.target.checked)} /><i></i></label>
          <label class="toggle"><span><b>Soundeffekte</b></span><input type="checkbox" checked=${audio.sfxOn} onChange=${e => audio.setSfxOn(e.target.checked)} /><i></i></label>
          <label class="slider"><span>Lautstärke</span><input type="range" min="0" max="1" step="0.05" value=${audio.volume} onInput=${e => audio.setVolume(Number(e.target.value))} /></label>
        </section>
        ${inLobby && html`<section><h4>Show-Ablauf <small class="muted">(nur in der Lobby)</small></h4>
          <div class="seg">${host.modes.map(m => html`<button class=${cx(s.modus === m.id && "on")} onClick=${() => set({ modus: m.id })}>${m.title}</button>`)}</div>
          <div class="seg">${[["aus", "Keine Teams"], ["2er", "2er-Teams"], ["2v2v2v2", "4 Lager"], ["frei", "Freie Wahl"]].map(([v, l]) => html`<button class=${cx(s.teams === v && "on")} onClick=${() => { set({ teams: v }); setTimeout(() => StageCtx.cmd({ teamsShuffle: {} }), 150); }}>${l}</button>`)}</div>
          ${toggle("v2Formate", "Neue Formate", "Auktion, Bluff, Duelle, Musik-Runden …")}
          ${toggle("allInErlaubt", "All-In erlaubt", "Wetten dürfen das ganze Konto setzen")}
          <h4 class="sub">Special Rules</h4>
          <div class="rule-grid">${host.specialRules.map(r => html`<button class=${cx("rule", rules.has(r.id) && "on")} title=${r.description} onClick=${() => { const n = new Set(rules); n.has(r.id) ? n.delete(r.id) : n.add(r.id); set({ specialRules: [...n] }); }}>
            <span>${r.emoji}</span><b>${r.name}</b><small>${r.description}</small></button>`)}</div>
        </section>`}
        <section><h4>Fragen</h4>
          <${KatalogEntry} katalog=${host.katalog} settings=${s} onOpen=${() => setKatOpen(true)} />
          ${!host.edition && html`<div class="chip-row">${host.questionSets.filter(q => q.id !== "eigen").map(q => html`<button class=${cx("pick", s.fragenSet === q.id && "on")} onClick=${() => set({ fragenSet: q.id })}>${q.emoji} ${q.name}</button>`)}</div>`}
          <div class="seg">${host.mixes.map(m => html`<button class=${cx(s.fragenMix === m.id && "on")} onClick=${() => set({ fragenMix: m.id })}>${m.label}</button>`)}</div>
          <div class="seg">${host.tempos.map(t => html`<button class=${cx(s.tempo === t.id && "on")} onClick=${() => set({ tempo: t.id })}>${t.label}</button>`)}</div>
          <h4 class="sub">Timer pro Frage</h4>
          <div class="seg">${[["auto", "Automatisch"], ["aus", "Aus"], ["15", "15 s"], ["30", "30 s"], ["60", "1 min"], ["120", "2 min"]].map(([v, l]) => html`<button class=${cx(timerVal === v && "on")} onClick=${() => setTimer(v)}>${l}</button>`)}</div>
          ${toggle("familienModus", "Familien-Modus", "Kindgerechte Fragen, mehr Zeit")}
          ${toggle("jokerAn", "Joker", "7 Joker auf den Handys")}
          ${toggle("radAn", "Glücksrad", "Zwischen den Runden")}
          ${toggle("autoTipp", "Auto-Tipps", "Bei schweren Fragen hilft die Regie")}
          <div class="seg">${[["voting", "Kategorie: Abstimmung"], ["gm", "Kategorie: Show-Master"], ["aus", "Keine Kategorie-Wahl"]].map(([v, l]) => html`<button class=${cx(s.kategorienWahl === v && "on")} onClick=${() => set({ kategorienWahl: v })}>${l}</button>`)}</div>
        </section>
        <section><h4>Show</h4>
          ${!inLobby && html`<div class="menu-row">${[1, 2, 3].map(n => html`<button class="btn violet small" onClick=${() => hostCall("/api/host/save", { slot: n }).then(() => StageCtx.toast("💾 Gespeichert in Slot " + n))}>💾 Slot ${n}</button>`)}</div>`}
          <div class="menu-row">
            <button class="btn ghost small" onClick=${() => hostCall("/api/host/bots", { add: 1 })}>🤖 Bot dazu</button>
            <button class="btn ghost small" onClick=${() => hostCall("/api/host/bots", { remove: true })}>Bots entfernen</button>
          </div>
          <div class="menu-row">
            ${!inLobby && html`<button class="btn ghost small" onClick=${() => StageCtx.cmd({ flowSkipOpening: {} })}>⏭ Intro überspringen</button>`}
            <button class="btn red small" onClick=${() => StageCtx.ask("Show beenden und zurück ins Hauptmenü? Der Autosave bleibt erhalten.", () => { close(); hostCall("/api/host/close", {}); })}>⏹ Zurück ins Menü</button>
          </div>
        </section>
      </div>
    </aside>
    ${katOpen && html`<${KatalogOverlay} katalog=${host.katalog} settings=${s} onPatch=${katPatch} close=${() => setKatOpen(false)} />`}
  </div>`;
}
