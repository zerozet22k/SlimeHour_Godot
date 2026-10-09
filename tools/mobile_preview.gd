extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.settings["touch"] = "on"
	# Simulate touching the virtual joystick
	game.stick_center = Vector2(160, 520)
	game.stick_knob = Vector2(195, 500)
	game.stick_touch_id = 0
	game.touch_move_dir = Vector2(0.8, -0.4).normalized()
	
	# Let a few frames run so enemies spawn and UI draws
	for i in range(12):
		await process_frame
		
	var out = "res://tools/art_review/mobile_preview.png"
	var err = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("Mobile preview saved to: ", out, " error=", err)
	quit()
