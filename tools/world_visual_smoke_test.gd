extends SceneTree
## Regression for a Windows screenshot showing HUD but no player, road or enemies.
## Must run with a graphical DisplayServer under Xvfb, NOT --headless.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --script tools/world_visual_smoke_test.gd
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "Graphical display server is active")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	check(packed != null, "Scene resource loads")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	check(game != null, "Game scene instantiates")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	var visuals = game.get_node_or_null("Visuals")
	var hud = game.get_node_or_null("Hud")
	check(visuals != null and hud != null, "Both world and HUD canvas nodes exist")
	if visuals == null or hud == null:
		quit(1)
		return
	check(visuals.get_script() != null, "World renderer GDScript compiled and attached")
	check(hud.get_script() != null, "HUD GDScript compiled and attached")
	game.start_run()
	check(not game.hero.is_empty() and game.state == "playing", "Sector 1 actually starts")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var vp: Viewport = root
	var snap: Image = vp.get_texture().get_image()
	check(snap != null and snap.get_width() >= 1280 and snap.get_height() >= 720, "Rendered window framebuffer is readable")
	if snap != null and snap.get_width() >= 1280 and snap.get_height() >= 720:
		var background: Color = Color("0a1020")
		var road_expected: Color = Color("111c33")
		var cx = snap.get_width() / 2
		var cy = snap.get_height() / 2
		# Player, health bar, sector banner, mobs or scenery can occlude any
		# single sampled pixel. Find actual road-colored pixels in an interior grid.
		var good_road = 0
		var inspected = 0
		for dy in [-180, -105, -45, 70, 145, 210]:
			for dx in [-250, -175, -90, 90, 175, 250]:
				var px = Vector2i(cx + dx, cy + dy)
				if px.x < 0 or px.y < 0 or px.x >= snap.get_width() or px.y >= snap.get_height():
					continue
				var col: Color = snap.get_pixelv(px)
				var diff_road = absf(col.r - road_expected.r) + absf(col.g - road_expected.g) + absf(col.b - road_expected.b)
				var diff_bg = absf(col.r - background.r) + absf(col.g - background.g) + absf(col.b - background.b)
				if diff_road < 0.17 and diff_bg > 0.035:
					good_road += 1
				inspected += 1
		print("VISIBLE ROAD PIXELS: ", good_road, " / ", inspected)
		check(good_road >= 4, "Actual road geometry is visible in multiple framebuffer locations")
	var script_text = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(script_text.contains("paint_road()") and script_text.contains("paint_hero()"),
		"World painter still draws road and hero")
	game.queue_free()
	print("WORLD VISUAL SMOKE TEST: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
