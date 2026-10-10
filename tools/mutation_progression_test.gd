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
	check(Mixes.unlock_count(15) == 0 and Mixes.unlock_count(16) == 1, "No early mutations before sector 16")
	check(Mixes.unlock_count(19) == 1 and Mixes.unlock_count(20) == 2, "Normal adds one mutation every four sectors")
	check(Mixes.unlock_count(24) == 3 and Mixes.unlock_count(40) == 7, "Normal limits sector 40 to seven recipes")
	check(Mixes.unlock_count(17, true) == 1 and Mixes.unlock_count(18, true) == 2, "Hard adds one every two sectors")
	check(Mixes.unlock_count(40, true) == 13, "Hard exposes thirteen mutations by sector 40")
	check(Mixes.encounter_chance(15) == 0.0 and Mixes.encounter_chance(40) <= 0.15, "Normal stays rare and gradual")
	check(Mixes.encounter_chance(40, true) > 0.40, "Hard is deliberately aggressive")
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
	g.sector = 16
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 1 and g.run_mutations_unlocked.has(Mixes.recipe_id(0)), "Sector 16 unlocks only the first mutation in this run")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(1)), "Sector 20 mutation remains locked at sector 16")
	g.sector = 20
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 2, "Second mutation introduces at sector 20")
	g.sector = 1
	g.run_mutations_unlocked.clear()
	check(g.run_mutations_unlocked.is_empty() and g.mutation_is_discovered(Mixes.recipe_id(0)), "Starting next run resets eligibility but keeps discovery")
	g.sector = 18
	g.hard_mode = true
	g.introduce_mutations()
	check(g.run_mutations_unlocked.size() == 2, "Hard run unlocks two recipes by sector 18")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(2)), "Third recipe remains locked on Hard before sector 20")
	g.free()
	var main_source = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var hud_source = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	check(main_source.contains("run_mutations_unlocked.clear()"), "Run-start cleanup is mandatory")
	check(not main_source.contains("profile[\"mutations_unlocked\"]"), "No persistent mutation spawn eligibility exists")
	check(hud_source.contains("MUTATION BOOK") and hud_source.contains("CURRENT RUN: LOCKED"), "Mutation Book distinguishes current locks from permanent discovery")
	print("MUTATION PROGRESSION: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
