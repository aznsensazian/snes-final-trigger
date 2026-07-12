; ---------------------------------------------------------------------------
; Small utilities: 16-bit number to decimal text.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"

.export Num2Str, PrintNumR, PrintNumL
.import TextPut
.importzp textPtr

.segment "ZEROPAGE"
.exportzp numVal, numBuf
numVal:  .res 2
numBuf:  .res 6                 ; 5 chars + NUL

.segment "CODE"

; Convert numVal (16-bit) to right-aligned decimal in numBuf.
; Leading zeros become spaces. Exits a8/i16.
.proc Num2Str
        .a8
        .i16
        php
        ai16
        ldx #0                  ; digit index
        ldy #0                  ; "seen nonzero" flag in Y low
@dig:   a16
        lda numVal
        sec
        ldy #0
@sub:   cmp f:pow10,x
        bcc @store
        sbc f:pow10,x
        iny
        bra @sub
@store: sta numVal
        a8
        tya                     ; digit count 0..9
        phx
        cpx #8                  ; last digit (index 8 = ones)?
        beq @always
        cmp #0
        bne @always
        ; leading zero -> space unless a digit was already written
        lda seen
        bne @zero
        lda #' '
        bra @put
@zero:  lda #'0'
        bra @put
@always:
        clc
        adc #'0'
        pha
        lda #1
        sta seen
        pla
@put:   plx
        pha
        txa
        lsr                     ; digit position = x/2
        php
        a16
        and #$00FF
        tay
        a8
        plp
        pla
        sta numBuf,y
        inx
        inx
        cpx #10
        bne @dig
        lda #0
        sta numBuf+5
        plp
        rts
pow10:  .word 10000, 1000, 100, 10, 1
.endproc

.segment "ZEROPAGE"
seen:   .res 1

.segment "CODE"

; Print numVal right-aligned (5 cells) at textX/textY.
.proc PrintNumR
        .a8
        .i16
        stz seen
        jsr Num2Str
        a16
        lda #.loword(numBuf)
        sta textPtr
        a8
        lda #0
        sta textPtr+2
        jsr TextPut
        rts
.endproc

; Print numVal left-aligned at textX/textY.
.proc PrintNumL
        .a8
        .i16
        stz seen
        jsr Num2Str
        ; find first non-space
        ldx #0
@sk:    lda numBuf,x
        cmp #' '
        bne @go
        inx
        cpx #4
        bne @sk
@go:    a16
        txa
        clc
        adc #.loword(numBuf)
        sta textPtr
        a8
        lda #0
        sta textPtr+2
        jsr TextPut
        rts
.endproc
