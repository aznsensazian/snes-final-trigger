# FINAL TRIGGER — Crystals of Time

A complete original 16-bit RPG for the Super Nintendo (SNES), built from
scratch in 65816 assembly. It boots as a real `.sfc` ROM in any accurate
SNES emulator (snes9x, Mesen-S, bsnes/higan, Mednafen) or on hardware via
a flash cart. Inspired by the golden-age console RPGs — a time-travelling,
crystal-powered adventure with turn-based battles, random encounters,
huge boss fights, and hidden superbosses.

## The game

The Time Eater **Xethul** is devouring the Crystals that keep the ages
turning. Step through the time gate in the Kingdom of Lyra and travel
across five eras — the Present, the Middle Ages, Prehistory, the Ruined
Future, and the Rift outside time itself — to recover the four elemental
Crystals of Water, Fire, Wind, and Earth, gather a party of five heroes,
and end Xethul before history unravels.

**Features**

- **Turn-based battle system** — Attack / Tech / Magic / Item menus, a
  speed-ordered turn queue, single- and all-target skills, elemental magic,
  healing, revives, MP costs, XP and level-ups with per-hero stat growth.
- **Random encounters** on wild terrain, with per-era enemy groups.
- **Five playable heroes** — Kaen (blade), Slade (heavy blade), Tessa
  (esper mage), Wyla (primal huntress), Nix (black mage), each with their
  own tech and magic lists that unlock by level.
- **Huge boss fights** — five story bosses rendered as 64×64 sprites
  (Grask, Magmadon, Steel Warden, Terra Wyrm, and the final boss Xethul),
  each guarding a Crystal, plus **two optional superbosses** (the Chrono
  Wyrm in the Rift and the Omega Golem in the Future) for the brave.
- **10 hand-authored maps** across 5 procedurally-pixelled tilesets, with
  dialog, recruitable allies, treasure chests, healing crystals, and time
  gates linking the eras.
- **Original soundtrack** — a custom SPC700 sound driver plays 9 sequenced
  songs (title, overworld, battle, boss, victory, game-over, and three era
  themes) plus 8 sound effects, all synthesized from BRR samples.
- **Battery save** — save anywhere from the pause menu (START); Continue
  from the title screen. Uses 8 KB of cartridge SRAM.

## Play it

Point any SNES emulator at `finaltrigger.sfc`:

```sh
# examples
snes9x finaltrigger.sfc
mednafen finaltrigger.sfc
mesen finaltrigger.sfc
```

The ROM is a 1 MB LoROM image with a correct internal header and checksum,
NTSC region, ROM+RAM+battery cart type.

**Controls**

| Button        | Overworld            | Battle                     |
|---------------|----------------------|----------------------------|
| D-Pad         | Walk                 | Move cursor                |
| A / Start     | Confirm / advance    | Confirm                    |
| B             | —                    | Cancel / attempt to flee   |
| Start         | Open pause/save menu | —                          |

At the title screen choose **New Game** or **Continue** (if a save exists).
Walk into signs, people, chests, and glowing time gates to interact.

## Build from source

Requires [cc65](https://cc65.github.io/) (for `ca65` / `ld65`) and Python 3
(Pillow is only used by the optional asset-preview scripts — the ROM build
does not need it).

```sh
make            # regenerates all assets and links finaltrigger.sfc
make -j$(nproc) # same, but parallelized (asset generators + .o rules are independent)
make assets     # regenerate baked assets only, without compiling/linking
make clean
```

The build pipeline:

1. Python generators under `tools/` synthesize every asset — fonts, era
   tilesets, character/enemy/boss sprites, maps, palettes, the SPC700 audio
   image — and emit binaries plus `assets/world.s` into `assets/`.
2. `ca65` assembles the `src/*.s` sources against those binaries.
3. `ld65` links them per `rom/lorom.cfg` into the LoROM image.
4. `tools/fixsum.py` patches the internal header checksum.

Everything is generated deterministically from code; there are no binary
art assets checked in — the pixels, music, and maps are all produced by the
Python tools, so the whole game is reproducible from source.

## Project layout

```
src/            65816 assembly
  init.s        power-on setup, RAM/VRAM/OAM clear
  main.s        main loop, state dispatch, NMI, joypad, RNG
  text.s        BG3 font/window/dialog engine
  sprites.s     OAM builder
  title.s       title screen + story intro
  map.s         overworld engine: walking, collision, camera, events
  battle.s      turn-based battle engine
  battle_tables.s  hero/skill/enemy/formation/item data
  party.s       party state, XP, level-ups
  util.s        number-to-text
  audio.s       SPC700 upload + music/SFX commands
  save.s        SRAM save/load
  stubs.s       ending sequence
  data.s        asset .incbins
tools/          Python asset generators
rom/lorom.cfg   ld65 linker config (LoROM, 1 MB, 8 KB SRAM)
Makefile
```

## Technical notes

- **Video**: BG mode 1 — BG1 is the 64×64 scrolling map (4bpp), BG3 the
  text/HUD layer (2bpp), sprites for the hero, party, enemies, and bosses.
  Title and battle backdrops use an HDMA colour gradient. All VRAM/CGRAM/OAM
  updates are DMA'd during vblank from the NMI handler.
- **Audio**: a hand-assembled SPC700 driver (see `tools/spc_driver.py`) is
  uploaded through the IPL boot ROM protocol, then driven by a one-byte
  command mailbox through the APU I/O ports. It runs a 64 Hz sequencer over
  four music channels plus one SFX channel.
- **Verification**: the game was developed against a headless build of the
  LakeSnes emulator core, driving scripted controller input and capturing
  framebuffer screenshots and audio for automated checking of every system.

## Credits

Original game, code, pixel art, maps, and music — all synthesized from the
generators in this repository. Built as a demonstration of a full,
playable, from-scratch SNES RPG.
