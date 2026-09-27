// Monkey Money — the stage (what the iPad shows). Connects as the `screen`
// role, renders the StageView, drives the host (menu, lobby, saves) through
// /api/host/* and directs the sound.
import { html, render, useState, useEffect, useRef, useCallback } from "../vendor/preact-htm.js";
import { connect, decode, api, cx, fmtMM, serverNow } from "../lib/core.js";
import { audio } from "../lib/audio.js";
import { Monkey, Money, Confetti } from "../lib/ui.js";
import { Regie } from "./regie.js";
import { StageCtx } from "./ctx.js";
import { MenuScreen, ModeScreen, SavesScreen, BoardsScreen, HowtoScreen, LobbyScene, SettingsDrawer } from "./host.js";
import { SceneView, Podium, sceneWantsPodium } from "./scenes.js";

const regie = new Regie();

// ---------- canvas scaling: fixed 1000-unit height, width follows the screen ----------
function useCanvas() {
  const calc = () => {
    const vw = window.innerWidth, vh = window.innerHeight;
    const W = Math.round(Math.min(1800, Math.max(1400, (1000 * vw) / vh)));
    const scale = Math.min(vh / 1000, vw / W);
    return { W, scale };
  };
  const [c, setC] = useState(calc());
  useEffect(() => {
    const on = () => setC(calc());
    window.addEventListener("resize", on);
    return () => window.removeEventListener("resize", on);
  }, []);
  return c;
}

function useAudioState() {
  const [, force] = useState(0);
  useEffect(() => audio.onChange(() => force(x => x + 1)), []);
  return audio;
}


function App() {
  const { W, scale } = useCanvas();
  const [host, setHost] = useState(null);
  const [view, setView] = useState(null);
  const [online, setOnline] = useState(false);
  const [screen, setScreen] = useState("menu"); // menu | modes | saves | boards | howto (when no show)
  const [drawer, setDrawer] = useState(false);
  const [toast, setToast] = useState(null);
  const [ask, setAsk] = useState(null);
  const conn = useRef(null);
  useAudioState();

  const refreshHost = useCallback(async () => {
    try { const s = await api("/api/host/state"); setHost(s); return s; } catch (e) { return null; }
  }, []);

  useEffect(() => {
    refreshHost();
    const id = setInterval(refreshHost, 3000);
    conn.current = connect({
      hello: () => ({ t: "hello", roomCode: "", role: "screen" }),
      onStatus: ok => { setOnline(ok); if (ok) refreshHost(); },
      onMessage: msg => {
        if (msg.t === "stage") setView(msg.view);
        else if (msg.t === "error") showToast("⚠️ " + msg.message);
      },
    });
    const unlock = () => { if (!audio.unlocked) audio.unlock(); };
    window.addEventListener("pointerdown", unlock, true);
    window.addEventListener("keydown", unlock, true);
    return () => { clearInterval(id); window.removeEventListener("pointerdown", unlock, true); };
  }, []);

  let toastTimer = useRef();
  function showToast(t) { setToast(t); clearTimeout(toastTimer.current); toastTimer.current = setTimeout(() => setToast(null), 2600); }

  const cmd = c => conn.current && conn.current.send({ t: "gm", cmd: c });
  StageCtx.cmd = cmd;
  StageCtx.host = host;
  StageCtx.refreshHost = refreshHost;
  StageCtx.toast = showToast;
  StageCtx.openDrawer = () => setDrawer(true);
  StageCtx.ask = (text, yes) => setAsk({ text, yes });

  const active = host && host.active;
  const inShow = active && view && view.roomCode === host.roomCode;

  // Sound direction follows the stage view; the menu has its own theme.
  useEffect(() => {
    if (inShow) regie.update(view, view && decodeMusic(view));
    else { regie.reset(); audio.playMusic(active ? null : "theme_main"); }
  }, [view, inShow, active]);
  const wasActive = useRef(false);
  useEffect(() => { if (wasActive.current && !active) setScreen("menu"); wasActive.current = !!active; }, [active]);

  // Keyboard: space/→ advances (handy on a laptop), P pauses.
  useEffect(() => {
    const on = e => {
      if (!inShow || e.target.tagName === "INPUT") return;
      if ((e.key === " " || e.key === "ArrowRight") && view.canAdvance) { e.preventDefault(); cmd({ flowNext: {} }); }
      if (e.key === "p") cmd(view.paused ? { resume: {} } : { pause: { text: null, dauerMs: null } });
    };
    window.addEventListener("keydown", on);
    return () => window.removeEventListener("keydown", on);
  }, [inShow, view]);

  let body;
  if (!host) body = html`<div class="boot"><div class="boot-logo">🐵</div><p>Bühne wird aufgebaut …</p></div>`;
  else if (!active) {
    const go = s => setScreen(s);
    body = screen === "modes" ? html`<${ModeScreen} host=${host} back=${() => go("menu")} />`
      : screen === "saves" ? html`<${SavesScreen} host=${host} back=${() => go("menu")} />`
      : screen === "boards" ? html`<${BoardsScreen} back=${() => go("menu")} />`
      : screen === "howto" ? html`<${HowtoScreen} back=${() => go("menu")} />`
      : html`<${MenuScreen} host=${host} go=${go} />`;
  } else if (!inShow) body = html`<div class="boot"><div class="boot-logo spin">🍌</div><p>Verbinde mit dem Raum …</p></div>`;
  else body = html`<${ShowLayout} view=${view} host=${host} />`;

  return html`
    <div class="backdrop ${inShow ? "phase-" + view.phase : "phase-menu"}">
      <div class="beam b1"></div><div class="beam b2"></div><div class="beam b3"></div>
      <div class="leaves l"></div><div class="leaves r"></div>
      <div class="floor"></div>
    </div>
    <div class="canvas" style=${`width:${W}px;transform:translate(-50%,-50%) scale(${scale})`}>
      ${body}
      ${inShow && drawer && html`<${SettingsDrawer} view=${view} host=${host} close=${() => setDrawer(false)} />`}
      ${!audio.unlocked && html`<button class="sound-unlock" onClick=${() => audio.unlock()}>🔊 Tippen für Ton</button>`}
      ${!online && host && html`<div class="offline">Verbindung zum Server wird wiederhergestellt …</div>`}
      ${toast && html`<div class="stage-toast pop-in">${toast}</div>`}
      ${ask && html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && setAsk(null)}><div class="sheet ask card pop-in">
        <h2>${ask.text}</h2>
        <div class="menu-row"><button class="btn red" onClick=${() => { const y = ask.yes; setAsk(null); y(); }}>Ja</button><button class="btn ghost" onClick=${() => setAsk(null)}>Abbrechen</button></div>
      </div></div>`}
    </div>`;
}

function decodeMusic(view) {
  const s = decode(view.scene);
  if (s.kind === "lobby") return s.settings ? s.settings.musik !== false : true;
  return true;
}

// ---------- match layout: top bar, scene, podium, controls ----------
function ShowLayout({ view, host }) {
  const scene = decode(view.scene);
  const podium = sceneWantsPodium(scene);
  return html`
    <div class=${cx("show", "scene-" + scene.kind, podium && "with-podium")}>
      ${scene.kind !== "lobby" && html`<${TopBar} view=${view} host=${host} />`}
      <main class="stage-main">
        ${scene.kind === "lobby" ? html`<${LobbyScene} view=${view} lobby=${scene} host=${host} />` : html`<${SceneView} view=${view} scene=${scene} key=${sceneKey(view, scene)} />`}
      </main>
      ${podium && html`<${Podium} view=${view} scene=${scene} />`}
      <${Moments} view=${view} />
      ${view.paused && scene.kind !== "pause" && html`<div class="paused-veil"><div class="card pop-in"><h2>⏸ Pause</h2><p class="muted">Gleich geht's weiter …</p></div></div>`}
    </div>`;
}

function sceneKey(view, scene) {
  if (scene.kind === "frage" || scene.kind === "aufloesung") return "q-" + (scene.wall ? scene.wall.nummer + scene.wall.text.slice(0, 12) : scene.minigameId) + scene.kind;
  return scene.kind;
}

function TopBar({ view, host }) {
  const code = view.roomCode;
  const hostPart = (host.baseURL || "").replace(/^https?:\/\//, "");
  return html`
    <header class="topbar">
      <div class="top-left">
        <div class="brand"><span class="brand-mark">🐵</span><div><span class="brand-word">MONKEY<b>MONEY</b></span><small class="join-line">📱 ${hostPart}/j/<b>${code}</b></small></div>${host.edition && html`<span class="chip gold">${host.edition}</span>`}</div>
        ${view.jackpotAktiv && html`<div class="jar" title="Jackpot-Glas"><span class="jar-ico">🫙</span><div><small>Jackpot</small><${Money} value=${view.jackpotGlas} /></div></div>`}
      </div>
      <div class="section">
        <div class="section-label">${view.sectionLabel}</div>
        <div class="progress"><i style=${`width:${Math.round((view.progress || 0) * 100)}%`}></i></div>
      </div>
      <div class="top-right">
        <${Controls} view=${view} />
      </div>
    </header>`;
}

function Controls({ view }) {
  const cmd = StageCtx.cmd;
  const showNext = view.canAdvance && (view.gmLos || !view.gmOnline);
  return html`<div class="controls">
      ${view.gmOnline && html`<span class="chip green">🎬 Regie</span>`}
      <button class="icon-btn" title=${view.paused ? "Weiter" : "Pause"} onClick=${() => cmd(view.paused ? { resume: {} } : { pause: { text: null, dauerMs: null } })}>${view.paused ? "▶️" : "⏸"}</button>
      <button class="icon-btn" title="Einstellungen" onClick=${() => StageCtx.openDrawer()}>⚙️</button>
      ${showNext && html`<button class="btn next-btn" key=${view.advanceLabel} onClick=${() => cmd({ flowNext: {} })}>${view.advanceLabel || "Weiter"} <span>▶</span></button>`}
    </div>`;
}

/** Banner ticker for fresh moments (joker, steal, bonus …). */
function Moments({ view }) {
  const [shown, setShown] = useState([]);
  const lastId = useRef(null);
  useEffect(() => {
    const ms = view.moments || [];
    if (lastId.current === null) { lastId.current = ms.length ? ms[ms.length - 1].id : 0; return; }
    const fresh = ms.filter(m => m.id > lastId.current && m.art !== "sound" && m.art !== "join");
    if (!ms.length) return;
    lastId.current = Math.max(lastId.current, ms[ms.length - 1].id);
    if (!fresh.length) return;
    setShown(s => [...s, ...fresh.map(m => ({ ...m, until: Date.now() + 4200 }))].slice(-3));
  }, [view.moments]);
  useEffect(() => {
    if (!shown.length) return;
    const t = setTimeout(() => setShown(s => s.filter(m => m.until > Date.now())), 600);
    return () => clearTimeout(t);
  }, [shown]);
  const players = Object.fromEntries(view.players.map(p => [p.id, p]));
  return html`<div class="moments">${shown.map(m => html`
    <div class=${cx("moment", "art-" + m.art)} key=${m.id}>
      ${m.playerId && players[m.playerId] ? html`<${Monkey} wire=${players[m.playerId].avatar} face="jubel" anim="none" size=${44} />` : html`<span class="m-ico">${momentIcon(m.art)}</span>`}
      <span>${m.text}</span>
      ${m.betrag != null && m.betrag !== 0 && html`<b class=${m.betrag > 0 ? "pos" : "neg"}>${m.betrag > 0 ? "+" : ""}${fmtMM(m.betrag)}</b>`}
    </div>`)}</div>`;
}

function momentIcon(art) {
  return { join: "👋", joker: "🃏", steuer: "🧾", jackpot: "🫙", kategorie: "🗂️", regie: "🎬", pranger: "🍅", finale: "🐊", rad: "🎡", pause: "⏸", tipp: "💡", streik: "✊", geier: "🦅", boost: "🚀", rueckenwind: "🌬️", ultrahard: "🧠", shake: "🥥", bank: "🏦" }[art] || "✨";
}

render(html`<${App} />`, document.getElementById("app"));
