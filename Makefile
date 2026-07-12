# FINAL TRIGGER — SNES RPG build
# Requires: cc65 (ca65/ld65), python3

AS      := ca65
LD      := ld65
ASFLAGS := --cpu 65816 -s -I src -I assets
ROM     := finaltrigger.sfc

SRCS := $(wildcard src/*.s)
OBJS := $(patsubst src/%.s,build/%.o,$(SRCS))

.PHONY: all clean assets test

all: $(ROM)

build:
	mkdir -p build

build/%.o: src/%.s src/regs.inc src/macros.inc | build
	$(AS) $(ASFLAGS) -o $@ $<

$(ROM): $(OBJS) rom/lorom.cfg
	$(LD) -C rom/lorom.cfg -o $@ $(OBJS) -m build/map.txt
	python3 tools/fixsum.py $@

clean:
	rm -rf build $(ROM)
