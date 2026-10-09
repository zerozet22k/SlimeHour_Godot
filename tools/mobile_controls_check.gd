extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	for i in range(4):
		await process_frame
	assert(game.portrait and game.is_touch_active())
	var down = InputEventScreenTouch.new()
	down.index = 1
	down.position = game.hud.to_global(Vector2(132, game.ui_height - 150.0))
	down.pressed = true
	game._unhandled_input(down)
	assert(game.stick_touch_id == 1)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = game.hud.to_global(Vector2(208, game.ui_height - 150.0))
	game._unhandled_input(drag)
	assert(game.touch_move_dir.x > 0.5)
	var dash = InputEventScreenTouch.new()
	dash.index = 2
	dash.position = game.hud.to_global(game.dash_btn_pos)
	dash.pressed = true
	game._unhandled_input(dash)
	assert(game.dash_touch_id == 2)
	dash.pressed = false
	game._unhandled_input(dash)
	assert(game.dash_touch_id == -1)
	down.pressed = false
	game._unhandled_input(down)
	assert(game.stick_touch_id == -1 and game.touch_move_dir == Vector2.ZERO)
	game.settings["aim"] = "mouse"
	var aim = InputEventScreenTouch.new()
	aim.index = 3
	aim.position = game.hud.to_global(Vector2(500, 500))
	aim.pressed = true
	game._unhandled_input(aim)
	assert(game.aim_touch_id == 3)
	var last_aim = game.mouse_world
	var last_dir = game.touch_aim_dir
	aim.pressed = false
	game._unhandled_input(aim)
	await process_frame
	assert(game.aim_touch_id == -1 and game.mouse_world == last_aim)
	game.hero["pos"] = Vector2(game.ROAD_HALF - 18.0, 0)
	await create_timer(0.7).timeout
	var hero_ui_x = 360.0 + float(game.hero["pos"].x) - game.cam_x
	assert(hero_ui_x > 20.0 and hero_ui_x < 700.0)
	assert(game.hero["aim"].distance_to(last_dir) < 0.01)
	down.pressed = true
	down.position = game.hud.to_global(Vector2(132, game.ui_height - 150.0))
	game._unhandled_input(down)
	assert(game.stick_touch_id == 1)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in range(4):
		await process_frame
	assert(not game.portrait)
	assert(game.stick_touch_id == -1 and game.touch_move_dir == Vector2.ZERO)
	print("MOBILE CONTROLS CHECK OK")
	game.queue_free()
	await process_frame
	quit()
