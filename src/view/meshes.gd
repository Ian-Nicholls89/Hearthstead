class_name Meshes
extends RefCounted
## Low-poly meshes built in code from boxes, gables, cones and cylinders with
## vertex colours, so the game ships with no model files. One tile = 1 unit;
## a building mesh has its origin at the footprint's top-left corner.

const WOOD := Color(0.62, 0.45, 0.28)
const WOOD_DARK := Color(0.42, 0.29, 0.18)
const PLASTER := Color(0.86, 0.8, 0.66)
const THATCH := Color(0.72, 0.6, 0.33)
const ROOF := Color(0.45, 0.27, 0.2)
const SLATE := Color(0.33, 0.35, 0.4)
const STONE := Color(0.62, 0.61, 0.58)
const STONE_DARK := Color(0.45, 0.44, 0.42)
const DOOR := Color(0.25, 0.16, 0.1)
const LEAF := Color(0.2, 0.45, 0.17)
const CLOTH := Color(0.7, 0.25, 0.2)

static var _cache := {}
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://src/view/lowpoly.gdshader")
	return _material


# --- primitives ---------------------------------------------------------------

## Adds a triangle facing away from `inside` (the middle of the solid it belongs
## to). Godot treats clockwise triangles as front faces, hence the a, c, b order.
static var inside := Vector3.ZERO


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_color(col)
	st.set_normal(n.normalized())
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


## For flat things lying on the ground: everything faces up.
static func facing_up(x := 0.0, z := 0.0) -> void:
	inside = Vector3(x, -1000.0, z)


static func box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	inside = center
	var p := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
		center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
		center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	var tc: Color = col if top.a == 0 else top
	_quad(st, p[4], p[5], p[6], p[7], tc)          # top
	_quad(st, p[3], p[2], p[1], p[0], col.darkened(0.3))   # bottom
	_quad(st, p[0], p[1], p[5], p[4], col.darkened(0.08))  # -z
	_quad(st, p[2], p[3], p[7], p[6], col)         # +z (front)
	_quad(st, p[1], p[2], p[6], p[5], col.darkened(0.15))  # +x
	_quad(st, p[3], p[0], p[4], p[7], col.darkened(0.04))  # -x


## A gable roof: ridge runs along x when along_x, else along z. `size` is the
## footprint and height of the roof; it overhangs by `over`.
static func gable(st: SurfaceTool, base: Vector3, size: Vector3, col: Color, along_x := true, over := 0.12) -> void:
	var hx := size.x * 0.5 + over
	var hz := size.z * 0.5 + over
	var y0 := base.y
	var y1 := base.y + size.y
	var c := base
	inside = base + Vector3(0, size.y * 0.3, 0)
	var gable_col := col.darkened(0.2)
	if along_x:
		var a := c + Vector3(-hx, 0, -hz)
		var b := c + Vector3(hx, 0, -hz)
		var d := c + Vector3(hx, 0, hz)
		var e := c + Vector3(-hx, 0, hz)
		var r0 := Vector3(c.x - hx, y1, c.z)
		var r1 := Vector3(c.x + hx, y1, c.z)
		_quad(st, e, d, r1, r0, col)
		_quad(st, b, a, r0, r1, col.darkened(0.12))
		_tri(st, a, e, r0, gable_col)
		_tri(st, d, b, r1, gable_col)
	else:
		var a := c + Vector3(-hx, 0, -hz)
		var b := c + Vector3(hx, 0, -hz)
		var d := c + Vector3(hx, 0, hz)
		var e := c + Vector3(-hx, 0, hz)
		var r0 := Vector3(c.x, y1, c.z - hz)
		var r1 := Vector3(c.x, y1, c.z + hz)
		_quad(st, d, b, r0, r1, col.darkened(0.12))
		_quad(st, a, e, r1, r0, col)
		_tri(st, b, a, r0, gable_col)
		_tri(st, e, d, r1, gable_col)
	var _unused := y0


static func cone(st: SurfaceTool, base: Vector3, radius: float, height: float, col: Color, sides := 6, rot := 0.0) -> void:
	var tip := base + Vector3(0, height, 0)
	inside = base + Vector3(0, height * 0.3, 0)
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := base + Vector3(cos(a1), 0, sin(a1)) * radius
		var shade := 0.85 + 0.15 * sin(a0 + 1.0)
		_tri(st, p1, p0, tip, Color(col.r * shade, col.g * shade, col.b * shade))
		_tri(st, p0, p1, base, col.darkened(0.35))


static func cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, col: Color, sides := 6, top_radius := -1.0) -> void:
	var tr := radius if top_radius < 0 else top_radius
	var top := base + Vector3(0, height, 0)
	inside = base + Vector3(0, height * 0.5, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var shade := 0.85 + 0.15 * sin(a0 + 1.0)
		_quad(st, base + d1 * radius, base + d0 * radius, top + d0 * tr, top + d1 * tr,
			Color(col.r * shade, col.g * shade, col.b * shade))
		_tri(st, top + d0 * tr, top, top + d1 * tr, col.lightened(0.05))


static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.index()
	return st.commit()


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# --- things ---------------------------------------------------------------------

static func tree(kind := 0) -> ArrayMesh:
	var key := "tree%d" % kind
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	cylinder(st, Vector3.ZERO, 0.07, 0.35, WOOD_DARK, 5)
	if kind == 0:   # pine
		cone(st, Vector3(0, 0.25, 0), 0.42, 0.65, LEAF, 7)
		cone(st, Vector3(0, 0.6, 0), 0.32, 0.55, LEAF.lightened(0.08), 7, 0.4)
		cone(st, Vector3(0, 0.92, 0), 0.2, 0.4, LEAF.lightened(0.15), 7)
	else:           # broadleaf
		var leaf := Color(0.3, 0.52, 0.2)
		cylinder(st, Vector3(0, 0.3, 0), 0.3, 0.2, leaf, 7, 0.42)
		cylinder(st, Vector3(0, 0.5, 0), 0.42, 0.3, leaf.lightened(0.06), 7, 0.36)
		cylinder(st, Vector3(0, 0.8, 0), 0.36, 0.22, leaf.lightened(0.1), 7, 0.12)
	_cache[key] = _commit(st)
	return _cache[key]


static func crate() -> ArrayMesh:
	if _cache.has("crate"):
		return _cache.crate
	var st := _begin()
	box(st, Vector3(0, 0.07, 0), Vector3(0.16, 0.14, 0.16), Color(1, 1, 1))
	_cache.crate = _commit(st)
	return _cache.crate


static func flat_tile(col := Color(1, 1, 1)) -> ArrayMesh:
	var key := "flat"
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	facing_up()
	_quad(st, Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0), col)
	_cache[key] = _commit(st)
	return _cache[key]


static func crop() -> ArrayMesh:
	if _cache.has("crop"):
		return _cache.crop
	var st := _begin()
	for i in 3:
		box(st, Vector3(0.2 + i * 0.3, 0.5, 0.5), Vector3(0.16, 1.0, 0.8), Color(1, 1, 1))
	_cache.crop = _commit(st)
	return _cache.crop


static func scaffold(size: Vector2i) -> ArrayMesh:
	var key := "scaffold%dx%d" % [size.x, size.y]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var w := float(size.x)
	var d := float(size.y)
	for p in [Vector2(0.15, 0.15), Vector2(w - 0.15, 0.15), Vector2(0.15, d - 0.15), Vector2(w - 0.15, d - 0.15)]:
		box(st, Vector3(p.x, 0.6, p.y), Vector3(0.07, 1.2, 0.07), WOOD)
	box(st, Vector3(w / 2, 1.15, 0.15), Vector3(w - 0.2, 0.06, 0.06), WOOD)
	box(st, Vector3(w / 2, 1.15, d - 0.15), Vector3(w - 0.2, 0.06, 0.06), WOOD)
	box(st, Vector3(0.15, 1.15, d / 2), Vector3(0.06, 0.06, d - 0.2), WOOD)
	box(st, Vector3(w - 0.15, 1.15, d / 2), Vector3(0.06, 0.06, d - 0.2), WOOD)
	box(st, Vector3(w / 2, 0.02, d / 2), Vector3(w - 0.1, 0.04, d - 0.1), Color(0.5, 0.42, 0.3))
	_cache[key] = _commit(st)
	return _cache[key]


## A small house-shaped body used by most workshops: walls, gable roof, door.
static func _hut(st: SurfaceTool, c: Vector3, size: Vector3, wall: Color, roof: Color, along_x := true) -> void:
	box(st, c + Vector3(0, size.y / 2, 0), size, wall)
	gable(st, c + Vector3(0, size.y, 0), Vector3(size.x, size.y * 0.75, size.z), roof, along_x)
	box(st, c + Vector3(0, 0.22, size.z / 2 + 0.01), Vector3(0.22, 0.44, 0.02), DOOR)


static func building(type: String) -> ArrayMesh:
	if _cache.has(type):
		return _cache[type]
	var size: Vector2i = Defs.BUILD[type].size
	var c := Vector3(size.x / 2.0, 0, size.y / 2.0)
	var st := _begin()
	match type:
		"camp":
			box(st, c + Vector3(-0.7, 0.35, -0.5), Vector3(1.1, 0.35, 0.6), WOOD)
			for x in [-1.1, -0.3]:
				for z in [-0.82, -0.18]:
					cylinder(st, c + Vector3(x, 0.17, z), 0.17, 0.04, WOOD_DARK, 8)
			gable(st, c + Vector3(-0.7, 0.52, -0.5), Vector3(1.1, 0.4, 0.6), Color(0.9, 0.87, 0.78), true, 0.02)
			gable(st, c + Vector3(0.75, 0.0, 0.5), Vector3(0.9, 0.75, 1.1), Color(0.78, 0.7, 0.55), false, 0.0)
			for i in 5:
				var a := TAU * i / 5.0
				box(st, c + Vector3(-0.3 + cos(a) * 0.18, 0.04, 0.7 + sin(a) * 0.18), Vector3(0.1, 0.08, 0.1), STONE)
			cone(st, c + Vector3(-0.3, 0.03, 0.7), 0.1, 0.22, Color(1.0, 0.55, 0.15), 5)
			box(st, c + Vector3(0.9, 0.2, -0.8), Vector3(0.5, 0.4, 0.4), WOOD)
		"house":
			box(st, c + Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.25), PLASTER)
			for x in [-0.72, 0.72]:
				box(st, c + Vector3(x, 0.45, 0.63), Vector3(0.08, 0.9, 0.04), WOOD_DARK)
			gable(st, c + Vector3(0, 0.9, 0), Vector3(1.5, 0.7, 1.25), THATCH)
			box(st, c + Vector3(0.45, 1.25, -0.25), Vector3(0.2, 0.6, 0.2), STONE_DARK)
			box(st, c + Vector3(0, 0.28, 0.635), Vector3(0.28, 0.56, 0.02), DOOR)
			box(st, c + Vector3(-0.45, 0.55, 0.635), Vector3(0.22, 0.2, 0.02), Color(0.95, 0.85, 0.5))
		"stone_house":
			box(st, c + Vector3(0, 0.5, 0), Vector3(1.55, 1.0, 1.3), STONE)
			gable(st, c + Vector3(0, 1.0, 0), Vector3(1.55, 0.75, 1.3), SLATE)
			box(st, c + Vector3(-0.5, 1.35, -0.2), Vector3(0.22, 0.65, 0.22), STONE_DARK)
			box(st, c + Vector3(0, 0.3, 0.66), Vector3(0.3, 0.6, 0.02), DOOR)
			box(st, c + Vector3(0.45, 0.6, 0.66), Vector3(0.22, 0.22, 0.02), Color(0.95, 0.85, 0.5))
		"barn":
			box(st, c + Vector3(0, 0.7, 0), Vector3(2.5, 1.4, 2.2), Color(0.55, 0.23, 0.17))
			gable(st, c + Vector3(0, 1.4, 0), Vector3(2.5, 1.0, 2.2), ROOF.darkened(0.2), false)
			box(st, c + Vector3(0, 0.5, 1.11), Vector3(0.9, 1.0, 0.02), WOOD_DARK)
		"stockpile":
			for i in 8:
				var a := TAU * i / 8.0
				box(st, c + Vector3(cos(a) * 1.3, 0.2, sin(a) * 1.3), Vector3(0.08, 0.4, 0.08), WOOD_DARK)
			for z in [-0.6, -0.35, -0.1]:
				box(st, c + Vector3(-0.5, 0.1, z), Vector3(1.0, 0.18, 0.2), WOOD)
			box(st, c + Vector3(0.55, 0.15, 0.4), Vector3(0.6, 0.3, 0.6), STONE)
			box(st, c + Vector3(0.55, 0.38, 0.4), Vector3(0.4, 0.16, 0.4), STONE.lightened(0.05))
		"gatherer":
			_hut(st, c + Vector3(-0.15, 0, -0.1), Vector3(1.2, 0.7, 1.0), WOOD, THATCH)
			for x in [0.55, 0.75]:
				cylinder(st, c + Vector3(x, 0, 0.6), 0.13, 0.2, Color(0.7, 0.55, 0.3), 6, 0.16)
			box(st, c + Vector3(0.65, 0.2, 0.6), Vector3(0.2, 0.05, 0.2), Color(0.7, 0.15, 0.35))
		"hunter":
			_hut(st, c + Vector3(-0.1, 0, -0.1), Vector3(1.3, 0.75, 1.0), WOOD_DARK, ROOF)
			box(st, c + Vector3(0.7, 0.45, 0.55), Vector3(0.05, 0.9, 0.05), WOOD)
			box(st, c + Vector3(0.7, 0.55, 0.55), Vector3(0.4, 0.4, 0.03), Color(0.72, 0.55, 0.38))
		"fisher":
			_hut(st, c + Vector3(-0.2, 0, -0.2), Vector3(1.1, 0.7, 0.9), WOOD, THATCH)
			box(st, c + Vector3(0.55, 0.06, 0.4), Vector3(0.6, 0.06, 1.0), WOOD)
			box(st, c + Vector3(0.55, 0.3, 0.75), Vector3(0.04, 0.5, 0.04), WOOD_DARK)
			box(st, c + Vector3(-0.6, 0.25, 0.6), Vector3(0.3, 0.3, 0.02), Color(0.6, 0.6, 0.5))
		"forester":
			_hut(st, c + Vector3(-0.15, 0, -0.15), Vector3(1.2, 0.75, 1.0), WOOD, Color(0.3, 0.38, 0.22))
			for i in 3:
				box(st, c + Vector3(0.65, 0.08 + i * 0.13, 0.55), Vector3(0.5, 0.12, 0.12), WOOD)
			cone(st, c + Vector3(-0.7, 0, 0.7), 0.12, 0.3, LEAF, 5)
		"herbalist":
			_hut(st, c + Vector3(0, 0, -0.25), Vector3(1.2, 0.7, 0.9), PLASTER, Color(0.35, 0.45, 0.25))
			for x in [-0.5, 0.0, 0.5]:
				box(st, c + Vector3(x, 0.06, 0.6), Vector3(0.35, 0.12, 0.35), Color(0.3, 0.6, 0.25))
		"woodcutter":
			_hut(st, c + Vector3(-0.2, 0, -0.2), Vector3(1.1, 0.75, 1.0), WOOD, ROOF)
			cylinder(st, c + Vector3(0.6, 0, 0.55), 0.15, 0.22, WOOD_DARK, 7)
			for i in 4:
				box(st, c + Vector3(-0.55 + i * 0.12, 0.15, 0.62), Vector3(0.1, 0.3, 0.25), Color(0.75, 0.52, 0.28))
		"blacksmith":
			box(st, c + Vector3(-0.15, 0.45, -0.1), Vector3(1.3, 0.9, 1.1), STONE)
			gable(st, c + Vector3(-0.15, 0.9, -0.1), Vector3(1.3, 0.55, 1.1), SLATE)
			box(st, c + Vector3(0.35, 1.2, -0.4), Vector3(0.28, 0.9, 0.28), STONE_DARK)
			box(st, c + Vector3(0.6, 0.15, 0.6), Vector3(0.3, 0.12, 0.15), Color(0.25, 0.25, 0.28))
			box(st, c + Vector3(-0.15, 0.25, 0.46), Vector3(0.3, 0.5, 0.02), Color(0.95, 0.5, 0.15))
		"tailor":
			_hut(st, c + Vector3(-0.15, 0, -0.15), Vector3(1.2, 0.8, 1.0), PLASTER, ROOF)
			box(st, c + Vector3(0.1, 0.62, 0.6), Vector3(1.0, 0.04, 0.4), CLOTH)
			for x in [-0.35, 0.55]:
				box(st, c + Vector3(x, 0.3, 0.78), Vector3(0.04, 0.62, 0.04), WOOD_DARK)
		"quarry":
			box(st, c + Vector3(0, 0.03, 0), Vector3(3.6, 0.06, 3.6), Color(0.52, 0.51, 0.49))
			box(st, c + Vector3(-0.6, 0.25, -0.6), Vector3(1.6, 0.5, 1.4), STONE_DARK)
			box(st, c + Vector3(-0.9, 0.55, -0.9), Vector3(1.0, 0.3, 0.8), STONE)
			for i in 4:
				box(st, c + Vector3(0.7 + (i % 2) * 0.4, 0.12 + (i / 2) * 0.22, 0.8), Vector3(0.35, 0.2, 0.35), STONE.lightened(0.1))
			box(st, c + Vector3(1.1, 0.8, -0.6), Vector3(0.08, 1.6, 0.08), WOOD)
			box(st, c + Vector3(0.7, 1.55, -0.6), Vector3(0.9, 0.06, 0.06), WOOD)
		"mine":
			cone(st, c + Vector3(0, 0, -0.3), 1.45, 1.3, Color(0.48, 0.36, 0.3), 7)
			box(st, c + Vector3(0, 0.35, 0.75), Vector3(0.7, 0.7, 0.3), Color(0.08, 0.06, 0.05))
			for x in [-0.4, 0.4]:
				box(st, c + Vector3(x, 0.4, 0.92), Vector3(0.1, 0.8, 0.1), WOOD)
			box(st, c + Vector3(0, 0.82, 0.92), Vector3(0.95, 0.1, 0.12), WOOD)
			box(st, c + Vector3(0.9, 0.15, 1.0), Vector3(0.35, 0.22, 0.25), Color(0.55, 0.35, 0.3))
		"well":
			cylinder(st, c, 0.32, 0.3, STONE, 8)
			cylinder(st, c + Vector3(0, 0.29, 0), 0.24, 0.02, Color(0.2, 0.35, 0.5), 8)
			for x in [-0.25, 0.25]:
				box(st, c + Vector3(x, 0.5, 0), Vector3(0.05, 0.5, 0.05), WOOD_DARK)
			gable(st, c + Vector3(0, 0.72, 0), Vector3(0.6, 0.22, 0.45), ROOF, true, 0.04)
		"chapel":
			box(st, c + Vector3(0, 0.8, 0.1), Vector3(1.6, 1.6, 2.4), Color(0.92, 0.9, 0.84))
			gable(st, c + Vector3(0, 1.6, 0.1), Vector3(1.6, 1.0, 2.4), SLATE, false)
			box(st, c + Vector3(0, 1.3, 1.2), Vector3(0.6, 2.6, 0.6), Color(0.9, 0.88, 0.8))
			cone(st, c + Vector3(0, 2.6, 1.2), 0.45, 0.9, SLATE, 4, PI / 4)
			box(st, c + Vector3(0, 0.35, 1.51), Vector3(0.35, 0.7, 0.02), DOOR)
		"town_hall":
			box(st, c + Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.2), STONE)
			box(st, c + Vector3(0, 1.0, 0), Vector3(2.4, 0.8, 2.0), PLASTER)
			gable(st, c + Vector3(0, 1.4, 0), Vector3(2.4, 0.9, 2.0), ROOF)
			box(st, c + Vector3(0.9, 2.3, 0), Vector3(0.05, 1.0, 0.05), WOOD_DARK)
			box(st, c + Vector3(1.08, 2.6, 0), Vector3(0.35, 0.22, 0.02), CLOTH)
			box(st, c + Vector3(0, 0.45, 1.11), Vector3(0.5, 0.9, 0.02), DOOR)
		"trading_post":
			box(st, c + Vector3(-0.4, 0.55, -0.5), Vector3(1.8, 1.1, 1.4), WOOD)
			gable(st, c + Vector3(-0.4, 1.1, -0.5), Vector3(1.8, 0.7, 1.4), ROOF)
			box(st, c + Vector3(0.5, 0.8, 0.8), Vector3(1.4, 0.05, 0.8), Color(0.85, 0.75, 0.3))
			for x in [-0.15, 1.15]:
				box(st, c + Vector3(x, 0.4, 1.15), Vector3(0.05, 0.8, 0.05), WOOD_DARK)
			for i in 3:
				box(st, c + Vector3(0.1 + i * 0.35, 0.15, 0.7), Vector3(0.28, 0.3, 0.28), WOOD.lightened(0.1))
		_:
			box(st, c + Vector3(0, 0.4, 0), Vector3(size.x - 0.4, 0.8, size.y - 0.4), WOOD)
	_cache[type] = _commit(st)
	return _cache[type]
