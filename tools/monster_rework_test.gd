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
	# Every species gives an actual behavior module with receiver capabilities.
	var Mixes = load("res://scripts/EnemyMixes.gd")
	var MK = load("res://scripts/MutationKit.gd")
	var Genome = load("res://scripts/FusionGenome.gd")
	var abilities := {}
	for species in Mixes.FEATURES:
		var spec: Dictionary = Genome.donor_spec(str(species))
		check(not spec.is_empty() and not Genome.body_caps(str(species)).is_empty(),
			str(species) + " has a transferable behavior and a receiving kit")
		abilities[str(spec["module"])] = true
	check(abilities.size() == 25, "All 25 normal species give distinct behavior mechanics")
	g.enemies.clear()
	g.delayed.clear()
	# Medic passes real interruptible triage, not a radial laser/bomb skin.
	var medic_id: String = Mixes.ensure(g.enemy_db, "larry", "nurse")
	var medic = g.spawn_enemy(medic_id, Vector2(0, -200), false, false)
	medic["graft_cd"] = 0.0
	MK.fusion_move(g, medic)
	check(g.delayed.size() == 1 and str(g.delayed[0].get("module", "")) == "triage",
		"Laser Larry body + Medic supplies one warned triage action, not ten healing lasers")
	check(MK.display_name(g, medic_id).ends_with("Laser Larry"), "Mutant identity retains its body name")
	g.delayed.clear()
	var bomb_id: String = Mixes.ensure(g.enemy_db, "kaboomba", "nurse")
	var bomber = g.spawn_enemy(bomb_id, Vector2(0, -200), false, false)
	bomber["graft_cd"] = 0.0
	MK.fusion_move(g, bomber)
	check(g.delayed.size() == 1 and str(g.delayed[0].get("module", "")) == "triage",
		"Kaboomba body + Medic gives healing, not a copied explosion fan")
	# Mutants show and use their body parent's attacks (tells, tethers, dashes).
	var visual_src := FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	var combat_src := FileAccess.get_file_as_string("res://scripts/Combat.gd")
	check((visual_src.contains('enemy_has_role(e, "leech") and float(e.get("tether_t"') or visual_src.contains('body == "leech" and float(e.get("tether_t"')) and visual_src.contains('var body: String = MutationKit.acting(g, e)') and not visual_src.contains('e["kind"] == "leech"'), "A Leech-bodied mutant draws its blood tether")
	check(combat_src.contains('var body_kind: String = MutationKit.acting(g, e)') and not combat_src.contains('str(e["kind"]) == "skitter"'), "Mutants move with the parent they are acting as (dash, ricochet)")
	# Grafts must not invent attacks from unrelated species; egg effects inherit
	# the body's color and are emitted from an actual Mama module.
	for pair in [["mini", "mama"], ["mama", "mini"], ["mortar", "mini"]]:
		g.delayed.clear()
		var id: String = EnemyMixes.ensure(g.enemy_db, pair[0], pair[1])
		var variant = g.spawn_enemy(id, Vector2(0, -200), false, false)
		variant["graft_cd"] = 0.0
		MK.fusion_move(g, variant)
		check(g.delayed.size() == 1 and str(g.delayed[0].get("fn", "")) == "genome_graft",
			str(pair) + " schedules one behavior-graft event without a laser barrage")
		if str(pair[1]) == "mama":
			g.enemy_hazards.clear()
			Genome.resolve(g, g.delayed[0])
			check(g.enemy_hazards.size() == 1 and str(g.enemy_hazards[0].get("kind", "")) == "egg"
				and str(g.enemy_hazards[0].get("mut_col", "")) == str(variant["mut_col"]),
				"Donated Mama egg carries the mutant color without generic effects")
	if errors > 0:
		push_error("%d monster checks failed" % errors)
		quit(1)
	else:
		print("MONSTER REWORK TESTS: PASS")
		quit(0)
