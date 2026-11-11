extends SceneTree
## Yield per building type over one year in a small housed town.
func _init():
	for type in ["gatherer", "hunter", "fisher", "forester", "woodcutter", "quarry", "mine", "herbalist", "field"]:
		var w := World.new(); w.new_game(1, 0)
		for i in 6:
			w.place("house", AutoPlay.find_spot(w, "house"), true)
		var spot := AutoPlay.find_spot(w, type)
		if spot.x < 0:
			print(type, " no spot"); continue
		var id := w.place(type, spot, true)
		w.set_builders(0)
		w.run(Defs.YEAR_TICKS)
		var nw: int = maxi(1, w.buildings[id].workers.size())
		print("%-11s workers %d  per worker/yr: %s" % [type, nw, ", ".join(w.made.keys().map(func(k): return "%s %d" % [k, w.made[k] / nw]))])
	quit()
