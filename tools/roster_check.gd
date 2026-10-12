extends SceneTree
## Enemies arrive in stages; any pair of previously-introduced species can mix.
const Combat = preload("res://scripts/Combat.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.start_run()
	check(game.available_enemies(1) == game.STARTER_ENEMIES, "Sector 1 has only starters")
	check(game.introduction_for(6) == "skitter", "Skitter debuts at Sector 6")
	check(game.introduction_for(7) == "sapper", "Sapper debuts at Sector 7")
	check(game.introduction_for(8) == "mirror", "Mirror debuts at Sector 8")
	check(game.introduction_for(9) == "burrower", "Burrower debuts at Sector 9")
	check(game.introduction_for(24) == "" and game.introduction_for(23) != "", "Every normal species debuts (by 23) before hybrids")
	check(not EnemyMixes.allowed(game.available_enemies(15), 15), "Hybrids remain locked until Sector 16")
	check(EnemyMixes.allowed(game.available_enemies(24), 25) and not EnemyMixes.allowed(game.available_enemies(23), 24), "Hybrid spawning unlocks at Sector 25")
	check(game.introduction_for(4) == "nurse" and game.available_enemies(4).has("nurse"), "Medic is an early normal monster in sector 4")
	check(game.ROUTE_INTRO_ORDER.has("larry") and game.introduction_for(23) == "larry", "Laser Larry is the last normal monster to debut (sector 23)")
	check(not game.available_enemies(7).has("mirror"), "Later species do not debut prematurely")
	for i in range(game.ROUTE_INTRO_ORDER.size()):
		var sector = 6 + i
		var species = str(game.ROUTE_INTRO_ORDER[i])
		check(game.introduction_for(sector) == species, species + " appears in its own introduction sector")
		check(not game.available_enemies(sector - 1).has(species), species + " is not available early")
		check(game.available_enemies(sector).has(species), species + " is available after debut")
	# Both parent orders are buildable as distinct monsters.
	for pair in [["blob", "zoomer"], ["mirror", "sapper"], ["ashwing", "burrower"], ["skitter", "spitter"]]:
		var first = str(pair[0])
		var second = str(pair[1])
		var id = EnemyMixes.ensure(game.enemy_db, first, second)
		check(id != "" and game.enemy_db.has(id), first + "+" + second + " can combine")
		var flipped = EnemyMixes.ensure(game.enemy_db, second, first)
		check(flipped != id and game.enemy_db[flipped]["mix"] == [second, first], first + "+" + second + " keeps body order")
		var hybrid = game.spawn_enemy(id, game.hero["pos"] + Vector2(0, -300), false, false)
		Combat.ai(game, hybrid, Vector2.DOWN, 300.0, 0.1, false)
		check(str(hybrid["kind"]) == id, id + " spawns as a valid enemy")
		var MK = load("res://scripts/MutationKit.gd")
		check(hybrid.has("mut_of") and MK.payload_of(game, hybrid) != "", id + " fights as its body parent and carries the other parent's augment")
	# After sector 12, cap population and rates instead of stacking
	# unbounded monsters on top of the existing mutation schedule.
	game.route = {"spawns": 1.0}
	game.hard_mode = false
	game.sector = 12
	var budget_at_12: int = game.budget_for(12)
	var rush_at_12: int = game.rush_size()
	check(game.late_enemy_hp_multiplier(12) == 1.0, "Sector 12 regular HP remains unchanged")
	game.sector = 13
	check(game.budget_for(13) >= budget_at_12 and game.budget_for(13) <= budget_at_12 + 8, "Sector 13 crowd budget transitions smoothly")
	check(game.rush_size() >= rush_at_12 and game.rush_size() <= rush_at_12 + 5, "Sector 13 rush transitions smoothly")
	check(game.enemy_cap() <= 140 and game.sector_spawn_rate(1.0) <= 12.251, "Sector 13 starts bounded simultaneous and per-second spawns")
	check(game.late_enemy_hp_multiplier(13) > 1.0, "Sector 13 begins modest regular HP gain")
	game.sector = 25
	var capped_budget: int = game.budget_for(25)
	var capped_rush: int = game.rush_size()
	check(capped_budget + capped_rush < 500, "Late Normal crowd stops below 500 total enemies per sector")
	check(game.enemy_cap() <= 115 and game.sector_spawn_rate(1.0) <= 15.001, "Late Normal live enemies and spawn throughput are capped")
	check(is_equal_approx(game.late_enemy_hp_multiplier(25), 1.52) and is_equal_approx(game.late_enemy_hp_multiplier(40), 1.6), "Smaller late crowds are tougher (up to +60% HP)")
	game.sector = 40
	check(game.budget_for(40) == 160 and game.budget_for(40) >= capped_budget, "Crowd climbs linearly and tops out at 160 (sector 31)")
	check(game.budget_for(1) == 40 and game.budget_for(11) == 80, "Crowd grows by 4 a sector from 40")
	check(game.reward_scale(10) > 1.5 and game.reward_scale(40) >= 1.0, "Fewer monsters pay proportionally more EXP and gold")
	check(game.enemy_cap() <= 115 and game.sector_spawn_rate(1.0) <= 15.001, "Sector 40 cannot restore unlimited spawn density")
	var normal_mob = game.spawn_enemy("blob", game.hero["pos"] + Vector2(0, -280), false, false)
	check(normal_mob["max_hp"] > 26.0 * game.enemy_scale(), "Regular mob HP has increased at late sectors")
	var boss = game.spawn_enemy("chonkzilla", game.hero["pos"] + Vector2(0, -420), true, false)
	# The endgame multiplier only activates AFTER WIN_SECTOR, not before.
	var boss_expected: float = 2400.0 * game.enemy_scale() * 3.5 * (1.0 + 0.08 * float(maxi(0, game.sector - 12))) * game.early_boss_bonus(game.sector)
	check(is_equal_approx(float(boss["max_hp"]), boss_expected), "Bosses use their own HP multiplier, not the crowd one")
	game.sector = game.WIN_SECTOR + 1
	var endgame_boss = game.spawn_enemy("chonkzilla", game.hero["pos"] + Vector2(0, -420), true, false)
	var endgame_expected: float = 2400.0 * game.enemy_scale() * 3.5 * (1.0 + 0.08 * float(game.sector - 12)) * game.early_boss_bonus(game.sector) * 1.8
	check(is_equal_approx(float(endgame_boss["max_hp"]), endgame_expected), "Post-victory bosses add their endgame multiplier")
	game.sector = 40
	game.hard_mode = true
	check(game.budget_for(40) == 160, "Hard sends the same crowd as Normal (all mutants)")
	check(game.enemy_cap() == int(ceil(90 * 0.8)), "Hard fields 80% of Normal's live cap")
	# Introduction is a basic species, not an obligatory hybrid.
	game.hard_mode = false
	game.sector = 9
	game.begin_sector()
	game.spawn_acc = 1.0
	game.update_director(0.0)
	check(game.intro_spawned and game.enemies.size() > 0 and str(game.enemies[0]["kind"]) == "burrower", "Sector 9 introduces its base species first")
	game.queue_free()
	await process_frame
	print("ROSTER CHECK: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures else 0)
