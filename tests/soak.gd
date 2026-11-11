extends SceneTree
## Soak run: the autoplayer builds a town for YEARS years (env, default 10) on SEEDS
## (comma list, default 1,2,3) and prints a line per year. Exit 1 if a town dies out.

func _init() -> void:
	var years := int(OS.get_environment("YEARS")) if OS.get_environment("YEARS") != "" else 10
	var seeds := (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else "1,2,3").split(",")
	var diff := int(OS.get_environment("DIFF")) if OS.get_environment("DIFF") != "" else 1
	var ok := true
	for s in seeds:
		var w := World.new()
		w.new_game(int(s), diff)
		var ap := AutoPlay.new()
		var t0 := Time.get_ticks_msec()
		var made_before := {}
		for y in years:
			for t in Defs.YEAR_TICKS:
				ap.act(w)
				w.step()
				if w.game_over:
					break
			var p := w.population()
			var causes := {}
			for e in w.events_log:
				if e.kind == "death" and e.tick > w.tick - Defs.YEAR_TICKS:
					var why: String = " ".join(e.text.split(" ", false).slice(2)).split(" at ")[0]
					causes[why] = causes.get(why, 0) + 1
			printerr("seed %s year %2d: pop %3d (kids %2d, homeless %2d, sick %d) food %5d wood %4d logs %4d stone %4d iron %3d tools %3d coats %3d | %d buildings | deaths %s" % [
				s, y + 1, p.total, p.children, p.homeless, p.sick, w.food_total(), w.stock("firewood"), w.stock("logs"),
				w.stock("stone"), w.stock("iron"), w.stock("tools"), w.stock("coats"), w.buildings.size(), causes])
			var fm := 0
			for f in Defs.FOODS:
				fm += w.made.get(f, 0) - made_before.get(f, 0)
			made_before = w.made.duplicate()
			printerr("      food made %d, jobs %s" % [fm, w.profession_counts()])
			if w.game_over:
				break
		printerr("seed %s: %s after %d years, %d ms, born %d died %d" % [s, "DIED OUT" if w.game_over else "alive", years, Time.get_ticks_msec() - t0, w.born_total, w.died_total])
		if w.game_over:
			ok = false
	quit(0 if ok else 1)
