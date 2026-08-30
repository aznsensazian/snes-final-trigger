; ---------------------------------------------------------------------------
; Turn-based battle engine.
; Layout: enemies (32x32 OBJ) on the left, heroes (16x16 OBJ) on the right,
; message window top, command menu + party HUD bottom (BG3), era-tinted
; gradient backdrop (HDMA) with a ground strip built from the current map
; tileset at VRAM $5000 (map tilemap at $4000 is preserved).
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export BattleInit, BattleFrame, GameOverInit, GameOverFrame
.import TextClear, TextPut, TextPutTile, TextFlush, DrawWindow
.import WaitVBlank, Rand8, OamReset, OamPush, OamFinish
.import PrintNumR, PrintNumL
.import PlaySong, PlaySfx
.import PartyGiveXp, PartyAliveMask
.import party, invCount, gems
.importzp PT_FLAGS, PT_LVL, PT_HP, PT_MAXHP, PT_MP, PT_MAXMP
.importzp PT_ATK, PT_DEF, PT_MAG, PT_SPD, PT_XP
.import HeroBase, HeroNames, SkillTab, HeroTechLists, HeroMagicLists
.import EnemyTab, EncGroupTab, ItemTab
.import EnemyObjChr, EnemyPal, BattleGrad
.import TsMetaTable, TsGroundMeta, TsHedgeMeta
.import BossFormTab, BossChr, BossPals, SetFlag
.importzp textPtr, textX, textY, textPal, textOpq
.importzp sprX, sprY, sprTile, sprAttr, sprSize
.importzp joyPressed, joyHeld, pendingState, frameCount, nmiFlags
.importzp shBG1H, shBG1V, shHDMAEN
.importzp numVal, lvlUpMask
.importzp tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7
.importzp mapTsId, mapEncGroup, battleReturn
.importzp bForceForm, bBossFlag, bBossDlg, pendingDlg

; battle phases
BP_INTRO  = 0
BP_NEXT   = 1
BP_MENU   = 2
BP_SUB    = 3
BP_TARGET = 4
BP_WIN    = 5
BP_LOSE   = 6
BP_RUNOK  = 7

SK_ALL   = $01
SK_HEAL  = $02
SK_MAG   = $04
SK_ALLY  = $08

.segment "ZEROPAGE"
battlePhase: .res 1
bTimer:      .res 1
menuSel:     .res 1
subSel:      .res 1
subCount:    .res 1
subKind:     .res 1             ; 1 tech, 2 magic, 3 item
tgtSel:      .res 1
tgtCount:    .res 1
tgtAlly:     .res 1
actHero:     .res 1             ; current hero index (0-4)
actHeroOff:  .res 2             ; hero index * 32
actId:       .res 1             ; skill/item id
actKind:     .res 1             ; 0 attack, 1 skill, 2 item
hideMask:    .res 1             ; enemy blink mask
heroFxIdx:   .res 1             ; hero sprite x offset (attack lunge) index
heroFxOff:   .res 1

.segment "BSS"
bEnemyId:    .res 3
bEnemyAlive: .res 3
bEnemySpr:   .res 3
bEnemyPal:   .res 3
bActCnt:     .res 1
bEnemyHp:    .res 6             ; 3 words
bTurnList:   .res 8
bTurnCount:  .res 1
bTurnPos:    .res 1
bSubIds:     .res 8
bTgtIds:     .res 8
bXpPool:     .res 2
bGemPool:    .res 2
bRound:      .res 1

.segment "EXBSS"
sceneBuf:    .res 2048

.segment "RODATA"
enemyXTab:  .byte 32, 52, 32
enemyYTab:  .byte 52, 92, 132
strApproach: .byte "Enemies draw near!", 0
strVictory:  .byte "Victory!", 0
strGotAway:  .byte "Got away!", 0
strNoEscape: .byte "Can't escape!", 0
strNoMp:     .byte "Not enough MP!", 0
strNoMagic:  .byte "No magic.", 0
strNothing:  .byte "Nothing usable.", 0
strDefeat:   .byte "The party has fallen...", 0
strAttack:   .byte "Attack", 0
strTech:     .byte "Tech", 0
strMagic:    .byte "Magic", 0
strItem:     .byte "Item", 0
strGained:   .byte "Gained ", 0
strXpGems:   .byte " XP!", 0
strLevelUp:  .byte " grew stronger!", 0
strFury:     .byte "unleashes fury!", 0
strGameOver1: .byte "The timeline fades to void.", 0
strGameOver2: .byte "PRESS START", 0

.segment "CODE"

; ===========================================================================
; helpers
; ===========================================================================

; set textPtr to a RODATA string. usage: LDPTR strFoo  (a8/i16)
.macro LDPTR str
        a16
        lda #.loword(str)
        sta textPtr
        a8
        lda #^str
        sta textPtr+2
.endmacro

; print string at col,row with pal
.macro PUTS col, row, pal, str
        lda #pal
        sta textPal
        lda #col
        sta textX
        lda #row
        sta textY
        LDPTR str
        jsr TextPut
.endmacro

; A(8) = rand in [0, tmp7)  (tmp7 = modulus, 1..255)
.proc randMod
        .a8
        .i16
        jsr Rand8
@m:     cmp tmp7
        bcc @done
        sec
        sbc tmp7
        bra @m
@done:  rts
.endproc

; compute actHeroOff = actHero*32
.proc heroOff
        .a8
        .i16
        a16
        lda #0
        a8
        lda actHero
        a16
        asl
        asl
        asl
        asl
        asl
        sta actHeroOff
        a8
        rts
.endproc

; ===========================================================================
; BattleInit
; ===========================================================================
.proc BattleInit
        .a8
        .i16
        ; --- flash effect ---
        lda #5
        jsr PlaySfx
        ldx #3
@fl:    lda #$04
        sta INIDISP
        jsr WaitVBlank
        lda #$0F
        sta INIDISP
        jsr WaitVBlank
        dex
        bne @fl
        lda #$80
        sta INIDISP
        stz shHDMAEN

        jsr TextClear
        lda #128
        sta textOpq             ; battle text lives in windows

        ; --- build ground strip tilemap in sceneBuf ---
        ; get metatile defs ptr for current tileset: TsMetaTable + ts*3
        lda mapTsId
        WidenMul3
        lda f:TsMetaTable,x
        sta tmp1                ; meta base (bank = same as table entries)
        a8
        lda f:TsMetaTable+2,x
        sta tmp2                ; bank in tmp2 low
        ; hedge meta id -> tmp3, ground -> tmp4
        lda mapTsId
        a16
        and #$00FF
        tax
        a8
        lda f:TsHedgeMeta,x
        sta tmp3
        lda f:TsGroundMeta,x
        sta tmp4

        ; clear sceneBuf
        a16
        ldx #0
        lda #$0000
@cl:    sta f:sceneBuf,x
        inx
        inx
        cpx #2048
        bne @cl

        ; helper values: row byte offsets
        ; hedge rows 18,19 ; ground rows 20..27
        a8
        lda tmp3
        jsr metaWords           ; -> tmp5..: wtl,wtr (tmp5), (tmp6) etc via bWords
        ldx #(18*64)
        jsr fillRowPair
        a8
        lda tmp4
        jsr metaWords
        ldx #(20*64)
        jsr fillRowPair
        ldx #(22*64)
        jsr fillRowPair
        ldx #(24*64)
        jsr fillRowPair
        ldx #(26*64)
        jsr fillRowPair

        ; --- DMA sceneBuf -> VRAM $5000 ---
        lda #$80
        sta VMAIN
        a16
        lda #VRAM_BG2MAP
        sta VMADDL
        lda #$1801
        sta DMAP0
        lda #.loword(sceneBuf)
        sta A1T0L
        a8
        lda #^sceneBuf
        sta A1B0
        a16
        lda #2048
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN

        ; --- pick formation and load enemies ---
        jsr pickFormation
        jsr loadEnemyGfx
        DmaToCgram EnemyPal, 144, 32

        ; --- HDMA gradient ---
        lda #$03
        sta DMAP0+$70
        lda #$21
        sta BBAD0+$70
        a16
        lda #.loword(BattleGrad)
        sta A1T0L+$70
        a8
        lda #^BattleGrad
        sta A1B0+$70
        lda #$80
        sta shHDMAEN

        ; --- PPU ---
        lda #$09
        sta BGMODE
        lda #$50                ; BG1 map $5000, 32x32
        sta BG1SC
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG12NBA
        sta BG12NBA
        lda #V_OBSEL_BIG
        sta OBSEL
        lda #$15
        sta TM
        a16
        stz shBG1H
        lda #.loword(-1)
        sta shBG1V
        a8

        ; --- pools/state ---
        stz bXpPool
        stz bXpPool+1
        stz bGemPool
        stz bGemPool+1
        stz hideMask
        stz heroFxIdx
        stz heroFxOff
        stz bRound

        jsr drawHud
        jsr drawMsgApproach
        jsr drawSprites
        jsr OamFinish
        jsr TextFlush

        ; fade in fast
        lda #0
@fi:    pha
        sta INIDISP
        jsr WaitVBlank
        pla
        inc
        inc
        cmp #16
        bcc @fi
        lda #$0F
        sta INIDISP

        lda #2
        jsr PlaySong
        lda #BP_INTRO
        sta battlePhase
        lda #40
        sta bTimer
        rts
.endproc

; read metatile A's 4 tilemap words into bWords (via [tmp1] bank tmp2)
.segment "BSS"
bWords: .res 8
.segment "CODE"
.proc metaWords
        .a8
        .i16
        sta tmp5
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        asl
        asl
        asl                     ; *8
        clc
        adc tmp1
        sta ptrScr
        a8
        lda tmp2
        sta ptrScr+2
        ldy #0
@lp:    lda [ptrScr],y
        sta bWords,y
        iny
        cpy #8
        bne @lp
        rts
.endproc

.segment "ZEROPAGE"
ptrScr: .res 3

.segment "CODE"

; fill two tilemap rows starting at byte offset X in sceneBuf with the
; metatile words in bWords (tl,tr / bl,br alternating across 32 columns)
.proc fillRowPair
        .a8
        .i16
        php
        ai16
        ldy #16                 ; 16 metatile columns
@col:   lda f:bWords+0
        sta f:sceneBuf,x
        inx
        inx
        lda f:bWords+2
        sta f:sceneBuf,x
        inx
        inx
        dey
        bne @col
        ; second row (bl/br)
        ldy #16
@col2:  lda f:bWords+4
        sta f:sceneBuf,x
        inx
        inx
        lda f:bWords+6
        sta f:sceneBuf,x
        inx
        inx
        dey
        bne @col2
        plp
        rts
.endproc

; ---------------------------------------------------------------------------
; pick a random formation from mapEncGroup, fill bEnemy arrays
.proc pickFormation
        .a8
        .i16
        stz bActCnt
        lda bForceForm
        cmp #$FF
        beq @random
        ; forced boss formation: BossFormTab + id*3
        a16
        lda #0
        a8
        lda bForceForm
        a16
        and #$00FF
        sta tmp6
        asl
        clc
        adc tmp6
        clc
        adc #.loword(BossFormTab)
        sta ptrScr
        a8
        lda #^BossFormTab
        sta ptrScr+2
        ldy #0
        ldx #0
@blp:   lda [ptrScr],y
        phy
        jsr initEnemySlot
        ply
        iny
        inx
        cpx #3
        bne @blp
        rts
@random:
        a16
        lda #0
        a8
        lda mapEncGroup
        a16
        and #$00FF
        asl
        tax
        lda f:EncGroupTab,x
        sta ptrScr
        a8
        lda #^EncGroupTab
        sta ptrScr+2
        ; count
        lda [ptrScr]
        sta tmp7
        jsr randMod             ; A = formation idx
        ; offset = 1 + idx*3
        sta tmp6
        a16
        lda #0
        a8
        lda tmp6
        a16
        and #$00FF
        sta tmp6
        asl
        clc
        adc tmp6
        inc
        tay                     ; y = 1 + idx*3
        a8
        ; read 3 slots
        ldx #0
@slot:  lda [ptrScr],y
        phy
        jsr initEnemySlot       ; A = enemy id or $FF, X = slot
        ply
        iny
        inx
        cpx #3
        bne @slot
        rts
.endproc

; init enemy slot X (0-2) with enemy id A ($FF = none)
.proc initEnemySlot
        .a8
        .i16
        cmp #$FF
        bne @yes
        lda #0
        sta f:bEnemyAlive,x
        rts
@yes:   sta f:bEnemyId,x
        lda #1
        sta f:bEnemyAlive,x
        phx
        jsr enemyDefY           ; Y = &EnemyTab[id of slot X]
        a8
        lda a:20,y              ; spriteId
        plx
        sta f:bEnemySpr,x
        phx
        jsr enemyDefY
        a8
        lda a:22,y              ; palSlot
        plx
        sta f:bEnemyPal,x
        phx
        a16
        lda a:10,y              ; maxhp
        sta tmp6
        txa
        and #$00FF
        asl
        tax
        lda tmp6
        sta f:bEnemyHp,x
        plx
        a8
        rts
.endproc

; Y = EnemyTab + bEnemyId[X]*24. Exits a8. Trashes tmp5/tmp6.
.proc enemyDefY
        .a8
        .i16
        a16
        lda #0
        a8
        lda f:bEnemyId,x
        a16
        and #$00FF
        sta tmp5
        asl
        asl
        asl                     ; *8
        sta tmp6
        asl                     ; *16
        clc
        adc tmp6                ; *24
        clc
        adc #.loword(EnemyTab)
        tay
        a8
        rts
.endproc

; ---------------------------------------------------------------------------
; The whole era enemy sheet (64 tiles) lives at OBJ tiles 64-127 ($6400).
; Slot sprites just point at spriteId*4 within it. A boss in slot 0 loads
; its 64x64 art into OBJ tiles 128+ (8 chunks of 8 tiles) + palette 4.
.proc loadEnemyGfx
        .a8
        .i16
        lda #$80
        sta VMAIN
        a16
        lda #(VRAM_OBJCHR + 64*16)
        sta VMADDL
        lda #$1801
        sta DMAP0
        lda #.loword(EnemyObjChr)
        sta A1T0L
        a8
        lda #^EnemyObjChr
        sta A1B0
        a16
        lda #2048
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN
        ; boss?
        lda f:bEnemySpr
        bmi @boss
        rts
@boss:  and #$7F                ; art index
        ; src base = BossChr + art*2048
        a16
        and #$00FF
        xba                     ; *256
        asl
        asl
        asl                     ; *2048
        clc
        adc #.loword(BossChr)
        sta tmp0
        a8
        stz tmp2                ; row 0..7
@row:   a16
        lda tmp0
        sta A1T0L
        lda #$1801
        sta DMAP0
        ; dst = $6000 + (128 + row*16)*16 words
        lda #0
        a8
        lda tmp2
        a16
        xba                     ; row*256 = row*16*16
        clc
        adc #(VRAM_OBJCHR + 128*16)
        sta VMADDL
        lda #256                ; 8 tiles
        sta DAS0L
        a8
        lda #^BossChr
        sta A1B0
        lda #$01
        sta MDMAEN
        a16
        lda tmp0
        clc
        adc #256
        sta tmp0
        a8
        inc tmp2
        lda tmp2
        cmp #8
        bne @row
        ; boss palette -> CGRAM 192 (OBJ palette 4)
        lda f:bEnemyPal
        a16
        and #$00FF
        xba                     ; *256
        lsr
        lsr
        lsr                     ; *32
        clc
        adc #.loword(BossPals)
        sta A1T0L
        a8
        lda #^BossPals
        sta A1B0
        lda #192
        sta CGADD
        a16
        lda #$2200
        sta DMAP0
        lda #32
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN
        rts
.endproc

; ===========================================================================
; drawing
; ===========================================================================

.proc drawMsgApproach
        .a8
        .i16
        jsr msgWindow
        PUTS 1, 1, 0, strApproach
        rts
.endproc

.proc msgWindow
        .a8
        .i16
        lda #1
        sta textPal
        lda #0
        sta textX
        lda #0
        sta textY
        lda #32
        ldx #4
        jsr DrawWindow
        rts
.endproc

; party HUD + command window
.proc drawHud
        .a8
        .i16
        lda #1
        sta textPal
        lda #0
        sta textX
        lda #19
        sta textY
        lda #10
        ldx #9
        jsr DrawWindow
        lda #1
        sta textPal
        lda #10
        sta textX
        lda #19
        sta textY
        lda #22
        ldx #9
        jsr DrawWindow
        ; commands
        PUTS 2, 20, 0, strAttack
        PUTS 2, 22, 0, strTech
        PUTS 2, 24, 0, strMagic
        PUTS 2, 26, 0, strItem
        ; party rows
        stz tmp3                ; hero idx
        ldx #0
@hero:  lda f:party+PT_FLAGS,x
        and #$01
        bne :+
        jmp @next
:       phx
        ; row = 20 + idx
        lda tmp3
        clc
        adc #20
        sta textY
        sta tmp4
        ; name color: red if dead
        a16
        lda f:party+PT_HP,x
        a8
        bne @aliveCol
        lda #5
        bra @col
@aliveCol:
        lda #0
@col:   sta textPal
        lda #11
        sta textX
        ; name ptr = HeroNames + idx*6
        a16
        lda #0
        a8
        lda tmp3
        a16
        sta tmp5
        asl
        asl                     ; *4
        clc
        adc tmp5                ; *5
        clc
        adc tmp5                ; *6
        clc
        adc #.loword(HeroNames)
        sta textPtr
        a8
        lda #^HeroNames
        sta textPtr+2
        jsr TextPut
        plx
        phx
        ; hp cur right-aligned at col 16
        a16
        lda f:party+PT_HP,x
        sta numVal
        a8
        lda #16
        sta textX
        lda tmp4
        sta textY
        lda #0
        sta textPal
        jsr PrintNumR
        lda #('/'-32+128)
        pha
        lda #21
        sta textX
        lda tmp4
        sta textY
        pla
        jsr TextPutTile
        plx
        phx
        a16
        lda f:party+PT_MAXHP,x
        sta numVal
        a8
        lda #22
        sta textX
        lda tmp4
        sta textY
        jsr PrintNumL
        plx
        phx
        a16
        lda f:party+PT_MP,x
        sta numVal
        a8
        lda #26
        sta textX
        lda tmp4
        sta textY
        jsr PrintNumR
        plx
        phx
        ; HP bar: 4 segments at cols 28-31, filled proportional to cur/max HP.
        ; segCount = HP*4 / MAXHP (0..4), clamped.
        a16
        lda f:party+PT_HP,x
        sta tmp5                ; tmp5 = HP (word)
        asl
        asl                     ; HP*4
        sta tmp6                ; tmp6 = HP*4 (word), may need >8bit div
        lda f:party+PT_MAXHP,x
        sta tmp7                ; tmp7 = MAXHP (word)
        a8
        ; if MAXHP == 0, segCount = 0 (shouldn't happen)
        lda tmp7
        ora tmp7+1
        bne @haveMax
        stz numVal
        bra @segReady
@haveMax:
        ; simple repeated-subtraction divide: tmp6 / tmp7 -> numVal (0..4)
        a16
        lda tmp6
        a8
        stz numVal
@divlp: a16
        lda tmp6
        cmp tmp7
        bcc @divdone
        sec
        sbc tmp7
        sta tmp6
        a8
        inc numVal
        lda numVal
        cmp #4
        bcs @divdone
        bra @divlp
@divdone:
        a8
@segReady:
        ; color: green if HP > 25% of max, else red. Dead (HP=0) shows all empty.
        a16
        lda f:party+PT_HP,x
        a8
        beq @deadBar
        ; low-hp threshold: HP*4 < MAXHP -> under 25%
        a16
        lda tmp5
        asl
        asl
        cmp tmp7
        a8
        bcs @barGreen
        lda #5                  ; red
        bra @barCol
@barGreen:
        lda #4                  ; green
@barCol: sta tmp1                ; tmp1 = fill palette
        bra @drawBar
@deadBar:
        lda #5
        sta tmp1
@drawBar:
        lda #28
        sta textX
        lda tmp4
        sta textY
        ldy #0
@barlp: cpy numVal
        bcs @barEmpty
        lda tmp1
        sta textPal
        lda #TILE_BARFULL
        bra @barPut
@barEmpty:
        lda #2                  ; dim gray palette for empty segment
        sta textPal
        lda #TILE_BAREMPTY
@barPut:
        jsr TextPutTile
        inc textX
        iny
        cpy #4
        bne @barlp
        plx
@next:  a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp3
        lda tmp3
        cmp #5
        bcs @done
        jmp @hero
@done:  rts
.endproc

; command menu cursor
.proc drawMenuCursor
        .a8
        .i16
        stz tmp0                ; row idx
@lp:    lda tmp0
        asl
        clc
        adc #20
        sta textY
        lda #1
        sta textX
        lda #0
        sta textPal
        lda tmp0
        cmp menuSel
        beq @cur
        lda #TILE_OSPACE
        bra @put
@cur:   lda #TILE_CURSOR
@put:   jsr TextPutTile
        inc tmp0
        lda tmp0
        cmp #4
        bne @lp
        rts
.endproc

; draw all battle sprites
.proc drawSprites
        .a8
        .i16
        jsr OamReset
        ; enemies
        stz tmp0                ; slot
        ldx #0
@en:    lda f:bEnemyAlive,x
        beq @nexte
        ; blink hide?
        lda tmp0
        a16
        and #$00FF
        tay
        a8
        lda a:bitTab,y
        and hideMask
        bne @nexte
        lda f:bEnemySpr,x
        bmi @bossSpr
        lda a:enemyXTab,y
        sta sprX
        lda a:enemyYTab,y
        sta sprY
        lda f:bEnemySpr,x
        asl
        asl
        clc
        adc #64
        sta sprTile
        ; attr = prio2 | (1+palSlot)<<1
        lda f:bEnemyPal,x
        inc
        asl
        ora #$20
        sta sprAttr
        lda #1
        sta sprSize
        phx
        jsr OamPush
        plx
        bra @nexte
@bossSpr:
        phx
        lda #1
        sta sprSize
        ldx #0
@bq:    lda a:bossQX,x
        sta sprX
        lda a:bossQY,x
        sta sprY
        lda a:bossQT,x
        sta sprTile
        lda #$28                ; pal 4, prio 2
        sta sprAttr
        phx
        jsr OamPush
        plx
        inx
        cpx #4
        bne @bq
        plx
@nexte: inx
        inc tmp0
        lda tmp0
        cmp #3
        bne @en
        ; heroes
        stz tmp0
        ldx #0
@he:    lda f:party+PT_FLAGS,x
        and #$01
        beq @nexth
        a16
        lda f:party+PT_HP,x
        a8
        beq @nexth
        lda #180
        ; lunge offset for acting hero
        pha
        lda tmp0
        cmp actHero
        bne @nofx
        pla
        sec
        sbc heroFxOff
        pha
@nofx:  pla
        sta sprX
        lda tmp0
        a16
        and #$00FF
        tay
        a8
        lda a:heroYTab,y
        sta sprY
        lda #8                  ; left-facing frame
        sta sprTile
        lda #$20
        sta sprAttr
        stz sprSize
        phx
        jsr OamPush
        plx
@nexth: a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp0
        lda tmp0
        cmp #5
        bne @he
        jsr OamFinish
        rts
bitTab:   .byte 1, 2, 4
heroYTab: .byte 44, 70, 96, 122, 148
bossQX:   .byte 24, 56, 24, 56
bossQY:   .byte 48, 48, 80, 80
bossQT:   .byte 128, 132, 192, 196
.endproc

; full text redraw (clears floating numbers / submenus)
.proc redrawBase
        .a8
        .i16
        jsr TextClear
        jsr drawHud
        rts
.endproc

; ===========================================================================
; turn order
; ===========================================================================
.segment "BSS"
bSpd: .res 8
.segment "CODE"

.proc buildTurnOrder
        .a8
        .i16
        stz bTurnCount
        stz bTurnPos
        ; heroes
        stz tmp0
        ldx #0
@he:    lda f:party+PT_FLAGS,x
        and #$01
        beq @nexth
        a16
        lda f:party+PT_HP,x
        a8
        beq @nexth
        lda tmp0
        jsr pushActor
@nexth: a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp0
        lda tmp0
        cmp #5
        bne @he
        ; enemies
        ldx #0
@en:    lda f:bEnemyAlive,x
        beq @nexte
        a16
        txa
        clc
        adc #5
        a8
        jsr pushActor
@nexte: inx
        cpx #3
        bne @en
        ; selection sort by bSpd desc
        stz tmp0                ; i
@sort:  lda tmp0
        inc
        cmp bTurnCount
        bcs @done
        sta tmp1                ; j = i+1
@inner: ; if bSpd[j] > bSpd[i] swap both arrays
        a16
        lda #0
        a8
        lda tmp0
        a16
        and #$00FF
        tax
        a8
        lda tmp1
        a16
        and #$00FF
        tay
        a8
        lda a:bSpd,y
        cmp a:bSpd,x
        bcc @noswap
        beq @noswap
        ; swap
        pha
        lda a:bSpd,x
        sta a:bSpd,y
        pla
        sta a:bSpd,x
        lda a:bTurnList,x
        pha
        lda a:bTurnList,y
        sta a:bTurnList,x
        pla
        sta a:bTurnList,y
@noswap:
        inc tmp1
        lda tmp1
        cmp bTurnCount
        bcc @inner
        inc tmp0
        bra @sort
@done:  rts
.endproc

; push actor id A with its speed into turn arrays
.proc pushActor
        .a8
        .i16
        pha
        a16
        lda #0
        a8
        lda bTurnCount
        a16
        and #$00FF
        tay
        a8
        pla
        sta a:bTurnList,y
        pha
        cmp #5
        bcc @hero
        ; enemy speed: EnemyTab[bEnemyId[slot]].spd (+15)
        sec
        sbc #5
        a16
        and #$00FF
        tax
        a8
        phy
        jsr enemyDefY
        a8
        lda a:15,y
        ply
        bra @have
@hero:  ; hero speed: party[i*32].spd
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        a8
        lda f:party+PT_SPD,x
@have:  sta a:bSpd,y
        pla
        inc bTurnCount
        rts
.endproc

; ===========================================================================
; frame dispatch
; ===========================================================================
.proc BattleFrame
        .a8
        .i16
        lda battlePhase
        cmp #BP_INTRO
        bne :+
        jmp phIntro
:       cmp #BP_NEXT
        bne :+
        jmp phNext
:       cmp #BP_MENU
        bne :+
        jmp phMenu
:       cmp #BP_SUB
        bne :+
        jmp phSub
:       cmp #BP_TARGET
        bne :+
        jmp phTarget
:       cmp #BP_RUNOK
        bne :+
        jmp phRunOk
:       rts
.endproc

.proc phIntro
        .a8
        .i16
        jsr drawSprites
        jsr TextFlush
        lda bTimer
        beq @go
        dec bTimer
        rts
@go:    jsr buildTurnOrder
        lda #BP_NEXT
        sta battlePhase
        rts
.endproc

.proc phNext
        .a8
        .i16
        jsr drawSprites
        lda bTimer
        beq :+
        dec bTimer
        rts
:       lda bTurnPos
        cmp bTurnCount
        bcc @have
        jsr buildTurnOrder
        inc bRound
@have:  a16
        lda #0
        a8
        lda bTurnPos
        a16
        and #$00FF
        tay
        a8
        inc bTurnPos
        lda a:bTurnList,y
        cmp #5
        bcs @enemy
        ; hero turn: still alive?
        sta actHero
        jsr heroOff
        ldx actHeroOff
        a16
        lda f:party+PT_HP,x
        a8
        beq phNext              ; dead: skip (tail-call loop)
        ; open command menu
        jsr redrawBase
        jsr msgWindow
        jsr printHeroNameMsg
        stz menuSel
        jsr drawMenuCursor
        jsr TextFlush
        lda #BP_MENU
        sta battlePhase
        rts
@enemy: sec
        sbc #5
        a16
        and #$00FF
        tax
        a8
        lda f:bEnemyAlive,x
        beq @skip
        jsr enemyAct
        jsr checkLose
        bcs @out
        lda #8
        sta bTimer
@skip:
@out:   rts
.endproc

; print current hero's name into msg row
.proc printHeroNameMsg
        .a8
        .i16
        lda #0
        sta textPal
        lda #1
        sta textX
        lda #1
        sta textY
        a16
        lda #0
        a8
        lda actHero
        a16
        sta tmp5
        asl
        asl
        clc
        adc tmp5
        clc
        adc tmp5                ; *6
        clc
        adc #.loword(HeroNames)
        sta textPtr
        a8
        lda #^HeroNames
        sta textPtr+2
        jsr TextPut
        rts
.endproc

.proc phMenu
        .a8
        .i16
        jsr drawSprites
        a16
        lda joyPressed
        bit #JOY_UP
        a8
        beq :+
        lda menuSel
        dec
        and #$03
        sta menuSel
        lda #0
        jsr PlaySfx
:       a16
        lda joyPressed
        bit #JOY_DOWN
        a8
        beq :+
        lda menuSel
        inc
        and #$03
        sta menuSel
        lda #0
        jsr PlaySfx
:       jsr drawMenuCursor
        jsr TextFlush
        ; B = run attempt
        a16
        lda joyPressed
        bit #JOY_B
        a8
        bne :+
        jmp @noRun
:       lda bForceForm
        cmp #$FF
        beq :+
        jmp @noEscape
:       jsr Rand8
        cmp #128
        bcc @flee
        jsr msgWindow
        PUTS 1, 1, 5, strNoEscape
        jsr TextFlush
        lda #30
        sta bTimer
        lda #BP_NEXT
        sta battlePhase
        rts
@noEscape:
        jsr msgWindow
        PUTS 1, 1, 5, strNoEscape
        jsr TextFlush
        lda #30
        sta bTimer
        lda #BP_NEXT
        sta battlePhase
        rts
@flee:  jsr msgWindow
        PUTS 1, 1, 0, strGotAway
        jsr TextFlush
        lda #40
        sta bTimer
        lda #BP_RUNOK
        sta battlePhase
        rts
@noRun: a16
        lda joyPressed
        bit #(JOY_A|JOY_START)
        a8
        bne :+
        jmp @out
:       lda menuSel
        bne :+
        jmp @attack
:       cmp #1
        beq @tech
        cmp #2
        beq @magic
        ; items
        jsr buildItemList
        lda subCount
        bne @haveList
        jsr msgWindow
        PUTS 1, 1, 5, strNothing
        jsr TextFlush
        rts
@tech:  lda #1
        sta subKind
        jsr buildSkillList
        lda subCount
        bne @haveList
        jsr msgWindow
        PUTS 1, 1, 5, strNoMagic
        jsr TextFlush
        rts
@magic: lda #2
        sta subKind
        jsr buildSkillList
        lda subCount
        bne @haveList
        jsr msgWindow
        PUTS 1, 1, 5, strNoMagic
        jsr TextFlush
        rts
@haveList:
        stz subSel
        jsr drawSubWindow
        lda #BP_SUB
        sta battlePhase
        rts
@attack:
        stz actKind
        jsr buildEnemyTargets
        lda tgtCount
        beq @out
        stz tgtSel
        lda #BP_TARGET
        sta battlePhase
@out:   rts
.endproc

; ===========================================================================
; sub-menu (tech/magic/item lists)
; ===========================================================================

; build bSubIds from hero's tech (subKind=1) or magic (subKind=2) list
.proc buildSkillList
        .a8
        .i16
        stz subCount
        ; list ptr table
        a16
        lda #0
        a8
        lda actHero
        a16
        and #$00FF
        asl
        tax
        lda subKind
        and #$0001
        bne @tech
        lda f:HeroMagicLists,x
        bra @have
@tech:  lda f:HeroTechLists,x
@have:  sta ptrScr
        a8
        lda #^HeroTechLists
        sta ptrScr+2
        ; count
        lda [ptrScr]
        sta tmp6                ; total entries
        beq @done
        ldx actHeroOff
        lda f:party+PT_LVL,x
        sta tmp5                ; hero level
        ldy #1
@lp:    lda [ptrScr],y          ; skillId
        pha
        iny
        lda [ptrScr],y          ; unlock level
        iny
        cmp tmp5
        beq @ok
        bcc @ok
        pla
        bra @next
@ok:    pla
        sta tmp4
        a16
        lda #0
        a8
        lda subCount
        a16
        and #$00FF
        tax
        a8
        lda tmp4
        sta a:bSubIds,x
        inc subCount
@next:  dec tmp6
        bne @lp
@done:  rts
.endproc

; build item list: ids with count>0
.proc buildItemList
        .a8
        .i16
        lda #3
        sta subKind
        stz subCount
        stz tmp5                ; item id
@lp:    a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tax
        a8
        lda f:invCount,x
        beq @next
        lda subCount
        a16
        and #$00FF
        tay
        a8
        lda tmp5
        sta a:bSubIds,y
        inc subCount
@next:  inc tmp5
        lda tmp5
        cmp #5                  ; ITEM_COUNT
        bne @lp
        rts
.endproc

; sub window with entries + cursor
.proc drawSubWindow
        .a8
        .i16
        lda #1
        sta textPal
        lda #0
        sta textX
        lda #4
        sta textY
        lda #17
        ldx #12
        jsr DrawWindow
        stz tmp3                ; entry idx
@lp:    lda tmp3
        cmp subCount
        bcc :+
        jmp @cur
:
        ; row = 5 + i*2
        lda tmp3
        asl
        clc
        adc #5
        sta textY
        sta tmp4
        lda #3
        sta textX
        lda #0
        sta textPal
        ; entry id
        a16
        lda #0
        a8
        lda tmp3
        a16
        and #$00FF
        tay
        a8
        lda a:bSubIds,y
        pha
        lda subKind
        cmp #3
        beq @item
        ; skill: name at SkillTab+id*16
        pla
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        clc
        adc #.loword(SkillTab)
        sta textPtr
        pha
        a8
        lda #^SkillTab
        sta textPtr+2
        jsr TextPut
        ; mp cost right side
        a16
        pla
        clc
        adc #10                 ; +10 = mpCost
        tay
        lda #0
        a8
        lda a:0,y
        a16
        and #$00FF
        sta numVal
        a8
        lda #14
        sta textX
        lda tmp4
        sta textY
        jsr PrintNumL
        bra @nx
@item:  ; item: name at ItemTab+id*16, count right
        pla
        pha
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        clc
        adc #.loword(ItemTab)
        sta textPtr
        a8
        lda #^ItemTab
        sta textPtr+2
        jsr TextPut
        pla
        a16
        and #$00FF
        tax
        lda #0
        a8
        lda f:invCount,x
        a16
        and #$00FF
        sta numVal
        a8
        lda #14
        sta textX
        lda tmp4
        sta textY
        jsr PrintNumL
@nx:    inc tmp3
        jmp @lp
        ; cursor
@cur:   stz tmp3
@clp:   lda tmp3
        cmp subCount
        bcs @done
        lda tmp3
        asl
        clc
        adc #5
        sta textY
        lda #1
        sta textX
        lda #0
        sta textPal
        lda tmp3
        cmp subSel
        beq @hand
        lda #TILE_OSPACE
        bra @put
@hand:  lda #TILE_CURSOR
@put:   jsr TextPutTile
        inc tmp3
        bra @clp
@done:  jsr TextFlush
        rts
.endproc

.proc phSub
        .a8
        .i16
        jsr drawSprites
        a16
        lda joyPressed
        bit #JOY_UP
        a8
        beq :+
        lda subSel
        bne @up
        lda subCount
@up:    dec
        sta subSel
:       a16
        lda joyPressed
        bit #JOY_DOWN
        a8
        beq :+
        lda subSel
        inc
        cmp subCount
        bcc @dn
        lda #0
@dn:    sta subSel
:       jsr drawSubWindow
        ; B: back to menu
        a16
        lda joyPressed
        bit #JOY_B
        a8
        beq @noB
        jmp backToMenu
@noB:   a16
        lda joyPressed
        bit #(JOY_A|JOY_START)
        a8
        bne :+
        jmp @out
:       ; entry id
        a16
        lda #0
        a8
        lda subSel
        a16
        and #$00FF
        tay
        a8
        lda a:bSubIds,y
        sta actId
        lda subKind
        cmp #3
        beq @useItem
        ; skill: check mp
        lda #1
        sta actKind
        jsr skillY              ; Y = SkillTab + actId*16
        a8
        lda a:10,y              ; cost
        a16
        and #$00FF
        sta tmp0
        ldx actHeroOff
        lda f:party+PT_MP,x
        cmp tmp0
        a8
        bcs @mpOk
        jsr msgWindow
        PUTS 1, 1, 5, strNoMp
        jsr TextFlush
        rts
@mpOk:  ; targeting from flags
        jsr skillY
        a8
        lda a:12,y              ; flags
        and #SK_ALLY
        bne @ally
        jsr buildEnemyTargets
        bra @tsel
@ally:  stz tmp6                ; alive allies
        jsr buildAllyTargets
@tsel:  lda tgtCount
        beq @out
        stz tgtSel
        ; all-target skills skip selection
        jsr skillY
        a8
        lda a:12,y
        and #SK_ALL
        beq @single
        jsr executeAction
        rts
@single:
        lda #BP_TARGET
        sta battlePhase
@out:   rts
@useItem:
        lda #2
        sta actKind
        ; revive items target dead allies
        jsr itemY               ; Y = ItemTab + actId*16
        a8
        lda a:10,y              ; type
        cmp #2
        bne @alive
        lda #1
        sta tmp6
        jsr buildAllyTargets
        bra @isel
@alive: stz tmp6
        jsr buildAllyTargets
@isel:  lda tgtCount
        bne @isok
        jsr msgWindow
        PUTS 1, 1, 5, strNothing
        jsr TextFlush
        rts
@isok:  stz tgtSel
        lda #BP_TARGET
        sta battlePhase
        rts
.endproc

; Y = SkillTab + actId*16. Exits a8 (Y set in 16-bit mode).
.proc skillY
        .a8
        .i16
        a16
        lda #0
        a8
        lda actId
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        clc
        adc #.loword(SkillTab)
        tay
        a8
        rts
.endproc

.proc itemY
        .a8
        .i16
        a16
        lda #0
        a8
        lda actId
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        clc
        adc #.loword(ItemTab)
        tay
        a8
        rts
.endproc

.proc backToMenu
        .a8
        .i16
        jsr redrawBase
        jsr msgWindow
        jsr printHeroNameMsg
        jsr drawMenuCursor
        jsr TextFlush
        lda #BP_MENU
        sta battlePhase
        rts
.endproc

; ===========================================================================
; target selection
; ===========================================================================
.proc buildEnemyTargets
        .a8
        .i16
        stz tgtCount
        stz tgtAlly
        ldx #0
@lp:    lda f:bEnemyAlive,x
        beq @next
        phx
        a16
        lda #0
        a8
        lda tgtCount
        a16
        and #$00FF
        tay
        txa                     ; A(16) = slot
        a8
        sta a:bTgtIds,y
        inc tgtCount
        plx
@next:  inx
        cpx #3
        bne @lp
        rts
.endproc

; tmp6: 0 = alive allies, 1 = dead allies
.proc buildAllyTargets
        .a8
        .i16
        stz tgtCount
        lda #1
        sta tgtAlly
        stz tmp5                ; hero idx
        ldx #0
@lp:    lda f:party+PT_FLAGS,x
        and #$01
        beq @next
        a16
        lda f:party+PT_HP,x
        a8
        beq @dead
        ; alive
        lda tmp6
        bne @next
        bra @add
@dead:  lda tmp6
        beq @next
@add:   phx
        a16
        lda #0
        a8
        lda tgtCount
        a16
        and #$00FF
        tay
        a8
        lda tmp5
        sta a:bTgtIds,y
        inc tgtCount
        plx
@next:  a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp5
        lda tmp5
        cmp #5
        bne @lp
        rts
.endproc

.proc phTarget
        .a8
        .i16
        ; move cursor
        a16
        lda joyPressed
        bit #(JOY_UP|JOY_LEFT)
        a8
        beq :+
        lda tgtSel
        bne @dec
        lda tgtCount
@dec:   dec
        sta tgtSel
:       a16
        lda joyPressed
        bit #(JOY_DOWN|JOY_RIGHT)
        a8
        beq :+
        lda tgtSel
        inc
        cmp tgtCount
        bcc @inc
        lda #0
@inc:   sta tgtSel
:
        ; blink target
        lda tgtAlly
        bne @allyCur
        ; enemy: blink sprite
        lda frameCount
        and #$04
        beq @clr
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        a16
        and #$00FF
        tay
        a8
        lda a:blinkTab,y
        sta hideMask
        bra @dr
@clr:   stz hideMask
        bra @dr
@allyCur:
        ; hand cursor beside HUD name
        stz tmp3
@hcur:  lda tmp3
        clc
        adc #20
        sta textY
        lda #10
        sta textX
        lda #0
        sta textPal
        ; is this row the selected ally?
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        cmp tmp3
        beq @hHand
        lda #TILE_OSPACE
        bra @hPut
@hHand: lda #TILE_CURSOR
@hPut:  jsr TextPutTile
        inc tmp3
        lda tmp3
        cmp #5
        bne @hcur
        jsr TextFlush
@dr:    jsr drawSprites
        ; B: cancel
        a16
        lda joyPressed
        bit #JOY_B
        a8
        beq @noB
        stz hideMask
        jmp backToMenu
@noB:   a16
        lda joyPressed
        bit #(JOY_A|JOY_START)
        a8
        beq @out
        stz hideMask
        jsr executeAction
@out:   rts
blinkTab: .byte 1, 2, 4
.endproc

; ===========================================================================
; action execution (blocking: runs its own frames)
; ===========================================================================
.segment "BSS"
bActSlot: .res 1                ; acting enemy slot
bVictim:  .res 1                ; enemy attack target (hero index)
bAmount:  .res 2                ; damage/heal amount scratch
.segment "CODE"

; short blocking delay with sprite redraw: A = frames
.proc animWait
        .a8
        .i16
        sta tmp3
@lp:    jsr drawSprites
        jsr WaitVBlank
        dec tmp3
        bne @lp
        rts
.endproc

; wait for A/START press (blocking)
.proc waitA
        .a8
        .i16
@lp:    jsr drawSprites
        jsr WaitVBlank
        a16
        lda joyPressed
        bit #(JOY_A|JOY_START)
        a8
        beq @lp
        rts
.endproc

; hero lunge animation
.proc lungeAnim
        .a8
        .i16
        ldx #0
@lp:    lda a:lungeTab,x
        sta heroFxOff
        phx
        lda #3
        jsr animWait
        plx
        inx
        cpx #4
        bne @lp
        stz heroFxOff
        rts
lungeTab: .byte 4, 8, 8, 2
.endproc

; ---------------------------------------------------------------------------
; deal bAmount damage to enemy slot (tmp5 = slot). Prints number, handles death.
.proc dmgToEnemy
        .a8
        .i16
        ; hp -= amount
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        asl
        tax
        lda f:bEnemyHp,x
        sec
        sbc bAmount
        beq @dead
        bcc @dead
        sta f:bEnemyHp,x
        a8
        bra @num
@dead:  lda #0
        sta f:bEnemyHp,x
        a8
        ; mark dead + pool rewards
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tax
        a8
        lda #0
        sta f:bEnemyAlive,x
        jsr enemyDefY
        a8
        a16
        lda a:16,y              ; xp
        clc
        adc f:bXpPool
        sta f:bXpPool
        lda a:18,y              ; gems
        clc
        adc f:bGemPool
        sta f:bGemPool
        a8
@num:   lda #3
        jsr PlaySfx
        ; print damage number at enemy position
        a16
        lda bAmount
        sta numVal
        a8
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tay
        a8
        lda a:eNumCol,y
        sta textX
        lda a:eNumRow,y
        sta textY
        lda #0
        sta textPal
        stz textOpq
        jsr PrintNumL
        lda #128
        sta textOpq
        jsr TextFlush
        rts
eNumCol: .byte 5, 8, 5
eNumRow: .byte 5, 10, 15
.endproc

; ---------------------------------------------------------------------------
; deal bAmount damage to hero (tmp5 = hero idx). Prints red number.
.proc dmgToHero
        .a8
        .i16
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        lda f:party+PT_HP,x
        sec
        sbc bAmount
        beq @dead
        bcc @dead
        sta f:party+PT_HP,x
        bra @num
@dead:  lda #0
        sta f:party+PT_HP,x
@num:   a8
        a16
        lda bAmount
        sta numVal
        a8
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tay
        a8
        lda a:hNumRow,y
        sta textY
        lda #22
        sta textX
        lda #5
        sta textPal
        stz textOpq
        jsr PrintNumL
        lda #128
        sta textOpq
        jsr TextFlush
        rts
hNumRow: .byte 5, 8, 12, 15, 18
.endproc

; heal hero (tmp5 = idx) by bAmount, capped at max. Green number.
.proc healHero
        .a8
        .i16
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        lda f:party+PT_HP,x
        clc
        adc bAmount
        cmp f:party+PT_MAXHP,x
        bcc @ok
        lda f:party+PT_MAXHP,x
@ok:    sta f:party+PT_HP,x
        lda bAmount
        sta numVal
        a8
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tay
        a8
        lda a:dmgToHero::hNumRow,y
        sta textY
        lda #22
        sta textX
        lda #4
        sta textPal
        stz textOpq
        jsr PrintNumL
        lda #128
        sta textOpq
        jsr TextFlush
        rts
.endproc

; ---------------------------------------------------------------------------
; hero attack/skill/item dispatcher. Blocking.
.proc executeAction
        .a8
        .i16
        jsr redrawBase
        jsr msgWindow
        jsr printHeroNameMsg
        jsr TextFlush
        jsr lungeAnim
        ldx actHeroOff
        lda actKind
        beq @attack
        cmp #1
        bne :+
        jmp doSkill
:       jmp doItem
@attack:
        ; damage = atk*2 + rnd&7 - enemyDef
        a16
        lda #0
        a8
        lda f:party+PT_ATK,x
        a16
        and #$00FF
        asl
        sta bAmount
        a8
        jsr Rand8
        and #$07
        a16
        and #$00FF
        clc
        adc bAmount
        sta bAmount
        a8
        ; enemy def
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5                ; target slot
        a16
        and #$00FF
        tax
        a8
        jsr enemyDefY
        a8
        a16
        lda #0
        a8
        lda a:13,y              ; def
        a16
        and #$00FF
        sta tmp0
        lda bAmount
        sec
        sbc tmp0
        bpl :+
        lda #1
:       bne :+
        lda #1
:       sta bAmount
        a8
        jsr dmgToEnemy
        lda #30
        jsr animWait
        jmp finishAction
.endproc

; ---------------------------------------------------------------------------
.proc doSkill
        .a8
        .i16
        ; deduct mp
        jsr skillY
        a8
        a16
        lda #0
        a8
        lda a:10,y
        a16
        and #$00FF
        sta tmp0
        ldx actHeroOff
        lda f:party+PT_MP,x
        sec
        sbc tmp0
        sta f:party+PT_MP,x
        a8
        ; base amount = power + (mag*2 if SK_MAG else atk) + rnd&15
        jsr skillY
        a8
        lda a:12,y
        sta tmp1                ; flags
        ; magic-cast SFX cue: play the shimmer arpeggio whenever this
        ; skill uses the SK_MAG formula, so Magic actions have a
        ; distinct audible identity from plain Tech attacks.
        lda tmp1
        and #SK_MAG
        beq :+
        lda #8
        jsr PlaySfx
:
        a16
        lda #0
        a8
        lda a:11,y              ; power
        a16
        and #$00FF
        sta bAmount
        a8
        ldx actHeroOff
        lda tmp1
        and #SK_MAG|SK_HEAL
        beq @useAtk
        a16
        lda #0
        a8
        lda f:party+PT_MAG,x
        a16
        and #$00FF
        asl
        clc
        adc bAmount
        sta bAmount
        a8
        bra @rnd
@useAtk:
        a16
        lda #0
        a8
        lda f:party+PT_ATK,x
        a16
        and #$00FF
        clc
        adc bAmount
        sta bAmount
        a8
@rnd:   jsr Rand8
        and #$0F
        a16
        and #$00FF
        clc
        adc bAmount
        sta bAmount
        a8
        ; heal or damage?
        lda tmp1
        and #SK_HEAL
        beq :+
        jmp @heal
:
        ; --- damage: single or all ---
        lda tmp1
        and #SK_ALL
        bne @dmgAll
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5
        jsr applyEnemyDef
        jsr dmgToEnemy
        lda #30
        jsr animWait
        jmp finishAction
@dmgAll:
        a16
        lda bAmount
        sta tmp2                ; keep base
        a8
        stz tmp4                ; idx
@dal:   lda tmp4
        cmp tgtCount
        bcs @dald
        a16
        lda #0
        a8
        lda tmp4
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5
        ; skip if already dead (killed earlier this action)
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tax
        a8
        lda f:bEnemyAlive,x
        beq @daln
        a16
        lda tmp2
        sta bAmount
        a8
        jsr applyEnemyDef
        jsr dmgToEnemy
@daln:  inc tmp4
        bra @dal
@dald:  lda #30
        jsr animWait
        jmp finishAction
@heal:  lda tmp1
        and #SK_ALL
        bne @healAll
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5
        jsr healHero
        lda #30
        jsr animWait
        jmp finishAction
@healAll:
        a16
        lda bAmount
        sta tmp2
        a8
        stz tmp4
@hal:   lda tmp4
        cmp tgtCount
        bcs @hald
        a16
        lda #0
        a8
        lda tmp4
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5
        a16
        lda tmp2
        sta bAmount
        a8
        jsr healHero
        inc tmp4
        bra @hal
@hald:  lda #30
        jsr animWait
        jmp finishAction
.endproc

; subtract target enemy's def from bAmount (tmp5 = slot), min 1
.proc applyEnemyDef
        .a8
        .i16
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tax
        a8
        jsr enemyDefY
        a8
        a16
        lda #0
        a8
        lda a:13,y
        a16
        and #$00FF
        sta tmp0
        lda bAmount
        sec
        sbc tmp0
        bpl :+
        lda #1
:       bne :+
        lda #1
:       sta bAmount
        a8
        rts
.endproc

; ---------------------------------------------------------------------------
.proc doItem
        .a8
        .i16
        ; consume
        a16
        lda #0
        a8
        lda actId
        a16
        and #$00FF
        tax
        a8
        lda f:invCount,x
        dec
        sta f:invCount,x
        ; target hero
        a16
        lda #0
        a8
        lda tgtSel
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta tmp5
        ; hero offset
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        a8
        ; item type
        jsr itemY
        a8
        lda a:10,y
        beq @hp
        cmp #1
        beq @mp
        cmp #2
        beq @revive
        ; full restore
        a16
        lda f:party+PT_MAXHP,x
        sta f:party+PT_HP,x
        sta bAmount
        lda f:party+PT_MAXMP,x
        sta f:party+PT_MP,x
        a8
        jsr healNum
        bra @done
@hp:    a16
        lda a:12,y              ; power
        sta bAmount
        a8
        jsr healHero
        bra @done
@mp:    a16
        lda a:12,y
        sta tmp0
        lda f:party+PT_MP,x
        clc
        adc tmp0
        cmp f:party+PT_MAXMP,x
        bcc :+
        lda f:party+PT_MAXMP,x
:       sta f:party+PT_MP,x
        lda tmp0
        sta bAmount
        a8
        jsr healNum
        bra @done
@revive:
        a16
        lda f:party+PT_MAXHP,x
        lsr
        sta f:party+PT_HP,x
        sta bAmount
        a8
        jsr healNum
@done:  lda #30
        jsr animWait
        jmp finishAction
.endproc

; print green number at target hero (tmp5) without hp change
.proc healNum
        .a8
        .i16
        a16
        lda bAmount
        sta numVal
        a8
        a16
        lda #0
        a8
        lda tmp5
        a16
        and #$00FF
        tay
        a8
        lda a:dmgToHero::hNumRow,y
        sta textY
        lda #22
        sta textX
        lda #4
        sta textPal
        stz textOpq
        jsr PrintNumL
        lda #128
        sta textOpq
        jsr TextFlush
        rts
.endproc

; ---------------------------------------------------------------------------
; common ending for hero actions: redraw, win check, next turn
.proc finishAction
        .a8
        .i16
        jsr redrawBase
        jsr TextFlush
        jsr checkWin
        bcs @out
        lda #6
        sta bTimer
        lda #BP_NEXT
        sta battlePhase
@out:   rts
.endproc

; ===========================================================================
; enemy turn (X = slot). Blocking.
; ===========================================================================
.proc enemyAct
        .a8
        .i16
        phx
        ; boss special check: aiType (+21) nonzero
        jsr enemyDefY
        a8
        lda a:21,y
        beq @normalEntry
        inc bActCnt
        cmp #2
        beq @ai2
        ; aiType 1: special every 3rd action
        lda bActCnt
        cmp #3
        bcc @normalEntry
        stz bActCnt
        plx
        phx
        jmp bossSpecial
@ai2:   ; aiType 2: special every 2nd action
        lda bActCnt
        and #$01
        bne @normalEntry
        plx
        phx
        jmp bossSpecial
@normalEntry:
        plx
        phx
        ; message: enemy name
        jsr msgWindow
        lda #0
        sta textPal
        lda #1
        sta textX
        lda #1
        sta textY
        plx
        phx
        jsr enemyDefY
        a8
        a16
        tya
        sta textPtr
        a8
        lda #^EnemyTab
        sta textPtr+2
        jsr TextPut
        jsr TextFlush
        ; attacker blink
        plx
        phx
        a16
        txa
        and #$00FF
        tay
        a8
        lda a:blinkTab2,y
        sta hideMask
        lda #6
        jsr animWait
        stz hideMask
        lda #6
        jsr animWait
        ; pick random living hero
        stz tmp6
        jsr buildAllyTargets
        lda tgtCount
        bne :+
        jmp @none
:       sta tmp7
        jsr randMod             ; A = index
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta f:bVictim           ; victim hero idx (tmp5 is clobbered below)
        ; damage = eatk*2 + rnd&7 - heroDef
        plx
        phx
        jsr enemyDefY
        a8
        a16
        lda #0
        a8
        lda a:12,y              ; atk
        a16
        and #$00FF
        asl
        sta bAmount
        a8
        jsr Rand8
        and #$07
        a16
        and #$00FF
        clc
        adc bAmount
        sta bAmount
        a8
        ; hero def
        a16
        lda #0
        a8
        lda f:bVictim
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        lda #0
        a8
        lda f:party+PT_DEF,x
        a16
        and #$00FF
        sta tmp0
        lda bAmount
        sec
        sbc tmp0
        bpl :+
        lda #1
:       bne :+
        lda #1
:       sta bAmount
        a8
        lda f:bVictim
        sta tmp5
        jsr dmgToHero
        jsr drawHud
        jsr TextFlush
        lda #30
        jsr animWait
@none:  plx
        jsr redrawBase
        jsr TextFlush
        rts
blinkTab2: .byte 1, 2, 4
.endproc

; ---------------------------------------------------------------------------
; Boss special: hits every living hero for atk*3/2 - def. X = slot (pushed
; once by enemyAct; we mirror its stack behavior and return via enemyAct's
; epilogue equivalent).
.proc bossSpecial
        .a8
        .i16
        ; message: name + "unleashes fury!"
        jsr msgWindow
        lda #0
        sta textPal
        lda #1
        sta textX
        lda #1
        sta textY
        plx
        phx
        jsr enemyDefY
        a8
        a16
        tya
        sta textPtr
        a8
        lda #^EnemyTab
        sta textPtr+2
        jsr TextPut
        PUTS 1, 2, 5, strFury
        jsr TextFlush
        ; attacker blink
        plx
        phx
        a16
        txa
        and #$00FF
        tay
        a8
        lda a:blinkTab3,y
        sta hideMask
        lda #8
        jsr animWait
        stz hideMask
        lda #8
        jsr animWait
        ; base = atk + atk/2 + rnd&7
        plx
        phx
        jsr enemyDefY
        a8
        a16
        lda #0
        a8
        lda a:12,y
        a16
        and #$00FF
        sta tmp0
        lsr
        clc
        adc tmp0
        sta tmp0                ; atk*1.5
        a8
        jsr Rand8
        and #$07
        a16
        and #$00FF
        clc
        adc tmp0
        sta tmp0
        a8
        ; targets: all living heroes
        stz tmp6
        jsr buildAllyTargets
        stz tmp4                ; idx
@lp:    lda tmp4
        cmp tgtCount
        bcs @done
        a16
        lda #0
        a8
        lda tmp4
        a16
        and #$00FF
        tay
        a8
        lda a:bTgtIds,y
        sta f:bVictim
        ; per-target def
        a16
        lda #0
        a8
        lda f:bVictim
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        lda #0
        a8
        lda f:party+PT_DEF,x
        a16
        and #$00FF
        sta tmp1
        lda tmp0
        sec
        sbc tmp1
        bpl :+
        lda #1
:       bne :+
        lda #1
:       sta bAmount
        a8
        lda f:bVictim
        sta tmp5
        jsr dmgToHero
        inc tmp4
        jmp @lp
@done:  jsr drawHud
        jsr TextFlush
        lda #35
        jsr animWait
        plx
        jsr redrawBase
        jsr TextFlush
        rts
blinkTab3: .byte 1, 2, 4
.endproc

; ===========================================================================
; win / lose / exit
; ===========================================================================

; carry set if battle ended in victory
.proc checkWin
        .a8
        .i16
        lda f:bEnemyAlive
        ora f:bEnemyAlive+1
        ora f:bEnemyAlive+2
        beq @win
        clc
        rts
@win:   jsr victory
        sec
        rts
.endproc

; carry set if party wiped
.proc checkLose
        .a8
        .i16
        jsr PartyAliveMask
        beq @lose
        clc
        rts
@lose:  jsr msgWindow
        PUTS 1, 1, 5, strDefeat
        jsr TextFlush
        lda #90
        jsr animWait
        lda #ST_GAMEOVER
        sta pendingState
        sec
        rts
.endproc

.proc victory
        .a8
        .i16
        lda #3
        jsr PlaySong
        jsr redrawBase
        jsr msgWindow
        PUTS 1, 1, 3, strVictory
        ; "XP gained: N   Gems: M"
        lda #0
        sta textPal
        lda #1
        sta textX
        lda #2
        sta textY
        LDPTR strGained
        jsr TextPut
        a16
        lda f:bXpPool
        sta numVal
        a8
        lda #8
        sta textX
        lda #2
        sta textY
        jsr PrintNumL
        PUTS 14, 2, 0, strXpGems
        jsr TextFlush
        ; apply rewards
        a16
        lda f:bXpPool
        sta tmp2
        a8
        jsr PartyGiveXp
        a16
        lda f:gems
        clc
        adc f:bGemPool
        sta f:gems
        a8
        jsr waitA
        ; level up messages
        stz tmp4
@lv:    lda tmp4
        cmp #5
        bcs @done
        a16
        lda #0
        a8
        lda tmp4
        a16
        and #$00FF
        tay
        a8
        lda a:bitTab5,y
        and lvlUpMask
        beq @next
        jsr msgWindow
        ; name
        lda #0
        sta textPal
        lda #1
        sta textX
        lda #1
        sta textY
        a16
        lda #0
        a8
        lda tmp4
        a16
        sta tmp0
        asl
        asl
        clc
        adc tmp0
        clc
        adc tmp0
        clc
        adc #.loword(HeroNames)
        sta textPtr
        a8
        lda #^HeroNames
        sta textPtr+2
        jsr TextPut
        PUTS 1, 2, 3, strLevelUp
        jsr drawHud
        jsr TextFlush
        jsr waitA
@next:  inc tmp4
        bra @lv
@done:  ; boss aftermath
        lda bBossFlag
        cmp #$FF
        beq @exit
        pha
        jsr SetFlag
        pla
        cmp #8                  ; WON: roll the ending
        bne @reward
        lda #$FF
        sta bBossFlag
        sta bForceForm
        stz shHDMAEN
        lda #ST_ENDING
        sta pendingState
        rts
@reward:
        lda bBossDlg
        sta pendingDlg
        lda #$FF
        sta bBossFlag
@exit:  jsr exitBattle
        rts
bitTab5: .byte 1,2,4,8,16
.endproc

.proc phRunOk
        .a8
        .i16
        jsr drawSprites
        lda bTimer
        beq @go
        dec bTimer
        rts
@go:    jsr exitBattle
        rts
.endproc

.proc exitBattle
        .a8
        .i16
        lda #$FF
        sta bForceForm
        stz shHDMAEN
        lda #1
        sta battleReturn
        lda #ST_MAP
        sta pendingState
        rts
.endproc

; ===========================================================================
; game over state
; ===========================================================================
.proc GameOverInit
        .a8
        .i16
        lda #$80
        sta INIDISP
        stz shHDMAEN
        jsr TextClear
        stz textOpq
        lda #$04                ; BG3 only
        sta TM
        PUTS 2, 12, 7, strGameOver1
        PUTS 10, 18, 2, strGameOver2
        jsr TextFlush
        lda #$0F
        sta INIDISP
        rts
.endproc

.proc GameOverFrame
        .a8
        .i16
        a16
        lda joyPressed
        bit #JOY_START
        a8
        beq @out
        lda #ST_TITLE
        sta pendingState
@out:   rts
.endproc
