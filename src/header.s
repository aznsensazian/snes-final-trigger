; ---------------------------------------------------------------------------
; SNES internal ROM header + CPU vectors
; ---------------------------------------------------------------------------
.import Reset, NmiHandler, IrqHandler

.segment "HEADER"
        ; $FFB0: expanded header
        .byte "FT"              ; maker code
        .byte "FTRG"            ; game code
        .res  6, $00            ; reserved
        .byte $00               ; expansion flash
        .byte $00               ; expansion RAM
        .byte $00               ; special version
        .byte $00               ; cart sub-number
        ; $FFC0: 21-byte title, padded with spaces
        .byte "FINAL TRIGGER        "
        ; $FFD5: map mode: slow LoROM
        .byte $20
        ; $FFD6: cart type: ROM + RAM + battery
        .byte $02
        ; $FFD7: ROM size: 1MB = $0A
        .byte $0A
        ; $FFD8: RAM size: 8KB = $03
        .byte $03
        ; $FFD9: country: USA/NTSC
        .byte $01
        ; $FFDA: developer
        .byte $00
        ; $FFDB: version
        .byte $00
        ; $FFDC: checksum complement / checksum (patched by tools/fixsum.py)
        .word $FFFF
        .word $0000

.segment "VECTORS"
        ; native mode vectors
        .word 0, 0              ; $FFE0-$FFE3 unused
        .word UnusedVec         ; COP
        .word UnusedVec         ; BRK
        .word UnusedVec         ; ABORT
        .word NmiHandler        ; NMI
        .word 0                 ; unused
        .word IrqHandler        ; IRQ
        ; emulation mode vectors
        .word 0, 0              ; $FFF0-$FFF3 unused
        .word UnusedVec         ; COP
        .word 0                 ; unused
        .word UnusedVec         ; ABORT
        .word UnusedVec         ; NMI (emulation)
        .word Reset             ; RESET
        .word UnusedVec         ; IRQ/BRK (emulation)

.segment "CODE"
UnusedVec:
        rti
