"""harness.py - drive build/RCCup.game in tools/emu68k.py: symbols, keys, joystick, screenshots."""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import emu68k

class Game:
    def __init__(self, exe='build/RCCup.game', mapf='build/RCCup.map', out='build/test', datadir='build/gen'):
        os.makedirs(out, exist_ok=True); self.out = out
        self.sym = {}
        names = None
        for l in open(mapf):
            if l.startswith('#sections'): names = l.split()[1:]; continue
            p = l.split()
            if len(p) == 3: self.sym[p[2]] = (p[0], int(p[1], 16))
        self.am = emu68k.Amiga(datadir); self.am.load_hunks(exe)
        self.base = {}
        for m in self.am.msgs:
            r = re.match(r'hunk (\d+): \d+ bytes at \$([0-9a-f]+)', m)
            if r: self.base[names[int(r.group(1))]] = int(r.group(2), 16)
    def A(self, n): s, o = self.sym[n]; return self.base[s] + o
    def w(self, n): return self.am.rw(self.A(n))
    def sw(self, n): v = self.am.rw(self.A(n)); return v - 65536 if v & 0x8000 else v
    def b(self, n): return self.am.rb(self.A(n))
    def l(self, n): return self.am.rl(self.A(n))
    def state(self):
        v = self.l('state')
        for k, (s, o) in self.sym.items():
            if s == 'code' and self.base['code'] + o == v and '.' not in k: return k
        return hex(v)
    def run(self, n): self.am.run_frames(n)
    def key(self, k, n=6): self.am.tap(k); self.run(n)
    def fire(self, n=6):
        self.am.joy['fire'] = 1; self.run(3); self.am.joy['fire'] = 0; self.run(n)
    def joy(self, d, n=6):
        self.am.joy[d] = 1; self.run(3); self.am.joy[d] = 0; self.run(n)
    def shot(self, name): self.am.render().resize((640, 512), 0).save(os.path.join(self.out, name + '.png'))
    def wait(self, st, mx=3000):
        n = 0
        while self.state() != st and n < mx: self.run(1); n += 1
        return n < mx
