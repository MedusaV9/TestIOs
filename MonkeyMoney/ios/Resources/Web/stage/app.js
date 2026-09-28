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
import { SceneView, Podium, sceneWantsPodium, revealStart } from "./scenes.js";
import { SceneSwitch } from "./fx.js";
import { REVEAL_BEAT } from "./regie.js";

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
  const backdrop = useRef(null);
  useAudioState();
  // Subtle jungle parallax: pointer position → two CSS variables (rAF-throttled, transform-only layers).
  useEffect(() => {
    let raf = 0, px = 0, py = 0;
    const on = e => {
      px = (e.clientX / window.innerWidth) * 2 - 1; py = (e.clientY / window.innerHeight) * 2 - 1;
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        const b = backdrop.current;
        if (b) { b.style.setProperty("--px", px.toFixed(3)); b.style.setProperty("--py", py.toFixed(3)); }
      });
    };
    window.addEventListener("pointermove", on, { passive: true });
    return () => { window.removeEventListener("pointermove", on); if (raf) cancelAnimationFrame(raf); };
  }, []);

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

  const sc = inShow ? decode(view.scene) : null;
  const sk = sc && sc.sectionKind && sc.sectionKind !== "runde" ? "sk-" + sc.sectionKind : "";
  const menuish = !inShow || (sc && sc.kind === "lobby");
  return html`
    <div class=${cx("backdrop", inShow ? "phase-" + view.phase : "phase-menu", sk, menuish && "jungle-on")} ref=${backdrop}>
      <div class="tint t-gold"></div><div class="tint t-red"></div><div class="tint t-wheel"></div><div class="tint t-spot"></div>
      <div class="beam b1"></div><div class="beam b2"></div><div class="beam b3"></div>
      <${Jungle} />
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

// ---------- jungle parallax (menu + lobby): three static SVG layers, moved only by transforms ----------
const frond = (x, y, r, len, fill) => {
  const w = len * 0.22;
  return `<g transform="translate(${x},${y}) rotate(${r})"><path d="M0,0 C${len * 0.25},${-w} ${len * 0.75},${-w} ${len},0 C${len * 0.75},${w} ${len * 0.25},${w} 0,0Z" fill="${fill}"/><path d="M0,0 L${len},0" stroke="rgba(0,0,0,.28)" stroke-width="3"/></g>`;
};
const cluster = (x, y, base, n, len, fills, flip = 1) => Array.from({ length: n }, (_, i) => frond(x, y, flip * (base + i * (70 / n)) + (flip < 0 ? 180 : 0), len * (0.8 + ((i * 37) % 10) / 25), fills[i % fills.length])).join("");
const vine = (x, len, sway, fill) => {
  let s = `<path d="M${x},-10 C${x + sway},${len * 0.35} ${x - sway},${len * 0.65} ${x + sway * 0.4},${len}" fill="none" stroke="${fill}" stroke-width="7" stroke-linecap="round"/>`;
  for (let k = 1; k < 6; k++) { const yy = (len / 6) * k, xx = x + Math.sin(k * 1.7) * sway * 0.5; s += frond(xx, yy, k % 2 ? 30 : 150, 46, fill); }
  return s;
};
const svgLayer = inner => `<svg viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid slice" aria-hidden="true">${inner}</svg>`;
const JUNGLE = {
  far: svgLayer(cluster(-40, 1040, -80, 7, 520, ["#0a2f2a", "#0c3a31"]) + cluster(1640, 1040, -80, 7, 520, ["#0a2f2a", "#0c3a31"], -1) + cluster(800, 1100, -130, 9, 360, ["#0a2a27"])),
  mid: svgLayer(cluster(-20, -40, 10, 6, 380, ["#0f4a3c", "#0d5a45"]) + cluster(1620, -40, 10, 6, 380, ["#0f4a3c", "#0d5a45"], -1)),
  near: svgLayer(vine(120, 420, 30, "#12664f") + vine(300, 260, 22, "#0f5a46") + vine(1320, 300, 26, "#0f5a46") + vine(1480, 460, 30, "#12664f")),
};
function Jungle() {
  return html`<div class="jungle" aria-hidden="true">
    <div class="j-layer j-far"><div class="j-drift" dangerouslySetInnerHTML=${{ __html: JUNGLE.far }}></div></div>
    <div class="j-layer j-mid"><div class="j-drift" dangerouslySetInnerHTML=${{ __html: JUNGLE.mid }}></div></div>
    <div class="j-layer j-near"><div class="j-drift" dangerouslySetInnerHTML=${{ __html: JUNGLE.near }}></div></div>
    <div class="fireflies">${Array.from({ length: 14 }, (_, i) => html`<i style=${`left:${(i * 73) % 100}%;top:${20 + ((i * 41) % 60)}%;animation-delay:${-i * 0.9}s;animation-duration:${7 + (i % 5)}s`}></i>`)}</div>
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
  const n = view.players.length;
  return html`
    <div class=${cx("show", "scene-" + scene.kind, podium && "with-podium", n > 6 ? "crowd-l" : n <= 3 ? "crowd-s" : "crowd-m")}>
      ${scene.kind !== "lobby" && html`<${TopBar} view=${view} host=${host} />`}
      <main class="stage-main">
        <${SceneSwitch} k=${sceneKey(view, scene)} kind=${scene.kind} data=${{ view, scene, host }} render=${renderScene} />
      </main>
      ${podium && html`<${Podium} view=${view} scene=${scene} />`}
      <${Moments} view=${view} />
      ${view.paused && scene.kind !== "pause" && html`<div class="paused-veil"><div class="card pop-in"><h2>⏸ Pause</h2><p class="muted">Gleich geht's weiter …</p></div></div>`}
    </div>`;
}

function renderScene({ view, scene, host }) {
  return scene.kind === "lobby" ? html`<${LobbyScene} view=${view} lobby=${scene} host=${host} />` : html`<${SceneView} view=${view} scene=${scene} />`;
}

/** Same key → the scene morphs in place (frage → aufloesung of one question). */
function sceneKey(view, scene) {
  if (scene.kind === "frage" || scene.kind === "aufloesung") return "q-" + scene.minigameId + "-" + (scene.wall ? scene.wall.nummer + scene.wall.text.slice(0, 16) : "");
  return scene.kind;
}

function TopBar({ view, host }) {
  const code = view.roomCode;
  const hostPart = (host.baseURL || "").replace(/^https?:\/\//, "");
  const pct = Math.round((view.progress || 0) * 100);
  return html`
    <header class="topbar">
      <div class="top-left">
        <div class="brand"><span class="brand-mark">🐵</span><div><span class="brand-word">MONKEY<b>MONEY</b></span><small class="join-line">📱 ${hostPart}/j/<b>${code}</b></small></div>${host.edition && html`<span class="chip gold">${host.edition}</span>`}</div>
        ${view.jackpotAktiv && html`<div class="jar" title="Jackpot-Glas"><span class="jar-ico">🫙</span><div><small>Jackpot</small><${Money} value=${view.jackpotGlas} /></div></div>`}
      </div>
      <div class="section">
        <div class="section-label" key=${view.sectionLabel}>${view.sectionLabel}</div>
        <div class="progress"><i style=${`transform:scaleX(${pct / 100})`}></i><b style=${`left:${pct}%`}></b></div>
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

/** Banner ticker for fresh moments (joker, steal, bonus …). During a reveal they wait until the answer is out. */
function Moments({ view }) {
  const [shown, setShown] = useState([]);
  const [tick, setTick] = useState(0);
  const lastId = useRef(null);
  useEffect(() => {
    const ms = view.moments || [];
    if (lastId.current === null) { lastId.current = ms.length ? ms[ms.length - 1].id : 0; return; }
    const fresh = ms.filter(m => m.id > lastId.current && m.art !== "sound" && m.art !== "join");
    if (!ms.length) return;
    lastId.current = Math.max(lastId.current, ms[ms.length - 1].id);
    if (!fresh.length) return;
    const sc = decode(view.scene);
    let wait = 0;
    if (sc.kind === "aufloesung") wait = Math.max(0, revealStart(sc) + REVEAL_BEAT.moments - serverNow());
    const now = Date.now();
    setShown(s => [...s, ...fresh.map((m, i) => ({ ...m, from: now + wait + i * 350, until: now + wait + i * 350 + 4200 }))].slice(-4));
  }, [view.moments]);
  useEffect(() => {
    if (!shown.length) return;
    const now = Date.now();
    let next = Infinity;
    for (const m of shown) { if (m.from > now) next = Math.min(next, m.from); if (m.until > now) next = Math.min(next, m.until); }
    const t = setTimeout(() => { setShown(s => s.filter(m => m.until > Date.now())); setTick(x => x + 1); }, Math.max(40, (next === Infinity ? 600 : next - now) + 20));
    return () => clearTimeout(t);
  }, [shown, tick]);
  const players = Object.fromEntries(view.players.map(p => [p.id, p]));
  const now = Date.now();
  const visible = shown.filter(m => m.from <= now).slice(-3);
  return html`<div class="moments">${visible.map(m => html`
    <div class=${cx("moment", "art-" + m.art)} key=${m.id}>
      ${m.playerId && players[m.playerId] ? html`<${Monkey} wire=${players[m.playerId].avatar} face="jubel" anim="none" size=${44} />` : html`<span class="m-ico">${momentIcon(m.art)}</span>`}
      <span>${m.text}</span>
      ${m.betrag != null && m.betrag !== 0 && html`<b class=${m.betrag > 0 ? "pos" : "neg"}>${m.betrag > 0 ? "+" : ""}${fmtMM(m.betrag)}</b>`}
    </div>`)}</div>`;
}

function momentIcon(art) {
  return { join: "👋", joker: "🃏", steuer: "🧾", jackpot: "🫙", kategorie: "🗂️", regie: "🎬", pranger: "🍅", finale: "🐊", rad: "🎡", pause: "⏸", tipp: "💡", streik: "✊", geier: "🦅", boost: "🚀", rueckenwind: "🌬️", ultrahard: "🧠", shake: "🥥", bank: "🏦", serie: "🔥", schnell: "⚡", fuehrung: "👑", money: "💸" }[art] || "✨";
}

render(html`<${App} />`, document.getElementById("app"));
