; ---------------------------------------------------------------------------
; Asset data banks (.incbin of generated files in assets/)
; ---------------------------------------------------------------------------

.segment "BANK1"
.export FontChr, FontChrEnd, TextPal
.export TitleChr, TitleChrEnd, TitleMap, TitlePal, TitleGrad

FontChr:     .incbin "font.chr"
FontChrEnd:
TextPal:     .incbin "textpal.bin"
TitleChr:    .incbin "title_logo.chr"
TitleChrEnd:
TitleMap:    .incbin "title_logo.map"
TitlePal:    .incbin "title_pal.bin"
TitleGrad:   .incbin "title_grad.bin"

.export HeroObjChr, HeroObjChrEnd, ObjPal
HeroObjChr:  .incbin "obj_hero.chr"
HeroObjChrEnd:
ObjPal:      .incbin "objpal.bin"

.export EnemyObjChr, EnemyPal, BattleGrad
EnemyObjChr: .incbin "obj_enemies.chr"
EnemyPal:    .incbin "enemypal.bin"
BattleGrad:  .incbin "battle_grad.bin"

.segment "BANK6"
.export AudioBin, AudioBinEnd
AudioBin:    .incbin "audio.bin"
AudioBinEnd:

.segment "BANK8"
.export BossChr, BossPals
BossChr:  .incbin "boss.chr"
BossPals: .incbin "bosspal.bin"
