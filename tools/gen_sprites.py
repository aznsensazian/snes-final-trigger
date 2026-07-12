#!/usr/bin/env python3
"""Generate OBJ sprite sheet: assets/obj_hero.chr + assets/objpal.bin.
OBJ VRAM is a 16-tile-wide grid; a 16x16 sprite at tile t uses t,t+1,t+16,t+17.
Frame i is placed at tile i*2 (columns i*2..i*2+1, rows 0..1)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from sprite_data import HERO_FRAMES, HERO_PAL, M

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def frame_grid(art):
    g = []
    for line in art:
        row = []
        for ch in line:
            row.append(0 if ch == "." else M[ch])
        g.append(row)
    return g

def main():
    os.makedirs(OUT, exist_ok=True)
    # canvas: 2 tile rows x 16 tile cols
    canvas = [[0] * 128 for _ in range(16)]
    for i, art in enumerate(HERO_FRAMES):
        g = frame_grid(art)
        for y in range(16):
            for x in range(16):
                canvas[y][i * 16 + x] = g[y][x]
    tiles = []
    for ty in range(2):
        for tx in range(16):
            t = [[canvas[ty * 8 + y][tx * 8 + x] for x in range(8)] for y in range(8)]
            tiles.append(tile_4bpp(t))
    with open(os.path.join(OUT, "obj_hero.chr"), "wb") as f:
        f.write(b"".join(tiles))
    with open(os.path.join(OUT, "objpal.bin"), "wb") as f:
        f.write(pack_palette([bgr555(*c) for c in HERO_PAL]))
    print(f"obj_hero.chr: {len(tiles)} tiles")

if __name__ == "__main__":
    main()
