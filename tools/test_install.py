"""test_install.py - runs the hard disk installer (build/Install) in the emulator with a small
AmigaDOS stand-in: the game disk (volume RCTurboCup:), a hard disk DH0:, a console window
with typed answers.  Checks every installed file against the disk.  Usage: python3 tools/test_install.py"""
import os, sys, shutil, struct
sys.path.insert(0, os.path.dirname(__file__))
import emu68k

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
B = os.path.join(ROOT, 'build')
T = os.path.join(B, 'test_install')
DISK_FILES = ['RCTurbo', 'RCTurbo.game', 'RCTurbo.info', 'ReadMe.txt', 'Install']

class DosAmiga(emu68k.Amiga):
    """emu68k with volumes, locks, a current directory and a console."""
    def setup_fs(self, vols, cwd, typed):
        self.vols = vols; self.locks = {}; self.nextlock = 0x100
        self.cwd = cwd; self.typed = list(typed); self.out = ''
        self.con = None
        def add(lvo, fn):
            sid = len(self.stubs) + 1; self.stubs[sid] = ('dos', fn)
            self.mem[self.dosbase - lvo:self.dosbase - lvo + 2] = (0xa000 | sid).to_bytes(2, 'big')
        for lvo, fn in ((30, self.f_open), (36, self.f_close), (42, self.f_read), (48, self.f_write),
                        (84, self.f_lock), (90, lambda: None), (120, self.f_createdir),
                        (126, self.f_cd), (132, self.f_ioerr)):
            add(lvo, fn)
    def host(self, name):
        if ':' in name:
            v, rest = name.split(':', 1)
            if v.upper() not in self.vols: return None
            base = self.vols[v.upper()]
        else:
            base, rest = self.cwd, name
        return os.path.join(base, *[p for p in rest.split('/') if p])
    def newlock(self, path):
        l = self.nextlock; self.nextlock += 4; self.locks[l] = path; return l
    def f_lock(self):
        p = self.host(self.cstr(self.d[1]))
        self.d[0] = self.newlock(p) if p and os.path.exists(p) else 0
    def f_createdir(self):
        p = self.host(self.cstr(self.d[1]))
        if not p or os.path.exists(p) or not os.path.isdir(os.path.dirname(p)): self.d[0] = 0; return
        os.mkdir(p); self.d[0] = self.newlock(p)
    def f_cd(self):
        old = self.newlock(self.cwd)
        if self.d[1] in self.locks: self.cwd = self.locks[self.d[1]]
        self.d[0] = old
    def f_ioerr(self): self.d[0] = 205
    def f_open(self):
        name = self.cstr(self.d[1]); mode = self.d[2]
        if name.upper().startswith('CON:'):
            self.d[0] = 0x7777; return
        p = self.host(name)
        try:
            f = open(p, 'w+b' if mode == 1006 else 'rb')
        except (OSError, TypeError):
            self.d[0] = 0; return
        fh = self.nextfh; self.nextfh += 1; self.files[fh] = f; self.d[0] = fh
    def f_close(self):
        if self.d[1] != 0x7777:
            f = self.files.pop(self.d[1], None)
            if f: f.close()
        self.d[0] = 0xffffffff
    def f_read(self):
        if self.d[1] == 0x7777:
            line = (self.typed.pop(0) if self.typed else '') + '\n'
            self.out += line
            data = line.encode()[:self.d[3]]
        else:
            data = self.files[self.d[1]].read(self.d[3])
        self.mem[self.d[2]:self.d[2] + len(data)] = data; self.d[0] = len(data)
    def f_write(self):
        data = bytes(self.mem[self.d[2]:self.d[2] + self.d[3]])
        if self.d[1] == 0x7777: self.out += data.decode('latin-1')
        else: self.files[self.d[1]].write(data)
        self.d[0] = len(data)

def run(typed, wb=False, cwd_disk=True, name=''):
    disk = os.path.join(T, 'disk'); dh0 = os.path.join(T, 'dh0'); work = os.path.join(T, 'work')
    am = DosAmiga(T)
    am.load_hunks(os.path.join(T, 'disk', 'Install'))
    am.setup_fs({'RCTURBOCUP': disk, 'DH0': dh0, 'WORK': work}, disk if cwd_disk else work, typed)
    if wb:
        am.set_wb_start()
        arg = am.romp; am.romp += 16
        lock = am.newlock(disk)
        am.mem[arg:arg + 4] = lock.to_bytes(4, 'big')
        am.mem[am.wbmsg + 36:am.wbmsg + 40] = arg.to_bytes(4, 'big')
        am.cwd = work
    try:
        am.run_frames(50)
        print('FAIL %s: did not finish' % name); return am
    except emu68k.Halt:
        pass
    return am

def adf_files(path):
    """the root files of an OFS disk image -> {name: bytes}"""
    img = open(path, 'rb').read(); blk = lambda n: img[n * 512:(n + 1) * 512]
    L = lambda b, o: struct.unpack('>I', b[o:o + 4])[0]
    out = {}; root = blk(880)
    for h in range(72):
        e = L(root, 24 + h * 4)
        while e:
            hd = blk(e); name = hd[433:433 + hd[432]].decode('latin-1')
            if struct.unpack('>i', hd[508:512])[0] == -3:
                data = b''; d = L(hd, 16)
                while d:
                    db = blk(d); data += db[24:24 + L(db, 12)]; d = L(db, 16)
                out[name] = data[:L(hd, 324)]
            e = L(hd, 496)
    return out

def same(a, b): return open(a, 'rb').read() == open(b, 'rb').read()

def main():
    shutil.rmtree(T, ignore_errors=True)
    disk = os.path.join(T, 'disk'); os.makedirs(disk)
    for d in ('dh0', 'work', 'work/Games'): os.makedirs(os.path.join(T, d))
    files = adf_files(os.path.join(B, 'RCTurboCup_V' + os.environ.get('VER', '0.2') + '.adf'))
    print('on the disk:', sorted(files))
    for n, d in files.items(): open(os.path.join(disk, n), 'wb').write(d)
    os.makedirs(os.path.join(disk, 'Tracks'))
    for i in range(1, 9): shutil.copy(os.path.join(B, 'gen', 'Track%d' % i), os.path.join(disk, 'Tracks'))
    open(os.path.join(disk, 'RCTurbo.dat'), 'wb').write(b'RCT1' + bytes(124))
    ok = True
    def check(n, c):
        nonlocal ok; ok &= bool(c); print(('PASS ' if c else 'FAIL ') + n)
    # 1: Workbench, just RETURN -> DH0:
    am = run([''], wb=True, name='wb')
    dest = os.path.join(T, 'dh0', 'RCTurboCup')
    check('WB: drawer made on DH0:', os.path.isdir(dest))
    for f in ['RCTurbo', 'RCTurbo.game', 'RCTurbo.info', 'ReadMe.txt', 'RCTurbo.dat']:
        check('WB: ' + f + ' copied', os.path.exists(os.path.join(dest, f)) and same(os.path.join(dest, f), os.path.join(disk, f)))
    for i in range(1, 9):
        check('WB: Tracks/Track%d copied' % i, same(os.path.join(dest, 'Tracks', 'Track%d' % i), os.path.join(disk, 'Tracks', 'Track%d' % i)))
    check('WB: drawer icon', open(os.path.join(T, 'dh0', 'RCTurboCup.info'), 'rb').read()[:2] == b'\xe3\x10')
    check('WB: Done message', 'Done!' in am.out)
    print(am.out)
    # 2: CLI from elsewhere, a wrong place, then Work:Games, then install again (Y)
    am = run(['Nowhere:', 'Work:Games'], cwd_disk=False, name='cli')
    check('CLI: wrong place asked again', 'not found' in am.out)
    check('CLI: Work:Games/RCTurboCup', os.path.exists(os.path.join(T, 'work', 'Games', 'RCTurboCup', 'RCTurbo.game')))
    am = run(['Work:Games', 'y'], name='again')
    check('again: asks to install over it', 'already there' in am.out and 'Done!' in am.out)
    am = run(['q'], name='quit')
    check('Q quits', 'Nothing was installed' in am.out)
    print('ALL PASS' if ok else 'SOME FAILED')

if __name__ == '__main__':
    main()
