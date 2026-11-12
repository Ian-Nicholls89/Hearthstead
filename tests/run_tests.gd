extends SceneTree
## Headless tests: godot --headless --path . --script res://tests/run_tests.gd
## Each test_* method returns nothing and calls check(); failures are listed at the end.

var failures: Array[String] = []
var current := ""


func _init() -> void:
	var only := OS.get_environment("ONLY")
	var t0 := Time.get_ticks_msec()
	for m in get_method_list():
		var n: String = m.name
		if not n.begins_with("test_") or (only != "" and not n.contains(only)):
			continue
		current = n
		var s := Time.get_ticks_msec()
		call(n)
		print("  %-40s %5d ms" % [n, Time.get_ticks_msec() - s])
	print("")
	if failures.is_empty():
		print("ALL TESTS PASSED (%d ms)" % (Time.get_ticks_msec() - t0))
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		quit(1)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, what])


func world(seed := 1, difficulty := 1, progression := false) -> World:
	var w := World.new()
	w.new_game(seed, difficulty)
	if not progression:
		w.unlock_all()
	return w


## Units of res in stores, workplace stock and people's hands.
func made(w: World, res: String) -> int:
	var n := w.stock(res)
	for b in w.buildings.values():
		if b.kind() != "storage":
			n += b.inv.get(res, 0) + b.input.get(res, 0)
	for c in w.citizens.values():
		n += c.carry.get(res, 0)
	return n


func camp(w: World) -> Building:
	for b in w.buildings.values():
		if b.type == "camp":
			return b
	return null


# --- map ---------------------------------------------------------------------

func test_map_is_deterministic() -> void:
	var a := world(42)
	var b := world(42)
	var c := world(43)
	check(a.terrain == b.terrain and a.feature == b.feature, "same seed, same map")
	check(a.feature != c.feature, "different seed, different map")


func test_map_has_what_a_town_needs() -> void:
	for s in [1, 2, 3, 4, 5, 6]:
		var w := world(s)
		var stone := 0
		var iron := 0
		var water := 0
		var trees := 0
		for i in w.feature.size():
			stone += int(w.feature[i] == Defs.Feature.STONE_DEP)
			iron += int(w.feature[i] == Defs.Feature.IRON_DEP)
			water += int(w.terrain[i] == Defs.Terrain.WATER)
			trees += int(w.feature[i] == Defs.Feature.TREE)
		check(stone >= 16, "seed %d stone ground (%d)" % [s, stone])
		check(iron >= 9, "seed %d iron ground (%d)" % [s, iron])
		check(water > 50, "seed %d water" % s)
		check(trees > 1000, "seed %d forest (%d)" % [s, trees])
		check(AutoPlay.find_spot(w, "quarry").x >= 0, "seed %d has a quarry spot" % s)
		check(AutoPlay.find_spot(w, "mine").x >= 0, "seed %d has a mine spot" % s)


func test_start_supplies_and_people() -> void:
	var w := world(1, 1)
	check(w.citizens.size() == 15, "6 couples and 3 children (%d)" % w.citizens.size())
	check(w.stock("logs") == 160, "starting logs")
	check(w.food_total() == 600, "starting food")


# --- building ---------------------------------------------------------------

func test_placement_rules() -> void:
	var w := world(1)
	var cb := camp(w)
	check(w.can_place("house", cb.pos) != "", "cannot build on the camp")
	var spot := AutoPlay.find_spot(w, "house")
	check(w.can_place("house", spot) == "", "found house spot is valid")
	var water := Vector2i(-1, -1)
	for i in w.terrain.size():
		if w.terrain[i] == Defs.Terrain.WATER:
			water = w.tile_of(i)
			break
	check(w.can_place("house", water) != "", "cannot build on water")
	check(w.can_place("quarry", spot) != "", "quarry needs stone ground")
	var id := w.place("house", spot)
	check(id >= 0, "placed")
	check(w.can_place("house", spot) != "", "cannot overlap")
	check(not w.passable(spot), "site blocks walking")


func test_builders_finish_a_house() -> void:
	var w := world(1)
	var id := w.place("house", AutoPlay.find_spot(w, "house"))
	var logs := w.stock("logs")
	w.run(Defs.MONTH_TICKS)
	var b: Building = w.buildings[id]
	check(b.built, "house built within a month (progress %.0f/%.0f, needs %s)" % [b.progress, b.work, b.needed])
	check(w.stock("logs") <= logs - 8, "logs were used")
	check(b.residents.size() >= 2, "a family moved in (%d)" % b.residents.size())


func test_roads_speed_walking() -> void:
	var w := world(1)
	var a := Vector2i(30, 48)
	var tiles: Array = []
	for x in range(30, 60):
		tiles.append(Vector2i(x, 48))
	var before := w.astar.get_point_weight_scale(Vector2i(40, 48))
	w.place_road(tiles)
	check(w.road[w.idx(Vector2i(40, 48))] == 1 or w.terrain[w.idx(Vector2i(40, 48))] != Defs.Terrain.GRASS, "road laid")
	check(w.astar.get_point_weight_scale(Vector2i(40, 48)) < before or w.terrain[w.idx(Vector2i(40, 48))] != Defs.Terrain.GRASS, "road is cheaper to walk")


func test_demolish_refunds_and_frees() -> void:
	var w := world(1)
	var spot := AutoPlay.find_spot(w, "barn")
	var id := w.place("barn", spot, true)
	var logs := w.stock("logs")
	w.demolish(id)
	check(not w.buildings.has(id), "gone")
	check(w.can_place("barn", spot) == "", "ground free again")
	check(w.stock("logs") == logs + 15, "half the logs back (%d -> %d)" % [logs, w.stock("logs")])


# --- needs --------------------------------------------------------------------

func test_hungry_people_eat() -> void:
	var w := world(1)
	var food := w.food_total()
	for c in w.citizens.values():
		c.full = 0.2
	w.run(200)
	var fed := w.citizens.values().filter(func(c): return c.full > 0.5).size()
	check(fed == w.citizens.size(), "everyone ate (%d/%d)" % [fed, w.citizens.size()])
	check(w.food_total() < food, "food was eaten")


func test_variety_comes_from_different_foods() -> void:
	var w := world(1)
	for i in 3:
		for c in w.citizens.values():
			c.full = 0.2
		w.run(150)
	var c: Citizen = w.citizens.values()[0]
	check(w.variety(c) >= 2, "ate more than one kind of food (%s)" % c.diet)


func test_cold_without_shelter_hurts() -> void:
	var w := world(1)
	w.tick = Defs.MONTH_TICKS * 10 + 1     # deep winter
	var cb := camp(w)
	w.store_take(cb, "firewood", 9999)
	for c in w.citizens.values():
		c.coat = 0.0
	w.run(600)
	var hurt := w.citizens.values().filter(func(c): return c.health < 1.0).size()
	check(hurt + w.died_total > 0, "people suffer in winter with no fire")


func test_house_with_firewood_keeps_warm() -> void:
	var w := world(1)
	var id := w.place("house", AutoPlay.find_spot(w, "house"), true)
	var h: Building = w.buildings[id]
	check(h.residents.size() >= 2, "family moved in")
	w.tick = Defs.MONTH_TICKS * 10 + 1
	var c: Citizen = w.citizens[h.residents[0]]
	c.warmth = 0.2
	c.coat = 0.0
	h.inv["firewood"] = 20
	var best := 0.0
	for i in 200:
		w.step()
		best = maxf(best, c.warmth)
	check(best > 0.9, "warmed up at home (%.2f, doing %s)" % [c.warmth, c.doing])


# --- work ---------------------------------------------------------------------

func test_gatherers_bring_in_food() -> void:
	var w := world(1)
	var id := w.place("gatherer", AutoPlay.find_spot(w, "gatherer"), true)
	w.run(Defs.MONTH_TICKS * 2)
	var b: Building = w.buildings[id]
	check(b.workers.size() == 4, "four gatherers (%d)" % b.workers.size())
	var made: int = w.stock("mushrooms") + b.inv.get("mushrooms", 0)
	for c in w.citizens.values():
		made += c.carry.get("mushrooms", 0)
		if c.diet.has("mushrooms"):
			made += 1
	check(made > 20, "mushrooms gathered (%d)" % made)


func test_woodcutter_makes_firewood() -> void:
	var w := world(1)
	var wood := w.stock("firewood")
	var id := w.place("woodcutter", AutoPlay.find_spot(w, "woodcutter"), true)
	w.run(Defs.MONTH_TICKS * 2)
	var b: Building = w.buildings[id]
	var made: int = w.stock("firewood") + b.inv.get("firewood", 0) - wood
	for h in w.buildings.values():
		if h.kind() == "house":
			made += h.inv.get("firewood", 0)
	check(made > 20, "firewood split (%d)" % made)


func test_fields_grow_and_harvest() -> void:
	var w := world(1)
	var id := w.place("field", AutoPlay.find_spot(w, "field"), true)
	w.run(Defs.MONTH_TICKS * 3)
	var b: Building = w.buildings[id]
	var planted := 0
	for v in b.field:
		if v >= 0.0:
			planted += 1
	check(planted == b.field.size(), "whole field planted in spring (%d)" % planted)
	w.run(Defs.MONTH_TICKS * 5 + 300)
	var got: int = w.made.get("wheat", 0)
	check(got > 100, "harvest came in (%d)" % got)


func test_quarry_and_mine() -> void:
	var w := world(1)
	var q := w.place("quarry", AutoPlay.find_spot(w, "quarry"), true)
	var m := w.place("mine", AutoPlay.find_spot(w, "mine"), true)
	check(q >= 0 and m >= 0, "both placed")
	var stone := w.stock("stone")
	var iron := w.stock("iron")
	w.run(Defs.MONTH_TICKS * 3)
	check(made(w, "stone") > stone + 40, "stone cut (%d)" % (made(w, "stone") - stone))
	check(made(w, "iron") > iron + 15, "iron dug (%d)" % (made(w, "iron") - iron))


func test_forester_keeps_the_forest() -> void:
	var w := world(1)
	var id := w.place("forester", AutoPlay.find_spot(w, "forester"), true)
	var logs := w.stock("logs")
	w.run(Defs.MONTH_TICKS * 3)
	check(made(w, "logs") > logs + 30, "logs felled (%d)" % (made(w, "logs") - logs))


func test_clearing_marked_trees() -> void:
	var w := world(1)
	var cb := camp(w)
	var rect := Rect2i(cb.pos - Vector2i(20, 20), Vector2i(40, 40))
	var n := w.mark_clear(rect, true)
	check(n > 0, "marked some trees")
	w.run(Defs.MONTH_TICKS)
	var left := 0
	for i in w.mark.size():
		left += w.mark[i]
	check(left < n, "labourers cleared some (%d of %d left)" % [left, n])


# --- people -----------------------------------------------------------------

func test_families_have_children() -> void:
	var w := world(1)
	for i in 6:
		w.place("house", AutoPlay.find_spot(w, "house"), true)
	w.run(Defs.MONTH_TICKS * 24)
	check(w.born_total > 0, "children born in two years (%d)" % w.born_total)


func test_tools_wear_and_get_replaced() -> void:
	var w := world(1)
	var c: Citizen = w.citizens.values().filter(func(c): return c.is_adult())[0]
	c.tool = 0.0
	var tools := w.stock("tools")
	w.run(300)
	check(c.tool > 0.5 or w.stock("tools") < tools, "fetched a new tool")


# --- persistence --------------------------------------------------------------

func test_save_round_trip() -> void:
	var w := world(7)
	w.place("house", AutoPlay.find_spot(w, "house"))
	w.place("field", AutoPlay.find_spot(w, "field"), true)
	w.mark_clear(Rect2i(10, 10, 10, 10), true)
	w.run(500)
	var d := SaveGame.to_dict(w)
	var json := JSON.stringify(d)
	var w2 := SaveGame.from_dict(JSON.parse_string(json))
	check(JSON.stringify(SaveGame.to_dict(w2)) == json, "saved and loaded worlds match")
	check(w2.stock("logs") == w.stock("logs"), "totals rebuilt")
	w2.run(400)
	check(w2.citizens.size() > 0 and not w2.game_over, "loaded world keeps running")


# --- the long run -------------------------------------------------------------

func test_autoplay_town_survives_three_years() -> void:
	var w := world(1)
	var ap := AutoPlay.new()
	for t in Defs.YEAR_TICKS * 3:
		ap.act(w)
		w.step()
	var p := w.population()
	print("    3 years: pop %d (adults %d), born %d, died %d, food %d, firewood %d, buildings %d" % [
		p.total, p.adults, w.born_total, w.died_total, w.food_total(), w.stock("firewood"), w.buildings.size()])
	check(p.total >= 15, "town did not shrink (%d)" % p.total)
	check(not w.game_over, "not wiped out")


# --- progression ------------------------------------------------------------------

func test_buildings_wait_for_their_tech() -> void:
	var w := world(1, 1, true)
	var spot := AutoPlay.find_spot(w, "house")
	check(w.can_place("house", spot) == "", "houses from the start")
	check(w.can_place("field", AutoPlay.find_spot(w, "house")).begins_with("Not discovered"), "fields need Agriculture")
	check(w.start_research("agriculture"), "can research Agriculture")
	check(not w.start_research("crop_rotation"), "Crop rotation is a later era")
	for i in 8:
		w.run(Defs.MONTH_TICKS)
		if w.techs.has("agriculture"):
			break
	check(w.techs.has("agriculture"), "learned Agriculture within 8 months")
	check(w.unlocked("field"), "fields unlocked")
	check(w.researching == "", "free to choose the next")


func test_knowledge_waits_when_nothing_is_researched() -> void:
	var w := world(1, 1, true)
	w.run(Defs.MONTH_TICKS * 3)
	check(w.knowledge > 10, "knowledge banked (%.1f)" % w.knowledge)
	w.start_research("fishing")
	check(w.techs.has("fishing"), "banked knowledge pays straight into the choice")


func test_milestones_open_the_next_era() -> void:
	var w := world(1, 1, true)
	check(w.era == 0, "starts in the Settlement era")
	for id in ["agriculture", "fishing", "stonework"]:
		w.techs[id] = true
	w.winters = 2
	for i in 5:
		w.place("house", AutoPlay.find_spot(w, "house"), true)
	for i in 6:
		w.spawn(i % 2 == 0, 20.0, "Test", Vector2i(48, 48))
	var ms := w.milestones()
	check(ms.all(func(m): return m.have >= m.need), "all milestones met: %s" % str(ms))
	w.run(Defs.MONTH_TICKS)
	check(w.era == 1, "the Village era began")
	check(w.tech_state("crop_rotation") == "available", "village techs open up")


func test_techs_change_the_rules() -> void:
	var w := world(1)
	check(is_equal_approx(w.mod("field_yield"), 1.0), "no bonus before")
	w._learn("crop_rotation")
	check(is_equal_approx(w.mod("field_yield"), 1.25), "crop rotation +25%")
	w._learn("better_tools")
	check(is_equal_approx(w.mod("tool_wear"), 0.4), "better tools")


func test_progress_is_saved() -> void:
	var w := world(1, 1, true)
	w.start_research("stonework")
	w.run(Defs.MONTH_TICKS * 2)
	w._learn("fishing")
	var w2 := SaveGame.from_dict(JSON.parse_string(JSON.stringify(SaveGame.to_dict(w))))
	check(w2.techs.has("fishing") and w2.researching == w.researching, "techs and research kept")
	check(is_equal_approx(w2.research.get("stonework", 0.0), w.research.get("stonework", 0.0)), "research progress kept")


func test_autoplay_reaches_the_village_era() -> void:
	var w := world(2, 1, true)
	var ap := AutoPlay.new()
	for t in Defs.YEAR_TICKS * 4:
		ap.act(w)
		w.step()
	print("    4 years with progression: era %d, techs %s, pop %d" % [w.era, w.techs.keys(), w.citizens.size()])
	check(w.era >= 1, "reached the Village era in 4 years")
