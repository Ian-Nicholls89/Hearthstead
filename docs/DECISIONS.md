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
