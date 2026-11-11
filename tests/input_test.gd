extends SceneTree
## Touch input through the real viewport: taps, drags, pinches and HUD blocking.
## Needs a display: xvfb-run tools/godot.sh --path . --script res://tests/input_test.gd

var fails: Array[String] = []
var game: Game


func check(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		fails.append(what)


func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)


func drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)


func frames(n := 3) -> void:
	for k in n:
		await process_frame


func _initialize() -> void:
	var w := World.new()
	w.new_game(5, 1)
	game = Game.new()
	root.add_child(game)
	game.start(w)
	game.set_speed(0)
	await frames(5)
	var size := root.get_visible_rect().size
	var mid := size * 0.5

	# one-finger drag pans the camera
	var before := game.rig.target
	touch(0, mid, true)
	for k in 10:
		drag(0, mid + Vector2(k * 20, 0), Vector2(20, 0))
	touch(0, mid + Vector2(200, 0), false)
	await frames()
	check(game.rig.target.distance_to(before) > 1.0, "drag pans the camera")

	# pinch zooms
	var d0 := game.rig.dist
	touch(0, mid - Vector2(100, 0), true)
	touch(1, mid + Vector2(100, 0), true)
	for k in 10:
		drag(0, mid - Vector2(100 + k * 15, 0), Vector2(-15, 0))
		drag(1, mid + Vector2(100 + k * 15, 0), Vector2(15, 0))
	touch(0, mid - Vector2(250, 0), false)
	touch(1, mid + Vector2(250, 0), false)
	await frames()
	check(game.rig.dist < d0 * 0.8, "pinching out zooms in (%.1f -> %.1f)" % [d0, game.rig.dist])

	# a tap on a house selects it
	game.rig.focus(Vector3(w.width / 2.0, 0, w.height / 2.0))
	var hid := w.place("house", AutoPlay.find_spot(w, "house"), true)
	var h: Building = w.buildings[hid]
	await frames()
	var sp := game.rig.cam.unproject_position(Vector3(h.pos.x + 1, 0.5, h.pos.y + 1))
	touch(0, sp, true)
	touch(0, sp, false)
	await frames()
	check(game.selected == hid, "tapping a house selects it")

	# road tool: drag lays a road
	game.set_tool("road")
	var a := game.rig.cam.unproject_position(Vector3(w.width / 2.0 - 6, 0, w.height / 2.0 + 6))
	var b := game.rig.cam.unproject_position(Vector3(w.width / 2.0 + 4, 0, w.height / 2.0 + 6))
	var roads0 := Array(w.road).count(1)
	touch(0, a, true)
	for k in 11:
		drag(0, a.lerp(b, k / 10.0), (b - a) / 10.0)
	touch(0, b, false)
	await frames()
	check(Array(w.road).count(1) > roads0 + 5, "dragging with the road tool lays road (%d)" % (Array(w.road).count(1) - roads0))

	# a tap on the HUD does not reach the map
	game.set_tool("road")
	await frames()
	var done_btn: Button = null
	for c in game.hud.place_bar.get_child(0).get_children():
		if c is Button and c.text == "Done":
			done_btn = c
	var dp := done_btn.get_global_rect().get_center()
	var under := game.rig.ground_tile(dp)
	var had := w.in_bounds(under) and w.road[w.idx(under)] == 1
	touch(0, dp, true)
	touch(0, dp, false)
	await frames()
	check(game.tool == "", "tapping Done leaves the road tool")
	check(not w.in_bounds(under) or had or w.road[w.idx(under)] == 0, "no road laid under the Done button")

	# placing a building: tap to move the ghost, tap again to build
	game.set_tool("house")
	await frames()
	var target := game._free_spot("house", game.rig.ground_tile(mid + Vector2(-220, -60)))
	var tp := game.rig.cam.unproject_position(Vector3(target.x + 0.5, 0, target.y + 0.5))
	var n0 := w.buildings.size()
	touch(0, tp, true)
	touch(0, tp, false)
	await frames()
	check(game.ghost_tile == target - Vector2i(1, 1), "tap moves the ghost (%s)" % game.ghost_tile)
	touch(0, tp, true)
	touch(0, tp, false)
	await frames()
	check(w.buildings.size() == n0 + 1, "second tap builds")
	game.set_tool("")

	print("")
	print("INPUT TESTS PASSED" if fails.is_empty() else "INPUT TESTS FAILED: %d" % fails.size())
	quit(0 if fails.is_empty() else 1)
