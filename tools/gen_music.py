#!/usr/bin/env python3
"""Build the complete SPC700 audio image: driver + samples + songs + sfx.
Outputs assets/audio.bin (raw image loaded at $0100) and assets/audio.inc
(load address / size / entry constants for the 65816 uploader)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from spc_driver import (build_driver, DIR_ADDR, PITCH_ADDR, INSTA1_ADDR,
                        INSTA2_ADDR, CODE_ADDR, DATA_ADDR)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

# ---------------------------------------------------------------------------
# BRR encoding (filter 0, range 12: nibble -8..7 -> sample n<<12>>1)
# ---------------------------------------------------------------------------
def brr_block(samples16, loop, end):
    """samples16: 16 ints in -8..7"""
    hdr = (12 << 4) | (0 << 2) | ((1 if loop else 0) << 1) | (1 if end else 0)
    out = bytearray([hdr])
    for i in range(0, 16, 2):
        hi = samples16[i] & 0xF
        lo = samples16[i + 1] & 0xF
        out.append((hi << 4) | lo)
    return bytes(out)

def sample_square():
    return brr_block([6] * 8 + [-6] * 8, loop=True, end=True)

def sample_triangle():
    # 32-sample triangle: 2 blocks (sounds one octave lower than table pitch)
    ramp = []
    for i in range(32):
        t = i / 32.0
        v = 4 * t if t < 0.25 else (2 - 4 * t if t < 0.75 else 4 * t - 4)
        ramp.append(max(-8, min(7, round(v * 7))))
    return brr_block(ramp[:16], True, False) + brr_block(ramp[16:], True, True)

def sample_saw():
    return brr_block([round(-8 + 15 * i / 15) for i in range(16)], True, True)

def sample_noise():
    # decaying noise burst, 24 blocks (384 samples), one-shot
    import random
    rng = random.Random(1234)
    out = b""
    blocks = 24
    for b in range(blocks):
        amp = max(1, round(7 * (1 - b / blocks)))
        blk = [rng.randint(-amp, amp) for _ in range(16)]
        out += brr_block(blk, False, b == blocks - 1)
    return out

# instrument ADSR (a1, a2): a1 = $80|dcy<<4|atk, a2 = sustain<<5|srate
INSTRUMENTS = [
    (0x8F, 0xE0),   # 0 square lead: fast attack, high sustain
    (0x8F, 0xF0),   # 1 triangle bass: full sustain
    (0x8E, 0xC8),   # 2 saw pad: slight decay
    (0x8F, 0xE6),   # 3 noise drum: decays via sample itself
]

# ---------------------------------------------------------------------------
# note helpers
# ---------------------------------------------------------------------------
NOTE_IDX = {n: i for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}

def N(name):
    """'A4' -> semitone index from C1 (=1). 0 is reserved for rest."""
    if name == "R":
        return 0
    octv = int(name[-1])
    key = name[:-1]
    return (octv - 1) * 12 + NOTE_IDX[key] + 1

def pitch_for(semi):
    """semitone index (1 = C1) -> DSP pitch for 16-sample loop at 32kHz."""
    f = 32.7032 * (2 ** ((semi - 1) / 12.0))
    return min(0x3FFF, round(f * 2.048))

# stream builder ------------------------------------------------------------
def stream(events, loop=True):
    """events: list of tuples:
       ('i', n) instrument, ('v', n) volume, (note_name, ticks) note/rest"""
    out = bytearray()
    for ev in events:
        if ev[0] == "i":
            out += bytes([0xFD, ev[1]])
        elif ev[0] == "v":
            out += bytes([0xFC, ev[1]])
        else:
            note, dur = ev
            while dur > 255:
                out += bytes([N(note), 255])
                note = "R" if note == "R" else note  # sustain split as re-key
                dur -= 255
            out += bytes([N(note), dur])
    out += bytes([0xFF if loop else 0xFE])
    return bytes(out)

# ---------------------------------------------------------------------------
# songs (tick = 1/64 s; 8 ticks = 1/8 note at 120bpm -> Q=16)
# ---------------------------------------------------------------------------
Q = 16          # quarter
E = 8           # eighth
S = 4           # sixteenth
H = 32          # half
W = 64          # whole

def song_title():
    mel = [("i", 0), ("v", 40)]
    line = [
        ("A4", Q), ("C5", Q), ("E5", Q), ("C5", Q),
        ("B4", Q), ("E5", Q), ("G5", H),
        ("A5", Q + E), ("G5", E), ("E5", Q), ("C5", Q),
        ("D5", H), ("B4", H),
        ("F4", Q), ("A4", Q), ("C5", Q), ("A4", Q),
        ("G4", Q), ("C5", Q), ("E5", H),
        ("D5", Q + E), ("C5", E), ("B4", Q), ("G4", Q),
        ("A4", W),
    ]
    mel += line
    harm = [("i", 2), ("v", 18)]
    chords = ["A3", "E3", "F3", "G3", "F3", "C4", "D3", "E3"]
    for c in chords:
        harm.append((c, W))
    bass = [("i", 1), ("v", 46)]
    roots = ["A3", "E3", "F3", "G3", "F3", "C3", "D3", "E3"]
    for r in roots:
        bass += [(r, H), ("R", E), (r, H - E)]
    drum = [("i", 3), ("v", 26)]
    for _ in range(8):
        drum += [("C3", Q), ("R", Q), ("C3", Q), ("R", Q)]
    return [stream(mel), stream(harm), stream(bass), stream(drum)]

def song_overworld():
    mel = [("i", 0), ("v", 42)]
    line = [
        ("C5", E), ("D5", E), ("E5", Q), ("G5", Q), ("E5", Q),
        ("F5", Q), ("E5", E), ("D5", E), ("C5", H),
        ("D5", E), ("E5", E), ("F5", Q), ("A5", Q), ("F5", Q),
        ("G5", Q), ("F5", E), ("E5", E), ("D5", H),
        ("E5", Q), ("G5", Q), ("C6", Q), ("B5", E), ("A5", E),
        ("G5", Q), ("A5", E), ("B5", E), ("C6", H),
        ("A5", Q), ("F5", Q), ("G5", Q), ("E5", Q),
        ("D5", Q), ("F5", E), ("D5", E), ("C5", H),
    ]
    mel += line
    harm = [("i", 2), ("v", 16)]
    for c in ["C4", "F3", "G3", "C4", "A3", "F3", "G3", "C4"]:
        harm.append((c, W))
    bass = [("i", 1), ("v", 48)]
    for r in ["C3", "F3", "G3", "C3", "A3", "F3", "G3", "C3"]:
        bass += [(r, Q), (r, E), ("R", E), (r, Q), (r, Q)]
    drum = [("i", 3), ("v", 22)]
    for _ in range(8):
        drum += [("C3", Q), ("C4", E), ("R", E), ("C3", E), ("R", E), ("C4", Q)]
    return [stream(mel), stream(harm), stream(bass), stream(drum)]

def song_battle():
    mel = [("i", 0), ("v", 44)]
    line = [
        ("D5", S), ("R", S), ("D5", S), ("R", S), ("F5", E), ("D5", E),
        ("G5", E), ("F5", E), ("D5", E), ("C5", E),
        ("D5", S), ("R", S), ("D5", S), ("R", S), ("A5", E), ("G5", E),
        ("A#5", E), ("A5", E), ("G5", E), ("F5", E),
        ("E5", E), ("F5", E), ("G5", Q), ("E5", E), ("C5", E),
        ("D5", E), ("E5", E), ("F5", Q), ("D5", Q),
        ("A4", E), ("C5", E), ("D5", Q), ("F5", E), ("E5", E),
        ("D5", Q), ("C5", E), ("A4", E), ("D5", Q),
    ]
    mel += line
    harm = [("i", 2), ("v", 15)]
    for c in ["D4", "D4", "A#3", "C4", "D4", "D4", "A#3", "C4"]:
        harm.append((c, H))
    bass = [("i", 1), ("v", 52)]
    for r in ["D3", "D3", "A#2", "C3"] * 2:
        bass += [(r, E), (r, E), ("R", S), (r, S), (r, E)]
    drum = [("i", 3), ("v", 30)]
    for _ in range(8):
        drum += [("C3", E), ("C4", E), ("C3", S), ("C3", S), ("C4", E)]
    return [stream(mel), stream(harm), stream(bass), stream(drum)]

def song_victory():
    mel = [("i", 0), ("v", 46),
           ("C5", S + 2), ("C5", S + 2), ("C5", S + 2), ("C5", Q),
           ("G#4", Q), ("A#4", Q), ("C5", Q + E), ("A#4", S), ("C5", H + Q)]
    harm = [("i", 2), ("v", 20),
            ("E4", S + 2), ("E4", S + 2), ("E4", S + 2), ("E4", Q),
            ("F4", Q), ("G4", Q), ("E4", Q + E), ("G4", S), ("E4", H + Q)]
    bass = [("i", 1), ("v", 50),
            ("C3", Q + S + S), ("C3", Q), ("C3", Q),
            ("G#2", Q), ("A#2", Q), ("C3", W)]
    return [stream(mel, loop=False), stream(harm, loop=False),
            stream(bass, loop=False), stream([("v", 0), ("R", 4)], loop=False)]

def song_gameover():
    mel = [("i", 0), ("v", 34),
           ("A4", H), ("G4", H), ("F4", H), ("E4", H + Q),
           ("D4", H), ("E4", Q), ("F4", H), ("E4", W), ("R", W)]
    bass = [("i", 1), ("v", 44),
            ("A2", W), ("F2", W), ("D2", W), ("E2", W + W), ("R", W)]
    return [stream(mel, loop=False), stream([("v", 0), ("R", 4)], loop=False),
            stream(bass, loop=False), stream([("v", 0), ("R", 4)], loop=False)]

def song_mystery():
    mel = [("i", 2), ("v", 24)]
    for _ in range(2):
        mel += [
            ("E4", Q), ("B4", Q), ("F#5", H),
            ("D#5", Q), ("B4", Q), ("F#4", H),
            ("G4", Q), ("D5", Q), ("A5", H),
            ("F#5", Q), ("D5", Q), ("A4", H),
        ]
    bass = [("i", 1), ("v", 40)]
    for _ in range(2):
        for r in ["E3", "B2", "G3", "D3"]:
            bass += [(r, W)]
    return [stream(mel), stream([("v", 0), ("R", 8)]), stream(bass),
            stream([("v", 0), ("R", 8)])]

def song_primal():
    mel = [("i", 0), ("v", 40)]
    line = [
        ("E5", E), ("G5", E), ("E5", E), ("D5", E), ("E5", Q), ("G4", Q),
        ("A4", E), ("C5", E), ("A4", E), ("G4", E), ("A4", H),
        ("E5", E), ("G5", E), ("A5", E), ("G5", E), ("E5", Q), ("D5", Q),
        ("C5", E), ("D5", E), ("E5", E), ("D5", E), ("A4", H),
    ]
    mel += line
    bass = [("i", 1), ("v", 52)]
    for r in ["A3", "A3", "G3", "A3"] * 2:
        bass += [(r, E), (r, S), (r, S), ("R", E), (r, E)]
    drum = [("i", 3), ("v", 34)]
    for _ in range(8):
        drum += [("C3", E), ("C3", S), ("C3", S), ("C4", E), ("C3", E),
                 ("C4", S), ("C4", S), ("C3", E), ("C4", E)]
    return [stream(mel), stream([("v", 0), ("R", 8)]), stream(bass), stream(drum)]

def song_ruins():
    mel = [("i", 2), ("v", 26)]
    for _ in range(2):
        mel += [
            ("D5", Q), ("A4", Q), ("F4", H),
            ("E4", Q), ("A4", Q), ("C#5", H),
            ("D5", Q), ("F5", Q), ("E5", H),
            ("A4", Q), ("C#5", Q), ("D4", H),
        ]
    harm = [("i", 0), ("v", 14)]
    for _ in range(4):
        harm += [("D4", E), ("A4", E), ("F4", E), ("A4", E)] * 4
    bass = [("i", 1), ("v", 44)]
    for _ in range(2):
        for r in ["D3", "A2", "F2", "A2"]:
            bass += [(r, W)]
    return [stream(mel), stream(harm), stream(bass), stream([("v", 0), ("R", 8)])]

def song_final():
    mel = [("i", 0), ("v", 44)]
    line = [
        ("C5", E), ("C5", E), ("D#5", Q), ("C5", E), ("F#4", E), ("G4", H),
        ("C5", E), ("C5", E), ("D#5", Q), ("F5", E), ("F#5", E), ("G5", H),
        ("G#5", Q), ("G5", Q), ("F5", Q), ("D#5", Q),
        ("D5", E), ("D#5", E), ("D5", E), ("C5", E), ("C5", H),
    ]
    mel += line
    harm = [("i", 2), ("v", 18)]
    for c in ["C4", "F#3", "G#3", "G3"] * 2:
        harm.append((c, H))
    bass = [("i", 1), ("v", 54)]
    for r in ["C3", "F#2", "G#2", "G2"] * 2:
        bass += [(r, E), (r, E), (r, E), ("R", E)]
    drum = [("i", 3), ("v", 30)]
    for _ in range(8):
        drum += [("C3", Q), ("C4", E), ("C3", E), ("C4", Q), ("C3", E), ("C4", E)]
    return [stream(mel), stream(harm), stream(bass), stream(drum)]

SONGS = [song_title, song_overworld, song_battle, song_victory,
         song_gameover, song_mystery, song_primal, song_ruins, song_final]

# sfx ------------------------------------------------------------------------
def sfx_cursor():
    return stream([("i", 0), ("v", 34), ("A5", 2)], loop=False)

def sfx_confirm():
    return stream([("i", 0), ("v", 38), ("C5", 3), ("G5", 5)], loop=False)

def sfx_cancel():
    return stream([("i", 0), ("v", 34), ("E4", 3), ("C4", 4)], loop=False)

def sfx_hit():
    return stream([("i", 3), ("v", 56), ("C4", 6)], loop=False)

def sfx_heal():
    return stream([("i", 0), ("v", 36), ("C5", 3), ("E5", 3), ("G5", 3),
                   ("C6", 6)], loop=False)

def sfx_encounter():
    return stream([("i", 2), ("v", 44), ("C5", 2), ("B4", 2), ("A#4", 2),
                   ("A4", 2), ("G#4", 2), ("G4", 3)], loop=False)

def sfx_gate():
    return stream([("i", 2), ("v", 40), ("C4", 3), ("E4", 3), ("G4", 3),
                   ("C5", 3), ("E5", 3), ("G5", 3), ("C6", 8)], loop=False)

def sfx_levelup():
    return stream([("i", 0), ("v", 40), ("C5", 4), ("E5", 4), ("G5", 4),
                   ("C6", 10)], loop=False)

SFX = [sfx_cursor, sfx_confirm, sfx_cancel, sfx_hit, sfx_heal,
       sfx_encounter, sfx_gate, sfx_levelup]

# ---------------------------------------------------------------------------
def main():
    os.makedirs(OUT, exist_ok=True)

    # place data region
    data = bytearray()
    base = DATA_ADDR
    songtab_addr = base
    NSONG = 12
    ptr = base + NSONG * 2 + 16
    sfxtab_addr = base + NSONG * 2

    song_ptrs = []
    blobs = []
    for fn in SONGS:
        streams = fn()
        # header: 4 words
        hdr_addr = ptr
        chunk = bytearray(8)
        ptr += 8
        offs = []
        for s in streams:
            offs.append(ptr)
            ptr += len(s)
        for i, off in enumerate(offs):
            chunk[i * 2] = off & 0xFF
            chunk[i * 2 + 1] = off >> 8
        for s in streams:
            chunk += s
        blobs.append(chunk)
        song_ptrs.append(hdr_addr)
    while len(song_ptrs) < NSONG:
        song_ptrs.append(0)

    sfx_ptrs = []
    for fn in SFX:
        s = fn()
        sfx_ptrs.append(ptr)
        blobs.append(bytearray(s))
        ptr += len(s)
    while len(sfx_ptrs) < 8:
        sfx_ptrs.append(0)

    # samples
    samples = [sample_square(), sample_triangle(), sample_saw(), sample_noise()]
    sample_addrs = []
    for s in samples:
        sample_addrs.append(ptr)
        blobs.append(bytearray(s))
        ptr += len(s)

    if ptr > 0xF000:
        raise ValueError("audio image too large")

    # assemble data region
    for p in song_ptrs:
        data += p.to_bytes(2, "little")
    for p in sfx_ptrs:
        data += p.to_bytes(2, "little")
    for b in blobs:
        data += b

    # driver
    code, labels = build_driver(songtab_addr, sfxtab_addr)
    if CODE_ADDR + len(code) > DATA_ADDR:
        raise ValueError(f"driver too big: {len(code)}")

    # build full image from $0100
    img_lo = 0x0100
    img = bytearray(DATA_ADDR + len(data) - img_lo)
    # sample directory
    for i, sa in enumerate(sample_addrs):
        off = (DIR_ADDR - img_lo) + i * 4
        img[off:off + 2] = sa.to_bytes(2, "little")
        img[off + 2:off + 4] = sa.to_bytes(2, "little")  # loop = start
    # pitch table (96 notes, entry 0 unused=0)
    for n in range(96):
        p = pitch_for(n) if n > 0 else 0
        off = (PITCH_ADDR - img_lo) + n * 2
        img[off:off + 2] = p.to_bytes(2, "little")
    # instrument tables
    for i, (a1, a2) in enumerate(INSTRUMENTS):
        img[(INSTA1_ADDR - img_lo) + i] = a1
        img[(INSTA2_ADDR - img_lo) + i] = a2
    # driver code
    img[(CODE_ADDR - img_lo):(CODE_ADDR - img_lo) + len(code)] = code
    # data region
    img[(DATA_ADDR - img_lo):] = data

    with open(os.path.join(OUT, "audio.bin"), "wb") as f:
        f.write(img)
    with open(os.path.join(OUT, "audio.inc"), "w") as f:
        f.write("; AUTO-GENERATED by tools/gen_music.py\n")
        f.write(f"SPC_LOAD_ADDR = ${img_lo:04X}\n")
        f.write(f"SPC_ENTRY = ${CODE_ADDR:04X}\n")
    print(f"audio.bin: {len(img)} bytes, driver {len(code)} bytes, "
          f"data {len(data)} bytes")

if __name__ == "__main__":
    main()
