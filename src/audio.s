; ---------------------------------------------------------------------------
; Audio: uploads the SPC700 driver+data image via the IPL ROM protocol,
; then sends play-song / play-sfx commands through the APU ports.
; Command byte: high nibble = rolling sequence (1-15), low nibble = command:
;   1 = play song (port1 = id), 2 = play sfx (port1 = id), 3 = stop music
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "audio.inc"

.export AudioInit, PlaySong, PlaySfx, StopMusic
.import AudioBin, AudioBinEnd

.segment "ZEROPAGE"
spcSeq:  .res 1                 ; rolling high nibble
sfxCool: .res 1                 ; unused reserve

.segment "CODE"

; ---------------------------------------------------------------------------
; Upload audio image and start the driver. Call once at boot (NMI off).
.proc AudioInit
        .a8
        .i16
        ; wait for IPL ready signature
@sig:   lda APUIO0
        cmp #$AA
        bne @sig
        lda APUIO1
        cmp #$BB
        bne @sig

        ; begin transfer to SPC_LOAD_ADDR
        lda #$01
        sta APUIO1
        ldx #SPC_LOAD_ADDR
        stx APUIO2              ; 16-bit? X is 16-bit but sta... use two stores
        ; (stx to $2142 writes 16-bit only if index regs 16-bit: yes, stx abs
        ;  writes low to $2142 and high to $2143)
        lda #$CC
        sta APUIO0
@ack:   cmp APUIO0
        bne @ack

        ; byte loop
        ldx #0
@lp:    lda f:AudioBin,x
        sta APUIO1
        txa                     ; low byte of index
        sta APUIO0
@e:     cmp APUIO0
        bne @e
        inx
        cpx #(AudioBinEnd-AudioBin)
        bne @lp

        ; terminate + jump to entry
        ldy #SPC_ENTRY
        sty APUIO2
        stz APUIO1
        txa
        inc
        sta APUIO0
@j:     cmp APUIO0
        bne @j

        stz spcSeq
        stz APUIO0              ; settle port0 at 0 so first command differs
        rts
.endproc

; ---------------------------------------------------------------------------
; internal: send command (low nibble in tmp) with param A.
.proc sendCmd
        .a8
        .i16
        sta APUIO1              ; param
        lda spcSeq
        clc
        adc #$10
        bne :+
        lda #$10
:       sta spcSeq
        ora cmdNib
        sta APUIO0
        ; wait for echo (bounded)
        ldx #800
@w:     cmp APUIO0
        beq @done
        dex
        bne @w
@done:  rts
.endproc

.segment "ZEROPAGE"
cmdNib: .res 1

.segment "CODE"

.proc PlaySong
        .a8
        .i16
        pha
        lda #$01
        sta cmdNib
        pla
        jsr sendCmd
        rts
.endproc

.proc PlaySfx
        .a8
        .i16
        pha
        lda #$02
        sta cmdNib
        pla
        jsr sendCmd
        rts
.endproc

.proc StopMusic
        .a8
        .i16
        lda #$03
        sta cmdNib
        lda #$00
        jsr sendCmd
        rts
.endproc
