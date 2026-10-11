extends SceneTree
## Skitter regression: long committed dash and swept obstacle collision.
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
const Combat = preload("res://scripts/Combat.gd")
const Hud = preload("res://scripts/Hud.gd")

class FakeWorld:
	extends RefCounted
	var portrait := false
	var landscape_width := 1280.0
	var ui_height := 720.0
	var cam_x := 0.0
	var cam_y := 0.0
	var road_half := 530.0
	var sector_kills := 0
	func back_limit() -> float:
		return 380.0
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
	check(source.contains('e["charge"] = 2.4') and source.contains('e["bounces"]'), "Skitter ricochets off walls and props during a long dash")
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
	var bounded = Combat.skitter_dash_bound(Vector2(900, -1500), 0.0, 380.0, 530.0, 16.0)
	check(bounded.is_equal_approx(Vector2(514.0, -880.0)), "Skitter stops at side and forward bounds")
	var rear = Combat.skitter_dash_bound(Vector2(0, 1400), 0.0, 380.0, 530.0, 16.0)
	check(is_equal_approx(rear.y, 364.0), "Skitter cannot charge past the rear sector barrier")
	# Zoomer has a bounded, recoverable orbit rather than Skitter's straight dash.
	var zoomer_wide = Combat.zoomer_play_area(Vector2(1800, -2500), 0.0, 380.0, 530.0, 11.0)
	check(zoomer_wide.is_equal_approx(Vector2(519.0, -760.0)), "Zoomer remains inside the road and forward pursuit range")
	var zoomer_rear = Combat.zoomer_play_area(Vector2(-1800, 1000), 0.0, 380.0, 530.0, 11.0)
	check(zoomer_rear.is_equal_approx(Vector2(-519.0, 369.0)), "Zoomer cannot run behind sector barrier")
	check(is_equal_approx(Combat.zoomer_speed_limit(Vector2(600, 0), false).length(), 310.0), "Normal Zoomer boosted sprint is capped")
	check(is_equal_approx(Combat.zoomer_speed_limit(Vector2(600, 0), true).length(), 350.0), "Hard Zoomer boosted sprint is capped")
	check(Combat.leech_link_can_reach(330.0, false), "Leechling can begin tether inside reduced range")
	check(not Combat.leech_link_can_reach(350.0, false), "Leechling cannot begin tether at former long range")
	check(Combat.leech_link_can_reach(365.0, true), "Existing tether has small break-distance allowance")
	check(not Combat.leech_link_can_reach(400.0, true), "Leechling tether breaks when player escapes reduced range")
	var world = FakeWorld.new()
	var broken = {"pos": Vector2(0, 3000), "dead": false, "boss": false, "budget": true}
	check(not Combat.reap_unreachable(world, broken, Vector2.ZERO, 1.0), "Out-of-range enemy gets a recovery grace period")
	check(not Combat.reap_unreachable(world, broken, Vector2.ZERO, 1.0), "Bugged enemy not reaped immediately")
	check(Combat.reap_unreachable(world, broken, Vector2.ZERO, 1.0), "Unrecoverable enemy is reaped after grace period")
	check(bool(broken["dead"]) and world.sector_kills == 1, "Reaped budget enemy still counts toward wave clear")
	var boss = {"pos": Vector2(0, 3000), "dead": false, "boss": true}
	for i in range(12):
		Combat.reap_unreachable(world, boss, Vector2.ZERO, 1.0)
	check(not bool(boss["dead"]), "Bosses are never silently removed")
	check(not Hud.should_show_enemy_arrows(6, true, false), "No arrows in crowded combat")
	check(not Hud.should_show_enemy_arrows(3, false, false), "No arrows until spawning finishes")
	check(Hud.should_show_enemy_arrows(5, true, false), "Arrows shown with five remaining threats")
	check(not Hud.should_show_enemy_arrows(1, true, true), "No arrows during boss intro")
	var main_source = FileAccess.get_file_as_string("res://scripts/Main.gd")
	check(main_source.contains("hp *= 2.0"), "Boss-only final HP multiplier remains two times")
	print("SKITTER DASH TEST: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
