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
		var px = Vector2i(snap.get_width() / 2, snap.get_height() / 2)
		var road: Color = snap.get_pixelv(px)
		var background: Color = Color("0a1020")
		var road_expected: Color = Color("111c33")
		print("WORLD COLOR at ", px, ": ", road, " expected road ", road_expected)
		# A uniformly dark frame (like the reported screenshot) is a failure.
		var diff_road = absf(road.r - road_expected.r) + absf(road.g - road_expected.g) + absf(road.b - road_expected.b)
		var diff_bg = absf(road.r - background.r) + absf(road.g - background.g) + absf(road.b - background.b)
		check(diff_road < 0.17 and diff_bg > 0.035,
			"Centre of gameplay viewport visibly shows the road, not an empty background")
	var script_text = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(script_text.contains("paint_road()") and script_text.contains("paint_hero()"),
		"World painter still draws road and hero")
	game.queue_free()
	print("WORLD VISUAL SMOKE TEST: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
