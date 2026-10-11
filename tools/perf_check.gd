extends SceneTree
## Frame-time benchmark of a heavy late-game fight (needs a window, not --headless).
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/perf_check.gd
## Prints average / 1% worst frame times and how long simulation vs. drawing took.

const Effects = preload("res://scripts/Effects.gd")
const Weapons = preload("res://scripts/Weapons.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sector = 14
	game.begin_sector()
	game.guns = [Weapons.new_gun(game, "smg", 2), Weapons.new_gun(game, "shotgun", 2)]
	for id in ["double_tap", "double_tap", "twin_barrels", "incendiary", "spinny_blade", "splinter", "gun_drone", "corpse_explosion", "popcorn", "static_field"]:
		Effects.add_card(game, id)
	var want = int(OS.get_environment("PERF_ENEMIES")) if OS.get_environment("PERF_ENEMIES") != "" else 260
	var frames: Array = []
	var mon := {}
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var warm = 60
	var t_start = Time.get_ticks_msec()
	while frames.size() < (int(OS.get_environment("PERF_FRAMES")) if OS.get_environment("PERF_FRAMES") != "" else 500) and Time.get_ticks_msec() - t_start < 90000:
		game.hero["hp"] = game.hero["maxhp"]
		game.hero["pos"].y = game.back_limit() - 120.0 if OS.get_environment("PERF_BACK") != "" else game.hero["pos"].y - 1.2
		if game.state != "playing":
			game.state = "playing"
		while game.enemies.size() < want:
			game.spawn_enemy(["blob", "zoomer", "chonk", "spitter", "riot", "mitosis"][randi() % 6], game.hero["pos"] + Vector2(randf_range(-480, 480), randf_range(-760, -120)))
		var t0 = Time.get_ticks_usec()
		await process_frame
		if warm > 0:
			warm -= 1
			continue
		frames.append((Time.get_ticks_usec() - t0) / 1000.0)
		mon["process"] = float(mon.get("process", 0.0)) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		mon["render_cpu"] = float(mon.get("render_cpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		mon["render_gpu"] = float(mon.get("render_gpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		mon["physics"] = float(mon.get("physics", 0.0)) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		mon["draw_calls"] = float(mon.get("draw_calls", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		mon["primitives"] = float(mon.get("primitives", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/perf-frame.png"))
	frames.sort()
	var sum = 0.0
	for f in frames:
		sum += f
	var avg = sum / frames.size()
	var p99 = frames[int(frames.size() * 0.99)]
	print("PERF frames=%d avg=%.2fms (%.0f fps) p99=%.2fms enemies=%d shots=%d fx=%d texts=%d" % [frames.size(), avg, 1000.0 / avg, p99, game.enemies.size(), game.shots.size(), game.fx.size(), game.texts.size()])
	var parts = []
	for k in game.prof:
		parts.append("%s=%dms" % [k, int(float(game.prof[k]) / 1000.0)])
	print("PERF sim breakdown (total over run): ", " ".join(parts))
	var hk := {}
	for h in game.enemy_hazards:
		hk[str(h["kind"])] = int(hk.get(str(h["kind"]), 0)) + 1
	var sk := {}
	for sh in game.shots:
		var key := str(sh["kind"]) + ("/acid" if sh.get("acid_trail", false) else "") + ("/f" if sh["friendly"] else "/e")
		sk[key] = int(sk.get(key, 0)) + 1
	print("PERF hazards ", hk, " shots ", sk)
	var per := {}
	for k in mon:
		per[k] = snappedf(float(mon[k]) / maxf(1.0, frames.size()), 0.01)
	print("PERF per-frame monitors ", per)
	quit()
