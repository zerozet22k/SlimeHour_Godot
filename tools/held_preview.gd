extends SceneTree
## Monsters holding their weapons in each attack pose -> tools/art_review/held_preview.png.
## Needs a real window:  Godot --path . --script tools/held_preview.gd
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")

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
	var mix: String = EnemyMixes.ensure(game.enemy_db, "lancer", "kaboomba")
	var c: Vector2 = game.hero["pos"]
	# [kind, offset, setup]
	var rows = [
		["lancer", Vector2(-300, -240), {}],
		["lancer", Vector2(-150, -240), {"wind": 0.15, "lancer_attack": "spear"}],
		["lancer", Vector2(0, -240), {"throw_at": -0.1}],
		["lancer", Vector2(150, -240), {"wind": 0.2, "lancer_attack": "sweep"}],
		["lancer", Vector2(300, -240), {"swing_at": -0.07}],
		["mortar", Vector2(-300, -80), {}],
		["mortar", Vector2(-150, -80), {"fire_at": -0.06}],
		["sapper", Vector2(0, -80), {}],
		["sapper", Vector2(150, -80), {"sap_wind": 0.08}],
		["sapper", Vector2(300, -80), {"throw_at": -0.75}],
		[mix if mix != "" else "lancer", Vector2(-220, 120), {}],
		[mix if mix != "" else "lancer", Vector2(220, 120), {"wind": 0.1, "lancer_attack": "spear"}],
	]
	var list = []
	for row in rows:
		var e = game.spawn_enemy(row[0], c + row[1], false, false)
		e["spawn"] = 1.0
		list.append([e, row])
	for k in range(6):
		for item in list:
			var e = item[0]
			var setup: Dictionary = item[1][2]
			e["pos"] = c + item[1][1]
			e["vel"] = Vector2.ZERO
			e["cd"] = 99.0
			e["lock"] = game.hero["pos"]
			for key in setup:
				var value = setup[key]
				if key.ends_with("_at"):
					value = float(e["t"]) + float(value)
				e[key] = value
		await physics_frame
	game.state = "playing"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/held_preview.png"))
	quit()
