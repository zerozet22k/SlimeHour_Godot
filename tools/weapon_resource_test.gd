extends SceneTree
## Verify that each weapon's evolution respects its actual resource mechanic.
const Main = preload("res://scripts/Main.gd")
const Weapons = preload("res://scripts/Weapons.gd")
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
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	for entry in rows:
		g.weapon_db[str(entry["id"])] = entry
	check(rows.size() == 22, "Twenty-two original weapon IDs remain")
	check(Weapons.EVOLUTION_DESCRIPTIONS.size() == 22, "All 22 evolution messages are specialized")
	for id in g.weapon_db.keys():
		var gun = Weapons.new_gun(g, id)
		check(not Weapons.evolution_description(gun).contains("+1 projectile"), str(id) + " has no blanket extra projectile")
	g.hero = {"pos": Vector2.ZERO, "hp": 100.0, "maxhp": 100.0, "moving": false, "aim": Vector2.RIGHT}
	var disc = Weapons.new_gun(g, "disc")
	var returning = Weapons.new_gun(g, "boomerang")
	check(int(disc["mag_max"]) == 2 and int(returning["mag_max"]) == 1, "Disc and boomerang use 2 and 1 returnable slots")
	check(Weapons.resource_type(g, disc) == "RETURN" and Weapons.resource_type(g, returning) == "RETURN", "Both returning weapons have no reload")
	var before_disc_rate = Weapons.fire_rate(g, disc)
	var before_boomer_rate = Weapons.fire_rate(g, returning)
	disc["evolved"] = true
	returning["evolved"] = true
	check(Weapons.mag_size(g, disc) == 2 and Weapons.mag_size(g, returning) == 1, "Evolution never creates extra returning blades")
	check(is_equal_approx(before_disc_rate, Weapons.fire_rate(g, disc)) and is_equal_approx(before_boomer_rate, Weapons.fire_rate(g, returning)), "Returning evolution buffs travel, not useless fire rate")
	var laser = Weapons.new_gun(g, "laser")
	laser["evolved"] = true
	check(Weapons.resource_type(g, laser) == "HEAT" and Weapons.mag_size(g, laser) == 1, "Laser has heat, not bullets")
	var flame = Weapons.new_gun(g, "flame")
	var initial_fuel = Weapons.mag_size(g, flame)
	check(Weapons.resource_type(g, flame) == "FUEL", "Flamethrower uses fuel")
	flame["evolved"] = true
	check(Weapons.mag_size(g, flame) > initial_fuel, "Flamethrower evolution grows fuel tank")
	check(Weapons.flame_range(g, flame) > 190.0, "Flamethrower evolution extends cone reach")
	check(Weapons.flame_cone_contains(Vector2.ZERO, Vector2.RIGHT, Vector2(65, 0), 195.0, 0.23), "Cone hits enemies in front")
	check(not Weapons.flame_cone_contains(Vector2.ZERO, Vector2.RIGHT, Vector2(-120, 0), 195.0, 0.23), "Cone does not hit enemies behind player")
	g.beams.clear()
	g.shots.clear()
	Weapons.fire_flame(g, flame, Vector2.ZERO, Vector2.RIGHT, 5.0)
	check(g.shots.is_empty() and g.beams.size() == 1 and bool(g.beams[0].get("flame_stream", false)), "Flamethrower emits drawn cone, zero projectile entities")
	var rail = Weapons.new_gun(g, "rail")
	var old_charge = Weapons.rail_charge_seconds(g, rail)
	rail["evolved"] = true
	check(Weapons.rail_charge_seconds(g, rail) < old_charge and Weapons.mag_size(g, rail) == 3, "Rail evolution speeds charging while preserving 3-shot magazine")
	var pistol = Weapons.new_gun(g, "pistol")
	var prior_rate = Weapons.fire_rate(g, pistol)
	pistol["evolved"] = true
	check(Weapons.fire_rate(g, pistol) > prior_rate, "Magazine-fed conventional pistol receives fire-rate boost")
	g.free()
	print("WEAPON RESOURCE TESTS: ", "PASS" if failed == 0 else str(failed) + " failed")
	quit(1 if failed else 0)
