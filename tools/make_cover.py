#!/usr/bin/env python3
"""Draws the itch.io cover, assets/cover.png (630x500): the title in DINOBYTE over a clearing sky and a
frame of the game itself (dump_test.odin, rendered natively), doubled. The cat is not shown.
Run: python3 -I tools/make_cover.py   (needs odin on PATH and Pillow)"""
import os
import subprocess
import tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
font = Image.open(os.path.join(ROOT, 'tools/data/dbyte_1x.png')).convert('RGBA')
W, H = 630, 500
SKY, WHITE, LIME, YELLOW = (59, 93, 201), (244, 244, 244), (167, 240, 112), (255, 205, 117)

with tempfile.TemporaryDirectory() as d:
    ppm = os.path.join(d, 'play.ppm')
    subprocess.run(['odin', 'test', 'src/game', '-collection:tggd=src', '-define:ODIN_TEST_THREADS=1',
                    '-define:DUMP_PLAY=' + ppm, '-define:DUMP_HOUSES=5', '-define:ODIN_TEST_NAMES=game.dump_play'],
                   cwd=ROOT, check=True, capture_output=True)
    frame = Image.open(ppm).convert('RGB')
    frame.load()

img = Image.new('RGB', (W, H), SKY)
px = img.load()

def text(s, y, scale, color):
    x0 = (W - len(s) * 6 * scale) // 2
    for i, ch in enumerate(s.encode('cp437')):
        cx, cy = (ch % 16) * 6, (ch // 16) * 8
        for gy in range(8):
            for gx in range(6):
                if font.getpixel((cx + gx, cy + gy))[3] > 0:
                    for sy in range(scale):
                        for sx in range(scale):
                            px[x0 + (i * 6 + gx) * scale + sx, y + gy * scale + sy] = color

text("COMPOSTERS", 20, 6, WHITE)
text("of SPLORR!!", 76, 3, LIME)
# The bin, the barrow and the street, doubled (screen x 16..315, y 18..195), top bar and chatter left out.
fp = frame.load()
X0, Y0, CW, CH = 16, 18, 299, 177
ox, oy = (W - CW * 2) // 2, 112
for y in range(CH):
    for x in range(CW):
        c = fp[X0 + x, Y0 + y]
        for d in range(4):
            px[ox + x * 2 + d % 2, oy + y * 2 + d // 2] = c
# Stop the frame's sky at its edges blending oddly: a thin line under the title.
for x in range(ox, ox + CW * 2):
    px[x, oy - 2] = YELLOW
text("Rot the greens. Green the street.", 474, 2, WHITE)
img.save(os.path.join(ROOT, 'assets/cover.png'))
print("assets/cover.png", img.size)
