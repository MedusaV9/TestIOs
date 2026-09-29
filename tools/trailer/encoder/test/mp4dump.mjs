// MP4 box inspector (for verifying encode.mjs output).
//   env -u NODE_OPTIONS node tools/trailer/encoder/test/mp4dump.mjs FILE.mp4
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const CONTAINERS = new Set(["moov", "trak", "mdia", "minf", "stbl", "dinf", "edts", "udta"]);
const ENTRY_SKIP = { avc1: 78, Opus: 28, mp4a: 28 };

export function parseBoxes(buf, start = 0, end = buf.length, depth = 0) {
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const out = [];
  let p = start;
  while (p + 8 <= end) {
    let size = dv.getUint32(p); const type = String.fromCharCode(...buf.subarray(p + 4, p + 8));
    let hdr = 8;
    if (size === 1) { size = Number(dv.getBigUint64(p + 8)); hdr = 16; } else if (size === 0) size = end - p;
    if (size < hdr || p + size > end) throw new Error(`bad box ${type} @${p} size ${size}`);
    const b = { type, offset: p, size, hdr, depth, body: buf.subarray(p + hdr, p + size), kids: [] };
    if (CONTAINERS.has(type)) b.kids = parseBoxes(buf, p + hdr, p + size, depth + 1);
    else if (type === "stsd") b.kids = parseBoxes(buf, p + hdr + 8, p + size, depth + 1);
    else if (ENTRY_SKIP[type]) b.kids = parseBoxes(buf, p + hdr + ENTRY_SKIP[type], p + size, depth + 1);
    out.push(b);
    p += size;
  }
  return out;
}

const find = (boxes, type) => { for (const b of boxes) { if (b.type === type) return b; const k = find(b.kids, type); if (k) return k; } return null; };
const u32 = (b, o) => ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) >>> 0;
const u16 = (b, o) => (b[o] << 8) | b[o + 1];
const i32 = (b, o) => u32(b, o) | 0;

/** Summarise a parsed file: top-level order + per-track tables. */
export function inspect(buf) {
  const boxes = parseBoxes(buf);
  const top = boxes.map(b => `${b.type}(${b.size})`);
  const moov = boxes.find(b => b.type === "moov");
  const mvhd = find([moov], "mvhd").body;
  const movieTs = u32(mvhd, 12), movieDur = u32(mvhd, 16);
  const tracks = moov.kids.filter(b => b.type === "trak").map(trak => {
    const t = {};
    const tk = find([trak], "tkhd").body;
    t.id = u32(tk, 12); t.tkhdDuration = u32(tk, 20); t.volume = u16(tk, 36);
    t.width = u32(tk, 76) / 65536; t.height = u32(tk, 80) / 65536;
    const md = find([trak], "mdhd").body; t.timescale = u32(md, 12); t.mediaDuration = u32(md, 16);
    t.handler = String.fromCharCode(...find([trak], "hdlr").body.subarray(8, 12));
    const el = find([trak], "elst");
    if (el) t.elst = { entries: u32(el.body, 4), segmentDuration: u32(el.body, 8), mediaTime: i32(el.body, 12) };
    const stsd = find([trak], "stsd"); const entry = stsd.kids[0]; t.entry = entry.type;
    if (entry.type === "avc1") {
      t.entryWH = [u16(entry.body, 24), u16(entry.body, 26)];
      const avcC = find([entry], "avcC").body; t.avcC = { profile: avcC[1], compat: avcC[2], level: avcC[3], bytes: avcC.length };
      t.extra = entry.kids.map(k => k.type);
    }
    if (entry.type === "Opus") {
      t.channelcount = u16(entry.body, 16); t.samplesize = u16(entry.body, 18); t.samplerate = u32(entry.body, 24) / 65536;
      const d = find([entry], "dOps").body;
      t.dOps = { version: d[0], outputChannelCount: d[1], preSkip: u16(d, 2), inputSampleRate: u32(d, 4), outputGain: u16(d, 8), mappingFamily: d[10] };
    }
    const stts = find([trak], "stts").body; t.stts = [];
    for (let i = 0; i < u32(stts, 4); i++) t.stts.push([u32(stts, 8 + 8 * i), u32(stts, 12 + 8 * i)]);
    const stss = find([trak], "stss"); if (stss) t.stss = Array.from({ length: u32(stss.body, 4) }, (_, i) => u32(stss.body, 8 + 4 * i));
    t.ctts = !!find([trak], "ctts");
    const stsc = find([trak], "stsc").body; t.stsc = [];
    for (let i = 0; i < u32(stsc, 4); i++) t.stsc.push([u32(stsc, 8 + 12 * i), u32(stsc, 12 + 12 * i)]);
    const stsz = find([trak], "stsz").body; t.samples = u32(stsz, 8);
    const sizes = Array.from({ length: t.samples }, (_, i) => u32(stsz, 12 + 4 * i));
    t.bytes = sizes.reduce((a, b) => a + b, 0);
    const co = find([trak], "stco") || find([trak], "co64"); t.chunkBox = co.type;
    const n = u32(co.body, 4);
    t.chunkOffsets = Array.from({ length: n }, (_, i) => co.type === "stco" ? u32(co.body, 8 + 4 * i) : Number(new DataView(co.body.buffer, co.body.byteOffset).getBigUint64(8 + 8 * i)));
    // Check every sample lies inside mdat.
    const mdat = boxes.find(b => b.type === "mdat");
    let s = 0, bad = 0;
    for (let c = 0; c < n; c++) {
      const run = [...t.stsc].reverse().find(r => r[0] <= c + 1);
      let o = t.chunkOffsets[c];
      for (let k = 0; k < run[1] && s < t.samples; k++, s++) {
        if (o < mdat.offset + mdat.hdr || o + sizes[s] > mdat.offset + mdat.size) bad++;
        o += sizes[s];
      }
    }
    t.samplesMapped = s; t.samplesOutsideMdat = bad;
    if (t.handler === "vide") {
      // first NAL of sample 0 should be an IDR / SPS-less avc stream (4-byte lengths).
      const o = t.chunkOffsets[0]; const len = u32(buf, o); t.firstNalType = buf[o + 4] & 31; t.firstNalLen = len;
    }
    return t;
  });
  return { top, movieTimescale: movieTs, movieDuration: movieDur, seconds: movieDur / movieTs, tracks, moovBeforeMdat: top.findIndex(x => x.startsWith("moov")) < top.findIndex(x => x.startsWith("mdat")) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const info = inspect(new Uint8Array(readFileSync(process.argv[2])));
  for (const t of info.tracks) { t.chunkOffsets = `${t.chunkOffsets.length} offsets [${t.chunkOffsets.slice(0, 3).join(", ")}, …]`; if (t.stss) t.stss = `${t.stss.length} keyframes [${t.stss.slice(0, 6).join(", ")}…]`; }
  console.log(JSON.stringify(info, null, 1));
}
