; ---------------------------------------------------------------------------
; Main loop, game-state dispatch, NMI handler, frame/joypad/RNG services.
; Register convention outside NMI: A 8-bit, X/Y 16-bit unless noted.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export Main, NmiHandler, IrqHandler, WaitVBlank, Rand8
.importzp frameCount, joyRaw, joyPressed, joyHeld, rngState
.import textMap
.import TitleInit, TitleFrame, IntroInit, IntroFrame
.import MapInit, MapFrame
.import BattleInit, BattleFrame
.import GameOverInit, GameOverFrame
.import EndingInit, EndingFrame
.import AudioInit

.segment "ZEROPAGE"
.exportzp nmiFlags, gameState, pendingState
.exportzp shBG1H, shBG1V, shBG2H, shBG2V, shBG3H, shBG3V, shHDMAEN
.exportzp tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7
nmiFlags:     .res 1            ; bit0: textMap dirty, bit1: OAM dirty
gameState:    .res 1
pendingState: .res 1
shBG1H:       .res 2            ; scroll shadows, written to PPU every vblank
shBG1V:       .res 2
shBG2H:       .res 2
shBG2V:       .res 2
shBG3H:       .res 2
shBG3V:       .res 2
shHDMAEN:     .res 1
tmp0:         .res 2
tmp1:         .res 2
tmp2:         .res 2
tmp3:         .res 2
tmp4:         .res 2
tmp5:         .res 2
tmp6:         .res 2
tmp7:         .res 2

.segment "OAMBUF"
.export oamBuf, oamHiBuf
oamBuf:       .res 512
oamHiBuf:     .res 32

.segment "CODE"

; ---------------------------------------------------------------------------
.proc Main
        .a8
        .i16
        a8
        jsr AudioInit
        ; sane scroll defaults: v = -1 so tilemap row 0 is screen row 0
        stz shBG1H
        stz shBG1H+1
        stz shBG2H
        stz shBG2H+1
        stz shBG3H
        stz shBG3H+1
        lda #$FF
        sta shBG1V
        sta shBG2V
        sta shBG3V
        lda #$03
        sta shBG1V+1
        sta shBG2V+1
        sta shBG3V+1
        stz shHDMAEN

        jsr OamClear

        lda #ST_TITLE
        sta pendingState
        lda #$FF
        sta gameState

        lda #$81                ; NMI + auto joypad
        sta NMITIMEN
        cli

loop:
        a8
        lda pendingState
        cmp gameState
        beq @frame
        sta gameState
        jsr StateInit
@frame: jsr StateFrame
        jsr WaitVBlank
        bra loop
.endproc

.proc StateInit
        .a8
        .i16
        a16
        lda #0
        a8
        lda gameState
        a16
        asl
        tax
        a8
        jsr (InitTab,x)
        rts
InitTab:
        .addr TitleInit
        .addr IntroInit
        .addr MapInit
        .addr BattleInit
        .addr GameOverInit
        .addr EndingInit
.endproc

.proc StateFrame
        .a8
        .i16
        a16
        lda #0
        a8
        lda gameState
        a16
        asl
        tax
        a8
        jsr (FrameTab,x)
        rts
FrameTab:
        .addr TitleFrame
        .addr IntroFrame
        .addr MapFrame
        .addr BattleFrame
        .addr GameOverFrame
        .addr EndingFrame
.endproc

; ---------------------------------------------------------------------------
; Reset OAM buffer: everything offscreen.
.export OamClear
.proc OamClear
        .a8
        .i16
        php
        ai16
        ldx #0
        lda #$F001              ; y=$F0, x=1
@lp:    sta f:oamBuf,x
        inx
        inx
        inx
        inx
        cpx #512
        bne @lp
        lda #$5555              ; size=0, x bit8=1 -> offscreen
        ldx #0
@lp2:   sta f:oamHiBuf,x
        inx
        inx
        cpx #32
        bne @lp2
        plp
        ; schedule OAM upload
        a8
        lda nmiFlags
        ora #$02
        sta nmiFlags
        rts
.endproc

; ---------------------------------------------------------------------------
.proc WaitVBlank
        php
        a8
        lda frameCount
@wait:  wai
        cmp frameCount
        beq @wait
        plp
        rts
.endproc

; ---------------------------------------------------------------------------
; 8-bit pseudo-random number in A. Preserves X/Y.
.proc Rand8
        php
        a16
        lda rngState
        asl
        bcc @nx
        eor #$1D87
@nx:    adc frameCount
        sta rngState
        plp
        a8
        lda rngState+1
        eor rngState
        rts
.endproc

; ---------------------------------------------------------------------------
.proc NmiHandler
        rep #$30
        pha
        phx
        phy
        phd
        phb

        lda #$0000
        tcd
        sep #$20
        lda #$00
        pha
        plb                     ; DB = 0

        lda RDNMI               ; acknowledge

        ; --- queued uploads (must run inside vblank) ---
        lda nmiFlags
        and #$01
        beq @noText
        lda #$80
        sta VMAIN
        rep #$20
        lda #VRAM_BG3MAP
        sta VMADDL
        lda #$1801
        sta DMAP0
        lda #.loword(textMap)
        sta A1T0L
        sep #$20
        lda #^textMap
        sta A1B0
        rep #$20
        lda #2048
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN
@noText:
        lda nmiFlags
        and #$02
        beq @noOam
        stz OAMADDL
        stz OAMADDH
        rep #$20
        lda #$0400              ; one register $2104
        sta DMAP0
        lda #.loword(oamBuf)
        sta A1T0L
        sep #$20
        lda #^oamBuf
        sta A1B0
        rep #$20
        lda #544
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN
@noOam:
        stz nmiFlags

        ; --- scroll registers from shadows ---
        lda shBG1H
        sta BG1HOFS
        lda shBG1H+1
        sta BG1HOFS
        lda shBG1V
        sta BG1VOFS
        lda shBG1V+1
        sta BG1VOFS
        lda shBG2H
        sta BG2HOFS
        lda shBG2H+1
        sta BG2HOFS
        lda shBG2V
        sta BG2VOFS
        lda shBG2V+1
        sta BG2VOFS
        lda shBG3H
        sta BG3HOFS
        lda shBG3H+1
        sta BG3HOFS
        lda shBG3V
        sta BG3VOFS
        lda shBG3V+1
        sta BG3VOFS

        ; --- HDMA enable shadow ---
        lda shHDMAEN
        sta HDMAEN

        ; --- joypad ---
@joyw:  lda HVBJOY
        and #$01
        bne @joyw
        rep #$20
        lda JOY1L
        sta joyRaw
        lda joyHeld
        eor #$FFFF
        and joyRaw
        sta joyPressed
        lda joyRaw
        sta joyHeld

        sep #$20
        inc frameCount

        rep #$30
        plb
        pld
        ply
        plx
        pla
        rti
.endproc

.proc IrqHandler
        rti
.endproc
