extends RefCounted
## Shared drawing for cards: cut-corner boxes and vector category icons for cards that have no art yet.
## Every function takes the CanvasItem to draw on, so Hud (UI) and Visuals (shop stalls) look the same.

const CAT_HUE = {"volley": Color("4fe0ff"), "projectile": Color("ffd24d"), "chain": Color("ff8a3d"), "element": Color("7dff9a"),
	"auto": Color("9fb8ff"), "move": Color("5bead8"), "defense": Color("8ff8ff"), "loot": Color("ffcf4d"),
	"chaos": Color("ff8ad8"), "mastery": Color("c07bff"), "heal": Color("ff6b7a"), "shop": Color("ffd24d")}

static func hue(cat: String) -> Color:
	return CAT_HUE.get(cat, Color("8fa3c0"))

## Angular "cyber" box: top-left and bottom-right corners are cut. `radius` is the old rounded-corner
## size; it maps to the cut so every existing caller turns sharp without changes.
static func rbox(ci: CanvasItem, r: Rect2, fill: Color, radius: float = 14.0, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	cbox(ci, r, fill, radius * 0.7, border, bw)

static func cut_pts(r: Rect2, cut: float) -> PackedVector2Array:
	var p = r.position
	var e = r.end
	var c = minf(cut, minf(r.size.x, r.size.y) * 0.4)
	if c < 2.0:
		return PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)])
	return PackedVector2Array([p + Vector2(c, 0), Vector2(e.x, p.y), Vector2(e.x, e.y - c), e - Vector2(c, 0), Vector2(p.x, e.y), p + Vector2(0, c)])

static func cbox(ci: CanvasItem, r: Rect2, fill: Color, cut: float, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	if fill.a > 0.0:
		ci.draw_colored_polygon(cut_pts(r, cut), fill)
	if bw > 0 and border.a > 0.0:
		# Keep the stroke inside the shape, like the old StyleBox border.
		var pts = cut_pts(r.grow(-bw * 0.5), maxf(0.0, cut - bw * 0.3))
		pts.append(pts[0])
		ci.draw_polyline(pts, border, bw)

static func star_pts(c: Vector2, r: float, points: int = 5, inner: float = 0.45, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for k in range(points * 2):
		pts.append(c + Vector2.from_angle(rot + k * PI / points) * (r if k % 2 == 0 else r * inner))
	return pts

## Icon for a card category (or shop item) centred on c, roughly 2*s wide. No frame: it sits on the card itself.
static func glyph(ci: CanvasItem, cat: String, c: Vector2, s: float, col: Color) -> void:
	var dark = col.darkened(0.55)
	var w = maxf(2.0, s * 0.12)
	# soft halo
	for k in range(3):
		ci.draw_circle(c, s * (1.15 - k * 0.18), Color(col, 0.06 + k * 0.04))
	match cat:
		"volley":
			for a in [-0.5, 0.0, 0.5]:
				var d = Vector2.UP.rotated(a)
				var tip = c + Vector2(0, s * 0.55) + d * s * 1.2
				ci.draw_line(c + Vector2(0, s * 0.55), tip, col, w * 1.6)
				ci.draw_circle(tip, w * 1.6, Color.WHITE)
		"projectile":
			var body = Rect2(c + Vector2(-s * 0.3, -s * 0.2), Vector2(s * 0.6, s * 0.95))
			rbox(ci, body, col, s * 0.08)
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.3, col.lightened(0.25))
			ci.draw_rect(Rect2(body.position.x, body.end.y - s * 0.2, body.size.x, s * 0.12), dark)
		"chain":
			ci.draw_colored_polygon(star_pts(c, s, 8, 0.5, 0.2), col)
			ci.draw_circle(c, s * 0.38, Color.WHITE)
			ci.draw_circle(c, s * 0.22, col.lightened(0.3))
		"element":
			var pts = PackedVector2Array()
			for k in range(24):
				var t = float(k) / 24.0 * TAU
				var rr = s * (0.62 + 0.4 * pow(maxf(0.0, -cos(t)), 3.0))
				pts.append(c + Vector2(sin(t) * s * 0.62 * (1.0 - 0.35 * pow(maxf(0.0, -cos(t)), 2.0)), -cos(t) * rr + s * 0.2))
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c + Vector2(0, s * 0.42), s * 0.3, Color.WHITE)
		"auto":
			for k in range(4):
				var p = c + Vector2.from_angle(PI * 0.25 + k * PI * 0.5) * s * 0.72
				ci.draw_line(c, p, dark, w * 1.4)
				ci.draw_circle(p, s * 0.26, col)
				ci.draw_circle(p, s * 0.1, Color.WHITE)
			ci.draw_circle(c, s * 0.42, col.lightened(0.2))
			ci.draw_circle(c, s * 0.18, dark)
		"move":
			for k in range(2):
				var o = c + Vector2(0, s * (0.35 - k * 0.6))
				ci.draw_polyline(PackedVector2Array([o + Vector2(-s * 0.7, s * 0.35), o + Vector2(0, -s * 0.3), o + Vector2(s * 0.7, s * 0.35)]), col if k == 1 else col.darkened(0.25), w * 2.2)
		"defense":
			var pts2 = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(s * 0.7, s * 0.3),
				c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.3), c + Vector2(-s * 0.8, -s * 0.6)])
			ci.draw_colored_polygon(pts2, col)
			var inner = PackedVector2Array()
			for p in pts2:
				inner.append(c + (p - c) * 0.6)
			ci.draw_colored_polygon(inner, col.lightened(0.35))
		"loot":
			for k in range(3):
				var cc = c + Vector2((k - 1) * s * 0.28, s * 0.35 - k * s * 0.3)
				ci.draw_circle(cc, s * 0.5, dark)
				ci.draw_circle(cc + Vector2(0, -s * 0.06), s * 0.48, col)
				ci.draw_circle(cc + Vector2(0, -s * 0.06), s * 0.3, col.lightened(0.3))
		"chaos", "shop":
			var die = Rect2(c - Vector2(s * 0.75, s * 0.75), Vector2(s * 1.5, s * 1.5))
			rbox(ci, die, Color.WHITE, s * 0.3)
			rbox(ci, die.grow(-w), col.lightened(0.6), s * 0.26)
			for p in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(0, 0), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
				ci.draw_circle(c + p * s, s * 0.13, dark)
		"mastery":
			var crown = PackedVector2Array([c + Vector2(-s * 0.85, s * 0.5), c + Vector2(-s * 0.85, -s * 0.45), c + Vector2(-s * 0.4, 0),
				c + Vector2(0, -s * 0.8), c + Vector2(s * 0.4, 0), c + Vector2(s * 0.85, -s * 0.45), c + Vector2(s * 0.85, s * 0.5)])
			ci.draw_colored_polygon(crown, col)
			for p in [Vector2(-0.85, -0.45), Vector2(0, -0.8), Vector2(0.85, -0.45)]:
				ci.draw_circle(c + p * s, s * 0.15, Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, s * 0.32), Vector2(s * 1.7, s * 0.18)), col.darkened(0.3))
		"heal":
			heart(ci, c, s * 0.85, col)
		"locked":
			rbox(ci, Rect2(c + Vector2(-s * 0.6, -s * 0.1), Vector2(s * 1.2, s * 0.95)), Color("8fa3c0"), s * 0.15)
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.38, PI, TAU, 16, Color("8fa3c0"), maxf(3.0, s * 0.16))
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.12, Color(0.05, 0.05, 0.1))
		_:
			ci.draw_colored_polygon(star_pts(c, s), col)

static func heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.5, col)
	ci.draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.5, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.92, 0), c + Vector2(s * 0.92, 0), c + Vector2(0, s * 0.95)]), col)
	ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.32), s * 0.16, Color(1, 1, 1, 0.6))

## Map node icons: swords, horned skull, flame, coin bag, campfire, chest, boss crown.
static func node_icon(ci: CanvasItem, t: String, c: Vector2, s: float, col: Color) -> void:
	var w = maxf(3.0, s * 0.18)
	match t:
		"fight":
			for k in [-1, 1]:
				var a = c + Vector2(-s * 0.8 * k, s * 0.8)
				var b = c + Vector2(s * 0.8 * k, -s * 0.8)
				ci.draw_line(a, b, col, w)
				var guard = a + (b - a) * 0.25
				var perp = (b - a).normalized().orthogonal() * s * 0.32
				ci.draw_line(guard - perp, guard + perp, col, w)
		"elite", "boss":
			if t == "boss":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.5), c + Vector2(-s * 0.8, -s * 1.15), c + Vector2(-s * 0.4, -s * 0.75),
					c + Vector2(0, -s * 1.2), c + Vector2(s * 0.4, -s * 0.75), c + Vector2(s * 0.8, -s * 1.15), c + Vector2(s * 0.8, -s * 0.5)]), Color("ffd24d"))
			else:
				for k in [-1, 1]:
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.45 * k, -s * 0.5), c + Vector2(s * 1.0 * k, -s * 1.1), c + Vector2(s * 0.75 * k, -s * 0.25)]), col)
			ci.draw_circle(c + Vector2(0, -s * 0.05), s * 0.78, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.45), Vector2(s * 0.9, s * 0.4)), col)
			for k in [-1, 1]:
				ci.draw_circle(c + Vector2(s * 0.32 * k, 0), s * 0.22, Color(0.05, 0.05, 0.1))
			for k in range(3):
				ci.draw_line(c + Vector2((k - 1) * s * 0.25, s * 0.5), c + Vector2((k - 1) * s * 0.25, s * 0.82), Color(0.05, 0.05, 0.1), maxf(2.0, s * 0.08))
		"hell":
			glyph(ci, "element", c, s, col)
		"event":
			ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, PI * 1.05, PI * 2.25, 16, col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.12, s * 0.05), c + Vector2(0, s * 0.35), col, w * 1.3)
			ci.draw_circle(c + Vector2(0, s * 0.75), w * 0.9, col)
		"shop":
			glyph(ci, "loot", c, s * 0.9, col)
		"rest":
			ci.draw_line(c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, s * 0.5), Color("8a5a3a"), w * 1.2)
			ci.draw_line(c + Vector2(-s * 0.9, s * 0.5), c + Vector2(s * 0.9, s * 0.8), Color("6b4329"), w * 1.2)
			glyph(ci, "element", c + Vector2(0, -s * 0.15), s * 0.75, col)
		"treasure":
			var body = Rect2(c + Vector2(-s * 0.9, -s * 0.2), Vector2(s * 1.8, s * 1.0))
			rbox(ci, body, col.darkened(0.25), s * 0.15)
			rbox(ci, Rect2(c + Vector2(-s * 0.95, -s * 0.75), Vector2(s * 1.9, s * 0.62)), col, s * 0.3)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.35), Vector2(s * 0.3, s * 0.45)), Color("ffd24d"))
		_:
			ci.draw_circle(c, s * 0.6, col)
