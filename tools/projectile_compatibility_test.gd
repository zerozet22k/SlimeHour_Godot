extends SceneTree
## Regression: Snake Shot and other projectile-only physics adapt across 22 guns.
const Main = preload("res://scripts/Main.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const Compatibility = preload("res://scripts/WeaponCompatibility.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))["cards"]
	check(roster.size() == 22, "22 separate weapon compatibility definitions")
	var projectiles = cards.filter(func(c): return str(c["cat"]) == "projectile")
	check(projectiles.size() >= 25, "Projectile card category has broad coverage")
	for weapon in roster:
		g.weapon_db[str(weapon["id"])] = weapon
	for card in cards:
		g.card_by_id[str(card["id"])] = card
	g.run_time = 0.113
	g.S = {"wave": 32.0, "curve": 2.2, "pierce": 1.0, "pspeed": 0.25, "accel": 1.0}
	for weapon in roster:
		var id = str(weapon["id"])
		var kind = str(weapon["kind"])
		var w = Weapons.new_gun(g, id)
		g.guns = [w]
		var note = Compatibility.card_interaction(g, "snake_shot")
		check(note.contains(": ") and note.length() > 24, id + ": Snake has a weapon-specific interaction")
		var wave = Compatibility.projectile_wave(g, w)
		var curve = Compatibility.projectile_curve(g, w)
		if kind in ["beam", "rail", "chain"]:
			check(wave == 0.0 and curve == 0.0 and absf(Compatibility.instant_sway(g, w)) > 0.0,
				id + ": Snake Shot translates to an instant-attack sway")
			check(Compatibility.instant_reach_bonus(g, w) > 0.0,
				id + ": Projectile speed converts to bounded attack reach")
		elif kind == "flame":
			check(wave == 0.0 and curve == 0.0, "Cinder never spawns fake snake bullets")
		else:
			check(wave > 0.0 and wave <= 48.0 and absf(curve) <= 3.0,
				id + ": Snake uses bounded physical trajectory")
		if kind == "chain":
			check(Compatibility.adapted_pierce(g, w) == 1,
				"Arc Caster converts Snake piercing into an extra chain jump")
		if kind in ["disc", "boomerang"]:
			check(wave <= 16.0, id + ": Returning weapon never gets uncontrollable slither")
		if kind == "bees":
			check(wave <= 8.0, "Bee homing overrides large Snake displacement")
		for card in projectiles:
			var cid = str(card["id"])
			if cid == "return_sender":
				check(Compatibility.applies_to(g, cid) == (kind not in ["disc", "boomerang", "rail", "beam", "chain", "flame"]),
					id + ": incompatible returning physics are excluded")
			else:
				check(Compatibility.applies_to(g, cid), id + ": " + cid + " is available")
	check(Compatibility.instant_acceleration(g, Weapons.new_gun(g, "rail"), 1.0) > 1.0,
		"Road Rage accelerates rail impact power over distance")
	check(Compatibility.instant_acceleration(g, Weapons.new_gun(g, "laser"), 1.0) > 1.0,
		"Road Rage accelerates beam cutting strength over distance")
	check(Compatibility.instant_acceleration(g, Weapons.new_gun(g, "rail"), 0.0) == 1.0,
		"Nonprojectile acceleration scales by real distance travelled")
	var weapons_src = FileAccess.get_file_as_string("res://scripts/Weapons.gd")
	var combat_src = FileAccess.get_file_as_string("res://scripts/Combat.gd")
	check(weapons_src.contains("Compatibility.instant_sway(g, w)") and
		weapons_src.contains("Compatibility.projectile_wave(g, w)"),
		"Laser, rail, Tesla and physical projectiles use same resolver")
	check(combat_src.contains("if not is_returning and float(s[\"wave\"]) > 0.0"),
		"Returning discs wiggle only while travelling outward")
	g.free()
	print("PROJECTILE COMPATIBILITY: ", "PASS" if failed == 0 else str(failed) + " failures")
	quit(1 if failed > 0 else 0)
