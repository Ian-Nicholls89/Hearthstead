#!/usr/bin/env bash
# Fetches the CC0 Quaternius nature models the game uses (OpenUSD copies in
# chibifire-stages/quaternius-stage, pinned), converts them with usd2json.py, and
# has Godot bake them into meshes with levels of detail under assets/nature.
set -euo pipefail
cd "$(dirname "$0")/.."
SHA=ed5dc51b1e44006c0fc843e6c7b4a840dfb498ab
BASE="https://raw.githubusercontent.com/chibifire-stages/quaternius-stage/$SHA/models/UltimateNature"
WORK=build/usd
mkdir -p "$WORK" assets/nature
MODELS="CommonTree_1 CommonTree_2 CommonTree_3 CommonTreeAutumn_1 CommonTreeAutumn_2 CommonTreeAutumn_3
CommonTreeDeadSnow_1 CommonTreeDeadSnow_2 CommonTreeDeadSnow_3
PineTree_1 PineTree_2 PineTree_3 PineTreeSnow_1 PineTreeSnow_2 PineTreeSnow_3
BirchTree_1 BirchTree_2 BirchTreeAutumn_1 BirchTreeAutumn_2 BirchTreeDeadSnow_1 BirchTreeDeadSnow_2
Bush_1 Bush_2 BushSnow_1 BushSnow_2 BushBerries_1 Rock_1 Rock_2 Rock_3 RockSnow_1 RockSnow_2 RockSnow_3
TreeStump TreeStumpSnow Grass GrassShort Flowers Plant_1 Plant_2 Wheat WoodLog"
for m in $MODELS; do
  f="$WORK/S_$m.usda"
  [ -s "$f" ] || curl -sfL -o "$f" "$BASE/S_$m.usda"
  python3 tools/usd2json.py "$f" "$WORK/$m.json"
done
timeout 600 tools/godot.sh --headless --path . --script res://tools/build_assets.gd
