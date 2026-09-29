// Stage scenes: intro, category vote, explain card, question wall + reveal,
// standings, wheel, pause, highlights, ceremony, credits, board games.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { decode, cx, fmtMM, fmtDelta, fmtNum, serverNow, useFrame, useSince, OPTION_STYLE, DIFF, Wheel } from "../lib/core.js";
import { Monkey, Money, Confetti, Stars } from "../lib/ui.js";
import { Extra, extraPlacement, extraTileInfo } from "./extras.js";
import { BoardgameScene } from "./boards.js";
import { CEREMONY_ROLL_MS, CEREMONY_SILENCE_MS, REVEAL_BEAT, dimTimes, rouletteSteps, ROULETTE_MS, STANDINGS_FLIP_MS } from "./regie.js";
import { useBeats, Burst, CoinPop, useFlip, StageTimer, StageBar, Secs, FitBox, lastSwitch } from "./fx.js";
import { StageCtx } from "./ctx.js";

// Reveal choreography: the answer lights up with the fanfare, not before.
const revealSeen = new Map();
let firstView = true;
export function revealStart(scene) {
  const w = scene.wall;
  const key = `${scene.minigameId}|${w ? w.nummer + w.text.slice(0, 20) : ""}|${Object.keys(scene.deltas || {}).length}`;
  if (!revealSeen.has(key)) {
    revealSeen.set(key, firstView ? serverNow() - REVEAL_BEAT.moments - 500 : serverNow());
    if (revealSeen.size > 60) revealSeen.delete(revealSeen.keys().next().value);
  }
  return revealSeen.get(key);
}
const BEATS = Object.values(REVEAL_BEAT);
/** ms since the reveal started (-1 outside `aufloesung`); re-renders only at the reveal beats. */
export function useRevealClock(scene, extra) {
  const at = scene.kind === "aufloesung" ? revealStart(scene) : null;
  return useBeats(at, extra && extra.length ? BEATS.concat(extra) : BEATS);
}
export function useRevealed(scene) {
  return useRevealClock(scene) >= REVEAL_BEAT.slam;
}
/** Wrong options go dark one after another — least-picked first, the popular trap last. */
function dimPlan(wall) {
  if (!wall || !wall.options || wall.correctIndex == null) return {};
  const wrong = wall.options.filter(o => !o.removed && o.id !== wall.correctIndex).sort((a, b) => (a.count || 0) - (b.count || 0) || a.id - b.id);
  const times = dimTimes(wrong.length);
  return Object.fromEntries(wrong.map((o, i) => [o.id, times[i]]));
}
const streakLabel = n => (n >= 5 ? "×2" : n >= 3 ? "×1,5" : "");
const secs = ms => (ms / 1000).toFixed(1).replace(".", ",");
const GOLD = ["#FFC93C", "#FFE27A", "#FF9F1C", "#FFF6E3", "#2BD98A"];
/** Name plates: shrink long names instead of cutting them off early. */
export const nameFit = name => { const n = (name || "").length; return n > 18 ? "nm-xl" : n > 12 ? "nm-l" : ""; };

export function sceneWantsPodium(scene) {
  return ["frage", "aufloesung", "kategorieWahl", "erklaerkarte", "rad"].includes(scene.kind);
}

export function playerMap(view) { return Object.fromEntries(view.players.map(p => [p.id, p])); }

export function SceneView({ view, scene }) {
  useEffect(() => { firstView = false; }, []);
  switch (scene.kind) {
    case "intro": return html`<${Intro} view=${view} s=${scene} />`;
    case "kategorieWahl": return html`<${KategorieWahl} view=${view} s=${scene} />`;
    case "erklaerkarte": return html`<${Explain} view=${view} c=${scene} />`;
    case "frage": case "aufloesung": return html`<${Question} view=${view} s=${scene} />`;
    case "zwischenstand": return html`<${Standings} view=${view} s=${scene} />`;
    case "rad": return html`<${WheelScene} view=${view} w=${scene} />`;
    case "pause": return html`<${Pause} view=${view} s=${scene} />`;
    case "highlights": return html`<${Highlights} view=${view} s=${scene} />`;
    case "siegerehrung": return html`<${Ceremony} view=${view} s=${scene} />`;
    case "ende": return html`<${Credits} view=${view} s=${scene} />`;
    case "brettspiel": return html`<${BoardgameScene} view=${view} b=${scene} />`;
    default: return html`<div class="center muted">…</div>`;
  }
}

// ---------- podium row ----------
/** Tile width + monkey size by head count (2 players get big tiles, 8 still fit on 1400 units). */
export function podiumDims(n) {
  if (n <= 2) return { tw: 250, size: 126 };
  if (n <= 3) return { tw: 232, size: 122 };
  if (n <= 4) return { tw: 212, size: 116 };
  if (n <= 5) return { tw: 198, size: 110 };
  if (n <= 6) return { tw: 186, size: 104 };
  if (n <= 8) return { tw: 166, size: 94 };
  return { tw: 128, size: 78 };
}

/** Who is expected to answer right now (the others don't get the "thinking" look). */
function expectedAnswerers(extra, players) {
  const all = players.filter(p => p.connected).map(p => p.id);
  if (!extra) return all;
  switch (extra.kind) {
    case "duel": return [extra.a, extra.b];
    case "bomb": return extra.holder ? [extra.holder] : [];
    case "buzzers": return [];
    case "pies": return all.filter(id => !(extra.out || []).includes(id));
    case "auction": return extra.leader ? [extra.leader] : all;
    default: return all;
  }
}

export function Podium({ view, scene }) {
  const isRev = scene.kind === "aufloesung";
  const t = useRevealClock(scene);
  const booked = !isRev || t >= REVEAL_BEAT.money;
  const late = isRev && t >= REVEAL_BEAT.extras;
  const R = isRev ? scene.reveal : null;
  const entry = R ? Object.fromEntries(R.eintraege.map(e => [e.playerId, e])) : {};
  const players = view.players;
  const extra = scene.extra ? decode(scene.extra) : null;
  const info = extra ? extraTileInfo(extra, scene, view) : {};
  const wall = scene.wall;
  const deltas = isRev ? scene.deltas || {} : {};
  const teams = Object.fromEntries((view.teams || []).map(t => [t.id, t]));
  // Until the money lands, show what everybody had before (no spoilers during the tension).
  const streaks = useRef({});
  const bal = p => (booked ? p.balance : entry[p.id] ? entry[p.id].balanceVorher : p.balance - (deltas[p.id] || 0));
  const streakOf = p => { if (booked) { streaks.current[p.id] = p.streak; return p.streak; } return streaks.current[p.id] ?? p.streak; };
  let leader = null;
  for (const p of players) if (bal(p) > 0 && (!leader || bal(p) > bal(leader))) leader = p;
  const { tw, size } = podiumDims(players.length);
  // Answer phase: a question is open (wall or pixel lock-ins) → show who is in and who still thinks.
  const asking = scene.kind === "frage" && ((wall && !wall.revealed) || (extra && extra.kind === "pixel" && info.locked));
  const expected = asking ? new Set(expectedAnswerers(extra, players)) : new Set();
  return html`<footer class=${cx("podium", asking && "asking")} style=${`--n:${Math.max(players.length, 1)};--tw:${tw}px`}>
    ${players.map((p, i) => {
      let face = "neutral", anim = "idle", badge = null;
      const answered = scene.kind === "frage" && ((wall && wall.answered.includes(p.id)) || (info.locked && info.locked.includes(p.id)));
      const waiting = asking && !answered && expected.has(p.id);
      if (asking) { face = answered ? "neutral" : waiting ? "denk" : "neutral"; anim = waiting ? "denk" : "idle"; }
      const e = entry[p.id];
      const d = deltas[p.id];
      if (isRev && !booked && (!e || e.richtig != null)) { face = "denk"; anim = "denk"; }
      if (isRev && booked && d != null) {
        face = d > 0 ? "jubel" : d < 0 ? "frust" : "neutral";
        anim = d > 0 ? "jubel" : d < 0 ? "frust" : "idle";
        badge = html`<span class=${cx("delta-pop fly", d > 0 ? "pos" : d < 0 ? "neg" : "zero", d >= 500 && "big")} style=${`animation-delay:${i * 70}ms`}>${d === 0 ? "±0" : fmtDelta(d)}${d >= 250 && html`<${CoinPop} n=${d >= 750 ? 8 : 5} />`}</span>`;
      }
      let tag = info.tags && info.tags[p.id];
      if (scene.kind === "erklaerkarte") {
        if ((scene.streik || []).includes(p.id)) tag = { text: "✊ Streik", cls: "out" };
        else if ((scene.bereit || []).includes(p.id)) { tag = { text: "👍 bereit", cls: "bank" }; face = "jubel"; }
      }
      const team = p.teamId && teams[p.teamId];
      const sk = streakOf(p);
      const fastest = late && R && R.schnellster === p.id && R.antwortAnzahl >= 2;
      const move = late && e ? e.platzVorher - e.platzNachher : 0;
      const crowned = late && R && R.fuehrungswechsel && e && e.platzNachher === 1;
      const milestone = late && e && e.richtig === true && (e.streak === 3 || e.streak === 5);
      return html`<div class=${cx("tile", answered && "answered", waiting && "waiting", !p.connected && "offline", tag && tag.hot && "hot", leader && leader.id === p.id && "leader",
          sk >= 5 ? "streak-5" : sk >= 3 && "streak-3", crowned && "crowned", isRev && booked && d > 0 && "won", isRev && booked && d < 0 && "lost")} key=${p.id}
          style=${team ? `--team:${team.farbe}` : ""}>
        ${sk >= 3 && html`<span class="aura"></span>`}
        ${badge}
        ${answered && html`<span class="lock-badge">✔</span>`}
        ${answered && html`<span class="lock-ring"></span>`}
        ${tag && html`<span class=${cx("tile-tag", tag.cls)}>${tag.text}</span>`}
        ${move !== 0 && html`<span class=${cx("rank-arrow", move > 0 ? "up" : "down")}>${move > 0 ? "▲" : "▼"}${Math.abs(move)}</span>`}
        ${crowned && html`<span class="crown-drop">👑<${Burst} /></span>`}
        ${milestone && html`<span class="streak-stamp">🔥 ${streakLabel(e.streak)}</span>`}
        ${info.ropes && info.ropes[p.id] != null && html`<div class="tile-rope" style=${`height:${24 + info.ropes[p.id] * 110}px`}></div>`}
        <div class="tile-monkey">
          ${waiting && html`<span class="think" style=${`animation-delay:${(i % 4) * 0.18}s`}><i></i><i></i><i></i></span>`}
          <${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} delay=${i * 230} />
        </div>
        <div class="tile-plate">
          <b class=${cx("tile-name", nameFit(p.name))}>${p.name}</b>
          <${Money} value=${bal(p)} class="tile-money" duration=${1100} />
          ${sk >= 3 && html`<span class="streak">🔥${sk}<i>${streakLabel(sk)}</i></span>`}
          ${late && e && e.speedBonus > 0 && html`<span class="speed-badge">⚡+${fmtNum(e.speedBonus)}</span>`}
          ${fastest && html`<span class="fast-callout">⚡ Schnellster${R.schnellsterMs ? " · " + secs(R.schnellsterMs) + " s" : ""}</span>`}
          ${asking && expected.has(p.id) && html`<span class="tile-status"><i></i></span>`}
        </div>
      </div>`;
    })}
  </footer>`;
}

// ---------- intro ----------
function Intro({ view, s }) {
  const n = view.players.length;
  const size = n > 8 ? 84 : n > 6 ? 100 : 122;
  return html`<div class="intro">
    <div class="intro-rays"></div>
    <div class="intro-spot sp1"></div><div class="intro-spot sp2"></div>
    <div class="intro-logo pop-in">
      <div class="logo big-logo"><div class="logo-hat">🎩</div><div class="logo-line l1">MONKEY</div><div class="logo-line l2">MONEY</div><div class="logo-plaque">DIE QUIZ-SHOW</div></div>
    </div>
    <h1 class="intro-headline rise-in" style="animation-delay:.6s">${s.headline}</h1>
    ${s.specialRules && s.specialRules.length > 0 && html`<div class="chip-row center rise-in intro-rules" style="animation-delay:1s">${s.specialRules.map(r => html`<span class="chip gold">✨ ${r}</span>`)}</div>`}
    <div class="intro-parade">${view.players.map((p, i) => html`<div class="parade-slot" style=${`animation-delay:${1.2 + i * 0.22}s`}>
      <${Monkey} wire=${p.avatar} face="jubel" anim="jubel" size=${size} delay=${i * 120} /><b class=${nameFit(p.name)}>${p.name}</b></div>`)}</div>
    <${Confetti} burst=${1} count=${120} rain=${true} />
  </div>`;
}

// ---------- category vote ----------
function KategorieWahl({ view, s }) {
  const total = s.optionen.reduce((a, o) => a + o.count, 0) || 1;
  const since = useSince(s.gewinner || "");
  const skip = useRef(null);
  if (skip.current === null) skip.current = !!s.gewinner && firstView;
  const wi = s.gewinner ? s.optionen.findIndex(o => o.id === s.gewinner) : -1;
  const steps = wi >= 0 && !skip.current ? rouletteSteps(s.optionen.length, wi) : [];
  const t = useBeats(s.gewinner ? since : null, steps.map(x => x.t));
  let spot = -1;
  for (const st of steps) if (st.t <= t) spot = st.idx;
  const rolling = wi >= 0 && steps.length > 0 && t < ROULETTE_MS;
  const done = wi >= 0 && !rolling;
  const votes = s.optionen.reduce((a, o) => a + o.count, 0);
  return html`<div class=${cx("kat", rolling && "rolling", done && "decided")}>
    <div class="kat-head">
      <div>
        <h1 class="rise-in">Welche Kategorie?</h1>
        <p class="muted rise-in" style="animation-delay:.12s">${s.letzter ? html`<b class="gold-text">${s.letzter.name}</b> liegt hinten und darf wählen!` : html`Stimmt auf euren Handys ab! <b class="kat-votes">${votes} ${votes === 1 ? "Stimme" : "Stimmen"}</b>`}</p>
      </div>
      ${!s.gewinner && html`<${StageTimer} deadline=${s.countdownAb || s.deadline} size=${118} />`}
    </div>
    <div class="kat-grid" style=${`--n:${s.optionen.length}`}>${s.optionen.map((o, i) => {
      const win = done && s.gewinner === o.id;
      const pct = Math.round((o.count / total) * 100);
      return html`<div class=${cx("kat-card", win && "win", done && !win && "lose", rolling && spot === i && "spot")} style=${`--c:${OPTION_STYLE[i % 8].c};animation-delay:${i * 110}ms`} key=${o.id}>
        <div class="kat-shine"></div>
        <div class="kat-emoji">${o.emoji || "❓"}</div>
        <h2>${o.label}</h2>
        <div class="kat-bar"><i style=${`transform:scaleX(${o.count / total})`}></i></div>
        <div class="kat-count"><b>${o.count}</b> ${o.count === 1 ? "Stimme" : "Stimmen"}${o.count > 0 ? html` · ${pct} %` : ""}</div>
        ${win && html`<${Burst} color=${OPTION_STYLE[i % 8].c} />`}
        ${win && html`<div class="kat-win">✔ GEWÄHLT</div>`}
      </div>`;
    })}</div>
  </div>`;
}

// ---------- explain card ----------
function Explain({ view, c }) {
  const n = view.players.length;
  const many = c.regeln.length > 3;
  return html`<div class="explain">
    <div class=${cx("explain-card", many && "many")}>
      <div class="explain-badge">Runde ${c.rundenNummer}<small>/${c.rundenGesamt}</small></div>
      <div class="explain-left">
        <div class="explain-halo"></div>
        <div class="explain-emoji pop-in">${c.emoji}</div>
        <h1 class="rise-in">${c.name}</h1>
        <p class="explain-kurz rise-in" style="animation-delay:.15s">${c.kurz}</p>
      </div>
      <div class="explain-right">
        <h4 class="explain-sub rise-in" style="animation-delay:.25s">So läuft's</h4>
        <ol class="explain-rules">${c.regeln.map((r, i) => html`<li class="rise-in" style=${`animation-delay:${0.35 + i * 0.24}s`}><span>${i + 1}</span><p>${r}</p></li>`)}</ol>
        ${c.gewinn && html`<div class="explain-gewinn rise-in" style=${`animation-delay:${0.4 + c.regeln.length * 0.24}s`}><span>💰</span><p>${c.gewinn}</p></div>`}
      </div>
      <div class="explain-foot">
        <div class="ready-row">${view.players.map(p => {
          const ok = c.bereit.includes(p.id), no = c.streik.includes(p.id);
          return html`<span class=${cx("ready-av", ok && "ok", no && "no")} key=${p.id} title=${p.name}><${Monkey} wire=${p.avatar} face=${ok ? "jubel" : no ? "frust" : "neutral"} anim="none" size=${40} />${(ok || no) && html`<i>${ok ? "✔" : "✊"}</i>`}</span>`;
        })}</div>
        <span class="ready-count"><b key=${c.bereit.length}>${c.bereit.length}</b>/${n} bereit${c.streik.length ? html` · <span class="streik-n">✊ ${c.streik.length}</span>` : ""}</span>
        <div class="explain-timer"><${StageBar} deadline=${c.deadline} paused=${view.paused} /></div>
        ${c.deadline && html`<span class="explain-count">⏳ <${Secs} deadline=${c.deadline} paused=${view.paused} /> s</span>`}
      </div>
    </div>
  </div>`;
}

// ---------- question wall ----------
/** Question text size by length; the narrow column (picture/vinyl on the left) gets a step smaller. */
function fontFor(text, narrow) {
  const n = (text || "").length;
  const f = n < 50 ? 52 : n < 90 ? 44 : n < 140 ? 38 : n < 200 ? 32 : n < 280 ? 28 : 25;
  return narrow ? Math.round(f * 0.86) : f;
}
function optLenClass(options) {
  const m = Math.max(0, ...options.map(o => (o.text || "").length));
  return m > 64 ? "len-4" : m > 42 ? "len-3" : m > 24 ? "len-2" : "";
}

/** Intro beat per question: decided at first sight, stable for the life of that question. */
const introPlan = new Map();
function planIntro(key, s, wall) {
  if (!introPlan.has(key)) {
    const started = wall.deadline && wall.timerMs ? wall.deadline - wall.timerMs : null;
    const fresh = !firstView && s.kind === "frage" && (started == null || serverNow() - started < 2600);
    const afterWipe = fresh && Date.now() - lastSwitch.at < 250 && lastSwitch.variant && lastSwitch.variant !== "slide";
    introPlan.set(key, { fresh, delay: afterWipe ? 0.38 : 0 });
    if (introPlan.size > 60) introPlan.delete(introPlan.keys().next().value);
  }
  return introPlan.get(key);
}

function Question({ view, s }) {
  const wall = s.wall;
  const extra = decode(s.extra);
  const reveal = s.kind === "aufloesung";
  const plan = reveal ? dimPlan(wall) : {};
  const t = useRevealClock(s, Object.values(plan));
  const revealed = reveal && t >= REVEAL_BEAT.slam;
  const booked = reveal && t >= REVEAL_BEAT.money;
  const place = extraPlacement(extra, wall);
  const pm = playerMap(view);
  const tension = reveal && !revealed;
  const noSide = revealed && place !== "side";
  const R = reveal ? s.reveal : null;
  const maxDelta = Math.max(0, ...Object.values(s.deltas || {}));
  const bigWin = booked && (maxDelta >= 500 || (s.sectionKind === "jackpot" && maxDelta > 0));
  const online = view.players.filter(p => p.connected).length;
  const allIn = !reveal && wall && wall.answered.length > 0 && wall.answered.length >= online;
  const sum = R && revealed && html`<${RevealSum} r=${R} pm=${pm} t=${t} />`;
  const richtig = R && revealed && R.richtigText && !(wall && wall.options && wall.options.length) && html`<div class="richtig-banner"><${Burst} /><span>✔ Richtig:</span> <b>${R.richtigText}</b></div>`;
  const qk = wall ? `${s.minigameId}|${wall.nummer}|${wall.text.slice(0, 24)}` : "";
  const intro = wall ? planIntro(qk, s, wall) : { fresh: false, delay: 0 };
  const cardDelay = intro.fresh ? intro.delay + 0.52 : 0;
  const optDelay = intro.fresh ? intro.delay + 0.66 : 0.2;
  const narrow = place === "left";
  const hasOpts = !!(wall && wall.options && wall.options.length);
  const dense = place === "below" && hasOpts;
  const side = place === "side" && html`<${FitBox} class="side-extra"><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} /><//>`;
  return html`<div class=${cx("qwall", noSide && "no-side", reveal && "is-reveal", revealed && "revealed", tension && "tension", booked && "booked", place && "x-" + place,
      dense && "dense", intro.fresh && "fresh", s.sectionKind !== "runde" && "sk-" + s.sectionKind)}
      style=${`--qd:${cardDelay}s;--od:${optDelay}s`}>
    ${!reveal && wall && wall.deadline && html`<${Urgency} deadline=${wall.deadline} paused=${view.paused} />`}
    ${tension && html`<div class="tension-veil"></div>`}
    ${allIn && html`<div class="all-in" key="allin"><span>✔ Alle haben geantwortet!</span></div>`}
    ${wall && intro.fresh && !reveal && html`<${QIntro} wall=${wall} s=${s} delay=${intro.delay} />`}
    ${wall ? html`
      <div class="q-main">
        <div class="q-meta">
          <span class="chip cat">${wall.kategorieEmoji} ${wall.kategorieName}</span>
          <span class="chip diff d-${wall.schwierigkeit}"><${Stars} n=${(DIFF[wall.schwierigkeit] || [0, 1])[1]} /> ${(DIFF[wall.schwierigkeit] || [""])[0]}</span>
          ${wall.gesamt > 0 && html`<span class="chip q-num">Frage <b>${wall.nummer}</b>/${wall.gesamt}</span>`}
          ${s.sectionKind === "jackpot" && html`<span class="chip gold">🫙 JACKPOT-FRAGE</span>`}
          ${s.sectionKind === "finale" && html`<span class="chip gold">🐊 FINALE</span>`}
          ${sum || html`<span class="q-value">💰 ${fmtMM(wall.wert)}</span>`}
        </div>
        <div class=${cx("q-body", narrow && "with-left")}>
          ${narrow && html`<div class="q-left"><${FitBox} center><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} /><//></div>`}
          <div class="q-center">
            <div class="q-card">
              ${wall.blackout && !reveal ? html`<div class="q-text blackout">🌑 BLACKOUT — die Frage steht nur auf euren Handys!</div>`
                : html`<div class="q-text" style=${`font-size:${fontFor(wall.text, narrow)}px`}>${wall.text}</div>`}
              ${wall.tipp && html`<div class="q-tipp pop-in">💡 ${wall.tipp}</div>`}
              ${!reveal && wall.deadline && html`<${StageBar} class="q-fuse" deadline=${wall.deadline} total=${wall.timerMs} paused=${view.paused} />`}
            </div>
            ${hasOpts && html`<${Options} wall=${wall} reveal=${reveal} t=${t} plan=${plan} pm=${pm} narrow=${narrow} />`}
            ${richtig}
            ${place === "below" && html`<${FitBox} class="q-extra"><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} /><//>`}
            ${reveal && revealed && wall.erklaerung && html`<div class="q-erkl rise-in" style="animation-delay:.5s">📖 ${wall.erklaerung}</div>`}
          </div>
        </div>
      </div>
      <aside class="q-side">
        ${!reveal && (wall.deadline ? html`<${StageTimer} deadline=${wall.deadline} total=${wall.timerMs} size=${150} paused=${view.paused} />` : html`<div class="no-timer"><b>∞</b><small>ohne Timer</small></div>`)}
        ${!reveal && html`<${AnsweredMeter} n=${wall.answered.length} of=${view.players.length} />`}
        ${tension && html`<div class="tension-text">Und die richtige Antwort ist …</div>`}
        ${side}
      </aside>`
    : html`<div class="q-noWall">
        ${s.title && html`<h1 class="rise-in">${s.title}</h1>`}
        ${sum && html`<div class="q-meta center">${sum}</div>`}
        ${R && revealed && R.richtigText && html`<div class="richtig-banner"><${Burst} /><span>✔ Richtig:</span> <b>${R.richtigText}</b></div>`}
        <${FitBox} class="q-full" center><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} full=${true} /><//>
      </div>`}
    ${bigWin && html`<${Confetti} burst=${1} count=${120} colors=${GOLD} />`}
  </div>`;
}

/** "Frage 2/4 · 250 MM · 🎮 Kategorie" sweeps across before the card lands (pure CSS, ~900 ms). */
function QIntro({ wall, s, delay }) {
  const [on, setOn] = useState(true);
  useEffect(() => { const t = setTimeout(() => setOn(false), 1000 + delay * 1000); return () => clearTimeout(t); }, []);
  if (!on) return null;
  const sk = s.sectionKind;
  const lead = sk === "jackpot" ? "🫙 Jackpot-Frage" : sk === "finale" ? "🐊 Finale" : null;
  return html`<div class=${cx("q-intro", sk !== "runde" && "sk-" + sk)} style=${`--d:${delay}s`} aria-hidden="true">
    <div class="qi-band">
      ${lead && html`<span class="qi-lead">${lead}</span>`}
      <span class="qi-num">Frage <b>${wall.nummer}</b>${wall.gesamt > 0 ? html`<small>/${wall.gesamt}</small>` : ""}</span>
      <i class="qi-dot"></i>
      <span class="qi-val">${fmtMM(wall.wert)}</span>
      <i class="qi-dot"></i>
      <span class="qi-cat">${wall.kategorieEmoji} ${wall.kategorieName}</span>
    </div>
  </div>`;
}

/** Answer counter with a pip per player (pops when someone locks in). */
function AnsweredMeter({ n, of }) {
  const full = n >= of && of > 0;
  return html`<div class=${cx("answered-count", full && "full")}>
    <div class="ac-num"><b key=${n}>${n}</b><span>/ ${of}</span></div>
    <small>${full ? "✔ alle drin" : "eingeloggt"}</small>
    <div class="pips">${Array.from({ length: of }, (_, i) => html`<i class=${i < n ? "on" : ""}></i>`)}</div>
  </div>`;
}

/** Red vignette + heartbeat in the last five seconds. Only this tiny node re-renders (1 Hz). */
function Urgency({ deadline, paused }) {
  const [, force] = useState(0);
  const remain = deadline - serverNow();
  useEffect(() => {
    if (paused) return;
    const r = deadline - serverNow();
    if (r <= -600) return;
    const next = r > 5000 ? r - 5000 : r > 0 ? (r % 500 || 500) : 600;
    const id = setTimeout(() => force(x => x + 1), next + 10);
    return () => clearTimeout(id);
  });
  if (paused || remain > 5000 || remain <= -500) return null;
  const lvl = remain <= 2000 ? 3 : remain <= 3500 ? 2 : 1;
  return html`<div class=${cx("urgency", "lvl-" + lvl)}><i></i></div>`;
}

/** "x von y richtig" meter + fastest chip (in the question meta row). */
function RevealSum({ r, pm, t }) {
  const late = t >= REVEAL_BEAT.extras;
  const frac = r.antwortAnzahl ? r.richtigAnzahl / r.antwortAnzahl : 0;
  const fast = late && r.schnellster && r.antwortAnzahl >= 2 && pm[r.schnellster];
  return html`<div class="reveal-sum">
    ${r.antwortAnzahl > 0 && html`<div class=${cx("rs-meter", r.richtigAnzahl === 0 && "none", r.richtigAnzahl === r.antwortAnzahl && "all")}>
      <span>✔ <b>${r.richtigAnzahl}</b> von ${r.antwortAnzahl} richtig</span>
      <i style=${`--v:${frac}`}></i>
    </div>`}
    ${fast && html`<div class="rs-fast"><${Monkey} wire=${fast.avatar} face="jubel" anim="none" size=${34} /><span>⚡ ${fast.name}${r.schnellsterMs ? html` <small>${secs(r.schnellsterMs)} s</small>` : ""}</span></div>`}
    ${late && r.fuehrungswechsel && html`<div class="rs-lead">👑 Neue Spitze!</div>`}
  </div>`;
}

function Options({ wall, reveal, t, plan, pm, narrow }) {
  const revealed = reveal && t >= REVEAL_BEAT.slam;
  const votes = reveal && t >= REVEAL_BEAT.votes;
  const pickers = {};
  for (const [pid, idx] of Object.entries(wall.answersByPlayer || {})) (pickers[idx] = pickers[idx] || []).push(pid);
  const n = wall.options.length;
  const total = Math.max(1, wall.options.reduce((a, o) => a + (o.count != null ? o.count : (pickers[o.id] || []).length), 0));
  return html`<div class=${cx("options", n > 4 && "many", n === 2 && "two", n === 3 && "three", optLenClass(wall.options), narrow && "narrow")}>${wall.options.map((o, i) => {
    const st = OPTION_STYLE[i % 8];
    const correct = revealed && wall.correctIndex === o.id;
    const wrong = revealed && wall.correctIndex != null && wall.correctIndex !== o.id;
    const out = reveal && !revealed && plan[o.id] != null && t >= plan[o.id];
    const who = pickers[o.id] || [];
    const count = o.count != null ? o.count : who.length;
    return html`<div class=${cx("opt", o.removed && "removed", correct && "correct", wrong && "wrong", out && "out", votes && "votes")} key=${o.id}
        style=${`--c:${st.c};--d:${st.d};--v:${count / total};animation-delay:calc(var(--od) + ${i * 0.08}s)`}>
      <span class="opt-fill"><i class="opt-bar"></i><i class="opt-shine"></i></span>
      <span class="opt-badge"><b>${st.l}</b><i>${st.e}</i></span>
      <span class="opt-text">${o.text}</span>
      ${votes && who.length > 0 && html`<span class="opt-who">${who.slice(0, 6).map((pid, k) => pm[pid] && html`<span class="who-pop" style=${`animation-delay:${k * 90}ms`}><${Monkey} wire=${pm[pid].avatar} anim="none" face=${correct ? "jubel" : wrong ? "frust" : "neutral"} size=${38} /></span>`)}${who.length > 6 && html`<small class="who-more">+${who.length - 6}</small>`}</span>`}
      ${votes && html`<span class="opt-count">${count}</span>`}
      ${correct && html`<${Burst} />`}
      ${correct && html`<span class="opt-check">✔</span>`}
    </div>`;
  })}</div>`;
}

// ---------- standings ----------
function Standings({ view, s }) {
  const entries = s.entries;
  const gain = e => (e.rundenDelta != null ? e.rundenDelta : e.delta);
  const max = Math.max(1, ...entries.map(e => Math.abs(e.player.balance)), ...entries.map(e => Math.abs(e.player.balance - gain(e))));
  const [st, setSt] = useState(0); // 0 empty · 1 old values · 2 booked · 3 badges
  useEffect(() => {
    const ts = [setTimeout(() => setSt(1), 300), setTimeout(() => setSt(2), STANDINGS_FLIP_MS - 250), setTimeout(() => setSt(3), STANDINGS_FLIP_MS + 900)];
    return () => ts.forEach(clearTimeout);
  }, []);
  const listRef = useRef();
  const from = Object.fromEntries(entries.map((e, i) => [e.player.id, e.platzVorher ? e.platzVorher - 1 : i]));
  useFlip(listRef, from, STANDINGS_FLIP_MS, []);
  const newLeader = entries.length > 1 && entries[0].platzVorher > 1;
  const dense = entries.length > 6;
  return html`<div class=${cx("standings", st >= 3 && "settled", dense && "dense")}>
    <div class="stand-head">
      <h1 class="rise-in">${s.halbzeit ? "⏸ Halbzeit!" : "Zwischenstand"}</h1>
      <span class="chip rise-in round-chip" style="animation-delay:.1s">nach Runde <b>${s.rundenNummer}</b> von ${s.rundenGesamt}</span>
      ${newLeader && st >= 3 && html`<span class="chip gold lead-chip">👑 Neue Spitze: ${entries[0].player.name}</span>`}
      ${s.deadline && html`<${StageTimer} deadline=${s.deadline} size=${84} paused=${view.paused} />`}
    </div>
    <ol class="stand-list" ref=${listRef}>${entries.map((e, i) => {
      const p = e.player;
      const g = gain(e);
      const old = e.platzVorher || i + 1;
      const move = old - (i + 1);
      const shownRank = st >= 3 ? i : old - 1;
      const bal = st >= 2 ? p.balance : p.balance - g;
      return html`<li class="stand-slot" data-flip=${p.id} key=${p.id}>
        <div class=${cx("stand-row", shownRank < 3 && "top-" + (shownRank + 1), i === 0 && st >= 3 && "first", i === 0 && newLeader && st >= 3 && "new-leader", move > 0 && st >= 3 && "climbed")} style=${`animation-delay:${(entries.length - old) * 0.08}s`}>
          <span class="stand-rank" key=${shownRank}>${shownRank < 3 ? ["🥇", "🥈", "🥉"][shownRank] : shownRank + 1}</span>
          <${Monkey} wire=${p.avatar} anim=${st >= 3 && i === 0 ? "jubel" : st >= 3 && g < 0 ? "frust" : "idle"} face=${st >= 3 && i === 0 ? "jubel" : st >= 3 && g < 0 ? "frust" : "neutral"} size=${dense ? 50 : 60} />
          <span class=${cx("stand-name", nameFit(p.name))}>${p.name}${p.streak >= 3 ? html` <small class="stand-streak">🔥${p.streak}</small>` : ""}
            ${st >= 3 && move !== 0 && html`<span class=${cx("rank-move", move > 0 ? "up" : "down")}>${move > 0 ? "↑" : "↓"}${Math.abs(move)}</span>`}
          </span>
          <div class="stand-bar"><i style=${`transform:scaleX(${st >= 1 ? Math.max(0.03, Math.max(0, bal) / max) : 0})`}></i></div>
          <span class=${cx("stand-delta", g > 0 ? "pos" : g < 0 ? "neg" : "none", st >= 2 && "on")}><small>Runde</small>${g !== 0 ? fmtDelta(g) : ""}</span>
          <span class="wind">${e.rueckenwind > 1 && html`<span class="chip green">🌬️ ×${fmtNum(e.rueckenwind)}</span>`}</span>
          <b class="stand-money"><${Money} value=${bal} duration=${1300} /></b>
          ${i === 0 && newLeader && st >= 3 && html`<span class="crown-drop row">👑<${Burst} /></span>`}
        </div>
      </li>`;
    })}</ol>
  </div>`;
}

// ---------- wheel ----------
const WHEEL_COLORS = { gruen: ["#2bd98a", "#0f7a4a"], blau: ["#4d8bff", "#1f4bb0"], gold: ["#ffc93c", "#b7780b"] };
function WheelScene({ view, w }) {
  const n = w.face.length || 1;
  const seg = 360 / n;
  const spinning = w.subphase === "dreht";
  const now = useFrame(spinning);
  let steps = 0;
  if (w.spinStartedAt && w.resultIndex != null) {
    const total = Wheel.steps(n, w.resultIndex);
    steps = w.subphase === "dreht" ? Wheel.progress(now - w.spinStartedAt, w.spinDurationMs) * total : total;
  }
  const landed = w.subphase !== "dreht" && w.subphase !== "idle" && w.resultIndex != null;
  const result = landed ? w.face[w.resultIndex] : null;
  const pm = playerMap(view);
  const lit = Math.floor(steps) % n;
  const R = 330;
  const grad = w.face.map((f, i) => `${(WHEEL_COLORS[f.klasse] || WHEEL_COLORS.blau)[i % 2 ? 1 : 0]} ${i * seg}deg ${(i + 1) * seg}deg`).join(",");
  return html`<div class=${cx("wheel-scene", landed && "landed", spinning && "spinning")}>
    <div class="wheel-wrap">
      <div class="wheel-glow"></div>
      <div class="wheel-pointer"></div>
      <div class="wheel" style=${`transform:rotate(${-steps * seg}deg);background:conic-gradient(from ${-seg / 2}deg, ${grad})`}>
        ${w.face.map((f, i) => html`<div class=${cx("wheel-seg", i === lit && (spinning || landed) && "lit")} style=${`transform:rotate(${i * seg}deg)`}>
          <span class="ws-emoji">${f.emoji}</span><span class="ws-name">${f.name}</span></div>`)}
        ${Array.from({ length: n }, (_, i) => html`<i class="wheel-peg" style=${`transform:rotate(${i * seg + seg / 2}deg) translateY(-${R - 8}px)`}></i>`)}
      </div>
      <div class="wheel-hub">🎡</div>
      <div class="wheel-lights">${Array.from({ length: 24 }, (_, i) => html`<i style=${`transform:rotate(${i * 15}deg) translateY(-${R + 26}px);animation-delay:${(i % 2) * 0.3}s`}></i>`)}</div>
    </div>
    <div class="wheel-info">
      ${!landed ? html`<div class="wheel-wait"><h1>Glücksrad!</h1><p class="muted">${spinning ? "Es dreht sich …" : "Gleich wird gedreht …"}</p></div>`
      : html`<div class=${cx("wheel-result pop-in", "k-" + result.klasse)}>
          <div class="wr-emoji">${result.emoji}</div>
          <h2>${result.name}</h2>
          <p>${w.erklaerung || result.wirkung}</p>
          ${w.betroffene.length > 0 && html`<div class="wr-who">${w.betroffene.map(id => pm[id] && html`<span><${Monkey} wire=${pm[id].avatar} face="denk" anim="idle" size=${60} /><b>${pm[id].name}</b></span>`)}</div>`}
          ${w.interactionEndsAt && html`<div class="wr-timer">⏳ <${Secs} deadline=${w.interactionEndsAt} paused=${view.paused} /> s — auf den Handys!</div>`}
        </div>`}
    </div>
  </div>`;
}

// ---------- pause ----------
function Pause({ view, s }) {
  const st = s.standings || [];
  return html`<div class=${cx("pause-scene", st.length > 6 && "dense")}>
    <div class="pause-card pop-in">
      <div class="pause-emoji">${(s.text || "").startsWith("💾") ? "💾" : "🍌"}</div>
      <h1>${(s.text || "Pause").replace(/^💾\s*/, "").replace(/\s*—\s*weiter mit ▶$/i, "")}</h1>
      ${s.endsAt ? html`<p class="pause-count">Weiter in <${Secs} deadline=${s.endsAt} /> s</p>` : html`<p class="pause-hint">Weiter mit <b>▶ Weiter</b> oben rechts oder Leertaste</p>`}
    </div>
    ${st.length > 0 && html`<div class="mini-stand-wrap"><h3>Zwischenstand</h3><ol class="mini-stand">${st.map((e, i) => html`<li class=${cx("rise-in", i === 0 && "first")} style=${`animation-delay:${0.2 + i * 0.07}s`}><span class="ms-rank">${i + 1}</span><${Monkey} wire=${e.player.avatar} anim="idle" size=${st.length > 6 ? 36 : 44} delay=${i * 200} /><b class=${nameFit(e.player.name)}>${e.player.name}</b><${Money} value=${e.player.balance} /></li>`)}</ol></div>`}
  </div>`;
}

// ---------- highlights ----------
function Highlights({ view, s }) {
  const pm = playerMap(view);
  const many = s.entries.length > 4;
  return html`<div class=${cx("highlights", many && "many")}>
    <h1 class="rise-in">✨ Die Highlights der Show</h1>
    <div class="hl-list">${s.entries.map((e, i) => html`<div class="hl" style=${`animation-delay:${0.3 + i * 0.6}s;--i:${i}`}>
      <span class="hl-n">${i + 1}</span>
      <span class="hl-emoji">${e.emoji}</span>
      <p>${e.text}</p>
      ${e.playerId && pm[e.playerId] && html`<${Monkey} wire=${pm[e.playerId].avatar} face="jubel" anim="jubel" size=${many ? 64 : 84} delay=${i * 150} />`}
    </div>`)}</div>
  </div>`;
}

// ---------- ceremony ----------
function Ceremony({ view, s }) {
  const since = useRef(serverNow()).current;
  const drum = CEREMONY_ROLL_MS + CEREMONY_SILENCE_MS;
  const t = useBeats(since, [drum, drum + 900, drum + 1800]);
  const stage = t < drum ? 0 : t < drum + 900 ? 1 : t < drum + 1800 ? 2 : 3; // 0 drum, 1 bronze, 2 silver, 3 gold
  const podium = s.podium;
  const pm = playerMap(view);
  const order = [podium[1], podium[0], podium[2]]; // silver, gold, bronze
  const rest = podium.slice(3);
  return html`<div class=${cx("ceremony", "st-" + stage)}>
    <div class="spot s1"></div><div class="spot s2"></div>
    ${stage === 0 ? html`<div class="drumroll"><div class="drum">🥁</div><h1>Und die Siegerin oder der Sieger ist …</h1></div>` : html`<h1 class="cer-title pop-in">🏆 Siegerehrung</h1>`}
    <div class="cer-podium">${order.map(e => {
      if (!e) return html`<div class="cer-col empty"></div>`;
      const visible = (e.platz === 3 && stage >= 1) || (e.platz === 2 && stage >= 2) || (e.platz === 1 && stage >= 3);
      return html`<div class=${cx("cer-col", "p" + e.platz, visible && "shown")} key=${e.player.id}>
        <div class="cer-who">
          ${e.platz === 1 && html`<div class="cer-rays"></div>`}
          ${e.platz === 1 && html`<div class="crown">👑</div>`}
          <${Monkey} wire=${e.player.avatar} face="jubel" anim=${e.platz === 1 ? "jubel" : "dance"} size=${e.platz === 1 ? 176 : 138} />
          <div class="cer-plate">
            <b class=${cx("cer-name", nameFit(e.player.name))}>${e.player.name}</b>
            <span class="cer-mm">${fmtMM(e.mm)}</span>
            ${e.at > 0 && html`<small class="cer-at">+${fmtNum(e.at)} AT</small>`}
          </div>
        </div>
        <div class="cer-block"><span>${e.platz}</span></div>
      </div>`;
    })}</div>
    ${stage >= 3 && html`
      ${rest.length > 0 && html`<div class="cer-rest">${rest.map(e => html`<span class="chip">${e.platz}. ${e.player.name} · ${fmtMM(e.mm)}</span>`)}</div>`}
      ${s.awards.length > 0 && html`<div class="awards"><h3>🎖️ Awards</h3>${s.awards.map((a, i) => html`<div class="award" style=${`animation-delay:${0.4 + i * 0.22}s`}>
        <span class="aw-emoji">${a.emoji}</span><div><b>${a.titel}</b><small>${(pm[a.playerId] || {}).name || ""}${a.detail ? " · " + a.detail : ""}</small></div>
        ${pm[a.playerId] && html`<${Monkey} wire=${pm[a.playerId].avatar} face="jubel" anim="none" size=${36} />`}</div>`)}</div>`}
      <${Confetti} burst=${1} count=${260} />`}
  </div>`;
}

function Credits({ view, s }) {
  return html`<div class="credits">
    <div class="credits-glow"></div>
    <div class="credits-roll">
      <p class="credits-kicker rise-in">Das war Monkey Money</p>
      <h1 class="rise-in" style="animation-delay:.1s">Danke fürs Mitspielen! 🐒</h1>
      <div class=${cx("credits-podium", s.podium.length > 5 && "many")}>${s.podium.map((e, i) => html`<div class=${cx("cp rise-in", i < 3 && "cp-" + (i + 1))} style=${`animation-delay:${0.25 + i * 0.12}s`}>
        <span class="cp-rank">${i < 3 ? ["🥇", "🥈", "🥉"][i] : i + 1 + "."}</span>
        <${Monkey} wire=${e.player.avatar} face=${i === 0 ? "jubel" : "neutral"} anim=${i === 0 ? "dance" : "idle"} size=${i === 0 ? 86 : 70} delay=${i * 180} />
        <b class=${nameFit(e.player.name)}>${e.player.name}</b><span class="cp-mm">${fmtMM(e.mm)}</span></div>`)}</div>
      <p class="muted">Feedback geht auf den Handys · Revanche mit denselben Affen?</p>
      <div class="menu-row center">
        <button class="btn big" onClick=${() => StageCtx.cmd({ revanche: {} })}>🔁 Revanche!</button>
        <button class="btn ghost" onClick=${() => fetch("/api/host/close", { method: "POST" }).then(() => StageCtx.refreshHost())}>🏠 Hauptmenü</button>
      </div>
    </div>
  </div>`;
}
