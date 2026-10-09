extends SceneTree

const Weapons = preload("res://scripts/Weapons.gd")
const Effects = preload("res://scripts/Effects.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.profile["ups"] = {}
	game.start_run()
	Effects.recalc(game)
	assert(game.hud.RARITY.size() == 6)
	assert(int(game.card_by_id["twin_barrels"]["rarity"]) >= 2)
	assert(int(game.card_by_id["bullet_hell"]["rarity"]) == 4)
	assert(int(game.card_by_id["pocket_singularity"]["rarity"]) == 5)
	game.gain_xp(10.0)
	assert(game.xp == 7.0 and game.level == 1)
	# Sector 1 enemies are close to base HP so the starting pistol can keep up.
	var blob = game.spawn_enemy("blob", Vector2.ZERO, false, false)
	assert(float(blob["max_hp"]) <= float(game.enemy_db["blob"]["hp"]) * 1.35)
	# Rarity odds: Epic or better stays rare, and one luck point only nudges it.
	var Effects = load("res://scripts/Effects.gd")
	var w0 = Effects.rarity_odds(game)
	var epic0 = (w0[2] + w0[3] + w0[4] + w0[5]) / 100.0
	assert(epic0 < 0.04)
	game.S["luck"] = 1.0
	var w1 = Effects.rarity_odds(game)
	var epic1 = (w1[2] + w1[3] + w1[4] + w1[5]) / 100.0
	assert(epic1 > epic0 and epic1 < epic0 * 1.06)
	game.S.erase("luck")
	# Damage: "+X% damage" sources add together; only TOTAL damage multiplies.
	Effects.add_card(game, "trigger_happy")
	var pool_before = game.dmg_pool()
	Effects.add_card(game, "tight_choke")
	assert(is_equal_approx(game.dmg_pool(), pool_before + 0.1))
	Effects.add_card(game, "glass_cannon")
	assert(is_equal_approx(game.more_mult(), 1.5))
	var common = Weapons.new_gun(game, "revolver", 0)
	var mythic = Weapons.new_gun(game, "revolver", 4)
	assert(Weapons.shot_damage(game, mythic) > Weapons.shot_damage(game, common))
	game.sector = game.WIN_SECTOR
	game.begin_sector()
	var boss20 = game.spawn_enemy("chonkzilla", Vector2.ZERO, true, false)
	assert(float(boss20["max_hp"]) > float(game.enemy_db["chonkzilla"]["hp"]) * 15.0)
	game.sector_clear()
	assert(game.state == "victory")
	game.do_action("continue_run")
	assert(game.state == "playing")
	game.sector += 1
	game.begin_sector()
	assert(game.sector == game.WIN_SECTOR + 1 and game.is_boss_sector())
	var boss21 = game.spawn_enemy("chonkzilla", Vector2.ZERO, true, false)
	assert(float(boss21["max_hp"]) > float(boss20["max_hp"]) * 1.7)
	print("BALANCE CHECK OK boss20=", roundi(float(boss20["max_hp"])), " boss21=", roundi(float(boss21["max_hp"])))
	game.queue_free()
	await process_frame
	quit()
