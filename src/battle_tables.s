; ---------------------------------------------------------------------------
; Battle data: hero bases/growth, skills, enemies, formations, item defs.
; ---------------------------------------------------------------------------

.segment "RODATA"

; --- heroes: 16 bytes each ---------------------------------------------------
; +0 baseHp +1 baseMp +2 atk +3 def +4 mag +5 spd
; +6 gHp +7 gMp +8 gAtk +9 gDef +10 gMag +11 gSpd +12..15 pad
.export HeroBase, HeroNames
HeroBase:
        ; KAEN - balanced swordsman
        .byte 48, 10, 12, 7, 6, 7,  13, 3, 2, 1, 1, 1, 0,0,0,0
        ; SLADE - heavy blade
        .byte 42, 5, 13, 8, 3, 5,   16, 2, 3, 2, 1, 1, 0,0,0,0
        ; TESSA - esper mage
        .byte 26, 14, 6, 5, 12, 6,  9, 5, 1, 1, 3, 1, 0,0,0,0
        ; WYLA - primal huntress
        .byte 38, 4, 12, 5, 2, 10,  15, 1, 3, 1, 1, 2, 0,0,0,0
        ; NIX - black mage
        .byte 24, 16, 5, 4, 13, 8,  8, 6, 1, 1, 3, 1, 0,0,0,0

HeroNames:                       ; 6 bytes each, NUL-padded
        .byte "KAEN", 0, 0
        .byte "SLADE", 0
        .byte "TESSA", 0
        .byte "WYLA", 0, 0
        .byte "NIX", 0, 0, 0

; --- skills: 16 bytes each ----------------------------------------------------
; +0..9 name(10,NUL-pad) +10 mpCost +11 power +12 flags +13..15 pad
; flags: bit0 all-targets, bit1 heal, bit2 magic formula, bit3 targets allies
.export SkillTab
SK_ALL   = $01
SK_HEAL  = $02
SK_MAG   = $04
SK_ALLY  = $08
.macro SKILL name, mp, pow, flags
        .local n
n:      .byte name
        .res 10-(*-n), 0
        .byte mp, pow, flags, 0, 0, 0
.endmacro

SkillTab:
        SKILL "Cyclone",    4,  35, 0                       ; 0
        SKILL "Volt Slash", 8,  70, 0                       ; 1
        SKILL "CrimsnWave", 14, 60, SK_ALL                  ; 2
        SKILL "Cleave",     5,  42, 0                       ; 3
        SKILL "QuakeBreak", 10, 80, 0                       ; 4
        SKILL "TitanSmash", 16, 70, SK_ALL                  ; 5
        SKILL "Pounce",     4,  38, 0                       ; 6
        SKILL "WildFrenzy", 12, 85, 0                       ; 7
        SKILL "PrimalRoar", 18, 65, SK_ALL                  ; 8
        SKILL "Aura Heal",  6,  55, SK_HEAL|SK_ALLY         ; 9
        SKILL "Starfall",   15, 75, SK_MAG|SK_ALL           ; 10
        SKILL "ShadowFang", 7,  60, SK_MAG                  ; 11
        SKILL "Void Pulse", 15, 72, SK_MAG|SK_ALL           ; 12
        SKILL "Fire",       5,  45, SK_MAG                  ; 13
        SKILL "Fira",       12, 95, SK_MAG                  ; 14
        SKILL "Firaga",     24, 170, SK_MAG                 ; 15
        SKILL "Cure",       5,  65, SK_HEAL|SK_ALLY         ; 16
        SKILL "Cura",       13, 150, SK_HEAL|SK_ALLY        ; 17
        SKILL "Ice",        5,  48, SK_MAG                  ; 18
        SKILL "Bolt",       5,  50, SK_MAG                  ; 19
        SKILL "Icera",      12, 100, SK_MAG                 ; 20
        SKILL "Boltra",     12, 105, SK_MAG                 ; 21
        SKILL "Doom Flare", 30, 200, SK_MAG|SK_ALL          ; 22
        SKILL "Heal All",   20, 90, SK_HEAL|SK_ALLY|SK_ALL  ; 23

; --- per-hero tech/magic lists -------------------------------------------------
; format: count, then count * {skillId, unlockLevel}
.export HeroTechLists, HeroMagicLists
HeroTechLists:
        .addr KaenT, SladeT, TessaT, WylaT, NixT
HeroMagicLists:
        .addr KaenM, SladeM, TessaM, WylaM, NixM

KaenT:  .byte 3
        .byte 0,1, 1,6, 2,13
SladeT: .byte 3
        .byte 3,1, 4,8, 5,15
TessaT: .byte 2
        .byte 9,1, 10,12
WylaT:  .byte 3
        .byte 6,1, 7,9, 8,16
NixT:   .byte 2
        .byte 11,1, 12,14
KaenM:  .byte 0
SladeM: .byte 0
TessaM: .byte 5
        .byte 13,1, 16,1, 14,9, 17,15, 15,21
WylaM:  .byte 0
NixM:   .byte 5
        .byte 18,1, 19,4, 20,10, 21,12, 22,19

; --- enemies: 24 bytes each ---------------------------------------------------
; +0..9 name +10 maxhp(w) +12 atk +13 def +14 mag +15 spd
; +16 xp(w) +18 gems(w) +20 spriteId +21 aiType +22 palSlot +23 pad
.export EnemyTab
.macro ENEMY name, hp, atk, def, mag, spd, xp, gems, spr, ai, pal
        .local n
n:      .byte name
        .res 10-(*-n), 0
        .word hp
        .byte atk, def, mag, spd
        .word xp
        .word gems
        .byte spr, ai, pal, 0
.endmacro

EnemyTab:
        ENEMY "Gobkin",    30,  7, 4, 0, 5,   8,  6, 0, 0, 0    ; 0
        ENEMY "Fang Wolf", 50, 12, 5, 0, 9,  13,  9, 1, 0, 0    ; 1
        ENEMY "Mud Slime", 72,  8, 9, 0, 3,  11,  8, 2, 0, 0    ; 2
        ; --- bosses (spr = $80|artIdx, pal = boss palette id) ---
        ENEMY "GRASK",      420, 16, 9, 0, 7,  120,  80, $80, 1, 0   ; 3
        ENEMY "MAGMADON",   700, 22, 13, 0, 6, 260, 150, $81, 1, 1   ; 4
        ENEMY "STL WARDEN", 1050, 30, 17, 0, 10, 500, 300, $82, 1, 2 ; 5
        ENEMY "TERRA WYRM", 1500, 38, 20, 0, 9, 900, 500, $83, 1, 3  ; 6
        ENEMY "XETHUL",     2800, 48, 24, 0, 12, 2000, 999, $84, 2, 4 ; 7
        ENEMY "CHRONOWYRM", 4000, 58, 28, 0, 14, 3000, 999, $83, 2, 5 ; 8
        ENEMY "OMEGAGOLEM", 3600, 64, 34, 0, 8, 2600, 999, $82, 2, 6  ; 9
        ; --- era enemies (palette-swap variants) ---
        ENEMY "Raptor",     65, 14, 6, 0, 12,  20, 12, 1, 0, 1   ; 10
        ENEMY "Lava Bug",   55, 16, 4, 0, 8,   18, 10, 0, 0, 1   ; 11
        ENEMY "Stone Ape",  95, 18, 10, 0, 6,  26, 16, 2, 0, 2   ; 12
        ENEMY "ScrapDrone", 90, 22, 12, 0, 14, 40, 30, 0, 0, 2   ; 13
        ENEMY "Sec-Bot",   130, 26, 16, 0, 10, 55, 40, 1, 0, 2   ; 14
        ENEMY "Toxic Ooze",160, 20, 18, 0, 6,  50, 35, 2, 0, 0   ; 15
        ENEMY "Cave Bat",   45, 12, 5, 0, 13,  16, 10, 1, 0, 0   ; 16
        ENEMY "Crawler",    80, 16, 9, 0, 7,   24, 14, 0, 0, 0   ; 17
        ENEMY "Deep Shade",120, 20, 12, 0, 9,  45, 25, 2, 0, 2   ; 18
        ENEMY "Void Spawn",200, 30, 18, 0, 12, 90, 60, 0, 0, 2   ; 19
        ENEMY "Time Leech",240, 34, 20, 0, 10, 110, 70, 2, 0, 1  ; 20
        ENEMY "Imp",       150, 24, 10, 16, 15, 65, 45, 3, 0, 1  ; 21 winged demon, magic-focused

; --- encounter groups ----------------------------------------------------------
; group: count, then count * 3 enemy ids ($FF = empty slot)
.export EncGroupTab
EncGroupTab:
        .addr Grp0, Grp1, Grp2, Grp3, Grp4, Grp5
Grp0:   .byte 6
        .byte 0, $FF, $FF
        .byte 0, $FF, $FF
        .byte 2, $FF, $FF
        .byte 0, 0, $FF
        .byte 1, $FF, $FF
        .byte 0, 2, $FF
Grp1:   .byte 6
        .byte 1, $FF, $FF
        .byte 16, 16, $FF
        .byte 17, $FF, $FF
        .byte 1, 17, $FF
        .byte 2, 2, $FF
        .byte 17, 16, 16
Grp2:   .byte 6
        .byte 10, $FF, $FF
        .byte 11, $FF, $FF
        .byte 10, 11, $FF
        .byte 12, $FF, $FF
        .byte 12, 10, $FF
        .byte 11, 11, 12
Grp3:   .byte 6
        .byte 13, $FF, $FF
        .byte 13, 13, $FF
        .byte 14, $FF, $FF
        .byte 15, $FF, $FF
        .byte 14, 13, $FF
        .byte 15, 14, $FF
Grp4:   .byte 6
        .byte 16, $FF, $FF
        .byte 16, 16, $FF
        .byte 17, 16, $FF
        .byte 18, $FF, $FF
        .byte 18, 17, $FF
        .byte 18, 18, $FF
Grp5:   .byte 6
        .byte 19, $FF, $FF
        .byte 19, 19, $FF
        .byte 20, $FF, $FF
        .byte 20, 19, $FF
        .byte 20, 20, $FF
        .byte 21, 20, $FF

; boss formations: 3 enemy ids each
.export BossFormTab
BossFormTab:
        .byte 3, $FF, $FF       ; 0 GRASK
        .byte 4, $FF, $FF       ; 1 MAGMADON
        .byte 5, $FF, $FF       ; 2 STEEL WARDEN
        .byte 6, $FF, $FF       ; 3 TERRA WYRM
        .byte 7, $FF, $FF       ; 4 XETHUL
        .byte 8, $FF, $FF       ; 5 CHRONO WYRM
        .byte 9, $FF, $FF       ; 6 OMEGA GOLEM

; --- items: 16 bytes each -------------------------------------------------------
; +0..9 name +10 type (0 hp,1 mp,2 revive,3 full) +11 pad +12 power(w) +14 pad
.export ItemTab
ITEM_COUNT = 5
.export ITEM_COUNT
.macro ITEMD name, type, power
        .local n
n:      .byte name
        .res 10-(*-n), 0
        .byte type, 0
        .word power
        .word 0
.endmacro

ItemTab:
        ITEMD "Potion",    0, 60
        ITEMD "Hi-Potion", 0, 250
        ITEMD "Ether",     1, 40
        ITEMD "Revive",    2, 0
        ITEMD "Elixir",    3, 0
