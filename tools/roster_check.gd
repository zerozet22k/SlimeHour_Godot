extends SceneTree
## Monster roster grows only after boss kills; death plays a slow-mo beat before the result screen.

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.start_run()
	var tier0 = game.ENEMY_TIERS[0]
	for i in range(400):
		assert(tier0.has(game.pick_enemy()))
	game.sector = 5
	game.sector_clear()
	assert(game.bosses_beaten == 1 and game.fresh_tier_sector == 6)
	game.sector = 6
	var seen = {}
	for i in range(400):
		seen[game.pick_enemy()] = true
	for k in game.ENEMY_TIERS[1]:
		assert(seen.has(k))
	assert(not seen.has("riot"))
	# Death: slow-mo first, result screen after.
	game.state = "playing"
	game.last_hit_by = "a Chonk belly flop"
	game.game_over()
	assert(game.dying_t > 0.0 and game.state == "playing" and game.killer_kind == "chonk")
	assert(Engine.time_scale < 1.0)
	game.finish_game_over()
	assert(game.state == "lost" and Engine.time_scale == 1.0)
	print("ROSTER CHECK OK")
	quit()
