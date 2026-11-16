#!/usr/bin/env bash
# Renders real frames natively (dump_test.odin, through tools/dump.sh) into assets/screenshots/:
# 01-heap (mid-street), 02-street (more houses green), 03-shed (the shop), 04-end (the ending, cat not
# found: the screenshots never show where she is), and assets/portal.png (480x360, for the portal).
# Needs odin on PATH and Pillow. Run: tools/make_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
S=assets/screenshots
mkdir -p "$S"
tools/dump.sh "$S/01-heap.png" -define:DUMP_HOUSES=2 >/dev/null
tools/dump.sh "$S/02-street.png" -define:DUMP_HOUSES=6 >/dev/null
tools/dump.sh "$S/03-shed.png" -define:DUMP_HOUSES=3 -define:DUMP_SHOP=true >/dev/null
tools/dump.sh "$S/04-end.png" -define:DUMP_END=true >/dev/null
python3 -I - <<'PY'
from PIL import Image
im = Image.open("assets/screenshots/02-street.png").convert("RGB")  # 3x
# The bin and the street, without the top bar and the chatter: 1152x648 -> crop 3x(8..392, 18..198).
crop = im.crop((0, 54, 1152, 594))
out = Image.new("RGB", (480, 360))
cw, ch = crop.size
src, dst = crop.load(), out.load()
for y in range(360):
    for x in range(480):
        dst[x, y] = src[x * cw // 480, y * ch // 360]
out.save("assets/portal.png")
PY
echo "$S: 01-heap 02-street 03-shed 04-end; assets/portal.png"
