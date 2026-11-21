#!/bin/sh
# Build Stronkie's RC Cup:  sh tools/build.sh   (VER=0.2 by default)
# Needs python3 with Pillow and numpy.  Assembler and disk tools are in tools/.
#   tools/make_gfx.py     -> build/gen: tracks (Track1..10), sprites, pickups, HUD, title, sounds, music
#   tools/make_loading.py -> build/gen/loadpic.*: the loading picture (and itch/cover_630x500.png)
#   tools/asm68k.py       -> build/RCCup (loader) and build/RCCup.game (src/rc.s + race.s + menus.s)
#   tools/make_disk.py    -> build/*.adf (with the hard disk installer, src/install.s) and the hard drive zip
#   tools/make_whdload.py -> build/*_WHDLoad.lha / .zip: the WHDLoad version (slave: src/whdload.s)
set -e
cd "$(dirname "$0")/.."
export VER=${VER:-0.5}
mkdir -p build/gen
python3 tools/make_gfx.py build/gen
python3 tools/make_loading.py build/gen
python3 tools/asm68k.py src/main.s -I build/gen -I src -o build/RCCup.game -map build/RCCup.map
mkdir -p build/demo
python3 tools/asm68k.py src/demo.s -I build/gen -I src -o build/demo/RCCup.game -map build/demo/RCCup.map
mkdir -p build/gen/Tracks && cp build/gen/Track[0-9] build/gen/Track10 build/gen/Tracks/
python3 tools/asm68k.py src/loader.s -I build/gen -I src -o build/RCCup
cp build/RCCup build/demo/RCCup
python3 tools/make_disk.py "$VER"
python3 tools/make_whdload.py "$VER"
# the free demo: 2 tracks, no installer, no saving
DISK_BUILD=build/demo DISK_NAME=StronkiesRCCup_DEMO_V$VER DISK_DRAWER=StronkiesRCCupDemo DISK_VOLUME=RCCupDemo DISK_TRACKS=2 \
  DISK_README=ReadMe_demo.txt DISK_NOINSTALL=1 python3 tools/make_disk.py "$VER"
WHD_BUILD=build/demo WHD_PKG=StronkiesRCCupDemo WHD_TRACKS=2 WHD_DEMO=1 python3 tools/make_whdload.py "$VER"
