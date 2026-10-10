extends SceneTree
## Regression for Infinite Ammo's virtual reload-proc cycle and bounded
## conversions of modifiers that cannot act as literal moving bullets.
## Run: godot --headless --path . --script tools/card_weapon_conversion_test.gd

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
	g.no_save = true
	g.hero = {"pos": Vector2.ZERO, "aim": Vector2.RIGHT, "hp": 100.0, "maxhp": 100.0, "moving": false}
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	check(roster.size() == 22, "22-weapon roster remains intact")
	for entry in roster:
		g.weapon_db[str(entry["id"])] = entry
		var gun = Weapons.new_gun(g, str(entry["id"]))
		check(int(gun["mag_max"]) <= Compatibility.cap(str(entry["id"])), str(entry["id"]) + " capacity remains capped")
	var w = Weapons.new_gun(g, "revolver")
	g.guns = [w]
	g.S = {"infammo": 1.0}
	g.run_time = 0.0
	# A harmless reload-triggered buff lets us observe activations without
	# needing sound, animations, physics frames or spawned projectiles.
	g.procs = {"reload": [{"p": {"on": "reload", "do": "buff", "stat": "dmg", "amt": 0.1, "t": 3.0}, "stacks": 1, "icd": 0.0}]}
	for i in range(5):
		Weapons.advance_infinite_ammo_cycle(g, w)
	check(g.buffs.is_empty() and int(w["virtual_ammo"]) == 1, "Infinite Ammo retains proc until last virtual round")
	Weapons.advance_infinite_ammo_cycle(g, w)
	check(g.buffs.size() == 1 and int(w["virtual_ammo"]) == 6, "Sixth virtual shot triggers reload cards with no reload")
	check(float(w["reload"]) == 0.0 and int(w["ammo"]) == 6, "Virtual reload never consumes ammo or locks firing")
	for i in range(6):
		Weapons.advance_infinite_ammo_cycle(g, w)
	check(g.buffs.size() == 1, "Virtual reload card has a 2.5-second safety cooldown")
	g.run_time = 3.0
	for i in range(6):
		Weapons.advance_infinite_ammo_cycle(g, w)
	check(g.buffs.size() == 2, "Reload card can reactivate after cooldown")
	var disc = Weapons.new_gun(g, "disc")
	var slots = int(disc["ammo"])
	Weapons.advance_infinite_ammo_cycle(g, disc)
	check(int(disc["ammo"]) == slots, "Virtual reload does not mint extra physical returning blades")
	g.S = {}
	g.run_time = 6.0
	g.buffs.clear()
	Weapons.return_catch_card_cycle(g, disc)
	check(g.buffs.size() == 1, "Successful return activates reload cards without Infinite Ammo")
	Weapons.return_catch_card_cycle(g, disc)
	check(g.buffs.size() == 1, "Catch card procs are rate-limited")
	g.S = {"infammo": 1.0}
	g.run_time = 9.0
	Weapons.return_catch_card_cycle(g, disc)
	check(g.buffs.size() == 1, "Infinite Ammo keeps catch and virtual reload triggers separate")
	g.S = {}
	g.run_time = 12.0
	var laser = Weapons.new_gun(g, "laser")
	laser["lvl"] = 5
	Weapons.advance_infinite_ammo_cycle(g, laser)
	check(g.buffs.size() == 2, "Heatless max-level Prism Beam still activates reload cards periodically")
	var chain = Weapons.new_gun(g, "tesla")
	g.S = {"bounce": 4.0, "split": 3.0, "pierce": 5.0}
	check(Compatibility.adapted_wall_bounce(g, chain) == 2, "Tesla converts wall bounces to two bounded jumps")
	check(Compatibility.adapted_pierce(g, chain) == 3, "Tesla converts extra pierce to at most three jumps")
	check(Compatibility.adapted_wall_bounce(g, Weapons.new_gun(g, "pistol")) == 0, "Normal bullet weapons retain native wall bounce")
	var combat = FileAccess.get_file_as_string("res://scripts/Combat.gd")
	var weapons = FileAccess.get_file_as_string("res://scripts/Weapons.gd")
	check(combat.contains("static func explosive_ricochet(") and combat.contains("trap_ricochet_done"), "Explosives and bubbles have bounded ricochet conversions")
	check(weapons.contains("advance_infinite_ammo_cycle(g, w)") and weapons.contains("g.st(\"infammo\") > 0.0"), "All weapons retain Infinite Ammo integration")
	g.free()
	print("CARD-WEAPON CONVERSION TESTS: ", "PASS" if failed == 0 else str(failed) + " failures")
	quit(1 if failed > 0 else 0)
