class_name Game
extends Node3D
## Runs one town: steps the World at the chosen speed, draws it, and turns taps
## into commands (select, place a building, lay a road, mark trees, demolish).

signal exit_to_menu

const SPEEDS := [0, 1, 2, 5, 10]
const BURST := 60                       # most sim ticks run in one frame

var world: World
var view: WorldView
var rig: CameraRig
var hud: Hud
var sun: DirectionalLight3D
var env: Environment
var speed_i := 1
var tool := ""                          # "", "road", "clear", "unclear", "demolish", or a building type
var ghost: MeshInstance3D
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var ghost_tile := Vector2i(-1, -1)
var ghost_reason := ""
var drag_tiles: Array = []
var drag_preview: MultiMeshInstance3D
var selected := -1                      # building id
var selected_person := -1
var _acc := 0.0
var _last_season := -1
var _hud_timer := 0.0


func start(w: World) -> void:
	world = w
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.85)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	view = WorldView.new()
	add_child(view)
	view.setup(world)
	rig = CameraRig.new()
	rig.bounds = Rect2(0, 0, world.width, world.height)
	add_child(rig)
	rig.focus(Vector3(world.width / 2.0, 0, world.height / 2.0 + 2))
	rig.tapped.connect(_on_tap)
	rig.drag_started.connect(_on_drag_start)
	rig.dragged.connect(_on_drag)
	rig.drag_ended.connect(_on_drag_end)
	_make_ghost()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	rig.blocked = hud.is_over_ui
	world.event.connect(hud.toast)
	world.nomads_arrived.connect(func(n): hud.ask_nomads(n))
	_last_season = Defs.season_index(world.month())
	if is_inside_tree():
		get_tree().root.focus_exited.connect(save)


func _make_ghost() -> void:
	ghost = MeshInstance3D.new()
	ghost_ok_mat = StandardMaterial3D.new()
	ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_ok_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_ok_mat.albedo_color = Color(0.4, 1.0, 0.45, 0.5)
	ghost_bad_mat = ghost_ok_mat.duplicate()
	ghost_bad_mat.albedo_color = Color(1.0, 0.3, 0.25, 0.5)
	ghost.visible = false
	add_child(ghost)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Meshes.flat_tile()
	drag_preview = MultiMeshInstance3D.new()
	drag_preview.multimesh = mm
	drag_preview.material_override = ghost_ok_mat
	add_child(drag_preview)


# --- clock ------------------------------------------------------------------------

func speed() -> int:
	return SPEEDS[speed_i]


func set_speed(i: int) -> void:
	speed_i = clampi(i, 0, SPEEDS.size() - 1)
	hud.refresh()


func _process(delta: float) -> void:
	var sp := speed()
	if sp > 0 and not world.game_over and not hud.modal_open():
		_acc += delta * Defs.TICKS_PER_SECOND * sp
		var n := int(_acc)
		if n > BURST:
			n = BURST
			_acc = float(n)
		# keep frames smooth on slow phones: stop after ~12 ms and let time slip
		var t0 := Time.get_ticks_usec()
		var done := 0
		for i in n:
			if i == n - 1 or Time.get_ticks_usec() - t0 > 10000:
				view.snapshot()
			world.step()
			done += 1
			if Time.get_ticks_usec() - t0 > 12000:
				break
		_acc = 0.0 if done < n else _acc - n
		if world.game_over:
			hud.show_game_over()
	view.anim_speed = 0.0 if speed() == 0 or hud.modal_open() else minf(float(speed()), 3.0)
	view.update_view(clampf(_acc, 0.0, 1.0), delta)
	_lighting()
	var season := Defs.season_index(world.month())
	if season != _last_season:
		_last_season = season
		save()
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		hud.refresh()


func _lighting() -> void:
	var t := float(world.tick % Defs.YEAR_TICKS) / Defs.YEAR_TICKS
	# warm summer light, cool and low winter light
	var summer := 0.5 + 0.5 * cos((t - 0.38) * TAU)
	sun.light_color = Color(0.85, 0.9, 1.0).lerp(Color(1.0, 0.95, 0.85), summer)
	sun.light_energy = 0.75 + 0.25 * summer
	env.background_color = Color(0.68, 0.74, 0.8).lerp(Color(0.55, 0.72, 0.88), summer)
	env.fog_light_color = env.background_color


func save() -> void:
	if world and not world.game_over:
		SaveGame.save(world)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## Android back: cancel the tool, close a panel, or open the pause menu.
func back() -> void:
	if tool != "":
		set_tool("")
	elif hud.close_top():
		pass
	elif selected >= 0 or selected_person >= 0:
		select(-1)
	else:
		hud.show_pause()


# --- tools ---------------------------------------------------------------------------

func set_tool(t: String) -> void:
	tool = t
	ghost.visible = false
	ghost_tile = Vector2i(-1, -1)
	ghost_reason = ""
	drag_tiles.clear()
	_preview([])
	rig.tool_drag = t in ["road", "clear", "unclear"]
	if t != "":
		select(-1)
	if Defs.BUILD.has(t) and t != "road":
		ghost.mesh = _ghost_mesh(t)
		# start the ghost on free ground near the middle of the screen
		var mid := rig.ground_tile(get_viewport().get_visible_rect().size * 0.5)
		_move_ghost(_free_spot(t, mid))
	view.radius_ring.visible = false
	hud.refresh()


func _ghost_mesh(t: String) -> Mesh:
	if Defs.BUILD[t].kind == "field":
		var bm := BoxMesh.new()
		var s: Vector2i = Defs.BUILD[t].size
		bm.size = Vector3(s.x, 0.1, s.y)
		return bm
	return Meshes.building(t)


func _free_spot(t: String, around: Vector2i) -> Vector2i:
	var s: Vector2i = Defs.BUILD[t].size
	for r in range(0, 14):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := around + Vector2i(x, y)
				if world.can_place(t, c - s / 2) == "":
					return c
	return around


func _move_ghost(center: Vector2i) -> void:
	var s: Vector2i = Defs.BUILD[tool].size
	ghost_tile = center - s / 2
	ghost_reason = world.can_place(tool, ghost_tile)
	ghost.visible = true
	ghost.material_override = ghost_ok_mat if ghost_reason == "" else ghost_bad_mat
	if Defs.BUILD[tool].kind == "field":
		ghost.position = Vector3(ghost_tile.x + s.x / 2.0, 0.05, ghost_tile.y + s.y / 2.0)
	else:
		ghost.position = Vector3(ghost_tile.x, 0.02, ghost_tile.y)
	var r := float(Defs.BUILD[tool].get("radius", 0))
	view.show_radius(Vector2(ghost_tile) + Vector2(s) * 0.5, r)
	hud.refresh()


func confirm_place() -> void:
	if not Defs.BUILD.has(tool) or ghost_tile.x < 0:
		return
	var id := world.place(tool, ghost_tile)
	if id >= 0:
		# stay in the tool so rows of houses are quick; nudge the ghost aside
		var s: Vector2i = Defs.BUILD[tool].size
		_move_ghost(ghost_tile + s / 2 + Vector2i(s.x + 1, 0))
	else:
		hud.toast(ghost_reason if ghost_reason != "" else "Can't build there.", "bad")


func _on_tap(screen: Vector2) -> void:
	var t := rig.ground_tile(screen)
	match tool:
		"":
			_select_at(screen, t)
		"road":
			world.place_road([t])
		"clear", "unclear":
			world.mark_clear(Rect2i(t, Vector2i.ONE), tool == "clear")
		"demolish":
			var b := world.building_at(t)
			if b and b.type != "camp":
				hud.confirm("Remove the %s?" % b.title().to_lower(),
					"Half of what went into it comes back.", func(): world.demolish(b.id))
			elif world.in_bounds(t) and world.road[world.idx(t)]:
				world.remove_road(t)
		_:
			if Defs.BUILD.has(tool):
				var s: Vector2i = Defs.BUILD[tool].size
				var center := ghost_tile + s / 2
				if t == center or (Rect2i(ghost_tile, s).has_point(t) and ghost_reason == ""):
					confirm_place()
				else:
					_move_ghost(t)


func _on_drag_start(screen: Vector2) -> void:
	drag_tiles = [rig.ground_tile(screen)]


func _on_drag(screen: Vector2) -> void:
	if drag_tiles.is_empty():
		return
	var a: Vector2i = drag_tiles[0]
	var b := rig.ground_tile(screen)
	var tiles: Array = []
	if tool == "road":
		tiles = road_path(a, b)
	else:
		var r := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), (a - b).abs() + Vector2i.ONE)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				tiles.append(Vector2i(x, y))
	drag_tiles = [a] + tiles
	_preview(tiles)


func _on_drag_end(_screen: Vector2) -> void:
	if drag_tiles.size() < 2:
		drag_tiles.clear()
		_preview([])
		return
	var tiles := drag_tiles.slice(1)
	if tool == "road":
		world.place_road(tiles)
	elif tool in ["clear", "unclear"]:
		var a: Vector2i = tiles[0]
		var b: Vector2i = tiles[-1]
		var r := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), (a - b).abs() + Vector2i.ONE)
		var n := world.mark_clear(r, tool == "clear")
		if tool == "clear" and n == 0:
			hud.toast("No trees or rocks there to clear.", "info")
	drag_tiles.clear()
	_preview([])


## An L-shaped road: along the longer side first, then the shorter.
static func road_path(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var d := b - a
	var corner := Vector2i(b.x, a.y) if absi(d.x) >= absi(d.y) else Vector2i(a.x, b.y)
	for seg in [[a, corner], [corner, b]]:
		var p: Vector2i = seg[0]
		var q: Vector2i = seg[1]
		var step := (q - p).sign()
		while true:
			if out.is_empty() or out[-1] != p:
				out.append(p)
			if p == q:
				break
			p += step
	return out


func _preview(tiles: Array) -> void:
	var mm := drag_preview.multimesh
	mm.instance_count = tiles.size()
	for i in tiles.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(tiles[i].x, 0.06, tiles[i].y)))
	drag_preview.material_override = ghost_bad_mat if tool == "unclear" else ghost_ok_mat


# --- selection --------------------------------------------------------------------------

func _select_at(screen: Vector2, t: Vector2i) -> void:
	var p := rig.ground_point(screen)
	var best := -1
	var bd := 0.5
	for c in world.citizens.values():
		var d: float = c.pos.distance_to(Vector2(p.x, p.z))
		if d < bd:
			bd = d
			best = c.id
	if best >= 0:
		selected = -1
		selected_person = best
		view.show_selection(null)
		hud.show_person(best)
		return
	var b := world.building_at(t)
	select(b.id if b else -1)


func select(id: int) -> void:
	selected = id
	selected_person = -1
	view.show_selection(world.buildings.get(id))
	if id >= 0:
		hud.show_building(id)
	else:
		hud.hide_inspector()
