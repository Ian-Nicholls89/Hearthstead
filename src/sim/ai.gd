class_name AI
extends RefCounted
## What each person does. Needs come first (eat, keep warm, tools, coats, stock the
## home), then their job, then labouring. A decision becomes a short plan of
## "go" and "do" steps; if any step fails the plan is dropped and they decide again.


static func update(w: World, c: Citizen) -> void:
	_needs(w, c)
	if not w.citizens.has(c.id):
		return
	if c.plan.is_empty():
		if c.wait > 0:
			c.wait -= 1
			return
		decide(w, c)
		if c.plan.is_empty():
			c.wait = 20 + w.rng.randi() % 20
			c.doing = "Idle"
		else:
			for s in c.plan:
				if s.t == "do":
					c.doing = s.label
					break
		return
	_run(w, c)


# --- needs ------------------------------------------------------------------

static func _needs(w: World, c: Citizen) -> void:
	c.full = maxf(0.0, c.full - Defs.FULL_DECAY * (1.0 if c.is_adult() else 0.6))
	var temp := w.temperature()
	var warming: bool = not c.plan.is_empty() and c.plan[0].t == "do" and c.plan[0].fx == "warm" and c.act_left >= 0
	if temp < Defs.COLD_BELOW:
		if not warming:
			var drain := Defs.WARMTH_DRAIN * (Defs.COLD_BELOW - temp) / 8.0
			if c.coat > 0.0:
				drain *= Defs.COAT_FACTOR
				c.coat = maxf(0.0, c.coat - Defs.COAT_WEAR)
			c.warmth = maxf(0.0, c.warmth - drain)
	else:
		c.warmth = minf(1.0, c.warmth + 0.003)
	if c.full <= 0.0:
		c.health -= Defs.STARVE_HURT
	if c.warmth <= 0.0:
		c.health -= Defs.FREEZE_HURT
	if c.sick:
		c.health -= Defs.SICK_HURT
	if c.full > 0.15 and c.warmth > 0.15 and not c.sick:
		c.health = minf(1.0, c.health + Defs.HEAL_RATE * (1.0 + 0.25 * mini(w.variety(c), 4)))
	if c.health <= 0.0:
		var why := "died of illness"
		if c.full <= 0.0:
			why = "starved to death"
		elif c.warmth <= 0.0:
			why = "froze to death"
		w.kill(c, why)


static func work_speed(w: World, c: Citizen) -> float:
	var s := 1.0 if c.tool > 0.0 else Defs.NO_TOOL_SPEED
	if c.sick:
		s *= 0.5
	if c.age > Defs.OLD_AGE:
		s *= 0.7
	if c.pregnant > 0:
		s *= 0.85
	return s * (0.8 + 0.4 * c.happy)


static func walk_speed(w: World, c: Citizen) -> float:
	var t := c.tile()
	var s := Defs.WALK_SPEED
	if w.in_bounds(t):
		var i := w.idx(t)
		if w.road[i]:
			s *= Defs.ROAD_SPEED_MUL
		elif w.terrain[i] == Defs.Terrain.FORD:
			s *= Defs.FORD_SPEED_MUL
		elif w.feature[i] == Defs.Feature.TREE and w.growth[i] > 0.3:
			s *= Defs.FOREST_SPEED_MUL
	if not c.is_adult() or c.age > Defs.OLD_AGE:
		s *= 0.8
	if c.carrying() > 0:
		s *= 0.9
	return s


# --- running a plan ---------------------------------------------------------

static func _run(w: World, c: Citizen) -> void:
	var s: Dictionary = c.plan[0]
	if s.t == "go":
		if c.act_left < 0:
			c.path = w.find_path(c.tile(), s.to)
			if c.path.is_empty() and c.tile() != s.to:
				abort(w, c)
				c.wait = 15
				return
			if not c.path.is_empty() and c.path[0] == c.tile():
				c.path.pop_front()
			c.act_left = 1
		if c.path.is_empty():
			c.plan.pop_front()
			c.act_left = -1
			return
		var nxt: Vector2i = c.path[0]
		var target := Vector2(nxt) + Vector2(0.5, 0.5)
		var sp := walk_speed(w, c)
		var d := c.pos.distance_to(target)
		if d <= sp:
			c.pos = target
			c.path.pop_front()
			if not c.path.is_empty() and not w.passable(c.path[0]):
				c.act_left = -1   # something was built in the way: find a new route
		else:
			c.pos += (target - c.pos) / d * sp
		return
	# a "do" step
	if c.act_left < 0:
		c.act_left = float(s.n)
		c.doing = s.get("label", c.doing)
		if s.fx == "warm" and c.warmth >= float(s.cap):
			c.plan.pop_front()
			c.act_left = -1
			return
	if s.fx == "warm":
		c.warmth = minf(float(s.cap), c.warmth + Defs.WARM_RATE)
		c.act_left -= 1
		if c.warmth >= float(s.cap) or c.act_left <= 0:
			c.plan.pop_front()
			c.act_left = -1
		return
	c.act_left -= work_speed(w, c) if s.get("work", false) else 1.0
	if c.act_left > 0:
		return
	c.act_left = -1
	c.plan.pop_front()
	if not _effect(w, c, s):
		abort(w, c)


## Drop the plan and give back anything reserved for it.
static func abort(w: World, c: Citizen) -> void:
	for s in c.plan:
		if s.has("fb"):
			var fb: Building = w.buildings.get(s.fb)
			if fb and s.fi < fb.field_busy.size():
				fb.field_busy[s.fi] = 0
	c.plan.clear()
	c.path.clear()
	c.act_left = -1
	if c.res_tile >= 0:
		if w.reserved.get(c.res_tile, -1) == c.id:
			w.reserved.erase(c.res_tile)
		c.res_tile = -1
	if c.res_haul >= 0:
		var b: Building = w.buildings.get(c.res_haul)
		if b:
			b.haul_reserved = maxi(0, b.haul_reserved - c.res_haul_n)
		c.res_haul = -1
		c.res_haul_n = 0
	if c.res_site >= 0:
		var b: Building = w.buildings.get(c.res_site)
		if b:
			b.incoming[c.res_site_res] = maxi(0, b.incoming.get(c.res_site_res, 0) - c.res_site_n)
		c.res_site = -1
		c.res_site_n = 0
	for h in w.restockers.keys():
		if w.restockers[h] == c.id:
			w.restockers.erase(h)


static func _food_in(inv: Dictionary) -> int:
	var n := 0
	for f in Defs.FOODS:
		n += inv.get(f, 0)
	return n


static func _add_carry(c: Citizen, res: String, n: int, w: World = null) -> void:
	if n > 0:
		c.carry[res] = c.carry.get(res, 0) + n
		if w:
			w.count_made(res, n)


static func _wear_tool(c: Citizen) -> void:
	if c.tool > 0.0:
		c.tool = maxf(0.0, c.tool - Defs.TOOL_WEAR)


static func _eat(w: World, c: Citizen, from: Building, store: bool) -> bool:
	var meal := Defs.MEAL_ADULT if c.is_adult() else Defs.MEAL_CHILD
	var now := w.abs_month()
	# eat what they have gone longest without
	var kinds: Array = Defs.FOODS.filter(func(f): return from.inv.get(f, 0) > 0)
	kinds.sort_custom(func(a, b): return c.diet.get(a, -99) < c.diet.get(b, -99))
	var got := 0
	for f in kinds:
		var want := meal - got
		if want <= 0:
			break
		var n: int
		if store:
			n = w.store_take(from, f, want)
		else:
			n = mini(want, from.inv[f])
			from.inv[f] -= n
			if from.inv[f] == 0:
				from.inv.erase(f)
		if n > 0:
			got += n
			c.diet[f] = now
	if got == 0:
		return false
	c.full = minf(1.0, c.full + float(got) / meal)
	return true


static func _effect(w: World, c: Citizen, s: Dictionary) -> bool:
	var b: Building = w.buildings.get(s.get("b", -1))
	match s.fx:
		"take":
			if b == null:
				return false
			var n := w.store_take(b, s.res, int(s.n))
			_add_carry(c, s.res, n)
			if n == 0 and c.res_site >= 0:
				return false
			return n > 0
		"take_food":
			if b == null:
				return false
			var kinds: Array = Defs.FOODS.filter(func(f): return b.inv.get(f, 0) > 0)
			kinds.sort_custom(func(a, x): return b.inv[a] > b.inv[x])
			kinds = kinds.slice(0, 4)
			var left := int(s.n)
			for i in kinds.size():
				var share := int(ceil(float(left) / (kinds.size() - i)))
				var n := w.store_take(b, kinds[i], share)
				_add_carry(c, kinds[i], n)
				left -= n
			return c.carrying() > 0
		"put_store":
			if b == null:
				return false
			for k in c.carry.keys():
				var n := w.store_add(b, k, c.carry[k])
				c.carry[k] -= n
				if c.carry[k] <= 0:
					c.carry.erase(k)
			return true
		"put_home":
			w.restockers.erase(s.get("b", -1))
			if b == null:
				return false
			for k in c.carry.keys():
				b.inv[k] = b.inv.get(k, 0) + c.carry[k]
			c.carry.clear()
			if b.inv.get("firewood", 0) > 0:
				b.warm = true
			return true
		"put_site":
			if b == null:
				return false
			for k in c.carry.keys():
				var used := mini(c.carry[k], b.needed.get(k, 0))
				if b.needed.has(k):
					b.needed[k] -= used
				c.carry[k] -= used
				if c.carry[k] <= 0:
					c.carry.erase(k)
			b.incoming[c.res_site_res] = maxi(0, b.incoming.get(c.res_site_res, 0) - c.res_site_n)
			c.res_site = -1
			c.res_site_n = 0
			_maybe_finish(w, b)
			return true
		"put_input":
			if b == null:
				return false
			for k in c.carry:
				b.input[k] = b.input.get(k, 0) + c.carry[k]
			c.carry.clear()
			return true
		"put_buffer":
			if b == null:
				return false
			for k in c.carry:
				b.inv[k] = b.inv.get(k, 0) + c.carry[k]
			c.carry.clear()
			return true
		"take_buffer":
			if b == null:
				return false
			var want := c.res_haul_n
			b.haul_reserved = maxi(0, b.haul_reserved - c.res_haul_n)
			c.res_haul = -1
			c.res_haul_n = 0
			var keys := b.inv.keys()
			keys.sort_custom(func(a, x): return b.inv[a] > b.inv[x])
			for k in keys:
				if want <= 0:
					break
				var n := mini(want, b.inv[k])
				b.inv[k] -= n
				if b.inv[k] <= 0:
					b.inv.erase(k)
				_add_carry(c, k, n)
				want -= n
			return c.carrying() > 0
		"eat_home":
			return b != null and _eat(w, c, b, false)
		"eat_store":
			return b != null and _eat(w, c, b, true)
		"gather":
			_release_tile(w, c)
			if b == null:
				return false
			var d: Dictionary = b.def()
			var keys: Array = d.yield.keys()
			var res: String = keys[w.rng.randi() % keys.size()]
			var amount := float(d.yield[res]) * Defs.gather_season_mul(w.month(), res)
			if b.type in ["gatherer", "herbalist", "hunter"]:
				amount *= 0.4 + 0.6 * b.forest
			if b.type == "hunter":
				amount *= maxf(0.2, b.game)
				b.game = maxf(0.0, b.game - 0.03)
			var n := int(amount) + (1 if w.rng.randf() < fmod(amount, 1.0) else 0)
			_add_carry(c, res, n, w)
			for k in d.get("extra", {}):
				if w.rng.randf() < 0.75:
					_add_carry(c, k, int(d.extra[k]), w)
			_wear_tool(c)
			return true
		"chop":
			_release_tile(w, c)
			var t: Vector2i = s.tile
			var i := w.idx(t)
			if not w.is_tree(i, Defs.TREE_GROWN):
				return false
			_add_carry(c, "logs", int(b.def().yield.logs) if b else 5, w)
			w.set_tree(t, 0.02)   # the forester replants as they go
			_wear_tool(c)
			return true
		"plant":
			_release_tile(w, c)
			var t: Vector2i = s.tile
			var i := w.idx(t)
			if w.feature[i] != Defs.Feature.NONE or w.occ[i] >= 0 or w.road[i]:
				return true
			w.set_tree(t, 0.02)
			return true
		"clear":
			_release_tile(w, c)
			var t: Vector2i = s.tile
			var i := w.idx(t)
			var f := w.feature[i]
			if not w.mark[i] or not Defs.CLEAR_YIELD.has(f):
				w.mark[i] = 0
				w.marked.erase(i)
				return true
			var yields: Dictionary = Defs.CLEAR_YIELD[f]
			for k in yields:
				var n: int = yields[k]
				if f == Defs.Feature.TREE and w.growth[i] < Defs.TREE_GROWN:
					n = 1
				_add_carry(c, k, n, w)
			w.clear_feature(t)
			_wear_tool(c)
			return true
		"extract":
			if b == null:
				return false
			var d: Dictionary = b.def()
			for k in d.yield:
				b.inv[k] = b.inv.get(k, 0) + int(d.yield[k])
				w.count_made(k, int(d.yield[k]))
			for k in d.get("extra", {}):
				if w.rng.randf() < float(d.extra[k]):
					b.inv[k] = b.inv.get(k, 0) + 1
					w.count_made(k, 1)
			_wear_tool(c)
			return true
		"process":
			if b == null:
				return false
			var d: Dictionary = b.def()
			for k in d.input:
				if b.input.get(k, 0) < int(d.input[k]):
					return false
			for k in d.input:
				b.input[k] -= int(d.input[k])
			for k in d.output:
				b.inv[k] = b.inv.get(k, 0) + int(d.output[k])
				w.count_made(k, int(d.output[k]))
			_wear_tool(c)
			return true
		"plant_field":
			if b == null:
				return false
			b.field_busy[s.fi] = 0
			if b.field[s.fi] < 0.0 and w.month() in Defs.PLANT_MONTHS:
				b.field[s.fi] = 0.0
			_wear_tool(c)
			return true
		"harvest":
			if b == null:
				return false
			b.field_busy[s.fi] = 0
			if b.field[s.fi] >= 1.0:
				var t := w.field_tile(b, s.fi)
				var amount := Defs.FIELD_YIELD * w.fert[w.idx(t)]
				b.inv[b.crop] = b.inv.get(b.crop, 0) + int(round(amount))
				w.count_made(b.crop, int(round(amount)))
				b.field[s.fi] = -1.0
			_wear_tool(c)
			return true
		"build":
			if b == null or b.built:
				return b != null
			b.progress = minf(b.work, b.progress + float(s.n))
			_wear_tool(c)
			_maybe_finish(w, b)
			return true
		"fetch_tool":
			if b and w.store_take(b, "tools", 1) == 1:
				c.tool = 1.0
				return true
			return false
		"fetch_coat":
			if b and w.store_take(b, "coats", 1) == 1:
				c.coat = 1.0
				return true
			return false
		"warm_camp":
			if b and w.store_take(b, "firewood", 1) == 1:
				return true
			return false
		"arrive":
			c.arriving = false
			return true
		"idle":
			return true
	return true


static func _maybe_finish(w: World, b: Building) -> void:
	if not b.built and b.progress >= b.work and b.materials_ready():
		w._finish(b)


static func _release_tile(w: World, c: Citizen) -> void:
	if c.res_tile >= 0:
		if w.reserved.get(c.res_tile, -1) == c.id:
			w.reserved.erase(c.res_tile)
		c.res_tile = -1


# --- deciding ---------------------------------------------------------------

static func _go(to: Vector2i) -> Dictionary:
	return {"t": "go", "to": to}


static func _do(fx: String, n: float, label: String, extra := {}) -> Dictionary:
	var s := {"t": "do", "fx": fx, "n": n, "label": label}
	s.merge(extra)
	return s


static func decide(w: World, c: Citizen) -> void:
	c.plan.clear()
	if c.arriving:
		var camp := _camp(w)
		var dest: Vector2i = camp.door if camp else Vector2i(w.width / 2, w.height / 2)
		c.plan = [_go(dest), _do("arrive", 1, "Arriving")]
		c.doing = "Arriving"
		return
	if c.carrying() > 0 and _plan_store(w, c):
		return
	if c.full < Defs.EAT_BELOW and _plan_eat(w, c):
		return
	var cold := w.temperature() < Defs.COLD_BELOW
	if cold and c.warmth < Defs.WARM_BELOW and _plan_warm(w, c):
		return
	if not c.is_adult():
		_plan_play(w, c)
		return
	if c.tool <= 0.0 and w.stock("tools") > 0 and _plan_fetch(w, c, "tools", "fetch_tool", "Fetching a tool"):
		return
	var autumn := w.month() >= 6 or cold
	if c.coat <= 0.0 and autumn and w.stock("coats") > 0 and _plan_fetch(w, c, "coats", "fetch_coat", "Fetching a coat"):
		return
	if _plan_restock(w, c):
		return
	if c.job == Citizen.BUILDER:
		if _plan_build(w, c) or _plan_labour(w, c):
			return
	elif c.job >= 0 and w.buildings.has(c.job):
		if _plan_work(w, c, w.buildings[c.job]):
			return
		if _plan_labour(w, c):
			return
	elif _plan_labour(w, c):
		return
	_plan_idle(w, c)


static func _camp(w: World) -> Building:
	for b in w.buildings.values():
		if b.type == "camp":
			return b
	return null


static func _plan_store(w: World, c: Citizen) -> bool:
	var main := ""
	var most := 0
	for k in c.carry:
		if c.carry[k] > most:
			most = c.carry[k]
			main = k
	var s := w.find_storage_space(main, c.tile())
	if s == null:
		return false
	c.plan = [_go(s.door), _do("put_store", 8, "Storing " + Defs.RES[main].name.to_lower(), {"b": s.id})]
	return true


static func _plan_eat(w: World, c: Citizen) -> bool:
	var h: Building = w.buildings.get(c.home)
	if h and _food_in(h.inv) > 0:
		c.plan = [_go(h.door), _do("eat_home", 20, "Eating at home", {"b": h.id})]
		return true
	var s := w.find_storage_with("", c.tile(), true)
	if s:
		c.plan = [_go(s.door), _do("eat_store", 20, "Eating from the store", {"b": s.id})]
		return true
	return false


static func _plan_warm(w: World, c: Citizen) -> bool:
	var h: Building = w.buildings.get(c.home)
	if h and (h.inv.get("firewood", 0) > 0 or h.warm):
		c.plan = [_go(h.door), _do("warm", 80, "Warming up at home", {"b": h.id, "cap": 1.0})]
		return true
	var camp := _camp(w)
	if camp and camp.inv.get("firewood", 0) > 0:
		c.plan = [_go(camp.door), _do("warm_camp", 2, "Lighting a fire", {"b": camp.id}),
			_do("warm", 80, "Huddling by the camp fire", {"b": camp.id, "cap": Defs.SHELTER_MAX_WARMTH})]
		return true
	return false


static func _plan_play(w: World, c: Citizen) -> void:
	var h: Building = w.buildings.get(c.home)
	var base: Vector2i = h.door if h else c.tile()
	var t := w.nearest_passable(base + Vector2i(w.rng.randi_range(-4, 4), w.rng.randi_range(-4, 4)))
	c.plan = [_go(t), _do("idle", w.rng.randi_range(40, 90), "Playing")]


static func _plan_idle(w: World, c: Citizen) -> void:
	var h: Building = w.buildings.get(c.home)
	var base: Vector2i = h.door if h else c.tile()
	var t := w.nearest_passable(base + Vector2i(w.rng.randi_range(-3, 3), w.rng.randi_range(-3, 3)))
	c.plan = [_go(t), _do("idle", w.rng.randi_range(30, 60), "Idle")]


static func _plan_fetch(w: World, c: Citizen, res: String, fx: String, label: String) -> bool:
	var s := w.find_storage_with(res, c.tile())
	if s == null:
		return false
	c.plan = [_go(s.door), _do(fx, 10, label, {"b": s.id})]
	return true


static func _plan_restock(w: World, c: Citizen) -> bool:
	var h: Building = w.buildings.get(c.home)
	if h == null or w.restockers.has(h.id):
		return false
	var plan: Array = []
	var food := _food_in(h.inv)
	var wood: int = h.inv.get("firewood", 0)
	var cold_soon := w.month() >= 7 or w.temperature() < Defs.COLD_BELOW
	if food < Defs.HOME_FOOD_LOW and w.food_total() > 0:
		var s := w.find_storage_with("", h.door, true)
		if s:
			plan = [_go(s.door), _do("take_food", 8, "Fetching food for home", {"b": s.id, "n": mini(15, Defs.HOME_FOOD_MAX - food)})]
	elif wood < (Defs.HOME_WOOD_MAX / 2 if cold_soon else Defs.HOME_WOOD_LOW) and w.stock("firewood") > 0:
		var s := w.find_storage_with("firewood", h.door)
		if s:
			plan = [_go(s.door), _do("take", 8, "Fetching firewood", {"b": s.id, "res": "firewood", "n": mini(Defs.CARRY, Defs.HOME_WOOD_MAX - wood)})]
	elif h.inv.get("herbs", 0) < 1 and w.stock("herbs") > 0:
		var s := w.find_storage_with("herbs", h.door)
		if s:
			plan = [_go(s.door), _do("take", 8, "Fetching herbs", {"b": s.id, "res": "herbs", "n": 2})]
	if plan.is_empty():
		return false
	plan.append(_go(h.door))
	plan.append(_do("put_home", 8, "Stocking the house", {"b": h.id}))
	w.restockers[h.id] = c.id
	c.plan = plan
	return true


static func _plan_haul(w: World, c: Citizen, b: Building) -> bool:
	var n := mini(Defs.CARRY, b.stock_total() - b.haul_reserved)
	if n <= 0:
		return false
	b.haul_reserved += n
	c.res_haul = b.id
	c.res_haul_n = n
	c.plan = [_go(b.door), _do("take_buffer", 8, "Collecting from the " + b.title().to_lower(), {"b": b.id})]
	return true


static func _plan_build(w: World, c: Citizen) -> bool:
	var sites := w.sites()
	sites.sort_custom(func(a, b): return a.id < b.id)
	for b in sites:
		if b.materials_ready() and b.progress < b.work:
			c.plan = [_go(b.door), _do("build", 40, "Building the " + b.title().to_lower(), {"b": b.id, "work": true})]
			return true
		if _plan_deliver(w, c, b):
			return true
	return false


static func _plan_deliver(w: World, c: Citizen, b: Building) -> bool:
	for k in b.needed:
		var short: int = b.needed[k] - b.incoming.get(k, 0)
		if short <= 0 or w.stock(k) <= 0:
			continue
		var s := w.find_storage_with(k, b.door)
		if s == null:
			continue
		var n := mini(mini(Defs.CARRY, short), s.inv.get(k, 0))
		b.incoming[k] = b.incoming.get(k, 0) + n
		c.res_site = b.id
		c.res_site_res = k
		c.res_site_n = n
		c.plan = [_go(s.door), _do("take", 8, "Fetching " + Defs.RES[k].name.to_lower(), {"b": s.id, "res": k, "n": n}),
			_go(b.door), _do("put_site", 8, "Delivering to the " + b.title().to_lower(), {"b": b.id})]
		return true
	return false


static func _plan_labour(w: World, c: Citizen) -> bool:
	# 1. haul full workplaces
	var best: Building = null
	var bd := INF
	for b in w.buildings.values():
		if not b.built or b.kind() in ["storage", "house", "decor", "hall", "trade", "road"]:
			continue
		if b.stock_total() - b.haul_reserved < Defs.HAUL_AT:
			continue
		var d := c.pos.distance_squared_to(Vector2(b.door))
		if d < bd:
			bd = d
			best = b
	if best and _plan_haul(w, c, best):
		return true
	# 2. carry materials to building sites
	var sites := w.sites()
	sites.sort_custom(func(a, b): return a.id < b.id)
	for b in sites:
		if _plan_deliver(w, c, b):
			return true
	# 3. lend a hand on building sites that have their materials
	for b in sites:
		if b.materials_ready() and b.progress < b.work:
			c.plan = [_go(b.door), _do("build", 40, "Helping build the " + b.title().to_lower(), {"b": b.id, "work": true})]
			return true
	# 4. clear marked trees and rocks
	var t := _nearest_mark(w, c)
	if t.x >= 0:
		var i := w.idx(t)
		w.reserved[i] = c.id
		c.res_tile = i
		var f := w.feature[i]
		c.plan = [_go(t), _do("clear", Defs.CLEAR_TICKS.get(f, 60), "Clearing", {"tile": t, "work": true})]
		return true
	return false


static func _nearest_mark(w: World, c: Citizen) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for i in w.marked:
		if w.reserved.has(i):
			continue
		var t := w.tile_of(i)
		var d := c.pos.distance_squared_to(Vector2(t))
		if d < bd:
			bd = d
			best = t
	return best


static func _plan_work(w: World, c: Citizen, b: Building) -> bool:
	var d: Dictionary = b.def()
	match b.kind():
		"gather":
			if b.stock_total() - b.haul_reserved >= Defs.HAUL_AT:
				return _plan_haul(w, c, b)
			return _plan_trip(w, c, b)
		"extract":
			if b.stock_total() - b.haul_reserved >= Defs.HAUL_AT:
				return _plan_haul(w, c, b)
			c.plan = [_go(b.door), _do("extract", d.time, "Working the " + b.title().to_lower(), {"b": b.id, "work": true})]
			return true
		"process":
			if b.stock_total() - b.haul_reserved >= Defs.HAUL_AT:
				return _plan_haul(w, c, b)
			var ready := true
			for k in d.input:
				if b.input.get(k, 0) < int(d.input[k]):
					ready = false
			if ready:
				c.plan = [_go(b.door), _do("process", d.time, "Working at the " + b.title().to_lower(), {"b": b.id, "work": true})]
				return true
			for k in d.input:
				if b.input.get(k, 0) >= int(d.input[k]):
					continue
				var s := w.find_storage_with(k, b.door)
				if s:
					c.plan = [_go(s.door), _do("take", 8, "Fetching " + Defs.RES[k].name.to_lower(), {"b": s.id, "res": k, "n": int(d.input[k]) * Defs.CARRY}),
						_go(b.door), _do("put_input", 6, "Unloading", {"b": b.id})]
					return true
			return false
		"field":
			if b.stock_total() - b.haul_reserved >= Defs.HAUL_AT:
				return _plan_haul(w, c, b)
			return _plan_farm(w, c, b)
		"trade":
			c.plan = [_go(b.door), _do("idle", 100, "Minding the trading post")]
			return true
	return false


static func _plan_farm(w: World, c: Citizen, b: Building) -> bool:
	var m := w.month()
	var start := w.rng.randi() % b.field.size()
	for k in b.field.size():
		var i := (start + k) % b.field.size()
		if b.field_busy[i]:
			continue
		var fx := ""
		if b.field[i] >= 1.0:
			fx = "harvest"
		elif b.field[i] < 0.0 and m in Defs.PLANT_MONTHS:
			fx = "plant_field"
		if fx == "":
			continue
		b.field_busy[i] = 1
		var n := Defs.FIELD_HARVEST_TICKS if fx == "harvest" else Defs.FIELD_PLANT_TICKS
		var label := "Harvesting " + b.crop if fx == "harvest" else "Planting " + b.crop
		c.plan = [_go(w.field_tile(b, i)), _do(fx, n, label, {"b": b.id, "fi": i, "fb": b.id, "work": true})]
		return true
	# nothing to do in the field: bring in what is lying there
	if b.stock_total() - b.haul_reserved > 0:
		return _plan_haul(w, c, b)
	return false


static func _plan_trip(w: World, c: Citizen, b: Building) -> bool:
	var d: Dictionary = b.def()
	var r: int = d.radius
	var cc := Vector2i(b.center())
	var target := Vector2i(-1, -1)
	var fx := "gather"
	var label := "Gathering"
	match b.type:
		"hunter": label = "Hunting"
		"herbalist": label = "Picking herbs"
		"fisher": label = "Fishing"
		"forester": label = "Felling a tree"
	var best_d := INF
	var found := 0
	for attempt in 40:
		var t := cc + Vector2i(w.rng.randi_range(-r, r), w.rng.randi_range(-r, r))
		if not w.in_bounds(t) or Vector2(t - cc).length() > r:
			continue
		var i := w.idx(t)
		if w.reserved.has(i) or not w.passable(t):
			continue
		var ok := false
		var plant := false
		match b.type:
			"fisher":
				ok = _touches_water(w, t)
			"forester":
				if w.is_tree(i, Defs.TREE_GROWN) and not w.mark[i]:
					ok = true
				elif attempt > 30 and found == 0 and _plantable(w, t):
					ok = true
					plant = true
			_:
				ok = w.is_tree(i, 0.3)
		if not ok:
			continue
		# of a few good spots, go to the nearest
		var dist := Vector2(t).distance_squared_to(Vector2(b.door))
		if dist < best_d:
			best_d = dist
			target = t
			fx = "plant" if plant else "gather"
			if b.type == "forester":
				label = "Planting a tree" if plant else "Felling a tree"
		found += 1
		if found >= 4:
			break
	if target.x < 0:
		return false
	var ti := w.idx(target)
	w.reserved[ti] = c.id
	c.res_tile = ti
	if fx == "plant":
		c.plan = [_go(target), _do("plant", 30, label, {"tile": target, "work": true})]
		return true
	if b.type == "forester":
		fx = "chop"
	c.plan = [_go(target), _do(fx, d.trip, label, {"b": b.id, "tile": target, "work": true}),
		_go(b.door), _do("put_buffer", 6, "Unloading", {"b": b.id})]
	return true


static func _touches_water(w: World, t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = t + d
		if w.in_bounds(p) and w.terrain[w.idx(p)] == Defs.Terrain.WATER:
			return true
	return false


static func _plantable(w: World, t: Vector2i) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var p := t + Vector2i(x, y)
			if not w.in_bounds(p):
				return false
			var i := w.idx(p)
			if w.occ[i] >= 0 or w.road[i] or w.terrain[i] != Defs.Terrain.GRASS:
				return false
	var i := w.idx(t)
	return w.feature[i] == Defs.Feature.NONE
