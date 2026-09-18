/* Monkey Money — Übungsmodus: solo practice against the iPad's question bank.
   No room, no timer, no money — just questions, explanations and a streak. */
(() => {
  const $ = id => document.getElementById(id);
  const { esc, fmtMM, haptic } = MM;
  const device = MM.deviceToken();
  const EMO = ["🍌", "🥥", "🐒", "🌴", "💎", "🎩", "🌊", "🔥"];
  const SCHW = { easy: "Leicht", medium: "Mittel", hard: "Schwer", ultrahard: "Ultra" };
  let current = null;

  function toast(text) {
    const t = $("toast");
    t.textContent = text; t.classList.add("show");
    clearTimeout(t._h); t._h = setTimeout(() => t.classList.remove("show"), 2200);
  }

  function stats(s) {
    $("sSerie").textContent = s.serie;
    $("sRichtig").textContent = `${s.richtig} / ${s.gespielt}`;
    $("sBeste").textContent = s.beste;
  }

  fetch("/api/kategorien").then(r => r.json()).then(list => {
    for (const k of list) $("kat").appendChild(MM.el(`<option value="${esc(k.id)}">${k.emoji} ${esc(k.name)}</option>`));
  }).catch(() => {});

  async function next() {
    $("nextBtn").classList.add("hidden");
    const q = new URLSearchParams({ device, kat: $("kat").value, schw: $("schw").value, familie: $("familie").checked ? "1" : "0" });
    const r = await fetch(`/api/uebung/frage?${q}`);
    if (!r.ok) { $("main").innerHTML = `<div class="idle"><div class="eye">🙈</div><h2>Keine Frage gefunden</h2><p>Andere Kategorie oder Schwierigkeit wählen.</p></div>`; return; }
    current = await r.json();
    stats(current.stats);
    $("main").innerHTML = `
      <div class="chip" style="margin-bottom:8px">${current.katEmoji} ${esc(current.katName)} · ${SCHW[current.schw] || current.schw} · ${fmtMM(current.wert)}</div>
      <div class="question">${esc(current.text)}</div>
      <div class="options">${current.options.map((o, i) => `<button class="opt" data-i="${i}" style="--d:${i * 60}ms"><span class="letter">${"ABCDEFGH"[i]}</span><span class="emo">${EMO[i % 8]}</span><span>${esc(o)}</span></button>`).join("")}</div>
      <div id="explain"></div>`;
    for (const b of $("main").querySelectorAll(".opt")) b.onclick = () => answer(Number(b.dataset.i));
  }

  async function answer(index) {
    if (!current) return;
    const opts = [...$("main").querySelectorAll(".opt")];
    opts.forEach(o => { o.disabled = true; });
    opts[index].classList.add("chosen");
    const r = await fetch("/api/uebung/antwort", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: current.id, index, device }) });
    if (!r.ok) { toast("Hoppla — Frage war nicht mehr offen."); return next(); }
    const res = await r.json();
    stats(res.stats);
    opts[res.correctIndex].classList.add("correct");
    if (!res.correct) opts[index].classList.add("wrong");
    haptic(res.correct ? "success" : "error");
    const f = $("flash"); f.className = "flash"; requestAnimationFrame(() => { f.className = "flash " + (res.correct ? "richtig" : "falsch"); });
    $("explain").innerHTML = `
      <div class="reveal ${res.correct ? "ok" : "nope"}" style="padding:18px 6px 6px"><div class="stamp">${res.correct ? "RICHTIG!" : "FALSCH!"}</div></div>
      ${res.erkl ? `<div class="explain"><p>${esc(res.erkl)}</p></div>` : ""}
      ${res.tipps && res.tipps.length ? `<div class="hint">💡 ${res.tipps.map(esc).join(" · ")}</div>` : ""}`;
    if (res.correct && res.stats.serie > 0 && res.stats.serie % 5 === 0) toast(`🔥 ${res.stats.serie}er-Serie!`);
    $("nextBtn").classList.remove("hidden");
    current = null;
  }

  $("nextBtn").onclick = next;
  $("kat").onchange = next; $("schw").onchange = next; $("familie").onchange = next;
  next();
})();
