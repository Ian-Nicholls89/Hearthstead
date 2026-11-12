#!/usr/bin/env bash
# Renders demo towns to build/shots: an autoplayed town at several dates and zooms.
# Uses $DISPLAY, or starts a virtual display (xvfb-run can hang on exit here).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/shots
if [ -z "${DISPLAY:-}" ]; then
  export DISPLAY=:77
  pgrep -f "Xvfb :77" >/dev/null || { Xvfb :77 -screen 0 1600x900x24 >/dev/null 2>&1 & sleep 2; }
fi
shot() { timeout 300 tools/godot.sh --path . --resolution "${RES:-1280x720}" -- --demo "$@" >/dev/null 2>&1 || echo "failed: $*"; }
shot 1 1.6 "$PWD/build/shots/autumn.png" 26 0.6
shot 1 1.85 "$PWD/build/shots/winter.png" 20 2.2
shot 2 5.5 "$PWD/build/shots/wide.png" 45 0.9
shot 3 3.42 "$PWD/build/shots/close_up.png" 8 -0.8
OUT="$PWD/build/shots/villagers.png" timeout 120 tools/godot.sh --path . --resolution 1280x720 --script res://tests/villager_shot.gd >/dev/null 2>&1 || true
ls -la build/shots
