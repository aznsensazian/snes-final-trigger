#!/usr/bin/env python3
"""Generate title screen assets:
  title_logo.chr  4bpp logo tiles (BG1, chr base $1000)
  title_logo.map  32x32 tilemap words (BG1 map $4000)
  title_pal.bin   16 colors -> CGRAM 32 (BG palette 2)
  title_grad.bin  HDMA table for backdrop gradient (mode 3 -> $2121/$2122)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from font_data import GLYPHS

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def glyph_grid(ch):
    art = GLYPHS.get(ch, GLYPHS["?"])
    g = [[0] * 8 for _ in range(8)]
    for y, line in enumerate(art):
        for x, c in enumerate(line):
            if c == "#":
                g[y][x] = 1
    return g

def scale3x(src):
    """Scale2x-family pixel-art upscale, 3x."""
    h, w = len(src), len(src[0])
    out = [[0] * (w * 3) for _ in range(h * 3)]
    def px(x, y):
        if 0 <= x < w and 0 <= y < h:
            return src[y][x]
        return 0
    for y in range(h):
        for x in range(w):
            e = px(x, y)
            a, b, c = px(x-1, y-1), px(x, y-1), px(x+1, y-1)
            d, f = px(x-1, y), px(x+1, y)
            g, hh, i = px(x-1, y+1), px(x, y+1), px(x+1, y+1)
            r = [[e]*3 for _ in range(3)]
            if b != hh and d != f:
                r[0][0] = d if d == b else e
                r[0][1] = e if (d == b and e != c) or (b == f and e != a) else e
                r[0][2] = f if b == f else e
                r[1][0] = d if (d == b and e != g) or (d == hh and e != a) else e
                r[1][2] = f if (b == f and e != i) or (hh == f and e != c) else e
                r[2][0] = d if d == hh else e
                r[2][1] = e
                r[2][2] = f if hh == f else e
            for dy in range(3):
                for dx in range(3):
                    out[y*3+dy][x*3+dx] = r[dy][dx]
    return out

def render_line(text, spacing=1):
    """Render text at 3x scale. Returns grid of 0/1, 24px tall."""
    # measure glyph widths (max used column + 1)
    cols = []
    for ch in text:
        g = glyph_grid(ch)
        wmax = 0
        for row in g:
            for x, v in enumerate(row):
                if v:
                    wmax = max(wmax, x + 1)
        if ch == " ":
            wmax = 3
        cols.append(wmax)
    width = sum(cols) + spacing * (len(text) - 1)
    grid = [[0] * width for _ in range(8)]
    x0 = 0
    for ch, wc in zip(text, cols):
        g = glyph_grid(ch)
        for y in range(8):
            for x in range(min(wc, 8)):
                if g[y][x]:
                    grid[y][x0 + x] = 1
        x0 += wc + spacing
    return scale3x(grid)

def decorate(grid):
    """1 -> gradient colors 1..8 by row; add outline color 9 around body."""
    h, w = len(grid), len(grid[0])
    out = [[0] * (w + 2) for _ in range(h + 2)]
    for y in range(h):
        for x in range(w):
            if grid[y][x]:
                band = 1 + min(7, (y * 8) // h)
                out[y + 1][x + 1] = band
    # outline
    res = [row[:] for row in out]
    for y in range(h + 2):
        for x in range(w + 2):
            if out[y][x] == 0:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < h + 2 and 0 <= xx < w + 2 and 1 <= out[yy][xx] <= 8:
                            res[y][x] = 9
                            break
                    else:
                        continue
                    break
    return res

def main():
    os.makedirs(OUT, exist_ok=True)
    line1 = decorate(render_line("FINAL"))
    line2 = decorate(render_line("TRIGGER"))

    # compose onto a 256x224 canvas region mapped to 32x32 tiles
    canvas = [[0] * 256 for _ in range(224)]
    def blit(grid, cy):
        w = len(grid[0])
        cx = (256 - w) // 2
        for y, row in enumerate(grid):
            for x, v in enumerate(row):
                if v:
                    canvas[cy + y][cx + x] = v
    blit(line1, 40)
    blit(line2, 74)

    # cut into unique 8x8 tiles
    tiles = {}          # bytes -> index
    order = []
    tilemap = [0] * (32 * 32)
    blank = tile_4bpp([[0] * 8 for _ in range(8)])
    tiles[blank] = 0
    order.append(blank)
    for ty in range(28):
        for tx in range(32):
            t = [[canvas[ty*8+y][tx*8+x] for x in range(8)] for y in range(8)]
            data = tile_4bpp(t)
            if data not in tiles:
                tiles[data] = len(order)
                order.append(data)
            # BG1 pal 2, no priority
            tilemap[ty*32+tx] = tiles[data] | (2 << 10)
    chr_data = b"".join(order)

    # palette: crystal blue gradient 1..8 (bright top -> deep bottom), 9=dark outline
    pal = [0] * 16
    ramp = [
        (30, 31, 31),  # near-white cyan
        (24, 30, 31),
        (18, 27, 31),
        (13, 23, 31),
        (9, 18, 30),
        (7, 13, 27),
        (6, 9, 23),
        (8, 6, 20),    # into violet
    ]
    for i, (r, g, b) in enumerate(ramp):
        pal[1 + i] = bgr555(r, g, b)
    pal[9] = bgr555(1, 1, 5)
    pal[10] = bgr555(31, 26, 8)   # gold accent (unused yet)

    with open(os.path.join(OUT, "title_logo.chr"), "wb") as f:
        f.write(chr_data)
    with open(os.path.join(OUT, "title_logo.map"), "wb") as f:
        f.write(b"".join(w.to_bytes(2, "little") for w in tilemap))
    with open(os.path.join(OUT, "title_pal.bin"), "wb") as f:
        f.write(pack_palette(pal))

    # HDMA gradient: night sky, purple horizon glow near bottom
    # mode 3 to $2121: bytes per entry = CGADD, CGDATA lo, CGADD, CGDATA hi
    steps = []
    for i in range(28):
        t = i / 27.0
        if t < 0.62:
            k = t / 0.62
            r = 2 + int(3 * k); g = 1 + int(2 * k); b = 8 + int(10 * k)
        else:
            k = (t - 0.62) / 0.38
            r = 5 + int(9 * k); g = 3 + int(2 * k); b = 18 - int(7 * k)
        steps.append(bgr555(r, g, b))
    table = bytearray()
    for c in steps:
        table += bytes((8, 0, c & 0xFF, 0, c >> 8))   # 8 scanlines each
    table += b"\x00"
    with open(os.path.join(OUT, "title_grad.bin"), "wb") as f:
        f.write(table)

    print(f"title: {len(order)} tiles ({len(chr_data)} bytes), grad {len(table)} bytes")

if __name__ == "__main__":
    main()
