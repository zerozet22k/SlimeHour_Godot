extends SceneTree
## Unlocks: kills open cards and guns mid-run, each one queues a popup, healing cards come last
## and stay out of offers before HEAL_MIN_LEVEL.

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.profile = {"xp": 0, "level": 0, "kills": 0}
	game.compute_unlocks()
	var cards0 = game.unlocked_cards.size()
	var guns0 = game.unlocked_guns.size()
	assert(game.next_unlock_kills == game.KILLS_PER_CARD)
	game.start_run()
	game.kills = game.gun_kill_need(1)
	game.refresh_unlocks()
	assert(game.unlocked_cards.size() > cards0)
	assert(game.unlocked_guns.size() == guns0 + 1)
	assert(not game.unlock_toasts.is_empty())
	assert(game.run_unlocks.size() == game.unlocked_cards.size() - cards0 + 1)
	# Healing cards sit at the very end of the unlock order.
	for id in game.card_by_id:
		if bool(game.card_by_id[id].get("heal", false)):
			assert(int(game.unlock_index[id]) >= game.db_cards.size() - 10)
	game.profile["level"] = 999
	game.compute_unlocks()
	game.level = 1
	assert(not game.card_available("regeneration"))
	game.level = game.HEAL_MIN_LEVEL
	assert(game.card_available("regeneration"))
	# Lifetime kills are banked once at the end of the run.
	var before = int(game.profile["kills"])
	game.award_profile()
	assert(int(game.profile["kills"]) == before + game.kills)
	assert(game.lifetime_kills() == int(game.profile["kills"]))
	print("UNLOCK CHECK OK  cards %d -> %d  guns %d -> %d" % [cards0, cards0 + game.run_unlocks.size() - 1, guns0, guns0 + 1])
	quit()
