#!/usr/bin/env python3
"""shots_v04.py - V0.4 screenshots (into screenshots/): title intro, start lights, big texts,
the new tracks, backwards races, the time trial ghost and the STRONKIE POCKET."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from harness import Game
import autopilot
OUT = os.path.join(os.path.dirname(__file__), '..', 'screenshots')
g = Game(out=OUT)
POCKET_ONLY = os.environ.get('POCKET_ONLY')
if POCKET_ONLY:
    g.run(40); g.joy('down', 25); g.joy('down', 25); g.fire(); g.wait('st_practice', 900); g.run(10)
    g.am.wl(g.A('state'), g.A('st_ttend'))
if not POCKET_ONLY:
    g.run(97); g.shot('v04_01_title')
    # a career race, the National Cup, Kitchen Table backwards
    g.fire(); g.wait('st_intro', 900); g.run(20)
    g.am.wb(g.A('r_cup'), 1); g.am.wb(g.A('r_race'), 8)
    g.am.wl(g.A('state'), g.A('st_intro_in')); g.wait('st_intro', 900); g.run(30); g.shot('v04_02_backwards')
    g.fire(); g.wait('st_race', 1500); g.run(56); g.shot('v04_03_start_lights')
    g.run(100); autopilot.drive(g, 420, fire_every=30); g.shot('v04_04_kitchen_table')
    b = g.A('cars'); g.am.ww(b + 16, 2); g.am.ww(b + 20, 1)
    for k in range(40):
        autopilot.drive(g, 30, fire_every=30)
        if g.sw('ovl_cur') == 7: g.run(8); g.shot('v04_05_final_lap'); break
    # practice: the secret bathroom (unlocked) and the time trial
    g.key(0x45, 4); g.key(0x45, 10); g.wait('st_title', 1500); g.run(10)
    g.am.wb(g.A('r_unlock'), 3)
    for k in range(2): g.joy('down', 25)
    g.fire(); g.wait('st_practice', 900); g.run(10)
    while g.w('cur_track') != 9: g.joy('left', 25)
    g.joy('down', 20); g.joy('down', 20); g.run(10); g.shot('v04_06_practice_modes')
    g.fire(); g.wait('st_race', 1500); g.run(170)
    for k in range(40):
        autopilot.drive(g, 60)
        if g.am.rw(b + 16) >= 1: break
    autopilot.drive(g, 160, look=5); g.shot('v04_07_bathroom_ghost')
    g.am.ww(b + 16, 3); g.am.ww(b + 20, 1)
    autopilot.drive(g, 2500)
    g.wait('st_ttend', 900); g.run(20); g.shot('v04_08_time_trial')
# the STRONKIE POCKET (SCREEN on the title)
g.fire(); g.wait('st_practice', 900); g.run(10)
g.am.wb(g.A('r_retro'), 1)
while g.w('cur_track') != 4: g.joy('right', 25)
while g.w('prac_mode') != 0: g.joy('up', 20)
g.fire(); g.wait('st_race', 1500); g.run(60); g.shot('v04_09_pocket_start')
g.run(110); autopilot.drive(g, 500, fire_every=20); g.shot('v04_10_pocket_race')
