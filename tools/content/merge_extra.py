#!/usr/bin/env python3
"""Merge the hand-written extra question packs (tools/content/extra/*.py) into fragen.json.

Each pack module defines KAT (top category id), optionally REGION (default region) and
DATA — a compact line format (one question per line, fields separated by " | ",
list items by " ; "):

    @ <sub> [de|global] [ab0|ab12|ab18]        switch sub-category (+ defaults for following lines)
    C <E|M|H|U> [flags] | text | correct | wrong1 ; wrong2 ; wrong3 | tipp1 ; tipp2 ; tipp3 | erkl
    W <diff> [flags]    | statement | wahr|falsch | erkl
    S <diff> [flags]    | text | richtwert | einheit | toleranz | min | max | tipps | erkl
    O <diff> [flags]    | text | item1 = wert1 ; item2 = wert2 ; item3 = wert3 ; item4 = wert4 | tipps | erkl
                          (items listed in the CORRECT order; they get shuffled for display)
    M <diff> [flags]    | text | right1 ; right2 | wrong1 ; wrong2 ; wrong3 ; wrong4 | tipps | erkl

    flags: de / global (region), ab0 / ab12 / ab18 (age), log (schaetz scale)
    difficulty: E=easy, M=medium, H=hard, U=ultrahard.  Lines starting with # are comments.

schaetz "toleranz" follows the existing bank: for years an absolute number of years (1–5),
otherwise a percentage (10–40).

Ids are deterministic: q_<kat>_<sub>_7NNNNN, numbered per sub in file order starting at 700001.
Re-running first drops every previously merged extra record (id number in the 7xxxxx range),
so the merge is idempotent.  New records are appended at the end of fragen.json (same compact
formatting as league_questions.py / compile_content.py).  Answer positions are shuffled with a
seeded RNG in blocks of four, so the correct index is spread evenly over 0–3.

Usage:  python3 tools/content/merge_extra.py            # validate + merge
        python3 tools/content/merge_extra.py --check    # validate + stats only
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import random
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "MonkeyMoney/ios/Resources/Content"
EXTRA = Path(__file__).resolve().parent / "extra"
ID_BASE = 700000
ID_RANGE = range(700000, 800000)

DIFF = {"E": "easy", "M": "medium", "H": "hard", "U": "ultrahard"}
TYPES = {"C": "choice", "W": "wahr_falsch", "S": "schaetz", "O": "sortier", "M": "mehrfach"}

# New sub-categories introduced by the extra packs (added to taxonomie.json if missing).
NEW_SUBS = [
    {"id": "energie_umwelttechnik", "ober": "technik_autos", "name": "Energie & Umwelttechnik"},
    {"id": "wetter_naturphaenomene", "ober": "tiere_natur", "name": "Wetter & Naturphänomene"},
    {"id": "obst_gemuese", "ober": "essen_trinken", "name": "Obst & Gemüse"},
    {"id": "maerchen_sagen", "ober": "kunst_literatur", "name": "Märchen & Sagen"},
]


class PackError(Exception):
    pass


def norm(text: str) -> str:
    t = unicodedata.normalize("NFC", text).lower()
    t = re.sub(r"[^\wäöüß]+", " ", t)
    return " ".join(t.split())


def num(s: str):
    s = s.strip().replace(",", ".")
    v = float(s)
    return int(v) if v == int(v) and "." not in s else v


def split_list(s: str) -> list[str]:
    return [x.strip() for x in s.split(" ; ") if x.strip()] if s.strip() else []


def load_pack(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


def parse_pack(path: Path, errors: list[str]) -> list[dict]:
    mod = load_pack(path)
    kat = mod.KAT
    region0 = getattr(mod, "REGION", "global")
    seed = int(hashlib.sha256(kat.encode()).hexdigest()[:8], 16)
    rng = random.Random(seed)
    slots: list[int] = []

    def next_slot() -> int:
        if not slots:
            block = [0, 1, 2, 3]
            rng.shuffle(block)
            slots.extend(block)
        return slots.pop()

    out = []
    sub, region, alter = None, region0, "ab0"
    for lineno, raw in enumerate(mod.DATA.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        where = f"{path.name}:{lineno}"
        try:
            if line.startswith("@"):
                parts = line[1:].split()
                sub, region, alter = parts[0], region0, "ab0"
                for p in parts[1:]:
                    if p in ("de", "global"):
                        region = p
                    elif p.startswith("ab"):
                        alter = p
                    else:
                        raise PackError(f"unknown sub flag {p!r}")
                continue
            if sub is None:
                raise PackError("question before first '@ sub' line")
            fields = [f.strip() for f in line.split(" | ")]
            head = fields[0].split()
            if len(head) < 2 or head[0] not in TYPES or head[1] not in DIFF:
                raise PackError(f"bad header {fields[0]!r}")
            typ, schw = TYPES[head[0]], DIFF[head[1]]
            q_region, q_alter, skala = region, alter, "linear"
            for f in head[2:]:
                if f in ("de", "global"):
                    q_region = f
                elif f in ("ab0", "ab12", "ab18"):
                    q_alter = f
                elif f == "log":
                    skala = "log"
                else:
                    raise PackError(f"unknown flag {f!r}")
            q = {"id": None, "kat": kat, "sub": sub, "schw": schw, "region": q_region, "typ": typ, "alter": q_alter,
                 "text": fields[1]}
            if typ == "choice":
                if len(fields) != 6:
                    raise PackError(f"choice needs 6 fields, got {len(fields)}")
                correct, wrongs = fields[2], split_list(fields[3])
                if len(wrongs) != 3:
                    raise PackError(f"choice needs 3 wrong answers, got {wrongs}")
                opts = wrongs[:]
                rng.shuffle(opts)
                k = next_slot()
                opts.insert(k, correct)
                q.update(tipps=split_list(fields[4]), erkl=fields[5], antworten=opts, korrekt=k)
            elif typ == "wahr_falsch":
                if len(fields) != 4 or fields[2] not in ("wahr", "falsch"):
                    raise PackError("wahr_falsch needs: text | wahr|falsch | erkl")
                q.update(tipps=[], erkl=fields[3], korrektBool=fields[2] == "wahr")
            elif typ == "schaetz":
                if len(fields) == 10 and fields[7] == "log":  # tolerate "| log |" before the tipps
                    skala = "log"
                    del fields[7]
                if len(fields) != 9:
                    raise PackError(f"schaetz needs 9 fields, got {len(fields)}")
                q.update(tipps=split_list(fields[7]), erkl=fields[8],
                         schaetz={"richtwert": num(fields[2]), "einheit": fields[3], "toleranz": num(fields[4]),
                                  "min": num(fields[5]), "max": num(fields[6]), "skala": skala})
            elif typ == "sortier":
                if len(fields) != 5:
                    raise PackError(f"sortier needs 5 fields, got {len(fields)}")
                items = [tuple(x.strip() for x in it.split(" = ", 1)) for it in split_list(fields[2])]
                if any(len(it) != 2 for it in items):
                    raise PackError("sortier items need 'label = wert'")
                idx = list(range(len(items)))
                shuffled = idx[:]
                while shuffled == idx or shuffled == idx[::-1]:
                    rng.shuffle(shuffled)
                q.update(tipps=split_list(fields[3]), erkl=fields[4],
                         elemente=[items[i][0] for i in shuffled],
                         reihenfolge=[shuffled.index(i) for i in idx],
                         werte=[it[1] for it in items])
            elif typ == "mehrfach":
                if len(fields) != 6:
                    raise PackError(f"mehrfach needs 6 fields, got {len(fields)}")
                right, wrong = split_list(fields[2]), split_list(fields[3])
                opts = right + wrong
                rng.shuffle(opts)
                q.update(tipps=split_list(fields[4]), erkl=fields[5], antworten=opts,
                         korrektMehrfach=sorted(opts.index(r) for r in right))
            q["_where"] = where
            out.append(q)
        except (PackError, ValueError, IndexError) as e:
            errors.append(f"{where}: {e}")
    return out


def validate(q: dict, subs: dict[str, str]) -> list[str]:
    e = []
    t = q["typ"]
    if subs.get(q["sub"]) != q["kat"]:
        e.append(f"sub {q['sub']!r} is not a sub-category of {q['kat']!r}")
    if q["region"] not in ("de", "global") or q["alter"] not in ("ab0", "ab12", "ab18"):
        e.append("bad region/alter")
    text = q["text"]
    if len(text) < 12:
        e.append("text too short")
    if t in ("choice", "schaetz", "sortier", "mehrfach") and not text.rstrip().rstrip("“”«»)").endswith(("?", ".", "!", ":", "…")):
        e.append("text should end with punctuation")
    if not q["erkl"] or len(q["erkl"]) < 15:
        e.append("erkl missing/too short")
    if t != "wahr_falsch":
        if len(q["tipps"]) != 3:
            e.append(f"needs exactly 3 tipps, got {len(q['tipps'])}")
    if '"' in text + q["erkl"] + "".join(q["tipps"]) + "".join(q.get("antworten", [])):
        e.append("use typographic quotes „…“ instead of straight quotes")
    if t == "choice":
        a = q["antworten"]
        if len(a) != 4 or len({x.strip().lower() for x in a}) != 4:
            e.append(f"choice needs 4 unique options: {a}")
        if not (0 <= q["korrekt"] < len(a)):
            e.append("korrekt out of range")
        correct = norm(a[q["korrekt"]])
        for tip in q["tipps"]:
            if correct and len(correct) > 3 and re.search(rf"\b{re.escape(correct)}\b", norm(tip)):
                e.append(f"tipp gives the answer away: {tip!r}")
    elif t == "mehrfach":
        a, k = q["antworten"], q["korrektMehrfach"]
        if len(a) != 6 or len({x.strip().lower() for x in a}) != 6:
            e.append(f"mehrfach needs 6 unique options: {a}")
        if not (2 <= len(k) <= 3) or len(set(k)) != len(k) or not all(0 <= i < len(a) for i in k):
            e.append("korrektMehrfach invalid")
    elif t == "schaetz":
        s = q["schaetz"]
        if not (s["min"] < s["richtwert"] < s["max"]):
            e.append(f"schaetz needs min < richtwert < max: {s}")
        if s["toleranz"] <= 0:
            e.append("toleranz must be > 0")
        if s["skala"] == "log" and s["min"] <= 0:
            e.append("log scale needs min > 0")
    elif t == "sortier":
        el, r, w = q["elemente"], q["reihenfolge"], q["werte"]
        if len(el) != 4 or len(set(el)) != 4:
            e.append("sortier needs 4 unique elements")
        if sorted(r) != list(range(len(el))):
            e.append("reihenfolge must be a permutation")
        if len(w) != len(el) or not all(isinstance(x, str) and x for x in w):
            e.append("werte must be one non-empty string per element")
    elif t == "wahr_falsch":
        if not isinstance(q.get("korrektBool"), bool):
            e.append("korrektBool missing")
    return e


def main() -> int:
    check_only = "--check" in sys.argv
    fragen_path, tax_path = CONTENT / "fragen.json", CONTENT / "taxonomie.json"
    data = json.loads(fragen_path.read_text(encoding="utf-8"))
    tax = json.loads(tax_path.read_text(encoding="utf-8"))

    tax_ids = {u["id"] for u in tax["unter"]}
    added_subs = [s for s in NEW_SUBS if s["id"] not in tax_ids]
    subs = {u["id"]: u["ober"] for u in tax["unter"]} | {s["id"]: s["ober"] for s in NEW_SUBS}

    def is_extra(q):
        return int(q["id"].rsplit("_", 1)[1]) in ID_RANGE

    base = [q for q in data["fragen"] if not is_extra(q)]
    removed = len(data["fragen"]) - len(base)
    base_ids = {q["id"] for q in base}
    base_texts = {norm(q["text"]): q["id"] for q in base}

    errors: list[str] = []
    new: list[dict] = []
    for path in sorted(EXTRA.glob("*.py")):
        if path.name.startswith("_"):
            continue
        new.extend(parse_pack(path, errors))

    seq: Counter = Counter()
    seen_texts: dict[str, str] = {}
    for q in new:
        where = q.pop("_where")
        seq[(q["kat"], q["sub"])] += 1
        q["id"] = f"q_{q['kat']}_{q['sub']}_{ID_BASE + seq[(q['kat'], q['sub'])]:06d}"
        for err in validate(q, subs):
            errors.append(f"{where} [{q['id']}]: {err}")
        n = norm(q["text"])
        if n in base_texts:
            errors.append(f"{where}: duplicate of existing {base_texts[n]}: {q['text']!r}")
        if n in seen_texts:
            errors.append(f"{where}: duplicate text within extras (also {seen_texts[n]})")
        seen_texts[n] = where
        if q["id"] in base_ids:
            errors.append(f"{where}: id collision {q['id']}")

    # --- near-duplicate warnings (same topic phrased differently) ---------------------------
    if "--similar" in sys.argv:
        stop = {"der", "die", "das", "und", "ein", "eine", "welche", "welcher", "welches", "wie", "was", "wer", "ist",
                "in", "im", "von", "mit", "den", "dem", "des", "zu", "auf", "für", "hat", "heißt", "wurde", "diese",
                "dieser", "sich", "man", "als", "am", "an", "es", "aus", "bei", "nach", "vom", "zum", "zur", "wird"}
        def words(t):
            return {w for w in norm(t).split() if w not in stop and len(w) > 2}
        index = defaultdict(set)
        base_words = []
        for i, q in enumerate(base):
            ws = words(q["text"])
            base_words.append(ws)
            for w in ws:
                index[w].add(i)
        for q in new:
            ws = words(q["text"])
            cand = Counter(i for w in ws for i in index[w])
            for i, c in cand.most_common(3):
                j = c / max(1, len(ws | base_words[i]))
                if j >= 0.45:
                    print(f"similar ({j:.2f}): {q['id']}: {q['text']}\n        ~ {base[i]['id']}: {base[i]['text']}")

    # --- statistics -----------------------------------------------------------------------
    print(f"extra questions parsed: {len(new)}")
    by_kat = Counter(q["kat"] for q in new)
    for kat in [o["id"] for o in tax["ober"]]:
        qs = [q for q in new if q["kat"] == kat]
        print(f"  {kat:22s} {by_kat[kat]:4d}  types={dict(Counter(q['typ'] for q in qs))}  diff={dict(Counter(q['schw'] for q in qs))}")
    print("types:", dict(Counter(q["typ"] for q in new)))
    print("difficulty:", dict(Counter(q["schw"] for q in new)))
    print("alter:", dict(Counter(q["alter"] for q in new)), " region:", dict(Counter(q["region"] for q in new)))
    print("korrekt index (choice):", dict(sorted(Counter(q["korrekt"] for q in new if q["typ"] == "choice").items())))
    print("wahr/falsch:", dict(Counter(q["korrektBool"] for q in new if q["typ"] == "wahr_falsch")))
    per_sub = defaultdict(int)
    for q in base + new:
        per_sub[q["sub"]] += 1
    thin = {s: per_sub[s] for s in subs if per_sub[s] < 40}
    print("subs with < 40 questions after merge:", thin or "none")

    if errors:
        print(f"\n{len(errors)} validation error(s):")
        for e in errors:
            print("  " + e)
        return 1
    if check_only:
        print("check ok (nothing written)")
        return 0

    data["fragen"] = base + new
    fragen_path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if added_subs:
        tax["unter"].extend(added_subs)
        tax_path.write_text(json.dumps(tax, ensure_ascii=False), encoding="utf-8")
    print(f"\nremoved {removed} previously merged extras, added {len(new)}; "
          f"fragen.json now has {len(data['fragen'])} questions; new subs added: {[s['id'] for s in added_subs]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
