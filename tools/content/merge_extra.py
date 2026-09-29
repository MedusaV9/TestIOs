#!/usr/bin/env python3
"""Merge the hand-written extra question packs into fragen.json.

Two pack folders, each with its own id range (ids must never change — Show-Masters ban
single questions by id):

    tools/content/extra/*.py   → q_<kat>_<sub>_7NNNNN   (first wave, starting at 700001 per sub)
    tools/content/extra2/*.py  → q_<kat>_<sub>_8NNNNN   (second wave, starting at 800001 per sub)

Numbering is per (kat, sub) in file order (files sorted by name) and restarts for every folder,
so adding packs to extra2 never renumbers a 7xxxxx question.  NEVER insert lines in front of
existing ones inside a folder — append new questions at the end of a sub's block or in a new
file that sorts last, otherwise later ids of that sub shift.

Each pack module defines KAT (top category id), optionally REGION (default region) and
DATA — a compact line format (one question per line, fields separated by " | ",
list items by " ; "):

    @ <sub> [de|global] [ab0|ab12|ab18]        switch sub-category (+ defaults for following lines)
    C <E|M|H|U> [flags] | text | correct | wrong1 ; wrong2 ; wrong3 | tipp1 ; tipp2 ; tipp3 | erkl
    E <diff> [flags]    | text | emojis | correct | wrong1 ; wrong2 ; wrong3 | tipp1 ; tipp2 ; tipp3 | erkl
                          (emoji rebus: 2–6 emoji without spaces, e.g. "Welcher Film ist hier gesucht?")
    W <diff> [flags]    | statement | wahr|falsch | erkl
    S <diff> [flags]    | text | richtwert | einheit | toleranz | min | max | tipps | erkl
    O <diff> [flags]    | text | item1 = wert1 ; item2 = wert2 ; item3 = wert3 ; item4 = wert4 | tipps | erkl
                          (items listed in the CORRECT order; they get shuffled for display)
    M <diff> [flags]    | text | right1 ; right2 | wrong1 ; wrong2 ; wrong3 ; wrong4 | tipps | erkl

    flags: de / global (region), ab0 / ab12 / ab18 (age), log (schaetz scale)
    difficulty: E=easy, M=medium, H=hard, U=ultrahard.  Lines starting with # are comments.
    (The first letter is the type, the second the difficulty — "E M" is a medium emoji rebus.)

schaetz "toleranz" follows the existing bank: for years an absolute number of years (1–5),
otherwise a percentage (10–40).

Re-running first drops every previously merged extra record (id number in 700000–899999),
so the merge is idempotent.  New records are appended at the end of fragen.json (extra first,
then extra2; same compact formatting as league_questions.py / compile_content.py).  Answer
positions are shuffled with a seeded RNG in blocks of four, so the correct index is spread evenly
over 0–3.  The files are written atomically (temp file in the same folder + os.replace), because
running servers read them, and only when their content actually changes.

Usage:  python3 tools/content/merge_extra.py              # validate + merge
        python3 tools/content/merge_extra.py --check      # validate + stats only
        python3 tools/content/merge_extra.py --similar    # + near-duplicate report for extra2
                                                          #   (keyword + answer overlap vs. whole bank)
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import random
import re
import sys
import tempfile
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "MonkeyMoney/ios/Resources/Content"
HERE = Path(__file__).resolve().parent
# (folder, id base, seed prefix).  The first wave seeds its RNG with the bare KAT — keep it that
# way, or every 7xxxxx record would reshuffle its answers.
SOURCES = [
    (HERE / "extra", 700000, ""),
    (HERE / "extra2", 800000, "extra2/"),
]
ID_RANGE = range(700000, 900000)

DIFF = {"E": "easy", "M": "medium", "H": "hard", "U": "ultrahard"}
TYPES = {"C": "choice", "E": "emoji", "W": "wahr_falsch", "S": "schaetz", "O": "sortier", "M": "mehrfach"}

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


_JOINERS = {0x200D, 0xFE0E, 0xFE0F, 0x20E3}


def emoji_clusters(s: str) -> list[str]:
    """Split an emoji string into user-visible emoji (ZWJ sequences, skin tones, flags, keycaps)."""
    out: list[str] = []
    glue = False  # previous code point was a ZWJ
    flag_open = False
    for ch in s:
        cp = ord(ch)
        if out and (glue or cp in _JOINERS or 0x1F3FB <= cp <= 0x1F3FF or 0xE0020 <= cp <= 0xE007F):
            out[-1] += ch
            glue = cp == 0x200D
            continue
        if 0x1F1E6 <= cp <= 0x1F1FF:  # regional indicators pair up into flags
            if flag_open:
                out[-1] += ch
                flag_open = False
                continue
            flag_open = True
        else:
            flag_open = False
        out.append(ch)
        glue = False
    return out


def emoji_key(s: str) -> str:
    return "".join(ch for ch in s if ord(ch) not in (0xFE0E, 0xFE0F))


def load_pack(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


def parse_pack(path: Path, errors: list[str], seed_prefix: str = "") -> list[dict]:
    mod = load_pack(path)
    kat = mod.KAT
    region0 = getattr(mod, "REGION", "global")
    seed_key = kat if not seed_prefix else f"{seed_prefix}{path.stem}"
    seed = int(hashlib.sha256(seed_key.encode()).hexdigest()[:8], 16)
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
        where = f"{path.parent.name}/{path.name}:{lineno}"
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
            elif typ == "emoji":
                if len(fields) != 7:
                    raise PackError(f"emoji needs 7 fields, got {len(fields)}")
                emojis, correct, wrongs = fields[2], fields[3], split_list(fields[4])
                if len(wrongs) != 3:
                    raise PackError(f"emoji needs 3 wrong answers, got {wrongs}")
                opts = wrongs[:]
                rng.shuffle(opts)
                k = next_slot()
                opts.insert(k, correct)
                q.update(tipps=split_list(fields[5]), erkl=fields[6], antworten=opts, korrekt=k, emojis=emojis)
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
    if t in ("choice", "emoji", "schaetz", "sortier", "mehrfach") and not text.rstrip().rstrip("“”«»)").endswith(("?", ".", "!", ":", "…")):
        e.append("text should end with punctuation")
    if not q["erkl"] or len(q["erkl"]) < 15:
        e.append("erkl missing/too short")
    if t != "wahr_falsch":
        if len(q["tipps"]) != 3:
            e.append(f"needs exactly 3 tipps, got {len(q['tipps'])}")
    if '"' in text + q["erkl"] + "".join(q["tipps"]) + "".join(q.get("antworten", [])) + "".join(q.get("elemente", [])):
        e.append("use typographic quotes „…“ instead of straight quotes")
    if t in ("choice", "emoji"):
        a = q["antworten"]
        if len(a) != 4 or len({x.strip().lower() for x in a}) != 4:
            e.append(f"{t} needs 4 unique options: {a}")
        if not (0 <= q["korrekt"] < len(a)):
            e.append("korrekt out of range")
        correct = norm(a[q["korrekt"]])
        for tip in q["tipps"]:
            if correct and len(correct) > 3 and re.search(rf"\b{re.escape(correct)}\b", norm(tip)):
                e.append(f"tipp gives the answer away: {tip!r}")
    if t == "emoji":
        em = q["emojis"]
        cl = emoji_clusters(em)
        if not (2 <= len(cl) <= 6):
            e.append(f"emoji needs 2–6 emoji, got {len(cl)}: {em!r}")
        if any(ch.isspace() for ch in em) or any(c[0].isascii() and "\u20e3" not in c for c in cl):
            e.append(f"emojis must be emoji only (no letters/spaces): {em!r}")
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


def correct_answer(q: dict) -> str:
    if q["typ"] in ("choice", "emoji", "bild_pixel") and q.get("antworten") and q.get("korrekt") is not None:
        return q["antworten"][q["korrekt"]]
    return ""


STOP = {"der", "die", "das", "und", "ein", "eine", "einen", "einem", "einer", "welche", "welcher", "welches", "wie",
        "was", "wer", "ist", "in", "im", "von", "mit", "den", "dem", "des", "zu", "auf", "für", "hat", "heißt",
        "wurde", "diese", "dieser", "diesen", "sich", "man", "als", "am", "an", "es", "aus", "bei", "nach", "vom",
        "zum", "zur", "wird", "sind", "zwei", "drei", "vier", "sortiere", "zuerst", "hier", "gesucht", "nicht",
        "oder", "auch", "noch", "nur", "sein", "seine", "ihre", "ihr", "viele", "wieviele", "ungefähr", "etwa",
        "jahr", "welchem", "welchen", "gibt", "ersten", "erste", "erster", "heute", "kommt", "stammt", "trägt",
        "nennt", "wo", "wann", "war", "waren", "hatte", "the"}


def words(t: str) -> set[str]:
    return {w for w in norm(t).split() if w not in STOP and len(w) > 2}


def similar_report(new: list[dict], bank: list[dict]) -> int:
    """Keyword/answer-overlap report: every new question vs. the whole bank (and earlier new ones)."""
    pool = list(bank)
    index: dict[str, set[int]] = defaultdict(set)
    pool_words: list[set[str]] = []
    by_answer: dict[str, list[int]] = defaultdict(list)

    def add(q):
        i = len(pool_words)
        ws = words(q["text"])
        pool_words.append(ws)
        for w in ws:
            index[w].add(i)
        a = norm(correct_answer(q))
        if a:
            by_answer[(q["typ"] == "emoji", a)].append(i)

    for q in pool:
        add(q)
    hits = 0
    for q in new:
        ws = words(q["text"])
        ans = norm(correct_answer(q))
        flagged = []
        cand = Counter(i for w in ws for i in index[w])
        for i, c in cand.most_common(4):
            j = c / max(1, len(ws | pool_words[i]))
            same_ans = ans and ans == norm(correct_answer(pool[i]))
            if j >= 0.45 or (same_ans and j >= 0.2):
                flagged.append((j, i, "text" if not same_ans else "text+answer"))
        if ans and q["typ"] == "emoji":
            for i in by_answer.get((True, ans), []):
                flagged.append((1.0, i, "same emoji answer"))
        elif ans and len(ans) > 3:
            # Same correct answer in the same sub-category → probably the same topic.
            for i in by_answer.get((False, ans), []):
                if pool[i]["sub"] == q["sub"] and all(i != f[1] for f in flagged):
                    j = len(ws & pool_words[i]) / max(1, len(ws | pool_words[i]))
                    if j >= 0.12:
                        flagged.append((j, i, "same answer, same sub"))
        seen = set()
        for j, i, why in flagged:
            if i in seen:
                continue
            seen.add(i)
            hits += 1
            o = pool[i]
            print(f"similar ({why} {j:.2f}): {q['id']}: {q['text']} [{correct_answer(q) or q.get('emojis', '')}]\n"
                  f"        ~ {o['id']}: {o['text']} [{correct_answer(o)}]")
        pool.append(q)
        add(q)
    print(f"--similar: {hits} hit(s)")
    return hits


def write_atomic(path: Path, text: str) -> bool:
    """Write text to path via a temp file in the same folder + os.replace. Returns False if unchanged."""
    data = text.encode("utf-8")
    if path.exists() and path.read_bytes() == data:
        return False
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise
    return True


def stats(title: str, qs: list[dict], tax: dict) -> None:
    print(f"{title}: {len(qs)}")
    by_kat = Counter(q["kat"] for q in qs)
    for kat in [o["id"] for o in tax["ober"]]:
        kq = [q for q in qs if q["kat"] == kat]
        print(f"  {kat:22s} {by_kat[kat]:4d}  types={dict(Counter(q['typ'] for q in kq))}  diff={dict(Counter(q['schw'] for q in kq))}")
    print("  types:", dict(Counter(q["typ"] for q in qs)))
    print("  difficulty:", dict(Counter(q["schw"] for q in qs)))
    print("  alter:", dict(Counter(q["alter"] for q in qs)), " region:", dict(Counter(q["region"] for q in qs)))
    print("  korrekt index (choice/emoji):", dict(sorted(Counter(q["korrekt"] for q in qs if q["typ"] in ("choice", "emoji")).items())))
    print("  wahr/falsch:", dict(Counter(q["korrektBool"] for q in qs if q["typ"] == "wahr_falsch")))
    print("  subs used:", len({q["sub"] for q in qs}))


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
    seen_texts: dict[str, str] = {norm(q["text"]): q["id"] for q in base if q["typ"] != "emoji"}
    seen_emojis: dict[str, str] = {emoji_key(q["emojis"]): q["id"] for q in base if q["typ"] == "emoji" and q.get("emojis")}

    errors: list[str] = []
    waves: list[list[dict]] = []
    for folder, id_base, seed_prefix in SOURCES:
        wave: list[dict] = []
        for path in sorted(folder.glob("*.py")) if folder.is_dir() else []:
            if path.name.startswith("_"):
                continue
            wave.extend(parse_pack(path, errors, seed_prefix))
        seq: Counter = Counter()
        for q in wave:
            where = q.pop("_where")
            seq[(q["kat"], q["sub"])] += 1
            n_id = id_base + seq[(q["kat"], q["sub"])]
            if n_id >= id_base + 100000:
                errors.append(f"{where}: id range of {folder.name} exhausted for {q['sub']}")
            q["id"] = f"q_{q['kat']}_{q['sub']}_{n_id:06d}"
            for err in validate(q, subs):
                errors.append(f"{where} [{q['id']}]: {err}")
            if q["typ"] == "emoji":
                k = emoji_key(q["emojis"])
                if k in seen_emojis:
                    errors.append(f"{where}: same emoji string as {seen_emojis[k]}: {q['emojis']!r}")
                seen_emojis[k] = q["id"]
            else:
                n = norm(q["text"])
                if n in seen_texts:
                    errors.append(f"{where}: duplicate text (also {seen_texts[n]}): {q['text']!r}")
                seen_texts[n] = q["id"]
            if q["id"] in base_ids:
                errors.append(f"{where}: id collision {q['id']}")
        waves.append(wave)
    new = [q for w in waves for q in w]

    # Emoji rebuses with the same solution are near-duplicates, whatever the emoji.
    emoji_answers: dict[str, str] = {}
    for q in base + new:
        if q["typ"] == "emoji":
            a = norm(correct_answer(q))
            if a in emoji_answers and is_extra(q):
                errors.append(f"[{q['id']}]: emoji solution {correct_answer(q)!r} already used by {emoji_answers[a]}")
            emoji_answers.setdefault(a, q["id"])

    if "--similar" in sys.argv:
        similar_report(waves[-1], base + [q for w in waves[:-1] for q in w])

    # --- statistics -----------------------------------------------------------------------
    for (folder, _, _), wave in zip(SOURCES, waves):
        stats(f"{folder.name} questions parsed", wave, tax)
    per_sub = defaultdict(int)
    for q in base + new:
        per_sub[q["sub"]] += 1
    thin = {s: per_sub[s] for s in subs if per_sub[s] < 40}
    print("subs with < 40 questions after merge:", thin or "none")
    print("bank after merge:", len(base) + len(new), dict(Counter(q["typ"] for q in base + new)))

    if errors:
        print(f"\n{len(errors)} validation error(s):")
        for e in errors:
            print("  " + e)
        return 1
    if check_only:
        print("check ok (nothing written)")
        return 0

    data["fragen"] = base + new
    wrote = write_atomic(fragen_path, json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    if added_subs:
        tax["unter"].extend(added_subs)
        write_atomic(tax_path, json.dumps(tax, ensure_ascii=False))
    print(f"\nremoved {removed} previously merged extras, added {len(new)} "
          f"({' + '.join(f'{len(w)} {f.name}' for (f, _, _), w in zip(SOURCES, waves))}); "
          f"fragen.json now has {len(data['fragen'])} questions ({'written' if wrote else 'unchanged'}); "
          f"new subs added: {[s['id'] for s in added_subs]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
