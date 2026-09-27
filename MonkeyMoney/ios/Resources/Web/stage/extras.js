// Minigame widgets around the question wall — one renderer per StageExtra kind.
import { html } from "../vendor/preact-htm.js";
import { cx, fmtMM, fmtNum, fmtDelta, serverNow, useNow, OPTION_STYLE } from "../lib/core.js";
import { Monkey, Money, PixelImage, Countdown } from "../lib/ui.js";

const pmap = view => Object.fromEntries(view.players.map(p => [p.id, p]));

/** Where a widget lives: left of the question, below it, in the side column, or none. */
export function extraPlacement(extra, wall) {
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
    case "duel": return html`<${Duel} x=${extra} pm=${pm} />`;
    case "steps": return html`<${Steps} x=${extra} pm=${pm} />`;
    case "pies": return html`<${Pies} x=${extra} pm=${pm} />`;
    case "telegram": return html`<${Telegram} x=${extra} pm=${pm} />`;
    case "oneVsAll": return html`<${OneVsAll} x=${extra} pm=${pm} />`;
    case "song": return html`<${Song} x=${extra} />`;
    case "steal": return html`<${Steal} x=${extra} pm=${pm} />`;
    case "card": return html`<div class="x-card card"><h3>${extra.title}</h3>${extra.lines.map(l => html`<p>${l}</p>`)}</div>`;
    default: return null;
  }
}

const Face = ({ p, face = "neutral", anim = "none", size = 44 }) => (p ? html`<${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} />` : null);

function PixelWidget({ x, pm, scene }) {
  return html`<div class="x-pixel">
    <div class="pixel-frame"><${PixelImage} src=${"/media/pixel/" + x.image} level=${x.level} maxLevel=${x.maxLevel} /></div>
    <div class="pixel-stair">${x.stufen.map((v, i) => html`<div class=${cx("stair", i === x.level && "on", i < x.level && "past")}><span>${i + 1}</span><b>${fmtNum(v)}</b></div>`)}</div>
    <div class="pixel-jack">🫙 ${fmtMM(x.jackpot)} <small>Jetzt raten!</small></div>
  </div>`;
}

function NumberLine({ x, pm, revealed }) {
  const pos = v => {
    if (x.log) { const lo = Math.log(Math.max(1e-9, x.min)), hi = Math.log(Math.max(1e-9, x.max)); return ((Math.log(Math.max(1e-9, v)) - lo) / (hi - lo)) * 100; }
    return ((v - x.min) / (x.max - x.min || 1)) * 100;
  };
  const clamp = v => Math.max(0, Math.min(100, v));
  const show = revealed && x.truth != null;
  return html`<div class=${cx("x-numline", show && "show")}>
    <div class="nl-track">
      <div class="nl-ends"><span>${fmtNum(x.min)}</span><span>${fmtNum(x.max)} ${x.unit}</span></div>
      <div class="nl-bar"></div>
      ${show && x.guesses.map((g, i) => html`<div class=${cx("nl-pin", g.platz === 1 && "best")} style=${`left:${clamp(pos(g.value))}%;animation-delay:${i * 0.2}s;--row:${i % 3}`}>
        <${Face} p=${pm[g.playerId]} face=${g.platz === 1 ? "jubel" : "neutral"} size=${58} />
        <small>${fmtNum(g.value)}</small></div>`)}
      ${show && html`<div class="nl-truth pop-in" style=${`left:${clamp(pos(x.truth))}%`}><span>🎯 ${fmtNum(x.truth)} ${x.unit}</span></div>`}
    </div>
    ${!show && html`<p class="muted center">🔢 Schätzt auf euren Handys — am nächsten dran gewinnt! (${x.guesses.length} Tipps)</p>`}
  </div>`;
}

function BankPot({ x, pm }) {
  const now = useNow(250);
  return html`<div class=${cx("x-bank", x.verdict && "v-" + x.verdict)}>
    <div class="bank-pot"><small>Im Pott</small><${Money} value=${x.pot} /></div>
    <div class="bank-chain">${[...x.chain].reverse().map((v, ri) => { const i = x.chain.length - 1 - ri; return html`<div class=${cx("chain-step", i === x.chainStep && "on", i < x.chainStep && "past")}>${fmtNum(v)}</div>`; })}</div>
    <div class="bank-meta"><span class="chip">Durchgang ${x.durchgang}/${x.durchgaenge}</span>${x.runEndsAt > now && html`<span class="chip">⏱ <${Countdown} deadline=${x.runEndsAt} /> s</span>`}</div>
    ${x.verdict && html`<div class="bank-verdict pop-in" key=${x.verdict + x.chainStep}>${{ waechst: "📈 Kette wächst!", haelt: "✋ Kette hält", verbrennt: "🔥 Verbrannt!" }[x.verdict] || x.verdict}</div>`}
    ${x.lastBanker && pm[x.lastBanker] && html`<div class="bank-last">🏦 ${pm[x.lastBanker].name} hat gebankt</div>`}
  </div>`;
}

function BankAuszug({ x, pm, deltas }) {
  const rows = Object.keys(pm).map(id => [id, deltas[id] || 0]).sort((a, b) => b[1] - a[1]);
  const max = Math.max(1, ...rows.map(r => r[1]));
  return html`<div class="bank-auszug">${rows.map(([id, v], i) => html`<div class="ba-row rise-in" style=${`animation-delay:${i * 0.15}s`}>
    <${Face} p=${pm[id]} face=${v > 0 ? "jubel" : "frust"} anim=${i === 0 ? "jubel" : "idle"} size=${50} /><b>${pm[id].name}</b>
    <div class="stand-bar"><i style=${`width:${(Math.max(0, v) / max) * 100}%`}></i></div><b class="gold-text">🏦 ${fmtMM(v)}</b></div>`)}</div>`;
}

function Bomb({ x, pm }) {
  const holder = pm[x.holder];
  const boom = !!x.exploded;
  return html`<div class=${cx("x-bomb", boom && "boom")} style=${`--t:${x.tension}`}>
    <div class="bomb-ico">${boom ? "💥" : "🍌"}</div>
    <div class="bomb-fuse"><i style=${`width:${(1 - x.tension) * 100}%`}></i></div>
    ${holder && html`<div class="bomb-holder"><${Face} p=${holder} face=${boom ? "frust" : "denk"} anim=${boom ? "frust" : "denk"} size=${110} /><b>${boom ? `${holder.name} ist matschig!` : `${holder.name} hält die Stinkbanane`}</b></div>`}
    <span class="chip">🔁 ${x.passes} Pässe · Durchgang ${x.durchgang}</span>
  </div>`;
}

function Bets({ x, pm, revealed, compact }) {
  return html`<div class="x-bets">
    ${x.teaser && !compact && html`<div class="bets-teaser">🎲 ${x.teaser}</div>`}
    <div class=${cx("bets-row", compact && "compact")}>${x.bets.map((b, i) => html`<div class=${cx("bet-card", b.revealed && "open")} style=${`animation-delay:${i * 0.15}s`}>
      <${Face} p=${pm[b.playerId]} face=${b.revealed ? "denk" : "neutral"} anim="idle" size=${compact ? 40 : 96} />
      ${!compact && html`<b>${(pm[b.playerId] || {}).name || ""}</b>`}
      <span class="bet-amt">${b.revealed ? fmtMM(b.betrag) : x.phase === "setzen" && b.betrag === 0 ? "…" : "🤫 ?"}</span>
    </div>`)}</div>
  </div>`;
}

function Ladder({ x, pm, revealed }) {
  return html`<div class="x-ladder">${x.correctOrder.map((idx, pos) => html`<div class=${cx("ladder-step", pos < x.revealedSteps && "open")} style=${`animation-delay:${pos * 0.2}s`}>
    <span class="ls-n">${pos + 1}</span><span class="ls-t">${pos < x.revealedSteps ? x.items[idx] : "???"}</span>${pos < x.revealedSteps && x.werte[idx] && html`<small>${x.werte[idx]}</small>`}
  </div>`)}</div>`;
}

function Lianen({ x, pm, revealed, view }) {
  return html`<div class="x-lianen-side"><div class="lianen-w">🐊 W = ${fmtMM(x.w)}</div><p class="muted">Richtig: +W · Falsch: −½ W<br />Die Liane zeigt, wie weit ihr vom Krokodil weg seid.</p><div class="croc">🐊🐊</div></div>`;
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
  return html`<div class="x-sack"><div class="sack" style=${`transform:scale(${0.55 + f * 0.45})`}>💰</div><${Money} value=${x.current} class="sack-amt" /><small class="muted">von ${fmtMM(x.start)} — schrumpft!</small></div>`;
}

function Buzzers({ x, pm }) {
  return html`<div class=${cx("x-buzz", x.armed && "armed")}>
    <div class="buzz-light">${x.armed ? "🔔 BUZZER FREI!" : "⏳ Gleich …"}</div>
    ${x.stufe && html`<span class="chip gold">${x.stufe}</span>`}
    <span class="chip">💰 ${fmtMM(x.wert)}</span>
    <ol class="buzz-order">${x.order.map((id, i) => html`<li class="pop-in"><b>${i + 1}.</b><${Face} p=${pm[id]} size=${40} /><span>${(pm[id] || {}).name}</span></li>`)}</ol>
  </div>`;
}

function Chips({ x, scene }) {
  const opts = (scene.wall && scene.wall.options) || [];
  const max = Math.max(1, ...x.perOption);
  return html`<div class="x-chips">${x.perOption.map((n, i) => html`<div class="chip-col">
    <div class="chip-stack" style=${`height:${(n / max) * 120}px;--c:${OPTION_STYLE[i % 8].c}`}></div>
    <b>${n} 🪙</b>${x.quotes && x.quotes[i] != null && html`<small>×${fmtNum(x.quotes[i])}</small>`}<span>${OPTION_STYLE[i % 8].l}${opts[i] ? "" : ""}</span>
  </div>`)}</div>`;
}

function Auction({ x, pm }) {
  const bids = Object.entries(x.bids || {}).sort((a, b) => b[1] - a[1]);
  return html`<div class="x-auction">
    <div class="auc-head">🔨 Auktion ${x.endsAt && html`<span class="chip">⏱ <${Countdown} deadline=${x.endsAt} /></span>`}</div>
    ${!bids.length && html`<p class="muted">🔨 Bietet auf euren Handys — wer am meisten bietet, darf antworten!</p>`}
    <div class="auc-bids">${bids.map(([id, v], i) => html`<div class=${cx("auc-bid", id === x.leader && "lead")}><${Face} p=${pm[id]} size=${46} /><b>${(pm[id] || {}).name}</b><span>${fmtMM(v)}</span></div>`)}</div>
  </div>`;
}

function Bluff({ x, pm }) {
  const votes = {};
  for (const v of Object.values(x.votes || {})) votes[v] = (votes[v] || 0) + 1;
  return html`<div class="x-bluff">${x.entries.map((e, i) => html`<div class=${cx("bluff-entry", x.truthIndex === e.id && "truth")}>
    <span class="be-l">${OPTION_STYLE[i % 8].l}</span><span class="be-t">${e.text}</span>
    ${votes[e.id] && html`<span class="chip">🗳 ${votes[e.id]}</span>`}
    ${x.authors && x.authors[e.id] && pm[x.authors[e.id]] && html`<span class="be-author">🤥 ${pm[x.authors[e.id]].name}</span>`}
    ${x.truthIndex === e.id && html`<span class="chip green">✔️ Wahrheit</span>`}
  </div>`)}${!x.entries.length && html`<p class="muted center">✍️ Alle schreiben eine glaubwürdige Lüge …</p>`}</div>`;
}

function Duel({ x, pm }) {
  const A = pm[x.a], B = pm[x.b];
  const bar = v => `${(v / Math.max(1, x.maxScore)) * 100}%`;
  return html`<div class="x-duel">
    <div class="duel-side a"><${Face} p=${A} face="denk" anim="idle" size=${86} /><b>${A && A.name}</b><div class="hp"><i style=${`width:${bar(x.scoreA)}`}></i></div><span>${x.scoreA}</span></div>
    <div class=${cx("duel-vs", (x.label || "").length > 6 && "long")}>${x.label || "VS"}</div>
    <div class="duel-side b"><${Face} p=${B} face="denk" anim="idle" size=${86} /><b>${B && B.name}</b><div class="hp"><i style=${`width:${bar(x.scoreB)}`}></i></div><span>${x.scoreB}</span></div>
  </div>`;
}

function Steps({ x, pm }) {
  return html`<div class="x-steps">${x.labels.map((l, i) => html`<div class=${cx("step", i === x.current && "on", i < x.current && "past")}>
    <span>${l}</span><div class="step-who">${Object.entries(x.positions || {}).filter(([, v]) => v === i).map(([id]) => html`<${Face} p=${pm[id]} size=${34} />`)}</div></div>`)}</div>`;
}

function Pies({ x, pm }) {
  return html`<div class="x-lianen-side"><div class="pie-big">🥧</div><p class="muted">Falsch = Torte ins Gesicht.<br />Bei ${x.maxDirt} Torten ist man raus.</p></div>`;
}
function PiesWide({ x, pm }) {
  return html`<div class="x-pies">${Object.entries(x.dirt || {}).map(([id, d]) => html`<div class=${cx("pie-p", (x.out || []).includes(id) && "out")}>
    <${Face} p=${pm[id]} face=${d > 0 ? "frust" : "neutral"} size=${56} /><div class="pie-bar">${Array.from({ length: x.maxDirt }, (_, i) => html`<i class=${i < d ? "on" : ""}>🥧</i>`)}</div></div>`)}</div>`;
}

function Telegram({ x, pm }) {
  return html`<div class="x-tele">
    <div class="tele-letters">${x.letters.map((l, i) => html`<span class=${cx("tl", x.solved.includes(i) && "ok")}>${l || "_"}</span>`)}</div>
    ${x.wort && html`<div class="tele-word pop-in">📨 ${x.wort}</div>`}
    <div class="tele-pairs">${x.pairs.map(p => html`<span class="chip">${p.map(id => (pm[id] || {}).name).join(" + ")}</span>`)}</div>
  </div>`;
}

function OneVsAll({ x, pm }) {
  const S = pm[x.solist];
  return html`<div class="x-ova">
    <div class="ova-solo"><${Face} p=${S} face=${x.solistCorrect === false ? "frust" : x.solistCorrect ? "jubel" : "denk"} anim="idle" size=${72} /><b>${S && S.name}</b>${x.solistCorrect != null && html`<span class=${cx("chip", x.solistCorrect ? "green" : "red")}>${x.solistCorrect ? "✔️ richtig" : "✗ falsch"}</span>`}</div>
    <div class="duel-vs">VS</div>
    <div class="ova-crowd"><b>${x.crowdCorrect}</b><span>aus dem Publikum richtig</span><small class="muted">Frage ${x.frage}</small></div>
  </div>`;
}

function Song({ x }) {
  return html`<div class=${cx("x-song", x.revealed && "open")}>
    ${x.video && !x.revealed ? html`<video class="song-video" src=${`/media/audio/Songs/${x.songId}/video3s.mp4`} autoplay muted playsinline loop></video>`
      : html`<div class=${cx("vinyl", !x.revealed && "spin")}><div class="vinyl-label">${x.revealed ? "🎤" : "🎵"}</div></div>`}
    ${x.revealed ? html`<div class="song-meta pop-in"><b>${x.titel}</b><span>${x.artist}</span></div>` : x.hint && html`<div class="song-hint">${x.hint.join(" ")}</div>`}
  </div>`;
}

function Steal({ x, pm }) {
  if (!x.thief && !x.victim) return null;
  return html`<div class="x-steal">
    <div class="steal-p"><${Face} p=${pm[x.thief]} face="jubel" anim="idle" size=${96} /><b>${(pm[x.thief] || {}).name || "?"}</b><small>Taschendieb</small></div>
    <div class="steal-arrow">${x.betrag ? html`<span>🤑 ${fmtMM(x.betrag)}</span>` : "🦹 ➡️"}</div>
    <div class="steal-p"><${Face} p=${pm[x.victim]} face=${x.victim ? "frust" : "neutral"} anim="idle" size=${96} /><b>${(pm[x.victim] || {}).name || "?"}</b><small>Opfer</small></div>
    ${!x.victim && x.candidates.length > 0 && html`<div class="chip-row center">${x.candidates.map(id => html`<span class="chip">${(pm[id] || {}).name}</span>`)}</div>`}
  </div>`;
}
