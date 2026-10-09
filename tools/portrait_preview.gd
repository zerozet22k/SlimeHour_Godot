extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/portrait-menu.png"))
	game.start_run()
	game.settings["touch"] = "auto"
	for i in range(16):
		await process_frame
	assert(game.portrait)
	assert(game.ui_height >= 1200.0)
	var out = ProjectSettings.globalize_path("res://build/portrait-preview.png")
	var err = root.get_texture().get_image().save_png(out)
	print("PORTRAIT PREVIEW ", out, " error=", err)
	game.open_offers("level")
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/portrait-offers.png"))
	game.state = "collection"
	game.hud.collection_cat = "weapons"
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/portrait-collection.png"))
	game.state = "settings"
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/portrait-settings.png"))
	game.state = "arsenal"
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/portrait-arsenal.png"))
	quit()
