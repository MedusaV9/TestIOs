// Minimal ISO-BMFF (MP4) muxer: one H.264 video track (avc1/avcC) and an
// optional Opus audio track (Opus/dOps), faststart layout (ftyp, moov, mdat),
// samples interleaved in ~0.5 s chunks. No dependencies; runs in browsers and Node.
//
//   const { parts, size, info } = muxMP4({ video, audio });
//   new Blob(parts, { type: "video/mp4" })
//
// video = { width, height, timescale, avcC: Uint8Array, colorSpace?,
//           samples: [{ data: Uint8Array, pts, dur, key }] }   // decode order, pts/dur in `timescale`
// audio = { channels: 2, preSkip, inputSampleRate: 48000, outputGain: 0,
//           presented,                                          // samples @48 kHz to present (after pre-skip)
//           samples: [{ data: Uint8Array, dur: 960 }] }

const MAX32 = 0xffffffff;

class W {
  constructor(cap = 256) { this.a = new Uint8Array(cap); this.n = 0; }
  need(k) {
    if (this.n + k <= this.a.length) return;
    const b = new Uint8Array(Math.max(this.a.length * 2, this.n + k));
    b.set(this.a.subarray(0, this.n)); this.a = b;
  }
  u8(v) { this.need(1); this.a[this.n++] = v & 255; return this; }
  u16(v) { this.need(2); this.a[this.n++] = (v >>> 8) & 255; this.a[this.n++] = v & 255; return this; }
  u24(v) { return this.u8(v >>> 16).u16(v & 0xffff); }
  u32(v) { v = v >>> 0; this.need(4); const a = this.a; let n = this.n; a[n++] = v >>> 24; a[n++] = (v >>> 16) & 255; a[n++] = (v >>> 8) & 255; a[n++] = v & 255; this.n = n; return this; }
  i16(v) { return this.u16(v & 0xffff); }
  i32(v) { return this.u32(v | 0); }
  u64(v) { return this.u32(Math.floor(v / 2 ** 32)).u32(v % 2 ** 32); }
  str(s) { for (let i = 0; i < s.length; i++) this.u8(s.charCodeAt(i)); return this; }
  bytes(b) { this.need(b.length); this.a.set(b, this.n); this.n += b.length; return this; }
  zeros(k) { this.need(k); this.a.fill(0, this.n, this.n + k); this.n += k; return this; }
  done() { return this.a.slice(0, this.n); }
}

const cat = parts => {
  const len = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(len); let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
};
const bodyOf = kids => cat(kids.flat(Infinity).filter(Boolean).map(k => (k instanceof W ? k.done() : k)));
const box = (type, ...kids) => { const b = bodyOf(kids); return new W(8 + b.length).u32(8 + b.length).str(type).bytes(b).done(); };
const full = (type, version, flags, ...kids) => box(type, new W(4).u8(version).u24(flags), ...kids);
const MATRIX = [0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000];
const matrix = w => { for (const m of MATRIX) w.u32(m); return w; };

// WebCodecs VideoColorSpace strings → ISO/IEC 23091-2 code points (for 'colr' nclx).
const PRIMARIES = { bt709: 1, bt470bg: 5, smpte170m: 6, bt2020: 9, smpte432: 12 };
const TRANSFER = { bt709: 1, smpte170m: 6, linear: 8, "iec61966-2-1": 13, pq: 16, hlg: 18 };
const MATRIXC = { rgb: 0, bt709: 1, bt470bg: 5, smpte170m: 6, "bt2020-ncl": 9 };

/** Run-length helper: [[count, value], ...] */
function runs(values) {
  const out = [];
  for (const v of values) {
    const last = out[out.length - 1];
    if (last && last[1] === v) last[0]++; else out.push([1, v]);
  }
  return out;
}

/** Group sample indices into chunks of ~`span` time units (by decode time). */
function chunkify(times, span) {
  const chunks = []; let cur = null;
  times.forEach((t, i) => {
    if (!cur || t >= cur.start + span) { cur = { idx: chunks.length, start: t, first: i, count: 0 }; chunks.push(cur); }
    cur.count++;
  });
  return chunks;
}

function stbl({ stsd, durations, ctts, sync, sizes, chunks, offsets, co64 }) {
  const stts = new W(); const r = runs(durations);
  stts.u32(r.length); for (const [c, d] of r) stts.u32(c).u32(d);
  let cttsBox = null;
  if (ctts && ctts.some(x => x !== 0)) {
    const w = new W(); const cr = runs(ctts);
    w.u32(cr.length); for (const [c, o] of cr) w.u32(c).u32(o);
    cttsBox = full("ctts", 0, 0, w);
  }
  let stss = null;
  if (sync && sync.length !== sizes.length) {
    const w = new W(); w.u32(sync.length); for (const s of sync) w.u32(s);
    stss = full("stss", 0, 0, w);
  }
  const stsc = new W(); const sr = [];
  chunks.forEach((c, i) => { if (!sr.length || sr[sr.length - 1][1] !== c.count) sr.push([i + 1, c.count]); });
  stsc.u32(sr.length); for (const [first, n] of sr) stsc.u32(first).u32(n).u32(1);
  const stsz = new W(12 + 4 * sizes.length); stsz.u32(0).u32(sizes.length); for (const s of sizes) stsz.u32(s);
  const co = new W(); co.u32(offsets.length); for (const o of offsets) (co64 ? co.u64(o) : co.u32(o));
  return box("stbl", stsd, full("stts", 0, 0, stts), cttsBox, stss,
    full("stsc", 0, 0, stsc), full("stsz", 0, 0, stsz), full(co64 ? "co64" : "stco", 0, 0, co));
}

const dinf = () => box("dinf", full("dref", 0, 0, new W().u32(1), full("url ", 0, 1)));

function tkhd({ id, duration, volume, width = 0, height = 0 }) {
  const v1 = duration > MAX32; const w = new W();
  if (v1) w.u64(0).u64(0).u32(id).u32(0).u64(duration); else w.u32(0).u32(0).u32(id).u32(0).u32(duration);
  w.zeros(8).i16(0).i16(0).u16(volume).u16(0);
  matrix(w).u32(width * 65536).u32(height * 65536);
  return full("tkhd", v1 ? 1 : 0, 3, w);
}

function mdhd(timescale, duration) {
  const v1 = duration > MAX32; const w = new W();
  if (v1) w.u64(0).u64(0).u32(timescale).u64(duration); else w.u32(0).u32(0).u32(timescale).u32(duration);
  w.u16(0x55c4).u16(0); // language "und"
  return full("mdhd", v1 ? 1 : 0, 0, w);
}

const hdlr = (type, name) => full("hdlr", 0, 0, new W().u32(0).str(type).zeros(12).str(name).u8(0));

function elst(segmentDuration, mediaTime) {
  const v1 = segmentDuration > MAX32 || mediaTime > 0x7fffffff; const w = new W().u32(1);
  if (v1) w.u64(segmentDuration).u64(mediaTime); else w.u32(segmentDuration).i32(mediaTime);
  w.i16(1).i16(0);
  return box("edts", full("elst", v1 ? 1 : 0, 0, w));
}

function avc1Entry(v) {
  const w = new W();
  w.zeros(6).u16(1)                 // reserved, data_reference_index
    .u16(0).u16(0).zeros(12)         // pre_defined, reserved, pre_defined[3]
    .u16(v.width).u16(v.height)
    .u32(0x00480000).u32(0x00480000) // 72 dpi
    .u32(0).u16(1);                  // reserved, frame_count
  const name = "WebCodecs H.264".slice(0, 31);
  w.u8(name.length).str(name).zeros(31 - name.length);
  w.u16(0x0018).i16(-1);
  const kids = [w, box("avcC", v.avcC), box("pasp", new W().u32(1).u32(1))];
  const cs = v.colorSpace;
  if (cs && cs.primaries in PRIMARIES && cs.transfer in TRANSFER && cs.matrix in MATRIXC) {
    kids.push(box("colr", new W().str("nclx").u16(PRIMARIES[cs.primaries]).u16(TRANSFER[cs.transfer])
      .u16(MATRIXC[cs.matrix]).u8(cs.fullRange ? 0x80 : 0)));
  }
  return box("avc1", ...kids);
}

function opusEntry(a) {
  const w = new W();
  w.zeros(6).u16(1).zeros(8)          // reserved, data_reference_index, reserved[2]
    .u16(a.channels).u16(16)          // channelcount, samplesize
    .u16(0).u16(0).u32(48000 * 65536); // pre_defined, reserved, samplerate 16.16
  const dOps = new W().u8(0).u8(a.channels).u16(a.preSkip).u32(a.inputSampleRate ?? 48000)
    .i16(a.outputGain ?? 0).u8(0);    // Version 0, ..., ChannelMappingFamily 0
  return box("Opus", w, box("dOps", dOps));
}

/**
 * Build the MP4. Returns { parts: Uint8Array[], size, duration (s), info }.
 * `parts` = [ftyp, moov, mdat header, ...sample payloads in file order].
 */
export function muxMP4({ video, audio = null, movieTimescale = 1000, chunkSeconds = 0.5 }) {
  const tracks = [];

  if (video) {
    const s = video.samples; const ts = video.timescale;
    // Decode timestamps = sorted presentation timestamps; shift so ctts >= 0 (B-frames).
    const pts = s.map(x => x.pts);
    const sorted = [...pts].sort((a, b) => a - b);
    const p0 = sorted[0] || 0;
    const dts = sorted.map(p => p - p0);
    let shift = 0;
    for (let i = 0; i < s.length; i++) shift = Math.max(shift, dts[i] - (pts[i] - p0));
    const ctts = s.map((x, i) => x.pts - p0 + shift - dts[i]);
    const durations = dts.map((d, i) => (i + 1 < dts.length ? dts[i + 1] - d : s[i].dur));
    const mediaDur = durations.reduce((a, b) => a + b, 0);
    tracks.push({
      kind: "video", id: tracks.length + 1, timescale: ts, samples: s, dts, durations, ctts,
      sync: s.map((x, i) => (x.key ? i + 1 : 0)).filter(Boolean), mediaDur,
      presentDur: Math.round((mediaDur * movieTimescale) / ts), mediaTime: shift,
      chunks: chunkify(dts, chunkSeconds * ts),
      stsd: () => full("stsd", 0, 0, new W().u32(1), avc1Entry(video)),
    });
  }

  if (audio) {
    const s = audio.samples;
    const durations = s.map(x => x.dur ?? 960);
    const dts = []; let t = 0; for (const d of durations) { dts.push(t); t += d; }
    const mediaDur = t;
    const presented = Math.min(audio.presented ?? mediaDur - audio.preSkip, mediaDur - audio.preSkip);
    tracks.push({
      kind: "audio", id: tracks.length + 1, timescale: 48000, samples: s, dts, durations, ctts: null, sync: null,
      mediaDur, presentDur: Math.round((presented * movieTimescale) / 48000), mediaTime: audio.preSkip,
      chunks: chunkify(dts, chunkSeconds * 48000),
      stsd: () => full("stsd", 0, 0, new W().u32(1), opusEntry(audio)),
    });
  }

  // File order of chunks: by start time (seconds), video first on ties.
  const order = [];
  for (const tr of tracks) for (const c of tr.chunks) order.push({ tr, c, t: c.start / tr.timescale });
  order.sort((a, b) => a.t - b.t || a.tr.id - b.tr.id);

  let payload = 0;
  for (const { tr, c } of order) for (let i = c.first; i < c.first + c.count; i++) payload += tr.samples[i].data.length;

  const ftyp = box("ftyp", new W().str("isom").u32(512).str("isom").str("iso2").str("avc1").str("mp41"));
  const bigMdat = payload + 8 > MAX32;
  const mdatHeader = bigMdat ? new W().u32(1).str("mdat").u64(payload + 16).done() : new W().u32(payload + 8).str("mdat").done();
  const co64 = ftyp.length + mdatHeader.length + payload + 1e6 > MAX32;

  const buildMoov = () => {
    const movieDur = Math.max(...tracks.map(t => t.presentDur));
    const mvhdV1 = movieDur > MAX32; const mv = new W();
    if (mvhdV1) mv.u64(0).u64(0).u32(movieTimescale).u64(movieDur); else mv.u32(0).u32(0).u32(movieTimescale).u32(movieDur);
    mv.u32(0x00010000).u16(0x0100).zeros(10); matrix(mv).zeros(24).u32(tracks.length + 1);
    const traks = tracks.map(tr => {
      const isV = tr.kind === "video";
      const minfHeader = isV ? full("vmhd", 0, 1, new W().u16(0).u16(0).u16(0).u16(0)) : full("smhd", 0, 0, new W().i16(0).u16(0));
      return box("trak",
        tkhd({ id: tr.id, duration: tr.presentDur, volume: isV ? 0 : 0x0100, width: isV ? video.width : 0, height: isV ? video.height : 0 }),
        elst(tr.presentDur, tr.mediaTime),
        box("mdia", mdhd(tr.timescale, tr.mediaDur), isV ? hdlr("vide", "VideoHandler") : hdlr("soun", "SoundHandler"),
          box("minf", minfHeader, dinf(), stbl({
            stsd: tr.stsd(), durations: tr.durations, ctts: tr.ctts, sync: tr.sync,
            sizes: tr.samples.map(x => x.data.length), chunks: tr.chunks, offsets: tr.offsets || tr.chunks.map(() => 0), co64,
          }))));
    });
    return { moov: box("moov", full("mvhd", mvhdV1 ? 1 : 0, 0, mv), ...traks), movieDur };
  };

  // Pass 1: size of moov (offsets don't change its size); pass 2: real offsets.
  const moovSize = buildMoov().moov.length;
  let off = ftyp.length + moovSize + mdatHeader.length;
  for (const tr of tracks) tr.offsets = new Array(tr.chunks.length);
  const parts = [];
  for (const { tr, c } of order) {
    tr.offsets[c.idx] = off;
    for (let i = c.first; i < c.first + c.count; i++) { parts.push(tr.samples[i].data); off += tr.samples[i].data.length; }
  }
  const { moov, movieDur } = buildMoov();
  if (moov.length !== moovSize) throw new Error("moov size changed between passes");
  const size = ftyp.length + moov.length + mdatHeader.length + payload;
  return {
    parts: [ftyp, moov, mdatHeader, ...parts], size,
    duration: movieDur / movieTimescale,
    info: {
      moovBytes: moov.length, chunks: order.length, co64, bigMdat,
      tracks: tracks.map(t => ({ kind: t.kind, samples: t.samples.length, chunks: t.chunks.length, timescale: t.timescale,
        mediaDur: t.mediaDur, presentDur: t.presentDur, mediaTime: t.mediaTime,
        bytes: t.samples.reduce((a, x) => a + x.data.length, 0), sync: t.sync ? t.sync.length : t.samples.length })),
    },
  };
}
