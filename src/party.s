; ---------------------------------------------------------------------------
; Party state: 5 heroes, inventory, gems. Persists across battles;
; serialized to SRAM by the save system.
;
; Hero record (32 bytes):
;  +0 flags (bit0 recruited)  +1 level
;  +2 hp  +4 maxhp  +6 mp  +8 maxmp        (words)
;  +10 atk +11 def +12 mag +13 spd
;  +14 xp toward next level (word)
; ---------------------------------------------------------------------------
.include "regs.inc"
.include "macros.inc"
.include "defs.inc"

.export PartyInit, PartyRecruit, PartyGiveXp, HeroLevelUp, PartyAliveMask
.export party, invCount, gems
.import HeroBase
.importzp tmp0, tmp1, tmp2, tmp3

PT_FLAGS = 0
PT_LVL   = 1
PT_HP    = 2
PT_MAXHP = 4
PT_MP    = 6
PT_MAXMP = 8
PT_ATK   = 10
PT_DEF   = 11
PT_MAG   = 12
PT_SPD   = 13
PT_XP    = 14
.export PT_FLAGS, PT_LVL, PT_HP, PT_MAXHP, PT_MP, PT_MAXMP
.export PT_ATK, PT_DEF, PT_MAG, PT_SPD, PT_XP

.segment "HIBSS"
party:    .res 160              ; 5 * 32
invCount: .res 8
gems:     .res 2

.segment "ZEROPAGE"
.exportzp lvlUpMask
lvlUpMask: .res 1               ; bit i set when hero i leveled in last GiveXp

.segment "CODE"

; ---------------------------------------------------------------------------
; New game: zero everything, recruit hero 0 (Kaen), starter items.
.proc PartyInit
        .a8
        .i16
        php
        ai16
        ldx #0
        lda #0
@cl:    sta f:party,x
        inx
        inx
        cpx #170
        bcc @cl
        plp
        .a8
        .i16
        lda #0
        jsr PartyRecruit
        lda #2                  ; Tessa joins from the festival
        jsr PartyRecruit
        ; starter inventory: 4 potions, 1 ether, 1 revive
        lda #4
        sta f:invCount
        lda #1
        sta f:invCount+2
        lda #1
        sta f:invCount+3
        ; starting gems
        lda #50
        sta f:gems
        lda #0
        sta f:gems+1
        rts
.endproc

; ---------------------------------------------------------------------------
; Recruit hero A (0-4) at level 1 with base stats from HeroBase.
.proc PartyRecruit
        .a8
        .i16
        sta tmp0
        a16
        lda #0
        a8
        lda tmp0
        a16
        asl
        asl
        asl
        asl                     ; hero*16
        sta tmp1
        asl                     ; hero*32
        tax
        lda tmp1
        clc
        adc #.loword(HeroBase)
        tay                     ; Y = &HeroBase[hero]
        a8
        lda #1
        sta f:party+PT_FLAGS,x
        sta f:party+PT_LVL,x
        ; maxhp/hp = baseHp
        a16
        lda #0
        a8
        lda a:0,y
        a16
        and #$00FF
        sta f:party+PT_MAXHP,x
        sta f:party+PT_HP,x
        ; maxmp/mp = baseMp
        lda #0
        a8
        lda a:1,y
        a16
        and #$00FF
        sta f:party+PT_MAXMP,x
        sta f:party+PT_MP,x
        a8
        lda a:2,y
        sta f:party+PT_ATK,x
        lda a:3,y
        sta f:party+PT_DEF,x
        lda a:4,y
        sta f:party+PT_MAG,x
        lda a:5,y
        sta f:party+PT_SPD,x
        a16
        lda #0
        sta f:party+PT_XP,x
        a8
        rts
.endproc

; ---------------------------------------------------------------------------
; Give A(16 in tmp2) xp to every recruited+alive hero; sets lvlUpMask.
.proc PartyGiveXp
        .a8
        .i16
        stz lvlUpMask
        ldx #0                  ; hero offset
        stz tmp3                ; hero index
@hero:  lda f:party+PT_FLAGS,x
        and #$01
        beq @next
        a16
        lda f:party+PT_HP,x
        beq @next16             ; dead heroes gain nothing
        lda f:party+PT_XP,x
        clc
        adc tmp2
        sta f:party+PT_XP,x
        a8
@chk:   jsr needXp              ; -> tmp0 = xp needed at current level
        a16
        lda f:party+PT_XP,x
        cmp tmp0
        bcc @next16
        sec
        sbc tmp0
        sta f:party+PT_XP,x
        a8
        jsr HeroLevelUp
        ; set mask bit
        lda tmp3
        a16
        and #$00FF
        tay
        a8
        lda a:bitTab,y
        ora lvlUpMask
        sta lvlUpMask
        bra @chk
@next16:
        a8
@next:  a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp3
        lda tmp3
        cmp #5
        bcc @hero
        rts
bitTab: .byte 1,2,4,8,16
.endproc

; xp needed to go from current level (of hero at X) to next: 4*L*L + 12*L
.proc needXp
        .a8
        .i16
        lda f:party+PT_LVL,x
        sta WRMPYA
        sta WRMPYB
        nop
        nop
        nop
        nop
        a16
        lda RDMPYL              ; L*L
        asl
        asl                     ; 4*L*L
        sta tmp0
        lda #0
        a8
        lda f:party+PT_LVL,x
        a16
        asl
        asl
        asl
        asl                     ; L*16 -> close enough to L*12; use 12: L*8+L*4
        lsr                     ; L*8
        sta tmp1
        lsr                     ; L*4
        clc
        adc tmp1                ; L*12
        clc
        adc tmp0
        sta tmp0
        a8
        rts
.endproc

; ---------------------------------------------------------------------------
; Level up hero at party offset X: level+1, apply growth, refill hp/mp.
.proc HeroLevelUp
        .a8
        .i16
        lda f:party+PT_LVL,x
        inc
        sta f:party+PT_LVL,x
        ; growth table: HeroBase + heroIdx*16, growth at +6
        ; heroIdx = X / 32
        phx
        a16
        txa                     ; X = hero*32 (party-relative)
        lsr                     ; hero*16
        clc
        adc #.loword(HeroBase)
        tay
        a8
        plx
        ; hp += gHp
        a16
        lda #0
        a8
        lda a:6,y               ; gHp   (absolute indexed via Y needs DB=0; use lda (0,y)? no)
        a16
        and #$00FF
        clc
        adc f:party+PT_MAXHP,x
        sta f:party+PT_MAXHP,x
        sta f:party+PT_HP,x
        lda #0
        a8
        lda a:7,y               ; gMp
        a16
        and #$00FF
        clc
        adc f:party+PT_MAXMP,x
        sta f:party+PT_MAXMP,x
        sta f:party+PT_MP,x
        a8
        lda f:party+PT_ATK,x
        clc
        adc a:8,y
        sta f:party+PT_ATK,x
        lda f:party+PT_DEF,x
        clc
        adc a:9,y
        sta f:party+PT_DEF,x
        lda f:party+PT_MAG,x
        clc
        adc a:10,y
        sta f:party+PT_MAG,x
        lda f:party+PT_SPD,x
        clc
        adc a:11,y
        sta f:party+PT_SPD,x
        rts
.endproc

; ---------------------------------------------------------------------------
; A = bitmask of recruited heroes with hp > 0.
.proc PartyAliveMask
        .a8
        .i16
        stz tmp0
        stz tmp1                ; index
        ldx #0
@lp:    lda f:party+PT_FLAGS,x
        and #$01
        beq @next
        a16
        lda f:party+PT_HP,x
        beq @next16
        a8
        lda tmp1
        a16
        and #$00FF
        tay
        a8
        lda a:bitTab,y
        ora tmp0
        sta tmp0
        bra @next
@next16:
        a8
@next:  a16
        txa
        clc
        adc #32
        tax
        a8
        inc tmp1
        lda tmp1
        cmp #5
        bcc @lp
        lda tmp0
        rts
bitTab: .byte 1,2,4,8,16
.endproc
