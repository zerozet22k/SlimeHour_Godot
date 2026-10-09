extends SceneTree
## GOO upgrades: buying spends GOO, levels cap, bonuses reach the run stats, and the shop renders.
## Never saves: profile changes are made with autotest set so save_options() is a no-op.
## Run with a window (no --headless) to also write build/upgrades.png.

const Effects = preload("res://scripts/Effects.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.no_save = true
	root.add_child(game)
	await process_frame
	game.autotest = "meta"
	game.profile["goo"] = 1000
	game.profile["ups"] = {}
	game.buy_meta(0)
	assert(game.meta_level("hp") == 1 and int(game.profile["goo"]) == 980)
	game.buy_meta(0)
	assert(int(game.profile["goo"]) == 940)
	game.profile["ups"]["dash"] = 1
	game.buy_meta(6)
	assert(game.meta_level("dash") == 1 and int(game.profile["goo"]) == 940)
	game.profile["ups"]["reroll"] = 2
	game.profile["ups"]["gold"] = 3
	game.profile["ups"]["startcard"] = 2
	game.profile["ups"]["haggle"] = 1
	game.start_run()
	assert(game.owned_order.size() == 2 and game.shop_reroll_cost == 11)
	Effects.recalc(game)
	assert(game.rerolls == 4 and game.gold == 45 and int(game.hero["dash_charges"]) == 2)
	assert(float(game.hero["maxhp"]) == 120.0)
	# Bestiary: first kill unlocks an entry, kills keep counting, Collection lists every monster.
	game.profile["mobs"] = {}
	game.note_mob("zoomer")
	game.note_mob("zoomer")
	assert(int(game.profile["mobs"]["zoomer"]) == 2)
	var hud = game.hud
	assert(hud.mob_info("blob")["title"] == "???" and hud.mob_info("zoomer")["title"] == "Zoomer")
	hud.collection_cat = "mobs"
	assert(hud.get_collection_items().size() == game.mob_order().size())
	game.state = "collection"
	for i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/bestiary.png"))
	game.state = "upgrades"
	for i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/upgrades.png"))
	print("META CHECK OK")
	quit()
