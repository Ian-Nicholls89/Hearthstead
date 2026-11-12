extends SceneTree
## Triangles and draw calls on screen at several zoom levels (needs a display).
func _initialize() -> void:
	var w := World.new()
	w.new_game(1, 1)
	var ap := AutoPlay.new()
	for t in int(1.6 * Defs.YEAR_TICKS):
		ap.act(w)
		w.step()
	var g := Game.new()
	root.add_child(g)
	g.start(w)
	g.set_speed(0)
	for d in [14.0, 26.0, 45.0, 75.0]:
		g.rig.dist = d
		g.rig._apply()
		for k in 3:
			await process_frame
		var t0 := Time.get_ticks_msec()
		for k in 3:
			await process_frame
		var ms := (Time.get_ticks_msec() - t0) / 3
		print("dist %4.0f: %4d ms/frame %8d tris  %5d draws  %5d objects" % [d, ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	quit()
