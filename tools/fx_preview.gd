extends SceneTree
## Fires a set of effects and captures them to tools/art_review/fx_preview_N.png.
## Needs a real window:  Godot --path . --script tools/fx_preview.gd
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
	var leech = game.spawn_enemy("leech", c + Vector2(-260, -220), false, false)
	leech["tether_t"] = 99.0
	leech["spawn"] = 1.0
	for shot in range(3):
		Combat.explode(game, c + Vector2(-330, 60), 70.0, 0.0, 9, Color("ff8a3d"))
		Combat.explode(game, c + Vector2(330, 40), 110.0, 0.0, 9, Color("b48cff"))
		game.beams.append({"a": c + Vector2(-80, -60), "b": c + Vector2(260, -300), "t": 0.3, "w": 10.0, "color": Color("ff3a5a")})
		game.beams.append({"a": c + Vector2(80, -40), "b": c + Vector2(420, -150), "t": 0.3, "w": 3.0, "color": Color("9fd0ff"), "zig": true})
		game.beams.append({"a": c + Vector2(-500, 160), "b": c + Vector2(-100, 120), "t": 0.3, "w": 6.0, "color": Color("8ff8ff"), "rail": true})
		game.fx.append({"kind": "slash", "pos": c + Vector2(120, 140), "vel": Vector2.ZERO, "t": 0.0, "life": 0.32, "color": Color("c8d5ff"), "size": 120.0, "dir": 0.4, "arc": 1.15})
		game.spawn_ring_fx(c + Vector2(0, 230), Color("65efb2"), 80.0)
		game.spawn_burst(c + Vector2(-80, 220), Color("ffd24d"), 14, 300.0, 5.0)
		for k in range(4 + shot * 4):
			await physics_frame
		game.state = "playing"
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/fx_preview_%d.png" % shot))
		game.fx.clear()
		game.beams.clear()
	quit()
