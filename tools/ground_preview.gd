extends SceneTree
## Renders ground effects and road obstacles to tools/art_review/ground_preview.png.
## Needs a real window:  Godot --path . --script tools/ground_preview.gd

const Combat = preload("res://scripts/Combat.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.enemies.clear()
	game.debug_session = true
	game.debug_godmode = true
	var c: Vector2 = game.hero["pos"]
	game.obstacles.clear()
	game.obstacles.append({"kind": "tree", "pos": c + Vector2(-430, -300), "radius": 28.0, "hp": -1.0})
	game.obstacles.append({"kind": "tree", "pos": c + Vector2(-330, -330), "radius": 28.0, "hp": -1.0})
	game.obstacles.append({"kind": "car", "pos": c + Vector2(-200, -280), "radius": 34.0, "hp": 200.0})
	game.obstacles.append({"kind": "car", "pos": c + Vector2(-110, -290), "radius": 34.0, "hp": 30.0})
	game.obstacles.append({"kind": "barrier", "pos": c + Vector2(20, -300), "radius": 30.0, "hp": 100.0})
	game.obstacles.append({"kind": "median", "pos": c + Vector2(130, -290), "radius": 30.0, "hp": -1.0})
	# Overlapping puddles merge; a ring of fire stays one patch.
	for i in range(4):
		game.add_zone("fire", c + Vector2(-380 + i * 18, -110), 50.0, 30.0)
	game.add_zone("poison", c + Vector2(-220, -110), 60.0, 30.0)
	game.add_zone("poison", c + Vector2(-190, -100), 60.0, 30.0)
	game.add_zone("ice", c + Vector2(-60, -110), 70.0, 30.0)
	# A long dash: one fire ribbon.
	game.settings["sfx"] = 0.0
	var ribbon = game.add_zone("fire", c + Vector2(80, 40), 34.0, 30.0, {"pts": [], "born": []})
	game.Trails.start(ribbon, c + Vector2(80, 40), game.run_time)
	for i in range(30):
		game.Trails.extend(ribbon, c + Vector2(80 + i * 12, 40 - sin(i * 0.25) * 60), game.run_time)
	# A Spitter's curving acid stream: one ribbon.
	var s = {"pos": c + Vector2(-420, 150), "last": c + Vector2(-420, 150)}
	for i in range(40):
		s["last"] = s["pos"]
		s["pos"] = c + Vector2(-420 + i * 10, 150 + sin(i * 0.2) * 50)
		game.EnemyIdentity.extend_acid(game, s, 13.0, 5.0, 30.0)
	print("hazards ", game.enemy_hazards.size(), " pts ", game.enemy_hazards[0].get("pts", []).size() if game.enemy_hazards.size() > 0 else -1)
	game.set_physics_process(false)
	for i in range(10):
		await process_frame
	game.state = "playing"
	game.banner_t = 0.0
	for i in range(3):
		await process_frame
	var img = root.get_texture().get_image()
	print("Capture: ", img.save_png(ProjectSettings.globalize_path("res://tools/art_review/ground_preview.png")))
	quit()
