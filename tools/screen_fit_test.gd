extends SceneTree
const Fit = preload("res://scripts/ScreenFit.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var standard = Vector2(1920, 1080)
	check(is_equal_approx(Fit.landscape_scale(standard), 1.5), "16:9 fits without letterbox")
	check(is_equal_approx(Fit.canvas_width(standard), 1280.0), "16:9 keeps 1280 HUD width")
	check(is_equal_approx(Fit.road_half(standard), 530.0), "16:9 keeps arena width")
	var wide = Vector2(3440, 1440)
	check(is_equal_approx(Fit.canvas_width(wide), 1720.0), "ultrawide displays fill screen")
	check(is_equal_approx(Fit.canvas_left(wide), -220.0), "ultrawide extension is symmetric")
	check(is_equal_approx(Fit.road_half(wide), 750.0), "ultrawide road is playable")
	var narrow = Vector2(1024, 768)
	check(is_equal_approx(Fit.canvas_width(narrow), 1280.0), "4:3 does not crop HUD")
	print("SCREEN FIT TESTS: ", "PASS" if failures == 0 else str(failures) + " errors")
	quit(1 if failures else 0)
