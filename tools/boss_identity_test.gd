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
	# Arena attacks use their boss's mechanic, not a recolored shared grid.
	for boss_id in bosses:
		if boss_id == "chonkzilla":
			continue
		reset(g)
		var map_boss = specimen(g, boss_id, 900 + bosses.find(boss_id))
		var soul_anchor: Dictionary = {}
		if boss_id == "necro":
			soul_anchor = g.spawn_enemy("leech", Vector2(-100.0, -90.0), false, false)
			soul_anchor["soul_owner"] = int(map_boss["id"])
		if boss_id == "glassoracle":
			for mirror_index in range(2):
				var mirror = g.spawn_enemy("mirror", Vector2(-170.0 + mirror_index * 340.0, -115.0), false, false)
				mirror["oracle_owner"] = int(map_boss["id"])
		Combat.boss_map_pattern(g, map_boss, 1)
		var field = g.delayed.filter(func(d): return str(d.get("map_pattern", "")) == boss_id)
		var expected := {"heli": "boss_blast", "necro": "boss_soul_link",
			"kingblob": "boss_blast", "coilqueen": "coil_wall",
			"glassoracle": "boss_line", "voidweaver": "rift_emit",
			"dreadengine": "boss_line"}
		check(field.size() >= 1 and field.all(func(d): return str(d["fn"]) == expected[boss_id]),
			boss_id + " uses its own arena attack type")
		if boss_id == "heli" or boss_id == "kingblob" or boss_id == "voidweaver":
			var map_left := false
			var map_right := false
			for event in field:
				map_left = map_left or float(event["pos"].x) < -g.road_half * 0.5
				map_right = map_right or float(event["pos"].x) > g.road_half * 0.5
			check(map_left and map_right, boss_id + " uses both sides of the arena")
		if boss_id == "necro":
			check(field[0]["source"] == soul_anchor, "Necro's arena strike is tied to a killable anchor")
			var hp_before_link: float = float(g.hero["hp"])
			soul_anchor["dead"] = true
			Combat.update_delayed(g, 2.0)
			check(is_equal_approx(float(g.hero["hp"]), hp_before_link),
				"Destroying a soul anchor cancels its warned arena strike")
		if boss_id == "kingblob":
			check(field.any(func(d): return bool(d.get("royal_spawn", false))),
				"King Blob's impact leaves a killable royal fragment")
		if boss_id == "glassoracle":
			check(field.all(func(d): return d.has("source")),
				"Oracle rays originate at physical mirrors")
			field[0]["source"]["dead"] = true
			g.delayed = [field[0]]
			g.hero["pos"] = Vector2(field[0]["pos"])
			var hp_before_ray: float = float(g.hero["hp"])
			Combat.update_delayed(g, 2.0)
			check(is_equal_approx(float(g.hero["hp"]), hp_before_ray),
				"Breaking a mirror cancels its warned ray")
		if boss_id == "dreadengine":
			var first_pass = field.filter(func(d): return int(d["map_pass"]) == 0)
			check(first_pass.size() == 4, "Dread Engine's piston bank leaves one open lane")
	# Between arena attacks, each boss maintains an actual moving bullet curtain.
	for boss_id in bosses:
		if boss_id == "chonkzilla":
			continue
		reset(g)
		g.hero["pos"] = Vector2.ZERO
		var shooter = specimen(g, boss_id, 1100 + bosses.find(boss_id))
		if boss_id == "necro" or boss_id == "glassoracle":
			var source_kind = "leech" if boss_id == "necro" else "mirror"
			var source = g.spawn_enemy(source_kind, Vector2(170.0, -120.0), false, false)
			source["soul_owner" if boss_id == "necro" else "oracle_owner"] = int(shooter["id"])
		Combat.boss_bullet_hell(g, shooter, 1, 0.5)
		var first_count: int = g.shots.size()
		Combat.boss_bullet_hell(g, shooter, 1, 0.8)
		check(first_count >= 3 and g.shots.size() > first_count,
			boss_id + " fires sustained, moving boss bullets")
		check(g.shots.size() <= 18 and g.shots.all(func(p): return int(p.get("boss_owner", -1)) == int(shooter["id"])),
			boss_id + " owns a bounded projectile curtain")

	# Chonkzilla is a distinct charge/terrain encounter, not a short teleport stomp.
	reset(g)
	var chonk = specimen(g, "chonkzilla", 501)
	Combat.ai(g, chonk, Vector2.DOWN, 260.0, 0.016, false)
	check(float(chonk["wind"]) > 0.5 and chonk.has("lock"), "Chonkzilla commits to a long, readable rush")
	Combat.ai(g, chonk, Vector2.DOWN, 260.0, 1.3, false)
	check(str(chonk.get("chonk_state", "")) == "rush" and float(chonk.get("chonk_speed", 0.0)) > 450.0,
		"Chonkzilla must actually enter a high-velocity body charge")
	var rock = g.spawn_enemy("blob", Vector2(0.0, -135.0), false, false)
	rock["chonk_pillar"] = true
	rock["chonk_owner"] = 501
	rock["summon"] = true
	rock["r"] = 37.0
	rock["hp"] = 40.0
	rock["max_hp"] = 40.0
	chonk["pos"] = Vector2(0, -140.0)
	Combat.ChonkzillaEncounter.after_motion(g, chonk, Vector2(0.0, -200.0))
	check(float(chonk.get("boss_recover", 0.0)) >= 2.0 and bool(rock.get("dead", false)),
		"Baiting Chonkzilla into a real, killable stone breaks its armor")
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "chonk_fault"),
		"Impact creates actual persistent seismic fissures")
	check(Combat.boss_identity_damage_factor(g, chonk) > 1.9,
		"Skill-based collision exposes a significant player damage window")

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
