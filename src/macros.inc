; ---------------------------------------------------------------------------
; Common macros: register width control and helpers.
; Convention: outside of interrupt save/restore, code keeps X/Y 16-bit and
; switches A between 8/16 as needed.
; ---------------------------------------------------------------------------

.macro a8
        sep #$20
.endmacro

.macro a16
        rep #$20
.endmacro

.macro i8
        sep #$10
.endmacro

.macro i16
        rep #$10
.endmacro

.macro ai8
        sep #$30
.endmacro

.macro ai16
        rep #$30
.endmacro

; load 16-bit immediate into X even when unsure of width (X always 16 here)
.macro ldx16 val
        ldx #val
.endmacro

; DMA a block to VRAM. Clobbers A (8-bit on exit), assumes force-blank or vblank.
; args: source label (24-bit), word address in VRAM, byte count
.macro DmaToVram src, vaddr, count
        a8
        lda #$80
        sta VMAIN               ; increment on high byte write
        a16
        lda #vaddr
        sta VMADDL
        lda #$1801              ; two-register write to $2118/19, incrementing
        sta DMAP0
        lda #.loword(src)
        sta A1T0L
        a8
        lda #^src
        sta A1B0
        a16
        lda #count
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN
.endmacro

; Widen an 8-bit byte value to 16-bit and multiply by 3 (table index for
; 3-byte-per-entry tables, e.g. long pointer tables). Input: 8-bit value
; already loaded in A (accumulator 8-bit on entry). Output: X = value*3,
; A left 16-bit. Clobbers A/tmp0, assumes tmp0 is available as scratch.
.macro WidenMul3
        a16
        and #$00FF
        sta tmp0
        asl
        clc
        adc tmp0
        tax
.endmacro

; DMA a block to CGRAM. args: source, starting color index, byte count
.macro DmaToCgram src, cstart, count
        a8
        lda #cstart
        sta CGADD
        a16
        lda #$2200              ; one register $2122
        sta DMAP0
        lda #.loword(src)
        sta A1T0L
        a8
        lda #^src
        sta A1B0
        a16
        lda #count
        sta DAS0L
        a8
        lda #$01
        sta MDMAEN
.endmacro
