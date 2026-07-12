; ---------------------------------------------------------------------------
; Temporary state stubs, replaced as systems come online.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export EndingInit, EndingFrame
.import TextClear, TextPut, TextFlush
.importzp textPtr, textX, textY, textPal, shHDMAEN

.segment "CODE"

.proc EndingInit
        .a8
        .i16
        lda #$80
        sta INIDISP
        stz shHDMAEN
        jsr TextClear
        lda #$04
        sta TM
        lda #3
        sta textPal
        lda #8
        sta textX
        lda #12
        sta textY
        a16
        lda #.loword(strWip)
        sta textPtr
        a8
        lda #^strWip
        sta textPtr+2
        jsr TextPut
        jsr TextFlush
        lda #$0F
        sta INIDISP
        rts
.endproc

.proc EndingFrame
        .a8
        .i16
        rts
.endproc

.segment "RODATA"
strWip: .byte "THE END...?", 0
