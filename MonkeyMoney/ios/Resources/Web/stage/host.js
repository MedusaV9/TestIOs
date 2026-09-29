// Host screens on the stage: main menu, mode choice, saves, leaderboards,
// how-to, the lobby and the settings drawer.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
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
/** One-line card pitch per known mode (minutes + rounds live in the badges); unknown ids keep the server subtitle. */
const MODE_TAG = { quick: "Ein-Tap-Start für zwischendurch", klassik: "Die ganze Show mit Jackpot & Finale", marathon: "Alle Formate · Halbzeit-Pause", blitz: "Drei Blitzrunden + Mini-Finale", party: "Wenig Wissen, viel Chaos", profi: "Knifflig · ohne Glücksrad", eigen: "Formate, Reihenfolge, Fragenzahl — du baust" };
/** "🎩 Klassik-Show" for the lobby card — every server mode, unknown ids with their server emoji. */
export function modeLabel(host, id) {
  const m = (host.modes || []).find(x => x.id === id);
  return m ? `${modeArt(m)[0]} ${m.title}` : "🎬 Show";
}

// ---------- "Eigene Show": playlist builder ----------
const EIGEN_MAX = 12;
const ART = { fragen: ["🧠", "Fragen"], songs: ["🎵", "Songs"], party: ["🎉", "Party"] };
const TEMPO_F = { zackig: 0.85, normal: 1, gemuetlich: 1.4 };
/** Same factor as MatchSettings.tempoFactor (family mode is slower). */
export const tempoFactor = s => (s && s.familienModus ? 1.5 : 1) * (TEMPO_F[s && s.tempo] || 1);
/** Seconds per question like Plan.estimateMinutes: rapid formats run short mini-reveals. */
const PER_Q = { affenzahn: 12, affenschaukel: 20, "letzter-affe": 11, herdentrieb: 18, "kokos-kopf": 30 };
/** Rough show length of a hand-built playlist (rounds + finale + per-round overhead), in minutes. */
export function eigenEstimate(list, factor = 1) {
  const n = list.length;
  const finale = n >= 5 ? 5 : 3;
  const fragen = list.reduce((a, r) => a + r.fragen, 0);
  const sec = list.reduce((a, r) => a + r.fragen * (PER_Q[r.id] || 45), 0) + finale * 45 + n * 40 + 120;
  return { min: Math.max(1, Math.round((sec * factor) / 60)), fragen, finale, runden: n };
}
export const EIGEN_PRESETS = [
  { id: "wissen", emoji: "🧠", name: "Wissens-Duell", hint: "Wissen pur · Leiter am Ende", jackpot: true,
    runden: [["bananen-basics", 4], ["bananen-tresor", 4], ["affenleiter", 4], ["taschendieb", 4], ["letzter-affe", 8], ["risiko-leiter", 6]] },
  { id: "party", emoji: "🎉", name: "Party-Mix", hint: "Herde, Bluff, Songs, Torten", jackpot: false,
    runden: [["herdentrieb", 5], ["kokos-kopf", 4], ["bananen-bluff", 4], ["wer-singts", 4], ["stinkbanane", 4], ["bananen-tortenschlacht", 6]] },
  { id: "schnell", emoji: "⚡", name: "Schnelle Runde", hint: "3 Runden · rund 10 Minuten", jackpot: false,
    runden: [["affenzahn", 5], ["bananen-basics", 3], ["affenschaukel", 4]] },
];
const presetList = (p, byId) => p.runden.filter(([id]) => byId[id]).map(([id, fragen]) => ({ id, fragen }));
const sameList = (a, b) => a.length === b.length && a.every((r, i) => r.id === b[i].id && r.fragen === b[i].fragen);
/** Position in the dramaturgy (Blueprints.blueprint(for settings:)): warm-up first, the last round is the risk round. */
const slotHint = (i, n) => (i === 0 ? "Aufwärmen" : i === n - 1 && n >= 3 ? "Risiko-Runde" : "");
const formatIndex = host => Object.fromEntries((host.formate || []).map(f => [f.id, f]));
const EIGEN_KEY = "mm:eigeneShow";
function loadEigen() {
  try { const v = JSON.parse(localStorage.getItem(EIGEN_KEY) || "null"); if (v && Array.isArray(v.playlist)) return { playlist: v.playlist, jackpot: v.jackpot !== false }; } catch (_) {}
  return { playlist: [], jackpot: true };
}
function saveEigen(v) { try { localStorage.setItem(EIGEN_KEY, JSON.stringify(v)); } catch (_) {} }

/**
 * Playlist builder: format library (filter by what the format feeds on), playlist with
 * add / remove / ↑↓ / question stepper, three presets, jackpot switch and a live estimate.
 * Controlled: every change goes out as a settings patch `{eigenePlaylist, eigenerJackpot}`.
 * `players` = head count in the lobby (null on the mode screen → no warnings, only "ab N").
 */
export function EigeneShowPanel({ host, playlist, jackpot, onChange, players = null, factor = 1, wide }) {
  const byId = formatIndex(host);
  const formate = host.formate || [];
  const [art, setArt] = useState("alle");
  const [pulse, setPulse] = useState({ i: -1, k: 0 });
  const list = (playlist || []).filter(r => byId[r.id]);
  const n = list.length, full = n >= EIGEN_MAX;
  const est = eigenEstimate(list, factor);
  const fallback = (host.modes || []).find(m => m.id === "eigen");
  const put = (pl, jp = jackpot) => onChange({ eigenePlaylist: pl.map(r => ({ id: r.id, fragen: r.fragen })), eigenerJackpot: jp });
  const touch = i => setPulse(p => ({ i, k: p.k + 1 }));
  const add = f => { if (full) return; put([...list, { id: f.id, fragen: Math.min(12, Math.max(1, f.fragen || 4)) }]); touch(n); };
  const remove = i => { put(list.filter((_, k) => k !== i)); setPulse(p => ({ i: -1, k: p.k })); };
  const move = (i, d) => { const j = i + d; if (j < 0 || j >= n) return; const nx = list.slice(); [nx[i], nx[j]] = [nx[j], nx[i]]; put(nx); touch(j); };
  const step = (i, d) => { const nx = list.slice(); nx[i] = { ...nx[i], fragen: Math.min(12, Math.max(1, nx[i].fragen + d)) }; put(nx); };
  const counts = {};
  for (const r of list) counts[r.id] = (counts[r.id] || 0) + 1;
  const low = f => players != null && (players < f.minPlayers || players > f.maxPlayers);
  const lowRounds = list.filter(r => low(byId[r.id]));
  const need = Math.max(0, ...lowRounds.map(r => byId[r.id].minPlayers));
  const lib = formate.filter(f => art === "alle" || f.art === art);
  const activePreset = (EIGEN_PRESETS.find(p => sameList(presetList(p, byId), list)) || {}).id;
  const jpPlays = jackpot && (n === 0 || n >= 3);
  return html`<div class=${cx("es", wide && "wide")}>
    <div class="es-presets">
      <span class="es-label">Schnellstart</span>
      ${EIGEN_PRESETS.map(p => html`<button class=${cx("es-preset", activePreset === p.id && "on")} data-preset=${p.id} onClick=${() => { put(presetList(p, byId), p.jackpot); touch(-1); }}>
        <span class="es-p-emo">${p.emoji}</span><span class="es-p-txt"><b>${p.name}</b><small>${p.hint}</small></span></button>`)}
    </div>
    <div class="es-cols">
      <section class="es-lib">
        <div class="es-sec-head">
          <h4>Format-Bibliothek</h4>
          <div class="es-filter">${["alle", "fragen", "songs", "party"].map(a => html`<button class=${cx("es-fchip", art === a && "on", "a-" + a)} data-art=${a} onClick=${() => setArt(a)}>
            ${a === "alle" ? "Alle" : ART[a][0] + " " + ART[a][1]}<small>${a === "alle" ? formate.length : formate.filter(f => f.art === a).length}</small></button>`)}</div>
        </div>
        <div class="es-grid">${lib.map((f, i) => html`<button class=${cx("es-card", "a-" + f.art, counts[f.id] && "in", low(f) && "low")} key=${f.id} data-format=${f.id} disabled=${full} title=${f.kurz}
            style=${`animation-delay:${Math.min(i, 12) * 25}ms`} onClick=${() => add(f)}>
          <span class="es-c-emo">${f.emoji}</span>
          <span class="es-c-txt"><b>${f.name}</b><small>${f.kurz}</small>
            <span class="es-c-tags"><i class=${"es-art a-" + f.art}>${ART[f.art] ? ART[f.art][1] : f.art}</i><i class="es-q">${f.fragen} Fragen</i>${(f.minPlayers > 2 || low(f)) && html`<i class=${cx("es-min", low(f) && "bad")} title=${`ab ${f.minPlayers} Spielern`}>ab ${f.minPlayers} Sp.</i>`}</span></span>
          ${counts[f.id] > 0 && html`<span class="es-c-in" key=${counts[f.id]}>${counts[f.id]}×</span>`}
          <span class="es-c-add">+</span>
        </button>`)}</div>
      </section>
      <section class="es-pl">
        <div class="es-sec-head">
          <h4>Deine Playlist <span class=${cx("es-count", full && "full")}><b key=${n}>${n}</b>/${EIGEN_MAX}</span></h4>
          <button class=${cx("es-jp", jackpot && "on", n > 0 && n < 3 && "idle")} data-jackpot onClick=${() => put(list, !jackpot)} title="Jackpot-Frage vor dem Finale (ab 3 Runden)">
            <span>🫙 Jackpot</span><i></i></button>
        </div>
        ${lowRounds.length > 0 && html`<div class="es-warnbar">⚠️ ${lowRounds.length === 1 ? "1 Runde braucht" : lowRounds.length + " Runden brauchen"} mind. ${need} Spieler — ihr seid ${players}.</div>`}
        ${n === 0 ? html`<div class="es-empty"><span>🛠️</span><b>Noch leer</b><p>Tippe links Formate an oder nimm oben ein Preset.<br />Ohne Auswahl läuft die Klassik-Playlist.</p></div>`
          : html`<ol class="es-rows">${list.map((r, i) => {
            const f = byId[r.id];
            const hint = slotHint(i, n);
            return html`<li class=${cx("es-row", low(f) && "warn", pulse.i === i && "pulse")} key=${i + "-" + r.id + (pulse.i === i ? "-" + pulse.k : "")}>
              <span class="es-r-n">${i + 1}</span>
              <span class="es-r-emo">${f.emoji}</span>
              <span class="es-r-name"><b>${f.name}</b>${low(f) ? html`<small class="es-r-warn">⚠️ ab ${f.minPlayers} Spielern</small>` : hint && html`<small>${hint}</small>`}</span>
              <span class="es-step"><button class="es-sb" aria-label="Weniger Fragen" disabled=${r.fragen <= 1} onClick=${() => step(i, -1)}>−</button><b key=${r.fragen}>${r.fragen}</b><button class="es-sb" aria-label="Mehr Fragen" disabled=${r.fragen >= 12} onClick=${() => step(i, 1)}>+</button></span>
              <span class="es-move"><button aria-label="Nach oben" disabled=${i === 0} onClick=${() => move(i, -1)}>↑</button><button aria-label="Nach unten" disabled=${i === n - 1} onClick=${() => move(i, 1)}>↓</button></span>
              <button class="es-del" aria-label="Entfernen" onClick=${() => remove(i)}>×</button>
            </li>`;
          })}</ol>`}
        <div class="es-est">
          <span class="es-est-min"><b key=${n ? est.min : "k"}>~${n ? est.min : Math.round(((fallback && fallback.minuten) || 27) * factor)}</b><small>min</small></span>
          <span class="es-est-txt"><span>${n ? html`<b>${n} ${n === 1 ? "Runde" : "Runden"}</b> · ${est.fragen} Fragen + Finale (${est.finale})` : html`<b>Klassik-Playlist</b> · 6 Runden + Finale`}</span>
            <small>${jpPlays ? "🫙 mit Jackpot-Frage" : jackpot ? "🫙 Jackpot erst ab 3 Runden" : "ohne Jackpot"}${full ? " · Playlist voll" : ""}</small></span>
        </div>
      </section>
    </div>
  </div>`;
}

/** Full-screen builder over lobby / drawer: edits go live to the room (settings patch). */
export function EigenOverlay({ host, settings, players, close }) {
  const fromServer = () => ({ playlist: settings.eigenePlaylist || [], jackpot: settings.eigenerJackpot !== false });
  const [local, setLocal] = useState(fromServer);
  const quiet = useRef(0);
  const serverKey = JSON.stringify([settings.eigenePlaylist || [], settings.eigenerJackpot]);
  // Echoes of our own patches arrive a moment later — only adopt server state once we're idle.
  useEffect(() => { if (Date.now() > quiet.current) setLocal(fromServer()); }, [serverKey]);
  const change = patch => {
    quiet.current = Date.now() + 800;
    const v = { playlist: patch.eigenePlaylist, jackpot: patch.eigenerJackpot };
    setLocal(v);
    saveEigen(v);
    StageCtx.cmd({ settingsSet: { _0: patch } });
  };
  return html`<div class="kt-overlay es-overlay" onClick=${e => e.stopPropagation()}>
    <header>
      <div><h2>🛠️ Eigene Show bauen</h2><p>Änderungen gelten sofort für diese Lobby — bis zu ${EIGEN_MAX} Runden, 1–12 Fragen pro Runde.</p></div>
      <button class="btn green kt-done" onClick=${close}>✔ Fertig</button>
    </header>
    <div class="kt-overlay-body"><${EigeneShowPanel} host=${host} playlist=${local.playlist} jackpot=${local.jackpot} onChange=${change} players=${players} factor=${tempoFactor(settings)} wide /></div>
  </div>`;
}

/** Compact playlist summary for the lobby's show card. */
function EigenSummary({ host, s, players, onEdit }) {
  const byId = formatIndex(host);
  const list = (s.eigenePlaylist || []).filter(r => byId[r.id]);
  const est = eigenEstimate(list, tempoFactor(s));
  const low = list.filter(r => players < byId[r.id].minPlayers);
  return html`<div class="es-mini">
    ${list.length ? html`<ol class="es-mini-list">${list.map((r, i) => html`<li class=${cx(players < byId[r.id].minPlayers && "warn")}><i>${i + 1}</i><span>${byId[r.id].emoji} ${byId[r.id].name}</span><small>${r.fragen}</small></li>`)}</ol>`
      : html`<p class="muted small">Noch keine eigene Playlist — es läuft die Klassik-Playlist.</p>`}
    <div class="es-mini-meta">${list.length ? html`<b>~${est.min} min</b> · ${list.length} Runden · ${est.fragen} Fragen` : html`<b>6 Runden</b> · Klassik`}${s.eigenerJackpot && (list.length === 0 || list.length >= 3) ? " · 🫙 Jackpot" : ""}</div>
    ${low.length > 0 && html`<p class="es-mini-warn">⚠️ ${low.length} ${low.length === 1 ? "Runde braucht" : "Runden brauchen"} mehr Spieler</p>`}
    <button class="btn violet small block es-edit" onClick=${onEdit}>🛠️ Playlist bauen</button>
  </div>`;
}

function ModeCard({ m, i, on, pick, eigen, host }) {
  const [emoji, accent] = modeArt(m);
  let min = m.minuten, runden = `${m.runden} Runden`, jackpot = m.jackpot, formats = m.formate || [];
  if (m.id === "eigen") {
    if (eigen.list.length) { min = eigen.est.min; runden = `${eigen.list.length} Runden`; jackpot = eigen.jackpot && eigen.list.length >= 3; formats = eigen.names; }
    else { min = null; runden = "1–12 Runden"; formats = ["✨ 3 Presets", `🎛️ ${(host.formate || []).length} Formate`, "🔢 1–12 Fragen"]; }
  }
  const shown = formats.slice(0, formats.length > 4 ? 3 : 4);
  const more = formats.length - shown.length;
  return html`<button class=${cx("mode-card", on && "on")} data-mode=${m.id} title=${m.subtitle} style=${`--accent:${accent};animation-delay:${i * 70}ms`} onClick=${() => pick(m.id)}>
    <span class="mc-top"><span class="mode-emoji">${emoji}</span><h2>${m.title}</h2></span>
    <p class="mc-tag">${MODE_TAG[m.id] || m.subtitle}</p>
    <span class="mc-meta">
      <span class="mc-b mc-min">${min != null ? `~${min} min` : "frei wählbar"}</span>
      <span class="mc-b">${runden}</span>
      ${jackpot && html`<span class="mc-b jp">🫙 Jackpot</span>`}
    </span>
    <span class="mc-formats">${shown.map(f => html`<span class="mc-f">${f}</span>`)}${more > 0 && html`<span class="mc-f more">+${more}</span>`}</span>
    ${on && html`<span class="mode-check">✔️</span>`}
  </button>`;
}

export function ModeScreen({ host, back }) {
  const [modus, setModus] = useState("klassik");
  const [set, setSet] = useState(host.defaults[modus].fragenSet);
  const [tempo, setTempo] = useState("normal");
  const [familie, setFamilie] = useState(false);
  const [filt, setFilt] = useState(filterOf(null));
  const [katOpen, setKatOpen] = useState(false);
  const [eigen, setEigen] = useState(loadEigen);
  const league = !!host.edition;
  const eigenOn = modus === "eigen";
  const byId = formatIndex(host);
  const eList = eigen.playlist.filter(r => byId[r.id]);
  const factor = tempoFactor({ tempo, familienModus: familie });
  const eigenInfo = { list: eList, jackpot: eigen.jackpot, est: eigenEstimate(eList, factor), names: eList.map(r => `${byId[r.id].emoji} ${byId[r.id].name}`) };
  const changeEigen = patch => { const v = { playlist: patch.eigenePlaylist, jackpot: patch.eigenerJackpot }; setEigen(v); saveEigen(v); };
  const start = () => {
    const patch = { fragenSet: set, tempo, familienModus: familie };
    for (const [k, v] of Object.entries(filt)) if (v.length) patch[k] = v;
    if (eigenOn) { patch.eigenePlaylist = eList; patch.eigenerJackpot = eigen.jackpot; }
    return hostCall("/api/host/start", { modus, patch });
  };
  const options = html`<div class=${cx("mode-options card", eigenOn && "side")}>
      ${!league && html`<div class="opt-block"><h4>Fragen-Set</h4><div class="chip-row">${host.questionSets.filter(q => q.id !== "eigen").map(q => html`
        <button class=${cx("pick", set === q.id && "on")} onClick=${() => setSet(q.id)}>${q.emoji} ${q.name} <small>${fmtNum(q.anzahl)}</small></button>`)}</div></div>`}
      <div class="opt-inline">
        <div class="opt-block"><h4>Tempo</h4><div class="seg">${host.tempos.map(t => html`<button class=${cx(tempo === t.id && "on")} onClick=${() => setTempo(t.id)}>${t.label}</button>`)}</div></div>
        <div class="opt-block"><h4>Publikum</h4><div class="seg"><button class=${cx(!familie && "on")} onClick=${() => setFamilie(false)}>🍻 Erwachsene</button><button class=${cx(familie && "on")} onClick=${() => setFamilie(true)}>👨‍👩‍👧 Familie & Kinder</button></div></div>
        <${KatalogEntry} katalog=${host.katalog} settings=${filt} onOpen=${() => setKatOpen(true)} />
      </div>
    </div>`;
  return html`<div class=${cx("modes", eigenOn && "eigen-on")}>
    <header class="screen-head"><button class="btn ghost small" onClick=${back}>‹ Zurück</button><h1>${eigenOn ? "🛠️ Deine eigene Show" : "Welche Show heute?"}</h1><span></span></header>
    <div class="mode-cards" style=${`--n:${host.modes.length}`}>
      ${host.modes.map((m, i) => html`<${ModeCard} key=${m.id} m=${m} i=${i} on=${modus === m.id} pick=${setModus} eigen=${eigenInfo} host=${host} />`)}
    </div>
    ${eigenOn ? html`<div class="mode-eigen">
        <div class="card es-host"><${EigeneShowPanel} host=${host} playlist=${eList} jackpot=${eigen.jackpot} onChange=${changeEigen} factor=${factor} /></div>
        ${options}
      </div>` : options}
    <div class="mode-go"><button class="btn big" onClick=${start}>🚪 Lobby öffnen</button><p class="muted">${eigenOn ? (eList.length ? `${eList.length} Runden · ~${eigenInfo.est.min} min — alles bleibt in der Lobby änderbar.` : "Ohne eigene Playlist läuft die Klassik-Show — du kannst sie in der Lobby noch bauen.") : "Alles andere (Teams, Joker, Timer, Special Rules …) stellst du in der Lobby ein."}</p></div>
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
  const [esOpen, setEsOpen] = useState(false);
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
        <div class=${cx("card show-card", !spieleabend && "m-" + s.modus)}>
          <h3>${spieleabend ? "🎲 Spiele-Abend" : modeLabel(host, s.modus)}</h3>
          ${!spieleabend && s.modus === "eigen" && html`<${EigenSummary} host=${host} s=${s} players=${players.length} onEdit=${() => setEsOpen(true)} />`}
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
    ${esOpen && s.modus === "eigen" && html`<${EigenOverlay} host=${host} settings=${s} players=${players.length} close=${() => setEsOpen(false)} />`}
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
  const [esOpen, setEsOpen] = useState(false);
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
          ${s.modus === "eigen" && html`<button class="kt-entry es-entry" onClick=${() => setEsOpen(true)}>
            <span class="kt-entry-ico">🛠️</span>
            <span class="kt-entry-txt"><b>Playlist bauen</b><small>${(s.eigenePlaylist || []).length ? `${s.eigenePlaylist.length} Runden · ~${eigenEstimate(s.eigenePlaylist, tempoFactor(s)).min} min` : "Noch leer — es läuft die Klassik-Playlist"}</small></span>
            <span class="kt-entry-go">›</span>
          </button>`}
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
    ${esOpen && inLobby && s.modus === "eigen" && html`<${EigenOverlay} host=${host} settings=${s} players=${view.players.length} close=${() => setEsOpen(false)} />`}
  </div>`;
}
