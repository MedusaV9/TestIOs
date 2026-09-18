/* Monkey Money — Show-Master cockpit (phone/tablet browser). */
(() => {
  const $ = id => document.getElementById(id);
  const { esc, fmtMM, serverNow } = MM;
  const params = new URLSearchParams(location.search);
  $("code").value = (params.get("code") || "").toUpperCase();
  let session = JSON.parse(localStorage.getItem("mm:gm") || "null");
  let conn = null, hello = null, view = null;

  const SOUNDS = [["applaus_gross", "👏 Applaus"], ["trommelwirbel", "🥁 Trommelwirbel"], ["falsch", "❌ Fail-Buzzer"], ["dreiklang_tief", "😮 Ohhh!"], ["kaching", "💰 Kassen-Kling"], ["slime", "🦗 Grillen"], ["muenzregen", "🎊 Konfetti"], ["glitch", "🌑 Blackout"]];
  for (const [id, label] of SOUNDS) { const b = MM.el(`<button class="btn secondary">${label}</button>`); b.onclick = () => cmd({ soundPlay: { _0: id } }); $("sounds").appendChild(b); }

  function toast(t) { const el = $("toast"); el.textContent = t; el.classList.add("show"); clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove("show"), 2500); }

  $("go").onclick = () => {
    const code = $("code").value.trim().toUpperCase(), pin = $("pin").value.trim();
    if (code.length !== 4 || pin.length !== 4) { $("err").textContent = "Code und PIN haben je 4 Zeichen."; return; }
    hello = { t: "hello", roomCode: code, role: "gm", gmPin: pin, sessionToken: session && session.code === code ? session.token : null };
    start();
  };
  if (session && $("code").value && session.code === $("code").value) { hello = { t: "hello", roomCode: session.code, role: "gm", sessionToken: session.token }; start(); }

  function start() {
    if (conn) return;
    conn = MM.connect({ hello: () => hello, onStatus: ok => $("conn").classList.toggle("off", !ok), onMessage: handle });
  }

  function cmd(c) { conn.send({ t: "gm", cmd: c }); }

  function handle(msg) {
    if (msg.t === "welcome") { session = { code: hello.roomCode, token: msg.sessionToken }; localStorage.setItem("mm:gm", JSON.stringify(session)); hello.sessionToken = msg.sessionToken; $("login").classList.add("hidden"); $("cockpit").classList.remove("hidden"); return; }
    if (msg.t === "error") { $("err").textContent = msg.message; if (msg.code === "pin" || msg.code === "room") { localStorage.removeItem("mm:gm"); session = null; } toast(msg.message); return; }
    if (msg.t !== "gm") return;
    view = msg.view;
    render();
  }

  let lastDeadline = null, timerStart = 0;
  function render() {
    const st = view.stage;
    $("roomLbl").textContent = view.roomCode;
    $("phaseChip").textContent = st.phase + (st.paused ? " · PAUSE" : "");
    $("jarChip").textContent = `Glas ${fmtMM(st.jackpotGlas)}`;
    $("sectionLbl").textContent = st.sectionLabel;
    $("mainAction").textContent = st.advanceLabel || "Weiter";
    $("mainAction").disabled = !st.canAdvance && !st.paused;
    $("pauseBtn").textContent = st.paused ? "▶ Weiter" : "⏸ Bananen-Pause";
    const scene = st.scene, kind = Object.keys(scene)[0];
    // Single-value enum cases (lobby, erklaerkarte, rad, brettspiel) encode as {"_0": {...}}.
    let payload = scene[kind] || {}; if (payload._0 && Object.keys(payload).length === 1) payload = payload._0;
    let info = kind;
    let deadline = null;
    if (kind === "frage" && payload.wall) { info = `Frage ${payload.wall.nummer}/${payload.wall.gesamt || "?"} · ${payload.wall.kategorieName} · ${payload.wall.schwierigkeit} · ${payload.wall.answered.length} Antworten`; deadline = payload.wall.deadline; }
    if (kind === "kategorieWahl") { info = "Kategorien-Wahl: " + payload.optionen.map(o => `${o.label} (${o.count})`).join(" · "); deadline = payload.deadline; }
    if (kind === "erklaerkarte") { info = `Erklärkarte: ${payload.name} — bereit ${payload.bereit.length}, Streik ${payload.streik.length}`; deadline = payload.deadline; }
    if (kind === "rad") info = `Glücksrad: ${payload.subphase}${payload.erklaerung ? " — " + payload.erklaerung : ""}`;
    if (kind === "lobby") info = `${st.players.length} Spieler · Join: ${payload.joinURL} · PIN ${payload.gmPin}`;
    if (kind === "zwischenstand") deadline = payload.deadline;
    $("sceneInfo").textContent = info;
    if (deadline !== lastDeadline) { lastDeadline = deadline; timerStart = serverNow(); }
    $("timer").style.visibility = deadline ? "visible" : "hidden";
    // Players
    $("players").innerHTML = view.players.map(p => `<div><span>${p.connected ? "🟢" : "🔴"} ${esc(p.name)} <small class="muted">Platz ${st.players.find(r => r.id === p.id)?.platz || "?"}${p.streak >= 3 ? " 🔥" : ""}</small></span><span><b style="color:var(--gold)">${fmtMM(p.balance)}</b> <button data-kick="${esc(p.id)}">✕</button></span></div>`).join("");
    $("players").querySelectorAll("[data-kick]").forEach(b => b.onclick = () => { if (confirm("Spieler rauswerfen?")) cmd({ kick: { _0: b.dataset.kick } }); });
    // Drama
    $("drama").style.width = `${view.dramaScore}%`;
    $("empfehlung").textContent = view.empfehlung;
    // Cheat sheet
    if (view.spickzettel) {
      const q = view.spickzettel;
      $("spickBody").innerHTML = `<p><b>${esc(q.text)}</b></p><div class="korrekt">✔ ${esc(q.korrekt)}</div><p class="muted">${esc(q.erklaerung)}</p>${q.tipps.length ? `<p class="muted">Tipps: ${q.tipps.map(esc).join(" · ")}</p>` : ""}<p class="muted">${esc(q.kategorie)} · ${q.schwierigkeit}</p>
        ${view.regal.length ? `<h3 style="margin-top:10px">📚 Fragen-Regal</h3>${view.regal.map(r => `<p class="muted">• ${esc(r.text)} <b>(${esc(r.korrekt)})</b></p>`).join("")}` : ""}`;
    } else $("spickBody").innerHTML = `<p class="muted">Keine Frage aktiv.</p>`;
    const ans = Object.entries(view.antworten);
    $("answers").innerHTML = ans.length ? ans.map(([pid, a]) => `<div><b>${esc(view.players.find(p => p.id === pid)?.name || pid)}</b>: ${esc(a)}</div>`).join("") : `<p class="muted">—</p>`;
    // Log
    $("log").innerHTML = [...view.log].reverse().slice(0, 40).map(l => `<div>${esc(l.text)}</div>`).join("");
    // Settings
    const s = view.settings;
    if (document.activeElement.tagName !== "SELECT") { $("tempo").value = s.tempo; $("mix").value = s.fragenMix; $("modus").value = s.modus; }
    $("autoGm").checked = s.autoGm; $("musik").checked = s.musik;
    $("timerAus").checked = !!s.timerAus;
    if (document.activeElement.id !== "fragenZeit") $("fragenZeit").value = String(s.fragenZeit || 0);
    $("timerChip").classList.toggle("hidden", !s.timerAus);
    $("mainAction").classList.toggle("pulse", !!s.timerAus && st.phase === "frage");
    $("modus").disabled = st.phase !== "lobby";
    // Board games
    if (kind === "lobby" && payload.boardgames) {
      $("boardgames").classList.remove("hidden");
      $("bgButtons").innerHTML = payload.boardgames.map(b => `<button class="btn secondary" data-bg="${b.id}" ${b.startbar ? "" : "disabled"} title="${esc(b.hinweis)}">${b.emoji} ${esc(b.name)}</button>`).join("");
      $("bgButtons").querySelectorAll("[data-bg]").forEach(b => b.onclick = () => { cmd({ settingsSet: { _0: { spielModus: "spieleabend" } } }); setTimeout(() => cmd({ boardgameStart: { id: b.dataset.bg, optionen: {} } }), 150); });
    } else $("boardgames").classList.toggle("hidden", kind !== "lobby");
  }

  (function tick() {
    if (lastDeadline) {
      const now = serverNow(), total = Math.max(1000, lastDeadline - timerStart), remain = Math.max(0, lastDeadline - now);
      $("timer").firstElementChild.style.width = `${Math.min(100, remain / total * 100)}%`;
      $("timer").classList.toggle("hot", remain < 5000);
    }
    requestAnimationFrame(tick);
  })();

  $("mainAction").onclick = () => cmd({ flowNext: {} });
  $("skipOpening").onclick = () => cmd({ flowSkipOpening: {} });
  $("pauseBtn").onclick = () => { if (view && view.stage.paused) cmd({ resume: {} }); else { const text = prompt("Pause-Text (z. B. Pizza ist da!)", "🍕 Pizza ist da!"); if (text !== null) cmd({ pause: { text, dauerMs: null } }); } };
  $("revanche").onclick = () => cmd({ revanche: {} });
  $("teams").onclick = () => cmd({ teamsShuffle: {} });
  $("tempo").onchange = () => cmd({ settingsSet: { _0: { tempo: $("tempo").value } } });
  $("mix").onchange = () => cmd({ settingsSet: { _0: { fragenMix: $("mix").value } } });
  $("modus").onchange = () => cmd({ settingsSet: { _0: { modus: $("modus").value } } });
  $("autoGm").onchange = () => cmd({ autoGmSet: { _0: $("autoGm").checked } });
  $("timerAus").onchange = () => { cmd({ settingsSet: { _0: { timerAus: $("timerAus").checked } } }); toast($("timerAus").checked ? "Timer aus — du löst die Fragen selbst auf" : "Timer wieder an"); };
  $("fragenZeit").onchange = () => cmd({ settingsSet: { _0: { fragenZeit: Number($("fragenZeit").value) } } });
  $("musik").onchange = () => cmd({ settingsSet: { _0: { musik: $("musik").checked } } });

  function pickPlayer(title) {
    if (!view) return null;
    const list = view.players.map((p, i) => `${i + 1}: ${p.name} (${fmtMM(p.balance)})`).join("\n");
    const n = Number(prompt(`${title}\n${list}`)); if (!n || n < 1 || n > view.players.length) return null;
    return view.players[n - 1].id;
  }

  document.querySelectorAll("[data-cmd]").forEach(b => b.onclick = () => {
    switch (b.dataset.cmd) {
      case "timer": cmd({ timerExtend: { ms: 15000 } }); break;
      case "hint": cmd({ hintGlobal: {} }); break;
      case "encore": cmd({ encore: {} }); break;
      case "wheel": cmd({ wheelSpin: { rigTarget: null } }); break;
      case "rig": { const seg = prompt("Ziel-Segment (id): doppelter-zaster, halbe-miete, banana-bailout, dividende, insider-tipp, inflation, affentheater, boersen-roulette, umarmungs-bonus, steuerpruefung, blackout, tausch-boerse, affe-wuerfelt, kompliment-konto"); if (seg) cmd({ wheelSpin: { rigTarget: seg } }); break; }
      case "score": { const pid = pickPlayer("Punkte für wen?"); if (!pid) return; const d = Number(prompt("Betrag (±, Vielfache von 50):", "100")); const g = prompt("Begründung (Pflicht):", "Bester Fehlversuch"); if (d && g) cmd({ scoreAdjust: { playerId: pid, delta: d, grund: g } }); break; }
      case "whisper": { const pid = pickPlayer("Flüster-Tipp an wen?"); if (!pid) return; const t = prompt("Tipp-Text:"); if (t) cmd({ whisper: { playerId: pid, text: t } }); break; }
      case "boost": { const pid = pickPlayer("Aufholjagd-Boost für wen? (nie Platz 1–2)"); if (!pid) return; const art = prompt("x2 / plus300 / joker", "x2"); const g = prompt("Begründung (Pflicht):", "Mut-Buzzer"); if (art && g) cmd({ boost: { playerId: pid, art, grund: g } }); break; }
      case "punish": { const pid = pickPlayer("Pranger für wen?"); if (!pid) return; const s = prompt("bananensteuer / clown / erdbeben", "bananensteuer"); if (s) cmd({ punish: { playerId: pid, strafe: s } }); break; }
      case "joker": { const z = confirm("Für ALLE? (Abbrechen = einen Spieler wählen)") ? "alle" : pickPlayer("Joker für wen?"); if (!z) return; const j = prompt("Joker-Id: bananen-split, ueberziehungskredit, goldene-banane, schmiergeld, rueckgaberecht, bananentresor, portfolio-umschichtung", "bananen-split"); if (j) cmd({ jokerGrant: { ziel: z, jokerId: j } }); break; }
      case "vote": { const f = prompt("Frage:", "Pause machen?"); if (!f) return; const o = prompt("Optionen (Komma):", "Ja,Nein"); if (!o) return; cmd({ voteStart: { frage: f, optionen: o.split(",").map(s => s.trim()), dauerMs: 20000, bindend: false } }); break; }
      case "mood": cmd({ moodPoll: {} }); break;
      case "broken": { const g = prompt("Grund:", "Frage fehlerhaft"); if (!g) return; const r = confirm("Allen den Fragenwert geben? (Abbrechen = annullieren)") ? "grantAll" : "annul"; cmd({ questionMarkBroken: { grund: g, refund: r } }); break; }
      case "skip": { const keep = confirm("Erspielte Punkte behalten? (Abbrechen = annullieren)"); cmd({ gameSkip: { keepPoints: keep } }); break; }
      case "feedback": cmd({ feedbackCollect: {} }); break;
      case "ende": if (confirm("Show wirklich beenden?")) cmd({ ende: {} }); break;
    }
  });
})();
