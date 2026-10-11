extends RefCounted
## Distinct silhouettes for street monsters that used to be the same round
## slime in different colours. Every model keeps the standard eye positions
## (+-0.36r, -0.18r) so live pupils and mutation traits still line up.
## Drawn once into the enemy atlas at the canvas origin.

const INK := Color(0.08, 0.05, 0.09)
const KINDS = ["blob", "zoomer", "mini", "mitosis", "spitter", "leech", "siren", "nurse", "skitter", "chonk"]

static func has(kind: String) -> bool:
	return kind in KINDS

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color = INK, w: float = 2.5) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, w, true)

static func blob_pts(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var th := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(th) * rx, sin(th) * ry))
	return pts

static func gloss(ci: CanvasItem, r: float) -> void:
	ci.draw_circle(Vector2(-r * 0.42, -r * 0.5), maxf(2.0, r * 0.14), Color(1, 1, 1, 0.42))

## Body and mouth. Eye whites are drawn afterwards by Visuals.
static func draw(ci: CanvasItem, kind: String, r: float, body: Color, dark: Color) -> void:
	match kind:
		"blob":
			# A jelly drip: pointed top, wide wobbly base, a drip running off.
			var pts := PackedVector2Array()
			for i in range(28):
				var th := TAU * float(i) / 28.0
				var k := 1.0 + 0.22 * maxf(0.0, -sin(th)) * maxf(0.0, -sin(th))
				pts.append(Vector2(cos(th) * r * (1.05 - 0.3 * maxf(0.0, -sin(th))), sin(th) * r * 0.95 * k))
			poly(ci, pts, body, dark.darkened(0.3), 3.0)
			ci.draw_circle(Vector2(r * 0.72, r * 0.85), r * 0.17, body)
			ci.draw_line(Vector2(r * 0.66, r * 0.6), Vector2(r * 0.72, r * 0.82), body, r * 0.22)
			gloss(ci, r)
			ci.draw_arc(Vector2(0, r * 0.35), r * 0.28, 0.25, PI - 0.25, 10, Color("6c2946"), 2.5)
		"zoomer":
			# A sleek dart: pointed nose, swept fins and a speed tail.
			for side in [-1.0, 1.0]:
				poly(ci, PackedVector2Array([Vector2(side * r * 0.55, r * 0.1), Vector2(side * r * 1.35, r * 0.75), Vector2(side * r * 0.6, r * 0.65)]), dark)
			poly(ci, PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 0.85, -r * 0.1), Vector2(r * 0.7, r * 0.7), Vector2(0, r * 1.05),
				Vector2(-r * 0.7, r * 0.7), Vector2(-r * 0.85, -r * 0.1)]), body, dark.darkened(0.3), 3.0)
			for k in range(3):
				ci.draw_line(Vector2((k - 1) * r * 0.25, r * 1.05), Vector2((k - 1) * r * 0.35, r * 1.5), Color(body, 0.55), 2.0)
			gloss(ci, r)
			ci.draw_line(Vector2(-r * 0.32, r * 0.36), Vector2(r * 0.4, r * 0.24), Color("66323c"), 2.5)
		"mini":
			# Tiny scrappy slime with a spiky tuft.
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, 1), r - 2.0, body)
			for k in range(3):
				var x := (k - 1) * r * 0.32
				poly(ci, PackedVector2Array([Vector2(x - r * 0.18, -r * 0.82), Vector2(x, -r * 1.35 + absf(k - 1) * r * 0.15), Vector2(x + r * 0.18, -r * 0.82)]), body, dark, 2.0)
			gloss(ci, r)
			ci.draw_line(Vector2(-r * 0.3, r * 0.4), Vector2(r * 0.35, r * 0.3), Color("66323c"), 2.5)
		"mitosis":
			# Caught mid-division: two cells pinched at the waist.
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.45, r * 0.05), r * 0.82, dark)
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.45, r * 0.05), r * 0.76, Color(body, 0.92))
				ci.draw_circle(Vector2(side * r * 0.55, r * 0.35), r * 0.2, Color(dark, 0.55))
			ci.draw_line(Vector2(0, -r * 0.55), Vector2(0, r * 0.65), Color(dark, 0.6), 2.0)
			gloss(ci, r)
			ci.draw_circle(Vector2(0, r * 0.45), r * 0.15, Color("276c64"))
		"spitter":
			# A spout on top for lobbing acid, toxic bubbles in the body.
			poly(ci, PackedVector2Array([Vector2(-r * 0.28, -r * 0.7), Vector2(-r * 0.38, -r * 1.45), Vector2(r * 0.38, -r * 1.45), Vector2(r * 0.28, -r * 0.7)]), dark)
			ci.draw_circle(Vector2(0, -r * 1.45), r * 0.36, dark)
			ci.draw_circle(Vector2(0, -r * 1.45), r * 0.24, Color("d8ff91"))
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -1), r - 2.0, body)
			for k in range(3):
				ci.draw_circle(Vector2((k - 1) * r * 0.45, r * 0.55 - absf(k - 1) * r * 0.1), r * 0.1, Color("d8ff91", 0.75))
			gloss(ci, r)
			ci.draw_circle(Vector2(0, r * 0.3), r * 0.2, Color("204010"))
		"leech":
			# A segmented worm rearing up, sucker mouth ringed with teeth.
			for k in range(3):
				var c := Vector2(0, r * (0.95 + k * 0.45))
				ci.draw_circle(c, r * (0.62 - k * 0.12), dark)
				ci.draw_circle(c, r * (0.54 - k * 0.12), body.darkened(0.08 * k))
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -1), r - 2.0, body)
			ci.draw_circle(Vector2(0, r * 0.4), r * 0.34, Color("3c145a"))
			for k in range(8):
				var a := TAU * float(k) / 8.0
				ci.draw_line(Vector2(0, r * 0.4) + Vector2.from_angle(a) * r * 0.34, Vector2(0, r * 0.4) + Vector2.from_angle(a) * r * 0.2, Color("f2e6ff"), 2.0)
			gloss(ci, r)
		"siren":
			# A cone-shell body with fin ears and a megaphone mouth.
			for side in [-1.0, 1.0]:
				poly(ci, PackedVector2Array([Vector2(side * r * 0.7, -r * 0.25), Vector2(side * r * 1.4, -r * 0.92), Vector2(side * r * 1.25, r * 0.4)]), Color("ad4f9b"))
			poly(ci, PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 1.0, r * 0.75), Vector2(-r * 1.0, r * 0.75)]), body, Color("7d3d76"), 3.0)
			for k in range(3):
				ci.draw_line(Vector2(-r * (0.3 + k * 0.22), -r * 0.5 + k * r * 0.4), Vector2(r * (0.3 + k * 0.22), -r * 0.5 + k * r * 0.4), Color("7d3d76", 0.45), 2.0)
			poly(ci, PackedVector2Array([Vector2(-r * 0.18, r * 0.42), Vector2(-r * 0.45, r * 0.95), Vector2(r * 0.45, r * 0.95), Vector2(r * 0.18, r * 0.42)]), Color("ffd6f5"), Color("7d3d76"), 2.0)
		"nurse":
			# Medic: round with a red-cross satchel and a nurse cap band.
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -1), r - 2.0, body)
			ci.draw_rect(Rect2(r * 0.45, -r * 0.05, r * 0.75, r * 0.65), Color("e7f2f6"))
			ci.draw_rect(Rect2(r * 0.45, -r * 0.05, r * 0.75, r * 0.65), INK, false, 2.0)
			ci.draw_rect(Rect2(r * 0.74, r * 0.03, r * 0.16, r * 0.49), Color("e8394a"))
			ci.draw_rect(Rect2(r * 0.58, r * 0.2, r * 0.48, r * 0.16), Color("e8394a"))
			ci.draw_line(Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.6, r * 0.1), Color(1, 1, 1, 0.4), 3.0)
			gloss(ci, r)
			ci.draw_arc(Vector2(0, r * 0.4), r * 0.2, 0.3, PI - 0.3, 8, Color("52323c"), 2.2)
		"skitter":
			# Low beetle: shell split down the middle, four sprinting legs.
			for side in [-1.0, 1.0]:
				for k in range(2):
					var hip := Vector2(side * r * 0.6, r * (-0.1 + k * 0.55))
					ci.draw_polyline(PackedVector2Array([hip, hip + Vector2(side * r * 0.65, -r * 0.25 + k * r * 0.5), hip + Vector2(side * r * 1.0, r * 0.25 + k * r * 0.35)]), Color("d6faff"), 3.0, true)
			poly(ci, blob_pts(Vector2(0, r * 0.15), r * 0.9, r * 1.05), body, dark.darkened(0.3), 3.0)
			ci.draw_line(Vector2(0, -r * 0.2), Vector2(0, r * 1.15), dark, 2.5)
			ci.draw_arc(Vector2(0, r * 0.15), r * 0.75, PI * 0.15, PI * 0.85, 12, Color(1, 1, 1, 0.25), 2.0, true)
			gloss(ci, r)
		"chonk":
			# Squat sumo: wide body, belly, topknot and stubby legs.
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.55, r * 0.85), r * 0.3, dark)
			poly(ci, blob_pts(Vector2(0, r * 0.08), r * 1.15, r * 0.92), body, dark.darkened(0.25), 3.5)
			ci.draw_circle(Vector2(0, r * 0.38), r * 0.52, body.lightened(0.15))
			ci.draw_arc(Vector2(0, r * 0.38), r * 0.52, PI * 0.1, PI * 0.9, 12, Color(dark, 0.5), 2.0, true)
			ci.draw_circle(Vector2(0, -r * 1.0), r * 0.22, dark)
			ci.draw_circle(Vector2(0, -r * 1.0), r * 0.15, Color("2a1418"))
			gloss(ci, r)
			var ey := -r * 0.18
			ci.draw_line(Vector2(-r * 0.55, ey - r * 0.36), Vector2(-r * 0.15, ey - r * 0.2), Color("201018"), 3.0)
			ci.draw_line(Vector2(r * 0.55, ey - r * 0.36), Vector2(r * 0.15, ey - r * 0.2), Color("201018"), 3.0)
			ci.draw_arc(Vector2(0, r * 0.45), r * 0.3, PI + 0.3, TAU - 0.3, 10, Color("201018"), 3.0)

## Inheritable mutation parts introduced with the new silhouettes.
## Returns false if the trait is not one of these.
static func part(ci: CanvasItem, c: Vector2, r: float, feature: String, accent: Color) -> bool:
	var shade := accent.darkened(0.43)
	match feature:
		"nozzle":
			poly(ci, PackedVector2Array([c + Vector2(-r * 0.22, -r * 0.75), c + Vector2(-r * 0.3, -r * 1.35), c + Vector2(r * 0.3, -r * 1.35), c + Vector2(r * 0.22, -r * 0.75)]), shade)
			ci.draw_circle(c + Vector2(0, -r * 1.35), r * 0.22, accent)
		"fuse":
			ci.draw_line(c + Vector2(0, -r * 0.9), c + Vector2(r * 0.25, -r * 1.35), Color("c8a060"), 3.0)
			ci.draw_circle(c + Vector2(r * 0.28, -r * 1.4), r * 0.14, Color("ffd24d"))
		"sucker":
			ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.3, shade)
			for k in range(6):
				var a := TAU * float(k) / 6.0
				ci.draw_line(c + Vector2(0, r * 0.45) + Vector2.from_angle(a) * r * 0.3, c + Vector2(0, r * 0.45) + Vector2.from_angle(a) * r * 0.18, accent, 2.0)
		"megaphone":
			poly(ci, PackedVector2Array([c + Vector2(r * 0.6, -r * 0.1), c + Vector2(r * 1.4, -r * 0.45), c + Vector2(r * 1.4, r * 0.35), c + Vector2(r * 0.6, r * 0.1)]), accent, shade, 2.0)
		"cross":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 1.25), Vector2(r * 0.6, r * 0.5)), Color("f2f6f8"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.06, -r * 1.2), Vector2(r * 0.12, r * 0.4)), Color("e8394a"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 1.06), Vector2(r * 0.4, r * 0.12)), Color("e8394a"))
		_:
			return false
	return true
