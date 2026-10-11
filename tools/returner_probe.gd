extends SceneTree
## Throws the Returner repeatedly and logs ammo / boomerangs in flight, to
## catch throws that never come back or a gun that stops firing.
const Weapons = preload("res://scripts/Weapons.gd")

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.debug_session = true
	game.debug_godmode = true
	game.guns = [Weapons.new_gun(game, "boomerang", 0)]
	game.stats_dirty = true
	game.settings["autofire"] = true
	game.settings["aim"] = "auto"
	var throws := 0
	var last_ammo := -1
	for frame in range(130):
		game.state = "playing"
		game.banner_t = 0.0
		game.hero["hp"] = game.hero["maxhp"]
		if game.enemies.size() < 6:
			game.spawn_enemy("blob", game.hero["pos"] + Vector2(randf_range(-200, 200), randf_range(-420, -220)))
		# Strafe sideways like a player would.
		game.hero["pos"].x = sin(frame * 0.03) * 220.0
		await physics_frame
		var w: Dictionary = game.guns[0]
		var flying := 0
		for s in game.shots:
			if str(s["kind"]) == "boomerang" and bool(s["friendly"]):
				flying += 1
		if int(w["ammo"]) < last_ammo:
			throws += 1
		last_ammo = int(w["ammo"])
		for s2 in game.shots:
			if str(s2["kind"]) == "boomerang" and bool(s2["friendly"]) and frame < 70 and frame % 4 == 0:
				print("f=%d rel=%s back=%s t=%.2f speed=%.0f vel=%s life=%.2f" % [frame, str(Vector2(s2["pos"]) - Vector2(game.hero["pos"])).substr(0, 24), str(s2["back"]), float(s2["t"]), float(s2["speed"]), str(s2["vel"]).substr(0, 22), float(s2["life"])])
		if frame in [70, 80, 90, 100, 110, 120]:
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/returner_%d.png" % frame))
		if frame % 60 == 0:
			print("t=%ds ammo=%d/%d flying=%d cd=%.2f throws=%d lvl=%d" % [frame / 60, int(w["ammo"]), int(w["mag_max"]), flying, float(w["cd"]), throws, int(w["lvl"])])
	quit()
