#!/usr/bin/env bash
# Fetches the CC0 Quaternius models the game uses (OpenUSD copies in
# chibifire-stages/quaternius-stage, pinned), converts them with usd2json.py, and has
# Godot bake them into meshes with levels of detail:
#   assets/nature/  trees, bushes, rocks, ground cover (Ultimate Nature)
#   assets/models/  buildings, props, crops and mountains (several packs)
set -euo pipefail
cd "$(dirname "$0")/.."
SHA=ed5dc51b1e44006c0fc843e6c7b4a840dfb498ab
BASE="https://raw.githubusercontent.com/chibifire-stages/quaternius-stage/$SHA/models"

NATURE="CommonTree_1 CommonTree_2 CommonTree_3 CommonTreeAutumn_1 CommonTreeAutumn_2 CommonTreeAutumn_3
CommonTreeDeadSnow_1 CommonTreeDeadSnow_2 CommonTreeDeadSnow_3
PineTree_1 PineTree_2 PineTree_3 PineTreeSnow_1 PineTreeSnow_2 PineTreeSnow_3
BirchTree_1 BirchTree_2 BirchTreeAutumn_1 BirchTreeAutumn_2 BirchTreeDeadSnow_1 BirchTreeDeadSnow_2
Bush_1 Bush_2 BushSnow_1 BushSnow_2 BushBerries_1 Rock_1 Rock_2 Rock_3 RockSnow_1 RockSnow_2 RockSnow_3
TreeStump TreeStumpSnow Grass GrassShort Flowers Plant_1 Plant_2 Wheat WoodLog Lilypad"

MODELS="UltimateFantasyRTS/HousesSecondAge1Level1 UltimateFantasyRTS/HousesSecondAge2Level1
UltimateFantasyRTS/HousesSecondAge3Level1 UltimateFantasyRTS/HousesFirstAge1Level3
UltimateFantasyRTS/HousesFirstAge2Level1 UltimateFantasyRTS/HousesFirstAge3Level1
UltimateFantasyRTS/StorageFirstAgeLeve3 UltimateFantasyRTS/ArcheryFirstAgeLevel1 UltimateFantasyRTS/PortFirstAgeLevel1
UltimateFantasyRTS/Logs UltimateFantasyRTS/CrateStack1 UltimateFantasyRTS/Crate UltimateFantasyRTS/Barrel
UltimateFantasyRTS/ResourceRock_1 UltimateFantasyRTS/ResourceRock_2 UltimateFantasyRTS/ResourceGold_1
UltimateFantasyRTS/Rock UltimateFantasyRTS/RockGroup UltimateFantasyRTS/MountainSingle UltimateFantasyRTS/MountainGroup_1
UltimateFantasyRTS/Mine UltimateFantasyRTS/TempleFirstAgeLevel1 UltimateFantasyRTS/TownCenterFirstAgeLevel3
UltimateFantasyRTS/MarketFirstAgeLevel2 MedievalVillage/Blacksmith MedievalVillage/Sawmill MedievalVillage/Well
MedievalVillage/Cart MedievalVillage/BonfireLit MedievalVillage/MarketStand_1 MedievalVillage/MarketStand_2
MedievalVillage/Hay MedievalVillage/Bags MedievalVillage/Fence Survival/Tent
UltimateCrops/WheatCrop UltimateCrops/Wheat_4 UltimateCrops/Lettuce_2 UltimateCrops/Carrot_4"

fetch() {   # pack model outdir
  local f="build/usd-src/$1_$2.usda"
  mkdir -p build/usd-src "$3"
  [ -s "$f" ] || curl -sfL -o "$f" "$BASE/$1/S_$2.usda"
  python3 tools/usd2json.py "$f" "$3/$2.json" >/dev/null
}
for m in $NATURE; do fetch UltimateNature "$m" build/usd-nature; done
for pm in $MODELS; do fetch "${pm%%/*}" "${pm##*/}" build/usd-models; done
SRC=res://build/usd-nature DST=res://assets/nature timeout 600 tools/godot.sh --headless --path . --script res://tools/build_assets.gd | tail -1
SRC=res://build/usd-models DST=res://assets/models timeout 600 tools/godot.sh --headless --path . --script res://tools/build_assets.gd | tail -1
