; ---------------------------------------------------------------------------
; Main entry, NMI handler, frame/joypad services.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"

.export Main, NmiHandler, IrqHandler, WaitVBlank, Rand8, Rand16
.importzp frameCount, joyRaw, joyPressed, joyHeld, rngState

.segment "ZEROPAGE"
.exportzp nmiFlags
nmiFlags:   .res 1              ; bit7: OAM buffer dirty

.segment "CODE"

; ---------------------------------------------------------------------------
.proc Main
        ; Boot-stage proof of life: deep blue backdrop, red when START held.
        a8
        ; backdrop color 0
        stz CGADD
        lda #$40                ; BGR555 $2C40: warm deep blue
        sta CGDATA
        lda #$2C
        sta CGDATA

        lda #$81                ; NMI on, auto-joypad on
        sta NMITIMEN
        cli
        lda #$0F                ; screen on, full brightness
        sta INIDISP

loop:
        jsr WaitVBlank
        a16
        lda joyRaw
        and #JOY_START
        beq @blue
        a8
        stz CGADD
        lda #$1F                ; red
        sta CGDATA
        stz CGDATA
        bra loop
@blue:  a8
        stz CGADD
        lda #$40
        sta CGDATA
        lda #$2C
        sta CGDATA
        bra loop
.endproc

; ---------------------------------------------------------------------------
; Wait until the next NMI has run.
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
; 8-bit random number in A (uses 16-bit Galois LFSR). Preserves X/Y.
.proc Rand16
        php
        a16
        lda rngState
        lsr
        bcc @nx
        eor #$B400
@nx:    sta rngState
        plp
        rts
.endproc

.proc Rand8
        jsr Rand16
        php
        a8
        lda rngState
        eor frameCount
        plp
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

        lda RDNMI               ; acknowledge NMI

        ; wait for auto-joypad read to finish
@joyw:  lda HVBJOY
        and #$01
        bne @joyw

        rep #$20
        lda JOY1L
        sta joyRaw
        lda joyHeld             ; joyHeld = raw from previous frame
        eor #$FFFF
        and joyRaw
        sta joyPressed          ; newly-pressed = raw & ~prev
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
