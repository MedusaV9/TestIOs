// Renders every PlayerPrompt kind the engine emits. Used by the phones and by
// the stage for pass-and-play seats. `send(action)` gets the wire action.
// Inputs lock optimistically (useCommit): the tap feels instant, a pending
// badge shows until the server echoes it, lost actions are resent / rolled back.
// `extra` (phones only): { phase, ergebnis, stats, players, ohneScreen }.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
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
    case "actions": return html`<${Actions} p=${p} send=${send} />`;
    case "feedback": return html`<${Feedback} p=${p} send=${send} />`;
    case "cards": return html`<${Cards} p=${p} send=${send} />`;
    default: return html`<div class="p-idle"><h2>…</h2></div>`;
  }
}

// ---------- shared bits ----------
/** Countdown bar with seconds, urgency pulse and soft ticks in the last 5 s. */
function Timer({ d, done }) {
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
  return html`<div class=${cx("p-timer", hot && "hot", remain === 0 && "over", done && "done")}>
    <div class="pt-bar"><i style=${`transform:scaleX(${frac})`}></i></div>
    <b class="pt-secs" key=${hot ? secs : "s"}>${done ? "🔒" : secs}</b>
  </div>`;
}
const Q = ({ t }) => (t ? html`<div class="p-question" style=${`font-size:${t.length > 140 ? 16 : t.length > 90 ? 18 : t.length > 50 ? 20 : 23}px`}>${t}</div>` : null);
const Sub = ({ t }) => (t ? html`<p class="p-sub">${t}</p>` : null);

/** "Eingeloggt" banner: pending (sending …) or confirmed. */
function LockNote({ pend, text = "Eingeloggt — Daumen drücken!", tries }) {
  return html`<div class=${cx("p-locked-note", pend ? "pending" : "ok")} role="status">
    ${pend ? html`<span class="ln-spin"></span><span>${pend.n > 1 ? `Sende erneut (${pend.n}) …` : "Wird übertragen …"}</span>`
      : html`<span class="ln-check"><i class="ck"></i></span><span>${text}</span>`}
  </div>`;
}

function OptButton({ o, i, chosen, onClick, locked, pending, children }) {
  const st = OPTION_STYLE[i % 8];
  return html`<button class=${cx("p-opt", chosen && "chosen", chosen && pending && "pending", chosen && locked && !pending && "locked-in", o.removed && "removed", locked && !chosen && "dim")}
      style=${`--c:${st.c};--d:${st.d};animation-delay:${i * 55}ms`} disabled=${o.removed || (locked && !chosen)} onClick=${onClick} aria-pressed=${!!chosen}>
    <span class="p-opt-badge"><b>${st.l}</b><i>${st.e}</i></span><span class="p-opt-text">${o.text}</span>
    ${chosen && html`<span class="p-lock">${pending ? html`<span class="ln-spin dark"></span>` : "🔒"}</span>`}${children}
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
    ${!standings && html`<div class="look-up"><span>${hint[0]}</span>${hint[1]}</div>`}
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
    <div class="lock-card pop-in"><span class="lock-ico">${pend ? "⏳" : "🔒"}</span><div class="big-val">${value}${unit && html` <small>${unit}</small>`}</div></div>
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

function Order({ p, send }) {
  const [order, setOrder] = useState(p.order && p.order.length ? p.order : p.items.map(i => i.id));
  const [moved, setMoved] = useState(null);
  const [pend, commit] = useCommit(send, p.locked);
  const locked = p.locked || !!pend;
  const byId = Object.fromEntries(p.items.map(i => [i.id, i]));
  const mv = (pos, d) => { const to = pos + d; if (to < 0 || to >= order.length) return; const n = [...order]; [n[pos], n[to]] = [n[to], n[pos]]; setOrder(n); setMoved({ id: n[to], d, t: Date.now() }); feel("tap"); send({ type: "order", list: n }); };
  return html`<div class="p-order">
    <${Timer} d=${p.deadline} done=${locked} /><${Q} t=${p.question} />
    <ol class="order-list">${order.map((id, pos) => html`<li class=${cx(locked && "locked", moved && moved.id === id && (moved.d < 0 ? "bump-up" : "bump-down"))} key=${id + (moved && moved.id === id ? moved.t : "")}>
      <span class="ord-n">${pos + 1}</span><span class="ord-t">${(byId[id] || {}).text}</span>
      ${!locked && html`<span class="ord-btns"><button onClick=${() => mv(pos, -1)} disabled=${pos === 0} aria-label="nach oben"><i class="tri up"></i></button><button onClick=${() => mv(pos, 1)} disabled=${pos === order.length - 1} aria-label="nach unten"><i class="tri down"></i></button></span>`}
    </li>`)}</ol>
    ${locked ? html`<${LockNote} pend=${pend} text="Reihenfolge eingeloggt" />`
      : html`<button class="btn green block big" onClick=${() => { send({ type: "order", list: order }); commit({ type: "confirm" }); }}>🔒 Reihenfolge einloggen</button>`}
  </div>`;
}

function TextInput({ p, send }) {
  const [v, setV] = useState("");
  const [pend, commit] = useCommit(send, p.submitted);
  const go = () => { const t = v.trim(); if (t) { document.activeElement && document.activeElement.blur && document.activeElement.blur(); commit({ type: "text", value: t }, t); } };
  if (p.submitted || pend) return html`<${LockedValue} title=${html`<${Q} t=${p.question} />`} value=${html`<span class="small">„${pend ? pend.value : p.submitted}“</span>`} pend=${pend} text="Abgeschickt" />`;
  return html`<div class="p-text">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <div class="text-wrap"><input class="text-in" maxlength=${p.maxLength} placeholder=${p.placeholder} value=${v} enterkeyhint="send" autocomplete="off" onInput=${e => setV(e.target.value)} onKeyDown=${e => e.key === "Enter" && go()} />
      ${p.maxLength && html`<small class="text-count">${v.length}/${p.maxLength}</small>`}</div>
    <button class="btn green block big" disabled=${!v.trim()} onClick=${go}>📨 Abschicken</button>
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
  return html`<div class="p-pick">
    <${Timer} d=${p.deadline} done=${shown != null} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class="pick-grid">${p.candidates.map((c, i) => html`<button class=${cx("pick-card", shown === c.id && "on")} style=${`animation-delay:${i * 60}ms`} disabled=${shown != null && shown !== c.id} onClick=${() => shown == null && commit({ type: "pickPlayer", id: c.id }, c.id)}>
      <${Monkey} wire=${c.avatar} anim=${shown === c.id ? "jubel" : "none"} face=${shown === c.id ? "denk" : "neutral"} size=${70} /><b>${c.name}</b><small>${fmtMM(c.balance)}</small></button>`)}</div>
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

function Cheer({ p, send }) {
  const [local, setLocal] = useState(0);
  return html`<div class="p-cheer">
    <h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class="tap-wrap">
      <button class="tap-btn armed" onPointerDown=${e => { e.preventDefault(); feel("tap"); setLocal(x => x + 1); send({ type: "cheer" }); }}><span class="tap-ico" key=${local % 2}>🥁</span><b key=${p.taps}>${p.taps}</b><small>TROMMELN!</small></button>
      ${local > 0 && html`<span class="tap-plus" key=${local}>🥁</span>`}
    </div>
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

function Binary({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  return html`<div class="p-binary">
    <${Timer} d=${p.deadline} done=${shown != null} /><h2 class="p-title">${p.title}</h2><${Sub} t=${p.subtitle} />
    <div class="bin-row">${[p.a, p.b].map((l, i) => html`<button class=${cx("bin-btn", i ? "b" : "a", shown === l && "on")} disabled=${shown != null && shown !== l} onClick=${() => shown == null && commit({ type: "binary", value: l }, l)}>${l}</button>`)}</div>
    ${shown != null && html`<${LockNote} pend=${pend} />`}
  </div>`;
}

function Vote({ p, send }) {
  const [pend, commit] = useCommit(send, p.chosen);
  const shown = pend ? pend.value : p.chosen;
  const total = p.options.reduce((a, o) => a + (o.count || 0), 0);
  return html`<div class="p-vote">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <div class=${cx("vote-grid", p.options.length === 3 && "three")}>${p.options.map((o, i) => html`<button class=${cx("vote-card", shown === o.id && "on")} style=${`--c:${OPTION_STYLE[i % 8].c};animation-delay:${i * 70}ms`} onClick=${() => shown !== o.id && commit({ type: "vote", value: o.id }, o.id)}>
      <span class="vote-emoji">${o.emoji || "🗳"}</span><b>${o.label}</b>${o.count > 0 && html`<small>${o.count} 🗳</small>`}
      ${total > 0 && html`<i class="vote-bar" style=${`transform:scaleX(${(o.count || 0) / total})`}></i>`}</button>`)}</div>
    ${shown != null && html`<${LockNote} pend=${pend} text="Stimme abgegeben — du kannst noch wechseln" />`}
  </div>`;
}

// ---------- result ----------
/** Counts 0 → value (or from → value) once, after `delay` ms. */
function CountUp({ value, from = 0, delay = 0, dur = 900, fmt = fmtNum }) {
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
      ${delta === 0 ? "±0" : html`${delta > 0 ? "+" : "−"}<${CountUp} value=${Math.abs(delta)} delay=${400} />`}<small> MM</small>
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

function Actions({ p, send }) {
  return html`<div class="p-actions">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    ${p.lines.length > 0 && html`<ul class="p-lines">${p.lines.map(l => html`<li>${l}</li>`)}</ul>`}
    <div class="p-btns">${p.buttons.map(b => html`<button class=${cx("btn block", b.style === "secondary" ? "ghost" : b.style === "danger" ? "red" : "green")} disabled=${!b.enabled} onClick=${() => { feel("tap"); send({ type: "button", id: b.id }); }}>${b.label}</button>`)}</div>
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

const UNO_COL = { "🔴": "#FF4D6D", "🟡": "#F5B301", "🟢": "#2BB56C", "🔵": "#3D7BFF", "⚫": "#222" };
function Cards({ p, send }) {
  return html`<div class="p-cards">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.hint && html`<p class="p-hint">${p.hint}</p>`}
    <div class="hand">${p.cards.map((c, i) => {
      const parts = String(c.text).split(" ");
      const col = UNO_COL[parts[0]] || null;
      const label = col ? parts.slice(1).join(" ") : c.text;
      return html`<button class=${cx("hand-card", c.removed && "off", col && "uno")} disabled=${c.removed} style=${`${col ? `--c:${col};` : ""}animation-delay:${i * 40}ms`} onClick=${() => { feel("tap"); send({ type: "choose", value: c.id }); }}><span>${label}</span></button>`;
    })}</div>
    <div class="p-btns">${p.buttons.map(b => html`<button class=${cx("btn", b.style === "secondary" ? "ghost" : b.style === "danger" ? "red" : "green")} disabled=${!b.enabled} onClick=${() => { feel("tap"); send({ type: "button", id: b.id }); }}>${b.label}</button>`)}</div>
  </div>`;
}
