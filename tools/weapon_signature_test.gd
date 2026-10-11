extends SceneTree
## Deterministic coverage for the 22 max-level gun identities.
const Main = preload("res://scripts/Main.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const WeaponSignatures = preload("res://scripts/WeaponSignatures.gd")

var failures := 0
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.hero = {"pos": Vector2.ZERO, "hp": 100.0, "maxhp": 100.0, "moving": false, "aim": Vector2.UP}
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var max_names = {}
	for entry in raw:
		g.weapon_db[str(entry["id"])] = entry
		var signature = str(entry["lv5"]).split(" — ")
		check(signature.size() >= 2, str(entry["id"]) + ": named level-five combat signature")
		if signature.size() >= 2:
			check(not max_names.has(signature[0]), str(entry["id"]) + ": unique max-ability name")
			max_names[signature[0]] = true
	check(g.weapon_db.size() == 22 and max_names.size() == 22, "Exactly 22 different level-five specialties")
	var keyed = {
		"revolver": "duelist", "shotgun": "breach", "smg": "suppress",
		"minigun": "vulcan_sweep", "sniper": "collateral", "rocket": "thermobaric",
		"grenade": "bank_guidance", "bees": "hive_scent", "bowling": "perfect_strike",
		"nailgun": "rivet_tether", "chicken": "panic", "bubble": "pressure_chain",
		"pinball": "perfect_bank", "splitbow": "hydra_seek", "snow": "whiteout",
		"disc": "vortex_recall", "boomerang": "momentum_catch"
	}
	for id in keyed:
		var w = Weapons.new_gun(g, id)
		w["spin"] = 1.0 # Full-spool Vulcan should enable its max-level signature
		w["lvl"] = 4
		var before = Weapons.base_opts(g, w, g.weapon_db[id])
		w["lvl"] = 5
		var after = Weapons.base_opts(g, w, g.weapon_db[id])
		var flag = str(keyed[id])
		check(not before["flags"].has(flag), id + ": no max-level signature at level 4")
		check(after["flags"].has(flag), id + ": max-level behavior is armed at level 5")
	# Evolution is a weapon mechanic, not a generic 20% rate change.
	check(Weapons.EVOLUTION_DESCRIPTIONS.size() == 22 and Weapons.EVOLVED_COLORS.size() == 22, "All 22 weapons have distinctive evolution descriptions and visual palettes")
	for id in g.weapon_db.keys():
		var desc = Weapons.evolution_description(Weapons.new_gun(g, str(id)))
		check(not desc.contains("count stays") and not desc.contains("Same "), str(id) + ": no misleading fixed-projectile evolution wording")
	var cyclone = Weapons.new_gun(g, "smg")
	cyclone["count"] = 6
	var ordinary = Weapons.base_opts(g, cyclone, g.weapon_db["smg"])
	cyclone["evolved"] = true
	var evolved_cyclone = Weapons.base_opts(g, cyclone, g.weapon_db["smg"])
	check(not ordinary["flags"].has("cyclone_tracer") and evolved_cyclone["flags"].has("cyclone_tracer"), "Cyclone X gains its own six-shot tracer")
	check(int(evolved_cyclone["pierce"]) >= int(ordinary["pierce"]) + 2, "Cyclone X tracer penetrates two extra enemies")
	check(evolved_cyclone["color"] != ordinary["color"], "Cyclone X has a distinct evolved tracer palette")
	check(Weapons.EVOLVED_COLORS["smg"] != Weapons.EVOLVED_COLORS["minigun"], "SMG and Vulcan visual signatures are distinct")
	cyclone["count"] = 7
	check(not Weapons.base_opts(g, cyclone, g.weapon_db["smg"])["flags"].has("cyclone_tracer"), "Cyclone X fires a periodic tracer, not permanent unlimited pierce")
	var regular_shotgun = Weapons.new_gun(g, "shotgun")
	var ordinary_pellets = Weapons.base_opts(g, regular_shotgun, g.weapon_db["shotgun"])
	regular_shotgun["evolved"] = true
	var breachmaster = Weapons.base_opts(g, regular_shotgun, g.weapon_db["shotgun"])
	check(str(Weapons.EVOLUTION_DESCRIPTIONS["shotgun"]).contains("slug") and breachmaster["kind"] == ordinary_pellets["kind"],
		"Breachmaster adds a periodic piercing slug instead of a stat bump")
	var deadeye = Weapons.new_gun(g, "revolver")
	deadeye["quickdraw"] = true
	var quick = Weapons.base_opts(g, deadeye, g.weapon_db["revolver"])
	check(float(quick["crit"]) >= 1.0 and quick["flags"].has("quickdraw"), "Deadeye Quickdraw makes the first shot after a pause a sure crit")
	var rocket_upgrade = Weapons.new_gun(g, "rocket")
	rocket_upgrade["evolved"] = true
	check(Weapons.base_opts(g, rocket_upgrade, g.weapon_db["rocket"])["flags"].has("fire_puddle"), "Payload Zero ignites ground on impact")
	var hydra_upgrade = Weapons.new_gun(g, "splitbow")
	hydra_upgrade["evolved"] = true
	check(Weapons.base_opts(g, hydra_upgrade, g.weapon_db["splitbow"])["flags"].has("frag_home"), "Evolved Hydra fragments track earlier")
	var ion = g.add_zone("lightning", Vector2.ZERO, 14.0, 1.5, {"a": Vector2.ZERO, "b": Vector2(600, 0)})
	check(absf(float(ion["life"]) - 1.5) < 0.01 and ion["a"].distance_to(ion["b"]) == 600.0, "Gauss ion field covers the real rail segment for 1.5 seconds")
	var battle_code = FileAccess.get_file_as_string("res://scripts/Combat.gd")
	var visual_code = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(battle_code.contains("field_radius") and battle_code.contains("seg_dist2(start, stop"), "Ion corridor checks segment width rather than just endpoints")
	check(visual_code.contains("field_width") and visual_code.contains("draw_polyline(pts"), "Ion corridor visibly crackles for its entire lifetime")
	# Stateful perfect catches reward skilled recall and reset after a miss.
	var returner = Weapons.new_gun(g, "boomerang")
	returner["lvl"] = 5
	var s = {"src": "boomerang", "gun": returner, "flags": {"momentum_catch": true, "owner": true}}
	WeaponSignatures.return_catch(g, s, true)
	WeaponSignatures.return_catch(g, s, true)
	check(int(returner.get("catch_streak", 0)) == 2, "Two successful returns build momentum")
	WeaponSignatures.return_catch(g, s, false)
	check(int(returner.get("catch_streak", 0)) == 0, "Missing the boomerang resets momentum")
	# Rocket follow-up is a crowd-control vacuum, not an additional damage explosion.
	g.delayed.clear()
	var rocket = {"flags": {"thermobaric": true}}
	WeaponSignatures.rocket_collapse(g, rocket, Vector2(45, 20))
	check(g.delayed.size() == 1 and g.delayed[0]["fn"] == "payload_vacuum" and not g.delayed[0].has("dmg"), "Thermobaric delayed vacuum does not duplicate blast damage")
	g.free()
	print("WEAPON SIGNATURE TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures else 0)
