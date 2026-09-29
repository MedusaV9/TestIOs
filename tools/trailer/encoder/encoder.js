// Encoder page logic (runs in headless Chromium, secure context required):
// JPEG frames → VideoEncoder (H.264) · cue list → OfflineAudioContext mix →
// AudioEncoder (Opus) · muxMP4 → POST the finished file back to the Node CLI.
import { muxMP4 } from "./mp4mux.js";

const log = (...a) => console.log("[enc]", ...a);
const SR = 48000;
const OPUS_FRAME = 960; // 20 ms @ 48 kHz

const toU8 = d => (d instanceof ArrayBuffer ? new Uint8Array(d.slice(0))
  : new Uint8Array(d.buffer.slice(d.byteOffset, d.byteOffset + d.byteLength)));

/** Resolve when the encoder's queue is ≤ max (uses 'dequeue' + a polling fallback). */
function drain(enc, max) {
  if (enc.encodeQueueSize <= max) return Promise.resolve();
  return new Promise(res => {
    const check = () => {
      if (enc.encodeQueueSize > max && enc.state === "configured") return;
      enc.removeEventListener("dequeue", check); clearInterval(iv); res();
    };
    enc.addEventListener("dequeue", check);
    const iv = setInterval(check, 10);
  });
}

/** Media timescale + ticks per frame that represent `fps` exactly where possible. */
export function timebase(fps) {
  if (Number.isInteger(90000 / fps)) return { timescale: 90000, tick: 90000 / fps };
  const ntsc = fps * 1.001;
  if (Math.abs(ntsc - Math.round(ntsc)) < 1e-6) return { timescale: Math.round(ntsc) * 1000, tick: 1001 };
  return { timescale: Math.round(fps * 1000), tick: 1000 };
}

/** Smallest H.264 High level ≥ 4.0 that fits frame size and macroblock rate. */
function autoAvcCodec(width, height, fps) {
  const mbs = Math.ceil(width / 16) * Math.ceil(height / 16);
  const levels = [[0x28, 8192, 245760], [0x2a, 8704, 522240], [0x32, 22080, 589824], [0x33, 36864, 983040], [0x34, 36864, 2073600]];
  const hit = levels.find(([, fs, mbps]) => mbs <= fs && mbs * fps <= mbps) || levels[levels.length - 1];
  return "avc1.6400" + hit[0].toString(16).padStart(2, "0");
}

// ─── audio ──────────────────────────────────────────────────────────────────

async function mixAudio(a) {
  const duration = a.duration;
  const length = Math.round(duration * SR);
  const ctx = new OfflineAudioContext({ numberOfChannels: 2, length, sampleRate: SR });
  const cache = new Map();
  const load = url => {
    if (!cache.has(url)) {
      cache.set(url, fetch(url).then(r => { if (!r.ok) throw new Error(`${url}: HTTP ${r.status}`); return r.arrayBuffer(); })
        .then(b => ctx.decodeAudioData(b)).catch(e => { throw new Error(`audio ${url}: ${e.message || e}`); }));
    }
    return cache.get(url);
  };
  const bufs = await Promise.all(a.cues.map(c => load(c.url)));

  const m = a.master || {};
  const master = ctx.createGain();
  if (m.limiter === false) master.connect(ctx.destination);
  else {
    // Gentle limiter: only peaks above ~-4 dBFS get squeezed (Chrome adds a little makeup gain).
    const lim = ctx.createDynamicsCompressor();
    const L = { threshold: -4, knee: 4, ratio: 12, attack: 0.003, release: 0.25, ...(m.limiter || {}) };
    for (const k of ["threshold", "knee", "ratio", "attack", "release"]) lim[k].value = L[k];
    master.connect(lim).connect(ctx.destination);
  }
  const mg = m.gain ?? 1;
  const mfi = m.fadeIn || 0, mfo = m.fadeOut || 0;
  master.gain.setValueAtTime(mfi > 0 ? 0 : mg, 0);
  if (mfi > 0) master.gain.linearRampToValueAtTime(mg, mfi);
  if (mfo > 0) { master.gain.setValueAtTime(mg, Math.max(mfi, duration - mfo)); master.gain.linearRampToValueAtTime(0, duration); }

  a.cues.forEach((c, i) => {
    const buf = bufs[i];
    const rate = c.rate ?? 1;
    const at = c.at ?? 0;
    let offset = c.offset ?? 0, start = at;
    if (start < 0) { offset += -start * rate; start = 0; }
    const natural = c.loop ? Infinity : Math.max(0, (buf.duration - offset) / rate);
    const end = Math.min(duration, c.dur != null ? at + c.dur : Infinity, start + natural);
    if (!(end > start)) { log(`cue ${i} (${c.src}) is outside the timeline – skipped`); return; }
    const src = ctx.createBufferSource();
    src.buffer = buf; src.playbackRate.value = rate; src.loop = !!c.loop;
    const g = ctx.createGain();
    const gain = c.gain ?? 1, fi = c.fadeIn || 0, fo = c.fadeOut || 0;
    if (fi > 0) { g.gain.setValueAtTime(0, start); g.gain.linearRampToValueAtTime(gain, start + fi); }
    else g.gain.setValueAtTime(gain, start);
    if (fo > 0) { g.gain.setValueAtTime(gain, Math.max(start + fi, end - fo)); g.gain.linearRampToValueAtTime(0, end); }
    src.connect(g).connect(master);
    src.start(start, offset);
    src.stop(end);
  });

  const rendered = await ctx.startRendering();
  const pcm = [rendered.getChannelData(0), rendered.getChannelData(1)];
  let peak = 0, sum = 0, clipped = 0;
  for (const ch of pcm) {
    for (let i = 0; i < ch.length; i++) {
      let v = ch[i];
      if (v > 0.999 || v < -0.999) { clipped++; v = ch[i] = v > 0 ? 0.999 : -0.999; }
      const av = Math.abs(v); if (av > peak) peak = av; sum += v * v;
    }
  }
  const rms = Math.sqrt(sum / (2 * length));
  return { pcm, length, peak, rms, clipped };
}

async function encodeOpus(pcm, length, bitrate) {
  const packets = []; let desc = null, err = null, odd = 0;
  const enc = new AudioEncoder({
    output(chunk, meta) {
      if (!desc && meta?.decoderConfig?.description) desc = toU8(meta.decoderConfig.description);
      if (chunk.duration && Math.abs(chunk.duration - 20000) > 1) odd++;
      const d = new Uint8Array(chunk.byteLength); chunk.copyTo(d);
      packets.push({ data: d, dur: OPUS_FRAME });
    },
    error(e) { err = e; },
  });
  const cfg = { codec: "opus", sampleRate: SR, numberOfChannels: 2, bitrate };
  const sup = await AudioEncoder.isConfigSupported(cfg);
  if (!sup.supported) throw new Error("AudioEncoder: opus not supported");
  enc.configure(cfg);
  // Feed the mix plus 80 ms of silence so pre-skip + the full duration are covered.
  const total = length + 4 * OPUS_FRAME;
  for (let pos = 0; pos < total; pos += OPUS_FRAME) {
    const data = new Float32Array(2 * OPUS_FRAME);
    const n = Math.max(0, Math.min(OPUS_FRAME, length - pos));
    if (n > 0) for (let ch = 0; ch < 2; ch++) data.set(pcm[ch].subarray(pos, pos + n), ch * OPUS_FRAME);
    const ad = new AudioData({ format: "f32-planar", sampleRate: SR, numberOfFrames: OPUS_FRAME, numberOfChannels: 2,
      timestamp: Math.round((pos * 1e6) / SR), data });
    await drain(enc, 32);
    enc.encode(ad); ad.close();
    if (err) throw err;
  }
  await enc.flush();
  if (err) throw err;
  enc.close();

  let preSkip = 312, head = "none";
  if (desc && desc.length >= 19 && String.fromCharCode(...desc.subarray(0, 8)) === "OpusHead") {
    preSkip = desc[10] | (desc[11] << 8); head = "OpusHead";
  }
  const keep = Math.ceil((preSkip + length) / OPUS_FRAME);
  if (packets.length < keep) log(`warning: only ${packets.length} opus packets, need ${keep}`);
  packets.length = Math.min(packets.length, keep);
  if (odd) log(`warning: ${odd} opus packets with duration ≠ 20 ms`);
  return { packets, preSkip, head };
}

// ─── video ──────────────────────────────────────────────────────────────────

async function encodeVideo(job, progress) {
  const { fps, frames } = job;
  const n = frames.length;
  const { timescale, tick } = timebase(fps);
  const fetchBlob = async url => { const r = await fetch(url); if (!r.ok) throw new Error(`${url}: HTTP ${r.status}`); return r.blob(); };

  const firstBlob = await fetchBlob(frames[0]);
  const probe = await createImageBitmap(firstBlob);
  const srcW = probe.width, srcH = probe.height; probe.close();
  const width = job.width || srcW & ~1, height = job.height || srcH & ~1;
  const resize = srcW !== width || srcH !== height ? { resizeWidth: width, resizeHeight: height, resizeQuality: "high" } : undefined;

  const base = { width, height, bitrate: job.bitrate, framerate: fps, avc: { format: "avc" }, latencyMode: "quality" };
  const candidates = [...new Set([job.codec || "avc1.640028", autoAvcCodec(width, height, fps)])];
  let config = null;
  for (const codec of candidates) {
    const s = await VideoEncoder.isConfigSupported({ ...base, codec });
    if (s.supported) { config = { ...base, codec }; break; }
    log(`${codec} ${width}x${height}@${fps} not supported`);
  }
  if (!config) throw new Error("no supported H.264 configuration");

  const out = []; let desc = null, colorSpace = null, err = null;
  const enc = new VideoEncoder({
    output(chunk, meta) {
      const dc = meta?.decoderConfig;
      if (dc?.description) desc = toU8(dc.description);
      if (dc?.colorSpace) colorSpace = { ...dc.colorSpace };
      const d = new Uint8Array(chunk.byteLength); chunk.copyTo(d);
      out.push({ data: d, ts: chunk.timestamp, key: chunk.type === "key" });
    },
    error(e) { err = e; },
  });
  enc.configure(config);

  const keyint = job.keyint || 2 * Math.round(fps);
  const PREFETCH = 6;
  const pending = new Map();
  const t0 = performance.now(); let lastLog = t0;
  for (let i = 0; i < n; i++) {
    for (let j = i; j < Math.min(n, i + PREFETCH); j++) {
      if (!pending.has(j)) {
        const p = (j === 0 ? Promise.resolve(firstBlob) : fetchBlob(frames[j])).then(b => createImageBitmap(b, resize));
        p.catch(() => {});
        pending.set(j, p);
      }
    }
    const bmp = await pending.get(i); pending.delete(i);
    if (bmp.width !== width || bmp.height !== height) throw new Error(`frame ${i}: ${bmp.width}x${bmp.height}, expected ${width}x${height}`);
    const frame = new VideoFrame(bmp, { timestamp: Math.round((i * 1e6) / fps), duration: Math.round(1e6 / fps) });
    bmp.close();
    await drain(enc, 4);
    if (err) throw err;
    enc.encode(frame, { keyFrame: i % keyint === 0 });
    frame.close();
    const now = performance.now();
    if (now - lastLog > 2000 || i === n - 1) { lastLog = now; progress(i + 1, n, (i + 1) / ((now - t0) / 1000)); }
  }
  await enc.flush();
  if (err) throw err;
  enc.close();
  const seconds = (performance.now() - t0) / 1000;
  if (!desc) throw new Error("encoder produced no avcC description");
  if (!out.length || !out[0].key) throw new Error("first video chunk is not a keyframe");

  const samples = out.map(c => ({ data: c.data, pts: Math.round((c.ts * fps) / 1e6) * tick, dur: tick, key: c.key }));
  return { samples, avcC: desc, colorSpace, width, height, timescale, tick, codec: config.codec, seconds, keyint };
}

// ─── job ────────────────────────────────────────────────────────────────────

export async function runJob(job) {
  const T0 = performance.now();
  const stats = { secureContext: window.isSecureContext, userAgent: navigator.userAgent };

  let audio = null;
  if (job.audio) {
    const t = performance.now();
    const mix = await mixAudio(job.audio);
    stats.audioMixMs = Math.round(performance.now() - t);
    const t2 = performance.now();
    const opus = await encodeOpus(mix.pcm, mix.length, job.audio.bitrate || 192000);
    stats.audioEncodeMs = Math.round(performance.now() - t2);
    Object.assign(stats, { audioPeak: +mix.peak.toFixed(4), audioRms: +mix.rms.toFixed(4), audioClipped: mix.clipped,
      opusPackets: opus.packets.length, preSkip: opus.preSkip, opusHead: opus.head });
    log(`audio: ${job.audio.cues.length} cues, ${(mix.length / SR).toFixed(3)} s, peak ${mix.peak.toFixed(3)}, rms ${mix.rms.toFixed(4)}, ` +
      `${opus.packets.length} opus packets, pre-skip ${opus.preSkip} (${opus.head}), mix ${stats.audioMixMs} ms, encode ${stats.audioEncodeMs} ms`);
    audio = { channels: 2, preSkip: opus.preSkip, inputSampleRate: SR, outputGain: 0, presented: mix.length, samples: opus.packets };
  }

  const v = await encodeVideo(job, (i, n, fps) => log(`video ${i}/${n} frames, ${fps.toFixed(1)} fps`));
  Object.assign(stats, { codec: v.codec, width: v.width, height: v.height, frames: v.samples.length, keyframes: v.samples.filter(s => s.key).length,
    keyint: v.keyint, videoEncodeSeconds: +v.seconds.toFixed(3), encodeFps: +(v.samples.length / v.seconds).toFixed(2),
    avcProfile: v.avcC[1], avcLevel: v.avcC[3], colorSpace: v.colorSpace, timescale: v.timescale });

  const mux = muxMP4({ video: v, audio });
  const blob = new Blob(mux.parts, { type: "video/mp4" });
  const r = await fetch(job.postUrl, { method: "POST", body: blob, headers: { "Content-Type": "video/mp4" } });
  if (!r.ok) throw new Error(`upload failed: HTTP ${r.status} ${await r.text()}`);
  Object.assign(stats, { size: mux.size, duration: mux.duration, mux: mux.info, totalSeconds: +((performance.now() - T0) / 1000).toFixed(3) });
  return stats;
}
