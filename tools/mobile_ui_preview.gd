extends SceneTree
## Renders the main mobile (portrait) screens with real game state into build/m-*.png.
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/mobile_ui_preview.gd -- --portrait-preview

const Effects = preload("res://scripts/Effects.gd")
const Weapons = preload("res://scripts/Weapons.gd")

var game

func _initialize() -> void:
	call_deferred("run")

func snap(name: String, frames: int = 4) -> void:
	for i in range(frames):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(("res://build/pc-%s.png" if OS.get_environment("PREVIEW_PC") != "" else "res://build/m-%s.png") % name))
	print("saved m-", name)

func run() -> void:
	var wide = OS.get_environment("PREVIEW_PC") != ""
	DisplayServer.window_set_size(Vector2i(1920, 1080) if wide else Vector2i(720, 1440))
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await snap("menu")
	game.start_run()
	game.guns.append(Weapons.new_gun(game, "shotgun", 2))
	for id in ["double_tap", "incendiary", "spinny_blade", "trigger_happy", "tight_choke", "glass_cannon", "four_leaf"]:
		Effects.add_card(game, id)
	Effects.add_card(game, "tight_choke")
	for i in range(40):
		game.spawn_enemy(["blob", "zoomer", "chonk", "spitter", "riot", "kaboomba"][i % 6], game.hero["pos"] + Vector2(randf_range(-420, 420), randf_range(-700, -120)))
	game.stick_touch_id = 0
	game.stick_center = Vector2(250, game.ui_height - 300)
	game.sector = 7
	game.begin_sector()
	for i in range(4):
		game.spawn_enemy(["mortar", "totem", "blinky", "tick"][i], game.hero["pos"] + Vector2(-300 + i * 200, -330), false, i == 2)
	game.stick_knob = game.stick_center + Vector2(50, -30)
	game.touch_move_dir = Vector2(0.8, -0.5).normalized()
	game.combo = 24
	game.combo_t = 2.0
	await snap("play", 30)
	game.stick_touch_id = -1
	game.touch_move_dir = Vector2.ZERO
	game.offers = [{"type": "card", "id": "tight_choke"}, {"type": "card", "id": "twin_barrels"}, {"type": "gun_up", "slot": 1}]
	game.offer_mode = "level"
	game.offer_t = 2.0
	game.state = "levelup"
	await snap("levelup")
	game.hud.peek = true
	await snap("peek")
	game.hud.peek = false
	game.state = "playing"
	game.open_map()
	await snap("map")
	game.gold = 300
	game.open_shop()
	await snap("shop")
	game.start_event()
	game.event_choose(0)
	await snap("event_roll", 20)
	await snap("event", 90)
	game.state = "rest"
	await snap("rest")
	game.state = "arsenal"
	await snap("arsenal")
	game.state = "lost"
	await snap("lost")
	game.state = "collection"
	game.hud.collection_cat = "chaos"
	await snap("collection")
	quit()
