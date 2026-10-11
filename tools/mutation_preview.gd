extends SceneTree
## Renders the curated mutations next to their parents to tools/art_review/mutation_preview.png.
## Needs a real window:  Godot --path . --script tools/mutation_preview.gd

const EnemyMixes = preload("res://scripts/EnemyMixes.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.enemies.clear()
	game.obstacles.clear()
	game.state = "playing"
	var c: Vector2 = game.hero["pos"]
	var i := 0
	for recipe in EnemyMixes.RECIPES.slice(0, 12):
		var id: String = EnemyMixes.ensure(game.enemy_db, str(recipe["a"]), str(recipe["b"]))
		if id == "":
			continue
		var pos := c + Vector2(-450 + (i % 6) * 180, -330 + floori(i / 6.0) * 210)
		var e = game.spawn_enemy(id, pos, false, false)
		e["spawn"] = 1.0
		e["aim"] = Vector2.DOWN
		i += 1
	game.set_physics_process(false)
	game.banner_t = 0.0
	for k in range(10):
		await process_frame
	print("Capture: ", root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/mutation_preview.png")))
	quit()
