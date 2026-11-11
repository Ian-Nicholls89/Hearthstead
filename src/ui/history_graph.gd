class_name HistoryGraph
extends Control
## Population (cream) and food stored (orange) month by month.

var history: Array = []


func _draw() -> void:
	var r := Rect2(Vector2(40, 10), size - Vector2(50, 40))
	draw_rect(r, Color(1, 1, 1, 0.05))
	if history.size() < 2:
		draw_string(get_theme_default_font(), r.position + Vector2(10, 30), "Check back after a few months.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.75, 0.65))
		return
	var max_pop := 1.0
	var max_food := 1.0
	for h in history:
		max_pop = maxf(max_pop, h.pop)
		max_food = maxf(max_food, h.food)
	for pair in [["food", max_food, Color(0.9, 0.6, 0.25)], ["pop", max_pop, Color(0.96, 0.91, 0.8)]]:
		var pts := PackedVector2Array()
		for i in history.size():
			var x: float = r.position.x + r.size.x * i / (history.size() - 1)
			var y: float = r.end.y - r.size.y * float(history[i][pair[0]]) / pair[1]
			pts.append(Vector2(x, y))
		draw_polyline(pts, pair[2], 3.0, true)
	var f := get_theme_default_font()
	draw_string(f, Vector2(r.position.x, r.end.y + 26), "People (up to %d)" % int(max_pop), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.96, 0.91, 0.8))
	draw_string(f, Vector2(r.position.x + 260, r.end.y + 26), "Food (up to %d)" % int(max_food), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.6, 0.25))
