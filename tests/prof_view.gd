extends SceneTree
func _initialize() -> void:
	var w := World.new()
	w.new_game(9, 1)
	var ap := AutoPlay.new()
	for t in Defs.YEAR_TICKS * 3:
		ap.act(w)
		w.step()
	var v := WorldView.new()
	root.add_child(v)
	v.setup(w)
	var hud_game := Game.new()
	root.add_child(hud_game)
	hud_game.start(w)
	await process_frame
	for name in ["_draw_tiles", "_draw_fields", "_update_sites", "_draw_people", "_season"]:
		var t0 := Time.get_ticks_usec()
		for i in 20:
			if name == "_draw_people":
				v._draw_people(0.5)
			else:
				v.call(name)
		print("%-14s %6d us" % [name, (Time.get_ticks_usec() - t0) / 20])
	var t1 := Time.get_ticks_usec()
	for i in 20:
		hud_game.hud.refresh()
	print("hud.refresh    %6d us" % ((Time.get_ticks_usec() - t1) / 20))
	var t2 := Time.get_ticks_usec()
	for i in 100:
		w.step()
	print("world.step     %6d us  (pop %d)" % [(Time.get_ticks_usec() - t2) / 100, w.citizens.size()])
	quit()
