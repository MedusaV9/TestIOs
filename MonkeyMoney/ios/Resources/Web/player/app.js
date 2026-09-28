// Monkey Money — the phone controller (browser). Join, then render whatever
// the engine prompts, with jokers, the jackpot jar and whispers.
import { html, render, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { connect, decode, api, cx, fmtMM, fmtNum, fmtDelta, deviceToken, MONKEYS, COLORS, setFeedback, feel } from "../lib/core.js";
import { Monkey, Money } from "../lib/ui.js";
import { Prompt } from "../lib/prompts.js";
import { fx, installTouch, isMuted, setMuted, unlock } from "./fx.js";

const codeFromUrl = ((location.pathname.match(/\/j\/([A-Za-z]{4})/) || [])[1] || new URLSearchParams(location.search).get("code") || "").toUpperCase();
const load = (k, d) => { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch (_) { return d; } };
const RANK_PHASES = ["zwischenstand", "halbzeit", "siegerehrung", "ende", "pause"];
const MEDAL = ["🥇", "🥈", "🥉"];

installTouch();

function App() {
  const [session, setSession] = useState(() => { const s = load("mm:session", null); return s && s.code === codeFromUrl ? s : null; });
  const [joining, setJoining] = useState(!!session);
  const [error, setError] = useState(null);
  const [view, setView] = useState(null);
  const [online, setOnline] = useState(true);
  const [attempt, setAttempt] = useState(0);
  const [offlineSince, setOfflineSince] = useState(0);
  const [back, setBack] = useState(0);
  const [ended, setEnded] = useState(null);
  const [toast, setToast] = useState(null);
  const [edition, setEdition] = useState("");
  const conn = useRef(null);
  const hello = useRef(session ? { t: "hello", roomCode: session.code, role: "player", sessionToken: session.token, name: load("mm:name", ""), avatar: load("mm:look", {}).wire } : null);
  const queue = useRef([]);
  const wasOffline = useRef(false);
  const hadView = useRef(false);
  const viewRef = useRef(null);
  viewRef.current = view;
  const toastT = useRef();
  const say = (text, kind = "") => { setToast({ text, kind, k: Date.now() }); clearTimeout(toastT.current); toastT.current = setTimeout(() => setToast(null), 2800); };

  useEffect(() => { setFeedback({ feel: fx, say: t => say(t, "warn") }); }, []);
  useEffect(() => { api("/api/room").then(r => { if (r && r.edition) { setEdition(r.edition); document.title = "Monkey Money " + r.edition; } }).catch(() => {}); }, []);

  // Offline bookkeeping: after a short grace show the overlay; celebrate the comeback.
  const [, force] = useState(0);
  useEffect(() => { if (online) return; const t = setTimeout(() => force(x => x + 1), 2600); return () => clearTimeout(t); }, [online, attempt]);
  // iOS suspends sockets in the background — reconnect as soon as we're visible again.
  useEffect(() => {
    const vis = () => { if (document.visibilityState === "visible" && conn.current && !conn.current.alive) conn.current.reconnect(); };
    document.addEventListener("visibilitychange", vis);
    window.addEventListener("online", vis);
    return () => { document.removeEventListener("visibilitychange", vis); window.removeEventListener("online", vis); };
  }, []);

  useEffect(() => { if (!back) return; const t = setTimeout(() => setBack(0), 2200); return () => clearTimeout(t); }, [back]);

  const endShow = reason => {
    const view = viewRef.current;
    localStorage.removeItem("mm:session");
    conn.current && conn.current.close(); conn.current = null;
    setEnded({ reason, me: view && view.me, stats: view && view.stats, platz: view && view.me.platz, players: view ? view.ranking.length : 0 });
    setView(null); setSession(null); setJoining(false);
  };

  const start = payload => {
    hello.current = payload;
    setJoining(true);
    setError(null);
    setEnded(null);
    if (conn.current) { conn.current.reconnect(); return; }
    conn.current = connect({
      hello: () => hello.current,
      onStatus: ok => {
        setOnline(ok);
        if (ok) { setAttempt(0); }
        else { setAttempt(a => a + 1); setOfflineSince(t => t || Date.now()); wasOffline.current = true; }
      },
      onMessage: msg => {
        if (msg.t === "welcome") {
          const s = { code: hello.current.roomCode.toUpperCase(), token: msg.sessionToken };
          localStorage.setItem("mm:session", JSON.stringify(s));
          hello.current = { ...hello.current, sessionToken: msg.sessionToken };
          setSession(s);
        } else if (msg.t === "player") {
          setView(msg.view);
          if (!hadView.current) feel("lock");
          hadView.current = true;
          if (wasOffline.current) {
            wasOffline.current = false;
            setOfflineSince(0);
            setBack(Date.now());
            fx("online");
            // Flush what was tapped while offline (fresh actions only; idem keys dedupe).
            const q = queue.current.filter(a => Date.now() - a.at < 10000); queue.current = [];
            for (const a of q) conn.current && conn.current.send(a.msg);
          }
        } else if (msg.t === "error") {
          if (msg.code === "room" && hadView.current) { endShow("Diese Show gibt es nicht mehr."); return; }
          if (["room", "no-session", "full", "profile"].includes(msg.code)) { localStorage.removeItem("mm:session"); setSession(null); setView(null); setJoining(false); conn.current && conn.current.close(); conn.current = null; }
          setError(msg.message);
        } else if (msg.t === "closed") endShow(msg.reason || "Der Raum wurde geschlossen.");
        else if (msg.t === "profileEvent") { const e = msg.event; say(`+${e.atDelta} AT${e.levelUp ? ` · LEVEL ${e.level}!` : ""}${e.quests.length ? " · Quest ✔" : ""}`, "gold"); feel("correct"); }
      },
    });
  };
  useEffect(() => { if (hello.current && session) start(hello.current); }, []);

  // Same action object → same idem key, so resends are deduplicated server-side.
  const idems = useRef(new WeakMap());
  const send = action => {
    let idem = idems.current.get(action);
    if (!idem) { idem = Math.random().toString(36).slice(2); idems.current.set(action, idem); }
    const msg = { t: "action", action, idem };
    const ok = !!(conn.current && conn.current.send(msg));
    if (!ok) {
      if (!queue.current.some(q => q.msg.idem === idem)) queue.current.push({ msg, at: Date.now() });
      say("📡 Offline — wird gesendet, sobald die Verbindung steht", "warn");
    }
    return ok;
  };
  const leave = () => { conn.current && conn.current.send({ t: "leave" }); localStorage.removeItem("mm:session"); conn.current && conn.current.close(); conn.current = null; setSession(null); setView(null); setJoining(false); hadView.current = false; };
  const retryNow = () => { unlock(); conn.current && conn.current.reconnect(); };

  let body;
  if (ended) body = html`<${Ended} info=${ended} />`;
  else if (!view) body = joining && !error ? html`<div class="p-wait"><div class="spin-banana">🍌</div><p>Verbinde mit dem iPad …</p><small class="muted">Raum ${hello.current && hello.current.roomCode}</small></div>` : html`<${Join} onJoin=${start} error=${error} edition=${edition} />`;
  else body = html`<${Game} view=${view} send=${send} say=${say} leave=${leave} />`;
  const longOffline = !online && !!offlineSince && Date.now() - offlineSince > 2500;
  const showBack = !!back && Date.now() - back < 2200;
  return html`<div class="phone">${body}
    ${!online && (view || joining) && !longOffline && html`<div class="p-offline" role="status"><span class="ln-spin"></span> Verbindung wackelt …</div>`}
    ${longOffline && (view || joining) && html`<div class="reconnect-veil fade-in" role="alertdialog" aria-label="Verbindung verloren">
      <div class="rc-card pop-in">
        <div class="rc-ico"><span class="rc-wave"></span><span class="rc-wave w2"></span>📡</div>
        <h2>Verbindung verloren</h2>
        <p class="muted">Keine Sorge — dein Geld und deine Antworten sind sicher auf dem iPad. Ich verbinde automatisch neu.</p>
        <div class="rc-attempt"><span class="ln-spin"></span> Versuch ${attempt} …</div>
        <button class="btn block" onClick=${retryNow}>🔄 Jetzt neu verbinden</button>
        <small class="muted">Gleiches WLAN wie das iPad?</small>
      </div></div>`}
    ${showBack && html`<div class="p-back pop-in" key=${back}><i class="ck"></i> Wieder verbunden</div>`}
    ${toast && html`<div class=${cx("p-toast pop-in", toast.kind)} key=${toast.k}>${toast.text}</div>`}
  </div>`;
}

// ---------- ended ----------
function Ended({ info }) {
  const [busy, setBusy] = useState(false);
  const look = load("mm:look", {});
  const rejoin = async () => {
    setBusy(true);
    try { const r = await api("/api/room"); if (r && r.code) { location.href = `/j/${r.code}`; return; } } catch (_) {}
    location.href = "/";
  };
  const st = info.stats;
  return html`<div class="ended">
    <div class="idle-stage"><div class="idle-glow"></div><${Monkey} wire=${(info.me && info.me.avatar) || look.wire} face="jubel" anim="jubel" size=${150} /></div>
    <h1>Show beendet</h1>
    <p class="muted">${info.reason}</p>
    ${info.me && html`<div class="ended-card card">
      <div><small>Platz</small><b>${info.platz}${info.players ? html`<i>/${info.players}</i>` : ""}</b></div>
      <div><small>Kontostand</small><b class="gold-text">${fmtMM(info.me.balance)}</b></div>
      ${st && html`<div><small>Richtig</small><b>${st.richtig}/${st.richtig + st.falsch}</b></div><div><small>Beste Serie</small><b>🔥 ${st.laengsteSerie}</b></div>`}
    </div>`}
    <button class="btn big block" disabled=${busy} onClick=${rejoin}>🔁 Neu beitreten</button>
    <a class="j-link" href="/uebung">🎯 Solo üben</a>
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
  const [dir, setDir] = useState(0);
  const dev = deviceToken();
  const strip = useRef();
  useEffect(() => { api(`/api/profiles?device=${encodeURIComponent(dev)}`).then(l => Array.isArray(l) && setProfiles(l)).catch(() => {}); }, []);
  const idx = MONKEYS.findIndex(m => m[0] === affe);
  const m = MONKEYS[idx >= 0 ? idx : 0];
  const wire = `${m[0]}.${farbe}`;
  const pickAffe = (id, d) => { setAffe(id); setDir(d); feel("tap"); };
  const step = d => pickAffe(MONKEYS[(idx + d + MONKEYS.length) % MONKEYS.length][0], d);
  useEffect(() => { const el = strip.current && strip.current.querySelector(".on"); if (el && el.scrollIntoView) el.scrollIntoView({ block: "nearest", inline: "center", behavior: "smooth" }); }, [affe]);
  // Swipe the big preview left/right.
  const touch = useRef(null);
  const onTS = e => { touch.current = e.touches[0].clientX; };
  const onTE = e => { if (touch.current == null) return; const dx = e.changedTouches[0].clientX - touch.current; touch.current = null; if (Math.abs(dx) > 40) step(dx < 0 ? 1 : -1); };
  const pickProfile = p => { setChosen(p); setName(p.name); const [a, f] = p.avatar.split("."); if (MONKEYS.some(x => x[0] === a)) setAffe(a); if (f) setFarbe(f); feel("tap"); };
  const ready = code.trim().length === 4 && (name.trim() || chosen);
  const go = async () => {
    unlock();
    const c = code.trim().toUpperCase();
    if (c.length !== 4) { feel("error"); return setErr("Bitte den 4-stelligen Raum-Code eingeben."); }
    if (!name.trim() && !chosen) { feel("error"); return setErr("Wie heißt du?"); }
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
    feel("lock");
    onJoin({ t: "hello", roomCode: c, role: "player", name: name.trim(), avatar: wire, profileId, profilePin, deviceToken: dev, sessionToken: null });
  };
  return html`<div class="join">
    <header class="join-head"><div class="j-logo">🐵 <span>MONKEY</span><b>MONEY</b></div>${edition && html`<span class="chip gold">⚔️ ${edition}</span>`}</header>
    <section class="j-block j-room">
      <label><span class="j-step">1</span> Raum</label>
      ${editCode ? html`<input class="code-in" maxlength="4" autocapitalize="characters" autocomplete="off" autocorrect="off" spellcheck="false" placeholder="ABCD" value=${code} onInput=${e => { const v = e.target.value.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 4); setCode(v); if (v.length === 4) { setEditCode(false); feel("tap"); } }} />`
        : html`<button class="code-show" onClick=${() => setEditCode(true)} aria-label="Raum-Code ändern">${code.split("").map((c, i) => html`<span style=${`animation-delay:${i * 70}ms`}>${c}</span>`)}<small>ändern</small></button>`}
    </section>
    <section class="j-picker">
      <label class="j-plabel"><span class="j-step">2</span> Dein Affe</label>
      <div class="j-stage" onTouchStart=${onTS} onTouchEnd=${onTE}>
        <button class="j-arrow" onClick=${() => step(-1)} aria-label="voriger Affe">‹</button>
        <div class=${cx("j-preview", dir < 0 ? "from-l" : dir > 0 ? "from-r" : "")} key=${wire}><div class="j-spot"></div><${Monkey} wire=${wire} face="jubel" anim="jubel" size=${170} /></div>
        <button class="j-arrow" onClick=${() => step(1)} aria-label="nächster Affe">›</button>
      </div>
      <div class="j-mname" key=${m[0]}><b>${m[1]}</b><small>„${m[2]}“</small></div>
      <div class="j-strip" ref=${strip}>${MONKEYS.map(([id, label], i) => html`<button class=${cx("j-thumb", id === affe && "on")} onClick=${() => pickAffe(id, i > idx ? 1 : -1)} aria-label=${label}><${Monkey} wire=${`${id}.${farbe}`} anim="none" size=${44} /></button>`)}</div>
      <div class="j-colors">${COLORS.map(([id, hex]) => html`<button class=${cx("swatch", farbe === id && "on")} style=${`--sw:${hex}`} aria-label=${id} onClick=${() => { setFarbe(id); feel("tap"); }}></button>`)}</div>
    </section>
    <section class="j-block">
      <label><span class="j-step">3</span> Dein Name</label>
      <input class="name-in" maxlength="18" placeholder="z. B. Banana Joe" enterkeyhint="go" autocomplete="nickname" value=${name} onInput=${e => { setName(e.target.value); setChosen(null); }} onKeyDown=${e => e.key === "Enter" && go()} />
      ${profiles.length > 0 && html`<div class="j-profiles"><small>Auf diesem Handy:</small>${profiles.map(p => html`<button class=${cx("pick", chosen && chosen.id === p.id && "on")} onClick=${() => pickProfile(p)}>${p.name} · Lv ${p.level}${p.hasPin ? " 🔒" : ""}</button>`)}</div>`}
      ${chosen && chosen.hasPin && html`<input class="name-in" inputmode="numeric" maxlength="4" placeholder="PIN" value=${pin} onInput=${e => setPin(e.target.value)} />`}
      ${!chosen && html`<label class="j-save"><input type="checkbox" checked=${save} onChange=${e => setSave(e.target.checked)} /> <span>Profil speichern <small>(Level, Shop, Bestenlisten)</small></span></label>`}
      ${!chosen && save && html`<input class="name-in" inputmode="numeric" maxlength="4" placeholder="PIN (optional, 4 Ziffern)" value=${pin} onInput=${e => setPin(e.target.value)} />`}
    </section>
    ${(err || error) && html`<p class="j-err" key=${err || error}>${err || error}</p>`}
    <div class="j-go">
      <button class=${cx("btn big block", ready && "ready")} disabled=${busy} onClick=${go}>${busy ? "⏳ Moment …" : "🍌 Rein da!"}</button>
      <a class="j-link" href="/uebung">🎯 Solo üben, bis die Show startet</a>
    </div>
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
  const [muted, setMute] = useState(isMuted());
  const lastMoment = useRef(null);
  const lastWhisper = useRef(null);
  const lastHaptic = useRef(null);
  const lastPlatz = useRef(me.platz);
  const [platzDir, setPlatzDir] = useState("");
  // Ranking snapshot at the start of the round (for arrows + round deltas).
  const snap = useRef(null);
  const prevPhase = useRef(view.phase);
  const rankPhase = RANK_PHASES.includes(view.phase);
  if (!snap.current) snap.current = view.ranking;
  if (prevPhase.current !== view.phase) {
    if (RANK_PHASES.includes(prevPhase.current) && !rankPhase) snap.current = view.ranking;
    prevPhase.current = view.phase;
  }
  useEffect(() => {
    const ms = view.moments || [];
    const newest = ms[ms.length - 1];
    if (lastMoment.current === null) { lastMoment.current = newest ? newest.id : 0; return; }
    if (newest && newest.id > lastMoment.current) { lastMoment.current = newest.id; if (newest.art !== "sound" && newest.art !== "join") say(newest.text); }
  }, [view.moments]);
  // Result feedback once per reveal (the view repeats haptic/flash on every update).
  useEffect(() => {
    const key = view.haptic || view.flash ? `${view.haptic}|${view.flash}|${p.kind}|${p.title || ""}` : null;
    if (key && key !== lastHaptic.current) {
      feel(view.haptic === "success" ? "correct" : view.haptic === "error" ? "wrong" : view.haptic === "heavy" ? "heavy" : "tap");
      if (view.flash) setFlash({ k: view.flash, t: Date.now() });
      if (p.kind === "reveal" && p.delta > 0) setTimeout(() => fx("coin"), 650);
    }
    lastHaptic.current = key;
  }, [view.haptic, view.flash, p.kind, p.title]);
  useEffect(() => { if (view.whisper && view.whisper !== lastWhisper.current) { feel("correct"); say("🤫 Flüster-Tipp für dich!", "gold"); } lastWhisper.current = view.whisper; }, [view.whisper]);
  useEffect(() => {
    if (me.platz !== lastPlatz.current) { setPlatzDir(me.platz < lastPlatz.current ? "up" : "down"); lastPlatz.current = me.platz; const t = setTimeout(() => setPlatzDir(""), 1800); return () => clearTimeout(t); }
  }, [me.platz]);
  const flashOn = flash && Date.now() - flash.t < 1200;
  const n = view.ranking.length;
  const hasJokers = view.jokers && view.jokers.length > 0;
  const extra = { phase: view.phase, ergebnis: view.ergebnis, stats: view.stats, players: n, ohneScreen: view.ohneScreen };
  const mainKey = p.kind + (["choice", "multiChoice", "number", "order", "text", "chips", "wager", "reveal"].includes(p.kind) ? "|" + (p.question || p.title || "") : "");
  const toggleMute = () => { const v = !muted; setMuted(v); setMute(v); if (!v) { unlock(); fx("lock"); } };
  return html`<div class=${cx("game", "ph-" + view.phase, "pk-" + p.kind, hasJokers && "has-jokers")}>
    <header class="g-head">
      <button class="g-me" onClick=${() => setMenu(true)} aria-label="Mein Menü"><span class="g-av"><${Monkey} wire=${me.avatar} anim="none" size=${44} /></span><span class="g-who"><b>${me.name}</b>
        <small class=${cx("g-rank", platzDir)} key=${me.platz}>${me.platz <= 3 ? MEDAL[me.platz - 1] + " " : ""}Platz ${me.platz}<i>/${n}</i>${platzDir && html` <i class=${"tri " + platzDir}></i>`}</small></span></button>
      <div class="g-money"><span class="g-coin">🍌</span><${Money} value=${me.balance} suffix="" /><small>MM</small></div>
    </header>
    <div class="g-sub">
      <span class="g-section">${view.sectionLabel}</span>
      ${me.streak >= 2 && html`<span class=${cx("chip gold", me.streak >= 3 && "flame")}>🔥 ${me.streak}${me.streak >= 5 ? " ×2" : me.streak >= 3 ? " ×1,5" : ""}</span>`}
      ${view.rueckenwind > 1 && html`<span class="chip green">🌬️ ×${fmtNum(view.rueckenwind)}</span>`}
      ${view.jackpotAktiv && html`<button class="chip jar-chip" onClick=${() => setJar(true)}>🫙 ${fmtMM(view.jackpotGlas)}</button>`}
    </div>
    <div class="g-progress" aria-hidden="true"><i style=${`width:${Math.round((view.progress || 0) * 100)}%`}></i></div>
    ${view.paused && html`<div class="g-pause">⏸ ${view.pauseText || "Pause"}</div>`}
    ${view.whisper && html`<div class="whisper pop-in" key=${view.whisper}><small>🤫 Flüster-Tipp vom Show-Master</small><b>${view.whisper}</b></div>`}
    <main class="g-main" key=${mainKey}>
      <${Prompt} p=${p} send=${send} me=${me} extra=${extra} />
      ${rankPhase && html`<${Ranking} view=${view} snap=${snap.current} />`}
    </main>
    ${hasJokers && html`<nav class="jokers" aria-label="Joker">${view.jokers.map(j => html`<button class=${cx("joker", j.nutzbar && "ready", j.ladungen === 0 && !j.kaufbar && "empty")} onClick=${() => { feel("tap"); setJoker(j); }} aria-label=${j.name}>
      <span class="jk-e">${j.emoji}</span>${j.ladungen > 0 ? html`<span class="jk-n">${j.ladungen}</span>` : null}<small>${j.ladungen > 0 ? "frei" : j.kaufbar ? fmtNum(j.preis) : "–"}</small></button>`)}</nav>`}
    ${jar && html`<${Sheet} close=${() => setJar(false)}><div class="big-emoji jar-big">🫙</div><h2>${fmtMM(view.jackpotGlas)}</h2><p>${view.jackpotHinweis}</p><button class="btn block" onClick=${() => setJar(false)}>Alles klar</button><//>`}
    ${joker && html`<${JokerSheet} j=${view.jokers.find(x => x.id === joker.id) || joker} send=${send} close=${() => setJoker(null)} balance=${me.balance} />`}
    ${menu && html`<${Sheet} close=${() => setMenu(false)}>
      <${Monkey} wire=${me.avatar} face="jubel" anim="jubel" size=${110} /><h2>${me.name}</h2><p class="muted">Raum ${view.roomCode} · Platz ${me.platz}/${n} · ${fmtMM(me.balance)}</p>
      <div class="menu-stats"><span><b>${view.stats.richtig}</b><small>✅ richtig</small></span><span><b>${view.stats.falsch}</b><small>❌ falsch</small></span><span><b>${view.stats.laengsteSerie}</b><small>🔥 beste Serie</small></span></div>
      <button class=${cx("toggle-row", !muted && "on")} onClick=${toggleMute} role="switch" aria-checked=${!muted}><span>${muted ? "🔇" : "🔊"} Klick-Sounds</span><i></i></button>
      <button class="btn ghost block" onClick=${() => { setMenu(false); leave(); }}>🚪 Raum verlassen</button>
      <button class="btn block" onClick=${() => setMenu(false)}>Zurück ins Spiel</button><//>`}
    ${flashOn && html`<div class=${cx("flash", flash.k)} key=${flash.t}></div>`}
    ${p.kind === "reveal" && p.correct && p.delta >= 50 && html`<${MoneyRain} n=${p.delta >= 500 ? 34 : 18} key=${p.title + p.delta} />`}
  </div>`;
}

function Sheet({ close, children }) {
  return html`<div class="sheet-veil" onClick=${e => e.target === e.currentTarget && close()}><div class="p-sheet sheet-up"><span class="sheet-grab" onClick=${close}></span>${children}</div></div>`;
}

function Ranking({ view, snap }) {
  const before = Object.fromEntries((snap || []).map(r => [r.id, r]));
  const final = ["siegerehrung", "ende"].includes(view.phase);
  return html`<div class="ranking card"><h3>${final ? "🏆 Endstand" : "📊 Zwischenstand"}</h3>
    <ol>${view.ranking.map((r, i) => {
      const b = before[r.id];
      const move = b ? b.platz - r.platz : 0;
      const d = b ? r.balance - b.balance : 0;
      return html`<li class=${cx(r.id === view.me.id && "me", r.platz <= 3 && "top" + r.platz)} style=${`animation-delay:${i * 70}ms`}>
        <span class="rk">${r.platz <= 3 ? MEDAL[r.platz - 1] : r.platz + "."}</span>
        <${Monkey} wire=${r.avatar} anim="none" size=${34} />
        <span class="rn">${r.name}${r.id === view.me.id ? html` <em>DU</em>` : ""}${!r.connected ? " 💤" : ""}</span>
        ${!final && move !== 0 && html`<span class=${cx("rmove", move > 0 ? "up" : "down")}><i class=${"tri " + (move > 0 ? "up" : "down")}></i>${Math.abs(move)}</span>`}
        <span class="rbal"><b>${fmtMM(r.balance)}</b>${!final && d !== 0 && html`<small class=${d > 0 ? "pos" : "neg"}>${fmtDelta(d)}</small>`}</span>
      </li>`;
    })}</ol></div>`;
}

function JokerSheet({ j, send, close, balance }) {
  const use = stufe => { send(stufe ? { type: "joker", id: j.id, stufe } : { type: "joker", id: j.id }); feel("lock"); close(); };
  return html`<${Sheet} close=${close}>
    <div class=${cx("jk-hero", j.nutzbar && "ready")}><span>${j.emoji}</span></div><h2>${j.name}</h2><p>${j.beschreibung}</p>
    <div class="jk-status">${j.ladungen > 0 ? html`<span class="chip green">🎟️ ${j.ladungen}× frei</span>` : j.kaufbar ? html`<span class="chip gold">🛒 ${fmtMM(j.preis)}</span>` : html`<span class="chip">Gerade nicht verfügbar</span>`}
      ${j.kaufbar && j.ladungen === 0 && html`<span class="chip">Konto: ${fmtMM(balance)}</span>`}</div>
    ${j.id === "schmiergeld" && j.nutzbar ? html`<button class="btn green block" onClick=${() => use(1)}>Stufe 1: eine falsche Option weg (25 %)</button><button class="btn green block" onClick=${() => use(2)}>Stufe 2: Hinweis (35 %)</button>`
      : j.nutzbar ? html`<button class="btn green block big" onClick=${() => use()}>${j.ladungen > 0 ? "✨ Jetzt einsetzen" : `Kaufen & einsetzen (${fmtMM(j.preis)})`}</button>`
      : j.kaufbar ? html`<button class="btn block" onClick=${() => { send({ type: "jokerBuy", id: j.id }); feel("lock"); close(); }}>🛒 Auf Vorrat kaufen (${fmtMM(j.preis)})</button>` : null}
    <button class="btn ghost block" onClick=${close}>Schließen</button>
  <//>`;
}

function MoneyRain({ n }) {
  const [items] = useState(() => Array.from({ length: n }, (_, i) => ({ coin: i % 3 === 0, l: Math.random() * 100, d: Math.random() * 900, t: 1800 + Math.random() * 1400, r: Math.random() * 720 - 360 })));
  return html`<div class="rain" aria-hidden="true">${items.map(x => html`<i class=${x.coin ? "coin" : ""} style=${`left:${x.l}%;animation-delay:${x.d}ms;animation-duration:${x.t}ms;--r:${x.r}deg`}></i>`)}</div>`;
}

const root = document.getElementById("app");
root.textContent = "";
render(html`<${App} />`, root);
