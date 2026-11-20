# RC Turbo Cup

![Title](screenshots/v01_01_title.png)

**Isometric toy car racing for the Amiga 500.** Race a radio controlled toy car through oversized rooms against Speedy Sam, Careful Carla, Mad Max and Engineer Erik. Collect upgrades and weapons on the track, spend your prize money in the shop and win three cups.

Created By Mark Stronks, Stronkie Soft © 2026

Written in 68000 assembly for a stock Amiga 500 with Kickstart / Workbench 1.3 and a 512K trapdoor expansion (1 MB). Runs from a bootable disk (or a Gotek), from hard drive / CF card and with WHDLoad. Play it with a **joystick** in port 2 (or the keyboard).

**Latest version: V0.1 - TEST VERSION.**

## Features

- **Scrolling isometric tracks** with walls, kerbs and giant props, in 32 colours with hardware scrolling, and a HUD with a minimap, speed, lap, place, weapon, cash and your STRONKIE letters
- **8 tracks** in 8 toy worlds: Garage Grand Prix, Living Room Rally, Garden Sprint (with a grass shortcut), Toy Store Dash, Playground Pursuit, Science Lab Circuit, Construction Crash and the Championship Arena
- **4 cars, 4 laps**: finish in the top 3 to go on, 4th place costs a spare car and a retry
- **Career**: Amateur Cup, National Cup and World Championship, 8 races each, with prize money, points and gold / silver / bronze trophies
- **4 rivals with their own personality**: Speedy Sam (fast, crashes), Careful Carla (steady), Mad Max (fires at you and rams you) and Engineer Erik (drives over the upgrades and keeps them)
- **Pickups on the track**: motor, tires and battery (permanent upgrades), missiles, bombs, homing missiles, cash, roll cage, turbo, shield and repair
- **STRONKIE letters**: collect S-T-R-O-N-K-I-E over the races for the next car (Rookie Buggy, Sport RC, Turbo RC, Super RC, Champion RC), $2000 and a new paint job
- **Weapons**: missiles, homing missiles and bombs; explosions spin the car round
- **Track hazards**: zippers, ramps (jumps), oil, marbles, water, sand, loose batteries and electric plates
- **Weather** in the later cups: rain (slippery) and wind
- **The shop**: motor, tires, battery, armor, weapon rack, missiles, bombs, spare cars and paint
- **Practice** on any track, best laps saved
- Music for the title, four race themes, the shop, winning and losing; motor sound; voices ("three, two, one, go!", "finish!")
- Your career is saved on the disk (or the hard drive / WHDLoad)

## Screenshots

![Intro](screenshots/v01_02_intro.png)
![Garage](screenshots/v01_04_garage.png)
![Living room](screenshots/v01_07_living_room.png)
![Garden](screenshots/v01_08_garden.png)
![Playground](screenshots/v01_09_playground.png)
![Science lab](screenshots/v01_10_science_lab.png)
![Arena](screenshots/v01_11_arena.png)
![Results](screenshots/v01_05_results.png)
![Shop](screenshots/v01_06_shop.png)

## Download and run

| File | What it is |
|---|---|
| `RCTurboCup_V0.1.adf` | Bootable disk. Boot it, or put it on a Gotek, and the game starts by itself. To put the game on your hard drive: boot Workbench from the hard drive, insert this disk and double click **Install** |
| `whdload/RCTurboCup_V0.1_WHDLoad.lha` | **WHDLoad version** (also as `.zip`): unpack on your hard drive and double click `RCTurboCup`. Own slave (`src/whdload.s`), no Kickstart image needed, F10 quits |
| `RCTurboCup_V0.1_harddrive.zip` | Drawer `RCTurboCup` with the game, the tracks, its icon and the ReadMe: copy it and double click `RCTurbo` |

**Requirements:** Amiga 500 (or any Amiga with a 68000) with Kickstart 1.3 and 1 MB: 512K chip + 512K trapdoor. Joystick in port 2.

## Controls

| | |
|---|---|
| Left / right | steer |
| Up | gas (or **fire = gas**: switch it on the title screen) |
| Down | brake / reverse |
| Fire, Space, 2nd button | use your weapon |
| P / Esc | pause (Esc again: quit the race) |
| M | music on / off |

## Building

```
sh tools/build.sh          # VER=0.1 by default
```

Needs python3 with Pillow and numpy. Everything else is in `tools/`:

- `tracks.py` - the 8 tracks: layouts, the isometric pictures (ground, road, kerbs, walls, props, hazards), the surface maps and the racing lines
- `sprites.py` - the cars (5 designs x 16 directions, with and without roll cage), missiles, bombs and explosions
- `make_gfx.py` - the track files, pickups, HUD, title and menu screens, sounds, voices and music
- `lz.py` - the packer (the game unpacks with `unlz`)
- `make_loading.py` - the loading picture (and the itch cover)
- `asm68k.py` - a small 68000 assembler that writes Amiga hunk executables
- `make_disk.py` - the bootable OFS disk, Workbench icons and the hard drive zip
- `make_whdload.py` - the WHDLoad package
- `emu68k.py`, `harness.py`, `autopilot.py`, `test_whdload.py`, `test_install.py`, `shots_v01.py` - a small A500 test bench (with scrolling and copper splits): whole races with a joystick autopilot, WHDLoad and the installer

Source: `src/rc.s` (start-up, display, scrolling, sprites, unpacking, text, input, sound), `src/race.s` (cars, physics, computer drivers, weapons, pickups, laps, HUD, camera), `src/menus.s` (title, career, shop, results, practice, track loading, saving), `src/loader.s` (the loader with the loading picture), `src/install.s` (the hard disk installer) and `src/whdload.s` (the WHDLoad slave).

## Version history

### V0.1 - TEST VERSION - 20 November 2026
- The first version: 8 scrolling isometric tracks, 4 cars, career with 3 cups, shop, pickups and weapons, STRONKIE letters, weather, practice, ADF, hard drive and WHDLoad versions

Created By Mark Stronks, Stronkie Soft
