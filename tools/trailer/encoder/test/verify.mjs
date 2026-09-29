// Verify an encode.mjs MP4 in Chromium: box structure, <video> metadata,
// frame-accurate seeks (PNG + barcode decode), decodeAudioData RMS, play().
//   env -u NODE_OPTIONS node tools/trailer/encoder/test/verify.mjs FILE.mp4 [--fps 30] [--duration 5] [--width 1280 --height 720]
//        [--seek 0.5,2.5,4.5] [--png-dir DIR]
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";
import { launch } from "../../../web/lib.mjs";
import { start } from "../server.mjs";
import { inspect } from "./mp4dump.mjs";

const arg = (k, d) => { const i = process.argv.indexOf(`--${k}`); return i > 0 ? process.argv[i + 1] : d; };
const FILE = path.resolve(process.argv[2]);
const FPS = Number(arg("fps", 30)), DUR = Number(arg("duration", 5));
const W = arg("width") && Number(arg("width")), H = arg("height") && Number(arg("height"));
const SEEKS = arg("seek", "0.5,2.5,4.5").split(",").map(Number);
const PNG = path.resolve(arg("png-dir", path.dirname(FILE)));
const base = path.basename(FILE, ".mp4");
const results = [];
const check = (name, ok, detail) => { results.push({ name, ok }); console.log(`${ok ? "PASS" : "FAIL"}  ${name}: ${detail}`); };

// 1. structure
const bytes = new Uint8Array(readFileSync(FILE));
const info = inspect(bytes);
const vt = info.tracks.find(t => t.handler === "vide"), at = info.tracks.find(t => t.handler === "soun");
console.log(`file ${FILE}: ${bytes.length} bytes, boxes ${info.top.join(" ")}`);
check("faststart (moov before mdat)", info.moovBeforeMdat, info.top.join(" "));
check("mvhd duration", Math.abs(info.seconds - DUR) < 0.05, `${info.movieDuration}/${info.movieTimescale} = ${info.seconds} s`);
check("video track", !!vt && vt.entry === "avc1" && vt.samplesOutsideMdat === 0 && vt.samplesMapped === vt.samples,
  vt && `${vt.samples} samples, ts ${vt.timescale}, mdhd ${vt.mediaDuration} (${vt.mediaDuration / vt.timescale} s), tkhd ${vt.tkhdDuration}, ` +
  `${vt.width}x${vt.height}, avcC profile ${vt.avcC.profile} level ${vt.avcC.level}, extra [${vt.extra}], stts ${JSON.stringify(vt.stts)}, ` +
  `stss ${vt.stss ? vt.stss.length : "none"} [${(vt.stss || []).slice(0, 4)}…], ${vt.chunkOffsets.length} chunks (${vt.chunkBox}), elst ${JSON.stringify(vt.elst)}, first NAL type ${vt.firstNalType}`);
if (at) {
  check("audio track (Opus/dOps)", at.entry === "Opus" && at.dOps.version === 0 && at.dOps.outputChannelCount === 2 && at.samplesOutsideMdat === 0 &&
    at.timescale === 48000 && at.volume === 0x100 && at.elst.mediaTime === at.dOps.preSkip && at.stts.every(([, d]) => d === 960),
    `${at.samples} packets, stts ${JSON.stringify(at.stts)}, mdhd ${at.mediaDuration}, tkhd ${at.tkhdDuration}, dOps ${JSON.stringify(at.dOps)}, ` +
    `entry ch ${at.channelcount}/${at.samplesize} bit/${at.samplerate} Hz, elst ${JSON.stringify(at.elst)}, ${at.chunkOffsets.length} chunks`);
}

// 2. browser
const srv = await start({
  mounts: { "/f/": path.dirname(FILE) },
  handle(req, res, url, p) { if (p === "/") { res.writeHead(200, { "Content-Type": "text/html" }); res.end("<!doctype html><title>verify</title><body></body>"); return true; } return false; },
});
const browser = await launch();
try {
  const page = await browser.newPage();
  page.on("pageerror", e => console.log("[page error]", e.message));
  await page.goto(srv.url + "/");
  const r = await page.evaluate(async ({ src, SEEKS, FPS }) => {
    const out = { canPlay: document.createElement("video").canPlayType('video/mp4; codecs="avc1.640028, opus"') };
    const v = document.createElement("video");
    v.preload = "auto"; v.playsInline = true; document.body.appendChild(v);
    const once = (el, ev, ms = 10000) => new Promise((res, rej) => {
      const to = setTimeout(() => rej(new Error(`timeout waiting for ${ev}`)), ms);
      el.addEventListener(ev, () => { clearTimeout(to); res(); }, { once: true });
      el.addEventListener("error", () => { clearTimeout(to); rej(new Error(`media error ${el.error && el.error.code}: ${el.error && el.error.message}`)); }, { once: true });
    });
    v.src = src;
    await once(v, "loadedmetadata");
    Object.assign(out, { duration: v.duration, videoWidth: v.videoWidth, videoHeight: v.videoHeight });
    const c = document.createElement("canvas"); c.width = v.videoWidth; c.height = v.videoHeight;
    const g = c.getContext("2d", { willReadFrequently: true });
    const s = c.height / 720, B = Math.round(32 * s), y = c.height - 14 * s - B - 8 * s;
    out.seeks = [];
    for (const t of SEEKS) {
      const frameShown = new Promise(res => (v.requestVideoFrameCallback ? v.requestVideoFrameCallback((_, m) => res(m.mediaTime)) : res(null)));
      v.currentTime = t;
      await once(v, "seeked");
      const mediaTime = await Promise.race([frameShown, new Promise(r => setTimeout(() => r(null), 1000))]);
      g.drawImage(v, 0, 0);
      let code = 0;
      for (let k = 0; k < 12; k++) {
        const px = g.getImageData(Math.round(8 * s + k * B + B / 2), Math.round(y + B / 2), 1, 1).data;
        code = (code << 1) | ((px[0] + px[1] + px[2]) / 3 > 128 ? 1 : 0);
      }
      out.seeks.push({ t, currentTime: v.currentTime, mediaTime, barcode: code, expected: Math.round(t * FPS), png: c.toDataURL("image/png") });
    }
    // play for 1 s
    v.currentTime = 0; await once(v, "seeked");
    const before = v.currentTime; let playErr = null;
    try { await v.play(); } catch (e) { playErr = String(e); v.muted = true; await v.play(); }
    const t0 = performance.now();
    await new Promise(r => setTimeout(r, 1000));
    Object.assign(out, { play: { before, after: v.currentTime, wall: (performance.now() - t0) / 1000, muted: v.muted, playErr,
      audioDecodedBytes: v.webkitAudioDecodedByteCount, videoDecodedBytes: v.webkitVideoDecodedByteCount, droppedFrames: v.getVideoPlaybackQuality?.().droppedVideoFrames } });
    v.pause();
    // decodeAudioData on the raw mp4 bytes
    const buf = await (await fetch(src)).arrayBuffer();
    const ctx = new OfflineAudioContext(2, 48000, 48000);
    try {
      const ab = await ctx.decodeAudioData(buf);
      const ch = [...Array(ab.numberOfChannels).keys()].map(i => ab.getChannelData(i));
      const rms = (a, b) => { let s2 = 0, n = 0; for (const d of ch) for (let i = a; i < Math.min(b, d.length); i++) { s2 += d[i] * d[i]; n++; } return Math.sqrt(s2 / Math.max(1, n)); };
      const perSecond = []; for (let i = 0; i * ab.sampleRate < ab.length; i++) perSecond.push(+rms(i * ab.sampleRate, (i + 1) * ab.sampleRate).toFixed(4));
      // onset of the first non-silent sample (checks pre-skip trimming roughly)
      let first = -1; for (let i = 0; i < ch[0].length; i++) if (Math.abs(ch[0][i]) > 1e-3) { first = i; break; }
      out.audio = { duration: ab.duration, sampleRate: ab.sampleRate, channels: ab.numberOfChannels, length: ab.length, rms: rms(0, ab.length), perSecond, firstSoundSample: first };
    } catch (e) { out.audio = { error: String(e) }; }
    return out;
  }, { src: `/f/${encodeURIComponent(path.basename(FILE))}`, SEEKS, FPS });

  console.log(`canPlayType('video/mp4; codecs="avc1.640028, opus"') = "${r.canPlay}"`);
  check("(b) loadedmetadata duration", Math.abs(r.duration - DUR) < 0.05, `${r.duration} s`);
  check("(b) video size", (!W || r.videoWidth === W) && (!H || r.videoHeight === H), `${r.videoWidth}x${r.videoHeight}`);
  mkdirSync(PNG, { recursive: true });
  for (const s of r.seeks) {
    const f = path.join(PNG, `${base}-seek-${s.t.toFixed(1)}.png`);
    writeFileSync(f, Buffer.from(s.png.split(",")[1], "base64"));
    check(`(b) seek ${s.t}s`, s.barcode === s.expected, `currentTime ${s.currentTime}, rVFC mediaTime ${s.mediaTime}, barcode frame ${s.barcode} (expected ${s.expected}) → ${f}`);
  }
  if (at) {
    const a = r.audio;
    check("(c) decodeAudioData", !a.error && Math.abs(a.duration - DUR) < 0.05 && a.rms > 0,
      a.error || `duration ${a.duration.toFixed(4)} s (${a.length} samples @ ${a.sampleRate} Hz, ${a.channels} ch), RMS ${a.rms.toFixed(4)}, per-second RMS [${a.perSecond}], first sound @ sample ${a.firstSoundSample}`);
  }
  const p = r.play;
  check("(d) play() advances", p.after - p.before > 0.8, `currentTime ${p.before.toFixed(3)} → ${p.after.toFixed(3)} in ${p.wall.toFixed(2)} s wall` +
    ` (muted ${p.muted}${p.playErr ? ", " + p.playErr : ""}), decoded bytes video ${p.videoDecodedBytes} / audio ${p.audioDecodedBytes}, dropped ${p.droppedFrames}`);
} finally {
  await browser.close();
  await srv.close();
}
const failed = results.filter(r => !r.ok);
console.log(failed.length ? `\n${failed.length} check(s) FAILED` : `\nall ${results.length} checks passed`);
process.exit(failed.length ? 1 : 0);
