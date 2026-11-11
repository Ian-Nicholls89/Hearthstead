#!/usr/bin/env bash
# Runs the pinned Godot; downloads it on a fresh machine.
set -euo pipefail
VER=4.7.2
DIR="$(cd "$(dirname "$0")/../.." && pwd)/.tooling/godot"
BIN="$DIR/Godot_v${VER}-stable_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  curl -sL -o "$DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip"
  unzip -oq "$DIR/godot.zip" -d "$DIR" && rm "$DIR/godot.zip"
fi
exec "$BIN" "$@"
