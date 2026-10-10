extends SceneTree
## Real boss mechanics regression. Run --headless --script tools/boss_identity_test.gd.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const Bestiary = preload("res://scripts/Bestiary.gd")

class SilentSfx:
	extends RefCounted
	func play(_name: String) -> void:
		pass
	func play_projectile(_name: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("BOSS IDENTITY: " + message)
	else:
		print("PASS: ", message)

func specimen(g, kind: String, uid: int) -> Dictionary:
	var d: Dictionary = g.enemy_db[kind]
	return {"id": uid, "kind": kind, "boss": true, "dead": false, "elite": false,
		"hp": float(d["hp"]) * 0.8, "max_hp": float(d["hp"]), "pos": Vector2(0, -250),
		"vel": Vector2.ZERO, "kb": Vector2.ZERO, "speed": float(d["speed"]),
		"r": float(d["r"]), "mass": float(d["mass"]), "dmg": float(d["dmg"]),
		"cd": 0.0, "wind": 0.0, "charge": 0.0, "cdir": Vector2.ZERO,
		"t": 4.0, "phase": 0.0, "pattern": -1, "aim": Vector2.DOWN,
		"stun": 0.0, "charm": 0.0, "squash": 0.0, "flash": 0.0}

func reset(g) -> void:
	g.enemies.clear()
	g.delayed.clear()
	g.shots.clear()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2(90, 0), "hp": 500.0,
		"maxhp": 500.0, "iframe": 0.0, "dash_window": 0.0, "aim": Vector2.UP}
	g.state = "playing"
	g.road_half = 490.0
	g.sector = 40
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var bosses: Array = []
	for row in data:
		g.enemy_db[str(row["id"])] = row
		if bool(row.get("boss", false)):
			bosses.append(str(row["id"]))
	check(bosses.size() == 8, "Eight bosses remain in original sector rotation")
	for boss_id in bosses:
		check(Bestiary.info(str(boss_id))[0] != "UNKNOWN", boss_id + " has a specific counterplay entry")

	# Chonkzilla: moving committed slam, fissures, punishable stagger.
	reset(g)
	var chonk = specimen(g, "chonkzilla", 501)
	Combat.ai(g, chonk, Vector2.DOWN, 260.0, 0.016, false)
	check(float(chonk["wind"]) > 0.5 and chonk.has("lock"), "Chonkzilla warns a committed landing")
	Combat.ai(g, chonk, Vector2.DOWN, 260.0, 1.3, false)
	check(float(chonk.get("boss_recover", 0.0)) > 0.5, "Chonkzilla enters a genuine stagger recovery")
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_line"), "Chonkzilla leaves distinct lateral ground fissures")
	check(Combat.boss_identity_damage_factor(g, chonk) > 1.4, "Players deal bonus damage during the stagger")

	# Heli's flight path, not fixed circular bullet hell.
	reset(g)
	var heli = specimen(g, "heli", 502)
	var flight = Combat.ai(g, heli, Vector2.DOWN, 260.0, 0.016, false)
	check(float(heli.get("flight_t", 0.0)) > 1.0 and absf(flight.x) > 0.7, "Heli performs a directional strafing run")
	Combat.ai(g, heli, Vector2.DOWN, 260.0, 0.15, false)
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_blast"), "Bombs spawn under the actual flying path")

	# Necro's links heal ONLY while the destroyable anchors survive.
	reset(g)
	var necro = specimen(g, "necro", 503)
	Combat.ai(g, necro, Vector2.DOWN, 260.0, 0.016, false)
	var linked = g.enemies.filter(func(m): return int(m.get("soul_owner", -1)) == 503)
	check(linked.size() >= 2, "Necro summons marked, killable soul anchors")
	var hp_before = float(necro["hp"])
	necro["cd"] = 10.0
	Combat.ai(g, necro, Vector2.DOWN, 260.0, 0.5, false)
	check(float(necro["hp"]) > hp_before, "Living anchors actually siphon health into Necro")
	for mob in linked:
		mob["dead"] = true
	var hp_after = float(necro["hp"])
	Combat.ai(g, necro, Vector2.DOWN, 260.0, 0.5, false)
	check(is_equal_approx(float(necro["hp"]), hp_after), "Destroying anchors stops all Necro healing")

	# King's children are consumable mass, not an ordinary minion wave.
	reset(g)
	var king = specimen(g, "kingblob", 504)
	king["pattern"] = 0
	Combat.ai(g, king, Vector2.DOWN, 260.0, 0.016, false)
	check(float(king["wind"]) > 0.0, "King Blob still has a marked leap")
	king["wind"] = 0.0
	king["cd"] = 0.0
	king["pattern"] = 1
	Combat.ai(g, king, Vector2.DOWN, 260.0, 0.016, false)
	var food = g.enemies.filter(func(m): return int(m.get("royal_owner", -1)) == 504)
	check(food.size() >= 3, "King Blob summons identifiable royal food")
	var old_mass = float(king["r"])
	food[0]["pos"] = king["pos"] + Vector2(25, 0)
	king["cd"] = 15.0
	Combat.ai(g, king, Vector2.DOWN, 260.0, 0.016, false)
	check(float(king["r"]) > old_mass and bool(food[0]["dead"]), "King Blob visibly grows when it absorbs a child")

	# Queen walls MOVE inward and their warnings share actual collision segment.
	reset(g)
	var coil = specimen(g, "coilqueen", 505)
	Combat.ai(g, coil, Vector2.DOWN, 260.0, 0.016, false)
	var walls = g.delayed.filter(func(d): return str(d.get("fn", "")) == "coil_wall")
	check(walls.size() == 2, "Coil Queen launches a pair of moving venom walls")
	if walls.size() == 2:
		var old_x = float(walls[0]["a"].x)
		Combat.update_delayed(g, 0.35)
		check(not is_equal_approx(float(walls[0]["a"].x), old_x), "Coil warning and hitbox both physically constrict")
		check(is_equal_approx(float(walls[0]["a"].x), float(walls[0]["b"].x)), "Constricting wall has exact collision-width warning")

	# Oracle armor is generated by external nodes and disappears with them.
	reset(g)
	var oracle = specimen(g, "glassoracle", 506)
	Combat.ai(g, oracle, Vector2.DOWN, 260.0, 0.016, false)
	var mirrors = g.enemies.filter(func(m): return int(m.get("oracle_owner", -1)) == 506)
	check(mirrors.size() >= 2 and Combat.boss_identity_damage_factor(g, oracle) < 0.5, "Living mirrors confer Oracle armor")
	for mob in mirrors:
		mob["dead"] = true
	check(is_equal_approx(Combat.boss_identity_damage_factor(g, oracle), 1.0), "Destroying mirrors fully strips Oracle armor")

	# Weaver portals emit actual shots from positions away from the boss.
	reset(g)
	var weaver = specimen(g, "voidweaver", 507)
	Combat.ai(g, weaver, Vector2.DOWN, 260.0, 0.016, false)
	check(float(weaver["wind"]) > 0.0 and g.delayed.filter(func(d): return str(d.get("fn", "")) == "rift_emit").size() == 2, "Void Weaver creates two attack portals and a phase swap")
	Combat.ai(g, weaver, Vector2.DOWN, 260.0, 0.95, false)
	Combat.update_delayed(g, 1.3)
	check(g.shots.size() >= 4, "Void Weaver's warned remote portals really launch crossfire")

	# Engine must eventually lose armor; armor cannot remain permanent.
	reset(g)
	var engine = specimen(g, "dreadengine", 508)
	check(Combat.boss_identity_damage_factor(g, engine) < 0.6, "Dread Engine begins plated")
	for i in range(3):
		engine["cd"] = 0.0
		Combat.ai(g, engine, Vector2.DOWN, 260.0, 0.016, false)
	check(float(engine.get("engine_heat", 0.0)) >= 100.0, "Pistons build actual core heat")
	Combat.ai(g, engine, Vector2.DOWN, 260.0, 0.016, false)
	check(float(engine.get("vent_t", 0.0)) > 0.0 and Combat.boss_identity_damage_factor(g, engine) > 1.7, "Overheated core exposes a true player damage window")

	var renderer = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(renderer.contains('"coil_wall"') and renderer.contains("MIRROR ARMOR") and renderer.contains("CORE EXPOSED"), "Distinct state and real hazard warnings are rendered")
	g.free()
	print("EIGHT BOSS IDENTITY TEST: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
