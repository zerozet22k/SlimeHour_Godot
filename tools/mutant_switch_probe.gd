extends SceneTree
## Spawns one mutant and logs which parent it acts as and what it is doing.
##   Godot --path . --script res://tools/mutant_switch_probe.gd   (MUTANT=burrower,lancer)
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const MutationKit = preload("res://scripts/MutationKit.gd")

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.enemies.clear()
	game.debug_session = true
	game.debug_godmode = true
	var pair := (OS.get_environment("MUTANT") if OS.get_environment("MUTANT") != "" else "burrower,lancer").split(",")
	var id: String = EnemyMixes.ensure(game.enemy_db, pair[0], pair[1])
	var e = game.spawn_enemy(id, game.hero["pos"] + Vector2(0, -260), false, false)
	e["hp"] = 99999.0
	e["max_hp"] = 99999.0
	var last := ""
	for frame in range(60 * 14):
		game.state = "playing"
		game.hero["hp"] = game.hero["maxhp"]
		game.budget_spawned = game.sector_budget
		await physics_frame
		var acting := MutationKit.acting(game, e)
		var state := "burrowing" if bool(e.get("burrowing", false)) else ("winding " + str(e.get("lancer_attack", "")) if float(e.get("wind", 0.0)) > 0.0 else "")
		var line := "%s %s" % [acting, state]
		if line != last:
			print("t=%.1fs  acting=%s  %s" % [frame / 60.0, acting, state])
			last = line
	print("shots fired by it: ", game.shots.filter(func(s): return not bool(s["friendly"])).size())
	quit()
