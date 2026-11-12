extends SceneTree
## Frame cost with many animated villagers, headless (CPU only). PEOPLE=n to change.
func _initialize() -> void:
	Engine.max_fps = 0
	var n := int(OS.get_environment("PEOPLE")) if OS.get_environment("PEOPLE") != "" else 120
	var w := World.new()
	w.new_game(1, 1)
	for i in maxi(0, n - w.citizens.size()):
		w.spawn(i % 2 == 0, 20.0, "Test", Vector2i(48, 48))
	var g := Game.new()
	root.add_child(g)
	g.start(w)
	g.set_speed(1)
	for k in 30:
		await process_frame
	var view_us := 0
	var anim_us := 0
	for f in 120:
		var t0 := Time.get_ticks_usec()
		g._process(1.0 / 60.0)
		var t1 := Time.get_ticks_usec()
		for v in g.view.villagers.values():
			v.player.advance(1.0 / 60.0)
		view_us += t1 - t0
		anim_us += Time.get_ticks_usec() - t1
	print("%d people: game+view %.2f ms, animation %.2f ms per frame" % [w.citizens.size(), view_us / 120000.0, anim_us / 120000.0])
	quit()
