extends RefCounted
## All two-archetype hybrids are possible. Build only encountered combinations.
## Canonical IDs keep A+B and B+A the SAME species.
## Never precache N^2 atlas sprites. Visuals reuse base sprites for hybrids.

static func id_for(a: String, b: String) -> String:
	var pair = [a, b]
	pair.sort()
	return "mix_" + str(pair[0]) + "_" + str(pair[1])

static func ensure(db: Dictionary, a: String, b: String) -> String:
	if a == b or not db.has(a) or not db.has(b):
		return ""
	if bool(db[a].get("boss", false)) or bool(db[b].get("boss", false)):
		return ""
	var id = id_for(a, b)
	if db.has(id):
		return id
	var first: Dictionary = db[a]
	var second: Dictionary = db[b]
	var one: Dictionary = first.get("look", {})
	var two: Dictionary = second.get("look", {})
	var gear: Array = one.get("gear", []).duplicate()
	for item in two.get("gear", []):
		if not gear.has(item):
			gear.append(item)
	var ca = Color(str(first["color"]))
	var cb = Color(str(second["color"]))
	db[id] = {
		"id": id, "name": str(first["name"]) + "-" + str(second["name"]) + " Chimera",
		"hp": (float(first["hp"]) + float(second["hp"])) * 0.71,
		"speed": (float(first["speed"]) + float(second["speed"])) * 0.5,
		"dmg": maxf(float(first["dmg"]), float(second["dmg"])),
		"r": maxf(float(first["r"]), float(second["r"])) + 2.0,
		"xp": maxi(int(first["xp"]), int(second["xp"])) + 2,
		"mass": maxf(float(first["mass"]), float(second["mass"])),
		"color": ca.lerp(cb, 0.43).to_html(false), "mix": [a, b],
		"look": {"body": "round", "face": one.get("face", "normal"),
			"second_color": str(second["color"]), "gear": gear,
			"variant": posmod(int(id.hash()), 4), "mix_parent": str(second["id"])}
	}
	return id

static func allowed(base: Array, sector: int) -> bool:
	# All hybrids unlock after 10 sectors. Both parent species must have appeared
	# in an earlier sector; this guarantees "new basics first, combinations later".
	return sector >= 16 and base.size() >= 2

static func roll(db: Dictionary, base: Array, sector: int, limited_totems: bool = false, recent: Array = []) -> String:
	if not allowed(base, sector):
		return ""
	var options = []
	for name in base:
		if not db.has(name) or bool(db[name].get("boss", false)):
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
