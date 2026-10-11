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

## Each sector is a real street. Layouts:
##   open      plain multi-lane road
##   two_way   double yellow centre line with jersey-barrier dividers
##   boulevard grassy tree-lined centre island
##   split     two carriageways around a wide planted park strip
## Islands are walkable grass with crosswalk gaps; only the props on them block.
const ISLAND_HALF = {"open": 0.0, "two_way": 8.0, "boulevard": 62.0, "split": 135.0}
const GAP_EVERY = 760.0
const GAP_SIZE = 170.0

static func layout_for(sector: int, half: float, boss: bool = false) -> String:
	if sector <= 1 or boss:
		return "open"
	var kinds: Array = ["two_way", "boulevard", "open", "split"] if half >= 620.0 else ["two_way", "boulevard", "open"]
	var rng = RandomNumberGenerator.new()
	rng.seed = int(5113 + sector * 7717)
	return str(kinds[(sector + rng.randi()) % kinds.size()])

## True when y (world) is inside a crosswalk opening of the centre island.
static func in_island_gap(y: float, start_y: float) -> bool:
	var d: float = fposmod(start_y - 300.0 - y, GAP_EVERY)
	return d < GAP_SIZE

static func generate(sector: int, half: float, start_y: float, length: float, boss: bool = false) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(17293 + sector * 9929)
	var result: Array = []
	var layout: String = layout_for(sector, half, boss)
	var island: float = float(ISLAND_HALF[layout])
	var top: float = start_y - length + 150.0
	var first: float = start_y - 420.0
	# Roadside trees in small clumps along both verges.
	var y: float = first
	var verge_step: float = maxf(240.0, 420.0 - float(sector) * 8.0)
	while y > top:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.82:
				var clump: int = 1 + (1 if rng.randf() < 0.45 else 0)
				for c in range(clump):
					var x: float = side * (half - rng.randf_range(48.0, 105.0))
					place(result, "tree", Vector2(x, y - c * 70.0 + rng.randf_range(-40.0, 40.0)), 29.0, -1.0)
		y -= verge_step + rng.randf_range(-60.0, 60.0)
	# Centre island props.
	if not boss and layout != "open":
		y = first - 120.0
		while y > top:
			if not in_island_gap(y, start_y):
				match layout:
					"two_way":
						place(result, "median", Vector2(0.0, y), 25.0, -1.0)
					"boulevard":
						place(result, "tree", Vector2(rng.randf_range(-14.0, 14.0), y), 29.0, -1.0)
					"split":
						for side in [-1.0, 1.0]:
							place(result, "tree", Vector2(side * rng.randf_range(55.0, 80.0), y + (side * 60.0)), 29.0, -1.0)
			y -= 300.0 if layout == "two_way" else 250.0
	elif sector >= 3 and not boss:
		# Open roads still get the odd divider so drivers keep their side.
		for i in range(2 + mini(5, (sector - 3) / 3)):
			place(result, "median", Vector2(0.0, first - 300.0 - i * (length - 1200.0) / float(maxi(1, 1 + mini(5, (sector - 3) / 3)))), 25.0, -1.0)
	# Construction zones: a few roadblocks and cones that close part of one
	# carriageway, always leaving a lane open beside them.
	if sector >= 2 and not boss:
		var zones: int = 1 + mini(5, sector / 3)
		for i in range(zones):
			var zy: float = first - 500.0 - float(i) * (length - 1400.0) / float(maxi(1, zones))
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var inner: float = island + 40.0
			var width: float = half - inner
			var closed: float = minf(width - 230.0, width * 0.55)
			if closed < 70.0:
				continue
			var x: float = side * (half - 50.0)
			while absf(x) > half - 50.0 - closed:
				place(result, "barrier", Vector2(x, zy), 31.0, 65.0 + sector * 3.0)
				x -= side * 78.0
			for c in range(3):
				place(result, "cone", Vector2(x + side * 10.0 - side * c * 8.0, zy + 55.0 + c * 34.0), 12.0, 18.0 + sector)
				place(result, "cone", Vector2(x + side * 10.0 - side * c * 8.0, zy - 55.0 - c * 34.0), 12.0, 18.0 + sector)
	# Parked cars from Sector 12: mostly along the kerb, sometimes in a lane.
	if sector >= 12 and not boss:
		for i in range(2 + mini(6, (sector - 12) / 3)):
			var cy: float = first - 700.0 - float(i) * 640.0 - rng.randf_range(0.0, 200.0)
			if cy < top:
				break
			var side2: float = 1.0 if i % 2 == 1 else -1.0
			var in_lane: bool = rng.randf() < 0.35
			var cx: float = side2 * (rng.randf_range(island + 120.0, half - 160.0) if in_lane else half - 125.0)
			place(result, "car", Vector2(cx, cy), 43.0, 110.0 + sector * 5.0)
	return result

## Adds an obstacle unless it would overlap one already placed.
static func place(result: Array, kind: String, pos: Vector2, radius: float, hp: float) -> void:
	for other in result:
		if Vector2(other["pos"]).distance_to(pos) < radius + float(other["radius"]) + 18.0:
			return
	result.append({"kind": kind, "pos": pos, "radius": radius, "hp": hp})

## Continuous circle-vs-static-circle collision blocks fast dashes too.
## Last point is moved just before contact instead of tunneling through a car.
static func resolve_movement(previous: Vector2, target: Vector2, radius: float, obstacles: Array) -> Vector2:
	var move = target - previous
	var a = move.length_squared()
	if a < 0.0001:
		return push_circle(target, radius, obstacles)
	var end = target
	var earliest = 1.0
	for obstacle in obstacles:
		var center: Vector2 = obstacle["pos"]
		var r = radius + float(obstacle["radius"])
		var f = previous - center
		if f.length_squared() <= r * r:
			continue
		var b = 2.0 * f.dot(move)
		var c = f.length_squared() - r * r
		var determinant = b * b - 4.0 * a * c
		if determinant < 0.0:
			continue
		var t = (-b - sqrt(determinant)) / (2.0 * a)
		if t >= 0.0 and t < earliest:
			earliest = t
	if earliest < 1.0:
		end = previous + move * maxf(0.0, earliest - 0.015)
	return push_circle(end, radius, obstacles)

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
