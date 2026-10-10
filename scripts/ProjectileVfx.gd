extends RefCounted
## Slime Hour projectile VFX: distinct signatures, shared budget, no spawned Nodes.
## All events live in Main.fx and are rendered by Visuals.gd in its single canvas pass.
## Visuals are cosmetic; none of these helpers change weapon DPS or collision.

const STYLE_COLORS = {
	"kinetic": Color("ffd47a"), "rapid": Color("a6eeff"),
	"heavy": Color("ffe7aa"), "pierce": Color("d0b2ff"),
	"shard": Color("a8ffc4"), "toxic": Color("a2f45f"),
	"frost": Color("a5efff"), "shock": Color("78cfff"),
	"fire": Color("ff8c36"), "blast": Color("ff7355"),
	"ricochet": Color("ffdb79"), "magic": Color("df8dff"),
	"enemy": Color("ff5278"), "water": Color("a0eeff"),
	"boss_ember": Color("ff7a39"), "boss_void": Color("cd80ff"),
	"boss_frost": Color("88efff"), "boss_storm": Color("f6a1ff"),
	"critical": Color("fff0b6")
}

static func quality(g) -> String:
	if not bool(g.settings.get("particles", true)):
		return "off"
	var q = str(g.settings.get("vfx_quality", "medium"))
	return q if q in ["low", "medium", "high"] else "medium"

static func style_for(kind: String, source: String, payload: Dictionary = {}) -> String:
	if kind in ["enemy", "skull"]:
		if "King Blob" in source or "kingblob" in source:
			return "boss_void"
		if "Necro" in source or "necro" in source:
			return "boss_frost"
		if "Heli" in source or "heli" in source:
			return "boss_storm"
		if "Chonk" in source or "chonkzilla" in source:
			return "boss_ember"
		return "magic" if kind == "skull" else "enemy"
	if float(payload.get("burn", 0.0)) > 0.0:
		return "fire"
	if float(payload.get("poison", 0.0)) > 0.0:
		return "toxic"
	if float(payload.get("freeze", 0.0)) > 0.0:
		return "frost"
	if float(payload.get("shock", 0.0)) > 0.0:
		return "shock"
	if kind == "flame" or source == "flame":
		return "fire"
	if kind == "snow" or source == "snow":
		return "frost"
	if source == "tesla" or kind == "chain":
		return "shock"
	if source == "bees" or kind == "bee":
		return "toxic"
	if kind in ["rocket", "grenade", "egg", "chicken"] or source == "rocket":
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
	return "kinetic"

static func tint(style: String) -> Color:
	return STYLE_COLORS.get(style, STYLE_COLORS["kinetic"])

static func flash(g, event: String, pos: Vector2, direction: Vector2, style: String, size: float = 8.0) -> void:
	if not (g is Node):
		return
	var q = quality(g)
	# Essential hit/crit, split, ricochet and boss warnings survive "particles OFF".
	var essential = event in ["impact", "crit", "bounce", "split", "pierce", "boss_impact"]
	if q == "off" and not essential:
		return
	# Entire fx array already contains explosion and damage effects; budget them together.
	var cap = 140 if q == "off" else (190 if q == "low" else (360 if q == "medium" else 540))
	if g.fx.size() >= cap or not g.on_screen(pos, 110.0):
		return
	if event in ["muzzle", "double_tap", "parallel", "burst"] and g.fx.size() > cap * 0.60:
		return
	if event == "expire" and g.fx.size() > cap * 0.4:
		return
	var life = 0.12
	match event:
		"crit", "split", "boss_impact":
			life = 0.24
		"bounce", "impact", "pierce":
			life = 0.17
		"double_tap", "parallel", "burst":
			life = 0.19
		"expire":
			life = 0.13
		_:
			life = 0.11
	g.fx.append({"kind": "projectile_vfx", "event": event, "style": style,
		"pos": pos, "vel": Vector2.ZERO,
		"dir": direction.normalized() if direction.length_squared() > 0.001 else Vector2.UP,
		"t": 0.0, "life": life, "color": tint(style), "size": clampf(size, 3.0, 32.0)})

static func muzzle(g, pos: Vector2, direction: Vector2, style: String, size: float) -> void:
	# Keep a recognizable flash at low RPM, sample automatic-fire flashes.
	var interval = 4 if quality(g) == "low" else (2 if quality(g) == "high" else 3)
	if int(g.sim_step) % interval == 0:
		flash(g, "muzzle", pos, direction, style, size)

static func pattern(g, pos: Vector2, direction: Vector2, style: String, fire_pattern: String) -> void:
	if fire_pattern in ["double_tap", "parallel", "burst"]:
		flash(g, fire_pattern, pos, direction, style, 14.0 if fire_pattern == "parallel" else 11.0)

static func impact(g, pos: Vector2, direction: Vector2, style: String, size: float = 8.0) -> void:
	flash(g, "impact", pos, direction, style, size)

static func critical(g, pos: Vector2, direction: Vector2, size: float = 13.0) -> void:
	flash(g, "crit", pos, direction, "critical", size)

static func pierce(g, pos: Vector2, direction: Vector2, style: String) -> void:
	flash(g, "pierce", pos, direction, style, 8.5)

static func split(g, pos: Vector2, direction: Vector2, style: String = "shard") -> void:
	flash(g, "split", pos, direction, style, 10.0)

static func ricochet(g, pos: Vector2, direction: Vector2, style: String) -> void:
	flash(g, "bounce", pos, direction, style, 10.0)

static func expire(g, pos: Vector2, direction: Vector2, style: String) -> void:
	flash(g, "expire", pos, direction, style, 5.0)

static func boss_impact(g, pos: Vector2, style: String, radius: float) -> void:
	flash(g, "boss_impact", pos, Vector2.UP, style, minf(30.0, radius * 0.3))
