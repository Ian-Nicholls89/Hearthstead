class_name Villager
extends Node3D
## One animated townsperson. The skeleton and animations come from Quaternius's
## Universal Animation Library (CC0, assets/ual); the body is a light low-poly
## villager built here and skinned rigidly to that skeleton, so a hundred of them
## stay cheap on a phone. Clothes, hair, hats and tools vary with sex and job.

const UAL := "res://assets/ual/AnimationLibrary_Godot_Standard.gltf"
const SCALE := 0.34                       # the rig is 1.75 m tall; a house is 2 tiles
const SKIN := [Color(0.94, 0.76, 0.62), Color(0.8, 0.6, 0.45), Color(0.55, 0.38, 0.26)]
const HAIR := [Color(0.25, 0.16, 0.09), Color(0.12, 0.09, 0.07), Color(0.62, 0.42, 0.2), Color(0.85, 0.7, 0.42),
	Color(0.5, 0.2, 0.1)]
const TROUSERS := Color(0.36, 0.27, 0.19)
const BOOTS := Color(0.2, 0.14, 0.1)
const LOOPING := ["Fixing_Kneeling", "Sword_Attack", "Interact", "PickUp_Table", "Push"]

## Clothes and kit for each job: tunic colour, hat, tool.
const LOOKS := {
	"Labourer": [Color(0.62, 0.55, 0.42), "", "sack"],
	"Builder": [Color(0.78, 0.52, 0.2), "cap", "hammer"],
	"Child": [Color(0.55, 0.68, 0.85), "", ""],
	"Gatherer": [Color(0.62, 0.22, 0.38), "", "basket"],
	"Hunter": [Color(0.3, 0.42, 0.22), "hood", "bow"],
	"Fisher": [Color(0.28, 0.45, 0.66), "cap", "rod"],
	"Farmer": [Color(0.82, 0.72, 0.36), "straw", "hoe"],
	"Forester": [Color(0.22, 0.48, 0.24), "hood", "axe"],
	"Herbalist": [Color(0.42, 0.66, 0.38), "", "basket"],
	"Woodcutter": [Color(0.62, 0.36, 0.18), "", "axe"],
	"Blacksmith": [Color(0.32, 0.3, 0.32), "", "hammer"],
	"Tailor": [Color(0.7, 0.25, 0.25), "", ""],
	"Stonecutter": [Color(0.66, 0.66, 0.62), "cap", "pick"],
	"Miner": [Color(0.46, 0.32, 0.26), "cap", "pick"],
	"Trader": [Color(0.78, 0.66, 0.18), "straw", ""],
	"Miller": [Color(0.9, 0.88, 0.82), "cap", "sack"],
	"Baker": [Color(0.95, 0.93, 0.88), "cap", ""],
	"Orchardist": [Color(0.55, 0.62, 0.3), "straw", "basket"],
	"Shepherd": [Color(0.55, 0.45, 0.32), "hood", "rod"],
	"Weaver": [Color(0.5, 0.32, 0.6), "", ""],
	"Teacher": [Color(0.2, 0.25, 0.45), "", ""],
	"Market trader": [Color(0.85, 0.55, 0.2), "straw", "basket"],
	"Glassblower": [Color(0.35, 0.55, 0.6), "", "hammer"],
	"Scholar": [Color(0.15, 0.12, 0.2), "cap", ""],
}

static var _template: Node3D
static var _library: AnimationLibrary
static var _rest := {}                    # bone name -> global rest origin
static var _meshes := {}
static var _material: ShaderMaterial

var skeleton: Skeleton3D
var body: MeshInstance3D
var player: AnimationPlayer
var load_box: MeshInstance3D
var look_key := ""
var anim := ""


static func _load() -> void:
	if _template:
		return
	var scene: Node3D = load(UAL).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	for m in sk.get_children():
		m.free()          # drop the mannequin; our villagers get their own body
	for i in sk.get_bone_count():
		_rest[sk.get_bone_name(i)] = sk.get_bone_global_rest(i).origin
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	_library = AnimationLibrary.new()
	for n in ap.get_animation_list():
		var a: Animation = ap.get_animation(n).duplicate()
		# our villagers have mittens: drop the finger tracks, over half of the work
		for t in range(a.get_track_count() - 1, -1, -1):
			var bone := String(a.track_get_path(t).get_concatenated_subnames())
			if bone.contains("f_") or bone.contains("thumb") or bone == "root" or bone.begins_with("DEF-toe"):
				a.remove_track(t)
		if n in LOOPING:
			a.loop_mode = Animation.LOOP_LINEAR
		_library.add_animation(n, a)
	ap.free()
	_template = scene
	_material = Meshes.material().duplicate()


static func create() -> Villager:
	_load()
	var v := Villager.new()
	var rig: Node3D = _template.get_node("Rig").duplicate()
	rig.scale = Vector3.ONE * SCALE
	v.add_child(rig)
	v.skeleton = rig.get_node("Skeleton3D")
	v.body = MeshInstance3D.new()
	v.body.material_override = _material
	v.skeleton.add_child(v.body)
	v.body.skeleton = NodePath("..")
	v.player = AnimationPlayer.new()
	v.add_child(v.player)
	v.player.root_node = NodePath("..")
	v.player.add_animation_library("", _library)
	# what they carry rides on their back
	var att := BoneAttachment3D.new()
	att.bone_name = "DEF-spine.003"
	v.skeleton.add_child(att)
	v.load_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.32, 0.2)
	v.load_box.mesh = bm
	v.load_box.position = Vector3(0, -0.05, -0.2)
	v.load_box.visible = false
	att.add_child(v.load_box)
	return v


static func material() -> ShaderMaterial:
	_load()
	return _material


## Dress this villager; rebuilds only when the look changes.
func dress(job: String, female: bool, skin_i: int, hair_i: int) -> void:
	var key := "%s|%s|%d|%d" % [job, female, skin_i, hair_i]
	if key == look_key:
		return
	look_key = key
	if not _meshes.has(key):
		_meshes[key] = _build(job, female, SKIN[skin_i % SKIN.size()], HAIR[hair_i % HAIR.size()])
	body.mesh = _meshes[key][0]
	body.skin = _meshes[key][1]


func play(name: String, speed := 1.0) -> void:
	player.speed_scale = speed
	if name == anim:
		return
	anim = name
	player.play(name, 0.2)


func carry(color: Color) -> void:
	if color.a <= 0.0:
		load_box.visible = false
		return
	load_box.visible = true
	var m: StandardMaterial3D = load_box.material_override
	if m == null:
		m = StandardMaterial3D.new()
		load_box.material_override = m
	m.albedo_color = color


# --- the body ---------------------------------------------------------------------------------------

static func _build(job: String, female: bool, skin: Color, hair: Color) -> Array:
	var look: Array = LOOKS.get(job, LOOKS["Labourer"])
	var tunic: Color = look[0]
	var hat: String = look[1]
	var tool: String = look[2]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bones: Array[String] = []
	var bind := func(b: String) -> void:
		var i := bones.find(b)
		if i < 0:
			bones.append(b)
			i = bones.size() - 1
		st.set_bones(PackedInt32Array([i, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	var R: Dictionary = _rest
	var box := func(b: String, c: Vector3, s: Vector3, col: Color) -> void:
		bind.call(b)
		Meshes.box(st, c, s, col)

	# head and hair
	var head: Vector3 = R["DEF-head"]
	box.call("DEF-neck", R["DEF-neck"] + Vector3(0, 0.05, 0), Vector3(0.1, 0.12, 0.1), skin)
	box.call("DEF-head", head + Vector3(0, 0.13, 0.01), Vector3(0.24, 0.27, 0.25), skin)
	box.call("DEF-head", head + Vector3(0, 0.12, 0.135), Vector3(0.05, 0.06, 0.03), skin.darkened(0.08))   # nose
	for x in [-0.055, 0.055]:
		box.call("DEF-head", head + Vector3(x, 0.16, 0.13), Vector3(0.035, 0.035, 0.01), Color(0.1, 0.08, 0.07))
	match hat:
		"straw":
			bind.call("DEF-head")
			Meshes.cylinder(st, head + Vector3(0, 0.27, 0.01), 0.27, 0.025, Color(0.88, 0.76, 0.42), 8)
			Meshes.cylinder(st, head + Vector3(0, 0.29, 0.01), 0.14, 0.09, Color(0.85, 0.72, 0.38), 8, 0.1)
		"hood":
			box.call("DEF-head", head + Vector3(0, 0.2, -0.02), Vector3(0.28, 0.2, 0.29), tunic.darkened(0.15))
			bind.call("DEF-head")
			Meshes.cone(st, head + Vector3(0, 0.3, -0.03), 0.15, 0.14, tunic.darkened(0.15), 6)
		"cap":
			box.call("DEF-head", head + Vector3(0, 0.27, 0.0), Vector3(0.26, 0.08, 0.27), tunic.darkened(0.25))
		_:
			box.call("DEF-head", head + Vector3(0, 0.25, -0.01), Vector3(0.26, 0.08, 0.27), hair)
			box.call("DEF-head", head + Vector3(0, 0.13, -0.11), Vector3(0.26, 0.2, 0.06), hair)
	if female and hat != "hood":
		box.call("DEF-neck", head + Vector3(0, 0.02, -0.12), Vector3(0.22, 0.26, 0.06), hair)

	# body: tunic over three spine segments, a belt, and a hem or skirt
	var hips: Vector3 = R["DEF-hips"]
	box.call("DEF-spine.001", Vector3(0, 1.08, -0.02), Vector3(0.34, 0.16, 0.21), tunic)
	box.call("DEF-spine.002", Vector3(0, 1.23, -0.02), Vector3(0.36, 0.16, 0.22), tunic)
	box.call("DEF-spine.003", Vector3(0, 1.39, -0.02), Vector3(0.42, 0.17, 0.23), tunic.lightened(0.05))
	box.call("DEF-hips", hips + Vector3(0, 0.07, 0.03), Vector3(0.35, 0.05, 0.22), Color(0.3, 0.2, 0.12))
	if job == "Blacksmith":
		box.call("DEF-spine.002", Vector3(0, 1.15, 0.1), Vector3(0.3, 0.38, 0.02), Color(0.3, 0.2, 0.12))
	var hem_h := 0.42 if female else 0.18
	box.call("DEF-hips", hips + Vector3(0, -hem_h / 2.0 + 0.04, 0.03), Vector3(0.37 if not female else 0.42, hem_h, 0.24), tunic.darkened(0.05))

	# arms: sleeves, forearms, hands
	for s in ["L", "R"]:
		var sign := 1.0 if s == "L" else -1.0
		var ua: Vector3 = R["DEF-upper_arm." + s]
		var fa: Vector3 = R["DEF-forearm." + s]
		var hd: Vector3 = R["DEF-hand." + s]
		box.call("DEF-upper_arm." + s, (ua + fa) / 2.0, Vector3(absf(fa.x - ua.x) + 0.02, 0.11, 0.11), tunic)
		box.call("DEF-forearm." + s, (fa + hd) / 2.0, Vector3(absf(hd.x - fa.x), 0.085, 0.085), skin if job != "Blacksmith" else tunic)
		box.call("DEF-hand." + s, hd + Vector3(sign * 0.05, 0, 0.01), Vector3(0.1, 0.08, 0.09), skin)
		# legs
		var th: Vector3 = R["DEF-thigh." + s]
		var sh: Vector3 = R["DEF-shin." + s]
		var ft: Vector3 = R["DEF-foot." + s]
		box.call("DEF-thigh." + s, (th + sh) / 2.0, Vector3(0.14, th.y - sh.y + 0.02, 0.15), TROUSERS)
		box.call("DEF-shin." + s, (sh + ft) / 2.0 + Vector3(0, 0.02, 0), Vector3(0.12, sh.y - ft.y, 0.13), TROUSERS.darkened(0.05))
		box.call("DEF-shin." + s, ft + Vector3(0, 0.08, 0.0), Vector3(0.13, 0.1, 0.14), BOOTS)
		box.call("DEF-foot." + s, ft + Vector3(0, -0.05, 0.06), Vector3(0.12, 0.09, 0.24), BOOTS)

	_tool(st, bind, tool)
	st.index()
	var mesh := st.commit()
	var skin_res := Skin.new()
	var sk: Skeleton3D = _template.get_node("Rig/Skeleton3D")
	for b in bones:
		skin_res.add_named_bind(b, sk.get_bone_global_rest(sk.find_bone(b)).affine_inverse())
	return [mesh, skin_res]


## A tool in the right hand. In the rest pose the right arm points along -X, so a
## handle held in the fist runs along Z.
static func _tool(st: SurfaceTool, bind: Callable, tool: String) -> void:
	if tool == "":
		return
	var h: Vector3 = _rest["DEF-hand.R"] + Vector3(-0.06, 0, 0.0)
	var wood := Color(0.5, 0.34, 0.2)
	var iron := Color(0.55, 0.57, 0.6)
	bind.call("DEF-hand.R")
	match tool:
		"axe", "hammer", "pick", "hoe":
			Meshes.box(st, h + Vector3(0, 0, 0.16), Vector3(0.04, 0.04, 0.6), wood)
			match tool:
				"axe": Meshes.box(st, h + Vector3(0, -0.06, 0.42), Vector3(0.03, 0.16, 0.1), iron)
				"hammer": Meshes.box(st, h + Vector3(0, 0, 0.44), Vector3(0.1, 0.1, 0.16), iron)
				"pick": Meshes.box(st, h + Vector3(0, 0, 0.44), Vector3(0.04, 0.34, 0.05), iron)
				"hoe": Meshes.box(st, h + Vector3(0, -0.07, 0.45), Vector3(0.12, 0.12, 0.03), iron)
		"rod":
			Meshes.box(st, h + Vector3(0, 0.1, 0.4), Vector3(0.03, 0.03, 0.9), wood)
		"bow":
			Meshes.box(st, h + Vector3(0, 0, 0.0), Vector3(0.04, 0.6, 0.04), wood)
			Meshes.box(st, h + Vector3(0, 0.28, 0.05), Vector3(0.03, 0.06, 0.1), wood)
			Meshes.box(st, h + Vector3(0, -0.28, 0.05), Vector3(0.03, 0.06, 0.1), wood)
		"basket":
			Meshes.cylinder(st, h + Vector3(0, -0.26, 0.0), 0.13, 0.16, Color(0.72, 0.56, 0.3), 7, 0.16)
			Meshes.box(st, h + Vector3(0, -0.06, 0.0), Vector3(0.02, 0.2, 0.02), Color(0.6, 0.45, 0.25))
		"sack":
			pass
