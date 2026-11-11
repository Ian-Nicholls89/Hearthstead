class_name Citizen
extends RefCounted
## One person. Needs drain every tick; `plan` is the queue of steps they are carrying out.

const LABOURER := -1
const BUILDER := -2

var id := 0
var first := ""
var surname := ""
var male := true
var age := 20.0                   # years
var mother := -1
var father := -1
var partner := -1
var home := -1
var job := LABOURER               # workplace id, or LABOURER / BUILDER
var pos := Vector2.ZERO           # tile coordinates, tile centre at +0.5
var path: Array[Vector2i] = []
var plan: Array = []              # steps: {"t": "go", "to": tile} or {"t": "do", "fx": ..., "n": ticks}
var act_left := -1.0
var carry := {}                   # res -> units in hand
var full := 1.0
var warmth := 1.0
var health := 1.0
var happy := 0.6
var sick := false
var tool := 0.0
var coat := 0.0
var pregnant := 0                 # months left
var diet := {}                    # food -> absolute month last eaten
var wait := 0                     # ticks before deciding again
var res_tile := -1                # reserved tile index
var res_haul := -1                # building whose stock is reserved for hauling
var res_haul_n := 0
var res_site := -1                # site expecting our delivery
var res_site_res := ""
var res_site_n := 0
var doing := ""                   # short label for the UI
var arriving := false             # nomads walking in from the edge


func name() -> String:
	return "%s %s" % [first, surname]


func tile() -> Vector2i:
	return Vector2i(int(floor(pos.x)), int(floor(pos.y)))


func is_adult() -> bool:
	return age >= Defs.ADULT_AGE


func carrying() -> int:
	var n := 0
	for k in carry:
		n += carry[k]
	return n


func to_dict() -> Dictionary:
	return {"id": id, "first": first, "surname": surname, "male": male, "age": age, "mother": mother,
		"father": father, "partner": partner, "home": home, "job": job, "pos": [pos.x, pos.y], "carry": carry,
		"full": full, "warmth": warmth, "health": health, "happy": happy, "sick": sick, "tool": tool,
		"coat": coat, "pregnant": pregnant, "diet": diet, "arriving": arriving}


static func from_dict(d: Dictionary) -> Citizen:
	var c := Citizen.new()
	c.id = int(d.id)
	c.first = d.first
	c.surname = d.surname
	c.male = d.male
	c.age = float(d.age)
	c.mother = int(d.mother)
	c.father = int(d.father)
	c.partner = int(d.partner)
	c.home = int(d.home)
	c.job = int(d.job)
	c.pos = Vector2(float(d.pos[0]), float(d.pos[1]))
	c.carry = Building._ints(d.carry)
	c.full = float(d.full)
	c.warmth = float(d.warmth)
	c.health = float(d.health)
	c.happy = float(d.happy)
	c.sick = d.sick
	c.tool = float(d.tool)
	c.coat = float(d.coat)
	c.pregnant = int(d.pregnant)
	c.diet = Building._ints(d.diet)
	c.arriving = d.get("arriving", false)
	return c
