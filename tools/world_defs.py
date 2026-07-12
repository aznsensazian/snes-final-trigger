"""World content: era maps (ASCII), events, dialog strings.

Event tuple: (mx, my, type, a, b, c, flag)
  type 0 warp:       a=destMap b=destX c=destY
  type 1 time gate:  same as warp + gate sfx
  type 2 dialog:     a=strId
  type 3 recruit:    a=heroId b=strId          flag=one-shot bit
  type 4 boss:       a=bossFormId b=strIdIntro c=postDlg   flag=win bit
  type 5 chest:      a=itemId b=strId          flag=one-shot bit
  type 6 heal:       a=strId
  type 9 rift bridge: b=strIdFail (needs crystal flags $F0, warps to map 9)
Flag bits: 0=SLADE 1=WYLA 2=NIX 4=C_WATER 5=C_FIRE 6=C_WIND 7=C_EARTH
           8=WON 9=SB1 10=SB2 11..15=chests
"""

# string pool: symbolic name -> text ('|' = newline)
STRINGS = {}
def S(name, text):
    STRINGS[name] = text
    return name

# ---------------------------------------------------------------------------
S("sign_castle",  "LYRA CASTLE|Festival of Ages today!|The gate hums strangely...")
S("sign_village", "Villager:|The old gate on the east hill|has begun to glow. Be careful!")
S("sign_house2",  "Old woman:|Legends say five Crystals keep|the ages turning in harmony.")
S("sign_house3",  "Boy:|A blue swirl took my kite!|It flew INTO the gate!")
S("cave_hint",    "Miner:|The caverns below Lyra rumble.|Something huge stirs there...")
S("gate_first",   "The time gate crackles...|The crystals' song pulls you|through the ages!")
S("rift_sage",    "The Old Sage:|This is the Rift, outside time.|Xethul devours the Crystals.|Gather them: Water, Fire,|Wind, Earth. Then face it.")
S("rift_bridge_no", "The bridge of hours is dark.|It needs the light of the|four Crystals.")
S("rift_bridge_go", "The four Crystals blaze!|The bridge of hours forms,|leading to Xethul's Maw!")
S("ma_sign",      "Knight:|Fiends spill from the Crystal|Cave. Our blades cannot cut|their hides!")
S("slade_join",   "SLADE:|A mercenary fights for coin...|but time itself unraveling?|That one's on the house.|SLADE joined the party!")
S("grask_intro",  "GRASK, WARDEN OF TIDES:|WHO DARES CLAIM THE|WATER CRYSTAL?!")
S("grask_win",    "The WATER CRYSTAL is yours!|Its light hums with the tide.")
S("wyla_join",    "WYLA:|You fight strong! Wyla fight|with you. Smash big lizard!|WYLA joined the party!")
S("magma_intro",  "MAGMADON:|*The volcano itself seems|to rise on ancient legs*")
S("magma_win",    "The FIRE CRYSTAL is yours!|It burns without burning.")
S("prehist_sign", "Painted on a stone:|Big fire mountain. Angry.|Shiny stone inside.")
S("nix_join",     "NIX:|...you can see me? In this|dead future, I thought I was|the last spark left.|NIX joined the party!")
S("warden_intro", "STEEL WARDEN:|INTRUDERS DETECTED.|CRYSTAL VAULT SEALED.|TERMINATION COMMENCING.")
S("warden_win",   "The WIND CRYSTAL is yours!|It whispers of open skies.")
S("dome_sign",    "Flickering terminal:|...year 2300... Xethul event...|all cities lost... the Crystal|is our last power source...")
S("wyrm_intro",   "TERRA WYRM:|*The caverns shake as the|great worm uncoils*")
S("wyrm_win",     "The EARTH CRYSTAL is yours!|It is heavier than mountains.")
S("xethul_intro", "XETHUL, THE TIME EATER:|LITTLE SPARKS OF HISTORY...|I HAVE EATEN A THOUSAND|TIMELINES. YOURS IS NEXT.")
S("chrono_intro", "CHRONO WYRM:|*A serpent of pure paradox|coils through the void*")
S("chrono_win",   "The paradox dissolves!|The Rift feels calmer now.")
S("omega_intro",  "OMEGA GOLEM:|PROTOTYPE X-9 ONLINE.|NO RECORDED DEFEATS.")
S("omega_win",    "The ancient war machine|falls silent forever.")
S("heal_crystal", "A shard of crystal light|washes over the party.|HP and MP restored!")
S("chest_potion", "Found a Potion!")
S("chest_hipotion", "Found a Hi-Potion!")
S("chest_ether",  "Found an Ether!")
S("chest_revive", "Found a Revive!")
S("chest_elixir", "Found an Elixir!")
S("maw_whisper",  "The walls are made of eaten|centuries. Whispers of lost|timelines beg you onward.")
S("cavern_sign",  "Carved above the arch:|HERE SLEEPS THE SHAPER|OF VALLEYS. DIG NOT DEEP.")

# ---------------------------------------------------------------------------
# Maps. Chars per tileset are defined in gen_world.py.
# ---------------------------------------------------------------------------

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

LYRA_EVENTS = [
    (25, 12, 1, 4, 8, 16, 0xFF, "gate_first"),   # gate -> Rift
    (24, 3, 0, 8, 15, 29, 0xFF, None),           # cave mouth -> Lyra Caverns
    (12, 9, 2, "sign_castle", 0, 0, 0xFF, None),
    (13, 9, 2, "sign_castle", 0, 0, 0xFF, None),
    (8, 13, 2, "sign_village", 0, 0, 0xFF, None),
    (9, 15, 2, "sign_house2", 0, 0, 0xFF, None),
    (11, 16, 2, "sign_house3", 0, 0, 0xFF, None),
    (7, 18, 2, "cave_hint", 0, 0, 0xFF, None),
    (16, 18, 5, 0, "chest_potion", 0, 11, None),  # flower chest
]

MAP_MIDDLE = """
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
^^^^tttttt::::^^^^^:::::::^^^^^^
^^ttttttttt:::::^::::::::::^^^^^
^tttttttttt::::::::::nnnn:::^^^^
^ttttttt::::::::::::nnGnnn::^^^^
^tttt:::::::==::::::nnnnnn::^^^^
^ttt:::,,,,,==,::::::nnnn:::^^^^
^tt::,,,h,,,==,,:::::::::::^^^^^
^t:::,,,,,,,==,,,::::::::::^^^^^
^::::,,h,,,===,,,::::::::^^^^^^^
^::::,,,,,==,,,,::::::::::^^^^^^
^:::,,,,,==,,,,::::::::::::^^^^^
~~::,,,,==,::::::::::::::::^^^^^
~~~b,,,==,::::::::tttttt:::^^^^^
~~~~b,==,::::::::tttttttt::^^^^^
~~~~~B=::::::::::ttttttttt:^^^^^
~~~~~B=:::::::::tttttttttt:^^^^^
~~~~b=,::::::::ttttttttttt^^^^^^
~~~b=,,::::::::ttttttt^^^^^^^^^^
~~~b=,::::::::ttttt^^^^^#o#^^^^^
~~b==,::::::::::tt:^^^^^#=#^^^^^
~~b=,,:::::::::::::^^^^^#=#^^^^^
~~b=,::::::::::::::::^^##=##^^^^
~~b==,,::::::::::::::=====^^^^^^
~~~b==::::::::::::::=:::::=^^^^^
~~~~b===:::::::::===::::::=^^^^^
~~~~~b,,==========::::::::^^^^^^
~~~~~b,,::::::::::::::::::^^^^^^
~~~~b::::::::::::::::::::^^^^^^^
~~~^^::::::::::::::::::^^^^^^^^^
^^^^^^::::::::::::::::^^^^^^^^^^
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
""".strip().splitlines()

MIDDLE_EVENTS = [
    (22, 4, 1, 4, 8, 16, 0xFF, None),            # gate -> Rift
    (25, 19, 0, 5, 15, 29, 0xFF, None),          # cave mouth -> Crystal Cave
    (8, 7, 3, 1, "slade_join", 0, 0, None),      # SLADE at his house (heroId 1)
    (7, 9, 2, "ma_sign", 0, 0, 0xFF, None),
    (12, 6, 2, "ma_sign", 0, 0, 0xFF, None),
    (5, 26, 5, 2, "chest_ether", 0, 12, None),
]

MAP_PREHIST = """
^^^^^^^^^^^^&&&&&&&&&^^^^^^^^^^^
^^jjjjjjj^^&&&&&&&&&&&^^jjjjj^^^
^jjjjjjjjj^&&&LLLLL&&&^jjjjjjj^^
^jjjjjjjjjj&&LLLLLLL&&jjjjjjjj^^
^jjjj:::::j&&LLLoLLL&&j::::jjj^^
^jjj::::::j&&&LL=LL&&&j:::::j^^^
^jj:::,::::&&&&&=&&&&&::::::j^^^
^jj::,,,::::&&&&=&&&&:::::::j^^^
^j:::,,,,::::========::::::jj^^^
^j::::,,,:::=:::::::=::::::jj^^^
^jj::::::::=::::::::==:::::j^^^^
^jjj::::::==:::::::::=::::jj^^^^
~~jjj:::::=:::::::::::=:::jj^^^^
~~~j::::::=::::nnnn:::=::::j^^^^
~~~~::::::=:::nnGnnn::=::::j^^^^
~~~~b:::::=:::nnnnnn::==:::j^^^^
~~~~b:::::==::nnnnn::::=:::j^^^^
~~~b::::::,=::::::::::=::::j^^^^
~~~b:::,,,,==,,::::::==:::jj^^^^
~~b::::,,,,,==,,:::::=::::jj^^^^
~~b::,,,,,,,,==,,::::=:::jjj^^^^
~~~b,,,,,,,,,,==,::::==::jj^^^^^
~~~~b,,,,,,,,,,=,:::::=:jjj^^^^^
~~~~~bb,,,,,,,,==::::=::jj^^^^^^
~~~~~~~b,,,,,,,,=::::=:jjj^^^^^^
~~~~~~~~bbb,,,,,=::::=jjjj^^^^^^
~~~~~~~~~~~bb,,,==::==jjj^^^^^^^
~~~~~~~~~~~~~b,,,====jjjj^^^^^^^
~~~~~~~~~~~~~~b,,::jjjjj^^^^^^^^
~~~~~~~~~~~~~~~bjjjjjj^^^^^^^^^^
^^^^^^^^^^^^^^^^^jjj^^^^^^^^^^^^
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
""".strip().splitlines()

PREHIST_EVENTS = [
    (16, 14, 1, 4, 8, 16, 0xFF, None),           # gate -> Rift
    (16, 4, 0, 6, 15, 29, 0xFF, None),           # volcano mouth -> Volcano Path
    (11, 18, 3, 3, "wyla_join", 0, 1, None),     # WYLA in the village
    (7, 20, 2, "prehist_sign", 0, 0, 0xFF, None),
    (14, 22, 5, 0, "chest_potion", 0, 13, None),
]

MAP_FUTURE = """
################################
#..........##########..........#
#.mmmmmmmm.###....###.mmmmmmmm.#
#.m======m.##..gg..##.m======m.#
#.m=....=m.##.gGg..##.m=....=m.#
#.m=.**.=m.##..gg..##.m=..*.=m.#
#.m=....=m.###....###.m=....=m.#
#.m==..==m.###....###.m==..==m.#
#.mmm..mmm..##....##..mmm..mmm.#
#....==......#....#......==....#
#....==......#....#......==....#
#.....==....##....##....==.....#
#......======......======......#
#..........==......==..........#
#..........==......==..........#
###.........==....==.........###
#o#..........======...........##
#=#...........====.............#
#=#...........====.............#
#==............==..............#
#.==...........==........===..##
#..==..........==.......==.=..##
#...===........==......==..=..##
#.....==.......==.....==...*..##
#......==......==....==........#
#.......===....==...==.........#
#.........==...==..==..........#
#..........==..==.==...........#
#...........======.............#
#............====..............#
#.............==...............#
################################
""".strip().splitlines()

FUTURE_EVENTS = [
    (15, 4, 1, 4, 8, 16, 0xFF, None),            # gate -> Rift
    (1, 16, 0, 7, 15, 29, 0xFF, None),           # sealed door -> Dome Ruins
    (5, 5, 3, 4, "nix_join", 0, 2, None),        # NIX in west compound
    (26, 5, 2, "dome_sign", 0, 0, 0xFF, None),
    (28, 23, 4, 6, "omega_intro", "omega_win", 10, None),  # OMEGA GOLEM superboss
    (6, 23, 5, 4, "chest_elixir", 0, 14, None),
]

MAP_RIFT = """
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&....................&&&&&&
&&&&........................&&&
&&&....gg..........gg......&&&&
&&....gGg..........gGg......&&&
&&.....gg....pp.....gg......&&&&
&&...........pp.............&&&
&&..........p==p............&&&&
&&..*.......p==p.......*....&&&
&&&.........p==p...........&&&&
&&&&........p==p..........&&&&&
&&&....gg...p==p....gg....&&&&&&
&&....gGg...p==p...gGg.....&&&&
&&.....gg...p==p....gg......&&&
&&...........==.............&&&
&&...........==.............&&&&
&&&..........==............&&&&
&&&&.........==...........&&&&&
&&&&&........==..........&&&&&&
&&&&&&.......==.........&&&&&&&
&&&&&&&......==........&&&&&&&&
&&&&&&&&.....==.......&&&&&&&&&
&&&&&&&&&....==......&&&&&&&&&&
&&&&&&&&&&...==.....&&&&&&&&&&&
&&&&&&&&&&&..==....&&&&&&&&&&&&
&&&&&&&&&&&&.==...&&&&&&&&&&&&&
&&&&&&&&&&&&.==..&&&&&&&&&&&&&&
&&&&&&&&&&&&.==.&&&&&&&&&&&&&&&
&&&&&&&&&&&&.==.&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
""".strip().splitlines()

RIFT_EVENTS = [
    (7, 5, 1, 0, 25, 13, 0xFF, None),            # NW gate -> Present (Lyra)
    (20, 5, 1, 1, 22, 5, 0xFF, None),            # NE gate -> Middle Ages
    (7, 13, 1, 2, 16, 15, 0xFF, None),           # SW gate -> Prehistory
    (19, 13, 1, 3, 15, 5, 0xFF, None),           # SE gate -> Future
    (14, 8, 2, "rift_sage", 0, 0, 0xFF, None),   # sage obelisk
    (13, 8, 2, "rift_sage", 0, 0, 0xFF, None),
    (14, 20, 9, 0, "rift_bridge_no", "rift_bridge_go", 0xFF, None),  # bridge
    (4, 9, 4, 5, "chrono_intro", "chrono_win", 9, None),   # CHRONO WYRM superboss
    (23, 9, 6, "heal_crystal", 0, 0, 0xFF, None),
]

MAP_CAVE_CRYSTAL = """
################################
################################
##......########......##...####
##.####.###....#.####.##.##.####
##.####.##.##..#.####.##.##.####
##.####.##.##.##.####.##.##.####
##..###.##.##.##..###.##.##..###
###.###.##.##.###.###.##.###.###
###.###.##.##.###.###.##.###.###
###.###.##.##.###.###.##.###.###
##..##..#..##..##..#..##..##..##
##.###.##.####.###.##.####.##.##
##.###.##.####.###.##.####.##.##
##.....##..***.....##.***..##.##
######.####.##.#####.#.##.###.##
######.####.##.#####.#.##.###.##
##.....####.##...###.#.##...#.##
##.#########.###.###.#.####.#.##
##.#########.###.###.#.####.#.##
##...#######.###.....#.####...##
####.#######.#########.#########
####.#######.#########.#########
####.....###.#########.......###
########.###.###############.###
########.###.###############.###
##....##.###....##########...###
##.##.##.#####w#.#########.#####
##.##.##.#####ww.#########.#####
##.##....#####ww.#########....##
##.############w.#############.#
##....=........................#
################################
""".strip().splitlines()

CAVE_CRYSTAL_EVENTS = [
    (6, 30, 0, 1, 25, 20, 0xFF, None),           # exit -> Middle Ages
    (12, 13, 4, 0, "grask_intro", "grask_win", 4, None),   # GRASK boss (WATER)
    (21, 13, 6, "heal_crystal", 0, 0, 0xFF, None),
    (24, 13, 5, 1, "chest_hipotion", 0, 15, None),
]

MAP_VOLCANO = """
################################
##LLLLLLLLLL########LLLLLLLLL###
##LLLLLLLLLLL######LLLLLLLLLL###
##LL........LL####LL.......LL###
##LL.######..LL##LL.######.LL###
##L..######...LLLL..######..L###
##L.########.........######.L###
##L.########.*.####..#####..L###
##L..#######...####.......#LL###
##LL.#######..#####..#####.LL###
##LL..######..#####.######.LL###
##LLL.######..#####.######LLL###
##LLL..#####..#####..####LLL####
##LLLL.#####...####..###LLLL####
###LLL..####.L.####...##LLL#####
###LLLL.####.LL.####...#LLL#####
###LLLL..###.LL..####...LL######
####LLLL.###.LLL..####..LL######
####LLLL..##.LLLL..###..L#######
#####LLLL.##..LLLL..##..L#######
#####LLL...##..LLL......L#######
######LL....#...LL.....LL#######
######LLL.......LL....LLL#######
#######LLL...*..L....LLL########
########LLL.....L...LLL#########
#########LL.....L..LLL##########
#########LLL....L.LLL###########
##########LL....LLLL############
###########L..=..LL#############
###########L.....L##############
############....LL##############
################################
""".strip().splitlines()

VOLCANO_EVENTS = [
    (14, 28, 0, 2, 16, 5, 0xFF, None),           # exit -> Prehistory
    (13, 7, 4, 1, "magma_intro", "magma_win", 5, None),    # MAGMADON (FIRE)
    (13, 23, 6, "heal_crystal", 0, 0, 0xFF, None),
    (12, 23, 5, 3, "chest_revive", 0, 3, None),  # uses flag bit 3 (spare)
]

MAP_DOME = """
################################
#..............................#
#.mmmmmmmmmmmmmmmmmmmmmmmmmmmm.#
#.m..........................m.#
#.m.**..####..####..####..**.m.#
#.m.....####..####..####.....m.#
#.m..........................m.#
#.m.####..*..............###.m.#
#.m.####..............#..###.m.#
#.m.......####..####..#......m.#
#.m.......####..####..#......m.#
#.m..####.............#.####.m.#
#.m..####..###..###...#.####.m.#
#.m........###..###....#.....m.#
#.m........###..###....#.....m.#
#.m..**................#..**.m.#
#.m....................#.....m.#
#.mmmmmmmm....mmmmmmmmmm.....m.#
#.........mm.........mmm.....m.#
#..........m..........m......m.#
#.####.....m...####...m.####.m.#
#.####.....m...####...m.####.m.#
#..........m..........m......m.#
#.....##...m....##....m......m.#
#.....##...mm...##...mm......m.#
#...........mm......mm.......m.#
#............mmmmmmmm........m.#
#............................m.#
#.mmmmmmmmmmmmmmmmmmmmmmmmmm.m.#
#............................m.#
#..............=..............#
################################
""".strip().splitlines()

DOME_EVENTS = [
    (15, 30, 0, 3, 1, 17, 0xFF, None),           # exit -> Future
    (23, 7, 4, 2, "warden_intro", "warden_win", 6, None),  # STEEL WARDEN (WIND)
    (5, 15, 6, "heal_crystal", 0, 0, 0xFF, None),
    (27, 15, 5, 1, "chest_hipotion", 0, 12, None),
]

MAP_CAVERNS = """
################################
################################
##.....#########......##########
##.###.#########.####.##########
##.###.#########.####.##########
##.###...........####.##########
##.#####.#######.####.##########
##.#####.#######.####.##########
##...###.###.....####...########
####.###.###.########.#.########
####.###.###.########.#.########
####.....###.########.#.########
##########.#.########.#.########
##########.#.########.#.########
##....####.#.####.....#.####..##
##.##.####.#.####.####.#.###..##
##.##.####...####.####.#.###..##
##.##.###########.####...###..##
##.##.###########.##########.###
##.##..##########.##########.###
##.###.##########.##########.###
##.###.####...###.######.....###
##.###.####.#.###.######.#######
##.###.....##....w######.#######
##.##########.###ww...##.#######
##.##########.###ww.#.##...#####
##...........####w..#.#####.####
############.####...#.#####.####
############.####.###.#####.####
############.####.###......####
##......=........###...########
################################
""".strip().splitlines()

CAVERNS_EVENTS = [
    (8, 29, 0, 0, 24, 4, 0xFF, None),            # exit -> Present overworld
    (12, 21, 4, 3, "wyrm_intro", "wyrm_win", 7, None),     # TERRA WYRM (EARTH)
    (30, 14, 6, "heal_crystal", 0, 0, 0xFF, None),
    (2, 26, 2, "cavern_sign", 0, 0, 0xFF, None),
]

MAP_MAW = """
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&pppp&&&&&&&&&&&&&&
&&&&&&&&&&&&pp....pp&&&&&&&&&&&&
&&&&&&&&&&pp...**...pp&&&&&&&&&&
&&&&&&&&&p....pppp....p&&&&&&&&&
&&&&&&&&p...pp&&&&pp...p&&&&&&&&
&&&&&&&p...p&&&&&&&&p...p&&&&&&&
&&&&&&p...p&&&&&&&&&&p...p&&&&&&
&&&&&&p..p&&&&&&&&&&&&p..p&&&&&&
&&&&&p..p&&&&&&&&&&&&&&p..p&&&&&
&&&&&p..p&&&&pppppp&&&&p..p&&&&&
&&&&p..p&&&&pp....pp&&&&p..p&&&&
&&&&p..p&&&pp......pp&&&p..p&&&&
&&&p..p&&&&p...pp...p&&&&p..p&&&
&&&p..p&&&&p..p&&p..p&&&&p..p&&&
&&&p..pppppp..p&&p..pppppp..p&&&
&&&p........*.p&&p..........p&&&
&&&pppppppppppp&&pppppppppppp&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&pppppppppp&&&&&&&&&&&
&&&&&&&&&&pp........pp&&&&&&&&&&
&&&&&&&&&pp....==....pp&&&&&&&&&
&&&&&&&&pp.....==.....pp&&&&&&&&
&&&&&&&&p......==......p&&&&&&&&
&&&&&&&&p......==......p&&&&&&&&
&&&&&&&&p......==......p&&&&&&&&
&&&&&&&&p......==......p&&&&&&&&
&&&&&&&&pppppp.==.pppppp&&&&&&&&
&&&&&&&&&&&&&p.==.p&&&&&&&&&&&&&
&&&&&&&&&&&&&p....p&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
""".strip().splitlines()

MAW_EVENTS = [
    (15, 29, 0, 4, 14, 21, 0xFF, None),          # exit back -> Rift
    (16, 4, 4, 4, "xethul_intro", "xethul_intro", 8, None),   # XETHUL (WON)
    (12, 17, 2, "maw_whisper", 0, 0, 0xFF, None),
    (20, 17, 6, "heal_crystal", 0, 0, 0xFF, None),
]

# map registry: (name, gridlines, events, tileset, music, encGroup, encRate, spawn)
MAPS = [
    ("Lyra Present",  MAP_LYRA,        LYRA_EVENTS,        0, 1, 0, 16, (13, 12)),
    ("Middle Ages",   MAP_MIDDLE,      MIDDLE_EVENTS,      0, 1, 1, 14, (13, 10)),
    ("Prehistory",    MAP_PREHIST,     PREHIST_EVENTS,     1, 6, 2, 14, (16, 15)),
    ("Future",        MAP_FUTURE,      FUTURE_EVENTS,      2, 7, 3, 12, (15, 5)),
    ("The Rift",      MAP_RIFT,        RIFT_EVENTS,        3, 5, 4, 0,  (14, 16)),
    ("Crystal Cave",  MAP_CAVE_CRYSTAL, CAVE_CRYSTAL_EVENTS, 4, 5, 1, 18, (6, 29)),
    ("Volcano Path",  MAP_VOLCANO,     VOLCANO_EVENTS,     4, 6, 2, 18, (14, 28)),
    ("Dome Ruins",    MAP_DOME,        DOME_EVENTS,        2, 7, 3, 16, (15, 29)),
    ("Lyra Caverns",  MAP_CAVERNS,     CAVERNS_EVENTS,     4, 5, 4, 18, (8, 29)),
    ("Xethul's Maw",  MAP_MAW,         MAW_EVENTS,         3, 8, 5, 16, (15, 28)),
]
