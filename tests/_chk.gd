extends SceneTree
func _init():
	for p in ["res://src/view/meshes.gd","res://src/view/world_view.gd","res://src/view/camera_rig.gd","res://src/view/game.gd","res://src/ui/hud.gd","res://src/ui/history_graph.gd","res://src/main.gd"]:
		var s = load(p)
		print(p, " -> ", s != null)
	quit()
