/* Shared helpers for the Monkey Money web clients (player + GM). */
window.MM = (() => {
  const MONKEYS = [
    ["don-bananas", "Don Bananas", "der Pate"], ["gitti-giro", "Gitti Giro", "die Buchhalterin"], ["kiki-krawall", "Kiki Krawall", "das Chaos-Äffchen"],
    ["baron-von-bananenstein", "Baron von Bananenstein", "der Adlige"], ["oma-zinseszins", "Oma Zinseszins", "die Sparfüchsin"], ["pumper-paule", "Pumper-Paule", "der Gym-Gorilla"],
    ["schnarch-schorsch", "Schnarch-Schorsch", "der Gemütliche"], ["glitzer-gina", "Glitzer-Gina", "die Diva"], ["dj-trommelfell", "DJ Trommelfell", "der Beat-Affe"],
    ["astro-astrid", "Astro-Astrid", "die Raumfahrerin"], ["kommissar-kokosnuss", "Kommissar Kokosnuss", "der Detektiv"], ["iro-ines", "Iro-Ines", "die Punkerin"],
    ["abraka-dieter", "Abraka-Dieter", "der Zauberer"], ["kahuna-kalle", "Kahuna-Kalle", "der Surfer"],
  ];
  const COLORS = [["gelb", "#FFD34E"], ["rot", "#E53950"], ["gruen", "#7ED957"], ["blau", "#3D7BFF"], ["lila", "#8E5BFF"], ["orange", "#FF8A3D"], ["tuerkis", "#2ED3C6"], ["pink", "#FF6BD6"]];
  const svgCache = {};

  function colorHex(token) {
    if (token && token.startsWith("hex") && token.length === 9) return "#" + token.slice(3);
    const c = COLORS.find(c => c[0] === token);
    return c ? c[1] : COLORS[0][1];
  }

  async function monkeySvg(id) {
    if (!svgCache[id]) {
      svgCache[id] = fetch(`/monkeys/${id}.svg`).then(r => r.ok ? r.text() : "").catch(() => "");
    }
    return svgCache[id];
  }

  /** Render an avatar wire string ("affe.farbe.extras") into a host element. */
  async function renderAvatar(host, wire, face) {
    const parts = (wire || "don-bananas.gelb").split(".");
    const id = MONKEYS.find(m => m[0] === parts[0]) ? parts[0] : "don-bananas";
    const raw = await monkeySvg(id);
    host.innerHTML = raw;
    const svg = host.querySelector("svg");
    if (!svg) return;
    svg.style.setProperty("--fell", colorHex(parts[1] || "gelb"));
    svg.style.setProperty("--fell-hell", lighten(colorHex(parts[1] || "gelb")));
    if (face) svg.dataset.gesicht = face;
    const extras = (parts[2] || "").split("+").filter(Boolean).filter(e => !e.startsWith("lv"));
    for (const e of extras) {
      try {
        const res = await fetch(`/cosmetics/${e}.svg`);
        if (!res.ok) continue;
        const txt = await res.text();
        const doc = new DOMParser().parseFromString(txt, "image/svg+xml");
        const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
        for (const n of [...doc.documentElement.childNodes]) g.appendChild(document.importNode(n, true));
        svg.appendChild(g);
      } catch (_) {}
    }
  }

  function lighten(hex) {
    const n = parseInt(hex.slice(1), 16);
    const r = Math.min(255, (n >> 16) + 70), g = Math.min(255, ((n >> 8) & 255) + 70), b = Math.min(255, (n & 255) + 70);
    return `rgb(${r},${g},${b})`;
  }

  function fmtMM(n) { return `${Number(n || 0).toLocaleString("de-DE")} MM`; }
  function fmtDelta(n) { return n >= 0 ? `+${fmtMM(n)}` : `−${fmtMM(-n)}`; }
  function esc(s) { return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
  function el(html) { const t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstElementChild; }

  /** Decode a PlayerPrompt (Swift enum JSON: {"choice": {...}}) into {kind, ...payload}. */
  function prompt(p) {
    if (!p) return { kind: "idle", title: "…" };
    const kind = Object.keys(p)[0];
    return Object.assign({ kind }, p[kind] || {});
  }

  /** Server-time offset estimation via ping/pong. */
  const clock = { offset: 0, samples: [] };
  function serverNow() { return Date.now() + clock.offset; }
  function addSample(t0, serverTime) {
    const rtt = Date.now() - t0;
    const off = serverTime + rtt / 2 - Date.now();
    clock.samples.push(off);
    if (clock.samples.length > 8) clock.samples.shift();
    const sorted = [...clock.samples].sort((a, b) => a - b);
    clock.offset = sorted[Math.floor(sorted.length / 2)];
  }

  /** Persistent WebSocket with reconnect + hello replay. */
  function connect({ onMessage, onStatus, hello }) {
    let ws, alive = false, retry = 800, pingTimer;
    const url = (location.protocol === "https:" ? "wss://" : "ws://") + location.host + "/ws";
    function open() {
      ws = new WebSocket(url);
      ws.onopen = () => { alive = true; retry = 800; onStatus(true); ws.send(JSON.stringify(hello())); pingTimer = setInterval(() => send({ t: "ping", t0: Date.now() }), 4000); };
      ws.onclose = () => { alive = false; onStatus(false); clearInterval(pingTimer); setTimeout(open, retry); retry = Math.min(6000, retry * 1.6); };
      ws.onerror = () => { try { ws.close(); } catch (_) {} };
      ws.onmessage = ev => {
        let msg; try { msg = JSON.parse(ev.data); } catch (_) { return; }
        if (msg.t === "pong") { addSample(msg.t0, msg.serverTime); return; }
        onMessage(msg);
      };
    }
    function send(obj) { if (alive && ws.readyState === 1) ws.send(JSON.stringify(obj)); }
    open();
    return { send, get alive() { return alive; } };
  }

  function haptic(kind) {
    if (!navigator.vibrate) return;
    if (kind === "success") navigator.vibrate([30, 40, 60]);
    else if (kind === "error") navigator.vibrate([120, 60, 120]);
    else navigator.vibrate(18);
  }

  function deviceToken() {
    let t = localStorage.getItem("mm:device");
    if (!t) { t = Math.random().toString(36).slice(2) + Date.now().toString(36); localStorage.setItem("mm:device", t); }
    return t;
  }

  return { MONKEYS, COLORS, colorHex, renderAvatar, fmtMM, fmtDelta, esc, el, prompt, serverNow, connect, haptic, deviceToken };
})();
