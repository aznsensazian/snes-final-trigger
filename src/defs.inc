; ---------------------------------------------------------------------------
; Shared game constants
; ---------------------------------------------------------------------------

; game states
ST_TITLE    = 0
ST_INTRO    = 1
ST_MAP      = 2
ST_BATTLE   = 3
ST_GAMEOVER = 4
ST_ENDING   = 5

; VRAM layout (word addresses)
VRAM_BG3CHR = $0000
VRAM_BG3MAP = $0800
VRAM_BGCHR  = $1000             ; BG1/BG2 4bpp tiles
VRAM_BG1MAP = $4000             ; 64x64
VRAM_BG2MAP = $5000             ; 64x64
VRAM_OBJCHR = $6000

; BG register values matching the layout above
V_BG1SC_64  = $43               ; $4000, 64x64
V_BG1SC_32  = $40               ; $4000, 32x32
V_BG2SC_64  = $53
V_BG3SC     = $08               ; $0800, 32x32
V_BG12NBA   = $11
V_BG34NBA   = $00
V_OBSEL     = $03               ; 8x8 + 16x16, chr at $6000
V_OBSEL_BIG = $63               ; 16x16 + 32x32, chr at $6000

; font UI tile indices (see tools/font_data.py)
TILE_CURSOR   = 95
TILE_WIN      = 96              ; tl,t,tr,l,fill,r,bl,b,br
TILE_BARFULL  = 105
TILE_BAREMPTY = 106
TILE_ARROWDN  = 107
TILE_NOTE     = 108
TILE_CRYSTAL  = 109
TILE_OSPACE   = 128             ; opaque space (window background)
