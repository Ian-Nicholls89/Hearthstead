class_name Hud
extends CanvasLayer
## Everything on screen over the valley, built in code: the top bar (date, speed,
## stock), the build bar, the inspector, the town and trade panels, toasts and
## dialogs. Large touch targets throughout.

const CREAM := Color(0.96, 0.91, 0.8)
const DIM := Color(0.75, 0.7, 0.6)
const GOOD := Color(0.55, 0.85, 0.45)
const BAD := Color(1.0, 0.5, 0.4)
const CHIPS := ["food", "firewood", "logs", "stone", "iron", "tools", "coats"]

var game: Game
var world: World
var root: Control
var date_label: Label
var speed_buttons: Array[Button] = []
var pop_label: Label
var chip_labels := {}
var build_bar: HBoxContainer
var palette: PanelContainer
var palette_row: HBoxContainer
var place_bar: PanelContainer
var place_label: Label
var place_button: Button
var inspector: PanelContainer
var insp_box: VBoxContainer
var toasts: VBoxContainer
var progress_button: Button
var mark_button: Button
var modal: Control
var panel_stack: Array[Control] = []
var _category := ""
var _insp_kind := ""
var _insp_id := -1
var _trade_give := {}
var _trade_take := {}


func setup(g: Game) -> void:
	game = g
	world = g.world
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	add_child(root)
	_top_bar()
	_bottom_bar()
	_inspector()
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-260, 130)
	toasts.custom_minimum_size = Vector2(520, 0)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 6)
	root.add_child(toasts)
	refresh()


## True if a screen point is over a panel, so the map should not react to it.
func is_over_ui(p: Vector2) -> bool:
	if modal != null and is_instance_valid(modal):
		return true
	for c in root.get_children():
		if c is Control and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and c.get_global_rect().has_point(p):
			return true
	return false


# --- theme ---------------------------------------------------------------------------

static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.13, 0.11, 0.09, 0.9)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(12)
	panel.border_color = Color(0.45, 0.36, 0.24, 0.9)
	panel.set_border_width_all(2)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	var colors := {"normal": Color(0.3, 0.24, 0.17), "hover": Color(0.38, 0.3, 0.21),
		"pressed": Color(0.6, 0.43, 0.2), "disabled": Color(0.2, 0.17, 0.14), "focus": Color(0, 0, 0, 0)}
	for k in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[k]
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		if k == "focus":
			sb.draw_center = false
		th.set_stylebox(k, "Button", sb)
	var tog := StyleBoxFlat.new()
	tog.bg_color = Color(0.6, 0.43, 0.2)
	tog.set_corner_radius_all(10)
	tog.set_content_margin_all(8)
	tog.content_margin_left = 14
	tog.content_margin_right = 14
	th.set_stylebox("hover_pressed", "Button", tog)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, "Button", CREAM)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	th.set_color("font_color", "Label", CREAM)
	th.set_constant("separation", "HBoxContainer", 8)
	th.set_constant("separation", "VBoxContainer", 8)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = Color(0.6, 0.43, 0.2)
	tab_sel.set_corner_radius_all(8)
	tab_sel.set_content_margin_all(10)
	var tab_un := tab_sel.duplicate()
	tab_un.bg_color = Color(0.3, 0.24, 0.17)
	th.set_stylebox("tab_selected", "TabContainer", tab_sel)
	th.set_stylebox("tab_unselected", "TabContainer", tab_un)
	th.set_stylebox("tab_hovered", "TabContainer", tab_un)
	var empty := StyleBoxEmpty.new()
	th.set_stylebox("panel", "TabContainer", empty)
	th.set_color("font_selected_color", "TabContainer", CREAM)
	th.set_color("font_unselected_color", "TabContainer", DIM)
	return th


static func btn(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(min_w, 56)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func label(text: String, size := 22, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- top bar --------------------------------------------------------------------------------

func _top_bar() -> void:
	var left := PanelContainer.new()
	left.position = Vector2(8, 8)
	root.add_child(left)
	var h := HBoxContainer.new()
	left.add_child(h)
	h.add_child(btn("Menu", show_pause, 0))
	date_label = label("", 20)
	date_label.custom_minimum_size = Vector2(200, 0)
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(date_label)
	for i in Game.SPEEDS.size():
		var t := "II" if i == 0 else "%dx" % Game.SPEEDS[i]
		var b := btn(t, func(): game.set_speed(i), 52)
		b.toggle_mode = true
		speed_buttons.append(b)
		h.add_child(b)
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-8, 8)
	root.add_child(right)
	var flow := HBoxContainer.new()
	right.add_child(flow)
	var pb := Button.new()
	pb.flat = true
	pb.focus_mode = Control.FOCUS_NONE
	pb.pressed.connect(show_town)
	pop_label = label("", 22)
	pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(pop_label)
	pb.custom_minimum_size = Vector2(80, 56)
	pop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.add_child(pb)
	for k in CHIPS:
		var chip := Button.new()
		chip.flat = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func(): show_town(1))
		chip.custom_minimum_size = Vector2(66, 56)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		var name: String = "Food" if k == "food" else Defs.RES[k].name
		var col: Color = Defs.RES[k].color if k != "food" else Color(0.85, 0.65, 0.35)
		var t := label(name, 15, col.lightened(0.25))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := label("0", 21)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		v.add_child(n)
		chip.add_child(v)
		chip_labels[k] = n
		flow.add_child(chip)


# --- bottom bar -----------------------------------------------------------------------------

func _bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(8, -8)
	root.add_child(panel)
	build_bar = HBoxContainer.new()
	panel.add_child(build_bar)
	for cat in Defs.CATEGORIES:
		var b := btn(cat, func(): _open_category(cat), 0)
		b.toggle_mode = true
		b.set_meta("cat", cat)
		build_bar.add_child(b)
	var tools := PanelContainer.new()
	tools.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.position = Vector2(-8, -8)
	root.add_child(tools)
	var th := HBoxContainer.new()
	tools.add_child(th)
	for t in [["Clear", "clear"], ["Remove", "demolish"]]:
		var b := btn(t[0], func(): _toggle_tool(t[1]))
		b.toggle_mode = true
		b.set_meta("tool", t[1])
		th.add_child(b)
	th.add_child(btn("Town", show_town))
	progress_button = btn("Progress", show_progress, 170)
	progress_button.add_theme_font_size_override("font_size", 17)
	th.add_child(progress_button)
	palette = PanelContainer.new()
	palette.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	palette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	palette.position = Vector2(8, -96)
	palette.visible = false
	root.add_child(palette)
	palette_row = HBoxContainer.new()
	palette.add_child(palette_row)
	place_bar = PanelContainer.new()
	place_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	place_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	place_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	place_bar.position = Vector2(0, -96)
	place_bar.visible = false
	root.add_child(place_bar)
	var pv := HBoxContainer.new()
	place_bar.add_child(pv)
	place_label = label("", 20)
	place_label.custom_minimum_size = Vector2(360, 0)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pv.add_child(place_label)
	place_button = btn("Build here", game.confirm_place, 150)
	pv.add_child(place_button)
	mark_button = btn("Unmark instead", func(): game.set_tool("unclear" if game.tool == "clear" else "clear"), 170)
	pv.add_child(mark_button)
	pv.add_child(btn("Done", func(): game.set_tool(""), 110))


func _toggle_tool(t: String) -> void:
	_category = ""
	palette.visible = false
	game.set_tool("" if game.tool == t else t)


func _open_category(cat: String) -> void:
	if _category == cat:
		_category = ""
		palette.visible = false
		refresh()
		return
	_category = cat
	game.set_tool("")
	for c in palette_row.get_children():
		c.queue_free()
	for type in Defs.BUILD_ORDER:
		var d: Dictionary = Defs.BUILD[type]
		if d.get("cat", "") != cat:
			continue
		var cost := _cost_text(d.cost)
		var open := world.unlocked(type)
		var sub: String = cost if open else "needs " + Progress.TECHS[Progress.tech_for(type)].name
		var b := btn("%s\n%s" % [d.name, sub], func(): _pick(type), 150)
		b.add_theme_font_size_override("font_size", 19)
		if not open:
			b.modulate = Color(1, 1, 1, 0.5)
		b.custom_minimum_size = Vector2(160, 80)
		b.tooltip_text = d.desc
		palette_row.add_child(b)
	palette.visible = true
	palette.reset_size()
	refresh()


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "free"
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [cost[k], Defs.RES[k].name.to_lower()])
	return ", ".join(parts)


func _pick(type: String) -> void:
	palette.visible = false
	_category = ""
	if not world.unlocked(type):
		toast("%s needs %s. Research it in Progress." % [Defs.BUILD[type].name, Progress.TECHS[Progress.tech_for(type)].name], "info")
		show_progress()
		return
	game.set_tool(type)
	toast(Defs.BUILD[type].desc, "info")


# --- refresh -------------------------------------------------------------------------------------

func refresh() -> void:
	if world == null:
		return
	date_label.text = Defs.date_text(world.tick)
	for i in speed_buttons.size():
		speed_buttons[i].set_pressed_no_signal(i == game.speed_i)
	var p := world.population()
	pop_label.text = "People\n%d" % p.total
	pop_label.add_theme_font_size_override("font_size", 19)
	for k in CHIPS:
		var n := world.food_total() if k == "food" else world.stock(k)
		chip_labels[k].text = _short(n)
		var low := false
		match k:
			"food": low = n < p.total * 15
			"firewood": low = n < p.total * 3 and world.month() >= 5
			"tools": low = n < 2
			"coats": low = n < 2
		chip_labels[k].add_theme_color_override("font_color", BAD if low else CREAM)
	for b in build_bar.get_children():
		b.set_pressed_no_signal(b.get_meta("cat") == _category)
	for b in _tool_buttons():
		b.set_pressed_no_signal(b.get_meta("tool") == game.tool or (b.get_meta("tool") == "clear" and game.tool == "unclear"))
	var t := game.tool
	place_bar.visible = t != ""
	mark_button.visible = t in ["clear", "unclear"]
	mark_button.text = "Unmark instead" if t == "clear" else "Mark instead"
	_refresh_progress_button()
	if Defs.BUILD.has(t) and t != "road":
		place_button.visible = true
		place_button.disabled = game.ghost_reason != ""
		var d: Dictionary = Defs.BUILD[t]
		place_label.text = "%s (%s). Tap to move, tap it again to build." % [d.name, _cost_text(d.cost)] \
			if game.ghost_reason == "" else game.ghost_reason
		place_label.add_theme_color_override("font_color", CREAM if game.ghost_reason == "" else BAD)
	else:
		place_button.visible = false
		place_label.add_theme_color_override("font_color", CREAM)
		match t:
			"road": place_label.text = "Drag to lay a road, or tap a tile."
			"clear": place_label.text = "Drag over trees and rocks to clear them."
			"unclear": place_label.text = "Drag to unmark tiles."
			"demolish": place_label.text = "Tap a building or road to remove it."
	if inspector.visible:
		_fill_inspector()


func _tool_buttons() -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is PanelContainer and c.get_child_count() > 0 and c.get_child(0) is HBoxContainer:
			for b in c.get_child(0).get_children():
				if b is Button and b.has_meta("tool"):
					out.append(b)
	return out


static func _short(n: int) -> String:
	if n >= 10000:
		return "%dk" % (n / 1000)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


# --- toasts ------------------------------------------------------------------------------------------

func toast(text: String, kind := "info") -> void:
	if toasts == null:
		return
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 20, {"good": GOOD, "bad": BAD, "death": BAD, "birth": Color(0.7, 0.85, 1.0)}.get(kind, CREAM))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(500, 0)
	p.add_child(l)
	toasts.add_child(p)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# --- inspector ---------------------------------------------------------------------------------------

func _inspector() -> void:
	inspector = PanelContainer.new()
	inspector.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inspector.position = Vector2(-8, 96)
	inspector.custom_minimum_size = Vector2(380, 0)
	inspector.visible = false
	root.add_child(inspector)
	insp_box = VBoxContainer.new()
	inspector.add_child(insp_box)


func show_building(id: int) -> void:
	_insp_kind = "building"
	_insp_id = id
	inspector.visible = true
	_fill_inspector(true)


func show_person(id: int) -> void:
	_insp_kind = "person"
	_insp_id = id
	inspector.visible = true
	_fill_inspector(true)


func hide_inspector() -> void:
	inspector.visible = false
	_insp_kind = ""


var _insp_sig := ""


func _fill_inspector(force := false) -> void:
	var lines: Array = []
	var buttons: Array = []
	var title := ""
	if _insp_kind == "building":
		var b: Building = world.buildings.get(_insp_id)
		if b == null:
			hide_inspector()
			return
		title = b.title()
		_building_lines(b, lines, buttons)
	elif _insp_kind == "person":
		var c: Citizen = world.citizens.get(_insp_id)
		if c == null:
			hide_inspector()
			return
		title = c.name()
		_person_lines(c, lines)
	var sig := title + "|" + "\n".join(lines) + "|" + str(buttons.map(func(x): return x[0]))
	if sig == _insp_sig and not force:
		return
	_insp_sig = sig
	for ch in insp_box.get_children():
		ch.queue_free()
	var head := HBoxContainer.new()
	var tl := label(title, 26)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(btn("X", func(): game.select(-1), 56))
	insp_box.add_child(head)
	for l in lines:
		var lab := label(l, 20, DIM if l.begins_with("  ") else CREAM)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(350, 0)
		insp_box.add_child(lab)
	for row in buttons:
		if row[0] == "workers":
			var b: Building = world.buildings[_insp_id]
			var h := HBoxContainer.new()
			h.add_child(btn("-", func(): world.set_wanted(b.id, b.wanted - 1); _fill_inspector(true), 64))
			var l := label("Workers %d / %d" % [b.workers.size(), b.wanted], 22)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(l)
			h.add_child(btn("+", func(): world.set_wanted(b.id, b.wanted + 1); _fill_inspector(true), 64))
			insp_box.add_child(h)
		elif row[0] == "crop":
			var b: Building = world.buildings[_insp_id]
			var h := HBoxContainer.new()
			for cr in Defs.CROPS:
				var cb := btn(Defs.RES[cr].name, func(): world.set_crop(b.id, cr); _fill_inspector(true), 120)
				cb.toggle_mode = true
				cb.set_pressed_no_signal(b.crop == cr)
				h.add_child(cb)
			insp_box.add_child(h)
		else:
			insp_box.add_child(btn(row[0], row[1]))


func _building_lines(b: Building, lines: Array, buttons: Array) -> void:
	var d := b.def()
	if not b.built:
		lines.append("Under construction: %d%%" % int(100.0 * b.progress / maxf(1.0, b.work)))
		var need: Array = []
		for k in b.needed:
			if b.needed[k] > 0:
				need.append("%d %s" % [b.needed[k], Defs.RES[k].name.to_lower()])
		lines.append("  Still needs: " + (", ".join(need) if not need.is_empty() else "nothing - just builders"))
		if world.builders_wanted == 0:
			lines.append("You have no builders. Add some in Town.")
	else:
		lines.append("  " + d.desc)
	if b.fire > 0:
		lines.append("ON FIRE!")
	match b.kind():
		"house":
			if b.built:
				var who: Array = []
				for rid in b.residents:
					var c: Citizen = world.citizens.get(rid)
					if c:
						who.append("%s (%d)" % [c.first, int(c.age)])
				lines.append("Home to: " + (", ".join(who) if not who.is_empty() else "nobody yet"))
				var food := 0
				for f in Defs.FOODS:
					food += b.inv.get(f, 0)
				lines.append("  Food %d, firewood %d, herbs %d" % [food, b.inv.get("firewood", 0), b.inv.get("herbs", 0)])
				if not b.warm:
					lines.append("Cold - no firewood!")
		"storage":
			if b.built:
				lines.append("Holding %d of %d" % [b.stock_total(), b.capacity()])
				var ks := b.inv.keys()
				ks.sort_custom(func(x, y): return b.inv[x] > b.inv[y])
				var parts: Array = []
				for k in ks.slice(0, 8):
					parts.append("%s %d" % [Defs.RES[k].name, b.inv[k]])
				if not parts.is_empty():
					lines.append("  " + ", ".join(parts))
		"field":
			if b.built:
				var planted := 0
				var ripe := 0
				for v in b.field:
					if v >= 0.0:
						planted += 1
					if v >= 1.0:
						ripe += 1
				lines.append("Crop: %s. Planted %d of %d, ripe %d" % [Defs.RES[b.crop].name.to_lower(), planted, b.field.size(), ripe])
				buttons.append(["crop"])
	if b.built and b.max_workers() > 0:
		buttons.append(["workers"])
		var stock: Array = []
		for k in b.inv:
			stock.append("%s %d" % [Defs.RES[k].name, b.inv[k]])
		if not stock.is_empty():
			lines.append("  Waiting to be carried: " + ", ".join(stock))
		if b.kind() == "process":
			var ins: Array = []
			for k in d.input:
				ins.append("%s %d" % [Defs.RES[k].name, b.input.get(k, 0)])
			lines.append("  Materials here: " + ", ".join(ins))
		if b.kind() == "gather" and b.type != "fisher" and b.type != "forester":
			lines.append("  Forest around it: %d%%" % int(b.forest * 100))
		if b.type == "hunter":
			lines.append("  Deer left: %d%%" % int(b.game * 100))
	if b.type == "trading_post" and b.built:
		if world.merchant.is_empty():
			lines.append("No merchant visiting.")
		else:
			lines.append("A merchant is here until %s." % Defs.MONTH_NAMES[Defs.month_of(world.merchant.until)])
			buttons.append(["Trade", show_trade])
	if b.type != "camp":
		buttons.append(["Remove", func(): confirm("Remove the %s?" % b.title().to_lower(),
			"Half of what went into it comes back.", func(): world.demolish(b.id); game.select(-1))])


func _person_lines(c: Citizen, lines: Array) -> void:
	lines.append("%s, age %d. %s" % [world.job_name(c), int(c.age), "Pregnant" if c.pregnant > 0 else ""])
	lines.append("  " + c.doing)
	lines.append("Health %d%%  Food %d%%  Warmth %d%%" % [int(c.health * 100), int(c.full * 100), int(c.warmth * 100)])
	lines.append("Happiness %d%%%s" % [int(c.happy * 100), "  - ill" if c.sick else ""])
	lines.append("  Tool %s, coat %s" % ["yes" if c.tool > 0 else "none", "yes" if c.coat > 0 else "none"])
	var h: Building = world.buildings.get(c.home)
	lines.append("  " + ("Lives in a %s" % h.title().to_lower() if h else "Homeless"))
	var p: Citizen = world.citizens.get(c.partner)
	if p:
		lines.append("  Partner: " + p.first)


# --- panels and dialogs --------------------------------------------------------------------------

func modal_open() -> bool:
	return modal != null and is_instance_valid(modal) and modal.get_meta("pauses", false)


func close_top() -> bool:
	if modal != null and is_instance_valid(modal):
		if modal.get_meta("closable", true):
			modal.queue_free()
			modal = null
		return true
	if palette.visible:
		palette.visible = false
		_category = ""
		return true
	return false


func _modal(title: String, pauses := true, closable := true, width := 620.0) -> VBoxContainer:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.set_meta("pauses", pauses)
	shade.set_meta("closable", closable)
	root.add_child(shade)
	modal = shade
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := label(title, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _close() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null


func _text(v: VBoxContainer, text: String, color := CREAM, size := 21) -> void:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)


func confirm(title: String, text: String, yes: Callable) -> void:
	var v := _modal(title)
	_text(v, text, DIM)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("Yes", func(): _close(); yes.call(), 160))
	h.add_child(btn("No", _close, 160))
	v.add_child(h)


func ask_nomads(n: int) -> void:
	var v := _modal("Nomads", true, false)
	_text(v, "%d nomads have heard of your town and ask to settle. They bring nothing but their hands - and maybe sickness." % n)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("Welcome them", func(): _close(); world.answer_nomads(true), 220))
	h.add_child(btn("Turn them away", func(): _close(); world.answer_nomads(false), 220))
	v.add_child(h)


func show_game_over() -> void:
	if modal != null and is_instance_valid(modal) and modal.get_meta("over", false):
		return
	var v := _modal("Hearthstead is empty", true, false)
	modal.set_meta("over", true)
	_text(v, "Your town lasted until %s. %d were born and %d died." % [Defs.date_text(world.tick), world.born_total, world.died_total])
	SaveGame.delete()
	v.add_child(btn("Back to the menu", func(): game.exit_to_menu.emit()))


func show_pause() -> void:
	var v := _modal("Paused")
	_text(v, "%s - %d people" % [Defs.date_text(world.tick), world.citizens.size()], DIM)
	v.add_child(btn("Carry on", _close))
	v.add_child(btn("How to play", show_help))
	v.add_child(btn("Save", func(): game.save(); toast("Saved.", "good"); _close()))
	v.add_child(btn("Save and leave", func(): game.save(); _close(); game.exit_to_menu.emit()))


func show_help() -> void:
	var v := _modal("How to play", true, true, 760)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 420)
	v.add_child(sc)
	var l := label(HELP, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(690, 0)
	sc.add_child(l)
	v.add_child(btn("Got it", _close))


const HELP := """Your people have nothing but a wagon of supplies. Keep them fed and warm through the winters and the town will grow.

Moving around: drag with one finger to look around, pinch to zoom, twist two fingers to turn.

Building: pick a category at the bottom left, then a building. Tap the ground to move it and tap it again to build. Builders carry the materials over and put it up. Buildings can be placed before you have the materials - they will wait.

People: everyone eats and needs a warm home in winter. Houses burn firewood. A family in a house will have children, who grow up to work after six years.

Work: workplaces take labourers automatically. Tap a building to set how many work there. Anyone not assigned is a labourer who hauls goods and clears land. Set the number of builders in Town.

The first year: build a gatherer's hut near the forest, a woodcutter, a forester, and houses before winter. Then hunters, fishers, fields, a quarry and a storage barn.

Later: tools wear out (blacksmith, which needs iron from a mine), coats wear out (tailor, which needs hides from hunters), illness needs herbs, and fires need wells nearby. A town hall brings nomads; a trading post brings merchants.

Clear: drag over trees and rocks to have labourers cut them for logs and stone."""


func show_town(tab := 0) -> void:
	var v := _modal("Town", false, true, 720)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 440)
	v.add_child(tabs)
	# people
	var pv := VBoxContainer.new()
	pv.name = "People"
	tabs.add_child(pv)
	var p := world.population()
	pv.add_child(label("%d people: %d adults, %d children. %d homeless, %d ill." % [p.total, p.adults, p.children, p.homeless, p.sick], 21))
	var bh := HBoxContainer.new()
	bh.add_child(btn("-", func(): world.set_builders(world.builders_wanted - 1); show_town(0), 64))
	var bl := label("Builders: %d" % world.builders_wanted, 22)
	bl.custom_minimum_size = Vector2(200, 0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bh.add_child(bl)
	bh.add_child(btn("+", func(): world.set_builders(world.builders_wanted + 1); show_town(0), 64))
	pv.add_child(bh)
	var jobs := world.profession_counts()
	var keys := jobs.keys()
	keys.sort_custom(func(a, b): return jobs[a] > jobs[b])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	for k in keys:
		grid.add_child(label(k, 20, DIM))
		grid.add_child(label(str(jobs[k]), 20))
	pv.add_child(grid)
	# stock
	var sv := GridContainer.new()
	sv.name = "Stock"
	sv.columns = 4
	sv.add_theme_constant_override("h_separation", 30)
	tabs.add_child(sv)
	for k in Defs.RES:
		sv.add_child(label(Defs.RES[k].name, 20, Defs.RES[k].color.lightened(0.3)))
		sv.add_child(label(str(world.stock(k)), 20))
	# log
	var sc := ScrollContainer.new()
	sc.name = "News"
	tabs.add_child(sc)
	var lv := VBoxContainer.new()
	sc.add_child(lv)
	var evs := world.events_log.slice(maxi(0, world.events_log.size() - 40))
	evs.reverse()
	for e in evs:
		var l := label("%s: %s" % [Defs.date_text(e.tick), e.text], 18,
			{"good": GOOD, "bad": BAD, "death": BAD}.get(e.kind, CREAM))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(640, 0)
		lv.add_child(l)
	# stats
	var st := VBoxContainer.new()
	st.name = "Years"
	tabs.add_child(st)
	st.add_child(label("Year %d. Born %d, died %d." % [Defs.year_of(world.tick), world.born_total, world.died_total], 21))
	var graph := HistoryGraph.new()
	graph.history = world.history
	graph.custom_minimum_size = Vector2(640, 300)
	st.add_child(graph)
	tabs.current_tab = tab
	v.add_child(btn("Close", _close))


# --- progress ---------------------------------------------------------------------------------------

func _refresh_progress_button() -> void:
	if progress_button == null:
		return
	var era_name: String = Progress.ERAS[world.era].name
	if world.researching != "":
		var t: Dictionary = Progress.TECHS[world.researching]
		var pct := int(100.0 * world.research.get(world.researching, 0.0) / float(t.cost))
		progress_button.text = "%s\n%s %d%%" % [era_name, t.name, pct]
		progress_button.add_theme_color_override("font_color", CREAM)
	elif _available_techs().is_empty():
		progress_button.text = "%s\nProgress" % era_name
		progress_button.add_theme_color_override("font_color", CREAM)
	else:
		progress_button.text = "%s\nChoose research" % era_name
		progress_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))


func _available_techs() -> Array:
	return Progress.TECHS.keys().filter(func(id): return world.tech_state(id) == "available")


func show_progress() -> void:
	var v := _modal("Progress", true, true, 1000)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(960, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.custom_minimum_size = Vector2(930, 0)
	sc.add_child(body)
	var era: Dictionary = Progress.ERAS[world.era]
	body.add_child(label("Era %d of %d: %s" % [world.era + 1, Progress.ERAS.size(), era.name], 26))
	var d := label(era.desc, 19, DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(d)
	var ms := world.milestones()
	if not ms.is_empty():
		body.add_child(label("To reach the %s era:" % Progress.ERAS[world.era + 1].name, 22))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 40)
		for m in ms:
			var done: bool = m.have >= m.need
			grid.add_child(label(("Done: " if done else "") + m.text, 20, GOOD if done else CREAM))
			grid.add_child(label("%d / %d" % [mini(m.have, m.need), m.need], 20, GOOD if done else DIM))
		body.add_child(grid)
	elif world.era < Progress.ERAS.size() - 1:
		body.add_child(label("The road to the %s era comes in a later update." % Progress.ERAS[world.era + 1].name, 20, DIM))
	var line := "Knowledge: +%.1f a month from your people." % world.knowledge_rate()
	if world.researching != "":
		var t: Dictionary = Progress.TECHS[world.researching]
		line += " Researching %s: %d / %d." % [t.name, int(world.research.get(world.researching, 0.0)), t.cost]
	elif world.knowledge >= 1.0:
		line += " %d banked - choose a tech below." % int(world.knowledge)
	body.add_child(label(line, 20))
	for e in range(0, mini(world.era + 2, Progress.ERAS.size())):
		var ids: Array = Progress.TECHS.keys().filter(func(id): return int(Progress.TECHS[id].era) == e)
		if ids.is_empty():
			continue
		body.add_child(label("%s techs%s" % [Progress.ERAS[e].name, "" if e <= world.era else " (next era)"], 23, Color(0.96, 0.85, 0.6)))
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 12)
		for branch in Progress.BRANCHES:
			var col := VBoxContainer.new()
			col.custom_minimum_size = Vector2(300, 0)
			col.add_child(label(branch, 18, DIM))
			for id in ids:
				if Progress.TECHS[id].branch == branch:
					col.add_child(_tech_card(id))
			cols.add_child(col)
		body.add_child(cols)
	v.add_child(btn("Close", _close))


func _tech_card(id: String) -> Button:
	var t: Dictionary = Progress.TECHS[id]
	var state := world.tech_state(id)
	var note := ""
	match state:
		"done": note = "Learned"
		"researching": note = "Researching %d / %d" % [int(world.research.get(id, 0.0)), t.cost]
		"available": note = "Tap to research - %d knowledge" % t.cost
		"needs": note = "Needs " + ", ".join(t.needs.map(func(n): return Progress.TECHS[n].name))
		"era": note = "In the %s era" % Progress.ERAS[int(t.era)].name
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 112)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = "%s\n%s\n%s" % [t.name, t.desc, note]
	b.add_theme_font_size_override("font_size", 17)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.bg_color = {"done": Color(0.22, 0.36, 0.2), "researching": Color(0.6, 0.43, 0.2),
		"available": Color(0.3, 0.24, 0.17)}.get(state, Color(0.18, 0.16, 0.14))
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, sb)
	if state in ["needs", "era"]:
		b.add_theme_color_override("font_color", Color(0.6, 0.56, 0.5))
	if state in ["available", "researching"]:
		b.pressed.connect(func():
			world.start_research(id)
			toast("Researching %s." % t.name, "info")
			show_progress())
	return b


func show_new_era(e: int) -> void:
	var v := _modal("A new era: %s" % Progress.ERAS[e].name, true, true, 700)
	_text(v, Progress.ERAS[e].desc)
	var new_techs: Array = Progress.TECHS.keys().filter(func(id): return int(Progress.TECHS[id].era) == e)
	if not new_techs.is_empty():
		_text(v, "New to research: " + ", ".join(new_techs.map(func(id): return Progress.TECHS[id].name)) + ".", DIM, 19)
	var rebuilt := {1: "Your huts are being rebuilt as timber-framed houses.",
		2: "Your houses are being rebuilt taller, on stone footings."}
	if rebuilt.has(e):
		_text(v, rebuilt[e], DIM, 19)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("See the tech tree", show_progress, 240))
	h.add_child(btn("Carry on", _close, 160))
	v.add_child(h)


func show_trade() -> void:
	if world.merchant.is_empty():
		return
	_trade_give = {}
	_trade_take = {}
	_fill_trade()


func _fill_trade() -> void:
	var v := _modal("Merchant", true, true, 880)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	v.add_child(cols)
	var give_v := 0
	var take_v := 0
	for k in _trade_give:
		give_v += _trade_give[k] * int(Defs.RES[k].value)
	for k in _trade_take:
		take_v += _trade_take[k] * int(Defs.RES[k].value)
	for side in ["take", "give"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(400, 0)
		cols.add_child(col)
		col.add_child(label("They offer" if side == "take" else "You give", 24))
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(400, 300)
		col.add_child(sc)
		var list := VBoxContainer.new()
		sc.add_child(list)
		var src: Dictionary = world.merchant.goods if side == "take" else world.totals
		var chosen: Dictionary = _trade_take if side == "take" else _trade_give
		for k in src:
			if src[k] <= 0:
				continue
			var h := HBoxContainer.new()
			var l := label("%s (%d)" % [Defs.RES[k].name, src[k]], 19)
			l.custom_minimum_size = Vector2(190, 0)
			h.add_child(l)
			var have: int = src[k]
			h.add_child(btn("-", func(): chosen[k] = maxi(0, chosen.get(k, 0) - 10); _fill_trade(), 52))
			var q := label(str(chosen.get(k, 0)), 20)
			q.custom_minimum_size = Vector2(54, 0)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(q)
			h.add_child(btn("+", func(): chosen[k] = mini(have, chosen.get(k, 0) + 10); _fill_trade(), 52))
			list.add_child(h)
	_text(v, "Worth: you give %d, you get %d" % [give_v, take_v], GOOD if give_v >= take_v and take_v > 0 else DIM)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := btn("Trade", func():
		if world.trade(_trade_give, _trade_take):
			_close()
		, 160)
	go.disabled = not (give_v >= take_v and take_v > 0)
	h.add_child(go)
	h.add_child(btn("Close", _close, 160))
	v.add_child(h)
