#!/usr/bin/env python3
"""Generate battle assets:
  assets/obj_enemies.chr  (rows 4-7 of the OBJ tile grid: 4 32x32 enemy slots)
  assets/enemypal.bin     (3 x 16 colors -> OBJ palettes 1-3, CGRAM 144)
  assets/battle_grad.bin  (HDMA backdrop gradient for battles)
A 32x32 sprite with top-left tile t uses tiles t..t+3, t+16.., t+32.., t+48..
Enemy slot k is placed at tile 64 + k*4."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from enemy_data import ENEMY_SPRITES, ENEMY_PAL

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def main():
    os.makedirs(OUT, exist_ok=True)
    # canvas: 4 tile rows x 16 tile cols = 128x32 px
    canvas = [[0] * 128 for _ in range(32)]
    for k, art in enumerate(ENEMY_SPRITES):
        for y in range(32):
            for x in range(32):
                ch = art[y][x]
                if ch != ".":
                    canvas[y][k * 32 + x] = int(ch, 16)
    tiles = []
    for ty in range(4):
        for tx in range(16):
            t = [[canvas[ty * 8 + y][tx * 8 + x] for x in range(8)] for y in range(8)]
            tiles.append(tile_4bpp(t))
    with open(os.path.join(OUT, "obj_enemies.chr"), "wb") as f:
        f.write(b"".join(tiles))
    # palette variants: 0 = natural greens, 1 = crimson/magma, 2 = steel/void
    def shifted(pal, mode):
        out = []
        for (r, g2, b) in pal:
            if mode == 1:
                out.append((min(31, int(r*1.5+6)), int(g2*0.55), int(b*0.5)))
            elif mode == 2:
                avg = (r + g2 + b) // 3
                out.append((int(avg*0.8+2), int(avg*0.85+2), min(31, int(avg*1.2+6))))
            else:
                out.append((r, g2, b))
        return out
    pals = b""
    for mode in range(3):
        p = shifted(ENEMY_PAL, mode)
        p[0] = (0, 0, 0)
        pals += pack_palette([bgr555(*c) for c in p])
    with open(os.path.join(OUT, "enemypal.bin"), "wb") as f:
        f.write(pals)

    # battle backdrop gradient: dusk amber -> deep violet
    table = bytearray()
    for i in range(28):
        t = i / 27.0
        r = int(10 + 8 * (1 - t))
        g = int(4 + 3 * (1 - t))
        b = int(10 + 12 * t * (1 - t) + 4 * t)
        c = bgr555(r, g, b)
        table += bytes((8, 0, c & 0xFF, 0, c >> 8))
    table += b"\x00"
    with open(os.path.join(OUT, "battle_grad.bin"), "wb") as f:
        f.write(table)
    print(f"enemies: {len(tiles)} tiles; gradient {len(table)} bytes")

if __name__ == "__main__":
    main()
