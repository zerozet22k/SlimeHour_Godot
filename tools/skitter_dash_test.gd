extends SceneTree
## Skitter regression: long committed dash and swept obstacle collision.
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
const Combat = preload("res://scripts/Combat.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/Combat.gd")
	check(source.contains('e["charge"] = 2.5'), "Skitter dash lasts beyond a short lunge")
	check(source.contains('e["cdir"] = (e["lock"] - e["pos"]).normalized()'), "Skitter locks its direction before dashing")
	check(source.contains("RoadObstacles.resolve_movement(before_dash_move"), "Skitter uses swept obstacle collision")
	var hero = Vector2(100, 0)
	var start = Vector2.ZERO
	var direction = (hero - start).normalized()
	var end = start + direction * 560.0 * 0.5
	check(end.x > hero.x + 100.0, "Unobstructed dash overshoots player")
	var obstacle = [{"pos": Vector2(160, 0), "radius": 20.0, "hp": -1.0}]
	var stopped = RoadObstacles.resolve_movement(start, end, 12.0, obstacle)
	check(stopped.x < 160.0 - 30.0 and stopped.x > 0.0, "Fast dash stops before obstacle rather than tunneling")
	var clear = RoadObstacles.resolve_movement(start, end, 12.0, [])
	check(clear.distance_to(end) < 0.01, "Unobstructed dash retains full travel")
	print("SKITTER DASH TEST: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
