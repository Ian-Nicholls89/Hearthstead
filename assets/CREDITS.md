# Third-party assets

All CC0 1.0 (public domain); no attribution required, but credit where it's due.

- `ual/` - **Universal Animation Library** (standard) by Quaternius, https://quaternius.com,
  via https://github.com/J-Ponzo/gltf-universal-animation-library. Skeleton and animations
  for the villagers; their bodies are built in `src/view/villager.gd`.
- `nature/` - **Ultimate Nature** by Quaternius.
- `models/` - by Quaternius: **Ultimate Fantasy RTS** (houses, storehouse, market,
  temple, town centre, mine, dock, archery range, logs, crates, rocks, mountains),
  **Medieval Village** (blacksmith, sawmill, well, cart, campfire, market stalls,
  fence, hay, bags, inn, cauldron), **Survival** (tent), **Ultimate Crops** (lettuce,
  apple trees), **Farm Buildings** (fences) and **Farm Animals** (sheep). The Large town
  uses more of Ultimate Fantasy RTS (university hall, glassworks tower, harbour,
  fountain square, theatre, stone church, bigger houses).
- Both come from the OpenUSD copies in https://github.com/chibifire-stages/quaternius-stage
  (commit ed5dc51) and are rebuilt with `tools/build_assets.sh` (`tools/usd2json.py`
  then `tools/build_assets.gd`). `tests/gallery.gd` renders them all for checking.
