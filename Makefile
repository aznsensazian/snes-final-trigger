# FINAL TRIGGER — SNES RPG build
# Requires: cc65 (ca65/ld65), python3

AS      := ca65
LD      := ld65
ASFLAGS := --cpu 65816 -s -I src --bin-include-dir assets
ROM     := finaltrigger.sfc

SRCS := $(wildcard src/*.s)
OBJS := $(patsubst src/%.s,build/%.o,$(SRCS))

.PHONY: all clean assets test

all: $(ROM)

build:
	mkdir -p build

FONT_ASSETS   := assets/font.chr assets/textpal.bin
TITLE_ASSETS  := assets/title_logo.chr assets/title_logo.map assets/title_pal.bin assets/title_grad.bin
SPRITE_ASSETS := assets/obj_hero.chr assets/objpal.bin
BATTLE_ASSETS := assets/obj_enemies.chr assets/enemypal.bin assets/battle_grad.bin
WORLD_ASSETS  := assets/world.s assets/ts0_chr.bin assets/ts0_pal.bin assets/ts0_meta.bin assets/ts0_attr.bin assets/map0.bin

$(FONT_ASSETS) &: tools/gen_font.py tools/font_data.py tools/common.py
	python3 tools/gen_font.py

$(TITLE_ASSETS) &: tools/gen_title.py tools/font_data.py tools/common.py
	python3 tools/gen_title.py

$(SPRITE_ASSETS) &: tools/gen_sprites.py tools/sprite_data.py tools/common.py
	python3 tools/gen_sprites.py

$(BATTLE_ASSETS) &: tools/gen_battle.py tools/enemy_data.py tools/common.py
	python3 tools/gen_battle.py

$(WORLD_ASSETS) &: tools/gen_world.py tools/tileart.py tools/common.py
	python3 tools/gen_world.py

build/data.o: $(FONT_ASSETS) $(TITLE_ASSETS) $(SPRITE_ASSETS) $(BATTLE_ASSETS)

build/world.o: assets/world.s $(WORLD_ASSETS) | build
	$(AS) $(ASFLAGS) -o $@ assets/world.s

OBJS += build/world.o

build/%.o: src/%.s src/regs.inc src/macros.inc src/defs.inc | build
	$(AS) $(ASFLAGS) -o $@ $<

$(ROM): $(OBJS) rom/lorom.cfg
	$(LD) -C rom/lorom.cfg -o $@ $(OBJS) -m build/map.txt -Ln build/labels.txt
	python3 tools/fixsum.py $@

clean:
	rm -rf build $(ROM)
