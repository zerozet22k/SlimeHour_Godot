extends SceneTree
## Renders one screenshot per street layout to tools/art_review/street_<layout>.png.
## Needs a real window:  Godot --path . --script tools/street_preview.gd

const Obst = preload("res://scripts/RoadObstacles.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	var done := {}
	for n in range(2, 30):
		var layout: String = Obst.layout_for(n, Obst.road_half_for_sector(n, 530.0))
		if done.has(layout) or (n % 5 == 0):
			continue
		done[layout] = true
		game.sector = n
		game.begin_sector()
		game.enemies.clear()
		game.barrels.clear()
		game.state = "playing"
		game.set_physics_process(false)
		game.hero["pos"] = Vector2(0, game.sector_start_y - 1700.0)
		game.cam_y = game.hero["pos"].y - game.hero_offset()
		game.cam_x = 0.0
		game.banner_t = 0.0
		for i in range(6):
			await process_frame
		game.cam_y = game.hero["pos"].y - game.hero_offset()
		await process_frame
		var img = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/art_review/street_%s.png" % layout))
		print("captured ", layout, " (sector ", n, ")")
	quit()
