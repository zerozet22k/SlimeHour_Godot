extends SceneTree
## Run via: godot --headless --path . --script tools/weapon_compatibility_test.gd
const Main = preload("res://scripts/Main.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const Compatibility = preload("res://scripts/WeaponCompatibility.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const Effects = preload("res://scripts/Effects.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))["cards"]
	var mobs = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for item in data:
		g.weapon_db[str(item["id"])] = item
	for item in mobs:
		g.enemy_db[str(item["id"])] = item
	for c in cards:
		g.card_by_id[str(c["id"])] = c
	g.hero = {"pos": Vector2.ZERO, "hp": 100.0, "maxhp": 100.0, "moving": false, "aim": Vector2.RIGHT}
	check(data.size() == 22 and Compatibility.CAPACITY.size() == 22 and Compatibility.VOLLEY_BUDGET.size() == 22 and Compatibility.OVERFLOW_SPECIALTY.size() == 22, "All 22 weapons define capacity, volley budgets and signature overflow")
	check(cards.size() == 300, "All 300 cards retained")
	check(int(g.card_by_id["hydra"]["rarity"]) == 3 and int(g.card_by_id["hydra"]["max"]) == 1, "Hydra is one-stack Legendary")
	check(int(g.card_by_id["return_sender"]["rarity"]) == 3, "Return to Sender is Legendary")
	for entry in data:
		var id = str(entry["id"])
		var gun = Weapons.new_gun(g, id)
		check(int(gun["mag_max"]) >= 1 and int(gun["mag_max"]) <= Compatibility.cap(id), id + " respects physical capacity")
		check(Compatibility.budget(g, gun) >= 1, id + " has an effective volley budget")
		check(Compatibility.resource_damage_bonus(g, gun) < 0.30, id + " does not receive excessive overflow damage")
		g.S["mag"] = 25.0
		g.S["mult"] = 12.0
		check(Weapons.mag_size(g, gun) <= Compatibility.cap(id), id + " stacks cannot bypass ammo cap")
		check(Compatibility.resource_damage_bonus(g, gun) <= 0.30 and Compatibility.support_bonus(g, gun) <= 0.25, id + " converts capped bonuses conservatively")
		check(Compatibility.resource_damage_bonus(g, gun) > 0.0 or Compatibility.support_bonus(g, gun) > 0.0, id + " retains a meaningful magazine overflow benefit")
		g.S.clear()
	var revolver = Weapons.new_gun(g, "revolver")
	g.S = {"mag": 0.5}
	check(Weapons.mag_size(g, revolver) == 6 and Compatibility.cap("revolver") == 6, "6-shot revolver cylinder never expands")
	check(Compatibility.cap("rail") == 3, "Gauss Lance always has three charge cells")
	check(Compatibility.cap("disc") == 6 and Compatibility.cap("boomerang") == 3, "Returning weapons obey distinct slot ceilings")
	check(Compatibility.active_cap("bees") == 30 and Compatibility.active_cap("bubble") == 12, "Swarm and trap populations have distinct limits")
	check(Compatibility.VOLLEY_BUDGET["shotgun"] == 14 and Compatibility.VOLLEY_BUDGET["grenade"] == 3, "Shotgun and grenade use distinct volley budgets")
	check(Compatibility.resource_damage_bonus(g, revolver) > 0.0, "Excess magazine becomes small revolver damage")
	check(Compatibility.heat_limit(g) > 3.0 and Compatibility.heat_limit(g) <= 4.5, "Prism Beam magazine cards extend heat reserve")
	g.S["reload"] = 0.35
	check(Compatibility.cooling_speed(g) > 1.0, "Reload cards improve beam cooling")
	g.S.clear()
	var disc = Weapons.new_gun(g, "disc")
	g.guns = [disc]
	check(not Compatibility.applies_to(g, "return_sender"), "Return to Sender cannot offer to a returning disc only")
	check(Compatibility.applies_to(g, "hydra"), "Hydra still offers a meaningful returning-weapon conversion")
	g.guns = [Weapons.new_gun(g, "grenade")]
	check(Compatibility.applies_to(g, "return_sender"), "Return to Sender works on ordinary flying grenades")
	check(Main.introduction_for(4) == "nurse" and Main.ROUTE_INTRO_ORDER.has("larry") and Main.introduction_for(40) == "larry", "Medic returns early and Laser Larry enters late")
	check(Main.available_enemies(15).has("nurse") and not Main.available_enemies(15).has("larry") and Main.available_enemies(40).has("larry"), "Normal enemy introductions progress from early Medic to late Larry")
	check(not EnemyMixes.allowed(Main.available_enemies(15), 15), "New base types appear before combinations")
	var available = Main.available_enemies(16)
	check(EnemyMixes.allowed(available, 16), "Dynamic combinations unlock after base species")
	var seen = {}
	var recent: Array = []
	for i in range(50):
		var hybrid = EnemyMixes.roll(g.enemy_db, available, 16, false, recent)
		if hybrid == "":
			continue
		check(g.enemy_db[hybrid]["mix"].size() == 2 and hybrid != EnemyMixes.id_for("nurse", "larry"), "Early authored fusion has exactly two compatible parents")
		seen[hybrid] = true
		recent.append(hybrid)
		if recent.size() > 9:
			recent.pop_front()
	check(seen.size() == 1 and seen.has(EnemyMixes.recipe_id(0)),
		"Sector 16 only introduces the first authored mutation, not random cross-pairs")
	seen.clear()
	recent.clear()
	var later = Main.available_enemies(23)
	for i in range(90):
		var hybrid = EnemyMixes.roll(g.enemy_db, later, 24, false, recent)
		if hybrid != "":
			seen[hybrid] = true
	check(seen.size() == 3, "Normal sector 24 exposes exactly three distinct mutation recipes")
	for kind in seen:
		check(g.enemy_db[kind]["mix"].size() == 2, "Every unlocked mutation inherits exactly two normal enemies")
	check(EnemyMixes.id_for("blob", "mirror") == EnemyMixes.id_for("mirror", "blob"), "Pair identities are canonical")
	g.free()
	print("COMPATIBILITY + PROCEDURAL ENEMY TESTS: ", "PASS" if failed == 0 else "%d failures" % failed)
	quit(1 if failed > 0 else 0)
