extends SceneTree

func _initialize() -> void:
	call_deferred("capture_collection")

func capture_collection() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.state = "collection"
	scene.hud.collection_cat = "weapons"
	scene.hud.collection_page = 0
	scene.mouse_screen = Vector2(100, 210)
	for i in range(5):
		await process_frame
	var out = "res://tools/art_review/collection_preview.png"
	var shot = root.get_texture().get_image()
	if shot == null:
		printerr("No render texture available")
		quit(1)
		return
	var err = shot.save_png(ProjectSettings.globalize_path(out))
	print("Collection preview: ", out, " error=", err)
	quit()
