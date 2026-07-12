; ---------------------------------------------------------------------------
; BG3 text/window engine.
; A 32x32 shadow tilemap lives in WRAM (textMap); TextFlush schedules a DMA
; of the whole 2KB to VRAM $0800 during the next vblank.
; Font tiles: ASCII-32 => tile 0..94, then UI tiles (see tools/font_data.py).
; Calling convention: a8/i16 unless noted.
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export TextInit, TextClear, TextPut, TextPutTile, TextFlush, DrawWindow
.import FontChr, FontChrEnd, TextPal
.importzp nmiFlags

.segment "ZEROPAGE"
.exportzp textPtr, textX, textY, textPal, textOpq
textOpq:  .res 1                ; nonzero: use opaque-background glyphs
textPtr:  .res 3                ; 24-bit string pointer
textX:    .res 1                ; column 0..31
textY:    .res 1                ; row 0..31
textPal:  .res 1                ; palette 0..7
textAttr: .res 2                ; cached (pal<<10)|priority
textDst:  .res 2                ; cached buffer byte index
winW:     .res 1
winH:     .res 1
winI:     .res 1
winTile:  .res 1

.segment "HIBSS"
.export textMap
textMap:  .res 2048

.segment "CODE"

; Upload font tiles + text palettes. Call under force blank.
.proc TextInit
        .a8
        .i16
        php
        DmaToVram FontChr, $0000, (FontChrEnd-FontChr)
        DmaToCgram TextPal, 0, 64
        plp
        ; fall through intent: caller clears; do it here for convenience
        jsr TextClear
        rts
.endproc

; Fill textMap with blank space tiles.
.proc TextClear
        .a8
        .i16
        php
        ai16
        lda #$2000              ; tile 0 (space), priority set
        ldx #0
@lp:    sta f:textMap,x
        inx
        inx
        cpx #2048
        bne @lp
        plp
        rts
.endproc

; internal: compute textAttr and textDst from textPal/textX/textY.
; Preserves caller width via php/plp.
.proc calcDst
        php
        a16
        lda #0
        a8
        lda textPal
        a16
        xba                     ; pal << 8
        asl
        asl                     ; pal << 10
        ora #$2000              ; priority
        sta textAttr
        lda #0
        a8
        lda textY
        a16
        asl
        asl
        asl
        asl
        asl                     ; y*32
        sta textDst
        lda #0
        a8
        lda textX
        a16
        clc
        adc textDst
        asl                     ; *2 bytes per entry
        sta textDst
        plp
        rts
.endproc

; internal: A(16) = tile index (high byte clear), X = byte index into textMap.
; Writes entry, advances X by 2. Requires ai16.
.proc putTile16
        ora textAttr
        sta f:textMap,x
        inx
        inx
        rts
.endproc

; Write NUL-terminated string at (textX,textY) pal textPal. textPtr = string.
; Code 1 = newline.
.proc TextPut
        .a8
        .i16
        jsr calcDst
        php
        ai16
        ldx textDst
@lp:    a8
        lda [textPtr]
        beq @done
        cmp #1
        beq @nl
        sec
        sbc #32
        clc
        adc textOpq             ; +128 when opaque mode
        a16
        and #$00FF
        jsr putTile16
@adv:   a16
        inc textPtr             ; 16-bit increment of pointer low word
        bra @lp
@nl:    a8
        inc textY
        jsr calcDst
        a16
        ldx textDst
        bra @adv
@done:  plp
        rts
.endproc

; Put single tile A(8) = tile index at (textX,textY), pal textPal.
.proc TextPutTile
        .a8
        .i16
        sta winTile
        jsr calcDst
        php
        ai16
        lda #0
        a8
        lda winTile
        a16
        and #$00FF
        ldx textDst
        jsr putTile16
        plp
        rts
.endproc

; Draw a window: textX/textY = top-left, A(8) = width cols, winH preset? No:
; call with A = width, X low byte = height. Palette = textPal (usually 1).
.proc DrawWindow
        .a8
        .i16
        sta winW
        php
        a8
        txa
        sta winH
        plp
        jsr calcDst
        php
        ai16
        lda #0
        a8
        stz winI
@rowlp: lda winI
        cmp winH
        bcs @done
        ; pick row tile base: top=96, mid=99, bottom=102
        lda #TILE_WIN
        pha
        lda winI
        beq @have               ; row 0 -> top (A on stack = TILE_WIN)
        inc                     ; compare against winH-1
        cmp winH
        bcc @mid
        pla
        lda #TILE_WIN+6
        pha
        bra @have
@mid:   pla
        lda #TILE_WIN+3
        pha
@have:  pla
        sta winTile
        ; write one row: left, (w-2) fill tiles, right
        a16
        ldx textDst
        lda #0
        a8
        lda winTile
        a16
        and #$00FF
        jsr putTile16
        lda #0
        a8
        lda winW
        dec
        dec
        a16
        and #$00FF
        tay
@fill:  beq @right
        lda #0
        a8
        lda winTile
        inc
        a16
        and #$00FF
        jsr putTile16
        dey
        bra @fill
@right: lda #0
        a8
        lda winTile
        inc
        inc
        a16
        and #$00FF
        jsr putTile16
        ; next row
        lda textDst
        clc
        adc #64
        sta textDst
        a8
        inc winI
        bra @rowlp
@done:  plp
        rts
.endproc

; Schedule the 2KB textMap upload for next vblank.
.proc TextFlush
        .a8
        .i16
        php
        a8
        lda nmiFlags
        ora #$01
        sta nmiFlags
        plp
        rts
.endproc
