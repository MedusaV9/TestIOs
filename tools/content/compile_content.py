#!/usr/bin/env python3
"""Compile the Monkey Money question packs into the compact bundle format.

Input : the original repo checkout (content/packs/**/*.json, content/taxonomie.json,
        content/musik/songs.json, assets/img/generated/pixel/*.png)
Output: MonkeyMoney/ios/Resources/Content/{fragen.json,taxonomie.json,songs.json}
        MonkeyMoney/ios/Resources/Content/pixel/*.png

Only the fields the game needs at runtime are kept (the editorial metadata such as
fact-check notes and sources stays in the source packs).
"""
from __future__ import annotations

import argparse
import glob
import json
import shutil
from pathlib import Path

SCHWIERIGKEIT = {"leicht": "easy", "mittel": "medium", "schwer": "hard", "ultrahard": "ultrahard"}


def compile_question(q: dict) -> dict:
    out = {
        "id": q["id"],
        "kat": q["kategorie"],
        "sub": q["unterkategorie"],
        "schw": SCHWIERIGKEIT[q["schwierigkeit"]],
        "region": q.get("region", "global"),
        "typ": q["typ"],
        "alter": q.get("altersfreigabe", "ab0"),
        "text": q["text"],
        "tipps": q.get("tipps", []),
        "erkl": q.get("erklaerung", ""),
    }
    typ = q["typ"]
    if typ in ("choice", "emoji", "bild_pixel"):
        out["antworten"] = q["antworten"]
        out["korrekt"] = q["korrekt"]
    if typ == "emoji":
        out["emojis"] = q["emojis"]
    if typ == "bild_pixel":
        out["bild"] = Path(q["medien"]["datei"]).name
    if typ == "wahr_falsch":
        out["korrektBool"] = q["korrekt_bool"]
    if typ == "mehrfach":
        out["antworten"] = q["antworten"]
        out["korrektMehrfach"] = q["korrekt_mehrfach"]
    if typ == "schaetz":
        s = q["schaetz"]
        out["schaetz"] = {
            "richtwert": s["richtwert"],
            "einheit": s.get("einheit", ""),
            "toleranz": s.get("toleranz_prozent", 10),
            "min": s.get("eingabe_min", 0),
            "max": s.get("eingabe_max", max(1, s["richtwert"] * 3)),
            "skala": s.get("skala", "linear"),
        }
    if typ == "sortier":
        out["elemente"] = q["elemente"]
        out["reihenfolge"] = q["korrekt_reihenfolge"]
        out["werte"] = q.get("aufloesung_werte", [])
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", help="path to the original Monkey Money repo")
    parser.add_argument("--out", default="MonkeyMoney/ios/Resources/Content")
    args = parser.parse_args()
    src = Path(args.source)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    fragen = []
    for f in sorted(glob.glob(str(src / "content/packs/**/*.json"), recursive=True)):
        pack = json.loads(Path(f).read_text())
        for q in pack.get("fragen", []):
            fragen.append(compile_question(q))
    (out / "fragen.json").write_text(json.dumps({"version": 1, "fragen": fragen}, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(fragen)} Fragen -> {out / 'fragen.json'} ({(out / 'fragen.json').stat().st_size // 1024} KB)")

    tax = json.loads((src / "content/taxonomie.json").read_text())
    compact_tax = {
        "ober": [
            {"id": k["id"], "name": k["name"], "emoji": k["emoji"], "farbe": k["farbe"]}
            for k in tax["oberkategorien"]
        ],
        "unter": [
            {"id": u["slug"], "ober": u["oberkategorie"], "name": u["name"]}
            for u in tax["unterkategorien"]
        ],
    }
    (out / "taxonomie.json").write_text(json.dumps(compact_tax, ensure_ascii=False, separators=(",", ":")))

    songs = json.loads((src / "content/musik/songs.json").read_text())["songs"]
    compact_songs = []
    for s in songs:
        compact_songs.append({
            "id": s["id"],
            "titel": s["titel"],
            "artist": s.get("artist", ""),
            "jahr": s.get("jahr"),
            "region": s.get("region", "global"),
            "schw": SCHWIERIGKEIT.get(s.get("schwierigkeit", "mittel"), "medium"),
            "tags": s.get("tags", []),
            "hatVideo": bool(s.get("medien", {}).get("video3s")),
            "videoHint": s.get("videoHint"),
            "komponist": s.get("komponist"),
        })
    (out / "songs.json").write_text(json.dumps({"songs": compact_songs}, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(compact_songs)} Songs")

    pixel_out = out / "pixel"
    pixel_out.mkdir(exist_ok=True)
    for png in glob.glob(str(src / "assets/img/generated/pixel/*.png")):
        shutil.copy(png, pixel_out / Path(png).name)
    print("pixel images:", len(list(pixel_out.glob('*.png'))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
