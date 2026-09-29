// Stage widgets of the next format batch.
// Contract (see stage/extras.js PLUG): export NEU2 = { kind: { placement(extra, wall) → "side"|"left"|"below"|null,
//   tiles(extra, scene, view) → { tags: { [playerId]: { text, cls, hot } }, locked: [playerId] },
//   Widget({ x, pm, scene, view, revealed, full }) } }. `pm` maps player id → PlayerRef (avatar wire, name, balance).
//
// Welle 2 (🪜 Tipp-Treppe, ✅ Faktencheck, 🪢 Tauziehen) ride on the existing `card` kind: the card's
// single line starts with "§W2§" and carries the widget's JSON payload (`f` = format id, see
// Core/Minigames/Formats/Welle2*.swift). Every other card (Kokosnuss-Shake …) renders exactly as before.
import { html } from "../vendor/preact-htm.js";
import { cx, fmtNum, serverNow } from "../lib/core.js";
import { Monkey } from "../lib/ui.js";
import { Burst } from "./fx.js";

// ---------- payload ----------
const MARK = "§W2§";
const cache = new Map();
/** Decoded Welle-2 payload of a card extra, or null for a plain card. */
function payload(x) {
  const l = x && Array.isArray(x.lines) ? x.lines[0] : null;
  if (typeof l !== "string" || !l.startsWith(MARK)) return null;
  if (!cache.has(l)) {
    let p = null;
    try { p = JSON.parse(l.slice(MARK.length)); } catch (_) { p = null; }
    cache.set(l, p);
    if (cache.size > 48) cache.delete(cache.keys().next().value);
  }
  return cache.get(l);
}

// ---------- shared bits ----------
const Av = ({ p, face = "neutral", anim = "none", size = 56, delay = 0 }) => (p ? html`<${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} delay=${delay} />` : null);
const nm = (pm, id) => (pm[id] ? pm[id].name : "?");
const plus = n => (n > 0 ? "+" + fmtNum(n) : n < 0 ? "−" + fmtNum(-n) : "±0");
const ids = pm => Object.keys(pm);

function Kopf({ emoji, title, right }) {
  return html`<div class="w2-kopf"><span class="w2-emo">${emoji}</span><b>${title}</b>${right && html`<span class="w2-n">${right}</span>`}</div>`;
}

/** Ranked round totals (the round summary). */
function Rang({ totals, pm, detail, max = 8 }) {
  const all = ids(pm);
  const rows = all.map(id => ({ id, v: totals[id] || 0 })).sort((a, b) => b.v - a.v || all.indexOf(a.id) - all.indexOf(b.id)).slice(0, max);
  const top = Math.max(1, ...rows.map(r => r.v));
  return html`<ol class="w2-rang">${rows.map((r, i) => html`<li class=${cx(i === 0 && r.v > 0 && "first")} key=${r.id} style=${`animation-delay:${0.15 + i * 0.08}s`}>
    <span class="w2-pl">${i + 1}.</span><${Av} p=${pm[r.id]} face=${r.v > 0 ? (i === 0 ? "jubel" : "neutral") : r.v < 0 ? "frust" : "neutral"} anim=${i === 0 && r.v > 0 ? "jubel" : "none"} size=${44} />
    <span class="w2-name">${nm(pm, r.id)}</span>
    <span class="w2-det">${detail ? detail(r.id) : ""}</span>
    <span class="w2-bar"><i style=${`transform:scaleX(${r.v > 0 ? Math.max(0.04, r.v / top) : 0})`}></i></span>
    <b class=${cx("w2-mm", r.v > 0 && "pos", r.v < 0 && "neg")}>${plus(r.v)} MM</b>
  </li>`)}</ol>`;
}

/** The pre-Welle-2 InfoCard (extras.js) for every plain card. */
function InfoCard({ x, full }) {
  const lines = x.lines || [];
  const big = full && (x.title || "").length <= 22;
  return html`<div class=${cx("x-card", big && "big")}>
    <h3 key=${x.title} class="pop-in">${x.title}</h3>
    ${lines.length > 0 && html`<div class=${cx("x-card-lines", lines.length > 4 && "cols")}>${lines.map(l => html`<p>${l}</p>`)}</div>`}
  </div>`;
}

// ---------- 🪜 Tipp-Treppe ----------
const STEP_LABEL = ["Ohne Tipp", "Nach Tipp 1", "Nach Tipp 2", "Nach Tipp 3"];

/** Countdown strip to the next hint (CSS-driven, no per-frame renders). */
function NextHint({ at, ms }) {
  if (!at) return null;
  const rem = Math.max(0, at - serverNow());
  const ago = Math.max(0, Math.min(ms, ms - rem));
  return html`<div class="w2-next"><span>⏳ Nächster Tipp</span><div class="w2-next-bar"><i key=${at} style=${`animation-duration:${ms}ms;animation-delay:-${ago}ms`}></i></div></div>`;
}

function TreppeAsk({ p, pm }) {
  const lockedAt = p.locked || {};
  return html`<div class="w2 w2-treppe col">
    <${Kopf} emoji="🪜" title="Tipp-Treppe" right=${`Frage ${p.nummer}/${p.gesamt}`} />
    <div class="w2-stairs">${p.werte.map((v, i) => {
      const who = ids(pm).filter(id => lockedAt[id] === i);
      const state = i < p.stufe ? "gone" : i === p.stufe ? "now" : "later";
      return html`<div class=${cx("w2-step", "s" + i, state)} key=${i} style=${`--i:${i}`}>
        <div class="w2-step-head">
          <span class="w2-step-label">${STEP_LABEL[i]}</span>
          ${state === "now" && html`<span class="w2-now">JETZT</span>`}
          <b class="w2-step-val">${fmtNum(v)}</b><small class="w2-step-k">${p.faktoren[i]}</small>
        </div>
        ${i >= 1 && i <= p.stufe && p.tipps[i - 1] && html`<p class="w2-step-tipp" key=${"t" + i}>💡 ${p.tipps[i - 1]}</p>`}
        ${who.length > 0 && html`<div class=${cx("w2-step-who", who.length > 2 && "many")}>${who.map(id => html`<span class="w2-lock" key=${id}><${Av} p=${pm[id]} size=${34} />${who.length <= 2 && html`<small>${nm(pm, id)}</small>`}</span>`)}</div>`}
      </div>`;
    })}</div>
    ${p.stufe < 3 ? html`<${NextHint} at=${p.naechsteAt} ms=${p.stufeMs} />` : html`<p class="w2-foot">Alle 3 Tipps sind raus — letzte Chance!</p>`}
    <p class="w2-foot"><b>${p.answered}</b> eingeloggt · früh = mehr Geld</p>
  </div>`;
}

function TreppeMini({ p, pm }) {
  const lines = p.ergebnis || [];
  const none = lines.filter(e => e.stufe == null);
  return html`<div class="w2 w2-treppe full mini">
    ${p.frage && html`<p class="w2-q">${p.frage}</p>`}
    ${p.richtig && html`<div class="w2-richtig pop-in" style="animation-delay:.3s"><span>✔ Richtig:</span> <b>${p.richtig}</b></div>`}
    <div class="w2-wide-stairs">${p.werte.map((v, i) => {
      const here = lines.filter(e => e.stufe === i);
      return html`<div class=${cx("w2-wstep", "s" + i)} key=${i} style=${`--i:${i}`}>
        <div class="w2-wstep-who">${here.map((e, k) => html`<span class=${cx("w2-wlock", e.correct ? "ok" : "bad")} key=${e.player} style=${`animation-delay:${0.45 + i * 0.12 + k * 0.05}s`}>
          <${Av} p=${pm[e.player]} face=${e.correct ? "jubel" : "frust"} anim=${e.correct && i === 0 ? "jubel" : "none"} size=${52} />
          <small>${nm(pm, e.player)}</small><em>${e.correct ? "+" + fmtNum(e.points) : "✗"}</em></span>`)}</div>
        <div class="w2-wstep-block"><b>${fmtNum(v)}</b><small>${p.faktoren[i]}</small>${i === 0 && here.some(e => e.correct) && html`<${Burst} />`}</div>
        <div class="w2-wstep-label"><span>${STEP_LABEL[i]}</span>${i >= 1 && p.tipps[i - 1] && html`<p>💡 ${p.tipps[i - 1]}</p>`}</div>
      </div>`;
    })}</div>
    ${none.length > 0 && html`<div class="w2-none">⏰ Nicht eingeloggt: ${none.map(e => html`<span class="w2-chip" key=${e.player}><${Av} p=${pm[e.player]} size=${26} />${nm(pm, e.player)}</span>`)}</div>`}
  </div>`;
}

function Treppe({ p, pm }) {
  if (p.phase === "frage") return html`<${TreppeAsk} p=${p} pm=${pm} />`;
  if (p.phase === "mini") return html`<${TreppeMini} p=${p} pm=${pm} />`;
  return html`<div class="w2 w2-treppe full done">
    <p class="w2-sub">🪜 Endstand der Tipp-Treppe · ${p.gespielt} ${p.gespielt === 1 ? "Frage" : "Fragen"}</p>
    <${Rang} totals=${p.totals || {}} pm=${pm} detail=${id => html`<span class="w2-chip-s">✔ ${(p.richtige || {})[id] || 0}/${p.gespielt}</span>${(p.ohneTipp || {})[id] ? html`<span class="w2-chip-s gold">🏔️ ${p.ohneTipp[id]}× ohne Tipp</span>` : ""}`} />
  </div>`;
}

const treppeTiles = p => {
  const tags = {};
  if (p.phase === "frage") for (const [id, st] of Object.entries(p.locked || {})) tags[id] = { text: `🪜 ${p.faktoren[st] || ""}`, cls: st === 0 ? "gold" : "bank" };
  if (p.phase === "mini") for (const e of p.ergebnis || []) if (e.stufe != null) tags[e.player] = e.correct ? { text: "+" + fmtNum(e.points), cls: e.stufe === 0 ? "gold" : "bank", hot: e.stufe === 0 } : { text: "✗", cls: "out" };
  if (p.phase === "fertig") for (const [id, n] of Object.entries(p.ohneTipp || {})) if (n > 0) tags[id] = { text: `🏔️ ${n}×`, cls: "gold" };
  return { tags, locked: [] };
};

// ---------- ✅ Faktencheck ----------
const flames = n => (n > 0 ? "🔥".repeat(Math.min(n, 4)) : "");

/** Under the two answer buttons: the rule in one line + everybody's streak (flames, next multiplier). */
function FaktAsk({ p, pm }) {
  const all = ids(pm);
  const k = s => p.stufen[Math.min(s, p.stufen.length - 1)];
  return html`<div class="w2 w2-fakt below">
    <div class="w2-fakt-head">
      <span class="w2-fakt-q">✅ Fakt ${p.nummer}/${p.gesamt} · <b class="t">WAHR</b> oder <b class="f">FALSCH</b>?</span>
      <span class="w2-fakt-pay">Richtig <b>+${fmtNum(p.wert)}</b> × Serie <b>${p.stufen.join(" → ")}</b>${p.strafe ? html` · falsch <b class="f">−${fmtNum(p.strafe)}</b>` : ""}</span>
    </div>
    <div class=${cx("w2-streaks", all.length > 6 && "dense")}>${all.map(id => {
      const s = (p.serien || {})[id] || 0;
      return html`<span class=${cx("w2-streak", s >= 1 && "on", s >= 3 && "hot")} key=${id}>
        <${Av} p=${pm[id]} size=${34} face=${s >= 3 ? "jubel" : "neutral"} /><b>${nm(pm, id)}</b>
        ${s > 0 && html`<i class="w2-fl" key=${"f" + s}>${flames(s)}</i>`}<em>${k(s)}</em></span>`;
    })}</div>
  </div>`;
}

function FaktMini({ p, pm }) {
  const lines = p.ergebnis || [];
  const wahr = p.wahr === true;
  return html`<div class="w2 w2-fakt full mini">
    <div class=${cx("w2-factcard", wahr ? "is-true" : "is-false")}>
      <span class="w2-fc-n">Fakt ${p.nummer}/${p.gesamt}</span>
      <p class="w2-fc-text">${p.fakt}</p>
      <div class=${cx("w2-stamp", wahr ? "true" : "false")}><span>${wahr ? "WAHR" : "FALSCH"}</span></div>
    </div>
    ${p.erkl && html`<p class="w2-erkl">📖 ${p.erkl}</p>`}
    <div class=${cx("w2-fakt-row", lines.length > 6 && "dense")}>${lines.map((e, i) => html`<span class=${cx("w2-fres", e.correct === true ? "ok" : e.correct === false ? "bad" : "none")} key=${e.player} style=${`animation-delay:${0.55 + i * 0.04}s`}>
      <${Av} p=${pm[e.player]} face=${e.correct ? "jubel" : e.correct === false ? "frust" : "neutral"} size=${46} />
      <b>${nm(pm, e.player)}</b>
      <em>${e.correct === true ? "+" + fmtNum(e.points) : e.correct === false ? (e.points < 0 ? "−" + fmtNum(-e.points) : "✗") : "—"}</em>
      ${e.serie >= 2 && html`<i class="w2-fl">${flames(e.serie)}</i>`}
    </span>`)}</div>
  </div>`;
}

function Fakt({ p, pm }) {
  if (p.phase === "frage") return html`<${FaktAsk} p=${p} pm=${pm} />`;
  if (p.phase === "mini") return html`<${FaktMini} p=${p} pm=${pm} />`;
  return html`<div class="w2 w2-fakt full done">
    <p class="w2-sub">✅ Endstand Faktencheck · ${p.gespielt} Fakten</p>
    <${Rang} totals=${p.totals || {}} pm=${pm} detail=${id => ((p.besteSerie || {})[id] >= 2 ? html`<span class="w2-chip-s gold">🔥 ${p.besteSerie[id]}er-Serie</span>` : "")} />
  </div>`;
}

const faktTiles = p => {
  const tags = {};
  if (p.phase === "frage") for (const [id, s] of Object.entries(p.serien || {})) if (s >= 2) tags[id] = { text: "🔥" + s, cls: "gold", hot: s >= 4 };
  if (p.phase === "mini") for (const e of p.ergebnis || []) {
    if (e.correct === true) tags[e.player] = { text: "+" + fmtNum(e.points), cls: e.serie >= 3 ? "gold" : "bank", hot: e.serie >= 4 };
    else if (e.correct === false) tags[e.player] = { text: e.points < 0 ? "−" + fmtNum(-e.points) : "✗", cls: "out" };
  }
  if (p.phase === "fertig") for (const [id, s] of Object.entries(p.besteSerie || {})) if (s >= 3) tags[id] = { text: "🔥" + s, cls: "gold" };
  return { tags, locked: [] };
};

// ---------- 🪢 Tauziehen ----------
const TEAM_COLOR = { gelb: "#FFD34E", lila: "#9B6BFF" };

function Seil({ p, animate, big }) {
  const k = Number(p.knoten) || 0, k0 = animate ? Number(p.knotenVorher) || 0 : k;
  return html`<div class=${cx("w2-rope", big && "big", animate && "anim")} style=${`--k:${k};--k0:${k0}`}>
    <i class="w2-zone a"></i><i class="w2-zone b"></i>
    <i class="w2-rope-line"></i>
    <i class="w2-mid"></i>
    <div class="w2-knot-track"><span class="w2-knot"><i></i></span></div>
  </div>`;
}

function TeamSide({ t, pm, p, side, face, size = 44, pulls = [], payout = null }) {
  const pulled = Object.fromEntries(pulls.map(z => [z.player, z]));
  const win = p.sieger && p.sieger === t.id;
  return html`<div class=${cx("w2-team", side, win && "win", p.sieger && p.sieger !== "remis" && !win && "lose")} style=${`--tc:${TEAM_COLOR[t.farbe] || "#fff"}`}>
    <div class="w2-team-name"><span>${t.emoji}</span><b>${t.name}</b></div>
    <div class="w2-team-monkeys">${t.mitglieder.map((id, i) => {
      const z = pulled[id];
      return html`<span class=${cx("w2-puller", z && "pulled", z && z.zug > 1 && "double", p.mvp === id && "mvp")} key=${id} style=${`animation-delay:${0.1 + i * 0.05}s`}>
        ${p.mvp === id && html`<i class="w2-crown">🏅</i>`}
        <${Av} p=${pm[id]} face=${face(id, z)} anim=${z || win ? "jubel" : "none"} size=${size} />
        <small>${nm(pm, id)}</small>
        ${z && html`<em>${z.zug > 1 ? "⚡ +2" : "+1"}</em>`}
        ${payout && payout[id] != null && html`<em class="pay">+${fmtNum(payout[id])}</em>`}
      </span>`;
    })}</div>
  </div>`;
}

function Zug({ p, pm }) {
  const [A, B] = p.teams || [];
  if (!A || !B) return null;
  if (p.phase === "frage") {
    return html`<div class="w2 w2-zug below">
      <div class="w2-zug-row">
        <${TeamSide} t=${A} pm=${pm} p=${p} side="a" face=${() => "denk"} size=${34} />
        <div class="w2-zug-mid"><${Seil} p=${p} />
          <div class="w2-zug-score"><b class="a">${p.zugA}</b><span>Züge · ⚡ Schnellster ×2 · Sieg <b>+${fmtNum(p.siegWert)}</b> p. P. · MVP <b>+${fmtNum(p.mvpWert)}</b></span><b class="b">${p.zugB}</b></div></div>
        <${TeamSide} t=${B} pm=${pm} p=${p} side="b" face=${() => "denk"} size=${34} />
      </div>
    </div>`;
  }
  const mini = p.phase === "mini";
  const pulls = p.letzte || [];
  const face = (id, z) => (mini ? (z ? "jubel" : "frust") : p.sieger === "remis" ? "neutral" : (A.mitglieder.includes(id) ? "a" : "b") === p.sieger ? "jubel" : "frust");
  const winner = p.sieger === "a" ? A : p.sieger === "b" ? B : null;
  const n = Math.max(A.mitglieder.length, B.mitglieder.length);
  const big = () => (n > 4 ? 46 : n > 3 ? 54 : 64);
  return html`<div class=${cx("w2 w2-zug full", mini ? "mini" : "done")}>
    ${mini && p.frage && html`<p class="w2-q">${p.frage}</p>`}
    ${mini && p.richtig && html`<div class="w2-richtig pop-in"><span>✔ Richtig:</span> <b>${p.richtig}</b></div>`}
    ${!mini && html`<div class=${cx("w2-banner pop-in", winner ? "gold" : "draw")}>${winner ? html`🏆 ${winner.emoji} ${winner.name} gewinnt!` : "🤝 Unentschieden — der Knoten hängt in der Mitte"}</div>`}
    <div class="w2-zug-row big">
      <${TeamSide} t=${A} pm=${pm} p=${p} side="a" face=${face} size=${big(A)} pulls=${mini ? pulls : []} payout=${mini ? null : p.auszahlung} />
      <div class="w2-zug-mid"><${Seil} p=${p} animate=${mini} big=${true} /><div class="w2-zug-score"><b class="a">${p.zugA}</b><span>Züge</span><b class="b">${p.zugB}</b></div></div>
      <${TeamSide} t=${B} pm=${pm} p=${p} side="b" face=${face} size=${big(B)} pulls=${mini ? pulls : []} payout=${mini ? null : p.auszahlung} />
    </div>
    ${mini && pulls.length === 0 && html`<p class="w2-sub">😬 Keiner lag richtig — das Seil bewegt sich nicht!</p>`}
    ${!mini && p.mvp && html`<p class="w2-sub w2-mvp">🏅 MVP: <b>${nm(pm, p.mvp)}</b> · ${(p.zuege || {})[p.mvp] || 0} Züge · +${fmtNum(p.mvpWert)} Bonus</p>`}
  </div>`;
}

const zugTiles = p => {
  const tags = {};
  const [A, B] = p.teams || [];
  if (!A || !B) return { tags, locked: [] };
  for (const t of [A, B]) for (const id of t.mitglieder) tags[id] = { text: t.emoji, cls: "bank" };
  if (p.phase === "mini") for (const z of p.letzte || []) tags[z.player] = { text: z.zug > 1 ? "⚡ +2" : "💪 +1", cls: z.zug > 1 ? "gold" : "bank", hot: z.zug > 1 };
  if (p.phase === "fertig") {
    for (const t of [A, B]) if (p.sieger && p.sieger !== "remis" && p.sieger !== t.id) for (const id of t.mitglieder) tags[id] = { text: t.emoji, cls: "out" };
    for (const [id, v] of Object.entries(p.auszahlung || {})) tags[id] = { text: (p.sieger === "remis" ? "🤝 +" : "🏆 +") + fmtNum(v), cls: "gold" };
    if (p.mvp) tags[p.mvp] = { text: "🏅 MVP", cls: "gold", hot: true };
  }
  return { tags, locked: [] };
};

// ---------- the card plugin ----------
const FORMATS = {
  "tipp-treppe": { placement: (p, wall) => (p.phase === "frage" && wall ? "left" : null), tiles: treppeTiles, Widget: Treppe },
  faktencheck: { placement: (p, wall) => (p.phase === "frage" && wall ? "below" : null), tiles: faktTiles, Widget: Fakt },
  tauziehen: { placement: (p, wall) => (p.phase === "frage" && wall ? "below" : null), tiles: zugTiles, Widget: Zug },
};
const fmtOf = x => { const p = payload(x); return p && FORMATS[p.f] ? [p, FORMATS[p.f]] : [null, null]; };

function CardWidget({ x, pm, full }) {
  const [p, F] = fmtOf(x);
  if (!F) return html`<${InfoCard} x=${x} full=${full} />`;
  return html`<${F.Widget} p=${p} pm=${pm} />`;
}

export const NEU2 = {
  card: {
    placement: (x, wall) => { const [p, F] = fmtOf(x); return F ? F.placement(p, wall) : "below"; },
    tiles: x => { const [p, F] = fmtOf(x); return F ? F.tiles(p) : { tags: {}, locked: [] }; },
    Widget: CardWidget,
  },
};

