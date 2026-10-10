extends SceneTree
const Combat = preload("res://scripts/Combat.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.start_run()
	assert(game.available_enemies(1) == game.STARTER_ENEMIES)
	assert(game.introduction_for(6) == "nurse")
	assert(game.introduction_for(10) == "larry")
	assert(game.introduction_for(11) == "mix_nurse_larry")
	assert(game.introduction_for(14) == "mortar")
	assert(game.introduction_for(18) == "bull")
	assert(game.introduction_for(19) == "mix_mortar_bull")
	assert(not game.available_enemies(10).has("mix_nurse_larry"))
	assert(game.available_enemies(11).has("mix_nurse_larry"))
	assert(game.enemy_db.has("mix_nurse_larry"))
	game.sector = 11
	game.begin_sector()
	game.spawn_acc = 1.0
	game.update_director(0.0)
	assert(game.intro_spawned and game.enemies[0]["kind"] == "mix_nurse_larry")
	var hybrid = game.spawn_enemy("mix_nurse_larry", game.hero["pos"] + Vector2(0, -300), false, false)
	Combat.ai(game, hybrid, Vector2.DOWN, 300.0, 0.1, false)
	assert(hybrid["kind"] == "mix_nurse_larry")
	assert(hybrid.has("mix_state_nurse") and hybrid.has("mix_state_larry"))
	assert(game.enemy_db["mix_nurse_larry"]["look"]["gear"].has("medic_cap"))
	assert(game.enemy_db["mix_nurse_larry"]["look"]["gear"].has("laser_lens"))
	var ally = game.spawn_enemy("blob", hybrid["pos"] + Vector2(40, 0), false, false)
	ally["hp"] = float(ally["max_hp"]) * 0.5
	Combat.build_grid(game)
	hybrid["mix_state_nurse"]["cd"] = 0.0
	hybrid["mix_state_larry"]["wind"] = 0.01
	hybrid["mix_state_larry"]["lock"] = game.hero["pos"]
	var before_beams = game.beams.size()
	var before_heal = float(ally["hp"])
	Combat.ai(game, hybrid, Vector2.DOWN, 300.0, 0.1, false)
	assert(float(ally["hp"]) > before_heal and game.beams.size() > before_beams)
	for i in range(game.MIX_PAIRS.size()):
		var intro_sector = 11 + 8 * i
		var id = game.mix_id(game.MIX_PAIRS[i])
		assert(game.introduction_for(intro_sector) == id)
		assert(not game.available_enemies(intro_sector - 1).has(id))
		assert(game.available_enemies(intro_sector).has(id))
		var mixed = game.spawn_enemy(id, game.hero["pos"] + Vector2(0, -320), false, false)
		Combat.ai(game, mixed, Vector2.DOWN, 320.0, 0.1, false)
		assert(mixed["kind"] == id)
		assert(mixed.has("mix_state_" + str(game.MIX_PAIRS[i][0])))
		assert(mixed.has("mix_state_" + str(game.MIX_PAIRS[i][1])))
	game.state = "playing"
	game.last_hit_by = "a Chonk belly flop"
	game.game_over()
	assert(game.dying_t > 0.0 and game.state == "playing" and game.killer_kind == "chonk")
	game.finish_game_over()
	assert(game.state == "lost" and Engine.time_scale == 1.0)
	game.queue_free()
	await process_frame
	print("ROSTER CHECK OK")
	quit()
