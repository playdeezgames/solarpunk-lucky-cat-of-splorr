#!/usr/bin/env bash
# Renders real frames natively (dump_test.odin, through tools/dump.sh) into assets/screenshots/:
# 01-heap (mid-street), 02-street (more houses green), 03-shed (the shop), 04-end (the ending, cat not
# found: the screenshots never show where she is), 05-new-scrap (a new neighbour's scrap card), and assets/portal.png (480x360, for the portal).
# Needs odin on PATH and Pillow. Run: tools/make_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
S=assets/screenshots
mkdir -p "$S"
tools/dump.sh "$S/01-heap.png" -define:DUMP_HOUSES=2 >/dev/null
tools/dump.sh "$S/02-street.png" -define:DUMP_HOUSES=6 >/dev/null
tools/dump.sh "$S/03-shed.png" -define:DUMP_HOUSES=3 -define:DUMP_SHOP=true >/dev/null
tools/dump.sh "$S/04-end.png" -define:DUMP_END=true >/dev/null
tools/dump.sh "$S/05-new-scrap.png" -define:DUMP_HOUSES=1 -define:DUMP_CARD=5 >/dev/null
python3 -I - <<'PY'
from PIL import Image
im = Image.open("assets/screenshots/02-street.png").convert("RGB")  # the 384x216 screen at 3x
src = im.load()
# 240x180 of the screen (x 16..256, y 15..195: the bin, the barrow and the first houses; no top bar,
# no chatter), doubled to 480x360.
out = Image.new("RGB", (480, 360))
dst = out.load()
for y in range(360):
    for x in range(480):
        dst[x, y] = src[(16 + x // 2) * 3, (15 + y // 2) * 3]
out.save("assets/portal.png")
PY
echo "$S: 01-heap 02-street 03-shed 04-end 05-new-scrap; assets/portal.png"
