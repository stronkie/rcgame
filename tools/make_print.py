#!/usr/bin/env python3
"""make_print.py - the printed extras of RC Turbo Cup, in the style of a
1980s/90s Amiga big box release.

  print/RCTurboCup_Manual.pdf      A5 manual (8 pages)
  print/RCTurboCup_DiskLabels.pdf  A4 sheet of 3.5" disk labels
  print/RCTurboCup_Box.pdf         fold-up box with the system requirements: A3 full size + an A4 mini

Uses the screenshots in screenshots/, the cover art (itch/cover_630x500.png) and
the game's own car and pickup graphics.  Created By Mark Stronks, Stronkie Soft 2026.
"""
import os, sys
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.pagesizes import A3, A4, A5, landscape
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, Frame, Table, TableStyle

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
SHOTS = os.path.join(ROOT, 'screenshots')
OUT = os.path.join(ROOT, 'print'); os.makedirs(OUT, exist_ok=True)
VER = os.environ.get('VER', '0.2')
KIND = 'FINAL RELEASE' if VER.startswith('1') else 'TEST VERSION'
TT = '/usr/share/fonts/truetype/'
for name, f in [('Body', 'crosextra/Carlito-Regular.ttf'), ('BodyB', 'crosextra/Carlito-Bold.ttf'),
                ('Head', 'dejavu/DejaVuSans-BoldOblique.ttf'), ('Sans', 'dejavu/DejaVuSans.ttf'),
                ('SansB', 'dejavu/DejaVuSans-Bold.ttf'), ('Mono', 'dejavu/DejaVuSansMono-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name, TT + f))

NAVY = HexColor('#10142c'); NAVYL = HexColor('#22284e'); YELLOW = HexColor('#ffd428'); ORANGE = HexColor('#ff8c00')
RED = HexColor('#dc1e1e'); BLUE = HexColor('#6ebeff'); GREY = HexColor('#555566'); PAPER = HexColor('#f8f8f4')
LIGHT = HexColor('#eef0f8')

def shot(name): return os.path.join(SHOTS, name + '.png')
COVER = os.path.join(ROOT, 'itch', 'cover_630x500.png')
LOGO = os.path.join(ROOT, 'assets', 'stronkiesoft_logo_x2.png')

body = ParagraphStyle('b', fontName='Body', fontSize=9.8, leading=12.6, textColor=black, spaceAfter=4)
head = ParagraphStyle('h', fontName='Head', fontSize=15, leading=18, textColor=NAVY, spaceAfter=5)
sub = ParagraphStyle('h2', fontName='SansB', fontSize=9.5, leading=12.5, textColor=RED, spaceAfter=3, spaceBefore=5)
def P(t, st=body): return Paragraph(t, st)

def img(c, src, x, y, w=None, h=None):
    im = src if isinstance(src, Image.Image) else Image.open(src)
    iw, ih = im.size
    if w and not h: h = w * ih / iw
    if h and not w: w = h * iw / ih
    if im.mode == 'RGBA': c.drawImage(ImageReader(im), x, y, w, h, mask='auto')
    else: c.drawImage(ImageReader(im.convert('RGB')), x, y, w, h)
    return w, h

def flow(c, items, x, y, w, h):
    f = Frame(x, y, w, h, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0, showBoundary=0)
    rest = f.addFromList(list(items), c)
    if rest: print('  (text did not fit:', len(rest), 'items)')

def chequer(c, x, y, w, h, n=None):
    s = h / 2; n = n or int(w / s)
    for i in range(n):
        for r in range(2):
            c.setFillColor(white if (i + r) % 2 == 0 else black)
            c.rect(x + i * s, y + r * s, s, s, stroke=0, fill=1)

def title_text(c, cx, y, size, text='RC TURBO CUP'):
    """the logo: chrome yellow letters with a red shadow"""
    c.setFont('Head', size)
    for d, col in ((size * 0.09, HexColor('#5a0000')), (size * 0.06, HexColor('#a00000')), (size * 0.03, RED)):
        c.setFillColor(col); c.drawCentredString(cx + d, y - d, text)
    c.setFillColor(black)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        c.drawCentredString(cx + dx * size * 0.03, y + dy * size * 0.03, text)
    c.setFillColor(YELLOW); c.drawCentredString(cx, y, text)

def table(rows, widths, size=8.6):
    t = Table(rows, colWidths=widths)
    t.setStyle(TableStyle([('FONT', (0, 0), (-1, -1), 'Body', size), ('FONT', (0, 0), (-1, 0), 'SansB', size - 0.6),
                           ('FONT', (0, 1), (0, -1), 'BodyB', size),
                           ('BACKGROUND', (0, 0), (-1, 0), NAVY), ('TEXTCOLOR', (0, 0), (-1, 0), YELLOW),
                           ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, LIGHT]),
                           ('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                           ('TOPPADDING', (0, 0), (-1, -1), 2), ('BOTTOMPADDING', (0, 0), (-1, -1), 2)]))
    return t

def page_frame(c, W, H, n, title):
    c.setFillColor(PAPER); c.rect(0, 0, W, H, stroke=0, fill=1)
    c.setFillColor(NAVY); c.rect(0, H - 13 * mm, W, 13 * mm, stroke=0, fill=1)
    chequer(c, 0, H - 15 * mm, W, 2 * mm)
    c.setFillColor(YELLOW); c.setFont('Head', 13); c.drawString(10 * mm, H - 9 * mm, title)
    c.setFont('Sans', 7); c.setFillColor(white); c.drawRightString(W - 10 * mm, H - 8.6 * mm, 'RC TURBO CUP')
    c.setFillColor(GREY); c.setFont('Sans', 7.5); c.drawCentredString(W / 2, 7 * mm, '- %d -' % n)

# ------------------------------------------------------------------ the game's own graphics
def car_image(design, k, colours, scale=4):
    import sprites as SP
    a = SP.render_car15(design, k, ss=6, scale=SP.CAR_SCALE * scale, size=16 * scale, anchor=(8 * scale, 10 * scale))
    cols = {1: (17, 17, 17), 2: colours[0], 3: colours[1], 4: (255, 255, 255), 5: (34, 51, 85), 8: (220, 30, 30),
            9: (136, 136, 153), 12: (255, 210, 30), 13: (150, 200, 255)}
    im = Image.new('RGBA', (a.shape[1], a.shape[0]), (0, 0, 0, 0)); px = im.load()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if a[y, x]: px[x, y] = cols.get(int(a[y, x]), (255, 0, 255)) + (255,)
    return im

def icon_image(name):
    import make_gfx as MG
    a, m = MG.icon(name)
    rgb = {16: (0, 0, 0), 20: (255, 255, 255), 24: (220, 34, 34), 28: (255, 214, 34)}
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); px = im.load()
    for y in range(16):
        for x in range(16):
            if m[y, x]: px[x, y] = rgb.get(int(a[y, x]), (128, 128, 128)) + (255,)
    return im.resize((64, 64), Image.NEAREST)

RIVALS = [('SPEEDY SAM', ((0, 34, 85), (51, 102, 238)), 'The fastest of the four, but he takes the bends too quickly '
           'and hits the walls a lot. Pass him in the corners.'),
          ('CAREFUL CARLA', ((0, 68, 17), (51, 187, 51)), 'Never makes a mistake. Slow in the bends, quick on the '
           'straights - and always there at the finish.'),
          ('MAD MAX', ((51, 51, 51), (136, 136, 136)), 'Fires a missile as soon as you are in front of him, drops '
           'bombs and rams you. Keep your distance.'),
          ('ENGINEER ERIK', ((119, 51, 0), (255, 153, 0)), 'Drives over every power-up he can find: weapons, shields, '
           'turbo and roll cages. Grab them before he does.')]

# ------------------------------------------------------------------ manual
def build_manual(path):
    W, H = A5; c = canvas.Canvas(path, pagesize=A5); c.setTitle('RC Turbo Cup - manual')
    # 1 cover
    c.setFillColor(NAVY); c.rect(0, 0, W, H, stroke=0, fill=1)
    img(c, COVER, 0, H * 0.32, w=W)
    chequer(c, 0, H * 0.30, W, 4 * mm)
    c.setFillColor(YELLOW); c.setFont('Head', 20); c.drawCentredString(W / 2, H * 0.20, 'INSTRUCTION MANUAL')
    c.setFillColor(BLUE); c.setFont('Sans', 9); c.drawCentredString(W / 2, H * 0.12, 'Commodore Amiga 500  -  V%s %s' % (VER, KIND))
    c.setFillColor(white); c.setFont('Sans', 8); c.drawCentredString(W / 2, H * 0.05, 'Created By Mark Stronks, Stronkie Soft (c) 2026')
    c.showPage()
    # 2 getting started
    page_frame(c, W, H, 2, 'GETTING STARTED')
    flow(c, [P('Welcome to RC Turbo Cup', head),
             P('Your radio controlled toy car is small - and the world is huge. Race through a garage, a living room, '
               'a garden, a toy store, a playground, a science lab, a building site and the championship arena, '
               'against four rivals who all want the cup.'),
             P('What you need', sub),
             P('An Amiga 500 (or any Amiga with a 68000) with Kickstart 1.3 and 1 MB of memory: 512K chip memory and a '
               '512K trapdoor expansion. A joystick in port 2. A hard drive, a CF card or WHDLoad are optional.'),
             P('Loading the game', sub),
             P('<b>From disk or Gotek:</b> switch on with the RC Turbo Cup disk in drive DF0: - the game starts by itself.'),
             P('<b>From Workbench:</b> open the disk and double click <b>RCTurbo</b>.'),
             P('<b>On your hard drive:</b> boot Workbench from the hard drive, insert the game disk and double click '
               '<b>Install</b>. Choose the place (DH0: is fine) and the drawer RCTurboCup is made for you.'),
             P('<b>WHDLoad:</b> unpack RCTurboCup_WHDLoad.lha on your hard drive and double click the RCTurboCup icon. '
               'No Kickstart image is needed. F10 quits back to Workbench.'),
             P('Saving', sub),
             P('Your career is saved on the disk (or the hard drive) after every race, so leave the disk '
               'write-enabled. Choose CONTINUE CAREER on the title screen to carry on.')],
         12 * mm, 14 * mm, W - 24 * mm, H - 34 * mm)
    c.showPage()
    # 3 controls and the screen
    page_frame(c, W, H, 3, 'CONTROLS AND THE SCREEN')
    flow(c, [P('Controls', sub),
             table([['Joystick', 'What it does'], ['Left / right', 'steer'], ['Up', 'gas (or fire: see below)'],
                    ['Down', 'brake, then reverse'], ['Fire', 'use your weapon'], ['2nd button / Space', 'use your weapon too'],
                    ['P or Esc', 'pause - Esc again quits the race'], ['M', 'music on or off']],
                   [32 * mm, W - 24 * mm - 32 * mm]),
             P('Prefer the fire button for the gas? Choose <b>CONTROLS: FIRE = GAS</b> on the title screen; then '
               'pushing the joystick up fires your weapon. The cursor keys work as a joystick as well.'),
             P('The race screen', sub)], 12 * mm, H * 0.46, W - 24 * mm, H * 0.5 - 14 * mm)
    img(c, shot('v02_04_garage'), 12 * mm, H * 0.20, w=W - 24 * mm)
    flow(c, [P('The track scrolls with your car. At the bottom: the <b>minimap</b> with all four cars, your speed '
               '(MPH), the lap, your place, C S T (roll cage, shield, turbo), the damage blocks, the STRONKIE '
               'letters you have, your weapon and your cash.')], 12 * mm, 12 * mm, W - 24 * mm, H * 0.08)
    c.showPage()
    # 4 pickups and hazards
    page_frame(c, W, H, 4, 'PICKUPS AND HAZARDS')
    items = [('MOTOR', 'Motor: higher top speed (for good)'), ('TIRES', 'Tires: more grip, sharper turns (for good)'),
             ('BATTERY', 'Battery: faster acceleration (for good)'), ('MISSILES', 'Two missiles: fire at the car ahead'),
             ('BOMBS', 'Two bombs: they drop behind you'), ('HOMING', 'Homing missile: finds the car in front'),
             ('CASH', '$100 for the shop'), ('CAGE', 'Roll cage: takes two hits or hard knocks'),
             ('TURBO', 'Turbo battery: 10 seconds faster'), ('SHIELD', 'Shield: 5 seconds untouchable'),
             ('REPAIR', 'Repair kit: all damage gone'), ('S', 'A STRONKIE letter: see page 5')]
    y = H - 24 * mm
    for i, (n, t) in enumerate(items):
        x = 12 * mm + (i % 2) * ((W - 24 * mm) / 2)
        yy = y - (i // 2) * 12 * mm
        img(c, icon_image(n), x, yy - 8 * mm, w=8 * mm)
        st = ParagraphStyle('it', parent=body, fontSize=8.6, leading=10)
        flow(c, [P(t, st)], x + 10 * mm, yy - 9 * mm, (W - 24 * mm) / 2 - 12 * mm, 10 * mm)
    flow(c, [P('The motor, tires, battery, the cash and the letters are only for you: the other cars drive past them. '
               'They do use the weapons, roll cages, turbos, shields and repair kits, and a used box comes back after a while.'),
             P('On the track', sub),
             P('<b>Yellow zippers</b> give you a burst of speed. <b>Ramps</b> make you jump (fast enough, you fly over the '
               'water behind them). <b>Oil</b> and chemical spills make you slide, <b>marbles</b> shake your steering, '
               '<b>water</b>, <b>sand</b> and <b>grass</b> slow you down, <b>loose batteries</b> make you bounce and the '
               '<b>electric plates</b> in the lab spin you round. Hard knocks on the walls cost damage: a damaged car is '
               'slower, and with too much damage it breaks down for a moment.')],
         12 * mm, 12 * mm, W - 24 * mm, H - 24 * mm - 6 * 12 * mm - 16 * mm)
    c.showPage()
    # 5 rivals and cars
    page_frame(c, W, H, 5, 'YOUR RIVALS AND YOUR CAR')
    y = H - 22 * mm
    for i, (name, cols, text) in enumerate(RIVALS):
        yy = y - i * 22 * mm
        img(c, car_image(1 + i % 3, 1, cols, 3), 12 * mm, yy - 16 * mm, w=16 * mm)
        flow(c, [P('<b>%s</b>' % name, sub), P(text, ParagraphStyle('r', parent=body, fontSize=9, leading=11))],
             32 * mm, yy - 20 * mm, W - 44 * mm, 20 * mm)
    flow(c, [P('Your car and the STRONKIE letters', sub),
             P('You start with the Rookie Buggy. In every race one red box carries a letter: collect '
               'S - T - R - O - N - K - I - E, one by one, over the races. With all eight you get the next car - Sport RC, '
               'Turbo RC, Super RC and finally the Champion RC - plus $2000 and a new paint job for the shop.')],
         12 * mm, 12 * mm, W - 24 * mm, H - 24 * mm - 4 * 22 * mm - 6 * mm)
    names = ['ROOKIE BUGGY', 'SPORT RC', 'TURBO RC', 'SUPER RC', 'CHAMPION RC']
    for d in range(5):
        x = 12 * mm + d * (W - 24 * mm) / 5
        img(c, car_image(d, 1, ((119, 0, 0), (238, 34, 34)), 3), x, 30 * mm, w=17 * mm)
        c.setFont('SansB', 5.5); c.setFillColor(NAVY); c.drawCentredString(x + 8.5 * mm, 27 * mm, names[d])
    c.showPage()
    # 6 career and shop
    page_frame(c, W, H, 6, 'THE CAREER AND THE SHOP')
    flow(c, [P('Three cups', sub),
             P('The <b>Amateur Cup</b>, the <b>National Cup</b> and the <b>World Championship</b>, each with 8 races on the 8 '
               'tracks. Every race is 4 laps against three of the four rivals (a different one sits out each race).'),
             P('Finish in the <b>top 3</b> to go on to the next race. A <b>4th place</b> costs one of your spare cars and you '
               'race again. No spare cars left: game over. In the later cups it can rain (slippery!) or blow (the wind '
               'pushes your car).'),
             table([['Place', 'Prize money', 'Points'], ['1st', '$1000', '10'], ['2nd', '$600', '6'], ['3rd', '$300', '3'],
                    ['4th', '-', '1']], [20 * mm, 40 * mm, 30 * mm]),
             P('The prize money is 1.5x in the National Cup and 2x in the World Championship. The points decide the '
               'trophy at the end of a cup: gold, silver or bronze.'),
             P('The shop', sub),
             table([['Item', 'What it does'], ['Motor', 'top speed (5 levels)'], ['Tires', 'grip and steering (5 levels)'],
                    ['Battery', 'acceleration (5 levels)'], ['Armor', 'less damage from the walls (5 levels)'],
                    ['Weapon rack', 'carry up to 6 missiles or bombs'], ['2 missiles / 2 bombs', '$150 a pair'],
                    ['Spare car', '$2500'], ['Paint', 'the paint jobs you have unlocked']],
                   [32 * mm, W - 24 * mm - 32 * mm])],
         12 * mm, 12 * mm, W - 24 * mm, H - 30 * mm)
    c.showPage()
    # 7 tracks
    page_frame(c, W, H, 7, 'THE TRACKS')
    tracks = [('1 GARAGE GRAND PRIX', 'On the workbench between nuts, bolts and the toolbox. A good one to learn on.'),
              ('2 LIVING ROOM RALLY', 'Over the carpet, past the mugs and the remote. Watch the marbles.'),
              ('3 GARDEN SPRINT', 'The garden path with puddles, a jump over the water - and a grass shortcut.'),
              ('4 TOY STORE DASH', 'A plastic toy track between building blocks and rubber ducks.'),
              ('5 PLAYGROUND PURSUIT', 'The school playground: sand pits, a ramp and tight hairpins.'),
              ('6 SCIENCE LAB CIRCUIT', 'Chemical spills and electric plates that spin you round.'),
              ('7 CONSTRUCTION CRASH', 'Sand, gravel, bricks, pipes and two big jumps.'),
              ('8 CHAMPIONSHIP ARENA', 'The longest track, with grandstands, oil and everything else.')]
    pics = {6: 'v02_03_start', 0: 'v02_04_garage', 1: 'v02_07_living_room', 2: 'v02_10_garden', 3: 'v02_11_toy_store', 4: 'v02_12_playground',
            5: 'v02_13_science_lab', 7: 'v02_15_arena'}
    cw = (W - 24 * mm - 6 * mm) / 2
    for i, (n, t) in enumerate(tracks):
        x = 12 * mm + (i % 2) * (cw + 6 * mm); y = H - 22 * mm - (i // 2) * 44 * mm
        p = pics.get(i)
        if p and os.path.exists(shot(p)):
            im = Image.open(shot(p)).crop((0, 0, 640, 420))
            img(c, im, x, y - 28 * mm, w=cw, h=28 * mm)
        else:
            c.setFillColor(NAVYL); c.rect(x, y - 28 * mm, cw, 28 * mm, stroke=0, fill=1)
        flow(c, [P('<b>%s</b>' % n, ParagraphStyle('tn', parent=body, fontSize=8.4, leading=10, textColor=RED)),
                 P(t, ParagraphStyle('tt', parent=body, fontSize=8, leading=9.6))], x, y - 42 * mm, cw, 13 * mm)
    c.showPage()
    # 8 back
    c.setFillColor(NAVY); c.rect(0, 0, W, H, stroke=0, fill=1)
    chequer(c, 0, H - 6 * mm, W, 4 * mm)
    st = ParagraphStyle('w', parent=body, textColor=white)
    sh = ParagraphStyle('wh', parent=sub, textColor=YELLOW)
    flow(c, [P('Racing tips', sh),
             P('- Brake a little before the hairpins; a wall costs more time than braking.', st),
             P('- Missiles fly straight: line up behind the car in front first.', st),
             P('- Save a roll cage or a shield for the last lap.', st),
             P('- Spend money on the motor and the tires first, a spare car when you are low.', st),
             P('- Practice mode keeps your best laps: try to beat them.', st),
             P('Credits', sh),
             P('Game, code, graphics, music and sound: Created By Mark Stronks, Stronkie Soft.', st),
             P('Written in 68000 assembly for the Amiga 500. Thanks to everybody who tests the game - tell me what you '
               'think on <b>stronkie.itch.io</b>!', st)],
         12 * mm, H * 0.30, W - 24 * mm, H * 0.62)
    img(c, LOGO, W / 2 - 25 * mm, H * 0.09, w=50 * mm)
    c.setFillColor(white); c.setFont('Sans', 8); c.drawCentredString(W / 2, H * 0.05, 'stronkie.itch.io  -  (c) 2026 Stronkie Soft')
    c.showPage(); c.save()

# ------------------------------------------------------------------ disk labels
def disk_label(c, x, y, w, h, demo=False):
    c.setFillColor(NAVY); c.rect(x, y, w, h, stroke=0, fill=1)
    art = Image.open(COVER).convert('RGB'); aw, ah = art.size
    crop = art.crop((0, int(ah * 0.55), aw, int(ah * 0.95)))
    c.drawImage(ImageReader(crop), x, y + h * 0.26, w, h * 0.36)
    chequer(c, x, y + h * 0.62, w, 2.4 * mm)
    title_text(c, x + w / 2, y + h * 0.75, 15)
    c.setFillColor(YELLOW); c.setFont('SansB', 7)
    c.drawCentredString(x + w / 2, y + h * 0.17, ('FREE DEMO  -  V%s' if demo else 'AMIGA 500  -  V%s') % VER)
    c.setFillColor(white); c.setFont('Sans', 6)
    c.drawCentredString(x + w / 2, y + h * 0.10, 'Created By Mark Stronks - STRONKIE SOFT')
    c.drawCentredString(x + w / 2, y + h * 0.04, 'Kickstart 1.3  -  1 MB  -  joystick  -  (c) 2026')
    c.setStrokeColor(GREY); c.setDash(2, 2); c.setLineWidth(0.3); c.rect(x, y, w, h, stroke=1, fill=0); c.setDash()

def build_labels(path):
    W, H = A4; c = canvas.Canvas(path, pagesize=A4); c.setTitle('RC Turbo Cup - disk labels')
    w, h = 70 * mm, 54 * mm
    for r in range(4):
        for col in range(2):
            disk_label(c, 30 * mm + col * (w + 10 * mm), H - 25 * mm - (r + 1) * (h + 8 * mm), w, h, demo=(r == 3 and col == 1))
    c.setFont('Sans', 7); c.setFillColor(GREY)
    c.drawCentredString(W / 2, 12 * mm, 'RC Turbo Cup - 3.5" disk labels (the last one is for the free demo). Cut along the dashed lines.')
    c.showPage(); c.save()

# ------------------------------------------------------------------ box
def box_front(c, x, y, w, h):
    c.setFillColor(NAVY); c.rect(x, y, w, h, stroke=0, fill=1)
    img(c, COVER, x, y + h * 0.18, w=w, h=h * 0.75)
    chequer(c, x, y + h * 0.16, w, h * 0.02)
    c.setFillColor(RED); c.rect(x, y, w, h * 0.1, stroke=0, fill=1)
    c.setFillColor(white); c.setFont('Head', w * 0.06); c.drawCentredString(x + w / 2, y + h * 0.032, 'AMIGA')
    c.setFillColor(YELLOW); c.setFont('SansB', w * 0.026)
    c.drawCentredString(x + w / 2, y + h * 0.122, 'ISOMETRIC TOY CAR RACING  -  8 TRACKS  -  3 CUPS')

def box_back(c, x, y, w, h):
    c.setFillColor(NAVY); c.rect(x, y, w, h, stroke=0, fill=1)
    c.setFillColor(YELLOW); c.setFont('Head', w * 0.058); c.drawCentredString(x + w / 2, y + h * 0.935, 'SMALL CARS. BIG RACES.')
    sw = w * 0.42
    for i, n in enumerate(('v02_04_garage', 'v02_10_garden', 'v02_13_science_lab', 'v02_06_shop')):
        cx = x + w * 0.05 + (i % 2) * (sw + w * 0.06); cy = y + h * 0.66 - (i // 2) * (sw * 0.8 + h * 0.015)
        if os.path.exists(shot(n)): img(c, shot(n), cx, cy, w=sw)
    st = ParagraphStyle('bk', fontName='Body', fontSize=w / 46, leading=w / 37, textColor=white)
    flow(c, [P('<b>Race your radio controlled toy car</b> through a garage, a living room, the garden, a toy store, the '
               'playground, a science lab, a building site and the championship arena - 8 smoothly scrolling isometric '
               'tracks in 32 colours. Beat Speedy Sam, Careful Carla, Mad Max and Engineer Erik in three cups, with '
               'missiles, bombs, turbos, shields, zippers and jumps. Spend your prize money in the shop and collect '
               'S-T-R-O-N-K-I-E for faster cars.', st)],
         x + w * 0.06, y + h * 0.215, w * 0.88, h * 0.155)
    # the system requirements
    bx, by, bw, bh = x + w * 0.06, y + h * 0.035, w * 0.88, h * 0.165
    c.setFillColor(white); c.rect(bx, by, bw, bh, stroke=0, fill=1)
    c.setFillColor(RED); c.rect(bx, by + bh - h * 0.03, bw, h * 0.03, stroke=0, fill=1)
    c.setFillColor(white); c.setFont('SansB', w * 0.03); c.drawString(bx + w * 0.02, by + bh - h * 0.022, 'SYSTEM REQUIREMENTS')
    c.setFillColor(black); c.setFont('Sans', w * 0.024)
    lines = ['Commodore Amiga 500 (or any Amiga with a 68000 CPU)', 'Kickstart / Workbench 1.3',
             '1 MB memory: 512K chip + 512K trapdoor expansion', 'Joystick in port 2  -  1 player',
             'Disk drive or Gotek; hard drive / CF card and WHDLoad supported']
    for i, t in enumerate(lines):
        c.drawString(bx + w * 0.025, by + bh - h * 0.055 - i * h * 0.022, '- ' + t)
    c.setFillColor(GREY); c.setFont('Sans', w * 0.018)
    c.drawCentredString(x + w / 2, y + h * 0.012, 'Created By Mark Stronks, Stronkie Soft (c) 2026  -  stronkie.itch.io')

def box_spine(c, x, y, w, h, rot):
    c.saveState(); c.setFillColor(NAVY); c.rect(x, y, w, h, stroke=0, fill=1)
    c.translate(x + w / 2, y + h / 2); c.rotate(rot)
    c.setFillColor(YELLOW); c.setFont('Head', w * 0.3); c.drawCentredString(0, -w * 0.1, 'RC TURBO CUP')
    c.setFillColor(white); c.setFont('SansB', w * 0.14); c.drawCentredString(h * 0.4, -w * 0.05, 'AMIGA')
    c.drawCentredString(-h * 0.38, -w * 0.05, 'STRONKIE SOFT')
    c.restoreState()

def box_net(c, ox, oy, s):
    w, h, d = 120 * mm * s, 160 * mm * s, 30 * mm * s
    x0 = ox + d
    c.setLineWidth(0.4); c.setStrokeColor(GREY)
    box_spine(c, ox, oy + d, d, h, 90)
    box_front(c, x0, oy + d, w, h)
    box_spine(c, x0 + w, oy + d, d, h, -90)
    box_back(c, x0 + w + d, oy + d, w, h)
    for fx in (x0, x0 + w + d):
        for fy in (oy, oy + d + h):
            c.setFillColor(NAVYL); c.rect(fx, fy, w, d, stroke=0, fill=1)
            chequer(c, fx, fy + d * 0.08, w, d * 0.14)
            c.setFillColor(YELLOW); c.setFont('SansB', d * 0.15)
            c.drawCentredString(fx + w / 2, fy + d * 0.45, 'RC TURBO CUP  -  AMIGA 500  -  STRONKIE SOFT')
    c.setFillColor(HexColor('#dddddd')); c.rect(x0 + 2 * w + d, oy + d, d * 0.6, h, stroke=0, fill=1)
    c.setDash(3, 2)
    for xx in (x0, x0 + w, x0 + w + d, x0 + 2 * w + d):
        c.line(xx, oy + d, xx, oy + d + h)
    for yy in (oy + d, oy + d + h):
        c.line(ox, yy, x0 + 2 * w + d, yy)
    c.setDash()

def build_box(path):
    c = canvas.Canvas(path, pagesize=landscape(A3)); c.setTitle('RC Turbo Cup - box')
    box_net(c, 20 * mm, 30 * mm, 1.0)
    c.setFont('Sans', 8); c.setFillColor(GREY)
    c.drawString(20 * mm, 12 * mm, 'RC Turbo Cup - fold-up box (A3). Cut on the outside, fold on the dashed lines, glue the grey flap.')
    c.showPage()
    c.setPageSize(landscape(A4))
    box_net(c, 12 * mm, 20 * mm, 0.62)
    c.setFont('Sans', 7); c.setFillColor(GREY)
    c.drawString(12 * mm, 9 * mm, 'Mini box (A4). Cut on the outside, fold on the dashed lines, glue the grey flap.')
    c.showPage(); c.save()

if __name__ == '__main__':
    build_manual(os.path.join(OUT, 'RCTurboCup_Manual.pdf'))
    build_labels(os.path.join(OUT, 'RCTurboCup_DiskLabels.pdf'))
    build_box(os.path.join(OUT, 'RCTurboCup_Box.pdf'))
    for f in sorted(os.listdir(OUT)): print(f, os.path.getsize(os.path.join(OUT, f)))
