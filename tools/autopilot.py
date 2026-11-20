"""autopilot.py - steer your car with the joystick along the racing line (for the tests)."""
import math
CARSZ = 128
def s16(v): return v - 65536 if v & 0x8000 else v
def drive(g, frames, look=3, fire_every=0):
    am = g.am; base = g.A('cars'); wpp = g.l('wp_ptr'); n = g.w('nwp')
    am.joy['up'] = 1
    for f in range(0, frames, 2):
        x = am.rl(base) / 256.0; y = am.rl(base + 4) / 256.0
        if x > 2 ** 23: x -= 2 ** 24
        if y > 2 ** 23: y -= 2 ** 24
        ang = am.rw(base + 12); wp = am.rw(base + 18)
        t = (wp + look) % n
        tx = s16(am.rw(wpp + t * 6)); ty = s16(am.rw(wpp + t * 6 + 2))
        want = math.atan2(ty - y, tx - x) / (2 * math.pi) * 256
        d = (want - ang + 128) % 256 - 128
        am.joy['left'] = 1 if d < -3 else 0
        am.joy['right'] = 1 if d > 3 else 0
        am.joy['fire'] = 1 if (fire_every and (f // 2) % fire_every == 0) else 0
        am.run_frames(2)
        if g.state() != 'st_race': break
    for k in ('up', 'left', 'right', 'fire'): am.joy[k] = 0
