// Spiele-Abend on the stage: how-to, the six boards, results and the
// pass-and-play seat (its prompt is answered right on the iPad).
import { html } from "../vendor/preact-htm.js";
import { decode, cx, fmtMM, fmtNum } from "../lib/core.js";
import { Monkey, TimerBar, Countdown } from "../lib/ui.js";
import { Prompt } from "../lib/prompts.js";
import { StageCtx } from "./ctx.js";

const SEAT_COLORS = ["#FFC93C", "#FF4D6D", "#2BD98A", "#4D8BFF", "#9B6BFF", "#FF8A3D", "#2ED3C6", "#FF6BD6"];
const DICE = ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"];

export function BoardgameScene({ view, b }) {
  const pm = Object.fromEntries(view.players.map(p => [p.id, p]));
  const name = s => (b.sitzNamen && b.sitzNamen[s]) || (pm[s] || {}).name || s;
  const seatColor = s => SEAT_COLORS[Math.max(0, b.sitze.indexOf(s)) % SEAT_COLORS.length];
  const ctx = { pm, name, seatColor, sitze: b.sitze };
  if (b.subphase === "howto") {
    return html`<div class="bg-howto card pop-in">
      <h1>${b.name}</h1>
      <ol class="explain-rules">${b.howto.map((r, i) => html`<li class="rise-in" style=${`animation-delay:${0.2 + i * 0.25}s`}><span>${i + 1}</span>${r}</li>`)}</ol>
      <div class="explain-timer"><${TimerBar} deadline=${b.howtoEndsAt} /></div>
      <div class="chip-row center">${b.sitze.map(s => html`<span class="chip" style=${`border-color:${seatColor(s)}`}>${name(s)}</span>`)}</div>
    </div>`;
  }
  if (b.subphase === "ergebnis" && b.ergebnis) {
    return html`<div class="bg-result">
      <h1 class="pop-in">🏆 ${b.name} — Ergebnis</h1>
      <ol>${[...b.ergebnis].sort((x, y) => x.platz - y.platz).map((r, i) => html`<li class="rise-in" style=${`animation-delay:${i * 0.2}s`}>
        <span class="stand-rank">${r.platz <= 3 ? ["🥇", "🥈", "🥉"][r.platz - 1] : r.platz}</span>
        ${pm[r.sitz] ? html`<${Monkey} wire=${pm[r.sitz].avatar} face=${r.platz === 1 ? "jubel" : "neutral"} anim=${r.platz === 1 ? "jubel" : "idle"} size=${64} />` : html`<span class="seat-local">📱</span>`}
        <b>${r.name}</b><small class="muted">${r.detail}</small><span class="gold-text">${r.lokal ? "Lokaler Sitz" : "+" + fmtMM(r.mm)}</span></li>`)}</ol>
    </div>`;
  }
  const sc = decode(b.view);
  let board;
  switch (sc.kind) {
    case "towers": board = html`<${Towers} v=${sc} ctx=${ctx} />`; break;
    case "werwolf": board = html`<${Werwolf} v=${sc} ctx=${ctx} />`; break;
    case "uno": board = html`<${Uno} v=${sc} ctx=${ctx} />`; break;
    case "madn": board = html`<${Madn} v=${sc} ctx=${ctx} />`; break;
    case "bananopoly": board = html`<${Bananopoly} v=${sc} ctx=${ctx} />`; break;
    case "siedler": board = html`<${Siedler} v=${sc.view || sc} ctx=${ctx} />`; break;
    default: board = html`<p class="muted">…</p>`;
  }
  return html`<div class="bg-scene">
    <div class="bg-board">${board}</div>
    <aside class="bg-side card">
      <h2>${b.name}</h2>
      ${b.aktuellerSpieler && html`<div class="chip gold">Am Zug: ${b.aktuellerSpieler}</div>`}
      ${b.lokalPrompt ? html`<div class="local-seat">
          <p class="local-title">📲 ${b.lokalName}, du bist dran!</p>
          <${Prompt} p=${decode(b.lokalPrompt)} send=${a => StageCtx.cmd({ boardgameLocal: { sitz: b.lokalSitz, action: a } })} compact=${true} />
        </div>`
        : b.lokalerPrompt && html`<p class="local-title">${b.lokalerPrompt}</p>`}
      <button class="btn ghost small" onClick=${() => StageCtx.cmd({ boardgameAbort: {} })}>✕ Spiel abbrechen</button>
    </aside>
  </div>`;
}

function Towers({ v, ctx }) {
  return html`<div class="towers">
    <div class="chip-row center"><span class="chip gold">Stufe ${v.stufe + 1}/8</span><span class="chip red">⚠️ Einsturz ${v.risiko} %</span><span class="chip">${v.chosen.length} gewählt</span></div>
    <div class="tower-row">${v.towers.map(t => html`<div class=${cx("tower", t.collapsed && "collapsed")}>
      <div class="tower-climbers">${t.climbers.map(id => ctx.pm[id] && html`<${Monkey} wire=${ctx.pm[id].avatar} face="denk" anim="idle" size=${46} />`)}</div>
      ${Array.from({ length: Math.max(1, t.height) }, (_, i) => html`<div class="tower-block" style=${`width:${110 - i * 5}px`}></div>`).reverse()}
      <div class="tower-base">${t.collapsed ? "💥" : "🗼"} ${fmtNum(t.loot)}</div>
    </div>`)}</div>
    <div class="chip-row center">${Object.entries(v.banked || {}).map(([id, n]) => html`<span class="chip">${ctx.name(id)}: ${n} 🍌</span>`)}</div>
  </div>`;
}

function SeatRing({ ctx, current, dead = [], roles, hands, center, night }) {
  const n = ctx.sitze.length;
  return html`<div class=${cx("seat-ring", night && "night")}>
    <div class="ring-center">${center}</div>
    ${ctx.sitze.map((s, i) => {
      const a = (i / n) * Math.PI * 2 - Math.PI / 2;
      const x = Math.cos(a) * 42, y = Math.sin(a) * 40;
      const p = ctx.pm[s];
      return html`<div class=${cx("ring-seat", current === s && "on", dead.includes(s) && "dead")} style=${`left:${50 + x}%;top:${50 + y}%;--c:${ctx.seatColor(s)}`}>
        ${p ? html`<${Monkey} wire=${p.avatar} face=${dead.includes(s) ? "frust" : current === s ? "denk" : "neutral"} anim=${dead.includes(s) ? "none" : "idle"} size=${70} />` : html`<span class="seat-local">📱</span>`}
        <b>${ctx.name(s)}</b>
        ${hands && hands[s] != null && html`<small>🃏 ${hands[s]}</small>`}
        ${roles && roles[s] && html`<small>${{ werwolf: "🐺", seherin: "🔮", hexe: "🧪" }[roles[s]] || "🐒"} ${roles[s]}</small>`}
      </div>`;
    })}
  </div>`;
}

function Werwolf({ v, ctx }) {
  const night = v.phase.startsWith("nacht");
  return html`<div class=${cx("werwolf", night && "night")}>
    <h2 class="ww-text" key=${v.text}>${v.text}</h2>
    <div class="chip-row center"><span class="chip gold">${night ? "🌙 Nacht" : "☀️ Tag"} ${v.dayNumber}</span>${v.deadline && html`<span class="chip">⏱ <${Countdown} deadline=${v.deadline} /></span>`}<span class="chip">${v.alive.length} leben · ${v.dead.length} tot</span></div>
    <${SeatRing} ctx=${ctx} dead=${v.dead} roles=${v.revealRoles} center=${night ? "🌙" : "☀️"} night=${night} />
  </div>`;
}

const UNO_COL = { rot: "#FF4D6D", gelb: "#F5B301", gruen: "#2BB56C", blau: "#3D7BFF", schwarz: "#222" };
export function UnoCard({ card, color, small }) {
  const col = UNO_COL[card.farbe === "schwarz" ? color || "schwarz" : card.farbe] || "#222";
  const label = { skip: "⛔", reverse: "🔄", draw2: "+2", wild: "🌈", wild4: "+4" }[card.wert] || card.wert;
  return html`<div class=${cx("uno-card", small && "small")} style=${`--c:${col}`}><span>${label}</span></div>`;
}

function Uno({ v, ctx }) {
  return html`<div class="uno">
    <div class="chip-row center"><span class="chip">${v.direction > 0 ? "↻" : "↺"} Richtung</span><span class="chip">🂠 Stapel ${v.drawPile}</span>${v.deadline && html`<span class="chip">⏱ <${Countdown} deadline=${v.deadline} /></span>`}</div>
    <${SeatRing} ctx=${ctx} current=${v.current} hands=${v.hands} center=${html`<div class="uno-center"><${UnoCard} card=${v.topCard} color=${v.color} /></div>`} />
    ${v.lastEvent && html`<p class="board-event pop-in" key=${v.lastEvent}>${v.lastEvent}</p>`}
  </div>`;
}

const RING = [[0, 4], [1, 4], [2, 4], [3, 4], [4, 4], [4, 3], [4, 2], [4, 1], [4, 0], [5, 0], [6, 0], [6, 1], [6, 2], [6, 3], [6, 4], [7, 4], [8, 4], [9, 4], [10, 4], [10, 5], [10, 6], [9, 6], [8, 6], [7, 6], [6, 6], [6, 7], [6, 8], [6, 9], [6, 10], [5, 10], [4, 10], [4, 9], [4, 8], [4, 7], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6], [0, 5]];
const HOUSES = [[[0, 0], [1, 0], [0, 1], [1, 1]], [[9, 0], [10, 0], [9, 1], [10, 1]], [[9, 9], [10, 9], [9, 10], [10, 10]], [[0, 9], [1, 9], [0, 10], [1, 10]]];
const LANES = [[[1, 5], [2, 5], [3, 5], [4, 5]], [[5, 1], [5, 2], [5, 3], [5, 4]], [[9, 5], [8, 5], [7, 5], [6, 5]], [[5, 9], [5, 8], [5, 7], [5, 6]]];

function Madn({ v, ctx }) {
  const cell = 100 / 11;
  const at = ([x, y]) => `left:${(x + 0.5) * cell}%;top:${(y + 0.5) * cell}%`;
  const MC = ["#FFC93C", "#FF4D6D", "#2BD98A", "#4D8BFF"];
  const tokPos = t => {
    const seat = Math.max(0, ctx.sitze.indexOf(t.sitz)) % 4;
    if (t.pos === -1) return HOUSES[seat][t.index % 4];
    if (t.pos >= 100) return LANES[seat][Math.min(3, t.pos - 100)];
    return RING[((t.pos % 40) + 40) % 40];
  };
  return html`<div class="madn-wrap">
    <div class="chip-row center"><span class="chip">${v.kurz ? "Kurze Partie" : "Klassisch"}</span>${v.dice && html`<span class="dice pop-in" key=${v.seq}>${DICE[v.dice]}</span>`}${v.deadline && html`<span class="chip">⏱ <${Countdown} deadline=${v.deadline} /></span>`}</div>
    <div class="madn">
      ${RING.map((p, i) => html`<i class="field" style=${at(p) + (i % 10 === 0 ? `;background:${MC[i / 10]}` : "")}></i>`)}
      ${HOUSES.flatMap((h, s) => h.map(p => html`<i class="field house" style=${at(p) + `;--c:${MC[s]}`}></i>`))}
      ${LANES.flatMap((h, s) => h.map(p => html`<i class="field lane" style=${at(p) + `;--c:${MC[s]}`}></i>`))}
      ${v.tokens.map(t => { const seat = Math.max(0, ctx.sitze.indexOf(t.sitz)) % 4; const p = ctx.pm[t.sitz];
        return html`<div class=${cx("token", v.current === t.sitz && "on")} style=${at(tokPos(t)) + `;--c:${MC[seat]}`}>${p ? html`<${Monkey} wire=${p.avatar} anim="none" size=${34} />` : "📱"}</div>`; })}
    </div>
    ${v.message && html`<p class="board-event">${v.message}</p>`}
  </div>`;
}

function Bananopoly({ v, ctx }) {
  const cellOf = i => (i < 7 ? [0, 7 - i] : i < 14 ? [i - 7, 0] : i < 21 ? [7, i - 14] : [28 - i, 7]);
  const PAIR = ["#8B5E34", "#4D8BFF", "#9B6BFF", "#FF8A3D", "#FF4D6D", "#FFC93C", "#2BD98A", "#2ED3C6", "#C0C0C0"];
  const at = ([x, y]) => `left:${x * 12.5}%;top:${y * 12.5}%`;
  return html`<div class="bpoly-wrap">
    <div class="chip-row center"><span class="chip gold">Runde ${v.round}/4</span>${v.dice && html`<span class="dice pop-in">${v.dice.map(d => DICE[d]).join(" ")}</span>`}${v.deadline && html`<span class="chip">⏱ <${Countdown} deadline=${v.deadline} /></span>`}</div>
    <div class="bpoly">
      <div class="bpoly-title">BANANOPOLY</div>
      ${v.fields.map(f => { const o = v.owners[f.index]; return html`<div class=${cx("bp-field", "t-" + f.typ)} style=${at(cellOf(f.index)) + (o ? `;box-shadow:inset 0 0 0 4px ${ctx.seatColor(o)}` : "")}>
        ${f.paar != null && html`<i style=${`background:${PAIR[f.paar % PAIR.length]}`}></i>`}<span>${f.name}</span>${f.preis > 0 && html`<small>${f.preis}</small>`}${v.stands.includes(f.index) && html`<b>🏪</b>`}</div>`; })}
      ${Object.entries(v.positions).map(([s, pos], k) => { const [x, y] = cellOf(pos); const p = ctx.pm[s];
        return html`<div class=${cx("bp-token", v.current === s && "on")} style=${`left:${x * 12.5 + 2 + (k % 3) * 3}%;top:${y * 12.5 + 4 + Math.floor(k / 3) * 3}%;--c:${ctx.seatColor(s)}`}>${p ? html`<${Monkey} wire=${p.avatar} anim="none" size=${30} />` : "📱"}</div>`; })}
    </div>
    <div class="chip-row center">${ctx.sitze.map(s => html`<span class=${cx("chip", v.current === s && "gold")}>${ctx.name(s)}: ${fmtNum(v.cash[s] || 0)} MM</span>`)}</div>
    ${v.event && html`<p class="board-event pop-in" key=${v.event}>${v.event}</p>`}
  </div>`;
}

const RES = { banane: ["#F5B301", "🍌"], holz: ["#2E7D32", "🪵"], stein: ["#7D8CA3", "🪨"], kokos: ["#8B5E34", "🥥"], blatt: ["#2BD98A", "🍃"], duerr: ["#C9A66B", "🏜️"] };
function Siedler({ v, ctx }) {
  const R = 1, S3 = Math.sqrt(3);
  const center = (q, r) => [S3 * (q + r / 2), 1.5 * r];
  const pts = v.hexes.map(h => center(h.q, h.r));
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  const minX = Math.min(...xs) - 1.2, maxX = Math.max(...xs) + 1.2, minY = Math.min(...ys) - 1.3, maxY = Math.max(...ys) + 1.3;
  const parse = k => k.split(",").map(Number);
  const hexPath = (cx0, cy0) => Array.from({ length: 6 }, (_, i) => { const a = (Math.PI / 180) * (60 * i - 30); return `${cx0 + Math.cos(a) * 0.97},${cy0 + Math.sin(a) * 0.97}`; }).join(" ");
  return html`<div class="siedler-wrap">
    <div class="chip-row center"><span class="chip">${v.phase}</span>${v.dice && html`<span class="dice">🎲 ${v.dice[0] + v.dice[1]}</span>`}${v.longestRoad && html`<span class="chip">🛤️ ${ctx.name(v.longestRoad)}</span>`}${v.deadline && html`<span class="chip">⏱ <${Countdown} deadline=${v.deadline} /></span>`}</div>
    <svg class="siedler" viewBox=${`${minX} ${minY} ${maxX - minX} ${maxY - minY}`}>
      ${v.hexes.map((h, i) => { const [x, y] = pts[i]; const [col, emo] = RES[h.rohstoff] || ["#666", "?"]; return html`<g>
        <polygon points=${hexPath(x, y)} fill=${col} stroke="#5A3A1C" stroke-width="0.06" />
        <text x=${x} y=${y - 0.18} font-size="0.5" text-anchor="middle">${emo}</text>
        ${h.zahl && html`<circle cx=${x} cy=${y + 0.36} r="0.26" fill="#FFF6E3" /><text x=${x} y=${y + 0.46} font-size="0.3" font-weight="900" text-anchor="middle" fill=${h.zahl === 6 || h.zahl === 8 ? "#E0264F" : "#1A1208"}>${h.zahl}</text>`}
        ${v.robber === i && html`<text x=${x + 0.45} y=${y - 0.3} font-size="0.45">🐒</text>`}
      </g>`; })}
      ${v.roads.map(r => { const [a, b] = r.edge.split("|").map(parse); return a && b && html`<line x1=${a[0]} y1=${a[1]} x2=${b[0]} y2=${b[1]} stroke=${ctx.seatColor(r.sitz)} stroke-width="0.14" stroke-linecap="round" />`; })}
      ${v.buildings.map(bd => { const [x, y] = parse(bd.corner); return html`<g><circle cx=${x} cy=${y} r=${bd.stufe === 2 ? 0.28 : 0.22} fill=${ctx.seatColor(bd.sitz)} stroke="#1A1208" stroke-width="0.04" /><text x=${x} y=${y + 0.1} font-size="0.26" text-anchor="middle">${bd.stufe === 2 ? "🌳" : "🏠"}</text></g>`; })}
    </svg>
    <div class="chip-row center">${ctx.sitze.map(s => html`<span class=${cx("chip", v.current === s && "gold")} style=${`border-color:${ctx.seatColor(s)}`}>${ctx.name(s)} ⭐${v.points[s] || 0} · 🃏${v.handSizes[s] || 0}</span>`)}</div>
    ${v.offer && html`<p class="board-event">🤝 ${v.offer}</p>`}${v.event && html`<p class="board-event">${v.event}</p>`}
  </div>`;
}
