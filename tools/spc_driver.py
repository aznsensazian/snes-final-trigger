"""SPC700 sound driver, hand-assembled via a tiny byte-emitter DSL.

Memory map (SPC RAM):
  $0100  sample directory (4 bytes per sample)
  $0140  pitch table (96 words, C1..B8)
  $0208  instrument ADSR tables (a1[4], a2[4] parallel)
  $0280  driver code
  $0600  song table (8 words) then song/sfx data, then BRR samples

Sequence format (per channel stream):
  $FF        end -> loop channel from its start
  $FE        halt channel (one-shot songs / sfx end)
  $FD nn     set instrument nn (0-3)
  $FC nn     set volume nn (both sides)
  $00 dd     rest for dd ticks (key off)
  $01-$7F dd note (semitones from C1) for dd ticks (key on)

Channels: slots 0-3 = music on voices 0-3, slot 4 = sfx on voice 6.
Tick = timer0 at 64 Hz (divider 125).

Driver zero page:
  $04/$05 stream work pointer
  $08 konMask  $09 kofMask  $0A tmp  $0B last cmd byte  $0C tick count
  $10+X ptrL   $18+X ptrH   $20+X startL  $28+X startH  $30+X wait
"""

DIR_ADDR    = 0x0100
PITCH_ADDR  = 0x0140
INSTA1_ADDR = 0x0208
INSTA2_ADDR = 0x0210
CODE_ADDR   = 0x0280
DATA_ADDR   = 0x0600


class Asm:
    def __init__(self, org):
        self.org = org
        self.out = bytearray()
        self.labels = {}
        self.fix_rel = []       # (offset, label)
        self.fix_abs = []       # (offset, label)

    def pc(self):
        return self.org + len(self.out)

    def label(self, name):
        self.labels[name] = self.pc()

    def db(self, *vals):
        for v in vals:
            self.out.append(v & 0xFF)

    # --- instructions used by the driver ---
    def mov_a_imm(self, v):      self.db(0xE8, v)
    def mov_x_imm(self, v):      self.db(0xCD, v)
    def mov_y_imm(self, v):      self.db(0x8D, v)
    def mov_a_dp(self, d):       self.db(0xE4, d)
    def mov_a_dpx(self, d):      self.db(0xF4, d)
    def _abs(self, a):
        if isinstance(a, str):
            self.fix_abs.append((len(self.out), a))
            self.db(0, 0)
        else:
            self.db(a & 0xFF, a >> 8)

    def mov_a_absy(self, a):     self.db(0xF6); self._abs(a)
    def mov_a_absx(self, a):     self.db(0xF5); self._abs(a)
    def mov_a_indy(self, d):     self.db(0xF7, d)      # MOV A,[dp]+Y
    def mov_dp_a(self, d):       self.db(0xC4, d)
    def mov_dpx_a(self, d):      self.db(0xD4, d)
    def mov_dp_imm(self, d, v):  self.db(0x8F, v, d)
    def mov_dp_dp(self, dst, src): self.db(0xFA, src, dst)
    def mov_a_x(self):           self.db(0x7D)
    def mov_x_a(self):           self.db(0x5D)
    def mov_a_y(self):           self.db(0xDD)
    def mov_y_a(self):           self.db(0xFD)
    def mov_y_dp(self, d):       self.db(0xEB, d)
    def adc_a_imm(self, v):      self.db(0x88, v)
    def and_a_imm(self, v):      self.db(0x28, v)
    def or_a_imm(self, v):       self.db(0x08, v)
    def or_a_dp(self, d):        self.db(0x04, d)
    def cmp_a_imm(self, v):      self.db(0x68, v)
    def cmp_a_dp(self, d):       self.db(0x64, d)
    def cmp_x_imm(self, v):      self.db(0xC8, v)
    def asl_a(self):             self.db(0x1C)
    def xcn_a(self):             self.db(0x9F)
    def inc_a(self):             self.db(0xBC)
    def inc_x(self):             self.db(0x3D)
    def inc_y(self):             self.db(0xFC)
    def incw_dp(self, d):        self.db(0x3A, d)
    def dec_dpx(self, d):        self.db(0x8B + 0x10, d)  # DEC dp+X = 9B
    def dec_dp(self, d):         self.db(0x8B, d)
    def dec_a(self):             self.db(0x9C)
    def push_a(self):            self.db(0x2D)
    def pop_a(self):             self.db(0xAE)
    def clrc(self):              self.db(0x60)

    def _rel(self, label):
        self.fix_rel.append((len(self.out), label))
        self.db(0)

    def beq(self, l):  self.db(0xF0); self._rel(l)
    def bne(self, l):  self.db(0xD0); self._rel(l)
    def bcc(self, l):  self.db(0x90); self._rel(l)
    def bcs(self, l):  self.db(0xB0); self._rel(l)
    def bra(self, l):  self.db(0x2F); self._rel(l)

    def call(self, l):
        self.db(0x3F)
        self.fix_abs.append((len(self.out), l))
        self.db(0, 0)

    def jmp(self, l):
        self.db(0x5F)
        self.fix_abs.append((len(self.out), l))
        self.db(0, 0)

    def ret(self):     self.db(0x6F)

    def dsp(self, reg, val):
        """write constant to DSP register"""
        self.mov_dp_imm(0xF2, reg)
        self.mov_dp_imm(0xF3, val)

    def dsp_a(self, reg):
        """write A to DSP register (constant reg)"""
        self.mov_dp_imm(0xF2, reg)
        self.mov_dp_a(0xF3)

    def resolve(self):
        for off, lbl in self.fix_rel:
            target = self.labels[lbl]
            delta = target - (self.org + off + 1)
            if not -128 <= delta <= 127:
                raise ValueError(f"branch out of range to {lbl}: {delta}")
            self.out[off] = delta & 0xFF
        for off, lbl in self.fix_abs:
            t = self.labels[lbl]
            self.out[off] = t & 0xFF
            self.out[off + 1] = t >> 8
        return bytes(self.out)


# parallel dp arrays
PTRL, PTRH, STARTL, STARTH, WAIT = 0x10, 0x18, 0x20, 0x28, 0x30
KON, KOF, TMP, LASTCMD, TICKS = 0x08, 0x09, 0x0A, 0x0B, 0x0C
WPTR = 0x04

def build_driver(songtab_addr, sfxtab_addr):
    a = Asm(CODE_ADDR)

    # ===== init =====
    a.label("start")
    a.dsp(0x6C, 0x20)           # FLG: mute off, echo write disable
    a.dsp(0x5C, 0xFF)           # KOF all
    a.dsp(0x5D, DIR_ADDR >> 8)  # DIR page
    a.dsp(0x0C, 0x70)           # MVOLL
    a.dsp(0x1C, 0x70)           # MVOLR
    a.dsp(0x2C, 0x00)           # EVOLL
    a.dsp(0x3C, 0x00)           # EVOLR
    a.dsp(0x6D, 0xF8)           # ESA (unused, point high)
    a.dsp(0x7D, 0x00)           # EDL
    a.dsp(0x0D, 0x00)           # EFB
    a.dsp(0x2D, 0x00)           # PMON
    a.dsp(0x3D, 0x00)           # NON
    a.dsp(0x4D, 0x00)           # EON
    a.dsp(0x5C, 0x00)           # KOF clear
    # clear channel state
    a.mov_x_imm(0)
    a.mov_a_imm(0)
    a.label("clr")
    a.mov_dpx_a(PTRH)
    a.mov_dpx_a(PTRL)
    a.inc_x()
    a.cmp_x_imm(5)
    a.bne("clr")
    a.mov_dp_imm(LASTCMD, 0)
    # timer 0: 8000/125 = 64 Hz
    a.mov_dp_imm(0xFA, 125)
    a.mov_dp_imm(0xF1, 0x01)

    # ===== main loop =====
    a.label("main")
    # --- poll command port ---
    a.mov_a_dp(0xF4)
    a.cmp_a_dp(LASTCMD)
    a.beq("nocmd")
    a.mov_dp_a(LASTCMD)
    a.cmp_a_imm(0)
    a.beq("nocmd")
    a.push_a()
    a.and_a_imm(0x0F)           # low nibble = command
    a.cmp_a_imm(1)
    a.beq("cmd_song")
    a.cmp_a_imm(2)
    a.beq("cmd_sfx")
    a.cmp_a_imm(3)
    a.beq("cmd_stop")
    a.pop_a()
    a.bra("ack")
    a.label("cmd_song")
    a.pop_a()
    a.call("start_song")
    a.bra("ack")
    a.label("cmd_sfx")
    a.pop_a()
    a.call("start_sfx")
    a.bra("ack")
    a.label("cmd_stop")
    a.pop_a()
    a.call("stop_music")
    a.label("ack")
    a.mov_a_dp(LASTCMD)
    a.mov_dp_a(0xF4)            # echo ack to CPU
    a.label("nocmd")
    # --- timer ---
    a.mov_a_dp(0xFD)
    a.beq("main")
    a.mov_dp_a(TICKS)
    a.label("tickloop")
    a.call("do_tick")
    a.dec_dp(TICKS)
    a.bne("tickloop")
    a.bra("main")

    # ===== do_tick =====
    a.label("do_tick")
    a.mov_dp_imm(KON, 0)
    a.mov_dp_imm(KOF, 0)
    a.dsp(0x5C, 0x00)           # clear KOF bits from last tick
    a.mov_x_imm(0)
    a.label("chloop")
    a.mov_a_dpx(PTRH)
    a.beq("chnext")
    a.dec_dpx(WAIT)
    a.bne("chnext")
    # load work pointer
    a.mov_a_dpx(PTRL)
    a.mov_dp_a(WPTR)
    a.mov_a_dpx(PTRH)
    a.mov_dp_a(WPTR + 1)
    a.call("fetch")
    # write back
    a.mov_a_dp(WPTR)
    a.mov_dpx_a(PTRL)
    a.mov_a_dp(WPTR + 1)
    a.mov_dpx_a(PTRH)
    a.label("chnext")
    a.inc_x()
    a.cmp_x_imm(5)
    a.bne("chloop")
    # apply key-offs then key-ons
    a.mov_a_dp(KOF)
    a.beq("nokof")
    a.dsp_a(0x5C)
    a.label("nokof")
    a.mov_a_dp(KON)
    a.beq("nokon")
    a.dsp_a(0x4C)
    a.label("nokon")
    a.ret()

    # ===== fetch: decode events until a wait is set =====
    a.label("fetch")
    a.mov_y_imm(0)
    a.mov_a_indy(WPTR)
    a.incw_dp(WPTR)
    a.cmp_a_imm(0xFF)
    a.beq("t_end")
    a.cmp_a_imm(0xFE)
    a.beq("t_halt")
    a.cmp_a_imm(0xFD)
    a.beq("t_inst")
    a.cmp_a_imm(0xFC)
    a.beq("t_vol")
    a.cmp_a_imm(0)
    a.beq("ev_rest")
    a.bra("ev_note")
    a.label("t_end");  a.jmp("ev_end")
    a.label("t_halt"); a.jmp("ev_halt")
    a.label("t_inst"); a.jmp("ev_inst")
    a.label("t_vol");  a.jmp("ev_vol")
    a.label("ev_note")
    # --- note ---
    a.asl_a()                   # note*2
    a.mov_y_a()
    a.mov_a_absy(PITCH_ADDR)    # pitch low
    a.push_a()
    a.inc_y()
    a.mov_a_absy(PITCH_ADDR)    # pitch high
    a.mov_dp_a(TMP)
    # VxPITCHL = (voice<<4)|2
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x02)
    a.mov_dp_a(0xF2)
    a.pop_a()
    a.mov_dp_a(0xF3)
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x03)
    a.mov_dp_a(0xF2)
    a.mov_a_dp(TMP)
    a.mov_dp_a(0xF3)
    # kon |= bit
    a.mov_a_absx("chbit")
    a.or_a_dp(KON)
    a.mov_dp_a(KON)
    a.bra("dur")

    a.label("ev_rest")
    a.mov_a_absx("chbit")
    a.or_a_dp(KOF)
    a.mov_dp_a(KOF)
    a.label("dur")
    a.mov_y_imm(0)
    a.mov_a_indy(WPTR)
    a.incw_dp(WPTR)
    a.mov_dpx_a(WAIT)
    a.ret()

    a.label("ev_end")           # loop channel
    a.mov_a_dpx(STARTL)
    a.mov_dp_a(WPTR)
    a.mov_a_dpx(STARTH)
    a.mov_dp_a(WPTR + 1)
    a.jmp("fetch")

    a.label("ev_halt")
    a.mov_a_imm(0)
    a.mov_dp_a(WPTR + 1)
    a.mov_a_absx("chbit")
    a.or_a_dp(KOF)
    a.mov_dp_a(KOF)
    a.mov_a_imm(1)
    a.mov_dpx_a(WAIT)           # harmless; channel inactive anyway
    a.ret()

    a.label("ev_inst")
    a.mov_a_indy(WPTR)
    a.incw_dp(WPTR)
    a.mov_dp_a(TMP)             # inst id
    # SRCN = (v<<4)|4
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x04)
    a.mov_dp_a(0xF2)
    a.mov_a_dp(TMP)
    a.mov_dp_a(0xF3)
    # ADSR1
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x05)
    a.mov_dp_a(0xF2)
    a.mov_y_dp(TMP)
    a.mov_a_absy(INSTA1_ADDR)
    a.mov_dp_a(0xF3)
    # ADSR2
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x06)
    a.mov_dp_a(0xF2)
    a.mov_y_dp(TMP)
    a.mov_a_absy(INSTA2_ADDR)
    a.mov_dp_a(0xF3)
    a.jmp("fetch")

    a.label("ev_vol")
    a.mov_a_indy(WPTR)
    a.incw_dp(WPTR)
    a.mov_dp_a(TMP)
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.mov_dp_a(0xF2)            # VOLL
    a.mov_a_dp(TMP)
    a.mov_dp_a(0xF3)
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x01)
    a.mov_dp_a(0xF2)            # VOLR
    a.mov_a_dp(TMP)
    a.mov_dp_a(0xF3)
    a.jmp("fetch")

    # ===== start_song: song id in port1 =====
    a.label("start_song")
    a.mov_a_dp(0xF5)
    a.asl_a()
    a.mov_y_a()
    a.mov_a_absy(songtab_addr)
    a.mov_dp_a(WPTR)
    a.inc_y()
    a.mov_a_absy(songtab_addr)
    a.mov_dp_a(WPTR + 1)
    # read 4 channel pointers
    a.mov_x_imm(0)
    a.mov_y_imm(0)
    a.label("sslp")
    a.mov_a_indy(WPTR)
    a.mov_dpx_a(PTRL)
    a.mov_dpx_a(STARTL)
    a.inc_y()
    a.mov_a_indy(WPTR)
    a.mov_dpx_a(PTRH)
    a.mov_dpx_a(STARTH)
    a.inc_y()
    a.mov_a_imm(1)
    a.mov_dpx_a(WAIT)
    a.inc_x()
    a.cmp_x_imm(4)
    a.bne("sslp")
    # key off voices 0-3, set default volume
    a.dsp(0x5C, 0x0F)
    a.mov_dp_imm(0xF2, 0x08)
    a.label("start_song_envx_wait")
    a.mov_a_dp(0xF3)
    a.bne("start_song_envx_wait")
    a.mov_a_dp(0xF2)
    a.clrc()
    a.adc_a_imm(0x10)
    a.mov_dp_a(0xF2)
    a.cmp_a_imm(0x48)
    a.bcc("start_song_envx_wait")
    a.dsp(0x5C, 0x00)
    a.mov_x_imm(0)
    a.label("svol")
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.mov_dp_a(0xF2)
    a.mov_dp_imm(0xF3, 0x38)
    a.mov_a_absx("chvoice")
    a.xcn_a()
    a.or_a_imm(0x01)
    a.mov_dp_a(0xF2)
    a.mov_dp_imm(0xF3, 0x38)
    a.inc_x()
    a.cmp_x_imm(4)
    a.bne("svol")
    a.ret()

    # ===== start_sfx: sfx id in port1, slot 4 / voice 6 =====
    a.label("start_sfx")
    a.mov_a_dp(0xF5)
    a.asl_a()
    a.mov_y_a()
    a.mov_x_imm(4)
    a.mov_a_absy(sfxtab_addr)
    a.mov_dpx_a(PTRL)
    a.inc_y()
    a.mov_a_absy(sfxtab_addr)
    a.mov_dpx_a(PTRH)
    a.mov_a_imm(1)
    a.mov_dpx_a(WAIT)
    # voice 6 volume
    a.dsp(0x60, 0x50)
    a.dsp(0x61, 0x50)
    a.ret()

    # ===== stop_music =====
    a.label("stop_music")
    a.mov_x_imm(0)
    a.mov_a_imm(0)
    a.label("stlp")
    a.mov_dpx_a(PTRH)
    a.inc_x()
    a.cmp_x_imm(4)
    a.bne("stlp")
    a.dsp(0x5C, 0x0F)
    a.mov_dp_imm(0xF2, 0x08)
    a.label("stop_music_envx_wait")
    a.mov_a_dp(0xF3)
    a.bne("stop_music_envx_wait")
    a.mov_a_dp(0xF2)
    a.clrc()
    a.adc_a_imm(0x10)
    a.mov_dp_a(0xF2)
    a.cmp_a_imm(0x48)
    a.bcc("stop_music_envx_wait")
    a.dsp(0x5C, 0x00)
    a.ret()

    # channel -> voice / voice bit tables
    a.label("chvoice")
    a.db(0, 1, 2, 3, 6)
    a.label("chbit")
    a.db(0x01, 0x02, 0x04, 0x08, 0x40)

    code = a.resolve()
    return code, a.labels
