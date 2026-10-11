extends SceneTree
## The shop (two rows, lock / ban) and the campfire -> tools/art_review/shop_preview.png
## and campfire_preview.png.  Needs a real window:  Godot --path . --script tools/shop_preview.gd

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.sector = 8
	game.gold = 900
	game.open_shop()
	game.shop_items[1]["locked"] = true
	for k in range(6):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/shop_preview.png"))
	game.state = "rest"
	game.phase = "rest"
	for k in range(4):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/campfire_preview.png"))
	quit()
