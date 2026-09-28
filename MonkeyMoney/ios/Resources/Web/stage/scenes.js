// Stage scenes: intro, category vote, explain card, question wall + reveal,
// standings, wheel, pause, highlights, ceremony, credits, board games.
import { html, useState, useEffect, useRef } from "../vendor/preact-htm.js";
import { decode, cx, fmtMM, fmtDelta, fmtNum, serverNow, useNow, useFrame, useSince, OPTION_STYLE, DIFF, Wheel } from "../lib/core.js";
import { Monkey, Money, TimerRing, TimerBar, Confetti, PixelImage, Stars, Countdown } from "../lib/ui.js";
import { Extra, extraPlacement, extraTileInfo } from "./extras.js";
import { BoardgameScene } from "./boards.js";
import { REVEAL_FANFARE_MS, CEREMONY_ROLL_MS, CEREMONY_SILENCE_MS, REVEAL_BEAT, dimTimes, rouletteSteps, ROULETTE_MS, STANDINGS_FLIP_MS } from "./regie.js";
import { useBeats, Burst, CoinPop, useFlip } from "./fx.js";
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
  const size = players.length > 8 ? 78 : players.length > 6 ? 92 : 108;
  return html`<footer class="podium" style=${`--n:${Math.max(players.length, 1)}`}>
    ${players.map((p, i) => {
      let face = "neutral", anim = "idle", badge = null;
      const answered = scene.kind === "frage" && ((wall && wall.answered.includes(p.id)) || (info.locked && info.locked.includes(p.id)));
      if (scene.kind === "frage") { face = answered ? "neutral" : "denk"; anim = answered ? "idle" : "denk"; }
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
      return html`<div class=${cx("tile", answered && "answered", !p.connected && "offline", tag && tag.hot && "hot", leader && leader.id === p.id && "leader",
          sk >= 5 ? "streak-5" : sk >= 3 && "streak-3", crowned && "crowned", isRev && booked && d > 0 && "won", isRev && booked && d < 0 && "lost")} key=${p.id}
          style=${team ? `--team:${team.farbe}` : ""}>
        ${sk >= 3 && html`<span class="aura"></span>`}
        ${badge}
        ${answered && html`<span class="lock-badge pop-in">✔</span>`}
        ${answered && html`<span class="lock-ring"></span>`}
        ${tag && html`<span class=${cx("tile-tag", tag.cls)}>${tag.text}</span>`}
        ${move !== 0 && html`<span class=${cx("rank-arrow", move > 0 ? "up" : "down")}>${move > 0 ? "▲" : "▼"}${Math.abs(move)}</span>`}
        ${crowned && html`<span class="crown-drop">👑<${Burst} /></span>`}
        ${milestone && html`<span class="streak-stamp">🔥 ${streakLabel(e.streak)}</span>`}
        ${info.ropes && info.ropes[p.id] != null && html`<div class="tile-rope" style=${`height:${24 + info.ropes[p.id] * 110}px`}></div>`}
        <div class="tile-monkey"><${Monkey} wire=${p.avatar} face=${face} anim=${anim} size=${size} delay=${i * 230} /></div>
        <div class="tile-plate">
          <b class="tile-name">${p.name}</b>
          <${Money} value=${bal(p)} class="tile-money" duration=${1100} />
          ${sk >= 3 && html`<span class="streak">🔥${sk}<i>${streakLabel(sk)}</i></span>`}
          ${late && e && e.speedBonus > 0 && html`<span class="speed-badge">⚡+${fmtNum(e.speedBonus)}</span>`}
          ${fastest && html`<span class="fast-callout">⚡ Schnellster${R.schnellsterMs ? " · " + secs(R.schnellsterMs) + " s" : ""}</span>`}
        </div>
      </div>`;
    })}
  </footer>`;
}

// ---------- intro ----------
function Intro({ view, s }) {
  return html`<div class="intro">
    <div class="intro-rays"></div>
    <div class="intro-spot sp1"></div><div class="intro-spot sp2"></div>
    <div class="intro-logo pop-in">
      <div class="logo big-logo"><div class="logo-hat">🎩</div><div class="logo-line l1">MONKEY</div><div class="logo-line l2">MONEY</div><div class="logo-plaque">DIE QUIZ-SHOW</div></div>
    </div>
    <h1 class="intro-headline rise-in" style="animation-delay:.6s">${s.headline}</h1>
    ${s.specialRules && s.specialRules.length > 0 && html`<div class="chip-row center rise-in" style="animation-delay:1s">${s.specialRules.map(r => html`<span class="chip gold">✨ ${r}</span>`)}</div>`}
    <div class="intro-parade">${view.players.map((p, i) => html`<div class="parade-slot" style=${`animation-delay:${1.2 + i * 0.25}s`}><${Monkey} wire=${p.avatar} face="jubel" anim="jubel" size=${120} delay=${i * 120} /><b>${p.name}</b></div>`)}</div>
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
  return html`<div class=${cx("kat", rolling && "rolling", done && "decided")}>
    <div class="kat-head">
      <div><h1 class="rise-in">Welche Kategorie?</h1><p class="muted rise-in" style="animation-delay:.12s">${s.letzter ? html`<b class="gold-text">${s.letzter.name}</b> liegt hinten und darf wählen!` : "Stimmt auf euren Handys ab!"}</p></div>
      ${!s.gewinner && html`<${TimerRing} deadline=${s.countdownAb || s.deadline} size=${130} />`}
    </div>
    <div class="kat-grid" style=${`--n:${s.optionen.length}`}>${s.optionen.map((o, i) => {
      const win = done && s.gewinner === o.id;
      return html`<div class=${cx("kat-card", win && "win", done && !win && "lose", rolling && spot === i && "spot")} style=${`--c:${OPTION_STYLE[i % 8].c};animation-delay:${i * 110}ms`} key=${o.id}>
        <div class="kat-shine"></div>
        <div class="kat-emoji">${o.emoji || "❓"}</div>
        <h2>${o.label}</h2>
        <div class="kat-bar"><i style=${`width:${(o.count / total) * 100}%`}></i></div>
        <div class="kat-count">${o.count} ${o.count === 1 ? "Stimme" : "Stimmen"}</div>
        ${win && html`<${Burst} color=${OPTION_STYLE[i % 8].c} />`}
        ${win && html`<div class="kat-win">✔ GEWÄHLT</div>`}
      </div>`;
    })}</div>
  </div>`;
}

// ---------- explain card ----------
function Explain({ view, c }) {
  const n = view.players.length;
  return html`<div class="explain">
    <div class="explain-card card">
      <div class="explain-badge">Runde ${c.rundenNummer}<small>/${c.rundenGesamt}</small></div>
      <div class="explain-left">
        <div class="explain-halo"></div>
        <div class="explain-emoji pop-in">${c.emoji}</div>
        <h1 class="rise-in">${c.name}</h1>
        <p class="explain-kurz rise-in" style="animation-delay:.15s">${c.kurz}</p>
      </div>
      <div class="explain-right">
        <ol class="explain-rules">${c.regeln.map((r, i) => html`<li class="rise-in" style=${`animation-delay:${0.35 + i * 0.28}s`}><span>${i + 1}</span>${r}</li>`)}</ol>
        ${c.gewinn && html`<div class="explain-gewinn rise-in" style=${`animation-delay:${0.4 + c.regeln.length * 0.28}s`}>💰 ${c.gewinn}</div>`}
      </div>
      <div class="explain-foot">
        <div class="ready-row">${view.players.map(p => {
          const ok = c.bereit.includes(p.id), no = c.streik.includes(p.id);
          return html`<span class=${cx("ready-av", ok && "ok", no && "no")} key=${p.id} title=${p.name}><${Monkey} wire=${p.avatar} face=${ok ? "jubel" : no ? "frust" : "neutral"} anim="none" size=${38} />${(ok || no) && html`<i>${ok ? "✔" : "✊"}</i>`}</span>`;
        })}</div>
        <span class="ready-count"><b key=${c.bereit.length}>${c.bereit.length}</b>/${n} bereit${c.streik.length ? html` · <span class="streik-n">✊ ${c.streik.length}</span>` : ""}</span>
        <div class="explain-timer"><${TimerBar} deadline=${c.deadline} /></div>
        ${c.deadline && html`<span class="explain-count">⏳ <${Countdown} deadline=${c.deadline} /></span>`}
      </div>
    </div>
  </div>`;
}

// ---------- question wall ----------
function fontFor(text) {
  const n = (text || "").length;
  return n < 50 ? 52 : n < 90 ? 44 : n < 140 ? 38 : n < 200 ? 32 : 28;
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
  return html`<div class=${cx("qwall", noSide && "no-side", reveal && "is-reveal", revealed && "revealed", tension && "tension", booked && "booked", place && "x-" + place, s.sectionKind !== "runde" && "sk-" + s.sectionKind)}>
    ${!reveal && wall && wall.deadline && html`<${Urgency} deadline=${wall.deadline} paused=${view.paused} />`}
    ${tension && html`<div class="tension-veil"></div>`}
    ${allIn && html`<div class="all-in" key="allin"><span>✔ Alle haben geantwortet!</span></div>`}
    ${wall ? html`
      <div class="q-main">
        <div class="q-meta rise-in">
          <span class="chip cat">${wall.kategorieEmoji} ${wall.kategorieName}</span>
          <span class="chip diff d-${wall.schwierigkeit}"><${Stars} n=${(DIFF[wall.schwierigkeit] || [0, 1])[1]} /> ${(DIFF[wall.schwierigkeit] || [""])[0]}</span>
          ${wall.gesamt > 0 && html`<span class="chip">Frage ${wall.nummer}/${wall.gesamt}</span>`}
          ${s.sectionKind === "jackpot" && html`<span class="chip gold">🫙 JACKPOT-FRAGE</span>`}
          ${s.sectionKind === "finale" && html`<span class="chip gold">🐊 FINALE</span>`}
          ${sum || html`<span class="q-value">💰 ${fmtMM(wall.wert)}</span>`}
        </div>
        <div class=${cx("q-body", place === "left" && "with-left")}>
          ${place === "left" && html`<div class="q-left"><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} /></div>`}
          <div class="q-center">
            <div class="q-card">
              ${wall.blackout && !reveal ? html`<div class="q-text blackout">🌑 BLACKOUT — die Frage steht nur auf euren Handys!</div>`
                : html`<div class="q-text" style=${`font-size:${fontFor(wall.text)}px`}>${wall.text}</div>`}
              ${wall.tipp && html`<div class="q-tipp pop-in">💡 ${wall.tipp}</div>`}
            </div>
            ${wall.options && wall.options.length > 0 && html`<${Options} wall=${wall} reveal=${reveal} t=${t} plan=${plan} pm=${pm} />`}
            ${richtig}
            ${place === "below" && html`<div class="q-extra"><${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} /></div>`}
            ${reveal && revealed && wall.erklaerung && html`<div class="q-erkl rise-in" style="animation-delay:.5s">📖 ${wall.erklaerung}</div>`}
          </div>
        </div>
      </div>
      <aside class="q-side">
        ${!reveal && (wall.deadline ? html`<${TimerRing} deadline=${wall.deadline} total=${wall.timerMs} size=${170} paused=${view.paused} />` : html`<div class="no-timer">⏱️<small>ohne Timer</small></div>`)}
        ${!reveal && html`<${AnsweredMeter} n=${wall.answered.length} of=${view.players.length} />`}
        ${tension && html`<div class="tension-text">Und die richtige Antwort ist …</div>`}
        ${place === "side" && html`<${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} />`}
      </aside>`
    : html`<div class="q-noWall">
        <h1 class="rise-in">${s.title || ""}</h1>
        ${sum && html`<div class="q-meta center">${sum}</div>`}
        ${R && revealed && R.richtigText && html`<div class="richtig-banner"><${Burst} /><span>✔ Richtig:</span> <b>${R.richtigText}</b></div>`}
        <${Extra} extra=${extra} scene=${s} view=${view} revealed=${revealed} full=${true} />
      </div>`}
    ${bigWin && html`<${Confetti} burst=${1} count=${120} colors=${GOLD} />`}
  </div>`;
}

/** Answer counter with a pip per player (pops when someone locks in). */
function AnsweredMeter({ n, of }) {
  return html`<div class=${cx("answered-count", n >= of && of > 0 && "full")}>
    <div><b key=${n}>${n}</b><span>/ ${of} eingeloggt</span></div>
    <div class="pips">${Array.from({ length: of }, (_, i) => html`<i class=${i < n ? "on" : ""}></i>`)}</div>
  </div>`;
}

/** Red vignette + heartbeat in the last five seconds. Only this tiny node re-renders. */
function Urgency({ deadline, paused }) {
  const now = useNow(250, !paused);
  const remain = deadline - now;
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

function Options({ wall, reveal, t, plan, pm }) {
  const revealed = reveal && t >= REVEAL_BEAT.slam;
  const votes = reveal && t >= REVEAL_BEAT.votes;
  const pickers = {};
  for (const [pid, idx] of Object.entries(wall.answersByPlayer || {})) (pickers[idx] = pickers[idx] || []).push(pid);
  const n = wall.options.length;
  const total = Math.max(1, wall.options.reduce((a, o) => a + (o.count != null ? o.count : (pickers[o.id] || []).length), 0));
  return html`<div class=${cx("options", n > 4 && "many", n === 2 && "two")}>${wall.options.map((o, i) => {
    const st = OPTION_STYLE[i % 8];
    const correct = revealed && wall.correctIndex === o.id;
    const wrong = revealed && wall.correctIndex != null && wall.correctIndex !== o.id;
    const out = reveal && !revealed && plan[o.id] != null && t >= plan[o.id];
    const who = pickers[o.id] || [];
    const count = o.count != null ? o.count : who.length;
    return html`<div class=${cx("opt", o.removed && "removed", correct && "correct", wrong && "wrong", out && "out", votes && "votes")} key=${o.id}
        style=${`--c:${st.c};--d:${st.d};--v:${count / total};animation-delay:${0.25 + i * 0.12}s`}>
      <span class="opt-fill"><i class="opt-bar"></i><i class="opt-shine"></i></span>
      <span class="opt-badge"><b>${st.l}</b><i>${st.e}</i></span>
      <span class="opt-text">${o.text}</span>
      ${votes && who.length > 0 && html`<span class="opt-who">${who.slice(0, 6).map((pid, k) => pm[pid] && html`<span class="who-pop" style=${`animation-delay:${k * 90}ms`}><${Monkey} wire=${pm[pid].avatar} anim="none" face=${correct ? "jubel" : wrong ? "frust" : "neutral"} size=${38} /></span>`)}</span>`}
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
  return html`<div class=${cx("standings", st >= 3 && "settled")}>
    <div class="stand-head">
      <h1 class="rise-in">${s.halbzeit ? "⏸ Halbzeit!" : "Zwischenstand"}</h1>
      <span class="chip rise-in" style="animation-delay:.1s">nach Runde ${s.rundenNummer} von ${s.rundenGesamt}</span>
      ${newLeader && st >= 3 && html`<span class="chip gold lead-chip">👑 Neue Spitze: ${entries[0].player.name}</span>`}
      ${s.deadline && html`<${TimerRing} deadline=${s.deadline} size=${80} stroke=${7} />`}
    </div>
    <ol class="stand-list" ref=${listRef}>${entries.map((e, i) => {
      const p = e.player;
      const g = gain(e);
      const old = e.platzVorher || i + 1;
      const move = old - (i + 1);
      const shownRank = st >= 3 ? i : old - 1;
      const bal = st >= 2 ? p.balance : p.balance - g;
      return html`<li class="stand-slot" data-flip=${p.id} key=${p.id}>
        <div class=${cx("stand-row", i === 0 && st >= 3 && "first", i === 0 && newLeader && st >= 3 && "new-leader", move > 0 && st >= 3 && "climbed")} style=${`animation-delay:${(entries.length - old) * 0.1}s`}>
          <span class="stand-rank" key=${shownRank}>${shownRank < 3 ? ["🥇", "🥈", "🥉"][shownRank] : shownRank + 1}</span>
          <${Monkey} wire=${p.avatar} anim=${st >= 3 && i === 0 ? "jubel" : st >= 3 && g < 0 ? "frust" : "idle"} face=${st >= 3 && i === 0 ? "jubel" : st >= 3 && g < 0 ? "frust" : "neutral"} size=${64} />
          <span class="stand-name">${p.name}${p.streak >= 3 ? html` <small class="stand-streak">🔥${p.streak}</small>` : ""}
            ${st >= 3 && move !== 0 && html`<span class=${cx("rank-move", move > 0 ? "up" : "down")}>${move > 0 ? "↑" : "↓"}${Math.abs(move)}</span>`}
          </span>
          <div class="stand-bar"><i style=${`width:${st >= 1 ? Math.max(3, (Math.max(0, bal) / max) * 100) : 0}%`}></i></div>
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
  return html`<div class=${cx("wheel-scene", landed && "landed")}>
    <div class="wheel-wrap">
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
      ${!landed ? html`<h1>Glücksrad!</h1><p class="muted">${spinning ? "Es dreht sich …" : "Gleich wird gedreht …"}</p>`
      : html`<div class=${cx("wheel-result card pop-in", "k-" + result.klasse)}>
          <div class="wr-emoji">${result.emoji}</div>
          <h2>${result.name}</h2>
          <p>${w.erklaerung || result.wirkung}</p>
          ${w.betroffene.length > 0 && html`<div class="wr-who">${w.betroffene.map(id => pm[id] && html`<span><${Monkey} wire=${pm[id].avatar} face="denk" anim="idle" size=${60} /><b>${pm[id].name}</b></span>`)}</div>`}
          ${w.interactionEndsAt && html`<div class="wr-timer">⏳ <${Countdown} deadline=${w.interactionEndsAt} /> s — auf den Handys!</div>`}
        </div>`}
    </div>
  </div>`;
}

// ---------- pause ----------
function Pause({ view, s }) {
  return html`<div class="pause-scene">
    <div class="pause-card card pop-in">
      <div class="pause-emoji">${(s.text || "").startsWith("💾") ? "💾" : "🍌"}</div>
      <h1>${(s.text || "Pause").replace(/^💾\s*/, "").replace(/\s*—\s*weiter mit ▶$/i, "")}</h1>
      ${s.endsAt ? html`<p class="pause-count">Weiter in <${Countdown} deadline=${s.endsAt} /> s</p>` : html`<p class="pause-hint">Weiter mit <b>▶ Weiter</b> oben rechts oder Leertaste</p>`}
    </div>
    <ol class="mini-stand">${(s.standings || []).map((e, i) => html`<li><span>${i + 1}.</span><${Monkey} wire=${e.player.avatar} anim="idle" size=${48} delay=${i * 200} /><b>${e.player.name}</b><${Money} value=${e.player.balance} /></li>`)}</ol>
  </div>`;
}

// ---------- highlights ----------
function Highlights({ view, s }) {
  const pm = playerMap(view);
  return html`<div class="highlights">
    <h1 class="rise-in">✨ Die Highlights der Show</h1>
    <div class="hl-list">${s.entries.map((e, i) => html`<div class="hl card" style=${`animation-delay:${0.3 + i * 0.7}s;--i:${i}`}>
      <span class="hl-emoji">${e.emoji}</span>
      <p>${e.text}</p>
      ${e.playerId && pm[e.playerId] && html`<${Monkey} wire=${pm[e.playerId].avatar} face="jubel" anim="jubel" size=${90} delay=${i * 150} />`}
    </div>`)}</div>
  </div>`;
}

// ---------- ceremony ----------
function Ceremony({ view, s }) {
  const since = useRef(serverNow()).current;
  const now = useNow(100);
  const t = now - since;
  const drum = CEREMONY_ROLL_MS + CEREMONY_SILENCE_MS;
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
          <${Monkey} wire=${e.player.avatar} face="jubel" anim=${e.platz === 1 ? "jubel" : "dance"} size=${e.platz === 1 ? 190 : 150} />
          <b class="cer-name">${e.player.name}</b>
          <span class="cer-mm">${fmtMM(e.mm)}</span>
          ${e.at > 0 && html`<small class="cer-at">+${fmtNum(e.at)} AT</small>`}
        </div>
        <div class="cer-block"><span>${e.platz}</span></div>
      </div>`;
    })}</div>
    ${stage >= 3 && html`
      ${rest.length > 0 && html`<div class="cer-rest">${rest.map(e => html`<span class="chip">${e.platz}. ${e.player.name} · ${fmtMM(e.mm)}</span>`)}</div>`}
      <div class="awards">${s.awards.map((a, i) => html`<div class="award card" style=${`animation-delay:${i * 0.25}s`}>
        <span class="aw-emoji">${a.emoji}</span><div><b>${a.titel}</b><small>${(pm[a.playerId] || {}).name || ""} · ${a.detail}</small></div></div>`)}</div>
      <${Confetti} burst=${1} count=${260} />`}
  </div>`;
}

function Credits({ view, s }) {
  const host = StageCtx.host || {};
  return html`<div class="credits">
    <div class="credits-roll">
      <h1>Danke fürs Mitspielen! 🐒</h1>
      <div class="credits-podium">${s.podium.map((e, i) => html`<div class="cp rise-in" style=${`animation-delay:${i * 0.15}s`}>
        <span class="cp-rank">${i < 3 ? ["🥇", "🥈", "🥉"][i] : i + 1 + "."}</span>
        <${Monkey} wire=${e.player.avatar} face=${i === 0 ? "jubel" : "neutral"} anim=${i === 0 ? "dance" : "idle"} size=${72} delay=${i * 180} />
        <b>${e.player.name}</b><span>${fmtMM(e.mm)}</span></div>`)}</div>
      <p class="muted">Feedback geht auf den Handys · Revanche mit denselben Affen?</p>
      <div class="menu-row center">
        <button class="btn big" onClick=${() => StageCtx.cmd({ revanche: {} })}>🔁 Revanche!</button>
        <button class="btn ghost" onClick=${() => fetch("/api/host/close", { method: "POST" }).then(() => StageCtx.refreshHost())}>🏠 Hauptmenü</button>
      </div>
    </div>
  </div>`;
}
