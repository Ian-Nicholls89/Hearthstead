#!/usr/bin/env bash
# Everything that must pass before a commit: import, unit tests, a short soak.
set -euo pipefail
cd "$(dirname "$0")/.."
G=tools/godot.sh
timeout 300 $G --headless --import --path . >/dev/null 2>&1 || true
echo "== tests"
timeout 900 $G --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E '^\s+test_|PASS|FAIL|SCRIPT ERROR|    [0-9]+ years'
echo "== soak (6 years, 3 seeds)"
YEARS=${YEARS:-6} SEEDS=${SEEDS:-1,2,3} timeout 900 $G --headless --path . --script res://tests/soak.gd 2>&1 | grep -E '^seed [0-9]+:|SCRIPT ERROR'
if [ -n "${DISPLAY:-}" ] || pgrep Xvfb >/dev/null; then
  echo "== touch input"
  DISPLAY=${DISPLAY:-:77} timeout 300 $G --path . --resolution 1280x720 --script res://tests/input_test.gd 2>&1 | grep -E '^ok|FAIL|PASSED|SCRIPT ERROR'
fi
