// Web Audio engine for the stage: looping music beds with crossfade and
// ducking, one-shot SFX with rate limiting and variants, song snippets.
// Everything the engine plays is also appended to `window.__mmAudio` so the
// sound direction can be verified from a test browser.

const BASE = "/media/audio";
const log = (window.__mmAudio = window.__mmAudio || []);

class AudioEngine {
  constructor() {
    this.ctx = null;
    this.buffers = new Map(); // url -> Promise<AudioBuffer|null>
    this.musicCue = null;
    this.music = null; // {src, gain, cue}
    this.duckFactor = 1;
    this.duckTimer = null;
    this.volume = Number(localStorage.getItem("mm:vol") ?? 0.8);
    this.musicOn = localStorage.getItem("mm:music") !== "0";
    this.sfxOn = localStorage.getItem("mm:sfx") !== "0";
    this.lastSfx = new Map();
    this.roundRobin = new Map();
    this.pendingMusic = null;
    this.snippet = null;
    this.listeners = new Set();
  }

  get unlocked() { return !!this.ctx && this.ctx.state === "running"; }

  ensure() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = this.volume;
      this.master.connect(this.ctx.destination);
      this.musicBus = this.ctx.createGain();
      this.musicBus.gain.value = 0.55;
      this.musicBus.connect(this.master);
      this.sfxBus = this.ctx.createGain();
      this.sfxBus.gain.value = 1;
      this.sfxBus.connect(this.master);
      this.ctx.onstatechange = () => this.emit();
    }
    return this.ctx;
  }

  /** Call from a user gesture (iOS/WebKit start suspended). */
  async unlock() {
    const ctx = this.ensure();
    if (!ctx) return false;
    try { await ctx.resume(); } catch (_) {}
    // A silent buffer primes iOS output.
    try { const b = ctx.createBuffer(1, 1, 22050); const s = ctx.createBufferSource(); s.buffer = b; s.connect(ctx.destination); s.start(0); } catch (_) {}
    this.emit();
    if (this.musicCue && !this.music) { const c = this.musicCue; this.musicCue = null; this.playMusic(c); }
    return ctx.state === "running";
  }

  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  emit() { for (const f of this.listeners) try { f(); } catch (_) {} }

  setVolume(v) { this.volume = v; localStorage.setItem("mm:vol", v); if (this.master) this.master.gain.setTargetAtTime(v, this.ctx.currentTime, 0.05); this.emit(); }
  setMusicOn(on) { this.musicOn = on; localStorage.setItem("mm:music", on ? "1" : "0"); if (!on) this.stopMusic(); this.emit(); }
  setSfxOn(on) { this.sfxOn = on; localStorage.setItem("mm:sfx", on ? "1" : "0"); this.emit(); }

  load(url) {
    if (!this.buffers.has(url)) {
      const ctx = this.ensure();
      const p = fetch(url)
        .then(r => (r.ok ? r.arrayBuffer() : Promise.reject(new Error(r.status))))
        .then(ab => new Promise((res, rej) => ctx.decodeAudioData(ab, res, rej)))
        .catch(err => { log.push({ t: Date.now(), kind: "error", id: url, err: String(err) }); return null; });
      this.buffers.set(url, p);
      // Keep memory in check: drop decoded music beds we are not using.
      const music = [...this.buffers.keys()].filter(k => k.includes("/Music/") || k.includes("/Beds/"));
      if (music.length > 4) this.buffers.delete(music.find(k => !this.music || !k.endsWith(`/${this.music.cue}.m4a`)));
    }
    return this.buffers.get(url);
  }

  preload(ids) { if (!this.ctx) return; for (const id of ids) this.load(`${BASE}/SFX/${id}.m4a`); }

  // ---------- music ----------
  playMusic(cue, { afterMs = 0 } = {}) {
    clearTimeout(this.pendingMusic);
    if (afterMs > 0) { this.pendingMusic = setTimeout(() => this.playMusic(cue), afterMs); return; }
    if (!cue || !this.musicOn) { this.stopMusic(); this.musicCue = cue || null; return; }
    if (this.music && this.music.cue === cue) return;
    this.musicCue = cue;
    if (!this.unlocked) return; // started on unlock
    const url = `${BASE}/Music/${cue}.m4a`;
    log.push({ t: Date.now(), kind: "music", id: cue });
    this.load(url).then(buf => {
      if (!buf || this.musicCue !== cue || (this.music && this.music.cue === cue)) return;
      const ctx = this.ctx;
      const src = ctx.createBufferSource();
      src.buffer = buf;
      src.loop = true;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, ctx.currentTime);
      g.gain.exponentialRampToValueAtTime(this.duckFactor || 0.0001, ctx.currentTime + 1.2);
      src.connect(g).connect(this.musicBus);
      src.start();
      const old = this.music;
      this.music = { src, gain: g, cue };
      if (old) this.fadeOut(old, 1.0);
    });
  }

  fadeOut(m, secs = 0.8) {
    try {
      const t = this.ctx.currentTime;
      m.gain.gain.cancelScheduledValues(t);
      m.gain.gain.setValueAtTime(Math.max(0.0001, m.gain.gain.value), t);
      m.gain.gain.exponentialRampToValueAtTime(0.0001, t + secs);
      m.src.stop(t + secs + 0.05);
    } catch (_) {}
  }

  stopMusic() {
    clearTimeout(this.pendingMusic);
    if (this.music) { this.fadeOut(this.music, 0.6); this.music = null; }
  }

  /** Lower the bed (0…1), optionally only for `forMs`. */
  duck(factor, forMs) {
    clearTimeout(this.duckTimer);
    this.duckFactor = factor;
    if (this.music && this.ctx) {
      const t = this.ctx.currentTime;
      this.music.gain.gain.cancelScheduledValues(t);
      this.music.gain.gain.setTargetAtTime(Math.max(0.0001, factor), t, 0.12);
    }
    if (forMs) this.duckTimer = setTimeout(() => this.duck(1), forMs);
  }

  // ---------- sfx ----------
  sfx(id, { gain = 1, rateLimitMs = 110, rate = 1 } = {}) {
    if (!this.sfxOn) return;
    const now = performance.now();
    if (now - (this.lastSfx.get(id) || -1e9) < rateLimitMs) return;
    this.lastSfx.set(id, now);
    log.push({ t: Date.now(), kind: "sfx", id });
    if (!this.unlocked) return;
    this.load(`${BASE}/SFX/${id}.m4a`).then(buf => {
      if (!buf) return;
      const src = this.ctx.createBufferSource();
      src.buffer = buf;
      src.playbackRate.value = rate;
      const g = this.ctx.createGain();
      g.gain.value = gain;
      src.connect(g).connect(this.sfxBus);
      src.start();
    });
  }

  variant(family, ids, opts) {
    const i = ((this.roundRobin.get(family) ?? -1) + 1) % ids.length;
    this.roundRobin.set(family, i);
    this.sfx(ids[i], opts);
  }

  // ---------- song snippets (music formats) ----------
  playSnippet(songId, snippet) {
    this.stopSnippet();
    log.push({ t: Date.now(), kind: "snippet", id: `${songId}/${snippet}` });
    if (!this.unlocked) return;
    const url = `${BASE}/Songs/${songId}/${snippet}.m4a`;
    const bedTrack = String(songId).startsWith("s_bett_");
    (bedTrack ? Promise.resolve(null) : this.load(url)).then(async buf => {
      // Songs without cut snippets (the bed tracks) are cut and, for „rückwärts“, reversed here.
      if (!buf) buf = await this.cutFromBed(songId, snippet);
      if (!buf) return;
      const src = this.ctx.createBufferSource();
      src.buffer = buf;
      const g = this.ctx.createGain();
      g.gain.value = 1;
      src.connect(g).connect(this.master);
      src.start();
      this.snippet = src;
      src.onended = () => { if (this.snippet === src) this.snippet = null; this.buffers.delete(url); };
    });
  }

  async cutFromBed(songId, snippet) {
    const bed = await this.load(`${BASE}/Beds/${songId}.m4a`);
    if (!bed) return null;
    const name = String(snippet);
    const secs = Math.max(1, Math.min(15, Number((name.match(/(\d+)s/) || [])[1] || 5)));
    const start = name.startsWith("intro") ? 0 : Math.max(0, Math.min(bed.duration - secs, bed.duration * 0.35));
    const len = Math.min(Math.floor(secs * bed.sampleRate), bed.length);
    const off = Math.min(Math.floor(start * bed.sampleRate), bed.length - len);
    const out = this.ctx.createBuffer(bed.numberOfChannels, len, bed.sampleRate);
    const rev = name.includes("rueckwaerts");
    for (let c = 0; c < bed.numberOfChannels; c++) {
      const src = bed.getChannelData(c).subarray(off, off + len), dst = out.getChannelData(c);
      if (rev) for (let i = 0; i < src.length; i++) dst[i] = src[src.length - 1 - i]; else dst.set(src);
    }
    return out;
  }

  stopSnippet() { try { this.snippet && this.snippet.stop(); } catch (_) {} this.snippet = null; }
}

export const audio = new AudioEngine();
window.__mmAudioEngine = audio;
