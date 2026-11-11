class_name Defs
extends RefCounted
## Every rule and number of the game in one place, so balance changes stay here.

const TICKS_PER_SECOND := 10          # sim ticks per real second at 1x speed
const MONTH_TICKS := 400              # one month = 40 s at 1x
const MONTHS_PER_YEAR := 12
const YEAR_TICKS := MONTH_TICKS * MONTHS_PER_YEAR

const MONTH_NAMES := [
	"Early Spring", "Spring", "Late Spring",
	"Early Summer", "Summer", "Late Summer",
	"Early Autumn", "Autumn", "Late Autumn",
	"Early Winter", "Winter", "Late Winter",
]
## Rough temperature per month; below COLD_BELOW people lose warmth.
const MONTH_TEMP := [4, 9, 13, 17, 21, 20, 15, 9, 3, -3, -7, -3]
const COLD_BELOW := 8
const GROW_MONTHS := [0, 1, 2, 3, 4, 5, 6, 7]   # crops grow in these months
const PLANT_MONTHS := [0, 1, 2, 3]
const HARVEST_MONTHS := [5, 6, 7, 8]
const FROST_MONTH := 9                         # unharvested crops die

# --- tiles -----------------------------------------------------------------
enum Terrain { GRASS, WATER, ROCK, FORD }
enum Feature { NONE, TREE, BOULDER, STONE_DEP, IRON_DEP }

# --- people ----------------------------------------------------------------
const ADULT_AGE := 6.0
const OLD_AGE := 60.0
const MAX_AGE := 85.0
const FERTILE_MIN := 14.0
const FERTILE_MAX := 45.0
const PREGNANCY_MONTHS := 5
const BIRTH_CHANCE := 0.06            # per eligible couple per month

const WALK_SPEED := 0.25              # tiles per tick on grass
const ROAD_SPEED_MUL := 1.6
const FOREST_SPEED_MUL := 0.75
const FORD_SPEED_MUL := 0.5

const FULL_DECAY := 1.0 / 1000.0      # fullness lost per tick
const EAT_BELOW := 0.35
const MEAL_ADULT := 5
const MEAL_CHILD := 3
const WARMTH_DRAIN := 0.0016          # per tick per (COLD_BELOW - temp)/8
const WARM_BELOW := 0.35
const WARM_RATE := 0.02
const SHELTER_MAX_WARMTH := 0.6       # the wagon camp is a poor shelter
const COAT_FACTOR := 0.5
const STARVE_HURT := 0.00125
const FREEZE_HURT := 0.0025
const SICK_HURT := 0.0004
const HEAL_RATE := 0.0005
const TOOL_WEAR := 1.0 / 80.0         # per work action
const COAT_WEAR := 1.0 / 4000.0       # per cold tick
const NO_TOOL_SPEED := 0.5

const CARRY := 10                     # units a person carries
const HAUL_AT := 12                   # a building's stock is hauled at this size
const HOME_FOOD_MAX := 40
const HOME_FOOD_LOW := 12
const HOME_WOOD_MAX := 20
const HOME_WOOD_LOW := 6
const HOME_HERBS_MAX := 4
const WOOD_BURN_COLD := 4             # firewood per house per cold month
const WOOD_BURN_WARM := 1

# --- resources -------------------------------------------------------------
const RES := {
	"logs":      {"name": "Logs", "food": false, "raw": true, "value": 2, "color": Color(0.55, 0.38, 0.2)},
	"stone":     {"name": "Stone", "food": false, "raw": true, "value": 2, "color": Color(0.6, 0.6, 0.62)},
	"iron":      {"name": "Iron", "food": false, "raw": true, "value": 6, "color": Color(0.55, 0.35, 0.3)},
	"firewood":  {"name": "Firewood", "food": false, "raw": false, "value": 2, "color": Color(0.75, 0.5, 0.25)},
	"tools":     {"name": "Tools", "food": false, "raw": false, "value": 14, "color": Color(0.5, 0.55, 0.65)},
	"hides":     {"name": "Hides", "food": false, "raw": false, "value": 4, "color": Color(0.7, 0.55, 0.4)},
	"coats":     {"name": "Coats", "food": false, "raw": false, "value": 12, "color": Color(0.45, 0.3, 0.2)},
	"herbs":     {"name": "Herbs", "food": false, "raw": false, "value": 4, "color": Color(0.35, 0.7, 0.35)},
	"berries":   {"name": "Berries", "food": true, "raw": false, "value": 2, "color": Color(0.7, 0.15, 0.35)},
	"mushrooms": {"name": "Mushrooms", "food": true, "raw": false, "value": 2, "color": Color(0.85, 0.8, 0.65)},
	"venison":   {"name": "Venison", "food": true, "raw": false, "value": 3, "color": Color(0.6, 0.2, 0.15)},
	"fish":      {"name": "Fish", "food": true, "raw": false, "value": 3, "color": Color(0.5, 0.65, 0.8)},
	"wheat":     {"name": "Wheat", "food": true, "raw": false, "value": 2, "color": Color(0.9, 0.78, 0.35)},
	"beans":     {"name": "Beans", "food": true, "raw": false, "value": 2, "color": Color(0.45, 0.6, 0.25)},
}
const FOODS := ["berries", "mushrooms", "venison", "fish", "wheat", "beans"]
const CROPS := ["wheat", "beans"]

# --- buildings -------------------------------------------------------------
## kind decides behaviour; size is in tiles; the door is the tile below the
## middle of the bottom edge (fields have no door - people walk in).
const BUILD := {
	"camp": {"name": "Wagon camp", "kind": "storage", "size": Vector2i(3, 3), "cost": {}, "work": 0,
		"capacity": 1600, "stores": "all", "buildable": false,
		"desc": "Where your people arrived. Stores everything and shelters the homeless, poorly."},
	"road": {"name": "Road", "kind": "road", "size": Vector2i(1, 1), "cost": {}, "work": 0, "cat": "Roads",
		"desc": "People walk faster on roads."},
	"house": {"name": "Wooden house", "kind": "house", "size": Vector2i(2, 2), "cost": {"logs": 16, "stone": 8},
		"work": 190, "residents": 5, "burn": 1.0, "cat": "Housing",
		"desc": "Home for one family. Burns firewood to keep them warm."},
	"stone_house": {"name": "Stone house", "kind": "house", "size": Vector2i(2, 2),
		"cost": {"logs": 10, "stone": 30, "iron": 4}, "work": 390, "residents": 5, "burn": 0.5, "cat": "Housing",
		"desc": "Warmer than wood: half the firewood."},
	"stockpile": {"name": "Stockpile", "kind": "storage", "size": Vector2i(3, 3), "cost": {}, "work": 20,
		"capacity": 1000, "stores": "raw", "cat": "Storage",
		"desc": "Open-air store for logs, stone and iron."},
	"barn": {"name": "Storage barn", "kind": "storage", "size": Vector2i(3, 3), "cost": {"logs": 30, "stone": 20},
		"work": 280, "capacity": 1500, "stores": "goods", "cat": "Storage",
		"desc": "Keeps food, firewood, tools, coats, hides and herbs."},
	"gatherer": {"name": "Gatherer's hut", "kind": "gather", "size": Vector2i(2, 2), "cost": {"logs": 20},
		"work": 160, "workers": 4, "radius": 10, "trip": 80, "yield": {"berries": 15, "mushrooms": 15},
		"cat": "Food", "desc": "Forages berries and mushrooms from the forest around it."},
	"hunter": {"name": "Hunting lodge", "kind": "gather", "size": Vector2i(2, 2), "cost": {"logs": 22, "stone": 6},
		"work": 190, "workers": 3, "radius": 12, "trip": 100, "yield": {"venison": 15}, "extra": {"hides": 1},
		"cat": "Food", "desc": "Hunts deer in the forest for venison and hides."},
	"fisher": {"name": "Fishing dock", "kind": "gather", "size": Vector2i(2, 2), "cost": {"logs": 26, "stone": 4},
		"work": 190, "workers": 4, "radius": 8, "trip": 100, "yield": {"fish": 14}, "needs": "water",
		"cat": "Food", "desc": "Must be built beside water. Fish all year, fewer in winter."},
	"field": {"name": "Crop field", "kind": "field", "size": Vector2i(6, 6), "cost": {}, "work": 30, "workers": 3,
		"cat": "Food", "desc": "Plant in spring, harvest in autumn. Wheat or beans; frost kills what is left."},
	"forester": {"name": "Forester's lodge", "kind": "gather", "size": Vector2i(2, 2), "cost": {"logs": 20, "stone": 6},
		"work": 160, "workers": 4, "radius": 10, "trip": 70, "yield": {"logs": 6},
		"cat": "Industry", "desc": "Fells grown trees for logs and plants saplings."},
	"herbalist": {"name": "Herbalist", "kind": "gather", "size": Vector2i(2, 2), "cost": {"logs": 22, "stone": 6},
		"work": 160, "workers": 2, "radius": 10, "trip": 70, "yield": {"herbs": 3},
		"cat": "Industry", "desc": "Collects herbs that cure illness."},
	"woodcutter": {"name": "Woodcutter", "kind": "process", "size": Vector2i(2, 2), "cost": {"logs": 20, "stone": 10},
		"work": 160, "workers": 2, "input": {"logs": 1}, "output": {"firewood": 3}, "time": 50,
		"cat": "Industry", "desc": "Splits logs into firewood."},
	"blacksmith": {"name": "Blacksmith", "kind": "process", "size": Vector2i(2, 2), "cost": {"logs": 30, "stone": 20},
		"work": 280, "workers": 2, "input": {"iron": 1, "logs": 1}, "output": {"tools": 1}, "time": 150,
		"cat": "Industry", "desc": "Makes tools from iron and logs. Workers without tools work at half speed."},
	"tailor": {"name": "Tailor", "kind": "process", "size": Vector2i(2, 2), "cost": {"logs": 26, "stone": 12},
		"work": 220, "workers": 2, "input": {"hides": 1}, "output": {"coats": 1}, "time": 150,
		"cat": "Industry", "desc": "Sews coats from hides. Coats halve the cold."},
	"quarry": {"name": "Quarry", "kind": "extract", "size": Vector2i(4, 4), "cost": {"logs": 30}, "work": 220,
		"workers": 6, "time": 90, "yield": {"stone": 5}, "extra": {"iron": 0.1}, "needs": "stone_dep",
		"cat": "Industry", "desc": "Build on grey stone ground. Cuts stone, sometimes iron."},
	"mine": {"name": "Iron mine", "kind": "extract", "size": Vector2i(3, 3), "cost": {"logs": 40, "stone": 20},
		"work": 330, "workers": 6, "time": 110, "yield": {"iron": 3}, "extra": {"stone": 0.3}, "needs": "iron_dep",
		"cat": "Industry", "desc": "Build on rust-red ground. Digs iron ore."},
	"well": {"name": "Well", "kind": "decor", "size": Vector2i(1, 1), "cost": {"stone": 12}, "work": 70,
		"radius": 10, "happy": 0.1, "cat": "Town", "desc": "Puts out fires nearby and cheers people up."},
	"chapel": {"name": "Chapel", "kind": "decor", "size": Vector2i(3, 3), "cost": {"logs": 50, "stone": 40, "iron": 10},
		"work": 500, "radius": 16, "happy": 0.25, "cat": "Town", "desc": "Makes the homes around it happier."},
	"town_hall": {"name": "Town hall", "kind": "hall", "size": Vector2i(3, 3), "cost": {"logs": 50, "stone": 50, "iron": 10},
		"work": 500, "cat": "Town", "desc": "Nomads hear of your town and may ask to join."},
	"trading_post": {"name": "Trading post", "kind": "trade", "size": Vector2i(3, 3),
		"cost": {"logs": 60, "stone": 40, "iron": 10}, "work": 500, "workers": 1, "cat": "Town",
		"desc": "Merchants visit to barter. Needs a trader."},
}
const BUILD_ORDER := ["road", "house", "stone_house", "stockpile", "barn", "gatherer", "hunter", "fisher", "field",
	"forester", "woodcutter", "herbalist", "quarry", "mine", "blacksmith", "tailor", "well", "chapel",
	"town_hall", "trading_post"]
const CATEGORIES := ["Roads", "Housing", "Storage", "Food", "Industry", "Town"]

const FIELD_PLANT_TICKS := 15
const FIELD_HARVEST_TICKS := 15
const FIELD_YIELD := 16                # per ripe tile, times fertility
const CROP_GROW := 0.0005              # growth per tick in growing months
const TREE_GROW := 1.0 / (MONTH_TICKS * 18.0)   # a sapling is grown in 1.5 years
const TREE_GROWN := 0.8
const CLEAR_TICKS := {Feature.TREE: 60, Feature.BOULDER: 80}
const CLEAR_YIELD := {Feature.TREE: {"logs": 3}, Feature.BOULDER: {"stone": 4}}


static func month_of(tick: int) -> int:
	return int(tick / MONTH_TICKS) % MONTHS_PER_YEAR


static func year_of(tick: int) -> int:
	return int(tick / YEAR_TICKS) + 1


static func temp_of(tick: int) -> float:
	# blend toward the next month so the cold creeps in rather than snapping
	var m := month_of(tick)
	var f := float(tick % MONTH_TICKS) / MONTH_TICKS
	return lerpf(MONTH_TEMP[m], MONTH_TEMP[(m + 1) % 12], f)


static func season_index(month: int) -> int:
	return int(month / 3)   # 0 spring, 1 summer, 2 autumn, 3 winter


static func gather_season_mul(month: int, res: String) -> float:
	if res == "fish":
		return 0.6 if season_index(month) == 3 else 1.0
	if res == "logs":
		return 1.0
	match season_index(month):
		0: return 0.6 if month == 0 else 1.0
		1: return 1.0
		2: return 0.9
		_: return 0.2


static func date_text(tick: int) -> String:
	return "%s, Year %d" % [MONTH_NAMES[month_of(tick)], year_of(tick)]
