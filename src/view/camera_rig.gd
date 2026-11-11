class_name CameraRig
extends Node3D
## Orbit camera over the valley. Touch: one finger pans, two fingers pinch to
## zoom and twist to turn. Mouse: left-drag pans, right-drag turns, wheel zooms.
## A short touch without much movement is a tap, reported through `tapped`.

signal tapped(screen_pos: Vector2)
signal drag_started(screen_pos: Vector2)
signal dragged(screen_pos: Vector2)
signal drag_ended(screen_pos: Vector2)

const MIN_DIST := 7.0
const MAX_DIST := 75.0
const TAP_MOVE := 14.0
const TAP_TIME := 350

var cam: Camera3D
var yaw := 0.6
var pitch := deg_to_rad(52.0)
var dist := 26.0
var target := Vector3.ZERO
var bounds := Rect2(0, 0, 96, 96)
## When true, single-finger drags are sent out (for roads, clearing) instead of panning.
var tool_drag := false
## Returns true for screen points covered by the HUD; touches starting there are ignored.
var blocked: Callable = func(_p): return false

var _touches := {}           # index -> position
var _start := {}             # index -> {pos, time}
var _pinch_d := 0.0
var _pinch_a := 0.0
var _pinch_mid := Vector2.ZERO
var _dragging_tool := false
var _mouse_left := false
var _mouse_right := false
var _mouse_start := Vector2.ZERO
var _mouse_time := 0


func _init() -> void:
	cam = Camera3D.new()
	cam.fov = 45
	cam.near = 0.3
	cam.far = 400
	add_child(cam)
	_apply()


func focus(p: Vector3) -> void:
	target = p
	_apply()


func _apply() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	dist = clampf(dist, MIN_DIST, MAX_DIST)
	# lower the camera a little when zoomed in, for a better look at the town
	var p := pitch - (1.0 - (dist - MIN_DIST) / (MAX_DIST - MIN_DIST)) * deg_to_rad(12.0)
	var off := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
	cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), target + off)


## The point on the ground under a screen position.
func ground_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return target
	var t := -o.y / d.y
	return o + d * t


func ground_tile(screen: Vector2) -> Vector2i:
	var p := ground_point(screen)
	return Vector2i(int(floor(p.x)), int(floor(p.z)))


func _pan(from: Vector2, to: Vector2) -> void:
	var a := ground_point(from)
	var b := ground_point(to)
	target += a - b
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_touch(e)
	elif e is InputEventScreenDrag:
		_drag(e)
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_button(e)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_motion(e)
	elif e is InputEventMagnifyGesture:
		dist /= e.factor
		_apply()
	elif e is InputEventPanGesture:
		target += Vector3(e.delta.x, 0, e.delta.y).rotated(Vector3.UP, yaw) * dist * 0.02
		_apply()


func _touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if blocked.call(e.position):
			return
		_touches[e.index] = e.position
		_start[e.index] = {"pos": e.position, "time": Time.get_ticks_msec()}
		if _touches.size() == 2:
			_begin_pinch()
			if _dragging_tool:
				_dragging_tool = false
				drag_ended.emit(e.position)
		get_viewport().set_input_as_handled()
		return
	if not _touches.has(e.index):
		return
	var s: Dictionary = _start.get(e.index, {})
	_touches.erase(e.index)
	_start.erase(e.index)
	if _dragging_tool and _touches.is_empty():
		_dragging_tool = false
		drag_ended.emit(e.position)
	elif not s.is_empty() and _touches.is_empty() and s.pos.distance_to(e.position) < TAP_MOVE \
			and Time.get_ticks_msec() - s.time < TAP_TIME:
		tapped.emit(e.position)
	if _touches.size() == 2:
		_begin_pinch()
	get_viewport().set_input_as_handled()


func _begin_pinch() -> void:
	var ps: Array = _touches.values()
	_pinch_d = ps[0].distance_to(ps[1])
	_pinch_a = (ps[1] - ps[0]).angle()
	_pinch_mid = (ps[0] + ps[1]) * 0.5


func _drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var old: Vector2 = _touches[e.index]
	_touches[e.index] = e.position
	if _touches.size() == 1:
		var s: Dictionary = _start[e.index]
		if tool_drag:
			if not _dragging_tool and s.pos.distance_to(e.position) > TAP_MOVE:
				_dragging_tool = true
				drag_started.emit(s.pos)
			if _dragging_tool:
				dragged.emit(e.position)
		else:
			_pan(old, e.position)
	elif _touches.size() >= 2:
		var ps: Array = _touches.values().slice(0, 2)
		var d: float = ps[0].distance_to(ps[1])
		var a: float = (ps[1] - ps[0]).angle()
		var mid: Vector2 = (ps[0] + ps[1]) * 0.5
		if _pinch_d > 1.0 and d > 1.0:
			dist *= _pinch_d / d
		yaw -= wrapf(a - _pinch_a, -PI, PI)
		_apply()
		_pan(_pinch_mid, mid)
		_pinch_d = d
		_pinch_a = a
		_pinch_mid = mid
	get_viewport().set_input_as_handled()


func _mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
			_apply()
		MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
			_apply()
		MOUSE_BUTTON_LEFT:
			_mouse_left = e.pressed
			if e.pressed:
				_mouse_start = e.position
				_mouse_time = Time.get_ticks_msec()
			else:
				if _dragging_tool:
					_dragging_tool = false
					drag_ended.emit(e.position)
				elif _mouse_start.distance_to(e.position) < TAP_MOVE:
					tapped.emit(e.position)
		MOUSE_BUTTON_RIGHT:
			_mouse_right = e.pressed
	get_viewport().set_input_as_handled()


func _mouse_motion(e: InputEventMouseMotion) -> void:
	if _mouse_right:
		yaw -= e.relative.x * 0.008
		pitch = clampf(pitch - e.relative.y * 0.005, deg_to_rad(25), deg_to_rad(80))
		_apply()
	elif _mouse_left:
		if tool_drag:
			if not _dragging_tool and _mouse_start.distance_to(e.position) > TAP_MOVE:
				_dragging_tool = true
				drag_started.emit(_mouse_start)
			if _dragging_tool:
				dragged.emit(e.position)
		else:
			_pan(e.position - e.relative, e.position)
