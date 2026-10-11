extends RefCounted
## All two-archetype hybrids are possible. Build only encountered combinations.
## Canonical IDs keep A+B and B+A the SAME species.
## Never precache N^2 atlas sprites. Visuals reuse base sprites for hybrids.

## Hybrid inheritance is anatomical, NOT a second complete monster face.
## Every second parent supplies one recognizable peripheral body feature.
const MutationKit = preload("res://scripts/MutationKit.gd")
const RETIRED = [] # Medic and Laser Larry are active normal monster species.
const FEATURES = {
	"blob": ["cheeks", "tail"], "zoomer": ["fins", "tail"],
	"chonk": ["shell", "cheeks"], "spitter": ["nozzle", "antennae"],
	"kaboomba": ["fuse", "spikes"], "mitosis": ["buds", "cheeks"],
	"mini": ["ears", "buds"], "riot": ["armor", "shoulders"],
	"bull": ["horns", "ears"], "mama": ["crest", "buds"],
	"mortar": ["helmet", "shoulders"], "totem": ["crown", "spikes"],
	"blinky": ["tail", "crest"], "tick": ["legs", "antennae"],
	"goblin": ["ears", "crest"], "ashwing": ["wings", "crest"],
	"mirror": ["crystal", "spikes"], "burrower": ["claws", "ears"],
	"siren": ["megaphone", "fins"], "skitter": ["legs", "antennae"],
	"sapper": ["armor", "helmet"], "lancer": ["horns", "claws"],
	"leech": ["sucker", "tentacles"],
	"nurse": ["cross", "cap"], "larry": ["laser_lens", "spikes"]
}
const TRAIT_NAMES = {
	"horns": "Horned", "ears": "Long-Eared", "antennae": "Whiskered",
	"wings": "Winged", "tail": "Tailed", "shell": "Shellback",
	"cheeks": "Puffy", "spikes": "Spined", "buds": "Budded",
	"armor": "Armored", "shoulders": "Shouldered", "crest": "Crested",
	"helmet": "Helmeted", "crown": "Crowned", "legs": "Spider-Legged",
	"crystal": "Crystal-Spined", "claws": "Clawed", "fins": "Finned",
	"tentacles": "Tentacled", "cap": "Capped", "laser_lens": "Laser-Eyed",
	"nozzle": "Spouting", "fuse": "Fused", "sucker": "Sucking", "megaphone": "Loudmouth", "cross": "Medic"
}

static func retired(id: String) -> bool:
	return id in RETIRED

static func usable(id: String) -> bool:
	if retired(id):
		return false
	if id.begins_with("mix_"):
		var parts = id.trim_prefix("mix_").split("_")
		for name in parts:
			if retired(str(name)):
				return false
	return true

static func traits_for(species: String) -> Array:
	return FEATURES.get(species, ["ears", "tail"])

static func id_for(a: String, b: String) -> String:
	var pair = [a, b]
	pair.sort()
	return "mix_" + str(pair[0]) + "_" + str(pair[1])

static func ensure(db: Dictionary, a: String, b: String) -> String:
	if a == b or not usable(a) or not usable(b) or not db.has(a) or not db.has(b):
		return ""
	if bool(db[a].get("boss", false)) or bool(db[b].get("boss", false)):
		return ""
	var id = id_for(a, b)
	if db.has(id):
		return id
	# Keep parent roles STABLE regardless of random roll order, restored save
	# order or when the same pair was encountered in a different run.
	var parents = [a, b]
	parents.sort()
	# Vary the body donor across pairs; otherwise early-alphabet species
	# dominate the appearance of nearly every sector-40 hybrid.
	if posmod(id.hash(), 2) == 1:
		parents.reverse()
	var primary = str(parents[0])
	var secondary = str(parents[1])
	var first: Dictionary = db[primary]
	var second: Dictionary = db[secondary]
	var one: Dictionary = first.get("look", {})
	var options = traits_for(secondary)
	# Distinct pairs get stable signature parts, while spawned members can
	# display other parts inherited from the SAME secondary archetype.
	var feature = str(options[posmod(id.hash(), options.size())])
	var ca = Color(str(first["color"]))
	var cb = Color(str(second["color"]))
	db[id] = {
		"id": id, "name": str(MutationKit.PAYLOAD_NAMES.get(MutationKit.payload_for(id, secondary), "Mutated")) + " " + str(first["name"]),
		"hp": (float(first["hp"]) + float(second["hp"])) * 0.71,
		"speed": (float(first["speed"]) + float(second["speed"])) * 0.5,
		"dmg": maxf(float(first["dmg"]), float(second["dmg"])),
		"r": maxf(float(first["r"]), float(second["r"])) + 2.0,
		"xp": maxi(int(first["xp"]), int(second["xp"])) + 2,
		"mass": maxf(float(first["mass"]), float(second["mass"])),
		"color": ca.lerp(cb, 0.43).to_html(false), "mix": [primary, secondary],
		"look": {"body": one.get("body", "round"), "face": one.get("face", "normal"),
			"second_color": str(second["color"]), "gear": one.get("gear", []).duplicate(),
			"trait": feature, "trait_options": options.duplicate(),
			"variant": posmod(id.hash(), 4), "mix_parent": secondary}
	}
	return id

## Encounter recipes, NOT an unrestricted random cross-product.
## Normal: reveal one NEW fusion every four sectors from sector 16.
## Hard: reveal one every two sectors, with higher encounter pressure.
## Keep normal enemies dominant so progression is legible; all other pairs
## remain constructible for debug and pre-existing bestiary data only.
const FIRST_FUSION_SECTOR = 16
const NORMAL_FUSION_SPACING = 4
const HARD_FUSION_SPACING = 2
const RECIPES = [
	{"a": "zoomer", "b": "skitter", "name": "Volt Runner", "style": "flank"},
	{"a": "spitter", "b": "sapper", "name": "Toxic Artillery", "style": "mine"},
	{"a": "mirror", "b": "blob", "name": "Glass Slime", "style": "echo"},
	{"a": "burrower", "b": "kaboomba", "name": "Fuse Mole", "style": "mine"},
	{"a": "leech", "b": "zoomer", "name": "Blood Chaser", "style": "flank"},
	{"a": "ashwing", "b": "spitter", "name": "Ember Spore", "style": "echo"},
	{"a": "siren", "b": "mirror", "name": "Siren Echo", "style": "echo"},
	{"a": "riot", "b": "bull", "name": "Bulwark Ram", "style": "mine"},
	{"a": "mortar", "b": "sapper", "name": "Siege Architect", "style": "mine"},
	{"a": "lancer", "b": "skitter", "name": "Needle Hunter", "style": "flank"},
	{"a": "tick", "b": "leech", "name": "Parasite Brood", "style": "brood"},
	{"a": "mama", "b": "chonk", "name": "Brood Bastion", "style": "brood"},
	{"a": "blinky", "b": "mirror", "name": "Parallax Shade", "style": "echo"},
	{"a": "mitosis", "b": "blob", "name": "Bloom Splitter", "style": "brood"},
	{"a": "totem", "b": "riot", "name": "Ward Marshal", "style": "mine"},
	{"a": "burrower", "b": "lancer", "name": "Tunnel Harpoon", "style": "flank"},
	{"a": "ashwing", "b": "kaboomba", "name": "Phoenix Bomb", "style": "mine"},
	{"a": "mama", "b": "mitosis", "name": "Brood Queen", "style": "brood"}
]

static func unlock_sector(index: int, hard_mode: bool = false) -> int:
	return FIRST_FUSION_SECTOR + index * (HARD_FUSION_SPACING if hard_mode else NORMAL_FUSION_SPACING)

static func recipe_id(index: int) -> String:
	var item: Dictionary = RECIPES[index]
	return id_for(str(item["a"]), str(item["b"]))

static func recipe_for_id(kind: String) -> Dictionary:
	for i in range(RECIPES.size()):
		if recipe_id(i) == kind:
			var result: Dictionary = RECIPES[i].duplicate()
			result["normal_sector"] = unlock_sector(i, false)
			result["hard_sector"] = unlock_sector(i, true)
			return result
	return {}

static func unlock_count(sector: int, hard_mode: bool = false) -> int:
	if sector < FIRST_FUSION_SECTOR:
		return 0
	var interval = HARD_FUSION_SPACING if hard_mode else NORMAL_FUSION_SPACING
	return mini(RECIPES.size(), 1 + int((sector - FIRST_FUSION_SECTOR) / interval))

static func encounter_chance(sector: int, hard_mode: bool = false) -> float:
	if sector < FIRST_FUSION_SECTOR:
		return 0.0
	var steps = maxi(0, sector - FIRST_FUSION_SECTOR)
	if hard_mode:
		# Hard becomes deliberately chaotic, without unloading every variant
		# at once. At sector 40 ~46% of regular spawns may be hybrids.
		return minf(0.56, 0.19 + steps * 0.011)
	# Normal encounters begin rarely and grow gradually. 14% at sector 40.
	return minf(0.25, 0.05 + steps * 0.00375)

static func allowed(base: Array, sector: int) -> bool:
	# Unlock no fusions before sector 16. Parental base species must have
	# already debuted, so the player can recognize the ingredients.
	if sector < FIRST_FUSION_SECTOR:
		return false
	var n = 0
	for id in base:
		if usable(str(id)):
			n += 1
	return n >= 2

static func available_recipes(db: Dictionary, base: Array, sector: int, hard_mode: bool = false, limited_totems: bool = false) -> Array:
	var out = []
	if not allowed(base, sector):
		return out
	var count = unlock_count(sector, hard_mode)
	for i in range(count):
		var recipe: Dictionary = RECIPES[i]
		var a = str(recipe["a"])
		var b = str(recipe["b"])
		# The caller supplies PREVIOUS-sector base species to avoid combining
		# a monster in the same sector where it first appears.
		if not base.has(a) or not base.has(b) or not db.has(a) or not db.has(b):
			continue
		if limited_totems and (a == "totem" or b == "totem"):
			continue
		out.append(recipe)
	return out

static func roll(db: Dictionary, base: Array, sector: int, limited_totems: bool = false, recent: Array = [], hard_mode: bool = false) -> String:
	var recipes = available_recipes(db, base, sector, hard_mode, limited_totems)
	if recipes.is_empty():
		return ""
	# A recently unlocked mutation is more likely to be recognized, but the
	# previous recipes still exist. No unrestricted all-pairs RNG.
	var indices: Array = []
	for i in range(recipes.size()):
		var recipe: Dictionary = recipes[i]
		var id = id_for(str(recipe["a"]), str(recipe["b"]))
		if not recent.has(id):
			indices.append(i)
	if indices.is_empty():
		for i in range(recipes.size()):
			indices.append(i)
	var newest = recipes.size() - 1
	var chosen = newest if indices.has(newest) and randf() < 0.42 else int(indices[randi() % indices.size()])
	var picked: Dictionary = recipes[chosen]
	var id = ensure(db, str(picked["a"]), str(picked["b"]))
	if id != "":
		# Authored fusion identity and one deliberate signature action. Raw
		# ensure() still supports the full bestiary/debug cross-product.
		db[id]["name"] = str(picked["name"])
		db[id]["fusion_style"] = str(picked["style"])
	return id
