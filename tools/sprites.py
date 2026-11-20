#!/usr/bin/env python3
"""sprites.py - the RC cars (16 directions, 5 classes, with and without roll cage),
missiles, bombs and explosions of RC Turbo Cup, as Amiga sprite data.
A car sprite: 16 wide, CAR_H rows, colours 1 dark, 2 body, 3 light (0 = transparent)."""
import math
import numpy as np
from PIL import Image, ImageDraw

CAR_H = 16
NDIR = 16
SS = 4                     # supersampling

SCALE = 1.12
def proj(x, y, z):
    """world (x along the car, y across, z up) already rotated -> sprite pixel (supersampled)."""
    return ((x - y) * SCALE * SS + 8 * SS, ((x + y) / 2 - z) * SCALE * SS + 10.5 * SS)

# a car model: list of boxes (x0, x1, y0, y1, z0, z1, colour role)  roles: 1 dark, 2 body, 3 light
# x: forward, y: right, z: up (world units, the car is about 12 long and 7 wide)
DESIGNS = {
    0: dict(name='ROOKIE BUGGY', body=[(-5, 4, -2.5, 2.5, 1.5, 3.5, 2), (-3, 1, -2, 2, 3.5, 5.5, 3), (-6, -5, -3.2, 3.2, 3, 5, 1)],
            wheels=[(3.5, 3.4, 2.0), (-3.5, 3.4, 2.4)], wheelw=1.8),
    1: dict(name='SPORT RC', body=[(-6, 6, -3, 3, 1, 3.2, 2), (-3, 2, -2.4, 2.4, 3.2, 4.8, 3), (4, 6, -2.6, 2.6, 2.6, 3.2, 3)],
            wheels=[(4, 3.2, 1.6), (-4, 3.2, 1.6)], wheelw=1.4),
    2: dict(name='TURBO RC', body=[(-6, 6, -3.2, 3.2, 1, 3, 2), (-2.5, 2, -2.4, 2.4, 3, 4.6, 3), (-7, -5.5, -3.6, 3.6, 4.4, 5.4, 1),
                                   (-6.6, -6, -0.5, 0.5, 3, 4.4, 1)],
            wheels=[(4, 3.3, 1.6), (-4, 3.4, 1.8)], wheelw=1.5),
    3: dict(name='SUPER RC', body=[(-6.5, 6.5, -3.6, 3.6, 0.8, 2.6, 2), (-2, 2.5, -2.6, 2.6, 2.6, 4.0, 3), (5, 6.5, -3.6, 3.6, 2.0, 2.6, 3),
                                   (-7, -5.5, -3.8, 3.8, 3.8, 4.8, 2)],
            wheels=[(4.3, 3.6, 1.5), (-4.3, 3.6, 1.6)], wheelw=1.6),
    4: dict(name='CHAMPION RC', body=[(-6, 7, -1.2, 1.2, 1, 2.8, 2), (-2.5, 0.5, -1.4, 1.4, 2.8, 4.2, 3), (6, 7.6, -3.6, 3.6, 1.0, 1.8, 2),
                                      (-7.4, -5.8, -3.6, 3.6, 3.6, 4.8, 2), (-5, -1, -2.6, 2.6, 1.2, 2.6, 2)],
            wheels=[(4.6, 3.4, 1.7), (-4.4, 3.4, 1.9)], wheelw=1.8),
}

def rot(x, y, a):
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c

def render_car(design, k, cage=False, big=0):
    a = k * 2 * math.pi / NDIR
    W = 16 * SS; H = CAR_H * SS
    im = Image.new('L', (W, H), 0); d = ImageDraw.Draw(im)
    D = DESIGNS[design]
    faces = []   # (depth, polygon, colour)
    def box(x0, x1, y0, y1, z0, z1, col):
        corners = {}
        for xi, xx in enumerate((x0, x1)):
            for yi, yy in enumerate((y0, y1)):
                rx, ry = rot(xx, yy, a)
                for zi, zz in enumerate((z0, z1)):
                    corners[(xi, yi, zi)] = (rx, ry, zz)
        def face(keys, c):
            pts = [corners[q] for q in keys]
            depth = sum(p[0] + p[1] for p in pts) / 4 + sum(p[2] for p in pts) / 4 * 0.5
            faces.append((depth, [proj(*p) for p in pts], c))
        # sides: shade by the direction they face (towards the viewer = +x+y)
        sides = [((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1), (0, -1)),   # y0 side, normal -y
                 ((0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1), (0, 1)),
                 ((0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1), (-1, 0)),
                 ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1), (1, 0))]
        for s in sides:
            nx, ny = rot(s[4][0], s[4][1], a)
            if nx + ny > -0.2:
                face(s[:4], 1 if (nx + ny) < 0.4 or col == 1 else 2)
        face(((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)), col)
    for b in D['body']: box(*b)
    for (wx, wy, r) in D['wheels']:
        for sgn in (-1, 1):
            box(wx - r, wx + r, sgn * wy - D['wheelw'] / 2, sgn * wy + D['wheelw'] / 2, 0, 2 * r * 0.9, 1)
    if cage:
        for (x0, x1, y) in ((-4, 2, -2.6), (-4, 2, 2.6)):
            pass
    faces.sort(key=lambda f: f[0])
    for _, poly, c in faces:
        d.polygon(poly, fill=c)
    if cage:   # the roll cage: bars over the car
        for (xx, yy) in ((-3, -2.8), (-3, 2.8), (2, -2.8), (2, 2.8)):
            rx, ry = rot(xx, yy, a)
            p0 = proj(rx, ry, 2); p1 = proj(rx, ry, 7)
            d.line([p0, p1], fill=3, width=SS)
        for (x0, y0, x1, y1) in ((-3, -2.8, -3, 2.8), (2, -2.8, 2, 2.8), (-3, -2.8, 2, -2.8), (-3, 2.8, 2, 2.8)):
            ax, ay = rot(x0, y0, a); bx, by = rot(x1, y1, a)
            d.line([proj(ax, ay, 7), proj(bx, by, 7)], fill=3, width=SS)
    if big:
        return np.array(im.resize((16 * big, CAR_H * big), Image.NEAREST))
    # down-sample: the most common non-zero colour wins if enough of the cell is covered
    a8 = np.array(im).reshape(CAR_H, SS, 16, SS).transpose(0, 2, 1, 3).reshape(CAR_H, 16, SS * SS)
    out = np.zeros((CAR_H, 16), np.uint8)
    for y in range(CAR_H):
        for x in range(16):
            cell = a8[y, x]; nz = cell[cell > 0]
            if len(nz) >= SS * SS * 0.4:
                vals, cnt = np.unique(nz, return_counts=True)
                out[y, x] = vals[np.argmax(cnt)]
    # outline: dark pixels around the car shape
    m = out > 0
    edge = np.zeros_like(m)
    edge[1:, :] |= m[:-1, :] & ~m[1:, :]
    return out

def sprite_bytes(arr):
    """rows of 2-bit pixels -> Amiga sprite data words (without the control words)."""
    out = bytearray()
    for row in arr:
        a = b = 0
        for i, v in enumerate(row[:16]):
            if v & 1: a |= 0x8000 >> i
            if v & 2: b |= 0x8000 >> i
        out += a.to_bytes(2, 'big') + b.to_bytes(2, 'big')
    return bytes(out)

def missile(k):
    """a rocket, 8 directions, 16x16 (colours: 1 dark, 2 body, 3 flame)"""
    a = k * 2 * math.pi / 8
    im = Image.new('L', (64, 64), 0); d = ImageDraw.Draw(im)
    def P(x, y, z=2): return proj(*rot(x, y, a), z)
    d.line([P(-5, 0), P(4, 0)], fill=2, width=7)
    d.polygon([P(4, -1), P(7, 0), P(4, 1)], fill=1)
    d.line([P(-6, -2), P(-4, 0), P(-6, 2)], fill=1, width=4)
    d.ellipse([P(-8, 0)[0] - 6, P(-8, 0)[1] - 5, P(-8, 0)[0] + 6, P(-8, 0)[1] + 5], fill=3)
    a8 = np.array(im).reshape(16, 4, 16, 4).max(axis=(1, 3))
    return a8

def bomb(f):
    im = Image.new('L', (16, 16), 0); d = ImageDraw.Draw(im)
    d.ellipse([3, 6, 12, 15], fill=1); d.ellipse([5, 8, 8, 11], fill=2)
    d.line([8, 6, 10, 3], fill=2)
    if f: d.ellipse([9, 0, 13, 4], fill=3)
    return np.array(im)

def explosion(f):
    rng = np.random.default_rng(f + 3)
    im = Image.new('L', (16, 16), 0); d = ImageDraw.Draw(im)
    r = [3, 6, 7, 6][f]
    for k in range(10):
        a = rng.uniform(0, 6.28); rr = rng.uniform(0, r)
        x = 8 + rr * math.cos(a); y = 9 + rr * math.sin(a) * 0.8
        s = rng.uniform(1.5, 3.5)
        d.ellipse([x - s, y - s, x + s, y + s], fill=[3, 2, 1][min(2, int(rr / max(1, r) * 3))] if f < 3 else 1)
    return np.array(im)

if __name__ == '__main__':
    pal = [0, 0, 0, 90, 20, 20, 220, 40, 40, 255, 170, 150]
    sheet = Image.new('P', (16 * 17, 5 * 2 * 17 + 40), 0)
    for dsn in range(5):
        for cage in (0, 1):
            for k in range(16):
                s = Image.fromarray(render_car(dsn, k, cage)); sheet.paste(s, (k * 17, (dsn * 2 + cage) * 17))
    for k in range(8): sheet.paste(Image.fromarray(missile(k)), (k * 17, 175))
    for f in range(4): sheet.paste(Image.fromarray(explosion(f)), (150 + f * 17, 175))
    sheet.putpalette(pal + [0] * (768 - len(pal)))
    sheet = sheet.convert('RGB')
    bg = Image.new('RGB', sheet.size, (60, 60, 60)); m = Image.fromarray((np.array(sheet).sum(axis=2) > 0).astype(np.uint8) * 255)
    bg.paste(sheet, (0, 0), m)
    bg.resize((bg.width * 4, bg.height * 4), Image.NEAREST).save('build/prev/cars.png')
