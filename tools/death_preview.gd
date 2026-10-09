extends SceneTree
## Screenshot of the death camera: build/death.png (needs a window).

func _initialize() -> void:
	call_deferred("shot")

func shot() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	for i in range(3):
		await process_frame
	game.start_run()
	game.banner_t = 0.0
	game.settings["hints"] = false
	var e = game.spawn_enemy("spitter", game.hero["pos"] + Vector2(160, -260))
	game.last_hit_by = "a Spitter's shot"
	game.game_over()
	await create_timer(1.6, true, false, true).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/death.png"))
	print("DEATH PREVIEW OK")
	quit()
