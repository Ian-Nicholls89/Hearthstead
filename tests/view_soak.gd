extends SceneTree
## Runs the whole game - sim, view and HUD - at top speed with the autoplayer for
## FRAMES frames, answering dialogs, to shake out runtime errors in the view code.

func _initialize() -> void:
	var w := World.new()
	w.new_game(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 9, 1)
	var game := Game.new()
	root.add_child(game)
	game.start(w)
	game.set_speed(4)
	var ap := AutoPlay.new()
	var frames := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 3000
	var t0 := Time.get_ticks_msec()
	var last := 0
	for f in frames:
		ap.act(w)
		if game.hud.modal_open():
			game.hud._close()
			if w.pending_nomads > 0:
				w.answer_nomads(true)
		if f % 400 == 0 and f > 0:
			game.select(w.buildings.keys()[f % w.buildings.size()])
			game.hud.show_town(f / 400 % 4)
			await process_frame
			game.hud._close()
		await process_frame
		if Time.get_ticks_msec() - last > 5000:
			last = Time.get_ticks_msec()
			print("frame %d  %s  pop %d  fps %d" % [f, Defs.date_text(w.tick), w.citizens.size(), Engine.get_frames_per_second()])
	print("VIEW SOAK DONE: %s, pop %d, %d ms" % [Defs.date_text(w.tick), w.citizens.size(), Time.get_ticks_msec() - t0])
	quit()
