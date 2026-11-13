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
	{"name": "Large town", "desc": "Guilds, a university, printing and a harbour.",
		"milestones": [["pop", 120, "people"], ["building:university", 1, "university"], ["traded", 1500, "worth of goods traded"], ["techs", 6, "Large town techs"]]},
	{"name": "Industrial revolution", "desc": "Coal, steam and brick - and smoke in the sky.",
		"milestones": [["pop", 200, "people"], ["made:coal", 5000, "coal mined"], ["building:station", 1, "railway station"], ["techs", 6, "Industrial techs"]]},
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

	"irrigation": {"name": "Irrigation", "era": 3, "branch": "Food", "cost": 160, "needs": ["crop_rotation"],
		"desc": "Channels from the river: fields yield a fifth more.", "mods": {"field_yield": 1.2}},
	"harbours": {"name": "Harbours", "era": 3, "branch": "Food", "cost": 180, "needs": ["fishing", "trade"],
		"desc": "Harbours with boats; trading ships make merchants call more often.", "build": ["harbour"],
		"mods": {"merchant": 1.5}},
	"granaries": {"name": "Granaries", "era": 3, "branch": "Food", "cost": 150, "needs": [],
		"desc": "Stores hold half as much again; markets reach further.", "mods": {"storage": 1.5, "market_range": 1.3}},
	"guilds": {"name": "Guilds", "era": 3, "branch": "Industry", "cost": 170, "needs": [],
		"desc": "Craft guilds: workshops work a quarter faster.", "mods": {"workshop": 0.75}},
	"glassmaking": {"name": "Glassmaking", "era": 3, "branch": "Industry", "cost": 160, "needs": [],
		"desc": "Glassworks turn stone into glass.", "build": ["glassworks"]},
	"printing": {"name": "Printing", "era": 3, "branch": "Industry", "cost": 200, "needs": ["schooling"],
		"desc": "Books spread ideas: every tech costs a fifth less.", "mods": {"tech_cost": 0.8}},
	"university": {"name": "University", "era": 3, "branch": "Society", "cost": 220, "needs": ["schooling", "glassmaking"],
		"desc": "Universities: scholars add a great deal of knowledge.", "build": ["university"]},
	"banking": {"name": "Banking", "era": 3, "branch": "Society", "cost": 170, "needs": ["markets"],
		"desc": "Better terms with merchants: your goods are worth a quarter more.", "mods": {"trade": 1.25}},
	"aqueducts": {"name": "Aqueducts", "era": 3, "branch": "Society", "cost": 180, "needs": ["masonry"],
		"desc": "Fountain squares bring clean water; illness is rarer.", "build": ["plaza"], "mods": {"illness": 0.7}},
	"theatre": {"name": "Theatre", "era": 3, "branch": "Society", "cost": 160, "needs": ["brewing"],
		"desc": "Theatres lift the whole neighbourhood.", "build": ["theatre"]},

	"fertiliser": {"name": "Fertiliser", "era": 4, "branch": "Food", "cost": 260, "needs": ["irrigation"],
		"desc": "Fields yield a quarter more.", "mods": {"field_yield": 1.25}},
	"mechanised_farming": {"name": "Mechanised farming", "era": 4, "branch": "Food", "cost": 300, "needs": ["steam_power"],
		"desc": "Machines plant and reap: farm work is much quicker.", "mods": {"farm_work": 0.5}},
	"forestry": {"name": "Forestry science", "era": 4, "branch": "Food", "cost": 280, "needs": [],
		"desc": "Managed woods: forests soak up far more smoke, and trees grow faster.", "mods": {"absorb": 1.8, "tree_growth": 1.5}},
	"coal_mining": {"name": "Coal mining", "era": 4, "branch": "Industry", "cost": 250, "needs": ["smithing"],
		"desc": "Coal mines at the foot of the mountains. Coal burns dirty.", "build": ["coal_mine"]},
	"brickmaking": {"name": "Brickmaking", "era": 4, "branch": "Industry", "cost": 260, "needs": ["coal_mining"],
		"desc": "Brickworks, and brick terraces for eight.", "build": ["brickworks", "terrace"]},
	"steelmaking": {"name": "Steelmaking", "era": 4, "branch": "Industry", "cost": 300, "needs": ["coal_mining"],
		"desc": "Steelworks turn iron and coal into steel.", "build": ["steelworks"]},
	"steam_power": {"name": "Steam power", "era": 4, "branch": "Industry", "cost": 320, "needs": ["steelmaking"],
		"desc": "Steam factories make tools by the crate.", "build": ["factory"]},
	"textile_mills": {"name": "Textile mills", "era": 4, "branch": "Industry", "cost": 280, "needs": ["weaving", "coal_mining"],
		"desc": "Mills make coats from wool by the hundred.", "build": ["textile_mill"]},
	"efficient_engines": {"name": "Efficient engines", "era": 4, "branch": "Industry", "cost": 340, "needs": ["steam_power"],
		"desc": "Cleaner, better engines: industry puts out 40% less smoke.", "mods": {"emission": 0.6}},
	"railways": {"name": "Railways", "era": 4, "branch": "Society", "cost": 320, "needs": ["steelmaking"],
		"desc": "Railway stations: merchants by train and new families every spring.", "build": ["station"],
		"mods": {"merchant": 1.5}},
	"sanitation": {"name": "Sanitation", "era": 4, "branch": "Society", "cost": 280, "needs": ["medicine"],
		"desc": "Sewers and hospitals: illness is rarer and nearly always cured.", "build": ["hospital"], "mods": {"illness": 0.8}},
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
