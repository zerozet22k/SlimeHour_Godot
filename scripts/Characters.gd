extends RefCounted
## Run-only character identities. Bonuses are deliberately small and never grant permanent unlocks.
## Existing profiles default to Scout; the user's last selected character is stored separately.
const DEFAULT = "scout"
const ROSTER = [
	{"id": "scout", "name": "SCOUT", "role": "Reliable sidearm", "weapon": "pistol", "color": "73eaff",
		"perks": "Sidearm damage +4%", "tradeoff": "No drawback",
		"weapon_damage": 1.04, "weapon_rate": 1.0, "rail_charge": 1.0, "crit": 0.0, "xp": 1.0},
	{"id": "ember", "name": "EMBER", "role": "Fire specialist", "weapon": "flame", "color": "ff9955",
		"perks": "Flamethrower damage +6%", "tradeoff": "XP earned -3%",
		"weapon_damage": 1.06, "weapon_rate": 1.0, "rail_charge": 1.0, "crit": 0.0, "xp": 0.97},
	{"id": "ace", "name": "ACE", "role": "Precision specialist", "weapon": "revolver", "color": "ffe091",
		"perks": "Revolver crit chance +3%", "tradeoff": "XP earned -2%",
		"weapon_damage": 1.0, "weapon_rate": 1.0, "rail_charge": 1.0, "crit": 0.03, "xp": 0.98},
	{"id": "vector", "name": "VECTOR", "role": "Close-range suppressor", "weapon": "smg", "color": "a4f4c4",
		"perks": "SMG fire rate +5%", "tradeoff": "XP earned -3%",
		"weapon_damage": 1.0, "weapon_rate": 1.05, "rail_charge": 1.0, "crit": 0.0, "xp": 0.97},
	{"id": "coil", "name": "COIL", "role": "Charged precision", "weapon": "rail", "color": "baa4ff",
		"perks": "Rail charge time -5%", "tradeoff": "XP earned -5%",
		"weapon_damage": 1.0, "weapon_rate": 1.0, "rail_charge": 1.0526316, "crit": 0.0, "xp": 0.95}
]

static func get_character(id: String) -> Dictionary:
	for ch in ROSTER:
		if str(ch["id"]) == id:
			return ch
	return ROSTER[0]

static func valid(id: String) -> bool:
	for ch in ROSTER:
		if str(ch["id"]) == id:
			return true
	return false

static func affinity(id: String, weapon_id: String, key: String, fallback: float = 1.0) -> float:
	var ch = get_character(id)
	if str(ch["weapon"]) != weapon_id:
		return fallback
	return float(ch.get(key, fallback))

static func xp_multiplier(id: String) -> float:
	return float(get_character(id).get("xp", 1.0))
