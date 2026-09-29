#!/usr/bin/env python3
"""Render the 14 monkey puppet SVGs × 8 palette colours × 4 faces into PNGs for
the native iPad/iPhone UI (SwiftUI cannot palette-swap inline SVG).

Usage: python3 tools/art/render_monkeys.py [--out MonkeyMoney/ios/Resources/Monkeys] [--size 480]
Requires cairosvg (pip install cairosvg).
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import cairosvg

COLORS = {"gelb": "#FFD34E", "rot": "#E53950", "gruen": "#7ED957", "blau": "#3D7BFF", "lila": "#8E5BFF", "orange": "#FF8A3D", "tuerkis": "#2ED3C6", "pink": "#FF6BD6"}
FACES = ["neutral", "jubel", "frust", "denk"]


def lighten(hex_color: str, amount: int = 70) -> str:
    n = int(hex_color[1:], 16)
    r, g, b = min(255, (n >> 16) + amount), min(255, ((n >> 8) & 255) + amount), min(255, (n & 255) + amount)
    return f"#{r:02X}{g:02X}{b:02X}"


def recolor(svg: str, color: str, face: str) -> str:
    # Palette swap: the puppets use CSS custom properties with defaults; cairosvg has no var() support, so inline them.
    svg = re.sub(r"var\(--fell,\s*#[0-9A-Fa-f]{6}\)", color, svg)
    svg = re.sub(r"var\(--fell-hell,\s*#[0-9A-Fa-f]{6}\)", lighten(color), svg)
    # Any other custom property keeps its default value.
    svg = re.sub(r"var\(--[a-z-]+,\s*(#[0-9A-Fa-f]{3,6}|[a-z]+)\)", r"\1", svg)
    # Face switch: cairosvg does not evaluate attribute selectors, so rewrite the display rules directly.
    svg = re.sub(r"#gesicht-neutral\{display:inline\}", f"#gesicht-{face}{{display:inline}}", svg)
    svg = re.sub(r"svg\[data-affe=\"[^\"]+\"\]\[data-gesicht=[a-z]+\][^{]*\{[^}]*\}", "", svg)
    return svg


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="MonkeyMoney/ios/Resources/Web/monkeys")
    ap.add_argument("--out", default="MonkeyMoney/ios/Resources/Monkeys")
    ap.add_argument("--size", type=int, default=480)
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for svg_path in sorted(Path(args.src).glob("*.svg")):
        raw = svg_path.read_text()
        for cid, hexc in COLORS.items():
            for face in FACES:
                target = out / f"{svg_path.stem}_{cid}_{face}.png"
                if target.exists():
                    count += 1
                    continue
                cairosvg.svg2png(bytestring=recolor(raw, hexc, face).encode(), write_to=str(target), output_height=args.size, output_width=int(args.size * 240 / 320))
                count += 1
    print(f"{count} puppets in {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
