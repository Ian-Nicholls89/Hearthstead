extends SceneTree
## Renders a line-up of villagers in different jobs and animations to build/villagers.png.

func _initialize() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.4
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.46, 0.2)
	ground.material_override = gm
	root3.add_child(ground)
	var setups := [["Farmer", false, "Walk"], ["Gatherer", true, "Fixing_Kneeling"], ["Woodcutter", false, "Sword_Attack"],
		["Hunter", false, "Idle"], ["Builder", true, "Interact"], ["Child", false, "Jog_Fwd"], ["Fisher", true, "Idle"],
		["Blacksmith", false, "Sword_Attack"], ["Miner", false, "Walk"], ["Herbalist", true, "Walk"]]
	var i := 0
	for s in setups:
		var v := Villager.create()
		root3.add_child(v)
		v.dress(s[0], s[1], i % 3, i % 5)
		v.position = Vector3((i % 5) * 0.55 - 1.1, 0, (i / 5) * 0.8)
		if s[0] == "Child":
			v.scale = Vector3.ONE * 0.7
		v.rotation.y = 0.5
		v.play(s[2])
		if i == 8:
			v.carry(Color(0.6, 0.6, 0.62))
		i += 1
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.3, 2.9)
	root3.add_child(cam)
	cam.look_at(Vector3(0, 0.25, 0.4))
	for k in 40:
		await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/villagers.png")
	quit()
