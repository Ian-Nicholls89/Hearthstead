extends SceneTree
## Plays a settlement through its change to the Village era with the view running,
## checking the houses rebuild into cottages; screenshots before and after.
func _initialize() -> void:
	var w := World.new()
	w.new_game(3, 1)
	var ap := AutoPlay.new()
	for t in Defs.YEAR_TICKS:
		ap.act(w)
		w.step()
	if w.era != 0:
		print("already past the settlement era; pick another seed")
	var g := Game.new()
	root.add_child(g)
	g.start(w)
	g.set_speed(0)
	g.rig.dist = 18
	g.rig._apply()
	for k in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/era_before.png")
	var hid := -1
	for b in w.buildings.values():
		if b.type == "house" and b.built:
			hid = b.id
	var before: Mesh = g.view.building_nodes[hid].get_node("Body").mesh
	# meet the milestones and let the month turn
	for id in ["agriculture", "fishing", "stonework"]:
		w.techs[id] = true
	w.winters = 2
	while w.citizens.size() < 20:
		w.spawn(true, 20.0, "Test", Vector2i(48, 48))
	while w.buildings.values().filter(func(b): return b.kind() == "house" and b.built).size() < 5:
		w.place("house", AutoPlay.find_spot(w, "house"), true)
	w.tick = (w.tick / Defs.MONTH_TICKS + 1) * Defs.MONTH_TICKS - 1
	w.step()
	g.hud._close()
	for k in 8:
		await process_frame
	var after: Mesh = g.view.building_nodes[hid].get_node("Body").mesh
	root.get_texture().get_image().save_png("/tmp/era_after.png")
	print("era %d, house rebuilt: %s" % [w.era, before != after])
	quit(0 if w.era == 1 and before != after else 1)
