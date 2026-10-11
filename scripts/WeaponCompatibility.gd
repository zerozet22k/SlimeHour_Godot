extends RefCounted
## Weapon resource and modifier contract. All original 22 IDs have an explicit
## capacity and volley budget; overflow converts to modest strength, never a
## second invisible magazine, infinite returning weapons, or unlimited AoE.
const CAPACITY = {
	"pistol": 24, "revolver": 6, "shotgun": 8, "smg": 90,
	"minigun": 320, "sniper": 8, "rocket": 6, "grenade": 12,
	"laser": 1, "tesla": 30, "flame": 220, "disc": 6,
	"boomerang": 3, "rail": 3, "bees": 16, "bowling": 6,
	"nailgun": 100, "chicken": 10, "bubble": 12, "pinball": 32,
	"splitbow": 12, "snow": 16
}
## Maximum entities/hitscan traces emitted by any ordinary trigger, before
## existing global frame and sector safety caps. This protects explosive guns
## from Hydra + multishot + parallel multiplication.
const VOLLEY_BUDGET = {
	"pistol": 3, "revolver": 3, "shotgun": 14, "smg": 4,
	"minigun": 3, "sniper": 3, "rocket": 3, "grenade": 3,
	"laser": 3, "tesla": 4, "flame": 3, "disc": 1,
	"boomerang": 1, "rail": 3, "bees": 8, "bowling": 3,
	"nailgun": 4, "chicken": 3, "bubble": 3, "pinball": 4,
	"splitbow": 3, "snow": 3
}
## Limits for concurrently simulated physical actors, independent of ammunition
## or projectiles per trigger. No limit is required for hitscan/cone weapons.
const ACTIVE_BUDGET = {
	"bees": 30, "bowling": 5, "chicken": 12, "bubble": 12,
	"pinball": 20, "snow": 10
}
## Overflow always has a weapon-native benefit. Generic damage is reserved for
## precision/return weapons; the remaining IDs improve their signature mechanic.
const OVERFLOW_SPECIALTY = {
	"pistol": "precision", "revolver": "damage", "shotgun": "stagger",
	"smg": "accuracy", "minigun": "spin retention", "sniper": "damage",
	"rocket": "blast radius", "grenade": "banked blast", "laser": "cooling",
	"tesla": "chain reach", "flame": "burn", "disc": "return speed",
	"boomerang": "catch power", "rail": "charge speed", "bees": "poison",
	"bowling": "impact", "nailgun": "pin chance", "chicken": "panic",
	"bubble": "trap durability", "pinball": "bank damage",
	"splitbow": "fragment tracking", "snow": "freeze"
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
		return int(d["mag"]) + int(w["wm"].get("mag", 0)) + int(g.st("mult")) + roundi(float(d["mag"]) * maxf(0.0, g.st("mag"))) + (1 if int(w["lvl"]) >= 3 else 0)
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

static func overflow_fraction(g, w: Dictionary) -> float:
	var extra = maxi(0, raw_capacity(g, w) - cap(str(w["id"])))
	return minf(1.0, float(extra) / float(maxi(1, int(g.weapon_db[w["id"]]["mag"]))))

static func resource_damage_bonus(g, w: Dictionary) -> float:
	var id = str(w["id"])
	var extra = overflow_fraction(g, w)
	if id == "revolver":
		return minf(0.18, extra * 0.18)
	if id in ["sniper", "disc", "boomerang"]:
		return minf(0.16, extra * 0.16)
	if id == "laser" and int(w["lvl"]) >= 5:
		# No heat at Lv5: heat/reload cards convert to capped focus damage.
		return minf(0.20, maxf(0.0, g.st("mag")) * 0.08 + maxf(0.0, g.st("reload")) * 0.10)
	return 0.0

static func support_bonus(g, w: Dictionary) -> float:
	# Capped, normalized overflow only; each caller maps the value to its own
	# utility (accuracy, recoil, fuel efficiency, blast, status, etc.).
	return minf(0.25, overflow_fraction(g, w) * 0.25)

static func heat_limit(g) -> float:
	return minf(4.5, 3.0 * (1.0 + maxf(0.0, g.st("mag")) * 0.5))

static func cooling_speed(g) -> float:
	return 1.0 + minf(0.65, maxf(0.0, g.st("reload")) * 0.35)

static func return_speed(g, w: Dictionary) -> float:
	return 1.0 + minf(0.55, maxf(0.0, g.st("reload")) * 0.18 + support_bonus(g, w))

static func active_cap(id: String) -> int:
	return int(ACTIVE_BUDGET.get(id, 0))

static func budget(g, w: Dictionary) -> int:
	return mini(int(VOLLEY_BUDGET.get(str(w["id"]), 8)), g.volley_cap())

## Projectile travel is not universal: wavy/snaking cards control REAL
## trajectory on moving actors, small attack sweep on hitscan and cone guns.
## Returning discs get to wiggle outward, never while flying home.
static func projectile_wave(g, w: Dictionary) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	var amount = maxf(0.0, g.st("wave"))
	match kind:
		"bees":
			return minf(8.0, amount * 0.15) # preserve pheromone/homing guidance
		"rocket", "grenade", "ball", "chicken", "snow", "bubble":
			return minf(14.0, amount * 0.35) # respect heavy/trap trajectories
		"disc", "boomerang":
			return minf(16.0, amount * 0.50) # outgoing path only
		"beam", "rail", "chain", "flame":
			return 0.0 # translated in the weapon's native instant/area geometry
		_:
			return minf(48.0, amount)

static func projectile_curve(g, w: Dictionary) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	var amount = g.st("curve")
	if kind in ["beam", "rail", "chain", "flame"]:
		return 0.0
	if kind in ["bees", "rocket", "grenade", "ball", "chicken", "snow", "bubble"]:
		return clampf(amount, -0.75, 0.75)
	if kind in ["disc", "boomerang"]:
		return clampf(amount, -1.3, 1.3)
	return clampf(amount, -3.0, 3.0)

static func instant_sway(g, w: Dictionary) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	if kind not in ["beam", "rail", "chain"]:
		return 0.0
	var wave = maxf(0.0, g.st("wave"))
	var curve = absf(g.st("curve"))
	# Oscillating attack direction represents slither/spin; DO NOT create
	# invisible projectiles for lasers, electricity or charge cells.
	var amplitude = minf(0.16, wave * 0.0026 + curve * 0.025)
	if amplitude <= 0.0:
		return 0.0
	return sin(g.run_time * 11.0) * amplitude

static func instant_reach_bonus(g, w: Dictionary) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	if kind in ["beam", "rail", "chain"]:
		# Zoom Zoom Bullets / Scope translate speed into a bounded extension,
		# without a non-existent projectile velocity.
		return minf(0.22, maxf(0.0, g.st("pspeed")) * 0.17)
	return 0.0

static func instant_acceleration(g, w: Dictionary, fraction: float) -> float:
	var kind = str(g.weapon_db[w["id"]]["kind"])
	if kind in ["beam", "rail"]:
		# Road Rage's travel acceleration becomes downrange cutting power.
		return 1.0 + minf(0.22, maxf(0.0, g.st("accel")) * 0.16) * clampf(fraction, 0.0, 1.0)
	return 1.0

static func adapted_pierce(g, w: Dictionary) -> int:
	# Snake Shot's +pierce means another chain hop on lightning, not a
	# non-existent projectile piercing a nonexistent bullet collider.
	if str(g.weapon_db[w["id"]]["kind"]) == "chain":
		return clampi(int(g.st("pierce")), 0, 3)
	return 0

## Arc Caster cannot collide with road walls as a moving projectile.
## Wall-bounce upgrades instead supply at most two extra lightning jumps.
static func adapted_wall_bounce(g, w: Dictionary) -> int:
	if str(g.weapon_db[w["id"]]["kind"]) != "chain":
		return 0
	return mini(2, floori(float(maxi(0, int(g.st("bounce")))) * 0.5))

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
					note = "More heat before overheating, then a stronger beam"
				elif kind in ["disc", "boomerang"]:
					note = "Up to %d in the air at once; beyond that they return faster" % cap(id)
				elif id == "revolver":
					note = "Still 6 shots; the extra becomes bonus damage"
				else:
					note = "Holds up to %d; beyond that it improves %s" % [cap(id), str(OVERFLOW_SPECIALTY.get(id, "weapon handling"))]
			"speed_loader":
				if kind in ["disc", "boomerang"]:
					note = "Throws come back faster"
				elif kind == "beam":
					note = "Cools down faster; at LV5 the beam hits harder"
				else:
					note = "Faster reload and refuel"
			"double_tap", "twin_barrels", "hydra":
				if kind in ["disc", "boomerang"]:
					note = "Stronger throws"
				elif kind == "flame":
					note = "A wider, denser flame cone"
				elif kind in ["rocket", "grenade", "chicken"]:
					note = "Up to %d shots; extras add damage instead" % budget(g, w)
				else:
					note = "Up to %d shots per volley; extras add damage instead" % budget(g, w)
			"snake_shot", "wobbly", "spiral_galaxy":
				if kind == "flame":
					note = "The flame sways; pierce makes it reach farther"
				elif kind == "beam":
					note = "The beam sweeps side to side and passes more enemies"
				elif kind == "rail":
					note = "The rail shot wavers slightly; still one piercing shot"
				elif kind == "chain":
					note = "Lightning wanders and jumps to up to 3 more targets"
				elif kind in ["disc", "boomerang"]:
					note = "Wiggles on the way out, flies straight back"
				elif kind == "bees":
					note = "Bees weave a little but still chase targets"
				elif kind in ["rocket", "grenade", "ball", "chicken", "snow", "bubble"]:
					note = "Heavy shots wobble a little"
				else:
					note = "Shots wiggle in flight and pierce more"
			"rubber_bullets", "pinball_wizard":
				if kind == "flame":
					note = "Flames bounce weaker off walls"
				elif kind in ["beam", "rail"]:
					note = "The beam really reflects off walls"
				elif kind == "chain":
					note = "Lightning redirects to more targets"
				else:
					note = "Shots bounce off walls"
			"muzzle_velocity", "scope":
				if kind in ["beam", "rail", "chain"]:
					note = "Up to +22% reach"
				elif kind == "flame":
					note = "Flames reach a bit farther"
				else:
					note = "Faster shots"
			"accelerator":
				if kind in ["beam", "rail"]:
					note = "The beam hits harder at long range"
				elif kind == "chain":
					note = "Later lightning jumps keep more power"
				elif kind == "flame":
					note = "Flames hit harder at the tip"
				else:
					note = "Shots speed up in flight"
			"piercing", "drill_bits", "armor_piercing", "ghost_rounds":
				if kind == "chain":
					note = "Pierce becomes up to +3 lightning targets"
				elif kind == "flame":
					note = "Pierce makes the flame reach up to 18% farther"
				elif kind in ["beam", "rail"]:
					note = "The beam passes through more enemies"
				else:
					note = "Shots pass through more enemies"
			"ricochet":
				if kind == "flame":
					note = "Some heat jumps to nearby enemies"
				elif kind in ["beam", "rail"]:
					note = "Jumps to another enemy after a hit"
				elif kind == "chain":
					note = "More lightning jumps"
				else:
					note = "Shots bounce to another enemy after a hit"
			"splinter", "cluster_rounds":
				if kind == "flame":
					note = "Embers jump to nearby enemies"
				elif kind in ["beam", "rail"]:
					note = "A few weaker fragments on impact"
				elif kind == "chain":
					note = "Adds extra lightning branches"
				else:
					note = "Shots burst into fragments"
			"return_sender":
				if kind in ["disc", "boomerang"]:
					note = "Already returns on its own"
				elif kind in ["rocket", "grenade", "chicken"]:
					note = "The returning shot blasts weaker"
				elif kind in ["rail", "beam", "chain", "flame"]:
					note = "No effect on this gun"
				else:
					note = "Shots fly back once and can hit again"
			"fan_hammer", "shell_shock", "kazoo":
				note = "Triggers even without reloading" if g.st("infammo") > 0.0 else ("Triggers when you reload" if kind not in ["beam", "disc", "boomerang"] else "No ordinary reload; works with Infinite Ammo")
			"rubber_bullets", "pinball_wizard", "bouncy_castle":
				if kind == "chain":
					note = "Wall bounces become up to 2 more lightning jumps"
			"splinter", "cluster_rounds":
				if kind == "chain":
					note = "Up to 2 extra lightning forks"
			"heat_seekers", "smart_rounds":
				if kind in ["beam", "rail", "chain", "flame"]:
					note = "A small aim assist"
				elif kind in ["disc", "boomerang"]:
					note = "Homes in on the way out, flies straight back"
				else:
					note = "Shots home in on enemies"
			"infinite_ammo":
				if kind in ["disc", "boomerang"]:
					note = "You still need to catch your throws"
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
