class_name Progress
extends RefCounted
## Eras, milestones and the tech tree (see docs/PROGRESSION.md). Only data and pure
## helpers live here; the state (era, techs, knowledge) is kept on the World.

const ERAS := [
	{"name": "Settlement", "desc": "A handful of exiles, wooden huts and whatever the forest gives.",
		"milestones": [["pop", 20, "people"], ["houses", 5, "houses"], ["winters", 2, "winters survived"], ["techs", 3, "Settlement techs"]]},
	{"name": "Village", "desc": "Timber-framed houses, tiled roofs, fields and the first trade.",
		"milestones": [["pop", 40, "people"], ["crops", 1500, "crops harvested"], ["building:trading_post", 1, "trading post"], ["techs", 5, "Village techs"]]},
	{"name": "Small town", "desc": "Stone houses, bread and wool, markets and faith.",
		"milestones": [["pop", 70, "people"], ["building:stone_house", 8, "stone houses"], ["made:bread", 1000, "bread baked"], ["techs", 6, "Small town techs"]]},
	{"name": "Large town", "desc": "Guilds, a university, printing and a harbour.", "milestones": []},
	{"name": "Industrial revolution", "desc": "Coal, steam and brick - and smoke in the sky.", "milestones": []},
	{"name": "City", "desc": "Electric light, trams and hospitals.", "milestones": []},
	{"name": "Modern", "desc": "Cars, computers and a choice about the planet.", "milestones": []},
	{"name": "Utopia", "desc": "Fusion, automation and the stars.", "milestones": []},
]

## id: name, era, branch, cost (knowledge), needs, what it does in words, and
## its effects: "build" lists buildings it unlocks, "mods" multiplies rules.
const TECHS := {
	"agriculture": {"name": "Agriculture", "era": 0, "branch": "Food", "cost": 20, "needs": [],
		"desc": "Crop fields of wheat or beans.", "build": ["field"]},
	"fishing": {"name": "Fishing", "era": 0, "branch": "Food", "cost": 15, "needs": [],
		"desc": "Fishing docks by the water.", "build": ["fisher"]},
	"stonework": {"name": "Stonework", "era": 0, "branch": "Industry", "cost": 25, "needs": [],
		"desc": "Quarries and storage barns.", "build": ["quarry", "barn"]},
	"hide_working": {"name": "Hide working", "era": 0, "branch": "Industry", "cost": 20, "needs": [],
		"desc": "Tailors sew coats from hides.", "build": ["tailor"]},
	"herb_lore": {"name": "Herb lore", "era": 0, "branch": "Society", "cost": 20, "needs": [],
		"desc": "Herbalists gather herbs that cure illness.", "build": ["herbalist"]},

	"crop_rotation": {"name": "Crop rotation", "era": 1, "branch": "Food", "cost": 55, "needs": ["agriculture"],
		"desc": "Fields yield a quarter more.", "mods": {"field_yield": 1.25}},
	"husbandry": {"name": "Animal husbandry", "era": 1, "branch": "Food", "cost": 50, "needs": [],
		"desc": "Deer recover twice as fast; hunters bring more hides.", "mods": {"game": 2.0, "hides": 1.6}},
	"smithing": {"name": "Smithing", "era": 1, "branch": "Industry", "cost": 60, "needs": [],
		"desc": "Iron mines and blacksmiths.", "build": ["mine", "blacksmith"]},
	"better_tools": {"name": "Better tools", "era": 1, "branch": "Industry", "cost": 55, "needs": ["smithing"],
		"desc": "Tools last over twice as long.", "mods": {"tool_wear": 0.4}},
	"masonry": {"name": "Masonry", "era": 1, "branch": "Industry", "cost": 70, "needs": ["stonework"],
		"desc": "Stone houses and chapels; fires spread less.", "build": ["stone_house", "chapel"], "mods": {"fire": 0.5}},
	"medicine": {"name": "Medicine", "era": 1, "branch": "Society", "cost": 50, "needs": ["herb_lore"],
		"desc": "Illness 40% rarer, and herbs cure more surely.", "mods": {"illness": 0.6, "cure": 1.15}},
	"trade": {"name": "Trade", "era": 1, "branch": "Society", "cost": 60, "needs": [],
		"desc": "Trading posts. Word spreads and merchants visit far more often.", "build": ["trading_post"],
		"mods": {"merchant": 2.0}},
	"town_planning": {"name": "Town planning", "era": 1, "branch": "Society", "cost": 70, "needs": [],
		"desc": "Town halls bring nomads; roads are faster still.", "build": ["town_hall"], "mods": {"road": 1.2}},

	"milling": {"name": "Milling", "era": 2, "branch": "Food", "cost": 100, "needs": ["agriculture"],
		"desc": "Windmills grind wheat into flour.", "build": ["windmill"]},
	"baking": {"name": "Baking", "era": 2, "branch": "Food", "cost": 110, "needs": ["milling"],
		"desc": "Bakeries turn flour into bread.", "build": ["bakery"]},
	"orchards": {"name": "Orchards", "era": 2, "branch": "Food", "cost": 90, "needs": [],
		"desc": "Apple orchards.", "build": ["orchard"]},
	"shepherding": {"name": "Shepherding", "era": 2, "branch": "Food", "cost": 100, "needs": ["husbandry"],
		"desc": "Sheep pastures for wool and mutton.", "build": ["pasture"]},
	"weaving": {"name": "Weaving", "era": 2, "branch": "Industry", "cost": 100, "needs": ["shepherding"],
		"desc": "Weavers make coats from wool; woollen coats keep out more cold.", "build": ["weaver"],
		"mods": {"cold": 0.85}},
	"paving": {"name": "Paving", "era": 2, "branch": "Industry", "cost": 90, "needs": ["masonry"],
		"desc": "Roads are laid with stone and are quicker to walk.", "mods": {"road": 1.25}},
	"faith": {"name": "Faith", "era": 2, "branch": "Society", "cost": 100, "needs": ["masonry"],
		"desc": "Chapels lift spirits far more.", "mods": {"chapel": 1.6}},
	"schooling": {"name": "Schooling", "era": 2, "branch": "Society", "cost": 120, "needs": [],
		"desc": "Schools: teachers add to the town's knowledge.", "build": ["school"]},
	"brewing": {"name": "Brewing", "era": 2, "branch": "Society", "cost": 100, "needs": [],
		"desc": "Taverns make the homes around them happier.", "build": ["tavern"]},
	"markets": {"name": "Markets", "era": 2, "branch": "Society", "cost": 120, "needs": ["trade"],
		"desc": "Markets carry food and firewood to nearby homes.", "build": ["market"]},
}
const BRANCHES := ["Food", "Industry", "Society"]

## Buildings open from the start; the rest come from techs.
const START_BUILDINGS := ["camp", "road", "house", "stockpile", "gatherer", "hunter", "woodcutter", "forester", "well"]


static func tech_for(building: String) -> String:
	for id in TECHS:
		if building in TECHS[id].get("build", []):
			return id
	return ""


static func knowledge_rate(adults: int) -> float:
	return 2.0 + 0.25 * adults
