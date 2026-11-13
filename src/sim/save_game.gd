class_name SaveGame
extends RefCounted
## World <-> JSON. Tile layers are stored as base64 bytes; the pathfinding grid and the
## building-occupancy layer are rebuilt on load rather than saved.

const VERSION := 1
const PATH := "user://hearthstead_save.json"


static func to_dict(w: World) -> Dictionary:
	var bs: Array = []
	for b in w.buildings.values():
		bs.append(b.to_dict())
	var cs: Array = []
	for c in w.citizens.values():
		cs.append(c.to_dict())
	return {
		"version": VERSION, "seed": w.map_seed, "difficulty": w.difficulty, "width": w.width, "height": w.height,
		"tick": w.tick, "rng": str(w.rng.state), "next_id": w.next_id, "builders": w.builders_wanted,
		"terrain": Marshalls.raw_to_base64(w.terrain), "feature": Marshalls.raw_to_base64(w.feature),
		"growth": Marshalls.raw_to_base64(w.growth.to_byte_array()),
		"fert": Marshalls.raw_to_base64(w.fert.to_byte_array()),
		"road": Marshalls.raw_to_base64(w.road), "mark": Marshalls.raw_to_base64(w.mark),
		"buildings": bs, "citizens": cs, "merchant": w.merchant, "pending_nomads": w.pending_nomads,
		"log": w.events_log, "era": w.era, "techs": w.techs.keys(), "researching": w.researching,
		"research": w.research, "knowledge": w.knowledge, "winters": w.winters,
		"traded": w.traded, "climate": w.climate, "climate_peak": w.climate_peak, "ending": w.ending,
		"era_ticks": w.era_ticks, "peak_pop": w.peak_pop, "history": w.history, "born": w.born_total, "died": w.died_total,
	}


static func from_dict(d: Dictionary) -> World:
	var w := World.new()
	w.map_seed = int(d.seed)
	w.difficulty = int(d.difficulty)
	w.width = int(d.width)
	w.height = int(d.height)
	w.tick = int(d.tick)
	w.rng.state = int(str(d.rng))
	w.next_id = int(d.next_id)
	w.builders_wanted = int(d.builders)
	w.terrain = Marshalls.base64_to_raw(d.terrain)
	w.feature = Marshalls.base64_to_raw(d.feature)
	w.growth = Marshalls.base64_to_raw(d.growth).to_float32_array()
	w.fert = Marshalls.base64_to_raw(d.fert).to_float32_array()
	w.road = Marshalls.base64_to_raw(d.road)
	w.mark = Marshalls.base64_to_raw(d.mark)
	w.occ.resize(w.width * w.height)
	w.occ.fill(-1)
	for bd in d.buildings:
		var b := Building.from_dict(bd)
		w.buildings[b.id] = b
		for y in b.size.y:
			for x in b.size.x:
				w.occ[w.idx(b.pos + Vector2i(x, y))] = b.id
		if b.kind() == "storage":
			for k in b.inv:
				w.totals[k] = w.totals.get(k, 0) + b.inv[k]
	for cd in d.citizens:
		var c := Citizen.from_dict(cd)
		w.citizens[c.id] = c
	w.merchant = d.merchant
	if not w.merchant.is_empty():
		w.merchant.until = int(w.merchant.until)
		w.merchant.post = int(w.merchant.post)
		var g := {}
		for k in w.merchant.goods:
			g[k] = int(w.merchant.goods[k])
		w.merchant.goods = g
	w.pending_nomads = int(d.pending_nomads)
	w.events_log = d.log.map(func(e): return {"tick": int(e.tick), "text": e.text, "kind": e.kind})
	w.history = d.history.map(func(h):
		var o := {}
		for k in h:
			o[k] = int(h[k])
		return o)
	w.era = int(d.get("era", 0))
	for t in d.get("techs", []):
		w.techs[t] = true
	w.researching = d.get("researching", "")
	for k in d.get("research", {}):
		w.research[k] = float(d.research[k])
	w.knowledge = float(d.get("knowledge", 0.0))
	w.winters = int(d.get("winters", 0))
	w.traded = int(d.get("traded", 0))
	w.climate = float(d.get("climate", 0.0))
	w.climate_peak = float(d.get("climate_peak", 0.0))
	w.ending = d.get("ending", "")
	w.era_ticks = d.get("era_ticks", [0]).map(func(t): return int(t))
	w.peak_pop = int(d.get("peak_pop", 0))
	w.count_trees()
	if not d.has("era"):
		# a town saved before progression: keep the techs for what it already built
		for b in w.buildings.values():
			var t := Progress.tech_for(b.type)
			if t != "":
				w.techs[t] = true
		w.winters = Defs.year_of(w.tick) - 1
	w._recompute_mods()
	w.born_total = int(d.born)
	w.died_total = int(d.died)
	for i in w.mark.size():
		if w.mark[i]:
			w.marked[i] = true
	w.rebuild_doors()
	w._setup_astar()
	return w


static func save(w: World, path := PATH) -> bool:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(w)))
	f.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func load_world(path := PATH) -> World:
	if not FileAccess.file_exists(path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != VERSION:
		return null
	return from_dict(d)


static func exists(path := PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
