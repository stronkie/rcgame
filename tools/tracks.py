#!/usr/bin/env python3
"""tracks.py - the 8 tracks of Stronkie's RC Cup: layout, isometric picture, surface map,
racing line and pickup spots.  Used by tools/make_gfx.py.
Created By Mark Stronks, Stronkie Soft.

World: top-down units, the car drives in it.  Screen (the 640x512 track picture):
    sx = wx - wy + 320        sy = (wx + wy) / 2
Surface map: one byte per 4x2 screen pixels (160 x 256), see SURF_*.
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw

WW, WH = 640, 512                 # the track picture
OX = 320
WOFF = 176                        # world mask offset: world -176..
WSIZE = 880
R = 22                            # half the road width
KERB = 4
WALL = 7                          # wall thickness (world)
WALLH = 9                         # wall height (screen pixels)
SW, SH = 160, 256                 # surface map

# surface types
(SURF_WALL, SURF_ROAD, SURF_KERB, SURF_OIL, SURF_SAND, SURF_WATER, SURF_MARBLE, SURF_BUMP,
 SURF_ZIP, SURF_RAMP, SURF_GRASS, SURF_ZAP) = range(12)

# shared colours (also the colours behind the sprites): 16 black, 20 white, 24 red, 28 yellow
BLACK, WHITE, RED, YELLOW = 16, 20, 24, 28
FX = 25                          # cycled every frame by the game: zipper arrows, flags, electric plates, camera flashes
# theme colour slots 0..15
(G0, G1, G2, RD, RM, RL, W0, W1, W2, P0, P1, P2, PA, WA0, WA1, SA) = range(16)

THEMES = {
    # name: 16 colours ($RGB): ground 3, road 3, wall 3, prop 3, accent, water 2, sand
    'garage':    [0x531, 0x742, 0x963, 0x333, 0x555, 0x777, 0x111, 0x334, 0x667, 0x922, 0xc44, 0xe88, 0x8ab, 0x247, 0x58b, 0xb94],
    'living':    [0x413, 0x624, 0x836, 0x445, 0x667, 0x99a, 0x135, 0x369, 0x7ad, 0x652, 0x974, 0xcb8, 0x5a5, 0x247, 0x58c, 0xca7],
    'garden':    [0x240, 0x360, 0x590, 0x643, 0x865, 0xa97, 0x420, 0x742, 0xa75, 0x843, 0xb65, 0xd98, 0xe6a, 0x236, 0x57a, 0xcb6],
    'toystore':  [0x557, 0x88a, 0xbbd, 0x125, 0x24a, 0x47d, 0x262, 0x2a3, 0x7e7, 0x925, 0xc48, 0xf8b, 0xf90, 0x135, 0x48c, 0xdb6],
    'school':    [0x444, 0x555, 0x666, 0x222, 0x333, 0x888, 0x721, 0xb42, 0xe86, 0x247, 0x46b, 0x8af, 0x3a4, 0x238, 0x59c, 0xc96],
    'lab':       [0x99a, 0xbbc, 0xdde, 0x223, 0x334, 0x557, 0x456, 0x789, 0xbce, 0x264, 0x4a7, 0x8eb, 0xa5d, 0x2a3, 0x7f5, 0xbb9],
    'building':  [0x753, 0x975, 0xb97, 0x444, 0x666, 0x999, 0x220, 0x542, 0x864, 0x842, 0xb63, 0xd96, 0x37b, 0x346, 0x68a, 0xdb7],
    'kitchen':   [0xc33, 0xe55, 0xeee, 0x444, 0x666, 0x999, 0x753, 0x975, 0xcb8, 0x26a, 0x48c, 0x9cf, 0x7c3, 0x247, 0x58c, 0xda5],
    'bathroom':  [0x8ab, 0xbde, 0xeff, 0x335, 0x557, 0x889, 0x89a, 0xbcd, 0xeef, 0xc48, 0xe7a, 0xfbd, 0xfd2, 0x36a, 0x8ce, 0xcb9],
    'arena':     [0x252, 0x373, 0x494, 0x333, 0x444, 0x777, 0x334, 0x667, 0xaab, 0x426, 0x84a, 0xb8d, 0xfa2, 0x247, 0x58c, 0xcb7],
}
SHARED = {16: 0x000, 20: 0xfff, 24: 0xd22, 25: 0xf80, 28: 0xfd2}

def P(*pts): return [tuple(p) for p in pts]

# The tracks: corner points (world units) in race order, corner radius, the
# extras along the lap (fraction of the lap: kind, lateral offset) and shortcuts.
GRIDS = {
    'garage':   [(0,0),(4,0),(4,3),(6,3),(6,6),(0,6)],
    'living':   [(0,0),(5,0),(5,2),(3,2),(3,4),(8,4),(8,7),(4,7),(4,9),(0,9)],
    'garden':   [(0,0),(4,0),(6,2),(6,4),(4,4),(4,6),(8,6),(8,9),(2,9),(0,7)],
    'toystore': [(0,0),(3,0),(3,-2),(6,-2),(6,3),(4,3),(4,5),(8,5),(8,8),(2,8),(2,5),(0,5)],
    'school':   [(0,0),(6,0),(6,2),(3,2),(3,4),(7,4),(7,8),(4,8),(2,6),(2,9),(0,9)],
    'lab':      [(0,0),(3,0),(3,2),(5,2),(5,0),(7,0),(7,5),(5,5),(5,7),(8,7),(8,10),(3,10),(3,6),(0,6)],
    'building': [(0,0),(4,0),(4,2),(6,2),(6,0),(8,0),(8,6),(5,6),(5,9),(2,9),(2,5),(0,5)],
    'arena':    [(0,0),(5,0),(7,2),(7,4),(4,4),(4,6),(9,6),(9,10),(5,10),(2,7),(0,7)],
    'kitchen':  [(0,0),(4,0),(4,2),(7,2),(7,6),(5,6),(5,4),(3,4),(3,8),(0,8)],
    'bathroom': [(0,0),(6,0),(6,3),(4,3),(4,5),(8,5),(8,9),(5,9),(3,7),(0,7)],
}

def fit(grid):
    """scale and place a grid layout so it fills the track picture."""
    p = np.array(grid, float)
    u = p[:, 0] - p[:, 1]; v = p[:, 0] + p[:, 1]
    s = min(526 / (u.max() - u.min()), 872 / (v.max() - v.min()), 62)
    uc = (u.max() + u.min()) / 2 * s; vc = (v.max() + v.min()) / 2 * s
    du = -uc; dv = 528 - vc                     # tx - ty, tx + ty
    tx = (du + dv) / 2; ty = (dv - du) / 2
    return [(x * s + tx, y * s + ty) for x, y in p], s

# The tracks in race order (Amateur Cup).  extras: (fraction of the lap, kind, lateral offset)
TRACKS = [
    dict(name='GARAGE GRAND PRIX', theme='garage', rad=48,
         extras=[(0.10, 'zip', 0), (0.27, 'oil', 8), (0.45, 'zip', -8), (0.60, 'bump', -9), (0.76, 'oil', -6), (0.88, 'zip', 0)],
         props=['nut', 'bolt', 'toolbox', 'can', 'spanner']),
    dict(name='LIVING ROOM RALLY', theme='living', rad=34,
         extras=[(0.07, 'zip', 0), (0.20, 'marble', 6), (0.34, 'zip', 0), (0.53, 'oil', -7), (0.67, 'marble', -6), (0.80, 'zip', 0), (0.93, 'bump', 8)],
         props=['mug', 'remote', 'cushion', 'book', 'sock']),
    dict(name='GARDEN SPRINT', theme='garden', rad=42,
         extras=[(0.06, 'zip', 0), (0.17, 'water', 0), (0.30, 'ramp', 0), (0.33, 'water', 0), (0.62, 'sand', 7), (0.75, 'zip', 0), (0.88, 'water', -8)],
         props=['pot', 'stone', 'gnome', 'can', 'flower'],
         shortcut=[((6, 3.1), (6.1, 6))]),
    dict(name='TOY STORE DASH', theme='toystore', rad=34,
         extras=[(0.05, 'zip', 0), (0.17, 'marble', 0), (0.30, 'zip', 0), (0.43, 'bump', 7), (0.57, 'ramp', 0), (0.68, 'zip', 0), (0.80, 'marble', -7), (0.93, 'zip', 0)],
         props=['block', 'ball', 'block', 'duck', 'box']),
    dict(name='PLAYGROUND PURSUIT', theme='school', rad=32,
         extras=[(0.06, 'zip', 0), (0.20, 'sand', 0), (0.34, 'zip', 0), (0.47, 'water', 8), (0.60, 'ramp', 0), (0.74, 'sand', -6), (0.88, 'zip', 0)],
         props=['ball', 'cone', 'chalk', 'ball', 'cone']),
    dict(name='SCIENCE LAB CIRCUIT', theme='lab', rad=34,
         extras=[(0.05, 'zip', 0), (0.15, 'zap', 6), (0.27, 'chem', -6), (0.40, 'zip', 0), (0.52, 'zap', -7), (0.63, 'chem', 7), (0.75, 'zip', 0), (0.88, 'zap', 0)],
         props=['flask', 'flask', 'box', 'tube', 'magnet']),
    dict(name='CONSTRUCTION CRASH', theme='building', rad=32,
         extras=[(0.05, 'zip', 0), (0.14, 'sand', 6), (0.26, 'ramp', 0), (0.38, 'sand', -6), (0.50, 'bump', 0), (0.62, 'zip', 0), (0.74, 'sand', 0), (0.86, 'ramp', 0)],
         props=['brick', 'pipe', 'bag', 'brick', 'cone']),
    dict(name='CHAMPIONSHIP ARENA', theme='arena', rad=40,
         extras=[(0.04, 'zip', 0), (0.13, 'oil', 7), (0.24, 'zip', 0), (0.36, 'marble', -6), (0.47, 'ramp', 0), (0.59, 'water', 0),
                 (0.70, 'zip', 0), (0.82, 'oil', -7), (0.93, 'zip', 0)],
         props=['stand', 'flag', 'stand', 'tyres', 'flag']),
    dict(name='KITCHEN TABLE TROPHY', theme='kitchen', rad=38,
         extras=[(0.05, 'zip', 0), (0.16, 'oil', 6), (0.28, 'marble', -6), (0.40, 'zip', 0), (0.52, 'ramp', 0), (0.55, 'water', 0),
                 (0.68, 'bump', 7), (0.80, 'oil', -6), (0.92, 'zip', 0)],
         props=['plate', 'cup', 'shaker', 'apple', 'cereal']),
    dict(name='BATHROOM BLITZ', theme='bathroom', rad=40,
         extras=[(0.05, 'zip', 0), (0.15, 'chem', 6), (0.27, 'water', -6), (0.39, 'zip', 0), (0.51, 'ramp', 0), (0.54, 'water', 0),
                 (0.66, 'chem', -7), (0.78, 'zip', 0), (0.90, 'water', 7)],
         props=['soap', 'duck', 'bottle', 'brush', 'sponge']),
]
for _t in TRACKS:
    _t['pts'], _t['scale'] = fit(GRIDS[_t['theme']])

def to_screen(wx, wy): return wx - wy + OX, (wx + wy) / 2.0

# ---------------------------------------------------------------- centre line
def centreline(pts, rad, step=2.0):
    """corner points -> closed centre line sampled every `step` units (rounded corners)."""
    n = len(pts); path = []
    for i in range(n):
        p0 = np.array(pts[i - 1], float); p1 = np.array(pts[i], float); p2 = np.array(pts[(i + 1) % n], float)
        a = p0 - p1; b = p2 - p1
        la = np.linalg.norm(a); lb = np.linalg.norm(b)
        a /= la; b /= lb
        ang = math.acos(max(-1, min(1, float(a @ b))))
        r = min(rad, la * 0.45 * math.tan(ang / 2), lb * 0.45 * math.tan(ang / 2))
        t = r / math.tan(ang / 2)
        s = p1 + a * t; e = p1 + b * t
        bis = (a + b); bis /= np.linalg.norm(bis)
        c = p1 + bis * (r / math.sin(ang / 2))
        a0 = math.atan2(s[1] - c[1], s[0] - c[0]); a1 = math.atan2(e[1] - c[1], e[0] - c[0])
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        m = max(2, int(abs(da) * r / step))
        for k in range(m + 1):
            aa = a0 + da * k / m
            path.append((c[0] + r * math.cos(aa), c[1] + r * math.sin(aa)))
    # resample evenly, starting in the middle of the first straight
    P0 = np.array(path + [path[0]])
    seg = np.linalg.norm(np.diff(P0, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)]); L = cum[-1]
    first = np.array(pts[0], float); second = np.array(pts[1], float)
    mid = first + (second - first) * 0.35
    d0 = np.linalg.norm(P0[:-1] - mid, axis=1); s0 = cum[int(np.argmin(d0))]
    N = int(L / step)
    out = []
    for k in range(N):
        s = (s0 + k * L / N) % L
        j = np.searchsorted(cum, s) - 1; j = max(0, min(j, len(seg) - 1))
        f = (s - cum[j]) / seg[j] if seg[j] else 0
        out.append(P0[j] + (P0[j + 1] - P0[j]) * f)
    return np.array(out), L

# ---------------------------------------------------------------- distance field
def field(cl):
    """for every world cell: distance to the centre line, signed lateral offset, index along the lap."""
    N = len(cl)
    tang = np.roll(cl, -1, axis=0) - np.roll(cl, 1, axis=0)
    tang /= np.linalg.norm(tang, axis=1)[:, None]
    dist = np.full((WSIZE, WSIZE), 1e9, np.float32)
    lat = np.zeros((WSIZE, WSIZE), np.float32)
    idx = np.zeros((WSIZE, WSIZE), np.int32)
    M = R + KERB + WALL + 40
    for c0 in range(0, N, 24):
        pts = cl[c0:c0 + 24]
        x0 = int(pts[:, 0].min() - M) + WOFF; x1 = int(pts[:, 0].max() + M) + WOFF
        y0 = int(pts[:, 1].min() - M) + WOFF; y1 = int(pts[:, 1].max() + M) + WOFF
        x0 = max(0, x0); y0 = max(0, y0); x1 = min(WSIZE, x1); y1 = min(WSIZE, y1)
        gy, gx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        gx -= WOFF; gy -= WOFF
        for k, p in enumerate(pts):
            dx = gx - p[0]; dy = gy - p[1]
            d = np.sqrt(dx * dx + dy * dy)
            sub = dist[y0:y1, x0:x1]
            m = d < sub
            sub[m] = d[m]
            t = tang[c0 + k]
            lat[y0:y1, x0:x1][m] = (t[0] * dy - t[1] * dx)[m]
            idx[y0:y1, x0:x1][m] = c0 + k
    return dist, lat, idx, tang

# ---------------------------------------------------------------- themes: ground
_NT = np.random.default_rng(5).random((64, 64))
def noise(ix, iy, p=32, k=0):
    """repeating noise (period p in both directions, so it packs well)"""
    return _NT[(ix % p + k * 7) % 64, (iy % p + k * 13) % 64]

def ground(theme, wx, wy, rnd):
    """the floor of the room: palette indices from world coordinates."""
    ix = np.floor(wx).astype(int); iy = np.floor(wy).astype(int)
    g = np.full(wx.shape, G1, np.uint8)
    if theme == 'garage':           # workbench planks along wy, with grain and nail heads
        pl = (ix // 28) % 2
        g[:] = np.where(pl == 0, G1, G2)
        g[(ix % 28) == 0] = G0
        grain = ((iy + ((ix // 28) % 2) * 11) % 28 == 0) & ((ix % 7) != 3)
        g[grain] = G0
        g[((iy % 56) == 40) & ((ix % 28) == 4)] = BLACK
    elif theme == 'living':         # patterned carpet
        cx = ix % 32; cy = iy % 32
        g[:] = G1
        dia = (np.abs(cx - 16) + np.abs(cy - 16)) < 9
        g[dia] = G2
        g[(np.abs(cx - 16) + np.abs(cy - 16)) < 4] = G0
        g[((cx == 0) | (cy == 0))] = G0
    elif theme == 'garden':         # mown grass stripes
        g[:] = np.where(((ix + iy) // 24) % 2 == 0, G1, G2)
        g[noise(ix, iy, 48) < 0.03] = G0
    elif theme == 'toystore':       # shop floor tiles
        g[:] = np.where(((ix // 24) + (iy // 24)) % 2 == 0, G1, G2)
        g[(ix % 24 == 0) | (iy % 24 == 0)] = G0
    elif theme == 'school':         # asphalt with painted squares
        g[:] = G1
        nz = noise(ix, iy, 32)
        g[nz < 0.06] = G0
        g[nz > 0.95] = G2
        sq = ((ix % 64) < 32) & ((iy % 64) < 32) & (((ix % 32) == 0) | ((iy % 32) == 0) | ((ix % 32) == 31) | ((iy % 32) == 31))
        g[sq] = WHITE
    elif theme == 'lab':            # white floor tiles
        g[:] = np.where(((ix // 32) + (iy // 32)) % 2 == 0, G2, G1)
        g[(ix % 32 == 0) | (iy % 32 == 0)] = G0
    elif theme == 'building':       # sand and gravel
        g[:] = G1
        nz = noise(ix, iy, 32)
        g[nz < 0.07] = G0
        g[nz > 0.93] = G2
        g[(((ix // 32) + (iy // 32)) % 3 == 0) & (noise(ix, iy, 32, 1) < 0.2)] = SA
    elif theme == 'kitchen':        # a gingham table cloth
        a = (ix // 16) % 2; b = (iy // 16) % 2
        g[:] = np.where(a & b, G0, np.where(a ^ b, G1, G2))
        g[((ix % 16) == 8) & ((iy % 4) == 0) & (a ^ b == 1)] = G2
    elif theme == 'bathroom':       # bathroom tiles
        g[:] = np.where(((ix // 20) + (iy // 20)) % 2 == 0, G2, G1)
        g[(ix % 20 == 0) | (iy % 20 == 0)] = G0
    elif theme == 'arena':          # stadium turf
        g[:] = np.where(((ix - iy) // 30) % 2 == 0, G1, G2)
        g[noise(ix, iy, 60) < 0.02] = G0
    return g

def road_tex(theme, wx, wy, lat, s):
    ix = np.floor(wx).astype(int); iy = np.floor(wy).astype(int)
    r = np.full(wx.shape, RM, np.uint8)
    nz = noise(ix, iy, 32, 2)
    r[nz < 0.08] = RD
    r[nz > 0.96] = RL
    if theme in ('toystore', 'arena', 'school'):   # lane dashes
        dash = (np.abs(lat) < 1.0) & ((s // 10) % 2 == 0)
        r[dash] = WHITE if theme != 'toystore' else YELLOW
    if theme == 'garden':                          # paving stones
        r[:] = RM
        r[((ix + iy) % 16 == 0) | ((ix - iy) % 16 == 0)] = RD
        r[noise(ix, iy, 32, 3) < 0.04] = RL
    return r

# kerb and wall colours per theme
def kerb_cols(theme): return {'garden': (RL, RD), 'lab': (YELLOW, BLACK), 'building': (YELLOW, BLACK)}.get(theme, (RED, WHITE))

# ---------------------------------------------------------------- props (big things on the floor)
def draw_box(img, cx, cy, w, d, h, top, left, right, edge=BLACK):
    """an isometric box with its ground centre at screen (cx, cy): w along world x, d along world y, h high."""
    dr = ImageDraw.Draw(img)
    # ground corners in screen space
    def s(ax, ay, z=0): return (cx + ax - ay, cy + (ax + ay) / 2 - z)
    a = s(-w / 2, -d / 2); b = s(w / 2, -d / 2); c = s(w / 2, d / 2); e = s(-w / 2, d / 2)
    at, bt, ct, et = [s(*p, z=h) for p in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
    dr.polygon([e, c, ct, et], fill=left, outline=edge)       # front left face (facing +y)
    dr.polygon([c, b, bt, ct], fill=right, outline=edge)      # front right face (facing +x)
    dr.polygon([at, bt, ct, et], fill=top, outline=edge)

def draw_cyl(img, cx, cy, r, h, top, side, dark, edge=BLACK):
    dr = ImageDraw.Draw(img)
    dr.rectangle([cx - r, cy - h - r / 2, cx + r, cy], fill=side)
    dr.ellipse([cx - r, cy - r / 2, cx + r, cy + r / 2], fill=side, outline=edge)
    dr.rectangle([cx - r + 1, cy - h, cx + r - 1, cy], fill=side)
    dr.rectangle([cx + r // 3, cy - h, cx + r - 1, cy], fill=dark)
    dr.line([cx - r, cy - h, cx - r, cy], fill=edge); dr.line([cx + r, cy - h, cx + r, cy], fill=edge)
    dr.ellipse([cx - r, cy - h - r / 2, cx + r, cy - h + r / 2], fill=top, outline=edge)

def draw_prop(img, kind, cx, cy, rnd):
    """draw one prop; returns its screen bounding box."""
    d = ImageDraw.Draw(img)
    if kind == 'nut':
        r = 14
        pts = [(cx + r * math.cos(a), cy + r * 0.5 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 7)[:-1]]
        top = [(x, y - 8) for x, y in pts]
        d.polygon(pts, fill=W0)
        for i in range(6):
            a, b = pts[i], pts[(i + 1) % 6]
            if a[1] + b[1] > 2 * cy - 4:
                d.polygon([a, b, top[(i + 1) % 6], top[i]], fill=RL if i % 2 else RM, outline=BLACK)
        d.polygon(top, fill=RL, outline=BLACK)
        d.ellipse([cx - 6, cy - 11, cx + 6, cy - 5], fill=G0, outline=BLACK)
        return (cx - r, cy - 16, cx + r, cy + 8)
    if kind == 'bolt':
        draw_cyl(img, cx, cy, 4, 26, RL, RM, RD); draw_cyl(img, cx, cy - 26, 9, 6, RL, RM, RD)
        return (cx - 10, cy - 40, cx + 10, cy + 3)
    if kind in ('toolbox', 'box', 'book', 'bag', 'brick', 'block', 'remote', 'cushion', 'chalk', 'stand'):
        dims = dict(toolbox=(40, 22, 20, P1, P0, P2), box=(30, 30, 24, PA, P0, P1), book=(44, 30, 8, P1, P0, P2),
                    bag=(26, 34, 12, SA, RD, RL), brick=(30, 14, 12, P1, P0, P2), block=(20, 20, 20, None, None, None),
                    remote=(12, 40, 5, RD, BLACK, RM), cushion=(36, 36, 10, P2, P1, P0), chalk=(6, 24, 6, WHITE, RL, RM),
                    stand=(60, 26, 34, RL, RD, RM))[kind]
        w, dd, h, top, left, right = dims
        if kind == 'block':
            top, left, right = rnd.choice([(P2, P0, P1), (WA1, WA0, WA1), (YELLOW, PA, YELLOW), (RL, RD, RM)])
        draw_box(img, cx, cy, w, dd, h, top, left, right)
        if kind == 'toolbox':
            d.line([cx - 10, cy - h - 8, cx + 10, cy - h + 2], fill=BLACK, width=2)
        if kind == 'remote':
            for k in range(4): d.point((cx - 6 + k * 3, cy - 6 + k), fill=RED)
        if kind == 'stand':        # a grandstand with a crowd
            for row in range(4):
                for k in range(16):
                    px = cx - 30 + k * 4 + row * 2; py = cy - h - 4 + row * 3 - k * 2 + 10
                    d.point((px, py), fill=rnd.choice([RED, YELLOW, WHITE, PA, WA1, FX]))
        if kind == 'block':
            d.text((cx - 3, cy - h - 6), rnd.choice('ABCRC'), fill=WHITE)
        return (cx - w - dd, cy - h - (w + dd) // 2, cx + w + dd, cy + (w + dd) // 2)
    if kind in ('can', 'mug', 'pot', 'flask', 'tyres', 'pipe'):
        if kind == 'can': draw_cyl(img, cx, cy, 10, 26, RL, P1, P0); d.rectangle([cx - 2, cy - 38, cx + 2, cy - 30], fill=BLACK)
        if kind == 'mug':
            draw_cyl(img, cx, cy, 11, 20, WA0, P2, P1); d.arc([cx + 7, cy - 17, cx + 17, cy - 7], 270, 90, fill=P2, width=3)
        if kind == 'pot':
            draw_cyl(img, cx, cy, 12, 16, G0, P1, P0)
            for k in range(5):
                a = k * 1.25; d.ellipse([cx - 4 + 9 * math.cos(a), cy - 30 + 5 * math.sin(a), cx + 4 + 9 * math.cos(a), cy - 24 + 5 * math.sin(a)], fill=PA)
            d.ellipse([cx - 3, cy - 30, cx + 3, cy - 24], fill=YELLOW)
        if kind == 'flask':
            draw_cyl(img, cx, cy, 11, 14, WA1, P1, P0); draw_cyl(img, cx, cy - 14, 4, 14, W2, W1, W0)
        if kind == 'tyres':
            for k in range(3): draw_cyl(img, cx, cy - k * 7, 11, 7, G0, BLACK, BLACK, edge=RD)
        if kind == 'pipe':
            draw_box(img, cx, cy, 50, 12, 12, W2, W0, W1)
        return (cx - 30, cy - 45, cx + 30, cy + 8)
    if kind == 'spanner':
        d.polygon([(cx - 26, cy - 4), (cx + 22, cy - 4 - 10), (cx + 24, cy - 10), (cx - 24, cy + 2)], fill=RL, outline=BLACK)
        d.ellipse([cx + 16, cy - 20, cx + 32, cy - 8], fill=RL, outline=BLACK); d.ellipse([cx + 21, cy - 17, cx + 27, cy - 12], fill=G1)
        return (cx - 28, cy - 22, cx + 34, cy + 4)
    if kind in ('stone', 'ball'):
        r = 13 if kind == 'stone' else 12
        col = (RD, RM, RL) if kind == 'stone' else (P0, P1, P2)
        d.ellipse([cx - r, cy - 2 * r, cx + r, cy], fill=col[1], outline=BLACK)
        d.ellipse([cx - r // 2, cy - 2 * r + 4, cx, cy - r], fill=col[2])
        if kind == 'ball': d.arc([cx - r, cy - 2 * r, cx + r, cy], 200, 340, fill=WHITE)
        return (cx - r, cy - 2 * r, cx + r, cy)
    if kind == 'gnome':
        draw_cyl(img, cx, cy, 7, 12, WA1, WA0, WA0)
        d.ellipse([cx - 5, cy - 22, cx + 5, cy - 12], fill=P2)
        d.polygon([(cx - 6, cy - 20), (cx + 6, cy - 20), (cx, cy - 36)], fill=RED, outline=BLACK)
        d.polygon([(cx - 4, cy - 15), (cx + 4, cy - 15), (cx, cy - 8)], fill=WHITE)
        return (cx - 8, cy - 37, cx + 8, cy + 4)
    if kind == 'flower':
        d.line([cx, cy, cx, cy - 22], fill=G0, width=2)
        for k in range(6):
            a = k * 1.05; d.ellipse([cx - 4 + 6 * math.cos(a), cy - 28 + 4 * math.sin(a), cx + 4 + 6 * math.cos(a), cy - 22 + 4 * math.sin(a)], fill=PA)
        d.ellipse([cx - 3, cy - 28, cx + 3, cy - 22], fill=YELLOW)
        return (cx - 11, cy - 33, cx + 11, cy + 2)
    if kind == 'duck':
        d.ellipse([cx - 12, cy - 14, cx + 12, cy], fill=YELLOW, outline=BLACK)
        d.ellipse([cx - 2, cy - 26, cx + 10, cy - 12], fill=YELLOW, outline=BLACK)
        d.polygon([(cx + 9, cy - 20), (cx + 16, cy - 18), (cx + 9, cy - 16)], fill=PA)
        d.point((cx + 5, cy - 21), fill=BLACK)
        return (cx - 13, cy - 27, cx + 17, cy + 1)
    if kind in ('cone',):
        d.polygon([(cx - 9, cy), (cx + 9, cy), (cx, cy - 26)], fill=PA if 'PA' else RED, outline=BLACK)
        d.line([cx - 5, cy - 10, cx + 5, cy - 10], fill=WHITE, width=2)
        return (cx - 10, cy - 27, cx + 10, cy + 1)
    if kind == 'sock':
        d.polygon([(cx - 14, cy - 6), (cx + 6, cy - 16), (cx + 14, cy - 8), (cx + 4, cy - 2), (cx - 10, cy + 2)], fill=P2, outline=BLACK)
        d.line([cx - 12, cy - 4, cx + 5, cy - 13], fill=RED, width=2)
        return (cx - 15, cy - 17, cx + 15, cy + 3)
    if kind == 'tube':
        for k in range(3):
            draw_cyl(img, cx - 10 + k * 10, cy + k * 2, 3, 22, WA1, W2, W1)
        return (cx - 15, cy - 28, cx + 15, cy + 7)
    if kind == 'magnet':
        d.arc([cx - 14, cy - 30, cx + 14, cy - 2], 0, 180, fill=RED, width=6)
        d.rectangle([cx - 14, cy - 18, cx - 9, cy - 10], fill=W2); d.rectangle([cx + 9, cy - 18, cx + 14, cy - 10], fill=W2)
        return (cx - 15, cy - 31, cx + 15, cy)
    if kind == 'plate':
        d.ellipse([cx - 22, cy - 11, cx + 22, cy + 11], fill=WHITE, outline=BLACK)
        d.ellipse([cx - 14, cy - 7, cx + 14, cy + 7], fill=W2)
        d.ellipse([cx - 6, cy - 5, cx + 6, cy + 3], fill=PA, outline=BLACK)
        return (cx - 23, cy - 12, cx + 23, cy + 12)
    if kind == 'cup':
        draw_cyl(img, cx, cy, 10, 18, W0, WHITE, W2); d.arc([cx + 7, cy - 15, cx + 17, cy - 5], 270, 90, fill=WHITE, width=3)
        return (cx - 11, cy - 25, cx + 18, cy + 5)
    if kind == 'shaker':
        draw_cyl(img, cx, cy, 6, 22, W2, WHITE, W2); draw_cyl(img, cx, cy - 22, 6, 4, RM, RL if False else RM, RD)
        return (cx - 7, cy - 32, cx + 7, cy + 3)
    if kind == 'apple':
        d.ellipse([cx - 11, cy - 20, cx + 11, cy], fill=RED, outline=BLACK); d.ellipse([cx - 6, cy - 16, cx - 1, cy - 11], fill=WHITE)
        d.line([cx, cy - 20, cx + 2, cy - 26], fill=W0, width=2); d.ellipse([cx + 2, cy - 27, cx + 9, cy - 22], fill=PA)
        return (cx - 12, cy - 28, cx + 12, cy + 1)
    if kind == 'cereal':
        draw_box(img, cx, cy, 30, 10, 40, YELLOW, P1, P0)
        d.text((cx - 10, cy - 30), 'RC', fill=WHITE)
        return (cx - 42, cy - 62, cx + 42, cy + 22)
    if kind == 'soap':
        draw_box(img, cx, cy, 26, 16, 8, P2, P1, P0)
        return (cx - 42, cy - 30, cx + 42, cy + 22)
    if kind == 'bottle':
        draw_cyl(img, cx, cy, 9, 28, P2, P1, P0); draw_cyl(img, cx, cy - 28, 4, 8, WHITE, W2, W1)
        return (cx - 10, cy - 42, cx + 10, cy + 5)
    if kind == 'brush':
        d.line([cx - 22, cy + 4, cx + 18, cy - 12], fill=WA1, width=4); d.line([cx + 10, cy - 14, cx + 22, cy - 19], fill=WHITE, width=5)
        return (cx - 24, cy - 22, cx + 24, cy + 7)
    if kind == 'sponge':
        draw_box(img, cx, cy, 24, 18, 10, YELLOW, PA, YELLOW)
        for k in range(5): d.point((cx - 8 + k * 4, cy - 12 + (k % 2) * 3), fill=PA)
        return (cx - 42, cy - 32, cx + 42, cy + 22)
    if kind == 'flag':
        d.line([cx, cy, cx, cy - 36], fill=WHITE, width=1)
        for k in range(4):
            for j in range(3):
                d.rectangle([cx + 1 + k * 4, cy - 36 + j * 4 + k, cx + 4 + k * 4, cy - 33 + j * 4 + k], fill=BLACK if (k + j) % 2 else FX)
        return (cx - 1, cy - 37, cx + 18, cy + 1)
    return (cx, cy, cx, cy)

# ---------------------------------------------------------------- render a track
def render(tr, seed=0):
    rnd = random.Random(seed + 7)
    theme = tr['theme']
    cl, L = centreline(tr['pts'], tr['rad'])
    N = len(cl)
    dist, lat, idx, tang = field(cl)
    # shortcuts: grass strips that cut a corner (no walls there)
    cut = np.zeros((WSIZE, WSIZE), bool)
    cutline = []
    g0 = np.array(GRIDS[theme], float); pts0 = np.array(tr['pts'])
    def g2w(g): return pts0[0] + (np.array(g) - g0[0]) * tr['scale']
    for (ga, gb) in tr.get('shortcut', []):
        a = g2w(ga); b = g2w(gb)
        im = Image.new('L', (WSIZE, WSIZE), 0); dd = ImageDraw.Draw(im)
        dd.line([a[0] + WOFF, a[1] + WOFF, b[0] + WOFF, b[1] + WOFF], fill=255, width=26)
        cut |= np.array(im) > 0
        cutline.append((a, b))

    # world coordinates of every screen pixel
    sy, sx = np.mgrid[0:WH, 0:WW].astype(np.float32)
    wx = sy + (sx - OX) / 2.0; wy = sy - (sx - OX) / 2.0
    ix = np.clip(np.round(wx).astype(int) + WOFF, 0, WSIZE - 1)
    iy = np.clip(np.round(wy).astype(int) + WOFF, 0, WSIZE - 1)
    D = dist[iy, ix]; LAT = lat[iy, ix]; S = idx[iy, ix] * (L / N)
    CUT = cut[iy, ix]
    img = ground(theme, wx, wy, rnd)
    road = D <= R
    kerb = (D > R) & (D <= R + KERB)
    wallm = (D > R + KERB) & (D <= R + KERB + WALL) & ~CUT
    grass = CUT & ~road & ~kerb
    img[road] = road_tex(theme, wx, wy, LAT, S)[road]
    k1, k2 = kerb_cols(theme)
    kc = np.where((S // 8).astype(int) % 2 == 0, k1, k2).astype(np.uint8)
    img[kerb] = kc[kerb]
    gcol = G0 if theme != 'garden' else G0
    img[grass] = np.where(((np.floor(wx) + np.floor(wy)) % 3) == 0, G2, G1)[grass] if theme != 'building' else SA

    surf = np.zeros((WH, WW), np.uint8)
    surf[road] = SURF_ROAD; surf[kerb] = SURF_KERB; surf[grass] = SURF_GRASS
    surf[~(road | kerb | grass)] = SURF_WALL

    # start / finish line: a checkered band across the road at s = 0
    s_rel = (S + L / 2) % L - L / 2
    start = road & (np.abs(s_rel) < 4)
    chk = ((np.floor(LAT / 4) + np.floor((s_rel + 4) / 4)) % 2 == 0)
    img[start] = np.where(chk, WHITE, BLACK)[start]
    # the starting grid boxes
    for k in range(0):
        gs = -18 - k * 16; gl = -9 if k % 2 == 0 else 9
        box = road & (np.abs(s_rel - gs) < 7) & (np.abs(LAT - gl) < 6) & ((np.abs(s_rel - gs) > 5.8) | (np.abs(LAT - gl) > 4.8))
        img[box] = WHITE

    # extras along the lap
    pickups = []
    for (f, kind, off) in tr['extras']:
        s0 = f * L
        ds = (S - s0 + L / 2) % L - L / 2
        if kind == 'zip':
            m = road & (np.abs(ds) < 9) & (np.abs(LAT - off) < 13)
            img[m] = YELLOW
            arrow = m & (np.abs(LAT - off) < 9) & ((((ds + 9) % 9) - np.abs(LAT - off) * 0.5) > 3) & ((((ds + 9) % 9) - np.abs(LAT - off) * 0.5) < 6)
            img[arrow] = FX
            surf[m] = SURF_ZIP
        elif kind in ('oil', 'chem'):
            rr = np.sqrt((ds * 0.8) ** 2 + (LAT - off) ** 2)
            blob = road & (rr < 9 + 2 * np.sin(np.arctan2(LAT - off, ds) * 3))
            img[blob] = BLACK if kind == 'oil' else WA1
            img[blob & (((np.floor(wx) * 3 + np.floor(wy)) % 7) == 0)] = RD if kind == 'oil' else WA0
            surf[blob] = SURF_OIL
        elif kind in ('water', 'sand'):
            rr = np.sqrt((ds * 0.6) ** 2 + (LAT - off) ** 2)
            big = 15 if off == 0 else 11
            blob = (road | kerb | grass) & (rr < big + 2 * np.sin(np.arctan2(LAT - off, ds) * 4))
            if kind == 'water':
                img[blob] = WA0
                img[blob & (((np.floor(wx) + np.floor(wy) * 2) % 9) == 0)] = WA1
                surf[blob] = SURF_WATER
            else:
                img[blob] = SA
                img[blob & (((np.floor(wx) * 5 + np.floor(wy) * 3) % 7) == 0)] = RL
                surf[blob] = SURF_SAND
        elif kind == 'marble':
            m = road & (np.abs(ds) < 12) & (np.abs(LAT - off) < 10)
            surf[m] = SURF_MARBLE
            for k in range(14):
                a = rnd.uniform(-11, 11); b = rnd.uniform(-9, 9) + off
                c = cl[int((s0 + a) / L * N) % N]; t = tang[int((s0 + a) / L * N) % N]
                px = c[0] - t[1] * b; py = c[1] + t[0] * b
                X, Y = to_screen(px, py)
                col = rnd.choice([RED, YELLOW, WA1, P2])
                ImageDraw.Draw(dummy := Image.new('L', (1, 1))).point((0, 0))
                for (u, v, cc) in ((0, 0, col), (1, 0, col), (0, 1, col), (1, 1, BLACK), (0, -1, WHITE)):
                    xx = int(X) + u; yy = int(Y) + v - 1
                    if 0 <= xx < WW and 0 <= yy < WH: img[yy, xx] = cc
        elif kind == 'bump':        # loose batteries lying on the road
            for k in range(3):
                a = -8 + k * 8; b = off + rnd.uniform(-4, 4)
                c = cl[int((s0 + a) / L * N) % N]; t = tang[int((s0 + a) / L * N) % N]
                px = c[0] - t[1] * b; py = c[1] + t[0] * b
                X, Y = to_screen(px, py)
                pim = Image.fromarray(img); draw_box(pim, X, Y, 10, 5, 5, YELLOW, BLACK, RL); img = np.array(pim)
                rr = np.sqrt((ds - a) ** 2 + (LAT - b) ** 2)
                surf[road & (rr < 6)] = SURF_BUMP
        elif kind == 'zap':         # electric plates
            m = road & (np.abs(ds) < 7) & (np.abs(LAT - off) < 9)
            img[m] = np.where(((np.floor(wx) + np.floor(wy)) % 4) < 2, FX, W2)[m]
            img[m & ((np.abs(ds) > 6) | (np.abs(LAT - off) > 8))] = BLACK
            surf[m] = SURF_ZAP
        elif kind == 'ramp':        # a wedge across the road, rising in the race direction
            m = road & (ds > -10) & (ds < 4)
            h = np.clip((ds + 10) / 14, 0, 1)
            surf[m] = SURF_RAMP
            img[m] = np.where(h > 0.66, RL, np.where(h > 0.33, RM, RD))[m]
            stripes = m & ((np.floor((LAT + 40) / 6) % 2) == 0) & (ds > 1)
            img[stripes] = YELLOW
            img[road & (np.abs(ds - 4) < 1)] = BLACK
    # walls: extruded upwards, near rows over far rows
    k1w, k2w = (W1, W2)
    for y in range(WH):
        xs = np.nonzero(wallm[y])[0]
        if len(xs) == 0: continue
        sv = S[y, xs]
        seg = (sv // 6).astype(int)
        side = np.where(seg % 2 == 0, W1, W0).astype(np.uint8)
        for h in range(WALLH):
            yy = y - h
            if yy < 0: break
            col = side.copy()
            if theme in ('garage', 'arena', 'building'):     # stacked tyres
                col = np.where((h % 3) == 1, W0, np.where((sv % 6) < 1, W0, W1)).astype(np.uint8)
                if theme == 'building': col = np.where(((sv + h) // 4).astype(int) % 2 == 0, YELLOW, BLACK).astype(np.uint8)
            elif theme == 'toystore':
                col = np.array([[P1, WA1, YELLOW, RL][int(v // 10) % 4] for v in sv], np.uint8)
                if h == 0: col[:] = W0
            elif theme == 'living':                          # books on their side
                col = np.array([[P1, W1, WA0, RD, P0][int(v // 5) % 5] for v in sv], np.uint8)
            elif theme == 'school':
                col = np.where(((sv // 8).astype(int) + (h // 5)) % 2 == 0, RED, WHITE).astype(np.uint8)
            elif theme == 'lab':
                col = np.where(h % 4 == 0, W2, W1).astype(np.uint8)
            elif theme == 'kitchen':                         # bread loaf slices
                col = np.where((sv % 7) < 1, W0, np.where(h > 6, W2, W1)).astype(np.uint8)
            elif theme == 'bathroom':                        # tiled kerb
                col = np.where(((sv // 5).astype(int) + h // 4) % 2 == 0, W2, W1).astype(np.uint8)
            elif theme == 'garden':
                col = np.where((sv % 9) < 1, W0, np.where(h < 3, W0, W1)).astype(np.uint8)
            img[yy, xs] = col
        if y - WALLH >= 0:
            img[y - WALLH, xs] = W2
    # props on the floor, far ones first, none over the track
    occupied = (D <= R + KERB + WALL + 2) | CUT
    pim = Image.fromarray(img)
    tries = 0; placed = []
    while tries < 900 and len(placed) < tr.get('nprops', 19):
        tries += 1
        X = rnd.randint(20, WW - 20); Y = rnd.randint(40, WH - 6)
        if occupied[Y, X]: continue
        if any(abs(X - a) < 52 and abs(Y - b) < 40 for a, b, _ in placed): continue
        kind = rnd.choice(tr['props'])
        test = Image.new('P', (WW, WH), 255)
        bb = draw_prop(test, kind, X, Y, random.Random(tries))
        t = np.array(test) != 255
        if (t & occupied).any(): continue
        if (t & (np.array([[0]]) == 1)).any(): pass
        placed.append((X, Y, kind))
    for X, Y, kind in sorted(placed, key=lambda p: p[1]):
        draw_prop(pim, kind, X, Y, random.Random(X * 7 + Y))
    img = np.array(pim)

    # surface map: 4x2 screen pixels per byte (the ground point of the car)
    sm = surf.reshape(SH, 2, SW, 4)
    # wall wins in a cell, else the most special surface
    smap = np.zeros((SH, SW), np.uint8)
    sub = sm[:, 0, :, 1]
    smap[:] = sub
    smap[(sm == SURF_WALL).sum(axis=(1, 3)) >= 5] = SURF_WALL
    # racing line points every 16 units, pickup spots, the grid
    wp = cl[::8]
    tw = np.roll(cl, -4, axis=0)[::8] - np.roll(cl, 4, axis=0)[::8]
    return dict(img=img, smap=smap, cl=cl, L=L, wp=wp, tw=tw, tang=tang, cut=cutline, props=placed)

def preview(tr, res, path, theme_pal):
    im = Image.fromarray(res['img'], 'P')
    pal = [0] * 768
    for i, c in enumerate(theme_pal):
        pal[i * 3:i * 3 + 3] = [((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17]
    for i, c in SHARED.items():
        pal[i * 3:i * 3 + 3] = [((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17]
    im.putpalette(pal)
    im.convert('RGB').save(path)

if __name__ == '__main__':
    import sys, time, os
    sys.path.insert(0, os.path.dirname(__file__))
    import lz
    os.makedirs('build/prev', exist_ok=True)
    which = [int(a) for a in sys.argv[1:]] or range(len(TRACKS))
    for i in which:
        t0 = time.time(); tr = TRACKS[i]
        res = render(tr, i)
        preview(tr, res, 'build/prev/track%d.png' % i, THEMES[tr['theme']])
        a = res['img']
        planes = bytearray()
        for y in range(WH):
            for p in range(5):
                planes += np.packbits((a[y] >> p) & 1).tobytes()
        pk = lz.pack(bytes(planes)); sp = lz.pack(res['smap'].tobytes())
        print(i, tr['name'], 'lap %.0f' % res['L'], 'packed', len(pk), 'surf', len(sp), 'props', len(res['props']), '%.1fs' % (time.time() - t0))
