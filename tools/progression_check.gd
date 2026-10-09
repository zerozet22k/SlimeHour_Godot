extends SceneTree

const Combat = preload("res://scripts/Combat.gd")
const Weapons = preload("res://scripts/Weapons.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	assert(game.ROAD_HALF == 530.0)
	assert(game.SECTOR_LEN == 4800.0)
	game.hero["pos"] = Vector2(0, game.sector_start_y - game.SECTOR_LEN * 0.35)
	game.update_director(0.0)
	assert(game.gates.is_empty())
	var early_enemy = game.spawn_enemy("blob", Vector2.ZERO, false, false)
	game.sector_kills = int(game.crowd_total() * 0.75)
	var late_enemy = game.spawn_enemy("blob", Vector2.ZERO, false, false)
	assert(float(late_enemy["max_hp"]) > float(early_enemy["max_hp"]))
	var first_hp = float(game.hero["maxhp"])
	var first_volley_cap = game.volley_cap()
	var first_shot_cap = game.shot_cap()
	game.sector += 1
	game.begin_sector()
	for i in range(2):
		await physics_frame
	assert(float(game.hero["maxhp"]) > first_hp)
	assert(game.volley_cap() > first_volley_cap)
	assert(first_shot_cap == game.MAX_SHOTS_LIMIT and game.shot_cap() == first_shot_cap)
	game.S["mult"] = 100.0
	var before = game.shots.size()
	Weapons.volley(game, game.guns[0], 0, game.hero["pos"], Vector2.RIGHT, {})
	assert(game.shots.size() - before == game.volley_cap())
	var oversized = Combat.shot(game, game.hero["pos"], Vector2.RIGHT, 1.0, {"r": 1000.0})
	assert(oversized != null and float(oversized["r"]) == game.projectile_size_cap())
	# Sectors end only when the whole crowd is dead.
	game.sector = 3
	game.begin_sector()
	assert(not game.crowd_cleared())
	game.budget_spawned = game.sector_budget
	game.rush_done = true
	game.rush_queue = 0
	game.enemies.clear()
	assert(game.crowd_cleared())
	print("PROGRESSION CHECK OK hp=", game.hero["maxhp"], " volley=", game.volley_cap(), " shots=", game.shot_cap(), " radius=", game.projectile_size_cap())
	game.queue_free()
	await process_frame
	quit()
