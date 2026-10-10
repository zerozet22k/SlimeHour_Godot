extends Node2D
## World rendering. Everything is drawn in one canvas pass from the dictionaries in Main.

const Weapons = preload("res://scripts/Weapons.gd")
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
		for x in range(-lane_count, lane_count + 1):
			draw_rect(Rect2(640 + x * 195.0 - g.cam_x - 3 + shake_off.x, y, 6, 44), Color(b["lane"], 0.55))
	for k in range(6):
		var a = 0.5 * (1.0 - k / 6.0)
		draw_rect(Rect2(left - 2 + k * 2, g.view_top, 2, g.view_bottom - g.view_top), Color(b["edge"], a * 0.6))
		draw_rect(Rect2(right - k * 2, g.view_top, 2, g.view_bottom - g.view_top), Color(b["edge"], a * 0.6))
	draw_rect(Rect2(left - 10, g.view_top, 8, g.view_bottom - g.view_top), Color(b["edge"], 0.25))
	draw_rect(Rect2(right + 2, g.view_top, 8, g.view_bottom - g.view_top), Color(b["edge"], 0.25))
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
		match z["kind"]:
			"fire", "blaze":
				draw_circle(p, r, Color(1.0, 0.4, 0.1, 0.18 * fade))
				for i in range(7 if z["kind"] == "fire" else 12):
					var a = i * 2.4 + g.anim_t * 3.0
					var fp = p + Vector2.from_angle(a) * r * 0.55 * fmod(i * 0.37 + g.anim_t, 1.0)
					var h = 8.0 + 5.0 * sin(g.anim_t * 12.0 + i)
					draw_circle(fp, h, Color(1.0, 0.55 + 0.3 * sin(i + g.anim_t * 9.0), 0.1, 0.55 * fade))
			"poison":
				draw_circle(p, r, Color(0.4, 1.0, 0.3, 0.16 * fade))
				for i in range(6):
					var bp = p + Vector2.from_angle(i * 1.7 + g.anim_t) * r * 0.5
					draw_circle(bp, 5.0 + 3.0 * sin(g.anim_t * 5.0 + i), Color(0.6, 1.0, 0.4, 0.4 * fade))
			"ice":
				draw_circle(p, r, Color(0.7, 0.95, 1.0, 0.22 * fade))
				draw_arc(p, r, 0, TAU, 24, Color(0.85, 1.0, 1.0, 0.5 * fade), 2.0)
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
				zigzag(P(z["a"]), P(z["b"]), Color(0.6, 0.85, 1.0, 0.6 * fade), 3.0)

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
		match kind:
			"tree":
				draw_circle(p + Vector2(0, 12), 15, Color("533a35"))
				draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 28)), Color("876043"))
				draw_circle(p + Vector2(-10, -12), 25, Color("225c52"))
				draw_circle(p + Vector2(14, -16), 22, Color("2f8966"))
				draw_circle(p + Vector2(0, -27), 21, Color("48b879"))
				draw_circle(p + Vector2(-14, -30), 8, Color("a8ef9e", 0.45))
				draw_arc(p + Vector2(0, -17), radius, PI * 0.95, TAU * 0.95, 24, Color("78cba2"), 2.0)
			"median":
				draw_rect(Rect2(p + Vector2(-23, -33), Vector2(46, 66)), Color("37414b"))
				draw_rect(Rect2(p + Vector2(-19, -29), Vector2(38, 58)), Color("efb953"))
				for k in range(4):
					draw_line(p + Vector2(-16, -24 + k * 14), p + Vector2(16, -12 + k * 14), Color("292c3c"), 7.0)
				draw_rect(Rect2(p + Vector2(-23, -33), Vector2(46, 66)), Color("fff3b0", 0.3), false, 2.0)
			"barrier":
				draw_rect(Rect2(p + Vector2(-32, -16), Vector2(64, 32)), Color("373748"))
				draw_rect(Rect2(p + Vector2(-30, -18), Vector2(60, 27)), Color("ff9e35"))
				for k in range(3):
					var x = -23.0 + k * 21.0
					draw_colored_polygon(PackedVector2Array([p + Vector2(x, 8), p + Vector2(x + 9, 8), p + Vector2(x + 27, -17), p + Vector2(x + 18, -17)]), Color("fff6ce"))
				draw_rect(Rect2(p + Vector2(-32, -18), Vector2(64, 28)), Color("673344"), false, 3.0)
			"car":
				var car_color = Color("6c85c9") if int(absi(roundi(p.y))) % 2 == 0 else Color("c56a66")
				draw_rect(Rect2(p + Vector2(-28, -49), Vector2(56, 98)), Color("0b111f"))
				for off in [-39.0, 27.0]:
					draw_rect(Rect2(p + Vector2(-35, off), Vector2(70, 13)), Color("252b39"))
				draw_rect(Rect2(p + Vector2(-27, -45), Vector2(54, 90)), car_color)
				draw_rect(Rect2(p + Vector2(-22, -25), Vector2(44, 25)), Color("82cddd"))
				draw_rect(Rect2(p + Vector2(-22, 13), Vector2(44, 23)), Color("335c78"))
				draw_rect(Rect2(p + Vector2(-25, -42), Vector2(10, 8)), Color("ffe7b1"))
				draw_rect(Rect2(p + Vector2(15, -42), Vector2(10, 8)), Color("ffe7b1"))
				draw_rect(Rect2(p + Vector2(-25, 40), Vector2(12, 5)), Color("ff706b"))
				draw_rect(Rect2(p + Vector2(13, 40), Vector2(12, 5)), Color("ff706b"))
				draw_rect(Rect2(p + Vector2(-28, -49), Vector2(56, 98)), Color("b7d9ed", 0.6), false, 2.0)
		if float(ob.get("hp", -1.0)) > 0.0:
			var hpmax = 65.0 + g.sector * 3.0 if kind == "barrier" else 110.0 + g.sector * 5.0
			var hpfrac = clampf(float(ob["hp"]) / hpmax, 0.0, 1.0)
			if hpfrac < 0.95:
				draw_rect(Rect2(p + Vector2(-31, -58), Vector2(62, 5)), Color("211d23"))
				draw_rect(Rect2(p + Vector2(-31, -58), Vector2(62.0 * hpfrac, 5)), Color("ffae59"))

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
		var image = g.tex("res://assets/ui/barrel.svg")
		var armed = bool(b.get("armed", false))
		if image != null:
			var flash = 0.35 + 0.65 * absf(sin(g.anim_t * (12.0 + (0.85 - float(b.get("fuse", 0.85))) * 15.0))) if armed else 1.0
			draw_texture_rect(image, Rect2(p - Vector2(21, 25), Vector2(42, 50)), false, Color(1.0, flash, flash, 1.0))
		else:
			draw_rect(Rect2(p - Vector2(15, 18), Vector2(30, 36)), Color("c8301e"))
		if armed:
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
	for d in g.delayed:
		if not d.has("tele"):
			continue
		var pos: Vector2 = d["pos"]
		var tgt = d.get("enemy")
		if tgt != null and not bool(tgt["dead"]):
			pos = tgt["pos"]
		var p = P(pos)
		var life = maxf(0.01, float(d.get("life", 0.6)))
		var k = 1.0 - clampf(float(d["t"]) / life, 0.0, 1.0)
		var r = float(d["tele"])
		var warning_color = Color(str(d.get("color", "ff744e")))
		draw_circle(p, r * k, Color(warning_color, 0.12 + 0.12 * k))
		draw_arc(p, r, 0, TAU, 40, Color(warning_color, 0.85), 2.8)
		if str(d["fn"]) in ["boss_blast", "elite_boom"]:
			draw_arc(p, r * (0.35 + k * 0.65), -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color("fff1c4", 0.85), 4.0)
			for j in range(4):
				var ray = Vector2.from_angle(float(j) * PI * 0.5)
				draw_line(p + ray * (r - 16.0), p + ray * r, Color(warning_color, 0.85), 3.0)
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
			if enemy_has_role(e, "larry") or enemy_has_role(e, "lancer"):
				var lock: Vector2 = e.get("lock", g.hero["pos"])
				var dir = (lock - e["pos"]).normalized()
				var color = Color("c1c8ff") if enemy_has_role(e, "lancer") else Color("ff5a82")
				draw_line(p, p + dir * (650.0 if enemy_has_role(e, "lancer") else 900.0), Color(color, 0.25 + 0.5 * fmod(g.anim_t * 8.0, 1.0)), 3.0)
			elif e.has("tele") and (e["kind"] in ["chonkzilla", "kingblob"] or enemy_has_role(e, "chonk")):
				var at = P(e.get("lock", e["pos"])) if e["kind"] == "kingblob" else p
				draw_arc(at, float(e["tele"]), 0, TAU, 40, Color(1, 0.3, 0.3, 0.8), 3.0)
				draw_circle(at, float(e["tele"]), Color(1, 0.2, 0.2, 0.12))
			elif enemy_has_role(e, "bull") or e["kind"] in ["zoomer", "skitter"]:
				var color = Color("83eaff") if e["kind"] == "skitter" else Color(1, 0.6, 0.2)
				draw_line(p, P(g.hero["pos"]), Color(color, 0.45), 5.0)
			elif enemy_has_role(e, "blinky"):
				var dest = P(e.get("lock", g.hero["pos"]))
				draw_arc(dest, 22.0, 0, TAU, 24, Color(0.8, 0.55, 1.0, 0.5 + 0.5 * fmod(g.anim_t * 6.0, 1.0)), 3.0)
				draw_line(p, dest, Color(0.8, 0.55, 1.0, 0.25), 2.0)
			elif enemy_has_role(e, "mirror"):
				var dest = P(e.get("lock", g.hero["pos"]))
				draw_line(p, dest, Color(0.35, 0.95, 1.0, 0.5 + 0.3 * sin(g.anim_t * 16.0)), 3.0)
				draw_arc(p, 27.0, 0, TAU, 28, Color("aafaff"), 2.0)
			elif e["kind"] == "burrower":
				var dest = P(e.get("lock", g.hero["pos"]))
				draw_circle(dest, 37.0, Color(0.8, 0.6, 0.3, 0.12))
				draw_arc(dest, 37.0, 0, TAU, 36, Color("ffe2a3"), 3.5)
				draw_line(p, dest, Color(0.8, 0.6, 0.3, 0.3), 2.0)

# ================================================================= enemies
func paint_enemies() -> void:
	for e in g.enemies:
		if bool(e["dead"]):
			continue
		var p = P(e["pos"])
		var r = float(e["r"])
		if p.y < g.view_top - r - 60.0 or p.y > g.view_bottom + r + 60.0:
			continue
		draw_enemy(e, p, r)
		if enemy_has_role(e, "ashwing") and float(e.get("rebirth_t", 0.0)) > 0.0:
			var progress = 1.0 - float(e["rebirth_t"]) / 1.35
			draw_circle(p, r * (0.7 + progress * 0.35), Color(1.0, 0.35, 0.06, 0.25))
			draw_arc(p, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color("ffdf80"), 4.0)
			text_c("REBIRTHING", p + Vector2(0, -r - 32.0), 11, Color("ffdf80"), 2)
		elif enemy_has_role(e, "siren"):
			draw_arc(p, 180.0, 0, TAU, 64, Color(0.95, 0.54, 0.85, 0.22), 2.0)
		elif enemy_has_role(e, "mirror") and float(e.get("wind", 0.0)) > 0.0:
			draw_arc(p, r + 9.0, 0, TAU, 24, Color("aafaff"), 3.0)
		if e.has("affix"):
			text_c(" · ".join(e["affix"]), p + Vector2(0, -r - 20), 11, Color(1, 0.82, 0.3, 0.85), 2)
		elif e["kind"] == "totem":
			draw_arc(p, 230.0, 0, TAU, 64, Color(0.48, 0.82, 1.0, 0.25 + 0.15 * sin(g.anim_t * 3.0)), 3.0)
			text_c("SHIELDS NEARBY", p + Vector2(0, -r - 34), 13, Color("7ad1ff"), 3)

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
	# live parts: rotor, fuse spark, pupils (pupils use the atlas dot, so they stay in the same batch)
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
		# Real composite overlays on top of the baked base body: cheap GPU
		# primitives, not a giant pre-baked atlas of every possible pairing.
		var secondary = Color(str(g.enemy_db[str(parents[1])]["color"]))
		var accent = secondary.lightened(0.18)
		var variant = int(parts.get("variant", 0))
		draw_arc(p, r * 0.88, -PI * 0.72, PI * 0.65, 14, Color(secondary, 0.85), maxf(2.0, r * 0.16))
		match variant:
			0:
				# Organic split horns and offset eyes.
				for side in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([p + Vector2(side * r * 0.48, -r * 0.45),
						p + Vector2(side * r * 0.86, -r * 1.34),
						p + Vector2(side * r * 0.12, -r * 0.88)]), accent)
			1:
				# Layered shell/visor hybrid, different from both parents.
				draw_rect(Rect2(p + Vector2(-r * 0.82, -r * 0.52), Vector2(r * 1.64, r * 0.36)), Color("21304a"))
				draw_line(p + Vector2(-r * 0.65, -r * 0.34), p + Vector2(r * 0.65, -r * 0.34), accent, maxf(2.0, r * 0.15))
			2:
				# Twin lateral fins and bright secondary-color marking.
				for side in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([p + Vector2(side * r * 0.45, r * 0.05),
						p + Vector2(side * r * 1.45, -r * 0.88),
						p + Vector2(side * r * 1.06, r * 0.62)]), Color(secondary, 0.9))
			3:
				# Armored frontal crest with segmented diagonal markings.
				draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.45, -r * 0.52),
					p + Vector2(0, -r * 1.3), p + Vector2(r * 0.45, -r * 0.52)]), accent)
				draw_line(p + Vector2(-r * 0.5, r * 0.45), p + Vector2(r * 0.5, r * 0.1), secondary, maxf(2.0, r * 0.13))
		draw_circle(p + Vector2(r * 0.66, -r * 0.70), maxf(2.7, r * 0.14), accent)
	draw_status(e, p, r)

## Fallback before the atlas is baked: draw the vector art directly.
func draw_enemy_live(e: Dictionary, p: Vector2, r: float) -> void:
	var kind = str(e["kind"])
	var parts: Dictionary = g.enemy_db[kind].get("look", {})
	draw_set_transform(p + Vector2(0, r * 0.75), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.35))
	draw_set_transform(p, 0.0, Vector2.ONE)
	draw_enemy_body(self, kind, bool(e["elite"]), r, e["color"], float(e["flash"]) > 0.0)
	var look: Vector2 = e["aim"]
	var eye_r = maxf(3.5, r * 0.3)
	if str(parts.get("face", "")) != "visor":
		for ex in ([0.0] if kind == "necro" else [-0.36, 0.36]):
			draw_circle(Vector2(ex * r, -r * 0.18) + look * eye_r * 0.45, eye_r * 0.5, Color("120810"))
	else:
		draw_rect(Rect2(-r * 0.2, -r * 0.18 - 2, r * 0.4, 4), Color("ff3a5a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_status(e, p, r)

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
				draw_set_transform(p, d.angle(), Vector2.ONE)
				draw_circle(Vector2(-2, -4), 3.5, Color(1, 1, 1, 0.6))
				draw_circle(Vector2(-2, 4), 3.5, Color(1, 1, 1, 0.6))
				draw_circle(Vector2.ZERO, 4.5, Color("ffd94d"))
				draw_line(Vector2(-1, -4), Vector2(-1, 4), Color("201810"), 2.0)
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
		if bool(b.get("flame_stream", false)):
			# Flame stream is ONE GPU-friendly cone, not scores of physics bullets.
			var forward = (e - a).normalized()
			var side = forward.orthogonal()
			var fade = clampf(float(b["t"]) / 0.065, 0.0, 1.0)
			var corners = PackedVector2Array([a, e + side * w, e - side * w])
			draw_colored_polygon(corners, Color(c, 0.20 * fade))
			draw_line(a, e, Color("ffd37a", 0.26 * fade), 6.0)
			draw_arc(e, w * 0.55, forward.angle() - PI * 0.5, forward.angle() + PI * 0.5, 10, Color("ffba56", 0.42 * fade), 3.0)
		elif bool(b.get("zig", false)):
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
