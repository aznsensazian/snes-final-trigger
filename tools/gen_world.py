#!/usr/bin/env python3
"""Generate all tilesets + maps + dialog strings -> assets/world.s and blobs.

Map binary layout (mapN.bin):
  +0 tileset, +1 music, +2 encGroup, +3 encRate, +4 spawnX, +5 spawnY,
  +6 eventCount, +7 pad,
  +8 events[E*8]{mx,my,type,a,b,c,flag,pad},
  then 1024 metatile grid, then 8192 baked 64x64 tilemap.
Attr flags: bit0 solid, bit1 encounter.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import tile_4bpp, pack_palette, bgr555
from tileart import h, speckle, hstripes, overlay, art16, split16
from world_defs import STRINGS, MAPS

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
SOLID, ENC = 1, 2

def q(tl, tr, bl, br):
    out = []
    for y in range(8):
        out.append(tl[y] + tr[y])
    for y in range(8):
        out.append(bl[y] + br[y])
    return out

def q4(painter, s0):
    return q(painter(s0), painter(s0 + 1), painter(s0 + 2), painter(s0 + 3))

def on_base(base16, art):
    g = [row[:] for row in base16]
    for y in range(16):
        for x in range(16):
            if art[y][x]:
                g[y][x] = art[y][x]
    return g

# shared structure art (palette 3 slots: o=1 s=2 S=3 d=4 r=5 R=6 w=7 W=8
#                       y=9 p=10 P=11 q=12 v=13 n=14 x=15)
SM = {"o": 1, "s": 2, "S": 3, "d": 4, "r": 5, "R": 6, "w": 7, "W": 8,
      "y": 9, "p": 10, "P": 11, "q": 12, "v": 13, "n": 14, "x": 15}

GATE_ART = art16([
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
], SM)

# ===========================================================================
# tileset 0: Verdant Realm
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

def ts_verdant():
    M = {}
    tm = {"o": 1, "g": 2, "G": 3, "d": 4, "f": 5, "F": 6, "w": 7, "W": 8,
          "l": 9, "s": 10, "S": 11, "r": 12, "R": 13, "k": 14, "n": 15}
    g = lambda s: speckle(2, 4, 3, s)
    grass = q4(g, 1)
    M["."] = (grass, 2, 0)
    M[","] = (q4(g, 5), 2, 0)
    wg = lambda s: speckle(2, 5, 3, s, dark_th=60, light_th=22)
    M[":"] = (q4(wg, 11), 2, ENC)
    fl = lambda s: overlay(g(s), speckle(0, 15, 10, s + 40, dark_th=10, light_th=8))
    M["F"] = (q4(fl, 21), 2, 0)
    def water(seed, phase):
        base = speckle(7, 7, 8, seed, dark_th=0, light_th=26)
        for y in range(8):
            if (y + phase) % 4 == 0:
                for x in range(8):
                    if h(x, y, seed + 9) < 110:
                        base[y][x] = 9
        return base
    M["~"] = (q(water(31, 0), water(32, 2), water(33, 1), water(34, 3)), 2, SOLID)
    sa = lambda s: speckle(10, 11, 10, s)
    M["b"] = (q4(sa, 41), 2, 0)
    pa = lambda s: speckle(11, 10, 11, s, dark_th=25, light_th=25)
    M["="] = (q4(pa, 51), 2, 0)
    ff = lambda s: speckle(5, 4, 6, s, dark_th=70, light_th=40)
    M["t"] = (q4(ff, 61), 2, ENC)
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
        "................",
    ], tm)
    M["T"] = (on_base(q4(g, 71), tree), 2, SOLID)
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
    M["^"] = (on_base(q4(g, 81), mnt), 2, SOLID)
    hl = lambda s: overlay(speckle(2, 4, 3, s), hstripes(0, 4, 5, 1, s % 3))
    M["n"] = (q4(hl, 91), 2, ENC)
    def plank(seed):
        gr = [[8 if y % 4 == 0 else 7 for _ in range(8)] for y in range(8)]
        for y in range(8):
            for x in range(8):
                if y % 4 != 0:
                    gr[y][x] = 11 if (x + y) % 7 else 10
        return gr
    M["B"] = (q(plank(1), plank(2), plank(3), plank(4)), 2, 0)
    rk = lambda s: speckle(12, 14, 13, s, dark_th=50, light_th=30)
    M["#"] = (q4(rk, 101), 2, SOLID)
    wallart = art16([
        "sSssSsSSsSssSsSs", "ssssssssssssssss", "oooooooooooooooo",
        "sSsSodSsSsdoSsSs", "ssssossssssossss", "SsSsodSsSsdoSsSs",
        "ssssossssssossss", "oooooooooooooooo", "sSsSsSodSsSsSsSs",
        "sssssssossssssss", "SsSsSsodSsSsSsSs", "ssssssossssssss"[:16].ljust(16, "s"),
        "oooooooooooooooo", "sSsSodSsSsSdoSsS", "ssssossssssossss",
        "dddddddddddddddd",
    ], SM)
    M["W"] = (wallart, 3, SOLID)
    roofart = art16([
        "nn..nn..nn..nn..", "nnoonnoonnoonnoo", "ssssssssssssssss",
        "SsSsSsSsSsSsSsSs", "ssssssssssssssss", "oooooooooooooooo",
        "rrrrrrrrrrrrrrrr", "rRrrRrrRrrRrrRrr", "rrrrrrrrrrrrrrrr",
        "RrrRrrRrrRrrRrrR", "rrrrrrrrrrrrrrrr", "rrRrrRrrRrrRrrRr",
        "oooooooooooooooo", "ssssssssssssssss", "SsSsSsSsSsSsSsSs",
        "ssssssssssssssss",
    ], SM)
    M["R"] = (roofart, 3, SOLID)
    gateart = art16([
        "sSsSsSsSsSsSsSsS", "ssssssssssssssss", "ssooooooooooooss",
        "ssoqqqqqqqqqqoss", "ssoqPPPPPPPPqoss", "soqqPqqqqqqPqqos",
        "soqPqooooooqPqos", "soqPqowwowoqPqos", "soqPqowwowoqPqos",
        "soqPqowwowoqPqos", "soqPqowwowoqPqos", "soqPqowwowoqPqos",
        "soqPqowwowoqPqos", "soqPqowwowoqPqos", "ssssssssssssssss",
        "dddddddddddddddd",
    ], SM)
    M["D"] = (gateart, 3, SOLID)
    houseart = art16([
        "....oooooooo....", "..oorrrrrrrroo..", ".orrrrRrrRrrrro.",
        "orrRrrrrrrrrRrro", "oRrrrRrrrrRrrrRo", "orrrrrrrrrrrrrro",
        "oooooooooooooooo", "owwWwwwWwwwWwwoo", "owyyowwwwwowyyoo",
        "owyyowqqqwowyyoo", "owwwowqqqwowwwoo", "owWwowqPqwowWwoo",
        "owwwowqPqwowwwoo", "oooooooooooooooo", "................",
        "................",
    ], SM)
    M["h"] = (on_base(q4(g, 111), houseart), 3, SOLID)
    M["G"] = (on_base(q4(g, 121), GATE_ART), 3, 0)
    cave = art16([
        "rrRrrRrrrRrrRrrr", "rrrrrrrrrrrrrrrr", "rRrrooooooorrRrr",
        "rrrooooooooorrr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "ggooooooooooogg.",
        "gggggggggggggggg",
    ], {"r": 12, "R": 13, "o": 1, "g": 2})
    M["o"] = (cave, 2, 0)
    return M, TS0_PAL2, TS0_PAL3, ".", "T"

# ===========================================================================
# tileset 1: Primal Jungle (Prehistory)
# ===========================================================================
TS1_PAL2 = [
    (0, 0, 0), (1, 2, 1), (6, 15, 5), (9, 19, 7), (4, 11, 4),
    (2, 8, 3), (4, 12, 4), (4, 9, 20), (7, 13, 26), (12, 19, 30),
    (22, 18, 11), (16, 11, 6), (11, 7, 5), (15, 10, 7), (31, 18, 4),
    (29, 9, 2),
]

def ts_jungle():
    M = {}
    g = lambda s: speckle(2, 4, 3, s + 900)
    M[","] = (q4(g, 1), 2, 0)
    wg = lambda s: speckle(2, 5, 3, s + 910, dark_th=70, light_th=18)
    M[":"] = (q4(wg, 5), 2, ENC)
    def water(seed, phase):
        base = speckle(7, 7, 8, seed, dark_th=0, light_th=26)
        for y in range(8):
            if (y + phase) % 4 == 0:
                for x in range(8):
                    if h(x, y, seed + 9) < 110:
                        base[y][x] = 9
        return base
    M["~"] = (q(water(131, 0), water(132, 2), water(133, 1), water(134, 3)), 2, SOLID)
    sa = lambda s: speckle(10, 11, 10, s + 920)
    M["b"] = (q4(sa, 9), 2, 0)
    pa = lambda s: speckle(11, 12, 10, s + 930, dark_th=30, light_th=20)
    M["="] = (q4(pa, 13), 2, 0)
    tm = {"o": 1, "g": 2, "G": 3, "d": 4, "f": 5, "F": 6, "s": 10, "S": 11,
          "r": 12, "R": 13, "L": 14, "l": 15}
    jung = art16([
        ".offo..offfo....",
        "offffoofFfffo...",
        "ofFffooffffFfo..",
        "offffffFffffo...",
        ".offFfffffffo...",
        "..offffFffo.....",
        "...odffffo......",
        "..offdffffo.....",
        ".ofFffdffffo....",
        "offfffdffFffo...",
        "ofFffodoffffo...",
        "offffodofFffo...",
        ".offoododffo....",
        "..oo..odo.oo....",
        "......odo.......",
        "................",
    ], tm)
    M["j"] = (on_base(q4(wg, 17), jung), 2, SOLID)
    mnt = art16([
        "......okko......",
        ".....okrrko.....",
        "....okrRrrko....",
        "....orrrRrro....",
        "...okrrrrrrko...",
        "...orrrRrrrro...",
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
    ], {**tm, "k": 12, "n": 13})
    M["^"] = (on_base(q4(g, 21), mnt), 2, SOLID)
    hl = lambda s: overlay(speckle(2, 4, 3, s + 940), hstripes(0, 4, 5, 1, s % 3))
    M["n"] = (q4(hl, 25), 2, ENC)
    # volcano rock rim
    vr = lambda s: speckle(12, 1, 13, s + 950, dark_th=45, light_th=30)
    M["&"] = (q4(vr, 29), 2, SOLID)
    # lava (bright animated-ish)
    def lava(seed):
        base = speckle(14, 15, 14, seed + 960, dark_th=60, light_th=0)
        return base
    M["L"] = (q4(lava, 33), 2, SOLID)
    # volcano mouth (enterable)
    mouth = art16([
        "rrRrrRrrrRrrRrrr", "rrrrrrrrrrrrrrrr", "rRrrooooooorrRrr",
        "rrrooooooooorrr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "rrooooooooooorr.",
        "rrooooooooooorr.", "rrooooooooooorr.", "LLooooooooooogLL",
        "LLLLLLLLLLLLLLLL",
    ], {"r": 12, "R": 13, "o": 1, "g": 2, "L": 14})
    M["o"] = (mouth, 2, 0)
    M["G"] = (on_base(q4(g, 37), GATE_ART), 3, 0)
    return M, TS1_PAL2, TS0_PAL3, ":", "j"

# ===========================================================================
# tileset 2: Ruined Future
# ===========================================================================
TS2_PAL2 = [
    (0, 0, 0), (2, 2, 4), (8, 9, 12), (11, 12, 16), (6, 7, 9),
    (14, 15, 20), (18, 19, 24), (13, 7, 4), (6, 22, 20), (28, 24, 6),
    (12, 11, 8), (16, 15, 12), (20, 20, 25), (4, 4, 6), (24, 26, 30),
    (10, 16, 24),
]

def ts_tech():
    M = {}
    fl = lambda s: speckle(2, 4, 3, s + 700, dark_th=35, light_th=18)
    M["."] = (q4(fl, 1), 2, ENC)
    def panel(seed):
        gr = speckle(2, 4, 3, seed + 710, dark_th=20, light_th=10)
        for x in range(8):
            gr[0][x] = 4
        for y in range(8):
            gr[y][0] = 4
        return gr
    M["="] = (q4(panel, 5), 2, 0)
    def wall(seed):
        gr = speckle(5, 4, 6, seed + 720, dark_th=25, light_th=25)
        for x in range(8):
            gr[7][x] = 1
            gr[3][x] = 4
        return gr
    M["m"] = (q4(wall, 9), 2, SOLID)
    def bigwall(seed):
        gr = speckle(3, 13, 5, seed + 730, dark_th=40, light_th=25)
        for x in range(8):
            gr[0][x] = 6
        return gr
    M["#"] = (q4(bigwall, 13), 2, SOLID)
    tm = {"o": 1, "s": 2, "S": 3, "d": 4, "w": 5, "W": 6, "r": 7, "g": 8,
          "y": 9, "u": 10, "U": 11, "M": 12, "k": 13, "n": 14, "b": 15}
    term = art16([
        "................",
        "..oooooooooooo..",
        ".oWWWWWWWWWWWWo.",
        ".oWkkkkkkkkkkWo.",
        ".oWkggggggggkWo.",
        ".oWkgkkgkkggkWo.",
        ".oWkggggggggkWo.",
        ".oWkkkkkkkkkkWo.",
        ".oWWWWWWWWWWWWo.",
        ".oWwwwwwwwwwwWo.",
        ".oWwyywrrwyywWo.",
        ".oWwwwwwwwwwwWo.",
        ".oWWWWWWWWWWWWo.",
        "..oooooooooooo..",
        "................",
        "................",
    ], tm)
    M["*"] = (on_base(q4(fl, 17), term), 2, SOLID)
    door = art16([
        "wwWwwwWwwWwwWwww", "wwwwwwwwwwwwwwww", "wwooooooooooooww",
        "wwokkkkkkkkkkoww", "wwokggggggggkoww", "wwokkkkkkkkkkoww",
        "wwokkkkkkkkkkoww", "wwokkkkkkkkkkoww", "wwokkkkkkkkkkoww",
        "wwokkkkkkkkkkoww", "wwokkkkkkkkkkoww", "wwokkkkkkkkkkoww",
        "wwokkkkkkkkkkoww", "wwokkkkkkkkkkoww", "wwwwwwwwwwwwwwww",
        "ssssssssssssssss",
    ], tm)
    M["o"] = (door, 2, 0)
    M["g"] = (q4(lambda s: speckle(2, 8, 3, s + 740, dark_th=30, light_th=14), 21), 2, 0)
    M["G"] = (on_base(q4(fl, 25), GATE_ART), 3, 0)
    return M, TS2_PAL2, TS0_PAL3, ".", "m"

# ===========================================================================
# tileset 3: The Rift / Void
# ===========================================================================
TS3_PAL2 = [
    (0, 0, 0), (2, 1, 5), (4, 2, 10), (6, 3, 14), (3, 1, 7),
    (10, 6, 18), (14, 10, 24), (7, 4, 14), (18, 12, 30), (26, 24, 31),
    (16, 26, 31), (12, 8, 22), (20, 16, 28), (2, 2, 4), (30, 30, 31),
    (8, 5, 16),
]

def ts_void():
    M = {}
    def void(seed):
        gr = speckle(2, 4, 3, seed + 800, dark_th=30, light_th=0)
        for y in range(8):
            for x in range(8):
                if h(x, y, seed + 801) < 5:
                    gr[y][x] = 9
        return gr
    M["&"] = (q4(void, 1), 2, SOLID)
    flo = lambda s: speckle(5, 7, 6, s + 810, dark_th=35, light_th=20)
    M["."] = (q4(flo, 5), 2, 0)
    def edge(seed):
        gr = speckle(5, 7, 6, seed + 820, dark_th=35, light_th=20)
        for x in range(8):
            gr[0][x] = 8
        return gr
    M["p"] = (q4(edge, 9), 2, SOLID)
    def bridge(seed):
        gr = speckle(6, 5, 12, seed + 830, dark_th=25, light_th=30)
        for y in range(8):
            gr[y][0] = 8
            gr[y][7] = 8
        return gr
    M["="] = (q4(bridge, 13), 2, 0)
    tm = {"o": 1, "c": 10, "C": 14, "v": 11, "V": 12, "s": 9}
    crys = art16([
        "................",
        ".......oo.......",
        "......oCco......",
        "......occo......",
        ".....oCccco.....",
        ".....occcco.....",
        "....oCcvvcco....",
        "....occvvcco....",
        "...oCccvvccco...",
        "...occcvvccco...",
        "...occcvvccco...",
        "....occccccco...",
        "....occcccco....",
        ".....oooooo.....",
        "................",
        "................",
    ], tm)
    M["*"] = (on_base(q4(flo, 17), crys), 2, SOLID)
    M["g"] = (q4(lambda s: speckle(5, 7, 8, s + 840, dark_th=20, light_th=25), 21), 2, 0)
    M["G"] = (on_base(q4(flo, 25), GATE_ART), 3, 0)
    return M, TS3_PAL2, TS0_PAL3, ".", "p"

# ===========================================================================
# tileset 4: Caverns
# ===========================================================================
TS4_PAL2 = [
    (0, 0, 0), (1, 1, 1), (11, 9, 7), (14, 11, 9), (8, 6, 5),
    (9, 7, 6), (13, 10, 8), (4, 9, 20), (8, 14, 26), (12, 19, 30),
    (16, 26, 31), (24, 31, 31), (31, 18, 4), (29, 10, 2), (5, 4, 3),
    (18, 15, 12),
]

def ts_cave():
    M = {}
    flo = lambda s: speckle(2, 4, 3, s + 500, dark_th=40, light_th=18)
    M["."] = (q4(flo, 1), 2, ENC)
    def rock(seed):
        gr = speckle(5, 14, 6, seed + 510, dark_th=45, light_th=28)
        for x in range(8):
            if h(x, 0, seed) < 128:
                gr[0][x] = 15
        return gr
    M["#"] = (q4(rock, 5), 2, SOLID)
    def water(seed, phase):
        base = speckle(7, 7, 8, seed + 520, dark_th=0, light_th=26)
        for y in range(8):
            if (y + phase) % 4 == 0:
                for x in range(8):
                    if h(x, y, seed + 9) < 110:
                        base[y][x] = 9
        return base
    M["w"] = (q(water(41, 0), water(42, 2), water(43, 1), water(44, 3)), 2, SOLID)
    lv = lambda s: speckle(12, 13, 12, s + 530, dark_th=60, light_th=0)
    M["L"] = (q4(lv, 9), 2, SOLID)
    tm = {"o": 1, "c": 10, "C": 11, "f": 2}
    crys = art16([
        "................",
        ".....oo..oo.....",
        "....oCco.occo...",
        "....occo.oCco...",
        "...oCccco.occo..",
        "...occcco.occo..",
        "..oCccccco.oo...",
        "..occccccco.....",
        "..occCccccoocco.",
        "...occcccccCcco.",
        "...occcccccccoo.",
        "....occcccccco..",
        ".....ooooooo....",
        "................",
        "................",
        "................",
    ], tm)
    M["*"] = (on_base(q4(flo, 13), crys), 2, SOLID)
    pa = lambda s: speckle(15, 6, 3, s + 540, dark_th=30, light_th=20)
    M["="] = (q4(pa, 17), 2, 0)
    return M, TS4_PAL2, TS0_PAL3, ".", "#"

TILESETS = [ts_verdant, ts_jungle, ts_tech, ts_void, ts_cave]

# ===========================================================================
def build_tileset(mdict):
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

def bake_map(grid_chars, meta_index, meta_defs):
    grid = bytearray()
    rows = list(grid_chars)
    while len(rows) < 32:
        rows.append(rows[-1])
    for row in rows[:32]:
        row = row.ljust(32, row[-1])[:32]
        for ch in row:
            grid.append(meta_index[ch])
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

def main():
    os.makedirs(OUT, exist_ok=True)

    # string pool -> ids
    str_names = sorted(STRINGS.keys())
    str_ids = {n: i for i, n in enumerate(str_names)}

    def resolve(v):
        if isinstance(v, str):
            return str_ids[v]
        return int(v) & 0xFF

    ts_data = []
    for i, fn in enumerate(TILESETS):
        M, pal2, pal3, ground, hedge = fn()
        chrb, meta, attr, idx = build_tileset(M)
        pal = pack_palette([bgr555(*c) for c in pal2] + [bgr555(*c) for c in pal3])
        meta_bin = bytearray()
        for words in meta:
            for w in words:
                meta_bin += w.to_bytes(2, "little")
        with open(os.path.join(OUT, f"ts{i}_chr.bin"), "wb") as f:
            f.write(chrb)
        with open(os.path.join(OUT, f"ts{i}_pal.bin"), "wb") as f:
            f.write(pal)
        with open(os.path.join(OUT, f"ts{i}_meta.bin"), "wb") as f:
            f.write(meta_bin)
        with open(os.path.join(OUT, f"ts{i}_attr.bin"), "wb") as f:
            f.write(attr)
        ts_data.append((meta, idx, idx[ground], idx[hedge], len(chrb)))
        print(f"ts{i}: {len(chrb)//32} tiles, {len(meta)} metatiles")

    # maps
    for mi, (name, grid_lines, events, ts, music, grp, rate, spawn) in enumerate(MAPS):
        meta, idx, _, _, _ = ts_data[ts]
        grid, baked = bake_map(grid_lines, idx, meta)
        attr_bin = open(os.path.join(OUT, f"ts{ts}_attr.bin"), "rb").read()

        def walkable(x, y):
            if not (0 <= x < 32 and 0 <= y < 32):
                return False
            return not (attr_bin[grid[y * 32 + x]] & 1)

        def relocate(x, y, what):
            if walkable(x, y):
                return x, y
            for dx, dy in ((0, 1), (0, -1), (-1, 0), (1, 0), (0, 2),
                           (2, 0), (-2, 0), (1, 1), (-1, 1), (1, -1),
                           (-1, -1), (0, -2)):
                if walkable(x + dx, y + dy):
                    print(f"  map{mi}: moved {what} ({x},{y})->({x+dx},{y+dy})")
                    return x + dx, y + dy
            raise ValueError(f"map{mi}: no walkable tile near ({x},{y}) for {what}")

        sx, sy = relocate(spawn[0], spawn[1], "spawn")
        body = bytearray([ts, music, grp, rate, sx, sy, len(events), 0])
        for ev in events:
            mx, my, typ, aa, bb, cc, flag = ev[:7]
            mx, my = relocate(mx, my, f"event t{typ}")
            body += bytes([mx, my, typ, resolve(aa), resolve(bb),
                           resolve(cc), flag & 0xFF, 0])
        body += grid
        body += baked
        with open(os.path.join(OUT, f"map{mi}.bin"), "wb") as f:
            f.write(body)

    # strings blob: emitted directly in world.s as .byte lines
    def esc(txt):
        out = []
        for part in txt.split("|"):
            out.append(part)
        return out

    lines = [
        "; AUTO-GENERATED by tools/gen_world.py -- do not edit",
        '.segment "BANK2"',
    ]
    exports = []
    for i in range(len(TILESETS)):
        exports += [f"Ts{i}Chr", f"Ts{i}ChrEnd", f"Ts{i}Pal", f"Ts{i}Meta",
                    f"Ts{i}Attr"]
    lines.append(".export " + ", ".join(exports))
    for i in range(len(TILESETS)):
        lines += [
            f'Ts{i}Chr:  .incbin "ts{i}_chr.bin"',
            f"Ts{i}ChrEnd:",
            f'Ts{i}Pal:  .incbin "ts{i}_pal.bin"',
            f'Ts{i}Meta: .incbin "ts{i}_meta.bin"',
            f'Ts{i}Attr: .incbin "ts{i}_attr.bin"',
        ]
    # maps in banks 3,4,5,7 (bank 6 = audio)
    bank_for = {0: 3, 1: 3, 2: 3, 3: 4, 4: 4, 5: 4, 6: 5, 7: 5, 8: 5, 9: 7}
    cur = None
    for mi in range(len(MAPS)):
        b = bank_for[mi]
        if b != cur:
            lines.append(f'.segment "BANK{b}"')
            cur = b
        lines.append(f".export Map{mi}")
        lines.append(f'Map{mi}: .incbin "map{mi}.bin"')

    # strings in bank 8
    lines.append('.segment "BANK8"')
    lines.append(".export StoryTab")
    for i, nm in enumerate(str_names):
        parts = esc(STRINGS[nm])
        chunks = []
        for j, p in enumerate(parts):
            p2 = p.replace('"', "'")
            chunks.append(f'"{p2}"')
            if j != len(parts) - 1:
                chunks.append("1")
        lines.append(f"Str{i}: .byte " + ", ".join(chunks) + ", 0")
    lines.append("StoryTab:")
    for i in range(len(str_names)):
        lines.append(f"  .faraddr Str{i}")

    lines.append('.segment "RODATA"')
    lines.append(".export MapTable, TsChrTable, TsChrSize, TsPalTable, TsMetaTable, TsAttrTable")
    lines.append(".export TsGroundMeta, TsHedgeMeta")
    lines.append("MapTable: " + " ".join(
        f".faraddr Map{i}" for i in range(len(MAPS))).replace(" .", "\n  ."))
    lines.append("TsChrTable:  " + ", ".join([""]).join(
        [""]))
    # rebuild tables cleanly
    lines = [l for l in lines if not l.startswith("TsChrTable")]
    lines.append("TsChrTable:")
    for i in range(len(TILESETS)):
        lines.append(f"  .faraddr Ts{i}Chr")
    lines.append("TsChrSize:")
    for i in range(len(TILESETS)):
        lines.append(f"  .word Ts{i}ChrEnd-Ts{i}Chr")
    lines.append("TsPalTable:")
    for i in range(len(TILESETS)):
        lines.append(f"  .faraddr Ts{i}Pal")
    lines.append("TsMetaTable:")
    for i in range(len(TILESETS)):
        lines.append(f"  .faraddr Ts{i}Meta")
    lines.append("TsAttrTable:")
    for i in range(len(TILESETS)):
        lines.append(f"  .faraddr Ts{i}Attr")
    lines.append("TsGroundMeta: .byte " + ", ".join(
        str(ts_data[i][2]) for i in range(len(TILESETS))))
    lines.append("TsHedgeMeta:  .byte " + ", ".join(
        str(ts_data[i][3]) for i in range(len(TILESETS))))

    with open(os.path.join(OUT, "world.s"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{len(MAPS)} maps, {len(str_names)} strings")

if __name__ == "__main__":
    main()
