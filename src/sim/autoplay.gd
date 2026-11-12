class_name AutoPlay
extends RefCounted
## A simple player for soak tests and balance runs. Each month it staffs the
## workplaces the way a careful player would and builds whatever the town is
## shortest of. Uses only the public commands the HUD uses.

const FOOD_ROTA := ["gatherer", "hunter", "field", "fisher", "field", "gatherer", "hunter", "field"]
const EXTRAS := ["barn", "stockpile", "tailor", "herbalist", "mine", "blacksmith", "well", "town_hall",
	"chapel", "stone_house", "trading_post", "well", "barn", "windmill", "bakery", "school", "market", "orchard",
	"stone_house", "pasture", "weaver", "tavern", "stone_house", "glassworks", "university", "plaza", "harbour",
	"theatre"]

var food_i := 0
var extra_i := 0


## The order a careful player might research in.
const RESEARCH := ["agriculture", "stonework", "hide_working", "fishing", "herb_lore", "smithing", "crop_rotation",
	"better_tools", "trade", "masonry", "medicine", "husbandry", "town_planning", "milling", "baking", "schooling",
	"markets", "faith", "orchards", "shepherding", "weaving", "brewing", "paving", "glassmaking", "university",
	"printing", "granaries", "guilds", "harbours", "irrigation", "aqueducts", "banking", "theatre"]


func act(w: World) -> void:
	if w.tick % Defs.MONTH_TICKS != 0:
		return
	if w.researching == "":
		for id in RESEARCH:
			if w.start_research(id):
				break
	_allocate(w)
	if w.stock("logs") < 60 and w.marked.size() < 20:
		_mark_trees(w)
	if w.pending_nomads > 0:
		w.answer_nomads(true)
	# up to three new sites a month, never more than three waiting
	for i in 3:
		if w.sites().size() >= 3 or not _one(w):
			return


func _one(w: World) -> bool:
	var pop: Dictionary = w.population()
	var n: int = pop.total
	var houses := _count(w, "house") + _count(w, "stone_house")
	# the first essentials, in order
	for t in ["gatherer", "woodcutter", "forester"]:
		if _count(w, t) == 0:
			return _try(w, t)
	if houses < 3:
		return _try(w, "house")
	if _count(w, "quarry") == 0:
		return _try(w, "quarry")
	var food_per_head := float(w.food_total()) / maxf(1.0, n)
	var thriving := food_per_head > 50 and w.stock("firewood") > n * 3
	if pop.homeless > 0 and houses < pop.adults / 2 + 1 and _can_afford(w, "house") and (thriving or pop.homeless > 3):
		return _try(w, "house")
	# enough places for the workers the town needs
	if _capacity(w, ["woodcutter"]) < _wood_workers(w):
		return _try(w, "woodcutter")
	if _capacity(w, ["gatherer", "hunter", "fisher", "field"]) < _food_workers(w) + 2:
		for k in FOOD_ROTA.size():
			var t: String = FOOD_ROTA[(food_i + k) % FOOD_ROTA.size()]
			if _try(w, t):
				food_i = (food_i + k + 1) % FOOD_ROTA.size()
				return true
	if _capacity(w, ["forester"]) < 4 + _count(w, "house") * 2:
		return _try(w, "forester")
	if w.stock("stone") < 30 and _capacity(w, ["quarry"]) < 3 + n / 10:
		return _try(w, "quarry")
	if w.stock("tools") < n and w.unlocked("blacksmith"):
		if _count(w, "mine") == 0:
			return _try(w, "mine")
		if _count(w, "blacksmith") == 0:
			return _try(w, "blacksmith")
	if w.stock("coats") < n / 3 and _count(w, "tailor") == 0:
		if _count(w, "hunter") == 0:
			return _try(w, "hunter")
		return _try(w, "tailor")
	if thriving and houses * 4 < n + 4 and _can_afford(w, "house"):
		return _try(w, "house")
	if not thriving or _spare(w) < 3:
		return false
	for k in EXTRAS.size():
		var t: String = EXTRAS[(extra_i + k) % EXTRAS.size()]
		if _count(w, t) * 30 >= n + 10 and t != "well":
			continue
		if _try(w, t):
			extra_i = (extra_i + k + 1) % EXTRAS.size()
			return true
	return false


func _adults(w: World) -> int:
	return w.citizens.values().filter(func(c): return c.is_adult() and not c.arriving).size()


func _food_workers(w: World) -> int:
	var need := 0.0
	for c in w.citizens.values():
		need += 37.0 if c.is_adult() else 14.0
	return ceili(need / 110.0) + (1 if w.food_total() < w.citizens.size() * 30 else 0)


func _wood_workers(w: World) -> int:
	var houses := w.buildings.values().filter(func(b): return b.kind() == "house" and b.built and not b.residents.is_empty()).size()
	return maxi(1, ceili(houses * 30.0 / 120.0) + (1 if w.stock("firewood") < w.citizens.size() * 3 else 0))


func _capacity(w: World, types: Array) -> int:
	var n := 0
	for b in w.buildings.values():
		if b.type in types:
			n += b.max_workers()
	return n


func _spare(w: World) -> int:
	var wanted := 0
	for b in w.workplaces():
		wanted += b.wanted
	return _adults(w) - w.builders_wanted - wanted


## Share the adults out: food and firewood first, then what keeps them going.
func _allocate(w: World) -> void:
	var adults := _adults(w)
	var builders := clampi(adults / 6, 1, 6) if not w.sites().is_empty() else 1
	w.set_builders(builders)
	var budget := adults - builders - 1 - adults / 10
	var places := w.workplaces()
	for b in places:
		b.wanted = 0
	var plan := [
		[["gatherer", "hunter", "fisher", "field"], _food_workers(w)],
		[["woodcutter"], _wood_workers(w)],
		[["forester"], 1 + _count(w, "house") / 3],
		[["quarry"], 4 if w.stock("stone") < 40 else 2],
		[["tailor"], 1 if w.stock("coats") < w.citizens.size() else 0],
		[["blacksmith"], 1 if w.stock("tools") < w.citizens.size() else 0],
		[["mine"], 2 if w.stock("iron") < 20 or w.stock("tools") < w.citizens.size() else 0],
		[["herbalist"], 1], [["trading_post"], 1], [["windmill", "bakery", "school", "market"], 1],
		[["orchard", "pasture", "weaver", "glassworks", "university", "harbour"], 1],
	]
	# spare hands go where the town is shortest
	var wood_short := w.stock("logs") < 80 or w.stock("firewood") < w.citizens.size() * 6
	var food_short := w.food_total() < w.citizens.size() * 40
	if wood_short and not food_short:
		plan.append([["forester", "woodcutter"], 99])
	plan.append([["gatherer", "hunter", "fisher", "field", "orchard", "pasture"], 99 if food_short or not wood_short else 2])
	plan.append([["forester", "woodcutter", "quarry", "mine"], 99])
	for p in plan:
		var want: int = p[1]
		var group := places.filter(func(b): return b.type in p[0])
		# spread over the group a worker at a time
		var progress := true
		while want > 0 and budget > 0 and progress:
			progress = false
			for b in group:
				if want <= 0 or budget <= 0:
					break
				if b.wanted < b.max_workers():
					b.wanted += 1
					want -= 1
					budget -= 1
					progress = true


## Short of logs: mark the nearest thick patch of forest for the labourers to clear.
func _mark_trees(w: World) -> void:
	var camp := Vector2i(w.width / 2, w.height / 2)
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for y in range(camp.y - 24, camp.y + 24, 3):
		for x in range(camp.x - 24, camp.x + 24, 3):
			var t := Vector2i(x, y)
			if not w.in_bounds(t):
				continue
			var score := _trees_near(w, t, 3) - Vector2(t).distance_to(Vector2(camp)) * 0.4
			if score > best_score:
				best_score = score
				best = t
	if best.x >= 0:
		w.mark_clear(Rect2i(best - Vector2i(3, 3), Vector2i(7, 7)), true)


func _count(w: World, type: String) -> int:
	return w.buildings.values().filter(func(b): return b.type == type).size()


func _can_afford(w: World, type: String) -> bool:
	var cost: Dictionary = Defs.BUILD[type].cost
	for k in cost:
		if w.stock(k) < int(cost[k]):
			return false
	return true


func _try(w: World, type: String) -> bool:
	if not w.unlocked(type) or not _can_afford(w, type):
		return false
	var spot := find_spot(w, type)
	if spot.x < 0:
		return false
	var id := w.place(type, spot)
	if id >= 0 and type == "field" and _count(w, "field") % 2 == 0:
		w.set_crop(id, "beans")
	return id >= 0


static func find_spot(w: World, type: String) -> Vector2i:
	var d: Dictionary = Defs.BUILD[type]
	var size: Vector2i = d.size
	var camp := Vector2i(w.width / 2, w.height / 2)
	var wants_forest: bool = type in ["gatherer", "hunter", "herbalist", "forester"]
	var far: bool = d.has("needs")
	var r := 45 if far else 24
	var best := Vector2i(-1, -1)
	var best_score := INF
	for y in range(camp.y - r, camp.y + r):
		for x in range(camp.x - r, camp.x + r):
			var p := Vector2i(x, y)
			if w.can_place(type, p) != "" or not _has_margin(w, p, size):
				continue
			var score := Vector2(p).distance_to(Vector2(camp))
			if wants_forest:
				score -= _trees_near(w, p + size / 2, 7) * 0.4
			elif type in ["house", "field", "stone_house"]:
				score += _trees_near(w, p + size / 2, 2) * 1.5
			if score < best_score:
				best_score = score
				best = p
	return best


static func _has_margin(w: World, p: Vector2i, size: Vector2i) -> bool:
	# leave a walkway around every building so nothing gets boxed in
	for y in range(-1, size.y + 2):
		for x in range(-1, size.x + 1):
			var t := p + Vector2i(x, y)
			if not w.in_bounds(t):
				return false
			if w.occ[w.idx(t)] >= 0:
				return false
	return true


static func _trees_near(w: World, c: Vector2i, r: int) -> int:
	var n := 0
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var t := c + Vector2i(x, y)
			if w.in_bounds(t) and w.is_tree(w.idx(t), 0.3):
				n += 1
	return n
