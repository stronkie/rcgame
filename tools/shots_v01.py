#!/usr/bin/env python3
"""shots_v01.py - V0.1 screenshots: title, intro, races, results, shop (into screenshots/)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from harness import Game
import autopilot
OUT = os.path.join(os.path.dirname(__file__), '..', 'screenshots')
g = Game(out=OUT)
g.run(40); g.shot('v01_01_title')
g.fire(); g.wait('st_intro', 900); g.run(60); g.shot('v01_02_intro')
g.fire(); g.wait('st_race', 900); g.run(100); g.shot('v01_03_start')
g.run(70); autopilot.drive(g, 330, fire_every=30); g.shot('v01_04_garage')
b = g.A('cars'); g.am.ww(b + 16, 3); g.am.ww(b + 20, 1)
autopilot.drive(g, 1500, fire_every=30)
g.wait('st_results', 900); g.run(20); g.shot('v01_05_results')
g.fire(); g.wait('st_shop', 900); g.run(20); g.fire(); g.run(30); g.shot('v01_06_shop')
for i in range(9): g.joy('down', 20)
g.fire(); g.wait('st_intro', 900); g.run(30); g.fire(); g.wait('st_race', 900); g.run(170)
autopilot.drive(g, 700, fire_every=20); g.shot('v01_07_living_room')
