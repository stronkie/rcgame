#!/bin/sh
# Build RC Turbo Cup:  sh tools/build.sh   (VER=0.2 by default)
# Needs python3 with Pillow and numpy.  Assembler and disk tools are in tools/.
#   tools/make_gfx.py     -> build/gen: tracks (Track1..8), sprites, pickups, HUD, title, sounds, music
#   tools/make_loading.py -> build/gen/loadpic.*: the loading picture (and itch/cover_630x500.png)
#   tools/asm68k.py       -> build/RCTurbo (loader) and build/RCTurbo.game (src/rc.s + race.s + menus.s)
#   tools/make_disk.py    -> build/*.adf (with the hard disk installer, src/install.s) and the hard drive zip
#   tools/make_whdload.py -> build/*_WHDLoad.lha / .zip: the WHDLoad version (slave: src/whdload.s)
set -e
cd "$(dirname "$0")/.."
export VER=${VER:-0.2}
mkdir -p build/gen
python3 tools/make_gfx.py build/gen
python3 tools/make_loading.py build/gen
python3 tools/asm68k.py src/main.s -I build/gen -I src -o build/RCTurbo.game -map build/RCTurbo.map
mkdir -p build/demo
python3 tools/asm68k.py src/demo.s -I build/gen -I src -o build/demo/RCTurbo.game -map build/demo/RCTurbo.map
mkdir -p build/gen/Tracks && cp build/gen/Track[1-8] build/gen/Tracks/
python3 tools/asm68k.py src/loader.s -I build/gen -I src -o build/RCTurbo
cp build/RCTurbo build/demo/RCTurbo
python3 tools/make_disk.py "$VER"
python3 tools/make_whdload.py "$VER"
# the free demo: 2 tracks, no installer, no saving
DISK_BUILD=build/demo DISK_NAME=RCTurboCup_DEMO_V$VER DISK_DRAWER=RCTurboCupDemo DISK_VOLUME=RCTurboDemo DISK_TRACKS=2 \
  DISK_README=ReadMe_demo.txt DISK_NOINSTALL=1 python3 tools/make_disk.py "$VER"
WHD_BUILD=build/demo WHD_PKG=RCTurboCupDemo WHD_TRACKS=2 WHD_DEMO=1 python3 tools/make_whdload.py "$VER"
