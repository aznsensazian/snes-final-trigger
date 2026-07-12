"""Procedural 8x8 tile painters for the era tilesets.
All painters return 8x8 grids of palette indices (within a 16-color palette).
A tiny deterministic hash provides texture noise so tiles look hand-pixelled
but are reproducible."""

def h(x, y, seed=0):
    v = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
    return (v ^ (v >> 16)) & 0xFF

def solid(c):
    return [[c] * 8 for _ in range(8)]

def speckle(base, dark, light, seed, dark_th=36, light_th=18):
    """Textured fill: mostly base with sparse dark/light pixels."""
    g = [[base] * 8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            r = h(x, y, seed)
            if r < light_th:
                g[y][x] = light
            elif r < light_th + dark_th:
                g[y][x] = dark
    return g

def hstripes(base, alt, period=4, width=1, phase=0):
    g = [[base] * 8 for _ in range(8)]
    for y in range(8):
        if (y + phase) % period < width:
            for x in range(8):
                g[y][x] = alt
    return g

def from_art(art, m):
    """art: 8 strings of 8 chars; m: char -> color index map. '.'=0."""
    g = []
    for line in art:
        row = []
        for ch in line:
            row.append(0 if ch == "." else m[ch])
        g.append(row)
    return g

def overlay(base, top):
    """top pixels (nonzero) painted over copy of base."""
    g = [row[:] for row in base]
    for y in range(8):
        for x in range(8):
            if top[y][x]:
                g[y][x] = top[y][x]
    return g

def quad(tl, tr, bl, br):
    """Four 8x8 tiles -> one 16x16 grid (for previews)."""
    out = []
    for y in range(8):
        out.append(tl[y] + tr[y])
    for y in range(8):
        out.append(bl[y] + br[y])
    return out

def split16(grid16):
    """16x16 grid -> (tl, tr, bl, br) 8x8 tiles."""
    tl = [[grid16[y][x] for x in range(8)] for y in range(8)]
    tr = [[grid16[y][x + 8] for x in range(8)] for y in range(8)]
    bl = [[grid16[y + 8][x] for x in range(8)] for y in range(8)]
    br = [[grid16[y + 8][x + 8] for x in range(8)] for y in range(8)]
    return tl, tr, bl, br

def art16(art, m):
    """16 strings of 16 chars -> 16x16 grid."""
    g = []
    for line in art:
        row = []
        for ch in line:
            row.append(0 if ch == "." else m[ch])
        g.append(row)
    return g
