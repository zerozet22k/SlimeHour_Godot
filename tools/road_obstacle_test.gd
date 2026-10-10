extends SceneTree
## Tests road expansion, map paging and physical roadside hazards.
const Obst = preload("res://scripts/RoadObstacles.gd")
const Main = preload("res://scripts/Main.gd")
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first = Obst.road_half_for_sector(1, 530.0)
	var mid = Obst.road_half_for_sector(10, 530.0)
	var late = Obst.road_half_for_sector(25, 530.0)
	check(is_equal_approx(first, 530.0), "first sector maintains beginner road width")
	check(first < mid and mid < late, "road expands progressively")
	check(Obst.road_half_for_sector(2, 800.0) >= 800.0, "ultrawide canvas remains covered")
	check(is_equal_approx(Obst.camera_x(0.0, late, 1280.0), 0.0), "camera centers the middle lane")
	check(Obst.camera_x(950.0, late, 1280.0) > 0.0, "camera pans to right-hand road")
	check(Obst.camera_x(-950.0, late, 1280.0) < 0.0, "camera pans to left-hand road")
	var early = Obst.generate(2, 570.0, 0.0, 4800.0)
	var middle = Obst.generate(8, 810.0, 0.0, 4800.0)
	var advanced = Obst.generate(19, 1250.0, 0.0, 4800.0)
	var early_trees = 0
	var middle_medians = 0
	var advanced_cars = 0
	for hazard in early:
		check(absf(float(hazard["pos"].x)) + float(hazard["radius"]) <= 570.0, "early obstacle fits road")
		if hazard["kind"] == "tree":
			early_trees += 1
		check(hazard["kind"] != "car", "no early parked cars")
	for hazard in middle:
		if hazard["kind"] == "median":
			middle_medians += 1
		check(hazard["kind"] != "car", "no cars before sector 12")
	for hazard in advanced:
		if hazard["kind"] == "car":
			advanced_cars += 1
	check(early_trees >= 4, "beginner sectors contain roadside trees")
	check(middle_medians > 0, "middle sectors gain short median dividers")
	check(advanced_cars >= 2, "later sectors introduce vehicle obstructions")
	check(advanced == Obst.generate(19, 1250.0, 0.0, 4800.0), "map objects are deterministically generated")
	var wall: Array = [{"pos": Vector2.ZERO, "radius": 30.0, "hp": -1.0}]
	check(Obst.push_circle(Vector2(4.0, 4.0), 17.0, wall).length() >= 46.99, "collision pushes actors outside obstacle")
	var stopped = Obst.resolve_movement(Vector2(-150, 0), Vector2(150, 0), 17.0, wall)
	check(stopped.x < -45.0, "dashes cannot tunnel through cars")
	check(Obst.bullet_target(Vector2(-100, 0), Vector2(100, 0), 3.0, wall) == 0, "projectiles hit road cover")
	check(Obst.bullet_target(Vector2(-100, 90), Vector2(100, 90), 3.0, wall) == -1, "unblocked projectiles pass beside cover")
	var game = Main.new()
	check(game.map_full == false, "map opens in normal selection mode")
	check(game.map_view_first == 0, "route overview begins at the start")
	check(game.obstacles.is_empty(), "unstarted runs have no stale obstacles")
	game.free()
	print("WIDE ROAD / HAZARDS / ROUTE OVERVIEW: " + ("PASS" if failed == 0 else str(failed) + " failed"))
	quit(1 if failed else 0)
