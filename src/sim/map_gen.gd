class_name MapGen
extends RefCounted
## Builds a valley from a seed: mountains at the rim, a river with fords, a lake,
## forests, loose boulders, and stone and iron ground to build quarries and mines on.

const START_CLEAR := 9


static func generate(w: World) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = w.map_seed
	var n := w.width * w.height
	w.terrain.resize(n)
	w.feature.resize(n)
	w.growth.resize(n)
	w.fert.resize(n)
	w.road.resize(n)
	w.mark.resize(n)
	w.occ.resize(n)
	w.terrain.fill(Defs.Terrain.GRASS)
	w.feature.fill(Defs.Feature.NONE)
	w.growth.fill(0.0)
	w.road.fill(0)
	w.mark.fill(0)
	w.occ.fill(-1)

	var elev := _noise(rng.randi(), 0.035, 4)
	var lake := _noise(rng.randi(), 0.05, 2)
	var forest := _noise(rng.randi(), 0.045, 3)
	var fert := _noise(rng.randi(), 0.06, 2)
	var c := Vector2(w.width, w.height) * 0.5
	var maxd := c.length()

	for y in w.height:
		for x in w.width:
			var i := y * w.width + x
			var d := Vector2(x, y).distance_to(c) / maxd
			var e := elev.get_noise_2d(x, y) * 0.5 + 0.5 + pow(d, 2.2) * 0.9
			var cd := Vector2(x, y).distance_to(c)
			if e > 0.86 and cd > 14:
				w.terrain[i] = Defs.Terrain.ROCK
			elif lake.get_noise_2d(x, y) > 0.38 and cd > 16:
				w.terrain[i] = Defs.Terrain.WATER
			w.fert[i] = clampf(0.8 + fert.get_noise_2d(x, y) * 0.6, 0.4, 1.25)

	_river(w, rng)

	for y in w.height:
		for x in w.width:
			var i := y * w.width + x
			if w.terrain[i] != Defs.Terrain.GRASS:
				continue
			var f := forest.get_noise_2d(x, y)
			if f > 0.05 and rng.randf() < 0.85:
				w.feature[i] = Defs.Feature.TREE
				w.growth[i] = rng.randf_range(0.5, 1.0) if rng.randf() < 0.9 else rng.randf_range(0.0, 0.5)
			elif f > -0.15 and rng.randf() < 0.12:
				w.feature[i] = Defs.Feature.TREE
				w.growth[i] = rng.randf_range(0.3, 1.0)
			elif rng.randf() < 0.006:
				w.feature[i] = Defs.Feature.BOULDER

	# a clear meadow to start in
	var ci := Vector2i(c)
	for y in range(-START_CLEAR, START_CLEAR + 1):
		for x in range(-START_CLEAR, START_CLEAR + 1):
			var t := ci + Vector2i(x, y)
			if not w.in_bounds(t) or Vector2(x, y).length() > START_CLEAR:
				continue
			var i := w.idx(t)
			w.terrain[i] = Defs.Terrain.GRASS
			w.feature[i] = Defs.Feature.NONE

	var reach := _reachable(w, ci)
	_deposits(w, rng, reach, ci, Defs.Feature.STONE_DEP, 3, 3.2, Vector2(14, 34))
	_deposits(w, rng, reach, ci, Defs.Feature.IRON_DEP, 2, 2.6, Vector2(18, 40))


static func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.seed = s
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = freq
	nz.fractal_octaves = octaves
	return nz


static func _river(w: World, rng: RandomNumberGenerator) -> void:
	var vertical := rng.randf() < 0.5
	var span := w.height if vertical else w.width
	var cross := w.width if vertical else w.height
	var side := 1 if rng.randf() < 0.5 else -1
	var off := float(cross) * 0.5 + side * rng.randf_range(16, 24)
	var wobble := _noise(rng.randi(), 0.04, 2)
	var fords := [int(span * 0.25), int(span * 0.5), int(span * 0.75)]
	for s in span:
		var mid := off + wobble.get_noise_1d(s) * 10.0
		for k in range(-1, 1):
			var t := Vector2i(int(mid) + k, s) if vertical else Vector2i(s, int(mid) + k)
			if not w.in_bounds(t):
				continue
			var ford := false
			for f in fords:
				if absi(s - f) <= 1:
					ford = true
			w.terrain[w.idx(t)] = Defs.Terrain.FORD if ford else Defs.Terrain.WATER


static func _reachable(w: World, from: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w.width * w.height)
	var q: Array[Vector2i] = [from]
	seen[w.idx(from)] = 1
	while not q.is_empty():
		var t: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nt: Vector2i = t + d
			if not w.in_bounds(nt):
				continue
			var i := w.idx(nt)
			if seen[i] or w.terrain[i] == Defs.Terrain.WATER or w.terrain[i] == Defs.Terrain.ROCK:
				continue
			seen[i] = 1
			q.append(nt)
	return seen


static func _deposits(w: World, rng: RandomNumberGenerator, reach: PackedByteArray, start: Vector2i,
		feat: int, count: int, radius: float, dist: Vector2) -> void:
	# prefer spots at the foot of the mountains, all reachable from the start
	var spots: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for y in range(4, w.height - 4):
		for x in range(4, w.width - 4):
			var t := Vector2i(x, y)
			var d := Vector2(t).distance_to(Vector2(start))
			if d < dist.x or d > dist.y or not reach[w.idx(t)]:
				continue
			fallback.append(t)
			if _near_rock(w, t, 4):
				spots.append(t)
	if spots.is_empty():
		spots = fallback
	var placed: Array[Vector2i] = []
	var tries := 0
	while placed.size() < count and tries < 400 and not spots.is_empty():
		tries += 1
		var t: Vector2i = spots[rng.randi() % spots.size()]
		var ok := true
		for p in placed:
			if Vector2(p).distance_to(Vector2(t)) < 18:
				ok = false
		if not ok:
			continue
		placed.append(t)
		var r := int(ceil(radius))
		for y in range(-r - 1, r + 2):
			for x in range(-r - 1, r + 2):
				var p := t + Vector2i(x, y)
				if not w.in_bounds(p) or not reach[w.idx(p)]:
					continue
				if Vector2(x, y).length() <= radius + rng.randf_range(-0.4, 0.6):
					var i := w.idx(p)
					if w.terrain[i] == Defs.Terrain.GRASS:
						w.feature[i] = feat
						w.growth[i] = 0.0


static func _near_rock(w: World, t: Vector2i, r: int) -> bool:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := t + Vector2i(x, y)
			if w.in_bounds(p) and w.terrain[w.idx(p)] == Defs.Terrain.ROCK:
				return true
	return false
