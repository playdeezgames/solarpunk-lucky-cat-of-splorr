#!/usr/bin/env bash
# Renders one frame natively (dump_test.odin) to a PNG at 3x. Usage: tools/dump.sh out.png [-define:DUMP_X=...]...
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$1"; shift
PPM="${OUT%.png}.ppm"
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:DUMP_PLAY="$PPM" "$@" -define:ODIN_TEST_NAMES=game.dump_play >/dev/null
python3 -I - "$PPM" "$OUT" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
big = Image.new('RGB', (im.width * 3, im.height * 3))
px, bp = im.load(), big.load()
for y in range(im.height):
    for x in range(im.width):
        c = px[x, y]
        for d in range(9):
            bp[x * 3 + d % 3, y * 3 + d // 3] = c
big.save(sys.argv[2])
PY
rm -f "$PPM"
