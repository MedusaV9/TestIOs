/* Monkey Money — Show-Master cockpit (phone/tablet browser).
   Regie (main action, cheat sheet, live answers), Fragen (question set +
   category pool + shelf), Werkzeuge (tools as bottom sheets, soundboard) and
   Einstellungen (every match setting; plan-shaping ones lobby-only). */
(() => {
  const $ = id => document.getElementById(id);
  const { esc, fmtMM, serverNow } = MM;
  const params = new URLSearchParams(location.search);
  $("code").value = (params.get("code") || "").toUpperCase();
  let session = JSON.parse(localStorage.getItem("mm:gm") || "null");
  let conn = null, hello = null, view = null;

  const SOUNDS = [["applaus_gross", "👏 Applaus"], ["trommelwirbel", "🥁 Trommelwirbel"], ["falsch", "❌ Fail-Buzzer"], ["dreiklang_tief", "😮 Ohhh!"], ["kaching", "💰 Kassen-Kling"], ["slime", "🦗 Grillen"], ["muenzregen", "🎊 Konfetti"], ["glitch", "🌑 Blackout"]];
  for (const [id, label] of SOUNDS) { const b = MM.el(`<button class="btn secondary">${label}</button>`); b.onclick = () => cmd({ soundPlay: { _0: id } }); $("sounds").appendChild(b); }
  const JOKERS = [["bananen-split", "🍌 Bananen-Split (50:50)"], ["ueberziehungskredit", "⏳ Überziehungskredit"], ["goldene-banane", "✨ Goldene Banane"], ["schmiergeld", "🤫 Schmiergeld"], ["rueckgaberecht", "↩️ Rückgaberecht"], ["bananentresor", "🛡️ Bananentresor"], ["portfolio-umschichtung", "🔄 Portfolio-Umschichtung"]];
  const SEGMENTS = [["doppelter-zaster", "💰 Doppelter Zaster"], ["halbe-miete", "⏱️ Halbe Miete"], ["banana-bailout", "🪂 Banana Bailout"], ["dividende", "📈 Dividende"], ["insider-tipp", "🕵️ Insider-Tipp"], ["inflation", "🎈 Inflation"], ["affentheater", "🎭 Affentheater"], ["boersen-roulette", "📊 Börsen-Roulette"], ["umarmungs-bonus", "🤗 Umarmungs-Bonus"], ["steuerpruefung", "🧾 Steuerprüfung"], ["blackout", "🌑 Blackout"], ["tausch-boerse", "🔁 Tausch-Börse"], ["affe-wuerfelt", "🎲 Der Affe würfelt"], ["kompliment-konto", "💬 Kompliment-Konto"]];
  const RULES = [["sr1", "🎰 Vabanque-Finale", "Verdeckter Einsatz statt Lianen-Finale"], ["sr2", "🦅 Pleitegeier", "3 Fehler in Folge: −20 %"], ["sr3", "🤫 Notariats-Runde", "Eine Runde ohne Joker, +25 % Werte"], ["sr4", "📦 Affensteuer", "Führender zahlt 10 % pro Runde in die Kiste"], ["sr5", "🤠 Kopfgeld", "200 MM für jeden, der den Boss schlägt"], ["sr6", "🔔 Kapitalismus-Gong", "1×: Zinsen oben, Grundeinkommen unten"], ["sr7", "🍌 Bananenschale", "Rundengewinn setzen: ×2 oder weg"]];

  function toast(t) { const el = $("toast"); el.textContent = t; el.classList.add("show"); clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove("show"), 2500); }

  // ---------- tabs (phones) ----------
  document.querySelectorAll("#tabs button").forEach(b => b.onclick = () => {
    document.querySelectorAll("#tabs button").forEach(x => x.classList.toggle("on", x === b));
    document.querySelectorAll(".cols .col").forEach(c => c.classList.toggle("active", c.dataset.col === b.dataset.tab));
  });
  document.querySelector('.cols .col[data-col="regie"]').classList.add("active");

  // ---------- login ----------
  $("go").onclick = () => {
    const code = $("code").value.trim().toUpperCase(), pin = $("pin").value.trim();
    if (code.length !== 4 || pin.length !== 4) { $("err").textContent = "Code und PIN haben je 4 Zeichen."; return; }
    hello = { t: "hello", roomCode: code, role: "gm", gmPin: pin, sessionToken: session && session.code === code ? session.token : null };
    start();
  };
  if (session && $("code").value && session.code === $("code").value) { hello = { t: "hello", roomCode: session.code, role: "gm", sessionToken: session.token }; start(); }
  function start() { if (conn) return; conn = MM.connect({ hello: () => hello, onStatus: ok => $("conn").classList.toggle("off", !ok), onMessage: handle }); }
  function cmd(c) { conn.send({ t: "gm", cmd: c }); }
  const set = patch => cmd({ settingsSet: { _0: patch } });

  function handle(msg) {
    if (msg.t === "welcome") { session = { code: hello.roomCode, token: msg.sessionToken }; localStorage.setItem("mm:gm", JSON.stringify(session)); hello.sessionToken = msg.sessionToken; $("login").classList.add("hidden"); $("cockpit").classList.remove("hidden"); return; }
    if (msg.t === "error") { $("err").textContent = msg.message; if (msg.code === "pin" || msg.code === "room") { localStorage.removeItem("mm:gm"); session = null; } toast(msg.message); return; }
    if (msg.t !== "gm") return;
    view = msg.view;
    render();
  }

  // ---------- bottom sheet for the tools ----------
  let sheetSubmit = null;
  function openSheet(title, bodyHtml, onSubmit, okLabel = "Los") {
    $("sheetTitle").textContent = title; $("sheetBody").innerHTML = bodyHtml; $("sheetOk").textContent = okLabel;
    sheetSubmit = onSubmit; $("toolSheet").classList.remove("hidden");
    $("sheetBody").querySelectorAll(".pick button").forEach(b => b.onclick = () => { const group = b.closest(".pick"); if (group.dataset.multi === "1") b.classList.toggle("on"); else { group.querySelectorAll("button").forEach(x => x.classList.remove("on")); b.classList.add("on"); } });
    $("sheetBody").querySelectorAll("[data-step]").forEach(b => b.onclick = () => { const inp = $("sheetAmount"); inp.value = Math.max(-5000, Math.min(5000, (Number(inp.value) || 0) + Number(b.dataset.step))); });
  }
  const closeSheet = () => { $("toolSheet").classList.add("hidden"); sheetSubmit = null; };
  $("sheetCancel").onclick = closeSheet;
  $("toolSheet").onclick = e => { if (e.target === $("toolSheet")) closeSheet(); };
  $("sheetOk").onclick = () => { if (sheetSubmit && sheetSubmit($("sheetBody")) !== false) closeSheet(); };
  const picked = (body, name) => [...body.querySelectorAll(`.pick[data-name="${name}"] button.on`)].map(b => b.dataset.v);
  const playerPick = (filter = () => true, multi = false) => `<div class="pick players" data-name="player" data-multi="${multi ? 1 : 0}">${view.players.filter(filter).map(p => `<button type="button" data-v="${esc(p.id)}">${esc(p.name)}<small>${fmtMM(p.balance)}</small></button>`).join("")}</div>`;
  const chips = (name, items, on = null) => `<div class="pick" data-name="${name}">${items.map(([v, l]) => `<button type="button" data-v="${esc(v)}" class="${v === on ? "on" : ""}">${l}</button>`).join("")}</div>`;
  const needPlayer = body => { const p = picked(body, "player")[0]; if (!p) { toast("Erst einen Spieler wählen"); return null; } return p; };

  // ---------- render ----------
  let lastDeadline = null, timerStart = 0;
  const active = () => document.activeElement && ["SELECT", "INPUT", "TEXTAREA"].includes(document.activeElement.tagName) ? document.activeElement.id : null;
  const setVal = (id, v) => { if (active() !== id) $(id).value = String(v); };
  const setChk = (id, v) => { if (active() !== id) $(id).checked = !!v; };

  function render() {
    const st = view.stage, s = view.settings, lobby = st.phase === "lobby" || st.phase === "ende";
    $("roomLbl").textContent = view.roomCode;
    $("phaseChip").textContent = st.phase + (st.paused ? " · PAUSE" : "");
    $("jarChip").textContent = `Glas ${fmtMM(st.jackpotGlas)}`;
    $("sectionLbl").textContent = st.sectionLabel;
    $("mainAction").textContent = st.advanceLabel || "Weiter";
    $("mainAction").disabled = !st.canAdvance && !st.paused;
    $("pauseBtn").textContent = st.paused ? "▶ Weiter" : "⏸ Bananen-Pause";
    const scene = st.scene, kind = Object.keys(scene)[0];
    let payload = scene[kind] || {}; if (payload._0 && Object.keys(payload).length === 1) payload = payload._0;
    let info = kind, deadline = null;
    if (kind === "frage" && payload.wall) { info = `Frage ${payload.wall.nummer}/${payload.wall.gesamt || "?"} · ${payload.wall.kategorieName} · ${payload.wall.schwierigkeit} · ${payload.wall.answered.length} Antworten`; deadline = payload.wall.deadline; }
    if (kind === "kategorieWahl") { info = "Kategorien-Wahl: " + payload.optionen.map(o => `${o.label} (${o.count})`).join(" · "); deadline = payload.deadline; }
    if (kind === "erklaerkarte") { info = `Erklärkarte: ${payload.name} — bereit ${payload.bereit.length}, Streik ${payload.streik.length}`; deadline = payload.deadline; }
    if (kind === "rad") info = `Glücksrad: ${payload.subphase}${payload.erklaerung ? " — " + payload.erklaerung : ""}`;
    if (kind === "lobby") info = `${st.players.length} Spieler · Join: ${payload.joinURL} · PIN ${payload.gmPin}`;
    if (kind === "zwischenstand") deadline = payload.deadline;
    $("sceneInfo").textContent = info;
    if (deadline !== lastDeadline) { lastDeadline = deadline; timerStart = serverNow(); }
    $("timer").style.visibility = deadline ? "visible" : "hidden";
    // Players with quick actions
    $("players").innerHTML = view.players.map(p => `<div><span>${p.connected ? "🟢" : "🔴"} ${esc(p.name)} <small class="muted">Platz ${st.players.find(r => r.id === p.id)?.platz || "?"}${p.streak >= 3 ? " 🔥" : ""}</small></span><span><b style="color:var(--gold)">${fmtMM(p.balance)}</b> <button data-quick="score" data-pid="${esc(p.id)}" title="Punkte">±</button><button data-quick="whisper" data-pid="${esc(p.id)}" title="Flüster-Tipp">🤫</button><button data-kick="${esc(p.id)}" title="Rauswerfen">✕</button></span></div>`).join("");
    $("players").querySelectorAll("[data-kick]").forEach(b => b.onclick = () => openSheet("Spieler rauswerfen?", `<p>${esc(view.players.find(p => p.id === b.dataset.kick)?.name || "")} verlässt den Raum.</p>`, () => cmd({ kick: { _0: b.dataset.kick } }), "Rauswerfen"));
    $("players").querySelectorAll("[data-quick]").forEach(b => b.onclick = () => tool(b.dataset.quick, b.dataset.pid));
    $("drama").style.width = `${view.dramaScore}%`;
    $("empfehlung").textContent = view.empfehlung;
    // Cheat sheet + shelf
    if (view.spickzettel) {
      const q = view.spickzettel;
      $("spickBody").innerHTML = `<p><b>${esc(q.text)}</b></p><div class="korrekt">✔ ${esc(q.korrekt)}</div><p class="muted">${esc(q.erklaerung)}</p>${q.tipps.length ? `<p class="muted">Tipps: ${q.tipps.map(esc).join(" · ")}</p>` : ""}<p class="muted">${esc(q.kategorie)} · ${q.schwierigkeit}</p>`;
    } else $("spickBody").innerHTML = `<p class="muted">Keine Frage aktiv.</p>`;
    $("regal").innerHTML = view.regal.length ? view.regal.map(r => `<p class="muted">• ${esc(r.text)} <b>(${esc(r.korrekt)})</b> <small>${esc(r.kategorie)} · ${r.schwierigkeit}</small></p>`).join("") : `<p class="muted">Die nächsten Fragen erscheinen hier, sobald eine Runde läuft.</p>`;
    const ans = Object.entries(view.antworten);
    $("answers").innerHTML = ans.length ? ans.map(([pid, a]) => `<div><b>${esc(view.players.find(p => p.id === pid)?.name || pid)}</b>: ${esc(a)}</div>`).join("") : `<p class="muted">—</p>`;
    $("log").innerHTML = [...view.log].reverse().slice(0, 40).map(l => `<div>${esc(l.text)}</div>`).join("");
    $("budget").textContent = `Budget: ${view.timerExtensionsLeft}× +15 s · ${view.encoresLeft}× Encore · ${view.jokerBudget}× Joker schenken · ${view.moodPollsLeft}× Stimmung`;
    // Question set + categories
    $("sets").innerHTML = (view.fragenSets || []).map(x => `<button type="button" class="set ${x.aktiv ? "on" : ""}" data-set="${esc(x.id)}" title="${esc(x.beschreibung)}"><span class="e">${x.emoji}</span><span class="n">${esc(x.name)}</span><span class="c">${x.anzahl} Fragen</span></button>`).join("");
    $("sets").querySelectorAll("[data-set]").forEach(b => b.onclick = () => { if (b.dataset.set === "eigen") { $("customPool").open = true; return; } set({ fragenSet: b.dataset.set }); toast(`Fragen-Set: ${b.querySelector(".n").textContent}`); });
    $("poolInfo").textContent = view.poolInfo || "";
    if (!$("cats").matches(":focus-within")) {
      $("cats").innerHTML = (view.kategorien || []).map(k => `<div class="cat ${k.gewaehlt ? "on" : ""}"><button type="button" class="cat-main" data-kat="${esc(k.id)}" style="--c:${esc(k.farbe)}"><span>${k.emoji} ${esc(k.name)}</span><small>${k.anzahl}</small></button><div class="subs">${k.unter.map(u => `<button type="button" class="${u.gewaehlt ? "on" : ""}" data-sub="${esc(u.id)}" data-kat="${esc(k.id)}">${esc(u.name)} <small>${u.anzahl}</small></button>`).join("")}</div></div>`).join("");
      $("cats").querySelectorAll(".cat-main").forEach(b => b.onclick = () => togglePool(b.dataset.kat, null));
      $("cats").querySelectorAll("[data-sub]").forEach(b => b.onclick = () => togglePool(b.dataset.kat, b.dataset.sub));
    }
    // Settings (never fight the control the GM is touching)
    setVal("tempo", s.tempo); setVal("mix", s.fragenMix); setVal("modus", s.modus); setVal("teams", s.teams); setVal("katWahl", s.kategorienWahl);
    setVal("fragenZeit", s.fragenZeit || 0); setVal("runden", s.rundenOverride || 0); setVal("finaleFaktor", s.finaleFaktor >= 1.5 ? "1.5" : (s.finaleFaktor <= 1 ? "1.0" : "1.25"));
    if (active() !== "deAnteil") { $("deAnteil").value = Math.round((s.deAnteil ?? 0.5) * 100); } $("deLbl").textContent = `${$("deAnteil").value} %`;
    setChk("autoGm", s.autoGm); setChk("musik", s.musik); setChk("timerAus", s.timerAus); setChk("kurzeShow", s.kurzeShow); setChk("jokerAn", s.jokerAn); setChk("radAn", s.radAn);
    setChk("gmLos", s.gmLos); setChk("familie", s.familienModus); setChk("alkohol", s.alkoholEdition); setChk("v2", s.v2Formate); setChk("allIn", s.allInErlaubt);
    $("rules").innerHTML = RULES.map(([id, l, d]) => `<button type="button" class="rule ${(s.specialRules || []).includes(id) ? "on" : ""}" data-rule="${id}" ${lobby ? "" : "disabled"} title="${esc(d)}">${l}</button>`).join("");
    $("rules").querySelectorAll("[data-rule]").forEach(b => b.onclick = () => { const cur = new Set(s.specialRules || []); cur.has(b.dataset.rule) ? cur.delete(b.dataset.rule) : cur.add(b.dataset.rule); set({ specialRules: [...cur] }); });
    for (const id of ["modus", "teams", "runden", "finaleFaktor", "v2", "allIn"]) $(id).disabled = !lobby;
    $("lobbyHint").classList.toggle("hidden", lobby);
    $("timerChip").classList.toggle("hidden", !s.timerAus);
    $("mainAction").classList.toggle("pulse", !!s.timerAus && st.phase === "frage");
    $("skipOpening").classList.toggle("hidden", st.phase !== "intro");
  }

  /** Toggle a category or one of its sub-categories in the custom pool. */
  function togglePool(kat, sub) {
    const cats = view.kategorien || [];
    let pool = new Set(view.settings.kategorienPool || []);
    const allKats = cats.map(k => k.id);
    if (pool.size === 0) pool = new Set(allKats); // "everything" → explicit list, then toggle
    const k = cats.find(c => c.id === kat);
    if (!sub) {
      if (pool.has(kat)) { pool.delete(kat); for (const u of k.unter) pool.delete(u.id); }
      else { pool.add(kat); for (const u of k.unter) pool.delete(u.id); }
    } else {
      if (pool.has(kat)) { // whole category was on → switch to all subs except this one
        pool.delete(kat); for (const u of k.unter) if (u.id !== sub) pool.add(u.id);
      } else if (pool.has(sub)) { pool.delete(sub); }
      else { pool.add(sub); if (k.unter.every(u => pool.has(u.id))) { for (const u of k.unter) pool.delete(u.id); pool.add(kat); } }
    }
    const list = [...pool];
    set({ kategorienPool: list.length === allKats.length && allKats.every(a => pool.has(a)) ? [] : list });
  }
  $("poolAll").onclick = () => set({ kategorienPool: [] });
  $("poolNone").onclick = () => { const first = (view.kategorien || [])[0]; if (first) set({ kategorienPool: [first.id] }); toast("Pool auf eine Kategorie reduziert — weitere antippen"); };

  (function tick() {
    if (lastDeadline) {
      const now = serverNow(), total = Math.max(1000, lastDeadline - timerStart), remain = Math.max(0, lastDeadline - now);
      $("timer").firstElementChild.style.width = `${Math.min(100, remain / total * 100)}%`;
      $("timer").classList.toggle("hot", remain < 5000);
    }
    requestAnimationFrame(tick);
  })();

  // ---------- controls ----------
  $("mainAction").onclick = () => cmd({ flowNext: {} });
  $("skipOpening").onclick = () => cmd({ flowSkipOpening: {} });
  $("pauseBtn").onclick = () => {
    if (view && view.stage.paused) { cmd({ resume: {} }); return; }
    openSheet("⏸ Bananen-Pause", `${chips("text", [["🍕 Pizza ist da!", "🍕 Pizza ist da!"], ["🍌 Bananen-Pause", "🍌 Bananen-Pause"], ["🚻 Kurze Pause", "🚻 Kurze Pause"], ["🍻 Nachschub holen", "🍻 Nachschub holen"]], "🍌 Bananen-Pause")}<label class="f">Dauer</label>${chips("dauer", [["0", "Offen (▶ zum Weitermachen)"], ["120000", "2 min"], ["300000", "5 min"], ["600000", "10 min"]], "0")}`,
      body => { const text = picked(body, "text")[0] || "🍌 Bananen-Pause"; const d = Number(picked(body, "dauer")[0] || 0); cmd({ pause: { text, dauerMs: d > 0 ? d : null } }); }, "Pause starten");
  };
  const on = (id, fn) => { $(id).onchange = fn; };
  on("tempo", () => set({ tempo: $("tempo").value }));
  on("mix", () => set({ fragenMix: $("mix").value }));
  on("modus", () => set({ modus: $("modus").value }));
  on("teams", () => { set({ teams: $("teams").value }); setTimeout(() => cmd({ teamsShuffle: {} }), 150); });
  on("katWahl", () => set({ kategorienWahl: $("katWahl").value }));
  on("runden", () => set({ rundenOverride: Number($("runden").value) }));
  on("finaleFaktor", () => set({ finaleFaktor: Number($("finaleFaktor").value) }));
  on("autoGm", () => cmd({ autoGmSet: { _0: $("autoGm").checked } }));
  on("timerAus", () => { set({ timerAus: $("timerAus").checked }); toast($("timerAus").checked ? "Timer aus — du löst die Fragen selbst auf" : "Timer wieder an"); });
  on("fragenZeit", () => set({ fragenZeit: Number($("fragenZeit").value) }));
  on("musik", () => set({ musik: $("musik").checked }));
  on("kurzeShow", () => set({ kurzeShow: $("kurzeShow").checked }));
  on("jokerAn", () => set({ jokerAn: $("jokerAn").checked }));
  on("radAn", () => set({ radAn: $("radAn").checked }));
  on("gmLos", () => set({ gmLos: $("gmLos").checked }));
  on("familie", () => set({ familienModus: $("familie").checked }));
  on("alkohol", () => set({ alkoholEdition: $("alkohol").checked }));
  on("v2", () => set({ v2Formate: $("v2").checked }));
  on("allIn", () => set({ allInErlaubt: $("allIn").checked }));
  $("deAnteil").oninput = () => { $("deLbl").textContent = `${$("deAnteil").value} %`; };
  on("deAnteil", () => set({ deAnteil: Number($("deAnteil").value) / 100 }));

  // ---------- tools as sheets ----------
  function tool(which, pid = null) {
    if (!view) return;
    const rank = id => view.stage.players.find(r => r.id === id)?.platz || 99;
    switch (which) {
      case "timer": cmd({ timerExtend: { ms: 15000 } }); toast("+15 s"); break;
      case "hint": cmd({ hintGlobal: {} }); toast("Tipp für alle"); break;
      case "encore": cmd({ encore: {} }); break;
      case "wheel": cmd({ wheelSpin: { rigTarget: null } }); break;
      case "mood": cmd({ moodPoll: {} }); break;
      case "feedback": cmd({ feedbackCollect: {} }); break;
      case "teams": cmd({ teamsShuffle: {} }); break;
      case "revanche": openSheet("🔁 Revanche", "<p>Gleiche Affen, neues Geld — zurück in die Lobby.</p>", () => cmd({ revanche: {} }), "Revanche!"); break;
      case "ende": openSheet("⏹ Show beenden", "<p>Die Show endet sofort, alle Handys zeigen den Abspann.</p>", () => cmd({ ende: {} }), "Beenden"); break;
      case "rig": openSheet("🎯 Gezinktes Rad", `<p class="muted">Das Rad landet garantiert auf diesem Feld.</p>${chips("seg", SEGMENTS)}`, body => { const seg = picked(body, "seg")[0]; if (!seg) { toast("Feld wählen"); return false; } cmd({ wheelSpin: { rigTarget: seg } }); }, "Drehen"); break;
      case "score":
        openSheet("🏦 Punkte ±", `${playerPick()}<label class="f">Betrag</label><div class="amount"><button type="button" data-step="-250">−250</button><button type="button" data-step="-50">−50</button><input type="number" id="sheetAmount" value="100" step="50"><button type="button" data-step="50">+50</button><button type="button" data-step="250">+250</button></div><label class="f">Begründung</label>${chips("grund", [["Bester Fehlversuch", "Bester Fehlversuch"], ["Lacher des Abends", "Lacher des Abends"], ["Technik-Ausgleich", "Technik-Ausgleich"], ["Frechheit", "Frechheit (−)"]], "Bester Fehlversuch")}<input type="text" id="sheetGrund" placeholder="… oder eigene Begründung">`,
          body => { const p = needPlayer(body); if (!p) return false; const d = Number($("sheetAmount").value) || 0; const g = $("sheetGrund").value.trim() || picked(body, "grund")[0] || "Regie"; if (!d) { toast("Betrag ≠ 0"); return false; } cmd({ scoreAdjust: { playerId: p, delta: d, grund: g } }); }, "Buchen");
        if (pid) $("sheetBody").querySelector(`.pick.players button[data-v="${pid}"]`)?.classList.add("on");
        break;
      case "whisper": {
        const q = view.spickzettel;
        const quick = q ? [...q.tipps.map((t, i) => [t, `💡 Tipp ${i + 1}: ${t.length > 38 ? t.slice(0, 36) + "…" : t}`]), [`Die Antwort ist: ${q.korrekt}`, `✔ Antwort verraten (${q.korrekt})`]] : [];
        openSheet("🤫 Flüster-Tipp", `${playerPick()}<label class="f">Tipp</label>${quick.length ? chips("quick", quick) : ""}<input type="text" id="sheetText" placeholder="… oder eigenen Text tippen">`,
          body => { const p = needPlayer(body); if (!p) return false; const t = $("sheetText").value.trim() || picked(body, "quick")[0] || ""; if (!t) { toast("Tipp wählen oder eingeben"); return false; } cmd({ whisper: { playerId: p, text: t } }); toast(`Geflüstert an ${view.players.find(x => x.id === p)?.name || ""}`); }, "Flüstern");
        if (pid) $("sheetBody").querySelector(`.pick.players button[data-v="${pid}"]`)?.classList.add("on");
        break;
      }
      case "boost":
        openSheet("🐒 Aufholjagd-Boost", `<p class="muted">Nie für Platz 1–2, einmal pro Spieler und Runde.</p>${playerPick(p => rank(p.id) > 2)}<label class="f">Art</label>${chips("art", [["x2", "×2 nächste Frage"], ["plus300", "+300 MM"], ["joker", "Gratis-Joker"]], "x2")}<label class="f">Begründung</label>${chips("grund", [["Mut-Buzzer", "Mut-Buzzer"], ["Comeback-Bonus", "Comeback-Bonus"], ["Pech gehabt", "Pech gehabt"]], "Mut-Buzzer")}`,
          body => { const p = needPlayer(body); if (!p) return false; cmd({ boost: { playerId: p, art: picked(body, "art")[0] || "x2", grund: picked(body, "grund")[0] || "Regie" } }); }, "Boosten");
        break;
      case "punish":
        openSheet("⚖️ Pranger", `${playerPick()}<label class="f">Strafe</label>${chips("strafe", [["bananensteuer", "🍌 Bananen-Steuer −100 ins Glas"], ["clown", "🤡 Clownsnase"], ["erdbeben", "📳 Handy-Erdbeben"]], "bananensteuer")}`,
          body => { const p = needPlayer(body); if (!p) return false; cmd({ punish: { playerId: p, strafe: picked(body, "strafe")[0] || "bananensteuer" } }); }, "Bestrafen");
        break;
      case "joker":
        openSheet("🎁 Joker schenken", `<label class="f">Für</label>${chips("ziel", [["alle", "👥 Alle"]], "alle")}${playerPick()}<label class="f">Joker</label>${chips("joker", JOKERS, "bananen-split")}<p class="muted">Budget: ${view.jokerBudget}</p>`,
          body => { const z = picked(body, "player")[0] || picked(body, "ziel")[0] || "alle"; cmd({ jokerGrant: { ziel: z, jokerId: picked(body, "joker")[0] || "bananen-split" } }); }, "Schenken");
        break;
      case "vote":
        openSheet("🗳️ Voting", `<label class="f">Frage</label><input type="text" id="sheetText" value="Pause machen?"><label class="f">Optionen (Komma)</label><input type="text" id="sheetOpts" value="Ja, Nein"><label class="f">Dauer</label>${chips("dauer", [["20000", "20 s"], ["45000", "45 s"], ["90000", "90 s"]], "20000")}`,
          () => { const f = $("sheetText").value.trim(), o = $("sheetOpts").value.split(",").map(x => x.trim()).filter(Boolean); if (!f || o.length < 2) { toast("Frage + mindestens 2 Optionen"); return false; } cmd({ voteStart: { frage: f, optionen: o, dauerMs: Number(picked($("sheetBody"), "dauer")[0] || 20000), bindend: false } }); }, "Abstimmen");
        break;
      case "broken":
        openSheet("🔴 Frage fehlerhaft", `<label class="f">Grund</label>${chips("grund", [["Frage fehlerhaft", "Frage fehlerhaft"], ["Antwort veraltet", "Antwort veraltet"], ["Technik", "Technik"]], "Frage fehlerhaft")}<label class="f">Ausgleich</label>${chips("refund", [["grantAll", "Allen den Fragenwert gutschreiben"], ["annul", "Frage annullieren"]], "grantAll")}`,
          body => cmd({ questionMarkBroken: { grund: picked(body, "grund")[0] || "Frage fehlerhaft", refund: picked(body, "refund")[0] || "grantAll" } }), "Anwenden");
        break;
      case "skip":
        openSheet("🚪 Notausgang", `<p class="muted">Das laufende Minispiel wird abgebrochen.</p>${chips("keep", [["1", "Erspielte Punkte behalten"], ["0", "Punkte annullieren"]], "1")}`, body => cmd({ gameSkip: { keepPoints: picked(body, "keep")[0] !== "0" } }), "Überspringen");
        break;
    }
  }
  document.querySelectorAll("[data-cmd]").forEach(b => b.onclick = () => tool(b.dataset.cmd));
})();
