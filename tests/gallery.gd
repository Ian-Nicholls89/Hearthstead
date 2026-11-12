extends SceneTree
## Renders every mesh in DIR (default res://build/gallery) in a labelled grid, each
## standing on a 1x1 tile with an arrow showing +Z (our "front"), to GALLERY png.
func _initialize() -> void:
	var dir: String = OS.get_environment("DIR") if OS.get_environment("DIR") != "" else "res://build/gallery"
	var names: Array = []
	for f in DirAccess.open(dir).get_files():
		if f.ends_with(".res"):
			names.append(f.get_basename())
	names.sort()
	var cols := 7
	var r := Node3D.new(); root.add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.6, 0.7, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8, 0.8, 0.85); env.environment.ambient_light_energy = 0.45
	r.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -30, 0); r.add_child(sun)
	var cell := 9.0
	for i in names.size():
		var m: Mesh = load("%s/%s.res" % [dir, names[i]])
		var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = Meshes.material()
		var aabb := m.get_aabb()
		var s := 4.0 / maxf(aabb.size.x, maxf(aabb.size.z, aabb.size.y))
		mi.scale = Vector3.ONE * s
		var at := Vector3((i % cols) * cell, 0, (i / cols) * cell)
		mi.position = at - Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z) * s
		r.add_child(mi)
		var arrow := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.15, 0.05, 1.2); arrow.mesh = bm
		var am := StandardMaterial3D.new(); am.albedo_color = Color(1, 0.1, 0.1); arrow.material_override = am
		arrow.position = at + Vector3(0, 0.02, 2.6); r.add_child(arrow)
		var lab := Label3D.new(); lab.text = "%s\n%.1fx%.1fx%.1f" % [names[i], aabb.size.x, aabb.size.z, aabb.size.y]
		lab.font_size = 64; lab.pixel_size = 0.006; lab.position = at + Vector3(0, 0.05, 2.0); lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.modulate = Color.BLACK; lab.outline_size = 0
		r.add_child(lab)
	var rows := ceili(names.size() / float(cols))
	var cam := Camera3D.new(); r.add_child(cam)
	var mid := Vector3((cols - 1) * cell / 2.0, 0, (rows - 1) * cell / 2.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect: float = float(root.size.x) / root.size.y
	cam.size = maxf(rows * cell * 1.2, cols * cell * 1.05 / aspect)
	cam.look_at_from_position(mid + Vector3(0, 60, 50), mid)
	cam.fov = 50
	for k in 6: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("GALLERY") if OS.get_environment("GALLERY") != "" else "/tmp/gallery.png")
	quit()
