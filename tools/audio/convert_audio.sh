#!/usr/bin/env bash
# Convert the CC0/CC-BY sound effects and song snippets of the original Monkey
# Money web project (OGG Vorbis) into AAC (.m4a) so that AVAudioPlayer on iOS
# and Safari on the phones can play them. Usage:
#   tools/audio/convert_audio.sh <original-repo-path>
set -euo pipefail
SRC="${1:?path to original Monkey Money repo}"
OUT="$(cd "$(dirname "$0")/../.." && pwd)/MonkeyMoney/ios/Resources/Audio"
mkdir -p "$OUT/SFX" "$OUT/Songs" "$OUT/Beds"

conv() { # in out
  [[ -f "$2" ]] && return 0
  ffmpeg -loglevel error -y -i "$1" -vn -c:a aac -b:a 96k -movflags +faststart "$2"
}

# Curated SFX set (id -> source file). Ids are what AudioCue in the app uses.
declare -A SFX=(
  [tap]="client/public/audio/sfx/tap_schalter_1_cc0_bsb.ogg"
  [tap2]="client/public/audio/sfx/tap_schalter_2_cc0_bsb.ogg"
  [richtig]="client/public/audio/sfx/richtig_triangel_cc0_bsb.ogg"
  [falsch]="client/public/audio/sfx/falsch_buzz_cc0_bsb.ogg"
  [fehlbuzz]="client/public/audio/sfx/fehlbuzz_alarm_cc0_bsb.ogg"
  [tick]="client/public/audio/sfx/tick_metronom_a_cc0_bsb.ogg"
  [tick_schnell]="client/public/audio/sfx/tick_metronom_b_cc0_bsb.ogg"
  [muenze1]="client/public/audio/sfx/muenze_einzeln_1_cc0_bsb.ogg"
  [muenze2]="client/public/audio/sfx/muenze_einzeln_2_cc0_bsb.ogg"
  [muenze3]="client/public/audio/sfx/muenze_einzeln_3_cc0_bsb.ogg"
  [muenzregen]="client/public/audio/sfx/muenzregen_cc0_bsb.ogg"
  [kaching]="client/public/audio/sfx/kasse_kaching_pd_wikimedia.ogg"
  [klau]="client/public/audio/sfx/klau_wusch_cc0_bsb.ogg"
  [reveal]="client/public/audio/sfx/reveal_blitzlicht_cc0_bsb.ogg"
  [joker]="client/public/audio/sfx/joker_korken_cc0_bsb.ogg"
  [frage_ein]="client/public/audio/sfx/frage_seite_cc0_bsb.ogg"
  [trommelwirbel]="client/public/audio/sfx/trommelwirbel_kurz_ccby_macleod.ogg"
  [trommelwirbel_lang]="client/public/audio/sfx/trommelwirbel_lang_cc0_iwan.ogg"
  [riser]="client/public/audio/sfx/riser_ccby_tritachyon.ogg"
  [buzzer_airhorn]="client/public/audio/sfx/buzzer_airhorn_cc0_bsb.ogg"
  [buzzer_boing]="client/public/audio/sfx/buzzer_boing_cc0_bsb.ogg"
  [buzzer_glocke]="client/public/audio/sfx/buzzer_glocke_cc0_bsb.ogg"
  [buzzer_hupe]="client/public/audio/sfx/buzzer_hupe_cc0_bsb.ogg"
  [buzzer_klingel]="client/public/audio/sfx/buzzer_klingel_cc0_bsb.ogg"
  [buzzer_pfeife]="client/public/audio/sfx/buzzer_pfeife_cc0_bsb.ogg"
  [buzzer_quaek]="client/public/audio/sfx/buzzer_quaek_cc0_bsb.ogg"
  [buzzer_wecker]="client/public/audio/sfx/buzzer_wecker_cc0_bsb.ogg"
  [applaus_kurz]="assets/audio/crowd/applause_kurz_pd_thore.ogg"
  [applaus_mittel]="assets/audio/crowd/applause_mittel_pd_thore.ogg"
  [applaus_jubel]="assets/audio/crowd/applause_jubel_pd_starlite.ogg"
  [applaus_gross]="assets/audio/crowd/applause_gross_ccby_RHumphries.ogg"
  [wuerfel1]="client/public/audio/sfx/dice-throw-1.ogg"
  [wuerfel2]="client/public/audio/sfx/dice-throw-2.ogg"
  [wuerfel3]="client/public/audio/sfx/dice-throw-3.ogg"
  [karte1]="client/public/audio/sfx/card-slide-1.ogg"
  [karte2]="client/public/audio/sfx/card-slide-2.ogg"
  [karte3]="client/public/audio/sfx/card-slide-3.ogg"
  [karten_mischen]="client/public/audio/sfx/card-shuffle.ogg"
  [chip1]="client/public/audio/sfx/chip-lay-1.ogg"
  [chip2]="client/public/audio/sfx/chip-lay-2.ogg"
  [chips_stapel]="client/public/audio/sfx/chips-stack-4.ogg"
  [jingle_hit]="client/public/audio/sfx/jingles_HIT02.ogg"
  [jingle_hit2]="client/public/audio/sfx/jingles_HIT14.ogg"
  [jingle_sax]="client/public/audio/sfx/jingles_SAX10.ogg"
  [powerup]="client/public/audio/sfx/powerUp7.ogg"
  [phaser]="client/public/audio/sfx/phaserUp3.ogg"
  [glitch]="client/public/audio/sfx/glitch_002.ogg"
  [slime]="client/public/audio/sfx/slime_000.ogg"
  [bong]="client/public/audio/sfx/bong_001.ogg"
  [impact_holz]="client/public/audio/sfx/impactWood_heavy_000.ogg"
  [impact_soft]="client/public/audio/sfx/impactSoft_heavy_001.ogg"
  [impact_glocke]="client/public/audio/sfx/impactBell_heavy_000.ogg"
  [scroll]="client/public/audio/sfx/scroll_001.ogg"
  [confirm]="client/public/audio/sfx/confirmation_001.ogg"
  [error]="client/public/audio/sfx/error_004.ogg"
  [frage]="client/public/audio/sfx/question_001.ogg"
  [drop]="client/public/audio/sfx/drop_002.ogg"
  [dreiklang]="client/public/audio/sfx/threeTone1.ogg"
  [dreiklang_tief]="client/public/audio/sfx/lowThreeTone.ogg"
  [schritt1]="client/public/audio/sfx/footstep_wood_000.ogg"
  [schritt2]="client/public/audio/sfx/footstep_wood_001.ogg"
)
for id in "${!SFX[@]}"; do
  conv "$SRC/${SFX[$id]}" "$OUT/SFX/$id.m4a"
done
echo "SFX: $(ls "$OUT/SFX" | wc -l) files"

# Song snippets for the music formats (Blitz-DJ, Rückwärts-Banane, Wer singt's,
# Stummfilm-Studio): intro5s, mitte10s, rueckwaerts5s, buzz_* + video3s.mp4.
for dir in "$SRC"/content/musik/media/s_*; do
  id="$(basename "$dir")"
  mkdir -p "$OUT/Songs/$id"
  for f in "$dir"/*.ogg; do
    conv "$f" "$OUT/Songs/$id/$(basename "${f%.ogg}").m4a"
  done
  if [[ -f "$dir/video3s.mp4" && ! -f "$OUT/Songs/$id/video3s.mp4" ]]; then
    cp "$dir/video3s.mp4" "$OUT/Songs/$id/video3s.mp4"
  fi
done
echo "Songs: $(ls "$OUT/Songs" | wc -l) folders"

# Bed loops (Kevin MacLeod / archive.org, see CREDITS) for the music formats
for f in "$SRC"/content/musik/bett/*.ogg; do
  conv "$f" "$OUT/Beds/$(basename "${f%.ogg}").m4a"
done
echo "Beds: $(ls "$OUT/Beds" | wc -l) files"
