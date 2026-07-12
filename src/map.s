; ---------------------------------------------------------------------------
; Overworld/dungeon map engine: loading, walking, collision, camera,
; exits/time gates, encounter accumulation.
; Maps are 32x32 metatiles (512x512 px). BG1 uses a pre-baked 64x64 tilemap
; from ROM; collision reads the metatile grid copied to WRAM.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export MapInit, MapFrame, MapLoad, FadeIn, FadeOut
.import TextInit, TextClear, TextFlush, WaitVBlank, Rand8
.import OamReset, OamPush, OamFinish
.import PlaySong, PlaySfx
.import MapTable, TsChrTable, TsChrSize, TsPalTable, TsMetaTable, TsAttrTable
.import HeroObjChr, HeroObjChrEnd, ObjPal
.import StoryTab
.import DrawWindow, TextPut
.import PartyRecruit, HeroLevelUp, party, invCount
.import PT_LVL, PT_HP, PT_MAXHP, PT_MP, PT_MAXMP, PT_FLAGS
.importzp sprX, sprY, sprTile, sprAttr, sprSize
.importzp joyHeld, joyPressed, pendingState, frameCount, nmiFlags, textOpq
.importzp textPtr, textX, textY, textPal
.importzp shBG1H, shBG1V, shHDMAEN
.importzp tmp0, tmp1, tmp2, tmp3, tmp4, tmp5

ATTR_SOLID = $01
ATTR_ENC   = $02

.segment "ZEROPAGE"
.exportzp curMap, heroX, heroY, heroDir, heroAnim, encAccum, encPend
.exportzp mapTsId, mapEncGroup, battleReturn, mapMusic
.exportzp mapMode, dlgNext, pendingDlg, bForceForm, bBossFlag, bBossDlg
mapMode:      .res 1            ; 0 walk, 1 dialog open
dlgNext:      .res 1            ; after-dialog action: 0 none, 1 battle, 2 maw
pendingDlg:   .res 1            ; dialog to show after battle return ($FF none)
bForceForm:   .res 1            ; forced boss formation ($FF none)
bBossFlag:    .res 1            ; story flag bit set on boss win ($FF none)
bBossDlg:     .res 1            ; dialog after boss win
mapMusic:     .res 1
mapTsId:      .res 1
mapEncGroup:  .res 1
battleReturn: .res 1
curMap:   .res 1
mapPtr:   .res 3                ; current map blob
attrPtr:  .res 3                ; tileset attr table
heroX:    .res 2                ; world px
heroY:    .res 2
heroDir:  .res 1                ; 0 down, 1 up, 2 left, 3 right
heroAnim: .res 1
heroMov:  .res 1
camX:     .res 2
camY:     .res 2
lastMx:   .res 1
lastMy:   .res 1
encAccum: .res 1
encPend:  .res 1                ; set when an encounter should start
mapEnc:   .res 1                ; encounter rate from header
exitCnt:  .res 1
gridOff:  .res 2                ; offset of grid within map blob

.segment "BSS"
mapExits: .res 128              ; up to 16 events * 8 bytes
.export storyFlags
storyFlags: .res 2

.segment "HIBSS"
.export mapGrid
mapGrid:  .res 1024

.segment "CODE"

; ---------------------------------------------------------------------------
.proc MapInit
        .a8
        .i16
        lda battleReturn
        beq @full
        ; quick restore after battle: VRAM map data is untouched
        stz battleReturn
        jsr FadeOut
        lda #$09
        sta BGMODE
        lda #V_BG1SC_64
        sta BG1SC
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG12NBA
        sta BG12NBA
        lda #V_BG34NBA
        sta BG34NBA
        lda #V_OBSEL
        sta OBSEL
        lda #$15
        sta TM
        stz encAccum
        stz encPend
        stz textOpq
        jsr TextClear
        jsr TextFlush
        jsr updateCamera
        jsr OamReset
        jsr drawHero
        jsr OamFinish
        lda mapMusic
        jsr PlaySong
        jsr WaitVBlank
        jsr FadeIn
        lda pendingDlg
        cmp #$FF
        beq :+
        pha
        lda #$FF
        sta pendingDlg
        pla
        jsr ShowDialog
:       rts
@full:  lda curMap
        jsr MapLoad
        rts
.endproc

; ---------------------------------------------------------------------------
; Load map A. Handles fade, VRAM/CGRAM uploads, hero spawn.
.proc MapLoad
        .a8
        .i16
        pha
        jsr FadeOut
        lda #$80
        sta INIDISP
        stz shHDMAEN

        ; resolve map pointer: MapTable + A*3
        a16
        lda #0
        a8
        pla
        sta curMap
        a16
        and #$00FF
        sta tmp0
        asl
        clc
        adc tmp0
        tax
        lda f:MapTable,x
        sta mapPtr
        a8
        lda f:MapTable+2,x
        sta mapPtr+2

        ; header fields
        lda [mapPtr]
        sta mapTsId
        ldy #1
        lda [mapPtr],y
        sta mapMusic
        ldy #2
        lda [mapPtr],y
        sta mapEncGroup
        ldy #3
        lda [mapPtr],y
        sta mapEnc
        ldy #6
        lda [mapPtr],y
        sta exitCnt

        ; copy exits to WRAM
        a16
        lda #0
        a8
        lda exitCnt
        a16
        and #$00FF
        asl
        asl
        asl                     ; *8
        beq @noex
        sta tmp0
        ldy #8                  ; source offset in blob
        ldx #0
@exlp:  a8
        lda [mapPtr],y
        sta f:mapExits,x
        iny
        inx
        a16
        cpx tmp0
        bne @exlp
@noex:
        ; grid offset = 8 + exitCnt*8
        a16
        lda #0
        a8
        lda exitCnt
        a16
        and #$00FF
        asl
        asl
        asl
        clc
        adc #8
        sta gridOff

        ; ---- copy metatile grid (1024) to WRAM via DMA to $2180 ----
        a16
        lda #.loword(mapGrid)
        sta WMADDL              ; 16-bit write covers $2181/$2182
        a8
        lda #(^mapGrid & 1)     ; WRAM bank bit: $7E=0, $7F=1
        sta WMADDH
        a16
        lda gridOff
        clc
        adc mapPtr
        sta A1T0L
        lda #$8000              ; mode 0, A->B, B addr = $80 ($2180)
        sta DMAP0               ; DMAP0=$00, BBAD0=$80
        a8
        lda mapPtr+2
        sta A1B0
        a16
        lda #1024
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN

        ; ---- DMA baked tilemap (8192) to VRAM $4000 ----
        lda #$80
        sta VMAIN
        a16
        lda #VRAM_BG1MAP
        sta VMADDL
        lda gridOff
        clc
        adc #1024
        clc
        adc mapPtr
        sta A1T0L
        lda #$1801
        sta DMAP0
        a8
        lda mapPtr+2
        sta A1B0
        a16
        lda #8192
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN

        ; ---- tileset chr/pal/attr (tileset id at header +0) ----
        lda [mapPtr]            ; tileset id
        a16
        and #$00FF
        sta tmp0
        asl
        clc
        adc tmp0
        tax                     ; id*3
        ; chr
        lda f:TsChrTable,x
        sta A1T0L
        a8
        lda f:TsChrTable+2,x
        sta A1B0
        a16
        lda #VRAM_BGCHR
        sta VMADDL
        lda #$1801
        sta DMAP0
        ; size: TsChrSize is a word table indexed by id*2
        lda tmp0
        asl
        phx
        tax
        lda f:TsChrSize,x
        sta DAS0L
        plx
        a8
        lda #$01
        sta MDMAEN
        ; pal -> CGRAM 32
        a16
        lda f:TsPalTable,x
        sta A1T0L
        a8
        lda f:TsPalTable+2,x
        sta A1B0
        lda #32
        sta CGADD
        a16
        lda #$2200
        sta DMAP0
        lda #64
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN
        ; attr pointer kept for collision
        a16
        lda f:TsAttrTable,x
        sta attrPtr
        a8
        lda f:TsAttrTable+2,x
        sta attrPtr+2

        ; ---- hero OBJ tiles + palette ----
        DmaToVram HeroObjChr, VRAM_OBJCHR, (HeroObjChrEnd-HeroObjChr)
        DmaToCgram ObjPal, 128, 32

        ; ---- PPU setup ----
        a8
        lda #$09
        sta BGMODE
        lda #V_BG1SC_64
        sta BG1SC
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG12NBA
        sta BG12NBA
        lda #V_BG34NBA
        sta BG34NBA
        lda #V_OBSEL
        sta OBSEL
        lda #$15                ; OBJ + BG3 + BG1
        sta TM

        ; ---- spawn hero (unless spawnOverride set) ----
        lda spawnOvr
        bne @ovr
        ldy #4
        lda [mapPtr],y
        sta tmp0
        ldy #5
        lda [mapPtr],y
        sta tmp1
        bra @spawn
@ovr:   lda spawnOvrX
        sta tmp0
        lda spawnOvrY
        sta tmp1
        stz spawnOvr
@spawn: a16
        lda #0
        a8
        lda tmp0
        a16
        asl
        asl
        asl
        asl
        sta heroX
        lda #0
        a8
        lda tmp1
        a16
        asl
        asl
        asl
        asl
        sta heroY
        a8
        lda tmp0
        sta lastMx
        lda tmp1
        sta lastMy
        stz heroDir
        stz heroAnim
        stz encAccum
        stz encPend
        stz textOpq
        stz mapMode
        stz dlgNext

        jsr TextClear
        jsr TextFlush
        jsr updateCamera
        jsr OamReset
        jsr drawHero
        jsr OamFinish
        lda mapMusic
        jsr PlaySong
        jsr WaitVBlank
        jsr FadeIn
        rts
.endproc

.segment "ZEROPAGE"
.exportzp spawnOvr, spawnOvrX, spawnOvrY
spawnOvr:  .res 1
spawnOvrX: .res 1
spawnOvrY: .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
.proc MapFrame
        .a8
        .i16
        lda mapMode
        beq @walk
        ; ---- dialog open: wait for confirm ----
        a16
        lda joyPressed
        and #(JOY_A|JOY_B|JOY_START)
        a8
        beq @dlgIdle
        jsr TextClear
        jsr TextFlush
        stz mapMode
        stz textOpq
        lda dlgNext
        beq @dlgIdle
        cmp #1
        bne @maw
        ; boss battle after dialog
        stz dlgNext
        lda #ST_BATTLE
        sta pendingState
        rts
@maw:   ; bridge crossing to Xethul's Maw
        stz dlgNext
        lda #15
        sta spawnOvrX
        lda #28
        sta spawnOvrY
        lda #1
        sta spawnOvr
        lda #9
        jsr MapLoad
@dlgIdle:
        rts
@walk:
        ; ---- movement input ----
        stz heroMov
        a16
        stz tmp0                ; dx
        stz tmp1                ; dy
        lda joyHeld
        bit #JOY_LEFT
        beq :+
        lda #.loword(-2)
        sta tmp0
        a8
        lda #2
        sta heroDir
        a16
:       lda joyHeld
        bit #JOY_RIGHT
        beq :+
        lda #2
        sta tmp0
        a8
        lda #3
        sta heroDir
        a16
:       lda joyHeld
        bit #JOY_UP
        beq :+
        lda #.loword(-2)
        sta tmp1
        a8
        lda #1
        sta heroDir
        a16
:       lda joyHeld
        bit #JOY_DOWN
        beq :+
        lda #2
        sta tmp1
        a8
        lda #0
        sta heroDir
        a16
:
        ; ---- X axis move + collide ----
        lda tmp0
        beq @ymove
        clc
        adc heroX
        sta tmp2                ; nx
        ; probe x: leading edge
        lda tmp0
        bmi @xl
        lda tmp2
        clc
        adc #13
        bra @xp
@xl:    lda tmp2
        clc
        adc #2
@xp:    sta tmp3                ; probe px
        lda heroY
        clc
        adc #8
        sta tmp4
        jsr GetAttrAt           ; tmp3,tmp4 -> A attr
        .a8
        and #ATTR_SOLID
        bne @ymove
        a16
        lda heroY
        clc
        adc #15
        sta tmp4
        jsr GetAttrAt
        .a8
        and #ATTR_SOLID
        bne @ymove
        a16
        lda tmp2
        sta heroX
        a8
        lda #1
        sta heroMov
        a16

@ymove: ; ---- Y axis ----
        a16
        lda tmp1
        beq @moved
        clc
        adc heroY
        sta tmp2                ; ny
        lda tmp1
        bmi @yu
        lda tmp2
        clc
        adc #15
        bra @yp
@yu:    lda tmp2
        clc
        adc #8
@yp:    sta tmp4                ; probe py
        lda heroX
        clc
        adc #2
        sta tmp3
        jsr GetAttrAt
        .a8
        and #ATTR_SOLID
        bne @moved
        a16
        lda heroX
        clc
        adc #13
        sta tmp3
        jsr GetAttrAt
        .a8
        and #ATTR_SOLID
        bne @moved
        a16
        lda tmp2
        sta heroY
        a8
        lda #1
        sta heroMov
        a16

@moved: a8
        lda heroMov
        beq @idle
        inc heroAnim
        bra @trig
@idle:  stz heroAnim

@trig:  ; ---- new-metatile triggers ----
        a16
        lda heroX
        clc
        adc #8
        lsr
        lsr
        lsr
        lsr
        sta tmp0                ; mx
        lda heroY
        clc
        adc #12
        lsr
        lsr
        lsr
        lsr
        sta tmp1                ; my
        a8
        lda tmp0
        cmp lastMx
        bne @newtile
        lda tmp1
        cmp lastMy
        beq @cam
@newtile:
        lda tmp0
        sta lastMx
        lda tmp1
        sta lastMy
        ; exits?
        jsr checkExits
        bcs @done               ; warped: skip rest this frame
        ; encounter zone?
        a16
        lda heroX
        clc
        adc #8
        sta tmp3
        lda heroY
        clc
        adc #12
        sta tmp4
        jsr GetAttrAt
        .a8
        and #ATTR_ENC
        beq @cam
        lda mapEnc
        beq @cam
        clc
        adc encAccum
        sta encAccum            ; accumulates rate per wild step
        jsr Rand8
        cmp encAccum
        bcs @cam
        ; encounter triggered
        stz encAccum
        lda #1
        sta encPend
        lda #ST_BATTLE
        sta pendingState

@cam:   jsr updateCamera
        jsr OamReset
        jsr drawHero
        jsr OamFinish
@done:  rts
.endproc

; ---------------------------------------------------------------------------
; attr byte for pixel (tmp3=px, tmp4=py). Returns A(8)=attr; exits a8.
; Entry A width may be 8 or 16. Trashes X/Y and tmp5.
.proc GetAttrAt
        .i16
        a16
        lda tmp4
        and #$01F0
        asl                     ; (py>>4)*32
        sta tmp5
        lda tmp3
        lsr
        lsr
        lsr
        lsr
        and #$001F
        clc
        adc tmp5
        tax
        a8
        lda f:mapGrid,x
        a16
        and #$00FF
        tay
        a8
        lda [attrPtr],y
        rts
.endproc

; ---------------------------------------------------------------------------
; Check events at (lastMx,lastMy). Carry set if an event consumed the step.
.proc checkExits
        .a8
        .i16
        ldx #0
        lda exitCnt
        bne :+
        clc
        rts
:       sta tmp2
@lp:    lda f:mapExits,x        ; mx
        cmp lastMx
        bne @next
        lda f:mapExits+1,x      ; my
        cmp lastMy
        bne @next
        jmp @match
@next:  a16
        txa
        clc
        adc #8
        tax
        a8
        dec tmp2
        bne @lp
        clc
        rts

@match: lda f:mapExits+2,x      ; type
        bne :+
        jmp @warp
:       cmp #1
        bne :+
        jmp @gate
:       cmp #2
        bne :+
        jmp @dialog
:       cmp #3
        bne :+
        jmp @recruit
:       cmp #4
        bne :+
        jmp @boss
:       cmp #5
        bne :+
        jmp @chest
:       cmp #6
        bne :+
        jmp @heal
:       cmp #9
        bne :+
        jmp @bridge
:       clc
        rts

; ---- type 0/1: warps -------------------------------------------------
@gate:  lda #6
        phx
        jsr PlaySfx
        plx
@warp:  lda f:mapExits+4,x      ; destX
        sta spawnOvrX
        lda f:mapExits+5,x      ; destY
        sta spawnOvrY
        lda #1
        sta spawnOvr
        lda f:mapExits+3,x      ; destMap
        jsr MapLoad
        sec
        rts

; ---- type 2: dialog ---------------------------------------------------
@dialog:
        lda f:mapExits+3,x
        jsr ShowDialog
        sec
        rts

; ---- type 3: recruit --------------------------------------------------
@recruit:
        lda f:mapExits+6,x
        jsr FlagTest
        bcc :+
        clc
        rts
:       lda f:mapExits+6,x
        phx
        jsr SetFlag
        plx
        lda f:mapExits+3,x      ; hero id
        pha
        lda f:mapExits+4,x      ; join text
        jsr ShowDialog
        pla
        jsr recruitHero
        lda #7
        jsr PlaySfx
        sec
        rts

; ---- type 4: boss -----------------------------------------------------
@boss:  lda f:mapExits+6,x
        jsr FlagTest
        bcc :+
        clc
        rts
:       lda f:mapExits+3,x
        sta bForceForm
        lda f:mapExits+5,x
        sta bBossDlg
        lda f:mapExits+6,x
        sta bBossFlag
        lda f:mapExits+4,x
        jsr ShowDialog
        lda #1
        sta dlgNext
        sec
        rts

; ---- type 5: chest ----------------------------------------------------
@chest: lda f:mapExits+6,x
        jsr FlagTest
        bcc :+
        clc
        rts
:       lda f:mapExits+6,x
        phx
        jsr SetFlag
        plx
        ; give item
        phx
        lda f:mapExits+3,x
        a16
        and #$00FF
        tax
        a8
        lda f:invCount,x
        cmp #9
        bcs :+
        inc
        sta f:invCount,x
:       plx
        lda #1
        phx
        jsr PlaySfx
        plx
        lda f:mapExits+4,x
        jsr ShowDialog
        sec
        rts

; ---- type 6: heal point -----------------------------------------------
@heal:  phx
        jsr healParty
        lda #4
        jsr PlaySfx
        plx
        lda f:mapExits+3,x
        jsr ShowDialog
        sec
        rts

; ---- type 9: rift bridge ----------------------------------------------
@bridge:
        lda f:storyFlags
        and #$F0
        cmp #$F0
        beq @go
        lda f:mapExits+4,x
        jsr ShowDialog
        sec
        rts
@go:    lda f:mapExits+5,x
        jsr ShowDialog
        lda #2
        sta dlgNext
        sec
        rts
.endproc

; ---------------------------------------------------------------------------
; Show dialog string A (StoryTab index). Opens the bottom window.
.export ShowDialog
.proc ShowDialog
        .a8
        .i16
        pha
        lda #1
        sta mapMode
        stz dlgNext
        lda #128
        sta textOpq
        lda #1
        sta textPal
        stz textX
        lda #19
        sta textY
        lda #32
        ldx #9
        jsr DrawWindow
        pla
        ; textPtr = StoryTab[id*3]
        a16
        and #$00FF
        sta tmp0
        asl
        clc
        adc tmp0
        tax
        lda f:StoryTab,x
        sta textPtr
        a8
        lda f:StoryTab+2,x
        sta textPtr+2
        lda #2
        sta textX
        lda #20
        sta textY
        lda #0
        sta textPal
        jsr TextPut
        jsr TextFlush
        rts
.endproc

; ---------------------------------------------------------------------------
; Story flag helpers. A = bit index 0-15. FlagTest: carry set when flag set.
.export FlagTest, SetFlag
.proc FlagTest
        .a8
        .i16
        jsr flagPos
        and f:storyFlags,x
        bne @set
        clc
        rts
@set:   sec
        rts
.endproc

.proc SetFlag
        .a8
        .i16
        jsr flagPos
        ora f:storyFlags,x
        sta f:storyFlags,x
        rts
.endproc

; A = bit 0-15 -> X = byte index (0/1), A = mask. Trashes Y, tmp3.
.proc flagPos
        .a8
        .i16
        pha
        and #$07
        a16
        and #$00FF
        tay
        a8
        lda a:maskTab,y
        sta tmp3
        pla
        a16
        and #$00FF
        lsr
        lsr
        lsr
        tax
        a8
        lda tmp3
        rts
maskTab: .byte 1,2,4,8,16,32,64,128
.endproc

; ---------------------------------------------------------------------------
; Recruit hero A at the veteran party's level.
.proc recruitHero
        .a8
        .i16
        pha
        jsr PartyRecruit
        ; X = hero*32 for the new hero
        a16
        lda #0
        a8
        pla
        pha
        a16
        and #$00FF
        asl
        asl
        asl
        asl
        asl
        tax
        a8
        ; level up until matching hero 0's level
@lvl:   lda f:party+PT_LVL,x
        cmp f:party+PT_LVL
        bcs @done
        phx
        jsr HeroLevelUp
        plx
        bra @lvl
@done:  pla
        rts
.endproc

; ---------------------------------------------------------------------------
; Restore full hp/mp for all recruited heroes.
.export healParty
.proc healParty
        .a8
        .i16
        ldx #0
        stz tmp3
@lp:    lda f:party+PT_FLAGS,x
        and #$01
        beq @next
        a16
        lda f:party+PT_MAXHP,x
        sta f:party+PT_HP,x
        lda f:party+PT_MAXMP,x
        sta f:party+PT_MP,x
        a8
@next:  a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp3
        lda tmp3
        cmp #5
        bne @lp
        rts
.endproc

; ---------------------------------------------------------------------------
.proc updateCamera
        .a8
        .i16
        a16
        lda heroX
        clc
        adc #8
        sec
        sbc #128
        bpl :+
        lda #0
:       cmp #256
        bcc :+
        lda #256
:       sta camX
        sta shBG1H
        lda heroY
        clc
        adc #8
        sec
        sbc #112
        bpl :+
        lda #0
:       cmp #288
        bcc :+
        lda #288
:       sta camY
        dec
        sta shBG1V
        a8
        rts
.endproc

; ---------------------------------------------------------------------------
.proc drawHero
        .a8
        .i16
        a16
        lda heroX
        sec
        sbc camX
        a8
        sta sprX
        a16
        lda heroY
        sec
        sbc camY
        a8
        sta sprY
        ; animation frame
        lda heroAnim
        and #$08
        beq @f0
        lda #1
        bra @have
@f0:    lda #0
@have:  sta tmp2
        ; base tile by direction: down=0, up=4, left/right=8
        lda heroDir
        beq @down
        cmp #1
        beq @up
        ; left or right
        lda #8
        bra @tile
@up:    lda #4
        bra @tile
@down:  lda #0
@tile:  sta tmp3
        lda tmp2
        asl                     ; frame*2
        clc
        adc tmp3
        sta sprTile
        ; attr: pal0 prio2, hflip for right
        lda heroDir
        cmp #3
        beq @flip
        lda #$20
        bra @attr
@flip:  lda #$60
@attr:  sta sprAttr
        lda #1
        sta sprSize
        jsr OamPush
        rts
.endproc

; ---------------------------------------------------------------------------
; Fade brightness 15 -> 0 (FadeOut) / 0 -> 15 (FadeIn), 2 frames per step.
.proc FadeOut
        .a8
        .i16
        lda #15
@lp:    pha
        sta INIDISP
        jsr WaitVBlank
        jsr WaitVBlank
        pla
        dec
        bpl @lp
        lda #$80
        sta INIDISP
        rts
.endproc

.proc FadeIn
        .a8
        .i16
        lda #0
@lp:    pha
        sta INIDISP
        jsr WaitVBlank
        jsr WaitVBlank
        pla
        inc
        cmp #16
        bne @lp
        lda #$0F
        sta INIDISP
        rts
.endproc
