#!/usr/bin/env python3
"""Generate the Monkey Money soundtrack with the Treblo (Sonauto) v3 API.

Usage:
    TREBLO_API_KEY=sk... python3 tools/music/generate_music.py [--only cue1,cue2] [--out DIR]

Every v3 generation costs 100 credits. The script submits all cues in parallel,
polls until they finish and downloads the audio as .m4a into the output folder
(default: MonkeyMoney/ios/Resources/Audio/Music). A `manifest.json` next to the
files records prompt, task id and model version so the tracks stay reproducible.
The API key is only ever read from the environment - never commit it.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

API = "https://api.treblo.com/v1"

# (cue id, prompt, [min_seconds, max_seconds])
CUES: list[tuple[str, str, list[int]]] = [
    ("theme_main",
     "Upbeat jungle TV game show main theme, big brass fanfare, tropical percussion, marimba and steel drums, "
     "playful mischievous monkey energy, casino jackpot bells, glamorous, catchy hook, instrumental",
     [60, 120]),
    ("lobby_loop",
     "Chill tropical lounge groove for a party quiz waiting room, marimba, steel drums, soft congas, laid back jungle "
     "ambience, playful, warm, loopable, instrumental",
     [120, 180]),
    ("intro_stinger",
     "Epic 30 second game show opening fanfare, drum roll build up, brass hit, tropical jungle drums, huge triumphant "
     "final chord, instrumental",
     [0, 30]),
    ("question_bed_easy",
     "Light suspenseful quiz show thinking music, ticking clock, soft marimba pulse, jungle percussion, playful tension, "
     "steady tempo, loopable underscore, instrumental",
     [60, 120]),
    ("question_bed_hard",
     "Dark suspenseful quiz show tension underscore, deep bass drone, heartbeat pulse, ticking clock, cinematic tribal "
     "jungle drums, high stakes, loopable, instrumental",
     [60, 120]),
    ("money_moment",
     "Triumphant 20 second jackpot win jingle, cash register, brass fanfare, casino slot machine bells, tropical "
     "percussion flourish, instrumental",
     [0, 30]),
    ("wheel_spin",
     "Carnival wheel of fortune spinning music, circus organ, accelerating then slowing percussion, playful suspense, "
     "tropical twist, big reveal ending, instrumental",
     [30, 60]),
    ("bank_round",
     "Exciting casino heist jazz funk, walking upright bass, big band brass stabs, urgent hi hats, money vault vibe, "
     "loopable, instrumental",
     [60, 120]),
    ("finale_showdown",
     "Epic quiz show finale music, urgent tribal jungle drums, cinematic orchestral brass, rising tension, heroic, "
     "dramatic, driving, instrumental",
     [90, 150]),
    ("victory_podium",
     "Triumphant victory celebration, brass fanfare, tropical samba party, confetti energy, cheering crowd feel, "
     "awards ceremony, joyful, instrumental",
     [60, 120]),
    ("standings_groove",
     "Smooth upbeat lounge funk for a scoreboard interlude, funky guitar, tropical keys, relaxed groove, loopable, "
     "instrumental",
     [60, 120]),
    ("bomb_pass",
     "Frantic hot potato ticking bomb chase music, fast comedic percussion, tuba, panic, cartoon jungle chaos, "
     "accelerating, instrumental",
     [60, 90]),
    ("estimate_think",
     "Mysterious thinking music, vibraphone, soft jazz brushes, curiosity, treasure vault, gentle suspense, loopable, "
     "instrumental",
     [60, 120]),
    ("pixel_retro",
     "Retro 8 bit chiptune jungle adventure music, upbeat arcade, playful, bouncy bass, loopable, instrumental",
     [60, 120]),
    ("jackpot_drama",
     "Dramatic jackpot question build up, timpani, long drum roll, choir stabs, casino bells, cinematic tension, "
     "instrumental",
     [30, 60]),
    ("boardgame_bed",
     "Relaxed cozy board game night music, acoustic guitar, ukulele, marimba, warm and playful, gentle percussion, "
     "loopable, instrumental",
     [120, 180]),
    ("credits_outro",
     "Warm nostalgic end credits music, jazzy piano, mellow brass, tropical sunset feel, feel good goodbye, instrumental",
     [60, 120]),
    ("werwolf_night",
     "Spooky mysterious jungle night ambience music, owl calls, low strings, slow tribal drums, whispering mystery, "
     "loopable, instrumental",
     [90, 150]),
    ("duel_showdown",
     "Spaghetti western showdown duel music with a jungle twist, whistling, twangy guitar, tribal drums, tense standoff, "
     "instrumental",
     [60, 90]),
    ("steal_sneak",
     "Sneaky pickpocket thief music, pizzicato strings, cartoon sneaking jazz, muted trumpet, playful mischief, "
     "instrumental",
     [30, 60]),
    ("market_trade",
     "Busy tropical bazaar marketplace trading music, upbeat hand percussion, accordion, marimba, lively haggling "
     "energy, loopable, instrumental",
     [60, 120]),
    ("music_round_dj",
     "Funky DJ party music, disco strings, turntable scratches, upbeat dance groove, tropical brass, loopable, "
     "instrumental",
     [60, 120]),
]


def api(path: str, key: str, body: dict | None = None) -> dict | str:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path,
        data=data,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST" if data else "GET",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw.strip().strip('"')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="", help="comma separated cue ids")
    parser.add_argument("--out", default="MonkeyMoney/ios/Resources/Audio/Music")
    parser.add_argument("--format", default="m4a")
    parser.add_argument("--bitrate", type=int, default=128)
    args = parser.parse_args()

    key = os.environ.get("TREBLO_API_KEY")
    if not key:
        print("TREBLO_API_KEY is not set", file=sys.stderr)
        return 2

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = out / "manifest.json"
    manifest: dict = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}

    wanted = [c for c in CUES if not args.only or c[0] in args.only.split(",")]
    balance = api("/credits/balance", key)
    print("credits:", balance)

    pending: dict[str, tuple[str, str]] = {}
    for cue_id, prompt, length in wanted:
        if cue_id in manifest and (out / f"{cue_id}.{args.format}").exists():
            print(f"skip {cue_id} (already generated)")
            continue
        body = {
            "prompt": prompt,
            "instrumental": True,
            "length_range": length,
            "output_format": args.format,
            "output_bit_rate": args.bitrate,
        }
        try:
            res = api("/generations/v3", key, body)
        except urllib.error.HTTPError as e:
            print(f"submit {cue_id} failed: {e} {e.read().decode()[:300]}", file=sys.stderr)
            continue
        task_id = res["task_id"] if isinstance(res, dict) else str(res)
        pending[task_id] = (cue_id, prompt)
        print(f"submitted {cue_id}: {task_id}")
        time.sleep(1.0)

    while pending:
        time.sleep(8)
        for task_id in list(pending):
            cue_id, prompt = pending[task_id]
            try:
                status = api(f"/generations/status/{task_id}", key)
            except urllib.error.HTTPError as e:
                print(f"status {cue_id}: {e}")
                continue
            status = status.get("status") if isinstance(status, dict) else status
            print(f"  {cue_id}: {status}")
            if status == "SUCCESS":
                info = api(f"/generations/{task_id}", key)
                url = info["song_paths"][0]
                target = out / f"{cue_id}.{args.format}"
                urllib.request.urlretrieve(url, target)
                manifest[cue_id] = {
                    "task_id": task_id,
                    "prompt": prompt,
                    "model_version": info.get("model_version"),
                    "tags": info.get("tags"),
                    "bytes": target.stat().st_size,
                }
                manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
                print(f"downloaded {target} ({target.stat().st_size // 1024} KB)")
                del pending[task_id]
            elif status == "FAILURE":
                info = api(f"/generations/{task_id}", key)
                print(f"FAILED {cue_id}: {info.get('error_message') if isinstance(info, dict) else info}")
                del pending[task_id]

    print("credits after:", api("/credits/balance", key))
    return 0


if __name__ == "__main__":
    sys.exit(main())
