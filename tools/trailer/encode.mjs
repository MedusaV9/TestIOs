// Trailer encoder: JPEG frame sequence (+ audio cue list) → H.264/Opus MP4 (faststart),
// using WebCodecs in headless Chromium (no ffmpeg needed). The MP4 muxer is
// tools/trailer/encoder/mp4mux.js.
//
//   env -u NODE_OPTIONS node tools/trailer/encode.mjs --frames DIR --fps 30 --audio cues.json --out OUT.mp4 \
//       [--bitrate 10000000] [--width 1920 --height 1080] [--audio-bitrate 192000] [--keyint 60] [--codec avc1.640028]
//
// DIR holds 00000.jpg, 00001.jpg … (sorted numerically). --audio none (or omitted) → video only.
// cues.json: { "duration": 28, "sampleRate": 48000, "master": { "gain": 0.9, "fadeIn": 0, "fadeOut": 0.6, "limiter": {…}|false },
//              "cues": [{ "src": "MonkeyMoney/ios/Resources/Audio/Music/theme_main.m4a", "at": 0, "offset": 0, "dur": 28,
//                         "gain": 0.8, "fadeIn": 0.05, "fadeOut": 1.0, "rate": 1, "loop": false }, …] }
// src is relative to the repo root (or the cues.json directory) or absolute; dur/fade*/rate/offset/loop optional.
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch } from "../web/lib.mjs";
import { start, sendJSON, receiveFile } from "./encoder/server.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "../..");

function usage(msg) {
  if (msg) console.error(`error: ${msg}\n`);
  console.error("usage: env -u NODE_OPTIONS node tools/trailer/encode.mjs --frames DIR --fps 30 --audio cues.json|none --out OUT.mp4\n" +
    "         [--bitrate 10000000] [--width W --height H] [--audio-bitrate 192000] [--keyint 2*fps] [--codec avc1.640028]");
  process.exit(msg ? 2 : 0);
}

function parseArgs(argv) {
  const a = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === "-h" || k === "--help") usage();
    if (!k.startsWith("--")) usage(`unexpected argument ${k}`);
    const v = argv[i + 1];
    if (v === undefined || v.startsWith("--")) usage(`missing value for ${k}`);
    a[k.slice(2)] = v; i++;
  }
  return a;
}

const num = (v, name) => {
  if (v === undefined) return undefined;
  const m = /^(\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)$/.exec(v); // e.g. 30000/1001
  const n = m ? Number(m[1]) / Number(m[2]) : Number(v);
  if (!Number.isFinite(n) || n <= 0) usage(`bad ${name}: ${v}`);
  return n;
};

const args = parseArgs(process.argv.slice(2));
if (!args.frames) usage("--frames is required");
if (!args.out) usage("--out is required");
const framesDir = path.resolve(args.frames);
const out = path.resolve(args.out);
const fps = num(args.fps ?? "30", "fps");
const bitrate = Math.round(num(args.bitrate ?? "10000000", "bitrate"));
const width = args.width ? Math.round(num(args.width, "width")) : undefined;
const height = args.height ? Math.round(num(args.height, "height")) : undefined;
if ((width && width % 2) || (height && height % 2)) usage("width/height must be even");
if (!!width !== !!height) usage("give both --width and --height");

if (!existsSync(framesDir) || !statSync(framesDir).isDirectory()) usage(`frames dir not found: ${framesDir}`);
const frameNames = readdirSync(framesDir).filter(f => /^\d+\.jpe?g$/i.test(f)).sort((x, y) => parseInt(x, 10) - parseInt(y, 10));
if (!frameNames.length) usage(`no NNNNN.jpg frames in ${framesDir}`);
const first = parseInt(frameNames[0], 10);
const gap = frameNames.findIndex((f, i) => parseInt(f, 10) !== first + i);
if (gap >= 0) console.warn(`warning: frame numbering has a gap before ${frameNames[gap]} (frames are encoded back to back)`);
const videoDuration = frameNames.length / fps;

// Audio cues → URLs served by the local server.
const audioFiles = {};
let audio = null;
if (args.audio && args.audio !== "none") {
  const cuesPath = path.resolve(args.audio);
  const spec = JSON.parse(readFileSync(cuesPath, "utf8"));
  if (!Array.isArray(spec.cues)) usage(`${cuesPath}: "cues" array missing`);
  if (spec.sampleRate && spec.sampleRate !== 48000) console.warn(`warning: sampleRate ${spec.sampleRate} ignored – Opus/MP4 is always mixed at 48000 Hz`);
  const cues = spec.cues.map((c, i) => {
    if (!c.src) usage(`cue ${i}: src missing`);
    const cands = path.isAbsolute(c.src) ? [c.src] : [path.resolve(REPO, c.src), path.resolve(path.dirname(cuesPath), c.src)];
    const file = cands.find(f => existsSync(f));
    if (!file) usage(`cue ${i}: audio file not found: ${c.src}`);
    const rel = path.relative(REPO, file);
    let url;
    if (!rel.startsWith("..") && !path.isAbsolute(rel)) url = "/repo/" + rel.split(path.sep).map(encodeURIComponent).join("/");
    else { url = `/abs/${i}/${encodeURIComponent(path.basename(file))}`; audioFiles[decodeURIComponent(url)] = file; }
    return { ...c, url };
  });
  const duration = spec.duration ?? videoDuration;
  if (Math.abs(duration - videoDuration) > 0.5 / fps) {
    console.warn(`warning: audio duration ${duration}s ≠ video duration ${videoDuration.toFixed(3)}s`);
  }
  audio = { duration, master: spec.master || {}, cues, bitrate: Math.round(num(args["audio-bitrate"] ?? "192000", "audio-bitrate")) };
}

let resultBytes = 0;
const srv = await start({
  mounts: { "/enc/": path.join(here, "encoder"), "/frames/": framesDir, "/repo/": REPO },
  files: audioFiles,
  async handle(req, res, url, pathname) {
    if (req.method === "POST" && pathname === "/result") {
      resultBytes = await receiveFile(req, out);
      sendJSON(res, { ok: true, bytes: resultBytes });
      return true;
    }
    return false;
  },
});

const job = {
  fps, bitrate, width, height, codec: args.codec, keyint: args.keyint ? Math.round(num(args.keyint, "keyint")) : undefined,
  frames: frameNames.map(f => `/frames/${encodeURIComponent(f)}`), audio, postUrl: "/result",
};

const T0 = Date.now();
const browser = await launch();
let code = 0;
try {
  const page = await browser.newPage();
  page.on("console", m => { const t = m.text(); if (m.type() === "error" || m.type() === "warning" || t.startsWith("[enc]")) console.log(t); });
  page.on("pageerror", e => console.error("[page error]", e.message));
  await page.goto(`${srv.url}/enc/index.html`);
  await page.waitForFunction(() => window.encoderReady === true, null, { timeout: 15000 });
  console.log(`encoding ${frameNames.length} frames @ ${+fps.toFixed(3)} fps (${videoDuration.toFixed(3)} s) from ${framesDir}` +
    (audio ? ` + ${audio.cues.length} audio cues` : " (no audio)"));
  const s = await page.evaluate(j => window.runJob(j), job);
  if (resultBytes !== s.size) throw new Error(`size mismatch: page built ${s.size} bytes, server received ${resultBytes}`);
  const wall = (Date.now() - T0) / 1000;
  const [vt, at] = [s.mux.tracks.find(t => t.kind === "video"), s.mux.tracks.find(t => t.kind === "audio")];
  const mbps = b => (b / 1e6).toFixed(2) + " Mbit/s";
  console.log([
    `wrote ${out}`,
    `  size      ${s.size} bytes (${(s.size / 1048576).toFixed(2)} MiB), moov ${s.mux.moovBytes} B before mdat, ${s.mux.chunks} chunks${s.mux.co64 ? ", co64" : ""}`,
    `  duration  ${s.duration.toFixed(3)} s`,
    `  bitrate   ${mbps((s.size * 8) / s.duration)} total · video ${mbps((vt.bytes * 8) / s.duration)} (target ${mbps(bitrate)})` +
      (at ? ` · audio ${((at.bytes * 8) / s.duration / 1000).toFixed(1)} kbit/s` : ""),
    `  video     ${s.frames} frames ${s.width}x${s.height} ${s.codec} (avcC profile ${s.avcProfile} level ${s.avcLevel / 10}), ${s.keyframes} keyframes every ${s.keyint}` +
      (s.colorSpace ? `, ${s.colorSpace.primaries}/${s.colorSpace.transfer}/${s.colorSpace.matrix}${s.colorSpace.fullRange ? " full" : ""}` : ""),
    at ? `  audio     Opus 2ch 48 kHz, ${s.opusPackets} packets, pre-skip ${s.preSkip} (${s.opusHead}), peak ${s.audioPeak}, rms ${s.audioRms}` +
      (s.audioClipped ? `, ${s.audioClipped} samples clamped` : "") + `; mix ${s.audioMixMs} ms + encode ${s.audioEncodeMs} ms` : "  audio     none",
    `  speed     ${s.encodeFps} frames/s video encode (${(s.encodeFps / fps).toFixed(2)}× realtime), ${wall.toFixed(1)} s wall total`,
  ].join("\n"));
} catch (e) {
  console.error("encode failed:", e.message || e);
  code = 1;
} finally {
  await browser.close();
  await srv.close();
}
process.exit(code);
