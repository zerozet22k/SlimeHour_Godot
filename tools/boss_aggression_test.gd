extends SceneTree
## Boss/elite aggression regression. Intentionally exercises each boss pattern,
## rather than only checking JSON existence or increasing HP numbers.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")

class SilentSfx:
	extends RefCounted
	func play(_name: String) -> void:
		pass
	func play_projectile(_name: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var errors := 0
func check(ok: bool, desc: String) -> void:
	if not ok:
		errors += 1
		push_error("FAIL: " + desc)
	else:
		print("PASS: ", desc)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.hero = {"pos": Vector2(0, 0), "vel": Vector2(130, 40), "hp": 250.0,
		"max_hp": 250.0, "aim": Vector2.UP, "dash_window": 0.0, "iframe": 0.0}
	g.sector = 35
	g.state = "playing"
	var enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var boss_ids: Array[String] = []
	for definition in enemies:
		g.enemy_db[str(definition["id"])] = definition
		if bool(definition.get("boss", false)):
			boss_ids.append(str(definition["id"]))
	check(boss_ids.size() == 8, "Exactly eight distinct bosses in active enemy roster")
	var wanted = ["chonkzilla", "heli", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine"]
	check(boss_ids == wanted, "Eight bosses are ordered for sectors 5 through 40")
	var base = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var visuals = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	for id in wanted:
		check(base.contains("\"" + id + "\""), id + ": spawn rotation contains boss")
		check(visuals.contains("\"" + id + "\""), id + ": visuals contain named boss")
	for id in wanted:
		var d: Dictionary = g.enemy_db[id]
		var enemy = {"id": 42, "kind": id, "boss": true, "dead": false,
			"hp": 25.0, "max_hp": 100.0, "pos": Vector2(0, -250),
			"vel": Vector2.ZERO, "kb": Vector2.ZERO, "speed": float(d["speed"]),
			"r": float(d["r"]), "dmg": float(d["dmg"]), "cd": 0.0,
			"wind": 0.0, "charge": 0.0, "cdir": Vector2.ZERO,
			"t": 4.0, "phase": 0.0, "pattern": -1}
		check(Combat.boss_stage(enemy) == 2, id + ": unlocks rage phase")
		var has_attack = false
		for i in range(6):
			g.delayed.clear()
			g.shots.clear()
			g.enemies.clear()
			enemy["cd"] = 0.0
			enemy["wind"] = 0.0
			enemy["pattern"] = i - 1
			enemy["t"] = 4.0 + i * 0.3
			Combat.ai(g, enemy, Vector2.DOWN, 260.0, 0.016, false)
			if not g.delayed.is_empty() or not g.shots.is_empty() or float(enemy["wind"]) > 0.0 or int(enemy.get("burst", 0)) > 0 or not g.enemies.is_empty():
				has_attack = true
			check(g.delayed.size() <= 32, id + " attack %d: bounded telegraph count" % i)
			check(g.shots.size() <= 55, id + " attack %d: bounded projectile count" % i)
		check(has_attack, id + ": actively attacks, not merely a health sponge")
	# Verify the exact warning and collision width are shared.
	g.delayed.clear()
	Combat.schedule_boss_line(g, Vector2(-180, -50), Vector2(180, 120), 24.0, 12.0, 1.1, "75ffbb")
	check(g.delayed.size() == 1 and g.delayed[0]["fn"] == "boss_line", "Laser lane registers delayed warning")
	check(is_equal_approx(float(g.delayed[0]["tele"]), 24.0) and is_equal_approx(float(g.delayed[0]["life"]), 1.1), "Beam warning uses true width and delay")
	g.delayed.clear()
	# Mirror is reactive to projectiles and must not behave like a proactive sniper.
	var mirror = {"kind": "mirror", "id": 7, "pos": Vector2(0, -250), "cd": 0.0, "wind": 0.0,
		"charge": 0.0, "t": 0.0, "phase": 0.0, "r": 17.0, "dmg": 12.0}
	Combat.ai(g, mirror, Vector2.DOWN, 250.0, 0.016, false)
	check(float(mirror["wind"]) == 0.0 and g.shots.is_empty(), "Mirror does not shoot proactively")
	mirror["wind"] = 0.70
	mirror["lock"] = g.hero["pos"]
	mirror["mirror_kind"] = "bullet"
	mirror["mirror_shots"] = 2
	Combat.ai(g, mirror, Vector2.DOWN, 250.0, 1.0, false)
	check(g.shots.size() == 2, "Mirror counterattacks with its copied volley")
	# Burrower: predicted, telegraphed re-emergence and genuine aftershock.
	var burrower = {"kind": "burrower", "id": 9, "pos": Vector2(0, -260), "cd": 0.0, "wind": 0.0,
		"charge": 0.0, "t": 0.0, "phase": 0.0, "r": 18.0, "dmg": 12.0, "kb": Vector2.ZERO,
		"vel": Vector2.ZERO}
	Combat.ai(g, burrower, Vector2.DOWN, 270.0, 0.016, false)
	check(float(burrower["wind"]) > 0.0 and burrower.has("lock"), "Burrower telegraphs predicted landing")
	g.delayed.clear()
	Combat.ai(g, burrower, Vector2.DOWN, 270.0, 1.0, false)
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_blast"), "Burrower creates dodgeable delayed surface collapse")
	g.free()
	print("BOSS AGGRESSION TESTS: ", "PASS" if errors == 0 else str(errors) + " failures")
	quit(1 if errors > 0 else 0)
