extends Node2D
## World rendering. Everything is drawn in one canvas pass from the dictionaries in Main.

const Weapons = preload("res://scripts/Weapons.gd")
const Combat = preload("res://scripts/Combat.gd")
const BossFight = preload("res://scripts/BossFight.gd")
const BossModels = preload("res://scripts/BossModels.gd")
const Trails = preload("res://scripts/Trails.gd")
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
const MonsterModels = preload("res://scripts/MonsterModels.gd")
const MutationKit = preload("res://scripts/MutationKit.gd")
const MutationParts = preload("res://scripts/MutationParts.gd")
const MonsterKit = preload("res://scripts/MonsterKit.gd")
const HeroModels = preload("res://scripts/HeroModels.gd")
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
	# Light pass: drawn additively on top of the world so lasers, sparks,
	# explosion cores and bullets actually glow.
	glow = GlowLayer.new()
	glow.v = self
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	add_child(glow)

class GlowLayer extends Node2D:
	var v
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		v.paint_glow(self)
		if v.draw_prof:
			v.g.prof["d.glow"] = float(v.g.prof.get("d.glow", 0.0)) + float(Time.get_ticks_usec() - t0)

var glow: Node2D = null

func _process(_delta: float) -> void:
	if glow != null:
		glow.queue_redraw()

## Everything in here is ADDED to the colours below it: keep alphas modest.
func paint_glow(ci: CanvasItem) -> void:
	if g.hero.is_empty():
		return
	for b in g.beams:
		var a: Vector2 = P(b["a"])
		var e: Vector2 = P(b["b"])
		var c: Color = b["color"]
		var w := float(b["w"])
		var life := clampf(float(b["t"]) / 0.2, 0.0, 1.0)
		ci.draw_line(a, e, Color(c, 0.16 * life), w * 6.0)
		ci.draw_line(a, e, Color(c, 0.32 * life), w * 2.4)
		ci.draw_circle(e, w * 3.0, Color(c, 0.3 * life))
		ci.draw_circle(a, w * 2.2, Color(c, 0.25 * life))
	var bullets := 0
	for s in g.shots:
		if bool(s["friendly"]) or bullets > 260:
			continue
		var p: Vector2 = P(s["pos"])
		if p.y < g.view_top - 20.0 or p.y > g.view_bottom + 20.0:
			continue
		bullets += 1
		ci.draw_circle(p, float(s["r"]) * 2.6, Color(s["color"], 0.16))
	for f in g.fx:
		var k := float(f["t"]) / maxf(0.001, float(f["life"]))
		var fp: Vector2 = P(f["pos"])
		var c2: Color = f["color"]
		match str(f["kind"]):
			"blast":
				var r := float(f["size"])
				var flash := maxf(0.0, 1.0 - k * 3.0)
				ci.draw_circle(fp, r * (0.7 + 0.5 * k), Color(c2, 0.28 * (1.0 - k)))
				ci.draw_circle(fp, r * 0.55, Color(1.0, 0.95, 0.8, 0.55 * flash))
			"spark":
				ci.draw_circle(fp, float(f["size"]) * 2.2 * (1.0 - k), Color(c2, 0.35 * (1.0 - k)))
			"ring":
				ci.draw_arc(fp, float(f["size"]) * (0.4 + ease_out(k) * 0.8), 0.0, TAU, 40, Color(c2, 0.35 * (1.0 - k)), 10.0 * (1.0 - k) + 2.0, true)
			"slash":
				paint_slash(ci, f, fp, k, true)
			"cinder_flame":
				ci.draw_circle(fp, float(f["size"]) * 1.3, Color(1.0, 0.45, 0.1, 0.16 * (1.0 - k)))
	for z in g.zones:
		if str(z["kind"]) in ["fire", "blaze"] and not z.has("pts"):
			ci.draw_circle(P(z["pos"]), float(z["r"]) * 0.9, Color(1.0, 0.45, 0.1, 0.10))
	for e2 in g.enemies:
		if enemy_has_role(e2, "leech") and float(e2.get("tether_t", 0.0)) > 0.0:
			ci.draw_line(P(e2["pos"]), P(g.hero["pos"]), Color(1.0, 0.15, 0.35, 0.18), 14.0)

static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)

## A crescent slash: the arc of a sweeping blade, sharp on the leading edge.
func paint_slash(ci: CanvasItem, f: Dictionary, p: Vector2, k: float, glow_pass: bool) -> void:
	var dir := float(f["dir"])
	var r := float(f["size"])
	var half := float(f.get("arc", 1.1))
	var sweep := ease_out(minf(1.0, k * 2.2))
	if sweep < 0.06:
		return
	var fade := 1.0 - k
	var c: Color = f["color"]
	var pts := PackedVector2Array()
	var start := dir - half
	var stop := dir - half + 2.0 * half * sweep
	var steps := 18
	for i in range(steps + 1):
		var a := lerpf(start, stop, float(i) / float(steps))
		pts.append(p + Vector2.from_angle(a) * r)
	for i in range(steps, -1, -1):
		var a2 := lerpf(start, stop, float(i) / float(steps))
		var thick := 0.22 * sin(PI * float(i) / float(steps))
		pts.append(p + Vector2.from_angle(a2) * r * (1.0 - thick))
	if glow_pass:
		ci.draw_colored_polygon(pts, Color(c, 0.35 * fade))
	else:
		ci.draw_colored_polygon(pts, Color(c, 0.55 * fade))
		var edge := PackedVector2Array()
		for i in range(steps + 1):
			edge.append(pts[i])
		ci.draw_polyline(edge, Color(1, 1, 1, 0.9 * fade), 3.0, true)

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

var draw_prof := OS.get_environment("PERF_DRAW") != ""
## Atlas region of the white dot. Circles drawn through dot() are textured
## rects, which Godot batches into a handful of draw calls; draw_circle costs
## one draw call each and was the main frame-rate killer in big fights.
var dot_src := Rect2()

## A clean white disc with a smooth alpha edge, in its own texture: white
## RGB everywhere so mipmaps never darken it, and no neighbouring sprites to
## bleed in when a bullet-sized dot samples a small mip level.
var dot_tex: Texture2D = null

func make_dot_texture() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	var radius := n * 0.5 - 2.0
	for y in range(n):
		for x in range(n):
			var d := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(radius - d + 0.5, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func dot_rect(rect: Rect2, col: Color) -> void:
	if dot_tex == null:
		dot_tex = make_dot_texture()
	draw_texture_rect(dot_tex, rect, false, col)

func dot(p: Vector2, r: float, col: Color) -> void:
	if dot_tex == null:
		dot_tex = make_dot_texture()
	draw_texture_rect(dot_tex, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, col)

func _draw() -> void:
	if headless:
		return
	var in_menu = g.state in ["menu", "collection", "upgrades"] or g.state == "settings" and g.settings_back == "menu"
	if g.hero.is_empty() or in_menu or g.state == "lost":
		return
	shake_off = Vector2(sin(g.anim_t * 97.0), cos(g.anim_t * 83.0)) * g.shake
	if draw_prof:
		# Benchmark only (PERF_DRAW=1): time each layer of the world.
		for layer in ["paint_road", "paint_ground", "paint_obstacles", "paint_gates", "paint_pickups", "paint_barrels",
				"paint_telegraphs", "paint_identity_hazards", "paint_enemies", "paint_pets", "paint_hero", "paint_shots",
				"paint_beams", "paint_fx", "paint_texts"]:
			if OS.get_environment("PERF_SKIP").split(",").has(layer):
				continue
			var t0 := Time.get_ticks_usec()
			call(layer)
			g.prof["d." + layer] = float(g.prof.get("d." + layer, 0.0)) + float(Time.get_ticks_usec() - t0)
	else:
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
## A real street at night. The walkable width is pavement + carriageway:
## asphalt with wear and proper markings in the middle, kerbs, then wide
## paved pavements with street lights out to the building line. Cross
## streets cut through with zebra crossings. Everything is world-anchored.
func wy(screen_y: float) -> float:
	return screen_y - 360.0 + g.cam_y - shake_off.y

func sy(world_y: float) -> float:
	return 360.0 + world_y - g.cam_y + shake_off.y

func hash2(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)

func asphalt_color(b: Dictionary) -> Color:
	return Color(0.115, 0.12, 0.135).lerp(Color(b["road"]), 0.35)

func street_now() -> Dictionary:
	return RoadObstacles.street(str(g.road_layout), float(g.road_half))

func paint_road() -> void:
	var b = BIOMES[g.biome_index()]
	var top: float = g.view_top
	var bottom: float = g.view_bottom
	draw_rect(Rect2(g.landscape_left, top, g.landscape_width, bottom - top), b["bg"])
	var cx: float = 640.0 - g.cam_x + shake_off.x
	var left: float = cx - g.road_half
	var right: float = cx + g.road_half
	var st := street_now()
	var carriage: float = float(st["carriage"])
	var cl: float = cx - carriage
	var cr: float = cx + carriage
	var asphalt := asphalt_color(b)
	var junctions: Array = []
	for cy in RoadObstacles.crossings(g.sector_start_y, g.SECTOR_LEN):
		var s: float = sy(float(cy))
		if s > top - RoadObstacles.CROSS_W and s < bottom + RoadObstacles.CROSS_W:
			junctions.append(s)
	var ps: float = float(st["pavement_start"])
	paint_city_blocks(b, left, right, top, bottom)
	paint_pavement(b, left, cx - ps, top, bottom)
	paint_pavement(b, cx + ps, right, top, bottom)
	paint_verges(b, st, cx, top, bottom)
	draw_rect(Rect2(cl, top, cr - cl, bottom - top), asphalt)
	# Cross streets run out through both pavements and between the buildings.
	var half_w: float = RoadObstacles.CROSS_W * 0.5
	for js in junctions:
		draw_rect(Rect2(g.landscape_left - 10.0, js - half_w, g.landscape_width + 20.0, half_w * 2.0), asphalt)
	paint_asphalt_wear(asphalt, cl, cr, top, bottom)
	paint_kerbs(cl, cr, top, bottom, junctions)
	paint_street_layout(b, g.cam_y)
	paint_bike_and_parking(st, cx, top, bottom, junctions)
	paint_lane_markings(st, cx, cl, cr, top, bottom, junctions)
	for js in junctions:
		paint_junction(cl, cr, left, right, js)
	paint_street_lights(cx, st, top, bottom, junctions)
	# The building line is the edge of the arena.
	for edge in [left, right]:
		draw_rect(Rect2(float(edge) - 3.0, top, 6.0, bottom - top), Color(b["edge"], 0.35))
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

## Houses along both edges: roofs seen from above with ridges, chimneys,
## a lit window and a front step onto the pavement.
func paint_city_blocks(b: Dictionary, left: float, right: float, top: float, bottom: float) -> void:
	var lot := 230.0
	var first := int(floor(wy(top) / lot)) - 1
	var last := int(ceil(wy(bottom) / lot)) + 1
	var roofs := [Color("5a3a3a"), Color("3d4a5c"), Color("4a5a3a"), Color("5c4a2e"), Color("463a5c")]
	for side in [-1, 1]:
		var inner: float = left if side < 0 else right
		var outer: float = g.landscape_left - 10.0 if side < 0 else g.landscape_left + g.landscape_width + 10.0
		if (side < 0 and inner <= outer) or (side > 0 and inner >= outer):
			continue
		var x0: float = minf(inner, outer)
		var w: float = absf(outer - inner)
		# Back gardens / the block behind the houses.
		draw_rect(Rect2(x0, top, w, bottom - top), Color(b["bg"]).lerp(Color("1e3a24"), 0.35))
		for k in range(first, last + 1):
			var y0: float = sy(float(k) * lot) + 14.0
			var h: float = lot - 28.0
			var roof: Color = roofs[int(hash2(k, side) * 5.0) % 5]
			var depth: float = minf(w, 150.0)
			var hx: float = inner - depth if side < 0 else inner
			# Footprint and two roof slopes with a ridge.
			draw_rect(Rect2(hx - 3.0, y0 - 3.0, depth + 6.0, h + 6.0), Color(0.05, 0.04, 0.06))
			draw_rect(Rect2(hx, y0, depth, h * 0.5), roof.lightened(0.12))
			draw_rect(Rect2(hx, y0 + h * 0.5, depth, h * 0.5), roof.darkened(0.15))
			draw_line(Vector2(hx, y0 + h * 0.5), Vector2(hx + depth, y0 + h * 0.5), roof.lightened(0.3), 3.0)
			var tile_y := y0 + 12.0
			while tile_y < y0 + h - 6.0:
				draw_line(Vector2(hx, tile_y), Vector2(hx + depth, tile_y), Color(0, 0, 0, 0.12), 1.0)
				tile_y += 14.0
			# Chimney and a glowing window on the street side.
			var cx_ch: float = hx + depth * (0.3 + hash2(k * 3, side) * 0.4)
			draw_rect(Rect2(cx_ch - 7.0, y0 + h * 0.2, 14.0, 14.0), Color("4a3a36"))
			draw_rect(Rect2(cx_ch - 5.0, y0 + h * 0.2 + 2.0, 10.0, 4.0), Color(0, 0, 0, 0.5))
			var street_x: float = inner - 6.0 if side < 0 else inner
			if hash2(k * 7, side) > 0.35:
				draw_rect(Rect2(street_x, y0 + h * 0.25, 6.0, 18.0), Color(b["deco"], 0.8))
			# Door and step onto the pavement.
			draw_rect(Rect2(street_x, y0 + h * 0.62, 6.0, 22.0), Color("8a5a36"))
			draw_rect(Rect2((inner if side < 0 else inner - 12.0), y0 + h * 0.6, 12.0, 26.0), Color(0.55, 0.56, 0.6))

## Walkable pavement: paving slabs with seams, anchored to the world.
func paint_pavement(b: Dictionary, x0: float, x1: float, top: float, bottom: float) -> void:
	if x1 - x0 < 2.0:
		return
	var slab := Color(0.30, 0.31, 0.34).lerp(Color(b["bg"]), 0.3)
	var seam := Color(0, 0, 0, 0.22)
	draw_rect(Rect2(x0, top, x1 - x0, bottom - top), slab)
	var step := 52.0
	var yy: float = sy(floor(wy(top) / step) * step)
	while yy < bottom:
		draw_line(Vector2(x0, yy), Vector2(x1, yy), seam, 2.0)
		yy += step
	var cxw: float = 640.0 - g.cam_x + shake_off.x
	var col_step := 52.0
	var start_k := int(ceil((x0 - cxw) / col_step))
	var x := cxw + float(start_k) * col_step
	while x < x1:
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(seam, 0.12), 1.0)
		x += col_step

func paint_kerbs(cl: float, cr: float, top: float, bottom: float, junctions: Array) -> void:
	var kerb := Color(0.62, 0.64, 0.68)
	var half_w: float = RoadObstacles.CROSS_W * 0.5
	var segs: Array = [[top, bottom]]
	for js in junctions:
		var next: Array = []
		for sg in segs:
			if js + half_w <= sg[0] or js - half_w >= sg[1]:
				next.append(sg)
			else:
				if js - half_w > sg[0]:
					next.append([sg[0], js - half_w])
				if js + half_w < sg[1]:
					next.append([js + half_w, sg[1]])
		segs = next
	for sg in segs:
		draw_rect(Rect2(cl - 7.0, sg[0], 7.0, sg[1] - sg[0]), kerb)
		draw_rect(Rect2(cl, sg[0], 4.0, sg[1] - sg[0]), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(cr, sg[0], 7.0, sg[1] - sg[0]), kerb)
		draw_rect(Rect2(cr - 4.0, sg[0], 4.0, sg[1] - sg[0]), Color(0, 0, 0, 0.3))

## World-anchored speckle, cracks, tar patches, manholes and tyre marks.
func paint_asphalt_wear(asphalt: Color, cl: float, cr: float, top: float, bottom: float) -> void:
	var tile := 150.0
	var light := asphalt.lightened(0.10)
	var dark := asphalt.darkened(0.25)
	var cxw: float = 640.0 - g.cam_x + shake_off.x
	var ty0 := int(floor(wy(top) / tile)) - 1
	var ty1 := int(ceil(wy(bottom) / tile))
	var tx0 := int(floor((cl - cxw) / tile))
	var tx1 := int(ceil((cr - cxw) / tile))
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1):
			var ox: float = cxw + float(tx) * tile
			var oy: float = sy(float(ty) * tile)
			for k in range(5):
				var px: float = ox + hash2(tx * 13 + k, ty) * tile
				var py: float = oy + hash2(tx, ty * 17 + k) * tile
				if px > cl + 4.0 and px < cr - 4.0:
					draw_rect(Rect2(px, py, 3.0, 2.0), light if k % 2 == 0 else dark)
			var roll: float = hash2(tx * 31, ty * 7)
			var px2: float = ox + tile * 0.5
			var py2: float = oy + tile * 0.5
			if px2 < cl + 40.0 or px2 > cr - 40.0:
				continue
			if roll < 0.10:
				draw_rect(Rect2(px2 - 34.0, py2 - 20.0, 68.0, 40.0), Color(dark, 0.55))
			elif roll < 0.20:
				var pts := PackedVector2Array()
				var q := Vector2(px2 - 30.0, py2 - 20.0)
				for j in range(6):
					pts.append(q)
					q += Vector2(12.0, 6.0 + hash2(tx + j, ty) * 10.0 - 5.0)
				draw_polyline(pts, Color(0, 0, 0, 0.35), 1.6, true)
			elif roll < 0.25:
				dot(Vector2(px2, py2), 14.0, Color(0.05, 0.05, 0.06))
				draw_arc(Vector2(px2, py2), 14.0, 0.0, TAU, 20, Color(light, 0.6), 2.0, true)
				for j in range(3):
					draw_line(Vector2(px2 - 9.0, py2 - 6.0 + j * 6.0), Vector2(px2 + 9.0, py2 - 6.0 + j * 6.0), Color(light, 0.35), 1.5)

## Edge lines, lane dashes, centre line and arrows from the real lane count.
func paint_lane_markings(st: Dictionary, cx: float, cl: float, cr: float, top: float, bottom: float, junctions: Array) -> void:
	var white := Color(0.92, 0.93, 0.95, 0.75)
	var yellow := Color("f2c230", 0.85)
	var half_w: float = RoadObstacles.CROSS_W * 0.5
	var lanes: int = int(st["lanes"])
	var island: float = float(st["island"])
	var lane_w: float = RoadObstacles.LANE_W
	var layout := str(st["layout"])
	var blocked := func(y0: float, y1: float, pad: float) -> bool:
		for js in junctions:
			if y1 > js - half_w - pad and y0 < js + half_w + pad:
				return true
		return false
	# Solid white edge lines a little in from each kerb.
	var y := top
	while y < bottom:
		var y2: float = minf(bottom, y + 24.0)
		if not blocked.call(y, y2, 30.0):
			var edge: float = float(st["traffic"])
			draw_rect(Rect2(cx - edge - 2.0, y, 4.0, y2 - y), white)
			draw_rect(Rect2(cx + edge - 2.0, y, 4.0, y2 - y), white)
			if island <= 0.0:
				if layout == "two_lane":
					if int(floor(wy(y) / 60.0)) % 2 == 0:
						draw_rect(Rect2(cx - 2.0, y, 4.0, y2 - y), yellow)
				else:
					draw_rect(Rect2(cx - 6.0, y, 3.0, y2 - y), yellow)
					draw_rect(Rect2(cx + 3.0, y, 3.0, y2 - y), yellow)
		y = y2
	# Dashed lines between lanes of the same direction.
	var dy: float = sy(floor(wy(top) / 90.0) * 90.0) - 90.0
	while dy < bottom + 90.0:
		if not blocked.call(dy, dy + 44.0, 40.0):
			for k in range(1, lanes):
				for side in [-1.0, 1.0]:
					draw_rect(Rect2(cx + side * (island + k * lane_w) - 2.5, dy, 5.0, 44.0), white)
		dy += 90.0
	# Direction arrows: traffic drives on the right.
	var arrow_step := 700.0
	var ay: float = sy(floor(wy(top) / arrow_step) * arrow_step)
	while ay < bottom + arrow_step:
		if not blocked.call(ay - 60.0, ay + 60.0, 80.0):
			for k in range(lanes):
				var lx: float = island + (k + 0.5) * lane_w
				paint_arrow(Vector2(cx + lx, ay), true, white)
				paint_arrow(Vector2(cx - lx, ay), false, white)
		ay += arrow_step

func paint_arrow(p: Vector2, up: bool, col: Color) -> void:
	var d: float = -1.0 if up else 1.0
	draw_rect(Rect2(p.x - 4.0, p.y - 26.0, 8.0, 52.0), Color(col, 0.55))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-14.0, 26.0 * d), p + Vector2(0.0, 46.0 * d), p + Vector2(14.0, 26.0 * d)]), Color(col, 0.55))

## Zebra crossings, stop lines and pavement crossings at a cross street.
func paint_junction(cl: float, cr: float, left: float, right: float, js: float) -> void:
	var half_w: float = RoadObstacles.CROSS_W * 0.5
	var white := Color(0.92, 0.93, 0.95, 0.8)
	for side in [-1.0, 1.0]:
		var zy: float = js + side * (half_w + 30.0)
		var x := cl + 14.0
		while x < cr - 14.0:
			draw_rect(Rect2(x, zy - 18.0, 16.0, 36.0), white)
			x += 32.0
		draw_rect(Rect2(cl + 10.0, js + side * (half_w + 60.0) - 3.0, cr - cl - 20.0, 6.0), Color(white, 0.6))
	# Crossings over the side street along both pavements.
	for edge in [(left + cl) * 0.5, (cr + right) * 0.5]:
		var yy := js - half_w + 12.0
		while yy < js + half_w - 12.0:
			draw_rect(Rect2(float(edge) - 32.0, yy, 64.0, 14.0), white)
			yy += 28.0

func paint_street_lights(cx: float, st: Dictionary, top: float, bottom: float, junctions: Array) -> void:
	var step := 330.0
	var y: float = sy(floor(wy(top) / step) * step) - step
	var pole_x: float = float(st["carriage"]) + 16.0
	var lamp_x: float = float(st["traffic"]) - 10.0
	while y < bottom + step:
		var skip := false
		for js in junctions:
			if absf(y + 125.0 - js) < RoadObstacles.CROSS_W * 0.5 + 30.0:
				skip = true
		if not skip:
			for side in [-1.0, 1.0]:
				var base := Vector2(cx + side * pole_x, y + 125.0)
				var lamp := Vector2(cx + side * lamp_x, y + 125.0)
				dot(lamp, 58.0, Color(1.0, 0.86, 0.55, 0.05))
				dot(base, 5.0, Color(0.1, 0.1, 0.12))
				draw_line(base, lamp, Color(0.18, 0.19, 0.22), 4.0)
				dot(lamp, 5.0, Color(0.18, 0.19, 0.22))
				dot(lamp, 3.0, Color("ffe6a8"))
		y += step

## Grass verge strips between the kerb and the pavement.
func paint_verges(b: Dictionary, st: Dictionary, cx: float, top: float, bottom: float) -> void:
	var verge: float = float(st["verge"])
	if verge <= 0.0:
		return
	var grass := Color(b["bg"]).lerp(Color("2f6b3a"), 0.5)
	var carriage: float = float(st["carriage"])
	for side in [-1.0, 1.0]:
		var x0: float = cx + carriage if side > 0.0 else cx - carriage - verge
		draw_rect(Rect2(x0, top, verge, bottom - top), grass)
		var step := 40.0
		var gy: float = sy(floor(wy(top) / step) * step)
		var i := 0
		while gy < bottom:
			for k in range(2):
				var fx: float = x0 + 10.0 + fmod(float(k) * 31.0 + float(i) * 19.0, verge - 20.0)
				draw_line(Vector2(fx, gy), Vector2(fx + 2.0, gy - 6.0), Color("7fcf6a", 0.35), 2.0)
			gy += step
			i += 1

## Screen-space [y0, y1] runs between junctions.
func open_segments(top: float, bottom: float, junctions: Array, pad: float) -> Array:
	var half_w: float = RoadObstacles.CROSS_W * 0.5 + pad
	var segs: Array = [[top, bottom]]
	for js in junctions:
		var next: Array = []
		for sg in segs:
			if js + half_w <= sg[0] or js - half_w >= sg[1]:
				next.append(sg)
			else:
				if js - half_w > sg[0]:
					next.append([sg[0], js - half_w])
				if js + half_w < sg[1]:
					next.append([js + half_w, sg[1]])
		segs = next
	return segs

## Green bike lanes with bike symbols, and parking lanes with bay marks.
func paint_bike_and_parking(st: Dictionary, cx: float, top: float, bottom: float, junctions: Array) -> void:
	var segs := open_segments(top, bottom, junctions, 60.0)
	var traffic: float = float(st["traffic"])
	var bike: float = float(st["bike"])
	var park: float = float(st["park"])
	var white := Color(0.92, 0.93, 0.95, 0.7)
	for side in [-1.0, 1.0]:
		if bike > 0.0:
			var bx: float = cx + side * (traffic + bike * 0.5)
			for sg in segs:
				draw_rect(Rect2(bx - bike * 0.5, sg[0], bike, sg[1] - sg[0]), Color(0.18, 0.55, 0.32, 0.35))
			var sym_step := 520.0
			var syy: float = sy(floor(wy(top) / sym_step) * sym_step)
			while syy < bottom + sym_step:
				var in_open := false
				for sg in segs:
					if syy > sg[0] + 20.0 and syy < sg[1] - 20.0:
						in_open = true
				if not in_open:
					syy += sym_step
					continue
				var c := Vector2(bx, syy)
				draw_arc(c + Vector2(-9, 6), 7.0, 0.0, TAU, 14, white, 2.0, true)
				draw_arc(c + Vector2(9, 6), 7.0, 0.0, TAU, 14, white, 2.0, true)
				draw_polyline(PackedVector2Array([c + Vector2(-9, 6), c + Vector2(-2, -4), c + Vector2(9, 6), c + Vector2(4, -6)]), white, 2.0, true)
				syy += sym_step
		if park > 0.0:
			var p0: float = traffic + bike
			var line_x: float = cx + side * p0
			var bay := 230.0
			var by: float = sy(floor(wy(top) / bay) * bay)
			while by < bottom + bay:
				var blocked := false
				for js in junctions:
					if absf(by - js) < RoadObstacles.CROSS_W * 0.5 + 40.0:
						blocked = true
				if not blocked:
					draw_line(Vector2(line_x, by), Vector2(line_x + side * park * 0.8, by), white, 3.0)
				by += bay
			for sg in segs:
				var y: float = sg[0]
				while y < sg[1]:
					draw_line(Vector2(line_x, y), Vector2(line_x, minf(sg[1], y + 20.0)), Color(white, 0.5), 2.0)
					y += 34.0

## Planted centre islands with kerbs, opening at every junction.
func paint_street_layout(b: Dictionary, _scroll: float) -> void:
	var st := street_now()
	var island: float = float(st["island"])
	if island <= 0.0:
		return
	var cx: float = 640.0 - g.cam_x + shake_off.x
	var top: float = g.view_top
	var bottom: float = g.view_bottom
	var half_w: float = RoadObstacles.CROSS_W * 0.5 + 72.0
	var segs: Array = [[top, bottom]]
	for cy in RoadObstacles.crossings(g.sector_start_y, g.SECTOR_LEN):
		var js: float = sy(float(cy))
		var next: Array = []
		for sg in segs:
			if js + half_w <= sg[0] or js - half_w >= sg[1]:
				next.append(sg)
			else:
				if js - half_w > sg[0]:
					next.append([sg[0], js - half_w])
				if js + half_w < sg[1]:
					next.append([js + half_w, sg[1]])
		segs = next
	var grass := Color(b["bg"]).lerp(Color("2f6b3a"), 0.55)
	var kerb := Color(0.62, 0.64, 0.68)
	for sg in segs:
		var h: float = sg[1] - sg[0]
		draw_rect(Rect2(cx - island - 6.0, sg[0], island * 2.0 + 12.0, h), kerb)
		draw_rect(Rect2(cx - island, sg[0] + (6.0 if sg[0] > top + 1.0 else 0.0), island * 2.0, h - (12.0 if sg[1] < bottom - 1.0 and sg[0] > top + 1.0 else 6.0)), grass)

func paint_ground() -> void:
	for f in g.fx:
		if f["kind"] == "splat":
			var p = P(f["pos"])
			var a = 0.35 * (1.0 - float(f["t"]) / float(f["life"]))
			var r = float(f["size"])
			draw_set_transform(p, float(f["rot"]), Vector2(1.0, 0.6))
			dot(Vector2.ZERO, r, Color(f["color"].darkened(0.4), a))
			dot(Vector2(r * 0.8, r * 0.3), r * 0.35, Color(f["color"].darkened(0.4), a))
			dot(Vector2(-r * 0.7, -r * 0.4), r * 0.25, Color(f["color"].darkened(0.4), a))
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
				if z.has("pts"):
					paint_ice_ribbon(z, fade)
				else:
					paint_ice_patch(p, r, float(z.get("seed", 0.0)), fade)
			"nails":
				var sd := float(z.get("seed", 0.0))
				for k in range(3):
					var a := Vector2.from_angle(sd + float(k) * 2.1)
					var q: Vector2 = p + a * 6.0
					draw_line(q - a.orthogonal() * 6.0, q + a.orthogonal() * 6.0, Color(0.78, 0.8, 0.84, fade), 2.0)
					dot(q - a.orthogonal() * 6.0, 2.0, Color(0.55, 0.57, 0.62, fade))
			"oil":
				dot(p, r, Color(0.05, 0.03, 0.08, 0.7 * fade))
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
				dot(p, 22.0, Color(0, 0, 0, 0.95))
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
				dot(start, 5.0, Color("b6eaff", 0.38 * charge))
				dot(stop, 5.0, Color("b6eaff", 0.38 * charge))

# ------------------------------------------------------------- ground effects
## Irregular puddle outline; the same seed always gives the same shape.
## Puddle outlines are cached as unit shapes (16 variants per style) and drawn
## scaled, instead of rebuilding ~30 sine points per puddle every frame.
var puddle_cache: Dictionary = {}

func puddle_poly(p: Vector2, r: float, seed: float, wobble: float, n: int, col: Color) -> void:
	var variant := posmod(int(seed * 7.0), 16)
	var key := Vector3i(variant, int(wobble * 100.0), n)
	var unit = puddle_cache.get(key)
	if unit == null:
		unit = PackedVector2Array()
		var sd := float(variant) * 0.7
		for i in range(n):
			var th := TAU * float(i) / float(n)
			var k := 1.0 + wobble * (0.6 * sin(th * 3.0 + sd) + 0.4 * sin(th * 5.0 + sd * 1.7))
			unit.append(Vector2(cos(th), sin(th) * 0.86) * k)
		puddle_cache[key] = unit
	draw_set_transform(p, 0.0, Vector2(r, r))
	draw_colored_polygon(unit, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

func paint_fire_patch(p: Vector2, r: float, seed: float, fade: float, blaze: bool, hostile: bool = false) -> void:
	if hostile:
		paint_hellfire(p, r, seed, fade)
		return
	puddle_poly(p, r, seed, 0.12, 24, Color(1.0, 0.3, 0.08, 0.5 * fade))
	puddle_poly(p, r * 0.8, seed, 0.13, 24, Color(1.0, 0.58, 0.16, 0.55 * fade))
	dot(p, r * 0.46, Color(1.0, 0.9, 0.45, 0.55 * fade))
	var count := clampi(int(r / 12.0), 3, 8 if blaze else 6)
	for i in range(count):
		var u := fmod(float(i) * 0.618 + seed, 1.0)
		var base := p + Vector2.from_angle(seed * 3.0 + float(i) * 2.399) * r * 0.78 * sqrt(u) * Vector2(1.0, 0.86)
		flame_tongue(base, (10.0 if blaze else 8.0) + 6.0 * (1.0 - u), float(i) * 1.7 + seed, 0.78 * fade)
	for i in range(3):
		var e := fmod(g.anim_t * 0.9 + float(i) * 0.33 + seed, 1.0)
		dot(p + Vector2(sin(seed + i * 2.0) * r * 0.5, -e * r * 0.9), 2.0 * (1.0 - e), Color(1.0, 0.8, 0.4, fade * (1.0 - e)))

## Enemy fire: crimson-magenta hellfire on a scorched base, with the red
## danger rim. Your fire stays orange.
func paint_hellfire(p: Vector2, r: float, seed: float, fade: float) -> void:
	puddle_poly(p, r, seed, 0.12, 24, Color(0.18, 0.02, 0.06, 0.55 * fade))
	puddle_poly(p, r * 0.85, seed, 0.14, 24, Color(0.85, 0.08, 0.25, 0.45 * fade))
	dot(p, r * 0.48, Color(1.0, 0.45, 0.6, 0.45 * fade))
	var count := clampi(int(r / 12.0), 3, 6)
	for i in range(count):
		var u := fmod(float(i) * 0.618 + seed, 1.0)
		var base := p + Vector2.from_angle(seed * 3.0 + float(i) * 2.399) * r * 0.75 * sqrt(u) * Vector2(1.0, 0.86)
		var flick := 0.72 + 0.28 * sin(g.anim_t * 15.0 + float(i) * 1.7)
		var hh := (9.0 + 6.0 * (1.0 - u)) * flick
		var w := hh * 0.42
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(0, -hh), base + Vector2(w, 0), base + Vector2(0, w * 0.4)]), Color(0.9, 0.1, 0.35, 0.8 * fade))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.45, 0), base + Vector2(0, -hh * 0.6), base + Vector2(w * 0.45, 0)]), Color(1.0, 0.6, 0.75, 0.8 * fade))
	danger_rim(p, r, seed, fade)

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

## Your poison is a teal toxin; enemy acid is sickly yellow-green with a
## pulsing red danger rim, so you can always tell whose puddle it is.
func paint_poison_patch(p: Vector2, r: float, seed: float, fade: float, hostile: bool = false) -> void:
	var base := Color(0.62, 0.9, 0.12) if hostile else Color(0.2, 0.92, 0.72)
	var deep := Color(0.28, 0.26, 0.04) if hostile else Color(0.04, 0.3, 0.26)
	var foam := Color(0.95, 1.0, 0.5) if hostile else Color(0.7, 1.0, 0.92)
	puddle_poly(p, r * 1.04, seed, 0.1, 24, Color(deep, 0.4 * fade))
	puddle_poly(p, r * 0.94, seed, 0.1, 24, Color(base, 0.3 * fade))
	dot(p + Vector2(-r * 0.2, -r * 0.15), r * 0.33, Color(foam, 0.16 * fade))
	for i in range(4):
		var u := fmod(g.anim_t * 0.7 + float(i) * 0.27 + seed, 1.0)
		var bp := p + Vector2.from_angle(seed + float(i) * 2.2) * r * 0.55 * Vector2(1.0, 0.86)
		dot(bp, 2.0 + u * 4.0, Color(foam, 0.5 * (1.0 - u) * fade))
	if hostile:
		danger_rim(p, r, seed, fade)

## Pulsing red dashed rim: the shared "this hurts YOU" mark on enemy ground hazards.
func danger_rim(p: Vector2, r: float, seed: float, fade: float) -> void:
	var pulse: float = 0.55 + 0.45 * sin(g.anim_t * 6.0 + seed)
	var spin: float = g.anim_t * 0.6
	# All ten dashes in ONE batched line call.
	var segs := PackedVector2Array()
	for k in range(10):
		var a0: float = spin + float(k) * TAU / 10.0
		for j in range(3):
			segs.append(p + Vector2.from_angle(a0 + float(j) * TAU / 60.0) * r * 1.02)
			segs.append(p + Vector2.from_angle(a0 + float(j + 1) * TAU / 60.0) * r * 1.02)
	draw_multiline(segs, Color(1.0, 0.2, 0.25, 0.75 * pulse * fade), 2.5)

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

## Frostcaster's ice trail: one pale ribbon with a bright edge.
func paint_ice_ribbon(z: Dictionary, fade: float) -> void:
	var pts: Array = z["pts"]
	if pts.size() < 2:
		return
	var ages := Trails.ages(z, g.run_time, float(z["life"]))
	var screen := PackedVector2Array()
	var body := PackedColorArray()
	var core := PackedColorArray()
	for i in range(pts.size()):
		screen.append(P(pts[i]))
		var live := (1.0 - ages[i]) * fade
		body.append(Color(0.72, 0.95, 1.0, 0.3 * live))
		core.append(Color(1, 1, 1, 0.45 * live))
	draw_polyline_colors(screen, body, float(z["r"]) * 2.0, true)
	draw_polyline_colors(screen, core, 3.0, true)

## Enemy acid: one continuous puddle stroke, drawn as a single mesh. The
## width wobbles like spilled liquid, the ends taper like a drip, the edge has
## a dark meniscus and a glossy centre, and the tail dries up by shrinking.
func paint_acid_ribbon(h: Dictionary) -> void:
	var pts: Array = h["pts"]
	if pts.size() < 2:
		return
	var ages := Trails.ages(h, g.run_time, float(h["trail_life"]))
	var r := float(h["r"])
	# Resample to an even step so the outline curves smoothly.
	var line := PackedVector2Array()
	var world := PackedVector2Array()
	var age := PackedFloat32Array()
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / 13.0)))
		for k in range(steps):
			var u := float(k) / float(steps)
			world.append(a.lerp(b, u))
			age.append(lerpf(ages[i], ages[i + 1], u))
	world.append(pts[pts.size() - 1])
	age.append(ages[ages.size() - 1])
	var n := world.size()
	for i in range(n):
		line.append(P(world[i]))
	var total := 0.0
	var along := PackedFloat32Array([0.0])
	for i in range(1, n):
		total += line[i].distance_to(line[i - 1])
		along.append(total)
	# Cross-section: crisp dark rim, bright meniscus, flat pool, and back.
	var offs := [-1.0, -0.8, 0.0, 0.8, 1.0]
	var cn := offs.size()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var gloss := PackedVector2Array()
	var gloss_c := PackedColorArray()
	for i in range(n):
		var prev := line[maxi(0, i - 1)]
		var next := line[mini(n - 1, i + 1)]
		var normal := (next - prev).normalized().orthogonal() if prev.distance_squared_to(next) > 0.01 else Vector2.UP
		var q: Vector2 = world[i]
		var wobble := 0.5 + 0.35 * sin(q.x * 0.083 + q.y * 0.061) * sin(q.y * 0.117 - q.x * 0.043 + 1.7) + 0.15 * sin(q.x * 0.31 - q.y * 0.27)
		var live := 1.0 - age[i]
		var dry := clampf(1.0 - pow(age[i], 1.6), 0.0, 1.0)
		var taper := clampf(along[i] / 22.0, 0.0, 1.0) * clampf((total - along[i]) / 16.0, 0.0, 1.0)
		var w := r * (0.72 + 0.42 * wobble) * dry * sqrt(taper) + 1.5 * taper * dry
		var rim := Color(0.45, 0.06, 0.08, 0.9 * live)
		var edge := Color(0.8, 1.0, 0.25, 0.9 * live)
		var pool := Color(0.55, 0.8, 0.1, 0.6 * live)
		for k in range(cn):
			var o: float = offs[k]
			var ao := absf(o)
			verts.append(line[i] + normal * signf(o) * (w * ao + (2.5 if ao == 1.0 else 0.0)))
			cols.append(rim if ao > 0.9 else (edge if ao > 0.5 else pool))
		gloss.append(line[i] + normal * w * 0.45)
		gloss_c.append(Color(0.9, 1.0, 0.75, 0.45 * live * taper * wobble))
	var idx := PackedInt32Array()
	for i in range(n - 1):
		for k in range(cn - 1):
			var a0 := i * cn + k
			var b0 := (i + 1) * cn + k
			idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	draw_polyline_colors(gloss, gloss_c, 1.6, true)
	# A few bubbles swell and pop at fixed spots along the puddle.
	for i in range(2, n - 2, 3):
		var q2: Vector2 = world[i]
		var seed := fposmod(sin(q2.x * 12.9898 + q2.y * 78.233) * 43758.5453, 1.0)
		if seed > 0.35 or age[i] > 0.75:
			continue
		var cycle := fposmod(g.anim_t * (0.8 + seed) + seed * 7.0, 1.0)
		var side := (seed - 0.17) * 2.4
		var prev2 := line[i - 1]
		var normal2 := (line[i + 1] - prev2).normalized().orthogonal()
		var bp := line[i] + normal2 * side * r * 0.5
		var br := 1.2 + cycle * r * 0.32
		if cycle < 0.85:
			draw_arc(bp, br, 0.0, TAU, 10, Color(0.85, 1.0, 0.6, 0.75 * (1.0 - age[i])), 1.3, true)
			dot(bp + Vector2(-br * 0.35, -br * 0.35), maxf(0.6, br * 0.22), Color(1, 1, 1, 0.6 * (1.0 - age[i])))
		else:
			var pop := (cycle - 0.85) / 0.15
			for j in range(4):
				var d := Vector2.from_angle(j * TAU / 4.0 + seed * 3.0)
				draw_line(bp + d * br * (1.0 + pop * 0.4), bp + d * br * (1.3 + pop), Color(0.85, 1.0, 0.6, 0.7 * (1.0 - pop)), 1.2)

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
				dot(p, s + 5, Color(c, 0.15))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s - bob), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)]), c)
				draw_line(p + Vector2(-1, -s * 0.5), p + Vector2(1, s * 0.2), Color(1, 1, 1, 0.7), 1.5)
			"gold":
				# Consolidated piles visually grow from copper to bright gold coins.
				var worth = int(pk["value"])
				var scale_coin = clampf(1.0 + log(float(maxi(1, worth))) * 0.15, 1.0, 2.3)
				var coin_color = Color("fff0a2") if worth >= 20 else (Color("ffd24d") if worth >= 5 else Color("cba15e"))
				var wsx = absf(cos(g.anim_t * 5.0 + float(pk["t"]) * 3.0))
				draw_set_transform(p, 0.0, Vector2(maxf(0.25, wsx), 1.0))
				dot(Vector2.ZERO, 7.0 * scale_coin, Color("946b23", 0.95))
				dot(Vector2.ZERO, 5.5 * scale_coin, coin_color)
				if worth >= 10:
					dot(Vector2(-3, -4) * scale_coin, 1.8 * scale_coin, Color("fff2cd", 0.85))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"heart":
				heart(p + Vector2(0, bob), 9.0, Color("ff4d6a"))
			"chest":
				var ct = g.tex("res://assets/ui/chest.svg")
				dot(p, 30, Color(1, 0.85, 0.3, 0.2 + 0.1 * sin(g.anim_t * 5.0)))
				if ct != null:
					draw_texture_rect(ct, Rect2(p - Vector2(29, 29 - bob), Vector2(58, 58)), false)
				else:
					draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color("ffd24d"))

func heart(p: Vector2, s: float, c: Color) -> void:
	dot(p + Vector2(-s * 0.45, -s * 0.2), s * 0.55, c)
	dot(p + Vector2(s * 0.45, -s * 0.2), s * 0.55, c)
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
				var st_now := street_now()
				if absf(float(ob["pos"].x)) > float(st_now["carriage"]) + float(st_now["verge"]):
					# Pavement tree pit with an iron grate.
					draw_rect(Rect2(p + Vector2(-26, -14), Vector2(52, 44)), Color(0.2, 0.2, 0.23))
					draw_rect(Rect2(p + Vector2(-22, -10), Vector2(44, 36)), Color("3a2a20"))
					for k in range(4):
						draw_line(p + Vector2(-22 + k * 14, -10), p + Vector2(-22 + k * 14, 26), Color(0.35, 0.36, 0.4, 0.8), 2.0)
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
		dot(c[0], float(c[1]) + 3.0, Color("0d221c"))
	for c in crowns:
		dot(c[0], float(c[1]), pal[0])
	for c in crowns:
		dot(Vector2(c[0]) + Vector2(-3, -4), float(c[1]) * 0.78, pal[1])
	for c in crowns:
		dot(Vector2(c[0]) + Vector2(-6, -7), float(c[1]) * 0.42, pal[2])
	for i in range(5):
		var lp: Vector2 = p + sway + Vector2(0, -24) + Vector2.from_angle(seed * 2.0 + float(i) * 1.3) * 14.0
		dot(lp, 2.2, Color(pal[3], 0.75))

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
## Traffic cone from above, drawn big and bright so it reads at a glance:
## shadow, black base, orange cone with two white reflective bands.
func paint_cone(p: Vector2) -> void:
	dot(p + Vector2(4, 5), 17.0, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(p + Vector2(-17, -17), Vector2(34, 34)), Color("15171d"))
	draw_rect(Rect2(p + Vector2(-14.5, -14.5), Vector2(29, 29)), Color("2c303a"))
	dot(p, 13.5, Color("15171d"))
	dot(p, 12.0, Color("ff6a10"))
	dot(p, 8.6, Color("fff4dc"))
	dot(p, 6.6, Color("ff7a1f"))
	dot(p, 3.6, Color("fff4dc"))
	dot(p, 2.2, Color("ff8a2e"))
	dot(p + Vector2(-5, -5), 2.2, Color(1, 1, 1, 0.55))

## Sawhorse roadblock: striped board on legs with blinking amber lamps.
func paint_roadblock(p: Vector2, seed: float) -> void:
	# Drawn 25% larger than before so roadworks are unmissable.
	draw_set_transform(p, 0.0, Vector2.ONE * 1.25)
	paint_roadblock_at(Vector2.ZERO, seed)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func paint_roadblock_at(p: Vector2, seed: float) -> void:
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
			dot(lamp, 11.0, Color(1.0, 0.75, 0.2, 0.22))
		dot(lamp, 5.0, Color("ffcf4a") if on else Color("8a5a14"))

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
			dot(p + Vector2(sin(i * 2.0 + seed) * 6.0, -hh + 8.0 - u * 40.0), 5.0 + u * 9.0, Color(0.2, 0.2, 0.22, 0.45 * (1.0 - u)))

func draw_ellipse_shadow(p: Vector2, r: float) -> void:
	draw_set_transform(p + Vector2(3, 13), 0.0, Vector2(1.0, 0.55))
	dot(Vector2.ZERO, r + 5.0, Color(0, 0, 0, 0.31))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func paint_barrels() -> void:
	for b in g.barrels:
		var p = P(b["pos"])
		if p.y < g.view_top - 40.0 or p.y > g.view_bottom + 40.0:
			continue
		var drop = float(b["drop"])
		if drop > 0.0:
			dot(p, 18.0 * (1.0 - drop), Color(0, 0, 0, 0.4))
			p.y -= drop * 500.0
		dot(p + Vector2(3, 8), 19, Color(0, 0, 0, 0.35))
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
			dot(spark_pos, 6.5 * flicker, Color("ff9c35", 0.8))
			dot(spark_pos + Vector2(0, -2.5), 3.6 * flicker, Color("fff6a8"))
			var progress = 1.0 - clampf(float(b.get("fuse", 0.85)) / 0.85, 0.0, 1.0)
			dot(p, 115.0, Color(1.0, 0.25, 0.12, 0.08 + progress * 0.15))
			draw_arc(p, 115.0, -PI * 0.5, -PI * 0.5 + progress * TAU, 40, Color("ffda70"), 4.0)
			draw_arc(p, 25.0, 0.0, TAU, 24, Color("ff5858"), 3.0)
			if progress > 0.25:
				for j in range(8):
					var ray = Vector2.from_angle(float(j) * TAU / 8.0 + g.anim_t * 0.4)
					draw_line(p + ray * 31.0, p + ray * (38.0 + progress * 14.0), Color("ffe088", 0.45 + progress * 0.4), 2.0)
	for pet in g.pets:
		if pet["kind"] == "mine":
			var mp = P(pet["pos"])
			dot(mp, 9, Color("3a3a48"))
			var blink = fmod(g.anim_t * (6.0 if float(pet["arm"]) <= 0.0 else 2.0), 1.0) < 0.5
			dot(mp, 3.5, Color("ff3a3a") if blink else Color("601818"))

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
		if fn in ["boss_blast", "elite_boom", "mut_pulse"]:
			danger_circle(p, r, k, warning_color, d)
			continue
		dot(p, r, Color(warning_color, 0.035 + 0.075 * k))
		draw_arc(p, r, 0.0, TAU, 32, Color(warning_color, 0.73), 2.0)
		draw_arc(p, maxf(6.0, r - 8.0), -PI * 0.5, -PI * 0.5 + TAU * k,
			28, Color(warning_color.lightened(0.45), 0.72), 2.0)
		if d["fn"] == "kaboomba_boom":
			# The dead bomber remains visible as a blinking armed body until detonation.
			var blink = fmod(g.anim_t * (6.0 + k * 12.0), 1.0) < 0.5
			dot(p + Vector2(2, 6), 17.0, Color(0, 0, 0, 0.4))
			dot(p, 16.0 + k * 5.0, Color("ffb543") if blink else Color("c52a37"))
			dot(p - Vector2(5, 4), 4.0, Color.WHITE)
			dot(p + Vector2(5, -4), 4.0, Color.WHITE)
			dot(p + Vector2(0, -21), 3.0 + k * 3.0, Color("fff37b"))
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
				dot(p + Vector2(0, -fall * 1.4), 9, Color("3a3320"))
				dot(p + Vector2(-2, -fall * 1.4 - 2), 5, Color("c9b27a"))
			"meteor":
				var mp = p + Vector2(fall * 0.4, -fall)
				draw_line(mp, mp + Vector2(50, -70), Color(1, 0.6, 0.2, 0.6), 10.0)
				dot(mp, 16, Color("ff7a3d"))
				dot(mp, 10, Color("ffd24d"))
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
				dot(p, float(e["tele"]), Color(1, 0.2, 0.2, 0.12))
			elif enemy_has_role(e, "bull") or enemy_has_role(e, "zoomer") or enemy_has_role(e, "skitter"):
				var color = Color("83eaff") if enemy_has_role(e, "skitter") else Color(1, 0.6, 0.2)
				draw_line(p, P(g.hero["pos"]), Color(color, 0.45), 5.0)
			elif enemy_has_role(e, "blinky"):
				var depart: Vector2 = P(e.get("rift_origin", e["pos"]))
				var arrive: Vector2 = P(e.get("lock", g.hero["pos"]))
				draw_arc(arrive, 22.0, 0, TAU, 24, Color("c79cff", 0.68), 3.0)
				# This preview is the exact dash slash segment, not a player prediction.
				draw_line(depart, arrive, Color("b88bff", 0.21), 30.0)
				draw_line(depart, arrive, Color("ebd5ff", 0.83), 2.5)
			elif enemy_has_role(e, "leech"):
				var drain_to = P(e.get("lock", g.hero["pos"]))
				var pulse = 0.34 + 0.26 * sin(g.anim_t * 14.0)
				draw_line(p, drain_to, Color(0.84, 0.34, 1.0, pulse), 4.5)
				draw_arc(drain_to, 27.0, 0, TAU, 30, Color("d9a3ff", 0.80), 3.0)
				draw_arc(p, float(e["r"]) + 8.0, 0, TAU, 24, Color("d9a3ff", 0.90), 3.5)
			elif enemy_has_role(e, "spitter"):
				# Its acid is slow (~240 px/s) and easy to watch, so no aim line: only the body cue.
				draw_arc(p, float(e["r"]) + 5.0, 0, TAU, 24, Color("a2ff83", 0.80), 2.5)
			elif enemy_has_role(e, "riot"):
				# Shield bash wind-up: the shield glows and leans forward.
				draw_arc(p + Vector2(e["aim"]) * float(e["r"]), float(e["r"]) * 0.9, Vector2(e["aim"]).angle() - 1.0, Vector2(e["aim"]).angle() + 1.0, 14, Color("c8d8ff", 0.85), 4.0, true)

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
	dot(p, r, Color(col, 0.07))
	dot(p, r * k, Color(col, 0.14 + 0.22 * k))
	draw_arc(p, r, 0.0, TAU, 48, Color(0, 0, 0, 0.45), 5.0, true)
	draw_arc(p, r, 0.0, TAU, 48, Color(col.lightened(0.35), 0.95), 2.5, true)
	if k > 0.78:
		draw_arc(p, r, 0.0, TAU, 48, Color(1, 1, 1, (k - 0.78) / 0.22 * 0.9), 3.5, true)
	var drop: float = (1.0 - k) * 150.0
	# A falling object tells the player what is about to land.
	if bool(d.get("bomb", false)) or bool(d.get("mortar", false)):
		var b := p + Vector2(0, -drop)
		dot(b, 8.0, Color("1d1f26"))
		dot(b + Vector2(-2, -2), 3.0, Color("8a8f9c"))
		draw_line(b + Vector2(0, -8), b + Vector2(0, -14), Color("ffd24d"), 2.0)
	elif bool(d.get("boulder", false)):
		var rock := p + Vector2(0, -drop * 1.4)
		dot(rock, r * 0.3, Color("6b4a33"))
		dot(rock + Vector2(-r * 0.08, -r * 0.08), r * 0.12, Color("9c7454"))
	elif str(d.get("style", "")) == "chonkzilla" and not bool(d.get("landing", false)):
		if k > 0.35:
			var fade: float = (k - 0.35) / 0.65
			var m := p + Vector2(drop * 0.4, -drop * 1.3)
			draw_line(m, m + Vector2(14, -24) * (1.0 + fade), Color(1, 0.6, 0.2, 0.45 * fade), 6.0)
			dot(m, 8.0, Color("ff7a3d", fade))
			dot(m, 4.5, Color("ffe08a", fade))
	elif str(d.get("style", "")) == "necro":
		var stone := PackedVector2Array([p + Vector2(-9, 10), p + Vector2(-9, -4), p + Vector2(0, -12), p + Vector2(9, -4), p + Vector2(9, 10)])
		draw_colored_polygon(stone, Color("8f8aa0", 0.4 + 0.5 * k))
		draw_line(p + Vector2(0, -6), p + Vector2(0, 5), Color(0, 0, 0, 0.6), 2.0)
		draw_line(p + Vector2(-4, -2), p + Vector2(4, -2), Color(0, 0, 0, 0.6), 2.0)
	elif str(d.get("style", "")) == "kingblob" and int(d.get("burst", 0)) > 0:
		var gem := p + Vector2(0, -drop)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -10), gem + Vector2(8, 0), gem + Vector2(0, 10), gem + Vector2(-8, 0)]), Color("ffcf3d"))
		dot(gem, 3.0, Color("ff3d5a"))
	elif bool(d.get("blink", false)):
		draw_arc(p, r * 0.5, g.anim_t * 4.0, g.anim_t * 4.0 + PI * 1.4, 20, Color(col.lightened(0.4), 0.9), 3.0, true)
	elif bool(d.get("landing", false)):
		pass # The airborne boss's own shadow is the tell.
	else:
		dot(p, 3.0 + 2.0 * k, Color(col.lightened(0.4), 0.8))

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
		dot(a.lerp(b, k), 4.0, Color(1, 1, 1, 0.7))
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
	dot(center, radius, Color(col.darkened(0.6), 0.18 if armed else 0.08))
	draw_arc(center, radius, 0.0, TAU, 56, Color(0, 0, 0, 0.4), 5.0, true)
	draw_arc(center, radius, g.anim_t * 0.8, g.anim_t * 0.8 + TAU * 0.92, 56, Color(col.lightened(0.3), 0.95 if armed else 0.45), 3.0, true)
	for ring in range(4):
		var rr: float = radius * (0.95 - fmod(g.anim_t * 0.5 + float(ring) * 0.25, 1.0) * 0.85)
		draw_arc(center, rr, -g.anim_t * 2.0 + ring, -g.anim_t * 2.0 + ring + PI * 1.2, 34, Color(col.lightened(0.5), 0.45), 2.0, true)
	dot(center, 14.0, Color("0b0614"))
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
				dot(p, 4.0, red)
		"bf_portal":
			var rr2: float = float(d.get("tele", 34.0)) * (0.4 + 0.6 * k)
			dot(p, rr2, Color("0b0614"))
			for i in range(3):
				var off: float = g.anim_t * (3.0 + i) + TAU * float(i) / 3.0
				draw_arc(p, rr2 * (1.0 - i * 0.22), off, off + PI * 1.3, 24, Color(col.lightened(0.2 * i), 0.95), 3.0, true)
			var aim: Vector2 = (g.hero["pos"] - Vector2(d["pos"])).normalized()
			draw_line(p + aim * (rr2 + 4.0), p + aim * (rr2 + 22.0 + 16.0 * k), Color(col.lightened(0.4), 0.85), 3.0)
		"bf_echo":
			var ghost := Color("8ceeff")
			dot(p, 13.0, Color(ghost, 0.18 + 0.25 * k))
			draw_arc(p, 13.0, 0.0, TAU, 20, Color(ghost, 0.85), 2.0, true)
			draw_arc(p, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, Color(ghost, 0.95), 3.0, true)
			dot(p + Vector2(-4, -3), 2.0, Color(ghost, 0.9))
			dot(p + Vector2(4, -3), 2.0, Color(ghost, 0.9))
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

## Leechling's drain: a sagging blood stream from you to it, with droplets
## flowing toward the leech.
func paint_blood_tether(from: Vector2, to: Vector2) -> void:
	var mid := (from + to) * 0.5 + Vector2(0, 26.0 + 6.0 * sin(g.anim_t * 4.0))
	var pts := PackedVector2Array()
	for i in range(17):
		var u := float(i) / 16.0
		pts.append(from.lerp(mid, u).lerp(mid.lerp(to, u), u))
	var pulse := 0.75 + 0.25 * sin(g.anim_t * 9.0)
	draw_polyline(pts, Color(0.35, 0.02, 0.1, 0.8), 9.0, true)
	draw_polyline(pts, Color(0.9, 0.12, 0.3, 0.85 * pulse), 5.0, true)
	draw_polyline(pts, Color(1.0, 0.6, 0.7, 0.6), 1.5, true)
	for k in range(5):
		var u2 := 1.0 - fmod(g.anim_t * 0.9 + float(k) * 0.2, 1.0)
		var idx := int(u2 * 16.0)
		dot(pts[idx], 3.5, Color(1.0, 0.3, 0.45, 0.95))
		dot(pts[idx] + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.8))
	dot(to, 10.0 + 3.0 * pulse, Color(0.9, 0.12, 0.3, 0.25))

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
				dot(p, r, Color(col, 0.13))
				draw_arc(p, r, 0, TAU, 28, Color(col, 0.7), 2.5)
				dot(p, 10.0, Color("33242a"))
				dot(p, 4.0, Color("ff704e") if armed else Color("a9dafa"))
			"egg":
				paint_mama_egg(p, r, 1.0 - clampf(float(h["life"]) / float(h["max_life"]), 0.0, 1.0), float(h["hp"]) / 28.0)
			"acid":
				paint_poison_patch(p, r, float(h["pos"].x) * 0.37, clampf(float(h["life"]) / 0.6, 0.0, 1.0), true)
			"fire":
				paint_fire_patch(p, r, float(h["pos"].x) * 0.37, clampf(float(h["life"]) / 0.6, 0.0, 1.0), false, true)
			"acid_trail":
				# One uninterrupted acid puddle stroke. Exact collision width, no rows of circles.
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
	# Pass 1: every body and pair of eyes, back to back (one atlas batch).
	var pass_t0 := Time.get_ticks_usec()
	enemy_pass = 1
	for e in g.enemies:
		if bool(e["dead"]):
			continue
		var body: String = MutationKit.primary(g, str(e["kind"]))
		var p1 = P(e["pos"])
		var r1 = float(e["r"])
		if p1.y < g.view_top - r1 - 60.0 or p1.y > g.view_bottom + r1 + 60.0:
			continue
		if bool(e.get("burrowing", false)) and not bool(e["boss"]):
			continue
		if body == "ashwing" and float(e.get("rebirth_t", 0.0)) > 0.0:
			continue
		draw_enemy(e, p1, r1)
	if draw_prof:
		g.prof["d.enemy_pass1"] = float(g.prof.get("d.enemy_pass1", 0.0)) + float(Time.get_ticks_usec() - pass_t0)
	# Pass 2: everything drawn on top of the bodies.
	enemy_pass = 2
	for e in g.enemies:
		if bool(e["dead"]):
			continue
		var body: String = MutationKit.primary(g, str(e["kind"]))
		var p = P(e["pos"])
		var r = float(e["r"])
		if p.y < g.view_top - r - 60.0 or p.y > g.view_bottom + r + 60.0:
			continue
		if bool(e["boss"]):
			paint_boss_links(e, p)
		if bool(e.get("burrowing", false)) and not bool(e["boss"]):
			paint_burrow_mound(e, p, r)
			continue
		if body == "ashwing" and float(e.get("rebirth_t", 0.0)) > 0.0:
			var total := 1.55 if g.hard_mode else 1.8
			paint_phoenix_egg(p, r, 1.0 - clampf(float(e["rebirth_t"]) / total, 0.0, 1.0))
		else:
			var de_t0 := Time.get_ticks_usec() if draw_prof else 0
			draw_enemy(e, p, r)
			if draw_prof:
				g.prof["d.pass2_draw_enemy"] = float(g.prof.get("d.pass2_draw_enemy", 0.0)) + float(Time.get_ticks_usec() - de_t0)
		# Real slime-wall links, only around visible threatening packs.
		if e["kind"] == "blob" and e["pos"].distance_squared_to(g.hero["pos"]) < 210.0 * 210.0:
			var linked = 0
			for other in Combat.query_touching(g, e["pos"], 76.0):
				if other == e or bool(other["dead"]) or str(other["kind"]) != "blob" or int(other["id"]) < int(e["id"]):
					continue
				if e["pos"].distance_squared_to(other["pos"]) < 75.0 * 75.0:
					draw_line(p, P(other["pos"]), Color("ffadc1", 0.40), 8.0)
					linked += 1
					if linked >= 2:
						break
		if body == "leech" and float(e.get("tether_t", 0.0)) > 0.0:
			paint_blood_tether(p, P(g.hero["pos"]))
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
			dot(p, r + 4.0, Color("5cbcff", 0.09))
			draw_arc(p, r + 5.0, 0.0, TAU, 18, Color("8fdcff", 0.46), 2.1)
			if float(e.get("shield_flash_until", 0.0)) > g.run_time:
				draw_arc(p, r + 8.0, 0.0, TAU, 22, Color("d9faff", 0.86), 3.0)
		if body == "ashwing" and float(e.get("rebirth_t", 0.0)) > 0.0:
			var progress = 1.0 - float(e["rebirth_t"]) / (1.55 if g.hard_mode else 1.8)
			progress = clampf(progress, 0.0, 1.0)
			draw_arc(p, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color("ffdf80", 0.8), 3.0, true)
		elif body == "larry" and float(e.get("overheat_t", 0.0)) > 0.0:
			draw_arc(p, r + 10.0, 0, TAU, 28, Color("ffcf8a"), 4.0)
			text_c("OVERHEATED", p + Vector2(0, -r - 28.0), 11, Color("ffe5a4"), 2)
		elif body == "nurse" and e.get("patient") != null:
			var patient = e["patient"]
			if not bool(patient.get("dead", false)):
				draw_line(p, P(patient["pos"]), Color("83efbb", 0.65), 2.5)
				if float(e.get("treat_t", 0.0)) > 0.0:
					draw_arc(p, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, float(e["treat_t"]) / 1.15), 24, Color("83ffac"), 3.0)
		elif body == "siren":
			draw_arc(p, 180.0, 0, TAU, 64, Color(0.95, 0.54, 0.85, 0.22), 2.0)
		elif body == "burrower" and float(e.get("exposed_t", 0.0)) > 0.0:
			for k in range(3):
				var th: float = g.anim_t * 4.0 + TAU * float(k) / 3.0
				dot(p + Vector2(cos(th) * r * 0.8, -r - 6.0 + sin(th) * 4.0), 3.0, Color("ffe07f"))
		elif body == "skitter" and float(e.get("dizzy_t", 0.0)) > 0.0:
			for k in range(3):
				var th2: float = g.anim_t * 5.0 + TAU * float(k) / 3.0
				dot(p + Vector2(cos(th2) * r * 0.9, -r - 6.0 + sin(th2) * 4.0), 3.0, Color("ffe07f"))
		# Elite affix labels only near you: a screen full of them is unreadable
		# and expensive.
		if e.has("affix") and Vector2(e["pos"]).distance_squared_to(g.hero["pos"]) < 280.0 * 280.0:
			text_c(" · ".join(e["affix"]), p + Vector2(0, -r - 20), 11, Color(1, 0.82, 0.3, 0.85), 2)
		elif body == "totem":
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
	enemy_pass = 0

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
	# A mutant shows its body parent's attacks and tells.
	return kind == role or (kind.begins_with("mix_") and str(g.enemy_db[kind]["mix"][0]) == role)

var atlas: Texture2D = null
var mix_rebake_pending := false
var atlas_cell: Dictionary = {}

class Baker extends Node2D:
	var v
	var keys: Array = []
	func _draw() -> void:
		for i in range(keys.size()):
			var o = Vector2((i % 8) * 200, int(i / 8) * 200)
			var key: String = keys[i]
			if key == "#dot":
				draw_circle(o + Vector2(100, 100), 95.0, Color.WHITE)
				continue
			# "@kind" is a portrait with the weapon in hand (cards, Bestiary);
			# in-game cells leave the hand empty for the live weapon.
			var portrait = key.begins_with("@")
			var kind = key.trim_prefix("@").trim_suffix("*")
			var elite = key.ends_with("*")
			draw_set_transform(o + Vector2(100, 138), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 38.0, Color(0, 0, 0, 0.35))
			draw_set_transform(o + Vector2(100, 108), 0.0, Vector2.ONE)
			if elite or bool(v.g.enemy_db[kind].get("boss", false)):
				draw_circle(Vector2.ZERO, 47.0, Color(1.0, 0.82, 0.3, 0.22))
			v.draw_enemy_body(self, kind, elite, 40.0, Color(str(v.g.enemy_db[kind]["color"])), false, portrait)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func bake_enemies() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var keys = []
	for kind in g.enemy_db:
		keys.append(kind)
		if not bool(g.enemy_db[kind].get("boss", false)):
			keys.append(kind + "*")
			if not held_parts_of(kind).is_empty():
				keys.append("@" + kind)
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
		var cell: Rect2 = atlas_cell["#dot"]
		dot_src = Rect2(cell.position + Vector2(4, 4), Vector2(192, 192))
	vp.queue_free()
	mix_rebake_pending = false

## Held weapons (spear, mortar tube, bomb) of a street monster or a fusion.
var held_cache: Dictionary = {}

func held_parts_of(kind: String) -> Array:
	var cached = held_cache.get(kind)
	if cached != null:
		return cached
	var found := held_parts_uncached(kind)
	held_cache[kind] = found
	return found

func held_parts_uncached(kind: String) -> Array:
	var fusion: Array = g.enemy_db[kind].get("mix", []) if kind.begins_with("mix_") else [kind, kind]
	if fusion.size() < 2 or not MonsterKit.has(str(fusion[0])) or not MonsterKit.has(str(fusion[1])):
		return []
	return MonsterKit.held_parts(str(fusion[0]), str(fusion[1]))

## Portrait cell (weapon in hand) when there is one, else the plain cell.
func portrait_key(kind: String) -> String:
	return "@" + kind if atlas_cell.has("@" + kind) else kind

## Draws the held weapon live so it aims, winds up, swings and is thrown.
func paint_held(e: Dictionary, p: Vector2, r: float) -> void:
	var kind := str(e["kind"])
	var held := held_parts_of(kind)
	if held.is_empty():
		return
	var skin: String = str(g.enemy_db[kind]["mix"][1]) if kind.begins_with("mix_") else kind
	var t := float(e["t"])
	var wind := float(e.get("wind", 0.0))
	var aim: Vector2 = Vector2(g.hero["pos"]) - Vector2(e["pos"])
	var pose := {"t": t}
	if wind > 0.0 and enemy_has_role(e, "lancer"):
		var attack := str(e.get("lancer_attack", "spear"))
		pose["attack"] = attack
		pose["wind"] = clampf(1.0 - wind / (0.6 if attack == "sweep" else 0.55), 0.0, 1.0)
		aim = Vector2(e.get("lock", g.hero["pos"])) - Vector2(e["pos"])
	elif float(e.get("sap_wind", 0.0)) > 0.0:
		pose["wind"] = clampf(1.0 - float(e["sap_wind"]) / 0.35, 0.0, 1.0)
	var since_throw := t - float(e.get("throw_at", -99.0))
	pose["gone"] = clampf((since_throw - 0.5) / 0.5, 0.0, 1.0)
	var since_swing := t - float(e.get("swing_at", -99.0))
	if since_swing < 0.58:
		pose["swing"] = since_swing / 0.32
		pose["swing_dir"] = float(e.get("swing_dir", aim.angle()))
	var since_fire := t - float(e.get("fire_at", -99.0))
	if since_fire < 0.4:
		pose["recoil"] = 1.0 - since_fire / 0.4
	draw_set_transform(p, 0.0, Vector2.ONE)
	for part in held:
		MonsterKit.draw_held(self, str(part), skin, r, aim, pose)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 0 = draw everything, 1 = bodies and eyes only, 2 = extras only. The crowd
## is drawn in two passes so every atlas sprite lands in one GPU batch
## instead of breaking the batch at each enemy's status dots and lines.
var enemy_pass := 0

func draw_enemy(e: Dictionary, p: Vector2, r: float) -> void:
	var bodies := enemy_pass != 2
	var extras := enemy_pass != 1
	var body: String = MutationKit.primary(g, str(e["kind"]))
	if bool(e.get("boss", false)) and BossFight.is_boss_kind(str(e["kind"])):
		if bodies:
			draw_boss(e, p, r)
		return
	if str(e.get("minion_role", "")) in ["ward", "mirror", "pod"]:
		if not bodies:
			return
		var flash_m := float(e["flash"]) > 0.0
		draw_ellipse_shadow(p + Vector2(0, r * 0.9), r * 0.8)
		draw_set_transform(p, 0.0, Vector2.ONE)
		BossModels.minion(self, str(e["minion_role"]), r, {"t": g.anim_t + float(e["phase"]), "aim": (g.hero["pos"] - Vector2(e["pos"])).normalized()})
		if flash_m:
			dot(Vector2.ZERO, r, Color(1, 1, 1, 0.45))
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
	if mixed and atlas_cell.has(kind):
		base_kind = kind
	elif mixed and not mix_rebake_pending and atlas != null:
		# A mutant first seen mid-run: bake its fusion sprite once.
		mix_rebake_pending = true
		bake_enemies()
	var src = atlas_cell.get(base_kind + ("*" if bool(e["elite"]) else ""))
	if atlas == null or src == null:
		if bodies:
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
	if extras and (body == "zoomer" or body == "mini"):
		var back = -e["vel"].normalized() if e["vel"].length() > 5 else Vector2.DOWN
		for j in range(3):
			draw_line(p + back.rotated(0.4 * (j - 1)) * r, p + back.rotated(0.4 * (j - 1)) * (r + 10 + j * 3), Color(col, 0.5), 2.0)
	if not bodies:
		pass
	elif spinning:
		var rot = float(e["t"]) * 14.0 if float(e.get("spin", 0.0)) > 0.0 else sin(g.anim_t * 14.0) * 0.5
		draw_set_transform(p, rot, Vector2(sx, sy) * k)
		draw_texture_rect_region(atlas, Rect2(-100, -108, CELL, CELL), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(atlas, Rect2(p.x - 100.0 * k * sx, p.y - 108.0 * k * sy, CELL * k * sx, CELL * k * sy), src, tint)
	# Chonkzilla's body itself changes as armor breaks; this is not merely a HUD label.
	# Draw cheap lines over the already-baked sprite: no new texture or particles.
	if extras and kind == "chonkzilla":
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
			dot(p + Vector2(0, r * 0.12), r * 0.12, Color("ffc381", 0.82))
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
	if not extras:
		pass
	elif kind == "heli":
		var a = g.anim_t * 25.0
		draw_line(p + Vector2.from_angle(a) * r * 1.6, p + Vector2.from_angle(a + PI) * r * 1.6, Color(0.9, 0.9, 1.0, 0.6), 5.0)
		draw_line(p + Vector2.from_angle(a + PI * 0.5) * r * 1.6, p + Vector2.from_angle(a + PI * 1.5) * r * 1.6, Color(0.9, 0.9, 1.0, 0.6), 5.0)
	elif body == "kaboomba":
		dot(p + Vector2(5, -r - 10), 3.5 + sin(g.anim_t * 30.0) * 1.5, Color("ffd24d"))
	var look: Vector2 = e["aim"]
	var eye_r = maxf(3.5, r * 0.3)
	var ey = -r * 0.18 * sy
	if str(parts.get("face", "")) == "visor":
		if extras:
			draw_rect(Rect2(p.x - r * 0.7 + (look.x + 1.0) * r * 0.5, p.y + ey - 2, r * 0.4, 4), Color("ff3a5a"))
	elif not spinning:
		var dot_src_rect: Rect2 = dot_src
		var pr = eye_r * 0.5
		var off = look * eye_r * 0.45
		var pc = Color("120810") if float(e["frozen"]) <= 0.0 else Color("4080a0")
		var big_head = g.st("bighead") > 0
		for ex in ([0.0] if kind == "necro" else [-0.36, 0.36]):
			var ep = p + Vector2(ex * r * sx, ey)
			# Pupils use the clean dot texture and are drawn in the extras
			# pass, so pass 1 stays one unbroken batch of atlas sprites.
			if not extras:
				pass
			elif big_head:
				dot_rect(Rect2(ep - Vector2(eye_r, eye_r) * 1.6, Vector2(eye_r, eye_r) * 3.2), Color.WHITE)
				dot_rect(Rect2(ep + off * 1.6 - Vector2(pr, pr) * 1.6, Vector2(pr, pr) * 3.2), pc)
			else:
				dot_rect(Rect2(ep + off - Vector2(pr, pr), Vector2(pr, pr) * 2.0), pc)
			if extras and float(e["charm"]) > 0.0:
				heart(ep + Vector2(0, -1), eye_r * 0.6, Color("ff3a8a"))
	if not extras:
		return
	if body == "riot" and float(e.get("shield_hp", 1.0)) > 0.0:
		var aim: Vector2 = e["aim"]
		var sp = p + aim * (r + 4)
		var perp = aim.orthogonal()
		draw_line(sp - perp * r * 1.1, sp + perp * r * 1.1, Color("2a3a60"), 9.0)
		draw_line(sp - perp * r * 1.0, sp + perp * r * 1.0, Color("a8c0ff"), 5.0)
	if mixed and parents.size() >= 2:
		# Inherit one ANATOMICAL feature from the second parent. Do not
		# paste eyes, masks, lips or a complete second face onto the base.
		if base_kind != kind:
			# Until its fusion sprite is baked, draw the fusion live.
			draw_set_transform(p, 0.0, Vector2.ONE)
			draw_enemy_body(self, kind, bool(e["elite"]), r, Color(str(g.enemy_db[kind]["color"])), false, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not spinning:
		paint_held(e, p, r)
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
		dot(p, r * 1.5, Color(1, 1, 1, 0.08 + 0.08 * pulse))
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
	dot(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.35))
	draw_set_transform(p, 0.0, Vector2.ONE)
	draw_enemy_body(self, kind, bool(e["elite"]), r, e["color"], float(e["flash"]) > 0.0, false)
	var look: Vector2 = e["aim"]
	var eye_r = maxf(3.5, r * 0.3)
	if str(parts.get("face", "")) != "visor":
		for ex in ([0.0] if kind == "necro" else [-0.36, 0.36]):
			dot(Vector2(ex * r, -r * 0.18) + look * eye_r * 0.45, eye_r * 0.5, Color("120810"))
	else:
		draw_rect(Rect2(-r * 0.2, -r * 0.18 - 2, r * 0.4, 4), Color("ff3a5a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	paint_held(e, p, r)
	draw_status(e, p, r)

## Second-parent inheritance draws one appendage/outer-body detail only.
## The first parent's complete face remains intact. 19 choices are enough to
## give sector-40 combinations recognizable silhouettes without N*N sprites.
func draw_hybrid_trait(ci: CanvasItem, c: Vector2, r: float, feature_name: String, accent: Color, feature_variant: int = 0) -> void:
	if MonsterModels.part(ci, c, r, feature_name, accent):
		return
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
func draw_enemy_body(ci: CanvasItem, kind: String, elite: bool, r: float, col: Color, flash: bool, held: bool = true) -> void:
	if BossFight.is_boss_kind(kind):
		# Portrait pose for atlases and the Bestiary (scaled to fit a cell).
		BossModels.draw(ci, kind, r * 0.82, {"t": 0.6, "flash": flash})
		return
	var fusion: Array = g.enemy_db[kind].get("mix", []) if kind.begins_with("mix_") else [kind, kind]
	if fusion.size() >= 2 and MonsterKit.has(str(fusion[0])) and MonsterKit.has(str(fusion[1])):
		# Street monsters and true fusions: body of the first parent wearing
		# the second parent's skin, face and decorations.
		MonsterKit.draw(ci, str(fusion[0]), str(fusion[1]), r, flash, held)
		if elite:
			var crown_y = -r - 4.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, crown_y + 4), Vector2(-r * 0.55, crown_y - 10), Vector2(-r * 0.25, crown_y - 3),
				Vector2(0, crown_y - 13), Vector2(r * 0.25, crown_y - 3), Vector2(r * 0.55, crown_y - 10), Vector2(r * 0.5, crown_y + 4)]), Color("ffd24d"))
		return
	var body = Color.WHITE if flash else col
	var dark = col.darkened(0.45)
	var parts: Dictionary = g.enemy_db[kind].get("look", {})
	var custom = MonsterModels.has(kind)
	var slime = not custom and kind in ["blob", "zoomer", "chonk", "spitter", "mitosis", "mini", "mama", "chonkzilla", "kingblob", "ashwing"]
	if custom:
		MonsterModels.draw(ci, kind, r, body, dark)
	if slime:
		for k in range(5):
			var a = TAU * float(k) / 5.0
			var lobe = Vector2(cos(a) * r * 0.62, sin(a) * r * 0.58)
			ci.draw_circle(lobe, r * (0.43 if k % 2 == 0 else 0.36), dark)
			ci.draw_circle(lobe + Vector2(0, -2), r * (0.39 if k % 2 == 0 else 0.32), body)
	match ("" if custom else kind):
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
	match ("#custom" if custom else kind):
		"#custom":
			pass
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
	match ("" if custom else kind):
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
			dot(fp, 4.0, Color(1.0, 0.5 + 0.2 * k, 0.1, 0.8))
	if float(e["poison"]) > 0.0:
		dot(p + Vector2(r * 0.8, -r * 0.7 - fmod(g.anim_t * 20.0, 10.0)), 3.0, Color("8dff6b"))
	if float(e["shock"]) > 0.0 and fmod(g.anim_t * 10.0 + float(e["phase"]), 1.0) < 0.5:
		zigzag(p + Vector2(-r, -r * 0.3), p + Vector2(r, r * 0.2), Color("bfe8ff"), 2.0)
	if float(e["bleed"]) > 0.0:
		dot(p + Vector2(-r * 0.5, r * 0.6 + fmod(g.anim_t * 25.0, 8.0)), 2.5, Color("ff3a5a"))
	if float(e["wet"]) > 0.0:
		dot(p + Vector2(r * 0.4, -r * 0.9 + fmod(g.anim_t * 18.0, 12.0)), 2.5, Color("6bb8ff"))
	if float(e["mark"]) > 0.0:
		draw_arc(p, r + 6, g.anim_t * 2.0, g.anim_t * 2.0 + TAU * 0.8, 16, Color("ff5a5a"), 2.0)
	if float(e["stun"]) > 0.0 and float(e["frozen"]) <= 0.0:
		for k in range(3):
			var sp2 = p + Vector2.from_angle(g.anim_t * 6.0 + k * TAU / 3.0) * Vector2(r * 0.9, r * 0.3) + Vector2(0, -r - 6)
			dot(sp2, 3.0, Color("fff27a"))
	if float(e["bubble"]) > 0.0:
		dot(p, r + 10, Color(0.6, 0.9, 1.0, 0.18))
		draw_arc(p, r + 10, 0, TAU, 24, Color(0.85, 0.97, 1.0, 0.8), 2.0)
		dot(p + Vector2(-r * 0.5, -r * 0.6), 4, Color(1, 1, 1, 0.8))

func paint_hero() -> void:
	var h = g.hero
	var hp: Vector2 = h["pos"]
	trail.push_front(hp)
	if trail.size() > 8:
		trail.pop_back()
	var dashing = float(h["dash_t"]) > 0.0
	if dashing or float(h["dash_window"]) > 0.15:
		for i in range(1, trail.size()):
			dot(P(trail[i]), 12.0 * (1.0 - i / 8.0), Color(0.4, 0.9, 1.0, 0.35 * (1.0 - i / 8.0)))
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
	dot(Vector2.ZERO, 14.0 * scale, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Each runner is their own model; arms reach the real grips of the guns.
	var held: Array = []
	for i in range(g.guns.size()):
		var w = g.guns[i]
		held.append({"id": str(w["id"]), "aim": Weapons.aim_for_slot(g, i), "muzzle": P(Weapons.muzzle_pos(g, i)),
			"firing": float(w["flash"]) > 0.0, "charge": float(w.get("charge", 0.0)), "evolved": bool(w["evolved"]),
			# A thrown Returner / Razor Disc is out of your hand until caught.
			"hidden": str(g.weapon_db[w["id"]]["kind"]) in ["disc", "boomerang"] and int(w["ammo"]) <= 0})
	var bash_phase := -1.0
	if float(h.get("bash_t", 0.0)) > 0.0:
		bash_phase = 1.0 - clampf(float(h["bash_t"]) / 0.23, 0.0, 1.0)
	HeroModels.draw_rig(self, str(g.selected_character), p, aim, scale, held,
		{"t": g.anim_t, "step": sin(g.anim_t * 13.0) * (3.0 if bool(h["moving"]) else 0.0), "blink": blink,
		"flash": float(h["flash"]) > 0.0, "bash": bash_phase, "bash_dir": h.get("bash_dir", aim)})
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var muzzle = P(Weapons.muzzle_pos(g, i))
		if float(w["flash"]) > 0.0:
			dot(muzzle, 9.0, Color(1, 0.95, 0.6, 0.8))
			dot(muzzle, 5.0, Color.WHITE)
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

## A Burrower tunnelling: a moving dirt mound; when it stops it shakes and
## cracks for a moment before it erupts.
func paint_burrow_mound(e: Dictionary, p: Vector2, r: float) -> void:
	var rumble: bool = float(e.get("rumble_t", 0.0)) > 0.0
	var shake := Vector2(sin(g.anim_t * 60.0), cos(g.anim_t * 53.0)) * (3.0 if rumble else 0.0)
	draw_set_transform(p + shake + Vector2(0, r * 0.4), 0.0, Vector2(1.0, 0.6))
	dot(Vector2.ZERO, r * 1.15, Color("3a2a1c"))
	dot(Vector2(0, -r * 0.2), r * 0.95, Color("7a5f40"))
	dot(Vector2(-r * 0.3, -r * 0.45), r * 0.3, Color("9c7a52"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rumble:
		var k: float = 1.0 - float(e["rumble_t"]) / 0.55
		for i in range(5):
			var a := TAU * float(i) / 5.0 + 0.4
			draw_line(p + Vector2.from_angle(a) * r * 0.5, p + Vector2.from_angle(a) * r * (0.9 + k * 1.6), Color("e4b873", 0.8), 2.5)
		draw_arc(p, 56.0, 0.0, TAU, 40, Color("e4b873", 0.25 + 0.45 * k), 2.0, true)

## Mama Blob's egg: speckled, wobbling harder and cracking as it nears hatching.
func paint_mama_egg(p: Vector2, r: float, ready: float, health: float) -> void:
	var wob: float = sin(g.anim_t * (6.0 + ready * 18.0)) * ready * 0.25
	draw_set_transform(p + Vector2(3, 6), 0.0, Vector2(1.0, 0.45))
	dot(Vector2.ZERO, r * 0.8, Color(0, 0, 0, 0.3))
	draw_set_transform(p, wob, Vector2(0.85, 1.05))
	dot(Vector2.ZERO, r + 2.0, Color("4a2638"))
	dot(Vector2.ZERO, r, Color("ffd9e6"))
	dot(Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.7))
	for i in range(5):
		var sp := Vector2(sin(float(i) * 2.7) * r * 0.55, cos(float(i) * 1.9) * r * 0.55)
		dot(sp, r * 0.12, Color("ff8bb8"))
	if ready > 0.5:
		var crack := PackedVector2Array([Vector2(-r * 0.6, -r * 0.1), Vector2(-r * 0.2, r * 0.15), Vector2(r * 0.1, -r * 0.15), Vector2(r * 0.55, r * 0.1)])
		draw_polyline(crack, Color("4a2638"), 2.0, true)
	if ready > 0.8:
		draw_polyline(PackedVector2Array([Vector2(r * 0.1, -r * 0.15), Vector2(r * 0.2, -r * 0.6)]), Color("4a2638"), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if health < 1.0:
		draw_arc(p, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(health, 0.0, 1.0), 24, Color(1, 1, 1, 0.6), 2.0, true)

## Ashwing's phoenix egg: dark shell with glowing cracks and licking flames.
func paint_phoenix_egg(p: Vector2, r: float, ready: float) -> void:
	var glow := 0.5 + 0.5 * sin(g.anim_t * (5.0 + ready * 14.0))
	for k in range(3):
		dot(p, r * (1.3 + k * 0.25), Color(1.0, 0.45, 0.1, 0.06 + 0.05 * ready * glow))
	for i in range(5):
		var a := -PI * 0.5 + (float(i) - 2.0) * 0.45
		var flick := 0.7 + 0.3 * sin(g.anim_t * 14.0 + i)
		var base := p + Vector2.from_angle(a) * r * 0.75
		draw_colored_polygon(PackedVector2Array([base + Vector2.from_angle(a + PI * 0.5) * 5.0, base + Vector2.from_angle(a) * r * 0.6 * flick, base - Vector2.from_angle(a + PI * 0.5) * 5.0]), Color(1.0, 0.55, 0.15, 0.85))
	draw_set_transform(p, 0.0, Vector2(0.82, 1.05))
	dot(Vector2.ZERO, r + 2.0, Color("2a0f0a"))
	dot(Vector2.ZERO, r, Color("6b2418"))
	dot(Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 0.7, 0.5, 0.35))
	var hot := Color(1.0, 0.75, 0.3, 0.5 + 0.5 * glow)
	draw_polyline(PackedVector2Array([Vector2(-r * 0.5, -r * 0.6), Vector2(-r * 0.1, -r * 0.2), Vector2(-r * 0.35, r * 0.25), Vector2(0, r * 0.7)]), hot, 2.5, true)
	if ready > 0.4:
		draw_polyline(PackedVector2Array([Vector2(r * 0.55, -r * 0.4), Vector2(r * 0.15, 0), Vector2(r * 0.4, r * 0.45)]), hot, 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A Sapper's sticky bomb on the player: blinking faster as it counts down.
func paint_sticky_bomb() -> void:
	if g.hero.is_empty() or not g.hero.has("sticky_bomb"):
		return
	var bomb: Dictionary = g.hero["sticky_bomb"]
	var p := P(Vector2(g.hero["pos"]) + Vector2(10, -14))
	var left: float = clampf(float(bomb["t"]) / 2.2, 0.0, 1.0)
	dot(p, 9.0, Color("1d1f26"))
	dot(p + Vector2(-2, -2), 3.0, Color("6b7080"))
	var blink := fmod(g.anim_t * (3.0 + (1.0 - left) * 14.0), 1.0) < 0.5
	dot(p + Vector2(0, -9), 3.0, Color("ff3b3b") if blink else Color("5a1414"))
	draw_arc(P(g.hero["pos"]), 24.0, -PI * 0.5, -PI * 0.5 + TAU * left, 28, Color("ff7a46", 0.9), 3.0, true)

func paint_orbitals() -> void:
	paint_sticky_bomb()
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
		dot(sp, 9, Color(0.55, 0.97, 1.0, 0.3))
		dot(sp, 6, Color("bffaff"))

func saw_blade(p: Vector2, r: float, rot: float, c: Color) -> void:
	var pts = PackedVector2Array()
	for k in range(16):
		var rr = r if k % 2 == 0 else r * 0.68
		pts.append(p + Vector2.from_angle(rot + k * TAU / 16.0) * rr)
	draw_colored_polygon(pts, c)
	dot(p, r * 0.35, Color("404858"))

func paint_pets() -> void:
	for t in g.turrets:
		var p = P(t["pos"])
		var a: Vector2 = t["aim"]
		var side = a.orthogonal()
		dot(p + Vector2(0, 4), 15, Color(0, 0, 0, 0.3))
		for s in [-1.0, 1.0]:
			draw_line(p + side * s * 8.0, p + side * s * 12.0 + Vector2(0, 9), Color("65758e"), 3.0)
		dot(p, 12, Color("28364f"))
		dot(p, 9, Color("5b7190"))
		draw_line(p + a * 2.0, p + a * 19.0, Color("263243"), 9.0)
		draw_line(p + a * 3.0, p + a * 18.0, Color("a8d8e8"), 5.0)
		dot(p, 4, Color("4fe0ff"))
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
				dot(cp + Vector2(0, 4), 14.0, Color("cbb8ff", 0.13))
				dot(cp, 12.0, Color("b6a1ff", 0.21))
				dot(cp + Vector2(0, -2), 9.0, Color("e0d4ff", 0.51))
				for side in [-1.0, 1.0]:
					dot(cp + Vector2(side * 3.3, -3) + aim * 1.5, 1.7, Color("412f62", 0.88))
				draw_line(cp + aim * 5.0, cp + aim * 18.0, Color("ddcaff", 0.72), 3.0)
				draw_arc(cp, 15.0, g.anim_t * 2.0, g.anim_t * 2.0 + PI, 15, Color("d8c8ff", 0.35), 1.5)
			"drone":
				var bob = sin(g.anim_t * 8.0 + float(pet["slot"])) * 3.0
				p.y += bob
				for s in [-1.0, 1.0]:
					dot(p + Vector2(s * 12.0, -4), 5.0, Color("252b3c"))
					draw_line(p + Vector2(s * 7.0, -9), p + Vector2(s * 17.0, -9), Color("b8d9e8"), 2.0)
				draw_rect(Rect2(p - Vector2(9, 6), Vector2(18, 12)), Color("405070") if g.st("dronerocket") <= 0 else Color("704040"))
				dot(p, 4.5, Color("172335"))
				dot(p, 2.5, Color("4fe0ff"))
			"intern":
				var a: Vector2 = pet.get("aim", Vector2.UP)
				var side = a.orthogonal().normalized()
				var stride = sin(g.anim_t * 12.0 + float(pet["slot"])) * 2.0
				for s in [-1.0, 1.0]:
					dot(p - a * (8.0 + stride * s) + side * s * 4.0, 3.0, Color("27304a"))
				dot(p, 9.5, Color("1f2c47"))
				dot(p, 7.5, Color("7397c2"))
				draw_line(p - side * 5.0, p + side * 5.0, Color("e5eff8"), 2.0)
				dot(p + a * 5.0, 6.5, Color("402d35"))
				dot(p + a * 5.0, 5.4, Color("ffd0aa"))
				var eyes = p + a * 8.0
				if a.y > -0.35:
					for s in [-1.0, 1.0]:
						dot(eyes + side * s * 2.3, 1.1, Color("202535"))
					draw_arc(p + a * 5.0, 3.2, 3.5, 5.8, 8, Color("5f383d"), 1.2)
				else:
					draw_arc(p + a * 5.0, 4.2, PI, TAU, 8, Color("302b3a"), 2.0)
				dot(p - side * 4.0 - a * 1.0, 2.2, Color("ffe5d2"))
				dot(p + side * 4.0 - a * 1.0, 2.2, Color("ffe5d2"))
				draw_line(p + a * 3.0, p + a * 16.0, Color("273a41"), 5.0)
				draw_line(p + a * 4.0, p + a * 17.0, Color("9dff9a"), 2.5)
				dot(p + side * 7.0 + a * 7.0 - Vector2(0, fmod(g.anim_t * 5.0, 3.0)), 1.8, Color("9fe8ff"))
			"chicken":
				var hop = absf(sin(g.anim_t * 9.0)) * 4.0
				dot(p + Vector2(-5, -hop - 1), 5.0, Color("e9d9b6"))
				dot(p + Vector2(0, -hop), 9, Color("fff8e0"))
				dot(p + Vector2(-2, -hop + 2), 5.0, Color("e7e1d0"))
				dot(p + Vector2(5, -hop - 6), 5, Color("fff8e0"))
				dot(p + Vector2(5, -hop - 11), 3, Color("ff3a3a"))
				dot(p + Vector2(2, -hop - 11), 2.3, Color("dd263b"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(9, -hop - 7), p + Vector2(14, -hop - 5), p + Vector2(9, -hop - 4)]), Color("ffb020"))
				dot(p + Vector2(6, -hop - 7), 1.2, Color.BLACK)
				for s in [-1.0, 1.0]:
					draw_line(p + Vector2(s * 4.0, 7 - hop), p + Vector2(s * 4.0, 12 - hop), Color("e89b32"), 1.5)
			"dog":
				dot(p, 10, Color("82512e"))
				dot(p + Vector2(0, -2), 8.5, Color("c88a4a"))
				dot(p + Vector2(1, 1), 4.5, Color("e2ae6c"))
				dot(p + Vector2(8, -6), 7, Color("c88a4a"))
				dot(p + Vector2(4, -11), 4, Color("654027"))
				dot(p + Vector2(11, -11), 3, Color("654027"))
				dot(p + Vector2(12, -5), 2, Color.BLACK)
				dot(p + Vector2(8, -7), 1.4, Color("28232d"))
				draw_arc(p + Vector2(8, -3), 3, 0.1, PI - 0.1, 8, Color("56372c"), 1.5)
				draw_line(p + Vector2(-9, -2), p + Vector2(-15, -8 + sin(g.anim_t * 20.0) * 3), Color("c88a4a"), 3.0)
			"saw":
				saw_blade(p, 15.0, g.anim_t * 20.0, Color("d8dce8"))
			"decoy":
				var pulse = 0.5 + 0.3 * sin(g.anim_t * 20.0)
				dot(p, 16, Color(0.7, 0.5, 1.0, pulse * 0.35))
				dot(p, 12, Color("37254f"))
				dot(p + Vector2(0, -1), 9, Color("b48cff"))
				for s in [-1.0, 1.0]:
					dot(p + Vector2(s * 3.0, -2), 1.8, Color("241536"))
				draw_arc(p + Vector2(0, 2), 3.0, 0.2, PI - 0.2, 8, Color("4a265f"), 1.6)
				text_c("!", p + Vector2(0, -18), 17, Color("ffd24d"), 3)

# ================================================================= shots
## Fast GPU-free streaks. No extra Nodes or particle emitters per shot.
## Every projectile remains readable without this optional cosmetic layer.
## Your own projectiles draw a little dimmer than enemy fire, so enemy
## bullets always read first. Set per shot in paint_shots.
var shot_dim := 1.0

func dimc(col: Color) -> Color:
	return Color(col, col.a * shot_dim)

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
			draw_line(lane - direction * length, lane, dimc(Color(color, 0.65)), 1.6)
	elif pattern in ["double_tap", "burst"]:
		draw_line(p - direction * length * 1.1 + side * 3.3, p - direction * 3.0 + side * 3.3, dimc(Color("fff1b6", 0.55)), 1.6)
		draw_line(p - direction * length * 0.75 - side * 3.3, p - direction * 2.0 - side * 3.3, dimc(Color(color, 0.65)), 1.5)
	match style:
		"fire":
			draw_line(p - direction * length, p, dimc(Color("ff4e20", 0.25)), radius * 2.0)
			draw_line(p - direction * length * 0.7, p, dimc(Color("ffba55", 0.72)), radius * 0.75)
			if q != "low":
				for i in range(2):
					var jitter = sin(t * 23.0 + float(i) * 3.3 + float(s["phase"])) * (4.0 + i * 2.0)
					dot(p - direction * (8.0 + i * 11.0) + side * jitter, 1.7 + i * 0.3, dimc(Color("ffb264", 0.65)))
		"toxic":
			draw_line(p - direction * length, p, dimc(Color("5fbb4a", 0.28)), radius * 1.5)
			draw_line(p - direction * length * 0.57, p, dimc(Color("b7ff72", 0.8)), 2.5)
			if q != "low":
				for i in range(2):
					var wobble = sin(t * 11.0 + float(i) * 1.9 + float(s["phase"])) * 5.0
					dot(p - direction * (9.0 + i * 12.0) + side * wobble, 2.2, dimc(Color("c0ff80", 0.62)))
		"frost", "boss_frost":
			draw_line(p - direction * length, p, dimc(Color("62aeea", 0.3)), radius * 1.6)
			var diamond = PackedVector2Array([p + direction * 5.0, p + side * 4.0, p - direction * 10.0, p - side * 4.0])
			draw_colored_polygon(diamond, dimc(Color("c5faff", 0.84)))
			draw_line(p - direction * 13.0 + side * 3.0, p - direction * 19.0 - side * 2.0, dimc(Color.WHITE), 1.5)
		"shock", "boss_storm":
			var jitter = sin(t * 38.0 + float(s["phase"])) * 4.0
			draw_line(p - direction * length, p - direction * length * 0.5 + side * jitter, dimc(Color("69bfff", 0.75)), 2.0)
			draw_line(p - direction * length * 0.5 + side * jitter, p, dimc(Color("eafcff", 0.9)), 2.0)
			dot(p, 3.5, dimc(Color("f4fdff", 0.9)))
		"blast", "boss_ember":
			draw_line(p - direction * length * 0.9, p, dimc(Color("ff6c29", 0.5)), radius * 1.5)
			draw_line(p - direction * length * 0.46, p, dimc(Color("ffe09d", 0.85)), radius * 0.65)
			if q != "low":
				dot(p - direction * 10.0 + side * sin(t * 18.0 + float(s["phase"])) * 3.0, 2.3, dimc(Color("ffad53", 0.72)))
		"boss_void", "magic":
			draw_line(p - direction * length, p, dimc(Color("a873ff", 0.36)), radius * 1.5)
			draw_arc(p, radius + 4.0, t * 3.0, t * 3.0 + PI * 1.4, 13, dimc(Color("e7b4ff", 0.72)), 1.6)
			dot(p, radius * 0.4, dimc(Color("ffe0ff", 0.9)))
		"pierce":
			draw_line(p - direction * length * 1.3, p + direction * 4.0, dimc(Color("8c74e8", 0.22)), radius * 1.2)
			draw_line(p - direction * length * 1.15, p + direction * 4.0, dimc(Color("f5eaff", 0.88)), 2.2)
		"shard":
			var shard = PackedVector2Array([p + direction * 7.0, p + side * 3.0, p - direction * 8.0, p - side * 3.0])
			draw_colored_polygon(shard, dimc(Color("c4ffe4", 0.78)))
			draw_line(p - direction * length, p - direction * 8.0, dimc(Color("80eab5", 0.45)), 1.7)
		"ricochet":
			draw_line(p - direction * length * 0.8, p, dimc(Color("ffd879", 0.65)), 2.4)
			dot(p, radius * 0.7, dimc(Color("fff3ad", 0.42)))
		"heavy":
			draw_line(p - direction * length * 0.7, p, dimc(Color("ffa34e", 0.27)), radius * 1.5)
			draw_line(p - direction * length * 0.48, p, dimc(Color("ffe4a1", 0.82)), 3.2)
		"rapid":
			draw_line(p - direction * length * 0.6, p, dimc(Color("64ccff", 0.52)), 2.6)
			draw_line(p - direction * length * 0.24, p, dimc(Color("e8ffff", 0.86)), 1.4)
		"water":
			draw_line(p - direction * length * 0.5, p, dimc(Color("7de8ff", 0.36)), 2.2)
			draw_arc(p, radius + 2.0, t, t + PI * 1.4, 12, dimc(Color("c9ffff", 0.45)), 1.4)
		_:
			draw_line(p - direction * length * 0.67, p, dimc(Color(color, 0.52)), 2.4)


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
		shot_dim = 0.6 if bool(s["friendly"]) else 1.0
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
				if bool(s.get("acid_trail", false)):
					paint_acid_glob(s, p, d, r)
					continue
				if bool(s.get("spear", false)):
					# The Lancer's actual spear in flight, with a speed streak.
					draw_line(p - d * 70.0, p - d * 22.0, dimc(Color("c8d5ff", 0.35)), 6.0)
					var side: Vector2 = d.orthogonal()
					draw_line(p - d * 26.0, p + d * 10.0, dimc(Color("140d17")), 5.0, true)
					draw_line(p - d * 26.0, p + d * 10.0, dimc(Color("9a6a3c")), 2.6, true)
					var blade := PackedVector2Array([p + d * 26.0, p + d * 13.0 + side * 6.0, p + d * 6.0, p + d * 13.0 - side * 6.0])
					draw_colored_polygon(blade, dimc(Color("e8ecff")))
					blade.append(blade[0])
					draw_polyline(blade, dimc(Color("140d17")), 1.6, true)
					continue
				if bool(s.get("sticky_bomb", false)):
					# Spinning bomb with a lit fuse.
					var spin: float = float(s.get("t", 0.0)) * 12.0 + g.anim_t * 6.0
					dot(p, r + 3.0, dimc(Color("140d17")))
					dot(p, r + 1.0, dimc(Color("2a2c35")))
					draw_arc(p, r * 0.75, spin, spin + 2.3, 10, dimc(Color("ff7a46")), 2.5)
					var fuse: Vector2 = p + Vector2.from_angle(spin - 1.2) * (r + 5.0)
					draw_line(p + Vector2.from_angle(spin - 1.2) * r, fuse, dimc(Color("c8a060")), 2.0)
					dot(fuse, 3.0 + sin(g.anim_t * 30.0), dimc(Color("ffd24d")))
					continue
				# Enemy shots must always read first: a glow, a dark contrast rim,
				# a bright body and a white core.
				var enemy_color: Color = s["color"]
				dot(p, r + 7, Color(enemy_color, 0.32))
				dot(p, r + 2.2, Color(0.05, 0.02, 0.06, 0.85))
				dot(p, r, enemy_color)
				dot(p, r * 0.46, Color("fff7ec"))
				if str(s.get("vfx_style", "")).begins_with("boss_"):
					var pulse = 0.55 + 0.45 * sin(g.anim_t * 12.0 + float(s["phase"]))
					draw_arc(p, r + 5.5 + pulse * 2.0, g.anim_t * 2.0, g.anim_t * 2.0 + PI * 1.3, 16, dimc(Color(enemy_color, 0.8)), 2.1)
					for j in range(3):
						var a = g.anim_t * 2.8 + float(j) * TAU / 3.0
						dot(p + Vector2.from_angle(a) * (r + 5.0), 1.8, dimc(Color("fff5e8", 0.85)))
			"skull":
				dot(p, r + 4, dimc(Color(0.7, 0.4, 1.0, 0.3)))
				dot(p, r + 1, dimc(Color("e0d8f0")))
				dot(p + Vector2(-2.5, -1), 2, dimc(Color("301040")))
				dot(p + Vector2(2.5, -1), 2, dimc(Color("301040")))
			"rocket":
				draw_line(p - d * 22.0, p - d * 6.0, dimc(Color(1, 0.6, 0.2, 0.7)), 7.0)
				draw_line(p - d * 8.0, p + d * 8.0, dimc(Color("e8e8f0")), 8.0)
				dot(p + d * 8.0, 4.0, c)
			"grenade":
				dot(p, r, dimc(Color("405020")))
				dot(p - Vector2(2, 2), r * 0.6, c)
			"egg":
				draw_set_transform(p, float(s["spin"]), Vector2(0.8, 1.0))
				dot(Vector2.ZERO, r, dimc(Color("fff8e0")))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"flame":
				var k = clampf(float(s["life"]) / maxf(0.01, float(s["max_life"])), 0.0, 1.0)
				dot(p, r, dimc(Color(1.0, 0.35 + 0.4 * k, 0.1, 0.35 * k + 0.1)))
				dot(p, r * 0.5, dimc(Color(1.0, 0.9, 0.4, 0.5 * k)))
			"disc":
				dot(p, r + 3, dimc(Color(c, 0.25)))
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
					dimc(Color("d8f5ff", 0.72)))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-4.0, 1.8), Vector2(-9.0, 6.0 * flap),
					Vector2(-6.0, 9.0 * flap), Vector2(0.3, 3.0)]),
					dimc(Color("d8f5ff", 0.72)))
				# Pointed abdomen with two distinct thick black stripes.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-11.0, 0.0), Vector2(-7.6, -4.3),
					Vector2(-1.5, -5.0), Vector2(3.8, -3.5),
					Vector2(4.7, 0.0), Vector2(3.8, 3.5),
					Vector2(-1.5, 5.0), Vector2(-7.6, 4.3)]),
					dimc(Color("251b11")))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-9.0, 0.0), Vector2(-6.0, -3.6),
					Vector2(-1.5, -4.0), Vector2(3.0, -2.8),
					Vector2(3.5, 0.0), Vector2(3.0, 2.8),
					Vector2(-1.5, 4.0), Vector2(-6.0, 3.6)]),
					dimc(Color("ffd43f")))
				draw_line(Vector2(-4.8, -3.5), Vector2(-4.8, 3.5), dimc(Color("21170d")), 2.2)
				draw_line(Vector2(-0.8, -3.8), Vector2(-0.8, 3.8), dimc(Color("21170d")), 2.2)
				# Small head, eyes, antennae and the pointed tail.
				dot(Vector2(5.6, 0.0), 3.5, dimc(Color("281e10")))
				dot(Vector2(5.6, 0.0), 2.8, dimc(Color("ffe26c")))
				dot(Vector2(7.3, -1.3), 1.1, dimc(Color("151515")))
				draw_line(Vector2(6.4, -2.5), Vector2(7.8, -5.0), dimc(Color("2c2014")), 1.0)
				draw_line(Vector2(6.1, 2.7), Vector2(7.3, 5.0), dimc(Color("2c2014")), 1.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10.0, -1.5), Vector2(-14.0, 0.0),
					Vector2(-10.0, 1.5)]), dimc(Color("27211a")))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ball":
				dot(p, r, dimc(Color("3a2a5a")))
				dot(p, r - 2, dimc(Color("6a4aa0")))
				for k in range(3):
					dot(p + Vector2.from_angle(float(s["spin"]) * 0.3 + k * 0.6) * r * 0.45, 2.5, dimc(Color("1a1028")))
			"chicken":
				draw_set_transform(p, float(s["spin"]) * 0.6, Vector2.ONE)
				dot(Vector2.ZERO, r, dimc(Color("fff27a")))
				dot(Vector2(r * 0.6, -r * 0.5), r * 0.5, dimc(Color("fff27a")))
				dot(Vector2(r * 0.6, -r * 1.0), r * 0.3, dimc(Color("ff3a3a")))
				draw_colored_polygon(PackedVector2Array([Vector2(r, -r * 0.5), Vector2(r * 1.6, -r * 0.3), Vector2(r, -r * 0.2)]), dimc(Color("ffa020")))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bubble":
				dot(p, r, dimc(Color(0.6, 0.9, 1.0, 0.15)))
				draw_arc(p, r, 0, TAU, 20, dimc(Color(0.85, 0.97, 1.0, 0.85)), 2.0)
				dot(p + Vector2(-r * 0.4, -r * 0.4), r * 0.2, dimc(Color(1, 1, 1, 0.8)))
			"snow":
				dot(p, r + 2, dimc(Color(0.8, 0.95, 1.0, 0.3)))
				dot(p, r, dimc(Color("f0faff")))
				dot(p + Vector2(-r * 0.3, -r * 0.3), r * 0.3, dimc(Color.WHITE))
			"coin":
				var wx = absf(cos(float(s["spin"])))
				draw_set_transform(p, 0.0, Vector2(maxf(0.2, wx), 1.0))
				dot(Vector2.ZERO, r, dimc(Color("ffd24d")))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_line(p - d * 14.0, p, dimc(Color(1, 0.85, 0.3, 0.4)), 3.0)
			"car":
				var flip = -1.0 if v.x < 0 else 1.0
				draw_rect(Rect2(p.x - 34, p.y - 16, 68, 26), dimc(Color("ff5a8a")))
				draw_rect(Rect2(p.x - 18, p.y - 30, 34, 16), dimc(Color("ffd24d")))
				dot(p + Vector2(-20, 12), 8, dimc(Color("202028")))
				dot(p + Vector2(20, 12), 8, dimc(Color("202028")))
				dot(p + Vector2(4 * flip, -24), 6, dimc(Color("fff0e0")))
				dot(p + Vector2(8 * flip, -22), 3, dimc(Color("ff3a3a")))
				dot(p + Vector2(36 * flip, -6), 5, dimc(Color("fff27a")))
			_:
				if (bool(s["friendly"]) or bool(s.get("reflected", false))) and paint_gun_bullet(s, p, d, r, c):
					continue
				var tail = p - d * (10.0 + r * 2.5)
				if shot_index % trail_stride == 0:
					draw_line(tail, p, dimc(Color(c, 0.26)), r * 1.6)
				# Batch all common bullets using the existing white-dot atlas,
				# letting CanvasItem group matching sprites into GPU draws.
				if atlas != null and atlas_cell.has("#dot"):
					var tint = dimc(Color(1.0, 1.0, 1.0, 0.7)) if s["flags"].has("big") else c.lightened(0.3)
					dot_rect(Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), tint)
				else:
					dot(p, r, dimc(Color(1.0, 1.0, 1.0, 0.7)) if s["flags"].has("big") else c.lightened(0.3))

## Spitter's acid: a wobbling glob lobbed through the air above its ground
## shadow (the shadow is where it really is), dripping as it flies.
	shot_dim = 1.0

func paint_acid_glob(s: Dictionary, p: Vector2, d: Vector2, r: float) -> void:
	# Cheap enough for a crowd of Spitters: stretched circles with a
	# squash-and-stretch wobble instead of per-glob polygons.
	var life := maxf(0.05, float(s["max_life"]))
	var u := clampf(float(s["t"]) / life, 0.0, 1.0)
	var lift := sin(u * PI) * 26.0
	var size := r * (2.3 + 0.35 * sin(u * PI))
	draw_set_transform(p + Vector2(0, 3), 0.0, Vector2(1.0, 0.45))
	dot(Vector2.ZERO, size * (1.0 - lift / 60.0), Color(0.05, 0.2, 0.02, 0.45))
	var c := p - Vector2(0, lift)
	for k in range(2):
		var back := c - d * (size * (1.2 + k * 0.9)) + Vector2(0, k * 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		dot(back, size * (0.32 - k * 0.09), Color(0.55, 1.0, 0.35, 0.85 - k * 0.25))
	var wob := 0.12 * sin(float(s["t"]) * 14.0 + float(s["phase"]))
	draw_set_transform(c, d.angle(), Vector2(1.12 + wob, 0.9 - wob))
	dot(Vector2.ZERO, size, Color("2f5a12"))
	dot(Vector2.ZERO, size * 0.8, Color("9dff4a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	dot(c + Vector2(size * 0.25, size * 0.15), size * 0.22, Color(0.85, 1.0, 0.57, 0.8))
	dot(c + Vector2(-size * 0.35, -size * 0.35), size * 0.16, Color(1, 1, 1, 0.75))

## Bullet guns each get their own projectile silhouette. Returns false for
## guns that keep the shared batched dot.
func paint_gun_bullet(s: Dictionary, p: Vector2, d: Vector2, r: float, c: Color) -> bool:
	var n := d.orthogonal()
	match str(s["src"]):
		"revolver":
			# Heavy brass slug with a hot trail.
			draw_line(p - d * 22.0, p, dimc(Color(c, 0.35)), r * 2.2)
			draw_colored_polygon(PackedVector2Array([p + d * r * 2.2, p + n * r * 1.1, p - d * r * 1.6 + n * r * 1.1, p - d * r * 1.6 - n * r * 1.1, p - n * r * 1.1]), dimc(Color("ffcf5a")))
			draw_line(p - d * r, p + d * r * 1.4, dimc(Color("fff3c4")), 1.5)
		"smg":
			# Thin electric streak.
			draw_line(p - d * 18.0, p, dimc(Color(c, 0.5)), 2.0)
			draw_line(p - d * 6.0, p + d * 3.0, dimc(Color("e8fbff")), 2.5)
		"minigun":
			draw_line(p - d * 14.0, p + d * 2.0, dimc(Color("ffd36b", 0.85)), 3.5)
			draw_line(p - d * 5.0, p + d * 3.0, dimc(Color("fff6d8")), 2.0)
		"sniper":
			# Long white needle.
			draw_line(p - d * 46.0, p, dimc(Color(c, 0.3)), 3.0)
			draw_line(p - d * 16.0, p + d * 6.0, dimc(Color("ffffff")), 2.0)
		"nailgun":
			# A nail: shaft plus a flat head.
			draw_line(p - d * 9.0, p + d * 7.0, dimc(Color("c9ccd4")), 2.5)
			draw_line(p - d * 9.0 - n * 4.0, p - d * 9.0 + n * 4.0, dimc(Color("8a8f9c")), 3.0)
			draw_line(p + d * 7.0, p + d * 10.0, dimc(Color("e8eaf0")), 1.5)
		"pinball":
			# Chrome ball with a highlight.
			dot(p, r + 1.5, dimc(Color(0.1, 0.1, 0.12)))
			dot(p, r, dimc(Color("c9ced8")))
			dot(p + Vector2(-r * 0.35, -r * 0.35), r * 0.38, dimc(Color.WHITE))
		"shotgun":
			if not s["flags"].has("slug"):
				return false
			draw_line(p - d * 20.0, p, dimc(Color(c, 0.35)), r * 1.8)
			dot(p, r, dimc(Color("ffd08a")))
			dot(p, r * 0.5, dimc(Color("fff3d8")))
		_:
			return false
	return true

## Danmaku-style boss bullets: dark rim for contrast on any ground, a bright
## body and a white core. The drawn size is a little larger than the hitbox.
func paint_boss_bullet(s: Dictionary, p: Vector2, d: Vector2, r: float) -> void:
	var col: Color = s["color"]
	var vr := r * 1.3
	match str(s.get("shape", "orb")):
		"rice":
			draw_set_transform(p, d.angle(), Vector2(1.9, 0.85))
			dot(Vector2.ZERO, vr + 1.8, Color(0.05, 0.02, 0.06, 0.75))
			dot(Vector2.ZERO, vr, col)
			dot(Vector2.ZERO, vr * 0.5, Color("fffaf0"))
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
			dot(p, vr + 4.0, Color(col, 0.22))
			dot(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			dot(p, vr, Color("efe8f6"))
			dot(p + Vector2(-vr * 0.38, -vr * 0.1), vr * 0.28, col.darkened(0.5))
			dot(p + Vector2(vr * 0.38, -vr * 0.1), vr * 0.28, col.darkened(0.5))
		"big":
			dot(p, vr + 7.0, Color(col, 0.18))
			dot(p, vr + 2.2, Color(0.05, 0.02, 0.06, 0.8))
			dot(p, vr, col)
			dot(p + Vector2(-vr * 0.2, -vr * 0.2), vr * 0.5, Color(col.lightened(0.55)))
			dot(p + Vector2(-vr * 0.35, -vr * 0.35), vr * 0.18, Color(1, 1, 1, 0.9))
		"flame":
			var flick := 0.8 + 0.2 * sin(float(s["t"]) * 40.0 + float(s["phase"]))
			dot(p, vr * 1.5 * flick, Color(col, 0.25))
			dot(p, vr * flick, col)
			dot(p, vr * 0.45, Color("fff6c8"))
		"missile":
			draw_line(p - d * 26.0, p - d * 8.0, Color(1.0, 0.65, 0.25, 0.75), 7.0)
			draw_line(p - d * 10.0, p + d * 10.0, Color(0.05, 0.02, 0.06), 11.0)
			draw_line(p - d * 9.0, p + d * 9.0, Color("dfe2ea"), 7.0)
			dot(p + d * 9.0, 4.0, Color("ff4d4d"))
		"boulder":
			var spin_b := float(s["t"]) * 7.0 * signf(Vector2(s["vel"]).x)
			dot(p, vr + 2.5, Color(0.05, 0.02, 0.06, 0.85))
			dot(p, vr, Color("8a6648"))
			for i in range(3):
				var q := p + Vector2.from_angle(spin_b + TAU * float(i) / 3.0) * vr * 0.5
				dot(q, vr * 0.22, Color("6b4a33"))
			dot(p + Vector2(-vr * 0.3, -vr * 0.35), vr * 0.25, Color(1, 1, 1, 0.18))
		"gear":
			dot(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			draw_colored_polygon(BossModels.gear_pts(p, vr * 1.15, 6, float(s["spin"])), col)
			dot(p, vr * 0.4, Color("fff1d6"))
		_:
			dot(p, vr + 4.0, Color(col, 0.2))
			dot(p, vr + 1.8, Color(0.05, 0.02, 0.06, 0.8))
			dot(p, vr, col)
			dot(p, vr * 0.5, Color("fffaf0"))

func zigzag(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	# A jagged bolt that re-forks a few times a second, with a white-hot core
	# and one or two short side branches.
	var length := a.distance_to(b)
	var n := maxi(4, int(length / 16.0))
	var perp := (b - a).normalized().orthogonal()
	var seed := int(g.anim_t * 30.0) + int(a.x * 7.0 + b.y * 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array([a])
	var amp := clampf(length * 0.06, 4.0, 14.0)
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + perp * rng.randf_range(-amp, amp))
	pts.append(b)
	draw_polyline(pts, Color(c, 0.3), w * 3.2, true)
	draw_polyline(pts, c, maxf(1.5, w * 1.2), true)
	draw_polyline(pts, Color(1, 1, 1, 0.9), maxf(1.0, w * 0.45), true)
	for f in range(2):
		var from_i := rng.randi_range(1, pts.size() - 2)
		var start: Vector2 = pts[from_i]
		var dir := (b - a).normalized().rotated(rng.randf_range(-0.9, 0.9))
		var fork := PackedVector2Array([start])
		var q := start
		for j in range(3):
			q += dir * rng.randf_range(8.0, 16.0) + perp * rng.randf_range(-5.0, 5.0)
			fork.append(q)
		draw_polyline(fork, Color(c, 0.7), maxf(1.0, w * 0.6), true)

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
			dot(e, w * (0.95 + 0.28 * sin(g.anim_t * 23.0)), Color(c, 0.57 * shimmer))
			dot(e, maxf(1.5, w * 0.37), Color("fff8e9", 0.86 * shimmer))

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
			dot(p, maxf(2.0, r * 0.35), Color("fff8dc", alpha))
		"double_tap", "burst":
			# Two staggered mini flashes, visually different from parallel lanes.
			for i in range(2):
				var advance = 5.0 * i + k * 9.0 * i
				var center = p + dir * advance + side * (4.0 if i == 0 else -4.0)
				draw_line(center - dir * 4.0, center + dir * r * 1.7, Color(c, (0.95 - i * 0.24) * alpha), 3.6 if i == 0 else 2.6)
				dot(center + dir * r, 2.8, Color("fff7db", 0.8 * alpha))
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
			dot(p, r * 0.38 * alpha, Color.WHITE)
		"pierce":
			draw_line(p - dir * r * 1.2, p + dir * r * (2.2 + k), Color(c, 0.7 * alpha), 3.0)
			draw_line(p + side * r * 0.8, p - side * r * 0.8, Color("ffffff", 0.9 * alpha), 1.8)
		"bounce":
			# Corner flash indicates a trajectory change rather than a kill.
			draw_line(p - dir * r, p, Color("fff3b6", alpha), 3.0)
			draw_line(p, p + side * r * 1.45, Color(c, 0.95 * alpha), 2.8)
			draw_line(p, p - side * r * 1.1, Color(c, 0.72 * alpha), 2.0)
			dot(p, 2.5 * alpha, Color.WHITE)
		"split":
			draw_arc(p, r * (0.7 + k * 1.5), 0, TAU, 20, Color(c, 0.57 * alpha), 2.3)
			for j in range(5):
				var ray = dir.rotated((float(j) - 2.0) * 0.44)
				var start = p + ray * r * (0.35 + k)
				draw_line(start, start + ray * r * (1.1 + k), Color("caffea", alpha), 2.2)
				dot(start + ray * r * (1.1 + k), 1.8, Color(c, alpha))
		"expire":
			draw_arc(p, r * (1.0 + 0.8 * k), 0, TAU, 12, Color(c, 0.37 * alpha), 1.5)
		"boss_impact":
			dot(p, r * (0.4 + k * 0.7), Color(c, 0.22 * alpha))
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
					dot(p + ray * r * (1.3 + k), 2.2 * alpha, Color("baff75", alpha * 0.72))
				elif style in ["fire", "blast", "boss_ember"]:
					dot(p + ray * r * (1.4 + k), 1.8 * alpha, Color("ffd48b", alpha * 0.9))

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
				dot(p, radius * 1.22, Color("ed4018", 0.24 * fade))
				dot(p - forward * radius * 0.28, radius * 0.93, Color("ff6e23", 0.55 * fade))
				dot(p + forward * radius * 0.18, radius * 0.65, Color("ffaf31", 0.71 * fade))
				dot(p + forward * radius * 0.28, radius * 0.34,
					Color("ffeb81", 0.76 * fade * (1.0 - k * 0.6)))
				if k < 0.35:
					dot(p + forward * radius * 0.37, radius * 0.18,
						Color("fff8cb", 0.72 * fade))
			"projectile_vfx":
				paint_projectile_event(f, p, k)
			"spark":
				# A hot streak along its flight, not a dot.
				var sv: Vector2 = f["vel"]
				var tail_len: float = clampf(sv.length() * 0.035, 2.0, 18.0)
				var sd: Vector2 = sv.normalized() if sv.length() > 1.0 else Vector2.UP
				var width: float = float(f["size"]) * (1.0 - k)
				draw_line(p - sd * tail_len, p, Color(c, 0.85 * (1.0 - k)), maxf(1.0, width), true)
				dot(p, width * 0.55, Color(1, 1, 0.9, 1.0 - k))
			"ring":
				# A thick shockwave that thins as it expands.
				var e_k := ease_out(k)
				var rr = float(f["size"]) * (0.4 + e_k * 0.8)
				dot(p, rr, Color(c, 0.07 * (1.0 - k)))
				draw_arc(p, rr, 0, TAU, 40, Color(c, 0.9 * (1.0 - k)), 7.0 * (1.0 - k) + 1.5, true)
				draw_arc(p, rr * 0.92, 0, TAU, 40, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.5, true)
			"smoke":
				var sr = float(f["size"]) * (0.6 + k * 0.6)
				dot(p, sr, Color(0.16, 0.15, 0.17, 0.14 * (1.0 - k)))
			"slash":
				paint_slash(self, f, p, k, false)
			"blast":
				# Fireball with a ragged edge, a white-hot flash, then a thinning
				# shockwave. Smoke and debris are separate fx.
				var size_b = float(f["size"])
				var grow = ease_out(minf(1.0, k * 2.0))
				var r = size_b * (0.45 + 0.6 * grow)
				var fade = 1.0 - k
				var ball := PackedVector2Array()
				var seed_b = float(f["pos"].x) * 0.13
				for i in range(20):
					var th := TAU * float(i) / 20.0
					var wob := 1.0 + 0.07 * sin(th * 5.0 + seed_b + k * 6.0) + 0.04 * sin(th * 9.0 - seed_b)
					ball.append(p + Vector2.from_angle(th) * r * wob)
				# Your explosions stay readable but quieter than enemy attacks.
				draw_colored_polygon(ball, Color(c.darkened(0.15), 0.38 * fade))
				dot(p, r * 0.72, Color(c.lightened(0.25), 0.42 * fade))
				dot(p, r * 0.42 * (1.0 - k), Color(1.0, 0.95, 0.75, 0.7 * fade))
				var flash = maxf(0.0, 1.0 - k * 4.0)
				if flash > 0.0:
					dot(p, size_b * 0.5, Color(1, 1, 1, 0.4 * flash))
				draw_arc(p, size_b * (0.6 + 0.7 * ease_out(k)), 0, TAU, 44, Color(c.lightened(0.4), 0.55 * fade), 4.0 * fade + 1.0, true)
			"shock":
				draw_arc(p, float(f["size"]) * k, 0, TAU, 48, Color(c, 1.0 - k), 8.0 * (1.0 - k) + 1.0)
			"confetti":
				draw_set_transform(p, float(f["rot"]) + float(f["t"]) * 9.0, Vector2(1.0, 0.5))
				draw_rect(Rect2(-float(f["size"]), -float(f["size"]) * 0.5, float(f["size"]) * 2.0, float(f["size"])), Color(c, 1.0 - k * k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ghostflash":
				dot(p, float(f["size"]) * (1.0 + k), Color(c, 0.4 * (1.0 - k)))
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
				dot(q, 8, Color("c87830"))
				dot(q + Vector2(-2, -2), 4, Color("ffb84d"))
			"disco":
				var ball = p + Vector2(0, -float(f["size"]) * 0.6)
				dot(ball, 18, Color("d0d8e8"))
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
