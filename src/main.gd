extends Node
## Title screen, then the game. Owns which one is showing.

var game: Game
var menu: Control


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		_demo(args)
		return
	_show_menu()
	var shot := args.find("--shot")
	if shot >= 0:
		for k in 20:
			await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(args[shot + 1])
		get_tree().quit()


func _show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	var layer := CanvasLayer.new()
	add_child(layer)
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.theme = Hud.make_theme()
	layer.add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(440, 0)
	center.add_child(v)
	var t := Hud.label("Hearthstead", 64, Color(0.96, 0.85, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Hud.label("Lead a band of exiles through the seasons.", 22, Hud.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(Control.new())
	if SaveGame.exists():
		v.add_child(Hud.btn("Continue", _continue))
	for d in [["New town - gentle", 0], ["New town - normal", 1], ["New town - harsh", 2]]:
		v.add_child(Hud.btn(d[0], func(): _new(d[1])))
	if OS.get_name() != "Android":
		v.add_child(Hud.btn("Quit", func(): get_tree().quit()))
	var ver := Hud.label("v" + str(ProjectSettings.get_setting("application/config/version")), 16, Hud.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


func _close_menu() -> void:
	if menu:
		menu.get_parent().queue_free()
		menu = null


func _continue() -> void:
	var w := SaveGame.load_world()
	if w == null:
		_new(1)
		return
	_play(w)


func _new(difficulty: int) -> void:
	var w := World.new()
	w.new_game(randi() % 1000000, difficulty)
	_play(w)
	game.hud.show_help()


func _play(w: World) -> void:
	_close_menu()
	game = Game.new()
	add_child(game)
	game.start(w)
	game.exit_to_menu.connect(_show_menu)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game:
			game.save()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and game == null:
		get_tree().quit()


## Screenshot mode for tools/screenshots.sh: --demo <seed> <years> <out.png> [zoom] [yaw]
func _demo(args: Array) -> void:
	var i := args.find("--demo")
	var seed := int(args[i + 1])
	var years := float(args[i + 2])
	var out: String = args[i + 3]
	var w := World.new()
	w.new_game(seed, 1)
	var ap := AutoPlay.new()
	for t in int(years * Defs.YEAR_TICKS):
		ap.act(w)
		w.step()
	_play(w)
	game.set_speed(1)
	if args.size() > i + 4:
		game.rig.dist = float(args[i + 4])
	if args.size() > i + 5:
		game.rig.yaw = float(args[i + 5])
	game.rig._apply()
	var ui := ""
	for a in args:
		if a.begins_with("ui="):
			ui = a.substr(3)
	for k in 5:
		await get_tree().process_frame
	match ui:
		"palette":
			game.hud._open_category("Food")
		"place":
			game.set_tool("house")
		"badplace":
			game.set_tool("quarry")
		"inspect":
			for b in w.buildings.values():
				if b.type == "gatherer":
					game.select(b.id)
		"house":
			for b in w.buildings.values():
				if b.type == "house" and b.built:
					game.select(b.id)
					break
		"person":
			game.selected_person = w.citizens.keys()[0]
			game.hud.show_person(game.selected_person)
		"town":
			game.hud.show_town(0)
		"stock":
			game.hud.show_town(1)
		"years":
			game.hud.show_town(3)
		"help":
			game.hud.show_help()
		"pause":
			game.hud.show_pause()
		"trade":
			w.merchant = {"goods": {"tools": 30, "coats": 20, "fish": 120}, "until": w.tick + 800, "post": -1}
			game.hud.show_trade()
		"road":
			game.set_tool("road")
			var c := Vector2i(w.width / 2, w.height / 2)
			game._preview(Game.road_path(c + Vector2i(3, 4), c + Vector2i(12, 9)))
		"menu":
			game.queue_free()
			game = null
			_show_menu()
	for k in 25:
		await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
