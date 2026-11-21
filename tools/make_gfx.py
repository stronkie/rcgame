#!/usr/bin/env python3
"""make_gfx.py - graphics, tracks, sounds and music of RC Turbo Cup (Amiga 500).
Created By Mark Stronks, Stronkie Soft.

Writes to build/gen/ (or argv[1]):
  Track1..Track8   the track files for the disk: packed picture (640x512, 5 interleaved
                   planes) and packed surface map (160x256 bytes)
  tracks.i         track data for the game: names, palettes, racing line, grid, pickup spots, minimaps
  gfx.i            sprites, pickup icons, the HUD, title and menu screens, sounds, music, tables
  layout.i         equates
  preview_*.png    previews
"""
import math, os, random, struct, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import lz
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build', 'gen')
VERSION = os.environ.get('VER', '0.1')
FONTDIR = '/usr/share/fonts/truetype/dejavu/'

def rle(data):            # (used by make_loading.py for the loader's picture)
    out = bytearray(); i = 0; lit = bytearray(); n = len(data)
    def flush():
        nonlocal lit
        while lit:
            ch = lit[:128]; lit = lit[128:]; out.append(len(ch) - 1); out.extend(ch)
    while i < n:
        j = i
        while j < n and j - i < 130 and data[j] == data[i]: j += 1
        if j - i >= 3: flush(); out.append(0x80 | (j - i - 3)); out.append(data[i]); i = j
        else: lit.append(data[i]); i += 1
    flush(); return bytes(out)

def ttf(size, bold=True, serif=False, cond=False, oblique=False):
    name = 'DejaVu' + ('Serif' if serif else 'Sans') + ('Condensed' if cond else '') + \
           ('-Bold' if bold else '') + ('Oblique' if oblique and not bold else ('Oblique' if oblique else ''))
    try: return ImageFont.truetype(FONTDIR + name.replace('-BoldOblique', '-BoldOblique') + '.ttf', size)
    except OSError: return ImageFont.truetype(FONTDIR + 'DejaVuSans-Bold.ttf', size)

def planes_interleaved(a, n=5, width_bytes=None):
    h, w = a.shape
    out = bytearray()
    for y in range(h):
        for p in range(n):
            out += np.packbits((a[y] >> p) & 1).tobytes()
    return bytes(out)

def c12(rgb): return ((rgb[0] + 8) // 17 << 8) | ((rgb[1] + 8) // 17 << 4) | ((rgb[2] + 8) // 17)
def rgb(c): return (((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)

# ------------------------------------------------------------------ font
def load_font():
    import re
    txt = open(os.path.join(ROOT, 'assets', 'font_gz.txt')).read()
    vals = [int(v, 16) for v in re.findall(r'\$([0-9a-f]{2})', txt)]
    g = [vals[i * 8:i * 8 + 8] for i in range(96)]
    fix = {'$': [0x18, 0x3e, 0x60, 0x3c, 0x06, 0x7c, 0x18, 0x00], '?': [0x3c, 0x66, 0x06, 0x0c, 0x18, 0x00, 0x18, 0x00],
           "'": [0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00], '_': [0, 0, 0, 0, 0, 0, 0, 0x7e],
           '%': [0x62, 0x66, 0x0c, 0x18, 0x30, 0x66, 0x46, 0x00],
           '{': [0x00, 0x10, 0x30, 0x7f, 0x30, 0x10, 0x00, 0x00], '}': [0x00, 0x08, 0x0c, 0xfe, 0x0c, 0x08, 0x00, 0x00],
           '^': [0x18, 0x3c, 0x7e, 0xff, 0x18, 0x18, 0x18, 0x00], '`': [0x18, 0x18, 0x18, 0xff, 0x7e, 0x3c, 0x18, 0x00],
           '|': [0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18], '~': [0x00, 0x3c, 0x7e, 0x7e, 0x7e, 0x7e, 0x3c, 0x00],
           '[': [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], ']': [0x00, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x00],
           '@': [0x00, 0x7e, 0x42, 0x42, 0x42, 0x42, 0x7e, 0x00]}
    for ch, gl in fix.items(): g[ord(ch) - 32] = gl
    return g
FONT = load_font()

def text(im, x, y, s, col, shadow=None):
    px = im.load()
    for off, c in (((1, shadow), (0, col)) if shadow is not None else ((0, col),)):
        for i, ch in enumerate(s):
            gl = FONT[(ord(ch) - 32) % 96]
            for r in range(8):
                for b in range(8):
                    if gl[r] & (0x80 >> b):
                        X = x + i * 8 + b + off; Y = y + r + off
                        if 0 <= X < im.width and 0 <= Y < im.height: px[X, Y] = c

# ------------------------------------------------------------------ shared colours
import tracks as T
import sprites as SP

# colours 16..31: 16 black, 20 white, 24 red, 28 yellow; the sprite pairs get the car colours per race
PAINTS = [  # your paint (dark, body): unlocked by the vehicle class
    (0x700, 0xe22), (0x445, 0xaab), (0x640, 0xeb2), (0x315, 0x94e), (0x044, 0x1cc), (0x222, 0x555)]
PAINT_NAMES = ['RACING RED', 'SILVER', 'GOLD', 'PURPLE', 'TURQUOISE', 'STEALTH BLACK']
PERS = [  # computer drivers: name, (dark, body)
    ('SPEEDY SAM', (0x025, 0x36e)),
    ('CAREFUL CARLA', (0x041, 0x3b3)),
    ('MAD MAX', (0x333, 0x888)),
    ('ENGINEER ERIK', (0x730, 0xf90)),
]
HUDPAL = [0x112, 0x223, 0x445, 0x667, 0xaab, 0x556, 0x4c4, 0xf80, 0x800, 0x48f, 0x8cf, 0x99a, 0x334, 0x0a0, 0xddd, 0x6df]
(H_BG, H_PAN, H_PANL, H_PANLL, H_TXT, H_DIM, H_GREEN, H_ORANGE, H_DRED, H_BLUE, H_LBLUE, H_MAP, H_LDIM, H_DGREEN, H_WHITE, H_CYAN) = range(16)

def shared_pal():
    """16..31: 16 black, 17 outline, 20 white, 21 glass, 24 red, 25 grey, 28 yellow, 29 light glass,
    18/19, 22/23, 26/27, 30/31: the four cars (dark, body)"""
    p = [0] * 32
    p[16] = 0x000; p[17] = 0x111; p[20] = 0xfff; p[21] = 0x235; p[24] = 0xd22; p[25] = 0x889; p[28] = 0xfd2; p[29] = 0x9cf
    p[18], p[19] = PAINTS[0]
    for s in range(3):
        p[22 + s * 4], p[23 + s * 4] = PERS[s][1]
    return p

# ------------------------------------------------------------------ tracks
GRID_SLOTS = [(-26, -10), (-26, 10), (-46, -10), (-46, 10)]     # (along the lap, across): the 4 start places

def angle256(dx, dy): return int(round(math.atan2(dy, dx) / (2 * math.pi) * 256)) & 255

def make_tracks():
    meta = []
    for i, tr in enumerate(T.TRACKS):
        res = T.render(tr, i)
        img = res['img']
        # ramps: give the wedge a visible raised edge (drawn after the fact)
        bm = planes_interleaved(img)
        pk = lz.pack(bm)
        sm = res['smap'].astype(np.uint8).tobytes()
        sp = lz.pack(sm)
        assert lz.unpack(pk, len(bm)) == bm
        data = b'RCT1' + struct.pack('>II', len(pk), len(sp)) + pk + sp
        if len(data) & 1: data += b'\0'
        open(os.path.join(OUT, 'Track%d' % (i + 1)), 'wb').write(data)
        T.preview(tr, res, os.path.join(OUT, 'preview_track%d.png' % (i + 1)), T.THEMES[tr['theme']])
        cl, L, tang = res['cl'], res['L'], res['tang']
        N = len(cl)
        # racing line: a point every 8 samples (16 units)
        wp = [(int(round(cl[k][0])), int(round(cl[k][1])), int(round(tang[k][0] * 64)), int(round(tang[k][1] * 64))) for k in range(0, N, 8)]
        # the grid (forwards, and for the races the other way round)
        grid = []; gridr = []
        for (s, l) in GRID_SLOTS:
            for sign, out in ((1, grid), (-1, gridr)):
                k = int(round(sign * s / L * N)) % N
                c = cl[k]; t = tang[k] * sign
                x = c[0] - t[1] * l; y = c[1] + t[0] * l
                out.append((int(round(x * 256)), int(round(y * 256)), angle256(t[0], t[1])))
        n8 = len(wp)
        wpr = [(wp[(n8 - i) % n8][0], wp[(n8 - i) % n8][1], -wp[(n8 - i) % n8][2], -wp[(n8 - i) % n8][3]) for i in range(n8)]
        # pickup spots: 6, away from the extras, alternating sides
        extras = [f for f, k, o in tr['extras']]
        spots = []
        for j, f in enumerate([0.16, 0.31, 0.46, 0.61, 0.76, 0.91]):
            ff = f
            for _ in range(20):
                if all(min(abs(ff - e), 1 - abs(ff - e)) > 0.04 for e in extras): break
                ff += 0.01
            k = int(ff * N) % N; c = cl[k]; t = tang[k]
            l = -9 if j % 2 == 0 else 9
            x = c[0] - t[1] * l; y = c[1] + t[0] * l
            sx, sy = T.to_screen(x, y)
            bx = max(0, min(77, int(round(sx - 8)) // 8))     # byte column of the 16x16 icon
            by = max(0, min(T.WH - 17, int(round(sy)) - 15))
            spots.append((int(round(x)), int(round(y)), bx, by, k // 8, (len(range(0, N, 8)) - k // 8) % len(range(0, N, 8))))
        # minimap: the centre line scaled into 76x34
        sxs = cl[:, 0] - cl[:, 1] + T.OX; sys_ = (cl[:, 0] + cl[:, 1]) / 2
        k = min(74 / (sxs.max() - sxs.min()), 32 / (sys_.max() - sys_.min()))
        ox = 1 + (76 - (sxs.max() - sxs.min()) * k) / 2 - sxs.min() * k
        oy = 1 + (34 - (sys_.max() - sys_.min()) * k) / 2 - sys_.min() * k
        mm = np.zeros((36, 80), np.uint8)
        for a, b in zip(sxs, sys_):
            mx = int(round(a * k + ox)); my = int(round(b * k + oy))
            mm[my, mx] = 1
            if mx + 1 < 80: mm[my, mx + 1] = 1
        meta.append(dict(name=tr['name'], theme=tr['theme'], wp=wp, wpr=wpr, grid=grid, gridr=gridr, spots=spots, mm=np.packbits(mm).tobytes(),
                         mmk=int(round(k * 256)), mmx=int(round(ox)), mmy=int(round(oy)), L=L, size=len(data),
                         pal=T.THEMES[tr['theme']]))
        print('track %d %-20s lap %4.0f  file %6d bytes  %d waypoints' % (i + 1, tr['name'], L, len(data), len(wp)))
    return meta

def tracks_asm(meta):
    L = ['; generated by tools/make_gfx.py - the tracks']
    L.append('track_table:')
    for i, m in enumerate(meta):
        L.append('\tdc.l\ttr%d_name,tr%d_pal,tr%d_wp,tr%d_spots,tr%d_mm,tr%d_grid,tr%d_wpr,tr%d_gridr' % ((i,) * 8))
        L.append('\tdc.w\t%d,%d,%d,%d,%d' % (len(m['wp']), m['mmk'], m['mmx'], m['mmy'], int(m['L'])))
    for i, m in enumerate(meta):
        L.append('tr%d_name:\tdc.b\t\'%s\',0\n\teven' % (i, m['name']))
        L.append('tr%d_pal:\tdc.w\t%s' % (i, ','.join('$%03x' % c for c in m['pal'])))
        for key, lab in (('wp', 'wp'), ('wpr', 'wpr')):
            L.append('tr%d_%s:' % (i, lab))
            for k in range(0, len(m[key]), 6):
                L.append('\tdc.w\t' + ','.join('%d,%d,%d' % (x, y, ((tx & 255) << 8) | (ty & 255)) for x, y, tx, ty in m[key][k:k + 6]))
        L.append('tr%d_spots:' % i)
        for sp in m['spots']:
            L.append('\tdc.w\t%d,%d,%d,%d,%d,%d' % sp)
        for key in ('grid', 'gridr'):
            L.append('tr%d_%s:' % (i, key))
            for (x, y, a) in m[key]:
                L.append('\tdc.l\t%d,%d\n\tdc.w\t%d' % (x, y, a))
        L.append('tr%d_mm:\tdc.b\t%s\n\teven' % (i, ','.join(str(b) for b in m['mm'])))
    L.append('track_files:')
    for i in range(len(meta)):
        n = 'Tracks/Track%d' % (i + 1)
        L.append('\tdc.b\t\'%s\'%s' % (n, ',0' * (16 - len(n))))
    L.append('\teven')
    return '\n'.join(L) + '\n'

# ------------------------------------------------------------------ car sprites
def car_sprites():
    out = bytearray()
    pal = {0: (70, 90, 70), 1: (17, 17, 17), 2: (102, 0, 0), 3: (221, 34, 34), 4: (255, 255, 255), 5: (34, 51, 85),
           8: (220, 30, 30), 9: (136, 136, 153), 12: (255, 210, 30), 13: (150, 200, 255)}
    prev = Image.new('RGB', (16 * 17, 10 * 17), pal[0])
    for dsn in range(5):
        for cage in (0, 1):
            for k in range(16):
                a = SP.render_car15(dsn, k, cage)
                out += SP.car15_bytes(a)
                im = Image.new('RGB', (16, 16)); im.putdata([pal.get(int(v), (255, 0, 255)) for v in a.flatten()])
                prev.paste(im, (k * 17, (dsn * 2 + cage) * 17))
    return bytes(out), prev

def weapon_bobs():
    """missiles, bombs, explosions: 16x16 bobs in playfield colours; per row: mask, 5 plane words"""
    frames = [(SP.missile(k), {1: 16, 2: 20, 3: 28}) for k in range(8)]
    frames += [(SP.bomb(f), {1: 16, 2: 20, 3: 28}) for f in range(2)]
    frames += [(SP.explosion(f), {1: 16, 2: 24, 3: 28}) for f in range(4)]
    out = bytearray()
    for a, m in frames:
        for row in a:
            mw = 0; pw = [0] * 5
            for i, v in enumerate(row[:16]):
                if v:
                    mw |= 0x8000 >> i
                    c = m[int(v)]
                    for p in range(5):
                        if c >> p & 1: pw[p] |= 0x8000 >> i
            out += mw.to_bytes(2, 'big') + b''.join(w.to_bytes(2, 'big') for w in pw)
    return bytes(out)

# ------------------------------------------------------------------ pickup icons (16x16, playfield colours)
ICONS = ['MOTOR', 'TIRES', 'BATTERY', 'MISSILES', 'BOMBS', 'HOMING', 'CASH', 'CAGE', 'TURBO', 'SHIELD', 'REPAIR',
         'S', 'T', 'R', 'O', 'N', 'K', 'I', 'E']
K, W, RD, Y = 16, 20, 24, 28
def icon(name):
    im = Image.new('P', (16, 16), 255); d = ImageDraw.Draw(im)
    letter = len(name) == 1
    face = RD if letter else Y
    d.rectangle([1, 1, 14, 14], fill=face, outline=K)
    d.line([2, 2, 13, 2], fill=W); d.line([2, 2, 2, 12], fill=W)
    d.line([15, 2, 15, 15], fill=K); d.line([2, 15, 15, 15], fill=K)
    def glyph(ch, col, dx=0, dy=0):
        text(im, 4 + dx, 4 + dy, ch, col)
    if letter: glyph(name, Y); glyph(name, W, -1, -1)
    elif name == 'MOTOR': glyph('M', RD)
    elif name == 'CASH': glyph('$', K)
    elif name == 'REPAIR': glyph('+', RD)
    elif name == 'TIRES':
        d.ellipse([3, 3, 12, 12], fill=K); d.ellipse([6, 6, 9, 9], fill=W)
    elif name == 'BATTERY':
        d.rectangle([4, 5, 11, 12], fill=K); d.rectangle([6, 3, 9, 4], fill=K); d.rectangle([5, 6, 10, 8], fill=RD)
    elif name == 'MISSILES':
        d.polygon([(3, 12), (10, 5), (12, 3), (11, 6), (4, 13)], fill=RD, outline=K); d.point((3, 13), fill=K)
    elif name == 'BOMBS':
        d.ellipse([3, 5, 11, 13], fill=K); d.line([9, 5, 11, 3], fill=RD); d.point((5, 7), fill=W)
    elif name == 'HOMING':
        d.ellipse([3, 3, 12, 12], outline=RD); d.ellipse([6, 6, 9, 9], fill=RD); d.line([7, 2, 7, 13], fill=K); d.line([2, 7, 13, 7], fill=K)
    elif name == 'CAGE':
        d.rectangle([4, 4, 11, 11], outline=K); d.line([4, 7, 11, 7], fill=K); d.line([7, 4, 7, 11], fill=K)
    elif name == 'TURBO':
        d.polygon([(9, 2), (4, 9), (7, 9), (6, 14), (11, 6), (8, 6)], fill=RD, outline=K)
    elif name == 'SHIELD':
        d.ellipse([3, 3, 12, 12], outline=K); d.ellipse([4, 4, 11, 11], outline=W); d.point((6, 6), fill=W)
    a = np.array(im)
    mask = (a != 255)
    a = np.where(mask, a, 0).astype(np.uint8)
    return a, mask

def icons_data():
    data = bytearray(); masks = bytearray()
    prev = Image.new('P', (len(ICONS) * 17, 16), 2)
    for k, n in enumerate(ICONS):
        a, m = icon(n)
        for y in range(16):
            for p in range(5):
                data += np.packbits((a[y] >> p) & 1).tobytes()
        masks += np.packbits(m.astype(np.uint8)).tobytes()
        prev.paste(Image.fromarray(a), (k * 17, 0))
    return bytes(data), bytes(masks), prev

# ------------------------------------------------------------------ the HUD (336x40: the first 16 pixels are not shown)
HUD_W, HUD_H = 336, 40
def hud_image():
    im = Image.new('P', (HUD_W, HUD_H), H_BG); d = ImageDraw.Draw(im)
    X = 16
    d.rectangle([X, 0, X + 319, 1], fill=16)                 # the top line (black: changes no colour)
    d.rectangle([X, 2, X + 319, 39], fill=H_PAN)
    d.line([X, 2, X + 319, 2], fill=H_PANLL); d.line([X, 39, X + 319, 39], fill=H_BG)
    # minimap well
    d.rectangle([X + 6, 2, X + 89, 38], fill=H_BG, outline=H_PANL)
    # middle panel
    for bx, w in ((94, 102), (200, 116)):
        d.rectangle([X + bx, 4, X + bx + w, 37], fill=H_PANL, outline=H_BG)
        d.line([X + bx + 1, 36, X + bx + w - 1, 36], fill=H_PANLL)
    for (tx, ty, s) in ((96, 6, 'MPH'), (96, 17, 'LAP'), (96, 28, 'POS')):
        text(im, X + tx, ty, s, H_DIM)
    return im

MM_X, MM_Y = 8, 3          # minimap position in the HUD (pixels, without the hidden 16)

# ------------------------------------------------------------------ title and menu screens
MENU_FIXED = [(8, 10, 24), (255, 255, 255), (255, 214, 40), (220, 30, 30), (150, 150, 170), (70, 200, 80), (110, 190, 255), (28, 32, 56),
              (46, 52, 86), (80, 88, 130), (0, 0, 0), (255, 140, 0)]
(M_BG, M_WHITE, M_YELLOW, M_RED, M_GREY, M_GREEN, M_LBLUE, M_PAN, M_PANL, M_PANLL, M_BLACK, M_ORANGE) = range(12)

def quantize(im, fixed, n=32):
    auto = im.quantize(n - len(fixed), method=Image.MEDIANCUT).getpalette()[:(n - len(fixed)) * 3]
    base = [v for c in fixed for v in c] + auto
    base += [0] * (96 - len(base))
    pimg = Image.new('P', (1, 1)); pimg.putpalette(base + [0] * (768 - len(base)))
    q = im.quantize(palette=pimg, dither=Image.NONE)
    pal = [c12(tuple(base[i * 3:i * 3 + 3])) for i in range(n)]
    return q, pal

def outlined(d, xy, s, font, fill, w=2, anchor='mm', outline=(0, 0, 0)):
    x, y = xy
    for dx in range(-w, w + 1):
        for dy in range(-w, w + 1):
            if dx or dy: d.text((x + dx, y + dy), s, font=font, fill=outline, anchor=anchor)
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def track_backdrop(n, x0, y0, dark=0.55):
    """a piece of a rendered track (RGB) as a backdrop"""
    tim = Image.open(os.path.join(OUT, 'preview_track%d.png' % n)).convert('RGB')
    crop = tim.crop((x0, y0, x0 + 320, y0 + 256))
    a = (np.array(crop).astype(float) * dark).astype(np.uint8)
    return Image.fromarray(a)

def logo_text(im, y, size=44):
    d = ImageDraw.Draw(im)
    f = ttf(size, oblique=True)
    # chrome letters: red shadow, then a yellow-white gradient
    for dx, dy, c in ((4, 4, (90, 0, 0)), (3, 3, (160, 0, 0)), (2, 2, (220, 30, 30))):
        outlined(d, (160 + dx, y + dy), 'RC TURBO CUP', f, c, 2)
    mask = Image.new('L', im.size, 0); md = ImageDraw.Draw(mask)
    md.text((160, y), 'RC TURBO CUP', font=f, fill=255, anchor='mm')
    grad = Image.new('RGB', im.size)
    gd = ImageDraw.Draw(grad)
    for yy in range(im.height):
        t = (yy - (y - size // 2)) / size
        c = (255, int(255 - 120 * max(0, min(1, t))), int(200 - 200 * max(0, min(1, t))))
        gd.line([0, yy, im.width, yy], fill=c)
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            pass
    outline = Image.new('L', im.size, 0); od = ImageDraw.Draw(outline)
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            od.text((160 + dx, y + dy), 'RC TURBO CUP', font=f, fill=255, anchor='mm')
    im.paste((0, 0, 0), (0, 0), outline)
    im.paste(grad, (0, 0), mask)

def big_car(im, x, y, design, k, colours, scale=4):
    a = SP.render_car15(design, k, ss=6, scale=SP.CAR_SCALE * scale, size=16 * scale, anchor=(8 * scale, 10 * scale))
    cols = {1: (17, 17, 17), 2: colours[0], 3: colours[1], 4: (255, 255, 255), 5: (34, 51, 85), 8: (220, 30, 30),
            9: (136, 136, 153), 12: (255, 210, 30), 13: (150, 200, 255)}
    rgbim = Image.new('RGBA', (a.shape[1], a.shape[0]), (0, 0, 0, 0)); px = rgbim.load()
    for yy in range(a.shape[0]):
        for xx in range(a.shape[1]):
            if a[yy, xx]: px[xx, yy] = cols[a[yy, xx]] + (255,)
    # a black outline
    big = rgbim
    sh = Image.new('RGBA', big.size, (0, 0, 0, 0))
    al = big.split()[3]
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        sh.paste((0, 0, 0, 255), (dx, dy), al)
    im.paste(sh, (x, y), sh); im.paste(big, (x, y), big)

def paste_logo(im, x, y, scale=1):
    lg = Image.open(os.path.join(ROOT, 'assets', 'stronkiesoft_logo.png')).convert('RGBA')
    if scale != 1: lg = lg.resize((lg.width * scale, lg.height * scale), Image.NEAREST)
    im.paste(lg, (x - lg.width // 2, y), lg)
    return lg.size

def title_screen():
    im = track_backdrop(8, 300, 230, 0.5)
    d = ImageDraw.Draw(im)
    # a dark band for the menu
    ov = Image.new('RGBA', (320, 256), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
    od.rectangle([40, 112, 280, 236], fill=(10, 12, 30, 215))
    im.paste(ov, (0, 0), ov)
    d.rectangle([40, 112, 280, 236], outline=(110, 190, 255))
    logo_text(im, 32, 34)
    outlined(d, (160, 66), 'THE TOY CAR RACING CHAMPIONSHIP', ttf(9), (255, 214, 40), 1)
    big_car(im, 4, 70, 4, 1, [(100, 0, 0), (220, 30, 30), (255, 160, 150)], 3)
    big_car(im, 262, 70, 2, 13, [(0, 20, 60), (50, 110, 230), (150, 200, 255)], 3)
    outlined(d, (160, 246), 'Created By Mark Stronks, Stronkie Soft  V%s' % VERSION, ttf(8, bold=False), (230, 230, 230), 1)
    lw, lh = paste_logo(im, 160, 80)
    q, pal = quantize(im, MENU_FIXED)
    return q, pal

def menu_screen():
    """the background of the menus: a dark workshop wall with a header"""
    im = Image.new('RGB', (320, 256), (14, 16, 34)); d = ImageDraw.Draw(im)
    for y in range(256):
        t = y / 256
        d.line([0, y, 319, y], fill=(int(16 + 14 * t), int(18 + 12 * t), int(40 + 20 * t)))
    # pegboard holes
    for y in range(40, 256, 12):
        for x in range(6 + (y // 12 % 2) * 6, 320, 12):
            d.point((x, y), fill=(8, 8, 20)); d.point((x + 1, y), fill=(36, 40, 70))
    d.rectangle([0, 0, 319, 30], fill=(30, 34, 64)); d.line([0, 31, 319, 31], fill=(110, 190, 255))
    # chequered strip
    for x in range(0, 320, 8):
        for r in range(2):
            d.rectangle([x, 32 + r * 4, x + 3, 35 + r * 4], fill=(255, 255, 255) if (x // 4 + r) % 2 == 0 else (0, 0, 0))
            d.rectangle([x + 4, 32 + r * 4, x + 7, 35 + r * 4], fill=(0, 0, 0) if (x // 4 + r) % 2 == 0 else (255, 255, 255))
    logo_text(im, 15, 22)
    q, pal = quantize(im, MENU_FIXED)
    return q, pal

# ------------------------------------------------------------------ tables
def tables():
    L = []
    sn = [int(round(math.sin(2 * math.pi * i / 256) * 256)) for i in range(256 + 64)]
    L.append('sintab:')
    for k in range(0, len(sn), 16): L.append('\tdc.w\t' + ','.join(str(v) for v in sn[k:k + 16]))
    L.append('costab\tequ\tsintab+128')
    at = [int(round(math.atan(i / 64) / (2 * math.pi) * 256)) for i in range(65)]
    L.append('atantab:\tdc.b\t' + ','.join(str(v) for v in at) + '\n\teven')
    return '\n'.join(L) + '\n'

# ------------------------------------------------------------------ sound
RATE = 11025
SND = ['beep', 'go', 'v_three', 'v_two', 'v_one', 'v_go', 'bonk', 'skid', 'launch', 'boom', 'pickup', 'zip', 'cash', 'letter',
       'splash', 'boing', 'zap', 'cheer', 'buy', 'error', 'v_title', 'v_finish', 'drop', 'click']

def tosamp(x):
    x = np.clip(x, -1, 1)
    return (np.round(x * 120).astype(np.int8)).tobytes()

def lowpass(x, k):
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * k; y[i] = acc
    return y

def env(n, a, dcy):
    t = np.arange(n) / RATE
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / dcy)

def sounds():
    import voice
    rnd = np.random.default_rng(7)
    S = {}
    def tone(f, dur, shape='sq', dcy=1.0, sweep=0.0):
        n = int(RATE * dur); t = np.arange(n) / RATE
        ph = np.cumsum((f + sweep * t) / RATE)
        w = np.sign(np.sin(2 * np.pi * ph)) if shape == 'sq' else np.sin(2 * np.pi * ph)
        return w * np.exp(-t / dcy)
    S['beep'] = tone(660, 0.18, 'sq', 0.5) * 0.6
    S['go'] = tone(1320, 0.45, 'sq', 0.6) * 0.6
    def resample(v, pitch=1.0):
        return v if pitch == 1.0 else v[(np.arange(int(len(v) / pitch)) * pitch).astype(int)]
        m = int(len(v) * RATE / voice.SR / pitch)
        idx = (np.arange(m) * voice.SR * pitch / RATE).astype(int)
        return v[np.minimum(idx, len(v) - 1)]
    S['v_three'] = resample(voice.say('T r i'), 0.95)
    S['v_two'] = resample(voice.say('t u'), 0.95)
    S['v_one'] = resample(voice.say('w V n'), 0.95)
    S['v_go'] = resample(voice.say('g oU'), 0.9)
    S['v_title'] = resample(voice.say('a r s i t @ r b oU k V p'), 1.0)
    S['v_finish'] = resample(voice.say('f I n I S'), 1.0)
    n = int(RATE * 0.16); t = np.arange(n) / RATE
    S['bonk'] = (np.sin(2 * np.pi * (180 - 300 * t) * t) * 0.9 + lowpass(rnd.uniform(-1, 1, n), 0.3) * 0.6) * np.exp(-t / 0.05)
    n = int(RATE * 0.3); t = np.arange(n) / RATE
    sk = rnd.uniform(-1, 1, n)
    S['skid'] = (lowpass(sk, 0.5) - lowpass(sk, 0.08)) * 2.0 * np.sin(np.pi * t / t[-1]) * (0.7 + 0.3 * np.sin(2 * np.pi * 40 * t))
    n = int(RATE * 0.4); t = np.arange(n) / RATE
    S['launch'] = lowpass(rnd.uniform(-1, 1, n), 0.25) * 1.6 * env(n, 0.01, 0.15) + np.sin(2 * np.pi * (400 + 900 * t) * t) * 0.3 * env(n, 0.01, 0.1)
    n = int(RATE * 0.55); t = np.arange(n) / RATE
    b = rnd.uniform(-1, 1, n)
    S['boom'] = (lowpass(b, 0.12) * 3.0 + lowpass(b, 0.4) * env(n, 0.001, 0.05)) * env(n, 0.002, 0.25)
    S['pickup'] = np.concatenate([tone(880, 0.06, 'sq', 1), tone(1175, 0.06, 'sq', 1), tone(1760, 0.1, 'sq', 0.08)]) * 0.5
    n = int(RATE * 0.5); t = np.arange(n) / RATE
    S['zip'] = (lowpass(rnd.uniform(-1, 1, n), 0.3) * 1.2 + np.sign(np.sin(2 * np.pi * (300 + 1400 * t) * t)) * 0.25) * env(n, 0.02, 0.2)
    S['cash'] = np.concatenate([tone(1568, 0.05, 'sq', 1), tone(2093, 0.25, 'sin', 0.1)]) * 0.6
    S['letter'] = np.concatenate([tone(1047, 0.07, 'sq', 1), tone(1319, 0.07, 'sq', 1), tone(1568, 0.07, 'sq', 1), tone(2093, 0.25, 'sq', 0.1)]) * 0.45
    n = int(RATE * 0.45); t = np.arange(n) / RATE
    S['splash'] = (lowpass(rnd.uniform(-1, 1, n), 0.45) - lowpass(rnd.uniform(-1, 1, n), 0.05)) * 2 * env(n, 0.005, 0.12)
    n = int(RATE * 0.3); t = np.arange(n) / RATE
    S['boing'] = np.sin(2 * np.pi * np.cumsum(220 + 500 * np.sin(np.pi * t / 0.3) ** 2) / RATE) * env(n, 0.005, 0.2)
    n = int(RATE * 0.35); t = np.arange(n) / RATE
    S['zap'] = np.sign(np.sin(2 * np.pi * 70 * t)) * rnd.uniform(0.4, 1, n) * env(n, 0.002, 0.15) * 0.8
    n = int(RATE * 0.9); t = np.arange(n) / RATE
    cr = rnd.uniform(-1, 1, n)
    S['cheer'] = (lowpass(cr, 0.35) - lowpass(cr, 0.05)) * 2.2 * np.minimum(1, t / 0.2) * np.exp(-t / 0.5) * (0.8 + 0.2 * np.sin(2 * np.pi * 7 * t))
    S['buy'] = np.concatenate([tone(784, 0.06, 'sq', 1), tone(1568, 0.15, 'sq', 0.1)]) * 0.5
    S['error'] = np.concatenate([tone(150, 0.1, 'sq', 1), tone(110, 0.15, 'sq', 1)]) * 0.45
    n = int(RATE * 0.12); t = np.arange(n) / RATE
    S['drop'] = np.sin(2 * np.pi * (600 - 2000 * t) * t) * env(n, 0.002, 0.05)
    S['click'] = tone(2400, 0.02, 'sq', 0.01) * 0.5
    out = {}
    for k in SND:
        data = tosamp(S[k])
        if len(data) % 2: data += b'\0'
        out[k] = data
    return out

def engine_wave():
    # a buzzy little electric motor: pulse with a harmonic, 32 bytes
    w = [int(round(100 * (0.7 * math.copysign(1, math.sin(2 * math.pi * i / 32)) + 0.3 * math.sin(6 * math.pi * i / 32)))) for i in range(32)]
    return bytes(v & 255 for v in w)

# ------------------------------------------------------------------ music: 2 channels (lead, bass)
NOTES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
def period(note):
    name, octv = note[:-1], int(note[-1])
    n = NOTES[name] + 12 * (octv - 4)
    freq = 130.81 * 2 ** (n / 12)
    return int(round(3546895 / (freq * 32)))

def seq(s, tick=5):
    out = []
    for tok in s.split():
        n, l = tok.split(':') if ':' in tok else (tok, '1')
        out.append((None if n == '-' else period(n), int(l) * tick))
    return out

def bass(chords, beats=8, tick=5, oct2=True):
    """8th note rock bass: root, octave, root, fifth..."""
    s = []
    for ch in chords:
        r = ch + '2'; o = ch + '3'
        for k in range(beats):
            s.append((r if k % 2 == 0 else o) + ':2')
    return ' '.join(s)

SONGS = {
    'title': (seq('A4:2 C5:2 E5:2 A5:4 G5:2 E5:2 C5:2 D5:2 E5:4 -:2 G4:2 B4:2 D5:2 G5:4 F5:2 D5:2 B4:2 C5:2 D5:4 -:2 '
                  'F4:2 A4:2 C5:2 F5:4 E5:2 C5:2 A4:2 B4:2 C5:4 -:2 E5:2 E5:2 E5:2 G#5:4 F#5:2 G#5:2 B5:2 A5:8 -:4'),
              seq(bass(['A', 'G', 'F', 'E'])), True),
    'race1': (seq('E5:2 E5:2 G5:2 E5:2 A5:3 G5:1 E5:2 D5:2 E5:4 B4:2 D5:2 E5:4 -:4 '
                  'E5:2 E5:2 G5:2 E5:2 A5:3 B5:1 A5:2 G5:2 A5:4 B5:2 D6:2 B5:4 -:4 '
                  'C6:2 B5:2 A5:2 G5:2 A5:4 E5:4 D5:2 E5:2 G5:2 A5:2 B5:4 -:4 '
                  'C6:2 B5:2 A5:2 B5:2 G5:4 E5:4 F#5:2 G5:2 F#5:2 D5:2 E5:8'),
              seq(bass(['E', 'E', 'C', 'D', 'E', 'E', 'C', 'D', 'A', 'G', 'A', 'B', 'A', 'G', 'D', 'E'], beats=4)), True),
    'race2': (seq('G5:2 -:1 G5:1 A5:2 B5:2 D6:3 B5:1 A5:2 G5:2 E5:2 G5:2 A5:4 -:4 '
                  'G5:2 -:1 G5:1 A5:2 B5:2 D6:3 E6:1 D6:2 B5:2 A5:2 B5:2 G5:4 -:4 '
                  'C6:2 C6:2 B5:2 A5:2 B5:2 B5:2 A5:2 G5:2 A5:2 A5:2 G5:2 F#5:2 G5:4 D5:4 '
                  'E5:2 F#5:2 G5:2 A5:2 B5:2 C6:2 D6:2 B5:2 C6:2 A5:2 F#5:2 D5:2 G5:8'),
              seq(bass(['G', 'G', 'E', 'E', 'C', 'C', 'D', 'D', 'C', 'G', 'A', 'G', 'C', 'G', 'D', 'G'], beats=4)), True),
    'race3': (seq('D5:2 F5:2 A5:2 D6:2 C6:2 A5:2 F5:2 A5:2 A#5:4 A5:2 G5:2 A5:8 '
                  'D5:2 F5:2 A5:2 D6:2 E6:2 D6:2 C6:2 A5:2 A#5:2 C6:2 D6:2 E6:2 F6:8 '
                  'F6:2 E6:2 D6:2 C6:2 A#5:4 A5:4 G5:2 A5:2 A#5:2 C6:2 D6:4 A5:4 '
                  'A#5:2 A5:2 G5:2 F5:2 E5:4 C#5:4 D5:4 A4:4 D5:8'),
              seq(bass(['D', 'D', 'A#', 'A', 'D', 'C', 'A#', 'F', 'D', 'A#', 'G', 'D', 'G', 'A', 'D', 'D'], beats=4)), True),
    'race4': (seq('C5:1 E5:1 G5:1 C6:1 B5:2 G5:2 A5:2 F5:2 G5:4 E5:2 C5:2 D5:2 E5:2 F5:2 D5:2 E5:4 C5:4 '
                  'C5:1 E5:1 G5:1 C6:1 B5:2 G5:2 A5:2 C6:2 D6:4 B5:2 G5:2 A5:2 B5:2 C6:2 D6:2 E6:8 '
                  'F6:2 E6:2 D6:2 C6:2 D6:2 C6:2 B5:2 A5:2 B5:2 A5:2 G5:2 F5:2 E5:4 G5:4 '
                  'F5:2 A5:2 C6:2 F6:2 E6:2 C6:2 G5:2 E5:2 D5:2 G5:2 B5:2 D6:2 C6:8'),
              seq(bass(['C', 'C', 'F', 'G', 'C', 'A', 'F', 'G', 'C', 'C', 'F', 'G', 'C', 'A', 'F', 'G', 'F', 'C', 'G', 'C', 'F', 'C', 'G', 'C'], beats=4)), True),
    'shop': (seq('C5:3 E5:1 G5:2 E5:2 A5:3 G5:1 E5:4 F5:3 A5:1 C6:2 A5:2 G5:8 '
                 'C5:3 E5:1 G5:2 E5:2 A5:3 C6:1 D6:4 C6:3 A5:1 G5:2 E5:2 C5:8', 6),
             seq(bass(['C', 'A', 'F', 'G', 'C', 'A', 'G', 'C'], beats=4), 6), True),
    'win': (seq('C5:1 E5:1 G5:1 C6:3 G5:1 C6:6 -:2 A5:1 C6:1 D6:1 E6:6 D6:1 E6:1 F6:1 G6:8'),
            seq('C3:3 G3:3 C4:6 -:2 F3:3 A3:3 C4:4 G3:4 C3:8'), False),
    'lose': (seq('E5:3 D5:3 C5:3 B4:3 A4:2 G#4:2 A4:8'),
             seq('A3:6 F3:6 E3:4 A2:8'), False),
}
SONG_ORDER = list(SONGS.keys())

def music():
    sq = bytes([80] * 8 + [(-80) & 255] * 24)                                 # 25% pulse lead
    saw = bytes([int(round(110 - 220 * i / 32)) & 255 for i in range(32)])    # saw bass
    asm = ['; music, generated by tools/make_gfx.py']
    for name, (mel, bas, loop) in SONGS.items():
        for ch, notes in (('a', mel), ('b', bas)):
            words = []
            for p, l in notes: words += [p or 0, l]
            words += [0xffff if loop else 0xfffe, 0]
            for k in range(0, len(words), 32):
                asm.append(('song_%s_%s:' % (name, ch) if k == 0 else '') + '\tdc.w\t%s' % ','.join('$%x' % w for w in words[k:k + 32]))
    asm.append('song_table:')
    for name in SONGS: asm.append('\tdc.l\tsong_%s_a,song_%s_b' % (name, name))
    return sq, saw, '\n'.join(asm) + '\n'

# ------------------------------------------------------------------ main
def save_prev(im, pal, name, scale=2):
    im = im.copy(); p = []
    for c in pal: p += list(rgb(c))
    im.putpalette(p + [0] * (768 - len(p)))
    im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST).save(os.path.join(OUT, name))

def main():
    os.makedirs(OUT, exist_ok=True)
    meta = make_tracks()
    open(os.path.join(OUT, 'tracks.i'), 'w').write(tracks_asm(meta))
    cars, cprev = car_sprites()
    open(os.path.join(OUT, 'cars.bin'), 'wb').write(cars)
    open(os.path.join(OUT, 'wbob.bin'), 'wb').write(weapon_bobs())
    ic, im_, iprev = icons_data()
    open(os.path.join(OUT, 'icons.bin'), 'wb').write(ic); open(os.path.join(OUT, 'iconmask.bin'), 'wb').write(im_)
    sp = shared_pal()
    save_prev(iprev, [0] * 16 + sp[16:], 'preview_icons.png', 4)
    hud = hud_image()
    hb = planes_interleaved(np.array(hud))
    open(os.path.join(OUT, 'hud.lz'), 'wb').write(lz.pack(hb))
    save_prev(hud, HUDPAL + sp[16:], 'preview_hud.png')
    tq, tpal = title_screen(); open(os.path.join(OUT, 'title.lz'), 'wb').write(lz.pack(planes_interleaved(np.array(tq))))
    save_prev(tq, tpal, 'preview_title.png')
    mq, mpal = menu_screen(); open(os.path.join(OUT, 'menu.lz'), 'wb').write(lz.pack(planes_interleaved(np.array(mq))))
    save_prev(mq, mpal, 'preview_menu.png')
    open(os.path.join(OUT, 'font8.bin'), 'wb').write(bytes(b for g in FONT for b in g))

    L = ['; generated by tools/make_gfx.py - do not edit']
    L.append('shared_pal:\tdc.w\t' + ','.join('$%03x' % c for c in sp[16:]))
    L.append('hud_pal:\tdc.w\t' + ','.join('$%03x' % c for c in HUDPAL))
    L.append('title_pal:\tdc.w\t' + ','.join('$%03x' % c for c in tpal))
    L.append('menu_pal:\tdc.w\t' + ','.join('$%03x' % c for c in mpal))
    L.append('paint_pal:')
    for p in PAINTS: L.append('\tdc.w\t$%03x,$%03x' % p)
    L.append('pers_pal:')
    for n, p in PERS: L.append('\tdc.w\t$%03x,$%03x' % p)
    L.append('paint_names:')
    for n in PAINT_NAMES: L.append('\tdc.b\t\'%s\',0' % n)
    L.append('pers_names:')
    for n, p in PERS: L.append('\tdc.b\t\'%s\',0' % n)
    L.append('design_names:')
    for k in range(5): L.append('\tdc.b\t\'%s\',0' % SP.DESIGNS[k]['name'])
    L.append('\teven')
    L.append(tables())
    eq = dict(CAR_H=SP.CAR_H, CARSPR=SP.CAR_H * 8, CAR_AX=int(SP.ANCHOR[0]), CAR_AY=int(SP.ANCHOR[1]), NTRACKS=len(T.TRACKS), WW=T.WW, WH=T.WH, SURF_W=T.SW, SURF_H=T.SH,
              HUD_H=HUD_H, MM_X=MM_X, MM_Y=MM_Y, NICONS=len(ICONS), NSONGS=len(SONGS), ROAD_R=T.R)
    for i, n in enumerate(['WALL', 'ROAD', 'KERB', 'OIL', 'SAND', 'WATER', 'MARBLE', 'BUMP', 'ZIP', 'RAMP', 'GRASS', 'ZAP']):
        eq['SURF_' + n] = i
    for i, n in enumerate(ICONS): eq['IC_' + (n if len(n) > 1 else 'L_' + n)] = i
    for i, n in enumerate(SONGS): eq['SONG_' + n.upper()] = i
    for i, c in enumerate(['BG', 'PAN', 'PANL', 'PANLL', 'TXT', 'DIM', 'GREEN', 'ORANGE', 'DRED', 'BLUE', 'LBLUE', 'MAP', 'LDIM', 'DGREEN', 'WHITE', 'CYAN']):
        eq['H_' + c] = i
    for i, c in enumerate(['BG', 'WHITE', 'YELLOW', 'RED', 'GREY', 'GREEN', 'LBLUE', 'PAN', 'PANL', 'PANLL', 'BLACK', 'ORANGE']):
        eq['M_' + c] = i
    for i, s in enumerate(SND): eq['S_' + s.upper()] = i
    eq['MAXTRK'] = max(m['size'] for m in meta)
    lay = ['%s\tequ\t%d' % (k, v) for k, v in eq.items()]
    open(os.path.join(OUT, 'layout.i'), 'w').write('\n'.join(lay) + '\n')
    snd = sounds()
    sq, saw, masm = music()
    L.append('\tsection\tsamples,data_c')
    for k, v in snd.items():
        open(os.path.join(OUT, 'snd_%s.raw' % k), 'wb').write(v)
        L.append('\teven\nsnd_%s:\tincbin\t"snd_%s.raw"\nsnd_%s_end:' % (k, k, k))
    L.append('\teven\ninst_lead:\tdc.b\t%s' % ','.join(str(b if b < 128 else b - 256) for b in sq))
    L.append('inst_bass:\tdc.b\t%s' % ','.join(str(b if b < 128 else b - 256) for b in saw))
    ew = engine_wave()
    L.append('inst_engine:\tdc.b\t%s' % ','.join(str(b if b < 128 else b - 256) for b in ew))
    L.append('snd_null:\tdc.w\t0,0')
    L.append('\tsection\tgfx,data')
    L.append('cars_gfx:\tincbin\t"cars.bin"\nwbob_gfx:\tincbin\t"wbob.bin"')
    L.append('icons_gfx:\tincbin\t"icons.bin"\nicons_mask:\tincbin\t"iconmask.bin"')
    L.append('hud_lz:\tincbin\t"hud.lz"\n\teven\ntitle_lz:\tincbin\t"title.lz"\n\teven\nmenu_lz:\tincbin\t"menu.lz"\n\teven')
    L.append('font8:\tincbin\t"font8.bin"')
    L.append('snd_table:')
    for k in SND:
        rate = 8000 if k.startswith('v_') else RATE
        L.append('\tdc.l\tsnd_%s\n\tdc.w\t(snd_%s_end-snd_%s)/2,%d' % (k, k, k, 3546895 // rate))
    L.append(masm)
    open(os.path.join(OUT, 'gfx.i'), 'w').write('\n'.join(L) + '\n')
    w = wave.open(os.path.join(OUT, 'preview_sounds.wav'), 'wb'); w.setnchannels(1); w.setsampwidth(1); w.setframerate(RATE)
    for k in SND: w.writeframes(bytes((b + 128) & 255 for b in snd[k]) + bytes([128]) * 2000)
    w.close()
    cprev.resize((cprev.width * 3, cprev.height * 3), Image.NEAREST).save(os.path.join(OUT, 'preview_cars.png'))
    print('cars %d, samples %d bytes, title %d, menu %d, hud %d' % (len(cars), sum(len(v) for v in snd.values()),
          os.path.getsize(os.path.join(OUT, 'title.lz')), os.path.getsize(os.path.join(OUT, 'menu.lz')), os.path.getsize(os.path.join(OUT, 'hud.lz'))))

if __name__ == '__main__':
    main()
