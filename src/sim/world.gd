class_name World
extends RefCounted
## The whole game state and its rules. Pure data and logic, no nodes, so it runs
## headless in tests and soak runs. The view reads it; the HUD calls its commands.

signal event(text: String, kind: String)      # kind: info, good, bad, birth, death
signal nomads_arrived(count: int)
signal era_changed(era: int)

const MALE_NAMES := ["Aldric", "Bram", "Cedric", "Duncan", "Edwin", "Finn", "Godric", "Hal", "Ivo", "Jory",
	"Kit", "Leof", "Mabon", "Ned", "Osric", "Piers", "Rafe", "Silas", "Tam", "Ulric", "Wat", "Wystan", "Ansel",
	"Bertram", "Colm", "Dunstan", "Elric", "Garth", "Hob", "Owen", "Robin", "Tobias", "Will", "Alfie", "Ewan"]
const FEMALE_NAMES := ["Ada", "Bryony", "Cecily", "Dora", "Edith", "Freya", "Gwen", "Hild", "Isolde", "Joan",
	"Kate", "Lettice", "Maud", "Nell", "Orla", "Petra", "Rosa", "Sybil", "Tilda", "Una", "Wren", "Agnes",
	"Beatrix", "Clemence", "Elsie", "Ivy", "Mabel", "Moll", "Rowan", "Elspeth", "Alys", "Hazel", "Juniper"]
const SURNAMES := ["Ashby", "Brook", "Carter", "Dale", "Fletcher", "Hart", "Hollins", "Marsh", "Miller",
	"Oakes", "Penn", "Reeve", "Shaw", "Thatcher", "Wade", "Weaver", "Wood", "Yardley", "Cobb", "Fenn", "Holt",
	"Lark", "Moss", "Rook", "Tanner", "Underhill", "Vane", "Warrick", "Hayward", "Bracken"]
const START := [
	{"couples": 7, "kids": 4, "stock": {"berries": 300, "venison": 300, "wheat": 300, "logs": 250, "stone": 150,
		"iron": 40, "firewood": 200, "tools": 40, "coats": 40, "herbs": 10}},
	{"couples": 6, "kids": 3, "stock": {"berries": 200, "venison": 200, "wheat": 200, "logs": 160, "stone": 100,
		"iron": 20, "firewood": 120, "tools": 20, "coats": 20, "herbs": 4}},
	{"couples": 5, "kids": 2, "stock": {"berries": 120, "venison": 100, "wheat": 80, "logs": 100, "stone": 50,
		"iron": 0, "firewood": 60, "tools": 8, "coats": 8}},
]

var map_seed := 1
var difficulty := 1
var width := 96
var height := 96
var tick := 0
var rng := RandomNumberGenerator.new()
var terrain := PackedByteArray()
var feature := PackedByteArray()
var growth := PackedFloat32Array()   # tree growth 0..1
var fert := PackedFloat32Array()
var road := PackedByteArray()
var mark := PackedByteArray()        # 1 = marked for clearing
var occ := PackedInt32Array()        # building id per tile, -1 free
var reserved := {}                   # tile index -> citizen id
var marked := {}                     # tile index -> true, tiles marked for clearing
var doors := {}                      # door tile -> building id
var astar := AStarGrid2D.new()
var buildings := {}                  # id -> Building
var citizens := {}                   # id -> Citizen
var next_id := 1
var builders_wanted := 4
var totals := {}                     # res -> units in storage
var merchant := {}                   # {"goods": {res: n}, "until": tick} while one is visiting
var pending_nomads := 0
var events_log: Array = []           # [{"tick", "text", "kind"}]
var made := {}                       # res -> units produced, for stats and tests
var restockers := {}                 # house id -> citizen fetching for it
var history: Array = []              # one entry per month
var game_over := false
# progression (see Progress and docs/PROGRESSION.md)
var era := 0
var techs := {}                      # tech id -> true once learned
var researching := ""
var research := {}                   # tech id -> knowledge put in so far
var knowledge := 0.0                 # gathered while nothing is being researched
var winters := 0                     # winters the town has come through
var sandbox := false                 # everything unlocked (tests, debugging)
var _mods := {}
var born_total := 0
var died_total := 0
const CHUNK := 16                    # the view redraws the map in chunks this size
var dirty_chunks := {}               # chunk index -> true, for the view
var revision := 0                    # bumped when tiles change, so the view knows to redraw
var building_revision := 0


# --- setup -----------------------------------------------------------------

func new_game(p_seed: int, p_difficulty := 1, size := 96) -> void:
	map_seed = p_seed
	difficulty = clampi(p_difficulty, 0, 2)
	width = size
	height = size
	rng.seed = map_seed * 7919 + 13
	MapGen.generate(self)
	_setup_astar()
	var c := Vector2i(width / 2, height / 2)
	var camp := place("camp", c - Vector2i(1, 1), true)
	var cb: Building = buildings[camp]
	var start: Dictionary = START[difficulty]
	for k in start.stock:
		store_add(cb, k, start.stock[k])
	for i in start.couples:
		var sur: String = SURNAMES[rng.randi() % SURNAMES.size()]
		var m := spawn(true, rng.randf_range(18, 34), sur, c)
		var f := spawn(false, rng.randf_range(17, 32), sur, c)
		m.partner = f.id
		f.partner = m.id
		if i < start.kids:
			var kid := spawn(rng.randf() < 0.5, rng.randf_range(1, 5), sur, c)
			kid.mother = f.id
			kid.father = m.id
	for cid in citizens:
		var p: Citizen = citizens[cid]
		p.tool = 1.0 if p.is_adult() else 0.0
		p.coat = 1.0
	say("Your people arrive in the valley. Winter is nine months away.", "info")


func spawn(male: bool, age: float, sur: String, at: Vector2i) -> Citizen:
	var c := Citizen.new()
	c.id = next_id
	next_id += 1
	c.male = male
	c.age = age
	c.surname = sur
	var names: Array = MALE_NAMES if male else FEMALE_NAMES
	c.first = names[rng.randi() % names.size()]
	var t := nearest_passable(at + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3)))
	c.pos = Vector2(t) + Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
	c.wait = rng.randi_range(0, 10)
	citizens[c.id] = c
	return c


func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in height:
		for x in width:
			_refresh_tile(Vector2i(x, y))


func _refresh_tile(t: Vector2i) -> void:
	dirty_chunks[(t.y / CHUNK) * ceili(float(width) / CHUNK) + t.x / CHUNK] = true
	var i := idx(t)
	var ter := terrain[i]
	var solid := ter == Defs.Terrain.WATER or ter == Defs.Terrain.ROCK
	if occ[i] >= 0:
		var b: Building = buildings.get(occ[i])
		if b and b.is_solid():
			solid = true
	astar.set_point_solid(t, solid)
	if solid:
		return
	var wgt := 1.0
	if road[i]:
		wgt = 0.6
	elif ter == Defs.Terrain.FORD:
		wgt = 2.0
	elif feature[i] == Defs.Feature.TREE and growth[i] > 0.3:
		wgt = 1.35
	astar.set_point_weight_scale(t, wgt)


# --- tiles -----------------------------------------------------------------

func idx(t: Vector2i) -> int:
	return t.y * width + t.x


func tile_of(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


func passable(t: Vector2i) -> bool:
	return in_bounds(t) and not astar.is_point_solid(t)


func nearest_passable(t: Vector2i) -> Vector2i:
	t = t.clamp(Vector2i.ZERO, Vector2i(width - 1, height - 1))
	if passable(t):
		return t
	for r in range(1, 12):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var p := t + Vector2i(x, y)
				if passable(p):
					return p
	return t


var path_calls := 0
var path_fails := 0
var path_usec := 0


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	path_calls += 1
	if not passable(to):
		path_fails += 1
		return out
	if not passable(from):
		from = nearest_passable(from)
	var t := Time.get_ticks_usec()
	out.assign(astar.get_id_path(from, to))
	path_usec += Time.get_ticks_usec() - t
	if out.is_empty():
		path_fails += 1
	return out


func set_tree(t: Vector2i, g: float) -> void:
	var i := idx(t)
	feature[i] = Defs.Feature.TREE
	growth[i] = g
	_refresh_tile(t)
	revision += 1


func clear_feature(t: Vector2i) -> void:
	var i := idx(t)
	if feature[i] == Defs.Feature.TREE or feature[i] == Defs.Feature.BOULDER:
		feature[i] = Defs.Feature.NONE
		growth[i] = 0.0
	mark[i] = 0
	marked.erase(i)
	_refresh_tile(t)
	revision += 1


func is_tree(i: int, min_growth := 0.0) -> bool:
	return feature[i] == Defs.Feature.TREE and growth[i] >= min_growth


# --- buildings: placing and removing ---------------------------------------

static func door_of(type: String, pos: Vector2i) -> Vector2i:
	var d: Dictionary = Defs.BUILD[type]
	var s: Vector2i = d.size
	if d.kind == "field" or d.kind == "road":
		return pos
	return Vector2i(pos.x + s.x / 2, pos.y + s.y)


## Returns "" if the building fits there, otherwise the reason it does not.
func can_place(type: String, pos: Vector2i) -> String:
	var d: Dictionary = Defs.BUILD[type]
	if not unlocked(type):
		return "Not discovered yet: research %s" % Progress.TECHS[Progress.tech_for(type)].name
	var s: Vector2i = d.size
	var need_dep := 0
	var water_near := false
	for y in s.y:
		for x in s.x:
			var t := pos + Vector2i(x, y)
			if not in_bounds(t):
				return "Off the map"
			var i := idx(t)
			if terrain[i] != Defs.Terrain.GRASS:
				return "Needs dry, open ground"
			if occ[i] >= 0:
				return "Something is already there"
			if road[i] and d.kind != "road":
				return "Remove the road first"
			var f := feature[i]
			if (d.get("needs") == "stone_dep" and f == Defs.Feature.STONE_DEP) or \
					(d.get("needs") == "iron_dep" and f == Defs.Feature.IRON_DEP):
				need_dep += 1
	if d.get("needs") == "stone_dep" and need_dep < s.x * s.y / 2:
		return "Build it on grey stone ground"
	if d.get("needs") == "iron_dep" and need_dep < s.x * s.y / 2:
		return "Build it on rust-red iron ground"
	if d.get("needs") == "water":
		for y in range(-1, s.y + 1):
			for x in range(-1, s.x + 1):
				var t := pos + Vector2i(x, y)
				if in_bounds(t) and terrain[idx(t)] == Defs.Terrain.WATER:
					water_near = true
		if not water_near:
			return "Must touch water"
	if d.kind != "field" and d.kind != "road":
		var door := door_of(type, pos)
		if not in_bounds(door) or terrain[idx(door)] == Defs.Terrain.WATER \
				or terrain[idx(door)] == Defs.Terrain.ROCK or occ[idx(door)] >= 0:
			return "The door is blocked"
		if doors.has(door):
			return "The door is blocked"
	# don't cover another building's door
	for y in s.y:
		for x in s.x:
			if doors.has(pos + Vector2i(x, y)):
				return "Would block a door"
	return ""


func rebuild_doors() -> void:
	doors.clear()
	for b in buildings.values():
		if b.kind() != "field":
			doors[b.door] = b.id


func place(type: String, pos: Vector2i, instant := false) -> int:
	if type == "road":
		return 1 if place_road([pos]) > 0 else -1
	if can_place(type, pos) != "":
		return -1
	var d: Dictionary = Defs.BUILD[type]
	var b := Building.new()
	b.id = next_id
	next_id += 1
	b.type = type
	b.pos = pos
	b.size = d.size
	b.door = door_of(type, pos)
	b.work = float(d.work)
	for k in d.cost:
		b.needed[k] = int(d.cost[k])
	if b.kind() == "field":
		b.field.resize(b.size.x * b.size.y)
		b.field.fill(-1.0)
		b.field_busy.resize(b.size.x * b.size.y)
	buildings[b.id] = b
	if b.kind() != "field":
		doors[b.door] = b.id
	# clearing the ground is part of the work; what is cut goes into the site
	for y in b.size.y:
		for x in b.size.x:
			var t := pos + Vector2i(x, y)
			var i := idx(t)
			var f := feature[i]
			if f == Defs.Feature.TREE or f == Defs.Feature.BOULDER:
				b.work += Defs.CLEAR_TICKS[f] * 0.5
				for r in Defs.CLEAR_YIELD[f]:
					if b.needed.get(r, 0) > 0:
						b.needed[r] = maxi(0, b.needed[r] - Defs.CLEAR_YIELD[f][r])
				feature[i] = Defs.Feature.NONE
				growth[i] = 0.0
			mark[i] = 0
			marked.erase(i)
			reserved.erase(i)
			occ[i] = b.id
	for y in b.size.y:
		for x in b.size.x:
			_refresh_tile(pos + Vector2i(x, y))
	if b.is_solid():
		_evict_from(b)
	if instant or (b.work <= 0 and b.materials_ready()):
		_finish(b)
	revision += 1
	building_revision += 1
	return b.id


func _evict_from(b: Building) -> void:
	for c in citizens.values():
		if b.contains(c.tile()):
			c.pos = Vector2(nearest_passable(c.tile())) + Vector2(0.5, 0.5)
			c.path.clear()


func _finish(b: Building) -> void:
	b.built = true
	b.progress = b.work
	b.needed.clear()
	b.incoming.clear()
	if b.max_workers() > 0:
		b.wanted = b.max_workers() if b.kind() != "trade" else 1
		if b.kind() == "field":
			b.wanted = 2
	if b.kind() == "gather":
		update_forest(b)
	building_revision += 1
	if b.type != "camp" and b.type != "stockpile":
		say("%s finished." % b.title(), "good")
	if b.kind() == "house":
		_housing()


func place_road(tiles: Array) -> int:
	var n := 0
	for t in tiles:
		if not in_bounds(t):
			continue
		var i := idx(t)
		if road[i] or terrain[i] == Defs.Terrain.WATER or terrain[i] == Defs.Terrain.ROCK:
			continue
		if occ[i] >= 0 and buildings[occ[i]].kind() != "field":
			continue
		if occ[i] >= 0:
			continue
		if feature[i] == Defs.Feature.TREE or feature[i] == Defs.Feature.BOULDER:
			feature[i] = Defs.Feature.NONE
			growth[i] = 0.0
		mark[i] = 0
		marked.erase(i)
		road[i] = 1
		_refresh_tile(t)
		n += 1
	if n:
		revision += 1
	return n


func remove_road(t: Vector2i) -> bool:
	if not in_bounds(t) or not road[idx(t)]:
		return false
	road[idx(t)] = 0
	_refresh_tile(t)
	revision += 1
	return true


func demolish(id: int, burned := false) -> void:
	var b: Building = buildings.get(id)
	if b == null or b.type == "camp":
		return
	for cid in b.workers:
		var c: Citizen = citizens.get(cid)
		if c:
			c.job = Citizen.LABOURER
	for cid in b.residents:
		var c: Citizen = citizens.get(cid)
		if c:
			c.home = -1
	for c in citizens.values():
		if c.res_haul == id or c.res_site == id:
			AI.abort(self, c)
		elif not c.plan.is_empty() and _plan_uses(c, id):
			AI.abort(self, c)
	if b.kind() == "storage":
		for k in b.inv:
			totals[k] = totals.get(k, 0) - b.inv[k]
	buildings.erase(id)
	rebuild_doors()
	for y in b.size.y:
		for x in b.size.x:
			var t := b.pos + Vector2i(x, y)
			occ[idx(t)] = -1
			_refresh_tile(t)
	if not burned:
		# give back half of what went into it
		var refund := {}
		var cost: Dictionary = b.def().cost
		for k in cost:
			var got: int = cost[k] - b.needed.get(k, 0) if not b.built else cost[k]
			refund[k] = got / 2
		for k in refund:
			if refund[k] > 0:
				var s := find_storage_space(k, b.door)
				if s:
					store_add(s, k, mini(refund[k], s.space()))
	revision += 1
	building_revision += 1


func _plan_uses(c: Citizen, id: int) -> bool:
	for step in c.plan:
		if step.get("b", -1) == id:
			return true
	return false


func building_at(t: Vector2i) -> Building:
	if not in_bounds(t):
		return null
	var id := occ[idx(t)]
	return buildings.get(id) if id >= 0 else null


func mark_clear(rect: Rect2i, on: bool) -> int:
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if not in_bounds(t):
				continue
			var i := idx(t)
			if on and (feature[i] == Defs.Feature.TREE or feature[i] == Defs.Feature.BOULDER) and occ[i] < 0:
				if not mark[i]:
					n += 1
				mark[i] = 1
				marked[i] = true
			elif not on and mark[i]:
				mark[i] = 0
				marked.erase(i)
				n += 1
	if n:
		revision += 1
	return n


func set_wanted(id: int, n: int) -> void:
	var b: Building = buildings.get(id)
	if b:
		b.wanted = clampi(n, 0, b.max_workers())


func set_crop(id: int, crop: String) -> void:
	var b: Building = buildings.get(id)
	if b and crop in Defs.CROPS:
		b.crop = crop


func set_builders(n: int) -> void:
	builders_wanted = clampi(n, 0, 40)


# --- storage ----------------------------------------------------------------

func storages() -> Array:
	return buildings.values().filter(func(b): return b.kind() == "storage" and b.built)


func store_add(b: Building, res: String, n: int) -> int:
	n = mini(n, b.space())
	if n <= 0:
		return 0
	b.inv[res] = b.inv.get(res, 0) + n
	totals[res] = totals.get(res, 0) + n
	return n


func store_take(b: Building, res: String, n: int) -> int:
	n = mini(n, b.inv.get(res, 0))
	if n <= 0:
		return 0
	b.inv[res] -= n
	if b.inv[res] == 0:
		b.inv.erase(res)
	totals[res] = totals.get(res, 0) - n
	return n


func stock(res: String) -> int:
	return totals.get(res, 0)


func food_total() -> int:
	var n := 0
	for f in Defs.FOODS:
		n += totals.get(f, 0)
	return n


func find_storage_with(res: String, from: Vector2i, food_any := false) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings.values():
		if b.kind() != "storage" or not b.built:
			continue
		var has := false
		if food_any:
			for f in Defs.FOODS:
				if b.inv.get(f, 0) > 0:
					has = true
		else:
			has = b.inv.get(res, 0) > 0
		if not has:
			continue
		var d := Vector2(b.door).distance_squared_to(Vector2(from))
		if d < bd:
			bd = d
			best = b
	return best


func find_storage_space(res: String, from: Vector2i) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings.values():
		if not b.accepts(res) or b.space() <= 0:
			continue
		var d := Vector2(b.door).distance_squared_to(Vector2(from))
		# the camp is a fallback once proper stores exist
		if b.type == "camp":
			d += 400.0
		if d < bd:
			bd = d
			best = b
	return best


# --- time ------------------------------------------------------------------

func month() -> int:
	return Defs.month_of(tick)


func abs_month() -> int:
	return int(tick / Defs.MONTH_TICKS)


func temperature() -> float:
	return Defs.temp_of(tick)


func step() -> void:
	if game_over:
		return
	tick += 1
	for c in citizens.values():
		AI.update(self, c)
	if tick % 10 == 0:
		_grow_fields(10)
		_burning(10)
	if tick % 20 == 0:
		_assign_jobs()
	if tick % Defs.MONTH_TICKS == 0:
		_monthly()


func run(ticks: int) -> void:
	for i in ticks:
		step()
		if game_over:
			return


func count_made(res: String, n: int) -> void:
	if n > 0:
		made[res] = made.get(res, 0) + n


func say(text: String, kind := "info") -> void:
	events_log.append({"tick": tick, "text": text, "kind": kind})
	if events_log.size() > 200:
		events_log.pop_front()
	event.emit(text, kind)


# --- jobs ------------------------------------------------------------------

func workplaces() -> Array:
	return buildings.values().filter(func(b): return b.built and b.max_workers() > 0)


func sites() -> Array:
	return buildings.values().filter(func(b): return not b.built)


func _assign_jobs() -> void:
	var labourers: Array = []
	var builders := 0
	for c in citizens.values():
		if not c.is_adult() or c.arriving:
			continue
		if c.job == Citizen.BUILDER:
			builders += 1
		elif c.job == Citizen.LABOURER:
			labourers.append(c)
		elif not buildings.has(c.job):
			c.job = Citizen.LABOURER
			labourers.append(c)
	for b in workplaces():
		b.workers.assign(b.workers.filter(func(id): return citizens.has(id) and citizens[id].job == b.id))
		while b.workers.size() > b.wanted:
			var c: Citizen = citizens[b.workers.pop_back()]
			c.job = Citizen.LABOURER
			labourers.append(c)
	if builders > builders_wanted:
		for c in citizens.values():
			if builders <= builders_wanted:
				break
			if c.job == Citizen.BUILDER:
				c.job = Citizen.LABOURER
				labourers.append(c)
				builders -= 1
	for b in workplaces():
		while b.workers.size() < b.wanted and not labourers.is_empty():
			var best := 0
			var bd := INF
			for i in labourers.size():
				var d: float = labourers[i].pos.distance_squared_to(Vector2(b.door))
				if d < bd:
					bd = d
					best = i
			var c: Citizen = labourers[best]
			labourers.remove_at(best)
			c.job = b.id
			b.workers.append(c.id)
	while builders < builders_wanted and not labourers.is_empty():
		var c: Citizen = labourers.pop_back()
		c.job = Citizen.BUILDER
		builders += 1


func job_name(c: Citizen) -> String:
	if not c.is_adult():
		return "Child"
	if c.job == Citizen.BUILDER:
		return "Builder"
	if c.job == Citizen.LABOURER:
		return "Labourer"
	var b: Building = buildings.get(c.job)
	if b == null:
		return "Labourer"
	match b.type:
		"gatherer": return "Gatherer"
		"hunter": return "Hunter"
		"fisher": return "Fisher"
		"field": return "Farmer"
		"forester": return "Forester"
		"herbalist": return "Herbalist"
		"woodcutter": return "Woodcutter"
		"blacksmith": return "Blacksmith"
		"tailor": return "Tailor"
		"quarry": return "Stonecutter"
		"mine": return "Miner"
		"trading_post": return "Trader"
	return "Worker"


# --- monthly rules ----------------------------------------------------------

func _monthly() -> void:
	var m := month()
	_progress_month()
	_ageing()
	_births()
	_housing()
	_burn_wood()
	_illness()
	_happiness()
	if m % 3 == 0:
		_trees()
	for b in buildings.values():
		if b.built and b.type == "hunter":
			b.game = minf(1.0, b.game + 0.08 * mod("game"))
		if b.built and b.kind() == "gather" and m % 3 == 0:
			update_forest(b)
	if m == Defs.FROST_MONTH:
		_frost()
	_merchant()
	_nomads()
	_fires()
	if m == 6 and stock("firewood") < citizens.size() * 3:
		say("Autumn is here and firewood is short.", "bad")
	if m == 8 and food_total() < citizens.size() * 25:
		say("Winter is coming and there is not much food stored.", "bad")
	history.append({"pop": citizens.size(), "food": food_total(), "firewood": stock("firewood"),
		"adults": citizens.values().filter(func(c): return c.is_adult()).size()})
	if history.size() > 600:
		history.pop_front()
	if citizens.is_empty():
		game_over = true
		say("The last of your people is gone.", "death")


func _ageing() -> void:
	for c in citizens.values():
		var was_child: bool = not c.is_adult()
		c.age += 1.0 / Defs.MONTHS_PER_YEAR
		if was_child and c.is_adult():
			c.tool = 0.0
		if c.age > Defs.OLD_AGE:
			var chance := pow((c.age - Defs.OLD_AGE) / (Defs.MAX_AGE - Defs.OLD_AGE), 2.0) * 0.08
			if rng.randf() < chance or c.age >= Defs.MAX_AGE:
				kill(c, "died of old age at %d" % int(c.age))


func _births() -> void:
	for c in citizens.values():
		if c.pregnant > 0:
			c.pregnant -= 1
			if c.pregnant == 0:
				var father: Citizen = citizens.get(c.partner)
				var sur: String = father.surname if father else c.surname
				var kid := spawn(rng.randf() < 0.5, 0.0, sur, c.tile())
				kid.pos = c.pos
				kid.mother = c.id
				kid.father = c.partner
				kid.home = c.home
				kid.coat = 0.0
				if buildings.has(c.home):
					buildings[c.home].residents.append(kid.id)
				born_total += 1
				say("%s was born to %s." % [kid.first + " " + kid.surname, c.first], "birth")
	for b in buildings.values():
		if b.kind() != "house" or not b.built:
			continue
		if b.residents.size() >= int(b.def().residents):
			continue
		for cid in b.residents:
			var f: Citizen = citizens.get(cid)
			if f == null or f.male or f.pregnant > 0 or f.partner < 0 or f.sick:
				continue
			if f.age < Defs.FERTILE_MIN or f.age > Defs.FERTILE_MAX:
				continue
			if not b.residents.has(f.partner):
				continue
			if rng.randf() < Defs.BIRTH_CHANCE * (0.6 + f.happy * 0.6):
				f.pregnant = Defs.PREGNANCY_MONTHS


func _lives_alone(c: Citizen) -> bool:
	if not buildings.has(c.home):
		return false
	for rid in buildings[c.home].residents:
		var r: Citizen = citizens.get(rid)
		if r and r != c and r.is_adult():
			return false
	return true


func _vacant_houses() -> Array:
	return buildings.values().filter(func(b): return b.kind() == "house" and b.built and b.residents.is_empty() and b.fire == 0)


func _set_home(c: Citizen, b: Building) -> void:
	if buildings.has(c.home):
		buildings[c.home].residents.erase(c.id)
	c.home = b.id if b else -1
	if b and not b.residents.has(c.id):
		b.residents.append(c.id)


func _move_household(head: Citizen, b: Building) -> void:
	var members: Array = [head]
	var p: Citizen = citizens.get(head.partner)
	if p:
		members.append(p)
	for c in citizens.values():
		if not c.is_adult() and (c.mother == head.id or c.father == head.id or (p and (c.mother == p.id or c.father == p.id))):
			if not members.has(c):
				members.append(c)
	for c in members:
		_set_home(c, b)


func _housing() -> void:
	var vacant := _vacant_houses()
	# couples form when there is somewhere for them to live
	var singles: Array = citizens.values().filter(func(c): return c.age >= Defs.FERTILE_MIN and c.partner < 0 and not c.arriving)
	for m in singles:
		if not m.male or m.partner >= 0:
			continue
		for f in singles:
			if f.male or f.partner >= 0 or absf(f.age - m.age) > 15:
				continue
			if (f.mother >= 0 and f.mother == m.mother) or (f.father >= 0 and f.father == m.father):
				continue
			var m_alone := _lives_alone(m)
			var f_alone := _lives_alone(f)
			if vacant.is_empty() and not m_alone and not f_alone:
				continue
			m.partner = f.id
			f.partner = m.id
			if f.surname != m.surname:
				f.surname = m.surname
			if m_alone:
				_move_household(f, buildings[m.home])
			elif f_alone:
				_move_household(m, buildings[f.home])
			else:
				var h: Building = vacant.pop_front()
				_move_household(m, h)
			break
	# households without their own house move into empty ones, the homeless first
	var heads: Array = []
	for c in citizens.values():
		if not c.is_adult() or c.arriving:
			continue
		var p: Citizen = citizens.get(c.partner)
		if p and p.id < c.id:
			continue   # one head per couple
		if c.home < 0 and (p == null or p.home < 0):
			heads.push_front(c)
		elif buildings.has(c.home):
			var h: Building = buildings[c.home]
			var parent_there := h.residents.has(c.mother) or h.residents.has(c.father)
			if parent_there or (p and p.home != c.home):
				heads.append(c)
	for c in heads:
		if vacant.is_empty():
			break
		_move_household(c, vacant.pop_front())
	# homeless children follow a parent
	for c in citizens.values():
		if c.home < 0 and not c.is_adult():
			for pid in [c.mother, c.father]:
				var par: Citizen = citizens.get(pid)
				if par and par.home >= 0:
					_set_home(c, buildings[par.home])
					break


func _burn_wood() -> void:
	var cold: bool = Defs.MONTH_TEMP[month()] < Defs.COLD_BELOW
	for b in buildings.values():
		if b.kind() != "house" or not b.built:
			continue
		if b.residents.is_empty():
			b.warm = true
			continue
		var need := int(ceil((Defs.WOOD_BURN_COLD if cold else Defs.WOOD_BURN_WARM) * float(b.def().burn)))
		var have: int = b.inv.get("firewood", 0)
		b.inv["firewood"] = maxi(0, have - need)
		b.warm = have >= need or not cold


func _illness() -> void:
	var now := abs_month()
	for c in citizens.values():
		if c.sick:
			var h: Building = buildings.get(c.home)
			var chance := 0.4
			if h and h.inv.get("herbs", 0) > 0:
				h.inv["herbs"] -= 1
				chance = minf(0.98, 0.85 * mod("cure"))
			if rng.randf() < chance:
				c.sick = false
			continue
		var p := 0.003
		if variety(c, now) < 2:
			p += 0.01
		if c.home < 0:
			p += 0.01
		if c.age > Defs.OLD_AGE:
			p += 0.01
		if rng.randf() < p * mod("illness"):
			c.sick = true
			say("%s has fallen ill." % c.name(), "bad")


func variety(c: Citizen, now := -1) -> int:
	if now < 0:
		now = abs_month()
	var n := 0
	for f in c.diet:
		if now - c.diet[f] <= 6:
			n += 1
	return n


func _happiness() -> void:
	var decor: Array = buildings.values().filter(func(b): return b.built and b.kind() == "decor")
	for c in citizens.values():
		var h := 0.35
		var home: Building = buildings.get(c.home)
		if home:
			h += 0.15
			if home.type == "stone_house":
				h += 0.05
			if not home.warm:
				h -= 0.15
			var bonus := 0.0
			for d in decor:
				if d.center().distance_to(home.center()) <= float(d.def().radius):
					bonus += float(d.def().happy)
			h += minf(bonus, 0.35)
		var v := variety(c)
		h += 0.05 * mini(v, 4)
		if c.sick:
			h -= 0.15
		if c.full < 0.1:
			h -= 0.2
		c.happy = clampf(h, 0.0, 1.0)


func update_forest(b: Building) -> void:
	var r := int(b.def().get("radius", 10))
	var n := 0
	var cc := b.center()
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var t := Vector2i(int(cc.x) + x, int(cc.y) + y)
			if in_bounds(t) and Vector2(x, y).length() <= r and is_tree(idx(t), 0.3):
				n += 1
	b.forest = clampf(n / (PI * r * r * 0.3), 0.0, 1.0)


func _trees() -> void:
	# called each season: trees grow and the forest creeps outward
	var spread: Array[int] = []
	var months := 3.0
	for i in feature.size():
		if feature[i] != Defs.Feature.TREE:
			continue
		growth[i] = minf(1.0, growth[i] + Defs.TREE_GROW * Defs.MONTH_TICKS * months)
		if growth[i] >= Defs.TREE_GROWN and rng.randf() < 0.01:
			spread.append(i)
	for i in spread:
		var t := tile_of(i) + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		if not in_bounds(t):
			continue
		var j := idx(t)
		if terrain[j] == Defs.Terrain.GRASS and feature[j] == Defs.Feature.NONE and occ[j] < 0 and not road[j]:
			feature[j] = Defs.Feature.TREE
			growth[j] = 0.05
	for i in feature.size():
		if feature[i] == Defs.Feature.TREE:
			_refresh_tile(tile_of(i))
	revision += 1


func _grow_fields(dt: int) -> void:
	var m := month()
	var growing := m in Defs.GROW_MONTHS
	for b in buildings.values():
		if b.kind() != "field" or not b.built:
			continue
		for i in b.field.size():
			if b.field[i] >= 0.0 and b.field[i] < 1.0 and growing:
				var rate := Defs.CROP_GROW * (1.15 if b.crop == "beans" else 1.0)
				b.field[i] = minf(1.0, b.field[i] + rate * dt)


func _frost() -> void:
	var lost := 0
	for b in buildings.values():
		if b.kind() != "field":
			continue
		for i in b.field.size():
			if b.field[i] >= 0.0:
				lost += 1
				b.field[i] = -1.0
	if lost > 0:
		say("Frost killed %d rows of unharvested crops." % lost, "bad")
	revision += 1


func field_tile(b: Building, i: int) -> Vector2i:
	return b.pos + Vector2i(i % b.size.x, i / b.size.x)


func _merchant() -> void:
	if not merchant.is_empty():
		if tick >= merchant.until:
			merchant = {}
			say("The merchant has left.", "info")
		return
	var post: Building = null
	for b in buildings.values():
		if b.type == "trading_post" and b.built and not b.workers.is_empty():
			post = b
	if post == null or rng.randf() > 0.3 * mod("merchant"):
		return
	var goods := {}
	var pool := ["berries", "venison", "fish", "wheat", "beans", "tools", "coats", "iron", "logs", "stone",
		"herbs", "firewood", "hides"]
	pool.shuffle()
	for k in pool.slice(0, 5):
		goods[k] = rng.randi_range(40, 160) if Defs.RES[k].value <= 4 else rng.randi_range(10, 40)
	merchant = {"goods": goods, "until": tick + Defs.MONTH_TICKS * 2, "post": post.id}
	say("A merchant has arrived at the trading post.", "good")


## Swap goods with a visiting merchant. Fails unless what you give is worth at least what you get.
func trade(give: Dictionary, take: Dictionary) -> bool:
	if merchant.is_empty():
		return false
	var give_v := 0
	var get_v := 0
	for k in give:
		if give[k] < 0 or stock(k) < give[k]:
			return false
		give_v += give[k] * int(Defs.RES[k].value)
	for k in take:
		if take[k] < 0 or merchant.goods.get(k, 0) < take[k]:
			return false
		get_v += take[k] * int(Defs.RES[k].value)
	if give_v < get_v or get_v == 0:
		return false
	for k in give:
		var left: int = give[k]
		for s in storages():
			left -= store_take(s, k, left)
			if left <= 0:
				break
	var post: Building = buildings.get(merchant.post)
	var at: Vector2i = post.door if post else Vector2i(width / 2, height / 2)
	for k in take:
		var left: int = take[k]
		while left > 0:
			var s := find_storage_space(k, at)
			if s == null:
				break
			left -= store_add(s, k, left)
		merchant.goods[k] -= take[k]
	say("Traded with the merchant.", "good")
	return true


func _nomads() -> void:
	if month() != 1 or pending_nomads > 0:
		return
	var hall := false
	for b in buildings.values():
		if b.type == "town_hall" and b.built:
			hall = true
	if not hall or rng.randf() > 0.6:
		return
	pending_nomads = rng.randi_range(4, 9)
	say("%d nomads ask to join your town." % pending_nomads, "info")
	nomads_arrived.emit(pending_nomads)


func answer_nomads(accept: bool) -> void:
	if pending_nomads <= 0:
		return
	var n := pending_nomads
	pending_nomads = 0
	if not accept:
		say("The nomads move on.", "info")
		return
	var edge := Vector2i(rng.randi_range(2, width - 3), 1)
	for i in range(n):
		var c := spawn(rng.randf() < 0.5, rng.randf_range(12, 40), SURNAMES[rng.randi() % SURNAMES.size()], edge)
		c.arriving = true
		c.sick = rng.randf() < 0.15
		c.coat = 0.3
	say("%d nomads have joined your town." % n, "good")


func _fires() -> void:
	for b in buildings.values():
		if not b.built or b.fire > 0 or b.kind() in ["field", "storage", "decor", "road"]:
			continue
		if b.type == "stockpile" or b.type == "camp":
			continue
		if rng.randf() < 0.0008 * mod("fire"):
			b.fire = 80 if _well_near(b) else 260
			say("%s is on fire!" % b.title(), "bad")


func _well_near(b: Building) -> bool:
	for w in buildings.values():
		if w.type == "well" and w.built and w.center().distance_to(b.center()) <= float(w.def().radius):
			return true
	return false


func _burning(dt: int) -> void:
	for b in buildings.values():
		if b.fire <= 0:
			continue
		b.fire = maxi(0, b.fire - dt)
		if b.fire == 0:
			if _well_near(b):
				say("The fire at the %s was put out." % b.title().to_lower(), "good")
			else:
				say("The %s burned down." % b.title().to_lower(), "bad")
				demolish(b.id, true)
			building_revision += 1


func kill(c: Citizen, why: String) -> void:
	if not citizens.has(c.id):
		return
	AI.abort(self, c)
	var b: Building = buildings.get(c.job)
	if b:
		b.workers.erase(c.id)
	var h: Building = buildings.get(c.home)
	if h:
		h.residents.erase(c.id)
	var p: Citizen = citizens.get(c.partner)
	if p:
		p.partner = -1
	citizens.erase(c.id)
	died_total += 1
	say("%s %s." % [c.name(), why], "death")


# --- progression ---------------------------------------------------------------

func unlocked(type: String) -> bool:
	if sandbox or type in Progress.START_BUILDINGS:
		return true
	var t := Progress.tech_for(type)
	return t == "" or techs.has(t)


func unlock_all() -> void:
	sandbox = true


## A rule multiplier from the techs learned, 1.0 if none changes it.
func mod(name: String) -> float:
	return _mods.get(name, 1.0)


func _recompute_mods() -> void:
	_mods.clear()
	for id in techs:
		var m: Dictionary = Progress.TECHS[id].get("mods", {})
		for k in m:
			_mods[k] = _mods.get(k, 1.0) * float(m[k])


## "done", "researching", "available", "needs" (a prerequisite) or "era" (later era).
func tech_state(id: String) -> String:
	var t: Dictionary = Progress.TECHS[id]
	if techs.has(id):
		return "done"
	if int(t.era) > era:
		return "era"
	for n in t.needs:
		if not techs.has(n):
			return "needs"
	return "researching" if researching == id else "available"


func start_research(id: String) -> bool:
	if not Progress.TECHS.has(id) or tech_state(id) not in ["available", "researching"]:
		return false
	researching = id
	_put_knowledge(0.0)
	return true


func knowledge_rate() -> float:
	var adults := citizens.values().filter(func(c): return c.is_adult()).size()
	return Progress.knowledge_rate(adults)


func _put_knowledge(amount: float) -> void:
	knowledge += amount
	if researching == "":
		return
	var cost := float(Progress.TECHS[researching].cost)
	var have: float = research.get(researching, 0.0)
	var add := minf(knowledge, cost - have)
	research[researching] = have + add
	knowledge -= add
	if research[researching] >= cost - 0.001:
		_learn(researching)


func _learn(id: String) -> void:
	techs[id] = true
	research.erase(id)
	if researching == id:
		researching = ""
	_recompute_mods()
	var t: Dictionary = Progress.TECHS[id]
	say("Discovered %s: %s" % [t.name, t.desc], "good")
	building_revision += 1


func era_techs_done(e: int) -> int:
	var n := 0
	for id in techs:
		if int(Progress.TECHS[id].era) == e:
			n += 1
	return n


## The milestones for leaving the current era: [{text, have, need}].
func milestones() -> Array:
	var out: Array = []
	if era >= Progress.ERAS.size() - 1:
		return out
	for m in Progress.ERAS[era].milestones:
		var have := 0
		var kind: String = m[0]
		match kind:
			"pop": have = citizens.size()
			"houses": have = buildings.values().filter(func(b): return b.kind() == "house" and b.built).size()
			"winters": have = winters
			"techs": have = era_techs_done(era)
			"crops":
				for c in Defs.CROPS:
					have += made.get(c, 0)
			_:
				if kind.begins_with("building:"):
					var type := kind.substr(9)
					have = buildings.values().filter(func(b): return b.type == type and b.built).size()
		out.append({"text": m[2], "have": have, "need": int(m[1])})
	return out


func _progress_month() -> void:
	_put_knowledge(knowledge_rate())
	if month() == 0 and tick > 0 and not citizens.is_empty():
		winters += 1
	var ms := milestones()
	if not ms.is_empty() and ms.all(func(m): return m.have >= m.need):
		era += 1
		say("A new era begins: %s. %s" % [Progress.ERAS[era].name, Progress.ERAS[era].desc], "good")
		era_changed.emit(era)
		building_revision += 1


# --- queries for the HUD ----------------------------------------------------

func population() -> Dictionary:
	var a := 0
	var k := 0
	var homeless := 0
	var sick := 0
	for c in citizens.values():
		if c.is_adult():
			a += 1
		else:
			k += 1
		if c.home < 0:
			homeless += 1
		if c.sick:
			sick += 1
	return {"total": a + k, "adults": a, "children": k, "homeless": homeless, "sick": sick}


func profession_counts() -> Dictionary:
	var out := {}
	for c in citizens.values():
		var n := job_name(c)
		out[n] = out.get(n, 0) + 1
	return out
