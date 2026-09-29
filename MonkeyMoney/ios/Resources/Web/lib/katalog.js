// Monkey Money — shared question catalogue (GM cockpit + stage settings).
// Filter panel (tiers, types, category tree) and a question browser with bans.
//   <Katalog katalog settings onPatch [onBan] [pin] [compact] [wide] [only] [onPick] [pickLabel] [local] />
// `settings` holds kategorienAus/schwierigkeitenAus/typenAus/fragenAus (the
// server echo); toggles are shown optimistically until the echo arrives.
import { html, useState, useEffect, useRef, useMemo } from "../vendor/preact-htm.js";
import { cx, fmtNum, haptic } from "./core.js";

export const TIERS = ["easy", "medium", "hard", "ultrahard"];
export const TIER_META = {
  easy: { emoji: "🍌", name: "Leicht", c: "#2bd98a" },
  medium: { emoji: "🥥", name: "Mittel", c: "#ffc93c" },
  hard: { emoji: "🌶️", name: "Schwer", c: "#ff8a3d" },
  ultrahard: { emoji: "💀", name: "ULTRAHARD", c: "#ff4d6d" },
};
export const TYPE_META = {
  choice: { emoji: "🔤", name: "Auswahl" }, wahr_falsch: { emoji: "⚖️", name: "Wahr/Falsch" }, emoji: { emoji: "😜", name: "Emoji" },
  bild_pixel: { emoji: "🖼️", name: "Pixelbild" }, mehrfach: { emoji: "☑️", name: "Mehrfach" }, schaetz: { emoji: "🎯", name: "Schätzen" }, sortier: { emoji: "↕️", name: "Sortieren" },
};
const KEYS = ["kategorienAus", "schwierigkeitenAus", "typenAus", "fragenAus"];

// ---------- filter state helpers ----------
/** The four filter lists of a settings object (always arrays). */
export function filterOf(s) {
  const o = {};
  for (const k of KEYS) o[k] = [...((s && s[k]) || [])];
  return o;
}
const same = (a, b) => KEYS.every(k => a[k].length === b[k].length && [...a[k]].sort().join("|") === [...b[k]].sort().join("|"));

/** Apply a settings patch to a filter object — mirrors MatchSettings.apply(patch:). */
export function applyFilterPatch(f, p) {
  const n = filterOf(f);
  if (p.filterReset) KEYS.forEach(k => (n[k] = []));
  if (Array.isArray(p.kategorienAus)) n.kategorienAus = [...p.kategorienAus];
  if (Array.isArray(p.schwierigkeitenAus) && p.schwierigkeitenAus.length < TIERS.length) n.schwierigkeitenAus = [...p.schwierigkeitenAus];
  if (Array.isArray(p.typenAus)) n.typenAus = [...p.typenAus];
  if (Array.isArray(p.fragenAus)) n.fragenAus = [...p.fragenAus];
  if (p.kategorieAus && !n.kategorienAus.includes(p.kategorieAus)) n.kategorienAus.push(p.kategorieAus);
  if (p.kategorieAn) n.kategorienAus = n.kategorienAus.filter(x => x !== p.kategorieAn);
  return n;
}

/** The filter the server used when it computed `katalog` (from its aus flags). */
function baseFilter(k) {
  const kat = [];
  for (const c of k.kategorien || []) { if (c.aus) kat.push(c.id); for (const u of c.unter || []) if (u.aus) kat.push(u.id); }
  return { kategorienAus: kat, schwierigkeitenAus: (k.schwierigkeiten || []).filter(t => t.aus).map(t => t.id), typenAus: (k.typen || []).filter(t => t.aus).map(t => t.id), fragenAus: new Array(k.fragenAus || 0).fill("?") };
}

/** Rough client-side estimate of active questions under filter `f` (only used as a delta on the server numbers). */
function estimator(k, f) {
  const katAus = new Set(f.kategorienAus), schwAus = new Set(f.schwierigkeitenAus), typAus = new Set(f.typenAus);
  const types = k.typen || [];
  const all = types.reduce((a, t) => a + t.anzahl, 0) || 1;
  const typeFrac = types.reduce((a, t) => a + (typAus.has(t.id) ? 0 : t.anzahl), 0) / all;
  const sum = (c, tier) => { const ps = c.proSchwierigkeit || {}; return tier ? (schwAus.has(tier) ? 0 : ps[tier] || 0) : TIERS.reduce((a, d) => a + (schwAus.has(d) ? 0 : ps[d] || 0), 0); };
  const sub = (u, parentOff, tier) => (parentOff || katAus.has(u.id) || !u.gewaehlt ? 0 : sum(u, tier) * typeFrac);
  const cat = (c, tier) => {
    if (katAus.has(c.id)) return 0;
    const subs = c.unter || [];
    if (!c.gewaehlt) return subs.reduce((a, u) => a + sub(u, false, tier), 0);
    let n = sum(c, tier);
    for (const u of subs) if (katAus.has(u.id)) n -= sum(u, tier);
    return Math.max(0, n) * typeFrac;
  };
  const total = tier => (k.kategorien || []).reduce((a, c) => a + cat(c, tier), 0);
  return { cat, sub, total, typAus, schwAus, katAus };
}

/** Numbers to display under filter `f`: the server's plus the estimated delta. */
function useShown(k, f) {
  return useMemo(() => {
    const base = baseFilter(k);
    const e0 = estimator(k, base), e1 = estimator(k, f);
    const clamp = (v, max) => Math.max(0, Math.min(max, Math.round(v)));
    const dirty = !same(base, { ...f, fragenAus: new Array(f.fragenAus.length).fill("?") });
    const bans = f.fragenAus.length - (k.fragenAus || 0);
    const cats = {};
    for (const c of k.kategorien || []) {
      const off = e1.katAus.has(c.id);
      cats[c.id] = dirty ? clamp(c.aktiv + e1.cat(c) - e0.cat(c), c.anzahl) : c.aktiv;
      for (const u of c.unter || []) cats[u.id] = dirty ? clamp(u.aktiv + e1.sub(u, off) - e0.sub(u, e0.katAus.has(c.id)), u.anzahl) : u.aktiv;
    }
    const tiers = {};
    for (const t of k.schwierigkeiten || []) tiers[t.id] = dirty ? clamp(t.aktiv + e1.total(t.id) - e0.total(t.id), t.anzahl) : t.aktiv;
    const aktiv = dirty || bans ? clamp(k.aktiv + e1.total() - e0.total() - Math.max(0, bans), k.gesamt) : k.aktiv;
    return { cats, tiers, aktiv, estimated: dirty || bans !== 0 };
  }, [k, f]);
}

/** Summary stats (for "7.832 von 11.834 Fragen aktiv · 2 Stufen aus"). */
export function katalogStats(k, settings) {
  if (!k) return null;
  const f = settings ? filterOf(settings) : baseFilter(k);
  const base = baseFilter(k);
  const e0 = estimator(k, base), e1 = estimator(k, f);
  const est = !same(base, { ...f, fragenAus: new Array(f.fragenAus.length).fill("?") }) || f.fragenAus.length !== (k.fragenAus || 0);
  const aktiv = est ? Math.max(0, Math.round(k.aktiv + e1.total() - e0.total() - (f.fragenAus.length - (k.fragenAus || 0)))) : k.aktiv;
  return { aktiv, gesamt: k.gesamt, stufenAus: f.schwierigkeitenAus.length, typenAus: f.typenAus.length, katAus: f.kategorienAus.length, gebannt: f.fragenAus.length, estimated: est };
}
export function katalogSummary(k, settings) {
  const s = katalogStats(k, settings);
  if (!s) return "";
  const parts = [`${s.estimated ? "≈ " : ""}${fmtNum(s.aktiv)} von ${fmtNum(s.gesamt)} Fragen aktiv`];
  if (s.stufenAus) parts.push(`${s.stufenAus} ${s.stufenAus === 1 ? "Stufe" : "Stufen"} aus`);
  if (s.typenAus) parts.push(`${s.typenAus} ${s.typenAus === 1 ? "Typ" : "Typen"} aus`);
  if (s.katAus) parts.push(`${s.katAus} ${s.katAus === 1 ? "Kategorie" : "Kategorien"} aus`);
  if (s.gebannt) parts.push(`${s.gebannt} gebannt`);
  return parts.join(" · ");
}

const EMPTY = { gesamt: 0, aktiv: 0, fragenAus: 0, kategorien: [], schwierigkeiten: [], typen: [] };
const norm = s => String(s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");

// ---------- main component ----------
export function Katalog({ katalog, settings, onPatch, onBan, pin, compact, wide, only, onPick, pickLabel, local, initialFilter }) {
  const server = useMemo(() => filterOf(settings || baseFilter(katalog || {})), [settings]);
  const [pend, setPend] = useState(null); // {f, at}
  const [tab, setTab] = useState(only || "filter");
  const [warn, setWarn] = useState(null);
  const f = pend ? pend.f : server;
  // Drop the optimistic layer once the server agrees (or after 5 s without echo).
  useEffect(() => { if (pend && same(pend.f, server)) setPend(null); }, [server]);
  useEffect(() => {
    if (!pend) return;
    const t = setTimeout(() => { setPend(null); if (!local) setWarn("⚠️ Keine Bestätigung vom Server — Stand zurückgesetzt."); }, 5000);
    return () => clearTimeout(t);
  }, [pend]);
  useEffect(() => { if (!warn) return; const t = setTimeout(() => setWarn(null), 3500); return () => clearTimeout(t); }, [warn]);

  const patch = p => {
    const n = applyFilterPatch(f, p);
    if (same(n, f) && !p.filterReset) return;
    setPend({ f: n, at: Date.now() });
    haptic();
    onPatch && onPatch(p);
  };
  const ban = (id, on) => {
    const list = on ? [...new Set([...f.fragenAus, id])] : f.fragenAus.filter(x => x !== id);
    setPend({ f: { ...f, fragenAus: list }, at: Date.now() });
    haptic();
    if (onBan) onBan(id, on); else onPatch && onPatch({ fragenAus: list });
  };
  const shown = useShown(katalog || EMPTY, f);
  if (!katalog) return html`<div class="kt"><p class="kt-empty">Katalog wird geladen …</p></div>`;

  const anyFilter = KEYS.some(k => f[k].length);
  const pct = katalog.gesamt ? Math.round((shown.aktiv / katalog.gesamt) * 100) : 0;
  const showFilter = only !== "browse";
  const showBrowse = only !== "filter";
  const both = wide && showFilter && showBrowse;
  return html`<div class=${cx("kt", compact && "kt-compact", wide && "kt-wide", pend && "kt-pending")}>
    ${only !== "browse" && html`<header class="kt-sum">
      <div class="kt-sum-n">
        <b class=${cx(shown.aktiv === 0 && "zero")}>${shown.estimated ? "≈ " : ""}${fmtNum(shown.aktiv)}</b>
        <span>von ${fmtNum(katalog.gesamt)} Fragen aktiv</span>
      </div>
      <div class="kt-meter"><i style=${`width:${pct}%`}></i></div>
      <div class="kt-sum-row">
        <small>${katalogSummary(katalog, f).split(" · ").slice(1).join(" · ") || "Alle Fragen im Spiel"}</small>
        ${anyFilter && html`<button class="kt-link" onClick=${() => patch({ filterReset: true })}>↺ Filter zurücksetzen</button>`}
      </div>
      ${shown.aktiv === 0 && html`<p class="kt-warn">Keine Fragen mehr aktiv — schalte etwas wieder an.</p>`}
    </header>`}
    ${warn && html`<p class="kt-warn">${warn}</p>`}
    ${showFilter && showBrowse && !wide && html`<nav class="kt-tabs">
      <button class=${cx(tab === "filter" && "on")} onClick=${() => setTab("filter")}>🎚️ Filter</button>
      <button class=${cx(tab === "browse" && "on")} onClick=${() => setTab("browse")}>🔎 Fragen durchsuchen</button>
    </nav>`}
    <div class=${cx("kt-body", both && "kt-cols")}>
      ${showFilter && (both || tab === "filter") && html`<${Filters} k=${katalog} f=${f} shown=${shown} patch=${patch} />`}
      ${showBrowse && (both || tab === "browse" || only === "browse") && html`<${Browser} k=${katalog} f=${f} pin=${pin} ban=${ban} onPick=${onPick} pickLabel=${pickLabel} local=${local} initial=${initialFilter} />`}
    </div>
  </div>`;
}

// ---------- filters ----------
function Filters({ k, f, shown, patch }) {
  const [q, setQ] = useState("");
  const [open, setOpen] = useState({});
  const katAus = new Set(f.kategorienAus), schwAus = new Set(f.schwierigkeitenAus), typAus = new Set(f.typenAus);
  const toggleTier = id => {
    const n = schwAus.has(id) ? f.schwierigkeitenAus.filter(x => x !== id) : [...f.schwierigkeitenAus, id];
    if (n.length >= TIERS.length) return;
    patch({ schwierigkeitenAus: n });
  };
  const toggleType = id => patch({ typenAus: typAus.has(id) ? f.typenAus.filter(x => x !== id) : [...f.typenAus, id] });
  const toggleKat = id => patch(katAus.has(id) ? { kategorieAn: id } : { kategorieAus: id });
  const setMany = (ids, off) => { const n = new Set(f.kategorienAus); ids.forEach(id => (off ? n.add(id) : n.delete(id))); patch({ kategorienAus: [...n] }); };
  const allTop = k.kategorien.map(c => c.id);
  const solo = c => { const mine = new Set([c.id, ...(c.unter || []).map(u => u.id)]); const n = new Set(f.kategorienAus.filter(id => !mine.has(id))); allTop.forEach(id => id !== c.id && n.add(id)); patch({ kategorienAus: [...n] }); };
  const allIds = k.kategorien.flatMap(c => [c.id, ...(c.unter || []).map(u => u.id)]);
  const needle = norm(q.trim());
  const cats = k.kategorien.map(c => {
    if (!needle) return { c, subs: c.unter || [], hit: false };
    const selfHit = norm(c.name).includes(needle);
    const subs = (c.unter || []).filter(u => selfHit || norm(u.name).includes(needle));
    return selfHit || subs.length ? { c, subs, hit: subs.length > 0 && !selfHit } : null;
  }).filter(Boolean);
  const tierLast = TIERS.length - f.schwierigkeitenAus.length === 1;
  return html`<section class="kt-filters">
    <div class="kt-group">
      <h4>Schwierigkeit</h4>
      <div class="kt-chips">${k.schwierigkeiten.map(t => { const m = TIER_META[t.id] || {}; const on = !schwAus.has(t.id);
        return html`<button data-id=${t.id} class=${cx("kt-chip tier", on && "on", on && tierLast && "last")} style=${`--c:${m.c}`} aria-pressed=${on} title=${on && tierLast ? "Mindestens eine Stufe bleibt an" : ""} onClick=${() => toggleTier(t.id)}>
          <span class="e">${t.emoji || m.emoji}</span><span class="l"><b>${t.name}</b><small>${fmtNum(on ? shown.tiers[t.id] ?? t.aktiv : 0)} / ${fmtNum(t.anzahl)}</small></span></button>`; })}</div>
    </div>
    <div class="kt-group">
      <h4>Fragetypen</h4>
      <div class="kt-chips">${k.typen.map(t => { const m = TYPE_META[t.id] || { emoji: "❔" }; const on = !typAus.has(t.id);
        return html`<button data-id=${t.id} class=${cx("kt-chip", on && "on")} aria-pressed=${on} onClick=${() => toggleType(t.id)}><span class="e">${m.emoji}</span><span class="l"><b>${t.name}</b><small>${fmtNum(t.anzahl)}</small></span></button>`; })}</div>
    </div>
    <div class="kt-group">
      <div class="kt-group-head"><h4>Kategorien</h4>
        <span class="kt-mini-btns"><button class="kt-link" onClick=${() => setMany(allIds, false)}>Alle an</button><button class="kt-link" onClick=${() => setMany(allTop, true)}>Alle aus</button></span></div>
      <label class="kt-search"><span>🔎</span><input type="search" placeholder="Kategorie suchen …" value=${q} onInput=${e => setQ(e.target.value)} />${q && html`<button class="kt-x" onClick=${() => setQ("")}>×</button>`}</label>
      <div class="kt-tree">${cats.map(({ c, subs, hit }) => {
        const off = katAus.has(c.id);
        const isOpen = open[c.id] || hit;
        const subsOff = (c.unter || []).filter(u => katAus.has(u.id)).length;
        return html`<div class=${cx("kt-cat", off && "off", isOpen && "open", !c.gewaehlt && "nopool")} style=${`--c:${c.farbe || "#ffc93c"}`} key=${c.id} data-id=${c.id}>
          <div class="kt-row">
            <button class="kt-row-main" onClick=${() => setOpen({ ...open, [c.id]: !open[c.id] })} aria-expanded=${!!isOpen}>
              <span class="kt-emo">${c.emoji}</span>
              <span class="kt-name"><b>${c.name}</b>
                <small>${fmtNum(off ? 0 : shown.cats[c.id])} / ${fmtNum(c.anzahl)}${(c.unter || []).length ? ` · ${c.unter.length} Themen` : ""}${subsOff && !off ? ` · ${subsOff} aus` : ""}${!c.gewaehlt ? " · nicht im Set" : ""}</small>
                <${Bars} ps=${c.proSchwierigkeit} n=${c.anzahl} schwAus=${schwAus} />
              </span>
              ${(c.unter || []).length > 0 && html`<span class=${cx("kt-chev", isOpen && "up")}></span>`}
            </button>
            <${Switch} on=${!off} label=${c.name} onClick=${() => toggleKat(c.id)} />
          </div>
          ${isOpen && subs.length > 0 && html`<div class="kt-subs">
            <div class="kt-subs-head"><small>${off ? "Kategorie ist aus — Themen ruhen" : "Themen"}</small>
              <span class="kt-mini-btns"><button class="kt-link" onClick=${() => setMany([c.id, ...c.unter.map(u => u.id)], false)}>Alle an</button><button class="kt-link" onClick=${() => setMany(c.unter.map(u => u.id), true)}>Alle aus</button><button class="kt-link" onClick=${() => solo(c)}>Nur diese</button></span></div>
            ${subs.map(u => { const uo = katAus.has(u.id);
              return html`<div class=${cx("kt-row sub", uo && "off", off && "ghost", !u.gewaehlt && "nopool")} key=${u.id}>
                <span class="kt-name"><b>${u.name}</b><small>${fmtNum(off || uo ? 0 : shown.cats[u.id])} / ${fmtNum(u.anzahl)}</small><${Bars} ps=${u.proSchwierigkeit} n=${u.anzahl} schwAus=${schwAus} /></span>
                <${Switch} on=${!uo} dim=${off} label=${u.name} onClick=${() => toggleKat(u.id)} />
              </div>`; })}
          </div>`}
        </div>`; })}
        ${cats.length === 0 && html`<p class="kt-empty">Keine Kategorie passt zu „${q}“.</p>`}
      </div>
    </div>
  </section>`;
}

function Switch({ on, dim, label, onClick }) {
  return html`<button class=${cx("kt-sw", on && "on", dim && "dim")} role="switch" aria-checked=${on} aria-label=${label} onClick=${e => { e.stopPropagation(); onClick(); }}><i></i></button>`;
}

function Bars({ ps, n, schwAus }) {
  if (!ps || !n) return null;
  return html`<span class="kt-bars">${TIERS.map(d => ps[d] ? html`<i class=${cx(schwAus.has(d) && "off")} style=${`flex:${ps[d]};--c:${TIER_META[d].c}`} title=${`${TIER_META[d].name}: ${ps[d]}`}></i>` : null)}</span>`;
}

// ---------- question browser ----------
const PAGE = 40;
function Browser({ k, f, pin, ban, onPick, pickLabel, local, initial }) {
  const [kat, setKat] = useState((initial && initial.kat) || "");
  const [sub, setSub] = useState((initial && initial.sub) || "");
  const [schw, setSchw] = useState((initial && initial.schw) || "");
  const [typ, setTyp] = useState((initial && initial.typ) || "");
  const [q, setQ] = useState("");
  const [qd, setQd] = useState("");
  const [nurAus, setNurAus] = useState(false);
  const [res, setRes] = useState({ items: [], gesamt: 0, loading: true, err: null, done: false });
  const [open, setOpen] = useState(null);
  const seq = useRef(0);
  const sentinel = useRef(null);
  useEffect(() => { const t = setTimeout(() => setQd(q.trim()), 300); return () => clearTimeout(t); }, [q]);
  const load = async (offset, append) => {
    const my = ++seq.current;
    setRes(r => ({ ...r, loading: true, err: null, items: append ? r.items : [] }));
    const u = new URLSearchParams({ offset, limit: PAGE });
    if (kat) u.set("kat", kat);
    if (sub) u.set("sub", sub);
    if (schw) u.set("schw", schw);
    if (typ) u.set("typ", typ);
    if (qd) u.set("q", qd);
    if (nurAus && !local) u.set("nurAus", "1");
    if (pin) u.set("pin", pin);
    try {
      const r = await fetch("/api/fragen?" + u);
      if (!r.ok) throw new Error(r.status === 403 ? "Kein Zugriff (PIN)" : await r.text());
      const d = await r.json();
      if (my !== seq.current) return;
      setRes(prev => { const items = append ? [...prev.items, ...d.fragen] : d.fragen; return { items, gesamt: d.gesamt, loading: false, err: null, done: items.length >= d.gesamt || d.fragen.length === 0 }; });
    } catch (e) {
      if (my === seq.current) setRes(r => ({ ...r, loading: false, err: e.message || "Fehler" }));
    }
  };
  useEffect(() => { load(0, false); }, [kat, sub, schw, typ, qd, nurAus]);
  // Infinite scroll: load the next page when the sentinel scrolls into view.
  useEffect(() => {
    const el = sentinel.current;
    if (!el || !("IntersectionObserver" in window)) return;
    const io = new IntersectionObserver(es => { if (es.some(e => e.isIntersecting) && !res.loading && !res.done && !res.err) load(res.items.length, true); }, { rootMargin: "300px" });
    io.observe(el);
    return () => io.disconnect();
  }, [res, sentinel.current]);

  const katAus = new Set(f.kategorienAus), schwAus = new Set(f.schwierigkeitenAus), typAus = new Set(f.typenAus), banned = new Set(f.fragenAus);
  const poolOut = x => { const c = k.kategorien.find(c => c.id === x.kat); if (!c) return false; const u = (c.unter || []).find(u => u.id === x.sub); return !(c.gewaehlt || (u && u.gewaehlt)); };
  const filtered = x => katAus.has(x.kat) || katAus.has(x.sub) || schwAus.has(x.schw) || typAus.has(x.typ) || (!local && poolOut(x));
  const top = k.kategorien.find(c => c.id === kat);
  let items = res.items;
  if (nurAus && local) items = items.filter(x => filtered(x) || banned.has(x.id));
  if (onPick && !nurAus) items = items.filter(x => !banned.has(x.id));
  return html`<section class="kt-browser">
    <div class="kt-bfilters">
      <label class="kt-search"><span>🔎</span><input type="search" placeholder="Fragen & Antworten durchsuchen …" value=${q} onInput=${e => setQ(e.target.value)} />${q && html`<button class="kt-x" onClick=${() => setQ("")}>×</button>`}</label>
      <div class="kt-selects">
        <select value=${kat} onChange=${e => { setKat(e.target.value); setSub(""); }}><option value="">Alle Kategorien</option>${k.kategorien.map(c => html`<option value=${c.id}>${c.emoji} ${c.name}</option>`)}</select>
        ${top && (top.unter || []).length > 0 && html`<select value=${sub} onChange=${e => setSub(e.target.value)}><option value="">Alle Themen</option>${top.unter.map(u => html`<option value=${u.id}>${u.name}</option>`)}</select>`}
        <select value=${typ} onChange=${e => setTyp(e.target.value)}><option value="">Alle Typen</option>${k.typen.map(t => html`<option value=${t.id}>${(TYPE_META[t.id] || {}).emoji || ""} ${t.name}</option>`)}</select>
      </div>
      <div class="kt-chips tight">
        <button class=${cx("kt-chip sm", !schw && "on")} onClick=${() => setSchw("")}>Alle Stufen</button>
        ${TIERS.map(d => html`<button class=${cx("kt-chip sm tier", schw === d && "on")} style=${`--c:${TIER_META[d].c}`} onClick=${() => setSchw(schw === d ? "" : d)}>${TIER_META[d].emoji} ${TIER_META[d].name}</button>`)}
        <button class=${cx("kt-chip sm red", nurAus && "on")} onClick=${() => setNurAus(!nurAus)}>🚫 Nur ausgeschlossene</button>
      </div>
    </div>
    <p class="kt-count">${res.err ? html`<span class="kt-err">⚠️ ${res.err}</span>` : res.loading && !res.items.length ? "Lade …" : `${fmtNum(nurAus && local ? items.length : res.gesamt)} Fragen`}</p>
    <div class="kt-qlist">
      ${items.map(x => { const isBan = banned.has(x.id); const isOut = filtered(x); const isOpen = open === x.id; const tm = TIER_META[x.schw] || {}; const ty = TYPE_META[x.typ] || { emoji: "❔", name: x.typ };
        return html`<article class=${cx("kt-q", isBan && "banned", isOut && "out", isOpen && "open")} key=${x.id} data-id=${x.id} style=${`--c:${tm.c || "#fff"}`}>
          <div class="kt-q-top">
            <button class="kt-q-head" onClick=${() => setOpen(isOpen ? null : x.id)} aria-expanded=${isOpen}>
              <span class="kt-q-meta"><span class="kt-tag tier">${tm.emoji} ${tm.name}</span><span class="kt-tag">${ty.emoji} ${ty.name}</span><span class="kt-path">${x.pfad}</span>
                ${isBan ? html`<span class="kt-tag red">gebannt</span>` : isOut ? html`<span class="kt-tag dim">gefiltert</span>` : null}</span>
              <span class="kt-q-text">${x.text}</span>
            </button>
            <button class=${cx("kt-ban", isBan && "on")} title=${isBan ? "Wieder zulassen" : "Frage bannen"} aria-label=${isBan ? "Wieder zulassen" : "Frage bannen"} onClick=${() => ban(x.id, !isBan)}>${isBan ? "↩️" : "🚫"}</button>
          </div>
          ${isOpen && html`<div class="kt-q-body">
            <${Answers} x=${x} />
            ${x.erkl && html`<p class="kt-erkl">💡 ${x.erkl}</p>`}
            <div class="kt-q-actions">
              <button class=${cx("kt-btn", isBan ? "green" : "red")} onClick=${() => ban(x.id, !isBan)}>${isBan ? "✅ Wieder zulassen" : "🚫 Frage bannen"}</button>
              ${onPick && !isBan && html`<button class="kt-btn gold" onClick=${() => onPick(x)}>${pickLabel || "🎯 Diese Frage nehmen"}</button>`}
            </div>
            <small class="kt-id">${x.id} · ${x.alter}</small>
          </div>`}
          ${!isOpen && onPick && !isBan && html`<button class="kt-pick" onClick=${() => onPick(x)}>${pickLabel || "🎯 Nehmen"}</button>`}
        </article>`; })}
      ${!res.loading && !res.err && items.length === 0 && html`<p class="kt-empty">Keine Fragen gefunden.</p>`}
      <div ref=${sentinel} class="kt-sentinel"></div>
      ${!res.done && res.items.length > 0 && html`<button class="kt-more" disabled=${res.loading} onClick=${() => load(res.items.length, true)}>${res.loading ? "Lade …" : `Mehr laden (${fmtNum(res.items.length)} von ${fmtNum(res.gesamt)})`}</button>`}
    </div>
  </section>`;
}

/** Answers with the correct one(s) marked; sortier shows the right order, schaetz the value. */
export function Answers({ x }) {
  const korrekt = String(x.korrekt || "");
  const list = x.antworten || [];
  if (x.typ === "sortier") {
    const order = korrekt.split(/\s*→\s*/);
    return html`<ol class="kt-ans sort">${order.map(a => html`<li class="ok">${a}</li>`)}</ol>`;
  }
  if (!list.length) return html`<p class="kt-korrekt">✔ ${korrekt}</p>`;
  const tokens = new Set(korrekt.split(/\s*(?:,|;|·|\+| und )\s*/).map(norm));
  const ok = a => a === korrekt || norm(a) === norm(korrekt) || (x.typ === "mehrfach" && tokens.has(norm(a)));
  const any = list.some(ok);
  return html`<ul class="kt-ans">${list.map((a, i) => html`<li class=${cx(ok(a) && "ok")}><span class="kt-l">${String.fromCharCode(65 + i)}</span>${a}${ok(a) ? " ✔" : ""}</li>`)}</ul>
    ${!any && html`<p class="kt-korrekt">✔ ${korrekt}</p>`}`;
}
