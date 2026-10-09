extends SceneTree

func _initialize() -> void:
	call_deferred("capture_shop")

func capture_shop() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.start_run()
	scene.sector_clear()
	scene.hero["pos"] = scene.stalls[2]["pos"] + Vector2(0, 50)
	scene.cam_y = float(scene.hero["pos"].y) - 110.0
	scene.gold = 100
	scene.banner_t = 0.0
	scene.settings["hints"] = false
	for i in range(5):
		await process_frame
	var out = "res://tools/art_review/shop_preview.png"
	var shot = root.get_texture().get_image()
	if shot == null:
		printerr("No render texture available")
		quit(1)
		return
	var err = shot.save_png(ProjectSettings.globalize_path(out))
	print("Shop preview: ", out, " error=", err)
	quit()
