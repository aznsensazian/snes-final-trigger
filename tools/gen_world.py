#!/usr/bin/env python3
"""Generate tilesets + maps:
  assets/tsN_chr.bin / tsN_pal.bin / tsN_meta.bin / tsN_attr.bin
  assets/mapN.bin  (header + exits + 32x32 metatile grid + baked 64x64 tilemap)
  assets/world.s   (incbins + pointer tables)
Map binary layout:
  +0 tileset, +1 music, +2 encGroup, +3 encRate, +4 spawnX, +5 spawnY,
  +6 exitCount, +7 pad, +8 exits[E*8]{mx,my,destMap,destX,destY,type,arg,pad},
  then 1024 grid, then 8192 baked tilemap.
Attr flags: bit0 solid, bit1 encounter.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from tileart import h, solid, speckle, hstripes, overlay, art16, split16

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
SOLID, ENC = 1, 2

# ===========================================================================
# Tileset 0: Verdant Realm (Present 1000 AD / Middle Ages 600 AD)
# palette 2 = terrain, palette 3 = structures
# ===========================================================================

TS0_PAL2 = [
    (0, 0, 0), (1, 2, 2), (7, 17, 6), (10, 21, 8), (5, 13, 5),
    (3, 9, 4), (5, 14, 6), (4, 9, 20), (7, 13, 26), (12, 19, 30),
    (25, 21, 13), (19, 15, 9), (15, 14, 13), (21, 20, 18), (9, 9, 9),
    (28, 28, 28),
]
TS0_PAL3 = [
    (0, 0, 0), (1, 2, 2), (16, 15, 16), (22, 21, 22), (10, 10, 12),
    (23, 9, 7), (16, 5, 4), (14, 9, 5), (20, 14, 8), (30, 26, 12),
    (16, 26, 31), (9, 16, 28), (6, 8, 22), (14, 8, 26), (30, 30, 30),
    (31, 25, 9),
]

def ts0_metatiles():
    """Return dict: char -> (grid16, palette#, attr)."""
    M = {}
    # terrain color shorthand for art16 maps
    tm = {"o": 1, "g": 2, "G": 3, "d": 4, "f": 5, "F": 6, "w": 7, "W": 8,
          "l": 9, "s": 10, "S": 11, "r": 12, "R": 13, "k": 14, "n": 15}
    sm = {"o": 1, "s": 2, "S": 3, "d": 4, "r": 5, "R": 6, "w": 7, "W": 8,
          "y": 9, "p": 10, "P": 11, "q": 12, "v": 13, "n": 14, "x": 15}

    def q(tl, tr, bl, br):
        out = []
        for y in range(8):
            out.append(tl[y] + tr[y])
        for y in range(8):
            out.append(bl[y] + br[y])
        return out

    g = lambda s: speckle(2, 4, 3, s)
    # safe grass
    M["."] = (q(g(1), g(2), g(3), g(4)), 2, 0)
    # town grass (same look, different seeds)
    M[","] = (q(g(5), g(6), g(7), g(8)), 2, 0)
    # wild grass (encounters): denser texture with dark tufts
    wg = lambda s: speckle(2, 5, 3, s, dark_th=60, light_th=22)
    M[":"] = (q(wg(11), wg(12), wg(13), wg(14)), 2, ENC)
    # flowers
    fl = lambda s: overlay(g(s), speckle(0, 15, 10, s + 40, dark_th=10, light_th=8))
    M["F"] = (q(fl(21), fl(22), fl(23), fl(24)), 2, 0)
    # water (animated palette slots 7,8,9)
    def water(seed, phase):
        base = speckle(7, 7, 8, seed, dark_th=0, light_th=26)
        for y in range(8):
            if (y + phase) % 4 == 0:
                for x in range(8):
                    if h(x, y, seed + 9) < 110:
                        base[y][x] = 9
        return base
    M["~"] = (q(water(31, 0), water(32, 2), water(33, 1), water(34, 3)), 2, SOLID)
    # beach sand
    sa = lambda s: speckle(10, 11, 10, s)
    M["b"] = (q(sa(41), sa(42), sa(43), sa(44)), 2, 0)
    # path
    pa = lambda s: speckle(11, 10, 11, s, dark_th=25, light_th=25)
    M["="] = (q(pa(51), pa(52), pa(53), pa(54)), 2, 0)
    # forest floor (walkable, dark, encounters)
    ff = lambda s: speckle(5, 4, 6, s, dark_th=70, light_th=40)
    M["t"] = (q(ff(61), ff(62), ff(63), ff(64)), 2, ENC)
    # big tree (solid)
    tree = art16([
        "....offfffo.....",
        "..offFfffffo....",
        ".ofFFfffFfffo...",
        ".offfffffffffo..",
        "ofFffFFfffFffo..",
        "offfffffffffffo.",
        "offFfffffFffffo.",
        ".offfFffffffFo..",
        ".offffffffffo...",
        "..offFfffffo....",
        "...offfffoo.....",
        "....offoo.......",
        ".....oSso.......",
        ".....oSso.......",
        "....osSsso......",
        "...gg.gg.gg.....",
    ], tm)
    # put tree on grass background
    treeg = [row[:] for row in q(g(71), g(72), g(73), g(74))]
    for y in range(16):
        for x in range(16):
            if tree[y][x]:
                treeg[y][x] = tree[y][x]
    M["T"] = (treeg, 2, SOLID)
    # mountain (solid)
    mnt = art16([
        "......okko......",
        ".....okrrko.....",
        "....okrRrrko....",
        "....ornnRrro....",
        "...okrnnrrrko...",
        "...orrnRrrrro...",
        "..okrRrrrRrrko..",
        "..orrrrkrrrrro..",
        ".okrrRrrkrRrrko.",
        ".orrrrrrrkrrrro.",
        "okrrRrrRrrkRrrko",
        "orrrrrrrrrrrrrro",
        "krRrrrkrrRrrrRrk",
        "rrrrrrrrrrrrrrrr",
        "gorrrgggggrrrogg",
        "ggggggggggggggg.",
    ], tm)
    mg = [row[:] for row in q(g(81), g(82), g(83), g(84))]
    for y in range(16):
        for x in range(16):
            if mnt[y][x]:
                mg[y][x] = mnt[y][x]
    M["^"] = (mg, 2, SOLID)
    # hills (walkable, encounters)
    hl = lambda s: overlay(speckle(2, 4, 3, s), hstripes(0, 4, 5, 1, s % 3))
    M["n"] = (q(hl(91), hl(92), hl(93), hl(94)), 2, ENC)
    # bridge (walkable planks over water)
    def plank(seed):
        gr = [[8 if y % 4 == 0 else 7 for _ in range(8)] for y in range(8)]
        for y in range(8):
            for x in range(8):
                if y % 4 != 0:
                    gr[y][x] = 11 if (x + y) % 7 else 10
        return gr
    M["B"] = (q(plank(1), plank(2), plank(3), plank(4)), 2, 0)
    # rock cliff filler (solid)
    rk = lambda s: speckle(12, 14, 13, s, dark_th=50, light_th=30)
    M["#"] = (q(rk(101), rk(102), rk(103), rk(104)), 2, SOLID)

    # --- structures on palette 3 ---
    # castle wall
    wallart = art16([
        "sSssSsSSsSssSsSs",
        "ssssssssssssssss",
        "oooooooooooooooo",
        "sSsSodSsSsdoSsSs",
        "ssssossssssossss",
        "SsSsodSsSsdoSsSs",
        "ssssossssssossss",
        "oooooooooooooooo",
        "sSsSsSodSsSsSsSs",
        "sssssssossssssss",
        "SsSsSsodSsSsSsSs",
        "ssssssossssssssss"[:16],
        "oooooooooooooooo",
        "sSsSodSsSsSdoSsS",
        "ssssossssssossss",
        "dddddddddddddddd",
    ], sm)
    M["W"] = (wallart, 3, SOLID)
    # castle roof/battlements
    roofart = art16([
        "nn..nn..nn..nn..",
        "nnooNNooNNoonnoo".replace("N", "n")[:16],
        "ssssssssssssssss",
        "SsSsSsSsSsSsSsSs",
        "ssssssssssssssss",
        "oooooooooooooooo",
        "rrrrrrrrrrrrrrrr",
        "rRrrRrrRrrRrrRrr",
        "rrrrrrrrrrrrrrrr",
        "RrrRrrRrrRrrRrrR",
        "rrrrrrrrrrrrrrrr",
        "rrRrrRrrRrrRrrRr",
        "oooooooooooooooo",
        "ssssssssssssssss",
        "SsSsSsSsSsSsSsSs",
        "ssssssssssssssss",
    ], sm)
    M["R"] = (roofart, 3, SOLID)
    # castle gate (event door)
    gateart = art16([
        "sSsSsSsSsSsSsSsS",
        "ssssssssssssssss",
        "ssooooooooooooss",
        "ssoqqqqqqqqqqoss",
        "ssoqPPPPPPPPqoss",
        "soqqPqqqqqqPqqos",
        "soqPqooooooqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "soqPqowwowoqPqos",
        "ssssssssssssssss",
        "dddddddddddddddd",
    ], sm)
    M["D"] = (gateart, 3, SOLID)  # solid; entering handled by exit tile in front
    # house (solid)
    houseart = art16([
        "....oooooooo....",
        "..oorrrrrrrroo..",
        ".orrrrRrrRrrrro.",
        "orrRrrrrrrrrRrro",
        "oRrrrRrrrrRrrrRo",
        "orrrrrrrrrrrrrro",
        "oooooooooooooooo",
        "owwWwwwWwwwWwwoo",
        "owyyowwwwwowyyoo",
        "owyyowqqqwowyyoo",
        "owwwowqqqwowwwoo",
        "owWwowqPqwowWwoo",
        "owwwowqPqwowwwoo",
        "oooooooooooooooo",
        "................",
        "................",
    ], sm)
    hg = [row[:] for row in q(g(111), g(112), g(113), g(114))]
    for y in range(16):
        for x in range(16):
            if houseart[y][x]:
                hg[y][x] = houseart[y][x]
    M["h"] = (hg, 3, SOLID)
    # time gate (walkable event; swirl)
    gate = art16([
        "................",
        ".....pppppp.....",
        "...ppPPPPPPpp...",
        "..pPPqqqqqqPPp..",
        "..pPqvvppvvqPp..",
        ".pPqvpPPPPpvqPp.",
        ".pPqvPpqqpPvqPp.",
        ".pPqpPqnnqPpqPp.",
        ".pPqpPqnnqPpqPp.",
        ".pPqvPpqqpPvqPp.",
        ".pPqvpPPPPpvqPp.",
        "..pPqvvppvvqPp..",
        "..pPPqqqqqqPPp..",
        "...ppPPPPPPpp...",
        ".....pppppp.....",
        "................",
    ], sm)
    gg2 = [row[:] for row in q(g(121), g(122), g(123), g(124))]
    for y in range(16):
        for x in range(16):
            if gate[y][x]:
                gg2[y][x] = gate[y][x]
    M["G"] = (gg2, 3, 0)
    # cave mouth (event door on rock)
    cave = art16([
        "rrRrrrRrrrrRrrrr",
        "rRrrrooooorrrRrr",
        "rrrooqqqqqoorrrr",
        "rrLoqooooooqoLrr".replace("L", "r"),
        "rroqoooooooooqrr",
        "rroqooooooooooqr",
        "rroooooooooooorr",
        "rrooooooooooooorr"[:16],
    ] + ["rroooooooooooorr"] * 6 + [
        "rrooooooooooooorr"[:16],
        "gggggggggggggggg",
    ], {**sm, "g": 2, "r": 2, "R": 3, "q": 4, "o": 1})
    # simpler: rebuild via terrain palette
    cave = art16([
        "rrRrrRrrrRrrRrrr",
        "rrrrrrrrrrrrrrrr",
        "rRrrooooooorrRrr",
        "rrrooooooooorrr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "rrooooooooooorr.",
        "ggooooooooooogg.",
        "gggggggggggggggg",
    ], {"r": 12, "R": 13, "o": 1, "g": 2})
    M["o"] = (cave, 2, 0)

    return M

# ===========================================================================
# Maps
# ===========================================================================

MAP_LYRA = """
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
^^::::::::^^^^^^::::::^^^^^^^^^^
^^::::::::::^^::::::::::o^^^^^^^
^::::T:::::::::::::::::==:^^^^^^
^:::TTT::::::::::::::::=::::^^^^
^::TTTTT:::::::::::::::=:::::^^^
^:::TTT::::WRRW:::::::==::::::^^
^::::T::::WWRRWW:::::==:::::::^^
^:::::::::WWDDWW::::==::::::::^^
~~::::::::::==:::::==::::nnn::^^
~~~b::::::::==::::==:::nnnnnn:^^
~~~~b::,,,,,==,,,==:::nnnGnnn:^^
~~~~~b,,h,,,==,,,==:::nnnnnnn:^^
~~~~~b,,,,,,===,,==::::nnnnn::^^
~~~~~~b,h,,,,==,,,=::::::::::^^^
~~~~~~b,,,,h,==,,,==:::::::::^^^
~~~~~b,,,,,,,==,,,,==::::::::^^^
~~~~b,,h,,,,===,F,,,=::::::::^^^
~~~~b,,,,,,==,,,FF,,=:::::::^^^^
~~~b:,,,,,==,,,,F,,,==::::::^^^^
~~~b:::,,==::::,,,,,,=::::::^^^^
~~~b::::==:::::::::::==::::^^^^^
~~~~b:::=::tttt:::::::=:::::^^^^
~~~~b:::=::tttttt:::::=:::::^^^^
~~~~~bbb=btttttttt::::==::::^^^^
~~~~~~~~B~~tttttt::::::=::::^^^^
~~~~~~~~B~~~ttttt:::::==:::^^^^^
~~~~~b==:b::ttttt:::::=::::^^^^^
~~~~b::::::::ttt::::::=::::^^^^^
^^^^^::::::::::::::::::::^^^^^^^
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
""".strip().splitlines()

def bake_map(grid_chars, meta_index, meta_defs):
    """grid: 32x32 chars -> (grid bytes, baked 8KB tilemap bytes)."""
    grid = bytearray()
    for row in grid_chars:
        for ch in row:
            grid.append(meta_index[ch])
    # baked 64x64 tilemap in SNES quadrant order
    tm = [0] * (64 * 64)
    for my in range(32):
        for mx in range(32):
            words = meta_defs[grid[my * 32 + mx]]
            for sy in range(2):
                for sx in range(2):
                    tx, ty = mx * 2 + sx, my * 2 + sy
                    quad = (1 if tx >= 32 else 0) + (2 if ty >= 32 else 0)
                    off = quad * 1024 + (ty % 32) * 32 + (tx % 32)
                    tm[off] = words[sy * 2 + sx]
    baked = b"".join(w.to_bytes(2, "little") for w in tm)
    return bytes(grid), baked

def build_tileset(mdict):
    """Dedupe 8x8 tiles, build chr/meta/attr binaries.
    Returns (chr_bytes, meta_words_list, attr_bytes, char->index map)."""
    tiles = {}
    order = []
    blank = tile_4bpp([[0] * 8 for _ in range(8)])
    tiles[blank] = 0
    order.append(blank)
    meta_defs = []
    attrs = bytearray()
    index = {}
    for i, (ch, (grid16, pal, attr)) in enumerate(sorted(mdict.items())):
        words = []
        for t in split16(grid16):
            data = tile_4bpp(t)
            if data not in tiles:
                tiles[data] = len(order)
                order.append(data)
            words.append(tiles[data] | (pal << 10))
        meta_defs.append(words)
        attrs.append(attr)
        index[ch] = i
    return b"".join(order), meta_defs, bytes(attrs), index

def main():
    os.makedirs(OUT, exist_ok=True)
    M = ts0_metatiles()
    chr0, meta0, attr0, idx0 = build_tileset(M)
    with open(os.path.join(OUT, "ts0_chr.bin"), "wb") as f:
        f.write(chr0)
    pal = pack_palette([bgr555(*c) for c in TS0_PAL2] + [bgr555(*c) for c in TS0_PAL3])
    with open(os.path.join(OUT, "ts0_pal.bin"), "wb") as f:
        f.write(pal)
    meta_bin = bytearray()
    for words in meta0:
        for w in words:
            meta_bin += w.to_bytes(2, "little")
    with open(os.path.join(OUT, "ts0_meta.bin"), "wb") as f:
        f.write(meta_bin)
    with open(os.path.join(OUT, "ts0_attr.bin"), "wb") as f:
        f.write(attr0)

    # --- map 0: Lyra overworld ---
    grid, baked = bake_map(MAP_LYRA, idx0, meta0)
    exits = [
        # mx, my, destMap, destX, destY, type, arg, pad
        (25, 12, 0, 15, 20, 1, 0, 0),   # time gate -> flower field (placeholder)
    ]
    hdr = bytes([0, 0, 0, 14, 14, 11, len(exits), 0])
    body = bytearray(hdr)
    for e in exits:
        body += bytes(e)
    body += grid
    body += baked
    with open(os.path.join(OUT, "map0.bin"), "wb") as f:
        f.write(body)

    # --- world.s ---
    lines = [
        "; AUTO-GENERATED by tools/gen_world.py -- do not edit",
        '.segment "BANK2"',
        ".export Ts0Chr, Ts0ChrEnd, Ts0Pal, Ts0Meta, Ts0Attr",
        'Ts0Chr:  .incbin "ts0_chr.bin"',
        "Ts0ChrEnd:",
        'Ts0Pal:  .incbin "ts0_pal.bin"',
        'Ts0Meta: .incbin "ts0_meta.bin"',
        'Ts0Attr: .incbin "ts0_attr.bin"',
        "",
        '.segment "BANK3"',
        ".export Map0",
        'Map0:    .incbin "map0.bin"',
        "",
        '.segment "RODATA"',
        ".export MapTable, TsChrTable, TsChrSize, TsPalTable, TsMetaTable, TsAttrTable",
        "MapTable:    .faraddr Map0",
        "TsChrTable:  .faraddr Ts0Chr",
        "TsChrSize:   .word Ts0ChrEnd-Ts0Chr",
        "TsPalTable:  .faraddr Ts0Pal",
        "TsMetaTable: .faraddr Ts0Meta",
        "TsAttrTable: .faraddr Ts0Attr",
        ".export TsGroundMeta, TsHedgeMeta",
        "TsGroundMeta: .byte %d" % idx0['.'],
        "TsHedgeMeta:  .byte %d" % idx0['T'],
    ]
    with open(os.path.join(OUT, "world.s"), "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"ts0: {len(chr0)//32} tiles, {len(meta0)} metatiles; map0 {len(body)} bytes")

if __name__ == "__main__":
    main()
