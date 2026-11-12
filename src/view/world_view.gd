class_name WorldView
extends Node3D
## Draws the World: terrain and water once, then trees, roads, fields, buildings
## and people, redrawing each layer only when the sim says it changed.

const GRASS_A := Color(0.3, 0.45, 0.19)
const GRASS_B := Color(0.38, 0.5, 0.22)
const FIELD_SOIL := Color(0.42, 0.3, 0.2)
const ROAD := Color(0.58, 0.48, 0.34)
const JOB_COLORS := {
	"Labourer": Color(0.62, 0.55, 0.45), "Builder": Color(0.85, 0.6, 0.2), "Child": Color(0.6, 0.75, 0.9),
	"Gatherer": Color(0.7, 0.25, 0.45), "Hunter": Color(0.45, 0.32, 0.2), "Fisher": Color(0.3, 0.5, 0.75),
	"Farmer": Color(0.85, 0.75, 0.3), "Forester": Color(0.25, 0.55, 0.25), "Herbalist": Color(0.45, 0.75, 0.4),
	"Woodcutter": Color(0.7, 0.42, 0.2), "Blacksmith": Color(0.3, 0.3, 0.35), "Tailor": Color(0.75, 0.3, 0.25),
	"Stonecutter": Color(0.7, 0.7, 0.7), "Miner": Color(0.5, 0.35, 0.3), "Trader": Color(0.8, 0.7, 0.2),
}

var world: World
var terrain_mat: ShaderMaterial
var tree_mat: ShaderMaterial
var thing_mat: ShaderMaterial
var water_mat: StandardMaterial3D
var nature: NatureView
var villagers := {}                 # citizen id -> Villager
var anim_speed := 1.0               # set by the game: 0 when paused
var marks: MultiMeshInstance3D
var roads: MultiMeshInstance3D
var soil: MultiMeshInstance3D
var crops: MultiMeshInstance3D
var building_nodes := {}            # id -> Node3D
var prev_pos := {}                  # citizen id -> Vector2 at the start of the last step
var facing := {}
var _rev := -1
var _brev := -1
var _field_timer := 0.0
var _site_timer := 0.0
var _tile_timer := 0.0
var selection: MeshInstance3D
var radius_ring: MeshInstance3D


func setup(w: World) -> void:
	world = w
	terrain_mat = Meshes.material().duplicate()
	tree_mat = Meshes.material().duplicate()
	thing_mat = Meshes.material().duplicate()
	_build_terrain()
	_build_water()
	nature = NatureView.new()
	add_child(nature)
	nature.setup(world, tree_mat)
	marks = _multimesh(Meshes.crate(), _flat_material(Color(0.9, 0.2, 0.15)), false)
	roads = _multimesh(Meshes.flat_tile(), _flat_material(ROAD), false)
	soil = _multimesh(Meshes.flat_tile(), _flat_material(FIELD_SOIL), false)
	crops = _multimesh(Meshes.crop(), thing_mat, true)
	selection = MeshInstance3D.new()
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 0.9, 0.3, 0.35)
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	pm.center_offset = Vector3(0.5, 0, 0.5)
	selection.mesh = pm
	selection.material_override = sm
	selection.visible = false
	add_child(selection)
	radius_ring = MeshInstance3D.new()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.45)
	radius_ring.material_override = rm
	radius_ring.visible = false
	add_child(radius_ring)
	snapshot()


func _flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _multimesh(mesh: Mesh, mat: Material, colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


static func tile_pos(t: Vector2i, y := 0.0) -> Vector3:
	return Vector3(t.x + 0.5, y, t.y + 0.5)


func _hash(i: int) -> float:
	var h := (i * 2654435761) & 0xffffffff
	return float(h % 10007) / 10007.0


# --- terrain -------------------------------------------------------------------

func _tile_height(x: int, y: int) -> float:
	x = clampi(x, 0, world.width - 1)
	y = clampi(y, 0, world.height - 1)
	var i := y * world.width + x
	match world.terrain[i]:
		Defs.Terrain.WATER: return -0.5
		Defs.Terrain.FORD: return -0.14
		Defs.Terrain.ROCK: return 1.0 + _hash(i) * 1.6 + _rock_depth(x, y) * 0.5
	return 0.0


func _rock_depth(x: int, y: int) -> float:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var t: Vector2i = Vector2i(x, y) + d
		if not world.in_bounds(t) or world.terrain[world.idx(t)] == Defs.Terrain.ROCK:
			n += 1
	return n


func _corner(x: int, y: int) -> float:
	# a corner sits as high as the lowest-lying of the flat tiles around it, so
	# grass stays flat and only the mountains and the river bed bend
	var hs := [_tile_height(x - 1, y - 1), _tile_height(x, y - 1), _tile_height(x - 1, y), _tile_height(x, y)]
	var flat := true
	for h in hs:
		if h != 0.0:
			flat = false
	if flat:
		return 0.0
	var low: float = hs.min()
	var high: float = hs.max()
	if low < 0.0:
		return low
	return high * 0.8 if hs.has(0.0) else (hs[0] + hs[1] + hs[2] + hs[3]) / 4.0


func _tile_color(i: int) -> Color:
	var j := _hash(i * 7 + 3)
	match world.terrain[i]:
		Defs.Terrain.WATER: return Color(0.33, 0.36, 0.28)
		Defs.Terrain.FORD: return Color(0.6, 0.56, 0.42)
		Defs.Terrain.ROCK: return Color(0.48, 0.46, 0.43).lightened(j * 0.12)
	match world.feature[i]:
		Defs.Feature.STONE_DEP: return Color(0.6, 0.6, 0.58).darkened(j * 0.12)
		Defs.Feature.IRON_DEP: return Color(0.56, 0.36, 0.28).darkened(j * 0.12)
	var f := clampf((world.fert[i] - 0.4) / 0.85, 0.0, 1.0)
	var c := Color(0.48, 0.48, 0.26).lerp(GRASS_A, f).lerp(GRASS_B, j * 0.5)
	return c


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := world.width
	var h := world.height
	var corners := PackedFloat32Array()
	corners.resize((w + 1) * (h + 1))
	for y in h + 1:
		for x in w + 1:
			corners[y * (w + 1) + x] = _corner(x, y)
	Meshes.facing_up(w / 2.0, h / 2.0)
	for y in h:
		for x in w:
			var i := y * w + x
			var c := _tile_color(i)
			var a := Vector3(x, corners[y * (w + 1) + x], y)
			var b := Vector3(x + 1, corners[y * (w + 1) + x + 1], y)
			var cc := Vector3(x + 1, corners[(y + 1) * (w + 1) + x + 1], y + 1)
			var d := Vector3(x, corners[(y + 1) * (w + 1) + x], y + 1)
			Meshes._tri(st, d, cc, b, c)
			Meshes._tri(st, d, b, a, c)
	# skirt down the map edge so it does not look paper-thin
	var edge := Color(0.3, 0.25, 0.2)
	Meshes.inside = Vector3(w / 2.0, 0, h / 2.0)
	for x in w:
		Meshes._quad(st, Vector3(x, -2, 0), Vector3(x + 1, -2, 0), Vector3(x + 1, corners[x + 1], 0), Vector3(x, corners[x], 0), edge)
		Meshes._quad(st, Vector3(x + 1, -2, h), Vector3(x, -2, h), Vector3(x, corners[h * (w + 1) + x], h), Vector3(x + 1, corners[h * (w + 1) + x + 1], h), edge)
	for y in h:
		Meshes._quad(st, Vector3(0, -2, y + 1), Vector3(0, -2, y), Vector3(0, corners[y * (w + 1)], y), Vector3(0, corners[(y + 1) * (w + 1)], y + 1), edge)
		Meshes._quad(st, Vector3(w, -2, y), Vector3(w, -2, y + 1), Vector3(w, corners[(y + 1) * (w + 1) + w], y + 1), Vector3(w, corners[y * (w + 1) + w], y), edge)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	mi.name = "Terrain"
	add_child(mi)


func _build_water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(world.width, world.height)
	mi.mesh = pm
	mi.position = Vector3(world.width / 2.0, -0.08, world.height / 2.0)
	water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.2, 0.42, 0.58, 0.8)
	water_mat.roughness = 0.2
	water_mat.metallic_specular = 0.6
	mi.material_override = water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- per frame --------------------------------------------------------------------

## Remember where everyone is before the sim moves them, so frames can interpolate.
func snapshot() -> void:
	for c in world.citizens.values():
		prev_pos[c.id] = c.pos


func update_view(alpha: float, delta: float) -> void:
	_tile_timer -= delta
	if world.revision != _rev and _tile_timer <= 0.0:
		_rev = world.revision
		_tile_timer = 0.4
		_draw_tiles()
	if world.building_revision != _brev:
		_brev = world.building_revision
		_sync_buildings()
	_site_timer -= delta
	if _site_timer <= 0.0:
		_site_timer = 0.3
		_update_sites()
	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = 0.5
		_draw_fields()
	nature.update_view(delta)
	_draw_people(alpha)
	_season()


func _season() -> void:
	var t := float(world.tick % Defs.YEAR_TICKS) / Defs.MONTH_TICKS   # 0..12
	# snow settles from Early Winter and melts through Early Spring
	var snow := 0.0
	if t >= 9.0:
		snow = clampf((t - 9.0) * 1.5, 0.0, 1.0)
	elif t < 1.0:
		snow = clampf(1.0 - t * 1.2, 0.0, 1.0)
	var autumn := 0.0
	if t >= 6.0 and t < 9.5:
		autumn = clampf((t - 6.0) / 1.5, 0.0, 1.0) * clampf((9.5 - t) * 2.0, 0.0, 1.0)
	if NatureView.season_of(world.month()) == 1:
		autumn = maxf(autumn, 1.0)    # match the near trees, which switch for the season
	terrain_mat.set_shader_parameter("snow", snow * 0.8)
	tree_mat.set_shader_parameter("snow", snow * 0.7)
	thing_mat.set_shader_parameter("snow", snow)
	tree_mat.set_shader_parameter("leaf_tint", Color(0.82, 0.42, 0.14, autumn * 0.8))
	water_mat.albedo_color = Color(0.2, 0.42, 0.58, 0.8).lerp(Color(0.8, 0.88, 0.95, 0.95), snow * 0.8)


func _draw_tiles() -> void:
	var mark_t: Array[Transform3D] = []
	var road_t: Array[Transform3D] = []
	for i in world.road.size():
		if world.road[i]:
			road_t.append(Transform3D(Basis(), Vector3(i % world.width, 0.015, i / world.width)))
	for i in world.marked:
		var x: int = i % world.width
		var y: int = i / world.width
		var hgt := 0.8
		if world.feature[i] == Defs.Feature.TREE:
			hgt = 0.6 + world.growth[i] * 2.0
		mark_t.append(Transform3D(Basis().scaled(Vector3(0.8, 0.8, 0.8)), Vector3(x + 0.5, hgt, y + 0.5)))
	_fill(marks, mark_t)
	_fill(roads, road_t)


func _fill(mmi: MultiMeshInstance3D, ts: Array) -> void:
	var mm := mmi.multimesh
	if mm.instance_count < ts.size() or mm.instance_count > ts.size() + 256:
		mm.instance_count = ts.size() + 64
	mm.visible_instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])


func _draw_fields() -> void:
	var soil_t: Array[Transform3D] = []
	var crop_t: Array[Transform3D] = []
	var crop_c: Array[Color] = []
	for b in world.buildings.values():
		if b.kind() != "field":
			continue
		for i in b.field.size():
			var t := world.field_tile(b, i)
			soil_t.append(Transform3D(Basis(), Vector3(t.x, 0.012, t.y)))
			var g: float = b.field[i]
			if g < 0.0:
				continue
			var ripe: bool = g >= 1.0
			var col: Color
			if b.crop == "wheat":
				col = Color(0.45, 0.65, 0.25).lerp(Color(0.92, 0.78, 0.32), clampf((g - 0.6) / 0.4, 0, 1))
			else:
				col = Color(0.35, 0.6, 0.25).lerp(Color(0.25, 0.45, 0.18), clampf((g - 0.6) / 0.4, 0, 1))
			var hgt: float = 0.05 + g * 0.4
			crop_t.append(Transform3D(Basis().scaled(Vector3(1, hgt, 1)), Vector3(t.x, 0.0, t.y)))
			crop_c.append(col if not ripe else col.lightened(0.1))
	_fill(soil, soil_t)
	_fill(crops, crop_t)
	for i in crop_c.size():
		crops.multimesh.set_instance_color(i, crop_c[i])


func _draw_people(alpha: float) -> void:
	for id in villagers.keys():
		if not world.citizens.has(id):
			villagers[id].queue_free()
			villagers.erase(id)
	for c in world.citizens.values():
		var v: Villager = villagers.get(c.id)
		if v == null:
			v = Villager.create()
			add_child(v)
			villagers[c.id] = v
		var job := world.job_name(c)
		v.dress(job, not c.male, c.id * 7 % 3, c.id * 13 % 5)
		var s := 1.0 if c.is_adult() else 0.55 + 0.45 * clampf(c.age / Defs.ADULT_AGE, 0.0, 1.0)
		v.scale = Vector3(s, s, s)
		var a: Vector2 = prev_pos.get(c.id, c.pos)
		var p := a.lerp(c.pos, alpha)
		var y := 0.0
		var t: Vector2i = c.tile()
		if world.in_bounds(t) and world.terrain[world.idx(t)] == Defs.Terrain.FORD:
			y = -0.12
		v.position = Vector3(p.x, y, p.y)
		var state := _state(c)
		v.visible = state[0] != "inside"
		if not v.visible:
			continue
		var d: Vector2 = c.pos - a
		if d.length_squared() > 0.00001:
			facing[c.id] = atan2(d.x, d.y)
		elif state[1] != Vector2.INF:
			var to: Vector2 = state[1] - c.pos
			if to.length_squared() > 0.01:
				facing[c.id] = atan2(to.x, to.y)
		v.rotation.y = lerp_angle(v.rotation.y, facing.get(c.id, 0.0), 0.25)
		var speed := anim_speed
		if state[0] == "Jog_Fwd":
			speed *= 1.7
		v.play(state[0], speed)
		var res := ""
		for k in c.carry:
			res = k
		v.carry(Defs.RES[res].color if res != "" else Color(0, 0, 0, 0))


## What a person looks like they are doing: [animation or "inside", spot they face].
func _state(c: Citizen) -> Array:
	if c.plan.is_empty():
		return ["Idle", Vector2.INF]
	var s: Dictionary = c.plan[0]
	if s.t == "go":
		return ["Jog_Fwd", Vector2.INF]
	var at := Vector2.INF
	if s.has("tile"):
		at = Vector2(s.tile) + Vector2(0.5, 0.5)
	var b: Building = world.buildings.get(s.get("b", -1))
	if b and b.kind() != "field":
		at = b.center()
	match s.fx:
		"eat_home", "put_home":
			return ["inside", at]
		"warm":
			if b and b.kind() == "house":
				return ["inside", at]
			return ["Idle_Torch", at]
		"gather":
			if b and b.type == "hunter":
				return ["Pistol_Aim_Neutral", at]
			if b and b.type == "fisher":
				return ["Idle_Torch", at]
			return ["Fixing_Kneeling", at]
		"plant", "plant_field", "harvest":
			return ["Fixing_Kneeling", at]
		"chop", "clear", "extract", "build":
			return ["Sword_Attack", at]
		"process":
			return ["Interact" if b and b.type == "tailor" else "Sword_Attack", at]
		"eat_store":
			return ["Idle_Talking", at]
		"idle":
			if not c.is_adult():
				return ["Dance" if c.id % 3 == 0 else "Idle", at]
			return ["Idle_Talking" if c.id % 4 == 0 else "Idle", at]
	return ["Interact", at]


# --- buildings ---------------------------------------------------------------------

func _sync_buildings() -> void:
	for id in building_nodes.keys():
		if not world.buildings.has(id):
			building_nodes[id].queue_free()
			building_nodes.erase(id)
	for b in world.buildings.values():
		if b.kind() == "field":
			continue
		var node: Node3D = building_nodes.get(b.id)
		if node == null:
			node = Node3D.new()
			node.position = Vector3(b.pos.x, 0, b.pos.y)
			var mi := MeshInstance3D.new()
			mi.name = "Body"
			mi.mesh = Meshes.building(b.type)
			mi.material_override = thing_mat
			node.add_child(mi)
			var sc := MeshInstance3D.new()
			sc.name = "Scaffold"
			sc.mesh = Meshes.scaffold(b.size)
			sc.material_override = thing_mat
			node.add_child(sc)
			if b.kind() == "house":
				node.add_child(_smoke(Vector3(1.45 if b.type == "house" else 0.5, 1.6, 0.75)))
			add_child(node)
			building_nodes[b.id] = node
	_update_sites()


func _update_sites() -> void:
	for id in building_nodes:
		var b: Building = world.buildings.get(id)
		if b == null:
			continue
		var node: Node3D = building_nodes[id]
		var body: MeshInstance3D = node.get_node("Body")
		var sc: MeshInstance3D = node.get_node("Scaffold")
		if b.built:
			body.scale = Vector3.ONE
			sc.visible = false
		else:
			var f := clampf(b.progress / maxf(1.0, b.work), 0.0, 1.0)
			body.scale = Vector3(1, maxf(0.03, f), 1)
			sc.visible = true
		_fire(node, b)
		var smoke: CPUParticles3D = node.get_node_or_null("Smoke")
		if smoke:
			# a fire in the hearth when someone is home and it is cold, or at mealtimes
			var cold: bool = Defs.MONTH_TEMP[world.month()] < Defs.COLD_BELOW + 4
			smoke.emitting = b.built and not b.residents.is_empty() and b.warm and (cold or (b.id + world.tick / 200) % 3 == 0)


func _smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 8
	p.lifetime = 3.5
	p.position = at
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 12
	p.gravity = Vector3(0.12, 0.25, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.8, 0.82, 0.55))
	grad.set_color(1, Color(0.85, 0.85, 0.88, 0.0))
	p.color_ramp = grad
	var sm := SphereMesh.new()
	sm.radial_segments = 6
	sm.rings = 3
	sm.radius = 0.25
	sm.height = 0.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	sm.material = m
	p.mesh = sm
	p.emitting = false
	return p


func _fire(node: Node3D, b: Building) -> void:
	var fire: Node3D = node.get_node_or_null("Fire")
	if b.fire > 0 and fire == null:
		fire = Node3D.new()
		fire.name = "Fire"
		var p := CPUParticles3D.new()
		p.amount = 40
		p.lifetime = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(b.size.x * 0.4, 0.3, b.size.y * 0.4)
		p.direction = Vector3.UP
		p.spread = 15
		p.gravity = Vector3(0, 1.5, 0)
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 1.2
		p.scale_amount_min = 0.15
		p.scale_amount_max = 0.35
		var pm := BoxMesh.new()
		pm.size = Vector3(0.3, 0.3, 0.3)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.5, 0.1)
		m.vertex_color_use_as_albedo = true
		pm.material = m
		p.mesh = pm
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.85, 0.3))
		grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
		p.color_ramp = grad
		p.position = Vector3(b.size.x / 2.0, 0.6, b.size.y / 2.0)
		fire.add_child(p)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.light_energy = 2.0
		light.omni_range = 5.0
		light.position = p.position + Vector3(0, 0.8, 0)
		fire.add_child(light)
		node.add_child(fire)
	elif b.fire <= 0 and fire != null:
		fire.queue_free()


# --- selection and radius ---------------------------------------------------------------

func show_selection(b: Building) -> void:
	if b == null:
		selection.visible = false
		radius_ring.visible = false
		return
	selection.visible = true
	selection.position = Vector3(b.pos.x, 0.03, b.pos.y)
	selection.scale = Vector3(b.size.x, 1, b.size.y)
	show_radius(b.center(), float(b.def().get("radius", 0)))


func show_radius(center: Vector2, r: float) -> void:
	if r <= 0:
		radius_ring.visible = false
		return
	radius_ring.visible = true
	radius_ring.mesh = _ring(r)
	radius_ring.position = Vector3(center.x, 0.05, center.y)


func _ring(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Meshes.facing_up()
	var n := 64
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		Meshes._quad(st, o0 * (r - 0.12), o1 * (r - 0.12), o1 * (r + 0.12), o0 * (r + 0.12), Color.WHITE)
	return st.commit()
