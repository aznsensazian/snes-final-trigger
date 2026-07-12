#!/usr/bin/env python3
"""Patch the SNES internal-header checksum of a LoROM image in place."""
import sys

def main(path):
    with open(path, "rb") as f:
        rom = bytearray(f.read())
    # zero out checksum fields first (complement = FFFF, sum = 0000)
    rom[0x7FDC:0x7FDE] = b"\xFF\xFF"
    rom[0x7FDE:0x7FE0] = b"\x00\x00"
    total = sum(rom) & 0xFFFF
    comp = total ^ 0xFFFF
    rom[0x7FDC] = comp & 0xFF
    rom[0x7FDD] = comp >> 8
    rom[0x7FDE] = total & 0xFF
    rom[0x7FDF] = total >> 8
    with open(path, "wb") as f:
        f.write(rom)
    print(f"fixsum: {path} size={len(rom)} checksum={total:04X}")

if __name__ == "__main__":
    main(sys.argv[1])
