extends RefCounted
## All two-archetype hybrids are possible. Build only encountered combinations.
## Canonical IDs keep A+B and B+A the SAME species.
## Never precache N^2 atlas sprites. Visuals reuse base sprites for hybrids.

## Hybrid inheritance is anatomical, NOT a second complete monster face.
## Every second parent supplies one recognizable peripheral body feature.
const RETIRED = ["nurse", "larry"]
const FEATURES = {
	"blob": ["cheeks", "tail"], "zoomer": ["ears", "tail"],
	"chonk": ["shell", "cheeks"], "spitter": ["antennae", "spikes"],
	"kaboomba": ["spikes", "tail"], "mitosis": ["buds", "cheeks"],
	"mini": ["ears", "buds"], "riot": ["armor", "shoulders"],
	"bull": ["horns", "ears"], "mama": ["crest", "buds"],
	"mortar": ["helmet", "shoulders"], "totem": ["crown", "spikes"],
	"blinky": ["tail", "crest"], "tick": ["legs", "antennae"],
	"goblin": ["ears", "crest"], "ashwing": ["wings", "crest"],
	"mirror": ["crystal", "spikes"], "burrower": ["claws", "ears"],
	"siren": ["fins", "antennae"], "skitter": ["legs", "antennae"],
	"sapper": ["armor", "helmet"], "lancer": ["horns", "claws"],
	"leech": ["tentacles", "tail"]
}
const TRAIT_NAMES = {
	"horns": "Horned", "ears": "Long-Eared", "antennae": "Whiskered",
	"wings": "Winged", "tail": "Tailed", "shell": "Shellback",
	"cheeks": "Puffy", "spikes": "Spined", "buds": "Budded",
	"armor": "Armored", "shoulders": "Shouldered", "crest": "Crested",
	"helmet": "Helmeted", "crown": "Crowned", "legs": "Spider-Legged",
	"crystal": "Crystal-Spined", "claws": "Clawed", "fins": "Finned",
	"tentacles": "Tentacled"
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
	var first: Dictionary = db[a]
	var second: Dictionary = db[b]
	var one: Dictionary = first.get("look", {})
	var options = traits_for(b)
	# Distinct pairs get stable signature parts, while spawned members can
	# display other parts inherited from the SAME secondary archetype.
	var feature = str(options[posmod(id.hash(), options.size())])
	var ca = Color(str(first["color"]))
	var cb = Color(str(second["color"]))
	db[id] = {
		"id": id, "name": str(TRAIT_NAMES.get(feature, "Mutated")) + " " + str(first["name"]),
		"hp": (float(first["hp"]) + float(second["hp"])) * 0.71,
		"speed": (float(first["speed"]) + float(second["speed"])) * 0.5,
		"dmg": maxf(float(first["dmg"]), float(second["dmg"])),
		"r": maxf(float(first["r"]), float(second["r"])) + 2.0,
		"xp": maxi(int(first["xp"]), int(second["xp"])) + 2,
		"mass": maxf(float(first["mass"]), float(second["mass"])),
		"color": ca.lerp(cb, 0.43).to_html(false), "mix": [a, b],
		"look": {"body": one.get("body", "round"), "face": one.get("face", "normal"),
			"second_color": str(second["color"]), "gear": one.get("gear", []).duplicate(),
			"trait": feature, "trait_options": options.duplicate(),
			"variant": posmod(id.hash(), 4), "mix_parent": b}
	}
	return id

static func allowed(base: Array, sector: int) -> bool:
	# All hybrids unlock after 10 sectors. Both parent species must have appeared
	# in an earlier sector; this guarantees "new basics first, combinations later".
	if sector < 16:
		return false
	var available = 0
	for name in base:
		if usable(str(name)):
			available += 1
	return available >= 2

static func roll(db: Dictionary, base: Array, sector: int, limited_totems: bool = false, recent: Array = []) -> String:
	if not allowed(base, sector):
		return ""
	var options = []
	for name in base:
		if not usable(str(name)) or not db.has(name) or bool(db[name].get("boss", false)):
			continue
		if limited_totems and name == "totem":
			continue
		options.append(name)
	if options.size() < 2:
		return ""
	# Bounded retries discourage the same combination appearing repeatedly.
	# No N² atlas baking or ever-growing catalogue at startup.
	var pick = ""
	for attempt in range(14):
		var first = randi_range(0, options.size() - 1)
		var second = randi_range(0, options.size() - 2)
		if second >= first:
			second += 1
		pick = id_for(str(options[first]), str(options[second]))
		if not recent.has(pick):
			break
	var parts = pick.trim_prefix("mix_").split("_")
	return ensure(db, str(parts[0]), str(parts[1]))
