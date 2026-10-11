extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.state = "characters"
	for i in range(4):
		await process_frame
	var out = "res://tools/art_review/character_select.png"
	var err = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("Character select saved: ", out, " error=", err)
	quit()
