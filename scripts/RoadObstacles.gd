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

## Each sector is a real street cross-section. Only the middle is asphalt;
## the rest of the walkable width is pavement with street trees.
##   two_lane   1 lane each way, dashed yellow centre line
##   four_lane  2 lanes each way, double yellow centre line
##   boulevard  2 lanes each way around a planted centre island
##   avenue     3 lanes each way around a wider planted island
const LANE_W = 115.0
const GUTTER = 12.0
const MIN_PAVEMENT = 150.0
const LAYOUT_LANES = {"two_lane": 1, "four_lane": 2, "boulevard": 2, "avenue": 3}
const LAYOUT_ISLAND = {"two_lane": 0.0, "four_lane": 0.0, "boulevard": 55.0, "avenue": 90.0}
## Cross streets: a junction every CROSS_EVERY, CROSS_W tall. Islands open at
## junctions and nothing is ever placed inside one.
const CROSS_EVERY = 1350.0
const CROSS_W = 210.0
const CROSS_FIRST = 1050.0

static func layout_for(sector: int, half: float, boss: bool = false) -> String:
	if sector <= 1 or boss:
		return "four_lane"
	var kinds: Array = ["two_lane", "four_lane", "boulevard"]
	if half >= 900.0:
		kinds.append("avenue")
	var rng = RandomNumberGenerator.new()
	rng.seed = int(5113 + sector * 7717)
	return str(kinds[(sector + rng.randi()) % kinds.size()])

## Lane count, island and carriageway half-width for a layout on this road,
## shrinking lanes if the pavement would get too narrow.
static func street(layout: String, half: float) -> Dictionary:
	var lanes: int = int(LAYOUT_LANES.get(layout, 2))
	var island: float = float(LAYOUT_ISLAND.get(layout, 0.0))
	while lanes > 1 and half - (island + lanes * LANE_W + GUTTER) < MIN_PAVEMENT:
		lanes -= 1
	var carriage: float = island + lanes * LANE_W + GUTTER
	return {"layout": layout, "lanes": lanes, "island": island, "carriage": carriage, "pavement": half - carriage}

## World y of every junction centre in a sector.
static func crossings(start_y: float, length: float) -> Array:
	var out: Array = []
	var y: float = start_y - CROSS_FIRST
	while y > start_y - length + 500.0:
		out.append(y)
		y -= CROSS_EVERY
	return out

## Distance-to-junction test used by the islands, props and markings.
static func in_junction(y: float, start_y: float, pad: float = 0.0) -> bool:
	var d: float = start_y - CROSS_FIRST - y
	if d < -CROSS_W * 0.5 - pad:
		return false
	var k: float = roundf(d / CROSS_EVERY)
	return absf(d - k * CROSS_EVERY) <= CROSS_W * 0.5 + pad

## Centre islands open at junctions.
static func in_island_gap(y: float, start_y: float) -> bool:
	return in_junction(y, start_y, 72.0)

static func generate(sector: int, half: float, start_y: float, length: float, boss: bool = false) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(17293 + sector * 9929)
	var result: Array = []
	var st: Dictionary = street(layout_for(sector, half, boss), half)
	var carriage: float = float(st["carriage"])
	var island: float = float(st["island"])
	var top: float = start_y - length + 150.0
	var first: float = start_y - 420.0
	# Street trees grow from tree pits on the pavement next to the kerb; wide
	# pavements get a second, staggered row near the buildings.
	var y: float = first
	while y > top:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.9:
				place(result, "tree", Vector2(side * (carriage + 52.0), y), 29.0, -1.0)
			if float(st["pavement"]) >= 300.0 and rng.randf() < 0.75:
				place(result, "tree", Vector2(side * (half - 70.0), y - 120.0), 29.0, -1.0)
		y -= 250.0
	# Planted centre islands.
	if island > 0.0 and not boss:
		y = first - 120.0
		while y > top:
			if not in_island_gap(y, start_y):
				place(result, "tree", Vector2(0.0, y), 29.0, -1.0)
			y -= 240.0
	# Roadworks close the kerb-side lane on multi-lane roads: sawhorses across
	# both ends, a cone taper on the approach and cones along the lane marking.
	if sector >= 2 and not boss and int(st["lanes"]) >= 2:
		var outer: float = carriage - GUTTER
		var inner: float = outer - LANE_W
		var lane_mid: float = (inner + outer) * 0.5
		var zones: int = 1 + mini(4, sector / 3)
		for i in range(zones):
			var zy: float = first - 520.0 - float(i) * (length - 1500.0) / float(maxi(1, zones))
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var zone_len: float = 380.0
			for end_y in [zy, zy - zone_len]:
				place(result, "barrier", Vector2(side * lane_mid, end_y), 31.0, 65.0 + sector * 3.0)
			var cy: float = zy - 45.0
			while cy > zy - zone_len + 30.0:
				place(result, "cone", Vector2(side * (inner + 6.0), cy), 12.0, 18.0 + sector)
				cy -= 48.0
			for k in range(3):
				var u: float = float(k + 1) / 4.0
				place(result, "cone", Vector2(side * lerpf(outer - 12.0, inner + 6.0, u), zy + 40.0 + (1.0 - u) * 150.0), 12.0, 18.0 + sector)
	# Parked cars from Sector 12 sit along the kerb in the outer lane.
	if sector >= 12 and not boss:
		var cars: int = 3 + mini(8, (sector - 12) / 2)
		var placed := 0
		var py: float = first - 140.0
		var lane_x: float = carriage - GUTTER - LANE_W * 0.5
		while py > top and placed < cars:
			var side2: float = -1.0 if rng.randf() < 0.5 else 1.0
			var before: int = result.size()
			place(result, "car", Vector2(side2 * lane_x, py), 43.0, 110.0 + sector * 5.0)
			if result.size() > before:
				placed += 1
			py -= 250.0 * float(1 + rng.randi() % 2)
	# Junctions stay clear for cross traffic.
	return result.filter(func(o): return not in_junction(float(o["pos"].y), start_y, float(o["radius"]) + 85.0))

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
