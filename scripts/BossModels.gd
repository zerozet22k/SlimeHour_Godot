extends RefCounted
## Hand-drawn vector models for the eight bosses and their minions.
## Bosses are single actors, so they are drawn live every frame: rotors spin,
## legs walk, crowns wobble, cracks spread with each phase and every attack
## wind-up is visible on the body itself.
##
## draw(ci, kind, r, a) draws at the canvas origin (callers set the transform).
## `a` (all optional): t, stage (0-2), tell (0-1), flash, aim (local Vector2),
## bank (-1..1), state, heat (0-1), vent, dizzy, armored, vanish, burrowed,
## trail (local offsets, head first), gun (angle), spin, xf (caller transform).

const INK := Color(0.07, 0.04, 0.09)

# ---------------------------------------------------------------- primitives
static func ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 28) -> void:
	ci.draw_colored_polygon(ell_pts(c, rx, ry, rot, n), col)

static func ell_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var th: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(th) * rx, sin(th) * ry).rotated(rot))
	return pts

static func wobble_pts(c: Vector2, rx: float, ry: float, t: float, amp: float, lobes: int = 3, n: int = 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var th: float = TAU * float(i) / float(n)
		var k: float = 1.0 + amp * sin(th * lobes + t * 3.6) + amp * 0.5 * sin(th * (lobes + 2) - t * 2.3)
		pts.append(c + Vector2(cos(th) * rx * k, sin(th) * ry * k))
	return pts

static func outlined(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color = INK, w: float = 3.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, w, true)

static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float = 2.0) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 40, col, w, true)

static func eye(ci: CanvasItem, c: Vector2, r: float, look: Vector2, iris: Color = Color("1a0e12")) -> void:
	ell(ci, c, r * 1.05, r, Color.WHITE)
	ci.draw_circle(c + look.limit_length(1.0) * r * 0.38, r * 0.55, iris)
	ci.draw_circle(c + look.limit_length(1.0) * r * 0.38 + Vector2(-r * 0.18, -r * 0.2), r * 0.17, Color(1, 1, 1, 0.9))
	ci.draw_arc(c, r * 1.05, 0.0, TAU, 24, INK, 2.0, true)

static func shadow(ci: CanvasItem, c: Vector2, rx: float, alpha: float = 0.32) -> void:
	ell(ci, c, rx, rx * 0.34, Color(0, 0, 0, alpha))

static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(rot - PI * 0.5 + PI * float(i) / 5.0) * rr)
	ci.draw_colored_polygon(pts, col)

static func gear_pts(c: Vector2, r: float, teeth: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(teeth * 4):
		var th: float = rot + TAU * float(i) / float(teeth * 4)
		var rr: float = r if (i % 4) in [1, 2] else r * 0.8
		pts.append(c + Vector2.from_angle(th) * rr)
	return pts

static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, strength: float = 1.0) -> void:
	for i in range(4):
		var k: float = 1.0 - float(i) * 0.22
		ci.draw_circle(c, r * k, Color(col, 0.10 * strength))

# ---------------------------------------------------------------- dispatch
static func draw(ci: CanvasItem, kind: String, r: float, a: Dictionary = {}) -> void:
	match kind:
		"chonkzilla": chonkzilla(ci, r, a)
		"heli": heli(ci, r, a)
		"necro": necro(ci, r, a)
		"kingblob": kingblob(ci, r, a)
		"coilqueen": coilqueen(ci, r, a)
		"glassoracle": oracle(ci, r, a)
		"voidweaver": weaver(ci, r, a)
		"dreadengine": engine(ci, r, a)
	if bool(a.get("flash", false)):
		ci.draw_circle(Vector2.ZERO, r * 1.05, Color(1, 1, 1, 0.35))

# ================================================================ CHONKZILLA
## A kaiju-sized jelly with dorsal plates, a stubby tail and a toothy grin.
static func chonkzilla(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var aim: Vector2 = a.get("aim", Vector2.DOWN)
	var body := Color("e86a8a")
	if stage == 2:
		body = body.lerp(Color("ff5a3c"), 0.25 + 0.1 * sin(t * 6.0))
	var dark := body.darkened(0.5)
	var plate := Color("6d2440")
	var sx: float = 1.0 + tell * 0.14
	var sy: float = 1.0 - tell * 0.12
	if bool(a.get("rolling", false)):
		# Curled into a spiked wrecking ball.
		var spin: float = float(a.get("spin", 0.0))
		for i in range(9):
			var th: float = spin + TAU * float(i) / 9.0
			var tip := Vector2.from_angle(th) * r * 1.22
			ci.draw_colored_polygon(PackedVector2Array([Vector2.from_angle(th - 0.22) * r * 0.85, tip,
				Vector2.from_angle(th + 0.22) * r * 0.85]), plate)
		outlined(ci, ell_pts(Vector2.ZERO, r * 0.95, r * 0.95, 0.0, 30), body, INK, 3.5)
		for i in range(3):
			var th2: float = spin * 1.0 + TAU * float(i) / 3.0
			ci.draw_arc(Vector2.ZERO, r * (0.35 + i * 0.18), th2, th2 + 2.0, 16, dark, 4.0, true)
		ci.draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.35))
		return
	# Tail curls out behind (up-screen).
	var tail := PackedVector2Array()
	for i in range(9):
		var u: float = float(i) / 8.0
		tail.append(Vector2(r * (0.3 + u * 0.75), -r * (0.35 + u * 0.55)) + Vector2(sin(t * 2.0 + u * 3.0) * 6.0 * u, 0))
	ci.draw_polyline(tail, INK, r * 0.42, true)
	ci.draw_polyline(tail, dark, r * 0.34, true)
	# Feet.
	for side in [-1.0, 1.0]:
		var foot := Vector2(side * r * 0.62, r * 0.78)
		outlined(ci, ell_pts(foot, r * 0.32, r * 0.2), dark.darkened(0.2), INK, 2.5)
		for c in range(3):
			ci.draw_circle(foot + Vector2((c - 1) * r * 0.12, r * 0.12), r * 0.05, Color("f3e4d0"))
	# Dorsal plates along the top arc; they glow in the rage phase.
	for i in range(5):
		var th: float = lerpf(-PI * 0.86, -PI * 0.14, float(i) / 4.0)
		var base := Vector2(cos(th) * r * 0.95 * sx, sin(th) * r * 0.82 * sy)
		var out := Vector2.from_angle(th)
		var h: float = r * (0.42 if i == 2 else 0.32)
		var tri := PackedVector2Array([base - out.orthogonal() * r * 0.17, base + out * h, base + out.orthogonal() * r * 0.17])
		outlined(ci, tri, plate if stage < 2 else plate.lerp(Color("ff8b3d"), 0.5 + 0.5 * sin(t * 8.0 + i)), INK, 2.5)
	# Body.
	var body_pts := wobble_pts(Vector2.ZERO, r * 1.08 * sx, r * 0.92 * sy, t, 0.025)
	outlined(ci, body_pts, body, INK, 4.0)
	ell(ci, Vector2(0, r * 0.3 * sy), r * 0.68 * sx, r * 0.48 * sy, body.lightened(0.28))
	for k in range(3):
		ci.draw_arc(Vector2(0, r * 0.3 * sy), r * (0.2 + k * 0.15), PI * 0.15, PI * 0.85, 10, Color(dark, 0.35), 2.0, true)
	# Stubby arms, raised while winding up.
	for side in [-1.0, 1.0]:
		var arm := Vector2(side * r * 1.0 * sx, r * (0.12 - tell * 0.3))
		outlined(ci, ell_pts(arm, r * 0.22, r * 0.3, side * 0.5), body.darkened(0.12), INK, 2.5)
	# Face.
	var brow_tilt: float = 0.2 + stage * 0.12 + tell * 0.15
	for side in [-1.0, 1.0]:
		var ec := Vector2(side * r * 0.36, -r * 0.22)
		eye(ci, ec, r * 0.17, aim, Color("2a0a10") if stage < 2 else Color("8a1010"))
		ci.draw_line(ec + Vector2(-side * r * 0.22, -r * 0.2 - brow_tilt * r * 0.25), ec + Vector2(side * r * 0.2, -r * 0.24 + brow_tilt * r * 0.08), INK, 5.0, true)
	var mouth := PackedVector2Array()
	var open: float = 0.18 + tell * 0.22 + (0.1 if stage == 2 else 0.0)
	for i in range(13):
		var u: float = float(i) / 12.0
		mouth.append(Vector2(lerpf(-r * 0.42, r * 0.42, u), r * 0.12 + sin(u * PI) * r * 0.06))
	for i in range(13):
		var u2: float = 1.0 - float(i) / 12.0
		mouth.append(Vector2(lerpf(-r * 0.42, r * 0.42, u2), r * 0.12 + sin(u2 * PI) * r * (0.06 + open)))
	outlined(ci, mouth, Color("3a0814"), INK, 2.5)
	for i in range(6):
		var x: float = lerpf(-r * 0.34, r * 0.34, float(i) / 5.0)
		var y: float = r * 0.12 + sin((x / (r * 0.84) + 0.5) * PI) * r * 0.06
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - r * 0.05, y), Vector2(x + r * 0.05, y), Vector2(x, y + r * 0.1)]), Color("fff4e0"))
	# Gloss.
	ell(ci, Vector2(-r * 0.5, -r * 0.5), r * 0.2, r * 0.11, Color(1, 1, 1, 0.45), -0.5)
	# Armour cracks spread with each phase.
	if stage >= 1:
		var hot := Color("ffcb8d") if stage == 1 else Color("ffef9a")
		var cracks := [[Vector2(-0.55, -0.55), Vector2(-0.35, -0.2), Vector2(-0.5, 0.05)],
			[Vector2(0.6, -0.45), Vector2(0.42, -0.1), Vector2(0.62, 0.2)],
			[Vector2(0.1, -0.78), Vector2(-0.02, -0.55)]]
		for ci_i in range(cracks.size() if stage == 2 else 2):
			var c: Array = cracks[ci_i]
			for j in range(c.size() - 1):
				ci.draw_line(Vector2(c[j]) * r, Vector2(c[j + 1]) * r, Color(hot, 0.9), 3.5 if stage == 2 else 2.5, true)
	if tell > 0.0:
		glow(ci, Vector2(0, r * 0.15), r * 1.25, Color("ffb070"), tell)
	if bool(a.get("dizzy", false)):
		for i in range(3):
			var th3: float = t * 4.0 + TAU * float(i) / 3.0
			star(ci, Vector2(cos(th3) * r * 0.6, -r * 1.0 + sin(th3) * r * 0.15), r * 0.13, Color("ffe07f"), t * 3.0)

# ================================================================ HELI-COPTER
## Top-down attack gunship: nose toward the player, rotor blur, wing pods.
static func heli(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var hull := Color("d98a3a")
	var hull_dark := Color("7a4316")
	var steel := Color("3a3f4d")
	# Tail boom + fin + tail rotor.
	outlined(ci, PackedVector2Array([Vector2(-r * 0.13, -r * 0.4), Vector2(r * 0.13, -r * 0.4), Vector2(r * 0.08, -r * 1.55), Vector2(-r * 0.08, -r * 1.55)]), hull_dark, INK, 2.5)
	for i in range(4):
		var y: float = -r * (0.6 + i * 0.22)
		ci.draw_line(Vector2(-r * 0.1, y), Vector2(r * 0.1, y - r * 0.08), Color("ffd24d") if i % 2 == 0 else INK, 3.0)
	outlined(ci, PackedVector2Array([Vector2(-r * 0.32, -r * 1.5), Vector2(r * 0.32, -r * 1.5), Vector2(r * 0.22, -r * 1.68), Vector2(-r * 0.22, -r * 1.68)]), hull, INK, 2.0)
	var tr: float = t * 40.0
	ci.draw_line(Vector2(-r * 0.4, -r * 1.6).rotated(0.0) + Vector2(cos(tr) * r * 0.05, 0), Vector2(r * 0.4, -r * 1.6), Color(0.9, 0.9, 1.0, 0.5), 3.0)
	# Stub wings with missile pods.
	outlined(ci, PackedVector2Array([Vector2(-r * 0.95, -r * 0.05), Vector2(r * 0.95, -r * 0.05), Vector2(r * 0.85, r * 0.2), Vector2(-r * 0.85, r * 0.2)]), steel, INK, 2.5)
	for side in [-1.0, 1.0]:
		var pod := Vector2(side * r * 0.82, r * 0.08)
		outlined(ci, ell_pts(pod, r * 0.12, r * 0.3), Color("565c6b"), INK, 2.0)
		for k in range(2):
			ci.draw_circle(pod + Vector2((k - 0.5) * r * 0.1, r * 0.3), r * 0.05, Color("ff4d4d"))
		# Wing-tip strobes blink faster while winding up.
		var blink: bool = fmod(t * (2.0 + tell * 10.0), 1.0) < 0.5
		ci.draw_circle(Vector2(side * r * 0.97, r * 0.06), r * 0.06, Color("ff3b3b") if blink else Color("5a1414"))
	# Fuselage.
	var body := ell_pts(Vector2(0, r * 0.12), r * 0.52, r * 0.88)
	outlined(ci, body, hull, INK, 3.5)
	ell(ci, Vector2(r * 0.18, r * 0.12), r * 0.22, r * 0.7, Color(hull_dark, 0.45))
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(side * r * 0.2, -r * 0.55), Vector2(side * r * 0.3, r * 0.35), Color(hull_dark, 0.8), 2.0, true)
	# Cockpit glass.
	outlined(ci, ell_pts(Vector2(0, r * 0.58), r * 0.32, r * 0.28), Color("2e5f8f"), INK, 2.5)
	ell(ci, Vector2(-r * 0.1, r * 0.5), r * 0.12, r * 0.07, Color(1, 1, 1, 0.55), -0.4)
	# Chin minigun follows the current firing angle.
	var gun_dir: Vector2 = Vector2.from_angle(float(a.get("gun", PI * 0.5)))
	var gun_base := Vector2(0, r * 0.88)
	ci.draw_circle(gun_base, r * 0.13, steel)
	ci.draw_line(gun_base, gun_base + gun_dir * r * 0.42, INK, 7.0)
	ci.draw_line(gun_base, gun_base + gun_dir * r * 0.42, Color("8a8f9c"), 4.0)
	# Main rotor: blur disc + four fast blades.
	ci.draw_circle(Vector2.ZERO, r * 1.65, Color(0.85, 0.9, 1.0, 0.07))
	ci.draw_arc(Vector2.ZERO, r * 1.65, 0.0, TAU, 48, Color(0.9, 0.95, 1.0, 0.18), 2.0, true)
	var rot: float = t * 26.0
	for i in range(4):
		var d := Vector2.from_angle(rot + PI * 0.5 * float(i))
		ci.draw_line(d * r * 0.12, d * r * 1.62, Color(0.12, 0.12, 0.16, 0.55), 6.0)
		ci.draw_line(d * r * 1.3, d * r * 1.62, Color("ffd24d"), 6.0)
	ci.draw_circle(Vector2.ZERO, r * 0.14, Color("2a2d36"))
	ci.draw_circle(Vector2.ZERO, r * 0.06, Color("c9ccd6"))
	# Damage smoke and sparks.
	if stage >= 1:
		for i in range(3 + stage * 2):
			var u: float = fmod(t * 0.9 + float(i) * 0.27, 1.0)
			ci.draw_circle(Vector2(r * 0.25 + sin(i * 2.1) * 6.0, -r * 0.35 - u * r * 1.3), r * (0.08 + u * 0.18), Color(0.22, 0.22, 0.24, 0.55 * (1.0 - u)))
	if stage == 2 and fmod(t * 7.0, 1.0) < 0.3:
		ci.draw_line(Vector2(r * 0.3, -r * 0.2), Vector2(r * 0.45, -r * 0.05), Color("fff3a0"), 2.5)

# ================================================================ NECRO-DAD
## A hooded lich with a very dad moustache, a soul-orb staff and orbiting wisps.
static func necro(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var aim: Vector2 = a.get("aim", Vector2.DOWN)
	var soul := Color("c79bff") if stage < 2 else Color("8dffb8")
	var robe := Color("3b2366")
	var robe_dark := Color("22123f")
	if tell > 0.0:
		# Summoning sigil turns beneath him while he winds up.
		var sr: float = r * (1.15 + tell * 0.25)
		ci.draw_arc(Vector2(0, r * 0.75), sr, t, t + TAU, 48, Color(soul, 0.35 + tell * 0.5), 2.5, true)
		ci.draw_arc(Vector2(0, r * 0.75), sr * 0.78, -t * 1.4, -t * 1.4 + TAU, 40, Color(soul, 0.3 + tell * 0.4), 1.5, true)
		for i in range(6):
			var th: float = t + TAU * float(i) / 6.0
			var p := Vector2(0, r * 0.75) + Vector2(cos(th) * sr * 0.89, sin(th) * sr * 0.89)
			ci.draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color(soul, 0.8), 2.0)
	# Float: compose the bob with the caller's transform when it is known.
	var xf = a.get("xf")
	if xf != null:
		ci.draw_set_transform_matrix(Transform2D(xf) * Transform2D(0.0, Vector2(0, sin(t * 2.0) * r * 0.06)))
	# Robe with tattered hem.
	var hem := PackedVector2Array([Vector2(-r * 0.55, -r * 0.3), Vector2(r * 0.55, -r * 0.3)])
	for i in range(9):
		var u: float = float(i) / 8.0
		var x: float = lerpf(r * 0.95, -r * 0.95, u)
		var y: float = r * (0.95 if i % 2 == 0 else 0.72) + sin(t * 3.0 + i) * r * 0.05
		hem.append(Vector2(x, y))
	outlined(ci, hem, robe, INK, 3.0)
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(side * r * 0.2, -r * 0.1), Vector2(side * r * 0.42, r * 0.8), Color(robe_dark, 0.9), 3.0, true)
	# Sleeves + bony hand gripping the staff.
	var staff_top := Vector2(r * 0.85, -r * 0.95)
	ci.draw_line(Vector2(r * 0.7, r * 1.0), staff_top, INK, 7.0, true)
	ci.draw_line(Vector2(r * 0.7, r * 1.0), staff_top, Color("6b4a2b"), 4.0, true)
	outlined(ci, ell_pts(Vector2(r * 0.6, r * 0.05), r * 0.24, r * 0.17, 0.5), robe_dark, INK, 2.0)
	ci.draw_circle(Vector2(r * 0.76, -r * 0.02), r * 0.09, Color("e8e2d0"))
	outlined(ci, ell_pts(Vector2(-r * 0.62, r * 0.08), r * 0.24, r * 0.17, -0.5), robe_dark, INK, 2.0)
	# Soul orb on the staff.
	var orb_r: float = r * (0.2 + tell * 0.08)
	glow(ci, staff_top, orb_r * 2.4, soul, 1.0 + tell * 1.5)
	ci.draw_circle(staff_top, orb_r, soul)
	ci.draw_arc(staff_top, orb_r * 0.6, t * 3.0, t * 3.0 + PI * 1.2, 12, Color.WHITE, 2.0, true)
	ci.draw_arc(staff_top, orb_r, 0.0, TAU, 20, INK, 2.0, true)
	# Hood + skull face + the moustache.
	var hood := PackedVector2Array([Vector2(0, -r * 1.12), Vector2(r * 0.48, -r * 0.82), Vector2(r * 0.58, -r * 0.3),
		Vector2(r * 0.3, -r * 0.08), Vector2(-r * 0.3, -r * 0.08), Vector2(-r * 0.58, -r * 0.3), Vector2(-r * 0.48, -r * 0.82)])
	outlined(ci, hood, robe_dark, INK, 3.0)
	ell(ci, Vector2(0, -r * 0.5), r * 0.4, r * 0.4, Color(0, 0, 0, 0.85))
	ell(ci, Vector2(0, -r * 0.5), r * 0.31, r * 0.34, Color("e9e4d4"))
	for side in [-1.0, 1.0]:
		var socket := Vector2(side * r * 0.13, -r * 0.56)
		ell(ci, socket, r * 0.09, r * 0.1, Color("1a0f22"))
		ci.draw_circle(socket + aim.limit_length(1.0) * r * 0.025, r * 0.045, soul)
		glow(ci, socket, r * 0.12, soul, 0.8)
	var stache := PackedVector2Array([Vector2(0, -r * 0.36), Vector2(r * 0.12, -r * 0.4), Vector2(r * 0.27, -r * 0.33),
		Vector2(r * 0.22, -r * 0.29), Vector2(r * 0.1, -r * 0.33), Vector2(0, -r * 0.3), Vector2(-r * 0.1, -r * 0.33),
		Vector2(-r * 0.22, -r * 0.29), Vector2(-r * 0.27, -r * 0.33), Vector2(-r * 0.12, -r * 0.4)])
	outlined(ci, stache, Color("4a3426"), INK, 1.5)
	for i in range(4):
		ci.draw_line(Vector2((i - 1.5) * r * 0.06, -r * 0.27), Vector2((i - 1.5) * r * 0.06, -r * 0.21), Color("8f8878"), 1.5)
	if xf != null:
		ci.draw_set_transform_matrix(Transform2D(xf))
	# Orbiting wisps.
	for i in range(3 + stage):
		var th2: float = t * 1.3 + TAU * float(i) / float(3 + stage)
		var w := Vector2(cos(th2) * r * 1.3, sin(th2) * r * 0.5 - r * 0.2)
		glow(ci, w, r * 0.16, soul, 1.0)
		ci.draw_circle(w, r * 0.07, Color(soul.lightened(0.5), 0.9))

# ================================================================ KING BLOB
## A royal jelly: ermine cape, jewelled crown, smug lids and floating bubbles.
static func kingblob(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var aim: Vector2 = a.get("aim", Vector2.DOWN)
	var body := Color("ff7b93")
	if stage == 2:
		body = body.lerp(Color("ff3d6e"), 0.35)
	var sq: float = float(a.get("squash", 0.0))
	var sx: float = 1.0 + sq * 0.3 + tell * 0.1
	var sy: float = 1.0 - sq * 0.25 - tell * 0.08
	# Cape behind the body.
	var cape := PackedVector2Array([Vector2(-r * 0.7, -r * 0.45), Vector2(r * 0.7, -r * 0.45), Vector2(r * 1.25, r * 0.85),
		Vector2(r * 0.4, r * 0.75 + sin(t * 2.0) * 4.0), Vector2(-r * 0.4, r * 0.75 + sin(t * 2.0 + 1.0) * 4.0), Vector2(-r * 1.25, r * 0.85)])
	outlined(ci, cape, Color("5b2a8a"), INK, 3.0)
	for i in range(7):
		var x: float = lerpf(-r * 1.15, r * 1.15, float(i) / 6.0)
		ci.draw_circle(Vector2(x, r * 0.84), r * 0.1, Color("f4f0ea"))
		ci.draw_circle(Vector2(x, r * 0.86), r * 0.025, INK)
	# Jelly body.
	var pts := wobble_pts(Vector2(0, r * 0.05), r * 1.02 * sx, r * 0.88 * sy, t, 0.035, 2)
	outlined(ci, pts, Color(body, 0.96), INK, 4.0)
	ell(ci, Vector2(0, r * 0.45 * sy), r * 0.75 * sx, r * 0.35 * sy, Color(body.darkened(0.25), 0.6))
	# Bubbles drifting inside the jelly.
	for i in range(6):
		var u: float = fmod(t * 0.25 + float(i) * 0.17, 1.0)
		var bx: float = sin(float(i) * 2.4) * r * 0.55
		ci.draw_arc(Vector2(bx, r * (0.6 - u * 1.1)), r * (0.04 + 0.03 * (i % 3)), 0.0, TAU, 12, Color(1, 1, 1, 0.5 * (1.0 - u)), 1.5, true)
	# Face: smug lids, rosy cheeks.
	var lid: float = 0.45 if stage < 2 else 0.25
	for side in [-1.0, 1.0]:
		var ec := Vector2(side * r * 0.32, -r * 0.08)
		eye(ci, ec, r * 0.16, aim)
		ci.draw_colored_polygon(PackedVector2Array([ec + Vector2(-r * 0.19, -r * 0.18), ec + Vector2(r * 0.19, -r * 0.18),
			ec + Vector2(r * 0.19, -r * 0.18 + r * 0.32 * lid), ec + Vector2(-r * 0.19, -r * 0.18 + r * 0.32 * lid)]), Color(body.darkened(0.1)))
		ci.draw_line(ec + Vector2(-r * 0.19, -r * 0.18 + r * 0.32 * lid), ec + Vector2(r * 0.19, -r * 0.18 + r * 0.32 * lid), INK, 2.5)
		if stage == 2:
			ci.draw_line(ec + Vector2(-side * r * 0.2, -r * 0.3), ec + Vector2(side * r * 0.15, -r * 0.2), INK, 4.0, true)
		ell(ci, Vector2(side * r * 0.55, r * 0.15), r * 0.13, r * 0.08, Color(1.0, 0.45, 0.6, 0.55))
	ci.draw_arc(Vector2(0, r * 0.15), r * 0.16, PI * 0.15, PI * 0.85, 10, INK, 3.0, true)
	# Gloss.
	ell(ci, Vector2(-r * 0.48, -r * 0.42), r * 0.22, r * 0.12, Color(1, 1, 1, 0.5), -0.6)
	# Crown, tilting in the rage phase.
	var crown_y: float = -r * 0.8 * sy
	var tilt: float = 0.0 if stage < 2 else 0.25
	var cw: float = r * 0.62
	var crown := PackedVector2Array([Vector2(-cw, 0), Vector2(-cw, -r * 0.3), Vector2(-cw * 0.55, -r * 0.14), Vector2(-cw * 0.3, -r * 0.45),
		Vector2(0, -r * 0.2), Vector2(cw * 0.3, -r * 0.45), Vector2(cw * 0.55, -r * 0.14), Vector2(cw, -r * 0.3), Vector2(cw, 0)])
	for i in range(crown.size()):
		crown[i] = crown[i].rotated(tilt) + Vector2(0, crown_y)
	if tell > 0.0:
		glow(ci, Vector2(0, crown_y - r * 0.15), r * 0.9, Color("ffe27a"), tell * 1.5)
	outlined(ci, crown, Color("ffcf3d"), Color("7a5208"), 3.0)
	var gems := [Color("ff3d5a"), Color("3dc6ff"), Color("4dff8a")]
	for i in range(3):
		var gp := Vector2((i - 1) * cw * 0.55, -r * 0.08).rotated(tilt) + Vector2(0, crown_y)
		ci.draw_circle(gp, r * 0.07, gems[i])
		ci.draw_circle(gp + Vector2(-r * 0.02, -r * 0.02), r * 0.025, Color(1, 1, 1, 0.8))

# ================================================================ COIL QUEEN
## A crowned cobra whose scaled body follows the head's real path.
static func coilqueen(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var aim: Vector2 = a.get("aim", Vector2.DOWN)
	var scale_a := Color("67ebb9")
	var scale_b := Color("2f9d78")
	var belly := Color("e9ffd0")
	if bool(a.get("burrowed", false)):
		# Only a churning mound shows while she tunnels.
		ell(ci, Vector2.ZERO, r * 0.95, r * 0.6, Color("5a4630"))
		outlined(ci, wobble_pts(Vector2(0, -r * 0.08), r * 0.75, r * 0.45, t * 3.0, 0.08, 5), Color("7a5f40"), INK, 3.0)
		for i in range(5):
			var th: float = TAU * float(i) / 5.0 + t
			ci.draw_line(Vector2.from_angle(th) * r * 0.2, Vector2.from_angle(th) * r * 0.6, Color(scale_a, 0.7), 2.5, true)
		for i in range(4):
			var u: float = fmod(t * 2.0 + float(i) * 0.25, 1.0)
			ci.draw_circle(Vector2(sin(i * 3.1) * r * 0.6, -r * 0.2 - u * r * 0.6), r * 0.06, Color("8a6d4a", 1.0 - u))
		return
	# Body segments (tail first so the head is on top).
	var trail: Array = a.get("trail", [])
	var n: int = trail.size()
	for i in range(n - 1, 0, -1):
		var u2: float = float(i) / float(maxi(1, n - 1))
		var seg_r: float = r * lerpf(0.66, 0.28, u2)
		var p: Vector2 = trail[i]
		ci.draw_circle(p, seg_r + 3.0, INK)
		ci.draw_circle(p, seg_r, scale_a if i % 2 == 0 else scale_b)
		ci.draw_circle(p, seg_r * 0.45, Color(belly, 0.35))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -seg_r * 0.6), p + Vector2(seg_r * 0.35, 0), p + Vector2(0, seg_r * 0.6), p + Vector2(-seg_r * 0.35, 0)]), Color(scale_b.darkened(0.3), 0.8))
	# Head faces the player.
	var ang: float = aim.angle() - PI * 0.5
	var hood_w: float = r * (1.05 + tell * 0.3)
	var hood := PackedVector2Array()
	for i in range(17):
		var u3: float = float(i) / 16.0
		var th2: float = lerpf(PI * 1.05, PI * -0.05, u3)
		hood.append(Vector2(cos(th2) * hood_w, -sin(th2) * r * 0.95 - r * 0.05).rotated(ang))
	hood.append(Vector2(r * 0.3, r * 0.35).rotated(ang))
	hood.append(Vector2(-r * 0.3, r * 0.35).rotated(ang))
	if tell > 0.0:
		glow(ci, Vector2.ZERO, hood_w * 1.2, scale_a, tell * 1.4)
	outlined(ci, hood, scale_b, INK, 3.5)
	for side in [-1.0, 1.0]:
		var spot := Vector2(side * hood_w * 0.55, -r * 0.35).rotated(ang)
		ci.draw_circle(spot, r * 0.16, Color("1d3d2f"))
		ci.draw_circle(spot, r * 0.09, Color("ffe36b"))
		ci.draw_circle(spot, r * 0.04, Color("1d3d2f"))
	# Head.
	outlined(ci, ell_pts(Vector2(0, r * 0.12).rotated(ang), r * 0.42, r * 0.55, ang), scale_a, INK, 3.0)
	ell(ci, Vector2(0, r * 0.35).rotated(ang), r * 0.22, r * 0.18, Color(belly, 0.6), ang)
	# Fangs, eyes and a flicking tongue.
	for side in [-1.0, 1.0]:
		var ec := Vector2(side * r * 0.2, r * 0.2).rotated(ang)
		ell(ci, ec, r * 0.11, r * 0.13, Color("ffe36b"), ang)
		ell(ci, ec, r * 0.025, r * 0.1, INK, ang)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(side * r * 0.14, r * 0.58).rotated(ang), Vector2(side * r * 0.08, r * 0.58).rotated(ang), Vector2(side * r * 0.11, r * 0.76).rotated(ang)]), Color.WHITE)
	if fmod(t * 1.3, 1.0) < 0.35 or tell > 0.3:
		var base := Vector2(0, r * 0.66).rotated(ang)
		var tip := Vector2(0, r * 0.95).rotated(ang)
		ci.draw_line(base, tip, Color("ff4d6a"), 3.0, true)
		ci.draw_line(tip, tip + Vector2(-r * 0.08, r * 0.1).rotated(ang), Color("ff4d6a"), 2.5, true)
		ci.draw_line(tip, tip + Vector2(r * 0.08, r * 0.1).rotated(ang), Color("ff4d6a"), 2.5, true)
	# Tiara.
	var tiara := PackedVector2Array([Vector2(-r * 0.24, -r * 0.18), Vector2(-r * 0.16, -r * 0.4), Vector2(-r * 0.06, -r * 0.24),
		Vector2(0, -r * 0.48), Vector2(r * 0.06, -r * 0.24), Vector2(r * 0.16, -r * 0.4), Vector2(r * 0.24, -r * 0.18)])
	for i in range(tiara.size()):
		tiara[i] = tiara[i].rotated(ang)
	outlined(ci, tiara, Color("ffcf3d"), Color("7a5208"), 2.0)
	ci.draw_circle(Vector2(0, -r * 0.3).rotated(ang), r * 0.06, Color("3dff9e") if stage < 2 else Color("ff3d6e"))

# ================================================================ GLASS ORACLE
## A floating faceted crystal with one great eye and orbiting prism shards.
static func oracle(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var aim: Vector2 = a.get("aim", Vector2.DOWN)
	var bob: float = sin(t * 1.6) * r * 0.06
	var c := Vector2(0, bob)
	# Halo.
	ci.draw_arc(c + Vector2(0, -r * 0.1), r * 1.2, 0.0, TAU, 48, Color("ffe9a8", 0.55), 3.0, true)
	ci.draw_arc(c + Vector2(0, -r * 0.1), r * 1.28, t, t + PI * 0.7, 24, Color("fff6d0", 0.7), 2.0, true)
	if bool(a.get("armored", false)):
		var hex := PackedVector2Array()
		for i in range(7):
			hex.append(c + Vector2.from_angle(t * 0.4 + TAU * float(i) / 6.0) * r * 1.55)
		ci.draw_colored_polygon(hex.slice(0, 6), Color("8ff4ff", 0.08))
		ci.draw_polyline(hex, Color("b8fbff", 0.55 + 0.25 * sin(t * 4.0)), 2.5, true)
	if tell > 0.0:
		glow(ci, c, r * 1.6, Color("dffcff"), tell * 1.6)
	# Faceted hexagonal crystal body, lit from the upper left.
	var pts := PackedVector2Array()
	for i in range(6):
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 6.0) * Vector2(r * 0.95, r * 1.12))
	var shades := [Color("c9fbff"), Color("8ae8f7"), Color("4fc3dd"), Color("2f8fb5"), Color("5ac9e6"), Color("a7f2ff")]
	for i in range(6):
		ci.draw_colored_polygon(PackedVector2Array([c, pts[i], pts[(i + 1) % 6]]), shades[i])
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color("1b4b66"), 3.5, true)
	for p in pts:
		ci.draw_line(c, p, Color(1, 1, 1, 0.35), 1.5, true)
	if stage >= 1:
		ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.3, -r * 0.8), c + Vector2(r * 0.15, -r * 0.45), c + Vector2(r * 0.4, -r * 0.2)]), Color(1, 1, 1, 0.85), 2.0, true)
	if stage == 2:
		ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.3, r * 0.45), c + Vector2(-r * 0.4, r * 0.75)]), Color(1, 1, 1, 0.85), 2.0, true)
	# The eye.
	var ec := c + Vector2(0, r * 0.05)
	ell(ci, ec, r * 0.5, r * 0.36, Color("f6fdff"))
	var look: Vector2 = aim.limit_length(1.0) * r * 0.14
	ci.draw_circle(ec + look, r * 0.27, Color("1e7fb0") if stage < 2 else Color("b03d7a"))
	ci.draw_circle(ec + look, r * 0.19, Color("6fe0ff") if stage < 2 else Color("ff8ac2"))
	ci.draw_circle(ec + look, r * (0.1 + tell * 0.05), INK)
	ci.draw_circle(ec + look + Vector2(-r * 0.08, -r * 0.08), r * 0.06, Color.WHITE)
	ci.draw_arc(ec, r * 0.5, 0.0, TAU, 28, Color("1b4b66"), 2.5, true)
	# Orbiting prism shards; they turn to face the player while charging.
	for i in range(6):
		var th: float = t * 0.9 + TAU * float(i) / 6.0
		var sp: Vector2 = c + Vector2(cos(th) * r * 1.5, sin(th) * r * 0.75)
		var face: float = lerpf(th, aim.angle(), tell)
		var shard := PackedVector2Array([sp + Vector2.from_angle(face) * r * 0.24, sp + Vector2.from_angle(face + PI * 0.5) * r * 0.08,
			sp - Vector2.from_angle(face) * r * 0.16, sp - Vector2.from_angle(face + PI * 0.5) * r * 0.08])
		outlined(ci, shard, Color("bff8ff"), Color("1b4b66"), 1.5)

# ================================================================ VOID WEAVER
## A void spider: starfield abdomen, eight walking legs, a cluster of eyes.
static func weaver(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var vanish: bool = bool(a.get("vanish", false))
	var alpha: float = 0.25 if vanish else 1.0
	var shell := Color("2a1648")
	var rim := Color("b397ff")
	# Legs.
	for side in [-1.0, 1.0]:
		for i in range(4):
			var hip := Vector2(side * r * 0.42, r * (-0.15 + i * 0.2))
			var swing: float = sin(t * 5.0 + float(i) * 1.3 + (0.0 if side < 0 else PI)) * 0.18
			var base_ang: float = (PI if side < 0 else 0.0) + side * (-0.7 + i * 0.45) + swing
			var knee: Vector2 = hip + Vector2.from_angle(base_ang - side * 0.5) * r * 0.75
			var foot: Vector2 = knee + Vector2.from_angle(base_ang + side * 0.6) * r * 0.75
			ci.draw_polyline(PackedVector2Array([hip, knee, foot]), Color(INK, alpha), 7.0, true)
			ci.draw_polyline(PackedVector2Array([hip, knee, foot]), Color(shell.lightened(0.15), alpha), 4.0, true)
			ci.draw_circle(knee, 3.5, Color(rim, alpha))
	# Abdomen: a window onto the void.
	var ab := Vector2(0, -r * 0.42)
	var ar: float = r * 0.82
	ci.draw_circle(ab, ar + 3.5, Color(INK, alpha))
	ci.draw_circle(ab, ar, Color("140a26", alpha))
	for i in range(14):
		var sp := Vector2(sin(float(i) * 12.9898) * 0.8, cos(float(i) * 78.233) * 0.8) * ar
		var tw: float = 0.5 + 0.5 * sin(t * 3.0 + float(i))
		ci.draw_circle(ab + sp, 1.4 + tw, Color(1, 1, 1, alpha * (0.4 + 0.6 * tw)))
	var swirl_speed: float = 1.2 + tell * 4.0 + stage * 0.6
	for k in range(3):
		var off: float = t * swirl_speed + TAU * float(k) / 3.0
		ci.draw_arc(ab, ar * (0.35 + k * 0.18), off, off + PI * 0.9, 18, Color("c08cff", alpha * 0.8), 3.0, true)
	if tell > 0.0:
		ci.draw_circle(ab, ar * 0.3 * tell, Color("ffb6ff", alpha * 0.8))
	ci.draw_arc(ab, ar, 0.0, TAU, 40, Color(rim, alpha * 0.9), 2.0, true)
	# Head with the eye cluster and fangs.
	var hd := Vector2(0, r * 0.32)
	ci.draw_circle(hd, r * 0.5 + 3.0, Color(INK, alpha))
	ci.draw_circle(hd, r * 0.5, Color(shell, alpha))
	ci.draw_arc(hd, r * 0.44, PI * 1.1, PI * 1.9, 14, Color(rim, alpha * 0.6), 2.0, true)
	var eyes := [Vector2(-0.18, -0.05), Vector2(0.18, -0.05), Vector2(-0.3, 0.12), Vector2(0.3, 0.12), Vector2(-0.08, 0.16), Vector2(0.08, 0.16)]
	for i in range(eyes.size()):
		var ep: Vector2 = hd + Vector2(eyes[i]) * r
		var er: float = r * (0.09 if i < 2 else 0.06)
		ci.draw_circle(ep, er * 1.7, Color("ff7ad9", alpha * 0.25))
		ci.draw_circle(ep, er, Color("ff7ad9", alpha))
		ci.draw_circle(ep + Vector2(-er * 0.3, -er * 0.3), er * 0.35, Color(1, 1, 1, alpha))
	for side in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(side * r * 0.14, r * 0.38), hd + Vector2(side * r * 0.04, r * 0.4), hd + Vector2(side * r * 0.1, r * 0.62)]), Color("e8dcff", alpha))
	# Rune ring.
	for i in range(8):
		var th: float = -t * 0.6 + TAU * float(i) / 8.0
		ci.draw_arc(Vector2.ZERO, r * 1.45, th, th + 0.45, 6, Color(rim, alpha * 0.55), 2.5, true)
	if vanish:
		for k in range(3):
			var u: float = fmod(t * 2.0 + float(k) / 3.0, 1.0)
			ci.draw_arc(Vector2.ZERO, r * (0.4 + u * 1.2), 0.0, TAU, 32, Color(rim, 0.5 * (1.0 - u)), 2.0, true)

# ================================================================ DREAD ENGINE
## A riveted furnace tank: treads, smokestacks, a spinning gear turret and a
## heat dial. Venting opens the front plates to show the glowing core.
static func engine(ci: CanvasItem, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	var stage: int = int(a.get("stage", 0))
	var tell: float = float(a.get("tell", 0.0))
	var heat: float = clampf(float(a.get("heat", 0.0)), 0.0, 1.0)
	var vent: bool = bool(a.get("vent", false))
	var steel := Color("5b5f6e")
	var steel_dark := Color("343743")
	var brass := Color("f0ad65")
	var hot := Color("ff7a2a").lerp(Color("fff1a8"), heat)
	# Treads.
	for side in [-1.0, 1.0]:
		var rect := Rect2(Vector2(side * r * 0.98 - r * 0.24, -r * 0.82), Vector2(r * 0.48, r * 1.64))
		ci.draw_rect(rect.grow(3.0), INK)
		ci.draw_rect(rect, Color("23252c"))
		for i in range(9):
			var y: float = fmod(t * 70.0 + float(i) * r * 0.2, r * 1.64)
			ci.draw_line(Vector2(rect.position.x, rect.position.y + y), Vector2(rect.end.x, rect.position.y + y), Color("4a4e5a"), 3.0)
	# Hull with chamfered corners.
	var w: float = r * 0.78
	var h: float = r * 0.9
	var hull := PackedVector2Array([Vector2(-w + 14, -h), Vector2(w - 14, -h), Vector2(w, -h + 14), Vector2(w, h - 14),
		Vector2(w - 14, h), Vector2(-w + 14, h), Vector2(-w, h - 14), Vector2(-w, -h + 14)])
	var hull_col := steel if stage < 2 else steel.lerp(Color("8a3a2a"), 0.3 + 0.1 * sin(t * 5.0))
	outlined(ci, hull, hull_col, INK, 4.0)
	ci.draw_rect(Rect2(-w + 6, -h * 0.15, w * 2.0 - 12, r * 0.12), brass)
	for i in range(6):
		ci.draw_line(Vector2(-w + 10 + i * (w * 2.0 - 20) / 5.0, -h * 0.15), Vector2(-w + 10 + i * (w * 2.0 - 20) / 5.0 + 8, -h * 0.15 + r * 0.12), INK, 3.0)
	for p in [Vector2(-w + 9, -h + 9), Vector2(w - 9, -h + 9), Vector2(-w + 9, h - 9), Vector2(w - 9, h - 9)]:
		ci.draw_circle(p, 3.0, Color("9ea3b3"))
	# Smokestacks with smoke.
	for side in [-1.0, 1.0]:
		var stack := Vector2(side * w * 0.6, -h + 4)
		ci.draw_rect(Rect2(stack - Vector2(r * 0.12, r * 0.3), Vector2(r * 0.24, r * 0.32)), steel_dark)
		ci.draw_rect(Rect2(stack - Vector2(r * 0.14, r * 0.34), Vector2(r * 0.28, r * 0.08)), brass)
		for i in range(4):
			var u: float = fmod(t * (0.8 + heat) + float(i) * 0.25 + (0.5 if side > 0 else 0.0), 1.0)
			ci.draw_circle(stack + Vector2(sin(t + i) * 6.0, -r * 0.36 - u * r * 0.9), r * (0.1 + u * 0.16), Color(0.25, 0.24, 0.26, 0.5 * (1.0 - u)))
	# Furnace grille / exposed core at the front.
	var grille := Rect2(Vector2(-w * 0.62, h * 0.28), Vector2(w * 1.24, h * 0.56))
	if vent:
		var pulse: float = 0.5 + 0.5 * sin(t * 12.0)
		ci.draw_rect(grille.grow(6.0), INK)
		glow(ci, grille.get_center(), r * 0.9, Color("fff1a8"), 2.0)
		ci.draw_rect(grille, Color("ffcf6b"))
		ci.draw_circle(grille.get_center(), r * (0.28 + pulse * 0.05), Color("fffbe0"))
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(Vector2(side * w * 0.62 - (r * 0.3 if side > 0 else 0.0) + side * r * 0.08, h * 0.22), Vector2(r * 0.3, h * 0.68)), steel_dark)
		for i in range(5):
			var u2: float = fmod(t * 1.6 + float(i) * 0.2, 1.0)
			ci.draw_circle(Vector2(sin(i * 1.7) * w * 0.7, h * 0.3 - u2 * r * 1.4), r * (0.1 + u2 * 0.22), Color(1, 1, 1, 0.35 * (1.0 - u2)))
	else:
		ci.draw_rect(grille.grow(3.0), INK)
		ci.draw_rect(grille, hot.darkened(0.35 - tell * 0.3))
		glow(ci, grille.get_center(), r * 0.5, hot, 0.6 + tell * 1.5 + heat)
		for i in range(6):
			var x: float = grille.position.x + (i + 0.5) * grille.size.x / 6.0
			ci.draw_line(Vector2(x, grille.position.y), Vector2(x, grille.end.y), steel_dark, 4.0)
	# Gear turret on the deck; spins faster while charging.
	var gr: float = r * 0.42
	var gc := Vector2(0, -h * 0.5)
	var spin: float = t * (1.0 + tell * 6.0 + stage)
	outlined(ci, gear_pts(gc, gr, 10, spin), brass.darkened(0.15), INK, 3.0)
	ci.draw_circle(gc, gr * 0.5, steel_dark)
	ci.draw_circle(gc, gr * 0.22, brass)
	# Heat dial.
	var dial := Vector2(w * 0.55, -h * 0.05)
	ci.draw_circle(dial, r * 0.17, Color("1d1f26"))
	ci.draw_arc(dial, r * 0.13, PI * 0.75, PI * 0.75 + PI * 1.5 * heat, 16, Color("57ff8a").lerp(Color("ff3b2a"), heat), 4.0, true)
	ci.draw_line(dial, dial + Vector2.from_angle(PI * 0.75 + PI * 1.5 * heat) * r * 0.13, Color.WHITE, 2.0, true)

# ================================================================ minions
static func minion(ci: CanvasItem, role: String, r: float, a: Dictionary) -> void:
	var t: float = float(a.get("t", 0.0))
	match role:
		"ward":
			# Soul lantern: cage on a chain with a flickering soul inside.
			var bob: float = sin(t * 2.5) * 3.0
			ci.draw_line(Vector2(0, -r * 1.6 + bob), Vector2(0, -r * 0.8 + bob), Color("8a7fa0"), 2.0)
			var cage := Rect2(Vector2(-r * 0.6, -r * 0.8 + bob), Vector2(r * 1.2, r * 1.5))
			var flame := Color("c79bff").lerp(Color("8dffb8"), 0.5 + 0.5 * sin(t * 3.0))
			glow(ci, cage.get_center(), r * 1.4, flame, 1.2)
			ci.draw_rect(cage.grow(2.0), INK)
			ci.draw_rect(cage, Color("1d1430"))
			ell(ci, cage.get_center() + Vector2(0, r * 0.1), r * 0.32, r * (0.45 + 0.08 * sin(t * 9.0)), flame)
			ell(ci, cage.get_center() + Vector2(0, r * 0.2), r * 0.16, r * 0.22, Color(1, 1, 1, 0.8))
			for i in range(4):
				var x: float = cage.position.x + (i + 0.5) * cage.size.x / 4.0
				ci.draw_line(Vector2(x, cage.position.y), Vector2(x, cage.end.y), Color("6b5a85"), 2.0)
			ci.draw_rect(Rect2(cage.position - Vector2(3, 4), Vector2(cage.size.x + 6, 6)), Color("6b5a85"))
		"mirror":
			var pane := PackedVector2Array([Vector2(0, -r * 1.25), Vector2(r * 0.7, 0), Vector2(0, r * 1.25), Vector2(-r * 0.7, 0)])
			outlined(ci, pane, Color("c6f6ff"), Color("9aa3b5"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -r * 1.0), Vector2(r * 0.5, 0), Vector2(0, r * 1.0), Vector2(-r * 0.5, 0)]), Color("7fd8ee"))
			var g: float = fmod(t * 0.7, 1.0) * 2.0 - 1.0
			ci.draw_line(Vector2(-r * 0.4 + g * r * 0.5, r * 0.3), Vector2(r * 0.1 + g * r * 0.5, -r * 0.6), Color(1, 1, 1, 0.75), 3.0, true)
			ci.draw_circle(Vector2(0, 0), r * 0.12, Color("ffffff"))
		"pod":
			var aim: Vector2 = a.get("aim", Vector2.DOWN)
			ci.draw_circle(Vector2.ZERO, r + 3.0, INK)
			ci.draw_circle(Vector2.ZERO, r, Color("4a4e5a"))
			ci.draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 20, Color("f0ad65"), 3.0, true)
			ci.draw_line(Vector2.ZERO, aim * r * 1.4, INK, 8.0)
			ci.draw_line(Vector2.ZERO, aim * r * 1.4, Color("9ea3b3"), 5.0)
			ci.draw_circle(Vector2.ZERO, r * 0.3, Color("ff6a3d") if fmod(t * 2.0, 1.0) < 0.5 else Color("8a2a14"))
