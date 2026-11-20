#!/usr/bin/env python3
"""shots_v02.py - V0.2 screenshots: title, intro, races, results, shop (into screenshots/)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from harness import Game
import autopilot
OUT = os.path.join(os.path.dirname(__file__), '..', 'screenshots')
g = Game(out=OUT)
g.run(40); g.shot('v02_01_title')
g.fire(); g.wait('st_intro', 900); g.run(60); g.shot('v02_02_intro')
g.fire(); g.wait('st_race', 900); g.run(100); g.shot('v02_03_start')
g.run(70); autopilot.drive(g, 330, fire_every=30); g.shot('v02_04_garage')
b = g.A('cars'); g.am.ww(b + 16, 3); g.am.ww(b + 20, 1)
autopilot.drive(g, 1500, fire_every=30)
g.wait('st_results', 900); g.run(20); g.shot('v02_05_results')
g.fire(); g.wait('st_shop', 900); g.run(20); g.fire(); g.run(30); g.shot('v02_06_shop')
for i in range(9): g.joy('down', 20)
g.fire(); g.wait('st_intro', 900); g.run(30); g.fire(); g.wait('st_race', 900); g.run(170)
autopilot.drive(g, 700, fire_every=20); g.shot('v02_07_living_room')
# more tracks in practice
g.key(0x45, 4); g.key(0x45, 10); g.wait('st_title_in', 300); g.wait('st_title', 900); g.run(10)
for k in range(2): g.joy('down', 25)
g.fire(); g.wait('st_practice', 900); g.run(10)
for t, name in ((2, 'garden'), (4, 'playground'), (5, 'science_lab'), (7, 'arena'), (3, 'toy_store')):
    while g.w('cur_track') != t: g.joy('right', 25)
    g.fire(); g.wait('st_race', 900); g.run(170)
    b = g.A('cars'); g.am.ww(b + 38, 1); g.am.ww(b + 36, 6); g.am.ww(b + 96, 6)
    autopilot.drive(g, 520, fire_every=12); g.shot('v02_%02d_%s' % (8 + t, name))
    g.key(0x45, 4); g.key(0x45, 10); g.wait('st_practice', 900); g.run(10)
