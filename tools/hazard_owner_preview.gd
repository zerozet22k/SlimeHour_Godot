extends SceneTree
## Your fire/poison (left) vs enemy fire/poison (right), plus your shots and
## enemy shots -> tools/art_review/hazard_owner.png.
## Needs a real window:  Godot --path . --script tools/hazard_owner_preview.gd
const EnemyIdentity = preload("res://scripts/EnemyIdentity.gd")
const Combat = preload("res://scripts/Combat.gd")

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
	var c: Vector2 = game.hero["pos"]
	game.add_zone("poison", c + Vector2(-180, -250), 60.0, 30.0)
	game.add_zone("fire", c + Vector2(-180, -100), 55.0, 30.0)
	EnemyIdentity.place(game, "acid", c + Vector2(180, -250), 60.0, 0.0, 30.0, 0.0)
	EnemyIdentity.place(game, "fire", c + Vector2(180, -100), 55.0, 0.0, 30.0, 0.0)
	for k in range(5):
		Combat.shot(game, c + Vector2(-260 + k * 30, 120), Vector2.UP, 1.0, {"friendly": true, "speed": 1.0, "life": 99.0, "r": 4.0, "kind": "bullet", "color": Color("8ff8ff"), "src": "pistol"})
		Combat.shot(game, c + Vector2(140 + k * 30, 120), Vector2.DOWN, 1.0, {"friendly": false, "speed": 1.0, "life": 99.0, "r": 6.0, "kind": "enemy", "color": Color("ff7b93"), "src": "test"})
	for k in range(20):
		game.hero["iframe"] = 5.0
		await physics_frame
	game.state = "playing"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/hazard_owner.png"))
	quit()
