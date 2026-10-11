extends Node2D
## World rendering. Everything is drawn in one canvas pass from the dictionaries in Main.

const Weapons = preload("res://scripts/Weapons.gd")
const Combat = preload("res://scripts/Combat.gd")
const BossFight = preload("res://scripts/BossFight.gd")
const BossModels = preload("res://scripts/BossModels.gd")
const Trails = preload("res://scripts/Trails.gd")
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
const WeaponAim = preload("res://scripts/WeaponAim.gd")


var g
var font: Font
var bold: Font
var trail: Array = []
var shake_off = Vector2.ZERO

const BIOMES = [
	{"bg": Color("0a1020"), "road": Color("111c33"), "lane": Color("2a4a7a"), "edge": Color("4fe0ff"), "deco": Color("ff5a8a")},
	{"bg": Color("0b1a2a"), "road": Color("18304a"), "lane": Color("5d8fb8"), "edge": Color("bff4ff"), "deco": Color("9fe8ff")},
	{"bg": Color("1a0d0d"), "road": Color("2a1716"), "lane": Color("6b3a2a"), "edge": Color("ff8a3d"), "deco": Color("ffd24d")},
	{"bg": Color("1d0f24"), "road": Color("2e1838"), "lane": Color("7a3d7a"), "edge": Color("ff8ad8"), "deco": Color("7dffcf")},
	{"bg": Color("07060d"), "road": Color("120f1f"), "lane": Color("3a2a5a"), "edge": Color("b48cff"), "deco": Color("ff5a5a")},
]

func _ready() -> void:
	g = get_parent()
	font = ThemeDB.fallback_font
	bold = load("res://scripts/Hud.gd").game_font()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	headless = DisplayServer.get_name() == "headless"
	bake_enemies.call_deferred()

func P(world: Vector2) -> Vector2:
	return g.world_to_screen(world) + shake_off

func text_c(t: String, pos: Vector2, size: int, color: Color, outline = 5, f: Font = null) -> void:
	var ff = f if f != null else bold
	var w = ff.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p = pos - Vector2(w * 0.5, 0)
	if outline > 0:
		draw_string_outline(ff, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.02, 0.02, 0.06, color.a))
	draw_string(ff, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

var headless = false

func _draw() -> void:
	if headless:
		return
	var in_menu = g.state in ["menu", "collection", "upgrades"] or g.state == "settings" and g.settings_back == "menu"
	if g.hero.is_empty() or in_menu or g.state == "lost":
		return
	shake_off = Vector2(sin(g.anim_t * 97.0), cos(g.anim_t * 83.0)) * g.shake
	paint_road()
	paint_ground()
	paint_obstacles()
	paint_gates()
	paint_pickups()
	paint_barrels()
	paint_telegraphs()
	paint_identity_hazards()
	paint_enemies()
	paint_pets()
	paint_hero()
	paint_shots()
	paint_beams()
	paint_fx()
	paint_texts()
	if g.flash_t > 0.0:
		draw_rect(Rect2(g.landscape_left, g.view_top, g.landscape_width, g.view_bottom - g.view_top), Color(g.flash_color, minf(0.35, g.flash_t * 1.6)))
	if g.slowmo_t > 0.0:
		var a = minf(0.25, g.slowmo_t * 0.5)
		for i in range(6):
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.3, 0.5, 1.0, 0.0), false)
		draw_rect(Rect2(0, 0, 1280, 18), Color(0.4, 0.7, 1.0, a))
		draw_rect(Rect2(0, 702, 1280, 18), Color(0.4, 0.7, 1.0, a))

# ================================================================= road
func paint_road() -> void:
	var b = BIOMES[g.biome_index()]
	draw_rect(Rect2(g.landscape_left, g.view_top, g.landscape_width, g.view_bottom - g.view_top), b["bg"])
	var left = 640.0 - g.road_half - g.cam_x + shake_off.x
	var right = 640.0 + g.road_half - g.cam_x + shake_off.x
	# Side scenery: parallax light posts and blocks
	var scroll = g.cam_y
	for i in range(int(floor(g.view_top / 110.0)) - 1, int(ceil(g.view_bottom / 110.0)) + 2):
		var y = fposmod(-scroll * 0.6, 110.0) + i * 110.0 - 110.0
		draw_rect(Rect2(left - 74.0, y, 70, 60), Color(b["bg"].lightened(0.06)))
		draw_rect(Rect2(right + 22.0, y + 40, 70, 60), Color(b["bg"].lightened(0.06)))
		draw_rect(Rect2(left - 62.0, y + 10, 10, 8), Color(b["deco"], 0.5))
		draw_rect(Rect2(right + 42.0, y + 50, 10, 8), Color(b["edge"], 0.4))
	draw_rect(Rect2(left, g.view_top, right - left, g.view_bottom - g.view_top), b["road"])
	# Lane dashes scroll with the world.
	var y0 = fposmod(-scroll, 90.0) - 90.0
	for i in range(int(floor(g.view_top / 90.0)) - 1, int(ceil(g.view_bottom / 90.0)) + 2):
		var y = y0 + i * 90.0 + shake_off.y
		var lane_count = floori((g.road_half - 45.0) / 195.0)
		var island_half: float = float(RoadObstacles.ISLAND_HALF.get(str(g.road_layout), 0.0))
		for x in range(-lane_count, lane_count + 1):
			if absf(x * 195.0) < island_half + 60.0:
				continue
			draw_rect(Rect2(640 + x * 195.0 - g.cam_x - 3 + shake_off.x, y, 6, 44), Color(b["lane"], 0.55))
	for k in range(6):
		var a = 0.5 * (1.0 - k / 6.0)
		draw_rect(Rect2(left - 2 + k * 2, g.view_top, 2, g.view_bottom - g.view_top), Color(b["edge"], a * 0.6))
		draw_rect(Rect2(right - k * 2, g.view_top, 2, g.view_bottom - g.view_top), Color(b["edge"], a * 0.6))
	draw_rect(Rect2(left - 10, g.view_top, 8, g.view_bottom - g.view_top), Color(b["edge"], 0.25))
	draw_rect(Rect2(right + 2, g.view_top, 8, g.view_bottom - g.view_top), Color(b["edge"], 0.25))
	paint_street_layout(b, scroll)
	# Road walls: solid kerbs with hazard stripes so the edge of the arena is obvious.
	for side in [left - 22.0, right]:
		draw_rect(Rect2(side, g.view_top, 22, g.view_bottom - g.view_top), Color("1a1f2e"))
		var sy0 = fposmod(-scroll, 60.0) - 60.0
		for i in range(int(floor(g.view_top / 60.0)) - 1, int(ceil(g.view_bottom / 60.0)) + 2):
			var yy = sy0 + i * 60.0
			draw_rect(Rect2(side + 3, yy, 16, 30), Color(b["edge"], 0.55))
	draw_rect(Rect2(left - 2, g.view_top, 3, g.view_bottom - g.view_top), Color(b["edge"], 0.9))
	draw_rect(Rect2(right - 1, g.view_top, 3, g.view_bottom - g.view_top), Color(b["edge"], 0.9))
	# Barrier behind the sector start: you can roam this sector but not walk back into the last one.
	var by = P(Vector2(0, g.back_limit() + 26.0)).y
	if by < g.view_bottom + 60.0 and g.phase == "fight":
		draw_rect(Rect2(left, by, right - left, g.view_bottom - by + 60.0), Color(0, 0, 0, 0.45))
		var n = int((right - left) / 40.0) + 1
		for i in range(n):
			var x = left + i * 40.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, by), Vector2(minf(x + 20.0, right), by), Vector2(minf(x + 34.0, right), by + 18.0), Vector2(minf(x + 14.0, right), by + 18.0)]), Color("ffd24d"))
		draw_rect(Rect2(left, by - 2, right - left, 4), Color("ffd24d"))
		draw_rect(Rect2(left, by + 18, right - left, 4), Color("ffd24d"))
		text_c("NO WAY BACK", Vector2(640 - g.cam_x, by + 52), 22, Color(1, 0.82, 0.3, 0.9), 4)

## Centre of the street: double yellow line, or a grassy island with kerbs
## and crosswalk gaps. Islands are walkable; their trees are the obstacles.
func paint_street_layout(b: Dictionary, scroll: float) -> void:
	var layout := str(g.road_layout)
	var cx: float = 640.0 - g.cam_x + shake_off.x
	if layout == "open":
		return
	var top: float = g.view_top
	var bottom: float = g.view_bottom
	if layout == "two_way":
		for off in [-5.0, 3.0]:
			draw_rect(Rect2(cx + off - 1.0, top, 3.0, bottom - top), Color("f2c230", 0.8))
		return
	var island: float = float(RoadObstacles.ISLAND_HALF[layout])
	var grass := Color(b["bg"]).lerp(Color("2f6b3a"), 0.55)
	var kerb := Color("a7adb8")
	var step := 8.0
	var y := top
	while y < bottom:
		var world_y: float = y - 360.0 + g.cam_y - shake_off.y
		var seg_end: float = minf(bottom, y + step)
		if not RoadObstacles.in_island_gap(world_y, g.sector_start_y):
			draw_rect(Rect2(cx - island, y, island * 2.0, seg_end - y), grass)
			draw_rect(Rect2(cx - island - 5.0, y, 5.0, seg_end - y), kerb)
			draw_rect(Rect2(cx + island, y, 5.0, seg_end - y), kerb)
		else:
			# Crosswalk stripes across the opening.
			if int(world_y / 16.0) % 2 == 0:
				draw_rect(Rect2(cx - island - 30.0, y, island * 2.0 + 60.0, seg_end - y), Color(1, 1, 1, 0.16))
		y = seg_end
	# Grass texture flecks scroll with the world.
	var fy0 := fposmod(-scroll, 46.0) - 46.0
	var i := 0
	var yy := top + fy0
	while yy < bottom:
		var world2: float = yy - 360.0 + g.cam_y - shake_off.y
		if not RoadObstacles.in_island_gap(world2, g.sector_start_y):
			for k in range(int(island / 22.0)):
				var fx: float = cx - island + 10.0 + fmod(float(k) * 37.0 + float(i) * 17.0, island * 2.0 - 20.0)
				draw_line(Vector2(fx, yy), Vector2(fx + 2.0, yy - 6.0), Color("7fcf6a", 0.35), 2.0)
		yy += 46.0
		i += 1

func paint_ground() -> void:
	for f in g.fx:
		if f["kind"] == "splat":
			var p = P(f["pos"])
			var a = 0.35 * (1.0 - float(f["t"]) / float(f["life"]))
			var r = float(f["size"])
			draw_set_transform(p, float(f["rot"]), Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, r, Color(f["color"].darkened(0.4), a))
			draw_circle(Vector2(r * 0.8, r * 0.3), r * 0.35, Color(f["color"].darkened(0.4), a))
			draw_circle(Vector2(-r * 0.7, -r * 0.4), r * 0.25, Color(f["color"].darkened(0.4), a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for z in g.zones:
		var p = P(z["pos"])
		var fade = clampf(float(z["t"]) / 0.4, 0.0, 1.0)
		var r = float(z["r"])
		if p.y < g.view_top - r - 200.0 and not z.has("pts"):
			continue
		match z["kind"]:
			"fire", "blaze":
				if z.has("pts"):
					paint_fire_ribbon(z, fade)
				else:
					paint_fire_patch(p, r, float(z.get("seed", 0.0)), fade, z["kind"] == "blaze")
			"poison":
				paint_poison_patch(p, r, float(z.get("seed", 0.0)), fade)
			"ice":
				paint_ice_patch(p, r, float(z.get("seed", 0.0)), fade)
			"oil":
				draw_circle(p, r, Color(0.05, 0.03, 0.08, 0.7 * fade))
				draw_arc(p + Vector2(-r * 0.3, -r * 0.2), r * 0.3, 3.5, 5.0, 8, Color(0.6, 0.4, 1.0, 0.4 * fade), 2.0)
			"banana":
				draw_set_transform(p, 0.4, Vector2.ONE)
				draw_arc(Vector2.ZERO, 12.0, 0.3, 2.8, 12, Color("ffe14d"), 7.0)
				draw_arc(Vector2.ZERO, 12.0, 0.3, 2.8, 12, Color("b8a020"), 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"blackhole":
				for k in range(5):
					var rr = r * (1.0 - fmod(g.anim_t * 1.5 + k * 0.2, 1.0))
					draw_arc(p, rr, 0, TAU, 32, Color(0.7, 0.4, 1.0, 0.45 * fade), 3.0)
				draw_circle(p, 22.0, Color(0, 0, 0, 0.95))
				draw_arc(p, 24.0, 0, TAU, 24, Color("b48cff"), 3.0)
			"lightning":
				# Gauss ion scar persists as a visible, crackling FIELD; unlike
				# the initial rail shot it has measurable width and tick damage.
				var start = P(z["a"])
				var stop = P(z["b"])
				var delta = stop - start
				var length = delta.length()
				if length < 1.0:
					continue
				var tangent = delta / length
				var sideways = tangent.orthogonal()
				var charge = clampf(float(z["t"]) / maxf(0.01, float(z["life"])), 0.0, 1.0)
				var pulse = 0.78 + 0.22 * sin(g.anim_t * 25.0)
				var field_width = maxf(12.0, float(z["r"]) * 1.8)
				draw_line(start, stop, Color("3977ff", 0.11 * charge), field_width * 1.5)
				draw_line(start, stop, Color("5ebdff", 0.18 * charge), field_width)
				for ribbon in range(2):
					var pts = PackedVector2Array()
					for j in range(15):
						var t = float(j) / 14.0
						var w = sin(t * 23.0 + g.anim_t * (19.0 + ribbon * 5.0) + ribbon * 1.3)
						var offset = w * (field_width * 0.30)
						pts.append(start.lerp(stop, t) + sideways * offset)
					draw_polyline(pts, Color("b5efff", (0.5 if ribbon == 0 else 0.3) * charge * pulse), 2.2 if ribbon == 0 else 1.3)
				draw_circle(start, 5.0, Color("b6eaff", 0.38 * charge))
				draw_circle(stop, 5.0, Color("b6eaff", 0.38 * charge))

# ------------------------------------------------------------- ground effects
## Irregular puddle outline; the same seed always gives the same shape.
func puddle(p: Vector2, r: float, seed: float, wobble: float, n: int = 28, drift: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var th := TAU * float(i) / float(n)
		var k := 1.0 + wobble * (0.6 * sin(th * 3.0 + seed) + 0.4 * sin(th * 5.0 + seed * 1.7 + g.anim_t * drift))
		pts.append(p + Vector2(cos(th), sin(th) * 0.86) * r * k)
	return pts

func flame_tongue(base: Vector2, h: float, phase: float, alpha: float) -> void:
	var flick := 0.72 + 0.28 * sin(g.anim_t * 15.0 + phase)
	var hh := h * flick
	var w := h * 0.42
	var sway := sin(g.anim_t * 7.0 + phase) * w * 0.35
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.55 + sway * 0.5, -hh * 0.55),
		base + Vector2(sway, -hh), base + Vector2(w * 0.55 + sway * 0.5, -hh * 0.55), base + Vector2(w, 0), base + Vector2(0, w * 0.45)]),
		Color(1.0, 0.42, 0.08, alpha))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, 0), base + Vector2(sway * 0.7, -hh * 0.62),
		base + Vector2(w * 0.5, 0), base + Vector2(0, w * 0.25)]), Color(1.0, 0.85, 0.32, alpha))

func paint_fire_patch(p: Vector2, r: float, seed: float, fade: float, blaze: bool) -> void:
	draw_colored_polygon(puddle(p, r, seed, 0.12, 28, 1.2), Color(1.0, 0.3, 0.08, 0.5 * fade))
	draw_colored_polygon(puddle(p, r * 0.8, seed, 0.13, 28, 1.6), Color(1.0, 0.58, 0.16, 0.55 * fade))
	draw_colored_polygon(puddle(p, r * 0.48, seed + 3.0, 0.16, 22, 2.0), Color(1.0, 0.9, 0.45, 0.6 * fade))
	var count := clampi(int(r / 8.0), 4, 14 if blaze else 10)
	for i in range(count):
		var u := fmod(float(i) * 0.618 + seed, 1.0)
		var base := p + Vector2.from_angle(seed * 3.0 + float(i) * 2.399) * r * 0.78 * sqrt(u) * Vector2(1.0, 0.86)
		flame_tongue(base, (10.0 if blaze else 8.0) + 6.0 * (1.0 - u), float(i) * 1.7 + seed, 0.78 * fade)
	for i in range(3):
		var e := fmod(g.anim_t * 0.9 + float(i) * 0.33 + seed, 1.0)
		draw_circle(p + Vector2(sin(seed + i * 2.0) * r * 0.5, -e * r * 0.9), 2.0 * (1.0 - e), Color(1.0, 0.8, 0.4, fade * (1.0 - e)))

## A dash's fire is one continuous burning stripe that dies from its tail.
func paint_fire_ribbon(z: Dictionary, fade: float) -> void:
	var pts: Array = z["pts"]
	if pts.size() < 2:
		return
	var ages := Trails.ages(z, g.run_time, float(z["life"]))
	var screen := PackedVector2Array()
	var outer := PackedColorArray()
	var inner := PackedColorArray()
	for i in range(pts.size()):
		screen.append(P(pts[i]))
		var live := (1.0 - ages[i]) * fade
		outer.append(Color(1.0, 0.33, 0.08, 0.55 * live))
		inner.append(Color(1.0, 0.82, 0.38, 0.7 * live))
	var r := float(z["r"])
	draw_polyline_colors(screen, outer, r * 1.7, true)
	draw_polyline_colors(screen, inner, r * 0.7, true)
	var stride := maxi(1, int(22.0 / Trails.STEP))
	for i in range(0, pts.size(), stride):
		var live2 := (1.0 - ages[i]) * fade
		if live2 <= 0.05:
			continue
		var side := sin(float(i) * 2.3) * r * 0.45
		var n := Vector2.UP
		if i + 1 < screen.size():
			n = (screen[i + 1] - screen[i]).normalized().orthogonal()
		flame_tongue(screen[i] + n * side, 9.0 + 5.0 * live2, float(i) * 1.3, 0.85 * live2)

func paint_poison_patch(p: Vector2, r: float, seed: float, fade: float) -> void:
	draw_colored_polygon(puddle(p, r * 1.04, seed, 0.1, 30, 0.8), Color(0.12, 0.32, 0.08, 0.35 * fade))
	draw_colored_polygon(puddle(p, r * 0.94, seed, 0.1, 30, 0.8), Color(0.45, 0.95, 0.28, 0.26 * fade))
	draw_colored_polygon(puddle(p + Vector2(-r * 0.2, -r * 0.15), r * 0.35, seed + 5.0, 0.2, 18), Color(0.8, 1.0, 0.55, 0.16 * fade))
	for i in range(5):
		var u := fmod(g.anim_t * 0.7 + float(i) * 0.21 + seed, 1.0)
		var bp := p + Vector2.from_angle(seed + float(i) * 2.2) * r * 0.55 * Vector2(1.0, 0.86)
		draw_arc(bp, 3.0 + u * 6.0, 0.0, TAU, 12, Color(0.8, 1.0, 0.6, 0.6 * (1.0 - u) * fade), 1.5, true)

func paint_ice_patch(p: Vector2, r: float, seed: float, fade: float) -> void:
	var shard := PackedVector2Array()
	for i in range(14):
		var th := TAU * float(i) / 14.0 + seed
		var k := 1.0 if i % 2 == 0 else 0.84 + 0.08 * sin(seed + i)
		shard.append(p + Vector2(cos(th), sin(th) * 0.86) * r * k)
	draw_colored_polygon(shard, Color(0.72, 0.95, 1.0, 0.24 * fade))
	var edge := shard.duplicate()
	edge.append(shard[0])
	draw_polyline(edge, Color(0.9, 1.0, 1.0, 0.65 * fade), 2.0, true)
	for i in range(0, 14, 3):
		draw_line(p, p.lerp(shard[i], 0.85), Color(1, 1, 1, 0.3 * fade), 1.5, true)
	for i in range(3):
		var tw := 0.5 + 0.5 * sin(g.anim_t * 5.0 + float(i) * 2.1 + seed)
		var sp := p + Vector2.from_angle(seed * 2.0 + float(i) * 2.1) * r * 0.5
		var a := Color(1, 1, 1, tw * fade)
		draw_line(sp - Vector2(4, 0), sp + Vector2(4, 0), a, 1.5)
		draw_line(sp - Vector2(0, 4), sp + Vector2(0, 4), a, 1.5)

## Enemy acid: one ribbon with rim and veins, evaporating from its tail.
func paint_acid_ribbon(h: Dictionary) -> void:
	var pts: Array = h["pts"]
	if pts.size() < 2:
		return
	var ages := Trails.ages(h, g.run_time, float(h["trail_life"]))
	var r := float(h["r"])
	var screen := PackedVector2Array()
	var rim := PackedColorArray()
	var fill := PackedColorArray()
	var vein := PackedColorArray()
	var edge := PackedColorArray()
	for i in range(pts.size()):
		screen.append(P(pts[i]))
		var live := 1.0 - ages[i]
		rim.append(Color(0.16, 0.36, 0.1, 0.4 * live))
		fill.append(Color(0.62, 1.0, 0.4, 0.32 * live))
		vein.append(Color(0.87, 1.0, 0.6, 0.35 * live))
		edge.append(Color(0.63, 0.97, 0.43, 0.7 * live))
	draw_polyline_colors(screen, rim, r * 2.0 + 7.0, true)
	draw_polyline_colors(screen, fill, r * 2.0, true)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(screen.size()):
		var a := screen[maxi(0, i - 1)]
		var b := screen[mini(screen.size() - 1, i + 1)]
		var n := (b - a).normalized().orthogonal() if a.distance_squared_to(b) > 0.01 else Vector2.UP
		left.append(screen[i] + n * r)
		right.append(screen[i] - n * r)
	draw_polyline_colors(left, edge, 2.0, true)
	draw_polyline_colors(right, edge, 2.0, true)
	draw_polyline_colors(screen, vein, 2.0, true)

# ================================================================= gates & pitstop
func paint_gates() -> void:
	for gate in g.gates:
		var y = P(Vector2(0, gate["y"])).y
		if y < g.view_top - 120.0 or y > g.view_bottom + 100.0:
			continue
		var used = bool(gate["used"])
		for side in ["left", "right"]:
			var opt = gate[side]
			var good = bool(opt.get("good", true))
			var x0 = 640.0 - g.road_half - g.cam_x if side == "left" else 640.0 - g.cam_x
			var col = Color("2bd6a0") if good else Color("ff4d6a")
			var a = 1.0
			if used:
				a = 1.0 if gate.get("picked", "") == side else 0.15
			var pulse = 0.08 * sin(g.anim_t * 4.0)
			draw_rect(Rect2(x0 + 8, y - 70, g.road_half - 16, 70), Color(col, (0.28 + pulse) * a))
			draw_rect(Rect2(x0 + 8, y - 70, g.road_half - 16, 70), Color(col.lightened(0.4), 0.9 * a), false, 4.0)
			draw_rect(Rect2(x0 + 8, y - 4, g.road_half - 16, 8), Color(col.lightened(0.5), 0.8 * a))
			text_c(str(opt["label"]), Vector2(x0 + g.road_half * 0.5, y - 26), 30 if str(opt["label"]).length() < 16 else 22, Color(1, 1, 1, a))
		draw_rect(Rect2(636 - g.cam_x, y - 80, 8, 84), Color("e8e8f0"))

func paint_pickups() -> void:
	for pk in g.pickups:
		var p = P(pk["pos"])
		if p.y < g.view_top - 20.0 or p.y > g.view_bottom + 20.0:
			continue
		var bob = sin(g.anim_t * 6.0 + float(pk["t"]) * 2.0) * 2.0
		match pk["kind"]:
			"xp":
				var v = int(pk["value"])
				var c = Color("b48cff") if v < 5 else (Color("6bffb0") if v < 20 else Color("ff5a7a"))
				var s = 6.0 if v < 5 else (8.0 if v < 20 else 11.0)
				draw_circle(p, s + 5, Color(c, 0.15))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s - bob), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)]), c)
				draw_line(p + Vector2(-1, -s * 0.5), p + Vector2(1, s * 0.2), Color(1, 1, 1, 0.7), 1.5)
			"gold":
				# Consolidated piles visually grow from copper to bright gold coins.
				var worth = int(pk["value"])
				var scale_coin = clampf(1.0 + log(float(maxi(1, worth))) * 0.15, 1.0, 2.3)
				var coin_color = Color("fff0a2") if worth >= 20 else (Color("ffd24d") if worth >= 5 else Color("cba15e"))
				var wsx = absf(cos(g.anim_t * 5.0 + float(pk["t"]) * 3.0))
				draw_set_transform(p, 0.0, Vector2(maxf(0.25, wsx), 1.0))
				draw_circle(Vector2.ZERO, 7.0 * scale_coin, Color("946b23", 0.95))
				draw_circle(Vector2.ZERO, 5.5 * scale_coin, coin_color)
				if worth >= 10:
					draw_circle(Vector2(-3, -4) * scale_coin, 1.8 * scale_coin, Color("fff2cd", 0.85))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"heart":
				heart(p + Vector2(0, bob), 9.0, Color("ff4d6a"))
			"chest":
				var ct = g.tex("res://assets/ui/chest.svg")
				draw_circle(p, 30, Color(1, 0.85, 0.3, 0.2 + 0.1 * sin(g.anim_t * 5.0)))
				if ct != null:
					draw_texture_rect(ct, Rect2(p - Vector2(29, 29 - bob), Vector2(58, 58)), false)
				else:
					draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color("ffd24d"))

func heart(p: Vector2, s: float, c: Color) -> void:
	draw_circle(p + Vector2(-s * 0.45, -s * 0.2), s * 0.55, c)
	draw_circle(p + Vector2(s * 0.45, -s * 0.2), s * 0.55, c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(s, 0), p + Vector2(0, s * 1.05)]), c)

## Static hazards are geometric art and actual colliders (RoadObstacles.gd).
## World-to-screen mapping clips distant objects, so wider roads remain fast.
func paint_obstacles() -> void:
	for ob in g.obstacles:
		var p: Vector2 = P(ob["pos"])
		var radius = float(ob["radius"])
		if p.y < g.view_top - 100.0 or p.y > g.view_bottom + 100.0:
			continue
		if p.x < g.landscape_left - 100.0 or p.x > g.landscape_left + g.landscape_width + 100.0:
			continue
		var kind = str(ob["kind"])
		draw_ellipse_shadow(p, radius)
		var seed = absf(float(ob["pos"].x) * 0.137 + float(ob["pos"].y) * 0.071)
		match kind:
			"tree":
				paint_tree(p, radius, seed)
			"median":
				paint_median(p)
			"barrier":
				paint_roadblock(p, seed)
			"cone":
				paint_cone(p)
			"car":
				var hpmax_car = 110.0 + g.sector * 5.0
				paint_car(p, seed, clampf(float(ob.get("hp", hpmax_car)) / hpmax_car, 0.0, 1.0))
		if float(ob.get("hp", -1.0)) > 0.0 and kind != "cone":
			var hpmax = 65.0 + g.sector * 3.0 if kind == "barrier" else 110.0 + g.sector * 5.0
			var hpfrac = clampf(float(ob["hp"]) / hpmax, 0.0, 1.0)
			if hpfrac < 0.95:
				draw_rect(Rect2(p + Vector2(-31, -58), Vector2(62, 5)), Color("211d23"))
				draw_rect(Rect2(p + Vector2(-31, -58), Vector2(62.0 * hpfrac, 5)), Color("ffae59"))

## Leafy canopy seen from above: clustered crowns with a lit side and a
## gentle sway. Opaque shapes, so overlaps never show as stacked circles.
func paint_tree(p: Vector2, radius: float, seed: float) -> void:
	var palettes = [[Color("17463f"), Color("23705a"), Color("3fa86f"), Color("8fe08a")],
		[Color("1d4a2c"), Color("2f7a3d"), Color("57b04f"), Color("b5ec7a")],
		[Color("3a3a1c"), Color("6b7a2a"), Color("a6b53c"), Color("e5ec8a")]]
	var pal: Array = palettes[int(seed) % palettes.size()]
	var sway := Vector2(sin(g.anim_t * 1.3 + seed) * 1.6, 0.0)
	draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 22)), Color("5a3b26"))
	draw_rect(Rect2(p + Vector2(-6, 0), Vector2(5, 22)), Color("7a5236"))
	var crowns: Array = []
	for i in range(6):
		var th := seed + float(i) * 1.047
		crowns.append([p + sway + Vector2(0, -20) + Vector2.from_angle(th) * Vector2(17.0, 12.0), 15.0 + 4.0 * sin(seed + i)])
	crowns.append([p + sway + Vector2(0, -22), 20.0])
	for c in crowns:
		draw_circle(c[0], float(c[1]) + 3.0, Color("0d221c"))
	for c in crowns:
		draw_circle(c[0], float(c[1]), pal[0])
	for c in crowns:
		draw_circle(Vector2(c[0]) + Vector2(-3, -4), float(c[1]) * 0.78, pal[1])
	for c in crowns:
		draw_circle(Vector2(c[0]) + Vector2(-6, -7), float(c[1]) * 0.42, pal[2])
	for i in range(5):
		var lp: Vector2 = p + sway + Vector2(0, -24) + Vector2.from_angle(seed * 2.0 + float(i) * 1.3) * 14.0
		draw_circle(lp, 2.2, Color(pal[3], 0.75))

## Concrete jersey divider with hazard chevrons.
func paint_median(p: Vector2) -> void:
	var body := Rect2(p + Vector2(-22, -34), Vector2(44, 68))
	draw_rect(body.grow(3.0), Color("1a1d24"))
	draw_rect(body, Color("9aa1ad"))
	draw_rect(Rect2(body.position + Vector2(5, 4), Vector2(34, 60)), Color("c3c9d3"))
	for k in range(4):
		var y := body.position.y + 10.0 + k * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - 15, y + 8), Vector2(p.x, y), Vector2(p.x + 15, y + 8),
			Vector2(p.x + 15, y + 13), Vector2(p.x, y + 5), Vector2(p.x - 15, y + 13)]), Color("ffb43a"))
	draw_line(body.position + Vector2(5, 4), body.position + Vector2(5, 64), Color(1, 1, 1, 0.35), 2.0)

## Traffic cone seen from above: square base, banded orange cone.
func paint_cone(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-12, -12), Vector2(24, 24)), Color("15171d"))
	draw_rect(Rect2(p + Vector2(-10, -10), Vector2(20, 20)), Color("3a3f4d"))
	draw_circle(p, 9.5, Color("15171d"))
	draw_circle(p, 8.0, Color("ff7a1f"))
	draw_arc(p, 5.0, 0.0, TAU, 16, Color("fff4dc"), 2.5, true)
	draw_circle(p, 2.2, Color("ffb066"))
	draw_circle(p + Vector2(-3, -3), 1.6, Color(1, 1, 1, 0.6))

## Sawhorse roadblock: striped board on legs with blinking amber lamps.
func paint_roadblock(p: Vector2, seed: float) -> void:
	for side in [-1.0, 1.0]:
		draw_line(p + Vector2(side * 22, -6), p + Vector2(side * 30, 16), Color("1a1d24"), 7.0)
		draw_line(p + Vector2(side * 22, -6), p + Vector2(side * 30, 16), Color("6b7080"), 4.0)
		draw_line(p + Vector2(side * 22, -6), p + Vector2(side * 14, 16), Color("1a1d24"), 7.0)
		draw_line(p + Vector2(side * 22, -6), p + Vector2(side * 14, 16), Color("6b7080"), 4.0)
	var board := Rect2(p + Vector2(-34, -18), Vector2(68, 18))
	draw_rect(board.grow(3.0), Color("1a1d24"))
	draw_rect(board, Color("fff4dc"))
	for k in range(5):
		var x0 := board.position.x + float(k) * 16.0 - 6.0
		var stripe := PackedVector2Array()
		for q in [Vector2(x0, board.end.y), Vector2(x0 + 8, board.end.y), Vector2(x0 + 18, board.position.y), Vector2(x0 + 10, board.position.y)]:
			stripe.append(Vector2(clampf(q.x, board.position.x, board.end.x), q.y))
		draw_colored_polygon(stripe, Color("ff7a1f"))
	draw_line(board.position + Vector2(2, 2), Vector2(board.end.x - 2, board.position.y + 2), Color(1, 1, 1, 0.5), 2.0)
	for side in [-1.0, 1.0]:
		var lamp := p + Vector2(side * 28, -24)
		var on := fmod(g.anim_t * 1.6 + (0.5 if side > 0 else 0.0) + seed, 1.0) < 0.5
		draw_rect(Rect2(lamp + Vector2(-4, 2), Vector2(8, 6)), Color("2a2d36"))
		if on:
			draw_circle(lamp, 11.0, Color(1.0, 0.75, 0.2, 0.22))
		draw_circle(lamp, 5.0, Color("ffcf4a") if on else Color("8a5a14"))

## Top-down parked car: rounded body, glass, wheels, lights. Wrecks smoke.
func paint_car(p: Vector2, seed: float, health: float) -> void:
	var colors = [Color("4f74d9"), Color("d9534f"), Color("e8c547"), Color("e9eef5"), Color("3fb58a"), Color("9a5fd0"), Color("2b2f3a")]
	var body_col: Color = colors[int(seed * 3.0) % colors.size()]
	var dark := body_col.darkened(0.35)
	for wy in [-30.0, 22.0]:
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(p + Vector2(side * 26.0 - 6.0, wy), Vector2(12, 16)), Color("15171d"))
	var hull := PackedVector2Array()
	var hw := 25.0
	var hh := 47.0
	for corner in [[Vector2(hw - 10, -hh + 10), -PI * 0.5], [Vector2(hw - 10, hh - 10), 0.0], [Vector2(-hw + 10, hh - 10), PI * 0.5], [Vector2(-hw + 10, -hh + 10), PI]]:
		for k in range(5):
			hull.append(p + Vector2(corner[0]) + Vector2.from_angle(float(corner[1]) + PI * 0.5 * float(k) / 4.0) * 10.0)
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_colored_polygon(hull, body_col)
	draw_polyline(outline, Color("0b0d12"), 3.0, true)
	draw_rect(Rect2(p + Vector2(-hw + 3, -hh + 6), Vector2(5, hh * 2.0 - 12)), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(p + Vector2(hw - 8, -hh + 6), Vector2(5, hh * 2.0 - 12)), Color(dark, 0.6))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-19, -22), p + Vector2(19, -22), p + Vector2(15, -6), p + Vector2(-15, -6)]), Color("7cc6dc"))
	draw_line(p + Vector2(-12, -19), p + Vector2(-4, -9), Color(1, 1, 1, 0.6), 2.0)
	draw_rect(Rect2(p + Vector2(-16, -6), Vector2(32, 26)), dark)
	draw_rect(Rect2(p + Vector2(-13, -3), Vector2(26, 20)), body_col.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 20), p + Vector2(15, 20), p + Vector2(18, 32), p + Vector2(-18, 32)]), Color("3d6f88"))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(p + Vector2(side * (hw + 1.0) - 3.0, -16), Vector2(6, 5)), dark)
		draw_rect(Rect2(p + Vector2(side * 14.0 - 6.0, -hh + 1.0), Vector2(12, 6)), Color("fff2c4"))
		draw_rect(Rect2(p + Vector2(side * 15.0 - 6.0, hh - 6.0), Vector2(12, 5)), Color("ff5a52"))
	if health < 0.55:
		draw_line(p + Vector2(-10, -18), p + Vector2(2, -12), Color(1, 1, 1, 0.8), 1.5)
		draw_line(p + Vector2(2, -12), p + Vector2(-4, -8), Color(1, 1, 1, 0.8), 1.5)
		for i in range(3):
			var u := fmod(g.anim_t * 0.8 + float(i) * 0.33 + seed, 1.0)
			draw_circle(p + Vector2(sin(i * 2.0 + seed) * 6.0, -hh + 8.0 - u * 40.0), 5.0 + u * 9.0, Color(0.2, 0.2, 0.22, 0.45 * (1.0 - u)))

func draw_ellipse_shadow(p: Vector2, r: float) -> void:
	draw_set_transform(p + Vector2(3, 13), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r + 5.0, Color(0, 0, 0, 0.31))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func paint_barrels() -> void:
	for b in g.barrels:
		var p = P(b["pos"])
		if p.y < g.view_top - 40.0 or p.y > g.view_bottom + 40.0:
			continue
		var drop = float(b["drop"])
		if drop > 0.0:
			draw_circle(p, 18.0 * (1.0 - drop), Color(0, 0, 0, 0.4))
			p.y -= drop * 500.0
		draw_circle(p + Vector2(3, 8), 19, Color(0, 0, 0, 0.35))
		var armed = bool(b.get("armed", false))
		# Untriggered barrels must NOT have a burning fuse. The spark is
		# present only on the armed asset after an actual weapon/dash hit.
		# One identical physical barrel in both states. Only the fuse
		# overlay changes; never swap to differently drawn barrel art.
		var image = g.tex("res://assets/ui/barrel_unlit.svg")
		if image != null:
			var flash = 0.35 + 0.65 * absf(sin(g.anim_t * (12.0 + (0.85 - float(b.get("fuse", 0.85))) * 15.0))) if armed else 1.0
			draw_texture_rect(image, Rect2(p - Vector2(21, 25), Vector2(42, 50)), false, Color(1.0, flash, flash, 1.0))
		else:
			draw_rect(Rect2(p - Vector2(15, 18), Vector2(30, 36)), Color("c8301e"))
		if armed:
			# The spark is rendered at the same fuse position on the SAME SVG.
			var spark_pos = p + Vector2(6.5, -23.0)
			var flicker = 0.70 + 0.30 * absf(sin(g.anim_t * 21.0))
			draw_circle(spark_pos, 6.5 * flicker, Color("ff9c35", 0.8))
			draw_circle(spark_pos + Vector2(0, -2.5), 3.6 * flicker, Color("fff6a8"))
			var progress = 1.0 - clampf(float(b.get("fuse", 0.85)) / 0.85, 0.0, 1.0)
			draw_circle(p, 115.0, Color(1.0, 0.25, 0.12, 0.08 + progress * 0.15))
			draw_arc(p, 115.0, -PI * 0.5, -PI * 0.5 + progress * TAU, 40, Color("ffda70"), 4.0)
			draw_arc(p, 25.0, 0.0, TAU, 24, Color("ff5858"), 3.0)
			if progress > 0.25:
				for j in range(8):
					var ray = Vector2.from_angle(float(j) * TAU / 8.0 + g.anim_t * 0.4)
					draw_line(p + ray * 31.0, p + ray * (38.0 + progress * 14.0), Color("ffe088", 0.45 + progress * 0.4), 2.0)
	for pet in g.pets:
		if pet["kind"] == "mine":
			var mp = P(pet["pos"])
			draw_circle(mp, 9, Color("3a3a48"))
			var blink = fmod(g.anim_t * (6.0 if float(pet["arm"]) <= 0.0 else 2.0), 1.0) < 0.5
			draw_circle(mp, 3.5, Color("ff3a3a") if blink else Color("601818"))

func paint_telegraphs() -> void:
	paint_boss_arena()
	for d in g.delayed:
		if d.has("source") and bool(d["source"].get("dead", false)):
			continue
		var fn: String = str(d.get("fn", ""))
		if fn == "boss_gravity":
			paint_gravity(d)
			continue
		if fn.begins_with("bf_"):
			paint_boss_event(d)
			continue
		if not d.has("tele"):
			continue
		var life = maxf(0.01, float(d.get("life", 0.6)))
		var k = 1.0 - clampf(float(d["t"]) / life, 0.0, 1.0)
		var warning_color = Color(str(d.get("color", "ff744e")))
		# Lines and circles share one language: a dark base marks the exact
		# hitbox, the inner fill grows to the rim, and the rim flashes white
		# in the last moment before it hits.
		if fn in ["boss_line", "blink_slash"]:
			danger_line(P(d["a"]), P(d["b"]), float(d["tele"]), k, warning_color, d)
			continue
		var pos: Vector2 = d["pos"]
		var tgt = d.get("enemy")
		if tgt != null and not bool(tgt["dead"]):
			pos = tgt["pos"]
		var p = P(pos)
		var r = float(d["tele"])
		if fn in ["boss_blast", "elite_boom"]:
			danger_circle(p, r, k, warning_color, d)
			continue
		draw_circle(p, r, Color(warning_color, 0.035 + 0.075 * k))
		draw_arc(p, r, 0.0, TAU, 32, Color(warning_color, 0.73), 2.0)
		draw_arc(p, maxf(6.0, r - 8.0), -PI * 0.5, -PI * 0.5 + TAU * k,
			28, Color(warning_color.lightened(0.45), 0.72), 2.0)
		if d["fn"] == "kaboomba_boom":
			# The dead bomber remains visible as a blinking armed body until detonation.
			var blink = fmod(g.anim_t * (6.0 + k * 12.0), 1.0) < 0.5
			draw_circle(p + Vector2(2, 6), 17.0, Color(0, 0, 0, 0.4))
			draw_circle(p, 16.0 + k * 5.0, Color("ffb543") if blink else Color("c52a37"))
			draw_circle(p - Vector2(5, 4), 4.0, Color.WHITE)
			draw_circle(p + Vector2(5, -4), 4.0, Color.WHITE)
			draw_circle(p + Vector2(0, -21), 3.0 + k * 3.0, Color("fff37b"))
			draw_arc(p, r, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color("ffdf6d"), 5.0)
			continue
		var fall = (1.0 - k) * 420.0
		match d["fn"]:
			"anvil":
				if bool(d.get("piano", false)):
					draw_rect(Rect2(p.x - 40, p.y - fall - 30, 80, 44), Color("181820"))
					for i in range(7):
						draw_rect(Rect2(p.x - 36 + i * 10.5, p.y - fall - 2, 9, 14), Color.WHITE)
				else:
					draw_colored_polygon(PackedVector2Array([p + Vector2(-26, -fall - 10), p + Vector2(26, -fall - 10), p + Vector2(16, -fall + 4), p + Vector2(-16, -fall + 4)]), Color("5a6070"))
					draw_rect(Rect2(p.x - 12, p.y - fall + 4, 24, 12), Color("4a5060"))
			"mortar":
				draw_circle(p + Vector2(0, -fall * 1.4), 9, Color("3a3320"))
				draw_circle(p + Vector2(-2, -fall * 1.4 - 2), 5, Color("c9b27a"))
			"meteor":
				var mp = p + Vector2(fall * 0.4, -fall)
				draw_line(mp, mp + Vector2(50, -70), Color(1, 0.6, 0.2, 0.6), 10.0)
				draw_circle(mp, 16, Color("ff7a3d"))
				draw_circle(mp, 10, Color("ffd24d"))
	for e in g.enemies:
		if float(e.get("wind", 0.0)) > 0.0:
			var p = P(e["pos"])
			if enemy_has_role(e, "lancer"):
				var lock: Vector2 = e.get("lock", g.hero["pos"])
				var lance_dir: Vector2 = (lock - e["pos"]).normalized()
				var angle: float = lance_dir.angle()
				if str(e.get("lancer_attack", "spear")) == "sweep":
					# Full sweep sector shows the actual 166-unit range and 132-degree attack cone.
					var sector_poly := PackedVector2Array([p])
					for step_i in range(25):
						var theta: float = angle - 1.152 + float(step_i) / 24.0 * 2.304
						sector_poly.append(p + Vector2.from_angle(theta) * 166.0)
					draw_colored_polygon(sector_poly, Color("aabaff", 0.16))
					draw_arc(p, 166.0, angle - 1.152, angle + 1.152, 40, Color("c5d5ff", 0.83), 3.0)
				else:
					draw_line(p, p + lance_dir * 610.0, Color("b9ccff", 0.21), 19.0)
					draw_line(p, p + lance_dir * 610.0, Color("e2eaff", 0.78), 3.0)
			elif enemy_has_role(e, "larry"):
				var lock: Vector2 = e.get("lock", g.hero["pos"])
				var beam_dir: Vector2 = (lock - e["pos"]).normalized()
				draw_line(p, p + beam_dir * 900.0, Color("ff5a82", 0.25 + 0.5 * fmod(g.anim_t * 8.0, 1.0)), 3.0)
			elif e.has("tele") and enemy_has_role(e, "chonk"):
				draw_arc(p, float(e["tele"]), 0, TAU, 40, Color(1, 0.3, 0.3, 0.8), 3.0)
				draw_circle(p, float(e["tele"]), Color(1, 0.2, 0.2, 0.12))
			elif enemy_has_role(e, "bull") or e["kind"] in ["zoomer", "skitter"]:
				var color = Color("83eaff") if e["kind"] == "skitter" else Color(1, 0.6, 0.2)
				draw_line(p, P(g.hero["pos"]), Color(color, 0.45), 5.0)
			elif enemy_has_role(e, "blinky"):
				var depart: Vector2 = P(e.get("rift_origin", e["pos"]))
				var arrive: Vector2 = P(e.get("lock", g.hero["pos"]))
				draw_arc(arrive, 22.0, 0, TAU, 24, Color("c79cff", 0.68), 3.0)
				# This preview is the exact dash slash segment, not a player prediction.
				draw_line(depart, arrive, Color("b88bff", 0.21), 30.0)
				draw_line(depart, arrive, Color("ebd5ff", 0.83), 2.5)
			elif e["kind"] == "leech":
				var drain_to = P(e.get("lock", g.hero["pos"]))
				var pulse = 0.34 + 0.26 * sin(g.anim_t * 14.0)
				draw_line(p, drain_to, Color(0.84, 0.34, 1.0, pulse), 4.5)
				draw_arc(drain_to, 27.0, 0, TAU, 30, Color("d9a3ff", 0.80), 3.0)
				draw_arc(p, float(e["r"]) + 8.0, 0, TAU, 24, Color("d9a3ff", 0.90), 3.5)
			elif e["kind"] == "spitter":
				# Its acid is slow (~240 px/s) and easy to watch, so no aim line: only the body cue.
				draw_arc(p, float(e["r"]) + 5.0, 0, TAU, 24, Color("a2ff83", 0.80), 2.5)
			elif enemy_has_role(e, "mirror"):
				var dest = P(e.get("lock", g.hero["pos"]))
				var central = (dest - p).normalized()
				for bend in [-0.23, 0.0, 0.23]:
					draw_line(p, p + central.rotated(bend) * minf(520.0, p.distance_to(dest) + 60.0),
						Color("72f3ff", 0.35 + 0.23 * sin(g.anim_t * 13.0)), 2.0)
				draw_arc(p, 31.0, 0, TAU, 28, Color("aafaff"), 3.0)
			elif e["kind"] == "burrower":
				var dest = P(e.get("lock", g.hero["pos"]))
				var burrow = e["kind"] == "burrower"
				var shade = Color("ffe2a3") if burrow else Color("cba0ff")
				var radius = 66.0 if burrow else 70.0
				draw_circle(dest, radius, Color(shade, 0.10))
				draw_arc(dest, radius, 0, TAU, 36, Color(shade, 0.9), 3.5)
				draw_circle(p, float(e["r"]) * 1.15, Color(shade, 0.18))
				draw_line(p, dest, Color(shade, 0.38), 2.0)

## Energy barriers at both ends of a locked boss arena.
func paint_boss_arena() -> void:
	if not bool(g.boss_arena_on) or not g.boss_alive():
		return
	var col := Color("ff5a7a")
	for e in g.enemies:
		if bool(e["boss"]) and not bool(e["dead"]):
			col = Color(BossFight.PALETTE.get(str(e["kind"]), "ff5a7a"))
			break
	for edge in [float(g.boss_arena_y) - float(g.BOSS_ARENA_UP) - 40.0, float(g.boss_arena_y) + float(g.BOSS_ARENA_DOWN) + 30.0]:
		var y: float = P(Vector2(0, edge)).y
		if y < g.view_top - 20.0 or y > g.view_bottom + 20.0:
			continue
		var x0: float = P(Vector2(-g.road_half, 0)).x
		var x1: float = P(Vector2(g.road_half, 0)).x
		draw_rect(Rect2(Vector2(x0, y - 9.0), Vector2(x1 - x0, 18.0)), Color(col, 0.10))
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(col, 0.35 + 0.2 * sin(g.anim_t * 4.0)), 4.0)
		var x := x0 + fmod(g.anim_t * 50.0, 40.0)
		while x < x1:
			draw_line(Vector2(x, y - 7.0), Vector2(x + 16.0, y + 7.0), Color(col.lightened(0.4), 0.6), 2.0)
			x += 40.0

func danger_circle(p: Vector2, r: float, k: float, col: Color, d: Dictionary) -> void:
	draw_circle(p, r, Color(col, 0.07))
	draw_circle(p, r * k, Color(col, 0.14 + 0.22 * k))
	draw_arc(p, r, 0.0, TAU, 48, Color(0, 0, 0, 0.45), 5.0, true)
	draw_arc(p, r, 0.0, TAU, 48, Color(col.lightened(0.35), 0.95), 2.5, true)
	if k > 0.78:
		draw_arc(p, r, 0.0, TAU, 48, Color(1, 1, 1, (k - 0.78) / 0.22 * 0.9), 3.5, true)
	var drop: float = (1.0 - k) * 150.0
	# A falling object tells the player what is about to land.
	if bool(d.get("bomb", false)) or bool(d.get("mortar", false)):
		var b := p + Vector2(0, -drop)
		draw_circle(b, 8.0, Color("1d1f26"))
		draw_circle(b + Vector2(-2, -2), 3.0, Color("8a8f9c"))
		draw_line(b + Vector2(0, -8), b + Vector2(0, -14), Color("ffd24d"), 2.0)
	elif bool(d.get("boulder", false)):
		var rock := p + Vector2(0, -drop * 1.4)
		draw_circle(rock, r * 0.3, Color("6b4a33"))
		draw_circle(rock + Vector2(-r * 0.08, -r * 0.08), r * 0.12, Color("9c7454"))
	elif str(d.get("style", "")) == "chonkzilla" and not bool(d.get("landing", false)):
		if k > 0.35:
			var fade: float = (k - 0.35) / 0.65
			var m := p + Vector2(drop * 0.4, -drop * 1.3)
			draw_line(m, m + Vector2(14, -24) * (1.0 + fade), Color(1, 0.6, 0.2, 0.45 * fade), 6.0)
			draw_circle(m, 8.0, Color("ff7a3d", fade))
			draw_circle(m, 4.5, Color("ffe08a", fade))
	elif str(d.get("style", "")) == "necro":
		var stone := PackedVector2Array([p + Vector2(-9, 10), p + Vector2(-9, -4), p + Vector2(0, -12), p + Vector2(9, -4), p + Vector2(9, 10)])
		draw_colored_polygon(stone, Color("8f8aa0", 0.4 + 0.5 * k))
		draw_line(p + Vector2(0, -6), p + Vector2(0, 5), Color(0, 0, 0, 0.6), 2.0)
		draw_line(p + Vector2(-4, -2), p + Vector2(4, -2), Color(0, 0, 0, 0.6), 2.0)
	elif str(d.get("style", "")) == "kingblob" and int(d.get("burst", 0)) > 0:
		var gem := p + Vector2(0, -drop)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -10), gem + Vector2(8, 0), gem + Vector2(0, 10), gem + Vector2(-8, 0)]), Color("ffcf3d"))
		draw_circle(gem, 3.0, Color("ff3d5a"))
	elif bool(d.get("blink", false)):
		draw_arc(p, r * 0.5, g.anim_t * 4.0, g.anim_t * 4.0 + PI * 1.4, 20, Color(col.lightened(0.4), 0.9), 3.0, true)
	elif bool(d.get("landing", false)):
		pass # The airborne boss's own shadow is the tell.
	else:
		draw_circle(p, 3.0 + 2.0 * k, Color(col.lightened(0.4), 0.8))

func danger_line(a: Vector2, b: Vector2, w: float, k: float, col: Color, d: Dictionary) -> void:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([a + n * w, b + n * w, b - n * w, a - n * w]), Color(col, 0.07))
	var inner: float = w * k
	draw_colored_polygon(PackedVector2Array([a + n * inner, b + n * inner, b - n * inner, a - n * inner]), Color(col, 0.14 + 0.22 * k))
	for side in [-1.0, 1.0]:
		draw_line(a + n * w * side, b + n * w * side, Color(0, 0, 0, 0.45), 4.0)
		draw_line(a + n * w * side, b + n * w * side, Color(col.lightened(0.35), 0.95), 2.0)
	if k > 0.78:
		draw_line(a, b, Color(1, 1, 1, (k - 0.78) / 0.22 * 0.8), maxf(2.0, w * 0.5))
	var length: float = a.distance_to(b)
	if bool(d.get("piston", false)):
		# Hazard stripes march toward the strike.
		var step := 34.0
		var shift: float = fmod(g.anim_t * 60.0, step)
		var x := shift
		while x < length:
			var c := a + dir * x
			draw_line(c - n * w * 0.8, c + dir * 12.0 + n * w * 0.8, Color("1d1f26", 0.55), 4.0)
			x += step
	elif bool(d.get("prism", false)):
		draw_line(a, b, Color(1, 1, 1, 0.25 + 0.5 * k), 1.5)
		draw_circle(a.lerp(b, k), 4.0, Color(1, 1, 1, 0.7))
	elif bool(d.get("web", false)):
		var x2 := fmod(g.anim_t * 40.0, 24.0)
		while x2 < length:
			draw_line(a + dir * x2, a + dir * minf(length, x2 + 10.0), Color(col.lightened(0.5), 0.6), 2.0)
			x2 += 24.0

func paint_gravity(d: Dictionary) -> void:
	var center: Vector2 = P(d["pos"])
	var radius: float = float(d["tele"])
	var armed = float(d.get("arm", 0.0)) <= 0.0
	var col := Color(str(d.get("color", "a18aff")))
	draw_circle(center, radius, Color(col.darkened(0.6), 0.18 if armed else 0.08))
	draw_arc(center, radius, 0.0, TAU, 56, Color(0, 0, 0, 0.4), 5.0, true)
	draw_arc(center, radius, g.anim_t * 0.8, g.anim_t * 0.8 + TAU * 0.92, 56, Color(col.lightened(0.3), 0.95 if armed else 0.45), 3.0, true)
	for ring in range(4):
		var rr: float = radius * (0.95 - fmod(g.anim_t * 0.5 + float(ring) * 0.25, 1.0) * 0.85)
		draw_arc(center, rr, -g.anim_t * 2.0 + ring, -g.anim_t * 2.0 + ring + PI * 1.2, 34, Color(col.lightened(0.5), 0.45), 2.0, true)
	draw_circle(center, 14.0, Color("0b0614"))
	draw_arc(center, 14.0, 0.0, TAU, 20, Color(col.lightened(0.5)), 2.0, true)

## Boss-specific delayed events: missile locks, portals, echoes, squeezes.
func paint_boss_event(d: Dictionary) -> void:
	var p: Vector2 = P(d["pos"])
	var life := maxf(0.01, float(d.get("life", 1.0)))
	var k := 1.0 - clampf(float(d["t"]) / life, 0.0, 1.0)
	var col := Color(str(d.get("color", "ffffff")))
	match str(d["fn"]):
		"bf_boulder":
			# The lane the boulder will roll down, with an arrow showing its direction.
			var la: Vector2 = P(d["a"])
			var lb: Vector2 = P(d["b"])
			var w: float = float(d.get("tele", 26.0))
			draw_rect(Rect2(Vector2(la.x, la.y - w), Vector2(lb.x - la.x, w * 2.0)), Color(col, 0.06 + 0.14 * k))
			for side in [-1.0, 1.0]:
				draw_line(Vector2(la.x, la.y + side * w), Vector2(lb.x, lb.y + side * w), Color(col.lightened(0.3), 0.75), 2.0)
			var dir := float(d["dir"])
			var x := fmod(g.anim_t * 120.0, 60.0)
			while x < lb.x - la.x:
				var ax: float = la.x + x if dir > 0.0 else lb.x - x
				draw_line(Vector2(ax, la.y - 9.0), Vector2(ax + dir * 10.0, la.y), Color(col.lightened(0.4), 0.7), 3.0)
				draw_line(Vector2(ax + dir * 10.0, la.y), Vector2(ax, la.y + 9.0), Color(col.lightened(0.4), 0.7), 3.0)
				x += 60.0
		"bf_ring":
			# Expanding shockwave band: stand inside or outside it, not on it.
			var inner: float = float(d["inner"])
			var outer: float = float(d["outer"])
			var mid: float = (inner + outer) * 0.5
			draw_arc(p, mid, 0.0, TAU, 64, Color(col, 0.08 + 0.16 * k), outer - inner, true)
			draw_arc(p, inner, 0.0, TAU, 64, Color(col.lightened(0.35), 0.9), 2.0, true)
			draw_arc(p, outer, 0.0, TAU, 64, Color(col.lightened(0.35), 0.9), 2.0, true)
			draw_arc(p, lerpf(inner, outer, k), 0.0, TAU, 64, Color(1, 1, 1, 0.25 + 0.5 * k), 2.0, true)
		"bf_lock":
			var rr: float = float(d.get("tele", 34.0)) * (1.7 - 0.7 * k)
			var red := Color("ff4d4d")
			var boss = d.get("boss")
			if boss != null and not bool(boss.get("dead", false)):
				draw_line(P(boss["pos"]), p, Color(red, 0.18 + 0.25 * k), 1.5)
			draw_arc(p, rr, 0.0, TAU, 32, Color(0, 0, 0, 0.4), 4.0, true)
			draw_arc(p, rr, 0.0, TAU, 32, Color(red, 0.95), 2.0, true)
			for i in range(4):
				var dir := Vector2.from_angle(g.anim_t * 2.0 + PI * 0.5 * float(i))
				draw_line(p + dir * (rr - 10.0), p + dir * (rr + 8.0), red, 3.0)
			if fmod(g.anim_t * (4.0 + k * 10.0), 1.0) < 0.5:
				draw_circle(p, 4.0, red)
		"bf_portal":
			var rr2: float = float(d.get("tele", 34.0)) * (0.4 + 0.6 * k)
			draw_circle(p, rr2, Color("0b0614"))
			for i in range(3):
				var off: float = g.anim_t * (3.0 + i) + TAU * float(i) / 3.0
				draw_arc(p, rr2 * (1.0 - i * 0.22), off, off + PI * 1.3, 24, Color(col.lightened(0.2 * i), 0.95), 3.0, true)
			var aim: Vector2 = (g.hero["pos"] - Vector2(d["pos"])).normalized()
			draw_line(p + aim * (rr2 + 4.0), p + aim * (rr2 + 22.0 + 16.0 * k), Color(col.lightened(0.4), 0.85), 3.0)
		"bf_echo":
			var ghost := Color("8ceeff")
			draw_circle(p, 13.0, Color(ghost, 0.18 + 0.25 * k))
			draw_arc(p, 13.0, 0.0, TAU, 20, Color(ghost, 0.85), 2.0, true)
			draw_arc(p, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, Color(ghost, 0.95), 3.0, true)
			draw_circle(p + Vector2(-4, -3), 2.0, Color(ghost, 0.9))
			draw_circle(p + Vector2(4, -3), 2.0, Color(ghost, 0.9))
		"bf_squeeze":
			# Venom floods in from both edges and stops at the corridor.
			var gap: float = float(d["gap"])
			var cx: float = float(d["pos"].x)
			var top: float = P(Vector2(0, float(d["top"]))).y
			var bottom: float = P(Vector2(0, float(d["bottom"]))).y
			for side in [-1.0, 1.0]:
				var edge: float = float(d["left"]) if side < 0 else float(d["right"])
				var stop: float = cx + side * gap
				var front: float = lerpf(edge, stop, k)
				var x0: float = P(Vector2(edge, 0)).x
				var x1: float = P(Vector2(front, 0)).x
				var xs: float = P(Vector2(stop, 0)).x
				draw_rect(Rect2(Vector2(minf(x0, xs), top), Vector2(absf(xs - x0), bottom - top)), Color(col.darkened(0.65), 0.16))
				draw_rect(Rect2(Vector2(minf(x0, x1), top), Vector2(absf(x1 - x0), bottom - top)), Color(col, 0.2 + 0.12 * k))
				draw_line(Vector2(xs, top), Vector2(xs, bottom), Color(col.lightened(0.4), 0.5), 2.0)
				var wave := PackedVector2Array()
				for i in range(24):
					var y: float = lerpf(top, bottom, float(i) / 23.0)
					wave.append(Vector2(x1 + sin(y * 0.05 + g.anim_t * 6.0) * 6.0, y))
				draw_polyline(wave, Color(0, 0, 0, 0.45), 6.0, true)
				draw_polyline(wave, Color(col.lightened(0.3), 0.95), 3.0, true)
			if k > 0.75:
				var flash := (k - 0.75) / 0.25
				for side2 in [-1.0, 1.0]:
					var xs2: float = P(Vector2(cx + side2 * gap, 0)).x
					draw_line(Vector2(xs2, top), Vector2(xs2, bottom), Color(1, 1, 1, flash * 0.8), 3.0)

## Necro's soul chains and the Oracle's mirror links, drawn under the boss.
func paint_boss_links(e: Dictionary, p: Vector2) -> void:
	for m in BossFight.minions(g, e):
		var role := str(m.get("minion_role", ""))
		var q := P(m["pos"])
		if role == "ward":
			var pts := PackedVector2Array()
			for i in range(13):
				var u := float(i) / 12.0
				var n: Vector2 = (q - p).normalized().orthogonal()
				pts.append(p.lerp(q, u) + n * sin(u * TAU * 2.0 + g.anim_t * 5.0) * 6.0)
			draw_polyline(pts, Color("c79bff", 0.45), 3.0, true)
		elif role == "mirror":
			draw_line(p, q, Color("bff8ff", 0.35 + 0.15 * sin(g.anim_t * 4.0)), 2.0)

## Persistent enemy hazards are rendered at their TRUE damage radii.
func paint_identity_hazards() -> void:
	for h in g.enemy_hazards:
		var p: Vector2 = P(h["pos"])
		if p.y < g.view_top - 120.0 or p.y > g.view_bottom + 120.0:
			continue
		var r = float(h["r"])
		var armed = float(h["arm"]) <= 0.0
		match str(h["kind"]):
			"mine":
				var col = Color("ffb861") if armed else Color("8f9daa")
				draw_circle(p, r, Color(col, 0.13))
				draw_arc(p, r, 0, TAU, 28, Color(col, 0.7), 2.5)
				draw_circle(p, 10.0, Color("33242a"))
				draw_circle(p, 4.0, Color("ff704e") if armed else Color("a9dafa"))
			"egg":
				draw_circle(p, r + 3.0, Color("7dffcf", 0.18))
				draw_arc(p, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - float(h["life"]) / float(h["max_life"])), 30, Color("a9ffee"), 3.0)
				draw_circle(p, r * 0.7, Color("caffeb"))
			"acid":
				draw_circle(p, r, Color("a3ff65", 0.22))
				draw_arc(p, r, 0, TAU, 20, Color("8adf5a", 0.55), 2.0)
			"acid_trail":
				# One uninterrupted toxic ribbon. Exact collision width, no rows of circles.
				if h.has("pts"):
					paint_acid_ribbon(h)
					continue
				var a: Vector2 = P(h["a"])
				var b: Vector2 = P(h["b"])
				var tangent: Vector2 = (b - a).normalized()
				var normal: Vector2 = tangent.orthogonal()
				var fade: float = clampf(float(h["life"]) / maxf(0.01, float(h["max_life"])), 0.0, 1.0)
				draw_line(a, b, Color("42752b", 0.35 * fade), r * 2.0 + 7.0)
				draw_line(a, b, Color("aaff73", 0.34 * fade), r * 2.0)
				draw_line(a + normal * r, b + normal * r, Color("a1f86d", 0.62 * fade), 2.0)
				draw_line(a - normal * r, b - normal * r, Color("a1f86d", 0.62 * fade), 2.0)
				for vein in range(3):
					var offset: float = (float(vein) - 1.0) * r * 0.38
					draw_line(a + normal * offset, b + normal * offset, Color("deff98", 0.15 * fade), 1.7)
			"fissure":
				var a: Vector2 = P(h["a"])
				var b: Vector2 = P(h["b"])
				draw_line(a, b, Color("d7a36d", 0.18), r * 2.0)
				draw_line(a, b, Color("f9cc83", 0.78 if armed else 0.3), 3.0)

# ================================================================= enemies
func paint_enemies() -> void:
	for e in g.enemies:
		if bool(e["dead"]):
			continue
		var p = P(e["pos"])
		var r = float(e["r"])
		if p.y < g.view_top - r - 60.0 or p.y > g.view_bottom + r + 60.0:
			continue
		if bool(e["boss"]):
			paint_boss_links(e, p)
		if bool(e.get("burrowing", false)) and not bool(e["boss"]):
			# Actual underground phase: render the entrance crater, not the
			# same standing slime. The destination and tunnel are shown above.
			draw_circle(p, r + 4.0, Color("312920", 0.8))
			draw_arc(p, r + 8.0, 0, TAU, 24, Color("e4b873", 0.8), 2.5)
			continue
		if enemy_has_role(e, "ashwing") and float(e.get("rebirth_t", 0.0)) > 0.0:
			draw_circle(p, r + 3.0, Color("652e28"))
			draw_circle(p, r * 0.72, Color("ffbc69"))
		else:
			draw_enemy(e, p, r)
		# Real slime-wall links, only around visible threatening packs.
		if e["kind"] == "blob" and e["pos"].distance_squared_to(g.hero["pos"]) < 210.0 * 210.0:
			var linked = 0
			for other in g.enemies:
				if other == e or bool(other["dead"]) or str(other["kind"]) != "blob" or int(other["id"]) < int(e["id"]):
					continue
				if e["pos"].distance_squared_to(other["pos"]) < 75.0 * 75.0:
					draw_line(p, P(other["pos"]), Color("ffadc1", 0.40), 8.0)
					linked += 1
					if linked >= 2:
						break
		if e["kind"] == "leech" and float(e.get("tether_t", 0.0)) > 0.0:
			draw_line(p, P(g.hero["pos"]), Color("c86eff", 0.6 + 0.2 * sin(g.anim_t * 10.0)), 3.5)
			var receiver: Dictionary = e.get("siphon_target", {})
			if not receiver.is_empty() and not bool(receiver.get("dead", false)):
				draw_line(p, P(receiver["pos"]), Color("c98aff", 0.65), 6.0)
				draw_line(p, P(receiver["pos"]), Color("f2d3ff", 0.75), 2.0)
				draw_arc(P(receiver["pos"]), float(receiver["r"]) + 9.0, 0, TAU, 26, Color("d7a2ff", 0.84), 3.0)
				text_c("EMPOWERED", P(receiver["pos"]) + Vector2(0, -float(receiver["r"]) - 22.0), 10, Color("e7baff"), 2)
		if float(e.get("laser_t", 0.0)) > 0.0:
			draw_arc(p, r + 8.0, 0, TAU, 22, Color("ff577a", 0.75), 3.0)
		if float(e.get("sprint_t", 0.0)) > 0.0:
			draw_arc(p, r + 6.0, 0, TAU, 20, Color("ffbc66", 0.75), 2.5)
		# Allies protected by a nearby Hype Totem must look protected.
		# Draw only a thin, translucent outline to keep mass encounters fast.
		if not Combat.protecting_totem(g, e).is_empty():
			draw_circle(p, r + 4.0, Color("5cbcff", 0.09))
			draw_arc(p, r + 5.0, 0.0, TAU, 18, Color("8fdcff", 0.46), 2.1)
			if float(e.get("shield_flash_until", 0.0)) > g.run_time:
				draw_arc(p, r + 8.0, 0.0, TAU, 22, Color("d9faff", 0.86), 3.0)
		if enemy_has_role(e, "ashwing") and float(e.get("rebirth_t", 0.0)) > 0.0:
			var progress = 1.0 - float(e["rebirth_t"]) / (1.55 if g.hard_mode else 1.8)
			progress = clampf(progress, 0.0, 1.0)
			draw_circle(p, r * (0.7 + progress * 0.35), Color(1.0, 0.35, 0.06, 0.25))
			draw_arc(p, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color("ffdf80"), 4.0)
			text_c("BREAK EGG OR IT REBIRTHS", p + Vector2(0, -r - 32.0), 10, Color("ffdf80"), 2)
		elif e["kind"] == "larry" and float(e.get("overheat_t", 0.0)) > 0.0:
			draw_arc(p, r + 10.0, 0, TAU, 28, Color("ffcf8a"), 4.0)
			text_c("OVERHEATED", p + Vector2(0, -r - 28.0), 11, Color("ffe5a4"), 2)
		elif e["kind"] == "nurse" and e.get("patient") != null:
			var patient = e["patient"]
			if not bool(patient.get("dead", false)):
				draw_line(p, P(patient["pos"]), Color("83efbb", 0.65), 2.5)
				if float(e.get("treat_t", 0.0)) > 0.0:
					draw_arc(p, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, float(e["treat_t"]) / 1.15), 24, Color("83ffac"), 3.0)
		elif enemy_has_role(e, "siren"):
			draw_arc(p, 180.0, 0, TAU, 64, Color(0.95, 0.54, 0.85, 0.22), 2.0)
		elif enemy_has_role(e, "mirror") and float(e.get("wind", 0.0)) > 0.0:
			draw_arc(p, r + 9.0, 0, TAU, 24, Color("aafaff"), 3.0)
		elif e["kind"] == "burrower" and float(e.get("emerge_t", 0.0)) > 0.0:
			draw_arc(p, 66.0, 0, TAU, 48, Color("ffe2a3", 0.9), 3.0)
			draw_circle(p, 66.0, Color("ffe2a3", 0.12))
		if e.has("affix"):
			text_c(" · ".join(e["affix"]), p + Vector2(0, -r - 20), 11, Color(1, 0.82, 0.3, 0.85), 2)
		elif enemy_has_role(e, "totem"):
			var linked_allies = 0
			for ally in g.enemies:
				if ally != e and not bool(ally["dead"]) and ally["pos"].distance_squared_to(e["pos"]) <= Combat.TOTEM_R * Combat.TOTEM_R:
					if ally["pos"].distance_squared_to(g.hero["pos"]) < 300.0 * 300.0:
						draw_line(p, P(ally["pos"]), Color("7ad1ff", 0.20), 1.3)
						linked_allies += 1
						if linked_allies >= 12:
							break
			draw_arc(p, Combat.TOTEM_R, 0, TAU, 64, Color(0.48, 0.82, 1.0, 0.25 + 0.15 * sin(g.anim_t * 3.0)), 3.0)
			text_c("HALVES ALLY DAMAGE", p + Vector2(0, -r - 34), 13, Color("7ad1ff"), 3)

# ---------------------------------------------------------------- baked enemy sprites
## Each enemy look (kind + elite) is drawn once into a texture at startup; per frame an enemy is
## one textured quad plus its pupils and any live effects. Same art, a fraction of the draw calls.
const BAKE_R = 40.0
const CELL = 200
const ATLAS_COLS = 8
## All enemy looks (kind + elite) and a white dot (for pupils) live in ONE atlas texture, so a whole
## crowd is drawn as plain textured quads that the GPU batches together.
func enemy_has_role(e: Dictionary, role: String) -> bool:
	var kind = str(e["kind"])
	return kind == role or (kind.begins_with("mix_") and g.enemy_db[kind]["mix"].has(role))

var atlas: Texture2D = null
var atlas_cell: Dictionary = {}

class Baker extends Node2D:
	var v
	var keys: Array = []
	func _draw() -> void:
		for i in range(keys.size()):
			var o = Vector2((i % 8) * 200, int(i / 8) * 200)
			var key: String = keys[i]
			if key == "#dot":
				draw_circle(o + Vector2(100, 100), 40.0, Color.WHITE)
				continue
			var kind = key.trim_suffix("*")
			var elite = key.ends_with("*")
			draw_set_transform(o + Vector2(100, 138), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 38.0, Color(0, 0, 0, 0.35))
			draw_set_transform(o + Vector2(100, 108), 0.0, Vector2.ONE)
			if elite or bool(v.g.enemy_db[kind].get("boss", false)):
				draw_circle(Vector2.ZERO, 47.0, Color(1.0, 0.82, 0.3, 0.22))
			v.draw_enemy_body(self, kind, elite, 40.0, Color(str(v.g.enemy_db[kind]["color"])), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func bake_enemies() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var keys = []
	for kind in g.enemy_db:
		keys.append(kind)
		if not bool(g.enemy_db[kind].get("boss", false)):
			keys.append(kind + "*")
	keys.append("#dot")
	var rows = ceili(keys.size() / float(ATLAS_COLS))
	var vp = SubViewport.new()
	vp.size = Vector2i(ATLAS_COLS * CELL, rows * CELL)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var baker = Baker.new()
	baker.v = self
	baker.keys = keys
	vp.add_child(baker)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		if OS.get_environment("DUMP_ATLAS") != "":
			img.save_png(ProjectSettings.globalize_path("res://build/atlas.png"))
		img.generate_mipmaps()
		for i in range(keys.size()):
			atlas_cell[keys[i]] = Rect2((i % ATLAS_COLS) * CELL, int(i / ATLAS_COLS) * CELL, CELL, CELL)
		atlas = ImageTexture.create_from_image(img)
	vp.queue_free()

func draw_enemy(e: Dictionary, p: Vector2, r: float) -> void:
	if bool(e.get("boss", false)) and BossFight.is_boss_kind(str(e["kind"])):
		draw_boss(e, p, r)
		return
	if str(e.get("minion_role", "")) in ["ward", "mirror", "pod"]:
		var flash_m := float(e["flash"]) > 0.0
		draw_ellipse_shadow(p + Vector2(0, r * 0.9), r * 0.8)
		draw_set_transform(p, 0.0, Vector2.ONE)
		BossModels.minion(self, str(e["minion_role"]), r, {"t": g.anim_t + float(e["phase"]), "aim": (g.hero["pos"] - Vector2(e["pos"])).normalized()})
		if flash_m:
			draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var health = clampf(float(e["hp"]) / maxf(1.0, float(e["max_hp"])), 0.0, 1.0)
		draw_arc(p, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * health, 24, Color(1, 1, 1, 0.7), 2.5, true)
		draw_status(e, p, r)
		return
	var kind = str(e["kind"])
	var parts: Dictionary = g.enemy_db[kind].get("look", {})
	# Dynamic hybrids reuse an already-baked parent quad; no N^2 atlas explosion.
	var mixed = kind.begins_with("mix_")
	var parents: Array = g.enemy_db[kind].get("mix", []) if mixed else []
	var base_kind = str(parents[0]) if not parents.is_empty() else kind
	var src = atlas_cell.get(base_kind + ("*" if bool(e["elite"]) else ""))
	if atlas == null or src == null:
		draw_enemy_live(e, p, r)
		return
	var flash = float(e["flash"]) > 0.0
	var tint = Color.WHITE
	if flash:
		tint = Color(2.4, 2.4, 2.4)
	else:
		if float(e["chill"]) > 0.0:
			tint = tint.lerp(Color(0.65, 0.95, 1.25), clampf(float(e["chill"]) / 100.0, 0.0, 0.7))
		if float(e["charm"]) > 0.0:
			tint = tint.lerp(Color(1.25, 0.6, 1.05), 0.6)
	var spawn = float(e["spawn"])
	var bob = sin(float(e["t"]) * 10.0 + float(e["phase"])) * 0.06
	var sq = float(e["squash"])
	var sx = (1.0 + sq * 0.6 + bob) * spawn
	var sy = (1.0 - sq * 0.5 - bob) * spawn
	var spinning = float(e.get("spin", 0.0)) > 0.0 or float(e.get("dance", 0.0)) > 0.0
	if float(e.get("dance", 0.0)) > 0.0:
		p.y -= absf(sin(g.anim_t * 10.0)) * 8.0
	if float(e["bubble"]) > 0.0:
		p.y -= 10.0 + sin(g.anim_t * 4.0) * 4.0
	var k = r / BAKE_R
	var col: Color = e["color"]
	if kind == "zoomer" or kind == "mini":
		var back = -e["vel"].normalized() if e["vel"].length() > 5 else Vector2.DOWN
		for j in range(3):
			draw_line(p + back.rotated(0.4 * (j - 1)) * r, p + back.rotated(0.4 * (j - 1)) * (r + 10 + j * 3), Color(col, 0.5), 2.0)
	if spinning:
		var rot = float(e["t"]) * 14.0 if float(e.get("spin", 0.0)) > 0.0 else sin(g.anim_t * 14.0) * 0.5
		draw_set_transform(p, rot, Vector2(sx, sy) * k)
		draw_texture_rect_region(atlas, Rect2(-100, -108, CELL, CELL), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(atlas, Rect2(p.x - 100.0 * k * sx, p.y - 108.0 * k * sy, CELL * k * sx, CELL * k * sy), src, tint)
	# Chonkzilla's body itself changes as armor breaks; this is not merely a HUD label.
	# Draw cheap lines over the already-baked sprite: no new texture or particles.
	if kind == "chonkzilla":
		var stage: int = Combat.boss_stage(e)
		if stage > 0:
			var fracture_color = Color("ffcb8d") if stage == 1 else Color("ff7750")
			var cracks: Array = [
				[p + Vector2(-r * 0.42, -r * 0.70), p + Vector2(-r * 0.12, -r * 0.12), p + Vector2(-r * 0.36, r * 0.48)],
				[p + Vector2(r * 0.36, -r * 0.78), p + Vector2(r * 0.08, -r * 0.04), p + Vector2(r * 0.38, r * 0.55)]
			]
			for crack in cracks:
				draw_line(crack[0], crack[1], Color(fracture_color, 0.85), 4.0 if stage == 2 else 2.8)
				draw_line(crack[1], crack[2], Color(fracture_color, 0.76), 3.6 if stage == 2 else 2.4)
		if stage == 2:
			draw_arc(p, r + 6.0, g.anim_t * 0.85, g.anim_t * 0.85 + PI * 1.3, 32,
				Color("ff7750", 0.73), 4.0)
			draw_circle(p + Vector2(0, r * 0.12), r * 0.12, Color("ffc381", 0.82))
	# live parts: rotor, fuse spark, pupils (pupils use the atlas dot, so they stay in the same batch)
	if kind == "coilqueen":
		for coil_index in range(3):
			var coil_angle = g.anim_t * 2.4 + coil_index * TAU / 3.0
			draw_arc(p, r + 8.0 + 7.0 * coil_index, coil_angle, coil_angle + PI * 0.9, 15, Color("78ffd3", 0.75), 3.5)
	elif kind == "glassoracle":
		var prism_orbit = g.anim_t * 1.3
		for prism_index in range(4):
			var shard_angle = prism_orbit + prism_index * TAU / 4.0
			draw_line(p + Vector2.from_angle(shard_angle) * r * 0.9, p + Vector2.from_angle(shard_angle) * r * 1.4, Color("dcffff"), 3.0)
	elif kind == "voidweaver":
		draw_arc(p, r * 1.35, -PI * 0.5 + g.anim_t * 0.9, PI + g.anim_t * 0.9, 35, Color("b397ff", 0.9), 4.0)
	elif kind == "dreadengine":
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(p + Vector2(side * (r + 7.0) - 10.0, -r * 0.36), Vector2(20, r * 0.72)), Color("ffc07c"))
	if kind == "heli":
		var a = g.anim_t * 25.0
		draw_line(p + Vector2.from_angle(a) * r * 1.6, p + Vector2.from_angle(a + PI) * r * 1.6, Color(0.9, 0.9, 1.0, 0.6), 5.0)
		draw_line(p + Vector2.from_angle(a + PI * 0.5) * r * 1.6, p + Vector2.from_angle(a + PI * 1.5) * r * 1.6, Color(0.9, 0.9, 1.0, 0.6), 5.0)
	elif kind == "kaboomba":
		draw_circle(p + Vector2(5, -r - 10), 3.5 + sin(g.anim_t * 30.0) * 1.5, Color("ffd24d"))
	var look: Vector2 = e["aim"]
	var eye_r = maxf(3.5, r * 0.3)
	var ey = -r * 0.18 * sy
	if str(parts.get("face", "")) == "visor":
		draw_rect(Rect2(p.x - r * 0.7 + (look.x + 1.0) * r * 0.5, p.y + ey - 2, r * 0.4, 4), Color("ff3a5a"))
	elif not spinning:
		var dot: Rect2 = atlas_cell["#dot"]
		dot = Rect2(dot.position + Vector2(60, 60), Vector2(80, 80))
		var pr = eye_r * 0.5
		var off = look * eye_r * 0.45
		var pc = Color("120810") if float(e["frozen"]) <= 0.0 else Color("4080a0")
		var big_head = g.st("bighead") > 0
		for ex in ([0.0] if kind == "necro" else [-0.36, 0.36]):
			var ep = p + Vector2(ex * r * sx, ey)
			if big_head:
				draw_texture_rect_region(atlas, Rect2(ep - Vector2(eye_r, eye_r) * 1.6, Vector2(eye_r, eye_r) * 3.2), dot, Color.WHITE)
				draw_texture_rect_region(atlas, Rect2(ep + off * 1.6 - Vector2(pr, pr) * 1.6, Vector2(pr, pr) * 3.2), dot, pc)
			else:
				draw_texture_rect_region(atlas, Rect2(ep + off - Vector2(pr, pr), Vector2(pr, pr) * 2.0), dot, pc)
			if float(e["charm"]) > 0.0:
				heart(ep + Vector2(0, -1), eye_r * 0.6, Color("ff3a8a"))
	if kind == "riot":
		var aim: Vector2 = e["aim"]
		var sp = p + aim * (r + 4)
		var perp = aim.orthogonal()
		draw_line(sp - perp * r * 1.1, sp + perp * r * 1.1, Color("2a3a60"), 9.0)
		draw_line(sp - perp * r * 1.0, sp + perp * r * 1.0, Color("a8c0ff"), 5.0)
	if mixed and parents.size() >= 2:
		# Inherit one ANATOMICAL feature from the second parent. Do not
		# paste eyes, masks, lips or a complete second face onto the base.
		var secondary = Color(str(g.enemy_db[str(parents[1])]["color"]))
		draw_hybrid_trait(self, p, r, str(e.get("hybrid_trait", parts.get("trait", "ears"))),
			secondary, int(parts.get("variant", 0)))
	draw_status(e, p, r)

## Bosses are drawn live: they animate, react to phases and wind up visibly.
func draw_boss(e: Dictionary, p: Vector2, r: float) -> void:
	var kind := str(e["kind"])
	var hop := float(e.get("bf_hop", 0.0))
	var state := str(e.get("bf_state", ""))
	var a := {"t": g.anim_t + float(e["phase"]), "stage": Combat.boss_stage(e),
		"tell": BossFight.tell_progress(e), "flash": float(e["flash"]) > 0.0,
		"aim": Vector2(e["aim"]), "squash": float(e["squash"]),
		"heat": float(e.get("bf_heat", 0.0)) / 100.0, "vent": state == "vent",
		"dizzy": float(e.get("bf_dizzy", 0.0)) > 0.0,
		"armored": kind == "glassoracle" and not BossFight.minions(g, e, "mirror").is_empty(),
		"vanish": bool(e.get("bf_vanish", false)), "burrowed": bool(e.get("burrowing", false)),
		"gun": float(e.get("bf_gun", PI * 0.5)), "spin": float(e.get("bf_spin", 0.0)),
		"rolling": state == "attack" and str(e.get("bf_attack", "")) == "belly_roll"}
	if kind == "coilqueen":
		var local: Array = []
		for q in e.get("bf_trail", []):
			local.append(Vector2(q) - Vector2(e["pos"]))
		a["trail"] = local
	# The shadow stays on the ground and shrinks while the boss is airborne.
	var lift := clampf(hop / 140.0, 0.0, 1.0)
	BossModels.shadow(self, p + Vector2(0, r * 0.85), r * (1.05 - lift * 0.35), 0.32 + lift * 0.12)
	if state == "transition":
		var pulse := 0.5 + 0.5 * sin(g.anim_t * 18.0)
		draw_circle(p, r * 1.5, Color(1, 1, 1, 0.08 + 0.08 * pulse))
		draw_arc(p, r * (1.35 + pulse * 0.1), 0.0, TAU, 48, Color(1, 1, 1, 0.75), 3.0, true)
	var rot := float(e.get("bf_bank", 0.0)) * 0.2 if kind == "heli" else 0.0
	var xf := Transform2D(rot, p + Vector2(0, -hop))
	a["xf"] = xf
	draw_set_transform_matrix(xf)
	BossModels.draw(self, kind, r, a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_status(e, p, r)

## Fallback before the atlas is baked: draw the vector art directly.
func draw_enemy_live(e: Dictionary, p: Vector2, r: float) -> void:
	var kind = str(e["kind"])
	var parts: Dictionary = g.enemy_db[kind].get("look", {})
	draw_set_transform(p + Vector2(0, r * 0.75), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.35))
	draw_set_transform(p, 0.0, Vector2.ONE)
	var mixed = kind.begins_with("mix_") and g.enemy_db[kind].has("mix")
	var parent = str(g.enemy_db[kind]["mix"][0]) if mixed else kind
	var parent_color = Color(str(g.enemy_db[parent]["color"])) if mixed else e["color"]
	draw_enemy_body(self, parent, bool(e["elite"]), r, parent_color, float(e["flash"]) > 0.0)
	if mixed:
		var secondary = Color(str(g.enemy_db[str(g.enemy_db[kind]["mix"][1])]["color"]))
		draw_hybrid_trait(self, Vector2.ZERO, r, str(e.get("hybrid_trait", parts.get("trait", "ears"))), secondary, int(parts.get("variant", 0)))
	var look: Vector2 = e["aim"]
	var eye_r = maxf(3.5, r * 0.3)
	if str(parts.get("face", "")) != "visor":
		for ex in ([0.0] if kind == "necro" else [-0.36, 0.36]):
			draw_circle(Vector2(ex * r, -r * 0.18) + look * eye_r * 0.45, eye_r * 0.5, Color("120810"))
	else:
		draw_rect(Rect2(-r * 0.2, -r * 0.18 - 2, r * 0.4, 4), Color("ff3a5a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_status(e, p, r)

## Second-parent inheritance draws one appendage/outer-body detail only.
## The first parent's complete face remains intact. 19 choices are enough to
## give sector-40 combinations recognizable silhouettes without N*N sprites.
func draw_hybrid_trait(ci: CanvasItem, c: Vector2, r: float, feature_name: String, accent: Color, feature_variant: int = 0) -> void:
	var shade = accent.darkened(0.43)
	match feature_name:
		"ears":
			for signum in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.43, -r * 0.69),
					c + Vector2(signum * r * 0.92, -r * 1.55), c + Vector2(signum * r * 0.87, -r * 0.34)]), shade)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.53, -r * 0.75),
					c + Vector2(signum * r * 0.87, -r * 1.38), c + Vector2(signum * r * 0.75, -r * 0.49)]), accent)
		"horns":
			for signum in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.34, -r * 0.77),
					c + Vector2(signum * r * 1.09, -r * 1.48), c + Vector2(signum * r * 0.76, -r * 0.53)]), shade)
				ci.draw_line(c + Vector2(signum * r * 0.55, -r * 0.72),
					c + Vector2(signum * r * 1.00, -r * 1.34), accent, maxf(2.0, r * 0.11))
		"antennae":
			for signum in [-1.0, 1.0]:
				var base = c + Vector2(signum * r * 0.43, -r * 0.85)
				var tip = c + Vector2(signum * r * 1.03, -r * 1.49)
				ci.draw_line(base, tip, shade, maxf(2.0, r * 0.11))
				ci.draw_circle(tip, r * 0.18, accent)
		"wings":
			for signum in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.60, -r * 0.10),
					c + Vector2(signum * r * 1.75, -r * 1.02), c + Vector2(signum * r * 1.46, r * 0.67),
					c + Vector2(signum * r * 0.77, r * 0.42)]), Color(accent, 0.83))
				ci.draw_line(c + Vector2(signum * r * 0.83, r * 0.23),
					c + Vector2(signum * r * 1.65, -r * 0.86), shade, maxf(1.5, r * 0.075))
		"tail":
			ci.draw_arc(c + Vector2(r * 0.65, r * 0.45), r * 0.55, -PI * 0.30, PI * 0.75,
				12, shade, maxf(3.0, r * 0.24))
			ci.draw_circle(c + Vector2(r * 1.07, r * 0.74), r * 0.23, accent)
		"shell":
			for signum in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(signum * r * 0.58, r * 0.06), r * 0.52,
					PI * 0.42, PI * 1.50, 12, shade, maxf(3.0, r * 0.30))
				ci.draw_circle(c + Vector2(signum * r * 0.86, r * 0.14), r * 0.18, accent)
		"cheeks":
			for signum in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(signum * r * 0.83, r * 0.39), r * 0.33, shade)
				ci.draw_circle(c + Vector2(signum * r * 0.80, r * 0.35), r * 0.26, accent)
		"spikes", "crystal":
			for k in range(3):
				var x = (float(k) - 1.0) * r * 0.74
				var length = r * (0.55 if feature_name == "spikes" else 0.84)
				var root = c + Vector2(x, -r * (0.77 if k == 1 else 0.66))
				ci.draw_colored_polygon(PackedVector2Array([root + Vector2(-r * 0.21, 0),
					root + Vector2(0, -length), root + Vector2(r * 0.21, 0)]), shade)
				ci.draw_line(root + Vector2(0, -r * 0.10), root + Vector2(0, -length * 0.75),
					accent, maxf(2.0, r * 0.08))
		"buds":
			for signum in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(signum * r * 0.79, -r * 0.70), r * 0.32, shade)
				ci.draw_circle(c + Vector2(signum * r * 0.78, -r * 0.73), r * 0.24, accent)
		"armor", "shoulders":
			for signum in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.66, -r * 0.55),
					c + Vector2(signum * r * 1.29, -r * 0.45), c + Vector2(signum * r * 1.18, r * 0.45),
					c + Vector2(signum * r * 0.75, r * 0.51)]), shade)
				ci.draw_line(c + Vector2(signum * r * 1.11, -r * 0.32),
					c + Vector2(signum * r * 1.02, r * 0.30), accent, maxf(2.0, r * 0.14))
		"crest", "crown", "helmet":
			var top = -r * (1.58 if feature_name == "crown" else 1.34)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.70, -r * 0.74),
				c + Vector2(-r * 0.48, top * 0.92), c + Vector2(0, top),
				c + Vector2(r * 0.47, top * 0.89), c + Vector2(r * 0.70, -r * 0.74)]), shade)
			ci.draw_line(c + Vector2(-r * 0.45, -r * 1.02),
				c + Vector2(r * 0.45, -r * 1.02), accent, maxf(2.0, r * 0.16))
		"legs":
			for signum in [-1.0, 1.0]:
				for j in range(2):
					var down = r * (0.24 + j * 0.37)
					ci.draw_line(c + Vector2(signum * r * 0.77, down * 0.4),
						c + Vector2(signum * r * 1.40, down + r * 0.1), shade, maxf(2.0, r * 0.13))
					ci.draw_circle(c + Vector2(signum * r * 1.40, down + r * 0.1), r * 0.11, accent)
		"claws":
			for signum in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(signum * r * 0.76, r * 0.30),
					c + Vector2(signum * r * 1.35, r * 0.78), shade, maxf(3.0, r * 0.19))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 1.22, r * 0.58),
					c + Vector2(signum * r * 1.58, r * 0.99), c + Vector2(signum * r * 1.31, r * 0.96)]), accent)
		"fins":
			for signum in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(signum * r * 0.76, -r * 0.20),
					c + Vector2(signum * r * 1.54, -r * 0.77),
					c + Vector2(signum * r * 1.17, r * 0.59)]), Color(accent, 0.85))
		"tentacles":
			for signum in [-1.0, 1.0]:
				var start = c + Vector2(signum * r * 0.70, r * 0.38)
				var finish = c + Vector2(signum * r * 1.22, r * 1.13)
				ci.draw_line(start, finish, shade, maxf(3.0, r * 0.18))
				ci.draw_circle(finish, r * 0.18, accent)
	# A tiny accent along the jaw signals the secondary genealogy, not
	# another complete muzzle, visor, pair of eyes or face.
	var mark_side = -1.0 if feature_variant % 2 == 0 else 1.0
	ci.draw_circle(c + Vector2(mark_side * r * 0.72, r * 0.62),
		maxf(2.0, r * 0.115), Color(accent, 0.82))

## Parts are data-driven, so one body can wear any combination of role gear.
func draw_modular_body(ci: CanvasItem, parts: Dictionary, r: float, body: Color, dark: Color) -> void:
	ci.draw_circle(Vector2.ZERO, r, dark)
	ci.draw_circle(Vector2(0, -1), r - 2.0, body)
	if parts.has("second_color"):
		var second = Color(str(parts["second_color"]))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -r + 2), Vector2(r * 0.68, -r * 0.68), Vector2(r - 2, 0), Vector2(r * 0.68, r * 0.68), Vector2(0, r - 2)]), second)
		ci.draw_line(Vector2(0, -r * 0.85), Vector2(0, r * 0.85), Color("fff2bf"), 2.0)
	if str(parts.get("face", "")) == "white":
		ci.draw_circle(Vector2(0, r * 0.08), r * 0.75, Color("d5e3ec"))
		ci.draw_circle(Vector2(0, r * 0.03), r * 0.69, Color("f8fcff"))
	elif str(parts.get("face", "")) == "visor":
		ci.draw_rect(Rect2(-r * 0.84, -r * 0.4, r * 1.68, r * 0.58), Color("2a1831"))

func draw_modular_gear(ci: CanvasItem, parts: Dictionary, r: float) -> void:
	for gear in parts.get("gear", []):
		match str(gear):
			"medic_cap":
				ci.draw_circle(Vector2(0, -r * 0.82), r * 0.57, Color("dce9f2"))
				ci.draw_rect(Rect2(-r * 0.62, -r * 1.05, r * 1.24, r * 0.43), Color("f8fcff"))
				ci.draw_rect(Rect2(-r * 0.09, -r * 1.01, r * 0.18, r * 0.34), Color("e84960"))
				ci.draw_rect(Rect2(-r * 0.21, -r * 0.89, r * 0.42, r * 0.12), Color("e84960"))
			"laser_lens":
				ci.draw_rect(Rect2(-r * 0.73, -r * 0.28, r * 1.46, r * 0.24), Color("591d40"))
				ci.draw_circle(Vector2(0, -r * 0.16), r * 0.2, Color("ff547e"))
				ci.draw_circle(Vector2(0, -r * 0.16), r * 0.1, Color("ffe0eb"))
			"helmet":
				ci.draw_circle(Vector2(0, -r * 0.74), r * 0.75, Color("47553d"))
				ci.draw_rect(Rect2(-r * 0.88, -r * 0.88, r * 1.76, r * 0.24), Color("75855e"))
				ci.draw_rect(Rect2(-r * 0.24, -r * 1.22, r * 0.48, r * 0.18), Color("b9c69b"))

## Everything about an enemy that does not move: body, props, eye whites, mouth, crown.
## Drawn on any canvas (ci) so it can be baked; centre is the current transform origin.
func draw_enemy_body(ci: CanvasItem, kind: String, elite: bool, r: float, col: Color, flash: bool) -> void:
	if BossFight.is_boss_kind(kind):
		# Portrait pose for atlases and the Bestiary (scaled to fit a cell).
		BossModels.draw(ci, kind, r * 0.82, {"t": 0.6, "flash": flash})
		return
	var body = Color.WHITE if flash else col
	var dark = col.darkened(0.45)
	var parts: Dictionary = g.enemy_db[kind].get("look", {})
	var slime = kind in ["blob", "zoomer", "chonk", "spitter", "mitosis", "mini", "mama", "chonkzilla", "kingblob", "ashwing"]
	if slime:
		for k in range(5):
			var a = TAU * float(k) / 5.0
			var lobe = Vector2(cos(a) * r * 0.62, sin(a) * r * 0.58)
			ci.draw_circle(lobe, r * (0.43 if k % 2 == 0 else 0.36), dark)
			ci.draw_circle(lobe + Vector2(0, -2), r * (0.39 if k % 2 == 0 else 0.32), body)
	match kind:
		"coilqueen":
			for k in range(6):
				var angle = float(k) * TAU / 6.0
				var tail_pos = Vector2.from_angle(angle) * r * 0.85
				ci.draw_circle(tail_pos, r * 0.37, Color("2a785c"))
				ci.draw_arc(tail_pos, r * 0.27, 0.0, TAU, 14, Color("9cffe0"), 3.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, -r * 0.9), Vector2(0, -r * 1.65), Vector2(r * 0.6, -r * 0.9)]), Color("baffd9"))
		"glassoracle":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.1, 0), Vector2(0, -r * 1.55), Vector2(r * 1.1, 0), Vector2(0, r * 1.25)]), Color("4c9cbd"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.8, 0), Vector2(0, -r * 1.23), Vector2(r * 0.8, 0), Vector2(0, r * 0.95)]), Color("d5ffff"))
			ci.draw_line(Vector2(-r * 0.65, r * 0.4), Vector2(r * 0.65, -r * 0.4), Color("81bdff"), 5.0)
		"voidweaver":
			for k in range(5):
				var angle = float(k) * TAU / 5.0 - PI * 0.5
				var tip = Vector2.from_angle(angle) * r * 1.65
				ci.draw_line(Vector2.ZERO, tip, Color("5c408d"), r * 0.17)
				ci.draw_circle(tip, r * 0.21, Color("bd95ff"))
			ci.draw_circle(Vector2.ZERO, r * 0.58, Color("452b77"))
		"dreadengine":
			ci.draw_rect(Rect2(-r * 1.15, -r * 0.82, r * 2.3, r * 1.75), Color("52382f"))
			ci.draw_rect(Rect2(-r * 0.85, -r * 1.1, r * 1.7, r * 1.6), Color("c88a4d"))
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(side * r * 0.83 - r * 0.24, -r * 0.4, r * 0.48, r * 1.0), Color("49434a"))
			ci.draw_circle(Vector2.ZERO, r * 0.34, Color("ffe3a0"))
		"skitter":
			for signum in [-1.0, 1.0]:
				ci.draw_line(Vector2(signum * r * 0.35, r * 0.4), Vector2(signum * r * 1.4, r * 1.1), Color("d6faff"), 3.0)
				ci.draw_circle(Vector2(signum * r * 1.4, r * 1.1), r * 0.18, Color("58bbdf"))
		"sapper":
			ci.draw_circle(Vector2(0, -r * 0.65), r * 0.6, Color("8a6041"))
			ci.draw_line(Vector2(-r * 0.65, -r * 0.15), Vector2(r * 0.6, r * 0.18), Color("ffe0ac"), 3.0)
			ci.draw_circle(Vector2(r * 0.6, r * 0.2), r * 0.22, Color("ff7a46"))
		"lancer":
			ci.draw_line(Vector2(r * 0.4, r * 0.9), Vector2(r * 1.35, -r * 1.5), Color("e4e8ff"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 1.35, -r * 1.55), Vector2(r * 1.0, -r * 0.9), Vector2(r * 1.7, -r * 0.9)]), Color("9caaff"))
		"leech":
			ci.draw_circle(Vector2(-r * 0.52, r * 0.67), r * 0.35, Color("58329b"))
			ci.draw_circle(Vector2(r * 0.52, r * 0.67), r * 0.35, Color("58329b"))
			ci.draw_arc(Vector2(0, r * 0.2), r * 0.52, PI * 0.2, PI * 0.85, 12, Color("3c145a"), 4.0)
		"ashwing":
			# Jagged flaming wings and a burnt phoenix crown.
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(side * r * 0.5, 0), Vector2(side * r * 1.7, -r * 0.8), Vector2(side * r * 1.2, r * 0.25), Vector2(side * r * 1.35, r * 0.7)]), Color("ff632f"))
				ci.draw_line(Vector2(side * r * 0.5, 0), Vector2(side * r * 1.35, -r * 0.55), Color("ffe19c"), maxf(2.0, r * 0.12))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.4, -r * 0.75), Vector2(0, -r * 1.85), Vector2(r * 0.4, -r * 0.75)]), Color("ffe19c"))
		"mirror":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.15, 0), Vector2(0, -r * 1.32), Vector2(r * 1.15, 0), Vector2(0, r * 1.25)]), Color("24899c"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.76, 0), Vector2(0, -r * 0.96), Vector2(r * 0.76, 0), Vector2(0, r * 0.93)]), Color("c0faff"))
		"burrower":
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.85, r * 0.48), r * 0.4, Color("72502d"))
				ci.draw_line(Vector2(side * r * 0.7, r * 0.35), Vector2(side * r * 1.45, r * 0.78), Color("ffe2a3"), 4.0)
		"siren":
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(side * r * 0.7, -r * 0.25), Vector2(side * r * 1.4, -r * 0.92), Vector2(side * r * 1.35, r * 0.5)]), Color("ad4f9b"))
			ci.draw_arc(Vector2.ZERO, r * 1.08, -PI * 0.8, PI * 0.8, 18, Color("ffd6f5"), 3.0)
		"spitter":
			for s in [-1.0, 1.0]:
				ci.draw_circle(Vector2(s * r * 0.7, -r * 0.65), r * 0.36, dark)
				ci.draw_circle(Vector2(s * r * 0.7, -r * 0.65), r * 0.25, Color("d8ff91"))
		"mitosis", "kingblob":
			for s in [-1.0, 1.0]:
				ci.draw_circle(Vector2(s * r * 0.8, r * 0.45), r * 0.42, dark)
				ci.draw_circle(Vector2(s * r * 0.8, r * 0.45), r * 0.35, body)
		"bull":
			for s in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(s * r * 0.6, -r * 0.5), Vector2(s * r * 1.25, -r * 1.5), Vector2(s * r * 0.95, -r * 0.12)]), Color("fff0cf"))
		"goblin":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.65, -r * 0.15), Vector2(-r * 1.35, -r * 0.6), Vector2(-r * 1.08, r * 0.4)]), dark)
		"necro":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.1, r * 0.7), Vector2(0, -r * 1.55), Vector2(r * 1.1, r * 0.7)]), Color("24142f"))
		"riot":
			for s in [-1.0, 1.0]:
				ci.draw_rect(Rect2(s * r * 0.65 - r * 0.22, -r * 0.25, r * 0.44, r * 0.8), Color("344765"))
		"heli":
			for s in [-1.0, 1.0]:
				ci.draw_circle(Vector2(s * r * 0.9, r * 0.25), r * 0.28, Color("303647"))
		"nurse":
			ci.draw_circle(Vector2(r * 0.9, -r * 0.25), r * 0.35, Color("e7f2f6"))
		"larry":
			ci.draw_circle(Vector2(0, -r * 0.9), r * 0.34, Color("662239"))
		"mortar":
			ci.draw_line(Vector2(r * 0.2, -r * 0.3), Vector2(r * 0.85, -r * 1.25), Color("2b2a24"), r * 0.55)
			ci.draw_line(Vector2(r * 0.2, -r * 0.3), Vector2(r * 0.8, -r * 1.15), Color("6a6656"), r * 0.38)
		"blinky":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(r, 0), Vector2(r * 0.8, r * 1.3), Vector2(r * 0.35, r * 0.95),
				Vector2(0, r * 1.35), Vector2(-r * 0.35, r * 0.95), Vector2(-r * 0.8, r * 1.3)]), Color(col, 0.75))
		"tick":
			for k in range(6):
				var lx = (-1.0 if k < 3 else 1.0)
				var ly = (k % 3 - 1) * r * 0.55
				ci.draw_line(Vector2(lx * r * 0.5, ly), Vector2(lx * r * 1.45, ly + r * 0.35), Color("24331c"), 2.5)
	match kind:
		"mirror":
			ci.draw_circle(Vector2.ZERO, r * 0.7, Color("1c6680"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.65, 0), Vector2(0, -r * 0.88), Vector2(r * 0.65, 0), Vector2(0, r * 0.85)]), body)
			ci.draw_line(Vector2(-r * 0.48, r * 0.2), Vector2(r * 0.45, -r * 0.43), Color.WHITE, 2.2)
		"burrower":
			ci.draw_circle(Vector2.ZERO, r, Color("72502d"))
			ci.draw_circle(Vector2(0, -r * 0.13), r * 0.87, body)
			ci.draw_arc(Vector2.ZERO, r * 0.72, PI, TAU, 14, Color("ffe2a3"), 3.0)
		"siren":
			ci.draw_circle(Vector2.ZERO, r, Color("7d3d76"))
			ci.draw_circle(Vector2.ZERO, r - 2.0, body)
			ci.draw_circle(Vector2(0, r * 0.44), r * 0.35, Color("743568"))
			ci.draw_circle(Vector2(0, r * 0.44), r * 0.19, Color("ffe6f6"))
		"chonk", "chonkzilla", "mama":
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -2), r - 3, body)
			ci.draw_circle(Vector2(-r * 0.35, r * 0.35), r * 0.25, body.lightened(0.15))
		"zoomer", "mini":
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2.ZERO, r - 2, body)
		"kaboomba":
			for k in range(8):
				var a = TAU * k / 8.0
				ci.draw_line(Vector2.from_angle(a) * r * 0.7, Vector2.from_angle(a) * r * 1.13, Color("342630"), 5.0)
			ci.draw_circle(Vector2.ZERO, r, Color("201018"))
			ci.draw_circle(Vector2(0, 1), r - 3, body if flash else Color("3a3037"))
			ci.draw_arc(Vector2.ZERO, r * 0.72, 0.15, PI - 0.15, 12, Color("ff704d"), 3.0)
			ci.draw_line(Vector2(0, -r), Vector2(5, -r - 9), Color("c8a060"), 3.0)
		"riot":
			ci.draw_rect(Rect2(-r * 0.82, -r * 0.85, r * 1.64, r * 1.7), Color("263650"))
			ci.draw_rect(Rect2(-r * 0.68, -r * 0.7, r * 1.36, r * 1.4), body)
			ci.draw_rect(Rect2(-r * 0.6, r * 0.1, r * 1.2, r * 0.24), Color("405d83"))
		"mitosis", "kingblob":
			ci.draw_circle(Vector2.ZERO, r, Color(dark, 0.9))
			ci.draw_circle(Vector2.ZERO, r - 3, Color(body, 0.85))
			ci.draw_circle(Vector2(r * 0.25, r * 0.3), r * 0.28, Color(dark, 0.6))
		"heli":
			ci.draw_rect(Rect2(-r * 0.38, r * 0.16, r * 0.76, r * 0.9), Color("343445"))
			ci.draw_circle(Vector2.ZERO, r * 0.82, Color("303140"))
			ci.draw_circle(Vector2.ZERO, r * 0.72, body)
			ci.draw_rect(Rect2(-r * 0.45, -r * 0.25, r * 0.9, r * 0.42), Color("8dd0de"))
			ci.draw_line(Vector2(-r * 0.5, r * 0.75), Vector2(r * 0.5, r * 0.75), Color("d8e6e8"), 5.0)
		"goblin":
			ci.draw_circle(Vector2(r * 0.7, r * 0.2), r * 0.6, Color("c8a040"))
			ci.draw_circle(Vector2(r * 0.7, r * 0.2), r * 0.45, Color("ffd24d"))
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2.ZERO, r - 2, body)
		"bull":
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, 1), r - 2, body)
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.4, body.lightened(0.16))
		"totem":
			ci.draw_rect(Rect2(-r * 0.8, -r * 1.35, r * 1.6, r * 2.4), Color("1d3550"))
			ci.draw_rect(Rect2(-r * 0.68, -r * 1.23, r * 1.36, r * 2.16), body)
			for k in range(3):
				ci.draw_rect(Rect2(-r * 0.68, -r * 0.7 + k * r * 0.62, r * 1.36, r * 0.14), Color("e8f8ff"))
		"blinky":
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -1), r - 2, body)
		"tick":
			ci.draw_circle(Vector2.ZERO, r, Color("24331c"))
			ci.draw_circle(Vector2(0, -1), r - 2, body)
			ci.draw_circle(Vector2(0, r * 0.35), r * 0.5, body.darkened(0.25))
		"necro":
			ci.draw_circle(Vector2.ZERO, r, Color("261932"))
			ci.draw_circle(Vector2.ZERO, r - 3, body)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, r * 0.8), Vector2(0, r * 1.3), Vector2(r * 0.6, r * 0.8)]), Color("44265b"))
		_:
			if str(parts.get("body", "")) == "round":
				draw_modular_body(ci, parts, r, body, dark)
			else:
				ci.draw_circle(Vector2.ZERO, r, dark)
				ci.draw_circle(Vector2(0, -1), r - 2, body)
	if slime:
		ci.draw_arc(Vector2(0, -1), r - 3, PI * 1.08, PI * 1.9, 18, Color(1, 1, 1, 0.28), maxf(2.0, r * 0.12))
		ci.draw_circle(Vector2(-r * 0.43, -r * 0.48), maxf(2.0, r * 0.13), Color(1, 1, 1, 0.38))
		ci.draw_circle(Vector2(r * 0.48, r * 0.49), maxf(1.5, r * 0.09), dark.lightened(0.12))
		for k in range(2):
			var bubble = Vector2((-0.55 + k * 1.04) * r, (0.42 - k * 0.15) * r)
			ci.draw_circle(bubble, maxf(1.5, r * 0.075), Color(1, 1, 1, 0.28))
	# eye whites (pupils are drawn live so they can look around)
	var eye_r = maxf(3.5, r * 0.3)
	var ey = -r * 0.18
	if str(parts.get("face", "")) == "visor":
		ci.draw_rect(Rect2(-r * 0.8, ey - eye_r * 0.7, r * 1.6, eye_r * 1.4), Color("200810"))
	else:
		for ep in ([Vector2(0, ey)] if kind == "necro" else [Vector2(-r * 0.36, ey), Vector2(r * 0.36, ey)]):
			ci.draw_circle(ep, eye_r, Color.WHITE)
	match kind:
		"ashwing":
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.2, Color("6d291c"))
			ci.draw_line(Vector2(-r * 0.43, r * 0.34), Vector2(r * 0.38, r * 0.34), Color("ffe19c"), 2.3)
		"mirror":
			ci.draw_line(Vector2(-r * 0.4, r * 0.4), Vector2(r * 0.4, r * 0.4), Color("14687a"), 2.3)
		"burrower":
			ci.draw_circle(Vector2(0, r * 0.5), r * 0.22, Color("503b2b"))
		"siren":
			ci.draw_circle(Vector2(0, r * 0.52), r * 0.16, Color("ffddfa"))
		"blob":
			ci.draw_arc(Vector2(0, r * 0.35), r * 0.28, 0.25, PI - 0.25, 10, Color("6c2946"), 2.5)
		"zoomer", "mini":
			ci.draw_line(Vector2(-r * 0.32, r * 0.36), Vector2(r * 0.4, r * 0.24), Color("66323c"), 2.5)
		"mitosis":
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.15, Color("276c64"))
		"kingblob":
			ci.draw_arc(Vector2(0, r * 0.38), r * 0.3, 0.1, PI - 0.1, 12, Color("63263e"), maxf(3.0, r * 0.08))
			for s in [-1.0, 1.0]:
				ci.draw_circle(Vector2(s * r * 0.7, r * 0.4), r * 0.12, Color("ffb0c4"))
		"riot":
			ci.draw_rect(Rect2(-r * 0.68, -r * 0.96, r * 1.36, r * 0.3), Color("344765"))
			ci.draw_rect(Rect2(-r * 0.6, -r * 0.85, r * 1.2, r * 0.15), Color("b7d8f9"))
		"heli":
			ci.draw_rect(Rect2(-r * 0.45, r * 0.45, r * 0.9, r * 0.23), Color("4c5363"))
		"goblin":
			ci.draw_circle(Vector2(r * 0.65, r * 0.22), r * 0.19, Color("fff4a3"))
		"chonk", "chonkzilla":
			ci.draw_line(Vector2(-r * 0.55, ey - eye_r * 1.2), Vector2(-r * 0.15, ey - eye_r * 0.7), Color("201018"), 3.0)
			ci.draw_line(Vector2(r * 0.55, ey - eye_r * 1.2), Vector2(r * 0.15, ey - eye_r * 0.7), Color("201018"), 3.0)
			ci.draw_arc(Vector2(0, r * 0.45), r * 0.3, PI + 0.3, TAU - 0.3, 10, Color("201018"), 3.0)
		"bull":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7, -r * 0.7), Vector2(-r * 1.2, -r * 1.3), Vector2(-r * 0.4, -r * 0.9)]), Color("f0e8d8"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.7, -r * 0.7), Vector2(r * 1.2, -r * 1.3), Vector2(r * 0.4, -r * 0.9)]), Color("f0e8d8"))
			ci.draw_circle(Vector2(0, r * 0.45), r * 0.22, Color("402020"))
		"spitter":
			ci.draw_circle(Vector2(0, r * 0.45), r * 0.3, Color("204010"))
			ci.draw_circle(Vector2(0, r * 0.45), r * 0.17, Color("89db52"))
		"mama":
			ci.draw_circle(Vector2(-r * 0.5, -r * 0.9), r * 0.25, Color("ff3a8a"))
			ci.draw_circle(Vector2(-r * 0.15, -r * 0.9), r * 0.25, Color("ff3a8a"))
			ci.draw_arc(Vector2(0, r * 0.35), r * 0.25, 0.2, PI - 0.2, 10, Color("401020"), 3.0)
		"necro":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.4), Vector2(0, -r * 1.7), Vector2(r, -r * 0.4)]), Color("2a1840"))
			ci.draw_rect(Rect2(-r * 0.4, r * 0.3, r * 0.8, r * 0.25), Color("e8e0f0"))
		"kaboomba":
			ci.draw_arc(Vector2(0, r * 0.35), r * 0.28, 0.25, PI - 0.25, 10, Color("201018"), 2.5)
	if not parts.is_empty():
		draw_modular_gear(ci, parts, r)
	if elite or kind in ["kingblob", "chonkzilla"]:
		var cy = -r - 4.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, cy + 4), Vector2(-r * 0.55, cy - 10), Vector2(-r * 0.25, cy - 3),
			Vector2(0, cy - 13), Vector2(r * 0.25, cy - 3), Vector2(r * 0.55, cy - 10), Vector2(r * 0.5, cy + 4)]), Color("ffd24d"))

func draw_status(e: Dictionary, p: Vector2, r: float) -> void:
	if float(e["frozen"]) > 0.0:
		draw_rect(Rect2(p - Vector2(r + 4, r + 4), Vector2(r * 2 + 8, r * 2 + 8)), Color(0.7, 0.95, 1.0, 0.45))
		draw_rect(Rect2(p - Vector2(r + 4, r + 4), Vector2(r * 2 + 8, r * 2 + 8)), Color(0.9, 1.0, 1.0, 0.8), false, 2.0)
	if float(e["burn"]) > 0.0:
		for k in range(3):
			var fp = p + Vector2((k - 1) * r * 0.5, -r * 0.6 - fmod(g.anim_t * 40.0 + k * 9.0, 14.0))
			draw_circle(fp, 4.0, Color(1.0, 0.5 + 0.2 * k, 0.1, 0.8))
	if float(e["poison"]) > 0.0:
		draw_circle(p + Vector2(r * 0.8, -r * 0.7 - fmod(g.anim_t * 20.0, 10.0)), 3.0, Color("8dff6b"))
	if float(e["shock"]) > 0.0 and fmod(g.anim_t * 10.0 + float(e["phase"]), 1.0) < 0.5:
		zigzag(p + Vector2(-r, -r * 0.3), p + Vector2(r, r * 0.2), Color("bfe8ff"), 2.0)
	if float(e["bleed"]) > 0.0:
		draw_circle(p + Vector2(-r * 0.5, r * 0.6 + fmod(g.anim_t * 25.0, 8.0)), 2.5, Color("ff3a5a"))
	if float(e["wet"]) > 0.0:
		draw_circle(p + Vector2(r * 0.4, -r * 0.9 + fmod(g.anim_t * 18.0, 12.0)), 2.5, Color("6bb8ff"))
	if float(e["mark"]) > 0.0:
		draw_arc(p, r + 6, g.anim_t * 2.0, g.anim_t * 2.0 + TAU * 0.8, 16, Color("ff5a5a"), 2.0)
	if float(e["stun"]) > 0.0 and float(e["frozen"]) <= 0.0:
		for k in range(3):
			var sp2 = p + Vector2.from_angle(g.anim_t * 6.0 + k * TAU / 3.0) * Vector2(r * 0.9, r * 0.3) + Vector2(0, -r - 6)
			draw_circle(sp2, 3.0, Color("fff27a"))
	if float(e["bubble"]) > 0.0:
		draw_circle(p, r + 10, Color(0.6, 0.9, 1.0, 0.18))
		draw_arc(p, r + 10, 0, TAU, 24, Color(0.85, 0.97, 1.0, 0.8), 2.0)
		draw_circle(p + Vector2(-r * 0.5, -r * 0.6), 4, Color(1, 1, 1, 0.8))

func paint_hero() -> void:
	var h = g.hero
	var hp: Vector2 = h["pos"]
	trail.push_front(hp)
	if trail.size() > 8:
		trail.pop_back()
	var dashing = float(h["dash_t"]) > 0.0
	if dashing or float(h["dash_window"]) > 0.15:
		for i in range(1, trail.size()):
			draw_circle(P(trail[i]), 12.0 * (1.0 - i / 8.0), Color(0.4, 0.9, 1.0, 0.35 * (1.0 - i / 8.0)))
	var p = P(hp)
	var scale = 0.75 if g.st("tiny") > 0 else 1.25
	# Ground ring so you can always find yourself in a crowd.
	var ring_a = 0.55 + 0.2 * sin(g.anim_t * 5.0)
	draw_set_transform(p + Vector2(0, 10 * scale), 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, 26.0 * scale, 0, TAU, 32, Color(0.35, 1.0, 0.9, ring_a), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var aim: Vector2 = h["aim"]
	var blink = float(h["iframe"]) > 0.0 and fmod(g.anim_t * 20.0, 1.0) < 0.4 and not dashing
	# Orbit blades behind/around hero
	paint_orbitals()
	draw_set_transform(p + Vector2(0, 12 * scale), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 14.0 * scale, Color(0, 0, 0, 0.4))
	draw_set_transform(p, 0.0, Vector2.ONE * scale)
	var facing_back = aim.y < -0.38
	var facing_side = absf(aim.x) > 0.55
	var side = aim.orthogonal().normalized()
	var step = sin(g.anim_t * 13.0) * (3.0 if bool(h["moving"]) else 0.0)
	# Character colors carry through to the playable hero, not just the select screen.
	var character_colors = {
		"scout": ["9a5c35", "e83f50", "8e552f"],
		"ember": ["a64b32", "ff933c", "81362a"],
		"ace": ["755d4c", "ffd080", "9b7542"],
		"vector": ["28675f", "71deb1", "24584d"],
		"coil": ["514f85", "aaa5ff", "373d77"]
	}
	var colors: Array = character_colors.get(g.selected_character, character_colors["scout"])
	var coat = Color(str(colors[0]))
	var scarf_color = Color(str(colors[1]))
	var hat_color = Color(str(colors[2]))
	if blink:
		coat.a = 0.48
	if float(h["flash"]) > 0.0:
		coat = Color("ff797c")
	# Legs alternate while running; all features use aim so the silhouette turns.
	for s in [-1.0, 1.0]:
		var foot = side * s * 7.0 - aim * (10.0 + step * s)
		draw_circle(foot, 5.8, Color("201b28"))
		draw_circle(foot + aim * 2.0, 3.8, Color("6e4530"))
	var scarf_tail = -aim * 25.0 + side * sin(g.anim_t * 11.0) * 5.0
	draw_line(-aim * 5.0, scarf_tail, Color("751f30"), 9.0)
	draw_line(-aim * 5.0, scarf_tail, scarf_color, 6.0)
	draw_circle(Vector2.ZERO, 17.0, Color("211c29"))
	draw_circle(Vector2.ZERO, 14.5, coat)
	draw_line(-side * 9.0 - aim * 4.0, side * 9.0 - aim * 4.0, Color("d7985a"), 2.0)
	for s in [-1.0, 1.0]:
		draw_circle(side * s * 13.0 + aim * 3.0, 5.3, Color("302734"))
		draw_circle(side * s * 13.0 + aim * 3.0, 3.4, coat.lightened(0.16))
	# The red neckerchief stays visible even when the back faces the camera.
	draw_arc(aim * 2.0, 12.0, aim.angle() - 1.0, aim.angle() + 1.0, 14, scarf_color.darkened(0.18), 5.0)
	var head = aim * 4.5
	draw_circle(head, 9.2, Color("322329"))
	draw_circle(head, 7.6, Color("965a37") if facing_back else Color("edb184"))
	if not facing_back:
		var eye_line = head + aim * 4.5
		if facing_side:
			draw_circle(eye_line + side * 1.0, 1.8, Color("172637"))
			draw_line(eye_line + aim * 2.0, eye_line - side * 2.0 + aim * 2.0, Color("693d32"), 1.5)
		else:
			for s in [-1.0, 1.0]:
				draw_circle(eye_line + side * s * 3.0, 1.5, Color("172637"))
			draw_line(eye_line + aim * 2.0 - side * 2.0, eye_line + aim * 2.0 + side * 2.0, Color("7c4436"), 1.5)
	# Hat brim lies across the sight line; crown and goggles move behind it.
	var hat = head - aim * 4.0
	draw_line(hat - side * 14.0, hat + side * 14.0, Color("2c2026"), 9.0)
	draw_line(hat - side * 14.0, hat + side * 14.0, hat_color, 6.0)
	draw_circle(hat - aim * 3.0, 7.0, Color("2c2026"))
	draw_circle(hat - aim * 3.0, 5.5, hat_color)
	draw_line(hat - side * 5.0 - aim * 2.0, hat + side * 5.0 - aim * 2.0, scarf_color.lightened(0.2), 2.0)
	for s in [-1.0, 1.0]:
		draw_circle(hat + side * s * 3.0 - aim * 2.0, 2.5, Color("2b2631"))
		draw_circle(hat + side * s * 3.0 - aim * 2.0, 1.6, Color("a6e1e9"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Visible melee sweep follows the MC's aim, fading after the hit frame.
	if float(h.get("bash_t", 0.0)) > 0.0:
		var phase = 1.0 - clampf(float(h["bash_t"]) / 0.23, 0.0, 1.0)
		var dir: Vector2 = h.get("bash_dir", aim)
		var ang = dir.angle()
		var half = deg_to_rad(72.0)
		var swing = ang - half + phase * half * 1.0
		for radius in [56.0, 77.0, 90.0]:
			draw_arc(p, radius, swing, swing + half, 20, Color(1.0, 0.96, 0.65, 0.7 * (1.0 - phase)), 8.0 if radius == 77.0 else 3.0)
		draw_line(p + dir * 17.0, p + dir.rotated(-0.28 + phase * 0.56) * 68.0, Color("fff5c2", 0.72 * (1.0 - phase)), 8.0)
	# Mirrored L / reverse-L supporting arms behind the weapon art.
	# The real barrel origin is unchanged, so the pose never spoils cursor aim.
	for i in range(g.guns.size()):
		var grip: Vector2 = Weapons.hand_pos(g, i)
		var arm: PackedVector2Array = WeaponAim.arm_pose(hp, aim, i, grip)
		for joint in range(arm.size() - 1):
			var start = P(arm[joint])
			var finish = P(arm[joint + 1])
			draw_line(start, finish, Color("251d2a"), 11.0, true)
			draw_line(start, finish, Color("9a603d") if not blink else Color("db876d", 0.5), 7.0, true)
		var wrist = P(arm[arm.size() - 1])
		draw_circle(wrist, 5.5, Color("261d27"))
		draw_circle(wrist, 3.8, Color("ebb27d") if not blink else Color("ebb27d", 0.55))
	# Guns in hand, using the generated weapon art.
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var gun_aim: Vector2 = Weapons.aim_for_slot(g, i)
		var muzzle = P(Weapons.muzzle_pos(g, i))
		var t = g.tex("res://assets/weapons/%s.png" % w["id"])
		var flip = WeaponAim.mirrored_grip(gun_aim, i)
		var ang = WeaponAim.art_rotation_for_mirror(gun_aim, str(w["id"]), flip)
		var kick = -gun_aim * (5.0 if float(w["flash"]) > 0.0 else 0.0)
		var anchor = WeaponAim.sprite_anchor(muzzle, gun_aim)
		draw_set_transform(anchor + kick, ang, Vector2(1.0, -1.0 if flip else 1.0))
		if t != null:
			draw_texture_rect(t, Rect2(-16, -18, 40, 40), false, Color("ffe9a0") if bool(w["evolved"]) else Color.WHITE)
		else:
			draw_rect(Rect2(-4, -4, 22, 8), Color(str(g.weapon_db[w["id"]]["color"])))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if float(w["flash"]) > 0.0:
			var tip = muzzle
			draw_circle(tip, 9.0, Color(1, 0.95, 0.6, 0.8))
			draw_circle(tip, 5.0, Color.WHITE)
		if g.weapon_db[w["id"]]["kind"] == "rail" and float(w["charge"]) > 0.0:
			draw_arc(muzzle, 6.0 + float(w["charge"]) * 10.0, 0, TAU, 16, Color(0.6, 0.9, 1.0, float(w["charge"])), 2.0)
	# shield charges & reload rings
	var sh = int(h["shield"])
	if sh > 0:
		draw_arc(p, 22.0 * scale, 0, TAU, 32, Color(0.55, 0.97, 1.0, 0.6), 2.5)
	for i in range(g.guns.size()):
		var w2 = g.guns[i]
		if float(w2["reload"]) > 0.0:
			var k = 1.0 - float(w2["reload"]) / maxf(0.01, float(w2["reload_max"]))
			draw_arc(p + Vector2(0, 30 + i * 9), 7, -PI * 0.5, -PI * 0.5 + TAU * k, 16, Color("ffd24d"), 3.0)
	if g.state == "playing" and g.settings["aim"] == "mouse" and g.autotest == "" and g.dying_t <= 0.0:
		var m = g.aim_screen
		var k = 13.0 * float(g.settings.get("cursor", 1.0))
		var w = maxf(2.0, k * 0.17)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(m + d * k * 0.45 + Vector2(1, 1), m + d * k * 1.15 + Vector2(1, 1), Color(0, 0, 0, 0.6), w + 1.0)
			draw_line(m + d * k * 0.45, m + d * k * 1.15, Color("5ef6ff"), w)
		draw_rect(Rect2(m - Vector2(1.5, 1.5), Vector2(3, 3)), Color("ff4655"))

func paint_orbitals() -> void:
	var n = int(g.st("orbit")) + g.temp_orbitals.size()
	var hp: Vector2 = g.hero["pos"]
	if n > 0:
		var radius = 74.0 * (1.0 + g.st("orbitr"))
		for i in range(n):
			var bp = P(hp + Vector2.from_angle(g.orbit_angle + i * TAU / n) * radius)
			saw_blade(bp, 13.0, g.anim_t * 18.0, Color("e8e8f0") if i < int(g.st("orbit")) else Color("ffd24d"))
	var m = int(g.st("orbshield"))
	for i in range(m):
		var sp = P(hp + Vector2.from_angle(-g.orbit_angle * 1.3 + i * TAU / m) * 44.0)
		draw_circle(sp, 9, Color(0.55, 0.97, 1.0, 0.3))
		draw_circle(sp, 6, Color("bffaff"))

func saw_blade(p: Vector2, r: float, rot: float, c: Color) -> void:
	var pts = PackedVector2Array()
	for k in range(16):
		var rr = r if k % 2 == 0 else r * 0.68
		pts.append(p + Vector2.from_angle(rot + k * TAU / 16.0) * rr)
	draw_colored_polygon(pts, c)
	draw_circle(p, r * 0.35, Color("404858"))

func paint_pets() -> void:
	for t in g.turrets:
		var p = P(t["pos"])
		var a: Vector2 = t["aim"]
		var side = a.orthogonal()
		draw_circle(p + Vector2(0, 4), 15, Color(0, 0, 0, 0.3))
		for s in [-1.0, 1.0]:
			draw_line(p + side * s * 8.0, p + side * s * 12.0 + Vector2(0, 9), Color("65758e"), 3.0)
		draw_circle(p, 12, Color("28364f"))
		draw_circle(p, 9, Color("5b7190"))
		draw_line(p + a * 2.0, p + a * 19.0, Color("263243"), 9.0)
		draw_line(p + a * 3.0, p + a * 18.0, Color("a8d8e8"), 5.0)
		draw_circle(p, 4, Color("4fe0ff"))
		draw_arc(p, 16, -PI * 0.5, -PI * 0.5 + TAU * float(t["t"]) / 8.0, 20, Color(0.3, 0.9, 1.0, 0.5), 2.0)
	for pet in g.pets:
		var p = P(pet["pos"])
		if p.y < g.view_top - 50.0 or p.y > g.view_bottom + 50.0:
			continue
		match pet["kind"]:
			"ghost":
				# Transparent ally follows close to the player; it is not a mirror shot.
				var bob = sin(g.anim_t * 4.0 + float(pet["slot"])) * 3.0
				var aim: Vector2 = pet.get("aim", Vector2.UP)
				var cp = p + Vector2(0, bob)
				draw_circle(cp + Vector2(0, 4), 14.0, Color("cbb8ff", 0.13))
				draw_circle(cp, 12.0, Color("b6a1ff", 0.21))
				draw_circle(cp + Vector2(0, -2), 9.0, Color("e0d4ff", 0.51))
				for side in [-1.0, 1.0]:
					draw_circle(cp + Vector2(side * 3.3, -3) + aim * 1.5, 1.7, Color("412f62", 0.88))
				draw_line(cp + aim * 5.0, cp + aim * 18.0, Color("ddcaff", 0.72), 3.0)
				draw_arc(cp, 15.0, g.anim_t * 2.0, g.anim_t * 2.0 + PI, 15, Color("d8c8ff", 0.35), 1.5)
			"drone":
				var bob = sin(g.anim_t * 8.0 + float(pet["slot"])) * 3.0
				p.y += bob
				for s in [-1.0, 1.0]:
					draw_circle(p + Vector2(s * 12.0, -4), 5.0, Color("252b3c"))
					draw_line(p + Vector2(s * 7.0, -9), p + Vector2(s * 17.0, -9), Color("b8d9e8"), 2.0)
				draw_rect(Rect2(p - Vector2(9, 6), Vector2(18, 12)), Color("405070") if g.st("dronerocket") <= 0 else Color("704040"))
				draw_circle(p, 4.5, Color("172335"))
				draw_circle(p, 2.5, Color("4fe0ff"))
			"intern":
				var a: Vector2 = pet.get("aim", Vector2.UP)
				var side = a.orthogonal().normalized()
				var stride = sin(g.anim_t * 12.0 + float(pet["slot"])) * 2.0
				for s in [-1.0, 1.0]:
					draw_circle(p - a * (8.0 + stride * s) + side * s * 4.0, 3.0, Color("27304a"))
				draw_circle(p, 9.5, Color("1f2c47"))
				draw_circle(p, 7.5, Color("7397c2"))
				draw_line(p - side * 5.0, p + side * 5.0, Color("e5eff8"), 2.0)
				draw_circle(p + a * 5.0, 6.5, Color("402d35"))
				draw_circle(p + a * 5.0, 5.4, Color("ffd0aa"))
				var eyes = p + a * 8.0
				if a.y > -0.35:
					for s in [-1.0, 1.0]:
						draw_circle(eyes + side * s * 2.3, 1.1, Color("202535"))
					draw_arc(p + a * 5.0, 3.2, 3.5, 5.8, 8, Color("5f383d"), 1.2)
				else:
					draw_arc(p + a * 5.0, 4.2, PI, TAU, 8, Color("302b3a"), 2.0)
				draw_circle(p - side * 4.0 - a * 1.0, 2.2, Color("ffe5d2"))
				draw_circle(p + side * 4.0 - a * 1.0, 2.2, Color("ffe5d2"))
				draw_line(p + a * 3.0, p + a * 16.0, Color("273a41"), 5.0)
				draw_line(p + a * 4.0, p + a * 17.0, Color("9dff9a"), 2.5)
				draw_circle(p + side * 7.0 + a * 7.0 - Vector2(0, fmod(g.anim_t * 5.0, 3.0)), 1.8, Color("9fe8ff"))
			"chicken":
				var hop = absf(sin(g.anim_t * 9.0)) * 4.0
				draw_circle(p + Vector2(-5, -hop - 1), 5.0, Color("e9d9b6"))
				draw_circle(p + Vector2(0, -hop), 9, Color("fff8e0"))
				draw_circle(p + Vector2(-2, -hop + 2), 5.0, Color("e7e1d0"))
				draw_circle(p + Vector2(5, -hop - 6), 5, Color("fff8e0"))
				draw_circle(p + Vector2(5, -hop - 11), 3, Color("ff3a3a"))
				draw_circle(p + Vector2(2, -hop - 11), 2.3, Color("dd263b"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(9, -hop - 7), p + Vector2(14, -hop - 5), p + Vector2(9, -hop - 4)]), Color("ffb020"))
				draw_circle(p + Vector2(6, -hop - 7), 1.2, Color.BLACK)
				for s in [-1.0, 1.0]:
					draw_line(p + Vector2(s * 4.0, 7 - hop), p + Vector2(s * 4.0, 12 - hop), Color("e89b32"), 1.5)
			"dog":
				draw_circle(p, 10, Color("82512e"))
				draw_circle(p + Vector2(0, -2), 8.5, Color("c88a4a"))
				draw_circle(p + Vector2(1, 1), 4.5, Color("e2ae6c"))
				draw_circle(p + Vector2(8, -6), 7, Color("c88a4a"))
				draw_circle(p + Vector2(4, -11), 4, Color("654027"))
				draw_circle(p + Vector2(11, -11), 3, Color("654027"))
				draw_circle(p + Vector2(12, -5), 2, Color.BLACK)
				draw_circle(p + Vector2(8, -7), 1.4, Color("28232d"))
				draw_arc(p + Vector2(8, -3), 3, 0.1, PI - 0.1, 8, Color("56372c"), 1.5)
				draw_line(p + Vector2(-9, -2), p + Vector2(-15, -8 + sin(g.anim_t * 20.0) * 3), Color("c88a4a"), 3.0)
			"saw":
				saw_blade(p, 15.0, g.anim_t * 20.0, Color("d8dce8"))
			"decoy":
				var pulse = 0.5 + 0.3 * sin(g.anim_t * 20.0)
				draw_circle(p, 16, Color(0.7, 0.5, 1.0, pulse * 0.35))
				draw_circle(p, 12, Color("37254f"))
				draw_circle(p + Vector2(0, -1), 9, Color("b48cff"))
				for s in [-1.0, 1.0]:
					draw_circle(p + Vector2(s * 3.0, -2), 1.8, Color("241536"))
				draw_arc(p + Vector2(0, 2), 3.0, 0.2, PI - 0.2, 8, Color("4a265f"), 1.6)
				text_c("!", p + Vector2(0, -18), 17, Color("ffd24d"), 3)

# ================================================================= shots
## Fast GPU-free streaks. No extra Nodes or particle emitters per shot.
## Every projectile remains readable without this optional cosmetic layer.
func paint_projectile_travel(s: Dictionary, p: Vector2, direction: Vector2) -> void:
	var style = str(s.get("vfx_style", "kinetic"))
	var pattern = str(s.get("vfx_pattern", ""))
	var color: Color = s["color"]
	var q = str(g.settings.get("vfx_quality", "medium"))
	var radius = clampf(float(s["r"]), 2.5, 12.0)
	var length = clampf(float(s["vel"].length()) * 0.033, 9.0, 39.0)
	var side = direction.orthogonal()
	var t = g.anim_t
	if q == "low":
		length *= 0.8
	# Physics-generated parallel shots get TWO ruled lanes, never a wide cone.
	if pattern == "parallel":
		for signum in [-1.0, 1.0]:
			var lane = p + side * signum * 3.3
			draw_line(lane - direction * length, lane, Color(color, 0.65), 1.6)
	elif pattern in ["double_tap", "burst"]:
		draw_line(p - direction * length * 1.1 + side * 3.3, p - direction * 3.0 + side * 3.3, Color("fff1b6", 0.55), 1.6)
		draw_line(p - direction * length * 0.75 - side * 3.3, p - direction * 2.0 - side * 3.3, Color(color, 0.65), 1.5)
	match style:
		"fire":
			draw_line(p - direction * length, p, Color("ff4e20", 0.25), radius * 2.0)
			draw_line(p - direction * length * 0.7, p, Color("ffba55", 0.72), radius * 0.75)
			if q != "low":
				for i in range(2):
					var jitter = sin(t * 23.0 + float(i) * 3.3 + float(s["phase"])) * (4.0 + i * 2.0)
					draw_circle(p - direction * (8.0 + i * 11.0) + side * jitter, 1.7 + i * 0.3, Color("ffb264", 0.65))
		"toxic":
			draw_line(p - direction * length, p, Color("5fbb4a", 0.28), radius * 1.5)
			draw_line(p - direction * length * 0.57, p, Color("b7ff72", 0.8), 2.5)
			if q != "low":
				for i in range(2):
					var wobble = sin(t * 11.0 + float(i) * 1.9 + float(s["phase"])) * 5.0
					draw_circle(p - direction * (9.0 + i * 12.0) + side * wobble, 2.2, Color("c0ff80", 0.62))
		"frost", "boss_frost":
			draw_line(p - direction * length, p, Color("62aeea", 0.3), radius * 1.6)
			var diamond = PackedVector2Array([p + direction * 5.0, p + side * 4.0, p - direction * 10.0, p - side * 4.0])
			draw_colored_polygon(diamond, Color("c5faff", 0.84))
			draw_line(p - direction * 13.0 + side * 3.0, p - direction * 19.0 - side * 2.0, Color.WHITE, 1.5)
		"shock", "boss_storm":
			var jitter = sin(t * 38.0 + float(s["phase"])) * 4.0
			draw_line(p - direction * length, p - direction * length * 0.5 + side * jitter, Color("69bfff", 0.75), 2.0)
			draw_line(p - direction * length * 0.5 + side * jitter, p, Color("eafcff", 0.9), 2.0)
			draw_circle(p, 3.5, Color("f4fdff", 0.9))
		"blast", "boss_ember":
			draw_line(p - direction * length * 0.9, p, Color("ff6c29", 0.5), radius * 1.5)
			draw_line(p - direction * length * 0.46, p, Color("ffe09d", 0.85), radius * 0.65)
			if q != "low":
				draw_circle(p - direction * 10.0 + side * sin(t * 18.0 + float(s["phase"])) * 3.0, 2.3, Color("ffad53", 0.72))
		"boss_void", "magic":
			draw_line(p - direction * length, p, Color("a873ff", 0.36), radius * 1.5)
			draw_arc(p, radius + 4.0, t * 3.0, t * 3.0 + PI * 1.4, 13, Color("e7b4ff", 0.72), 1.6)
			draw_circle(p, radius * 0.4, Color("ffe0ff", 0.9))
		"pierce":
			draw_line(p - direction * length * 1.3, p + direction * 4.0, Color("8c74e8", 0.22), radius * 1.2)
			draw_line(p - direction * length * 1.15, p + direction * 4.0, Color("f5eaff", 0.88), 2.2)
		"shard":
			var shard = PackedVector2Array([p + direction * 7.0, p + side * 3.0, p - direction * 8.0, p - side * 3.0])
			draw_colored_polygon(shard, Color("c4ffe4", 0.78))
			draw_line(p - direction * length, p - direction * 8.0, Color("80eab5", 0.45), 1.7)
		"ricochet":
			draw_line(p - direction * length * 0.8, p, Color("ffd879", 0.65), 2.4)
			draw_circle(p, radius * 0.7, Color("fff3ad", 0.42))
		"heavy":
			draw_line(p - direction * length * 0.7, p, Color("ffa34e", 0.27), radius * 1.5)
			draw_line(p - direction * length * 0.48, p, Color("ffe4a1", 0.82), 3.2)
		"rapid":
			draw_line(p - direction * length * 0.6, p, Color("64ccff", 0.52), 2.6)
			draw_line(p - direction * length * 0.24, p, Color("e8ffff", 0.86), 1.4)
		"water":
			draw_line(p - direction * length * 0.5, p, Color("7de8ff", 0.36), 2.2)
			draw_arc(p, radius + 2.0, t, t + PI * 1.4, 12, Color("c9ffff", 0.45), 1.4)
		_:
			draw_line(p - direction * length * 0.67, p, Color(color, 0.52), 2.4)


func paint_shots() -> void:
	var shot_count = g.shots.size()
	var trail_stride = 1 if shot_count < 140 else (2 if shot_count < 280 else 3)
	if str(g.settings.get("vfx_quality", "medium")) == "low":
		trail_stride *= 2
	for shot_index in range(shot_count):
		var s = g.shots[shot_index]
		var p = P(s["pos"])
		if p.y < g.view_top - 40.0 or p.y > g.view_bottom + 40.0:
			continue
		var c: Color = s["color"]
		# Less visual clutter in bullet-heavy builds; enemy warning shots remain strong.
		if bool(s["friendly"]):
			c.a *= 0.62
		var r = float(s["r"])
		var v: Vector2 = s["vel"]
		var d = v.normalized() if v.length() > 1 else Vector2.UP
		if shot_index % trail_stride == 0 and ((bool(s["friendly"]) and bool(g.settings.get("particles", true))) or str(s.get("vfx_style", "")) in ["boss_ember", "boss_void", "boss_frost", "boss_storm"]):
			paint_projectile_travel(s, p, d)
		match s["kind"]:
			"bossbullet":
				paint_boss_bullet(s, p, d, r)
			"enemy":
				var enemy_color: Color = s["color"]
				draw_circle(p, r + 5, Color(enemy_color, 0.25))
				draw_circle(p, r, enemy_color)
				draw_circle(p, r * 0.46, Color("fff7ec"))
				if str(s.get("vfx_style", "")).begins_with("boss_"):
					var pulse = 0.55 + 0.45 * sin(g.anim_t * 12.0 + float(s["phase"]))
					draw_arc(p, r + 5.5 + pulse * 2.0, g.anim_t * 2.0, g.anim_t * 2.0 + PI * 1.3, 16, Color(enemy_color, 0.8), 2.1)
					for j in range(3):
						var a = g.anim_t * 2.8 + float(j) * TAU / 3.0
						draw_circle(p + Vector2.from_angle(a) * (r + 5.0), 1.8, Color("fff5e8", 0.85))
			"skull":
				draw_circle(p, r + 4, Color(0.7, 0.4, 1.0, 0.3))
				draw_circle(p, r + 1, Color("e0d8f0"))
				draw_circle(p + Vector2(-2.5, -1), 2, Color("301040"))
				draw_circle(p + Vector2(2.5, -1), 2, Color("301040"))
			"rocket":
				draw_line(p - d * 22.0, p - d * 6.0, Color(1, 0.6, 0.2, 0.7), 7.0)
				draw_line(p - d * 8.0, p + d * 8.0, Color("e8e8f0"), 8.0)
				draw_circle(p + d * 8.0, 4.0, c)
			"grenade":
				draw_circle(p, r, Color("405020"))
				draw_circle(p - Vector2(2, 2), r * 0.6, c)
			"egg":
				draw_set_transform(p, float(s["spin"]), Vector2(0.8, 1.0))
				draw_circle(Vector2.ZERO, r, Color("fff8e0"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"flame":
				var k = clampf(float(s["life"]) / maxf(0.01, float(s["max_life"])), 0.0, 1.0)
				draw_circle(p, r, Color(1.0, 0.35 + 0.4 * k, 0.1, 0.35 * k + 0.1))
				draw_circle(p, r * 0.5, Color(1.0, 0.9, 0.4, 0.5 * k))
			"disc":
				draw_circle(p, r + 3, Color(c, 0.25))
				saw_blade(p, r, float(s["spin"]), c)
			"saw":
				saw_blade(p, r, float(s["spin"]), c)
			"boomerang":
				var a = float(s["spin"])
				draw_line(p, p + Vector2.from_angle(a) * r * 1.2, c, 6.0)
				draw_line(p, p + Vector2.from_angle(a + 1.9) * r * 1.2, c, 6.0)
			"bee":
				# Swarmcaster's actors are BEES: a striped golden abdomen,
				# round head, two fluttering transparent wings and a stinger.
				# Facing follows the velocity, not a generic alien orb.
				var bee_scale = clampf(r / 4.0, 0.95, 1.5)
				var flap = 0.65 + 0.35 * absf(sin(g.anim_t * 58.0 + float(s["phase"])))
				draw_set_transform(p, d.angle(), Vector2.ONE * bee_scale)
				# The wings sit BEHIND the body so the yellow/black stripes
				# remain legible even in a dense swarm.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-4.0, -1.8), Vector2(-9.0, -6.0 * flap),
					Vector2(-6.0, -9.0 * flap), Vector2(0.3, -3.0)]),
					Color("d8f5ff", 0.72))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-4.0, 1.8), Vector2(-9.0, 6.0 * flap),
					Vector2(-6.0, 9.0 * flap), Vector2(0.3, 3.0)]),
					Color("d8f5ff", 0.72))
				# Pointed abdomen with two distinct thick black stripes.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-11.0, 0.0), Vector2(-7.6, -4.3),
					Vector2(-1.5, -5.0), Vector2(3.8, -3.5),
					Vector2(4.7, 0.0), Vector2(3.8, 3.5),
					Vector2(-1.5, 5.0), Vector2(-7.6, 4.3)]),
					Color("251b11"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-9.0, 0.0), Vector2(-6.0, -3.6),
					Vector2(-1.5, -4.0), Vector2(3.0, -2.8),
					Vector2(3.5, 0.0), Vector2(3.0, 2.8),
					Vector2(-1.5, 4.0), Vector2(-6.0, 3.6)]),
					Color("ffd43f"))
				draw_line(Vector2(-4.8, -3.5), Vector2(-4.8, 3.5), Color("21170d"), 2.2)
				draw_line(Vector2(-0.8, -3.8), Vector2(-0.8, 3.8), Color("21170d"), 2.2)
				# Small head, eyes, antennae and the pointed tail.
				draw_circle(Vector2(5.6, 0.0), 3.5, Color("281e10"))
				draw_circle(Vector2(5.6, 0.0), 2.8, Color("ffe26c"))
				draw_circle(Vector2(7.3, -1.3), 1.1, Color("151515"))
				draw_line(Vector2(6.4, -2.5), Vector2(7.8, -5.0), Color("2c2014"), 1.0)
				draw_line(Vector2(6.1, 2.7), Vector2(7.3, 5.0), Color("2c2014"), 1.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10.0, -1.5), Vector2(-14.0, 0.0),
					Vector2(-10.0, 1.5)]), Color("27211a"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ball":
				draw_circle(p, r, Color("3a2a5a"))
				draw_circle(p, r - 2, Color("6a4aa0"))
				for k in range(3):
					draw_circle(p + Vector2.from_angle(float(s["spin"]) * 0.3 + k * 0.6) * r * 0.45, 2.5, Color("1a1028"))
			"chicken":
				draw_set_transform(p, float(s["spin"]) * 0.6, Vector2.ONE)
				draw_circle(Vector2.ZERO, r, Color("fff27a"))
				draw_circle(Vector2(r * 0.6, -r * 0.5), r * 0.5, Color("fff27a"))
				draw_circle(Vector2(r * 0.6, -r * 1.0), r * 0.3, Color("ff3a3a"))
				draw_colored_polygon(PackedVector2Array([Vector2(r, -r * 0.5), Vector2(r * 1.6, -r * 0.3), Vector2(r, -r * 0.2)]), Color("ffa020"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bubble":
				draw_circle(p, r, Color(0.6, 0.9, 1.0, 0.15))
				draw_arc(p, r, 0, TAU, 20, Color(0.85, 0.97, 1.0, 0.85), 2.0)
				draw_circle(p + Vector2(-r * 0.4, -r * 0.4), r * 0.2, Color(1, 1, 1, 0.8))
			"snow":
				draw_circle(p, r + 2, Color(0.8, 0.95, 1.0, 0.3))
				draw_circle(p, r, Color("f0faff"))
				draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color.WHITE)
			"coin":
				var wx = absf(cos(float(s["spin"])))
				draw_set_transform(p, 0.0, Vector2(maxf(0.2, wx), 1.0))
				draw_circle(Vector2.ZERO, r, Color("ffd24d"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_line(p - d * 14.0, p, Color(1, 0.85, 0.3, 0.4), 3.0)
			"car":
				var flip = -1.0 if v.x < 0 else 1.0
				draw_rect(Rect2(p.x - 34, p.y - 16, 68, 26), Color("ff5a8a"))
				draw_rect(Rect2(p.x - 18, p.y - 30, 34, 16), Color("ffd24d"))
				draw_circle(p + Vector2(-20, 12), 8, Color("202028"))
				draw_circle(p + Vector2(20, 12), 8, Color("202028"))
				draw_circle(p + Vector2(4 * flip, -24), 6, Color("fff0e0"))
				draw_circle(p + Vector2(8 * flip, -22), 3, Color("ff3a3a"))
				draw_circle(p + Vector2(36 * flip, -6), 5, Color("fff27a"))
			_:
				var tail = p - d * (10.0 + r * 2.5)
				if shot_index % trail_stride == 0:
					draw_line(tail, p, Color(c, 0.26), r * 1.6)
				# Batch all common bullets using the existing white-dot atlas,
				# letting CanvasItem group matching sprites into GPU draws.
				if atlas != null and atlas_cell.has("#dot"):
					var dot_rect: Rect2 = atlas_cell["#dot"]
					dot_rect = Rect2(dot_rect.position + Vector2(60, 60), Vector2(80, 80))
					var tint = Color(1.0, 1.0, 1.0, 0.7) if s["flags"].has("big") else c.lightened(0.3)
					draw_texture_rect_region(atlas, Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), dot_rect, tint)
				else:
					draw_circle(p, r, Color(1.0, 1.0, 1.0, 0.7) if s["flags"].has("big") else c.lightened(0.3))

## Danmaku-style boss bullets: dark rim for contrast on any ground, a bright
## body and a white core. The drawn size is a little larger than the hitbox.
func paint_boss_bullet(s: Dictionary, p: Vector2, d: Vector2, r: float) -> void:
	var col: Color = s["color"]
	var vr := r * 1.3
	match str(s.get("shape", "orb")):
		"rice":
			draw_set_transform(p, d.angle(), Vector2(1.9, 0.85))
			draw_circle(Vector2.ZERO, vr + 1.8, Color(0.05, 0.02, 0.06, 0.75))
			draw_circle(Vector2.ZERO, vr, col)
			draw_circle(Vector2.ZERO, vr * 0.5, Color("fffaf0"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shard":
			var f := d * vr * 1.8
			var n := d.orthogonal() * vr * 0.85
			var pts := PackedVector2Array([p + f, p + n, p - f * 0.7, p - n])
			draw_colored_polygon(pts, col)
			pts.append(p + f)
			draw_polyline(pts, Color(0.05, 0.02, 0.06, 0.8), 1.8, true)
			draw_line(p - f * 0.3, p + f * 0.6, Color("ffffff", 0.9), 1.5)
		"skull":
			draw_circle(p, vr + 4.0, Color(col, 0.22))
			draw_circle(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			draw_circle(p, vr, Color("efe8f6"))
			draw_circle(p + Vector2(-vr * 0.38, -vr * 0.1), vr * 0.28, col.darkened(0.5))
			draw_circle(p + Vector2(vr * 0.38, -vr * 0.1), vr * 0.28, col.darkened(0.5))
		"big":
			draw_circle(p, vr + 7.0, Color(col, 0.18))
			draw_circle(p, vr + 2.2, Color(0.05, 0.02, 0.06, 0.8))
			draw_circle(p, vr, col)
			draw_circle(p + Vector2(-vr * 0.2, -vr * 0.2), vr * 0.5, Color(col.lightened(0.55)))
			draw_circle(p + Vector2(-vr * 0.35, -vr * 0.35), vr * 0.18, Color(1, 1, 1, 0.9))
		"flame":
			var flick := 0.8 + 0.2 * sin(float(s["t"]) * 40.0 + float(s["phase"]))
			draw_circle(p, vr * 1.5 * flick, Color(col, 0.25))
			draw_circle(p, vr * flick, col)
			draw_circle(p, vr * 0.45, Color("fff6c8"))
		"missile":
			draw_line(p - d * 26.0, p - d * 8.0, Color(1.0, 0.65, 0.25, 0.75), 7.0)
			draw_line(p - d * 10.0, p + d * 10.0, Color(0.05, 0.02, 0.06), 11.0)
			draw_line(p - d * 9.0, p + d * 9.0, Color("dfe2ea"), 7.0)
			draw_circle(p + d * 9.0, 4.0, Color("ff4d4d"))
		"boulder":
			var spin_b := float(s["t"]) * 7.0 * signf(Vector2(s["vel"]).x)
			draw_circle(p, vr + 2.5, Color(0.05, 0.02, 0.06, 0.85))
			draw_circle(p, vr, Color("8a6648"))
			for i in range(3):
				var q := p + Vector2.from_angle(spin_b + TAU * float(i) / 3.0) * vr * 0.5
				draw_circle(q, vr * 0.22, Color("6b4a33"))
			draw_circle(p + Vector2(-vr * 0.3, -vr * 0.35), vr * 0.25, Color(1, 1, 1, 0.18))
		"gear":
			draw_circle(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			draw_colored_polygon(BossModels.gear_pts(p, vr * 1.15, 6, float(s["spin"])), col)
			draw_circle(p, vr * 0.4, Color("fff1d6"))
		_:
			draw_circle(p, vr + 4.0, Color(col, 0.2))
			draw_circle(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			draw_circle(p, vr, col)
			draw_circle(p, vr * 0.5, Color("fffaf0"))

func zigzag(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var pts = PackedVector2Array([a])
	var n = maxi(3, int(a.distance_to(b) / 18.0))
	var perp = (b - a).normalized().orthogonal()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + perp * randf_range(-7, 7))
	pts.append(b)
	draw_polyline(pts, Color(c, 0.35), w * 3.0)
	draw_polyline(pts, c, w)

func paint_beams() -> void:
	for b in g.beams:
		var a = P(b["a"])
		var e = P(b["b"])
		var c: Color = b["color"]
		var w = float(b["w"])
		if bool(b.get("zig", false)):
			zigzag(a, e, c, w)
		elif bool(b.get("rail", false)):
			var k = clampf(float(b["t"]) / 0.22, 0.0, 1.0)
			draw_line(a, e, Color(c, 0.3 * k), w * 3.0)
			draw_line(a, e, Color(c, 0.9 * k), w)
			draw_line(a, e, Color(1, 1, 1, k), w * 0.35)
		else:
			var shimmer = 0.85 + 0.15 * sin(g.anim_t * 26.0 + a.distance_to(e) * 0.03)
			draw_line(a, e, Color(c, 0.25 * shimmer), w * 2.9)
			draw_line(a, e, Color(c, 0.85 * shimmer), w * 1.1)
			draw_line(a, e, Color(1, 1, 1, 0.92 * shimmer), maxf(1.5, w * 0.36))
			draw_circle(e, w * (0.95 + 0.28 * sin(g.anim_t * 23.0)), Color(c, 0.57 * shimmer))
			draw_circle(e, maxf(1.5, w * 0.37), Color("fff8e9", 0.86 * shimmer))

## Short readable combat glyphs. A different silhouette for every semantic event.
func paint_projectile_event(f: Dictionary, p: Vector2, k: float) -> void:
	var dir: Vector2 = f.get("dir", Vector2.UP)
	var side = dir.orthogonal()
	var c: Color = f["color"]
	var style = str(f.get("style", "kinetic"))
	var event = str(f.get("event", "impact"))
	var alpha = 1.0 - k
	var r = float(f["size"]) * (0.7 + 0.7 * k)
	match event:
		"muzzle":
			draw_line(p - dir * 2.0, p + dir * r * 1.6, Color(c, 0.72 * alpha), maxf(2.0, r * 0.6))
			draw_line(p - side * r * 0.7, p + side * r * 0.7, Color("fff5d0", 0.65 * alpha), 2.0)
			draw_circle(p, maxf(2.0, r * 0.35), Color("fff8dc", alpha))
		"double_tap", "burst":
			# Two staggered mini flashes, visually different from parallel lanes.
			for i in range(2):
				var advance = 5.0 * i + k * 9.0 * i
				var center = p + dir * advance + side * (4.0 if i == 0 else -4.0)
				draw_line(center - dir * 4.0, center + dir * r * 1.7, Color(c, (0.95 - i * 0.24) * alpha), 3.6 if i == 0 else 2.6)
				draw_circle(center + dir * r, 2.8, Color("fff7db", 0.8 * alpha))
		"parallel":
			for i in [-1.0, 1.0]:
				var lane = p + side * i * 9.0
				draw_line(lane - dir * r * 0.6, lane + dir * r * (2.0 + k), Color(c, 0.82 * alpha), 3.4)
				draw_line(lane + dir * r, lane + dir * r * (2.5 + k), Color("ffffff", 0.72 * alpha), 1.4)
			draw_line(p - side * 10.0, p + side * 10.0, Color(c, 0.4 * alpha), 1.6)
		"crit":
			draw_arc(p, r * 1.5, 0, TAU, 18, Color("ffe8a5", 0.8 * alpha), 2.8)
			for j in range(8):
				var angle = float(j) * TAU / 8.0
				var ray = Vector2.from_angle(angle)
				var extent = r * (2.15 if j % 2 == 0 else 1.55)
				draw_line(p + ray * r * 0.44, p + ray * extent, Color("fff2bd", alpha), 2.6 if j % 2 == 0 else 1.5)
			draw_circle(p, r * 0.38 * alpha, Color.WHITE)
		"pierce":
			draw_line(p - dir * r * 1.2, p + dir * r * (2.2 + k), Color(c, 0.7 * alpha), 3.0)
			draw_line(p + side * r * 0.8, p - side * r * 0.8, Color("ffffff", 0.9 * alpha), 1.8)
		"bounce":
			# Corner flash indicates a trajectory change rather than a kill.
			draw_line(p - dir * r, p, Color("fff3b6", alpha), 3.0)
			draw_line(p, p + side * r * 1.45, Color(c, 0.95 * alpha), 2.8)
			draw_line(p, p - side * r * 1.1, Color(c, 0.72 * alpha), 2.0)
			draw_circle(p, 2.5 * alpha, Color.WHITE)
		"split":
			draw_arc(p, r * (0.7 + k * 1.5), 0, TAU, 20, Color(c, 0.57 * alpha), 2.3)
			for j in range(5):
				var ray = dir.rotated((float(j) - 2.0) * 0.44)
				var start = p + ray * r * (0.35 + k)
				draw_line(start, start + ray * r * (1.1 + k), Color("caffea", alpha), 2.2)
				draw_circle(start + ray * r * (1.1 + k), 1.8, Color(c, alpha))
		"expire":
			draw_arc(p, r * (1.0 + 0.8 * k), 0, TAU, 12, Color(c, 0.37 * alpha), 1.5)
		"boss_impact":
			draw_circle(p, r * (0.4 + k * 0.7), Color(c, 0.22 * alpha))
			for j in range(10):
				var ray = Vector2.from_angle(float(j) * TAU / 10.0)
				draw_line(p + ray * r * 0.5, p + ray * r * (1.6 + k), Color(c, 0.78 * alpha), 2.8)
			draw_arc(p, r * (1.4 + k), 0, TAU, 22, Color("fff3ea", 0.7 * alpha), 3.0)
		_:
			draw_arc(p, r * 1.2, 0, TAU, 14, Color(c, 0.5 * alpha), 2.0)
			var rays = 6 if style in ["frost", "shock", "toxic", "blast", "boss_void"] else 4
			for j in range(rays):
				var ray = Vector2.from_angle(float(j) * TAU / rays)
				draw_line(p + ray * r * 0.4, p + ray * r * (1.5 + k), Color(c, alpha), 2.5 if style == "heavy" else 1.9)
				if style in ["frost", "shard"]:
					draw_line(p + ray * r * 1.2, p + ray.rotated(0.35) * r * 0.75, Color("e5ffff", alpha * 0.8), 1.4)
				elif style in ["shock", "boss_storm"]:
					draw_line(p + ray * r, p + ray.rotated(-0.32) * r * 1.6, Color("e4f9ff", alpha), 1.5)
				elif style == "toxic":
					draw_circle(p + ray * r * (1.3 + k), 2.2 * alpha, Color("baff75", alpha * 0.72))
				elif style in ["fire", "blast", "boss_ember"]:
					draw_circle(p + ray * r * (1.4 + k), 1.8 * alpha, Color("ffd48b", alpha * 0.9))

func paint_fx() -> void:
	for f in g.fx:
		var pos_screen = P(f["pos"])
		var margin = maxf(50.0, float(f.get("size", 6.0)) * 1.5)
		if pos_screen.y < g.view_top - margin or pos_screen.y > g.view_bottom + margin:
			continue
		var k = float(f["t"]) / maxf(0.001, float(f["life"]))
		var p = P(f["pos"])
		var c: Color = f["color"]
		match f["kind"]:
			"cinder_flame":
				# Restore Cinder's ORIGINAL moving, overlapping flame puffs.
				# Draw only: no enemy collision, no emitted bullet or cone fan.
				var fade = pow(maxf(0.0, 1.0 - k), 1.25)
				var flicker = 0.91 + 0.09 * sin(g.anim_t * 42.0 + float(f["seed"]))
				var radius = float(f["size"]) * (0.76 + k * 0.95) * flicker
				var forward = f["vel"].normalized()
				# Soft red outer flame, orange body, yellow inner core.
				draw_circle(p, radius * 1.22, Color("ed4018", 0.24 * fade))
				draw_circle(p - forward * radius * 0.28, radius * 0.93, Color("ff6e23", 0.55 * fade))
				draw_circle(p + forward * radius * 0.18, radius * 0.65, Color("ffaf31", 0.71 * fade))
				draw_circle(p + forward * radius * 0.28, radius * 0.34,
					Color("ffeb81", 0.76 * fade * (1.0 - k * 0.6)))
				if k < 0.35:
					draw_circle(p + forward * radius * 0.37, radius * 0.18,
						Color("fff8cb", 0.72 * fade))
			"projectile_vfx":
				paint_projectile_event(f, p, k)
			"spark":
				draw_circle(p, float(f["size"]) * (1.0 - k), Color(c, 1.0 - k))
			"ring":
				draw_arc(p, float(f["size"]) * (0.4 + k * 0.8), 0, TAU, 32, Color(c, 1.0 - k), 3.0)
			"blast":
				var r = float(f["size"]) * (0.5 + 0.6 * sqrt(k))
				draw_circle(p, r, Color(c, 0.35 * (1.0 - k)))
				draw_circle(p, r * 0.6 * (1.0 - k), Color(1, 0.97, 0.85, 0.8 * (1.0 - k)))
				draw_arc(p, r, 0, TAU, 40, Color(c.lightened(0.3), 1.0 - k), 4.0)
			"shock":
				draw_arc(p, float(f["size"]) * k, 0, TAU, 48, Color(c, 1.0 - k), 8.0 * (1.0 - k) + 1.0)
			"confetti":
				draw_set_transform(p, float(f["rot"]) + float(f["t"]) * 9.0, Vector2(1.0, 0.5))
				draw_rect(Rect2(-float(f["size"]), -float(f["size"]) * 0.5, float(f["size"]) * 2.0, float(f["size"])), Color(c, 1.0 - k * k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ghostflash":
				draw_circle(p, float(f["size"]) * (1.0 + k), Color(c, 0.4 * (1.0 - k)))
			"spike":
				var h = 22.0 * sin(k * PI)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 4), p + Vector2(0, 4 - h), p + Vector2(7, 4)]), Color(c, 1.0 - k * 0.5))
			"anvil_hit":
				var sq = 1.0 - k
				if bool(f.get("piano", false)):
					draw_rect(Rect2(p.x - 44, p.y - 18 * sq, 88, 24 * sq + 6), Color("181820"))
				else:
					draw_rect(Rect2(p.x - 26, p.y - 12 * sq, 52, 14 * sq + 4), Color("5a6070", 1.0 - k * 0.5))
			"jet":
				draw_colored_polygon(PackedVector2Array([p + Vector2(30, 0), p + Vector2(-20, -16), p + Vector2(-10, 0), p + Vector2(-20, 16)]), Color("c8d0e0"))
				draw_line(p + Vector2(-20, 0), p + Vector2(-120, 0), Color(1, 1, 1, 0.3), 4.0)
			"arc":
				var to = P(f["to"])
				var mid = (p + to) * 0.5 + Vector2(0, -60)
				var t = k
				var q = p.lerp(mid, t).lerp(mid.lerp(to, t), t)
				draw_circle(q, 8, Color("c87830"))
				draw_circle(q + Vector2(-2, -2), 4, Color("ffb84d"))
			"disco":
				var ball = p + Vector2(0, -float(f["size"]) * 0.6)
				draw_circle(ball, 18, Color("d0d8e8"))
				for i in range(8):
					var a = g.anim_t * 3.0 + i * TAU / 8.0
					var cc = Color.from_hsv(fmod(i / 8.0 + g.anim_t, 1.0), 0.7, 1.0, 0.25 * (1.0 - k))
					draw_line(ball, ball + Vector2.from_angle(a) * float(f["size"]), cc, 10.0)


func paint_texts() -> void:
	for t in g.texts:
		var k = float(t["t"]) / float(t["life"])
		var p = P(t["pos"])
		var size = int(t["size"])
		var pop = 1.0 + 0.5 * maxf(0.0, 1.0 - k * 6.0)
		var c: Color = t["color"]
		c.a = 1.0 - maxf(0.0, (k - 0.6) / 0.4)
		text_c(str(t["text"]), p, int(size * pop), c, 4 if bool(t.get("num", false)) else 6)
