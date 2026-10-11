extends SceneTree
## Spitters firing acid (with curving hooks) -> tools/art_review/acid_preview_N.png.
## Needs a real window:  Godot --path . --script tools/acid_preview.gd

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.enemies.clear()
	game.obstacles.clear()
	game.debug_session = true
	game.debug_godmode = true
	game.banner_t = 0.0
	game.sector = 7
	var c: Vector2 = game.hero["pos"]
	var spitters = []
	for x in [-260.0, 0.0, 260.0]:
		var e = game.spawn_enemy("spitter", c + Vector2(x, -330), false, false)
		e["spawn"] = 1.0
		e["cd"] = 0.0
		spitters.append(e)
	var shot := 0
	for frame in range(150):
		for e in spitters:
			e["pos"] = c + Vector2(e["pos"].x - c.x, -330)
		game.hero["pos"] = c + Vector2(sin(frame * 0.05) * 120.0, 0)
		await physics_frame
		if frame in [70, 110, 149]:
			game.banner_t = 0.0
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/acid_preview_%d.png" % shot))
			shot += 1
	quit()
