extends SceneTree
## Every new run MUST relock mutations. The book remembers kills, but
## historical discoveries and the player's best sector must not grant spawns.
const Main = preload("res://scripts/Main.gd")
const Mixes = preload("res://scripts/EnemyMixes.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var db: Dictionary = {}
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for item in roster:
		db[str(item["id"])] = item
	check(Mixes.FIRST_FUSION_SECTOR == 25, "Procedural mutation encounters start only after the normal roster")
	check(Mixes.unlock_count(24) == 0 and Mixes.unlock_count(25) == 1, "One new pair at sector 25")
	check(Mixes.unlock_count(28) == 2 and Mixes.unlock_count(40) == 6, "Normal adds a pair every three sectors")
	check(Mixes.unlock_count(27, true) == 2 and Mixes.unlock_count(40, true) == 8, "Hard adds a pair every two sectors")
	check(Mixes.encounter_chance(24) == 0.0 and Mixes.encounter_chance(40) <= 0.15, "Normal encounter chance remains low")
	var g = Main.new()
	g.no_save = true
	g.enemy_db = db
	g.best["sector"] = 40
	g.profile["mobs"] = {Mixes.recipe_id(0): 42}
	g.sector = 1
	g.introduce_mutations()
	check(g.run_mutations_unlocked.is_empty(), "No early mutation introduction")
	g.sector = 40
	g.introduce_mutations()
	check(g.run_mutations_unlocked.is_empty(), "Normal road never unlocks mutations (Hard road only)")
	g.hard_mode = true
	g.sector = 25
	g.introduce_mutations()
	check(g.run_mutation_pairs.size() == 18 and g.run_mutations_unlocked.size() == 2,
		"Each run rolls 18 distinct compatible pairs; both directions of the first are unlocked")
	var first: Array = g.run_mutation_pairs[0]
	var first_id := Mixes.id_for(str(first[0]), str(first[1]))
	check(g.mutation_is_unlocked(first_id), "Generated first pair is unlocked in this run")
	check(g.mutation_is_discovered(Mixes.recipe_id(0)), "Old Mutation Book discoveries survive")
	check(Mixes.compatible_pair(str(first[0]), str(first[1])), "Every chosen combination has a meaningful donor module in either direction")
	for pair in g.run_mutation_pairs:
		check(Mixes.compatible_pair(str(pair[0]), str(pair[1])), "Generated pair is compatible")
	g.sector = 28
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 4, "Hard gains two ordered mutants per recipe by sector 28")
	g.sector = 40
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 16, "Sector 40 has eight procedural recipes, not all 18")
	var active := g.active_mutation_ids()
	check(active.size() == 6 and active.has(Mixes.id_for(str(g.run_mutation_pairs[7][0]), str(g.run_mutation_pairs[7][1]))),
		"Hard limits a sector to three active recipes with the newest present")
	g.mutation_spawn_sector = 40
	g.mutation_sector_spawns = g.mutation_sector_limit()
	var blocked := true
	for i in range(100):
		if str(g.pick_enemy()).begins_with("mix_"):
			blocked = false
	check(blocked, "Sector budget blocks further mutation spawning")
	g.mutation_sector_spawns = 0
	g.enemies = [{"kind": active[0], "dead": false}, {"kind": active[1], "dead": false}, {"kind": active[2], "dead": false}]
	blocked = true
	for i in range(100):
		if str(g.pick_enemy()).begins_with("mix_"):
			blocked = false
	check(blocked, "Three living mutations block more on Hard")
	g.enemies.clear()
	var hits := 0
	for i in range(500):
		var chosen := str(g.pick_enemy())
		if chosen.begins_with("mix_"):
			hits += 1
			check(active.has(chosen), "Only active mutation recipes appear")
	check(hits >= 100 and hits <= 260, "Hard respects fusion encounter chance rather than replacing parent spawns")
	g.sector = 1
	g.run_mutations_unlocked.clear()
	g.run_mutation_pairs.clear()
	check(not g.mutation_is_unlocked(first_id) and g.mutation_is_discovered(Mixes.recipe_id(0)),
		"Fresh runs relock combinations but retain old discovery records")
	check(g.mutation_live_limit() == 3 and g.mutation_sector_limit() == 10,
		"Hard retains its mutation caps")
	g.free()
	print("PROCEDURAL MUTATION PROGRESSION: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures else 0)
