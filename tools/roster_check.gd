extends SceneTree
## Enemies arrive in stages; any pair of previously-introduced species can mix.
const Combat = preload("res://scripts/Combat.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.start_run()
	check(game.available_enemies(1) == game.STARTER_ENEMIES, "Sector 1 has only starters")
	check(game.introduction_for(6) == "nurse", "Nurse debuts at Sector 6")
	check(game.introduction_for(8) == "skitter", "Skitter debuts at Sector 8")
	check(game.introduction_for(10) == "larry", "Larry debuts at Sector 10")
	check(game.introduction_for(11) == "", "Sector 11 has no fixed forced Nurse/Larry hybrid")
	check(not EnemyMixes.allowed(game.available_enemies(10), 10), "Hybrids locked before Sector 11")
	check(EnemyMixes.allowed(game.available_enemies(10), 11), "Hybrid spawning unlocks at Sector 11")
	check(not game.available_enemies(10).has("mirror"), "Later species do not debut prematurely")
	for i in range(game.ROUTE_INTRO_ORDER.size()):
		var sector = 6 + i * 2
		var species = str(game.ROUTE_INTRO_ORDER[i])
		check(game.introduction_for(sector) == species, species + " appears in its own introduction sector")
		check(not game.available_enemies(sector - 1).has(species), species + " is not available early")
		check(game.available_enemies(sector).has(species), species + " is available after debut")
	# All combinations are buildable on demand (canonical regardless of parent order).
	for pair in [["blob", "zoomer"], ["nurse", "larry"], ["nurse", "ashwing"], ["skitter", "spitter"]]:
		var first = str(pair[0])
		var second = str(pair[1])
		var id = EnemyMixes.ensure(game.enemy_db, first, second)
		check(id != "" and game.enemy_db.has(id), first + "+" + second + " can combine")
		check(id == EnemyMixes.ensure(game.enemy_db, second, first), first + "+" + second + " canonical regardless of order")
		var hybrid = game.spawn_enemy(id, game.hero["pos"] + Vector2(0, -300), false, false)
		Combat.ai(game, hybrid, Vector2.DOWN, 300.0, 0.1, false)
		check(str(hybrid["kind"]) == id, id + " spawns as a valid enemy")
		check(hybrid.has("mix_state_" + first) and hybrid.has("mix_state_" + second), id + " initializes both parent mechanics")
	# Introduction is a basic species, not an obligatory hybrid.
	game.sector = 12
	game.begin_sector()
	game.spawn_acc = 1.0
	game.update_director(0.0)
	check(game.intro_spawned and game.enemies.size() > 0 and str(game.enemies[0]["kind"]) == "leech", "Sector 12 introduces its base species first")
	game.queue_free()
	await process_frame
	print("ROSTER CHECK: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures else 0)
