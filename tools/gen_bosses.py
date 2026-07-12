#!/usr/bin/env python3
"""Boss graphics: 32x32 art -> scale2x -> 64x64, packed as 8 sequential
rows of 8 tiles (256 bytes per row chunk) per boss.
Outputs assets/boss.chr (5 x 2048) and assets/bosspal.bin (7 x 32)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from boss_data import BOSS_ARTS, BOSS_PALS

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def grid_of(art):
    g = []
    for line in art:
        row = []
        for ch in line[:32]:
            row.append(0 if ch == "." else int(ch, 16))
        while len(row) < 32:
            row.append(0)
        g.append(row)
    while len(g) < 32:
        g.append([0] * 32)
    return g

def scale2x(src):
    h, w = len(src), len(src[0])
    out = [[0] * (w * 2) for _ in range(h * 2)]
    def px(x, y):
        if 0 <= x < w and 0 <= y < h:
            return src[y][x]
        return 0
    for y in range(h):
        for x in range(w):
            e = px(x, y)
            b, d, f, hh = px(x, y-1), px(x-1, y), px(x+1, y), px(x, y+1)
            e0 = d if (d == b and b != f and d != hh) else e
            e1 = f if (b == f and b != d and f != hh) else e
            e2 = d if (d == hh and d != b and hh != f) else e
            e3 = f if (hh == f and d != hh and b != f) else e
            out[y*2][x*2] = e0
            out[y*2][x*2+1] = e1
            out[y*2+1][x*2] = e2
            out[y*2+1][x*2+1] = e3
    return out

def main():
    os.makedirs(OUT, exist_ok=True)
    blob = bytearray()
    for art in BOSS_ARTS:
        big = scale2x(grid_of(art))
        for tr in range(8):
            for tc in range(8):
                t = [[big[tr*8+y][tc*8+x] for x in range(8)] for y in range(8)]
                blob += tile_4bpp(t)
    with open(os.path.join(OUT, "boss.chr"), "wb") as f:
        f.write(blob)
    pals = b""
    for p in BOSS_PALS:
        pals += pack_palette([bgr555(*c) for c in p])
    with open(os.path.join(OUT, "bosspal.bin"), "wb") as f:
        f.write(pals)
    print(f"boss.chr {len(blob)} bytes, {len(BOSS_ARTS)} bosses; "
          f"{len(BOSS_PALS)} palettes")

if __name__ == "__main__":
    main()
