#!/usr/bin/env python3
"""Generate assets/font.chr (2bpp) + assets/textpal.bin (BG3 palettes)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_2bpp, pack_palette, bgr555
from font_data import GLYPHS, UI_TILES, UI_ORDER

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def render_glyph(art):
    """ASCII art -> 8x8 grid with color 1 body + color 2 shadow at (+1,+1)."""
    cell = [[0] * 8 for _ in range(8)]
    for y, line in enumerate(art):
        for x, ch in enumerate(line):
            if ch == "#":
                cell[y][x] = 1
    # drop shadow
    for y in range(7, -1, -1):
        for x in range(7, -1, -1):
            if cell[y][x] == 1:
                sy, sx = y + 1, x + 1
                if sy < 8 and sx < 8 and cell[sy][sx] == 0:
                    cell[sy][sx] = 2
    return cell

def render_ui(art):
    cell = [[0] * 8 for _ in range(8)]
    for y, line in enumerate(art):
        for x, ch in enumerate(line):
            if ch != ".":
                cell[y][x] = int(ch)
    return cell

def main():
    os.makedirs(OUT, exist_ok=True)
    chr_data = bytearray()
    for code in range(32, 127):
        art = GLYPHS.get(chr(code))
        if art is None:
            art = GLYPHS["?"]
        chr_data += tile_2bpp(render_glyph(art))
    for name in UI_ORDER:
        chr_data += tile_2bpp(render_ui(UI_TILES[name]))
    with open(os.path.join(OUT, "font.chr"), "wb") as f:
        f.write(chr_data)

    # BG3 2bpp palettes (CGRAM colors 0-31, 8 palettes of 4)
    pal = []
    # pal 0: main text. 0=transparent, 1=white, 2=shadow navy, 3=gold
    pal += [0, bgr555(31, 31, 31), bgr555(4, 4, 10), bgr555(31, 26, 8)]
    # pal 1: window chrome. 1=outer silver line, 2=fill dark blue, 3=inner gold line
    pal += [0, bgr555(28, 28, 31), bgr555(2, 3, 11), bgr555(24, 20, 6)]
    # pal 2: dim/gray text (disabled entries)
    pal += [0, bgr555(16, 16, 18), bgr555(4, 4, 10), bgr555(12, 12, 14)]
    # pal 3: yellow highlight text
    pal += [0, bgr555(31, 30, 10), bgr555(6, 5, 2), bgr555(31, 20, 4)]
    # pal 4: green (heals / HP)
    pal += [0, bgr555(12, 31, 14), bgr555(2, 8, 4), bgr555(24, 31, 24)]
    # pal 5: red (damage / alerts)
    pal += [0, bgr555(31, 10, 8), bgr555(8, 2, 2), bgr555(31, 20, 16)]
    # pal 6: cyan (magic / crystals)
    pal += [0, bgr555(14, 26, 31), bgr555(3, 6, 10), bgr555(26, 31, 31)]
    # pal 7: purple (time / void)
    pal += [0, bgr555(24, 12, 31), bgr555(6, 3, 10), bgr555(30, 24, 31)]
    with open(os.path.join(OUT, "textpal.bin"), "wb") as f:
        f.write(pack_palette(pal))
    print(f"font.chr: {len(chr_data)} bytes ({len(chr_data)//16} tiles), textpal.bin: 64 bytes")

if __name__ == "__main__":
    main()
