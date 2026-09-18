/* Monkey Money — phone player (browser fallback). Renders the declarative
   PlayerPrompt kinds the engine emits; the native iPhone app renders the same. */
(() => {
  const $ = id => document.getElementById(id);
  const { MONKEYS, COLORS, esc, fmtMM, fmtDelta, renderAvatar, prompt: decode, serverNow, haptic } = MM;

  // ---------- join screen ----------
  const codeFromPath = (location.pathname.match(/\/j\/([A-Za-z]{4})/) || [])[1] || new URLSearchParams(location.search).get("code") || "";
  $("code").value = codeFromPath.toUpperCase();
  $("joinRoomChip").textContent = codeFromPath ? `Raum ${codeFromPath.toUpperCase()}` : "Raum-Code eingeben";
  const saved = JSON.parse(localStorage.getItem("mm:look") || "null") || { affe: 0, farbe: "gelb" };
  let affeIdx = Math.max(0, MONKEYS.findIndex(m => m[0] === (saved.affeId || "")) >= 0 ? MONKEYS.findIndex(m => m[0] === saved.affeId) : saved.affe || 0);
  let farbe = saved.farbe || "gelb";
  $("name").value = localStorage.getItem("mm:name") || "";

  function paintMonkey() {
    const m = MONKEYS[affeIdx];
    $("mname").textContent = m[1];
    $("mtitle").textContent = `„${m[2]}“`;
    renderAvatar($("preview"), `${m[0]}.${farbe}`);
    [...$("colors").children].forEach(sw => sw.classList.toggle("on", sw.dataset.c === farbe));
  }
  for (const [id, hex] of COLORS) {
    const sw = MM.el(`<div class="swatch" data-c="${id}" style="background:${hex}"></div>`);
    sw.onclick = () => { farbe = id; paintMonkey(); haptic(); };
    $("colors").appendChild(sw);
  }
  $("prev").onclick = () => { affeIdx = (affeIdx + MONKEYS.length - 1) % MONKEYS.length; paintMonkey(); haptic(); };
  $("next").onclick = () => { affeIdx = (affeIdx + 1) % MONKEYS.length; paintMonkey(); haptic(); };
  $("saveProfile").onchange = () => $("pinRow").classList.toggle("hidden", !$("saveProfile").checked);
  paintMonkey();

  // Profiles known on this device (REST on the iPad).
  const deviceToken = MM.deviceToken();
  let chosenProfile = null;
  fetch(`/api/profiles?device=${encodeURIComponent(deviceToken)}`).then(r => r.ok ? r.json() : []).then(list => {
    if (!Array.isArray(list) || !list.length) return;
    const box = $("profiles");
    box.classList.remove("hidden");
    box.innerHTML = `<h3>📱 Auf diesem Handy zuletzt:</h3>`;
    for (const p of list) {
      const b = MM.el(`<button class="btn secondary small" style="margin:4px 4px 0 0">${esc(p.name)} · Lv ${p.level} · ${p.atAktuell} AT ${p.hasPin ? "🔒" : ""}</button>`);
      b.onclick = () => { chosenProfile = p; $("name").value = p.name; const i = MONKEYS.findIndex(m => m[0] === p.avatar.split(".")[0]); if (i >= 0) affeIdx = i; farbe = p.avatar.split(".")[1] || farbe; paintMonkey(); toast(`Weiter als ${p.name}`); };
      box.appendChild(b);
    }
  }).catch(() => {});

  $("loadProfile").onclick = async () => {
    const name = prompt("Profil-Name?");
    if (!name) return;
    const pin = prompt("PIN (4 Ziffern, leer lassen falls keine):") || "";
    const r = await fetch(`/api/profiles/find?name=${encodeURIComponent(name)}&pin=${encodeURIComponent(pin)}&device=${encodeURIComponent(deviceToken)}`);
    if (!r.ok) { $("joinErr").textContent = "Profil nicht gefunden oder PIN falsch."; return; }
    chosenProfile = await r.json();
    chosenProfile.pinGiven = pin;
    $("name").value = chosenProfile.name;
    toast(`Profil ${chosenProfile.name} geladen`);
  };

  let session = JSON.parse(localStorage.getItem("mm:session") || "null");
  let conn = null;
  let helloPayload = null;

  $("go").onclick = async () => {
    const code = $("code").value.trim().toUpperCase();
    const name = $("name").value.trim();
    if (code.length !== 4) { $("joinErr").textContent = "Bitte den 4-stelligen Raum-Code eingeben."; return; }
    if (!name && !chosenProfile) { $("joinErr").textContent = "Wie heißt du?"; return; }
    localStorage.setItem("mm:name", name);
    localStorage.setItem("mm:look", JSON.stringify({ affeId: MONKEYS[affeIdx][0], farbe }));
    const avatar = `${MONKEYS[affeIdx][0]}.${farbe}`;
    let profileId = chosenProfile ? chosenProfile.id : null;
    let profilePin = chosenProfile ? chosenProfile.pinGiven || null : null;
    if (!profileId && $("saveProfile").checked) {
      try {
        const r = await fetch("/api/profiles", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, avatar, pin: $("pin").value || null, device: deviceToken }) });
        if (r.ok) { const p = await r.json(); profileId = p.id; toast(`Profil angelegt: ${p.name} (+300 AT Willkommen)`); }
      } catch (_) {}
    } else if (profileId) {
      // Persist the freshly chosen look on the profile before joining.
      fetch(`/api/profiles/${profileId}/update`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ avatar, device: deviceToken, pin: profilePin }) }).catch(() => {});
    }
    helloPayload = { t: "hello", roomCode: code, role: "player", name, avatar, profileId, profilePin, deviceToken, sessionToken: session && session.code === code ? session.token : null };
    startSocket();
  };

  // Auto-rejoin when a session for this room exists.
  if (session && codeFromPath && session.code === codeFromPath.toUpperCase()) {
    helloPayload = { t: "hello", roomCode: session.code, role: "player", sessionToken: session.token, name: $("name").value, avatar: `${MONKEYS[affeIdx][0]}.${farbe}` };
    startSocket();
  }

  function startSocket() {
    if (conn) return;
    conn = MM.connect({
      hello: () => helloPayload,
      onStatus: ok => $("conn").classList.toggle("off", !ok),
      onMessage: handle,
    });
  }

  // ---------- game ----------
  let view = null;
  let lastMomentId = 0;
  let timerRaf = null;
  let orderState = null;
  let chipsState = null;
  let taps = 0;

  function handle(msg) {
    if (msg.t === "welcome") {
      session = { code: helloPayload.roomCode.toUpperCase(), token: msg.sessionToken };
      localStorage.setItem("mm:session", JSON.stringify(session));
      helloPayload.sessionToken = msg.sessionToken;
      $("join").classList.add("hidden");
      $("game").classList.remove("hidden");
      return;
    }
    if (msg.t === "error") {
      $("joinErr").textContent = msg.message;
      if (msg.code === "room" || msg.code === "no-session") { localStorage.removeItem("mm:session"); session = null; $("join").classList.remove("hidden"); $("game").classList.add("hidden"); }
      return;
    }
    if (msg.t === "closed") { toast("Der Raum wurde geschlossen."); localStorage.removeItem("mm:session"); return; }
    if (msg.t === "profileEvent") { const e = msg.event; toast(`+${e.atDelta} AT${e.levelUp ? ` · LEVEL ${e.level}!` : ""}${e.quests.length ? " · Quest ✔" : ""}`); return; }
    if (msg.t !== "player") return;
    view = msg.view;
    render();
  }

  function send(action) { conn.send({ t: "action", action, idem: Math.random().toString(36).slice(2) }); haptic(); }

  function toast(text) {
    const t = $("toast");
    t.textContent = text;
    t.classList.add("show");
    clearTimeout(t._h);
    t._h = setTimeout(() => t.classList.remove("show"), 2800);
  }

  function render() {
    if (!view) return;
    const me = view.me;
    $("meName").textContent = me.name;
    $("meBalance").textContent = fmtMM(me.balance);
    const p0 = decode(view.prompt);
    const noTimer = view.phase === "frage" && ["choice", "number", "order", "wager", "chips", "text"].includes(p0.kind) && !p0.deadline;
    $("meStatus").textContent = view.statusText + (view.rueckenwind > 1 ? ` · 🌬️ ×${view.rueckenwind}` : "") + (noTimer ? " · ⏱️ kein Timer" : "");
    $("meStreak").textContent = me.streak >= 3 ? `🔥 Streak ${me.streak} (×${me.streak >= 5 ? 2 : 1.5})` : (me.streak > 0 ? `Serie: ${me.streak}` : "");
    if ($("meAvatar").dataset.wire !== me.avatar) { $("meAvatar").dataset.wire = me.avatar; renderAvatar($("meAvatar"), me.avatar); }
    if (view.flash) { const f = $("flash"); f.className = "flash"; requestAnimationFrame(() => { f.className = "flash " + view.flash; }); }
    if (view.haptic) haptic(view.haptic);
    const newest = view.moments && view.moments.length ? view.moments[view.moments.length - 1] : null;
    if (newest && newest.id > lastMomentId) { lastMomentId = newest.id; if (newest.art !== "sound") toast(newest.text); }

    // Jokers
    const jk = $("jokers");
    if (view.jokers && view.jokers.length) {
      jk.classList.remove("hidden");
      jk.innerHTML = "";
      for (const j of view.jokers) {
        const b = MM.el(`<button class="joker" ${j.nutzbar ? "" : "disabled"} title="${esc(j.beschreibung)}"><span class="e">${j.emoji}</span>${esc(j.name)}<span class="p">${j.ladungen > 0 ? `${j.ladungen}× frei` : (j.preis ? fmtMM(j.preis) : "gratis")}</span></button>`);
        b.onclick = () => {
          if (j.id === "schmiergeld") { const st = confirm("Stufe 2 (Hinweis, 35 %)? Abbrechen = Stufe 1 (Option weg, 25 %)") ? 2 : 1; send({ type: "joker", id: j.id, stufe: st }); }
          else send({ type: "joker", id: j.id });
        };
        jk.appendChild(b);
      }
    } else jk.classList.add("hidden");

    // Ranking card
    const rank = $("rankCard");
    if (["zwischenstand", "halbzeit", "siegerehrung", "ende", "pause"].includes(view.phase)) {
      rank.classList.remove("hidden");
      $("ranking").innerHTML = view.ranking.map(r => `<li><span>${r.platz}. ${esc(r.name)}${r.id === me.id ? " (du)" : ""}</span><span class="mm">${fmtMM(r.balance)}</span></li>`).join("");
    } else rank.classList.add("hidden");

    renderPrompt(decode(view.prompt));
  }

  function timerHtml(deadline) {
    return deadline ? `<div class="timer" data-deadline="${deadline}"><div style="width:100%"></div></div>` : "";
  }

  function startTimers() {
    cancelAnimationFrame(timerRaf);
    const bars = [...document.querySelectorAll(".timer[data-deadline]")];
    if (!bars.length) return;
    const start = serverNow();
    const step = () => {
      const now = serverNow();
      for (const bar of bars) {
        const dl = Number(bar.dataset.deadline);
        const total = Math.max(1000, dl - start + 1);
        const remain = Math.max(0, dl - now);
        bar.firstElementChild.style.width = `${Math.min(100, (remain / (bar._total || (bar._total = Math.max(total, remain)))) * 100)}%`;
        bar.classList.toggle("hot", remain < 5000);
      }
      timerRaf = requestAnimationFrame(step);
    };
    step();
  }

  function whisperHtml() { return view.whisper ? `<div class="whisper">${esc(view.whisper)}</div>` : ""; }

  function renderPrompt(p) {
    const main = $("main");
    const key = JSON.stringify(p);
    if (main.dataset.key === key) return;
    main.dataset.key = key;
    const kindChanged = main.dataset.kind !== p.kind;
    main.dataset.kind = p.kind;
    if (kindChanged) { orderState = null; chipsState = null; taps = 0; }
    let html = "";
    switch (p.kind) {
      case "idle":
        html = `<div class="idle"><div class="eye">🐵</div><h2>${esc(p.title)}</h2><p>${esc(p.subtitle || "")}</p></div>`;
        break;
      case "choice": {
        const locked = p.chosen !== null && p.chosen !== undefined && !p.secondTry;
        html = `${timerHtml(p.deadline)}${whisperHtml()}${p.hint ? `<div class="hint">${esc(p.hint)}</div>` : ""}<div class="question">${esc(p.question)}</div>
          <div class="options ${locked ? "locked" : ""}">${p.options.map((o, i) => `<button class="opt ${o.removed ? "removed" : ""} ${p.chosen === o.id ? "chosen" : ""}" data-i="${i}" data-id="${o.id}"><span class="letter">${"ABCDEFGH"[i]}</span><span>${esc(o.text)}</span>${o.count != null ? `<span class="count">${o.count}</span>` : ""}</button>`).join("")}</div>
          ${p.secondTry ? `<p class="hint">↩️ Rückgaberecht: wähle eine andere Antwort (50 % Gewinn)</p>` : ""}`;
        break;
      }
      case "multiChoice":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.question)}</div><div class="options">${p.options.map((o, i) => `<button class="opt ${p.chosen.includes(o.id) ? "chosen" : ""}" data-i="${i}" data-id="${o.id}"><span class="letter">${"ABCDEFGH"[i]}</span><span>${esc(o.text)}</span></button>`).join("")}</div>`;
        break;
      case "reveal": {
        const cls = p.correct === true ? "ok" : p.correct === false ? "nope" : "meh";
        html = `<div class="reveal ${cls}"><div class="stamp">${esc(p.title)}</div><div class="delta ${p.delta < 0 ? "neg" : ""}">${fmtDelta(p.delta)}</div>${p.streak >= 3 ? `<div class="streak">🔥 Streak ${p.streak}</div>` : ""}<div class="detail">${esc(p.detail || "")}</div></div>`;
        break;
      }
      case "buzzer":
        html = `${p.question ? `<div class="question center">${esc(p.question)}</div>` : ""}<button class="buzzer ${p.armed ? "" : "off"}" id="buzz" ${p.armed ? "" : "disabled"}>${p.pressed ? "GEBUZZERT!" : (p.armed ? "BUZZ!" : "…")}</button>${p.hint ? `<p class="hint center">${esc(p.hint)}</p>` : ""}`;
        break;
      case "number": {
        const cur = p.current ?? (p.min + p.max) / 2;
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.question)}</div><div class="slider-wrap"><div class="slider-value" id="numVal">${fmtNum(cur)}</div><div class="slider-unit">${esc(p.unit)}</div>
          <input type="range" id="num" min="${p.min}" max="${p.max}" step="${p.step}" value="${cur}" ${p.locked ? "disabled" : ""}>
          <div class="stepper"><button data-d="-10">−−</button><button data-d="-1">−</button><button data-d="1">+</button><button data-d="10">++</button></div>
          <input type="number" id="numDirect" value="${cur}" ${p.locked ? "disabled" : ""} step="${p.step}">
          <button class="btn" id="lockNum" ${p.locked ? "disabled" : ""} style="margin-top:12px">${p.locked ? "EINGELOGGT ✔" : "EINLOGGEN"}</button></div>`;
        break;
      }
      case "order": {
        if (!orderState) orderState = [...p.order];
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.question)}</div><div class="order">${orderState.map((id, pos) => { const it = p.items.find(i => i.id === id); return `<div class="item" data-pos="${pos}"><span class="pos">${pos + 1}</span><span>${esc(it ? it.text : "")}</span><span class="mv"><button data-mv="-1" data-pos="${pos}">▲</button><button data-mv="1" data-pos="${pos}">▼</button></span></div>`; }).join("")}</div>
          <button class="btn" id="lockOrder" ${p.locked ? "disabled" : ""} style="margin-top:12px">${p.locked ? "EINGELOGGT ✔" : "EINLOGGEN"}</button>`;
        break;
      }
      case "wager": {
        const cur = p.current ?? p.min;
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.title)}</div>${p.subtitle ? `<p class="muted">${esc(p.subtitle)}</p>` : ""}<div class="slider-wrap"><div class="slider-value" id="numVal">${fmtMM(cur)}</div>
          <input type="range" id="num" min="${p.min}" max="${p.max}" step="${p.step}" value="${cur}" ${p.locked ? "disabled" : ""}>
          <div class="stepper"><button data-d="-1">−</button><button data-d="1">+</button></div>
          <button class="btn" id="lockNum" ${p.locked ? "disabled" : ""}>${p.locked ? "EINGELOGGT ✔" : "EINSATZ SETZEN"}</button></div>`;
        break;
      }
      case "text":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.question)}</div><input type="text" id="txt" maxlength="${p.maxLength}" placeholder="${esc(p.placeholder)}" ${p.submitted ? "disabled" : ""} value="${esc(p.submitted || "")}"><button class="btn" id="sendTxt" ${p.submitted ? "disabled" : ""} style="margin-top:12px">${p.submitted ? "ABGESCHICKT ✔" : "ABSCHICKEN"}</button>`;
        break;
      case "tapFrenzy":
        html = `${timerHtml(p.deadline)}<div class="question center">${esc(p.title)}</div><div class="tap-count" id="tapCount">${taps}</div><button class="frenzy" id="frenzy" ${p.active ? "" : "disabled"}>🥥</button>`;
        break;
      case "chips": {
        if (!chipsState) chipsState = [...p.placed];
        const used = chipsState.reduce((a, b) => a + b, 0);
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.question)}</div><div class="chips-left">${p.total - used} Chips übrig</div>${p.options.map((o, i) => `<div class="chip-row"><span class="lbl">${esc(o.text)}</span><button data-ch="-1" data-i="${i}" ${p.locked ? "disabled" : ""}>−</button><span class="n">${chipsState[i] || 0}</span><button data-ch="1" data-i="${i}" ${p.locked ? "disabled" : ""}>+</button></div>`).join("")}
          <button class="btn" id="lockChips" ${p.locked || used !== p.total ? "disabled" : ""}>${p.locked ? "GESETZT ✔" : "SETZEN"}</button>`;
        break;
      }
      case "pickPlayer":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.title)}</div>${p.subtitle ? `<p class="muted">${esc(p.subtitle)}</p>` : ""}<div class="players-grid">${p.candidates.map(c => `<button class="pcard ${p.chosen === c.id ? "on" : ""}" data-pid="${esc(c.id)}"><span class="mini" data-avatar="${esc(c.avatar)}"></span><span>${esc(c.name)}<small>${fmtMM(c.balance)}</small></span></button>`).join("")}</div>`;
        break;
      case "bank":
        html = `${timerHtml(p.deadline)}<div class="row" style="justify-content:space-between"><span class="chip gold">Pott: ${fmtMM(p.pot)}</span><span class="chip">Gesichert: ${fmtMM(p.banked)}</span></div>
          <button class="btn bank-btn" id="bankBtn" ${p.pot > 0 ? "" : "disabled"}>🏦 BANK! ${fmtMM(p.pot)}</button>
          ${p.question ? `<div class="question" style="margin-top:14px">${esc(p.question)}</div>` : ""}<div class="options ${p.chosen != null ? "locked" : ""}">${p.options.map((o, i) => `<button class="opt ${p.chosen === o.id ? "chosen" : ""} ${o.removed ? "removed" : ""}" data-i="${i}" data-id="${o.id}"><span class="letter">${"ABCD"[i]}</span><span>${esc(o.text)}</span></button>`).join("")}</div>`;
        break;
      case "cheer":
        html = `<div class="question center">${esc(p.title)}</div>${p.subtitle ? `<p class="muted center">${esc(p.subtitle)}</p>` : ""}<button class="btn cheer-btn" id="cheerBtn">🥁 ANFEUERN!</button><div class="tap-count">${p.taps || ""}</div>`;
        break;
      case "confirm":
        html = `${timerHtml(p.deadline)}<div class="question center">${esc(p.title)}</div>${p.subtitle ? `<p class="muted center">${esc(p.subtitle)}</p>` : ""}<button class="btn" id="confirmBtn" ${p.done ? "disabled" : ""}>${p.done ? "✔ " : ""}${esc(p.button)}</button>`;
        break;
      case "binary":
        html = `${timerHtml(p.deadline)}<div class="question center">${esc(p.title)}</div>${p.subtitle ? `<p class="muted center">${esc(p.subtitle)}</p>` : ""}<div class="row"><button class="btn ${p.chosen === p.a ? "" : "secondary"}" data-bin="${esc(p.a)}" ${p.chosen ? "disabled" : ""}>${esc(p.a).toUpperCase()}</button><button class="btn ${p.chosen === p.b ? "" : "secondary"}" data-bin="${esc(p.b)}" ${p.chosen ? "disabled" : ""}>${esc(p.b).toUpperCase()}</button></div>`;
        break;
      case "vote":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.title)}</div><div class="options votes ${p.chosen ? "locked" : ""}">${p.options.map((o, i) => `<button class="opt ${p.chosen === o.id ? "chosen" : ""}" data-i="${i}" data-vote="${esc(o.id)}"><span class="letter">${o.emoji || "•"}</span><span>${esc(o.label)}</span><span class="count">${o.count || ""}</span></button>`).join("")}</div>`;
        break;
      case "explain":
        html = `${timerHtml(p.deadline)}<div class="explain"><h2>${esc(p.title)}</h2><p>${esc(p.text)}</p><div class="row"><button class="btn" id="readyBtn" ${p.ready ? "disabled" : ""}>${p.ready ? "✔ Bereit" : "Bereit!"}</button><button class="btn secondary" id="strikeBtn" ${p.streik ? "disabled" : ""}>✊ Streik</button></div></div>`;
        break;
      case "actions":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.title)}</div>${p.lines.map(l => `<p class="muted" style="white-space:pre-line">${esc(l)}</p>`).join("")}<div class="options">${p.buttons.map(b => `<button class="btn ${b.style === "primary" ? "" : b.style} small" data-btn="${esc(b.id)}" ${b.enabled ? "" : "disabled"} style="width:100%">${esc(b.label)}</button>`).join("")}</div>`;
        break;
      case "cards":
        html = `${timerHtml(p.deadline)}<div class="question">${esc(p.title)}</div>${p.hint ? `<p class="muted">${esc(p.hint)}</p>` : ""}<div class="hand">${p.cards.map(c => { const [f, w] = c.text.split(" "); return `<button class="ucard ${colorClass(f)} ${c.removed ? "removed" : ""}" data-id="${c.id}" ${c.removed ? "disabled" : ""}>${esc(w || "")}</button>`; }).join("")}</div>
          <div class="row" style="margin-top:12px">${p.buttons.map(b => `<button class="btn ${b.style === "primary" ? "" : b.style} small" data-btn="${esc(b.id)}" ${b.enabled ? "" : "disabled"}>${esc(b.label)}</button>`).join("")}</div>`;
        break;
      case "feedback":
        html = `<h2>📝 Presse-Stimmen</h2>${p.questions.map((q, i) => `<label class="f">${esc(q)}</label><input type="text" id="fb${i}" maxlength="80">`).join("")}<button class="btn" id="fbSend" style="margin-top:12px">Abschicken</button>`;
        break;
      default:
        html = `<div class="idle"><h2>${esc(p.kind)}</h2></div>`;
    }
    main.innerHTML = html;
    main.querySelectorAll("[data-avatar]").forEach(h => renderAvatar(h, h.dataset.avatar));
    bind(p);
    startTimers();
  }

  function colorClass(emoji) { return { "🔴": "rot", "🟡": "gelb", "🟢": "gruen", "🔵": "blau", "⚫": "schwarz" }[emoji] || "schwarz"; }
  function fmtNum(v) { return Number.isInteger(v) ? v.toLocaleString("de-DE") : Number(v).toFixed(1); }

  function bind(p) {
    const main = $("main");
    main.querySelectorAll(".opt[data-id]").forEach(b => b.onclick = () => {
      if (p.kind === "multiChoice") { const id = Number(b.dataset.id); const set = new Set(p.chosen); set.has(id) ? set.delete(id) : set.add(id); send({ type: "multiChoose", list: [...set] }); return; }
      send({ type: "choose", value: Number(b.dataset.id) });
    });
    main.querySelectorAll(".opt[data-vote]").forEach(b => b.onclick = () => send({ type: "vote", value: b.dataset.vote }));
    main.querySelectorAll("[data-pid]").forEach(b => b.onclick = () => send({ type: "pickPlayer", id: b.dataset.pid }));
    main.querySelectorAll("[data-bin]").forEach(b => b.onclick = () => send({ type: "binary", value: b.dataset.bin }));
    main.querySelectorAll("[data-btn]").forEach(b => b.onclick = () => send({ type: "button", id: b.dataset.btn }));
    main.querySelectorAll(".ucard[data-id]").forEach(b => b.onclick = () => send({ type: "choose", value: Number(b.dataset.id) }));
    const buzz = $("buzz"); if (buzz) buzz.onclick = () => send({ type: "buzz", at: serverNow() });
    const bank = $("bankBtn"); if (bank) bank.onclick = () => { send({ type: "bank" }); toast("BANK! gedrückt"); };
    const cheer = $("cheerBtn"); if (cheer) cheer.onclick = () => send({ type: "cheer" });
    const conf = $("confirmBtn"); if (conf) conf.onclick = () => send({ type: "confirm" });
    const ready = $("readyBtn"); if (ready) ready.onclick = () => send({ type: "ready", value: "bereit" });
    const strike = $("strikeBtn"); if (strike) strike.onclick = () => { if (confirm("Streik: das Minispiel entfällt bei Mehrheit — ersatzweise eine Blitzfrage.")) send({ type: "ready", value: "streik" }); };
    const num = $("num");
    if (num) {
      const val = $("numVal"), direct = $("numDirect");
      const show = () => { val.textContent = p.kind === "wager" ? fmtMM(Number(num.value)) : fmtNum(Number(num.value)); if (direct) direct.value = num.value; };
      num.oninput = show;
      if (direct) direct.oninput = () => { num.value = direct.value; val.textContent = fmtNum(Number(num.value)); };
      main.querySelectorAll("[data-d]").forEach(b => b.onclick = () => { num.value = Math.min(p.max, Math.max(p.min, Number(num.value) + Number(b.dataset.d) * Number(p.step))); show(); });
      $("lockNum").onclick = () => send(p.kind === "wager" ? { type: "wager", value: Number(num.value) } : { type: "number", value: Number(num.value) });
    }
    main.querySelectorAll("[data-mv]").forEach(b => b.onclick = () => {
      const pos = Number(b.dataset.pos), to = pos + Number(b.dataset.mv);
      if (to < 0 || to >= orderState.length) return;
      [orderState[pos], orderState[to]] = [orderState[to], orderState[pos]];
      $("main").dataset.key = "";
      renderPrompt(p);
      send({ type: "order", list: orderState });
    });
    const lockOrder = $("lockOrder"); if (lockOrder) lockOrder.onclick = () => { send({ type: "order", list: orderState }); send({ type: "confirm" }); };
    main.querySelectorAll("[data-ch]").forEach(b => b.onclick = () => {
      const i = Number(b.dataset.i), d = Number(b.dataset.ch);
      const used = chipsState.reduce((a, c) => a + c, 0);
      if (d > 0 && used >= p.total) return;
      chipsState[i] = Math.max(0, (chipsState[i] || 0) + d);
      $("main").dataset.key = "";
      renderPrompt(p);
    });
    const lockChips = $("lockChips"); if (lockChips) lockChips.onclick = () => { send({ type: "chips", list: chipsState }); send({ type: "confirm" }); };
    const txt = $("sendTxt"); if (txt) txt.onclick = () => { const v = $("txt").value.trim(); if (v) send({ type: "text", value: v }); };
    const frenzy = $("frenzy");
    if (frenzy) {
      let pending = 0;
      frenzy.onpointerdown = e => { e.preventDefault(); taps++; pending++; $("tapCount").textContent = taps; };
      clearInterval(frenzy._iv);
      frenzy._iv = setInterval(() => { if (pending) { conn.send({ t: "action", action: { type: "taps", value: pending } }); pending = 0; } }, 1000);
    }
    const fb = $("fbSend"); if (fb) fb.onclick = () => send({ type: "feedback", list: p.questions.map((_, i) => $("fb" + i).value) });
  }
})();
