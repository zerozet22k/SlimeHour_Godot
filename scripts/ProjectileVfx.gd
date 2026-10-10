extends RefCounted
## Lightweight, data-driven projectile visual language; no per-bullet nodes.
## Compact timed impacts reuse the existing fx renderer and its bounded array.
const STYLE_COLORS = {
	"kinetic": Color("ffda78"), "rapid": Color("9fefff"),
	"heavy": Color("ffe4b4"), "pierce": Color("cfb5ff"),
	"shard": Color("b6ffc1"), "toxic": Color("b2ff72"),
	"frost": Color("a6f2ff"), "shock": Color("85d6ff"),
	"fire": Color("ff9645"), "blast": Color("ff7959"),
	"ricochet": Color("ffde8b"), "magic": Color("ffaaff"),
	"enemy": Color("ff6b89"), "water": Color("a0eeff")
}

static func style_for(kind: String, source: String, payload: Dictionary = {}) -> String:
	if kind in ["enemy", "skull"]:
		return "enemy" if kind == "enemy" else "magic"
	if kind in ["flame"] or source == "flame":
		return "fire"
	if kind == "snow" or source == "snow":
		return "frost"
	if source == "tesla" or kind == "chain":
		return "shock"
	if source == "bees" or kind == "bee" or kind == "grenade":
		return "toxic"
	if kind in ["rocket", "egg", "chicken"] or source == "rocket":
		return "blast"
	if kind in ["frag", "bolt"] or source == "splitbow":
		return "shard"
	if kind == "bubble":
		return "water"
	if kind in ["boomerang", "disc", "coin", "ball"] or source in ["pinball", "bowling"]:
		return "ricochet"
	if source in ["sniper", "rail", "laser", "revolver"]:
		return "pierce"
	if source in ["shotgun", "nailgun"]:
		return "heavy"
	if source in ["smg", "minigun"]:
		return "rapid"
	if payload.has("burn") and float(payload["burn"]) > 0:
		return "fire"
	if payload.has("poison") and float(payload["poison"]) > 0:
		return "toxic"
	if payload.has("freeze") and float(payload["freeze"]) > 0:
		return "frost"
	if payload.has("shock") and float(payload["shock"]) > 0:
		return "shock"
	return "kinetic"

static func tint(style: String) -> Color:
	return STYLE_COLORS.get(style, STYLE_COLORS["kinetic"])

static func flash(g, event: String, pos: Vector2, direction: Vector2, style: String, size: float = 8.0) -> void:
	# Main settings may disable particles; essential impact markers remain visible,
	# but extra sparks disappear. A hard cap prevents FPS death with multishot builds.
	var cap = 280 if not bool(g.settings.get("particles", true)) else 600
	if g.fx.size() >= cap:
		return
	if event == "muzzle" and (not bool(g.settings.get("particles", true)) or g.fx.size() > 300):
		return
	var life = 0.12 if event == "muzzle" else (0.18 if event == "impact" else 0.24)
	g.fx.append({"kind": "projectile_vfx", "event": event, "style": style,
		"pos": pos, "vel": Vector2.ZERO, "dir": direction.normalized(),
		"t": 0.0, "life": life, "color": tint(style), "size": clampf(size, 3.0, 26.0)})

static func muzzle(g, pos: Vector2, direction: Vector2, style: String, size: float) -> void:
	# Every third simulation frame throttles automatic weapons and stacked volleys.
	if int(g.sim_step) % 3 == 0:
		flash(g, "muzzle", pos, direction, style, size)

static func impact(g, pos: Vector2, direction: Vector2, style: String, size: float = 8.0) -> void:
	flash(g, "impact", pos, direction, style, size)

static func ricochet(g, pos: Vector2, direction: Vector2, style: String) -> void:
	flash(g, "bounce", pos, direction, style, 9.0)

static func expire(g, pos: Vector2, direction: Vector2, style: String) -> void:
	if bool(g.settings.get("particles", true)):
		flash(g, "expire", pos, direction, style, 5.0)
