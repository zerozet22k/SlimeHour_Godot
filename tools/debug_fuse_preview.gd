extends SceneTree
## Debug Lab mutation picker with one monster picked -> tools/art_review/debug_fuse.png.
##   Godot --path . --script tools/debug_fuse_preview.gd

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.debug_panel_open = true
	game.debug_tab = "ENEMIES"
	game.debug_category = "MUTATIONS"
	game.debug_fuse_a = "burrower"
	for k in range(4):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/debug_fuse.png"))
	quit()
