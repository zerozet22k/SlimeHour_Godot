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
	check(Mixes.RECIPES.size() == 18, "Exactly 18 authored mutations")
	check(Mixes.unlock_count(24) == 0 and Mixes.unlock_count(25) == 1, "No mutations until every normal species has debuted (sector 25)")
	check(Mixes.unlock_count(27) == 1 and Mixes.unlock_count(28) == 2, "Normal adds one mutation every three sectors")
	check(Mixes.unlock_count(40) == 6, "Normal limits sector 40 to six recipes")
	check(Mixes.unlock_count(26, true) == 1 and Mixes.unlock_count(27, true) == 2, "Hard adds one every two sectors")
	check(Mixes.unlock_count(40, true) == 8, "Hard exposes eight mutations by sector 40")
	check(Mixes.encounter_chance(24) == 0.0 and Mixes.encounter_chance(40) <= 0.15, "Normal stays rare and gradual")
	check(Mixes.encounter_chance(40, true) > Mixes.encounter_chance(40), "Hard is more aggressive than Normal")
	var seen_ids: Dictionary = {}
	for i in range(Mixes.RECIPES.size()):
		var key = Mixes.recipe_id(i)
		check(not seen_ids.has(key), "Recipe %d has a unique ID" % i)
		seen_ids[key] = true
		var recipe = Mixes.RECIPES[i]
		check(db.has(str(recipe["a"])) and db.has(str(recipe["b"])), "Recipe %d uses real parent enemies" % i)
		check(not bool(db[str(recipe["a"])].get("boss", false)) and not bool(db[str(recipe["b"])].get("boss", false)), "Recipe %d excludes boss inheritance" % i)
	check(seen_ids.size() == 18, "All recipe IDs are stable")
	var g = Main.new()
	g.no_save = true
	g.enemy_db = db
	g.best["sector"] = 40
	g.profile["mobs"] = {Mixes.recipe_id(0): 42, Mixes.recipe_id(9): 3}
	# A veteran with complete past knowledge still cannot spawn recipes in a fresh run.
	g.sector = 1
	g.run_mutations_unlocked.clear()
	check(g.mutation_is_discovered(Mixes.recipe_id(0)), "Permanent Bestiary discovery survives")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(0)), "Previously discovered mutation starts run locked")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(9)), "Best-sector 40 doesn't unlock future recipes")
	g.introduce_mutations()
	check(g.run_mutations_unlocked.is_empty(), "Sector 1 has no mutation introductions")
	g.sector = 25
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 2 and g.run_mutations_unlocked.has(Mixes.recipe_id(0)) and g.run_mutations_unlocked.has(Mixes.recipe_ids(0)[1]), "Sector 25 unlocks both sides of the first mutation")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(1)), "Sector 28 mutation remains locked at sector 25")
	g.sector = 28
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 4, "Both sides of the second mutation introduce at sector 28")
	g.sector = 1
	g.run_mutations_unlocked.clear()
	check(g.run_mutations_unlocked.is_empty() and g.mutation_is_discovered(Mixes.recipe_id(0)), "Starting next run resets eligibility but keeps discovery")
	g.sector = 27
	g.hard_mode = true
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 4, "Hard run unlocks both sides of two recipes by sector 27")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(2)), "Third recipe remains locked on Hard before sector 29")

	# Limits do not erase Mutation Book recipes; they control actual encounters.
	g.hard_mode = false
	g.sector = 40
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 12, "Six recipes (12 ordered forms) stay unlocked by sector 40")
	var active_normal := g.active_mutation_ids()
	check(active_normal.size() == 4 and active_normal.has(Mixes.recipe_id(5)),
		"Normal limits each sector to two active mutation pairs, including the latest")
	g.sector = 41
	var rotated_normal := g.active_mutation_ids()
	check(rotated_normal.size() == 4 and active_normal != rotated_normal,
		"Older mutations rotate between sectors instead of disappearing permanently")
	g.sector = 40
	g.mutation_spawn_sector = 40
	g.mutation_sector_spawns = g.mutation_sector_limit()
	var all_normal := true
	for i in range(150):
		if str(g.pick_enemy()).begins_with("mix_"):
			all_normal = false
	check(all_normal, "A sector's encounter budget blocks further mutants without blocking normal monsters")
	g.mutation_sector_spawns = 0
	g.enemies = [{"kind": active_normal[0], "dead": false}, {"kind": active_normal[1], "dead": false}]
	all_normal = true
	for i in range(150):
		if str(g.pick_enemy()).begins_with("mix_"):
			all_normal = false
	check(all_normal, "Two living mutants block additional Normal mutation spawns")
	g.enemies.clear()
	var sample_hits := 0
	for i in range(500):
		var picked: String = g.pick_enemy()
		if picked.begins_with("mix_"):
			sample_hits += 1
			if not active_normal.has(picked):
				check(false, "Inactive mutation pair never spawns in Normal")
	check(sample_hits >= 15 and sample_hits <= 90,
		"Encounter chance is actually honored (sample 500 rolls, not parent-replacement spam)")
	g.mutation_sector_spawns = g.mutation_sector_limit()
	g.sector = 41
	check(g.pick_enemy() is String and g.mutation_sector_spawns == 0,
		"Changing sectors resets the spawn budget for the next encounter")
	g.hard_mode = true
	g.sector = 40
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 16, "Hard unlocks eight recipes by sector 40")
	var active_hard := g.active_mutation_ids()
	check(active_hard.size() == 6 and active_hard.has(Mixes.recipe_id(7)),
		"Hard rotates three active mutation pairs, including its latest")
	check(g.mutation_live_limit() == 3 and g.mutation_sector_limit() == 10,
		"Hard has a separate bounded live and per-sector mutation limit")
	g.free()
	var main_source = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var hud_source = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	check(main_source.contains("run_mutations_unlocked.clear()"), "Run-start cleanup is mandatory")
	check(not main_source.contains("profile[\"mutations_unlocked\"]"), "No persistent mutation spawn eligibility exists")
	check(hud_source.contains("MUTATION BOOK") and hud_source.contains("CURRENT RUN: LOCKED"), "Mutation Book distinguishes current locks from permanent discovery")
	print("MUTATION PROGRESSION: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
