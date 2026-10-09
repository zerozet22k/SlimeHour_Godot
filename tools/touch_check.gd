extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var options_path = "user://crowd_rush_options.json"
	var had_options = FileAccess.file_exists(options_path)
	var options_before = FileAccess.get_file_as_string(options_path) if had_options else ""
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.settings["touch"] = "auto"
	if not OS.has_feature("mobile"):
		assert(not game.is_touch_active())
		assert(not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"))
		game.settings["touch"] = "on" # Simulate an old saved desktop preference.
		assert(not game.is_touch_active())
		var tap = InputEventScreenTouch.new()
		tap.index = 7
		tap.position = Vector2(160, 520)
		tap.pressed = true
		game._unhandled_input(tap)
		assert(game.stick_touch_id == -1)
		game.toggle_setting("touch")
		assert(game.settings["touch"] == "off")
		assert(not game.is_touch_active())
	else:
		game.settings["touch"] = "on"
		assert(game.is_touch_active())
		var touch = InputEventScreenTouch.new()
		touch.index = 8
		touch.position = Vector2(160, 520)
		touch.pressed = true
		game._unhandled_input(touch)
		assert(game.stick_touch_id == 8)
		game.toggle_setting("touch")
		assert(not game.is_touch_active())
		assert(game.stick_touch_id == -1)
		assert(game.touch_move_dir == Vector2.ZERO)
	if had_options:
		var f = FileAccess.open(options_path, FileAccess.WRITE)
		f.store_string(options_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(options_path))
	print("TOUCH CHECK OK")
	game.queue_free()
	await process_frame
	quit()
