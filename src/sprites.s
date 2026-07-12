; ---------------------------------------------------------------------------
; OAM buffer helpers. oamBuf/oamHiBuf are DMA'd to OAM in NMI when
; nmiFlags bit1 is set.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"

.export OamReset, OamPush, OamFinish
.import oamBuf, oamHiBuf
.importzp nmiFlags

.segment "ZEROPAGE"
.exportzp sprX, sprY, sprTile, sprAttr, sprSize, oamIdx
sprX:    .res 1
sprY:    .res 1
sprTile: .res 1
sprAttr: .res 1
sprSize: .res 1                 ; 0 = small, 1 = large (OBSEL size pair)
oamIdx:  .res 1                 ; next free OAM slot (0..127)

.segment "CODE"

; Clear buffer: all sprites offscreen (y=$F0), hi bits = xhigh set.
.proc OamReset
        .a8
        .i16
        php
        ai16
        ldx #0
        lda #$F001
@lp:    sta f:oamBuf,x
        inx
        inx
        inx
        inx
        cpx #512
        bne @lp
        lda #$5555
        ldx #0
@lp2:   sta f:oamHiBuf,x
        inx
        inx
        cpx #32
        bne @lp2
        plp
        stz oamIdx
        rts
.endproc

; Push one 16x16 sprite from sprX/sprY/sprTile/sprAttr.
.proc OamPush
        .a8
        .i16
        php
        a16
        lda #0
        a8
        lda oamIdx
        a16
        asl
        asl
        tax                     ; X = slot*4
        a8
        lda sprX
        sta f:oamBuf,x
        inx
        lda sprY
        sta f:oamBuf,x
        inx
        lda sprTile
        sta f:oamBuf,x
        inx
        lda sprAttr
        sta f:oamBuf,x
        ; hi bits: 2 bits per sprite -> %10 (large size, xhigh clear)
        a16
        lda #0
        a8
        lda oamIdx
        and #$03
        a16
        and #$00FF
        tax
        a8
        lda f:maskTab,x
        sta tmpMask
        lda sprSize
        beq @small
        lda f:valTab,x
        bra @haveVal
@small: lda #0
@haveVal:
        sta tmpVal
        a16
        lda #0
        a8
        lda oamIdx
        lsr
        lsr                     ; hi-table byte index
        a16
        and #$00FF
        tax
        a8
        lda tmpMask
        eor #$FF
        and f:oamHiBuf,x
        ora tmpVal
        sta f:oamHiBuf,x
        inc oamIdx
        plp
        rts
maskTab: .byte $03, $0C, $30, $C0
valTab:  .byte $02, $08, $20, $80
.endproc

; Schedule the OAM upload.
.proc OamFinish
        .a8
        .i16
        lda nmiFlags
        ora #$02
        sta nmiFlags
        rts
.endproc

.segment "ZEROPAGE"
tmpMask: .res 1
tmpVal:  .res 1
