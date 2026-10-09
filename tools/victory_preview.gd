extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sector = 20
	game.kills = 842
	game.level = 26
	game.run_time = 1420.0
	game.sector_clear()
	for i in range(4):
		await process_frame
	var out = "res://tools/art_review/victory_preview.png"
	var err = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("Victory preview: ", out, " error=", err)
	quit()
