// Renders every PlayerPrompt kind the engine emits. Used by the phones and by
// the stage for pass-and-play seats. `send(action)` gets the wire action.
// Inputs lock optimistically (useCommit): the tap feels instant, a pending
// badge shows until the server echoes it, lost actions are resent / rolled back.
// `extra` (phones only): { phase, ergebnis, stats, players, ohneScreen }.
import { html, useState, useEffect, useRef, useLayoutEffect } from "../vendor/preact-htm.js";
import { cx, fmtMM, fmtNum, fmtDelta, OPTION_STYLE, serverNow, useFrame, feel, useCommit } from "./core.js";
import { Monkey } from "./ui.js";

export function Prompt({ p, send, me, compact, extra }) {
  const x = extra || {};
  switch (p.kind) {
    case "idle": return html`<${Idle} p=${p} me=${me} x=${x} compact=${compact} />`;
    case "choice": return html`<${Choice} p=${p} send=${send} key=${p.question} />`;
    case "multiChoice": return html`<${MultiChoice} p=${p} send=${send} key=${p.question} />`;
    case "buzzer": return html`<${Buzzer} p=${p} send=${send} key=${p.question || "buzz"} />`;
    case "number": return html`<${NumberInput} p=${p} send=${send} key=${p.question} />`;
    case "wager": return html`<${Wager} p=${p} send=${send} key=${p.title} />`;
    case "order": return html`<${Order} p=${p} send=${send} key=${p.question} />`;
    case "text": return html`<${TextInput} p=${p} send=${send} key=${p.question} />`;
    case "tapFrenzy": return html`<${Taps} p=${p} send=${send} />`;
    case "chips": return html`<${Chips} p=${p} send=${send} key=${p.question} />`;
    case "pickPlayer": return html`<${PickPlayer} p=${p} send=${send} key=${p.title} />`;
    case "bank": return html`<${Bank} p=${p} send=${send} />`;
    case "cheer": return html`<${Cheer} p=${p} send=${send} me=${me} />`;
    case "confirm": return html`<${Confirm} p=${p} send=${send} key=${p.title} />`;
    case "binary": return html`<${Binary} p=${p} send=${send} key=${p.title} />`;
    case "vote": return html`<${Vote} p=${p} send=${send} key=${p.title} />`;
    case "reveal": return html`<${Reveal} p=${p} me=${me} x=${x} compact=${compact} />`;
    case "explain": return html`<${Explain} p=${p} send=${send} key=${p.title} />`;
    case "actions": return html`<${Actions} p=${p} send=${send} compact=${compact} />`;
    case "feedback": return html`<${Feedback} p=${p} send=${send} />`;
    case "cards": return html`<${Cards} p=${p} send=${send} compact=${compact} />`;
    default: return html`<div class="p-idle"><h2>…</h2></div>`;
  }
}

// ---------- shared bits ----------
/** Countdown bar with seconds, urgency pulse and soft ticks in the last 5 s. */
export function Timer({ d, done }) {
  const first = useRef({ d: null, total: 0 });
  const now = useFrame(!!d && !done);
  const lastSec = useRef(null);
  const remain = d ? Math.max(0, d - now) : 0;
  const secs = Math.ceil(remain / 1000);
  const hot = remain > 0 && remain <= 5000;
  useEffect(() => { if (hot && !done && lastSec.current !== secs) feel("tick"); lastSec.current = secs; }, [secs]);
  if (!d) return null;
  if (first.current.d !== d) first.current = { d, total: Math.max(1000, d - serverNow()) };
  const frac = Math.max(0, Math.min(1, remain / first.current.total));
  return html`<div class=${cx("p-timer", hot && "hot", remain === 0 && "over", done && "done")} role="timer" aria-label=${done ? "Eingeloggt" : `Noch ${secs} Sekunden`}>
    <div class="pt-bar" aria-hidden="true"><i style=${`transform:scaleX(${frac})`}></i></div>
    <b class="pt-secs" key=${done ? "lk" : hot ? secs : "s"} aria-hidden="true">${done ? html`<i class="lk"></i>` : secs}</b>
  </div>`;
}
/** The question card; the font steps down with the text length (see .q-len-*). */
export const Q = ({ t }) => (t ? html`<h2 class=${cx("p-question", "q-len-" + (t.length > 140 ? 4 : t.length > 90 ? 3 : t.length > 50 ? 2 : 1))}>${t}</h2>` : null);
const Sub = ({ t }) => (t ? html`<p class="p-sub">${t}</p>` : null);

/** "Eingeloggt" banner: pending (sending …) or confirmed. */
function LockNote({ pend, text = "Eingeloggt — Daumen drücken!", tries }) {
  return html`<div class=${cx("p-locked-note", pend ? "pending" : "ok")} role="status">
    ${pend ? html`<span class="ln-spin"></span><span>${pend.n > 1 ? `Sende erneut (${pend.n}) …` : "Wird übertragen …"}</span>`
      : html`<span class="ln-check"><i class="ck"></i></span><span>${text}</span>`}
  </div>`;
}

export function OptButton({ o, i, chosen, onClick, locked, pending, children, klass }) {
  const st = OPTION_STYLE[i % 8];
  return html`<button class=${cx("p-opt", chosen && "chosen", chosen && pending && "pending", chosen && locked && !pending && "locked-in", o.removed && "removed", locked && !chosen && "dim", klass)}
      style=${`--c:${st.c};--d:${st.d};animation-delay:${i * 55}ms`} disabled=${o.removed || (locked && !chosen)} onClick=${onClick} aria-pressed=${!!chosen} aria-label=${`${st.l}: ${o.text}${o.removed ? " (gestrichen)" : ""}`}>
    <span class="p-opt-badge" aria-hidden="true"><b>${st.l}</b><i>${st.e}</i></span><span class="p-opt-text">${o.text}</span>
    ${chosen && html`<span class=${cx("p-lock", !pending && "on")} aria-hidden="true">${pending ? html`<span class="ln-spin dark"></span>` : html`<i class="lk"></i>`}</span>`}${children}
  </button>`;
}

// ---------- waiting ----------
const PHASE_HINT = {
  lobby: ["🍌", "Gleich geht's los — die Show startet auf dem großen Bildschirm"],
  intro: ["🎬", "Augen auf die Bühne!"],
  "kategorie-wahl": ["🗳️", "Die Kategorie wird gewählt …"],
  erklaerkarte: ["📜", "Gleich kommen die Regeln"],
  frage: ["📺", "Schau auf die Bühne"],
  aufloesung: ["🥁", "Die Auflösung läuft …"],
  rad: ["🎡", "Das Glücksrad dreht sich …"],
  zwischenstand: ["📊", "Zwischenstand auf der Bühne"],
  halbzeit: ["⏸️", "Halbzeit — kurz die Beine vertreten"],
  pause: ["☕", "Kurz durchatmen — gleich geht's weiter"],
  highlights: ["🎞️", "Die Highlights laufen auf dem Bildschirm"],
  siegerehrung: ["🏆", "Siegerehrung auf der Bühne!"],
  ende: ["🎬", "Danke fürs Mitspielen!"],
  brettspiel: ["🎲", "Warte auf deinen Zug"],
};
const TIPS = [
  "⚡ Schnell antworten bringt Speed-Bonus",
  "🔥 Ab 3 richtigen in Folge: Streak ×1,5 — ab 5 sogar ×2",
  "🃏 Joker unten antippen — manche kann man kaufen",
  "🌬️ Wer hinten liegt, bekommt Rückenwind",
  "🫙 Strafen landen im Jackpot-Glas",
];

function Idle({ p, me, x, compact }) {
  const t = String(p.title || "");
  const face = /💥|MATSCH|matschig|Falsch|❌|Pleite|raus/i.test(t) ? "frust" : /GEWONNEN|Richtig|✅|🎉|👑|drin/i.test(t) ? "jubel" : /…|\.\.\.|dreht|wartet|Warte|wählt/i.test(t) ? "denk" : "neutral";
  const phase = x.phase || "";
  const standings = phase === "zwischenstand" || phase === "halbzeit";
  const [tip, setTip] = useState(0);
  useEffect(() => { if (phase !== "lobby") return; const iv = setInterval(() => setTip(i => (i + 1) % TIPS.length), 4200); return () => clearInterval(iv); }, [phase]);
  let hint = PHASE_HINT[phase] || ["📺", "Schau auf die Bühne"];
  if (x.ohneScreen && /Bühne|Bildschirm/.test(hint[1])) hint = ["🎙️", "Hör auf den Game Master"];
  const round = standings && /Runde: *([+−-]?[\d.]+.*)$/.exec(p.subtitle || "");
  const roundVal = round ? round[1] : null;
  const neg = roundVal && /^[−-]/.test(roundVal);
  const st = x.stats;
  const played = st ? st.richtig + st.falsch : 0;
  if (compact) return html`<div class="p-idle compact"><h2>${p.title}</h2>${p.subtitle && html`<p class="muted">${p.subtitle}</p>`}</div>`;
  return html`<div class=${cx("p-idle", "ph-" + phase, standings && "standings")}>
    ${me && !standings && html`<div class="idle-stage"><div class="idle-glow"></div><${Monkey} wire=${me.avatar} face=${face} anim=${phase === "lobby" ? "dance" : face === "jubel" ? "jubel" : face === "denk" ? "denk" : face === "frust" ? "frust" : "idle"} size=${150} /></div>`}
    ${standings ? html`<div class="st-hero pop-in">
        <small>Dein Platz</small><b class="st-place">${me ? me.platz : "?"}<i>/${x.players || "?"}</i></b>
        ${roundVal ? html`<span class=${cx("st-round", neg ? "neg" : "pos")}>Diese Runde: ${roundVal}</span>` : p.subtitle && html`<span class="st-round">${p.subtitle}</span>`}
      </div>`
      : html`<h2 class="idle-title">${p.title}</h2>${p.subtitle && html`<p class="idle-sub">${p.subtitle}</p>`}`}
    ${phase === "lobby" && x.players > 0 && html`<div class="idle-count"><b>${x.players}</b> ${x.players === 1 ? "Affe" : "Affen"} im Raum</div>`}
    ${!standings && html`<div class="look-up">${!x.ohneScreen && phase !== "lobby" && phase !== "ende" && html`<i class="lu-live" aria-hidden="true"></i>`}<span>${hint[0]}</span>${hint[1]}</div>`}
    ${phase === "lobby" && html`<div class="idle-tip" key=${tip}>${TIPS[tip]}</div>`}
    ${played > 0 && !standings && html`<div class="mini-stats">
      <span><b>${st.richtig}</b><small>✅ richtig</small></span><span><b>${st.falsch}</b><small>❌ falsch</small></span><span><b>${st.laengsteSerie}</b><small>🔥 Serie</small></span>
    </div>`}
  </div>`;
}

// ---------- answers ----------
function Choice({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  const locked = pend != null || (p.chosen != null && !p.secondTry);
  const n = p.options.length;
  return html`<div class="p-choice">
    <${Timer} d=${p.deadline} done=${locked} />
    ${p.hint && html`<div class="p-hint">💡 ${p.hint}</div>`}
    <${Q} t=${p.question} />
    <div class=${cx("p-opts", n > 4 && "many", n <= 2 && "duo", locked && "is-locked")}>${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${shown === o.id} locked=${locked} pending=${!!pend}
      onClick=${() => { if (!locked && !o.removed && !(p.secondTry && p.chosen === o.id)) commit({ type: "choose", value: o.id }, o.id); }} />`)}</div>
    ${p.secondTry && !pend && html`<p class="p-hint">↩️ Rückgaberecht: wähle eine andere Antwort (50 % Gewinn)</p>`}
    ${locked && html`<${LockNote} pend=${pend} />`}
  </div>`;
}

function MultiChoice({ p, send }) {
  const [sel, setSel] = useState(new Set(p.chosen));
  const [pend, commit] = useCommit(send, p.locked);
  const locked = p.locked || !!pend;
  const toggle = id => { if (locked) return; const n = new Set(sel); n.has(id) ? n.delete(id) : n.size < p.required && n.add(id); setSel(n); feel("tap"); };
  return html`<div class="p-choice">
    <${Timer} d=${p.deadline} done=${locked} /><${Q} t=${p.question} />
    <div class="p-need"><span>Wähle <b>${p.required}</b> Antworten</span><span class="need-dots">${Array.from({ length: p.required }, (_, i) => html`<i class=${i < sel.size ? "on" : ""}></i>`)}</span></div>
    <div class=${cx("p-opts", p.options.length > 5 && "many")}>${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${sel.has(o.id)} locked=${locked} pending=${!!pend} onClick=${() => toggle(o.id)} />`)}</div>
    ${locked ? html`<${LockNote} pend=${pend} />`
      : html`<button class="btn green block big" disabled=${sel.size !== p.required} onClick=${() => commit({ type: "multiChoose", list: [...sel] })}>🔒 Einloggen (${sel.size}/${p.required})</button>`}
  </div>`;
}

function Buzzer({ p, send }) {
  const [pend, commit] = useCommit(send, p.pressed, { tries: 2, every: 1500 });
  const locked = p.lockedUntil && p.lockedUntil > serverNow();
  const pressed = p.pressed || !!pend;
  const armed = p.armed && !pressed && !locked;
  return html`<div class="p-buzzer">
    ${p.question && html`<${Q} t=${p.question} />`}
    ${p.hint && html`<div class="p-hint">💡 ${p.hint}</div>`}
    <div class="buzz-wrap">
      ${armed && html`<span class="buzz-ring"></span><span class="buzz-ring r2"></span>`}
      <button class=${cx("buzz-btn", armed && "armed", pressed && "pressed")} disabled=${!p.armed || pressed || locked}
        onPointerDown=${() => { if (p.armed && !pressed && !locked) { feel("heavy"); commit({ type: "buzz", at: serverNow() }); } }}>
        <span>${pressed ? "GEBUZZT!" : locked ? "GESPERRT" : p.armed ? "BUZZ!" : "WARTEN …"}</span>
      </button>
    </div>
    ${pressed && html`<${LockNote} pend=${pend} text="Gebuzzt — jetzt laut antworten!" />`}
    ${!p.armed && !pressed && !locked && html`<p class="p-sub">Gleich wird der Buzzer scharf …</p>`}
  </div>`;
}

function Stepper({ value, set, min, max, step, fmt }) {
  const bump = d => { set(Math.min(max, Math.max(min, Math.round((value + d * step) / step) * step))); feel("tap"); };
  return html`<div class="stepper">
    <button class="st-btn" onClick=${() => bump(-10)} aria-label="minus 10">−10</button><button class="st-btn" onClick=${() => bump(-1)} aria-label="minus">−</button>
    <button class="st-btn" onClick=${() => bump(1)} aria-label="plus">+</button><button class="st-btn" onClick=${() => bump(10)} aria-label="plus 10">+10</button>
  </div>`;
}

function LockedValue({ title, value, unit, pend, text }) {
  return html`<div class="p-locked">
    ${title}
    <div class="lock-card pop-in"><span class=${cx("lock-ico", pend && "pend")} key=${pend ? "p" : "ok"} aria-hidden="true">${pend ? html`<span class="ln-spin"></span>` : html`<i class="lk"></i>`}</span><div class="big-val">${value}${unit && html` <small>${unit}</small>`}</div></div>
    <${LockNote} pend=${pend} text=${text} />
  </div>`;
}

function NumberInput({ p, send }) {
  const toSlider = v => (p.log ? (Math.log(v) - Math.log(p.min)) / (Math.log(p.max) - Math.log(p.min)) : (v - p.min) / (p.max - p.min));
  const fromSlider = f => (p.log ? Math.exp(Math.log(p.min) + f * (Math.log(p.max) - Math.log(p.min))) : p.min + f * (p.max - p.min));
  const snap = v => Math.min(p.max, Math.max(p.min, Math.round(v / p.step) * p.step));
  const [v, setV] = useState(p.current != null ? p.current : snap((p.min + p.max) / 2));
  const [pend, commit] = useCommit(send, p.locked);
  if (p.locked || pend) return html`<${LockedValue} title=${html`<${Q} t=${p.question} />`} value=${fmtNum(pend ? pend.value : p.current)} unit=${p.unit} pend=${pend} text="Tipp eingeloggt" />`;
  const pct = Math.round(toSlider(v) * 1000) / 10;
  return html`<div class="p-number">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <div class="big-val" key=${v}>${fmtNum(v)} <small>${p.unit}</small></div>
    <input type="range" min="0" max="1000" value=${Math.round(toSlider(v) * 1000)} style=${`--pct:${pct}%`} onInput=${e => setV(snap(fromSlider(Number(e.target.value) / 1000)))} />
    <div class="range-ends"><span>${fmtNum(p.min)}</span><span>${fmtNum(p.max)}</span></div>
    <${Stepper} value=${v} set=${setV} min=${p.min} max=${p.max} step=${p.step} fmt=${x => fmtNum(x)} />
    <input class="direct" type="number" inputmode="decimal" value=${v} aria-label="Zahl direkt eingeben" onChange=${e => setV(snap(Number(e.target.value)))} />
    <button class="btn green block big" onClick=${() => commit({ type: "number", value: v }, v)}>🔒 Tipp abgeben</button>
  </div>`;
}

function Wager({ p, send }) {
  const [v, setV] = useState(p.current != null ? p.current : p.min);
  const [pend, commit] = useCommit(send, p.locked);
  if (p.locked || pend) return html`<${LockedValue} title=${html`<h2 class="p-title">${p.title}</h2>`} value=${fmtMM(pend ? pend.value : p.current || 0)} pend=${pend} text="Einsatz steht" />`;
  const pct = p.max > p.min ? ((v - p.min) / (p.max - p.min)) * 100 : 0;
  const mid = Math.round((p.min + p.max) / 2 / p.step) * p.step;
  return html`<div class="p-number">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class=${cx("big-val gold-text", v === p.max && v > 0 && "allin")} key=${v}>${fmtMM(v)}</div>
    <input type="range" min=${p.min} max=${p.max} step=${p.step} value=${v} style=${`--pct:${pct}%`} onInput=${e => setV(Number(e.target.value))} />
    <div class="quick-bets">${[[p.min, "Min"], [mid, "Hälfte"], [p.max, "ALL-IN"]].map(([x, l]) => html`<button class=${cx("qb", v === x && "on", l === "ALL-IN" && "allin")} onClick=${() => { setV(x); feel("tap"); }}><small>${l}</small><b>${fmtNum(x)}</b></button>`)}</div>
    <button class="btn block big" onClick=${() => commit({ type: "wager", value: v }, v)}>🎲 Setzen</button>
  </div>`;
}

/** Sort list: drag the grip (pointer events — touch, pen, mouse) or use the ▲/▼ buttons.
 *  Reorders animate with FLIP; every change is sent right away, the button locks in. */
function Order({ p, send }) {
  const [order, setOrder] = useState(p.order && p.order.length ? p.order : p.items.map(i => i.id));
  const [moved, setMoved] = useState(null);
  const [dragId, setDragId] = useState(null);
  const [pend, commit] = useCommit(send, p.locked);
  const locked = p.locked || !!pend;
  const byId = Object.fromEntries(p.items.map(i => [i.id, i]));
  const list = useRef(null);
  const flip = useRef(null);
  const drag = useRef(null);
  const lis = () => (list.current ? [...list.current.querySelectorAll("li[data-id]")] : []);
  // Visual tops before a reorder → after the render every row slides from there (FLIP).
  const reorder = (n, movedId) => {
    const tops = {};
    for (const li of lis()) tops[li.dataset.id] = li.getBoundingClientRect().top;
    for (const li of lis()) { li.style.transition = "none"; li.style.transform = ""; }
    flip.current = tops;
    setOrder(n);
    setMoved(movedId != null ? { id: movedId, t: Date.now() } : null);
    send({ type: "order", list: n });
  };
  useLayoutEffect(() => {
    const tops = flip.current;
    if (!tops) return;
    flip.current = null;
    const rows = lis();
    for (const li of rows) {
      const was = tops[li.dataset.id];
      const dy = was == null ? 0 : was - li.getBoundingClientRect().top;
      li.style.transition = "none";
      li.style.transform = dy ? `translateY(${dy}px)` : "";
    }
    const raf = requestAnimationFrame(() => requestAnimationFrame(() => rows.forEach(li => { li.style.transition = ""; li.style.transform = ""; })));
    return () => cancelAnimationFrame(raf);
  }, [order]);
  const mv = (pos, d) => { const to = pos + d; if (to < 0 || to >= order.length) return; const n = [...order]; [n[pos], n[to]] = [n[to], n[pos]]; feel("tap"); reorder(n, n[to]); };

  const onDown = (e, id) => {
    if (locked || drag.current || (e.pointerType === "mouse" && e.button !== 0)) return;
    e.preventDefault();
    const rows = lis();
    const idx = order.indexOf(id);
    if (idx < 0 || !rows[idx]) return;
    const rects = rows.map(li => { const r = li.getBoundingClientRect(); return { top: r.top + scrollY, h: r.height }; });
    const gap = rects.length > 1 ? rects[1].top - (rects[0].top + rects[0].h) : 8;
    try { e.currentTarget.setPointerCapture(e.pointerId); } catch (_) {}
    drag.current = { id, idx, to: idx, y0: e.clientY + scrollY, rects, rows, gap, pid: e.pointerId };
    setDragId(id);
    feel("tap");
  };
  const onMove = e => {
    const s = drag.current;
    if (!s || e.pointerId !== s.pid) return;
    e.preventDefault();
    // Auto-scroll near the screen edges (long lists on small phones).
    if (e.clientY > innerHeight - 90) scrollBy(0, 10); else if (e.clientY < 90) scrollBy(0, -10);
    const y = e.clientY + scrollY;
    const r = s.rects[s.idx];
    const lo = s.rects[0].top - r.top - 12, hi = s.rects[s.rects.length - 1].top + s.rects[s.rects.length - 1].h - (r.top + r.h) + 12;
    const dy = Math.max(lo, Math.min(hi, y - s.y0));
    s.rows[s.idx].style.transform = `translateY(${dy}px) scale(1.03)`;
    const center = r.top + r.h / 2 + dy;
    let to = 0;
    s.rects.forEach((q, i) => { if (i !== s.idx && center > q.top + q.h / 2) to++; });
    if (to !== s.to) { s.to = to; feel("tick"); }
    const step = r.h + s.gap;
    s.rows.forEach((li, i) => {
      if (i === s.idx) return;
      const shift = s.idx < to && i > s.idx && i <= to ? -step : s.idx > to && i >= to && i < s.idx ? step : 0;
      li.style.transform = shift ? `translateY(${shift}px)` : "";
    });
  };
  const onUp = e => {
    const s = drag.current;
    if (!s || e.pointerId !== s.pid) return;
    drag.current = null;
    setDragId(null);
    if (s.to !== s.idx) { const n = [...order]; n.splice(s.idx, 1); n.splice(s.to, 0, s.id); feel("lock"); reorder(n, s.id); }
    else { flip.current = Object.fromEntries(s.rows.map(li => [li.dataset.id, li.getBoundingClientRect().top])); for (const li of s.rows) { li.style.transition = "none"; li.style.transform = ""; } setOrder([...order]); }
  };
  return html`<div class="p-order">
    <${Timer} d=${p.deadline} done=${locked} /><${Q} t=${p.question} />
    ${!locked && html`<p class="p-sub ord-help">Am Griff <span class="ord-grip-mini" aria-hidden="true"></span> ziehen oder mit den Pfeilen schieben</p>`}
    <ol class=${cx("order-list", dragId != null && "is-dragging")} ref=${list} aria-label="Reihenfolge">${order.map((id, pos) => html`<li data-id=${id} key=${id}
        class=${cx(locked && "locked", dragId === id && "dragging", moved && moved.id === id && dragId == null && "hl")}>
      <span class=${cx("ord-grip", locked && "off")} onPointerDown=${e => onDown(e, id)} onPointerMove=${onMove} onPointerUp=${onUp} onPointerCancel=${onUp} aria-hidden="true">
        <span class="ord-n">${pos + 1}</span>${!locked && html`<i class="grip-dots"></i>`}
      </span>
      <span class="ord-t">${(byId[id] || {}).text}</span>
      ${!locked && html`<span class="ord-btns"><button onClick=${() => mv(pos, -1)} disabled=${pos === 0} aria-label=${`${(byId[id] || {}).text} nach oben`}><i class="tri up"></i></button><button onClick=${() => mv(pos, 1)} disabled=${pos === order.length - 1} aria-label=${`${(byId[id] || {}).text} nach unten`}><i class="tri down"></i></button></span>`}
    </li>`)}</ol>
    ${locked ? html`<${LockNote} pend=${pend} text="Reihenfolge eingeloggt" />`
      : html`<button class="btn green block big" onClick=${() => { send({ type: "order", list: order }); commit({ type: "confirm" }); }}>🔒 Reihenfolge einloggen</button>`}
  </div>`;
}

/** Keep a focused input (and the button under it) above the on-screen keyboard.
 *  iOS shrinks only the visual viewport, so watch it and scroll when needed. */
export function useKeepVisible(ref) {
  useEffect(() => {
    const vv = window.visualViewport;
    let t;
    const fit = () => {
      clearTimeout(t);
      t = setTimeout(() => {
        const el = ref.current;
        if (!el || document.activeElement !== el) return;
        const box = (el.closest("[data-kb]") || el).getBoundingClientRect();
        const top = vv ? vv.offsetTop : 0, H = vv ? vv.height : innerHeight;
        if (box.bottom > top + H - 8 || box.top < top + 8) scrollBy({ top: box.bottom - (top + H) + 16, behavior: "smooth" });
      }, 120);
    };
    const el = ref.current;
    el && el.addEventListener("focus", fit);
    vv && vv.addEventListener("resize", fit);
    window.addEventListener("resize", fit);
    return () => { clearTimeout(t); el && el.removeEventListener("focus", fit); vv && vv.removeEventListener("resize", fit); window.removeEventListener("resize", fit); };
  }, []);
}

function TextInput({ p, send }) {
  const [v, setV] = useState("");
  const [pend, commit] = useCommit(send, p.submitted);
  const inp = useRef(null);
  useKeepVisible(inp);
  const go = () => { const t = v.trim(); if (t) { document.activeElement && document.activeElement.blur && document.activeElement.blur(); commit({ type: "text", value: t }, t); } };
  if (p.submitted || pend) return html`<${LockedValue} title=${html`<${Q} t=${p.question} />`} value=${html`<span class="small">„${pend ? pend.value : p.submitted}“</span>`} pend=${pend} text="Abgeschickt" />`;
  const left = p.maxLength ? p.maxLength - v.length : null;
  return html`<div class="p-text">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <div class="text-box" data-kb>
      <div class="text-wrap"><input ref=${inp} class="text-in" maxlength=${p.maxLength} placeholder=${p.placeholder} aria-label=${p.placeholder || "Antwort"} value=${v} enterkeyhint="send" autocomplete="off" autocorrect="off" spellcheck="false" onInput=${e => setV(e.target.value)} onKeyDown=${e => e.key === "Enter" && go()} />
        ${p.maxLength && html`<small class=${cx("text-count", left <= 5 && "low")} aria-hidden="true">${v.length}/${p.maxLength}</small>`}</div>
      <button class="btn green block big" disabled=${!v.trim()} onClick=${go}>📨 Abschicken</button>
    </div>
  </div>`;
}

function Taps({ p, send }) {
  const pending = useRef(0);
  const [local, setLocal] = useState(0);
  useEffect(() => {
    const iv = setInterval(() => { if (pending.current) { send({ type: "taps", value: pending.current }); pending.current = 0; } }, 700);
    return () => { clearInterval(iv); if (pending.current) send({ type: "taps", value: pending.current }); };
  }, []);
  const n = p.count + pending.current;
  return html`<div class="p-taps">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <div class="tap-wrap">
      <button class=${cx("tap-btn", p.active && "armed")} disabled=${!p.active} onPointerDown=${e => { e.preventDefault(); pending.current++; setLocal(x => x + 1); feel("tap"); }}>
        <span class="tap-ico" key=${local % 2}>🥥</span><b key=${n}>${n}</b><small>${p.active ? "TIPP TIPP TIPP!" : "WARTEN …"}</small>
      </button>
      ${local > 0 && html`<span class="tap-plus" key=${local}>+1</span>`}
    </div>
  </div>`;
}

function Chips({ p, send }) {
  const [placed, setPlaced] = useState(p.placed && p.placed.length ? p.placed : p.options.map(() => 0));
  const [pend, commit] = useCommit(send, p.locked);
  const locked = p.locked || !!pend;
  const used = placed.reduce((a, b) => a + b, 0);
  const add = (i, d) => { const n = [...placed]; n[i] = Math.max(0, n[i] + d); if (n.reduce((a, b) => a + b, 0) > p.total) { feel("error"); return; } setPlaced(n); feel("tap"); };
  return html`<div class="p-chips">
    <${Timer} d=${p.deadline} done=${locked} /><${Q} t=${p.question} />
    <div class="p-need"><span>🪙 <b>${p.total - used}</b> von ${p.total} Chips übrig</span><span class="need-dots">${Array.from({ length: Math.min(p.total, 12) }, (_, i) => html`<i class=${i < p.total - used ? "on" : ""}></i>`)}</span></div>
    ${p.options.map((o, i) => { const st = OPTION_STYLE[i % 8]; return html`<div class=${cx("chip-line", placed[i] > 0 && "has")} style=${`--c:${st.c};--d:${st.d}`}>
      <span class="p-opt-badge"><b>${st.l}</b></span><span class="cl-t">${o.text}</span>
      ${!locked && html`<button class="cl-btn" onClick=${() => add(i, -1)} disabled=${placed[i] === 0} aria-label="Chip weg">−</button>`}<b class="cl-n" key=${placed[i]}>${placed[i]}</b>${!locked && html`<button class="cl-btn plus" onClick=${() => add(i, 1)} disabled=${used >= p.total} aria-label="Chip dazu">+</button>`}
    </div>`; })}
    ${locked ? html`<${LockNote} pend=${pend} text="Chips liegen" />` : html`<button class="btn green block big" onClick=${() => { send({ type: "chips", list: placed }); commit({ type: "confirm" }); }}>🔒 Chips setzen</button>`}
  </div>`;
}

function PickPlayer({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  const n = p.candidates.length;
  const size = n <= 2 ? 96 : n <= 4 ? 72 : 58;
  return html`<div class="p-pick">
    <${Timer} d=${p.deadline} done=${shown != null} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class=${cx("pick-grid", n <= 2 && "duo", n > 4 && "many", shown != null && "has-pick")} role="radiogroup" aria-label=${p.title}>${p.candidates.map((c, i) => html`<button class=${cx("pick-card", shown === c.id && "on")} style=${`animation-delay:${i * 60}ms`}
        role="radio" aria-checked=${shown === c.id} aria-label=${`${c.name}, Platz ${c.platz}, ${fmtMM(c.balance)}`}
        disabled=${shown != null && shown !== c.id} onClick=${() => shown == null && commit({ type: "pickPlayer", id: c.id }, c.id)}>
      ${c.platz > 0 && html`<span class="pk-rank" aria-hidden="true">${c.platz}.</span>`}
      ${shown === c.id && html`<span class="pk-check" aria-hidden="true"><i class="ck"></i></span>`}
      <span class="pk-av"><${Monkey} wire=${c.avatar} anim=${shown === c.id ? "jubel" : "none"} face=${shown === c.id ? "denk" : "neutral"} size=${size} /></span>
      <b>${c.name}</b><small>${fmtMM(c.balance)}</small></button>`)}</div>
    ${shown != null && html`<${LockNote} pend=${pend} text="Gewählt" />`}
  </div>`;
}

function Bank({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  return html`<div class="p-bank">
    <${Timer} d=${p.deadline} />
    <div class="bank-top"><div><small>Pott</small><b key=${p.pot}>${fmtMM(p.pot)}</b></div><div><small>Gebankt</small><b class="gold-text" key=${p.banked}>${fmtMM(p.banked)}</b></div></div>
    <button class="bank-btn" disabled=${p.pot <= 0} onClick=${() => { feel("lock"); send({ type: "bank" }); }}>🏦 BANK!</button>
    <${Q} t=${p.question} />
    <div class="p-opts">${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${shown === o.id} locked=${shown != null} pending=${!!pend} onClick=${() => shown == null && commit({ type: "choose", value: o.id }, o.id)} />`)}</div>
  </div>`;
}

const CHEER_BITS = ["🥁", "👏", "🔥", "🍌", "🎉", "💥"];
function Cheer({ p, send }) {
  const [local, setLocal] = useState(0);
  const [bits, setBits] = useState([]);
  const times = useRef([]);
  const [combo, setCombo] = useState(0);
  // Combo = taps in the last 1.5 s; decays when the drumming stops.
  useEffect(() => { if (!combo) return; const t = setTimeout(() => { times.current = times.current.filter(x => Date.now() - x < 1500); setCombo(times.current.length); }, 400); return () => clearTimeout(t); }, [combo, local]);
  const tap = e => {
    e.preventDefault();
    feel("tap");
    send({ type: "cheer" });
    const now = Date.now();
    times.current = [...times.current.filter(x => now - x < 1500), now];
    setCombo(times.current.length);
    setLocal(x => x + 1);
    setBits(b => [...b.slice(-9), { k: now + Math.random(), e: CHEER_BITS[(local + b.length) % CHEER_BITS.length], x: Math.round(Math.random() * 160 - 80), r: Math.round(Math.random() * 50 - 25) }]);
  };
  const shown = Math.max(p.taps || 0, local);
  const heat = Math.min(1, combo / 10);
  return html`<div class="p-cheer" style=${`--heat:${heat}`}>
    <h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class="tap-wrap cheer-wrap">
      <span class="cheer-ring" aria-hidden="true"></span><span class="cheer-ring r2" aria-hidden="true"></span>
      <button class=${cx("tap-btn armed cheer-btn", combo >= 6 && "hot")} onPointerDown=${tap} aria-label="Trommeln">
        <span class="tap-ico" key=${local % 2}>🥁</span><b key=${shown}>${shown}</b><small>${combo >= 6 ? "WAHNSINN!" : combo >= 3 ? "LAUTER!" : "TROMMELN!"}</small></button>
      ${bits.map(b => html`<span class="cheer-bit" key=${b.k} style=${`--x:${b.x}px;--r:${b.r}deg`} aria-hidden="true">${b.e}</span>`)}
    </div>
    <div class="cheer-meter" aria-hidden="true"><i style=${`transform:scaleX(${heat})`}></i><span>${combo >= 3 ? `🔥 Combo ×${combo}` : "Tippen, tippen, tippen!"}</span></div>
  </div>`;
}

function Confirm({ p, send }) {
  const [pend, commit] = useCommit(send, p.done);
  const done = p.done || !!pend;
  return html`<div class="p-confirm">
    <${Timer} d=${p.deadline} done=${done} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <button class=${cx("btn big block", done ? "ghost" : "green")} disabled=${done} onClick=${() => commit({ type: "confirm" })}>${p.done ? "✔️ " : pend ? "⏳ " : ""}${p.button}</button>
  </div>`;
}

// Wire values the formats use for binary prompts → icon + display label.
const BIN_WORDS = {
  long: ["📈", "Long", "up"], short: ["📉", "Short", "down"], ja: ["👍", "Ja"], nein: ["👎", "Nein"], shot: ["🥃", "Shot"], schotter: ["💸", "Schotter"],
  weiter: ["🧗", "Weiter"], runter: ["🪂", "Runter"], sichern: ["🏦", "Sichern"], hoch: ["", "Hoch", "up"], "höher": ["", "Höher", "up"], hoeher: ["", "Höher", "up"],
  tiefer: ["", "Tiefer", "down"], niedriger: ["", "Niedriger", "down"], mehr: ["", "Mehr", "up"], weniger: ["", "Weniger", "down"],
};
const ARROWS = { "⬆": "up", "↑": "up", "▲": "up", "⏫": "up", "⬇": "down", "↓": "down", "▼": "down", "⏬": "down", "⬅": "left", "←": "left", "➡": "right", "→": "right" };
const LEAD_EMOJI = /^((?:\p{Extended_Pictographic}|[↑↓←→▲▼⬆⬇⬅➡])(?:\uFE0F|\u200D\p{Extended_Pictographic})*\uFE0F?)\s*(.*)$/u;
/** "⬆️ Höher" → {arrow:"up", text:"Höher"}, "long" → {icon:"📈", text:"Long"}, else {text}. */
export function binaryLabel(l) {
  const raw = String(l == null ? "" : l).trim();
  const w = BIN_WORDS[raw.toLowerCase()];
  if (w) return { icon: w[0] || null, text: w[1], arrow: w[0] ? null : w[2] || null, dir: w[2] || null };
  const m = LEAD_EMOJI.exec(raw);
  if (m && m[2]) {
    const a = ARROWS[m[1].replace(/\uFE0F/g, "")] || null;
    const w2 = BIN_WORDS[m[2].toLowerCase()];
    return { icon: a ? null : m[1], arrow: a, text: w2 ? w2[1] : m[2], dir: a || (w2 && w2[2]) || null };
  }
  return { icon: null, arrow: null, text: raw, dir: null };
}

function Binary({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  const labels = [binaryLabel(p.a), binaryLabel(p.b)];
  // Colour follows the meaning when the labels carry a direction (⬆ = green, ⬇ = red).
  const tone = (L, i) => (L.dir === "up" ? "a" : L.dir === "down" ? "b" : i ? "b" : "a");
  return html`<div class="p-binary">
    <${Timer} d=${p.deadline} done=${shown != null} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class=${cx("bin-row", shown != null && "has-pick")} role="radiogroup" aria-label=${p.title}>${[p.a, p.b].map((l, i) => { const L = labels[i];
      return html`<button class=${cx("bin-btn", tone(L, i), L.arrow && "arrow " + L.arrow, shown === l && "on")} role="radio" aria-checked=${shown === l} aria-label=${L.text}
          disabled=${shown != null && shown !== l} onClick=${() => shown == null && commit({ type: "binary", value: l }, l)}>
        ${L.arrow ? html`<span class="bin-arrow" aria-hidden="true"><i></i></span>` : L.icon ? html`<span class="bin-ico" aria-hidden="true">${L.icon}</span>` : null}
        <span class="bin-t">${L.text}</span>
        ${shown === l && html`<span class="bin-mine">${pend ? "⏳ wird gesendet" : "✓ Deine Wahl"}</span>`}
      </button>`; })}</div>
    ${shown != null && html`<${LockNote} pend=${pend} />`}
  </div>`;
}

function Vote({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  const total = p.options.reduce((a, o) => a + (o.count || 0), 0);
  const max = p.options.reduce((a, o) => Math.max(a, o.count || 0), 0);
  // Emoji options (category vote) → cards with a rising fill; plain text → poll rows with bars.
  const cards = p.options.length <= 6 && p.options.every(o => o.emoji);
  const pct = o => (total ? Math.round(((o.count || 0) / total) * 100) : 0);
  return html`<div class="p-vote">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <div class=${cx(cards ? "vote-grid" : "vote-list", cards && p.options.length % 2 === 1 && "odd")} role="radiogroup" aria-label=${p.title}>${p.options.map((o, i) => {
      const on = shown === o.id, lead = total > 0 && o.count === max && max > 0;
      return html`<button class=${cx("vote-card", on && "on", lead && "lead")} style=${`--c:${OPTION_STYLE[i % 8].c};--f:${total ? (o.count || 0) / total : 0};animation-delay:${i * 70}ms`}
          role="radio" aria-checked=${on} aria-label=${`${o.label}${total ? `, ${o.count || 0} Stimmen` : ""}`} onClick=${() => !on && commit({ type: "vote", value: o.id }, o.id)}>
        <i class="vote-fill" aria-hidden="true"></i>
        ${cards ? html`<span class="vote-emoji" aria-hidden="true">${o.emoji}</span>` : html`<span class="vote-l" aria-hidden="true">${OPTION_STYLE[i % 8].l}</span>`}
        <b>${o.label}</b>
        ${total > 0 && html`<span class="vote-n" aria-hidden="true"><em>${pct(o)} %</em><small>${o.count || 0} ${o.count === 1 ? "Stimme" : "Stimmen"}</small></span>`}
        ${on && html`<span class="vote-mine" aria-hidden="true">✓ Deine Stimme</span>`}
      </button>`; })}</div>
    ${shown != null && html`<${LockNote} pend=${pend} text="Stimme abgegeben — du kannst noch wechseln" />`}
  </div>`;
}

// ---------- result ----------
/** Counts 0 → value (or from → value) once, after `delay` ms. */
export function CountUp({ value, from = 0, delay = 0, dur = 900, fmt = fmtNum }) {
  const [v, setV] = useState(from);
  useEffect(() => {
    let raf, t0;
    const reduce = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce || from === value) { setV(value); return; }
    const step = t => { t0 = t0 || t; const k = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - k, 3); setV(Math.round(from + (value - from) * e)); if (k < 1) raf = requestAnimationFrame(step); };
    const to = setTimeout(() => { raf = requestAnimationFrame(step); }, delay);
    return () => { clearTimeout(to); cancelAnimationFrame(raf); };
  }, [value, from]);
  return fmt(v);
}

function Reveal({ p, me, x, compact }) {
  const e = x.ergebnis || null;
  const richtig = e && e.richtig != null ? e.richtig : p.correct;
  const cls = richtig === true ? "ok" : richtig === false ? "nope" : "meh";
  const face = richtig === true ? "jubel" : richtig === false ? "frust" : "denk";
  const delta = p.delta;
  const speed = (e && e.speedBonus) || p.speedBonus || 0;
  const streak = e ? e.streak : p.streak;
  const faktor = e && e.streakFaktor > 1 ? e.streakFaktor : 0;
  const stampText = richtig === true ? "RICHTIG!" : richtig === false ? "FALSCH!" : p.title;
  const showTitle = richtig != null && p.title && !/^\W*(richtig|falsch)\W*$/i.test(p.title);
  const up = e && e.platzNachher < e.platzVorher, down = e && e.platzNachher > e.platzVorher;
  const detail = p.detail && e && e.richtigText ? p.detail.split(" · ").filter(t => !/^(Du:|Richtig( war)?:)/.test(t.trim())).join(" · ") : p.detail;
  let beat = 0;
  const b = () => `animation-delay:${(beat++) * 160 + 250}ms`;
  if (compact) return html`<div class=${cx("p-reveal compact", cls)}><div class="stamp pop-in">${stampText}</div><div class=${cx("rev-delta", delta > 0 ? "pos" : delta < 0 ? "neg" : "zero")}>${delta === 0 ? "±0 MM" : fmtDelta(delta) + " MM"}</div>${p.detail && html`<p class="rev-detail">${p.detail}</p>`}</div>`;
  return html`<div class=${cx("p-reveal", cls)}>
    <div class="rev-burst"></div>
    <div class="rev-top">
      ${me && html`<${Monkey} wire=${me.avatar} face=${face} anim=${face === "jubel" ? "jubel" : face === "frust" ? "frust" : "idle"} size=${110} />`}
      <div class="stamp">${stampText}</div>
    </div>
    ${showTitle && html`<p class="rev-title rv" style=${b()}>${p.title}</p>`}
    ${e && e.richtigText && html`<div class="rev-answer rv" style=${b()}><small>${richtig === true ? "Lösung" : "Richtig war"}</small><b>${e.richtigText}</b></div>`}
    <div class=${cx("rev-delta rv", delta > 0 ? "pos" : delta < 0 ? "neg" : "zero")} style=${b()}>
      <span class="rev-num">${delta === 0 ? "±0" : html`${delta > 0 ? "+" : "−"}<${CountUp} value=${Math.abs(delta)} delay=${400} />`}</span><small> MM</small>
    </div>
    <div class="rev-chips rv" style=${b()}>
      ${speed > 0 && html`<span class="rchip speed">⚡ Speed +${fmtNum(speed)}</span>`}
      ${e && e.antwortMs != null && html`<span class="rchip">⏱ ${fmtNum(Math.round(e.antwortMs / 100) / 10)} s</span>`}
      ${streak >= 2 && html`<span class=${cx("rchip streak", faktor && "hot")}>🔥 Serie ${streak}${faktor ? html` <b>×${fmtNum(faktor)}</b>` : ""}</span>`}
    </div>
    ${e && html`<div class="rev-grid rv" style=${b()}>
      <div class=${cx("rev-rank", up && "up", down && "down")}><small>Platz</small>
        <b>${e.platzVorher !== e.platzNachher ? html`<s>${e.platzVorher}</s><i class=${"tri " + (up ? "up" : "down")}></i>${e.platzNachher}` : e.platzNachher}</b>
        <em>${up ? `${e.platzVorher - e.platzNachher} hoch` : down ? `${e.platzNachher - e.platzVorher} runter` : "gehalten"}</em></div>
      <div class="rev-bal"><small>Kontostand</small><b><${CountUp} from=${e.balance - delta} value=${e.balance} delay=${700} dur=${1100} /></b><em>MM</em></div>
    </div>`}
    ${detail && html`<p class="rev-detail rv" style=${b()}>${detail}</p>`}
  </div>`;
}

// ---------- rules, lists, boards ----------
function Explain({ p, send }) {
  const [pend, commit] = useCommit(send, p.ready);
  const ready = p.ready || !!pend;
  return html`<div class="p-explain">
    <${Timer} d=${p.deadline} done=${ready} />
    <h2 class="p-title">${p.title}</h2>
    ${p.text && html`<p class="p-sub">${p.text}</p>`}
    <ol class="p-rules">${p.regeln.map((r, i) => html`<li style=${`animation-delay:${i * 0.1}s`}><span>${i + 1}</span>${r}</li>`)}</ol>
    ${p.gewinn && html`<div class="p-gewinn">💰 ${p.gewinn}</div>`}
    <button class=${cx("btn block big", ready ? "ghost" : "green")} disabled=${ready} onClick=${() => commit({ type: "ready", value: "bereit" })}>${p.ready ? "✔️ Bereit — warte auf die anderen" : pend ? "⏳ Bereit …" : "👍 Verstanden, bereit!"}</button>
    ${!ready && !p.streik && html`<button class="btn ghost block" onClick=${() => { feel("tap"); send({ type: "ready", value: "streik" }); }}>✊ Streik <small class="muted">(Mehrheit: Blitzfrage statt Minispiel)</small></button>`}
    ${p.streik && html`<p class="p-hint">✊ Du streikst.</p>`}
  </div>`;
}

/** Board-game titles: "Du bist dran! …" / "Kokos ist dran · …" → a whose-turn banner. */
function turnOf(title) {
  const t = String(title || "");
  let m = /^(?:🎯\s*)?Du bist dran!?\s*(.*)$/.exec(t);
  if (m) return { mine: true, who: "Du", rest: m[1].replace(/^[·:,\s]+/, "") };
  m = /^(.+?) ist dran\b\s*(.*)$/.exec(t);
  if (m && m[1].length <= 40) return { mine: false, who: m[1], rest: m[2].replace(/^[·:,\s]+/, "") };
  return null;
}
function TurnBanner({ turn, compact }) {
  return html`<div class=${cx("turn-banner", turn.mine ? "mine" : "wait", compact && "compact")} role="status">
    <span class="tb-ico" aria-hidden="true">${turn.mine ? "🎯" : "⏳"}</span>
    <b>${turn.mine ? "Du bist dran!" : `${turn.who} ist dran`}</b>
    ${!turn.mine && html`<span class="tb-dots" aria-hidden="true"><i></i><i></i><i></i></span>`}
  </div>`;
}
const UNO_COL = { "🔴": ["rot", "#FF4D6D", "#B3123A"], "🟡": ["gelb", "#FFC21A", "#B77F00"], "🟢": ["gruen", "#2BC46F", "#0E7A42"], "🔵": ["blau", "#3D7BFF", "#1B47B8"], "⚫": ["schwarz", "#2A2440", "#0D0A1A"] };
const COLOR_WORDS = { rot: "🔴", gelb: "🟡", gruen: "🟢", "grün": "🟢", blau: "🔵", schwarz: "⚫" };
/** "🔴 7" → {col, hex, dark, face}; null when it is not an UNO-style label. */
function unoCard(text) {
  const t = String(text || "").trim();
  const sp = t.indexOf(" ");
  const head = (sp > 0 ? t.slice(0, sp) : t).replace(/\uFE0F/g, "");
  const c = UNO_COL[head];
  if (!c) return null;
  const face = sp > 0 ? t.slice(sp + 1).trim() : "";
  const wild = /^wild/i.test(face) || c[0] === "schwarz";
  const big = wild ? (face.replace(/^wild\s*/i, "") || "") : face;
  return { col: c[0], hex: c[1], dark: c[2], face, big, wild, corner: wild ? big || "W" : face };
}
function UnoFace({ u }) {
  return html`<span class=${cx("uc-oval", u.wild && "wild")} aria-hidden="true"><b class=${cx(u.big.length > 2 && "long")}>${u.big || (u.wild ? "" : u.face)}</b></span>
    <span class="uc-corner tl" aria-hidden="true">${u.corner}</span><span class="uc-corner br" aria-hidden="true">${u.corner}</span>`;
}
const btnClass = b => cx("btn block", b.style === "secondary" ? "ghost" : b.style === "danger" ? "red" : "green");
/** Button whose label starts with a colour dot (UNO colour pick) → a coloured button. */
function ColorBtn({ b, onClick }) {
  const m = LEAD_EMOJI.exec(String(b.label));
  const c = m && UNO_COL[m[1].replace(/\uFE0F/g, "")];
  if (!c) return html`<button class=${btnClass(b)} disabled=${!b.enabled} onClick=${onClick}>${b.label}</button>`;
  return html`<button class="btn block color-pick" style=${`--c:${c[1]};--d:${c[2]}`} disabled=${!b.enabled} onClick=${onClick}><span class="cp-dot" aria-hidden="true"></span>${m[2] || c[0]}</button>`;
}

function Actions({ p, send, compact }) {
  const turn = turnOf(p.title);
  const lines = p.lines.filter(l => String(l || "").trim());
  const colors = p.buttons.length >= 2 && p.buttons.every(b => { const m = LEAD_EMOJI.exec(String(b.label)); return m && UNO_COL[m[1].replace(/\uFE0F/g, "")]; });
  const grid = colors || (p.buttons.length >= 4 && p.buttons.every(b => String(b.label).length <= 16));
  const press = b => () => { feel("tap"); send({ type: "button", id: b.id }); };
  return html`<div class=${cx("p-actions", turn && (turn.mine ? "my-turn" : "their-turn"))}>
    <${Timer} d=${p.deadline} />
    ${turn ? html`<${TurnBanner} turn=${turn} compact=${compact} />${turn.rest && html`<h2 class="p-title sm">${turn.rest}</h2>`}` : html`<h2 class="p-title">${p.title}</h2>`}
    ${lines.length > 0 && html`<ul class="p-lines">${lines.map(l => html`<li>${l}</li>`)}</ul>`}
    ${p.buttons.length > 0 ? html`<div class=${cx("p-btns", grid && "grid", colors && "colors")}>${p.buttons.map(b => colors ? html`<${ColorBtn} b=${b} onClick=${press(b)} />` : html`<button class=${btnClass(b)} disabled=${!b.enabled} onClick=${press(b)}>${b.label}</button>`)}</div>`
      : turn && !turn.mine && html`<p class="p-sub">Lehn dich zurück — dein Zug kommt gleich.</p>`}
  </div>`;
}

function Feedback({ p, send }) {
  const [vals, setVals] = useState(p.questions.map(() => ""));
  const [pend, commit] = useCommit(send, p.done);
  if (p.done) return html`<div class="p-idle"><div class="big-emoji pop-in">💛</div><h2 class="idle-title">Danke fürs Feedback!</h2><p class="idle-sub">Der Bildschirm startet gleich die Revanche.</p></div>`;
  const quick = ["🤩", "👍", "😐", "👎"];
  const set = (i, v) => { const n = [...vals]; n[i] = v; setVals(n); };
  return html`<div class="p-feedback"><h2 class="p-title">Wie war die Show?</h2>
    ${p.questions.map((q, i) => html`<div class="fb-q"><p>${q}</p><div class="fb-row">${quick.map(e => html`<button class=${cx("fb-emo", vals[i] === e && "on")} onClick=${() => { set(i, e); feel("tap"); }}>${e}</button>`)}</div>
      <input class="text-in" placeholder="oder frei …" value=${quick.includes(vals[i]) ? "" : vals[i]} onInput=${e => set(i, e.target.value)} /></div>`)}
    <button class="btn green block big" disabled=${!!pend} onClick=${() => commit({ type: "feedback", list: vals })}>${pend ? "⏳ Wird gesendet …" : "📨 Abschicken"}</button></div>`;
}

function Cards({ p, send, compact }) {
  const turn = turnOf(p.title);
  // "Oben: 🔴 7 · Farbe rot" → the discard pile and the colour in play.
  const top = /Oben:\s*(.+?)(?:\s*·\s*Farbe\s+(\S+))?\s*$/.exec(turn ? turn.rest : p.title || "");
  const topCard = top && unoCard(top[1]);
  const color = top && top[2] ? top[2].toLowerCase() : topCard && !topCard.wild ? topCard.col : null;
  const colorDot = color && UNO_COL[COLOR_WORDS[color]];
  const mine = turn ? turn.mine : p.buttons.length > 0 || p.cards.some(c => !c.removed);
  const playable = p.cards.filter(c => !c.removed).length;
  const [played, setPlayed] = useState(null);
  const play = c => { if (c.removed) return; feel("lock"); setPlayed(c.id); setTimeout(() => setPlayed(null), 650); send({ type: "choose", value: c.id }); };
  const rest = turn && !top ? turn.rest : null;
  return html`<div class=${cx("p-cards", mine ? "my-turn" : "their-turn")}>
    <${Timer} d=${p.deadline} />
    ${turn ? html`<${TurnBanner} turn=${turn} compact=${compact} />` : html`<h2 class="p-title">${p.title}</h2>`}
    ${rest && html`<h2 class="p-title sm">${rest}</h2>`}
    ${(topCard || p.hint) && html`<div class="uno-table">
      ${topCard && html`<div class="uno-pile"><small>Oben</small><span class=${cx("uno-card static", "c-" + topCard.col)} style=${`--c:${topCard.hex};--d:${topCard.dark}`} role="img" aria-label=${`Oben liegt ${topCard.col} ${topCard.face}`}><${UnoFace} u=${topCard} /></span></div>`}
      <div class="uno-info">
        ${colorDot && html`<span class="uno-color" style=${`--c:${colorDot[1]}`}><i aria-hidden="true"></i>Farbe <b>${color}</b></span>`}
        ${p.hint && html`<span class="uno-count">🃏 ${p.hint}</span>`}
        ${mine && p.cards.length > 0 && html`<span class=${cx("uno-can", !playable && "none")}>${playable ? `${playable} ${playable === 1 ? "Karte passt" : "Karten passen"}` : "Keine Karte passt — zieh eine"}</span>`}
      </div>
    </div>`}
    <div class=${cx("hand", p.cards.length > 10 && "tight")} role="group" aria-label="Deine Hand">${p.cards.map((c, i) => {
      const u = unoCard(c.text);
      const ok = !c.removed;
      const cls = cx("hand-card", c.removed && "off", u && "uno", u && "c-" + u.col, ok && mine && "playable", played === c.id && "played");
      return u ? html`<button class=${cls} disabled=${c.removed} style=${`--c:${u.hex};--d:${u.dark};animation-delay:${i * 40}ms`} aria-label=${`${u.col} ${u.face}${c.removed ? " (passt nicht)" : ""}`} onClick=${() => play(c)}><${UnoFace} u=${u} /></button>`
        : html`<button class=${cls} disabled=${c.removed} style=${`animation-delay:${i * 40}ms`} onClick=${() => play(c)}><span>${c.text}</span></button>`;
    })}</div>
    ${p.buttons.length > 0 && html`<div class="p-btns row">${p.buttons.map(b => html`<button class=${cx(btnClass(b), b.id === "banane" && "banane")} disabled=${!b.enabled} onClick=${() => { feel(b.id === "banane" ? "heavy" : "tap"); send({ type: "button", id: b.id }); }}>${b.label}</button>`)}</div>`}
  </div>`;
}
