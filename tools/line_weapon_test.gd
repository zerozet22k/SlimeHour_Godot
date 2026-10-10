extends SceneTree
## Run: godot --headless --path . --script tools/line_weapon_test.gd
## Regression checks for instant-hit Railgun + Beam Me wall/chain geometry.

const Weapons = preload("res://scripts/Weapons.gd")
const Main = preload("res://scripts/Main.gd")

class MockGame:
	extends RefCounted
	const ROAD_HALF = 530.0
	var road_half = ROAD_HALF
	var stats: Dictionary = {}
	var enemies: Array = []
	var weapon_db: Dictionary = {
		"rail": {"bounce": 0, "rico": 0},
		"laser": {"bounce": 0, "rico": 0}
	}
	func st(key: String) -> float:
		return float(stats.get(key, 0.0))
	func enemies_near(_position: Vector2, _radius: float) -> Array:
		return enemies

var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("LINE WEAPON FAIL: " + description)
	else:
		print("PASS: " + description)

func _run_tests() -> void:
	var g = MockGame.new()
	var wall = float(g.ROAD_HALF) - 5.0
	var rail = {"id": "rail", "wm": {"bounce": 1, "rico": 2}}
	var laser = {"id": "laser", "wm": {"bounce": 1, "rico": 2}}
	g.stats = {"bounce": 1, "rico": 1}
	for gun in [rail, laser]:
		_check(Weapons.line_bounces(g, gun) == 2, str(gun["id"]) + " gains card and mod wall reflections")
		_check(Weapons.line_ricochets(g, gun) == 3, str(gun["id"]) + " gains enemy chain jumps")

	var straight = Weapons.line_segments(g, Vector2(wall - 20.0, 0), Vector2.RIGHT, 90, 0)
	_check(straight.size() == 1 and absf(straight[0]["b"].x - wall) < 0.01, "no bounce stops at road wall")
	var reflected = Weapons.line_segments(g, Vector2(wall - 20.0, 0), Vector2.RIGHT, 90, 1)
	_check(reflected.size() == 2 and reflected[1]["b"].x < reflected[1]["a"].x, "shot inside road reflects back")
	var edge_right = Weapons.line_segments(g, Vector2(wall + 12, 0), Vector2(1, -0.3), 200, 1)
	_check(edge_right.size() == 1 and edge_right[0]["b"].x < edge_right[0]["a"].x, "shot outside right edge reflects inward")
	var edge_left = Weapons.line_segments(g, Vector2(-wall - 12, 0), Vector2(-1, -0.3), 200, 1)
	_check(edge_left.size() == 1 and edge_left[0]["b"].x > edge_left[0]["a"].x, "shot outside left edge reflects inward")
	var inward = Weapons.line_segments(g, Vector2(wall + 12, 0), Vector2.LEFT, 150, 0)
	_check(inward.size() == 1 and inward[0]["b"].x < inward[0]["a"].x, "inward shot from edge needs no bounce")
	var long_path = Weapons.line_segments(g, Vector2.ZERO, Vector2.RIGHT, 2200, 3)
	var inside = long_path.size() == 3
	for s in long_path:
		inside = inside and absf(s["a"].x) <= wall + 0.01 and absf(s["b"].x) <= wall + 0.01
	_check(inside, "multiple bounces remain inside road")
	_check(Weapons.line_segments(g, Vector2.ZERO, Vector2.ZERO, 200, 1).is_empty(), "zero aim does not emit invalid hits")

	g.enemies = [
		{"id": 1, "dead": false, "pos": Vector2(wall - 60, 0), "r": 12.0},
		{"id": 2, "dead": false, "pos": Vector2(wall - 110, 0), "r": 12.0},
		{"id": 3, "dead": true, "pos": Vector2(wall - 85, 0), "r": 12.0}
	]
	var line = Weapons.line_segments(g, Vector2(wall - 10, 0), Vector2.RIGHT, 180, 1)
	var hit_one = Weapons.line_targets(g, line, 14, 1)
	var pierced = Weapons.line_targets(g, line, 14, 999)
	_check(hit_one.size() == 1 and int(hit_one[0]["enemy"]["id"]) == 1, "reflected laser acquires first enemy")
	_check(pierced.size() == 2 and int(pierced[1]["enemy"]["id"]) == 2, "reflected rail keeps pierce")
	var chained = Weapons.next_chain_target(g, g.enemies[0]["pos"], {1: true})
	_check(chained != null and int(chained["id"]) == 2, "enemy ricochet finds an unvisited live target")
	_check(Weapons.next_chain_target(g, g.enemies[0]["pos"], {1: true, 2: true}) == null, "chain never repeats visited enemies")

	_check(Main.version_is_newer("v0.1.4", "v0.1.3"), "newer patch triggers updater")
	_check(Main.version_is_newer("v0.2.0", "v0.1.9"), "newer minor triggers updater")
	_check(not Main.version_is_newer("v0.1.2", "v0.1.3"), "older release cannot trigger downgrade")
	_check(not Main.version_is_newer("v0.1.3", "v0.1.3"), "installed release does not trigger update")
	_check(not Main.version_is_newer("bad", "v0.1.3"), "malformed version is ignored")

	print("LINE WEAPON TESTS: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
