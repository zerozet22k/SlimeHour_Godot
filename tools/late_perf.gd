extends SceneTree
## Real-director benchmark of a late sector (default 53) with a strong build.
## Needs a window:  Godot --path . --script res://tools/late_perf.gd   (LATE_SECTOR=53)
const Effects = preload("res://scripts/Effects.gd")
const Weapons = preload("res://scripts/Weapons.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sfx.set_volumes(0.0, 0.0)
	game.start_run()
	game.debug_session = true
	game.debug_godmode = true
	game.settings["autofire"] = true
	var target := int(OS.get_environment("LATE_SECTOR")) if OS.get_environment("LATE_SECTOR") != "" else 53
	game.sector = target
	game.level = 18
	game.begin_sector()
	game.guns = [Weapons.new_gun(game, "grenade", 1), Weapons.new_gun(game, "rocket", 3)]
	game.guns[1]["lvl"] = 5
	for id in ["trigger_happy", "trigger_happy", "gatling_mood", "incendiary", "gun_drone", "drone_swarm", "rocket_boots",
			"kaboom", "corpse_explosion", "ghost_pepper", "popcorn", "fireworks", "spite", "thunderclap", "static_field"]:
		Effects.add_card(game, id, true)
	game.stats_dirty = true
	var frames: Array = []
	var worst := {}
	var t_start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 40000 and frames.size() < 900:
		game.hero["hp"] = game.hero["maxhp"]
		if game.state != "playing":
			game.state = "playing"
		var before: Dictionary = game.prof.duplicate()
		var t0 = Time.get_ticks_usec()
		await process_frame
		var ms = (Time.get_ticks_usec() - t0) / 1000.0
		frames.append(ms)
		if ms > 200.0:
			var parts := []
			for k in game.prof:
				var d := float(game.prof[k]) - float(before.get(k, 0.0))
				if d > 20000.0:
					parts.append("%s=%dms" % [k, int(d / 1000.0)])
			print("SLOW %.0fms: %s" % [ms, " ".join(parts)])
		if frames.size() % 60 == 0 or (Time.get_ticks_msec() - t_start > 9000):
			print("t=%ds frame=%.1fms enemies=%d shots=%d fx=%d delayed=%d zones=%d hazards=%d pickups=%d texts=%d" % [
				(Time.get_ticks_msec() - t_start) / 1000, ms, game.enemies.size(), game.shots.size(), game.fx.size(),
				game.delayed.size(), game.zones.size(), game.enemy_hazards.size(), game.pickups.size(), game.texts.size()])
	frames.sort()
	var sum = 0.0
	for f in frames:
		sum += f
	print("LATE frames=%d avg=%.2fms p99=%.2fms" % [frames.size(), sum / frames.size(), frames[int(frames.size() * 0.99)]])
	quit()
