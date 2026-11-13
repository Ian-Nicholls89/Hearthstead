# Decisions

- **Godot 4.7, GL Compatibility renderer.** Runs on most Android phones; the look
  is flat-shaded low-poly, which suits it.
- **No model files.** Every building, tree and person is built from boxes, gables,
  cones and cylinders in `meshes.gd`, with vertex colours and one shared shader that
  adds snow on upward faces in winter and autumn colours on leaves.
- **The sim knows nothing of nodes.** `World` is a RefCounted; the view polls its
  `revision` counters. This keeps tests, soak runs and balancing fast (a year of a
  15-person town simulates in under a second).
- **People run small plans** of "go" and "do" steps, with reservations for tiles,
  hauls and deliveries, released if a plan is dropped.
- **Time:** 10 ticks a second at 1x, 40 seconds a month, 8 minutes a year. Children
  work from age 6 (Banished uses 10, but the town would stall for an hour of play).
- **Balance is checked by the autoplayer**, which staffs food and firewood first and
  builds what is short. Four seeds survive ten years at normal difficulty.
- **Placing:** tap to move the ghost, tap it again (or press Build here) to place.
  Sites can be placed without materials; builders wait for them.
- **Saves:** JSON in `user://`, written each new season, when the app is paused or
  loses focus, and on leaving. Plans are not saved; people re-decide on load.
- **0.2 graphics: CC0 models, converted here.** Quaternius's packs are CC0. Kenney's
  site refuses automated downloads, so it is not used. The nature models come as
  OpenUSD text, which `tools/usd2json.py` reads directly (Blender could not be used in
  the build container); Godot bakes them into meshes with automatic LODs.
- **Villagers are a light body on a real rig.** The Universal Animation Library's
  mannequin is 13.7k triangles, too heavy for a crowd on a phone, so villagers are
  ~700-triangle bodies built in code and skinned rigidly to its skeleton; all 46
  animations work, finger tracks are dropped. About 1 ms a frame for 120 people on a
  desktop CPU.
- **Forests in chunks.** 16x16-tile chunks of MultiMeshes: detailed seasonal models
  within ~38 m of the camera, the old procedural trees beyond. Vertex colours from USD
  are linear and converted to sRGB, because the Compatibility renderer shows vertex
  colours as stored.
- **0.3 buildings: composed, merged models.** Each building type is a recipe of
  Quaternius models placed on its footprint (`building_art.gd`) and merged into one
  mesh, so a building is one draw call. Doors face +Z like the models. Stores and
  workplaces show heaps (logs, stone, crates) that grow with what they hold.
- **Water** is one subdivided plane with a shader: colour from a per-tile
  distance-to-land texture (shallow to deep), a foam line at the banks, small waves,
  and ice in winter. Banks are sandy; reeds, pebbles and lily pads line the shores.
- **Mountains** get scattered peak models on rock tiles, more and bigger away from the
  foot, drawn at every distance. The icon is rendered from the game's own models
  (`tools/make_icon.gd` + `make_icon.py`).
- **0.4 progression** (`docs/PROGRESSION.md`). Milestones open eras; knowledge
  (2 + 0.25 per adult a month) is spent on techs in a three-branch tree, banked when
  nothing is being researched. Techs unlock buildings (gated in `World.can_place`
  unless `sandbox`, which the tests use) and multiply rules through `World.mod()`.
  Buildings get era looks as `type@N` recipes; the view rebuilds them when the era
  changes. Saves from before 0.4 keep the techs for what they had already built.
- **0.5 Small town.** New goods (flour, bread, apples, mutton, wool) and ten techs.
  Orchards produce only in their months (`months` on an extract building); schools
  are extract buildings whose yield is knowledge; markets are a monthly-ish top-up of
  nearby homes from the stores (every 100 ticks) rather than walking traders, to keep
  the sim cheap. Era looks: `house@2` (taller cottages on stone). The autoplayer now
  puts spare hands where the town is shortest; long games (15+ years) still show it
  stalling around 25-30 people with the wood economy tight - balance is stage v1.0.
- **0.7 Industrial revolution and climate.** Climate is one 0..100 number: industrial
  buildings carry an `emit` rate scaled by how staffed they are, forests absorb by tree
  count, techs scale both. Effects are deliberately simple (colder winters, slower
  crops, storm fires, water level and haze in the view); 100 ends the game. Endings
  share one screen (`Hud.ENDINGS`) fed by `World.story()`. The heavy city models
  (5-40k triangles) are used only for one-off buildings; brick terraces and the
  era's houses are the cottages recoloured (`BuildingArt.tinted`).
