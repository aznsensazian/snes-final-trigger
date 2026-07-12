; ---------------------------------------------------------------------------
; Title screen + story intro states.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export TitleInit, TitleFrame, IntroInit, IntroFrame
.import TextInit, TextClear, TextPut, TextPutTile, TextFlush, DrawWindow
.import PartyInit
.import PlaySong, PlaySfx
.import storyFlags
.importzp curMap, pendingDlg, bForceForm, bBossFlag, spawnOvr
.import TitleChr, TitleChrEnd, TitleMap, TitlePal, TitleGrad
.importzp textPtr, textX, textY, textPal, textOpq
.importzp frameCount, joyPressed, joyHeld, pendingState, nmiFlags, shHDMAEN
.importzp tmp0

.segment "ZEROPAGE"
titlePhase:  .res 1
titleCursor: .res 1
introPage:   .res 1
introPtr:    .res 3
introState:  .res 1             ; 0=typing, 1=page done
introLeft:   .res 1             ; left column for text

.segment "CODE"

; ---------------------------------------------------------------------------
.proc TitleInit
        .a8
        .i16
        a8
        lda #$80
        sta INIDISP             ; force blank
        stz shHDMAEN

        jsr TextInit
        DmaToVram TitleChr, VRAM_BGCHR, (TitleChrEnd-TitleChr)
        DmaToVram TitleMap, VRAM_BG1MAP, 2048
        DmaToCgram TitlePal, 32, 32

        a8
        lda #$09                ; mode 1, BG3 priority
        sta BGMODE
        lda #V_BG1SC_32
        sta BG1SC
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG12NBA
        sta BG12NBA
        lda #V_BG34NBA
        sta BG34NBA
        lda #$05                ; BG1 + BG3
        sta TM

        ; HDMA channel 7: mode 3 -> $2121/$2122 (backdrop gradient)
        lda #$03
        sta DMAP0+$70
        lda #$21
        sta BBAD0+$70
        a16
        lda #.loword(TitleGrad)
        sta A1T0L+$70
        a8
        lda #^TitleGrad
        sta A1B0+$70
        lda #$80
        sta shHDMAEN

        lda #0
        jsr PlaySong
        stz textOpq
        stz titlePhase
        stz titleCursor
        jsr drawBase
        jsr TextFlush

        lda #$0F
        sta INIDISP
        rts
.endproc

.proc drawBase
        .a8
        .i16
        a8
        jsr TextClear
        lda #6
        sta textPal
        lda #6
        sta textX
        lda #14
        sta textY
        a16
        lda #.loword(strSubtitle)
        sta textPtr
        a8
        lda #^strSubtitle
        sta textPtr+2
        jsr TextPut

        lda #2
        sta textPal
        lda #7
        sta textX
        lda #26
        sta textY
        a16
        lda #.loword(strFooter)
        sta textPtr
        a8
        lda #^strFooter
        sta textPtr+2
        jsr TextPut
        rts
.endproc

; ---------------------------------------------------------------------------
.proc TitleFrame
        .a8
        .i16
        a8
        lda titlePhase
        beq :+
        jmp @menu
:

        ; --- phase 0: blinking PRESS START ---
        lda frameCount
        and #$20
        beq @erase
        lda #0
        sta textPal
        lda #10
        sta textX
        lda #19
        sta textY
        a16
        lda #.loword(strPress)
        sta textPtr
        a8
        lda #^strPress
        sta textPtr+2
        jsr TextPut
        bra @chk
@erase: lda #10
        sta textX
        lda #19
        sta textY
        a16
        lda #.loword(strBlank11)
        sta textPtr
        a8
        lda #^strBlank11
        sta textPtr+2
        jsr TextPut
@chk:   jsr TextFlush
        a16
        lda joyPressed
        and #(JOY_START|JOY_A)
        a8
        beq @done
        ; open menu
        lda #1
        jsr PlaySfx
        lda #1
        sta titlePhase
        stz titleCursor
        lda #128
        sta textOpq
        lda #1
        sta textPal
        lda #9
        sta textX
        lda #17
        sta textY
        lda #14
        ldx #7
        jsr DrawWindow
        lda #0
        sta textPal
        lda #12
        sta textX
        lda #19
        sta textY
        a16
        lda #.loword(strNewGame)
        sta textPtr
        a8
        lda #^strNewGame
        sta textPtr+2
        jsr TextPut
        lda #12
        sta textX
        lda #21
        sta textY
        a16
        lda #.loword(strContinue)
        sta textPtr
        a8
        lda #^strContinue
        sta textPtr+2
        jsr TextPut
        jsr TextFlush
@done:  rts

        ; --- phase 1: menu ---
@menu:  a16
        lda joyPressed
        and #(JOY_UP|JOY_DOWN)
        a8
        beq @nocur
        lda titleCursor
        eor #1
        sta titleCursor
        lda #0
        jsr PlaySfx
@nocur:
        ; draw cursor hand
        lda #0
        sta textPal
        lda #10
        sta textX
        lda #19
        sta textY
        lda titleCursor
        beq @c0
        lda #TILE_OSPACE
        jsr TextPutTile
        lda #10
        sta textX
        lda #21
        sta textY
        lda #TILE_CURSOR
        jsr TextPutTile
        bra @cd
@c0:    lda #TILE_CURSOR
        jsr TextPutTile
        lda #10
        sta textX
        lda #21
        sta textY
        lda #TILE_OSPACE
        jsr TextPutTile
@cd:    jsr TextFlush

        a16
        lda joyPressed
        and #(JOY_START|JOY_A)
        a8
        beq @noA
        lda titleCursor
        bne @cont
        lda #1
        jsr PlaySfx
        jsr PartyInit
        stz storyFlags
        stz storyFlags+1
        stz curMap
        stz spawnOvr
        lda #$FF
        sta pendingDlg
        sta bForceForm
        sta bBossFlag
        lda #ST_INTRO
        sta pendingState
        rts
@cont:  ; no save system yet: show message
        stz textOpq
        lda #2
        sta textPal
        lda #11
        sta textX
        lda #24
        sta textY
        a16
        lda #.loword(strNoData)
        sta textPtr
        a8
        lda #^strNoData
        sta textPtr+2
        jsr TextPut
        jsr TextFlush
@noA:   a16
        lda joyPressed
        and #JOY_B
        a8
        beq @out
        stz titlePhase
        stz textOpq
        jsr drawBase
        jsr TextFlush
@out:   rts
.endproc

; ---------------------------------------------------------------------------
; Story intro: typewriter pages on black.
; ---------------------------------------------------------------------------
.proc IntroInit
        .a8
        .i16
        a8
        lda #$80
        sta INIDISP
        stz shHDMAEN
        jsr TextClear
        jsr TextFlush
        lda #$04                ; BG3 only
        sta TM
        lda #$09
        sta BGMODE
        lda #V_BG3SC
        sta BG3SC
        lda #V_BG34NBA
        sta BG34NBA

        lda #5
        jsr PlaySong
        stz textOpq
        stz introPage
        jsr pageStart

        lda #$0F
        sta INIDISP
        rts
.endproc

; set up pointers/positions for current page
.proc pageStart
        .a8
        .i16
        a8
        jsr TextClear
        stz introState
        lda introPage
        a16
        and #$00FF
        asl
        tax
        lda f:PageTab,x
        sta introPtr
        a8
        lda #^Page0
        sta introPtr+2
        lda #3
        sta introLeft
        sta textX
        lda #5
        sta textY
        lda #0
        sta textPal
        rts
.endproc

.proc IntroFrame
        .a8
        .i16
        a8
        lda introState
        bne @waitA

        ; reveal speed: 1 char per 2 frames, or fast while A/B held
        lda frameCount
        and #$01
        beq @tick
        a16
        lda joyHeld
        and #(JOY_A|JOY_B)
        a8
        beq @flush
@tick:  jsr revealOne
        a16
        lda joyHeld
        and #(JOY_A|JOY_B)
        a8
        beq @flush
        jsr revealOne
        jsr revealOne
@flush: jsr TextFlush
        rts

@waitA: ; page finished: blink arrow, wait for A/START
        lda frameCount
        and #$10
        bne :+
        jmp @aoff
:
        lda #28
        sta textX
        lda #24
        sta textY
        lda #TILE_ARROWDN
        jsr TextPutTile
        bra @ack
@aoff:  lda #28
        sta textX
        lda #24
        sta textY
        lda #' '-32
        jsr TextPutTile
@ack:   jsr TextFlush
        a16
        lda joyPressed
        and #(JOY_A|JOY_START)
        a8
        beq @out
        inc introPage
        lda introPage
        cmp #PAGE_COUNT
        bcs @go
        jsr pageStart
        rts
@go:    lda #ST_MAP
        sta pendingState
@out:   rts
.endproc

; reveal next character of current page (no-op when done)
.proc revealOne
        .a8
        .i16
        a8
        lda introState
        bne @out
        lda [introPtr]
        beq @done
        cmp #1
        beq @nl
        jsr TextPutTilePrepped
        inc textX
        bra @adv
@nl:    lda introLeft
        sta textX
        inc textY
        inc textY
@adv:   a16
        inc introPtr
        a8
@out:   rts
@done:  lda #1
        sta introState
        rts
.endproc

; write char in A (ASCII) at textX/textY without recomputing palette attrs
.proc TextPutTilePrepped
        .a8
        .i16
        sec
        sbc #32
        jmp TextPutTile
.endproc

; ---------------------------------------------------------------------------
.segment "RODATA"
strSubtitle: .byte "- CRYSTALS OF TIME -", 0
strFooter:   .byte "HOMEBREW RPG 2026", 0
strPress:    .byte "PRESS START", 0
strBlank11:  .byte "           ", 0
strNewGame:  .byte "New Game", 0
strContinue: .byte "Continue", 0
strNoData:   .byte "No saved data.", 0

PAGE_COUNT = 4
PageTab: .addr Page0, Page1, Page2, Page3

Page0:  .byte "In the beginning, five", 1
        .byte "Crystals sang the world", 1
        .byte "into being...", 1, 1
        .byte "Fire. Water. Wind. Earth.", 1
        .byte "And binding them all,", 1
        .byte "the Crystal of Time.", 0

Page1:  .byte "For eons they kept the", 1
        .byte "ages turning in harmony.", 1, 1
        .byte "But something ancient has", 1
        .byte "awakened between the", 1
        .byte "seconds of the world...", 0

Page2:  .byte "XETHUL, THE TIME EATER.", 1, 1
        .byte "One by one, the Crystals", 1
        .byte "are being devoured...", 1, 1
        .byte "and history itself", 1
        .byte "unravels.", 0

Page3:  .byte "The Kingdom of Lyra,", 1
        .byte "year 1000 of the", 1
        .byte "Age of Radiance.", 1, 1
        .byte "The Festival of Ages", 1
        .byte "begins at dawn...", 0
