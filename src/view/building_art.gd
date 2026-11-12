class_name BuildingArt
extends RefCounted
## How each building looks: Quaternius models (CC0, assets/models and assets/nature)
## arranged on the building's footprint and merged into one mesh. Positions are in
## tiles from the footprint's top-left corner; `size` is the widest the model may be.
## Models face +Z, which is where our doors are.

## type -> list of variants; a variant is a list of parts [model, x, z, size, turn°]
const RECIPES := {
	"camp": [[["Tent", 0.95, 0.9, 1.45, 15], ["Cart", 2.25, 1.0, 1.3, -75], ["BonfireLit", 1.55, 2.25, 0.75, 0],
		["CrateStack1", 2.5, 2.35, 0.55, 10], ["Bags", 0.55, 2.35, 0.6, -20], ["Barrel", 2.65, 0.35, 0.32, 0]]],
	# "type@N" is a building's look from era N on: settlement huts, then cottages
	"house@0": [[["HousesFirstAge1Level2", 1.0, 0.95, 1.7, 0]], [["HousesFirstAge2Level3", 1.0, 0.95, 1.85, 0]],
		[["HousesFirstAge3Level3", 1.0, 0.95, 1.8, 0]]],
	"house@1": [[["HousesSecondAge1Level1", 1.0, 0.95, 1.85, 0]], [["HousesSecondAge2Level1", 1.0, 0.95, 1.85, 0]],
		[["HousesFirstAge1Level3", 1.0, 0.95, 1.8, 0]]],
	"house@2": [[["HousesSecondAge1Level3", 1.0, 0.9, 1.75, 0]], [["HousesSecondAge3Level2", 1.0, 1.0, 1.95, 0]],
		[["HousesSecondAge2Level2", 1.0, 1.0, 1.95, 0]]],
	"stone_house": [[["HousesSecondAge3Level1", 1.0, 0.95, 1.85, 0]]],
	"windmill": [[["WindmillSecondAge", 1.0, 1.0, 1.95, 0]]],
	"bakery": [[["HousesSecondAge2Level2", 1.0, 0.95, 1.9, 0], ["Cauldron", 1.75, 1.75, 0.35, 0]]],
	"orchard": [[["Apple_4", 0.75, 0.75, 1.35, 0], ["Apple_4", 2.25, 0.8, 1.3, 70], ["Apple_4", 0.8, 2.2, 1.25, 140],
		["Apple_4", 2.2, 2.25, 1.35, 210]]],
	"pasture": [[["Fence2", 2.0, 0.1, 3.9, 0], ["Fence2", 2.0, 3.9, 3.9, 0], ["Fence2", 0.1, 2.0, 3.9, 90],
		["Fence2", 3.9, 2.0, 3.9, 90], ["Sheep", 1.2, 1.3, 0.75, 30], ["Sheep", 2.7, 1.0, 0.75, -60],
		["Sheep", 1.8, 2.6, 0.75, 120], ["Sheep", 3.0, 2.8, 0.75, 200], ["Hay", 0.7, 3.2, 0.6, 0]]],
	"weaver": [[["HousesFirstAge2Level3", 0.8, 0.8, 1.4, 0], ["MarketStand_2", 1.5, 1.45, 0.9, 0], ["Bags", 1.65, 0.5, 0.4, 0]]],
	"school": [[["TowerHouseSecondAge", 1.5, 1.4, 2.8, 0]]],
	"tavern": [[["Inn", 1.5, 1.45, 2.9, 0]]],
	"market": [[["MarketSecondAgeLevel1", 1.5, 1.5, 2.95, 0]]],
	"stockpile": [[["Fence", 0.75, 0.12, 1.3, 0], ["Fence", 2.25, 0.12, 1.3, 0], ["Fence", 0.12, 1.1, 1.3, 90],
		["Fence", 2.88, 1.1, 1.3, 90]]],
	"barn": [[["StorageFirstAgeLeve3", 1.5, 1.4, 2.85, 0]]],
	"gatherer": [[["HousesFirstAge3Level1", 0.8, 0.8, 1.35, 0], ["BushBerries_1", 1.6, 0.45, 0.65, 30],
		["Bags", 1.55, 1.55, 0.5, 0]]],
	"hunter": [[["ArcheryFirstAgeLevel1", 1.0, 1.0, 1.95, 0]]],
	"fisher": [[["PortFirstAgeLevel1", 1.0, 1.0, 1.95, 0]]],
	"forester": [[["HousesFirstAge1Level3", 0.75, 0.8, 1.35, 0], ["PineTree_1", 1.6, 0.45, 0.45, 0],
		["PineTree_2", 1.75, 0.95, 0.35, 40]]],
	"herbalist": [[["MarketStand_1", 0.75, 0.9, 1.15, 0], ["Flowers", 1.55, 1.45, 0.55, 0], ["Plant_1", 1.5, 0.55, 0.55, 0],
		["Plant_1", 1.75, 0.95, 0.4, 70]]],
	"woodcutter": [[["Sawmill", 1.0, 0.95, 1.95, 0]]],
	"blacksmith": [[["Blacksmith", 1.0, 0.95, 1.95, 0]]],
	"tailor": [[["HousesFirstAge2Level1", 0.75, 0.75, 1.35, 0], ["MarketStand_2", 1.5, 1.45, 0.9, 0]]],
	"quarry": [[["MountainSingle", 1.4, 1.3, 2.3, 30], ["ResourceRock_1", 3.0, 1.0, 1.3, 0], ["ResourceRock_2", 2.9, 2.85, 1.0, 50],
		["RockGroup", 1.9, 2.6, 1.9, 0], ["Crate", 0.6, 3.35, 0.45, 15]]],
	"mine": [[["Mine", 1.5, 1.3, 2.7, 0], ["CrateStack1", 2.6, 2.55, 0.5, -10]]],
	"well": [[["Well", 0.5, 0.5, 0.95, 0]]],
	"chapel": [[["TempleFirstAgeLevel1", 1.5, 1.5, 2.9, 0]]],
	"town_hall": [[["TownCenterFirstAgeLevel3", 1.5, 1.5, 2.95, 0]]],
	"trading_post": [[["MarketFirstAgeLevel2", 1.5, 1.5, 2.95, 0]]],
}

## What sits in a store or waits at a workplace: resource -> [model, units per pile]
const PILES := {
	"logs": ["Logs", 40], "firewood": ["Logs", 60], "stone": ["Rock", 40], "iron": ["Crate", 25],
	"tools": ["Crate", 25], "coats": ["Bags", 25], "hides": ["Bags", 30], "herbs": ["Bags", 30],
	"flour": ["Bags", 30], "bread": ["Crate", 30], "wool": ["Bags", 30], "apples": ["Crate", 30], "mutton": ["Crate", 30],
}

static var _cache := {}
static var _models := {}


static func model(name: String) -> Mesh:
	if not _models.has(name):
		var path := "res://assets/models/%s.res" % name
		if not ResourceLoader.exists(path):
			path = "res://assets/nature/%s.res" % name
		_models[name] = load(path)
	return _models[name]


static func variants(type: String) -> int:
	return RECIPES.get(type, [[]]).size()


## The recipe name for a building in an era: "type@era" if the era has its own look.
static func recipe(type: String, era: int) -> String:
	for e in range(era, -1, -1):
		var k := "%s@%d" % [type, e]
		if RECIPES.has(k):
			return k
	return type


## The merged mesh for one look of a building in an era, or null if it has none.
static func mesh(type: String, variant := 0, era := 9) -> Mesh:
	type = recipe(type, era)
	if not RECIPES.has(type):
		return null
	var vs: Array = RECIPES[type]
	var key := "%s/%d" % [type, variant % vs.size()]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in vs[variant % vs.size()]:
		st.append_from(model(part[0]), 0, place(model(part[0]), part[1], part[2], part[3], part[4]))
	var m := st.commit()
	_cache[key] = m
	return m


## The transform that stands a model on the ground at (x, z), fitted to `size` tiles.
static func place(m: Mesh, x: float, z: float, size: float, turn: float) -> Transform3D:
	var aabb := m.get_aabb()
	var s := size / maxf(aabb.size.x, aabb.size.z)
	var b := Basis(Vector3.UP, deg_to_rad(turn)).scaled(Vector3(s, s, s))
	var c := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
	return Transform3D(b, Vector3(x, 0, z) - b * c)
