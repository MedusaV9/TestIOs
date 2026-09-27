// Übungsmodus: solo practice on the phone against the iPad's question bank.
import { html, render, useState, useEffect } from "../vendor/preact-htm.js";
import { api, cx, fmtMM, deviceToken, haptic, OPTION_STYLE, DIFF } from "../lib/core.js";

const device = deviceToken();

function App() {
  const [kats, setKats] = useState([]);
  const [kat, setKat] = useState("");
  const [schw, setSchw] = useState("");
  const [familie, setFamilie] = useState(false);
  const [q, setQ] = useState(null);
  const [res, setRes] = useState(null);
  const [picked, setPicked] = useState(null);
  const [stats, setStats] = useState({ gespielt: 0, richtig: 0, serie: 0, beste: 0 });
  const [none, setNone] = useState(false);
  useEffect(() => { api("/api/kategorien").then(setKats).catch(() => {}); next(); }, []);
  async function next(k = kat, s = schw, f = familie) {
    setRes(null); setPicked(null); setNone(false);
    try {
      const x = await api(`/api/uebung/frage?${new URLSearchParams({ device, kat: k, schw: s, familie: f ? "1" : "0" })}`);
      setQ(x); setStats(x.stats);
    } catch (_) { setQ(null); setNone(true); }
  }
  async function answer(i) {
    if (res || picked != null) return;
    setPicked(i);
    try { const r = await api("/api/uebung/antwort", { id: q.id, index: i, device }); setRes(r); setStats(r.stats); haptic(r.correct ? "success" : "error"); }
    catch (_) { next(); }
  }
  return html`<div class="phone uebung">
    <header class="join-head"><div class="j-logo">🎯 <span>ÜBUNGS</span><b>MODUS</b></div><a class="chip" href="/">‹ Mitspielen</a></header>
    <div class="u-stats"><div><b>${stats.serie}</b><small>Serie 🔥</small></div><div><b>${stats.richtig}/${stats.gespielt}</b><small>richtig</small></div><div><b>${stats.beste}</b><small>Rekord</small></div></div>
    <div class="u-filter">
      <select value=${kat} onChange=${e => { setKat(e.target.value); next(e.target.value, schw, familie); }}><option value="">🌍 Alle Themen</option>${kats.map(k => html`<option value=${k.id}>${k.emoji} ${k.name}</option>`)}</select>
      <select value=${schw} onChange=${e => { setSchw(e.target.value); next(kat, e.target.value, familie); }}><option value="">🎚️ Alle Stufen</option>${Object.entries(DIFF).map(([id, [l]]) => html`<option value=${id}>${l}</option>`)}</select>
      <label class="j-save"><input type="checkbox" checked=${familie} onChange=${e => { setFamilie(e.target.checked); next(kat, schw, e.target.checked); }} /> 👪 nur kindgerechte Fragen</label>
    </div>
    ${none && html`<div class="p-idle"><div class="big-emoji">🙈</div><h2>Keine Frage gefunden</h2><p class="muted">Andere Kategorie oder Schwierigkeit wählen.</p></div>`}
    ${q && html`<div class="p-choice" key=${q.id}>
      <div class="chip-row"><span class="chip">${q.katEmoji} ${q.katName}</span><span class="chip">${(DIFF[q.schw] || [q.schw])[0]}</span><span class="chip gold">${fmtMM(q.wert)}</span></div>
      <div class="p-question" style="font-size:20px">${q.text}</div>
      <div class="p-opts">${q.options.map((o, i) => { const st = OPTION_STYLE[i % 8]; const ok = res && res.correctIndex === i; const bad = res && picked === i && !res.correct;
        return html`<button class=${cx("p-opt", picked === i && !res && "chosen", ok && "u-ok", bad && "u-bad", res && !ok && !bad && "dim")} style=${`--c:${st.c};--d:${st.d};animation-delay:${i * 60}ms`} onClick=${() => answer(i)}>
          <span class="p-opt-badge"><b>${st.l}</b><i>${st.e}</i></span><span class="p-opt-text">${o}</span></button>`; })}</div>
      ${res && html`<div class=${cx("p-reveal", res.correct ? "ok" : "nope")} style="flex:none"><div class="stamp pop-in">${res.correct ? "RICHTIG!" : "FALSCH!"}</div>${res.erkl && html`<p class="rev-detail">${res.erkl}</p>`}</div>
        <button class="btn big block" onClick=${() => next()}>Nächste Frage ▶</button>`}
    </div>`}
  </div>`;
}

render(html`<${App} />`, document.getElementById("app"));
