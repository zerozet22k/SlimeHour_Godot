extends SceneTree
## Mitosis halves re-merge; Ticks hop; new mutation parts exist for every species.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const MonsterModels = preload("res://scripts/MonsterModels.gd")

class SilentSfx:
	extends RefCounted
	func play(_id: String, _a = 0.0, _b = 1.0, _c = 1.0) -> void:
		pass
	func play_projectile(_id: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var errors := 0

func check(ok: bool, desc: String) -> void:
	if ok:
		print("PASS: ", desc)
	else:
		errors += 1
		push_error("MONSTER FAIL: " + desc)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.state = "playing"
	g.sector = 8
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "push": Vector2.ZERO, "hp": 999.0, "maxhp": 999.0,
		"shield": 0, "dash_window": 0.0, "iframe": 100.0, "flash": 0.0, "aim": Vector2.DOWN, "moving": false}
	g.route = {"name": "TEST"}
	g.road_half = 640.0
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		g.enemy_db[str(record["id"])] = record
	# Mitosis splits into two halves that re-merge.
	var cell = g.spawn_enemy("mitosis", Vector2(0, -200), false, false)
	Combat.kill(g, cell, {"gen": 1, "pos": cell["pos"]}, 0.0)
	var halves = g.enemies.filter(func(m): return bool(m.get("half", false)) and not bool(m["dead"]))
	check(halves.size() == 2, "Mitosis splits into two halves, not Minis")
	for i in range(240):
		g.hero["iframe"] = 100.0
		Combat.build_grid(g)
		Combat.update_enemies(g, 1.0 / 30.0)
		g.enemies = g.enemies.filter(func(e): return not bool(e["dead"]))
	var whole = g.enemies.filter(func(m): return str(m["kind"]) == "mitosis" and not bool(m.get("half", false)))
	check(whole.size() == 1, "Untouched halves crawl together and re-merge")
	# A frozen Mitosis cannot split.
	g.enemies.clear()
	var frozen = g.spawn_enemy("mitosis", Vector2(0, -200), false, false)
	frozen["frozen"] = 1.0
	Combat.kill(g, frozen, {"gen": 1, "pos": frozen["pos"]}, 0.0)
	check(g.enemies.filter(func(m): return not bool(m["dead"])).is_empty(), "Freezing stops the split")
	# Ticks hop instead of walking.
	g.enemies.clear()
	var tick = g.spawn_enemy("tick", Vector2(0, -300), false, false)
	var speeds: Array = []
	for i in range(60):
		g.hero["iframe"] = 100.0
		Combat.build_grid(g)
		Combat.update_enemies(g, 1.0 / 30.0)
		speeds.append(Vector2(tick["vel"]).length())
	check(speeds.max() > float(tick["speed"]) * 2.0 and speeds.min() < float(tick["speed"]) * 0.3, "Lil Tick moves in hops")
	# Every species offers mutation parts that can be drawn on any body.
	for species in EnemyMixes.FEATURES:
		check(not EnemyMixes.FEATURES[species].is_empty(), species + " has inheritable mutation parts")
	for part in ["nozzle", "fuse", "sucker", "megaphone", "cross"]:
		check(EnemyMixes.TRAIT_NAMES.has(part), part + " has a mutation name")
	# Mutations: body parent delivers, second parent supplies the payload.
	var Mixes = load("res://scripts/EnemyMixes.gd")
	var MK = load("res://scripts/MutationKit.gd")
	for species in Mixes.FEATURES:
		check(MK.GIVES.has(species), species + " gives a mutation payload")
	g.enemies.clear()
	g.delayed.clear()
	var ids := {}
	for pair in [["nurse", "larry", "laser"], ["nurse", "kaboomba", "explode"]]:
		var n := 0
		var id: String = ""
		while true:
			id = "mix_" + pair[0] + "_t" + str(n) + "_" + pair[1]
			if MK.payload_for(id, pair[1]) == pair[2]:
				break
			n += 1
		var base: Dictionary = g.enemy_db[pair[0]].duplicate(true)
		base["id"] = id
		base["mix"] = [pair[0], pair[1]]
		base["name"] = "test"
		g.enemy_db[id] = base
		ids[pair[1]] = id
	# Pin the augment for a deterministic check.
	var medic = g.spawn_enemy(ids["larry"], Vector2(0, -200), false, false)
	medic["mut_pulse_t"] = 0.0
	Combat.ai(g, medic, Vector2.DOWN, 200.0, 0.016, false)
	check(g.delayed.filter(func(d): return str(d.get("fn", "")) == "boss_line").size() == 6, "Medic body + laser pulses a 6-way laser star")
	check(MK.display_name(g, ids["larry"]).ends_with(" Medic"), "Mutant is named for its augment and body")
	var seen_augments := {}
	for k in range(40):
		seen_augments[MK.payload_for("mix_x" + str(k), "larry")] = true
	check(seen_augments.size() == 2, "A giver passes on either of its two augments depending on the mutation")
	g.delayed.clear()
	var bomber = g.spawn_enemy(ids["kaboomba"], Vector2(0, -200), false, false)
	bomber["mut_pulse_t"] = 0.0
	Combat.ai(g, bomber, Vector2.DOWN, 200.0, 0.016, false)
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "mut_pulse" and str(d.get("payload", "")) == "explode"), "Medic body + Kaboomba pulses a warned explosion")
	if errors > 0:
		push_error("%d monster checks failed" % errors)
		quit(1)
	else:
		print("MONSTER REWORK TESTS: PASS")
		quit(0)
