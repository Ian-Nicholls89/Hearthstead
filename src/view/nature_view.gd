class_name NatureView
extends Node3D
## Trees, bushes, rocks and ground cover from Quaternius's Ultimate Nature pack (CC0),
## drawn per 16x16-tile chunk. Near the camera each chunk shows the detailed models,
## swapped for autumn, snow and bare winter versions; further away it shows the old
## light procedural trees instead. Only chunks whose tiles changed are rebuilt.

const CHUNK := World.CHUNK
const NEAR := 38.0                     # metres from the camera to a chunk's middle
const TREE_SCALE := 0.78
const KINDS := {
	# kind: [summer, autumn, winter] mesh names per variant
	"common": [["CommonTree_1", "CommonTreeAutumn_1", "CommonTreeDeadSnow_1"],
		["CommonTree_2", "CommonTreeAutumn_2", "CommonTreeDeadSnow_2"],
		["CommonTree_3", "CommonTreeAutumn_3", "CommonTreeDeadSnow_3"]],
	"pine": [["PineTree_1", "PineTree_1", "PineTreeSnow_1"], ["PineTree_2", "PineTree_2", "PineTreeSnow_2"],
		["PineTree_3", "PineTree_3", "PineTreeSnow_3"]],
	"birch": [["BirchTree_1", "BirchTreeAutumn_1", "BirchTreeDeadSnow_1"],
		["BirchTree_2", "BirchTreeAutumn_2", "BirchTreeDeadSnow_2"]],
	"bush": [["Bush_1", "Bush_1", "BushSnow_1"], ["Bush_2", "Bush_2", "BushSnow_2"], ["BushBerries_1", "Bush_1", "BushSnow_1"]],
	"rock": [["Rock_1", "Rock_1", "RockSnow_1"], ["Rock_2", "Rock_2", "RockSnow_2"], ["Rock_3", "Rock_3", "RockSnow_3"]],
	"grass": [["Grass", "Grass", ""], ["GrassShort", "GrassShort", ""], ["Flowers", "GrassShort", ""], ["Plant_1", "Plant_1", ""]],
}

var world: World
var mat: ShaderMaterial
var far_mat: ShaderMaterial
var season := 0                         # 0 summer, 1 autumn, 2 winter
var chunks := {}                        # chunk index -> {key -> MultiMeshInstance3D}
var _meshes := {}
var _timer := 0.0


func setup(w: World, leaf_mat: ShaderMaterial) -> void:
	world = w
	mat = Meshes.material().duplicate()
	far_mat = leaf_mat
	season = season_of(world.month())
	var cw := ceili(float(world.width) / CHUNK)
	var ch := ceili(float(world.height) / CHUNK)
	for cy in ch:
		for cx in cw:
			chunks[cy * cw + cx] = {}
			_build(cx, cy)
	world.dirty_chunks.clear()


static func season_of(m: int) -> int:
	if m >= 9 or m == 0:
		return 2
	if m >= 6:
		return 1
	return 0


func mesh(name: String) -> Mesh:
	if name == "":
		return null
	if not _meshes.has(name):
		_meshes[name] = load("res://assets/nature/%s.res" % name)
	return _meshes[name]


func _hash(i: int, salt := 0) -> float:
	var h := ((i + salt * 7919) * 2654435761) & 0xffffffff
	return float(h % 10007) / 10007.0


func tree_kind(i: int) -> Array:
	var h := _hash(i, 3)
	var kind := "common" if h < 0.45 else ("pine" if h < 0.8 else "birch")
	var vs: Array = KINDS[kind]
	return [kind, int(_hash(i, 4) * vs.size()) % vs.size()]


func update_view(delta: float) -> void:
	var s := season_of(world.month())
	if s != season:
		season = s
		for ci in chunks:
			_apply_season(chunks[ci])
	_timer -= delta
	if _timer > 0.0 or world.dirty_chunks.is_empty():
		return
	_timer = 0.3
	var cw := ceili(float(world.width) / CHUNK)
	var todo: Array = world.dirty_chunks.keys()
	world.dirty_chunks.clear()
	for ci in todo:
		_build(ci % cw, ci / cw)


func _apply_season(nodes: Dictionary) -> void:
	for key in nodes:
		var mmi: MultiMeshInstance3D = nodes[key]
		if not mmi.has_meta("names"):
			continue
		var names: Array = mmi.get_meta("names")
		var m := mesh(names[season])
		mmi.visible = m != null
		if m:
			mmi.multimesh.mesh = m


func _build(cx: int, cy: int) -> void:
	var cw := ceili(float(world.width) / CHUNK)
	var nodes: Dictionary = chunks[cy * cw + cx]
	var lists := {}        # key -> Array[Transform3D]
	var far := {"far_pine": [], "far_leaf": []}
	for y in range(cy * CHUNK, mini((cy + 1) * CHUNK, world.height)):
		for x in range(cx * CHUNK, mini((cx + 1) * CHUNK, world.width)):
			var i := y * world.width + x
			var f := world.feature[i]
			var h := _hash(i)
			if f == Defs.Feature.TREE:
				var tk := tree_kind(i)
				var g := world.growth[i]
				var s := (0.3 + g * 0.7) * TREE_SCALE * (0.85 + h * 0.3)
				var p := Vector3(x + 0.3 + h * 0.4, 0, y + 0.3 + _hash(i, 1) * 0.4)
				var b := Basis(Vector3.UP, h * TAU).scaled(Vector3(s, s, s))
				_add(lists, "%s%d" % tk, Transform3D(b, p))
				var fs := 0.35 + g * 0.75 + h * 0.15
				far["far_pine" if tk[0] == "pine" else "far_leaf"].append(
					Transform3D(Basis(Vector3.UP, h * TAU).scaled(Vector3(fs, fs * 1.15, fs)), p))
			elif f == Defs.Feature.BOULDER:
				var b := Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.55 + h * 0.3))
				_add(lists, "rock%d" % (int(h * 3) % 3), Transform3D(b, Vector3(x + 0.5, -0.05, y + 0.5)))
			elif world.terrain[i] == Defs.Terrain.GRASS and world.occ[i] < 0 and not world.road[i] \
					and f == Defs.Feature.NONE:
				# ground cover: bushes at forest edges, tufts and flowers in the open
				var r := _hash(i, 9)
				if r < 0.05 and _near_tree(x, y):
					var b := Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.35 + h * 0.15))
					_add(lists, "bush%d" % (int(_hash(i, 2) * 3) % 3), Transform3D(b, Vector3(x + h, 0, y + _hash(i, 5))))
				elif r < 0.22:
					var b := Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.3 + h * 0.2))
					var gi := 0 if r < 0.1 else (1 if r < 0.17 else (2 if r < 0.205 else 3))
					_add(lists, "grass%d" % gi, Transform3D(b, Vector3(x + h, 0, y + _hash(i, 6))))
	var center := Vector3((cx + 0.5) * CHUNK, 0, (cy + 0.5) * CHUNK)
	var keys := {}
	for key in lists:
		keys[key] = true
		var mmi: MultiMeshInstance3D = nodes.get(key)
		if mmi == null:
			var kind: String = key.rstrip("0123456789")
			var names: Array = KINDS[kind][int(key.substr(kind.length()))]
			mmi = _make(mesh(names[season]), mat)
			mmi.set_meta("names", names)
			mmi.visible = names[season] != ""
			mmi.visibility_range_end = NEAR if kind != "grass" else NEAR * 0.75
			mmi.visibility_range_end_margin = 2.0
			if kind == "grass":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nodes[key] = mmi
		_fill(mmi, lists[key], center)
	for key in far:
		keys[key] = true
		var mmi: MultiMeshInstance3D = nodes.get(key)
		if mmi == null:
			mmi = _make(Meshes.tree(0 if key == "far_pine" else 1), far_mat)
			mmi.visibility_range_begin = NEAR
			mmi.visibility_range_begin_margin = 2.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nodes[key] = mmi
		_fill(mmi, far[key], center)
	for key in nodes.keys():
		if not keys.has(key):
			nodes[key].queue_free()
			nodes.erase(key)


func _near_tree(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t: Vector2i = Vector2i(x, y) + d
		if world.in_bounds(t) and world.feature[world.idx(t)] == Defs.Feature.TREE:
			return true
	return false


func _add(lists: Dictionary, key: String, t: Transform3D) -> void:
	if not lists.has(key):
		lists[key] = []
	lists[key].append(t)


func _make(m: Mesh, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)
	return mmi


## Instances are stored relative to the chunk's middle so the node sits there and
## the visibility range is measured from the right place.
func _fill(mmi: MultiMeshInstance3D, ts: Array, center: Vector3) -> void:
	mmi.position = center
	var mm := mmi.multimesh
	mm.instance_count = ts.size()
	for i in ts.size():
		var t: Transform3D = ts[i]
		t.origin -= center
		mm.set_instance_transform(i, t)
