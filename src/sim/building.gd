class_name Building
extends RefCounted
## A placed building: a construction site until `built`, then a home, store or workplace.

var id := 0
var type := ""
var pos := Vector2i.ZERO          # top-left tile
var size := Vector2i.ONE
var door := Vector2i.ZERO         # where people stand to use it
var built := false
var progress := 0.0               # builder work done
var work := 0.0                   # builder work needed
var needed := {}                  # res -> units still to deliver
var incoming := {}                # res -> units on their way
var workers: Array[int] = []
var wanted := 0
var residents: Array[int] = []
var inv := {}                     # storage stock, home pantry or a workplace's output
var input := {}                   # a workshop's raw materials
var haul_reserved := 0
var crop := "wheat"
var field := PackedFloat32Array() # per tile: -1 bare, 0..1 growing, >=1 ripe
var field_busy := PackedByteArray()
var game := 1.0                   # deer left around a hunting lodge
var forest := 0.0                 # 0..1 how wooded its radius is
var fire := 0                     # ticks left burning, 0 = not on fire
var warm := true                  # a house with firewood


func def() -> Dictionary:
	return Defs.BUILD[type]


func kind() -> String:
	return Defs.BUILD[type]["kind"]


func title() -> String:
	return Defs.BUILD[type]["name"]


func max_workers() -> int:
	return int(Defs.BUILD[type].get("workers", 0))


func is_solid() -> bool:
	return kind() != "field" and kind() != "road"


func contains(t: Vector2i) -> bool:
	return t.x >= pos.x and t.y >= pos.y and t.x < pos.x + size.x and t.y < pos.y + size.y


func center() -> Vector2:
	return Vector2(pos) + Vector2(size) * 0.5


func stock_total() -> int:
	var n := 0
	for k in inv:
		n += inv[k]
	return n


func capacity() -> int:
	return int(Defs.BUILD[type].get("capacity", 0))


func accepts(res: String) -> bool:
	if not built or kind() != "storage":
		return false
	var s: String = Defs.BUILD[type]["stores"]
	return s == "all" or (s == "raw") == bool(Defs.RES[res]["raw"])


func space() -> int:
	return capacity() - stock_total()


func materials_ready() -> bool:
	for k in needed:
		if needed[k] > 0:
			return false
	return true


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "pos": [pos.x, pos.y], "built": built, "progress": progress, "work": work,
		"needed": needed, "workers": workers, "wanted": wanted, "residents": residents, "inv": inv,
		"input": input, "crop": crop, "field": Array(field), "game": game, "fire": fire, "warm": warm}


static func from_dict(d: Dictionary) -> Building:
	var b := Building.new()
	b.id = int(d.id)
	b.type = d.type
	b.pos = Vector2i(int(d.pos[0]), int(d.pos[1]))
	b.size = Defs.BUILD[b.type]["size"]
	b.door = World.door_of(b.type, b.pos)
	b.built = d.built
	b.progress = float(d.progress)
	b.work = float(d.work)
	b.needed = _ints(d.needed)
	b.workers.assign(d.workers.map(func(v): return int(v)))
	b.wanted = int(d.wanted)
	b.residents.assign(d.residents.map(func(v): return int(v)))
	b.inv = _ints(d.inv)
	b.input = _ints(d.input)
	b.crop = d.crop
	b.field = PackedFloat32Array(d.field)
	b.field_busy.resize(b.field.size())
	b.game = float(d.game)
	b.fire = int(d.fire)
	b.warm = d.warm
	return b


static func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[k] = int(d[k])
	return o
