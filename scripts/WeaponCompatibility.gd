extends RefCounted
## Weapon resource and modifier contract. All original 22 IDs have an explicit
## capacity and volley budget; overflow converts to modest strength, never a
## second invisible magazine, infinite returning weapons, or unlimited AoE.
const CAPACITY = {
	"pistol": 48, "revolver": 6, "shotgun": 12, "smg": 144,
	"minigun": 320, "sniper": 12, "rocket": 8, "grenade": 12,
	"laser": 1, "tesla": 45, "flame": 300, "disc": 5,
	"boomerang": 3, "rail": 6, "bees": 24, "bowling": 8,
	"nailgun": 160, "chicken": 12, "bubble": 15, "pinball": 48,
	"splitbow": 18, "snow": 24
}
## Maximum entities/hitscan traces emitted by any ordinary trigger, before
## existing global frame and sector safety caps. This protects explosive guns
## from Hydra + multishot + parallel multiplication.
const VOLLEY_BUDGET = {
	"pistol": 12, "revolver": 6, "shotgun": 20, "smg": 12,
	"minigun": 10, "sniper": 6, "rocket": 3, "grenade": 3,
	"laser": 4, "tesla": 4, "flame": 3, "disc": 1,
	"boomerang": 1, "rail": 3, "bees": 10, "bowling": 4,
	"nailgun": 12, "chicken": 4, "bubble": 4, "pinball": 8,
	"splitbow": 6, "snow": 5
}

static func cap(id: String) -> int:
	return int(CAPACITY.get(id, 12))

static func raw_capacity(g, w: Dictionary) -> int:
	var d: Dictionary = g.weapon_db[w["id"]]
	var kind = str(d["kind"])
	if kind == "beam":
		# Not ammo: a virtual capacity unit for the card conversion formula.
		return 1 + maxi(0, roundi(100.0 * maxf(0.0, g.st("mag") + float(w["wm"].get("mag", 0.0)))))
	if kind in ["disc", "boomerang"]:
		return int(d["mag"]) + int(w["wm"].get("mag", 0)) + int(g.st("mult")) + (1 if int(w["lvl"]) >= 3 else 0)
	var n = float(d["mag"]) * (1.0 + g.st("mag") + float(w["wm"].get("mag", 0.0)))
	if str(w["id"]) == "smg" and int(w["lvl"]) >= 3:
		n *= 1.5
	if kind == "flame" and bool(w["evolved"]):
		n *= 1.25
	return maxi(1, roundi(n))

static func capacity(g, w: Dictionary) -> int:
	if str(g.weapon_db[w["id"]]["kind"]) == "beam":
		return 1
	return clampi(raw_capacity(g, w), 1, cap(str(w["id"])))

static func overflow_damage(g, w: Dictionary) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	var raw = raw_capacity(g, w)
	var overflow = maxi(0, raw - cap(str(w["id"])))
	if kind == "beam":
		# Level 5 beam never overheats, so its excess ammo cards must not go dead.
		return minf(0.12, float(overflow) / 100.0 * 0.12)
	var original = maxi(1, int(g.weapon_db[w["id"]]["mag"]))
	return minf(0.18, float(overflow) / float(original) * 0.12)

static func resource_damage_bonus(g, w: Dictionary) -> float:
	var bonus = overflow_damage(g, w)
	var kind = str(g.weapon_db[w["id"]]["kind"])
	if kind == "beam" and int(w["lvl"]) >= 5:
		bonus += minf(0.10, maxf(0.0, g.st("reload")) * 0.10)
	return bonus

static func budget(g, w: Dictionary) -> int:
	return mini(int(VOLLEY_BUDGET.get(str(w["id"]), 8)), g.volley_cap())

static func card_interaction(g, card_id: String) -> String:
	if g.guns.is_empty():
		return ""
	var rows: Array[String] = []
	for w in g.guns:
		var id = str(w["id"])
		var kind = str(g.weapon_db[id]["kind"])
		var note = ""
		match card_id:
			"extended_mag", "drum_mag", "ammo_belt":
				if kind == "beam":
					note = "Heat reserve; excess improves beam damage"
				elif kind in ["disc", "boomerang"]:
					note = "Return slots are fixed; no bonus magazine"
				elif id == "revolver":
					note = "6-round cylinder; excess converts to damage"
				else:
					note = "Capacity capped at %d; overflow improves damage" % cap(id)
			"speed_loader":
				if kind in ["disc", "boomerang"]:
					note = "Faster returning blades"
				elif kind == "beam":
					note = "Faster cooling; at Lv 5, extra beam damage"
				else:
					note = "Faster reload / fuel refill"
			"double_tap", "twin_barrels", "hydra":
				if kind in ["disc", "boomerang"]:
					note = "Real return slots / stronger throws, never phantom blades"
				elif kind == "flame":
					note = "Saturated and wider fire cone, not extra bullets"
				elif kind in ["rocket", "grenade", "chicken"]:
					note = "Up to %d projectiles; overflow is capped damage" % budget(g, w)
				else:
					note = "Up to %d attacks per volley" % budget(g, w)
			"return_sender":
				if kind in ["disc", "boomerang"]:
					note = "Return is inherent; redundant return card is unavailable"
				elif kind in ["rocket", "grenade", "chicken"]:
					note = "Returned payload has a weaker blast"
				elif kind in ["rail", "beam", "chain", "flame"]:
					note = "Not compatible with nonprojectile weapons"
				else:
					note = "Projectile returns once, may hit again"
			"heat_seekers", "smart_rounds":
				if kind in ["beam", "rail", "chain", "flame"]:
					note = "Small aim assist within existing attack geometry"
				elif kind in ["disc", "boomerang"]:
					note = "Outward homing only; return path protected"
				else:
					note = "Physical projectiles home toward enemies"
			"infinite_ammo":
				if kind in ["disc", "boomerang"]:
					note = "Still must retrieve returning weapons"
				elif kind == "beam":
					note = "No overheating"
				else:
					note = "No reload; fire-rate penalty still applies"
		if note != "":
			rows.append(str(g.weapon_db[id]["name"]) + ": " + note)
		if rows.size() >= 2:
			break
	return "  /  ".join(rows)

static func applies_to(g, card_id: String) -> bool:
	if card_id != "return_sender":
		return true
	for w in g.guns:
		var kind = str(g.weapon_db[w["id"]]["kind"])
		if kind not in ["disc", "boomerang", "rail", "beam", "chain", "flame"]:
			return true
	return false
