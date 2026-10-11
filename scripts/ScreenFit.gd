extends RefCounted
## Viewport-independent landscape coordinates; no stretched characters or side bars.
static func landscape_scale(vp: Vector2) -> float:
	if vp.x <= 0 or vp.y <= 0:
		return 1.0
	return minf(vp.x / 1280.0, vp.y / 720.0)

static func canvas_width(vp: Vector2) -> float:
	return maxf(1280.0, vp.x / landscape_scale(vp))

static func canvas_left(vp: Vector2) -> float:
	return 640.0 - canvas_width(vp) * 0.5

## The walkable street (road + pavements) fills the visible width, leaving
## a row of house fronts along each edge of the screen.
const HOUSE_STRIP = 64.0

static func road_half(vp: Vector2) -> float:
	return canvas_width(vp) * 0.5 - HOUSE_STRIP
