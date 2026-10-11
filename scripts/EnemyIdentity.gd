extends RefCounted
## Bounded normal-enemy traps with visible arming time, destructible eggs/mines and cover.
const CAP = 84
const Trails = preload("res://scripts/Trails.gd")

static func place(g, kind: String, pos: Vector2, radius: float, damage: float, life: float, arm: float) -> void:
	if g.enemy_hazards.size() >= CAP:
		return
	pos.x = clampf(pos.x, -g.road_half + radius + 12.0, g.road_half - radius - 12.0)
	g.enemy_hazards.append({"kind": kind, "pos": pos, "r": radius, "dmg": damage,
		"life": life, "max_life": life, "arm": arm,
		"hp": 18.0 if kind == "mine" else (28.0 if kind == "egg" else 0.0), "hurt_t": 0.0})

static func place_line(g, a: Vector2, b: Vector2, width: float, damage: float, duration: float, kind: String = "fissure", arm_time: float = 0.5) -> void:
	if g.enemy_hazards.size() < CAP:
		g.enemy_hazards.append({"kind": kind, "pos": (a + b) * 0.5, "a": a, "b": b,
			"r": width, "dmg": damage, "life": duration, "max_life": duration,
			"arm": arm_time, "hp": 0.0, "hurt_t": 0.0})

## A Spitter shot paints ONE growing ribbon instead of a chain of segments.
## The ribbon evaporates from its tail `duration` seconds after each part lands.
static func extend_acid(g, s: Dictionary, width: float, damage: float, duration: float) -> void:
	var h = s.get("trail_h")
	if h == null or bool(h.get("gone", false)):
		if g.enemy_hazards.size() >= CAP:
			return
		h = {"kind": "acid_trail", "r": width, "dmg": damage, "life": duration,
			"max_life": duration, "arm": 0.08, "hp": 0.0, "hurt_t": 0.0, "trail_life": duration}
		Trails.start(h, s["last"], g.run_time)
		g.enemy_hazards.append(h)
		s["trail_h"] = h
	Trails.extend(h, s["pos"], g.run_time)
	h["life"] = duration

static func update_hazards(g, dt: float) -> void:
	for i in range(g.enemy_hazards.size() - 1, -1, -1):
		var h: Dictionary = g.enemy_hazards[i]
		h["life"] = float(h["life"]) - dt
		h["arm"] = maxf(0.0, float(h["arm"]) - dt)
		h["hurt_t"] = maxf(0.0, float(h["hurt_t"]) - dt)
		var trail_alive: bool = not h.has("pts") or Trails.prune(h, g.run_time, float(h["trail_life"]))
		if not trail_alive or float(h["life"]) <= 0.0 or (float(h["hp"]) <= 0.0 and str(h["kind"]) in ["mine", "egg"]):
			h["gone"] = true
			if str(h["kind"]) == "egg" and float(h["hp"]) > 0.0 and g.enemies.size() < g.MAX_ENEMIES:
				var child = g.spawn_enemy("mini", h["pos"], false, false)
				child["summon"] = true
			g.enemy_hazards.remove_at(i)
			continue
		if float(h["arm"]) > 0.0 or float(h["hurt_t"]) > 0.0:
			continue
		var hero: Vector2 = g.hero["pos"]
		var inside = false
		if h.has("pts"):
			inside = Trails.dist2(h, hero) <= pow(float(h["r"]) + 11.0, 2.0)
		elif str(h["kind"]) in ["fissure", "acid_trail"]:
			var nearest = Geometry2D.get_closest_point_to_segment(hero, h["a"], h["b"])
			inside = hero.distance_squared_to(nearest) <= pow(float(h["r"]) + 11.0, 2.0)
		else:
			inside = hero.distance_squared_to(h["pos"]) <= pow(float(h["r"]) + 11.0, 2.0)
		if not inside:
			continue
		match str(h["kind"]):
			"mine":
				g.hurt(float(h["dmg"]), h["pos"], "a Sapper proximity mine")
				g.spawn_ring_fx(h["pos"], Color("ffbc68"), 52.0)
				g.enemy_hazards.remove_at(i)
			"acid", "acid_trail":
				g.hurt(float(h["dmg"]), h["pos"], "Spitter poison trail")
				h["hurt_t"] = 0.62
			"fissure":
				g.hurt(float(h["dmg"]), h["pos"], "a Burrower fissure")
				h["hurt_t"] = 0.60

static func hit_hazards(g, s: Dictionary) -> bool:
	if not bool(s["friendly"]):
		return false
	for h in g.enemy_hazards:
		if str(h["kind"]) not in ["mine", "egg"]:
			continue
		var near = Geometry2D.get_closest_point_to_segment(h["pos"], s["last"], s["pos"])
		if near.distance_squared_to(h["pos"]) > pow(float(h["r"]) + float(s["r"]), 2.0):
			continue
		h["hp"] = float(h["hp"]) - float(s["dmg"])
		g.spawn_burst(h["pos"], Color("ffe6a8"), 3, 95.0, 2.0)
		if str(s["kind"]) not in ["disc", "boomerang", "flame", "ball", "saw", "car"]:
			if int(s.get("pierce", 0)) > 0:
				s["pierce"] = int(s["pierce"]) - 1
			else:
				s["dead"] = true
				return true
		return false
	return false

static func clip_beam(g, a: Vector2, b: Vector2) -> Vector2:
	var result = b
	var best = a.distance_squared_to(b)
	for ob in g.obstacles:
		if float(ob.get("hp", -1.0)) == 0.0:
			continue
		var nearest = Geometry2D.get_closest_point_to_segment(ob["pos"], a, b)
		if nearest.distance_squared_to(ob["pos"]) <= pow(float(ob["radius"]), 2.0):
			var distance = a.distance_squared_to(nearest)
			if distance < best and distance > 12.0:
				best = distance
				result = nearest
	return result

static func covered(g, a: Vector2, b: Vector2) -> bool:
	return clip_beam(g, a, b).distance_squared_to(b) > 4.0

static func bull_push(g, e: Dictionary, dt: float) -> void:
	var direction: Vector2 = e.get("cdir", Vector2.ZERO)
	if direction.length_squared() < 0.01:
		return
	for ob in g.obstacles:
		if str(ob["kind"]) not in ["barrier", "car"]:
			continue
		if e["pos"].distance_squared_to(ob["pos"]) > pow(float(e["r"]) + float(ob["radius"]) + 13.0, 2.0):
			continue
		var target: Vector2 = ob["pos"] + direction * 170.0 * dt
		target.x = clampf(target.x, -g.road_half + float(ob["radius"]), g.road_half - float(ob["radius"]))
		ob["pos"] = target
		break

static func blob_wall_collision(g, previous: Vector2, proposed: Vector2) -> Vector2:
	var close: Array = []
	for e in g.enemies:
		if not bool(e["dead"]) and str(e["kind"]) == "blob" and e["pos"].distance_squared_to(proposed) < 135.0 * 135.0:
			close.append(e)
			if close.size() >= 7:
				break
	for i in range(close.size()):
		for j in range(i + 1, close.size()):
			var a: Vector2 = close[i]["pos"]
			var b: Vector2 = close[j]["pos"]
			if a.distance_squared_to(b) > 75.0 * 75.0:
				continue
			var near = Geometry2D.get_closest_point_to_segment(proposed, a, b)
			if proposed.distance_squared_to(near) < 21.0 * 21.0 and previous.distance_to(near) > 18.0:
				return previous
	return proposed
