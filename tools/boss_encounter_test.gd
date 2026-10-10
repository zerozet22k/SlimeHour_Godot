extends SceneTree
## Cinematic gating and unique boss setpieces. Run --headless --script tools/boss_encounter_test.gd.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")

class SilentSfx:
	extends RefCounted
	func play(_id: String) -> void:
		pass
	func play_projectile(_id: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var errors := 0

func check(ok: bool, desc: String) -> void:
	if ok:
		print("PASS: ", desc)
	else:
		errors += 1
		push_error("ENCOUNTER FAIL: " + desc)

func make_boss(g, kind: String, uid: int) -> Dictionary:
	var data: Dictionary = g.enemy_db[kind]
	return {"id": uid, "kind": kind, "boss": true, "dead": false,
		"hp": 300.0, "max_hp": 300.0, "pos": Vector2(0, -170),
		"r": float(data["r"]), "speed": float(data["speed"]),
		"dmg": float(data["dmg"]), "t": 0.0, "cd": 0.0,
		"arena_t": 0.1, "engine_heat": 0.0}

func reset(g) -> void:
	g.enemies.clear()
	g.delayed.clear()
	g.shots.clear()
	g.hero["pos"] = Vector2.ZERO
	g.hero["vel"] = Vector2(90.0, 0.0)
	g.hero["push"] = Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.state = "playing"
	g.phase = "fight"
	g.sector = 5
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "push": Vector2.ZERO,
		"hp": 999.0, "maxhp": 999.0, "shield": 0,
		"dash_window": 0.0, "iframe": 100.0}
	g.route = {"name": "BOSS ROAD"}
	g.cam_y = -150.0
	g.road_half = 490.0
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		g.enemy_db[str(record["id"])] = record

	g.sector_budget = 10
	g.budget_spawned = 10
	g.sector_kills = 8
	g.rush_done = true
	g.rush_queue = 0
	var mob = {"id": 10, "boss": false, "kind": "blob", "dead": false}
	g.enemies.append(mob)
	check(not g.regular_crowd_defeated(), "Boss gate rejects living mobs")
	mob["dead"] = true
	check(g.regular_crowd_defeated(), "Boss gate opens after the last mob dies")
	g.rush_queue = 1
	check(not g.regular_crowd_defeated(), "Boss gate waits for the rush queue")
	g.rush_queue = 0
	g.budget_spawned = 9
	check(not g.regular_crowd_defeated(), "Boss gate waits for entire budget")
	g.budget_spawned = 10
	g.enemies.clear()
	g.begin_boss_reveal("chonkzilla")
	check(g.boss_spawned and g.boss_intro_t >= 3.5 and g.boss_intro_kind == "chonkzilla", "Cinematic boss reveal")
	check(g.enemies.size() == 1 and bool(g.enemies[0]["boss"]), "Exactly one boss after cleared crowd")
	var before = g.run_time
	g._physics_process(0.016)
	check(is_equal_approx(g.run_time, before), "Reveal freezes all simulation")
	check(not g.crowd_cleared(), "Boss blocks route completion")
	g.boss_intro_t = 0.0
	reset(g)

	var kinds = ["chonkzilla", "heli", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine"]
	var signatures = ["chonk_owner", "boss_missile", "possessed", "royal_owner",
		"boss_serpent_emerge", "boss_echo", "boss_gravity", "engine_owner"]
	for i in range(kinds.size()):
		reset(g)
		var boss = make_boss(g, kinds[i], 100 + i)
		if kinds[i] == "necro":
			var ward = g.spawn_enemy("leech", Vector2(80.0, -160.0), false, false)
			ward["soul_owner"] = int(boss["id"])
		Combat.boss_arena_tick(g, boss, 0.2)
		check(not g.delayed.any(func(d): return str(d.get("fn", "")) == "arena_event"),
			kinds[i] + ": no fullscreen, unavoidable boss attack")
		check(g.delayed.size() <= 8, kinds[i] + ": limited simultaneous warnings")
		if kinds[i] in ["chonkzilla", "necro", "kingblob", "dreadengine"]:
			var id_key = signatures[i] if kinds[i] != "necro" else "possessed"
			check(g.enemies.any(func(m): return bool(m.get(id_key, false)) if id_key == "possessed" else int(m.get(id_key, -1)) == int(boss["id"])),
				kinds[i] + ": creates real targetable encounter actors")
		else:
			check(g.delayed.any(func(d): return str(d.get("fn", "")) == signatures[i]),
				kinds[i] + ": unique physical setpiece")
		check(float(boss["arena_t"]) >= 5.0, kinds[i] + ": special is cooldown bounded")

	# Chonkzilla's setpieces are destructible terrain, not a fake moving circle.
	reset(g)
	var chonk = make_boss(g, "chonkzilla", 300)
	chonk["stone_t"] = 0.0
	Combat.boss_arena_tick(g, chonk, 0.2)
	var chonk_rocks = g.enemies.filter(func(m): return int(m.get("chonk_owner", -1)) == 300)
	check(chonk_rocks.size() >= 1, "Chonkzilla plants targetable terrain along its charge path")
	if not chonk_rocks.is_empty():
		check(bool(chonk_rocks[0].get("chonk_pillar", false)) and float(chonk_rocks[0]["hp"]) > 0.0,
			"Rock has an actual damageable enemy hitbox")

	# Heli missile must launch an actual homing projectile after warning.
	reset(g)
	var helicopter = make_boss(g, "heli", 301)
	Combat.boss_arena_tick(g, helicopter, 0.2)
	Combat.update_delayed(g, 1.5)
	check(g.shots.any(func(p): return float(p.get("homing", 0.0)) > 0.6),
		"Heli launches a genuine guided missile")

	# Coil Queen actually changes location, with a previously locked tell.
	reset(g)
	var queen = make_boss(g, "coilqueen", 302)
	Combat.boss_arena_tick(g, queen, 0.2)
	var previous: Vector2 = queen["pos"]
	check(bool(queen.get("burrowing", false)), "Coil Queen enters burrow")
	Combat.update_delayed(g, 1.5)
	check(not bool(queen.get("burrowing", false)) and queen["pos"].distance_to(previous) > 10.0,
		"Coil Queen surfaces at the warned location")

	# Gravity changes motion only inside the visible field.
	reset(g)
	var weaver = make_boss(g, "voidweaver", 303)
	Combat.boss_arena_tick(g, weaver, 0.2)
	var gravity = g.delayed.filter(func(d): return str(d.get("fn", "")) == "boss_gravity")
	if not gravity.is_empty():
		gravity[0]["arm"] = 0.0
		g.hero["pos"] = gravity[0]["pos"] + Vector2(85.0, 0.0)
		Combat.update_delayed(g, 0.1)
		check(Vector2(g.hero["push"]).length() > 0.0, "Weaver's gravity physically pulls nearby player")
		g.hero["push"] = Vector2.ZERO
	else:
		check(false, "Weaver spawns gravity knot")

	# Break the Engine's weapon pods: the hull armor drops and reactor heats.
	reset(g)
	var engine = make_boss(g, "dreadengine", 304)
	Combat.boss_arena_tick(g, engine, 0.2)
	check(int(engine.get("engine_parts_last", 0)) > 0, "Engine creates destroyable modules")
	for pod in g.enemies:
		if int(pod.get("engine_owner", -1)) == int(engine["id"]):
			pod["dead"] = true
	Combat.boss_arena_tick(g, engine, 0.1)
	check(float(engine.get("engine_heat", 0.0)) > 20.0, "Destroying pods increases Engine heat")
	check(Combat.boss_identity_damage_factor(g, engine) > 0.8, "Destroyed pods reduce Engine armor")

	var visuals = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(visuals.contains('"boss_gravity"') and visuals.contains('"chonk_fault"') and visuals.contains('"chonk_pillar"'), "Physical setpieces render exact locations")
	check(not visuals.contains('== "arena_event"'), "Renderer no longer paints unavoidable viewport damage")
	var hud = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	check(hud.contains("func paint_boss_cinematic"), "Cinematic portrait and desktop remain present")
	g.free()
	print("BOSS ENCOUNTER TEST: ", "PASS" if errors == 0 else str(errors) + " failures")
	quit(1 if errors else 0)
