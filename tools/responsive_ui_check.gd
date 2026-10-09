extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.open_offers("level")
	for size in [Vector2i(390, 844), Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(size)
		for frame in range(5):
			await process_frame
		for screen in ["menu", "settings", "collection", "levelup", "paused"]:
			game.state = screen
			for frame in range(3):
				await process_frame
			var bounds = Rect2(Vector2.ZERO, Vector2(720, game.ui_height) if game.portrait else Vector2(1280, 720))
			for button in game.hud.buttons:
				assert(bounds.encloses(button.rect), "%s %s outside screen" % [size, screen])
			root.get_texture().get_image().save_png("res://build/ui-%dx%d-%s.png" % [size.x, size.y, screen])
	print("RESPONSIVE UI CHECK OK: 4 sizes, 5 screens")
	quit()
