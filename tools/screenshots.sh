#!/usr/bin/env bash
# Renders demo towns to build/shots: an autoplayed town at several dates and zooms.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/shots
shot() { timeout 300 xvfb-run -a -s "-screen 0 1600x900x24" tools/godot.sh --path . --resolution "${RES:-1280x720}" -- --demo "$@" 2>&1 | grep -E 'SCRIPT ERROR' || true; }
shot 1 0.4 "$PWD/build/shots/summer_y1.png" 30 0.6
shot 1 1.8 "$PWD/build/shots/winter_y2.png" 26 2.2
shot 2 5.5 "$PWD/build/shots/town_y6.png" 40 0.9
shot 3 3.65 "$PWD/build/shots/close_y4.png" 12 -0.8
ls -la build/shots
