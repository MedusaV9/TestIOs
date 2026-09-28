// Stage widgets of the new formats: speed (Affenzahn), survival (Der letzte Affe),
// schaukel (Affenschaukel), herde (Herdentrieb), memory (Kokos-Kopf).
// Contract (see stage/extras.js PLUG): export NEU = { kind: { placement(extra, wall) → "side"|"left"|"below"|null,
//   tiles(extra, scene, view) → { tags: { [playerId]: { text, cls, hot } }, locked: [playerId] },
//   Widget({ x, pm, scene, view, revealed, full }) } }. `pm` maps player id → PlayerRef (avatar wire, name, balance).
// While a question is open the widget sits next to / below the question card; the mini-reveals
// and the round summary have no question wall and get the whole scene (FitBox scales them).
import { html } from "../vendor/preact-htm.js";
import { cx, fmtMM, fmtNum } from "../lib/core.js";
import { Monkey } from "../lib/ui.js";
import { useBeats, Burst, Secs } from "./fx.js";

// ---------- shared bits ----------
const Av = ({ p, face = "neutral", anim = "none", size = 64 }) => (p ? html`<${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} />` : null);
const nm = (pm, id) => (pm[id] ? pm[id].name : "?");
const secs = ms => (ms == null ? "—" : (Math.round(ms / 100) / 10).toLocaleString("de-DE", { minimumFractionDigits: 1 }) + " s");
const plus = n => (n > 0 ? "+" + fmtNum(n) : n < 0 ? "−" + fmtNum(-n) : "±0");
const sideWhileAsking = (x, wall) => (x.phase === "frage" && wall ? "side" : null);

/** Small header line of a widget: "⚡ Blitz · Frage 2/6". */
function Kopf({ emoji, title, n, of, right }) {
  return html`<div class="xn-kopf"><span class="xn-emo">${emoji}</span><b>${title}</b>${n != null && html`<span class="xn-n">Frage ${n}/${of}</span>`}${right}</div>`;
}

/** Ranked round totals (the round summary of every new format). */
function Rangliste({ totals, pm, detail, max = 8, highlight = [] }) {
  const ids = Object.keys(pm);
  const rows = ids.map(id => ({ id, v: totals[id] || 0 })).sort((a, b) => b.v - a.v || ids.indexOf(a.id) - ids.indexOf(b.id)).slice(0, max);
  const top = rows.length ? rows[0].v : 0;
  return html`<ol class="xn-rang">${rows.map((r, i) => html`<li class=${cx(i === 0 && r.v > 0 && "first", highlight.includes(r.id) && "hl")} style=${`animation-delay:${0.15 + i * 0.09}s`} key=${r.id}>
    <span class="xn-pl">${i + 1}.</span><${Av} p=${pm[r.id]} face=${i === 0 && r.v > 0 ? "jubel" : "neutral"} anim=${i === 0 && r.v > 0 ? "jubel" : "none"} size=${46} />
    <span class="xn-name">${nm(pm, r.id)}</span>
    ${detail && html`<span class="xn-det">${detail(r.id)}</span>`}
    <span class="xn-bar"><i style=${`transform:scaleX(${top > 0 ? Math.max(0.04, r.v / top) : 0})`}></i></span>
    <b class=${cx("xn-mm", r.v > 0 && "pos")}>${plus(r.v)} MM</b>
  </li>`)}</ol>`;
}

/** Everyone who locked in, as a row of small monkeys (answered = count or id list). */
function Eingeloggt({ answered, pm, label = "eingeloggt" }) {
  const n = Array.isArray(answered) ? answered.length : answered || 0;
  const of = Object.keys(pm).length;
  return html`<div class=${cx("xn-meter", n >= of && of > 0 && "full")}>
    <div class="xn-meter-n"><b key=${n}>${n}</b><span>/ ${of} ${label}</span></div>
    <div class="xn-pips">${Array.from({ length: of }, (_, i) => html`<i class=${cx(i < n && "on")}></i>`)}</div>
  </div>`;
}

// ---------- ⚡ Affenzahn ----------
function Speed({ x, pm }) {
  if (x.phase === "frage") {
    const best = Object.entries(x.totals || {}).sort((a, b) => b[1] - a[1]).slice(0, 3);
    return html`<div class="xn xn-speed side">
      <${Kopf} emoji="⚡" title="Blitzrunde" n=${x.nummer} of=${x.gesamt} />
      <div class="xn-speed-hint">Nur Tempo zählt!<small>Schnellster Richtiger: <b>${fmtMM(x.wert * 2)}</b></small></div>
      ${best.length > 0 && html`<ol class="xn-mini-rang">${best.map(([id, v], i) => html`<li key=${id}><span>${["🥇", "🥈", "🥉"][i]}</span><${Av} p=${pm[id]} size=${34} /><b>${nm(pm, id)}</b><em>${plus(v)}</em></li>`)}</ol>`}
    </div>`;
  }
  if (x.phase === "fertig") {
    return html`<div class="xn xn-speed full">
      <p class="xn-sub">⚡ Endstand der Blitzrunde</p>
      <${Rangliste} totals=${x.totals || {}} pm=${pm} detail=${id => html`${(x.siege || {})[id] ? html`<span class="chip gold">🏆 ${x.siege[id]}×</span>` : ""}${(x.bestMs || {})[id] ? html`<span class="chip">⏱ ${secs(x.bestMs[id])}</span>` : ""}`} />
    </div>`;
  }
  // Mini-reveal: speed podium of this question.
  const right = (x.ranking || []).filter(e => e.correct);
  const podium = [right[1], right[0], right[2]];
  const rest = (x.ranking || []).filter(e => !podium.includes(e));
  return html`<div class="xn xn-speed full mini">
    ${x.frage && html`<p class="xn-q">${x.frage}</p>`}
    ${x.richtig && html`<div class="xn-richtig pop-in"><span>✔ Richtig:</span> <b>${x.richtig}</b></div>`}
    <div class="xn-podest">${podium.map((e, i) => {
      if (!e) return html`<div class="xn-step empty s${[2, 1, 3][i]}"></div>`;
      const place = [2, 1, 3][i];
      return html`<div class=${cx("xn-step", "s" + place)} key=${e.player} style=${`animation-delay:${[0.35, 0.7, 0.1][i]}s`}>
        ${place === 1 && html`<${Burst} />`}
        <${Av} p=${pm[e.player]} face="jubel" anim=${place === 1 ? "jubel" : "none"} size=${place === 1 ? 104 : 84} />
        <b class="xn-step-name">${nm(pm, e.player)}</b>
        <span class="xn-time">⏱ ${secs(e.ms)}</span>
        <div class="xn-block"><span class="xn-place">${e.platz}.</span><em>+${fmtNum(e.points)}</em></div>
      </div>`;
    })}</div>
    ${rest.length > 0 && html`<div class="xn-rest">${rest.map(e => html`<span class=${cx("xn-chip", e.correct ? "ok" : e.correct === false ? "bad" : "none")} key=${e.player}>
      <${Av} p=${pm[e.player]} size=${30} />${nm(pm, e.player)} ${e.correct ? html`<em>${secs(e.ms)} · +${fmtNum(e.points)}</em>` : e.correct === false ? html`<em>✗ falsch</em>` : html`<em>— keine Antwort</em>`}</span>`)}</div>`}
    ${right.length === 0 && html`<p class="xn-sub">😬 Keiner lag richtig — nächste Frage!</p>`}
  </div>`;
}

const speedTiles = x => {
  const tags = {};
  if (x.phase === "mini") for (const e of x.ranking || []) if (e.correct && e.platz <= 3) tags[e.player] = { text: `⚡ ${e.platz}.`, cls: e.platz === 1 ? "gold" : "", hot: e.platz === 1 };
  if (x.phase === "fertig") for (const [id, n] of Object.entries(x.siege || {})) if (n > 0) tags[id] = { text: `🏆 ${n}×`, cls: "gold" };
  return { tags, locked: [] };
};

// ---------- 🪂 Der letzte Affe ----------
const pips = n => html`<span class="xn-lives">${[0, 1].map(i => html`<i class=${cx(i < n && "on")}>🍌</i>`)}</span>`;

function Survival({ x, pm }) {
  const ids = Object.keys(pm);
  const outAt = Object.fromEntries((x.out || []).map(o => [o.player, o.atQuestion]));
  const leben = x.leben || {};
  const alive = new Set(x.alive || []);
  if (x.phase === "frage") {
    return html`<div class="xn xn-surv side">
      <${Kopf} emoji="🪂" title="Survival" n=${x.nummer} of=${x.gesamt} />
      <div class="xn-surv-count"><b>${alive.size}</b><span>noch im Spiel</span></div>
      <div class="xn-surv-mini">${ids.filter(id => alive.has(id)).map(id => html`<span class=${cx("xn-surv-m", (leben[id] || 0) <= 1 && "last")} key=${id}><${Av} p=${pm[id]} face="denk" size=${36} />${pips(leben[id] || 0)}</span>`)}</div>
      <small class="xn-foot">Falsch = ein Leben weg · Bonus für den Letzten: <b>${fmtMM(x.bonus)}</b></small>
    </div>`;
  }
  const hit = new Set(x.getroffen || []);
  const knocked = new Set(x.lastOut || []);
  const fertig = x.phase === "fertig";
  const sieger = new Set(x.sieger || []);
  const share = sieger.size ? Math.round(x.bonus / sieger.size / 10) * 10 : 0;
  const tipps = Object.entries(x.tipps || {});
  return html`<div class=${cx("xn xn-surv full", fertig && "done")}>
    ${!fertig && x.frage && html`<p class="xn-q">${x.frage}</p>`}
    ${!fertig && (x.gnade ? html`<div class="xn-banner gnade pop-in">😅 Gnade! Alle lagen falsch — keiner verliert ein Leben</div>`
      : x.richtig && html`<div class="xn-richtig pop-in"><span>✔ Richtig:</span> <b>${x.richtig}</b></div>`)}
    ${fertig && html`<div class="xn-banner gold pop-in">${sieger.size === 1 ? `🏆 ${nm(pm, [...sieger][0])} ist der letzte Affe! +${fmtNum(share)} Bonus` : sieger.size > 1 ? `🪂 ${sieger.size} Überlebende teilen den Bonus: je +${fmtNum(share)}` : "💀 Keiner hat überlebt"}</div>`}
    <div class="xn-surv-grid">${ids.map((id, i) => {
      const out = outAt[id] != null && !alive.has(id);
      const cls = cx("xn-surv-card", out && "out", knocked.has(id) && "knocked", hit.has(id) && "hit", fertig && sieger.has(id) && "winner");
      return html`<div class=${cls} key=${id} style=${`animation-delay:${0.1 + i * 0.06}s`}>
        ${fertig && sieger.has(id) && html`<span class="xn-crown">👑</span>`}
        <${Av} p=${pm[id]} face=${out ? "frust" : fertig && sieger.has(id) ? "jubel" : hit.has(id) ? "frust" : "neutral"} anim=${fertig && sieger.has(id) ? "jubel" : "none"} size=${78} />
        <b>${nm(pm, id)}</b>
        ${out ? html`<span class="xn-raus">💀 raus · Frage ${outAt[id]}</span>` : pips(leben[id] || 0)}
        <small>${fmtMM((x.banked || {})[id] || 0)}</small>
      </div>`;
    })}</div>
    ${fertig && tipps.length > 0 && html`<div class="xn-tipps">🎯 Tipps: ${tipps.map(([from, to]) => html`<span class=${cx("xn-chip", sieger.has(to) ? "ok" : "bad")}>${nm(pm, from)} → ${nm(pm, to)} ${sieger.has(to) ? "✅" : "❌"}</span>`)}</div>`}
    ${!fertig && x.cheers > 0 && html`<small class="xn-foot">🥁 ${x.cheers}× angefeuert</small>`}
  </div>`;
}

const survivalTiles = x => {
  const tags = {};
  const alive = new Set(x.alive || []);
  for (const o of x.out || []) if (!alive.has(o.player)) tags[o.player] = { text: "💀 raus", cls: "out" };
  for (const [id, n] of Object.entries(x.leben || {})) if (alive.has(id)) tags[id] = { text: "🍌".repeat(Math.max(0, n)), cls: n <= 1 ? "out" : "bank", hot: (x.getroffen || []).includes(id) };
  for (const id of x.phase === "fertig" ? x.sieger || [] : []) tags[id] = { text: "👑 überlebt", cls: "gold", hot: true };
  return { tags, locked: [] };
};

// ---------- ↕️ Affenschaukel ----------
function pos(v, x) {
  const lo = x.lo, hi = x.hi;
  if (v == null || !(hi > lo)) return 0.5;
  const p = x.log && lo > 0 && v > 0 ? (Math.log(v) - Math.log(lo)) / (Math.log(hi) - Math.log(lo)) : (v - lo) / (hi - lo);
  return Math.max(0.02, Math.min(0.98, p));
}

function Skala({ x, reveal }) {
  const pa = pos(x.anchor, x), pt = reveal && x.truth != null ? pos(x.truth, x) : pa;
  const up = x.richtung === "hoeher";
  return html`<div class=${cx("xn-skala", reveal && "reveal")} style=${`--pa:${pa};--pt:${pt}`}>
    <div class="xn-track"><i class="lo"></i><i class="hi"></i>${reveal && html`<span class=${cx("xn-span", up ? "up" : "down")} style=${`left:${Math.min(pa, pt) * 100}%;width:${Math.abs(pt - pa) * 100}%`}></span>`}</div>
    <div class="xn-slide anchor"><div class="xn-pin anchor"><b>${x.anchorText}</b><small>${x.unit || "Anker"}</small></div></div>
    ${reveal && x.truth != null && html`<div class="xn-slide truth swing"><div class="xn-pin truth"><b>${x.truthText}</b><small>✔ Wahrheit</small></div></div>`}
    <div class="xn-ends"><span>⬇️ tiefer</span><span>höher ⬆️</span></div>
  </div>`;
}

function Schaukel({ x, pm }) {
  if (x.phase === "frage") {
    return html`<div class="xn xn-schaukel below">
      <div class="xn-sk-ask">Liegt die Antwort <b class="up">HÖHER ⬆️</b> oder <b class="down">TIEFER ⬇️</b> als <b class="anchor">${x.anchorText}${x.unit ? " " + x.unit : ""}</b>?</div>
      <${Skala} x=${x} reveal=${false} />
      <div class="xn-sk-foot"><span>↕️ Frage ${x.nummer}/${x.gesamt}</span><span><b>${x.answered}</b> geschaukelt</span></div>
    </div>`;
  }
  const up = x.richtung === "hoeher";
  const votes = x.votes || { up: [], down: [] };
  const col = (dir, list) => {
    const win = (dir === "up") === up;
    return html`<div class=${cx("xn-sk-col", dir, win ? "win" : "lose")}>
      <h4>${dir === "up" ? "⬆️ Höher" : "⬇️ Tiefer"} ${win && html`<span class="chip green">richtig</span>`}</h4>
      <div class="xn-sk-voters">${list.length ? list.map((id, i) => html`<span class="xn-voter" key=${id} style=${`animation-delay:${1.1 + i * 0.08}s`}>
        <${Av} p=${pm[id]} face=${win ? "jubel" : "frust"} size=${52} /><b>${nm(pm, id)}</b>
        ${win && (x.points || {})[id] ? html`<em>+${fmtNum(x.points[id])}${(x.serien || {})[id] >= 2 ? ` · 🔥${x.serien[id]}` : ""}</em>` : ""}</span>`) : html`<small class="muted">niemand</small>`}</div>
    </div>`;
  };
  return html`<div class=${cx("xn xn-schaukel full", x.phase === "fertig" && "done")}>
    ${x.frage && html`<p class="xn-q">${x.frage}</p>`}
    <div class="xn-richtig pop-in" style="animation-delay:.9s"><span>✔ Richtig:</span> <b>${x.truthText}${x.unit ? " " + x.unit : ""}</b> <em class=${up ? "up" : "down"}>${up ? "HÖHER ⬆️" : "TIEFER ⬇️"} als ${x.anchorText}</em></div>
    <${Skala} x=${x} reveal=${true} />
    ${x.phase === "fertig" ? html`<${Rangliste} totals=${x.totals || {}} pm=${pm} max=${6} detail=${id => ((x.serien || {})[id] >= 2 ? html`<span class="chip gold">🔥 ${x.serien[id]}</span>` : "")} />`
      : html`<div class="xn-sk-cols">${col("down", votes.down || [])}${col("up", votes.up || [])}</div>`}
  </div>`;
}

const schaukelTiles = x => {
  const tags = {};
  if (x.phase !== "frage" && x.votes) {
    const up = x.richtung === "hoeher";
    for (const id of x.votes.up || []) tags[id] = { text: "⬆️", cls: up ? "bank" : "out", hot: up };
    for (const id of x.votes.down || []) tags[id] = { text: "⬇️", cls: up ? "out" : "bank", hot: !up };
  }
  return { tags, locked: [] };
};

// ---------- 🐑 Herdentrieb ----------
function Herde({ x, pm }) {
  if (x.phase === "frage") {
    return html`<div class="xn xn-herde side">
      <${Kopf} emoji="🐑" title="Herdentrieb" n=${x.nummer} of=${x.gesamt} />
      <div class="xn-herde-hint">Kein Richtig, kein Falsch:<b>Tippe, was die MEHRHEIT wählt!</b></div>
      <${Eingeloggt} answered=${x.answered} pm=${pm} label="getippt" />
      <small class="xn-foot">Größte Gruppe: <b>+${fmtNum(x.wert)}</b> pro Kopf · allein: 0</small>
    </div>`;
  }
  const opts = x.options || [];
  const max = Math.max(1, ...opts.map(o => o.count || 0));
  const maj = new Set(x.majority || []);
  const lone = new Set(x.einzelgaenger || []);
  const tie = maj.size > 1;
  return html`<div class=${cx("xn xn-herde full", x.phase === "fertig" && "done")}>
    <p class="xn-prompt">${x.prompt}</p>
    <div class=${cx("xn-herde-opts", opts.length > 3 && "many")}>${opts.map((o, i) => {
      const win = maj.has(o.id);
      return html`<div class=${cx("xn-herde-opt", win && "win", !win && (o.count || 0) > 0 && "lose", (o.count || 0) === 0 && "empty")} key=${o.id} style=${`--h:${(o.count || 0) / max};animation-delay:${i * 0.1}s`}>
        ${win && html`<span class="xn-ribbon">${tie ? "Gleichstand" : "🐑 Die Herde!"}</span>`}
        <div class="xn-herde-bar"><i></i><b>${o.count || 0}</b></div>
        <span class="xn-herde-emo">${o.emoji}</span>
        <b class="xn-herde-text">${o.text}</b>
        <div class="xn-herde-voters">${(o.voters || []).map((id, k) => html`<span class=${cx("xn-voter", lone.has(id) && "lone")} key=${id} style=${`animation-delay:${0.9 + k * 0.08}s`}>
          <${Av} p=${pm[id]} face=${win ? "jubel" : lone.has(id) ? "frust" : "neutral"} size=${44} /><small>${nm(pm, id)}</small>${lone.has(id) && html`<em>Einzelgänger</em>`}</span>`)}</div>
      </div>`;
    })}</div>
    ${maj.size === 0 && html`<p class="xn-sub">🐺 Lauter Einzelgänger — diesmal keine Herde!</p>`}
    ${x.phase === "fertig" && html`<${Rangliste} totals=${x.totals || {}} pm=${pm} max=${6} />`}
  </div>`;
}

const herdeTiles = x => {
  const tags = {};
  if (x.phase !== "frage") {
    const maj = new Set(x.majority || []);
    for (const o of x.options || []) for (const id of o.voters || []) if (maj.has(o.id)) tags[id] = { text: "🐑 +" + fmtNum((x.points || {})[id] || 0), cls: "gold" };
    for (const id of x.einzelgaenger || []) tags[id] = { text: "🐺 allein", cls: "out" };
  }
  return { tags, locked: [] };
};

// ---------- 🧠 Kokos-Kopf ----------
function Memory({ x, pm, view }) {
  const n = x.laenge || 0;
  const beats = x.phase === "zeigen" && x.zeigenAb ? Array.from({ length: n + 2 }, (_, i) => i * x.symbolMs) : [];
  const t = useBeats(x.phase === "zeigen" ? x.zeigenAb : null, beats);
  const head = html`<div class="xn-kopf"><span class="xn-emo">🧠</span><b>Kokos-Kopf</b><span class="xn-n">Runde ${x.schritt}/${x.gesamt} · ${n} Symbole</span></div>`;
  if (x.phase === "zeigen") {
    const i = t < 0 ? -1 : Math.floor(t / Math.max(1, x.symbolMs));
    const seq = x.sequenz || x.gezeigt || [];
    const showing = i >= 0 && i < n ? seq[i] : null;
    return html`<div class="xn xn-memory full zeigen">
      ${head}
      <div class="xn-mem-stage">${showing ? html`<div class="xn-mem-big" key=${"s" + i}><span>${showing}</span>${x.namen && x.namen[i] ? html`<small>${x.namen[i]}</small>` : ""}</div>`
        : html`<div class="xn-mem-wait" key=${i < 0 ? "vor" : "nach"}>${i < 0 ? "👀 Gut aufpassen …" : "📱 Jetzt auf dem Handy sortieren!"}</div>`}</div>
      <div class="xn-mem-dots">${Array.from({ length: n }, (_, k) => html`<i class=${cx(k < i && "done", k === i && "now")}></i>`)}</div>
    </div>`;
  }
  if (x.phase === "eingeben") {
    const done = new Set(x.answered || []);
    return html`<div class="xn xn-memory full eingeben">
      ${head}
      <div class="xn-mem-cards">${Array.from({ length: n }, (_, k) => html`<div class="xn-mem-card back" style=${`animation-delay:${k * 0.07}s`}><span>?</span><small>${k + 1}</small></div>`)}</div>
      <p class="xn-sub">📱 Bringt die Symbole in die richtige Reihenfolge!</p>
      <div class="xn-mem-who">${Object.keys(pm).map(id => html`<span class=${cx("xn-mem-p", done.has(id) && "in")} key=${id}><${Av} p=${pm[id]} face=${done.has(id) ? "neutral" : "denk"} anim=${done.has(id) ? "none" : "denk"} size=${46} />${done.has(id) && html`<i>✔</i>`}</span>`)}
        ${x.deadline && html`<span class="xn-mem-clock">⏱ <${Secs} deadline=${x.deadline} paused=${view && view.paused} /></span>`}</div>
    </div>`;
  }
  const seq = x.sequenz || x.gezeigt || [];
  const perfekt = new Set(x.perfekt || []);
  const ids = Object.keys(pm).sort((a, b) => ((x.richtige || {})[b] || 0) - ((x.richtige || {})[a] || 0));
  return html`<div class=${cx("xn xn-memory full reveal", x.phase === "fertig" && "done")}>
    ${head}
    <div class="xn-mem-cards">${seq.map((s, k) => html`<div class="xn-mem-card flip" style=${`animation-delay:${0.15 + k * 0.28}s`} key=${k}><span>${s}</span><small>${k + 1}. ${(x.namen || [])[k] || ""}</small></div>`)}</div>
    ${x.phase === "fertig" ? html`<${Rangliste} totals=${x.totals || {}} pm=${pm} max=${6} />`
      : html`<div class="xn-mem-results">${ids.map((id, k) => {
        const r = (x.richtige || {})[id];
        return html`<span class=${cx("xn-mem-res", perfekt.has(id) && "perfect")} key=${id} style=${`animation-delay:${0.4 + n * 0.28 + k * 0.08}s`}>
          <${Av} p=${pm[id]} face=${perfekt.has(id) ? "jubel" : r ? "neutral" : "frust"} size=${46} />
          <b>${nm(pm, id)}</b><em>${r == null ? "—" : `${r}/${n}`}</em>
          ${perfekt.has(id) && html`<span class="chip gold">💯</span>`}${x.schnellster === id && html`<span class="chip">⚡ schnellster</span>`}
          ${(x.points || {})[id] ? html`<small>+${fmtNum(x.points[id])}</small>` : ""}</span>`;
      })}</div>`}
  </div>`;
}

const memoryTiles = x => {
  const tags = {};
  if (x.phase === "eingeben") return { tags, locked: x.answered || [] };
  if (x.phase === "aufloesung") for (const [id, r] of Object.entries(x.richtige || {})) tags[id] = { text: `🧠 ${r}/${x.laenge}`, cls: (x.perfekt || []).includes(id) ? "gold" : r ? "bank" : "out", hot: (x.perfekt || []).includes(id) };
  return { tags, locked: [] };
};

export const NEU = {
  speed: { placement: sideWhileAsking, tiles: speedTiles, Widget: Speed },
  survival: { placement: sideWhileAsking, tiles: survivalTiles, Widget: Survival },
  schaukel: { placement: (x, wall) => (x.phase === "frage" && wall ? "below" : null), tiles: schaukelTiles, Widget: Schaukel },
  herde: { placement: sideWhileAsking, tiles: herdeTiles, Widget: Herde },
  memory: { placement: () => null, tiles: memoryTiles, Widget: Memory },
};

