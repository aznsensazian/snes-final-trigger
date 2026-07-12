"""Shared helpers for SNES asset generators."""
import struct

def bgr555(r, g, b):
    """r,g,b in 0..31 -> SNES BGR555 word."""
    return (b << 10) | (g << 5) | r

def rgb888_to_bgr555(r, g, b):
    return bgr555(r >> 3, g >> 3, b >> 3)

def pack_palette(colors):
    """List of BGR555 words -> bytes."""
    return b"".join(struct.pack("<H", c) for c in colors)

def tile_2bpp(pixels):
    """pixels: 8x8 list of rows of ints 0..3 -> 16 bytes SNES 2bpp planar."""
    out = bytearray()
    for y in range(8):
        p0 = p1 = 0
        for x in range(8):
            v = pixels[y][x]
            p0 = (p0 << 1) | (v & 1)
            p1 = (p1 << 1) | ((v >> 1) & 1)
        out += bytes((p0, p1))
    return bytes(out)

def tile_4bpp(pixels):
    """pixels: 8x8 list of rows of ints 0..15 -> 32 bytes SNES 4bpp planar."""
    out = bytearray()
    for y in range(8):
        p0 = p1 = 0
        for x in range(8):
            v = pixels[y][x]
            p0 = (p0 << 1) | (v & 1)
            p1 = (p1 << 1) | ((v >> 1) & 1)
        out += bytes((p0, p1))
    for y in range(8):
        p2 = p3 = 0
        for x in range(8):
            v = pixels[y][x]
            p2 = (p2 << 1) | ((v >> 2) & 1)
            p3 = (p3 << 1) | ((v >> 3) & 1)
        out += bytes((p2, p3))
    return bytes(out)

def grid_from_art(art, charmap=None):
    """Convert list of strings to pixel grid. Default: '.'/' '=0, '#'=1, digits/hex=value."""
    rows = []
    for line in art:
        row = []
        for ch in line:
            if ch in ". ":
                row.append(0)
            elif ch == "#":
                row.append(1)
            elif charmap and ch in charmap:
                row.append(charmap[ch])
            else:
                row.append(int(ch, 16))
        rows.append(row)
    return rows

def pad_grid(grid, w, h):
    g = [list(r) + [0] * (w - len(r)) for r in grid]
    while len(g) < h:
        g.append([0] * w)
    return g

def split_tiles(grid, tw, th):
    """Split a big pixel grid into 8x8 tiles in row-major order of (th x tw) tile grid."""
    tiles = []
    for ty in range(th):
        for tx in range(tw):
            t = [[grid[ty * 8 + y][tx * 8 + x] for x in range(8)] for y in range(8)]
            tiles.append(t)
    return tiles
