extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.enemies.clear()
	game.guns.clear()
	game.hero["aim"] = Vector2.DOWN
	var ids = ["blob", "zoomer", "chonk", "spitter", "kaboomba", "mitosis", "mini", "riot", "bull", "mama", "mortar", "totem", "blinky", "tick", "goblin", "ashwing", "mirror", "burrower", "siren", "skitter", "sapper", "lancer", "leech", "nurse", "larry"]
	for i in range(ids.size()):
		var pos = Vector2(-460 + (i % 7) * 150, game.cam_y - 250 + floori(float(i) / 7.0) * 135)
		var e = game.spawn_enemy(ids[i], pos)
		e["vel"] = Vector2(1, 0)
		e["aim"] = Vector2.DOWN
		e["spawn"] = 1.0
	game.pets.append({"kind": "intern", "pos": Vector2(-80, game.cam_y + 175), "aim": Vector2.DOWN, "slot": 0})
	game.set_process(false)
	game.visuals.queue_redraw()
	game.hud.queue_redraw()
	for i in range(8):
		await process_frame
	var img = root.get_texture().get_image()
	if img != null:
		print("Capture: ", img.save_png(ProjectSettings.globalize_path("res://tools/art_review/model_preview.png")))
	else:
		print("Capture unavailable")
	quit()
