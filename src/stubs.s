; ---------------------------------------------------------------------------
; Ending sequence: story pages after defeating Xethul, then back to title.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export EndingInit, EndingFrame
.import TextClear, TextPut, TextFlush, PlaySong
.importzp textPtr, textX, textY, textPal, textOpq, shHDMAEN
.importzp joyPressed, pendingState, frameCount

.segment "ZEROPAGE"
endPage: .res 1

.segment "CODE"

.proc EndingInit
        .a8
        .i16
        lda #$80
        sta INIDISP
        stz shHDMAEN
        stz textOpq
        jsr TextClear
        lda #$04                ; BG3 only
        sta TM
        lda #$09
        sta BGMODE
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG34NBA
        sta BG34NBA
        lda #0
        jsr PlaySong
        stz endPage
        jsr drawPage
        lda #$0F
        sta INIDISP
        rts
.endproc

.proc drawPage
        .a8
        .i16
        jsr TextClear
        lda #0
        sta textPal
        lda #3
        sta textX
        lda #8
        sta textY
        a16
        lda #0
        a8
        lda endPage
        a16
        and #$00FF
        asl
        tax
        lda f:PageTab,x
        sta textPtr
        a8
        lda #^EndPage0
        sta textPtr+2
        jsr TextPut
        ; page indicator arrow
        lda #3
        sta textPal
        lda #28
        sta textX
        lda #24
        sta textY
        a16
        lda #.loword(strMore)
        sta textPtr
        a8
        lda #^strMore
        sta textPtr+2
        jsr TextPut
        jsr TextFlush
        rts
.endproc

.proc EndingFrame
        .a8
        .i16
        a16
        lda joyPressed
        and #(JOY_A|JOY_START)
        a8
        beq @out
        inc endPage
        lda endPage
        cmp #PAGE_COUNT
        bcs @title
        jsr drawPage
        rts
@title: lda #ST_TITLE
        sta pendingState
@out:   rts
.endproc

.segment "RODATA"
strMore: .byte "(A)", 0
PAGE_COUNT = 5
PageTab: .addr EndPage0, EndPage1, EndPage2, EndPage3, EndPage4

EndPage0:
        .byte "The Time Eater shrieks as", 1
        .byte "the four Crystals blaze", 1
        .byte "with the light of every", 1
        .byte "dawn it ever swallowed.", 0
EndPage1:
        .byte "Xethul shatters into a", 1
        .byte "thousand harmless seconds,", 1
        .byte "raining like snow into", 1
        .byte "the Rift.", 0
EndPage2:
        .byte "The Crystals return to", 1
        .byte "their thrones. Somewhere,", 1
        .byte "a fifth voice joins their", 1
        .byte "song: the Crystal of Time,", 1
        .byte "reborn.", 0
EndPage3:
        .byte "Kaen, Tessa, Slade, Wyla", 1
        .byte "and Nix step through the", 1
        .byte "gate one last time...", 1, 1
        .byte "each to their own century,", 1
        .byte "forever bound across time.", 0
EndPage4:
        .byte "      FINAL TRIGGER", 1, 1
        .byte "   - CRYSTALS OF TIME -", 1, 1, 1
        .byte "        THE  END", 1, 1, 1
        .byte "   Thank you for playing!", 0
