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

	check(g.boss_arena_on, "Boss reveal locks the arena")
	if errors > 0:
		push_error("%d boss encounter checks failed" % errors)
		quit(1)
	else:
		print("All boss encounter checks passed")
		quit(0)
