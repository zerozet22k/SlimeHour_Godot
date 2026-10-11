extends SceneTree
## Hero with two guns aimed in several directions -> tools/art_review/hero_aim_N.png.
## Needs a real window:  Godot --path . --script tools/hero_aim_preview.gd
const Weapons = preload("res://scripts/Weapons.gd")

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.enemies.clear()
	game.obstacles.clear()
	game.debug_session = true
	game.debug_godmode = true
	game.banner_t = 0.0
	game.guns = [Weapons.new_gun(game, "shotgun"), Weapons.new_gun(game, "sniper")]
	game.settings["aim"] = "auto"
	var dirs = [Vector2(1, -0.3), Vector2(-1, -0.3), Vector2(0.2, 1), Vector2(-0.3, -1)]
	for n in range(dirs.size()):
		for k in range(8):
			var c: Vector2 = game.hero["pos"]
			game.aim_screen = game.world_to_screen(c + dirs[n].normalized() * 160.0) if game.has_method("world_to_screen") else game.aim_screen
			game.mouse_world = c + dirs[n].normalized() * 160.0
			await physics_frame
		game.state = "playing"
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/hero_aim_%d.png" % n))
	quit()
