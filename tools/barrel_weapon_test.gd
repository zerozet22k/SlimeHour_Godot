extends SceneTree
## Run: godot --headless --path . --script res://tools/barrel_weapon_test.gd
## Every real weapon class must be able to arm a barrel without faking bullets.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const Weapons = preload("res://scripts/Weapons.gd")

class SilentSfx:
	extends Node
	func play(_sound: String, _volume: float = 1.0, _pitch: float = 1.0) -> void:
		pass
	func play_projectile(_event: String, _style: String = "", _pattern: String = "", _volume: float = 1.0) -> void:
		pass

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func fresh_barrel(pos: Vector2 = Vector2(80, 0), drop: float = 0.0) -> Dictionary:
	return {"pos": pos, "hp": 12.0, "drop": drop, "armed": false, "fuse": 0.0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.sfx = SilentSfx.new()
	g.add_child(g.sfx)
	g.hero = {"pos": Vector2.ZERO, "hp": 100.0, "maxhp": 100.0, "moving": false, "aim": Vector2.RIGHT}
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	check(rows is Array and rows.size() == 22, "All 22 weapon definitions remain present")
	for d in rows:
		g.weapon_db[str(d["id"])] = d

	# Regular projectiles use their swept segment, regardless of weapon art.
	var projectile_kinds = ["pistol", "revolver", "shotgun", "smg", "minigun", "sniper",
		"rocket", "grenade", "disc", "boomerang", "bees", "bowling",
		"nailgun", "chicken", "bubble", "pinball", "splitbow", "snow"]
	for weapon_id in projectile_kinds:
		g.barrels = [fresh_barrel()]
		var kind = str(g.weapon_db[weapon_id]["kind"])
		var shot = {"last": Vector2.ZERO, "pos": Vector2(160, 0),
			"vel": Vector2.RIGHT * 400.0, "r": 4.0, "dmg": 15.0,
			"kind": kind, "pierce": 0, "dead": false}
		Combat.collide_barrels(g, shot)
		check(float(g.barrels[0]["hp"]) <= 0.0, weapon_id + " direct projectile can arm barrel")

	# Beam + ricochet and line-based attacks do not have bullet entities.
	g.barrels = [fresh_barrel()]
	var laser = Weapons.new_gun(g, "laser")
	Weapons.fire_beam(g, laser, Vector2.ZERO, Vector2.RIGHT, 15.0)
	check(float(g.barrels[0]["hp"]) <= 0.0, "Prism Beam hits nearby barrel with hitscan segment")

	g.barrels = [fresh_barrel()]
	var flame = Weapons.new_gun(g, "flame")
	g.shots.clear()
	Weapons.fire_flame(g, flame, Vector2.ZERO, Vector2.RIGHT, 15.0)
	check(float(g.barrels[0]["hp"]) <= 0.0 and g.shots.is_empty(), "Cinder ignites barrel through true cone, without projectile actors")

	g.barrels = [fresh_barrel(Vector2(-80, 0))]
	Weapons.fire_flame(g, flame, Vector2.ZERO, Vector2.RIGHT, 15.0)
	check(float(g.barrels[0]["hp"]) == 12.0, "Cinder cannot ignite barrel behind flame cone")

	g.barrels = [fresh_barrel()]
	var arc = Weapons.new_gun(g, "tesla")
	Weapons.fire_chain(g, arc, Vector2.ZERO, Vector2.RIGHT, 15.0)
	check(float(g.barrels[0]["hp"]) <= 0.0, "Arc Caster arcs to barrel when no enemy is available")

	g.barrels = [fresh_barrel()]
	var rail = Weapons.new_gun(g, "rail")
	Weapons.fire_rail(g, rail, Vector2.ZERO, Vector2.RIGHT, 15.0)
	check(float(g.barrels[0]["hp"]) <= 0.0, "Gauss Lance hits barrel along instant line")

	g.barrels = [fresh_barrel(Vector2(80, 70))]
	check(Combat.damage_barrels_segment(g, Vector2.ZERO, Vector2(160, 0), 5.0, 20.0) == 0,
		"Hitscan attack does not ignite barrel outside effective width")
	check(float(g.barrels[0]["hp"]) == 12.0, "Barrel remains unarmed outside hit area")

	g.barrels = [fresh_barrel(Vector2(80, 0), 0.6)]
	check(Combat.damage_barrels_segment(g, Vector2.ZERO, Vector2(160, 0), 5.0, 20.0) == 0,
		"Falling barrels cannot ignite before landing")

	g.barrels = [fresh_barrel()]
	Combat.damage_barrels_segment(g, Vector2.ZERO, Vector2(160, 0), 5.0, 20.0)
	Combat.update_barrels(g, 0.016)
	check(bool(g.barrels[0]["armed"]) and float(g.barrels[0]["fuse"]) > 0.0,
		"Any weapon hit starts existing visible fuse timer, not instant explosion")

	var unlit = FileAccess.get_file_as_string("res://assets/ui/barrel_unlit.svg")
	var lit = FileAccess.get_file_as_string("res://assets/ui/barrel.svg")
	var visuals = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(not unlit.contains("M108 9L119 0") and lit.contains("M108 9L119 0"),
		"Default barrel artwork is unlit; armed artwork contains the fuse spark")
	check(visuals.contains('var image = g.tex("res://assets/ui/barrel_unlit.svg")') and
		visuals.contains('var spark_pos = p + Vector2(6.5, -23.0)'),
		"Both barrel states use identical base sprite; fuse spark is a separate armed overlay")
	g.free()
	print("BARREL WEAPON TESTS: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures > 0 else 0)
