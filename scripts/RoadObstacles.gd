extends RefCounted
## Deterministic, sector-scaled road hazards. Obstacles are separate from barrels:
## they stop movement, interrupt bullets, and cannot seal off an entire lane.
const HERO_RADIUS = 17.0
const SAFETY_GAP = 200.0

static func road_half_for_sector(sector: int, visible_half: float) -> float:
	# Road eventually extends beyond the camera and can be explored sideways.
	return maxf(visible_half, 530.0 + minf(900.0, float(maxi(0, sector - 1)) * 40.0))

static func camera_x(hero_x: float, road_half: float, canvas_width: float) -> float:
	var limit = maxf(0.0, road_half - canvas_width * 0.5 + 70.0)
	return clampf(hero_x, -limit, limit)

static func generate(sector: int, half: float, start_y: float, length: float) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(17293 + sector * 9929)
	var result: Array = []
	# Trees at the verges, with ample clearance toward the driving lanes.
	var count = 4 + mini(8, sector / 2)
	for i in range(count):
		var y = start_y - 500.0 - i * (length - 850.0) / maxf(1.0, count - 1)
		var side = -1.0 if i % 2 == 0 else 1.0
		var x = side * (half - rng.randf_range(65.0, 115.0))
		result.append({"kind": "tree", "pos": Vector2(x, y), "radius": 29.0, "hp": -1.0})
	# The median visibly separates two directions, without creating a solid wall.
	if sector >= 3:
		var mid_count = 2 + mini(5, (sector - 3) / 3)
		for i in range(mid_count):
			var y = start_y - 700.0 - i * (length - 1200.0) / maxf(1.0, mid_count - 1)
			result.append({"kind": "median", "pos": Vector2(0.0, y), "radius": 25.0, "hp": -1.0})
	# Breakable traffic barriers appear before any parked vehicles.
	if sector >= 6:
		for i in range(1 + mini(3, (sector - 6) / 5)):
			var y = start_y - 1050.0 - i * 940.0
			var x = (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(160.0, half - 140.0)
			result.append({"kind": "barrier", "pos": Vector2(x, y), "radius": 31.0, "hp": 65.0 + sector * 3.0})
	# Cars require lateral movement or deliberate destruction; first appear in
	# Sector 12, spaced to avoid overlapping medians or other obstacles.
	if sector >= 12:
		for i in range(1 + mini(4, (sector - 12) / 7)):
			var y = start_y - 1400.0 - i * 850.0
			var x = (1.0 if i % 2 == 1 else -1.0) * rng.randf_range(210.0, half - 150.0)
			result.append({"kind": "car", "pos": Vector2(x, y), "radius": 43.0, "hp": 110.0 + sector * 5.0})
	return result

static func push_circle(pos: Vector2, radius: float, obstacles: Array) -> Vector2:
	var result = pos
	for obstacle in obstacles:
		if float(obstacle.get("hp", -1.0)) == 0.0:
			continue
		var off: Vector2 = result - Vector2(obstacle["pos"])
		var min_dist = radius + float(obstacle["radius"])
		if off.length_squared() < min_dist * min_dist:
			if off.length_squared() < 0.01:
				off = Vector2.RIGHT
			result = Vector2(obstacle["pos"]) + off.normalized() * min_dist
	return result

static func bullet_target(previous: Vector2, current: Vector2, radius: float, obstacles: Array) -> int:
	var best = -1
	var travel = previous.distance_squared_to(current)
	for i in range(obstacles.size()):
		var obstacle: Dictionary = obstacles[i]
		if float(obstacle.get("hp", -1.0)) == 0.0:
			continue
		var nearest = Geometry2D.get_closest_point_to_segment(Vector2(obstacle["pos"]), previous, current)
		var touch = float(obstacle["radius"]) + radius
		if nearest.distance_squared_to(Vector2(obstacle["pos"])) <= touch * touch:
			var dist = previous.distance_squared_to(nearest)
			if dist <= travel:
				travel = dist
				best = i
	return best
