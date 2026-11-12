extends SceneTree
## Renders the launcher icon's foreground (a cottage among trees with a villager)
## from the game's own models, on a transparent background, to build/icon_fg.png.
## tools/make_icon.py then composes the icon files.

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r := Node3D.new()
	vp.add_child(r)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.8)
	env.environment.ambient_light_energy = 0.55
	r.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -50, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	r.add_child(sun)
	var mat := Meshes.material()
	# a round patch of meadow to stand on
	var ground := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.15
	cm.bottom_radius = 2.0
	cm.height = 0.3
	cm.radial_segments = 32
	ground.mesh = cm
	ground.position = Vector3(0, -0.15, 0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.58, 0.28)
	ground.material_override = gm
	r.add_child(ground)
	var parts := [["HousesSecondAge1Level1", 0.0, -0.15, 2.1, -20], ["PineTree_2", -1.35, -0.6, 1.0, 0],
		["CommonTree_3", 1.35, -0.75, 1.2, 0], ["PineTree_1", 1.6, 0.4, 0.7, 30], ["Bush_1", -1.25, 0.75, 0.5, 0],
		["Logs", 0.95, 1.0, 0.55, 60]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var m := BuildingArt.model(p[0])
		mi.mesh = m
		mi.material_override = mat
		mi.transform = BuildingArt.place(m, p[1], p[2], p[3], p[4])
		r.add_child(mi)
	var v := Villager.create()
	r.add_child(v)
	v.dress("Woodcutter", false, 0, 0)
	v.position = Vector3(0.15, 0, 1.15)
	v.rotation.y = 0.5
	v.scale = Vector3.ONE * 1.35
	v.play("Idle")
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	r.add_child(cam)
	cam.look_at_from_position(Vector3(4.2, 4.4, 6.5), Vector3(0, 0.75, 0))
	for k in 12:
		await process_frame
	vp.get_texture().get_image().save_png("res://build/icon_fg.png")
	quit()
