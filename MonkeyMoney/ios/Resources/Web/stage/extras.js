// Minigame widgets around the question wall — one renderer per StageExtra kind.
import { html } from "../vendor/preact-htm.js";
import { cx, fmtMM, fmtNum, fmtDelta, serverNow, OPTION_STYLE } from "../lib/core.js";
import { Monkey, Money, PixelImage } from "../lib/ui.js";
import { Secs as Countdown, useSecondsLeft } from "./fx.js";
import { NEU } from "./extras-neu.js";
import { NEU2 } from "./extras-neu2.js";

/**
 * Widget plugins for newer formats: kind → { placement(extra, wall), tiles(extra, scene, view), Widget }.
 * Each module owns its kinds (extras-neu.js: speed/survival/schaukel/herde/memory, extras-neu2.js: the next batch).
 */
const PLUG = { ...NEU, ...NEU2 };

const pmap = view => Object.fromEntries(view.players.map(p => [p.id, p]));

/** Where a widget lives: left of the question, below it, in the side column, or none. */
export function extraPlacement(extra, wall) {
  const plug = PLUG[extra.kind];
  if (plug) return plug.placement ? plug.placement(extra, wall) : "below";
  switch (extra.kind) {
    case "none": return null;
    case "pixel": return extra.image ? "left" : null;
    case "bomb": case "sack": case "buzzers": return "side";
    case "bankPot": return "below";
    case "lianen": case "pies": return "side";
    case "song": return "left";
    default: return wall && wall.options && wall.options.length > 0 ? "below" : "below";
  }
}

/** Per-player podium extras: who locked in, tags like 💣 or 🏦 +400. */
export function extraTileInfo(extra, scene, view) {
  const plug = PLUG[extra.kind];
  if (plug && plug.tiles) return plug.tiles(extra, scene, view) || { tags: {}, locked: [] };
  const tags = {};
  let locked = [];
  switch (extra.kind) {
    case "pixel": locked = extra.locked || []; break;
    case "bomb": if (extra.holder) tags[extra.holder] = { text: extra.exploded === extra.holder ? "💥" : "💣", cls: "bomb", hot: true }; break;
    case "bankPot": for (const [pid, v] of Object.entries(extra.banked || {})) tags[pid] = { text: "🏦 " + fmtNum(v), cls: "bank" }; break;
    case "sack": for (const [pid, v] of Object.entries(extra.frozen || {})) tags[pid] = { text: "🥥 " + fmtNum(v), cls: "bank" }; break;
    case "buzzers": (extra.order || []).forEach((pid, i) => (tags[pid] = { text: i === 0 ? "🔔 1." : `${i + 1}.`, cls: i === 0 ? "gold" : "", hot: i === 0 })); for (const pid of extra.lockedOut || []) tags[pid] = { text: "🚫", cls: "out" }; break;
    case "duel": tags[extra.a] = { text: "⚔️", cls: "gold", hot: true }; tags[extra.b] = { text: "⚔️", cls: "gold", hot: true }; break;
    case "oneVsAll": tags[extra.solist] = { text: "🦸 Solo", cls: "gold", hot: true }; break;
    case "steal": if (extra.thief) tags[extra.thief] = { text: "🦹", cls: "gold" }; if (extra.victim) tags[extra.victim] = { text: "😱", cls: "out" }; break;
    case "pies": for (const [pid, d] of Object.entries(extra.dirt || {})) if (d > 0) tags[pid] = { text: "🥧".repeat(Math.min(d, 5)), cls: "pie" }; for (const pid of extra.out || []) tags[pid] = { text: "🥧 raus", cls: "out" }; break;
    case "lianen": return { tags, locked, ropes: extra.lengths || {} };
    case "steps": for (const [pid, v] of Object.entries(extra.banked || {})) if (v) tags[pid] = { text: "✔️ " + fmtNum(v), cls: "bank" }; break;
    case "auction": if (extra.leader) tags[extra.leader] = { text: "🔨 " + fmtNum((extra.bids || {})[extra.leader] || 0), cls: "gold", hot: true }; break;
    default: break;
  }
  return { tags, locked };
}

export function Extra({ extra, scene, view, revealed, full }) {
  const pm = pmap(view);
  const plug = PLUG[extra.kind];
  if (plug && plug.Widget) return html`<${plug.Widget} x=${extra} pm=${pm} scene=${scene} view=${view} revealed=${revealed} full=${!!full} />`;
  switch (extra.kind) {
    case "none": return null;
    case "pixel": return html`<${PixelWidget} x=${extra} pm=${pm} scene=${scene} />`;
    case "numberLine": return html`<${NumberLine} x=${extra} pm=${pm} revealed=${revealed} />`;
    case "bankPot": return full && scene.kind === "aufloesung" ? html`<${BankAuszug} x=${extra} pm=${pm} deltas=${scene.deltas || {}} />` : html`<${BankPot} x=${extra} pm=${pm} />`;
    case "bomb": return html`<${Bomb} x=${extra} pm=${pm} />`;
    case "bets": return html`<${Bets} x=${extra} pm=${pm} revealed=${revealed} compact=${!!scene.wall} />`;
    case "ladder": return html`<${Ladder} x=${extra} pm=${pm} revealed=${revealed} />`;
    case "lianen": return html`<${Lianen} x=${extra} pm=${pm} revealed=${revealed} view=${view} />`;
    case "sack": return html`<${Sack} x=${extra} pm=${pm} />`;
    case "buzzers": return html`<${Buzzers} x=${extra} pm=${pm} />`;
    case "chips": return html`<${Chips} x=${extra} scene=${scene} />`;
    case "auction": return html`<${Auction} x=${extra} pm=${pm} />`;
    case "bluff": return html`<${Bluff} x=${extra} pm=${pm} />`;
    case "duel": return html`<${Duel} x=${extra} pm=${pm} full=${!!full} />`;
    case "steps": return html`<${Steps} x=${extra} pm=${pm} />`;
    case "pies": return html`<${Pies} x=${extra} pm=${pm} />`;
    case "telegram": return html`<${Telegram} x=${extra} pm=${pm} full=${!!full} />`;
    case "oneVsAll": return html`<${OneVsAll} x=${extra} pm=${pm} />`;
    case "song": return html`<${Song} x=${extra} />`;
    case "steal": return html`<${Steal} x=${extra} pm=${pm} />`;
    case "card": return html`<${InfoCard} x=${extra} full=${!!full} />`;
    default: return null;
  }
}

const Face = ({ p, face = "neutral", anim = "none", size = 44 }) => (p ? html`<${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} />` : null);

function PixelWidget({ x, pm, scene }) {
  const sharp = x.level >= x.maxLevel || scene.kind === "aufloesung";
  return html`<div class=${cx("x-pixel", sharp && "sharp")}>
    <div class="pixel-frame">
      <${PixelImage} src=${"/media/pixel/" + x.image} level=${x.level} maxLevel=${x.maxLevel} />
      <span class="pixel-scan"></span>
      <div class="pixel-jack"><small>${sharp ? "Jackpot" : "Jetzt raten!"}</small><b>🫙 ${fmtMM(x.jackpot)}</b></div>
    </div>
    <div class="pixel-stair">${x.stufen.map((v, i) => html`<div class=${cx("stair", i === x.level && "on", i < x.level && "past")}><span>${i + 1}</span><b>${fmtNum(v)}</b></div>`)}</div>
  </div>`;
}

function NumberLine({ x, pm, revealed }) {
  const pos = v => {
    if (x.log) { const lo = Math.log(Math.max(1e-9, x.min)), hi = Math.log(Math.max(1e-9, x.max)); return ((Math.log(Math.max(1e-9, v)) - lo) / (hi - lo)) * 100; }
    return ((v - x.min) / (x.max - x.min || 1)) * 100;
  };
  const clamp = v => Math.max(1, Math.min(99, v));
  const show = revealed && x.truth != null;
  // Pins that would collide get their own row (up to three), nearest-first gets the lowest row.
  const rows = {};
  if (show) {
    const last = [-99, -99, -99];
    for (const g of [...x.guesses].sort((a, b) => a.value - b.value)) {
      const p = clamp(pos(g.value));
      let r = last.findIndex(l => p - l >= 7);
      if (r < 0) r = last.indexOf(Math.min(...last));
      last[r] = p;
      rows[g.playerId] = r;
    }
  }
  return html`<div class=${cx("x-numline", show && "show")}>
    <div class="nl-track">
      <div class="nl-ends"><span>${fmtNum(x.min)}</span><span>${fmtNum(x.max)} ${x.unit}</span></div>
      <div class="nl-bar"></div>
      ${show && x.guesses.map((g, i) => html`<div class=${cx("nl-pin", g.platz === 1 && "best")} style=${`left:${clamp(pos(g.value))}%;animation-delay:${i * 0.2}s;--row:${rows[g.playerId] || 0}`}>
        <${Face} p=${pm[g.playerId]} face=${g.platz === 1 ? "jubel" : "neutral"} size=${50} />
        <small>${fmtNum(g.value)}</small></div>`)}
      ${show && html`<div class="nl-truth pop-in" style=${`left:${clamp(pos(x.truth))}%`}><span>🎯 ${fmtNum(x.truth)} ${x.unit}</span></div>`}
    </div>
    ${!show && html`<div class="x-wait"><span class="xw-ico">🔢</span><p>Schätzt auf euren Handys — am nächsten dran gewinnt!</p><span class="chip">${x.guesses.length} ${x.guesses.length === 1 ? "Tipp" : "Tipps"}</span></div>`}
  </div>`;
}

function BankPot({ x, pm }) {
  const runLeft = useSecondsLeft(x.runEndsAt);
  return html`<div class=${cx("x-bank", x.verdict && "v-" + x.verdict)}>
    <div class="bank-pot"><small>Im Pott</small><${Money} value=${x.pot} /></div>
    <div class="bank-chain">${[...x.chain].reverse().map((v, ri) => { const i = x.chain.length - 1 - ri; return html`<div class=${cx("chain-step", i === x.chainStep && "on", i < x.chainStep && "past")}>${fmtNum(v)}</div>`; })}</div>
    <div class="bank-meta"><span class="chip">Durchgang ${x.durchgang}/${x.durchgaenge}</span>${x.runEndsAt && runLeft > 0 && html`<span class="chip">⏱ <${Countdown} deadline=${x.runEndsAt} /> s</span>`}
      ${x.lastBanker && pm[x.lastBanker] && html`<span class="chip green bank-last">🏦 ${pm[x.lastBanker].name} hat gebankt</span>`}</div>
    ${x.verdict && html`<div class="bank-verdict pop-in" key=${x.verdict + x.chainStep}>${{ waechst: "📈 Kette wächst!", haelt: "✋ Kette hält", verbrennt: "🔥 Verbrannt!" }[x.verdict] || x.verdict}</div>`}
  </div>`;
}

function BankAuszug({ x, pm, deltas }) {
  const rows = Object.keys(pm).map(id => [id, deltas[id] || 0]).sort((a, b) => b[1] - a[1]);
  const max = Math.max(1, ...rows.map(r => r[1]));
  return html`<div class=${cx("bank-auszug", rows.length > 5 && "dense")}>
    <div class="ba-head"><span>🏦 Kontoauszug</span><small>gebankt in dieser Runde</small></div>
    ${rows.map(([id, v], i) => html`<div class=${cx("ba-row rise-in", i === 0 && v > 0 && "top")} style=${`animation-delay:${i * 0.12}s`}>
    <${Face} p=${pm[id]} face=${v > 0 ? "jubel" : "frust"} anim=${i === 0 ? "jubel" : "idle"} size=${rows.length > 5 ? 38 : 46} /><b class="ba-name">${pm[id].name}</b>
    <div class="stand-bar"><i style=${`transform:scaleX(${Math.max(0, v) / max})`}></i></div><b class="gold-text">${fmtMM(v)}</b></div>`)}</div>`;
}

function Bomb({ x, pm }) {
  const holder = pm[x.holder];
  const boom = !!x.exploded;
  return html`<div class=${cx("x-bomb", boom && "boom")} style=${`--t:${x.tension}`}>
    <div class="bomb-ico">${boom ? "💥" : "🍌"}</div>
    <div class="bomb-fuse"><i style=${`transform:scaleX(${1 - x.tension})`}></i></div>
    ${holder && html`<div class="bomb-holder"><${Face} p=${holder} face=${boom ? "frust" : "denk"} anim=${boom ? "frust" : "denk"} size=${78} /><b>${boom ? `${holder.name} ist matschig!` : holder.name}</b>${!boom && html`<small>hält die Stinkbanane</small>`}</div>`}
    <span class="chip">🔁 ${x.passes} Pässe · Durchgang ${x.durchgang}</span>
  </div>`;
}

function Bets({ x, pm, revealed, compact }) {
  const n = x.bets.length;
  return html`<div class=${cx("x-bets", !compact && n > 5 && "many")}>
    ${x.teaser && !compact && html`<div class="bets-teaser">🎲 ${x.teaser}</div>`}
    <div class=${cx("bets-row", compact && "compact")} style=${!compact ? `--cols:${n > 5 ? Math.ceil(n / 2) : n}` : ""}>${x.bets.map((b, i) => html`<div class=${cx("bet-card", b.revealed && "open", !b.revealed && b.betrag > 0 && "set")} style=${`animation-delay:${i * 0.12}s`}>
      <${Face} p=${pm[b.playerId]} face=${b.revealed ? "denk" : "neutral"} anim="idle" size=${compact ? 40 : n > 5 ? 70 : 90} />
      ${!compact && html`<b>${(pm[b.playerId] || {}).name || ""}</b>`}
      <span class="bet-amt">${b.revealed ? fmtMM(b.betrag) : x.phase === "setzen" && b.betrag === 0 ? html`<i class="dots"><i></i><i></i><i></i></i>` : "🤫 ?"}</span>
    </div>`)}</div>
  </div>`;
}

function Ladder({ x, pm, revealed }) {
  return html`<div class=${cx("x-ladder", x.correctOrder.length > 4 && "many")}>${x.correctOrder.map((idx, pos) => html`<div class=${cx("ladder-step", pos < x.revealedSteps && "open")} style=${`animation-delay:${pos * 0.2}s`}>
    <span class="ls-n">${pos + 1}</span><span class="ls-t">${pos < x.revealedSteps ? x.items[idx] : html`<i class="ls-hidden">? ? ?</i>`}</span>${pos < x.revealedSteps && x.werte[idx] && html`<small>${x.werte[idx]}</small>`}
  </div>`)}</div>`;
}

function Lianen({ x, pm, revealed, view }) {
  return html`<div class="x-lianen-side">
    <div class="lianen-w"><small>Einsatz W</small><b>${fmtMM(x.w)}</b></div>
    <div class="lianen-rules"><span class="chip green">✔ richtig: +W</span><span class="chip red">✗ falsch: −½ W</span></div>
    <p class="muted">Die Liane über jedem Affen zeigt, wie weit er vom Krokodil weg ist.</p>
    <div class="croc">🐊</div>
  </div>`;
}
function LianenWide({ x, pm, revealed, view }) {
  const ids = view.players.map(p => p.id).filter(id => x.lengths[id] != null);
  return html`<div class="x-lianen">
    <div class="lianen-w">W = ${fmtMM(x.w)}</div>
    <div class="lianen-row">${ids.map(id => {
      const len = x.lengths[id];
      const d = x.deltas[id];
      return html`<div class="liana" key=${id}>
        <div class="liana-rope" style=${`height:${8 + len * 82}px`}></div>
        <div class="liana-monkey"><${Face} p=${pm[id]} face=${revealed && d > 0 ? "jubel" : revealed && d < 0 ? "frust" : "denk"} anim=${revealed && d > 0 ? "jubel" : "idle"} size=${48} /></div>
      </div>`;
    })}</div>
    <div class="croc">🐊🐊🐊</div>
  </div>`;
}

function Sack({ x, pm }) {
  const f = x.start ? x.current / x.start : 1;
  return html`<div class=${cx("x-sack", f < 0.35 && "low")}>
    <div class="sack" style=${`transform:scale(${0.55 + f * 0.45})`}>💰</div>
    <${Money} value=${x.current} class="sack-amt" />
    <div class="sack-bar"><i style=${`transform:scaleX(${f})`}></i></div>
    <small class="muted">von ${fmtMM(x.start)} — schrumpft!</small>
  </div>`;
}

function Buzzers({ x, pm }) {
  return html`<div class=${cx("x-buzz", x.armed && "armed")}>
    <div class="buzz-light"><span class="buzz-dot"></span>${x.armed ? "BUZZER FREI!" : "Gleich …"}</div>
    <div class="chip-row center">${x.stufe && html`<span class="chip gold">${x.stufe}</span>`}<span class="chip">💰 ${fmtMM(x.wert)}</span></div>
    ${x.order.length > 0 && html`<ol class="buzz-order">${x.order.map((id, i) => html`<li class="pop-in" key=${id}><b>${i + 1}.</b><${Face} p=${pm[id]} size=${36} /><span>${(pm[id] || {}).name}</span></li>`)}</ol>`}
  </div>`;
}

function Chips({ x, scene }) {
  const opts = (scene.wall && scene.wall.options) || [];
  const max = Math.max(1, ...x.perOption);
  const total = x.perOption.reduce((a, b) => a + b, 0);
  return html`<div class="x-chips">
    ${x.perOption.map((n, i) => html`<div class=${cx("chip-col", n === max && n > 0 && "top")} style=${`--c:${OPTION_STYLE[i % 8].c};--d:${OPTION_STYLE[i % 8].d}`}>
      <span class="chip-l">${OPTION_STYLE[i % 8].l}</span>
      <div class="chip-track"><div class="chip-stack" style=${`transform:scaleX(${n / max})`}></div></div>
      <b>${n} 🪙</b>${x.quotes && x.quotes[i] != null && html`<small>×${fmtNum(x.quotes[i])}</small>`}
    </div>`)}
    ${total === 0 && html`<p class="chips-hint muted">🪙 Verteilt eure Chips auf den Handys auf die Türen!</p>`}
  </div>`;
}

function Auction({ x, pm }) {
  const bids = Object.entries(x.bids || {}).sort((a, b) => b[1] - a[1]);
  const top = bids.length ? bids[0][1] : 1;
  return html`<div class=${cx("x-auction", !bids.length && "empty")}>
    <div class="auc-head"><span class="auc-gavel">🔨</span><span>Auktion</span>${x.endsAt && html`<span class="chip">⏱ <${Countdown} deadline=${x.endsAt} /> s</span>`}</div>
    ${!bids.length && html`<p class="auc-empty">Bietet auf euren Handys — wer am meisten bietet, darf antworten!</p>`}
    <div class="auc-bids">${bids.map(([id, v], i) => html`<div class=${cx("auc-bid", id === x.leader && "lead")} key=${id} style=${`--v:${v / Math.max(1, top)}`}>
      <span class="auc-rank">${i + 1}</span><${Face} p=${pm[id]} size=${44} /><b>${(pm[id] || {}).name}</b><i class="auc-bar"></i><span class="auc-amt">${fmtMM(v)}</span></div>`)}</div>
  </div>`;
}

function Bluff({ x, pm }) {
  const votes = {};
  for (const v of Object.values(x.votes || {})) votes[v] = (votes[v] || 0) + 1;
  if (!x.entries.length) return x.phase === "luegen"
    ? html`<div class="x-wait"><span class="xw-ico">✍️</span><p>Alle schreiben eine glaubwürdige Lüge …</p></div>` : null;
  return html`<div class=${cx("x-bluff", x.entries.length > 4 && "many")}>${x.entries.map((e, i) => html`<div class=${cx("bluff-entry", x.truthIndex === e.id && "truth", x.truthIndex != null && x.truthIndex !== e.id && "lie")} key=${e.id}>
    <span class="be-l">${OPTION_STYLE[i % 8].l}</span><span class="be-t">${e.text}</span>
    ${votes[e.id] && html`<span class="chip">🗳 ${votes[e.id]}</span>`}
    ${x.authors && x.authors[e.id] && pm[x.authors[e.id]] && html`<span class="be-author">🤥 ${pm[x.authors[e.id]].name}</span>`}
    ${x.truthIndex === e.id && html`<span class="chip green">✔️ Wahrheit</span>`}
  </div>`)}</div>`;
}

function Duel({ x, pm, full }) {
  const A = pm[x.a], B = pm[x.b];
  const bar = v => Math.max(0, Math.min(1, v / Math.max(1, x.maxScore)));
  const lead = x.scoreA === x.scoreB ? null : x.scoreA > x.scoreB ? "a" : "b";
  const size = full ? 128 : 76;
  const bets = Object.values(x.bets || {});
  const onA = bets.filter(v => v === x.a).length, onB = bets.filter(v => v === x.b).length;
  return html`<div class=${cx("x-duel", full && "full")}>
    <div class=${cx("duel-side a", lead === "a" && "lead")}><${Face} p=${A} face=${lead === "a" ? "jubel" : "denk"} anim="idle" size=${size} /><b>${A && A.name}</b><div class="hp"><i style=${`transform:scaleX(${bar(x.scoreA)})`}></i></div><span class="duel-score">${x.scoreA}</span>${full && bets.length > 0 && html`<small class="duel-bets">🎲 ${onA} ${onA === 1 ? "Wette" : "Wetten"}</small>`}</div>
    <div class=${cx("duel-vs", (x.label || "").length > 6 && "long")}>${x.label || "VS"}</div>
    <div class=${cx("duel-side b", lead === "b" && "lead")}><${Face} p=${B} face=${lead === "b" ? "jubel" : "denk"} anim="idle" size=${size} /><b>${B && B.name}</b><div class="hp"><i style=${`transform:scaleX(${bar(x.scoreB)})`}></i></div><span class="duel-score">${x.scoreB}</span>${full && bets.length > 0 && html`<small class="duel-bets">🎲 ${onB} ${onB === 1 ? "Wette" : "Wetten"}</small>`}</div>
  </div>`;
}

function Steps({ x, pm }) {
  return html`<div class="x-steps">${x.labels.map((l, i) => html`<div class=${cx("step", i === x.current && "on", i < x.current && "past")}>
    <span>${l}</span><div class="step-who">${Object.entries(x.positions || {}).filter(([, v]) => v === i).map(([id]) => html`<${Face} p=${pm[id]} size=${30} />`)}</div></div>`)}</div>`;
}

function Pies({ x, pm }) {
  const out = (x.out || []).length;
  return html`<div class="x-lianen-side x-pies-side">
    <div class="pie-big">🥧</div>
    <p class="muted">Falsch = Torte ins Gesicht.<br />Bei <b>${x.maxDirt}</b> Torten ist man raus.</p>
    ${out > 0 && html`<span class="chip red">🥧 ${out} raus</span>`}
  </div>`;
}
function PiesWide({ x, pm }) {
  return html`<div class="x-pies">${Object.entries(x.dirt || {}).map(([id, d]) => html`<div class=${cx("pie-p", (x.out || []).includes(id) && "out")}>
    <${Face} p=${pm[id]} face=${d > 0 ? "frust" : "neutral"} size=${56} /><div class="pie-bar">${Array.from({ length: x.maxDirt }, (_, i) => html`<i class=${i < d ? "on" : ""}>🥧</i>`)}</div></div>`)}</div>`;
}

function Telegram({ x, pm, full }) {
  return html`<div class=${cx("x-tele", full && "full")}>
    ${x.letters.length > 0 && html`<div class="tele-letters">${x.letters.map((l, i) => html`<span class=${cx("tl", x.solved.includes(i) && "ok", l && "set")} style=${`animation-delay:${i * 0.06}s`}>${l || ""}</span>`)}</div>`}
    ${x.wort && html`<div class="tele-word pop-in">📨 ${x.wort}</div>`}
    <div class="tele-pairs">${x.pairs.map((p, k) => html`<span class="tele-pair" style=${`--c:${OPTION_STYLE[k % 8].c}`}>${p.map(id => pm[id] && html`<span class="tp-p"><${Face} p=${pm[id]} size=${full ? 40 : 30} /><b>${pm[id].name}</b></span>`)}</span>`)}</div>
  </div>`;
}

function OneVsAll({ x, pm }) {
  const S = pm[x.solist];
  return html`<div class="x-ova">
    <div class="ova-solo"><${Face} p=${S} face=${x.solistCorrect === false ? "frust" : x.solistCorrect ? "jubel" : "denk"} anim="idle" size=${60} />
      <div><small>Solist</small><b>${S && S.name}</b>${x.solistCorrect != null && html`<span class=${cx("chip", x.solistCorrect ? "green" : "red")}>${x.solistCorrect ? "✔️ richtig" : "✗ falsch"}</span>`}</div></div>
    <div class="duel-vs">VS</div>
    <div class="ova-crowd"><b>${x.crowdCorrect}</b><div><span>aus dem Publikum richtig</span><small class="muted">Frage ${x.frage}</small></div></div>
  </div>`;
}

function Song({ x }) {
  return html`<div class=${cx("x-song", x.revealed && "open")}>
    ${x.video && !x.revealed ? html`<video class="song-video" src=${`/media/audio/Songs/${x.songId}/video3s.mp4`} autoplay muted playsinline loop></video>`
      : html`<div class=${cx("vinyl", !x.revealed && "spin")}><i class="vinyl-shine"></i><div class="vinyl-label">${x.revealed ? "🎤" : "🎵"}</div></div>`}
    ${!x.revealed && !x.video && html`<div class="eq" aria-hidden="true">${[0, 1, 2, 3, 4, 5, 6].map(i => html`<i style=${`animation-delay:${-i * 0.17}s`}></i>`)}</div>`}
    ${x.revealed ? html`<div class="song-meta pop-in"><b>${x.titel}</b><span>${x.artist}</span></div>` : x.hint && html`<div class="song-hint">${x.hint.join(" ")}</div>`}
  </div>`;
}

function Steal({ x, pm }) {
  if (!x.thief && !x.victim) return null;
  return html`<div class="x-steal">
    <div class="steal-p thief"><${Face} p=${pm[x.thief]} face="jubel" anim="idle" size=${88} /><b>${(pm[x.thief] || {}).name || "?"}</b><small>Taschendieb</small></div>
    <div class="steal-arrow"><i></i>${x.betrag ? html`<span>🤑 ${fmtMM(x.betrag)}</span>` : html`<span>klaut bei …</span>`}</div>
    <div class="steal-p victim"><${Face} p=${pm[x.victim]} face=${x.victim ? "frust" : "neutral"} anim="idle" size=${88} /><b>${(pm[x.victim] || {}).name || "?"}</b><small>Opfer</small></div>
    ${!x.victim && x.candidates.length > 0 && html`<div class="chip-row center steal-cands">${x.candidates.map(id => html`<span class="chip">${(pm[id] || {}).name}</span>`)}</div>`}
  </div>`;
}

/** Free stats card (Kokosnuss-Shake countdown, tallies …): the title is the headline. */
function InfoCard({ x, full }) {
  const big = full && (x.title || "").length <= 22;
  return html`<div class=${cx("x-card", big && "big")}>
    <h3 key=${x.title} class="pop-in">${x.title}</h3>
    ${x.lines.length > 0 && html`<div class=${cx("x-card-lines", x.lines.length > 4 && "cols")}>${x.lines.map(l => html`<p>${l}</p>`)}</div>`}
  </div>`;
}
