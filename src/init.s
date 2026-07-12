; ---------------------------------------------------------------------------
; System initialization: puts hardware in a known state, clears all memory.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"

.export Reset
.import Main

.segment "ZEROPAGE"
.exportzp frameCount, joyRaw, joyPressed, joyHeld, rngState
frameCount:  .res 2
joyRaw:      .res 2
joyPressed:  .res 2
joyHeld:     .res 2             ; delayed-repeat state for menus
rngState:    .res 2

.segment "CODE"
.proc Reset
        sei
        clc
        xce                     ; leave 6502 emulation mode
        rep #$38                ; 16-bit A/X/Y, binary mode
        ldx #$1FFF
        txs                     ; stack at top of low WRAM mirror
        lda #$0000
        tcd                     ; direct page at $0000

        sep #$20                ; 8-bit A
        lda #$80
        pha
        plb                     ; DB = $80 (ROM bank mirror; $21xx/$43xx still reachable via long)
        lda #$00
        pha
        plb                     ; DB = $00

        ; force blank, full brightness setting comes later
        lda #$8F
        sta INIDISP

        ; clear PPU registers
        stz OBSEL
        stz OAMADDL
        stz OAMADDH
        stz BGMODE
        stz MOSAIC
        stz BG1SC
        stz BG2SC
        stz BG3SC
        stz BG4SC
        stz BG12NBA
        stz BG34NBA
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS
        stz BG2HOFS
        stz BG2HOFS
        stz BG2VOFS
        stz BG2VOFS
        stz BG3HOFS
        stz BG3HOFS
        stz BG3VOFS
        stz BG3VOFS
        stz BG4HOFS
        stz BG4HOFS
        stz BG4VOFS
        stz BG4VOFS
        lda #$80
        sta VMAIN
        stz M7SEL
        stz W12SEL
        stz W34SEL
        stz WOBJSEL
        stz WH0
        stz WH1
        stz WH2
        stz WH3
        stz WBGLOG
        stz WOBJLOG
        stz TM
        stz TS
        stz TMW
        stz TSW
        lda #$30
        sta CGWSEL
        stz CGADSUB
        lda #$E0
        sta COLDATA
        stz SETINI

        ; clear CPU registers
        stz NMITIMEN
        lda #$FF
        sta WRIO
        stz WRMPYA
        stz WRMPYB
        stz WRDIVL
        stz WRDIVH
        stz WRDIVB
        stz HTIMEL
        stz HTIMEH
        stz VTIMEL
        stz VTIMEH
        stz MDMAEN
        stz HDMAEN
        stz MEMSEL

        ; --- clear all 128KB of WRAM with DMA from a zero constant ---
        stz WMADDL
        stz WMADDM
        stz WMADDH
        rep #$20
        lda #$8008              ; fixed source, write to $2180
        sta DMAP0
        lda #.loword(zeroByte)
        sta A1T0L
        sep #$20
        lda #^zeroByte
        sta A1B0
        rep #$20
        lda #$0000              ; 65536 bytes
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN              ; first 64KB
        rep #$20
        lda #$0000
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN              ; second 64KB

        ; --- clear 64KB VRAM ---
        rep #$20
        lda #$0000
        sta VMADDL
        lda #$1809              ; two registers, fixed source
        sta DMAP0
        lda #.loword(zeroByte)
        sta A1T0L
        sep #$20
        lda #^zeroByte
        sta A1B0
        rep #$20
        lda #$0000
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN

        ; --- clear CGRAM ---
        stz CGADD
        rep #$20
        lda #$2208              ; one register $2122, fixed source
        sta DMAP0
        lda #.loword(zeroByte)
        sta A1T0L
        sep #$20
        lda #^zeroByte
        sta A1B0
        rep #$20
        lda #512
        sta DAS0L
        sep #$20
        lda #$01
        sta MDMAEN

        ; --- clear OAM: move all sprites offscreen ---
        stz OAMADDL
        stz OAMADDH
        ldx #128
@oamlo: lda #$01                ; x = 1 (with x-high bit set below, => offscreen)
        sta OAMDATA
        lda #$F0                ; y = 240 (offscreen)
        sta OAMDATA
        stz OAMDATA
        stz OAMDATA
        dex
        bne @oamlo
        ldx #32
@oamhi: lda #$55                ; x-high bits set for all: fully offscreen
        sta OAMDATA
        dex
        bne @oamhi

        ; seed RNG
        rep #$20
        lda #$C0DE
        sta rngState
        sep #$20

        rep #$10                ; X/Y 16-bit from here on
        jml Main

zeroByte:
        .byte $00
.endproc
