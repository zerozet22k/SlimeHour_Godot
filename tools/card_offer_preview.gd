extends SceneTree
## Level-up offers with the longest card texts -> tools/art_review/card_offer.png.
## Needs a real window:  Godot --path . --script tools/card_offer_preview.gd
const Effects = preload("res://scripts/Effects.gd")

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	var ids: Array = []
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		ids = ["thermal_shock", "rainbow_rounds", "reactive_armor", "slipstream"]
	else:
		ids = Array(args[0].split(","))
	# Own one copy of each so the "now > next" stat preview shows too.
	for id in ids:
		if game.card_by_id.has(id):
			Effects.add_card(game, str(id), true)
	game.offers = []
	for id in ids:
		if game.card_by_id.has(id):
			game.offers.append({"type": "card", "id": id})
	game.offer_mode = "chest"
	game.state = "levelup"
	game.offer_t = 2.0
	for k in range(6):
		await process_frame
	var out := "res://tools/art_review/card_offer.png" if args.size() < 2 else "res://tools/art_review/" + args[1]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	quit()
