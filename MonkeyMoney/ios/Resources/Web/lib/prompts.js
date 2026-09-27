// Renders every PlayerPrompt kind the engine emits. Used by the phones and by
// the stage for pass-and-play seats. `send(action)` gets the wire action.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { cx, fmtMM, fmtNum, fmtDelta, OPTION_STYLE, serverNow, haptic } from "./core.js";
import { Monkey, TimerBar } from "./ui.js";

export function Prompt({ p, send, me, compact, extra }) {
  const key = p.kind;
  switch (p.kind) {
    case "idle": return html`<${Idle} p=${p} me=${me} />`;
    case "choice": return html`<${Choice} p=${p} send=${send} key=${p.question} />`;
    case "multiChoice": return html`<${MultiChoice} p=${p} send=${send} key=${p.question} />`;
    case "buzzer": return html`<${Buzzer} p=${p} send=${send} />`;
    case "number": return html`<${NumberInput} p=${p} send=${send} key=${p.question} />`;
    case "wager": return html`<${Wager} p=${p} send=${send} key=${p.title} />`;
    case "order": return html`<${Order} p=${p} send=${send} key=${p.question} />`;
    case "text": return html`<${TextInput} p=${p} send=${send} key=${p.question} />`;
    case "tapFrenzy": return html`<${Taps} p=${p} send=${send} />`;
    case "chips": return html`<${Chips} p=${p} send=${send} key=${p.question} />`;
    case "pickPlayer": return html`<${PickPlayer} p=${p} send=${send} />`;
    case "bank": return html`<${Bank} p=${p} send=${send} />`;
    case "cheer": return html`<${Cheer} p=${p} send=${send} me=${me} />`;
    case "confirm": return html`<${Confirm} p=${p} send=${send} />`;
    case "binary": return html`<${Binary} p=${p} send=${send} />`;
    case "vote": return html`<${Vote} p=${p} send=${send} />`;
    case "reveal": return html`<${Reveal} p=${p} me=${me} />`;
    case "explain": return html`<${Explain} p=${p} send=${send} />`;
    case "actions": return html`<${Actions} p=${p} send=${send} />`;
    case "feedback": return html`<${Feedback} p=${p} send=${send} />`;
    case "cards": return html`<${Cards} p=${p} send=${send} />`;
    default: return html`<div class="p-idle"><h2>…</h2></div>`;
  }
}

const Timer = ({ d }) => (d ? html`<div class="p-timer"><${TimerBar} deadline=${d} /></div>` : null);
const Q = ({ t }) => (t ? html`<div class="p-question" style=${`font-size:${t.length > 120 ? 17 : t.length > 70 ? 19 : 22}px`}>${t}</div>` : null);

function Idle({ p, me }) {
  const t = String(p.title || "");
  const face = /💥|MATSCH|matschig|Falsch|❌/.test(t) ? "frust" : /GEWONNEN|Richtig|✅|🎉|👑/.test(t) ? "jubel" : /…|\.\.\.|dreht|wartet|Warte/i.test(t) ? "denk" : "neutral";
  return html`<div class="p-idle">
    ${me && html`<${Monkey} wire=${me.avatar} face=${face} anim=${face === "jubel" ? "jubel" : face === "denk" ? "denk" : "idle"} size=${150} />`}
    <h2>${p.title}</h2>${p.subtitle && html`<p class="muted">${p.subtitle}</p>`}
    <div class="look-up">📺 Schau auf die Bühne</div>
  </div>`;
}

function OptButton({ o, i, chosen, onClick, locked, children }) {
  const st = OPTION_STYLE[i % 8];
  return html`<button class=${cx("p-opt", chosen && "chosen", o.removed && "removed", locked && !chosen && "dim")} style=${`--c:${st.c};--d:${st.d};animation-delay:${i * 60}ms`}
      disabled=${o.removed || (locked && !chosen)} onClick=${onClick}>
    <span class="p-opt-badge"><b>${st.l}</b><i>${st.e}</i></span><span class="p-opt-text">${o.text}</span>${chosen && html`<span class="p-lock">🔒</span>`}${children}
  </button>`;
}

function Choice({ p, send }) {
  const locked = p.chosen != null && !p.secondTry;
  return html`<div class="p-choice">
    <${Timer} d=${p.deadline} />
    ${p.hint && html`<div class="p-hint">💡 ${p.hint}</div>`}
    <${Q} t=${p.question} />
    <div class=${cx("p-opts", p.options.length > 4 && "many")}>${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${p.chosen === o.id} locked=${locked}
      onClick=${() => { if (!locked && !o.removed) { haptic(); send({ type: "choose", value: o.id }); } }} />`)}</div>
    ${p.secondTry && html`<p class="p-hint">↩️ Rückgaberecht: wähle eine andere Antwort (50 % Gewinn)</p>`}
    ${locked && html`<p class="p-locked-note">✓ Eingeloggt — Daumen drücken!</p>`}
  </div>`;
}

function MultiChoice({ p, send }) {
  const [sel, setSel] = useState(new Set(p.chosen));
  const toggle = id => { const n = new Set(sel); n.has(id) ? n.delete(id) : n.add(id); setSel(n); haptic(); };
  return html`<div class="p-choice">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <p class="p-hint">Wähle ${p.required} Antworten</p>
    <div class="p-opts">${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${sel.has(o.id)} locked=${p.locked} onClick=${() => !p.locked && toggle(o.id)} />`)}</div>
    ${!p.locked && html`<button class="btn green block" disabled=${sel.size !== p.required} onClick=${() => send({ type: "multiChoose", list: [...sel] })}>🔒 Einloggen (${sel.size}/${p.required})</button>`}
  </div>`;
}

function Buzzer({ p, send }) {
  const locked = p.lockedUntil && p.lockedUntil > serverNow();
  return html`<div class="p-buzzer">
    ${p.question && html`<${Q} t=${p.question} />`}
    ${p.hint && html`<div class="p-hint">💡 ${p.hint}</div>`}
    <button class=${cx("buzz-btn", p.armed && !p.pressed && !locked && "armed", p.pressed && "pressed")} disabled=${!p.armed || p.pressed || locked}
      onPointerDown=${() => { if (p.armed && !p.pressed) { haptic("heavy"); send({ type: "buzz", at: serverNow() }); } }}>
      <span>${p.pressed ? "GEBUZZT!" : locked ? "GESPERRT" : p.armed ? "BUZZ!" : "WARTEN …"}</span>
    </button>
  </div>`;
}

function Stepper({ value, set, min, max, step, fmt }) {
  const bump = d => set(Math.min(max, Math.max(min, Math.round((value + d * step) / step) * step)));
  return html`<div class="stepper">
    <button class="btn ghost small" onClick=${() => bump(-10)}>−−</button><button class="btn ghost small" onClick=${() => bump(-1)}>−</button>
    <b class="stepper-val">${fmt(value)}</b>
    <button class="btn ghost small" onClick=${() => bump(1)}>+</button><button class="btn ghost small" onClick=${() => bump(10)}>++</button>
  </div>`;
}

function NumberInput({ p, send }) {
  const toSlider = v => (p.log ? (Math.log(v) - Math.log(p.min)) / (Math.log(p.max) - Math.log(p.min)) : (v - p.min) / (p.max - p.min));
  const fromSlider = f => (p.log ? Math.exp(Math.log(p.min) + f * (Math.log(p.max) - Math.log(p.min))) : p.min + f * (p.max - p.min));
  const snap = v => Math.min(p.max, Math.max(p.min, Math.round(v / p.step) * p.step));
  const [v, setV] = useState(p.current != null ? p.current : snap((p.min + p.max) / 2));
  if (p.locked || p.current != null && p.locked) return html`<div class="p-locked"><${Q} t=${p.question} /><div class="big-val">${fmtNum(p.current)} ${p.unit}</div><p class="p-locked-note">✓ Eingeloggt</p></div>`;
  return html`<div class="p-number">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <div class="big-val">${fmtNum(v)} <small>${p.unit}</small></div>
    <input type="range" min="0" max="1000" value=${Math.round(toSlider(v) * 1000)} onInput=${e => setV(snap(fromSlider(Number(e.target.value) / 1000)))} />
    <div class="range-ends"><span>${fmtNum(p.min)}</span><span>${fmtNum(p.max)}</span></div>
    <${Stepper} value=${v} set=${setV} min=${p.min} max=${p.max} step=${p.step} fmt=${x => fmtNum(x)} />
    <input class="direct" type="number" inputmode="decimal" value=${v} onChange=${e => setV(snap(Number(e.target.value)))} />
    <button class="btn green block big" onClick=${() => { haptic("success"); send({ type: "number", value: v }); }}>🔒 Tipp abgeben</button>
  </div>`;
}

function Wager({ p, send }) {
  const [v, setV] = useState(p.current != null ? p.current : p.min);
  if (p.locked) return html`<div class="p-locked"><h2>${p.title}</h2><div class="big-val">${fmtMM(p.current || 0)}</div><p class="p-locked-note">✓ Einsatz steht</p></div>`;
  return html`<div class="p-number">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.subtitle && html`<p class="muted center">${p.subtitle}</p>`}
    <div class="big-val gold-text">${fmtMM(v)}</div>
    <input type="range" min=${p.min} max=${p.max} step=${p.step} value=${v} onInput=${e => setV(Number(e.target.value))} />
    <div class="quick-bets">${[p.min, Math.round((p.min + p.max) / 2 / p.step) * p.step, p.max].map(x => html`<button class="btn ghost small" onClick=${() => setV(x)}>${x === p.max ? "ALL-IN " : ""}${fmtNum(x)}</button>`)}</div>
    <button class="btn block big" onClick=${() => { haptic("success"); send({ type: "wager", value: v }); }}>🎲 Setzen</button>
  </div>`;
}

function Order({ p, send }) {
  const [order, setOrder] = useState(p.order && p.order.length ? p.order : p.items.map(i => i.id));
  const byId = Object.fromEntries(p.items.map(i => [i.id, i]));
  const mv = (pos, d) => { const to = pos + d; if (to < 0 || to >= order.length) return; const n = [...order]; [n[pos], n[to]] = [n[to], n[pos]]; setOrder(n); haptic(); send({ type: "order", list: n }); };
  return html`<div class="p-order">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <ol class="order-list">${order.map((id, pos) => html`<li class=${cx(p.locked && "locked")} key=${id}>
      <span class="ord-n">${pos + 1}</span><span class="ord-t">${(byId[id] || {}).text}</span>
      ${!p.locked && html`<span class="ord-btns"><button onClick=${() => mv(pos, -1)} disabled=${pos === 0}>▲</button><button onClick=${() => mv(pos, 1)} disabled=${pos === order.length - 1}>▼</button></span>`}
    </li>`)}</ol>
    ${p.locked ? html`<p class="p-locked-note">✓ Reihenfolge eingeloggt</p>` : html`<button class="btn green block" onClick=${() => { send({ type: "order", list: order }); send({ type: "confirm" }); haptic("success"); }}>🔒 Reihenfolge einloggen</button>`}
  </div>`;
}

function TextInput({ p, send }) {
  const [v, setV] = useState("");
  if (p.submitted) return html`<div class="p-locked"><${Q} t=${p.question} /><div class="big-val small">„${p.submitted}“</div><p class="p-locked-note">✓ Abgeschickt</p></div>`;
  return html`<div class="p-text">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <input class="text-in" maxlength=${p.maxLength} placeholder=${p.placeholder} value=${v} onInput=${e => setV(e.target.value)} onKeyDown=${e => e.key === "Enter" && v.trim() && send({ type: "text", value: v.trim() })} />
    <button class="btn green block" disabled=${!v.trim()} onClick=${() => send({ type: "text", value: v.trim() })}>📨 Abschicken</button>
  </div>`;
}

function Taps({ p, send }) {
  const pending = useRef(0);
  const [local, setLocal] = useState(0);
  useEffect(() => {
    const iv = setInterval(() => { if (pending.current) { send({ type: "taps", value: pending.current }); pending.current = 0; } }, 700);
    return () => { clearInterval(iv); if (pending.current) send({ type: "taps", value: pending.current }); };
  }, []);
  return html`<div class="p-taps">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <button class=${cx("tap-btn", p.active && "armed")} disabled=${!p.active} onPointerDown=${() => { pending.current++; setLocal(x => x + 1); haptic(); }}>
      <span class="tap-ico">🥥</span><b>${p.count + pending.current}</b><small>SCHÜTTELN!</small>
    </button>
  </div>`;
}

function Chips({ p, send }) {
  const [placed, setPlaced] = useState(p.placed && p.placed.length ? p.placed : p.options.map(() => 0));
  const used = placed.reduce((a, b) => a + b, 0);
  const add = (i, d) => { const n = [...placed]; n[i] = Math.max(0, n[i] + d); if (n.reduce((a, b) => a + b, 0) > p.total) return; setPlaced(n); haptic(); };
  return html`<div class="p-chips">
    <${Timer} d=${p.deadline} /><${Q} t=${p.question} />
    <p class="p-hint">🪙 ${p.total - used} von ${p.total} Chips übrig</p>
    ${p.options.map((o, i) => { const st = OPTION_STYLE[i % 8]; return html`<div class="chip-line" style=${`--c:${st.c}`}>
      <span class="p-opt-badge"><b>${st.l}</b></span><span class="cl-t">${o.text}</span>
      ${!p.locked && html`<button onClick=${() => add(i, -1)}>−</button>`}<b class="cl-n">${placed[i]}</b>${!p.locked && html`<button onClick=${() => add(i, 1)}>+</button>`}
    </div>`; })}
    ${p.locked ? html`<p class="p-locked-note">✓ Chips liegen</p>` : html`<button class="btn green block" onClick=${() => { send({ type: "chips", list: placed }); send({ type: "confirm" }); }}>🔒 Chips setzen</button>`}
  </div>`;
}

function PickPlayer({ p, send }) {
  return html`<div class="p-pick">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.subtitle && html`<p class="muted center">${p.subtitle}</p>`}
    <div class="pick-grid">${p.candidates.map(c => html`<button class=${cx("pick-card", p.chosen === c.id && "on")} disabled=${p.chosen != null && p.chosen !== c.id} onClick=${() => { haptic(); send({ type: "pickPlayer", id: c.id }); }}>
      <${Monkey} wire=${c.avatar} anim="none" face=${p.chosen === c.id ? "denk" : "neutral"} size=${70} /><b>${c.name}</b><small>${fmtMM(c.balance)}</small></button>`)}</div>
  </div>`;
}

function Bank({ p, send }) {
  return html`<div class="p-bank">
    <${Timer} d=${p.deadline} />
    <div class="bank-top"><div><small>Pott</small><b>${fmtMM(p.pot)}</b></div><div><small>Gebankt</small><b class="gold-text">${fmtMM(p.banked)}</b></div></div>
    <button class="bank-btn" disabled=${p.pot <= 0} onClick=${() => { haptic("success"); send({ type: "bank" }); }}>🏦 BANK!</button>
    <${Q} t=${p.question} />
    <div class="p-opts">${p.options.map((o, i) => html`<${OptButton} o=${o} i=${i} chosen=${p.chosen === o.id} locked=${p.chosen != null} onClick=${() => p.chosen == null && send({ type: "choose", value: o.id })} />`)}</div>
  </div>`;
}

function Cheer({ p, send, me }) {
  return html`<div class="p-cheer">
    <h2 class="p-title">${p.title}</h2>${p.subtitle && html`<p class="muted center">${p.subtitle}</p>`}
    <button class="tap-btn armed" onPointerDown=${() => { haptic(); send({ type: "cheer" }); }}><span class="tap-ico">🥁</span><b>${p.taps}</b><small>TROMMELN!</small></button>
  </div>`;
}

function Confirm({ p, send }) {
  return html`<div class="p-confirm">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.subtitle && html`<p class="muted center">${p.subtitle}</p>`}
    <button class=${cx("btn big block", p.done ? "ghost" : "green")} disabled=${p.done} onClick=${() => { haptic("success"); send({ type: "confirm" }); }}>${p.done ? "✓ " : ""}${p.button}</button>
  </div>`;
}

function Binary({ p, send }) {
  return html`<div class="p-binary">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.subtitle && html`<p class="muted center">${p.subtitle}</p>`}
    <div class="bin-row">${[p.a, p.b].map((l, i) => html`<button class=${cx("bin-btn", i ? "b" : "a", p.chosen === l && "on")} disabled=${p.chosen != null && p.chosen !== l} onClick=${() => { haptic(); send({ type: "binary", value: l }); }}>${l}</button>`)}</div>
  </div>`;
}

function Vote({ p, send }) {
  return html`<div class="p-vote">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <div class="vote-grid">${p.options.map((o, i) => html`<button class=${cx("vote-card", p.chosen === o.id && "on")} style=${`--c:${OPTION_STYLE[i % 8].c};animation-delay:${i * 70}ms`} onClick=${() => { haptic(); send({ type: "vote", value: o.id }); }}>
      <span class="vote-emoji">${o.emoji || "🗳"}</span><b>${o.label}</b>${o.count > 0 && html`<small>${o.count} 🗳</small>`}</button>`)}</div>
  </div>`;
}

function Reveal({ p, me }) {
  const cls = p.correct === true ? "ok" : p.correct === false ? "nope" : "meh";
  const face = p.correct === true ? "jubel" : p.correct === false ? "frust" : "denk";
  return html`<div class=${cx("p-reveal", cls)}>
    <div class="stamp pop-in">${p.title}</div>
    ${me && html`<${Monkey} wire=${me.avatar} face=${face} anim=${face === "jubel" ? "jubel" : face === "frust" ? "frust" : "idle"} size=${140} />`}
    <div class=${cx("rev-delta", p.delta > 0 ? "pos" : p.delta < 0 ? "neg" : "zero")}>${p.delta === 0 ? "±0 MM" : fmtDelta(p.delta) + " MM"}</div>
    ${p.speedBonus ? html`<span class="chip green">⚡ Speed-Bonus +${fmtNum(p.speedBonus)}</span>` : null}
    ${p.streak >= 2 && html`<span class="chip gold">🔥 Serie ${p.streak}</span>`}
    ${p.detail && html`<p class="rev-detail">${p.detail}</p>`}
  </div>`;
}

function Explain({ p, send }) {
  return html`<div class="p-explain">
    <${Timer} d=${p.deadline} />
    <h2 class="p-title">${p.title}</h2>
    ${p.text && html`<p class="muted center">${p.text}</p>`}
    <ol class="p-rules">${p.regeln.map((r, i) => html`<li style=${`animation-delay:${i * 0.12}s`}><span>${i + 1}</span>${r}</li>`)}</ol>
    ${p.gewinn && html`<div class="p-gewinn">💰 ${p.gewinn}</div>`}
    <button class=${cx("btn block big", p.ready ? "ghost" : "green")} disabled=${p.ready} onClick=${() => { haptic("success"); send({ type: "ready", value: "bereit" }); }}>${p.ready ? "✓ Bereit — warte auf die anderen" : "👍 Verstanden, bereit!"}</button>
    ${!p.ready && !p.streik && html`<button class="btn ghost small block" onClick=${() => send({ type: "ready", value: "streik" })}>✊ Streik (bei Mehrheit: Blitzfrage statt Minispiel)</button>`}
    ${p.streik && html`<p class="p-hint">✊ Du streikst.</p>`}
  </div>`;
}

function Actions({ p, send }) {
  return html`<div class="p-actions">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>
    <ul class="p-lines">${p.lines.map(l => html`<li>${l}</li>`)}</ul>
    <div class="p-btns">${p.buttons.map(b => html`<button class=${cx("btn block", b.style === "secondary" ? "ghost" : b.style === "danger" ? "red" : "green")} disabled=${!b.enabled} onClick=${() => { haptic(); send({ type: "button", id: b.id }); }}>${b.label}</button>`)}</div>
  </div>`;
}

function Feedback({ p, send }) {
  const [vals, setVals] = useState(p.questions.map(() => ""));
  if (p.done) return html`<div class="p-idle"><h2>💛 Danke fürs Feedback!</h2></div>`;
  const quick = ["🤩", "👍", "😐", "👎"];
  return html`<div class="p-feedback"><h2 class="p-title">Wie war die Show?</h2>
    ${p.questions.map((q, i) => html`<div class="fb-q"><p>${q}</p><div class="chip-row">${quick.map(e => html`<button class=${cx("pick", vals[i] === e && "on")} onClick=${() => { const n = [...vals]; n[i] = e; setVals(n); }}>${e}</button>`)}</div>
      <input class="text-in" placeholder="oder frei …" value=${quick.includes(vals[i]) ? "" : vals[i]} onInput=${e => { const n = [...vals]; n[i] = e.target.value; setVals(n); }} /></div>`)}
    <button class="btn green block" onClick=${() => send({ type: "feedback", list: vals })}>📨 Abschicken</button></div>`;
}

const UNO_COL = { "🔴": "#FF4D6D", "🟡": "#F5B301", "🟢": "#2BB56C", "🔵": "#3D7BFF", "⚫": "#222" };
function Cards({ p, send }) {
  return html`<div class="p-cards">
    <${Timer} d=${p.deadline} /><h2 class="p-title">${p.title}</h2>${p.hint && html`<p class="p-hint">${p.hint}</p>`}
    <div class="hand">${p.cards.map((c, i) => {
      const parts = String(c.text).split(" ");
      const col = UNO_COL[parts[0]] || null;
      const label = col ? parts.slice(1).join(" ") : c.text;
      return html`<button class=${cx("hand-card", c.removed && "off", col && "uno")} disabled=${c.removed} style=${col ? `--c:${col}` : ""} onClick=${() => { haptic(); send({ type: "choose", value: c.id }); }}><span>${label}</span></button>`;
    })}</div>
    <div class="p-btns">${p.buttons.map(b => html`<button class=${cx("btn small", b.style === "secondary" ? "ghost" : b.style === "danger" ? "red" : "green")} disabled=${!b.enabled} onClick=${() => send({ type: "button", id: b.id })}>${b.label}</button>`)}</div>
  </div>`;
}
