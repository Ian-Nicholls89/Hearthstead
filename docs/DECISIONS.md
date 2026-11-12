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
