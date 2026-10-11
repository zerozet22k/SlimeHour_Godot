extends RefCounted
## One continuous ground trail (fire behind a dash, a Spitter's acid ribbon).
## A trail is a dictionary with "pts" (Array of Vector2) and "born" (Array of
## float timestamps). It grows at the head and evaporates from the tail, so a
## long path is ONE shape with one hitbox instead of a row of circles.

const STEP := 16.0

static func start(trail: Dictionary, p: Vector2, now: float) -> void:
	trail["pts"] = [p]
	trail["born"] = [now]
	trail["pos"] = p

## Adds the new head point once it has moved far enough.
static func extend(trail: Dictionary, p: Vector2, now: float) -> void:
	var pts: Array = trail["pts"]
	# The last point is a floating head glued to the source; the one before
	# it is the last fixed point, which decides when a new point is laid.
	if pts.size() < 2 or Vector2(pts[pts.size() - 2]).distance_to(p) >= STEP:
		pts.append(p)
		trail["born"].append(now)
	else:
		pts[pts.size() - 1] = p
		trail["born"][pts.size() - 1] = now
	trail["pos"] = p

## Drops tail points older than `life` seconds. Returns false once empty.
static func prune(trail: Dictionary, now: float, life: float) -> bool:
	var pts: Array = trail["pts"]
	var born: Array = trail["born"]
	while pts.size() > 1 and now - float(born[0]) > life:
		pts.pop_front()
		born.pop_front()
	return not (pts.size() <= 1 and (born.is_empty() or now - float(born[0]) > life))

## Squared distance from p to the nearest point on the trail.
static func dist2(trail: Dictionary, p: Vector2) -> float:
	var pts: Array = trail["pts"]
	if pts.size() == 1:
		return p.distance_squared_to(pts[0])
	var best := INF
	for i in range(pts.size() - 1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		best = minf(best, p.distance_squared_to(q))
	return best

## [center, radius] of a circle enclosing every point (for spatial queries).
static func bounds(trail: Dictionary) -> Array:
	var pts: Array = trail["pts"]
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for q in pts:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var c := (lo + hi) * 0.5
	return [c, c.distance_to(hi)]

## 0 (fresh) .. 1 (about to evaporate) for each point.
static func ages(trail: Dictionary, now: float, life: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for b in trail["born"]:
		out.append(clampf((now - float(b)) / maxf(0.01, life), 0.0, 1.0))
	return out
