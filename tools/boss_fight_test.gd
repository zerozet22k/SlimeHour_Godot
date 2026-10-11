extends SceneTree
## Simulates all eight boss fights through all three phases.
## Run: Godot --headless --path . --script tools/boss_fight_test.gd
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const BossFight = preload("res://scripts/BossFight.gd")

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
		push_error("BOSS FIGHT FAIL: " + desc)

func _initialize() -> void:
	call_deferred("_run")

func make_game():
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.state = "playing"
	g.phase = "fight"
	g.sector = 10
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "push": Vector2.ZERO, "hp": 999.0, "maxhp": 999.0,
		"shield": 0, "dash_window": 0.0, "iframe": 100.0, "flash": 0.0, "aim": Vector2.DOWN, "moving": false}
	g.route = {"name": "BOSS ROAD"}
	g.road_half = 640.0
	g.landscape_width = 1280.0
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		g.enemy_db[str(record["id"])] = record
	return g

func reset(g) -> void:
	g.enemies.clear()
	g.delayed.clear()
	g.shots.clear()
	g.zones.clear()
	g.hero["pos"] = Vector2.ZERO
	g.hero["push"] = Vector2.ZERO

func _run() -> void:
	var g = make_game()
	check_structure()
	for kind in BossFight.MOVES:
		fight(g, str(kind))
	check_safe_cells(g)
	check_damage_windows(g)
	if errors > 0:
		push_error("%d boss fight checks failed" % errors)
		quit(1)
	else:
		print("BOSS FIGHT TESTS: PASS")
		quit(0)

## Every attack belongs to exactly one boss, and phases open with something new.
func check_structure() -> void:
	var owner := {}
	for kind in BossFight.MOVES:
		var phases: Array = BossFight.MOVES[kind]
		check(phases.size() == 3, kind + ": three phases")
		for attack in phases[0] + phases[1] + phases[2]:
			check(BossFight.ATTACKS.has(attack), kind + ": " + str(attack) + " is defined")
			check(not owner.has(attack) or owner[attack] == kind, str(attack) + " is unique to one boss")
			owner[attack] = kind
		check(not phases[1][0] in phases[0], kind + ": phase 2 opens with a new attack")
		check(not phases[2][0] in phases[1], kind + ": final phase opens with an ultimate")

func step_world(g, dt: float) -> void:
	Combat.build_grid(g)
	Combat.update_delayed(g, dt)
	Combat.update_enemies(g, dt)
	Combat.update_shots(g, dt)
	g.enemies = g.enemies.filter(func(e): return not bool(e["dead"]))
	g.shots = g.shots.filter(func(s): return not bool(s.get("dead", false)))

func fight(g, kind: String) -> void:
	reset(g)
	var boss = g.spawn_enemy(kind, Vector2(0, -290), true)
	var seen := {}
	var phases_seen := {}
	var max_shots := 0
	var max_hazards := 0
	var dt := 1.0 / 30.0
	for phase in range(3):
		boss["hp"] = float(boss["max_hp"]) * [1.0, 0.6, 0.3][phase]
		for i in range(int(30.0 / dt)):
			g.hero["pos"] = Vector2(sin(i * 0.05) * 160.0, 0.0)
			g.hero["iframe"] = 100.0
			step_world(g, dt)
			if str(boss.get("bf_state", "")) == "attack":
				seen[str(boss["bf_attack"])] = true
			phases_seen[int(boss.get("bf_phase", 0))] = true
			max_shots = maxi(max_shots, g.shots.filter(func(s): return int(s.get("boss_owner", -1)) == int(boss["id"])).size())
			max_hazards = maxi(max_hazards, g.delayed.filter(func(d): return int(d.get("owner", -1)) == int(boss["id"])).size())
	for phase in range(3):
		for attack in BossFight.MOVES[kind][phase]:
			check(seen.has(attack), kind + ": performed " + str(attack))
	check(phases_seen.size() == 3, kind + ": went through all three phases")
	check(max_shots >= 30, kind + ": bullet-hell density (%d bullets)" % max_shots)
	check(max_shots <= BossFight.OWNED_CAP and max_hazards <= BossFight.HAZARD_CAP, kind + ": bullets and hazards stay bounded")
	Combat.kill(g, boss, {"gen": 0, "pos": boss["pos"]}, 0.0)
	check(not g.delayed.any(func(d): return int(d.get("owner", -1)) == int(boss["id"])), kind + ": warnings vanish on death")
	check(not g.shots.any(func(s): return int(s.get("boss_owner", -1)) == int(boss["id"]) and not bool(s["dead"])), kind + ": bullets vanish on death")
	check(not g.enemies.any(func(m): return int(m.get("minion_owner", -1)) == int(boss["id"]) and not bool(m["dead"])), kind + ": minions vanish on death")

## Every simultaneous wave of a map-wide attack leaves somewhere to stand.
func check_safe_cells(g) -> void:
	var grids = {"chonkzilla": "meteor_shower", "necro": "grave_march", "heli": "carpet_bomb",
		"dreadengine": "piston_bank", "voidweaver": "web_lattice"}
	for kind in grids:
		reset(g)
		var boss = g.spawn_enemy(kind, Vector2(0, -290), true)
		BossFight.update(g, boss, Vector2.DOWN, 290.0, 0.0)
		boss["bf_attack"] = grids[kind]
		boss["bf_lock"] = Vector2.ZERO
		boss["bf_side"] = 1.0
		boss["bf_i"] = 0
		BossFight.start_attack(g, boss, 2)
		var a: Dictionary = BossFight.arena(g)
		var times := {}
		for d in g.delayed:
			times[snappedf(float(d["t"]), 0.01)] = true
		var all_safe := true
		for t in times:
			var wave: Array = g.delayed.filter(func(d): return absf(float(d["t"]) - float(t)) < 0.02)
			var safe := false
			var y: float = float(a["top"]) + 20.0
			while y < float(a["bottom"]) and not safe:
				var x: float = float(a["left"]) + 20.0
				while x < float(a["right"]) and not safe:
					var hit := false
					for d in wave:
						if str(d["fn"]) == "boss_line":
							hit = Combat.seg_dist2(d["a"], d["b"], Vector2(x, y)) <= pow(float(d["tele"]) + 12.0, 2.0)
						else:
							hit = Vector2(x, y).distance_to(d["pos"]) <= float(d["tele"]) + 12.0
						if hit:
							break
					safe = not hit
					x += 12.0
				y += 12.0
			all_safe = all_safe and safe
		check(all_safe and not times.is_empty(), kind + ": every " + grids[kind] + " wave leaves a safe spot")

func check_damage_windows(g) -> void:
	reset(g)
	var oracle = g.spawn_enemy("glassoracle", Vector2(0, -290), true)
	BossFight.update(g, oracle, Vector2.DOWN, 290.0, 0.0)
	var mirror = BossFight.spawn_minion(g, oracle, "mirror", Vector2(100, -100), "mirror", 1.0, true)
	check(BossFight.damage_factor(g, oracle) < 0.5, "Living mirrors armour the Oracle")
	mirror["dead"] = true
	check(BossFight.damage_factor(g, oracle) == 1.0, "Breaking mirrors strips the armour")
	var engine = g.spawn_enemy("dreadengine", Vector2(0, -290), true)
	BossFight.update(g, engine, Vector2.DOWN, 290.0, 0.0)
	engine["bf_heat"] = 100.0
	BossFight.start_tell(g, engine, 0)
	check(str(engine["bf_state"]) == "vent" and BossFight.damage_factor(g, engine) > 1.5, "Overheated engine vents and exposes its core")
	var chonk = g.spawn_enemy("chonkzilla", Vector2(0, -290), true)
	BossFight.update(g, chonk, Vector2.DOWN, 290.0, 0.0)
	chonk["hp"] = float(chonk["max_hp"]) * 0.5
	BossFight.update(g, chonk, Vector2.DOWN, 290.0, 0.01)
	check(str(chonk["bf_state"]) == "transition" and BossFight.damage_factor(g, chonk) == 0.0, "Phase change is a brief invulnerable transition")
