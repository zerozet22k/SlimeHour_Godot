extends SceneTree
## Totem aura integration regression: direct, DOT, immediate spawn cache, expiry.
const Combat = preload("res://scripts/Combat.gd")
const Main = preload("res://scripts/Main.gd")
class SilentSfx:
	extends RefCounted
	func play(_event: String) -> void:
		pass
	func play_projectile(_event: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var errors := 0
func check(ok: bool, title: String) -> void:
	if ok:
		print("PASS: ", title)
	else:
		errors += 1
		push_error("FAIL: " + title)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.settings["numbers"] = false
	g.run_time = 5.0
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for item in roster:
		g.enemy_db[str(item["id"])] = item
	var aura = {"kind": "totem", "pos": Vector2.ZERO, "dead": false, "charm": 0.0, "hp": 100.0}
	var ally = {"kind": "blob", "pos": Vector2(120, 0), "dead": false, "hp": 100.0, "max_hp": 100.0,
		"r": 14.0, "elite": false, "boss": false, "flash": 0.0, "squash": 0.0,
		"stun": 0.0, "charm": 0.0}
	g.totems = [aura]
	g.enemies = [aura, ally]
	check(not Combat.protecting_totem(g, ally).is_empty(), "Live totem protects a nearby ally")
	check(is_equal_approx(Combat.totem_protected_damage(g, ally, 40.0), 20.0), "Shield halves bullet and explosion damage")
	g.damage_dealt = 0.0
	Combat.dot(g, ally, 20.0, Color.GREEN, "POISON")
	check(is_equal_approx(float(ally["hp"]), 90.0), "Shield halves poison damage over time")
	check(is_equal_approx(g.damage_dealt, 10.0), "Recorded damage is actual post-shield damage")
	check(float(ally.get("shield_flash_until", 0.0)) > g.run_time, "Visual shield impact feedback is registered")
	ally["hp"] = 100.0
	Combat.dot(g, ally, 12.0, Color.ORANGE, "BURN")
	check(is_equal_approx(float(ally["hp"]), 94.0), "Shield also halves burn damage")
	ally["hp"] = 100.0
	Combat.dot(g, ally, 16.0, Color.RED, "BLEED")
	check(is_equal_approx(float(ally["hp"]), 92.0), "Shield also halves bleed damage")
	ally["hp"] = 100.0
	Combat.damage(g, ally, 30.0, false, {"gen": 1, "pos": ally["pos"]})
	check(is_equal_approx(float(ally["hp"]), 85.0), "Actual direct damage path applies protection")
	var second_aura = {"kind": "totem", "pos": Vector2(80, 0), "dead": false, "charm": 0.0}
	g.totems.append(second_aura)
	check(is_equal_approx(Combat.totem_protected_damage(g, ally, 20.0), 10.0), "Overlapping totems never stack multiplicatively")
	aura["dead"] = true
	second_aura["dead"] = true
	check(is_equal_approx(Combat.totem_protected_damage(g, ally, 20.0), 20.0), "Killing totems immediately removes their protection")
	aura["dead"] = false
	aura["charm"] = 1.0
	check(Combat.protecting_totem(g, ally).is_empty(), "Charmed totem no longer shields hostile enemies")
	aura["charm"] = 0.0
	aura["pos"] = Vector2(-300, 0)
	check(Combat.protecting_totem(g, ally).is_empty(), "Ally outside 230-unit aura takes normal damage")
	aura["pos"] = Vector2.ZERO
	check(Combat.protecting_totem(g, aura).is_empty(), "Hype Totem cannot shield itself")
	var main_code = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var visual_code = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(main_code.contains("totems.clear()"), "New run and sector clear stale totem cache")
	check(main_code.contains("totems.append(e)"), "Newly spawned totems shield immediately")
	check(visual_code.contains("Combat.protecting_totem(g, e)"), "Live protected allies have visual shields")
	print("HYPE TOTEM AURA: ", "PASS" if errors == 0 else str(errors) + " failures")
	g.free()
	quit(1 if errors > 0 else 0)
