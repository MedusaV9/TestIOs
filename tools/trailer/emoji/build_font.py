#!/usr/bin/env python3
"""Build a small COLRv0 colour-emoji font for rendering the web UI in headless Chromium.

The sandbox (and many CI boxes) ship no emoji font at all, so every 🍌 renders as a tofu box in
screenshots and in the trailer.  This script needs no third-party packages: it writes the
OpenType tables by hand.

    shapes-*.json   drawn emoji  {"1F34C": {"name": "banana", "layers": [ ... ]}, ...}
    everything else that is an emoji and not covered by an installed font maps to an empty glyph,
    so unknown emoji simply disappear instead of showing boxes.

Layer shapes (viewBox 0..100, y down, like SVG; one layer = one colour):
    {"fill": "#RRGGBB[AA]", "circle": [cx, cy, r]}
    {"fill": ..., "ellipse": [cx, cy, rx, ry, rotDeg?]}
    {"fill": ..., "rect": [x, y, w, h, radius?]}
    {"fill": ..., "poly": [[x, y], ...]}
    {"fill": ..., "d": "M .. L .. H .. V .. Q .. T .. C .. S .. Z"}   (no arcs; abs + rel)
    {"fill": ..., "line": [x1, y1, x2, y2], "w": width}                (round caps)
    {"fill": ..., "polyline": [[x, y], ...], "w": width}               (round caps + joins)
    {"fill": ..., "arc": [cx, cy, r, startDeg, endDeg], "w": width}    (0° = right, clockwise)
    "fill": "currentColor" paints the layer in the surrounding text colour (for → ✔ ▶ …).
    Optional per emoji: "adv": advance in font units (default 1180; text symbols ≈ 800).

Usage:
    python3 build_font.py                      # all shapes-*.json → MMEmoji.ttf next to this file
    python3 build_font.py --only shapes-b.json --out /tmp/x.ttf
    python3 build_font.py --install            # also copy to ~/.local/share/fonts + fc-cache
"""
from __future__ import annotations

import glob
import json
import math
import os
import re
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
UPEM = 1000
ADV = 1180            # advance of an emoji (≈1.18 em, like common emoji fonts)
X0, Y0, S = 90, 880, 10.0   # viewBox (0..100, y down) → font units


# ---------------------------------------------------------------- geometry → quadratic contours
# A contour is a list of (x, y, on_curve) in viewBox coordinates.

def _circle(cx, cy, rx, ry=None, rot=0.0):
    ry = rx if ry is None else ry
    n = 8
    k = 1 / math.cos(math.pi / n)
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        for (f, on) in ((1.0, True), (k, False)):
            aa = a if on else a + math.pi / n
            x, y = rx * f * math.cos(aa), ry * f * math.sin(aa)
            pts.append((cx + x * c - y * s, cy + x * s + y * c, on))
    return [pts]


def _rect(x, y, w, h, r=0):
    r = max(0.0, min(r, w / 2, h / 2))
    if r <= 0:
        return [[(x, y, True), (x + w, y, True), (x + w, y + h, True), (x, y + h, True)]]
    return [[(x + r, y, True), (x + w - r, y, True), (x + w, y, False), (x + w, y + r, True),
             (x + w, y + h - r, True), (x + w, y + h, False), (x + w - r, y + h, True),
             (x + r, y + h, True), (x, y + h, False), (x, y + h - r, True),
             (x, y + r, True), (x, y, False)]]


def _poly(points):
    return [[(float(p[0]), float(p[1]), True) for p in points]]


def _segment(x1, y1, x2, y2, w):
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy) or 1e-6
    nx, ny = -dy / L * w / 2, dx / L * w / 2
    body = [[(x1 + nx, y1 + ny, True), (x2 + nx, y2 + ny, True), (x2 - nx, y2 - ny, True), (x1 - nx, y1 - ny, True)]]
    return body


def _polyline(points, w):
    out = []
    for a, b in zip(points, points[1:]):
        out += _segment(a[0], a[1], b[0], b[1], w)
    for p in points:
        out += _circle(p[0], p[1], w / 2)
    return out


def _arc(cx, cy, r, a0, a1, w):
    n = max(3, int(abs(a1 - a0) / 12) + 1)
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
    return _polyline(pts, w)


_TOK = re.compile(r"[MmLlHhVvQqTtCcSsZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def _path(d):
    toks = _TOK.findall(d)
    i, cmd = 0, None
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    last_ctrl = None       # (kind, point) for T / S reflection
    contours, pts = [], []

    def num():
        nonlocal i
        v = float(toks[i]); i += 1
        return v

    def close():
        nonlocal pts
        if len(pts) >= 3:
            # drop duplicate closing point
            if pts[0][2] and pts[-1][2] and abs(pts[0][0] - pts[-1][0]) < 1e-6 and abs(pts[0][1] - pts[-1][1]) < 1e-6:
                pts.pop()
            contours.append(pts)
        pts = []

    while i < len(toks):
        t = toks[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t; i += 1
            if cmd in "Zz":
                close(); cur = start; last_ctrl = None
                continue
        if cmd is None:
            raise ValueError("path must start with a command: " + d[:40])
        rel = cmd.islower()
        C = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if C == "M":
            if pts: close()
            cur = (ox + num(), oy + num()); start = cur
            pts = [(cur[0], cur[1], True)]
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif C == "L":
            cur = (ox + num(), oy + num()); pts.append((cur[0], cur[1], True)); last_ctrl = None
        elif C == "H":
            cur = ((cur[0] if rel else 0.0) + num(), cur[1]); pts.append((cur[0], cur[1], True)); last_ctrl = None
        elif C == "V":
            cur = (cur[0], (cur[1] if rel else 0.0) + num()); pts.append((cur[0], cur[1], True)); last_ctrl = None
        elif C in "QT":
            if C == "Q":
                c1 = (ox + num(), oy + num())
            else:
                c1 = (2 * cur[0] - last_ctrl[1][0], 2 * cur[1] - last_ctrl[1][1]) if last_ctrl and last_ctrl[0] == "q" else cur
            end = (ox + num(), oy + num())
            pts.append((c1[0], c1[1], False)); pts.append((end[0], end[1], True))
            cur = end; last_ctrl = ("q", c1)
        elif C in "CS":
            if C == "C":
                c1 = (ox + num(), oy + num())
            else:
                c1 = (2 * cur[0] - last_ctrl[1][0], 2 * cur[1] - last_ctrl[1][1]) if last_ctrl and last_ctrl[0] == "c" else cur
            c2 = (ox + num(), oy + num())
            end = (ox + num(), oy + num())
            p0 = cur
            # cubic → 4 quadratics
            n = 4
            def bez(t):
                u = 1 - t
                return (u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * end[0],
                        u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * end[1])
            def dbez(t):
                u = 1 - t
                return (3 * u * u * (c1[0] - p0[0]) + 6 * u * t * (c2[0] - c1[0]) + 3 * t * t * (end[0] - c2[0]),
                        3 * u * u * (c1[1] - p0[1]) + 6 * u * t * (c2[1] - c1[1]) + 3 * t * t * (end[1] - c2[1]))
            for k in range(n):
                ta, tb = k / n, (k + 1) / n
                a, b = bez(ta), bez(tb)
                da, db = dbez(ta), dbez(tb)
                # intersection of tangents; fall back to midpoint control
                den = da[0] * db[1] - da[1] * db[0]
                if abs(den) > 1e-9:
                    s_ = ((b[0] - a[0]) * db[1] - (b[1] - a[1]) * db[0]) / den
                    q = (a[0] + da[0] * s_, a[1] + da[1] * s_)
                    if math.hypot(q[0] - (a[0] + b[0]) / 2, q[1] - (a[1] + b[1]) / 2) > 2 * math.hypot(b[0] - a[0], b[1] - a[1]):
                        q = bez((ta + tb) / 2); q = (2 * q[0] - (a[0] + b[0]) / 2, 2 * q[1] - (a[1] + b[1]) / 2)
                else:
                    m = bez((ta + tb) / 2); q = (2 * m[0] - (a[0] + b[0]) / 2, 2 * m[1] - (a[1] + b[1]) / 2)
                pts.append((q[0], q[1], False)); pts.append((b[0], b[1], True))
            cur = end; last_ctrl = ("c", c2)
        else:
            raise ValueError(f"unsupported path command {cmd!r} (arcs are not supported)")
    if pts: close()
    return contours


def shape_contours(layer):
    if "circle" in layer: return _circle(*layer["circle"][:3])
    if "ellipse" in layer:
        e = layer["ellipse"]; return _circle(e[0], e[1], e[2], e[3], e[4] if len(e) > 4 else 0.0)
    if "rect" in layer: return _rect(*layer["rect"])
    if "poly" in layer: return _poly(layer["poly"])
    if "d" in layer: return _path(layer["d"])
    if "line" in layer:
        x1, y1, x2, y2 = layer["line"]; w = layer.get("w", 4)
        return _segment(x1, y1, x2, y2, w) + _circle(x1, y1, w / 2) + _circle(x2, y2, w / 2)
    if "polyline" in layer: return _polyline(layer["polyline"], layer.get("w", 4))
    if "arc" in layer: return _arc(*layer["arc"], layer.get("w", 4))
    raise ValueError("unknown layer shape: " + json.dumps(layer)[:80])


def _area(c):
    return sum(c[i][0] * c[(i + 1) % len(c)][1] - c[(i + 1) % len(c)][0] * c[i][1] for i in range(len(c))) / 2


def _reverse(c):
    r = list(reversed(c))
    k = next((i for i, p in enumerate(r) if p[2]), 0)   # start on an on-curve point
    return r[k:] + r[:k]


def orient(contours, primitive):
    """Same winding for every contour of a primitive (overlapping caps/segments must not cancel
    under the nonzero rule); an SVG path keeps its authored holes, only its largest contour is
    made clockwise (in font space)."""
    if not contours: return contours
    if primitive:
        return [c if _area(c) > 0 else _reverse(c) for c in contours]
    big = max(contours, key=lambda c: abs(_area(c)))
    return contours if _area(big) > 0 else [_reverse(c) for c in contours]


def to_font(contours, primitive=True):
    # viewBox is y-down: a positive viewBox area is clockwise on screen = clockwise in font space after the flip
    cs = [c for c in contours if len(c) >= 2]
    cs = orient(cs, primitive)
    return [[(round(X0 + x * S), round(Y0 - y * S), on) for (x, y, on) in c] for c in cs]


# ---------------------------------------------------------------- OpenType tables

def glyf_entry(contours):
    if not contours:
        return b"", (0, 0, 0, 0), 0, 0
    xs = [p[0] for c in contours for p in c]; ys = [p[1] for c in contours for p in c]
    bbox = (min(xs), min(ys), max(xs), max(ys))
    out = struct.pack(">hhhhh", len(contours), *bbox)
    end, n = [], 0
    for c in contours:
        n += len(c); end.append(n - 1)
    out += struct.pack(">" + "H" * len(end), *end)
    out += struct.pack(">H", 0)  # no instructions
    flags = bytes(0x01 if p[2] else 0x00 for c in contours for p in c)
    out += flags
    px = py = 0
    xb, yb = b"", b""
    for c in contours:
        for (x, y, _) in c:
            xb += struct.pack(">h", x - px); yb += struct.pack(">h", y - py); px, py = x, y
    out += xb + yb
    while len(out) % 4: out += b"\0"
    return out, bbox, n, len(contours)


def checksum(data):
    data += b"\0" * ((4 - len(data) % 4) % 4)
    return sum(struct.unpack(">%dI" % (len(data) // 4), data)) & 0xFFFFFFFF


def cmap_table(mapping):
    codes = sorted(mapping)
    # format 4 (BMP) — one segment per run of consecutive codes, glyph ids via glyphIdArray
    bmp = [c for c in codes if c <= 0xFFFF]
    runs = []
    for c in bmp:
        if runs and c == runs[-1][1] + 1: runs[-1][1] = c
        else: runs.append([c, c])
    runs.append([0xFFFF, 0xFFFF])
    segX2 = len(runs) * 2
    ends = b"".join(struct.pack(">H", r[1]) for r in runs)
    starts = b"".join(struct.pack(">H", r[0]) for r in runs)
    deltas, offsets, gia = b"", b"", []
    for idx, (a, b) in enumerate(runs):
        if a == 0xFFFF:
            deltas += struct.pack(">h", 1); offsets += struct.pack(">H", 0); continue
        deltas += struct.pack(">h", 0)
        # offset from this idRangeOffset entry to glyphIdArray[len(gia)]
        offsets += struct.pack(">H", (len(runs) - idx) * 2 + len(gia) * 2)
        gia += [mapping[c] for c in range(a, b + 1)]
    search = 2 * (2 ** int(math.log2(len(runs))))
    body = struct.pack(">HHHH", segX2, search, int(math.log2(search // 2)), segX2 - search) + ends + b"\0\0" + starts + deltas + offsets
    body += b"".join(struct.pack(">H", g) for g in gia)
    f4 = struct.pack(">HHH", 4, 6 + len(body), 0) + body
    # format 12 (everything)
    groups = []
    for c in codes:
        g = mapping[c]
        if groups and c == groups[-1][1] + 1 and g == groups[-1][2] + (c - groups[-1][0]):
            groups[-1][1] = c
        else:
            groups.append([c, c, g])
    f12 = struct.pack(">HHIII", 12, 0, 16 + 12 * len(groups), 0, len(groups)) + b"".join(struct.pack(">III", *g) for g in groups)
    header = struct.pack(">HH", 0, 2) + struct.pack(">HHI", 3, 1, 4 + 16) + struct.pack(">HHI", 3, 10, 4 + 16 + len(f4))
    return header + f4 + f12


def name_table(family):
    recs = [(1, family), (2, "Regular"), (3, family + " Regular 1.0"), (4, family + " Regular"), (5, "Version 1.000"), (6, family.replace(" ", "") + "-Regular")]
    strings, records, off = b"", b"", 0
    for nid, s in recs:
        enc = s.encode("utf-16-be")
        records += struct.pack(">HHHHHH", 3, 1, 0x409, nid, len(enc), off)
        strings += enc; off += len(enc)
    return struct.pack(">HHH", 0, len(recs), 6 + 12 * len(recs)) + records + strings


def build(glyphs, mapping, colr, palette, family="MM Emoji Trailer"):
    """glyphs: list of (contours_in_font_units, advance). mapping: code → glyph id.
    colr: {base_gid: [(layer_gid, palette_index), ...]}. palette: list of (r, g, b, a)."""
    glyf, loca = b"", [0]
    hmtx = b""
    gbox = [0, 0, 0, 0]
    max_pts = max_ctr = 0
    first = True
    for contours, adv in glyphs:
        data, bbox, npts, nctr = glyf_entry(contours)
        glyf += data; loca.append(len(glyf))
        hmtx += struct.pack(">Hh", adv, bbox[0] if data else 0)
        max_pts, max_ctr = max(max_pts, npts), max(max_ctr, nctr)
        if data:
            if first: gbox = list(bbox); first = False
            else: gbox = [min(gbox[0], bbox[0]), min(gbox[1], bbox[1]), max(gbox[2], bbox[2]), max(gbox[3], bbox[3])]
    n = len(glyphs)
    loca_b = struct.pack(">" + "I" * len(loca), *loca)
    now = int(time.time()) + 2082844800
    head = struct.pack(">IIIIHHqqhhhhHHhhh", 0x00010000, 0x00010000, 0, 0x5F0F3CF5, 0x000B, UPEM, now, now,
                       gbox[0], gbox[1], gbox[2], gbox[3], 0, 8, 2, 1, 0)
    asc, desc = 900, -150
    hhea = struct.pack(">IhhhHhhhhhhhhhhhH", 0x00010000, asc, desc, 0, ADV, min(0, gbox[0]), 0, gbox[2], 1, 0, 0, 0, 0, 0, 0, 0, n)
    maxp = struct.pack(">IHHHHHHHHHHHHHH", 0x00010000, n, max_pts, max_ctr, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0)
    bmp_codes = [c for c in mapping if c <= 0xFFFF]
    os2 = struct.pack(">HhHHHhhhhhhhhhhh10sIIII4sHHHhhhHHIIhhHHH",
                      4, ADV, 400, 5, 0, 650, 700, 0, 140, 650, 700, 0, 480, 50, 250, 0, b"\0" * 10,
                      0, 1 << (57 - 32), 0, 0, b"MMNK", 0x40, min(bmp_codes or [0x20]), 0xFFFF,
                      asc, desc, 0, 950, 250, 1, 0, 500, 700, 0, 32, 0)
    post = struct.pack(">IIhhIIIII", 0x00030000, 0, -100, 50, 0, 0, 0, 0, 0)
    # COLR v0
    bases = sorted(colr)
    base_recs, layer_recs = b"", b""
    li = 0
    for b in bases:
        base_recs += struct.pack(">HHH", b, li, len(colr[b]))
        for (lg, pi) in colr[b]:
            layer_recs += struct.pack(">HH", lg, pi); li += 1
    colr_t = struct.pack(">HHIIH", 0, len(bases), 14, 14 + len(base_recs), li) + base_recs + layer_recs
    cpal = struct.pack(">HHHHI", 0, len(palette), 1, len(palette), 14) + struct.pack(">H", 0)
    cpal += b"".join(struct.pack(">BBBB", b_, g_, r_, a_) for (r_, g_, b_, a_) in palette)
    tables = {
        b"OS/2": os2, b"cmap": cmap_table(mapping), b"glyf": glyf,
        b"head": head, b"hhea": hhea, b"hmtx": hmtx, b"loca": loca_b, b"maxp": maxp,
        b"name": name_table(family), b"post": post,
    }
    if colr:
        tables[b"COLR"] = colr_t; tables[b"CPAL"] = cpal
    tags = sorted(tables)
    num = len(tags)
    es = int(math.log2(num)); sr = (2 ** es) * 16
    out = struct.pack(">IHHHH", 0x00010000, num, sr, es, num * 16 - sr)
    offset = 12 + 16 * num
    dir_, body = b"", b""
    head_off = 0
    for t in tags:
        data = tables[t]
        if t == b"head": head_off = offset
        dir_ += struct.pack(">4sIII", t, checksum(data), offset, len(data))
        pad = data + b"\0" * ((4 - len(data) % 4) % 4)
        body += pad; offset += len(pad)
    font = bytearray(out + dir_ + body)
    adj = (0xB1B0AFBA - checksum(bytes(font))) & 0xFFFFFFFF
    struct.pack_into(">I", font, head_off + 8, adj)
    return bytes(font)


# ---------------------------------------------------------------- which codepoints to cover

def emoji_codepoints():
    """Every Extended_Pictographic / Emoji_Presentation code point (via perl's Unicode tables)."""
    perl = r'for my $c (0xA9..0x1FAFF) { next if $c>=0xD800 && $c<=0xDFFF; my $s=chr($c); print "$c\n" if $s =~ /[\p{Extended_Pictographic}\p{Emoji_Presentation}\p{Regional_Indicator}\p{Emoji_Modifier}]/ }'
    try:
        out = subprocess.run(["perl", "-e", perl], capture_output=True, text=True, check=True).stdout
        return {int(x) for x in out.split()}
    except Exception:
        return set(range(0x1F000, 0x1FB00)) | set(range(0x2600, 0x27C0))


def covered_by_installed_fonts(family):
    """Code points some installed (non-emoji) font already has — those keep their text glyph."""
    try:
        out = subprocess.run(["fc-list", "--format", "%{family}\t%{charset}\n"], capture_output=True, text=True).stdout
    except Exception:
        return set()
    cov = set()
    for line in out.splitlines():
        fam, _, cs = line.partition("\t")
        if family in fam: continue
        for part in cs.split():
            a, _, b = part.partition("-")
            a = int(a, 16); b = int(b, 16) if b else a
            if b - a < 200000: cov.update(range(a, b + 1))
    return cov


def parse_color(c):
    c = c.lstrip("#")
    if len(c) == 3: c = "".join(ch * 2 for ch in c)
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    a = int(c[6:8], 16) if len(c) == 8 else 255
    return (r, g, b, a)


def main(argv):
    only = None; out = HERE / "MMEmoji.ttf"; install = False; family = "MM Emoji Trailer"; text = False
    it = iter(argv)
    for a in it:
        if a == "--only": only = next(it)
        elif a == "--out": out = Path(next(it))
        elif a == "--install": install = True
        elif a == "--family": family = next(it)
        elif a == "--text": text = True
    files = [HERE / only] if only else sorted(Path(p) for p in glob.glob(str(HERE / "shapes-*.json")))
    drawn = {}
    for f in files:
        data = json.loads(f.read_text(encoding="utf-8"))
        for k, v in data.items():
            cp = int(k.replace("U+", ""), 16)
            if cp in drawn: print(f"warning: {k} drawn twice (keeping {f.name})", file=sys.stderr)
            drawn[cp] = v
    glyphs = [([], 500), ([], ADV), ([], 0)]     # .notdef, blank emoji, zero-width
    mapping = {}
    symbols = set(range(0x2190, 0x2200)) | set(range(0x2300, 0x2400)) | set(range(0x25A0, 0x2800)) | set(range(0x2B00, 0x2C00))
    for cp in sorted((emoji_codepoints() | symbols) - covered_by_installed_fonts("MM Emoji Trailer")):
        mapping[cp] = 1
    for cp in (0xFE0F, 0xFE0E, 0x200D, 0x20E3) + tuple(range(0x1F3FB, 0x1F400)) + tuple(range(0xE0020, 0xE0080)):
        mapping[cp] = 2
    palette, pal_idx = [], {}
    colr = {}
    errors = 0
    for cp in sorted(drawn):
        spec = drawn[cp]
        layers = []
        all_contours = []
        try:
            for layer in spec["layers"]:
                cs = to_font(shape_contours(layer), primitive="d" not in layer)
                if not cs: continue
                fill = layer.get("fill", "#000000")
                if fill == "currentColor":
                    layers.append((cs, 0xFFFF)); all_contours += cs; continue
                col = parse_color(fill)
                if col not in pal_idx: pal_idx[col] = len(palette); palette.append(col)
                layers.append((cs, pal_idx[col])); all_contours += cs
        except Exception as e:
            print(f"error in U+{cp:04X} ({spec.get('name')}): {e}", file=sys.stderr); errors += 1; continue
        if not layers: continue
        adv = int(spec.get("adv", ADV))
        base = len(glyphs)
        glyphs.append((all_contours, adv))
        mapping[cp] = base
        if text: continue
        lids = []
        for cs, pi in layers:
            lids.append((len(glyphs), pi)); glyphs.append((cs, adv))
        colr[base] = lids
    if not palette: palette = [(0, 0, 0, 255)]
    font = build(glyphs, mapping, colr, palette, family)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp"); tmp.write_bytes(font); os.replace(tmp, out)
    print(f"{out}: {len(drawn) - errors} drawn emoji, {sum(1 for g in mapping.values() if g == 1)} blank, {len(glyphs)} glyphs, {len(font)//1024} KB" + (f", {errors} errors" if errors else ""))
    if install:
        dst = Path.home() / ".local/share/fonts"; dst.mkdir(parents=True, exist_ok=True)
        shutil.copy(out, dst / out.name)
        print("installed →", dst / out.name)
        if not text:
            # Chromium only falls back to non-colour fonts for text-presentation characters (→ ✔ ☀
            # without U+FE0F) — ship a monochrome twin with the same coverage for those.
            twin = out.with_name(out.stem + "Text.ttf")
            main([*(["--only", only] if only else []), "--out", str(twin), "--family", family + " Text", "--text", "--install"])
            return 1 if errors else 0
        subprocess.run(["fc-cache", "-f", str(dst)], check=False)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
