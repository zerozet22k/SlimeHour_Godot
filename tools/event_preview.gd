extends SceneTree
## Random-encounter screens: choose and result -> tools/art_review/event_*.png.
## Needs a real window:  Godot --path . --script tools/event_preview.gd

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.gold = 200
	for id in ["crate", "double"]:
		for ev in game.EVENTS:
			if str(ev["id"]) == id:
				game.start_event()
				game.event = ev.duplicate(true)
				break
		# Re-run the template fill on the chosen event.
		game.state = "event"
		for k in range(4):
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/event_%s_choose.png" % id))
		game.event_choose(0)
		for k in range(60):
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/event_%s_rolling.png" % id))
		for k in range(120):
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/event_%s_result.png" % id))
	quit()
