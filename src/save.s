; ---------------------------------------------------------------------------
; Battery SRAM save/load. LoROM SRAM is at bank $70:0000+.
; Layout: magic(4) + party(160) + inv(8) + gems(2) + storyFlags(2) +
;         curMap(1) + heroX(2) + heroY(2) + checksum(2).
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export SaveGame, LoadGame, SaveExists
.import party, invCount, gems, storyFlags
.importzp curMap, heroX, heroY, tmp0, tmp1, tmp2

SRAM      = $700000
MAGIC0    = $46                 ; 'F'
MAGIC1    = $54                 ; 'T'
MAGIC2    = $53                 ; 'S'
MAGIC3    = $31                 ; '1'

.segment "CODE"

; Copy a live snapshot into a WRAM staging buffer, then to SRAM with checksum.
.proc SaveGame
        .a8
        .i16
        ; magic
        lda #MAGIC0
        sta f:SRAM+0
        lda #MAGIC1
        sta f:SRAM+1
        lda #MAGIC2
        sta f:SRAM+2
        lda #MAGIC3
        sta f:SRAM+3
        ; party (160)
        ldx #0
@party: lda f:party,x
        sta f:SRAM+4,x
        inx
        cpx #160
        bne @party
        ; inv (8)
        ldx #0
@inv:   lda f:invCount,x
        sta f:SRAM+164,x
        inx
        cpx #8
        bne @inv
        ; gems, storyFlags
        lda f:gems
        sta f:SRAM+172
        lda f:gems+1
        sta f:SRAM+173
        lda f:storyFlags
        sta f:SRAM+174
        lda f:storyFlags+1
        sta f:SRAM+175
        lda curMap
        sta f:SRAM+176
        lda heroX
        sta f:SRAM+177
        lda heroX+1
        sta f:SRAM+178
        lda heroY
        sta f:SRAM+179
        lda heroY+1
        sta f:SRAM+180
        ; checksum: sum bytes 0..180
        a16
        lda #0
        sta tmp0
        a8
        ldx #0
@sum:   lda f:SRAM,x
        a16
        and #$00FF
        clc
        adc tmp0
        sta tmp0
        a8
        inx
        cpx #181
        bne @sum
        lda tmp0
        sta f:SRAM+181
        lda tmp0+1
        sta f:SRAM+182
        rts
.endproc

; Carry set if a valid save exists.
.proc SaveExists
        .a8
        .i16
        lda f:SRAM+0
        cmp #MAGIC0
        bne @no
        lda f:SRAM+1
        cmp #MAGIC1
        bne @no
        lda f:SRAM+2
        cmp #MAGIC2
        bne @no
        lda f:SRAM+3
        cmp #MAGIC3
        bne @no
        ; verify checksum
        a16
        lda #0
        sta tmp0
        a8
        ldx #0
@sum:   lda f:SRAM,x
        a16
        and #$00FF
        clc
        adc tmp0
        sta tmp0
        a8
        inx
        cpx #181
        bne @sum
        lda tmp0
        cmp f:SRAM+181
        bne @no
        lda tmp0+1
        cmp f:SRAM+182
        bne @no
        sec
        rts
@no:    clc
        rts
.endproc

; Load save into live state. Assumes SaveExists already confirmed.
.proc LoadGame
        .a8
        .i16
        ldx #0
@party: lda f:SRAM+4,x
        sta f:party,x
        inx
        cpx #160
        bne @party
        ldx #0
@inv:   lda f:SRAM+164,x
        sta f:invCount,x
        inx
        cpx #8
        bne @inv
        lda f:SRAM+172
        sta f:gems
        lda f:SRAM+173
        sta f:gems+1
        lda f:SRAM+174
        sta f:storyFlags
        lda f:SRAM+175
        sta f:storyFlags+1
        lda f:SRAM+176
        sta curMap
        lda f:SRAM+177
        sta heroX
        lda f:SRAM+178
        sta heroX+1
        lda f:SRAM+179
        sta heroY
        lda f:SRAM+180
        sta heroY+1
        rts
.endproc
