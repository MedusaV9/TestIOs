// Monkey Money — the phone controller (browser). Join, then render whatever
// the engine prompts, with jokers, the jackpot jar and whispers.
import { html, render, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { connect, decode, api, cx, fmtMM, fmtNum, deviceToken, haptic, MONKEYS, COLORS } from "../lib/core.js";
import { Monkey, Money } from "../lib/ui.js";
import { Prompt } from "../lib/prompts.js";

const codeFromUrl = ((location.pathname.match(/\/j\/([A-Za-z]{4})/) || [])[1] || new URLSearchParams(location.search).get("code") || "").toUpperCase();
const load = (k, d) => { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch (_) { return d; } };

function App() {
  const [session, setSession] = useState(() => { const s = load("mm:session", null); return s && s.code === codeFromUrl ? s : null; });
  const [joining, setJoining] = useState(!!session);
  const [error, setError] = useState(null);
  const [view, setView] = useState(null);
  const [online, setOnline] = useState(true);
  const [toast, setToast] = useState(null);
  const [edition, setEdition] = useState("");
  const conn = useRef(null);
  const hello = useRef(session ? { t: "hello", roomCode: session.code, role: "player", sessionToken: session.token, name: load("mm:name", ""), avatar: load("mm:look", {}).wire } : null);
  const toastT = useRef();
  const say = t => { setToast(t); clearTimeout(toastT.current); toastT.current = setTimeout(() => setToast(null), 2800); };

  useEffect(() => { api("/api/room").then(r => { if (r && r.edition) { setEdition(r.edition); document.title = "Monkey Money " + r.edition; } }).catch(() => {}); }, []);

  const start = payload => {
    hello.current = payload;
    setJoining(true);
    setError(null);
    if (conn.current) { conn.current.reconnect(); return; }
    conn.current = connect({
      hello: () => hello.current,
      onStatus: setOnline,
      onMessage: msg => {
        if (msg.t === "welcome") {
          const s = { code: hello.current.roomCode.toUpperCase(), token: msg.sessionToken };
          localStorage.setItem("mm:session", JSON.stringify(s));
          hello.current = { ...hello.current, sessionToken: msg.sessionToken };
          setSession(s);
        } else if (msg.t === "player") setView(msg.view);
        else if (msg.t === "error") {
          if (["room", "no-session", "full", "profile"].includes(msg.code)) { localStorage.removeItem("mm:session"); setSession(null); setView(null); setJoining(false); conn.current && conn.current.close(); conn.current = null; }
          setError(msg.message);
        } else if (msg.t === "closed") { say("Der Raum wurde geschlossen."); localStorage.removeItem("mm:session"); }
        else if (msg.t === "profileEvent") { const e = msg.event; say(`+${e.atDelta} AT${e.levelUp ? ` · LEVEL ${e.level}!` : ""}${e.quests.length ? " · Quest ✔" : ""}`); haptic("success"); }
      },
    });
  };
  useEffect(() => { if (hello.current && session) start(hello.current); }, []);

  const send = action => conn.current && conn.current.send({ t: "action", action, idem: Math.random().toString(36).slice(2) });
  const leave = () => { conn.current && conn.current.send({ t: "leave" }); localStorage.removeItem("mm:session"); conn.current && conn.current.close(); conn.current = null; setSession(null); setView(null); setJoining(false); };

  let body;
  if (!view) body = joining && !error ? html`<div class="p-wait"><div class="spin-banana">🍌</div><p>Verbinde mit dem iPad …</p></div>` : html`<${Join} onJoin=${start} error=${error} edition=${edition} />`;
  else body = html`<${Game} view=${view} send=${send} say=${say} leave=${leave} />`;
  return html`<div class="phone">${body}
    ${!online && view && html`<div class="p-offline">Verbindung weg — ich versuche es weiter …</div>`}
    ${toast && html`<div class="p-toast pop-in" key=${toast}>${toast}</div>`}
  </div>`;
}

// ---------- join ----------
function Join({ onJoin, error, edition }) {
  const look = load("mm:look", {});
  const [code, setCode] = useState(codeFromUrl);
  const [editCode, setEditCode] = useState(codeFromUrl.length !== 4);
  const [name, setName] = useState(load("mm:name", ""));
  const [affe, setAffe] = useState(look.affeId || MONKEYS[Math.floor(Math.random() * MONKEYS.length)][0]);
  const [farbe, setFarbe] = useState(look.farbe || "gelb");
  const [profiles, setProfiles] = useState([]);
  const [chosen, setChosen] = useState(null);
  const [save, setSave] = useState(false);
  const [pin, setPin] = useState("");
  const [err, setErr] = useState(null);
  const [busy, setBusy] = useState(false);
  const dev = deviceToken();
  useEffect(() => { api(`/api/profiles?device=${encodeURIComponent(dev)}`).then(l => Array.isArray(l) && setProfiles(l)).catch(() => {}); }, []);
  const idx = MONKEYS.findIndex(m => m[0] === affe);
  const m = MONKEYS[idx >= 0 ? idx : 0];
  const wire = `${m[0]}.${farbe}`;
  const step = d => { setAffe(MONKEYS[(idx + d + MONKEYS.length) % MONKEYS.length][0]); haptic(); };
  const pickProfile = p => { setChosen(p); setName(p.name); const [a, f] = p.avatar.split("."); if (MONKEYS.some(x => x[0] === a)) setAffe(a); if (f) setFarbe(f); haptic(); };
  const go = async () => {
    const c = code.trim().toUpperCase();
    if (c.length !== 4) return setErr("Bitte den 4-stelligen Raum-Code eingeben.");
    if (!name.trim() && !chosen) return setErr("Wie heißt du?");
    setBusy(true); setErr(null);
    localStorage.setItem("mm:name", JSON.stringify(name.trim()));
    localStorage.setItem("mm:look", JSON.stringify({ affeId: m[0], farbe, wire }));
    let profileId = chosen ? chosen.id : null;
    const profilePin = chosen && chosen.hasPin ? pin || null : null;
    try {
      if (!profileId && save) { const p = await api("/api/profiles", { name: name.trim(), avatar: wire, pin: pin || null, device: dev }); profileId = p.id; }
      else if (profileId) api(`/api/profiles/${profileId}/update`, { avatar: wire, device: dev, pin: profilePin }).catch(() => {});
    } catch (_) {}
    setBusy(false);
    onJoin({ t: "hello", roomCode: c, role: "player", name: name.trim(), avatar: wire, profileId, profilePin, deviceToken: dev, sessionToken: null });
  };
  return html`<div class="join">
    <header class="join-head"><div class="j-logo">🐵 <span>MONKEY</span><b>MONEY</b></div>${edition && html`<span class="chip gold">⚔️ ${edition}</span>`}</header>
    <section class="j-block">
      <label>Raum</label>
      ${editCode ? html`<input class="code-in" maxlength="4" autocapitalize="characters" autocomplete="off" placeholder="ABCD" value=${code} onInput=${e => { const v = e.target.value.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 4); setCode(v); if (v.length === 4) setEditCode(false); }} />`
        : html`<div class="code-show" onClick=${() => setEditCode(true)}>${code.split("").map(c => html`<span>${c}</span>`)}<small>ändern</small></div>`}
    </section>
    <section class="j-picker">
      <button class="j-arrow" onClick=${() => step(-1)}>‹</button>
      <div class="j-preview" key=${wire}><${Monkey} wire=${wire} face="jubel" anim="idle" size=${150} /></div>
      <button class="j-arrow" onClick=${() => step(1)}>›</button>
      <div class="j-mname"><b>${m[1]}</b><small>„${m[2]}“</small></div>
      <div class="j-colors">${COLORS.map(([id, hex]) => html`<button class=${cx("swatch", farbe === id && "on")} style=${`background:${hex}`} onClick=${() => { setFarbe(id); haptic(); }}></button>`)}</div>
    </section>
    <section class="j-block">
      <label>Dein Name</label>
      <input class="name-in" maxlength="18" placeholder="z. B. Banana Joe" value=${name} onInput=${e => { setName(e.target.value); setChosen(null); }} onKeyDown=${e => e.key === "Enter" && go()} />
      ${profiles.length > 0 && html`<div class="j-profiles"><small>Auf diesem Handy:</small>${profiles.map(p => html`<button class=${cx("pick", chosen && chosen.id === p.id && "on")} onClick=${() => pickProfile(p)}>${p.name} · Lv ${p.level}${p.hasPin ? " 🔒" : ""}</button>`)}</div>`}
      ${chosen && chosen.hasPin && html`<input class="name-in" inputmode="numeric" maxlength="4" placeholder="PIN" value=${pin} onInput=${e => setPin(e.target.value)} />`}
      ${!chosen && html`<label class="j-save"><input type="checkbox" checked=${save} onChange=${e => setSave(e.target.checked)} /> Profil speichern (Level, Shop, Bestenlisten)</label>`}
      ${!chosen && save && html`<input class="name-in" inputmode="numeric" maxlength="4" placeholder="PIN (optional, 4 Ziffern)" value=${pin} onInput=${e => setPin(e.target.value)} />`}
    </section>
    ${(err || error) && html`<p class="j-err">${err || error}</p>`}
    <button class="btn big block" disabled=${busy} onClick=${go}>🍌 Rein da!</button>
    <a class="j-link" href="/uebung">🎯 Solo üben, bis die Show startet</a>
  </div>`;
}

// ---------- game ----------
function Game({ view, send, say, leave }) {
  const me = view.me;
  const p = decode(view.prompt);
  const [jar, setJar] = useState(false);
  const [joker, setJoker] = useState(null);
  const [menu, setMenu] = useState(false);
  const [flash, setFlash] = useState(null);
  const lastMoment = useRef(null);
  const lastWhisper = useRef(null);
  useEffect(() => {
    const ms = view.moments || [];
    const newest = ms[ms.length - 1];
    if (lastMoment.current === null) { lastMoment.current = newest ? newest.id : 0; return; }
    if (newest && newest.id > lastMoment.current) { lastMoment.current = newest.id; if (newest.art !== "sound" && newest.art !== "join") say(newest.text); }
  }, [view.moments]);
  useEffect(() => { if (view.haptic) haptic(view.haptic); if (view.flash) { setFlash({ k: view.flash, t: Date.now() }); } }, [view.haptic, view.flash, view.serverTime]);
  useEffect(() => { if (view.whisper && view.whisper !== lastWhisper.current) { haptic("success"); say("🤫 Flüster-Tipp für dich!"); } lastWhisper.current = view.whisper; }, [view.whisper]);
  const rankPhase = ["zwischenstand", "halbzeit", "siegerehrung", "ende", "pause"].includes(view.phase);
  const flashOn = flash && Date.now() - flash.t < 1200;
  return html`<div class=${cx("game", "ph-" + view.phase, "pk-" + p.kind)}>
    <header class="g-head">
      <button class="g-me" onClick=${() => setMenu(true)}><${Monkey} wire=${me.avatar} anim="none" size=${46} /><span><b>${me.name}</b><small>Platz ${me.platz} von ${view.ranking.length}</small></span></button>
      <div class="g-money"><${Money} value=${me.balance} /></div>
    </header>
    <div class="g-sub">
      <span class="g-section">${view.sectionLabel}</span>
      ${me.streak >= 2 && html`<span class="chip gold">🔥 ${me.streak}</span>`}
      ${view.rueckenwind > 1 && html`<span class="chip green">🌬️ ×${fmtNum(view.rueckenwind)}</span>`}
      ${view.jackpotAktiv && html`<button class="chip jar-chip" onClick=${() => setJar(true)}>🫙 ${fmtMM(view.jackpotGlas)}</button>`}
    </div>
    <div class="g-progress"><i style=${`width:${Math.round((view.progress || 0) * 100)}%`}></i></div>
    ${view.paused && html`<div class="g-pause">⏸ ${view.pauseText || "Pause"}</div>`}
    ${view.whisper && html`<div class="whisper pop-in" key=${view.whisper}><small>🤫 Flüster-Tipp vom Show-Master</small><b>${view.whisper}</b></div>`}
    <main class="g-main" key=${p.kind}>
      <${Prompt} p=${p} send=${send} me=${me} />
      ${rankPhase && html`<${Ranking} view=${view} />`}
    </main>
    ${view.jokers && view.jokers.length > 0 && html`<nav class="jokers">${view.jokers.map(j => html`<button class=${cx("joker", j.nutzbar && "ready", j.ladungen === 0 && !j.kaufbar && "empty")} onClick=${() => setJoker(j)}>
      <span class="jk-e">${j.emoji}</span><small>${j.ladungen > 0 ? `${j.ladungen}×` : j.kaufbar ? fmtNum(j.preis) : "–"}</small></button>`)}</nav>`}
    ${jar && html`<div class="sheet-veil" onClick=${() => setJar(false)}><div class="p-sheet pop-in"><div class="big-emoji">🫙</div><h2>${fmtMM(view.jackpotGlas)}</h2><p>${view.jackpotHinweis}</p><button class="btn block" onClick=${() => setJar(false)}>Alles klar</button></div></div>`}
    ${joker && html`<${JokerSheet} j=${view.jokers.find(x => x.id === joker.id) || joker} send=${send} close=${() => setJoker(null)} />`}
    ${menu && html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && setMenu(false)}><div class="p-sheet pop-in">
      <${Monkey} wire=${me.avatar} face="jubel" anim="jubel" size=${110} /><h2>${me.name}</h2><p class="muted">Raum ${view.roomCode} · ${fmtMM(me.balance)}</p>
      <button class="btn ghost block" onClick=${() => { setMenu(false); leave(); }}>🚪 Raum verlassen</button>
      <button class="btn block" onClick=${() => setMenu(false)}>Zurück ins Spiel</button></div></div>`}
    ${flashOn && html`<div class=${cx("flash", flash.k)} key=${flash.t}></div>`}
    ${p.kind === "reveal" && p.correct && p.delta >= 50 && html`<${MoneyRain} n=${p.delta >= 500 ? 34 : 18} key=${view.serverTime - (view.serverTime % 100000)} />`}
  </div>`;
}

function Ranking({ view }) {
  return html`<div class="ranking card"><h3>${["siegerehrung", "ende"].includes(view.phase) ? "🏆 Endstand" : "Zwischenstand"}</h3>
    <ol>${view.ranking.map(r => html`<li class=${cx(r.id === view.me.id && "me")}><span class="rk">${r.platz <= 3 ? ["🥇", "🥈", "🥉"][r.platz - 1] : r.platz + "."}</span><${Monkey} wire=${r.avatar} anim="none" size=${34} /><span class="rn">${r.name}${r.id === view.me.id ? " (du)" : ""}</span><b>${fmtMM(r.balance)}</b></li>`)}</ol></div>`;
}

function JokerSheet({ j, send, close }) {
  const use = stufe => { send(stufe ? { type: "joker", id: j.id, stufe } : { type: "joker", id: j.id }); haptic("success"); close(); };
  return html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && close()}><div class="p-sheet pop-in">
    <div class="big-emoji">${j.emoji}</div><h2>${j.name}</h2><p>${j.beschreibung}</p>
    <p class="muted">${j.ladungen > 0 ? `Du hast ${j.ladungen}× frei` : j.kaufbar ? `Kaufen für ${fmtMM(j.preis)}` : "Gerade nicht verfügbar"}</p>
    ${j.id === "schmiergeld" && j.nutzbar ? html`<button class="btn green block" onClick=${() => use(1)}>Stufe 1: eine falsche Option weg (25 %)</button><button class="btn green block" onClick=${() => use(2)}>Stufe 2: Hinweis (35 %)</button>`
      : j.nutzbar ? html`<button class="btn green block big" onClick=${() => use()}>${j.ladungen > 0 ? "Jetzt einsetzen" : `Kaufen & einsetzen (${fmtMM(j.preis)})`}</button>`
      : j.kaufbar ? html`<button class="btn block" onClick=${() => { send({ type: "jokerBuy", id: j.id }); close(); }}>🛒 Auf Vorrat kaufen (${fmtMM(j.preis)})</button>` : null}
    <button class="btn ghost block" onClick=${close}>Schließen</button>
  </div></div>`;
}

function MoneyRain({ n }) {
  return html`<div class="rain">${Array.from({ length: n }, (_, i) => html`<i class=${i % 3 === 0 ? "coin" : ""} style=${`left:${Math.random() * 100}%;animation-delay:${Math.random() * 900}ms;animation-duration:${1800 + Math.random() * 1400}ms;--r:${Math.random() * 720 - 360}deg`}></i>`)}</div>`;
}

render(html`<${App} />`, document.getElementById("app"));
