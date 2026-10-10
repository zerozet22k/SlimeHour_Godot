extends SceneTree
## Integrated boss spawn gating / death-camera reveal / entire-arena dash test.
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
		"r": float(data["r"]), "dmg": float(data["dmg"]), "t": 0.0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.state = "playing"
	g.phase = "fight"
	g.sector = 5
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "hp": 999.0,
		"maxhp": 999.0, "shield": 0, "dash_window": 0.0, "iframe": 100.0}
	g.route = {"name": "BOSS ROAD"}
	g.cam_y = -150.0
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		g.enemy_db[str(record["id"])] = record

	# 75% progress no longer spawns a boss while monsters remain alive.
	g.sector_budget = 10
	g.budget_spawned = 10
	g.sector_kills = 8
	g.rush_done = true
	g.rush_queue = 0
	var mob = {"id": 10, "boss": false, "kind": "blob", "dead": false}
	g.enemies.append(mob)
	check(not g.regular_crowd_defeated(), "Boss gate rejects living regular mobs even past 75% progress")
	mob["dead"] = true
	check(g.regular_crowd_defeated(), "Boss gate opens only after final mob dies")
	g.rush_queue = 1
	check(not g.regular_crowd_defeated(), "Boss gate waits for final rush monster to spawn")
	g.rush_queue = 0
	g.budget_spawned = 9
	check(not g.regular_crowd_defeated(), "Boss gate waits for entire spawn budget")
	g.budget_spawned = 10
	g.enemies.clear()
	g.begin_boss_reveal("chonkzilla")
	check(g.boss_spawned and g.boss_intro_t >= 3.5 and g.boss_intro_kind == "chonkzilla", "Boss reveal starts cinematic timer and marks spawn")
	check(g.enemies.size() == 1 and bool(g.enemies[0]["boss"]), "Cinematic spawns exactly one boss with no crowd")
	var before = g.run_time
	g._physics_process(0.016)
	check(is_equal_approx(g.run_time, before), "Cinematic freezes combat simulation including hero and guns")
	check(not g.crowd_cleared(), "Boss fight does not end before its boss is killed")
	g.boss_intro_t = 0.0
	g.enemies.clear()

	var all = ["chonkzilla", "heli", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine"]
	for i in range(all.size()):
		g.delayed.clear()
		var boss = make_boss(g, all[i], i + 100)
		boss["arena_t"] = 0.1
		Combat.boss_arena_tick(g, boss, 0.2)
		var events = g.delayed.filter(func(d): return str(d.get("fn", "")) == "arena_event")
		check(events.size() >= 1, all[i] + ": can trigger full-arena attack")
		if events.is_empty():
			continue
		check(events[0].has("life") and events[0].has("style") and events[0].has("color"), all[i] + ": arena has timed warning and signature style")
		check(float(events[0]["life"]) >= 1.7 and float(events[0]["life"]) <= 2.3, all[i] + ": dodge gets clear impact warning")
		check(float(boss["arena_t"]) >= 8.0, all[i] + ": global pressure is intense but bounded")
		if events.size() > 1:
			check(float(events[1]["t"]) - float(events[0]["t"]) >= 1.5, all[i] + ": second impact allows dash recharge")
			check(bool(events[1].get("second", false)), all[i] + ": second impact is explicit")
		# Resolve in place (no movement to a safe spot): existing dash iframes
		# must prevent damage even when warning fills the entire world road.
		var hp = float(g.hero["hp"])
		g.hero["iframe"] = 100.0
		Combat.update_delayed(g, float(events[0]["life"]) + 0.01)
		check(is_equal_approx(float(g.hero["hp"]), hp), all[i] + ": dodge invulnerability wins against arena impact")
		g.delayed.clear()
	var hud = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	var visuals = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(hud.contains("func paint_boss_cinematic") and hud.contains("func paint_arena_warning"), "Portrait and desktop have cinematic and impact countdown")
	check(visuals.contains('"arena_event"') and visuals.contains("g.view_bottom"), "Arena danger draws across the full visible viewport")
	g.free()
	print("BOSS ENCOUNTER TEST: ", "PASS" if errors == 0 else str(errors) + " failures")
	quit(1 if errors else 0)
