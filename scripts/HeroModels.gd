extends RefCounted
## The five playable runners, drawn top-down and turning with their aim.
## draw_rig() draws the whole figure in screen space: body, arms reaching to
## the real grips of the guns they hold, the guns, hands, head, and the
## character's own bash move. Everything is procedural so it can animate.

const GunModels = preload("res://scripts/GunModels.gd")
const INK := Color(0.08, 0.06, 0.1)

const PALETTES = {
	"scout": {"coat": "9a5c35", "trim": "e83f50", "hat": "2e6f8e", "skin": "edb184", "glove": "e9b27e", "sleeve": "8a5230", "boot": "6e4530"},
	"ember": {"coat": "4b4038", "trim": "f2d23a", "hat": "e8592c", "skin": "e2a274", "glove": "3a302a", "sleeve": "5a4c42", "boot": "26221f"},
	"ace": {"coat": "6b4a32", "trim": "c8333a", "hat": "b8874a", "skin": "e3a878", "glove": "8a5a36", "sleeve": "5e402b", "boot": "4a3020"},
	"vector": {"coat": "3e5a48", "trim": "71deb1", "hat": "2e4a3c", "skin": "c98f66", "glove": "1f2621", "sleeve": "33473a", "boot": "1f2420"},
	"coil": {"coat": "4a3f8a", "trim": "8ff8ff", "hat": "2a2450", "skin": "b9a7e8", "glove": "2a2450", "sleeve": "3a3170", "boot": "1d1838"},
}

static func pal(id: String, o: Dictionary) -> Dictionary:
	var src: Dictionary = PALETTES.get(id, PALETTES["scout"])
	var out := {}
	var fade := 0.5 if bool(o.get("blink", false)) else 1.0
	for key in src:
		out[key] = Color(Color(str(src[key])), fade)
	if bool(o.get("flash", false)):
		out["coat"] = Color("ff797c")
		out["sleeve"] = Color("ff9a9c")
	return out

static func disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, line: float = 2.2) -> void:
	ci.draw_circle(c, r + line, Color(INK, fill.a))
	ci.draw_circle(c, r, fill)

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(INK, fill.a), w, true)

## Ellipse aligned to the facing: RF along F, RS along the side.
static func oval(c: Vector2, f: Vector2, s: Vector2, rf: float, rs: float, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(c + f * cos(a) * rf + s * sin(a) * rs)
	return pts

# ------------------------------------------------------------------ the rig
## GUNS: Array of {id, aim (unit), muzzle (screen), firing, charge, evolved}.
## O: t, step, blink, flash, bash (0..1 or -1), bash_dir.
static func draw_rig(ci: CanvasItem, id: String, p: Vector2, f: Vector2, k: float, guns: Array, o: Dictionary) -> void:
	if f.length_squared() < 0.01:
		f = Vector2.UP
	f = f.normalized()
	var s := f.orthogonal()
	var c := pal(id, o)
	var t := float(o.get("t", 0.0))
	var bash := float(o.get("bash", -1.0))
	var bash_dir: Vector2 = o.get("bash_dir", f)
	var lunge := bash_dir * (sin(clampf(bash, 0.0, 1.0) * PI) * 6.0 if bash >= 0.0 else 0.0)
	var centre := p + lunge
	var gk := k / 1.25
	# Head before the arms: the hands holding the guns must never be hidden.
	ci.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	draw_body(ci, id, f, s, c, o)
	draw_head(ci, id, f, s, c, o)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Where every gun sits and where its hands go.
	var placed: Array = []
	for i in range(guns.size()):
		var gun: Dictionary = guns[i]
		var a: Vector2 = gun["aim"]
		var fs := -1.0 if a.x < 0.0 else 1.0
		var origin: Vector2 = Vector2(gun["muzzle"]) + lunge - a * (4.0 * gk if bool(gun.get("firing", false)) else 0.0)
		var ang := a.angle()
		var size := gk * GunModels.size(str(gun["id"]))
		var g2: Array = GunModels.grips(str(gun["id"]))
		var g0: Vector2 = g2[0]
		var rear: Vector2 = origin + Vector2(g0.x, g0.y * fs).rotated(ang) * size
		var fore = null
		if g2[1] != null:
			var g1: Vector2 = g2[1]
			fore = origin + Vector2(g1.x, g1.y * fs).rotated(ang) * size
		placed.append({"gun": gun, "origin": origin, "ang": ang, "fs": fs, "rear": rear, "fore": fore, "aim": a, "size": size})
	# Arms: slot 1 in the right hand, slot 2 in the left, slot 3 rides a back mount.
	var arms: Array = []
	var right := centre + s * 12.5 * k
	var left := centre - s * 12.5 * k
	if placed.size() >= 1:
		arms.append([right, placed[0]["rear"]])
	if placed.size() >= 2:
		arms.append([left, placed[1]["rear"]])
	elif placed.size() == 1 and id != "ace":
		var support = placed[0]["fore"]
		if support == null:
			support = Vector2(placed[0]["rear"]) + Vector2(1.5, 3.0 * float(placed[0]["fs"])).rotated(float(placed[0]["ang"])) * float(placed[0]["size"])
		arms.append([left, support])
	elif placed.size() == 1:
		# Ace keeps the off hand loose at the hip: a one-handed gunslinger.
		arms.append([left, left + f * 4.0 * k - s * 3.0 * k])
	if id == "ember" and not placed.is_empty() and str(placed[0]["gun"]["id"]) == "flame":
		# Fuel hose from the backpack tanks to the flamethrower.
		var tank := centre - f * 11.0 * k + s * 5.0 * k
		var end: Vector2 = Vector2(placed[0]["rear"]) - Vector2.from_angle(float(placed[0]["ang"])) * 2.0
		var mid := (tank + end) * 0.5 + s * 10.0 * k
		var hose := PackedVector2Array()
		for i in range(9):
			var u := float(i) / 8.0
			hose.append(tank.lerp(mid, u).lerp(mid.lerp(end, u), u))
		ci.draw_polyline(hose, INK, 4.0, true)
		ci.draw_polyline(hose, Color("2b2b2b"), 2.4, true)
	if id == "coil" and not placed.is_empty() and str(placed[0]["gun"]["id"]) == "rail":
		var pack := centre - f * 9.0 * k
		var grip_at: Vector2 = placed[0]["rear"]
		ci.draw_line(pack, grip_at, Color(Color("baa4ff"), 0.35), 3.0)
		ci.draw_line(pack, grip_at, Color(Color("8ff8ff"), 0.6 + 0.4 * sin(t * 9.0)), 1.0)
	for arm in arms:
		draw_arm(ci, arm[0], arm[1], centre, c, k)
	for i in range(placed.size()):
		var it: Dictionary = placed[i]
		if i == 2:
			# Back mount: a strut from the pack to the third gun.
			ci.draw_line(centre - f * 8.0 * k, it["rear"], INK, 5.0)
			ci.draw_line(centre - f * 8.0 * k, it["rear"], Color("4a5160"), 3.0)
		var gun: Dictionary = it["gun"]
		if bool(gun.get("hidden", false)):
			continue
		ci.draw_set_transform(it["origin"], float(it["ang"]), Vector2(1.0, float(it["fs"])) * float(it["size"]))
		GunModels.draw(ci, str(gun["id"]), {"t": t, "firing": bool(gun.get("firing", false)),
			"charge": float(gun.get("charge", 0.0)), "evolved": bool(gun.get("evolved", false))})
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for arm in arms:
		disc(ci, arm[1], 3.6 * k * 0.8, c["glove"], 1.6)
	if bash >= 0.0:
		draw_bash(ci, id, centre, bash_dir, bash, c, k, t)

static func draw_arm(ci: CanvasItem, shoulder: Vector2, hand: Vector2, centre: Vector2, c: Dictionary, k: float) -> void:
	var out := (shoulder - centre).normalized()
	var elbow := (shoulder + hand) * 0.5 + out * 4.0 * k * 0.8
	var arm := PackedVector2Array([shoulder, elbow, hand])
	ci.draw_polyline(arm, Color(INK, Color(c["sleeve"]).a), 8.0 * k * 0.8, true)
	ci.draw_polyline(arm, c["sleeve"], 5.0 * k * 0.8, true)

# ------------------------------------------------------------------ bodies
static func legs(ci: CanvasItem, f: Vector2, s: Vector2, o: Dictionary, boot: Color, spur: bool = false) -> void:
	var step := float(o.get("step", 0.0))
	for sg in [-1.0, 1.0]:
		var foot: Vector2 = s * sg * 7.0 - f * (9.5 + step * sg)
		disc(ci, foot, 4.2, boot, 1.6)
		ci.draw_circle(foot + f * 1.8 - s * sg * 0.8, 1.3, Color(1, 1, 1, 0.25 * boot.a))
		if spur:
			ci.draw_circle(foot - f * 4.5, 1.2, Color("ffd080"))

static func draw_body(ci: CanvasItem, id: String, f: Vector2, s: Vector2, c: Dictionary, o: Dictionary) -> void:
	var t := float(o.get("t", 0.0))
	match id:
		"ember":
			legs(ci, f, s, o, c["boot"])
			# Twin fuel tanks on the back.
			for sg in [-1.0, 1.0]:
				var tank: Vector2 = -f * 11.0 + s * sg * 5.2
				disc(ci, tank, 5.0, Color("c8333a"), 1.8)
				ci.draw_circle(tank, 2.4, Color("c9ced8"))
				ci.draw_circle(tank + Vector2(-1.5, -1.5), 1.2, Color(1, 1, 1, 0.5))
			disc(ci, Vector2.ZERO, 15.5, c["coat"])
			# Reflective turnout stripes across the coat.
			for off in [-1.5, 3.5]:
				var half := sqrt(maxf(0.0, 15.0 * 15.0 - off * off))
				ci.draw_line(f * off - s * half, f * off + s * half, c["trim"], 2.6)
				ci.draw_line(f * (off + 1.6) - s * (half - 1.0), f * (off + 1.6) + s * (half - 1.0), Color(0.85, 0.88, 0.9, 0.7), 1.0)
			for sg in [-1.0, 1.0]:
				disc(ci, s * sg * 13.0 + f * 2.0, 5.5, Color(c["coat"]).lightened(0.12), 1.6)
		"ace":
			legs(ci, f, s, o, c["boot"], true)
			# Long duster flaring behind, swaying as he walks.
			var sway := sin(t * 7.0) * (3.0 if absf(float(o.get("step", 0.0))) > 0.0 else 1.0)
			var duster := PackedVector2Array([s * 13.0 + f * 2.0, s * 15.5 - f * 19.0 + s * sway * 0.4, s * 5.0 - f * 25.0 + s * sway,
				-s * 5.0 - f * 25.0 + s * sway, -s * 15.5 - f * 19.0 + s * sway * 0.4, -s * 13.0 + f * 2.0])
			poly(ci, duster, Color(c["coat"]).darkened(0.12))
			ci.draw_line(-f * 12.0, -f * 24.0 + s * sway, Color(INK, 0.6), 1.5)
			disc(ci, Vector2.ZERO, 14.5, c["coat"])
			# Vest and sheriff star.
			poly(ci, PackedVector2Array([f * 13.0 - s * 6.0, f * 13.0 + s * 6.0, f * 3.0 + s * 8.0, f * 3.0 - s * 8.0]), Color("3a2a1e"), 1.4)
			var star := f * 8.0 + s * 4.5
			var pts := PackedVector2Array()
			for i in range(10):
				pts.append(star + Vector2.from_angle(f.angle() + float(i) * PI / 5.0) * (2.8 if i % 2 == 0 else 1.2))
			ci.draw_colored_polygon(pts, Color("ffd080"))
			for sg in [-1.0, 1.0]:
				disc(ci, s * sg * 12.5 + f * 2.0, 4.8, Color(c["coat"]).lightened(0.1), 1.6)
		"vector":
			legs(ci, f, s, o, c["boot"])
			# Radio pack with a whip antenna.
			poly(ci, PackedVector2Array([-f * 7.0 - s * 7.0, -f * 7.0 + s * 7.0, -f * 15.0 + s * 6.0, -f * 15.0 - s * 6.0]), Color("35463a"))
			ci.draw_line(-f * 12.0 + s * 5.0, -f * 24.0 + s * 10.0 + s * sin(t * 6.0) * 1.5, INK, 1.4)
			ci.draw_circle(-f * 24.0 + s * 10.0 + s * sin(t * 6.0) * 1.5, 1.4, Color("ff4655"))
			var body := PackedVector2Array()
			for i in range(8):
				var a := TAU * float(i) / 8.0 + PI / 8.0
				body.append(f * cos(a) * 14.5 + s * sin(a) * 15.5)
			poly(ci, body, Color("26302c"))
			var plate := PackedVector2Array()
			for i in range(8):
				var a2 := TAU * float(i) / 8.0 + PI / 8.0
				plate.append(f * (cos(a2) * 11.0 + 1.0) + s * sin(a2) * 11.5)
			poly(ci, plate, c["coat"], 1.6)
			for x in [-6.5, 0.0, 6.5]:
				var pouch: Vector2 = f * 8.5 + s * x
				poly(ci, PackedVector2Array([pouch - s * 2.6 - f * 2.2, pouch + s * 2.6 - f * 2.2, pouch + s * 2.6 + f * 2.2, pouch - s * 2.6 + f * 2.2]), Color("4f6e58"), 1.2)
			for sg in [-1.0, 1.0]:
				poly(ci, oval(s * sg * 13.5 + f * 1.5, f, s, 5.5, 4.2, 8), Color("33473a"), 1.6)
		"coil":
			legs(ci, f, s, o, c["boot"])
			# Hooded cloak: a teardrop trailing behind, its hem rippling.
			var cloak := PackedVector2Array()
			for i in range(36):
				var a := TAU * float(i) / 36.0
				var dir := f.rotated(a)
				var back := maxf(0.0, -cos(a))
				var rad := 15.0 + 10.0 * pow(back, 1.5) + sin(a * 6.0 + t * 5.0) * 1.3 * back
				cloak.append(dir * rad)
			poly(ci, cloak, Color(c["coat"]).darkened(0.15))
			disc(ci, Vector2.ZERO, 13.0, c["coat"], 1.6)
			for sg in [-1.0, 1.0]:
				ci.draw_line(s * sg * 6.0 + f * 2.0, s * sg * 7.0 - f * 18.0, Color(Color("aaa5ff"), 0.45 * Color(c["coat"]).a), 1.4)
			# Power coil on the back.
			var pack := -f * 9.0
			ci.draw_circle(pack, 7.5, Color(Color("baa4ff"), 0.18))
			ci.draw_arc(pack, 6.0, 0.0, TAU, 20, INK, 4.4, true)
			ci.draw_arc(pack, 6.0, 0.0, TAU, 20, Color("baa4ff"), 2.6, true)
			ci.draw_circle(pack, 2.4 + 0.6 * sin(t * 8.0), c["trim"])
			ci.draw_circle(pack + Vector2.from_angle(t * 5.0) * 6.0, 1.4, Color.WHITE)
			for sg in [-1.0, 1.0]:
				disc(ci, s * sg * 12.0 + f * 1.5, 4.6, Color(c["coat"]).lightened(0.1), 1.6)
		_:
			legs(ci, f, s, o, c["boot"])
			# Scout: scarf streaming behind, messenger bag, light jacket.
			var tail := PackedVector2Array()
			for i in range(6):
				var u := float(i) / 5.0
				tail.append(-f * (5.0 + u * 21.0) + s * sin(t * 11.0 - u * 3.0) * 4.5 * u)
			ci.draw_polyline(tail, INK, 8.0, true)
			ci.draw_polyline(tail, c["trim"], 5.0, true)
			disc(ci, -f * 10.0 - s * 8.0, 4.2, Color("5a4630"), 1.6)
			disc(ci, Vector2.ZERO, 14.5, c["coat"])
			ci.draw_line(f * 14.0, f * 3.0, Color("d7985a"), 1.6)
			ci.draw_line(f * 6.0 + s * 10.0, -f * 9.0 - s * 7.0, Color("3a2c22"), 2.2)
			for sg in [-1.0, 1.0]:
				disc(ci, s * sg * 12.5 + f * 2.5, 4.8, Color(c["coat"]).lightened(0.16), 1.6)
			ci.draw_arc(f * 2.0, 11.0, f.angle() - 1.0, f.angle() + 1.0, 14, Color(c["trim"]).darkened(0.15), 4.5)

# ------------------------------------------------------------------ heads
static func draw_head(ci: CanvasItem, id: String, f: Vector2, s: Vector2, c: Dictionary, o: Dictionary) -> void:
	var head := f * 4.0
	var t := float(o.get("t", 0.0))
	var back := f.y < -0.38
	match id:
		"ember":
			# Firefighter helmet: long back brim, crest ridge, front shield;
			# a round gas mask filter shows under the front.
			disc(ci, head + f * 8.0, 3.4, Color("2a2a2a"), 1.4)
			ci.draw_line(head + f * 8.0 - s * 2.0, head + f * 8.0 + s * 2.0, Color("6b6b6b"), 1.0)
			poly(ci, oval(head - f * 3.0, f, s, 11.0, 9.5), c["hat"])
			ci.draw_line(head + f * 5.0, head - f * 11.0, Color(c["hat"]).darkened(0.3), 3.0)
			ci.draw_line(head + f * 5.0, head - f * 11.0, Color(c["hat"]).lightened(0.25), 1.0)
			if not back:
				poly(ci, PackedVector2Array([head + f * 9.5, head + f * 6.0 + s * 3.0, head + f * 3.5, head + f * 6.0 - s * 3.0]), Color("f2d23a"), 1.2)
				ci.draw_arc(head + f * 2.0, 8.5, f.angle() - 0.7, f.angle() + 0.7, 10, Color(1.0, 0.6, 0.2, 0.8 * Color(c["hat"]).a), 2.0)
		"ace":
			# Wide-brim hat hides the face: curled brim edges, creased crown, gold band.
			poly(ci, oval(head - f * 1.0, f, s, 12.0, 13.5, 28), c["hat"])
			for sg in [-1.0, 1.0]:
				ci.draw_arc(head - f * 1.0, 12.0, (s * sg).angle() - 0.8, (s * sg).angle() + 0.8, 10, Color(c["hat"]).lightened(0.22), 2.2)
			poly(ci, oval(head - f * 1.0, f, s, 7.5, 5.8), Color(c["hat"]).darkened(0.22), 1.6)
			ci.draw_line(head + f * 5.0, head - f * 7.0, Color(c["hat"]).darkened(0.45), 1.4)
			var band := oval(head - f * 1.0, f, s, 7.7, 6.0)
			band.append(band[0])
			ci.draw_polyline(band, Color("ffd080"), 1.6, true)
			if not back:
				poly(ci, PackedVector2Array([head + f * 11.5 - s * 4.0, head + f * 11.5 + s * 4.0, head + f * 15.0]), c["trim"], 1.2)
		"vector":
			# Helmet with ear cups and a night-vision mount.
			for sg in [-1.0, 1.0]:
				disc(ci, head + s * sg * 9.2, 2.8, Color("1f2621"), 1.4)
			disc(ci, head, 9.0, c["hat"])
			ci.draw_arc(head, 6.5, f.angle() + 2.2, f.angle() + 4.1, 10, Color(1, 1, 1, 0.18), 2.0)
			if not back:
				poly(ci, PackedVector2Array([head + f * 5.0 - s * 4.0, head + f * 5.0 + s * 4.0, head + f * 8.0 + s * 4.0, head + f * 8.0 - s * 4.0]), Color("1f2621"), 1.2)
				for sg in [-1.0, 1.0]:
					var tube: Vector2 = head + f * 7.0 + s * sg * 2.6
					ci.draw_line(tube, tube + f * 5.0, INK, 3.4)
					ci.draw_line(tube, tube + f * 5.0, Color("2b302c"), 2.2)
					ci.draw_circle(tube + f * 5.2, 1.7, Color(c["trim"]).lightened(0.2 * sin(t * 3.0)))
		"coil":
			# Deep hood with a glowing visor slit and a pointed tip behind.
			poly(ci, PackedVector2Array([head - f * 6.0 - s * 5.0, head - f * 14.0, head - f * 6.0 + s * 5.0]), c["hat"], 1.6)
			disc(ci, head, 9.6, c["hat"])
			if not back:
				disc(ci, head + f * 3.5, 5.6, Color("120e24"), 1.0)
				ci.draw_arc(head + f * 2.0, 6.0, f.angle() - 0.85, f.angle() + 0.85, 12, Color(c["trim"]).lightened(0.15 * sin(t * 5.0)), 2.4)
			ci.draw_arc(head, 9.6, f.angle() - 1.2, f.angle() + 1.2, 12, Color(Color("baa4ff"), 0.7 * Color(c["hat"]).a), 1.6)
		_:
			# Scout: cap with the bill pointing where he aims, so his facing reads at a glance.
			disc(ci, head, 7.8, Color("965a37") if back else c["skin"])
			poly(ci, PackedVector2Array([head + f * 3.0 - s * 6.5, head + f * 3.0 + s * 6.5, head + f * 9.5 + s * 5.0,
				head + f * 12.0, head + f * 9.5 - s * 5.0]), Color(c["hat"]).darkened(0.25), 1.6)
			disc(ci, head - f * 1.0, 7.0, c["hat"], 1.8)
			ci.draw_line(head - f * 1.0 - s * 5.0, head - f * 1.0 + s * 5.0, Color(c["trim"]), 1.6)
			ci.draw_circle(head - f * 1.0, 1.4, Color(c["hat"]).lightened(0.3))

# ------------------------------------------------------------------ bash moves
## PHASE runs 0..1 over the bash. The swing covers the same cone as the hit.
static func draw_bash(ci: CanvasItem, id: String, p: Vector2, dir: Vector2, phase: float, c: Dictionary, k: float, t: float) -> void:
	var ang := dir.angle()
	var e := 1.0 - pow(1.0 - minf(1.0, phase * 1.6), 3.0)
	var fade := 1.0 - maxf(0.0, phase - 0.55) / 0.45
	var from := ang - 1.25
	var now := from + 2.5 * e
	var hand := p + Vector2.from_angle(now) * 14.0 * k * 0.8
	match id:
		"vector":
			# Shield shove: a riot shield driven straight out, then pulled back.
			var push := sin(minf(1.0, phase * 1.4) * PI)
			var front := p + dir * (18.0 + 30.0 * push)
			var side := dir.orthogonal()
			poly(ci, PackedVector2Array([front - side * 20.0, front + side * 20.0, front + side * 18.0 + dir * 6.0, front - side * 18.0 + dir * 6.0]), Color(Color("26302c"), fade))
			ci.draw_line(front - side * 14.0 + dir * 3.0, front + side * 14.0 + dir * 3.0, Color(c["trim"], fade), 2.0)
			draw_arm(ci, p + side * 6.0, front - dir * 1.0, p, c, k)
			if push > 0.8:
				for i in range(5):
					var a := ang + (float(i) - 2.0) * 0.3
					ci.draw_line(p + Vector2.from_angle(a) * 62.0, p + Vector2.from_angle(a) * 82.0, Color(1, 1, 1, 0.8), 2.5)
		"coil":
			# Shock palm: an open glowing hand and a cone of crackling rings.
			var reach := 18.0 + 16.0 * sin(minf(1.0, phase * 1.5) * PI)
			var palm := p + dir * reach
			draw_arm(ci, p, palm, p, c, k)
			ci.draw_circle(palm, 6.0, Color(Color("baa4ff"), 0.5 * fade))
			ci.draw_circle(palm, 3.5, Color(Color("8ff8ff"), fade))
			for ring in range(3):
				var rad := 30.0 + (phase * 70.0 + ring * 18.0)
				if rad < 92.0:
					ci.draw_arc(p, rad, ang - 1.1, ang + 1.1, 18, Color(Color("baa4ff"), 0.85 * fade * (1.0 - rad / 95.0)), 3.0, true)
			for i in range(3):
				var a2 := ang + sin(t * 37.0 + i * 2.0) * 0.9
				var pts := PackedVector2Array([palm])
				for j in range(4):
					pts.append(palm + Vector2.from_angle(a2) * (12.0 + j * 14.0) * (0.4 + phase) + Vector2.from_angle(a2 + PI * 0.5) * sin(t * 50.0 + j * 3.0 + i) * 5.0)
				ci.draw_polyline(pts, Color(Color("cfeaff"), 0.9 * fade), 1.6)
		"ace":
			# Bullwhip: the lash trails the swing and cracks at the far end.
			var length := 88.0
			var pts := PackedVector2Array()
			for i in range(14):
				var u := float(i) / 13.0
				var lag := (1.0 - e) * 1.4 * u * u
				pts.append(hand + Vector2.from_angle(now - lag) * length * u * (0.35 + 0.65 * minf(1.0, phase * 2.5)))
			draw_arm(ci, p, hand, p, c, k)
			ci.draw_polyline(pts, Color(INK, fade), 4.0, true)
			ci.draw_polyline(pts, Color(Color("8a5a36"), fade), 2.4, true)
			if phase > 0.45 and phase < 0.75:
				var tip := pts[pts.size() - 1]
				for i in range(6):
					var a3 := float(i) * TAU / 6.0
					ci.draw_line(tip, tip + Vector2.from_angle(a3) * 9.0, Color(1, 0.95, 0.7, 0.9), 2.0)
				ci.draw_circle(tip, 3.5, Color.WHITE)
		"ember":
			# Fire axe chop with a burning smear.
			var length := 62.0
			smear(ci, p, from, now, length + 6.0, Color(1.0, 0.55, 0.15), fade)
			var tip := p + Vector2.from_angle(now) * length
			draw_arm(ci, p, hand, p, c, k)
			ci.draw_line(hand, tip, INK, 6.0)
			ci.draw_line(hand, tip, Color("a8322a"), 3.6)
			var side := Vector2.from_angle(now + PI * 0.5)
			poly(ci, PackedVector2Array([tip - Vector2.from_angle(now) * 12.0, tip - Vector2.from_angle(now) * 12.0 + side * 13.0,
				tip + side * 15.0, tip]), Color("c9ced8"), 1.8)
			ci.draw_line(tip - Vector2.from_angle(now) * 12.0 + side * 13.0, tip + side * 15.0, Color.WHITE, 1.4)
			for i in range(4):
				var a4 := now - 0.2 * float(i + 1)
				ci.draw_circle(p + Vector2.from_angle(a4) * (length - 6.0 + sin(t * 30.0 + i) * 6.0), 2.5 - i * 0.4, Color(1.0, 0.8, 0.3, fade))
		_:
			# Scout: baseball bat swing.
			var length := 64.0
			smear(ci, p, from, now, length, Color(1.0, 0.96, 0.75), fade)
			var tip := p + Vector2.from_angle(now) * length
			var dir2 := Vector2.from_angle(now)
			var side2 := dir2.orthogonal()
			draw_arm(ci, p, hand, p, c, k)
			poly(ci, PackedVector2Array([hand - side2 * 2.0, hand + side2 * 2.0, tip + side2 * 4.5, tip - side2 * 4.5]), Color("c8945a"), 1.8)
			ci.draw_line(hand, hand + dir2 * 12.0, Color("2a2a2a"), 4.0)
			ci.draw_circle(tip, 4.5, Color("b07a48"))

## Crescent smear behind a swung weapon.
static func smear(ci: CanvasItem, p: Vector2, from: float, now: float, r: float, col: Color, fade: float) -> void:
	if now - from < 0.08:
		return
	var pts := PackedVector2Array()
	var steps := 14
	for i in range(steps + 1):
		pts.append(p + Vector2.from_angle(lerpf(from, now, float(i) / float(steps))) * r)
	for i in range(steps, -1, -1):
		var u := float(i) / float(steps)
		pts.append(p + Vector2.from_angle(lerpf(from, now, u)) * r * (1.0 - 0.3 * u))
	ci.draw_colored_polygon(pts, Color(col, 0.45 * fade))

## Screen muzzle for a gun in SLOT, matching Weapons.hand_pos/muzzle_pos.
static func muzzle_for(centre: Vector2, f: Vector2, k: float, gun_id: String, slot: int, count: int) -> Vector2:
	var s := f.orthogonal()
	var side: float = [16.0, -16.0, 0.0][clampi(slot, 0, 2)]
	if count == 1:
		side = 3.5
	var forward := 6.0 if slot == 2 else 12.0
	return centre + (s * side + f * (forward + GunModels.reach(gun_id))) * (k / 1.25)

## Character-select model: the runner holding their starting gun.
static func portrait(ci: CanvasItem, id: String, gun_id: String, centre: Vector2, k: float, t: float) -> void:
	var f := Vector2(0.55, 0.83).normalized()
	var s := f.orthogonal()
	var guns := [{"id": gun_id, "aim": f, "muzzle": muzzle_for(centre, f, k, gun_id, 0, 1)}]
	ci.draw_set_transform(centre + Vector2(0, 12.0 * k), 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, 15.0 * k, Color(0, 0, 0, 0.35))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rig(ci, id, centre, f, k, guns, {"t": t})

# ------------------------------------------------------------------ bust portraits
## Front-facing head-and-shoulders portrait for the character select screen.
## Drawn in a 100x100 design box centred on C; SIZE is the box width in px.
## The bottom edge (y = +50) is flat so it sits on a panel's lower border.
static func bust(ci: CanvasItem, id: String, c: Vector2, size: float, t: float) -> void:
	var u := size / 100.0
	var hy := sin(t * 2.2) * 0.8
	ci.draw_set_transform(c, 0.0, Vector2.ONE * u)
	var p: Dictionary = PALETTES.get(id, PALETTES["scout"])
	var coat := Color(str(p["coat"]))
	var skin := Color(str(p["skin"]))
	var trim := Color(str(p["trim"]))
	var hat := Color(str(p["hat"]))
	var torso := PackedVector2Array([Vector2(-48, 50), Vector2(-44, 30), Vector2(-26, 18 + hy), Vector2(26, 18 + hy), Vector2(44, 30), Vector2(48, 50)])
	if id == "coil":
		torso = PackedVector2Array([Vector2(-50, 50), Vector2(-40, 16), Vector2(0, -6 + hy), Vector2(40, 16), Vector2(50, 50)])
	poly(ci, torso, coat, 2.4)
	if id != "coil":
		ci.draw_rect(Rect2(-8, 8 + hy, 16, 14), skin.darkened(0.18))
		for side in [-1.0, 1.0]:
			disc(ci, Vector2(side * 21.0, -1 + hy), 5.0, skin, 1.8)
		poly(ci, oval(Vector2(0, -2 + hy), Vector2.UP, Vector2.RIGHT, 24.0, 20.5, 28), skin, 2.4)
	match id:
		"ember":
			bust_ember(ci, hy, coat, trim, hat, t)
		"ace":
			bust_ace(ci, hy, coat, trim, hat, t)
		"vector":
			bust_vector(ci, hy, coat, trim, hat, t)
		"coil":
			bust_coil(ci, hy, trim, hat, t)
		_:
			bust_scout(ci, hy, coat, trim, hat, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func face(ci: CanvasItem, hy: float, eye: Color, squint: bool = false) -> void:
	for side in [-1.0, 1.0]:
		var e := Vector2(side * 8.0, -1 + hy)
		if squint:
			ci.draw_line(e - Vector2(4, 0), e + Vector2(4, 0), INK, 2.2)
			ci.draw_circle(e + Vector2(0, 1.4), 1.6, eye)
		else:
			ci.draw_circle(e, 4.2, Color.WHITE)
			ci.draw_arc(e, 4.2, 0.0, TAU, 14, INK, 1.4, true)
			ci.draw_circle(e + Vector2(0.6, 0.4), 2.2, eye)
			ci.draw_circle(e + Vector2(1.3, -0.6), 0.8, Color.WHITE)
	ci.draw_line(Vector2(0, 2 + hy), Vector2(-1.5, 7 + hy), Color(INK, 0.5), 1.6)

static func bust_scout(ci: CanvasItem, hy: float, coat: Color, trim: Color, hat: Color, t: float) -> void:
	# Jacket collar and zip.
	for side in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(side * 26, 18 + hy), Vector2(side * 10, 22 + hy), Vector2(side * 16, 40), Vector2(side * 30, 30)]), coat.lightened(0.15), 1.8)
	ci.draw_line(Vector2(0, 26 + hy), Vector2(0, 50), Color("d7985a"), 2.0)
	# Red scarf wrap with a tail blowing to the side.
	poly(ci, PackedVector2Array([Vector2(-18, 12 + hy), Vector2(18, 12 + hy), Vector2(20, 22 + hy), Vector2(-20, 22 + hy)]), trim, 2.0)
	var flap := sin(t * 6.0) * 3.0
	poly(ci, PackedVector2Array([Vector2(12, 18 + hy), Vector2(34, 26 + flap), Vector2(40, 22 + flap), Vector2(18, 14 + hy)]), trim.darkened(0.1), 2.0)
	face(ci, hy, Color("2a4a6a"))
	for k in range(3):
		ci.draw_circle(Vector2(-12 + k * 2.5, 5 + hy + (k % 2)), 0.9, Color("b9714a"))
		ci.draw_circle(Vector2(8 + k * 2.5, 5 + hy + (k % 2)), 0.9, Color("b9714a"))
	ci.draw_arc(Vector2(1, 8 + hy), 5.0, 0.3, 2.6, 8, INK, 1.8, true)
	# Messy hair under a backwards cap, goggles pushed up on it.
	for k in range(5):
		var x := -20.0 + k * 10.0
		poly(ci, PackedVector2Array([Vector2(x - 5, -14 + hy), Vector2(x + 1, -6 + hy + (k % 2) * 2), Vector2(x + 6, -14 + hy)]), Color("6b3b22"), 1.4)
	poly(ci, oval(Vector2(0, -16 + hy), Vector2.UP, Vector2.RIGHT, 14.0, 24.0, 24), hat, 2.4)
	ci.draw_rect(Rect2(-24, -14 + hy, 48, 4), hat.darkened(0.25))
	poly(ci, oval(Vector2(0, -12 + hy), Vector2.UP, Vector2.RIGHT, 3.5, 6.0, 12), Color("6b3b22"), 1.4)
	ci.draw_line(Vector2(-25, -20 + hy), Vector2(25, -20 + hy), Color("2b2631"), 3.0)
	for side in [-1.0, 1.0]:
		disc(ci, Vector2(side * 9.0, -21 + hy), 6.2, Color("6e5a48"), 1.8)
		ci.draw_circle(Vector2(side * 9.0, -21 + hy), 4.4, Color("a6e1e9"))
		ci.draw_line(Vector2(side * 9.0 - 2.0, -23 + hy), Vector2(side * 9.0 + 1.0, -24.5 + hy), Color.WHITE, 1.4)

static func bust_ember(ci: CanvasItem, hy: float, coat: Color, trim: Color, hat: Color, t: float) -> void:
	# Turnout coat with reflective bands and a gas mask hanging at the neck.
	for y in [34.0, 42.0]:
		ci.draw_line(Vector2(-45, y), Vector2(45, y), trim, 4.0)
		ci.draw_line(Vector2(-45, y + 2.5), Vector2(45, y + 2.5), Color(0.85, 0.88, 0.9), 1.2)
	poly(ci, PackedVector2Array([Vector2(-14, 16 + hy), Vector2(14, 16 + hy), Vector2(11, 30 + hy), Vector2(-11, 30 + hy)]), Color("2a2a2a"), 2.0)
	for side in [-1.0, 1.0]:
		disc(ci, Vector2(side * 9.0, 25 + hy), 4.0, Color("4a4a4a"), 1.6)
		ci.draw_line(Vector2(side * 9.0 - 2.5, 25 + hy), Vector2(side * 9.0 + 2.5, 25 + hy), Color("8a8a8a"), 1.0)
	face(ci, hy, Color("5a3a1a"))
	ci.draw_line(Vector2(-13, -7 + hy), Vector2(-4, -5 + hy), INK, 2.4)
	ci.draw_line(Vector2(13, -7 + hy), Vector2(4, -5 + hy), INK, 2.4)
	ci.draw_line(Vector2(-4, 10 + hy), Vector2(5, 10 + hy), INK, 2.0)
	ci.draw_circle(Vector2(-12, 7 + hy), 3.0, Color(0.15, 0.12, 0.1, 0.35))
	ci.draw_circle(Vector2(14, 3 + hy), 2.2, Color(0.15, 0.12, 0.1, 0.35))
	# Helmet: wide brim, dome, ridge and a front shield badge.
	poly(ci, oval(Vector2(0, -7 + hy), Vector2.UP, Vector2.RIGHT, 5.0, 34.0, 24), hat.darkened(0.15), 2.2)
	poly(ci, oval(Vector2(0, -16 + hy), Vector2.UP, Vector2.RIGHT, 16.0, 25.0, 26), hat, 2.4)
	ci.draw_line(Vector2(0, -31 + hy), Vector2(0, -12 + hy), hat.lightened(0.25), 3.0)
	poly(ci, PackedVector2Array([Vector2(-8, -24 + hy), Vector2(8, -24 + hy), Vector2(7, -13 + hy), Vector2(0, -9 + hy), Vector2(-7, -13 + hy)]), Color("f2d23a"), 1.8)
	ci.draw_circle(Vector2(0, -17 + hy), 2.6, Color("c8333a"))
	ci.draw_arc(Vector2(0, -7 + hy), 30.0, 0.25, PI - 0.25, 16, Color(1.0, 0.6, 0.2, 0.5 + 0.3 * sin(t * 4.0)), 1.6)

static func bust_ace(ci: CanvasItem, hy: float, coat: Color, trim: Color, hat: Color, t: float) -> void:
	# Duster lapels, vest and sheriff star.
	poly(ci, PackedVector2Array([Vector2(-14, 22 + hy), Vector2(14, 22 + hy), Vector2(10, 50), Vector2(-10, 50)]), Color("3a2a1e"), 1.8)
	for side in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(side * 26, 18 + hy), Vector2(side * 12, 22 + hy), Vector2(side * 14, 46), Vector2(side * 32, 34)]), coat.lightened(0.12), 1.8)
	var star := PackedVector2Array()
	for i in range(10):
		star.append(Vector2(-22, 38) + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (6.0 if i % 2 == 0 else 2.6))
	poly(ci, star, Color("ffd080"), 1.4)
	# Bandana knotted at the neck.
	poly(ci, PackedVector2Array([Vector2(-16, 14 + hy), Vector2(16, 14 + hy), Vector2(0, 32 + hy)]), trim, 2.0)
	face(ci, hy, Color("3a5a2a"), true)
	for k in range(9):
		ci.draw_circle(Vector2(-12 + k * 3.0, 14 + hy - absf(k - 4) * 0.6), 0.7, Color(0.3, 0.2, 0.15, 0.6))
	ci.draw_line(Vector2(-3, 9 + hy), Vector2(4, 9.5 + hy), INK, 1.8)
	ci.draw_line(Vector2(3, 9.5 + hy), Vector2(12, 6 + hy + sin(t * 1.5)), Color("e8d0a0"), 1.6)
	# Shadow under the brim, then the hat: pinched crown and curled brim.
	ci.draw_colored_polygon(oval(Vector2(0, -6 + hy), Vector2.UP, Vector2.RIGHT, 5.0, 22.0, 16), Color(0, 0, 0, 0.28))
	poly(ci, PackedVector2Array([Vector2(-42, -16 + hy), Vector2(-30, -10 + hy), Vector2(0, -7 + hy), Vector2(30, -10 + hy), Vector2(42, -16 + hy),
		Vector2(34, -13 + hy), Vector2(0, -12 + hy), Vector2(-34, -13 + hy)]), hat, 2.2)
	poly(ci, PackedVector2Array([Vector2(-20, -12 + hy), Vector2(-18, -32 + hy), Vector2(-6, -36 + hy), Vector2(0, -31 + hy), Vector2(6, -36 + hy),
		Vector2(18, -32 + hy), Vector2(20, -12 + hy)]), hat.darkened(0.08), 2.4)
	ci.draw_rect(Rect2(-20, -17 + hy, 40, 4), Color("ffd080"))
	ci.draw_line(Vector2(0, -31 + hy), Vector2(0, -20 + hy), hat.darkened(0.35), 1.4)

static func bust_vector(ci: CanvasItem, hy: float, coat: Color, trim: Color, hat: Color, t: float) -> void:
	# Plate carrier with pouches.
	poly(ci, PackedVector2Array([Vector2(-30, 26), Vector2(30, 26), Vector2(34, 50), Vector2(-34, 50)]), coat.darkened(0.1), 2.0)
	for x in [-20.0, -7.0, 6.0, 19.0]:
		poly(ci, PackedVector2Array([Vector2(x - 5, 32), Vector2(x + 5, 32), Vector2(x + 5, 46), Vector2(x - 5, 46)]), Color("4f6e58"), 1.6)
		ci.draw_line(Vector2(x - 4, 35), Vector2(x + 4, 35), INK, 1.0)
	ci.draw_rect(Rect2(-10, 27, 20, 3), trim)
	face(ci, hy, Color("3a3a2a"))
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(side * 4.0, 4 + hy), Vector2(side * 13.0, 4 + hy), Color(0.1, 0.1, 0.1, 0.55), 2.4)
	# Balaclava over the lower face.
	poly(ci, PackedVector2Array([Vector2(-20, 6 + hy), Vector2(20, 6 + hy), Vector2(16, 20 + hy), Vector2(0, 24 + hy), Vector2(-16, 20 + hy)]), Color("2a332d"), 2.0)
	# Headset with a boom mic.
	for side in [-1.0, 1.0]:
		disc(ci, Vector2(side * 23.0, -2 + hy), 6.5, Color("1f2621"), 1.8)
	ci.draw_polyline(PackedVector2Array([Vector2(-23, 4 + hy), Vector2(-18, 12 + hy), Vector2(-8, 13 + hy)]), INK, 2.2)
	ci.draw_circle(Vector2(-7, 13 + hy), 2.2, Color("1f2621"))
	# Helmet with the night vision flipped up.
	poly(ci, oval(Vector2(0, -15 + hy), Vector2.UP, Vector2.RIGHT, 17.0, 26.0, 26), hat, 2.4)
	ci.draw_line(Vector2(-26, -8 + hy), Vector2(26, -8 + hy), hat.darkened(0.3), 3.0)
	ci.draw_rect(Rect2(-6, -30 + hy, 12, 6), Color("1f2621"))
	for side in [-1.0, 1.0]:
		var tube := Vector2(side * 5.5, -37 + hy)
		poly(ci, PackedVector2Array([tube + Vector2(-3.5, 9), tube + Vector2(3.5, 9), tube + Vector2(3.5, -4), tube + Vector2(-3.5, -4)]), Color("2b302c"), 1.6)
		ci.draw_circle(tube + Vector2(0, -4), 3.0, trim.lightened(0.15 + 0.15 * sin(t * 3.0 + side)))
	ci.draw_arc(Vector2(0, -15 + hy), 20.0, PI + 0.5, PI + 1.2, 8, Color(1, 1, 1, 0.2), 3.0)

static func bust_coil(ci: CanvasItem, hy: float, trim: Color, hat: Color, t: float) -> void:
	for side in [-1.0, 1.0]:
		ci.draw_polyline(PackedVector2Array([Vector2(side * 12, 18 + hy), Vector2(side * 18, 30), Vector2(side * 18, 44), Vector2(side * 26, 50)]), Color(Color("aaa5ff"), 0.6), 1.6)
	# Floating power coil behind the shoulder.
	var ring := Vector2(32, 8 + sin(t * 2.0) * 2.0)
	ci.draw_arc(ring, 9.0, 0.0, TAU, 20, INK, 5.0, true)
	ci.draw_arc(ring, 9.0, 0.0, TAU, 20, Color("baa4ff"), 3.0, true)
	ci.draw_circle(ring + Vector2.from_angle(t * 4.0) * 9.0, 1.8, Color.WHITE)
	# Deep hood, face lost in shadow, glowing visor.
	poly(ci, PackedVector2Array([Vector2(-30, 26 + hy), Vector2(-28, -14 + hy), Vector2(-12, -38 + hy), Vector2(0, -44 + hy), Vector2(12, -38 + hy),
		Vector2(28, -14 + hy), Vector2(30, 26 + hy), Vector2(0, 20 + hy)]), hat, 2.4)
	poly(ci, oval(Vector2(0, -2 + hy), Vector2.UP, Vector2.RIGHT, 21.0, 18.0, 24), Color("120e24"), 1.6)
	ci.draw_rect(Rect2(-15, -5 + hy, 30, 7), Color(trim, 0.25))
	ci.draw_rect(Rect2(-14, -3.5 + hy, 28, 4), trim)
	var scan := -14.0 + fposmod(t * 0.8, 1.0) * 26.0
	ci.draw_rect(Rect2(scan, -4 + hy, 3, 5), Color.WHITE)
	for k in range(3):
		ci.draw_circle(Vector2(-4 + k * 4.0, 10 + hy), 1.1, Color(trim, 0.6))
	ci.draw_arc(Vector2(0, -2 + hy), 21.0, PI + 0.4, TAU - 0.4, 16, Color(Color("baa4ff"), 0.7), 1.6)

## Bust portrait holding the starting gun across the chest, in the middle of
## the frame: trigger hand on the grip, support hand on the foregrip (Ace
## keeps it one-handed, tipped up like a gunslinger).
static func bust_with_gun(ci: CanvasItem, id: String, gun_id: String, c: Vector2, size: float, t: float) -> void:
	bust(ci, id, c, size, t)
	var u := size / 100.0
	var length := float(GunModels.LENGTH.get(gun_id, 20.0))
	var gs := (34.0 + length * 0.6) / length * u * 0.95
	var ang := -0.55 if id == "ace" else -0.18
	var dir := Vector2.from_angle(ang)
	var mid := c + Vector2(2.0 * u, 30.0 * u + sin(t * 2.2) * 0.8 * u)
	var muzzle := mid + dir * length * gs * 0.5
	ci.draw_set_transform(muzzle, ang, Vector2.ONE * gs)
	GunModels.draw(ci, gun_id, {"t": t})
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var glove := Color(str(PALETTES.get(id, PALETTES["scout"])["glove"]))
	var sleeve := Color(str(PALETTES.get(id, PALETTES["scout"])["sleeve"]))
	var g2: Array = GunModels.grips(gun_id)
	var g0: Vector2 = g2[0]
	var hands: Array = [muzzle + g0.rotated(ang) * gs]
	if id != "ace":
		var g1: Vector2 = g2[1] if g2[1] != null else g0 + Vector2(2.0, 3.5)
		hands.append(muzzle + g1.rotated(ang) * gs)
	for i in range(hands.size()):
		var hand: Vector2 = hands[i]
		# Forearm rising from the bottom of the frame to the hand.
		var from := hand + Vector2(-7.0 * u if i == 0 else 5.0 * u, 18.0 * u)
		ci.draw_line(from, hand, INK, 7.5 * u)
		ci.draw_line(from, hand, sleeve, 5.0 * u)
		disc(ci, hand, 3.6 * u, glove, 1.6 * u)
