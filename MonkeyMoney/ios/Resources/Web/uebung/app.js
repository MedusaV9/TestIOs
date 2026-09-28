// Übungsmodus: solo practice on the phone against the iPad's question bank.
// Start screen (topic + difficulty + options) → questions with instant feedback
// and explanation → session summary. Everything personal (best streak, accuracy
// per topic, last sessions, wrongly answered questions for the review) lives in
// localStorage; the review replays those questions locally, without the server.
//   GET  /api/kategorien                                  → [{id, name, emoji, farbe}]
//   GET  /api/uebung/frage?device=&kat=&schw=&familie=1   → {id, kat, katName, katEmoji, schw, wert, text, options, typ, stats} | 404
//   POST /api/uebung/antwort {id, index|null, device}     → {correct, correctIndex, erkl, tipps, stats} | 409
import { html, render, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { api, cx, fmtNum, deviceToken, setFeedback, feel } from "../lib/core.js";
import { Monkey } from "../lib/ui.js";
import { OptButton, Timer, Q } from "../lib/prompts.js";
import { TIER_META, TIERS } from "../lib/katalog.js";
import { fx, installTouch, isMuted, setMuted, unlock } from "../player/fx.js";

const device = deviceToken();
const KEY = "mm:uebung";
const MIX = { id: "", name: "Gemischt", emoji: "🎲", farbe: "#FFC93C" };
const LENGTHS = [[10, "10 Fragen"], [20, "20 Fragen"], [0, "Endlos"]];
const TIMERS = [[0, "Ohne Zeit"], [30, "30 s"], [15, "15 s"]];
const reduced = () => window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;

installTouch();
setFeedback({ feel: fx });

// ---------- local store ----------
const fresh = () => ({ v: 1, best: 0, right: 0, played: 0, cats: {}, tiers: {}, history: [], wrong: [], prefs: { kat: "", schw: "", familie: false, timer: 0, len: 10 } });
function loadStore() {
  try { const s = JSON.parse(localStorage.getItem(KEY)); if (s && s.v === 1) return { ...fresh(), ...s, prefs: { ...fresh().prefs, ...(s.prefs || {}) } }; } catch (_) {}
  return fresh();
}
function saveStore(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (_) {} }
const pct = (r, n) => (n ? Math.round((r / n) * 100) : 0);
const look = (() => { try { return JSON.parse(localStorage.getItem("mm:look")) || {}; } catch (_) { return {}; } })();
const avatar = look.wire || "don-bananas.gelb";

/** Category colours are tuned for the stage; keep very dark ones readable on the night background. */
function accent(hex) {
  const n = parseInt(String(hex || "#ffc93c").slice(1), 16);
  const lum = (0.2126 * (n >> 16) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255;
  return lum < 0.16 ? "#E8B400" : hex;
}
const shuffle = a => { const b = [...a]; for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; } return b; };
const when = t => {
  const d = new Date(t), now = new Date();
  const day = d.toDateString() === now.toDateString() ? "Heute" : new Date(now - 864e5).toDateString() === d.toDateString() ? "Gestern" : d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" });
  return `${day} ${d.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })}`;
};

function App() {
  const [store, setStore] = useState(loadStore);
  const [kats, setKats] = useState([]);
  const [katErr, setKatErr] = useState(false);
  const [screen, setScreen] = useState("start"); // start | play | summary
  const [session, setSession] = useState(null);
  const [muted, setMute] = useState(isMuted());
  const update = fn => setStore(s => { const n = fn(s); saveStore(n); return n; });
  useEffect(() => { api("/api/kategorien").then(l => Array.isArray(l) && setKats(l)).catch(() => setKatErr(true)); }, []);
  const toggleMute = () => { const v = !muted; setMuted(v); setMute(v); if (!v) { unlock(); fx("lock"); } };
  const start = (review = false) => {
    unlock();
    const p = store.prefs;
    const list = review ? shuffle(store.wrong).slice(0, 10) : null;
    setSession({ review, prefs: p, queue: list, len: review ? list.length : p.len, n: 0, right: 0, streak: 0, bestStreak: 0, cats: {}, times: [], newBest: false, startedAt: Date.now(), k: Date.now() });
    setScreen("play");
    feel("lock");
    window.scrollTo(0, 0);
  };
  const finish = s => {
    if (s.n > 0) update(st => ({ ...st, history: [{ at: Date.now(), kat: s.prefs.kat, schw: s.prefs.schw, right: s.right, played: s.n, streak: s.bestStreak, review: s.review }, ...st.history].slice(0, 12) }));
    setSession(s);
    setScreen(s.n > 0 ? "summary" : "start");
    window.scrollTo(0, 0);
  };
  const katById = Object.fromEntries(kats.map(k => [k.id, k]));
  return html`<div class=${cx("phone uebung", "u-" + screen)}>
    ${screen === "start" && html`<${Start} store=${store} kats=${kats} katErr=${katErr} update=${update} start=${start} muted=${muted} toggleMute=${toggleMute} />`}
    ${screen === "play" && html`<${Play} key=${session.k} session=${session} store=${store} update=${update} katById=${katById} finish=${finish} muted=${muted} toggleMute=${toggleMute} />`}
    ${screen === "summary" && html`<${Summary} s=${session} store=${store} katById=${katById} again=${() => start(false)} review=${() => start(true)} back=${() => setScreen("start")} />`}
  </div>`;
}

// ---------- start ----------
function Start({ store, kats, katErr, update, start, muted, toggleMute }) {
  const p = store.prefs;
  const setP = patch => { feel("tap"); update(s => ({ ...s, prefs: { ...s.prefs, ...patch } })); };
  const all = [MIX, ...kats];
  const cur = all.find(k => k.id === p.kat) || MIX;
  const tier = p.schw && TIER_META[p.schw];
  const acc = pct(store.right, store.played);
  return html`<div class="u-start fade-in">
    <header class="u-head">
      <div class="j-logo">🎯 <span>ÜBUNGS</span><b>MODUS</b></div>
      <div class="u-head-r">
        <button class="u-icon" onClick=${toggleMute} aria-pressed=${!muted} aria-label=${muted ? "Sounds an" : "Sounds aus"}>${muted ? "🔇" : "🔊"}</button>
        <a class="chip u-back" href="/">‹ Mitspielen</a>
      </div>
    </header>

    <section class="u-hero">
      <span class="u-hero-av"><${Monkey} wire=${avatar} face=${store.played ? "jubel" : "neutral"} anim="idle" size=${76} /></span>
      <div class="u-hero-stats">
        <div><b>🔥 ${store.best}</b><small>Beste Serie</small></div>
        <div><b>${store.played ? acc + " %" : "–"}</b><small>Trefferquote</small></div>
        <div><b>${fmtNum(store.played)}</b><small>Fragen geübt</small></div>
      </div>
    </section>

    ${store.wrong.length > 0 && html`<button class="u-review-card u-review-go" onClick=${() => start(true)}>
      <span class="u-rc-ico" aria-hidden="true">🔁</span>
      <span class="u-rc-t"><b>Nochmal falsch beantwortete</b><small>${store.wrong.length} ${store.wrong.length === 1 ? "Frage wartet" : "Fragen warten"} auf die Revanche</small></span>
      <span class="u-rc-go" aria-hidden="true">▶</span>
    </button>`}

    <section class="u-block">
      <h2 class="u-h">Thema</h2>
      ${katErr && html`<p class="u-note">⚠️ Themen konnten nicht geladen werden — „Gemischt“ geht trotzdem.</p>`}
      <div class="u-kats" role="radiogroup" aria-label="Thema">${all.map((k, i) => {
        const st = k.id ? store.cats[k.id] : { r: store.right, n: store.played };
        const on = p.kat === k.id;
        return html`<button class=${cx("u-kat", on && "on", !k.id && "mix")} data-id=${k.id || "mix"} role="radio" aria-checked=${on} style=${`--c:${accent(k.farbe)};animation-delay:${Math.min(i, 12) * 25}ms`}
            aria-label=${`${k.name}${st && st.n ? `, ${pct(st.r, st.n)} Prozent richtig` : ""}`} onClick=${() => setP({ kat: k.id })}>
          <span class="u-kat-art" aria-hidden="true">${k.id ? html`<i class="u-kat-svg" style=${`-webkit-mask-image:url(/img/${k.id}.svg);mask-image:url(/img/${k.id}.svg)`}></i>` : html`<i class="u-kat-mix"></i>`}</span>
          <span class="u-kat-name"><em aria-hidden="true">${k.emoji}</em> ${k.name}</span>
          ${st && st.n > 0 ? html`<span class="u-kat-acc" aria-hidden="true"><i style=${`--w:${pct(st.r, st.n) / 100}`}></i><small>${pct(st.r, st.n)} %</small></span>` : html`<span class="u-kat-acc new" aria-hidden="true"><small>${k.id ? "neu" : "alles"}</small></span>`}
        </button>`; })}</div>
    </section>

    <section class="u-block">
      <h2 class="u-h">Schwierigkeit</h2>
      <div class="u-tiers" role="radiogroup" aria-label="Schwierigkeit">
        <button class=${cx("u-tier", !p.schw && "on")} data-id="mix" role="radio" aria-checked=${!p.schw} style="--c:#ffc93c" onClick=${() => setP({ schw: "" })}><span aria-hidden="true">🎲</span><b>Gemischt</b></button>
        ${TIERS.map(t => { const m = TIER_META[t]; const st = store.tiers[t]; return html`<button class=${cx("u-tier", p.schw === t && "on")} data-id=${t} role="radio" aria-checked=${p.schw === t} style=${`--c:${m.c}`} onClick=${() => setP({ schw: t })}>
          <span aria-hidden="true">${m.emoji}</span><b>${m.name}</b>${st && st.n > 0 && html`<small>${pct(st.r, st.n)} %</small>`}</button>`; })}
      </div>
    </section>

    <section class="u-block u-opts">
      <h2 class="u-h">Optionen</h2>
      <div class="u-seg" role="radiogroup" aria-label="Länge">${LENGTHS.map(([v, l]) => html`<button class=${cx(p.len === v && "on")} role="radio" aria-checked=${p.len === v} onClick=${() => setP({ len: v })}>${l}</button>`)}</div>
      <div class="u-seg" role="radiogroup" aria-label="Zeitlimit">${TIMERS.map(([v, l]) => html`<button class=${cx(p.timer === v && "on")} role="radio" aria-checked=${p.timer === v} onClick=${() => setP({ timer: v })}>${v ? "⏱ " : ""}${l}</button>`)}</div>
      <button class=${cx("toggle-row", p.familie && "on")} role="switch" aria-checked=${!!p.familie} onClick=${() => setP({ familie: !p.familie })}><span>👪 Nur kindgerechte Fragen</span><i></i></button>
    </section>

    ${store.history.length > 0 && html`<section class="u-block">
      <h2 class="u-h">Letzte Runden</h2>
      <ol class="u-hist">${store.history.slice(0, 5).map(h => { const k = h.kat ? kats.find(x => x.id === h.kat) : MIX; const tm = h.schw && TIER_META[h.schw];
        return html`<li><span class="u-hist-e" aria-hidden="true">${h.review ? "🔁" : (k || MIX).emoji}</span>
          <span class="u-hist-t"><b>${h.review ? "Wiederholung" : (k || { name: h.kat }).name}${tm ? ` · ${tm.name}` : ""}</b><small>${when(h.at)}${h.streak >= 2 ? ` · 🔥 ${h.streak}` : ""}</small></span>
          <span class=${cx("u-hist-s", pct(h.right, h.played) >= 70 && "good")}>${h.right}/${h.played}</span></li>`; })}</ol>
    </section>`}

    <div class="u-dock">
      <div class="u-dock-sum" aria-live="polite"><b>${cur.emoji} ${cur.name}</b><small>${tier ? tier.name : "Alle Stufen"} · ${p.len ? p.len + " Fragen" : "Endlos"}${p.timer ? ` · ${p.timer} s` : ""}${p.familie ? " · 👪" : ""}</small></div>
      <button class="btn big u-go" onClick=${() => start(false)}>Los ▶</button>
    </div>
  </div>`;
}

// ---------- play ----------
function Play({ session, store, update, katById, finish, muted, toggleMute }) {
  const [s, setS] = useState(session);
  const [q, setQ] = useState(null);
  const [next, setNext] = useState(null); // prefetched question (server keeps one open per device)
  const [res, setRes] = useState(null);
  const [picked, setPicked] = useState(null);
  const [err, setErr] = useState(null);
  const [loading, setLoading] = useState(true);
  const [deadline, setDeadline] = useState(null);
  const [newBest, setNewBest] = useState(false);
  const shownAt = useRef(0);
  const fb = useRef(null);
  const nextBtn = useRef(null);
  const p = s.prefs;
  const total = s.len || 0;
  const last = total > 0 && s.n >= total;

  const fetchQ = async () => {
    const r = await fetch(`/api/uebung/frage?${new URLSearchParams({ device, kat: p.kat, schw: p.schw, familie: p.familie ? "1" : "0" })}`);
    if (r.status === 404) throw Object.assign(new Error("none"), { none: true });
    if (!r.ok) throw new Error(await r.text().catch(() => r.statusText));
    return r.json();
  };
  const show = x => {
    setQ(x); setRes(null); setPicked(null); setErr(null); setLoading(false); setNewBest(false);
    shownAt.current = Date.now();
    setDeadline(p.timer ? Date.now() + p.timer * 1000 : null);
  };
  const load = async () => {
    setLoading(true); setErr(null);
    if (s.review) {
      const item = s.queue[s.n];
      if (!item) { finish(s); return; }
      // Local replay: shuffle again (never Wahr/Falsch) and remember where the right answer went.
      const order = item.typ === "wahr_falsch" ? item.options.map((_, i) => i) : shuffle(item.options.map((_, i) => i));
      show({ ...item, options: order.map(i => item.options[i]), correctIndex: order.indexOf(item.correctIndex), local: true });
      return;
    }
    try { show(next || (await fetchQ())); setNext(null); }
    catch (e) { setLoading(false); setErr(e.none ? "none" : "net"); }
  };
  useEffect(() => { load(); }, []);

  // Timer: running out counts as wrong (index null).
  useEffect(() => {
    if (!deadline || res || picked != null) return;
    const t = setTimeout(() => answer(null), Math.max(0, deadline - Date.now()));
    return () => clearTimeout(t);
  }, [deadline, res, picked, q]);

  const answer = async i => {
    if (!q || res || picked != null) return;
    setPicked(i === null ? -1 : i);
    feel("lock");
    const ms = Date.now() - shownAt.current;
    let r;
    if (q.local) r = { correct: i === q.correctIndex, correctIndex: q.correctIndex, erkl: q.erkl };
    else {
      try { r = await api("/api/uebung/antwort", { id: q.id, index: i, device }); }
      catch (_) {
        // 409 = the server forgot the open question (restart / other tab) → just take a fresh one.
        setPicked(null); setErr(null); try { show(await fetchQ()); } catch (e) { setErr(e.none ? "none" : "net"); } return;
      }
    }
    setRes(r);
    setTimeout(() => fx(r.correct ? "correct" : "wrong"), 60);
    // Session + lifetime bookkeeping.
    const streak = r.correct ? s.streak + 1 : 0;
    const ns = { ...s, n: s.n + 1, right: s.right + (r.correct ? 1 : 0), streak, bestStreak: Math.max(s.bestStreak, streak), times: [...s.times, ms],
      cats: { ...s.cats, [q.kat]: { r: ((s.cats[q.kat] || {}).r || 0) + (r.correct ? 1 : 0), n: ((s.cats[q.kat] || {}).n || 0) + 1 } } };
    const record = streak > store.best && streak >= 3;
    if (record && !s.newBest) ns.newBest = true;
    setNewBest(record);
    setS(ns);
    const entry = { id: q.id, kat: q.kat, katName: q.katName, katEmoji: q.katEmoji, schw: q.schw, wert: q.wert, typ: q.typ, text: q.text, options: q.options, correctIndex: r.correctIndex, erkl: r.erkl || "" };
    update(st => {
      const bump = (m, k) => ({ ...m, [k]: { r: ((m[k] || {}).r || 0) + (r.correct ? 1 : 0), n: ((m[k] || {}).n || 0) + 1 } });
      const wrong = st.wrong.filter(w => w.id !== q.id);
      const n = { ...st, best: Math.max(st.best, streak), wrong: r.correct ? wrong : [entry, ...wrong].slice(0, 60) };
      if (!s.review) Object.assign(n, { right: st.right + (r.correct ? 1 : 0), played: st.played + 1, cats: bump(st.cats, q.kat), tiers: bump(st.tiers, q.schw) });
      return n;
    });
    // Prefetch while the explanation is read (the answered question is closed server-side already).
    if (!s.review && !(total > 0 && ns.n >= total)) fetchQ().then(setNext).catch(() => {});
    setTimeout(() => {
      if (fb.current && fb.current.scrollIntoView) fb.current.scrollIntoView({ block: "nearest", behavior: reduced() ? "auto" : "smooth" });
      nextBtn.current && nextBtn.current.focus({ preventScroll: true });
    }, 380);
  };
  const go = () => { feel("tap"); if (last) { finish(s); return; } window.scrollTo({ top: 0, behavior: reduced() ? "auto" : "smooth" }); load(); };
  // Keyboard: 1–8 / A–H answer, Enter / Space → next.
  useEffect(() => {
    const k = e => {
      if (e.target && /input|textarea/i.test(e.target.tagName)) return;
      if (res && (e.key === "Enter" || e.key === " ")) { e.preventDefault(); go(); return; }
      if (!q || res) return;
      const i = /^[1-8]$/.test(e.key) ? Number(e.key) - 1 : /^[a-h]$/i.test(e.key) ? e.key.toLowerCase().charCodeAt(0) - 97 : -1;
      if (i >= 0 && i < q.options.length) answer(i);
    };
    document.addEventListener("keydown", k);
    return () => document.removeEventListener("keydown", k);
  });

  const kat = q ? katById[q.kat] || { name: q.katName, emoji: q.katEmoji, farbe: "#ffc93c" } : null;
  const tier = q && TIER_META[q.schw];
  const [qText, ...qExtra] = q ? String(q.text).split("\n") : [""];
  const n = q ? q.options.length : 0;
  const locked = picked != null || !!res;
  const timeUp = res && picked === -1;
  const shownN = s.n + (res ? 0 : 1);
  return html`<div class="u-play">
    <header class="u-bar">
      <button class="u-icon u-end" onClick=${() => finish(s)} aria-label="Übung beenden">✕</button>
      <div class="u-prog" aria-label=${total ? `Frage ${Math.min(shownN, total)} von ${total}` : `Frage ${shownN}`}>
        <b>${s.review ? "🔁 " : ""}${total ? `${Math.min(shownN, total)} / ${total}` : `Frage ${shownN}`}</b>
        ${total > 0 && html`<span class="u-prog-bar" aria-hidden="true"><i style=${`width:${(s.n / total) * 100}%`}></i></span>`}
      </div>
      <div class="u-bar-r">
        <span class=${cx("chip", s.streak >= 3 ? "gold flame" : "")} aria-label=${`Serie ${s.streak}`}>🔥 ${s.streak}</span>
        <span class="chip green" aria-label=${`${s.right} richtig`}>✓ ${s.right}</span>
        <button class="u-icon" onClick=${toggleMute} aria-pressed=${!muted} aria-label=${muted ? "Sounds an" : "Sounds aus"}>${muted ? "🔇" : "🔊"}</button>
      </div>
    </header>

    ${loading && !q && html`<div class="p-wait"><div class="spin-banana">🍌</div><p>Frage wird gemischt …</p></div>`}
    ${err === "none" && html`<div class="u-empty pop-in"><div class="big-emoji">🙈</div><h2>Keine Fragen gefunden</h2><p class="muted">Für diese Auswahl gibt es gerade keine Fragen. Probier ein anderes Thema oder eine andere Stufe.</p><button class="btn block" onClick=${() => finish(s)}>‹ Zur Auswahl</button></div>`}
    ${err === "net" && html`<div class="u-empty pop-in"><div class="big-emoji">📡</div><h2>Keine Verbindung</h2><p class="muted">Das iPad ist gerade nicht erreichbar. Gleiches WLAN?</p><button class="btn block" onClick=${load}>🔄 Nochmal versuchen</button><button class="btn ghost block" onClick=${() => finish(s)}>‹ Zur Auswahl</button></div>`}

    ${q && !err && html`<section class=${cx("u-q", locked && "answered")} key=${q.id + ":" + s.n}>
      ${deadline && html`<${Timer} d=${deadline} done=${locked} />`}
      <div class="u-meta">
        <span class="chip u-meta-kat" style=${`--c:${accent(kat.farbe)}`}><span aria-hidden="true">${kat.emoji}</span> ${kat.name}</span>
        ${tier && html`<span class="chip u-meta-tier" style=${`--c:${tier.c}`}><span aria-hidden="true">${tier.emoji}</span> ${tier.name}</span>`}
        ${q.wert > 0 && html`<span class="chip u-meta-wert">💰 ${fmtNum(q.wert)}</span>`}
      </div>
      <${Q} t=${qText} />
      ${qExtra.length > 0 && html`<div class="u-emoji-line" aria-label="Emoji-Rätsel">${qExtra.join(" ")}</div>`}
      <div class=${cx("p-opts", n > 4 && "many", n <= 2 && "duo", locked && "is-locked")}>${q.options.map((o, i) => {
        const ok = res && res.correctIndex === i, bad = res && picked === i && !res.correct;
        return html`<${OptButton} o=${{ id: i, text: o }} i=${i} chosen=${picked === i && !res} pending=${picked === i && !res} locked=${locked && !ok && !bad}
          klass=${cx(ok && "u-ok", bad && "u-bad", res && !ok && !bad && "u-dim")} onClick=${() => answer(i)}>
          ${ok && html`<span class="u-mark ok" aria-hidden="true"><i class="ck"></i></span>`}${bad && html`<span class="u-mark bad" aria-hidden="true">✕</span>`}
        <//>`; })}</div>
      ${res && html`<div class=${cx("u-fb", res.correct ? "ok" : "nope")} ref=${fb} role="status" aria-live="polite">
        <div class="u-fb-top">
          <span class="stamp">${res.correct ? "RICHTIG!" : timeUp ? "ZEIT UM!" : "FALSCH!"}</span>
          <span class="u-fb-line">${res.correct ? (s.streak >= 2 ? html`Serie <b>🔥 ${s.streak}</b>` : html`<b>+1</b> Treffer`) : html`Richtig: <b>${String.fromCharCode(65 + res.correctIndex)} — ${q.options[res.correctIndex]}</b>`}</span>
        </div>
        ${newBest && html`<p class="u-record pop-in">🏆 Neuer Rekord: ${s.streak} in Folge!</p>`}
        ${res.erkl && html`<p class="u-erkl"><span aria-hidden="true">💡</span> ${res.erkl}</p>`}
        <button class="btn big block u-next" ref=${nextBtn} onClick=${go}>${last ? "Auswertung 🏁" : "Nächste Frage ▶"}</button>
      </div>`}
    </section>`}
  </div>`;
}

// ---------- summary ----------
function Summary({ s, store, katById, again, review, back }) {
  const acc = pct(s.right, s.n);
  const face = acc >= 70 ? "jubel" : acc >= 40 ? "denk" : "frust";
  const title = acc >= 90 ? "Affenstark!" : acc >= 70 ? "Richtig gut!" : acc >= 40 ? "Solide!" : "Weiter üben!";
  const avg = s.times.length ? s.times.reduce((a, b) => a + b, 0) / s.times.length / 1000 : 0;
  const cats = Object.entries(s.cats).sort((a, b) => b[1].n - a[1].n);
  useEffect(() => { setTimeout(() => fx(acc >= 50 ? "correct" : "lock"), 300); }, []);
  return html`<div class="u-sum fade-in">
    <div class="idle-stage u-sum-stage"><div class="idle-glow"></div><${Monkey} wire=${avatar} face=${face} anim=${face === "jubel" ? "jubel" : face} size=${130} /></div>
    <h1 class="u-sum-title">${s.review ? "🔁 " : ""}${title}</h1>
    <div class="u-ring" style=${`--p:${acc}`} role="img" aria-label=${`${s.right} von ${s.n} richtig, ${acc} Prozent`}>
      <div><b>${s.right}<i>/${s.n}</i></b><small>richtig</small></div>
    </div>
    <div class="u-sum-grid">
      <div><b>${acc} %</b><small>Trefferquote</small></div>
      <div class=${cx(s.newBest && "rec")}><b>🔥 ${s.bestStreak}</b><small>${s.newBest ? "Neuer Rekord!" : "Beste Serie"}</small></div>
      <div><b>${avg ? fmtNum(Math.round(avg * 10) / 10) + " s" : "–"}</b><small>Ø Antwortzeit</small></div>
    </div>
    ${cats.length > 1 && html`<ul class="u-sum-cats">${cats.map(([id, c]) => { const k = katById[id] || { name: id, emoji: "❔", farbe: "#ffc93c" };
      return html`<li style=${`--c:${accent(k.farbe)}`}><span aria-hidden="true">${k.emoji}</span><b>${k.name}</b><span class="u-sc-bar" aria-hidden="true"><i style=${`width:${pct(c.r, c.n)}%`}></i></span><small>${c.r}/${c.n}</small></li>`; })}</ul>`}
    <div class="u-sum-btns">
      ${store.wrong.length > 0 && html`<button class="btn green big block u-review-go" onClick=${review}>🔁 Falsche wiederholen (${Math.min(10, store.wrong.length)})</button>`}
      <button class=${cx("btn big block", store.wrong.length > 0 && "ghost")} onClick=${again}>▶ Nochmal</button>
      <button class="btn ghost block" onClick=${back}>‹ Zur Auswahl</button>
    </div>
  </div>`;
}

const root = document.getElementById("app");
root.textContent = "";
render(html`<${App} />`, root);
