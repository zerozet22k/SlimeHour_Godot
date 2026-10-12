extends SceneTree
## Spawns fusions and logs what their combined signature move fires over 9 s.
##   Godot --path . --script res://tools/mutant_fusion_probe.gd   (MUTANT="mirror,larry;lancer,larry")
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
	var env := OS.get_environment("MUTANT")
	var pairs := (env if env != "" else "mirror,larry;lancer,larry;riot,mirror;mirror,riot;spitter,ashwing;burrower,kaboomba").split(";")
	for pair_text in pairs:
		var pair := pair_text.split(",")
		var id: String = EnemyMixes.ensure(game.enemy_db, pair[0], pair[1])
		game.enemies.clear()
		game.shots.clear()
		game.delayed.clear()
		game.enemy_hazards.clear()
		var e = game.spawn_enemy(id, game.hero["pos"] + Vector2(0, -240), false, false)
		e["hp"] = 99999.0
		e["max_hp"] = 99999.0
		var counts := {}
		var hz := {}
		for frame in range(60 * 9):
			game.state = "playing"
			game.hero["hp"] = game.hero["maxhp"]
			game.budget_spawned = game.sector_budget
			await physics_frame
			for s in game.shots:
				if not bool(s["friendly"]) and not s.has("probe_seen"):
					s["probe_seen"] = true
					var k := "spear" if bool(s.get("spear", false)) else str(s.get("src", "shot"))
					counts[k] = int(counts.get(k, 0)) + 1
			for d in game.delayed:
				if bool(d.get("mut_payload", false)) and not d.has("counted"):
					d["counted"] = true
					counts[str(d.get("fn", ""))] = int(counts.get(str(d.get("fn", "")), 0)) + 1
			for h in game.enemy_hazards:
				if not h.has("probe_seen"):
					h["probe_seen"] = true
					hz[str(h["kind"])] = int(hz.get(str(h["kind"]), 0)) + 1
		var sigs: Array = MutationKit.signatures(game, id)
		print("%s + %s -> %s  [%s]\n    %s\n    fired=%s hazards=%s" % [pair[0], pair[1], MutationKit.move_name_for(sigs), str(sigs), MutationKit.move_desc_for(sigs), str(counts), str(hz)])
	quit()
