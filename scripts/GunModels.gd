extends RefCounted
## Procedural side-profile guns, drawn in the hero's hands.
## Local space: the muzzle is the origin, the barrel points along +X and the
## grip hangs toward +Y, so the caller only rotates (and flips Y when aiming
## left so no gun is ever upside down). GRIPS says where the hands hold it.

const INK := Color(0.07, 0.05, 0.09)
const STEEL := Color("5d6676")
const STEEL_HI := Color("b3bccb")
const DARK := Color("2b303c")
const WOOD := Color("8a5631")
const WOOD_HI := Color("b9784a")
const GOLD := Color("f2c14e")
const RED := Color("cf3440")
const OLIVE := Color("5b6a2e")

## [trigger hand, support hand]. A null support hand means a one-handed
## design: when it is the only gun, the off hand cups the trigger hand.
const GRIPS = {
	"pistol": [Vector2(-12, 5), null],
	"revolver": [Vector2(-16, 5), null],
	"shotgun": [Vector2(-30, 4), Vector2(-12, 2)],
	"smg": [Vector2(-17, 5), Vector2(-6.5, 4)],
	"minigun": [Vector2(-37, 2), Vector2(-28, -10)],
	"sniper": [Vector2(-32, 5), Vector2(-17, 1)],
	"rocket": [Vector2(-17, 7), Vector2(-9, 6)],
	"grenade": [Vector2(-22, 6), Vector2(-7, 3)],
	"laser": [Vector2(-17, 7), Vector2(-8.5, 5)],
	"tesla": [Vector2(-19, 6), null],
	"flame": [Vector2(-25, 5), Vector2(-10, 3)],
	"disc": [Vector2(-18, 6), null],
	"boomerang": [Vector2(-12, 1), null],
	"rail": [Vector2(-34, 6), Vector2(-18.5, 4.5)],
	"bees": [Vector2(-20, 6), null],
	"bowling": [Vector2(-20, 8.5), Vector2(-9.5, 7.5)],
	"nailgun": [Vector2(-15.5, 6.5), null],
	"chicken": [Vector2(-13, 6), null],
	"bubble": [Vector2(-18, 7), null],
	"pinball": [Vector2(-15, 7), null],
	"splitbow": [Vector2(-3, 0), Vector2(-13, 0)],
	"snow": [Vector2(-19, 7), Vector2(-9, 5)],
}

const LENGTH = {
	"pistol": 16.0, "revolver": 20.0, "shotgun": 41.0, "smg": 28.0, "minigun": 37.0,
	"sniper": 44.0, "rocket": 32.0, "grenade": 34.0, "laser": 26.0, "tesla": 24.0,
	"flame": 27.0, "disc": 24.0, "boomerang": 14.0, "rail": 44.0, "bees": 26.0,
	"bowling": 30.0, "nailgun": 22.0, "chicken": 18.0, "bubble": 22.0, "pinball": 25.0,
	"splitbow": 16.0, "snow": 24.0,
}

## Short guns are drawn larger so a pistol still reads in a fist next to a
## sniper rifle; long guns stay at 1x so they do not swamp the body.
static func size(id: String) -> float:
	return 1.0 + clampf((34.0 - float(LENGTH.get(id, 20.0))) / 30.0, 0.0, 0.7)

## Distance from the trigger hand to the muzzle, at in-game size.
static func reach(id: String) -> float:
	var g0: Vector2 = grips(id)[0]
	return maxf(6.0, -g0.x * size(id))

static func grips(id: String) -> Array:
	return GRIPS.get(id, [Vector2(-12, 5), null])

static func shape(ci: CanvasItem, pts: Array, fill: Color, w: float = 1.4) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, fill)
	p.append(p[0])
	ci.draw_polyline(p, INK, w, true)

static func box(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, fill: Color, w: float = 1.4) -> void:
	shape(ci, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], fill, w)

static func grip(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, fill: Color) -> void:
	# Pistol grip raked back like a real one.
	shape(ci, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - 1.5, y1), Vector2(x0 - 2.0, y1)], fill)

static func guard(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_polyline(PackedVector2Array([Vector2(x0, y), Vector2(x0, y + 3.5), Vector2(x1, y + 3.5), Vector2(x1 + 1.0, y)]), INK, 1.4, true)

static func shine(ci: CanvasItem, x0: float, x1: float, y: float, a: float = 0.55) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, a), 1.0)

## ST keys: t (time), firing (bool), charge 0..1, evolved (bool).
static func draw(ci: CanvasItem, id: String, st: Dictionary = {}) -> void:
	var t := float(st.get("t", 0.0))
	var firing := bool(st.get("firing", false))
	match id:
		"pistol":
			box(ci, -15, -0.5, -3, 2, DARK)
			grip(ci, -15, -10.5, 1.5, 10, RED)
			ci.draw_line(Vector2(-14.5, 4), Vector2(-11, 4), Color(1, 1, 1, 0.25), 1.0)
			guard(ci, -9.5, -5, 2)
			box(ci, -16, -4.5, 0, -0.5, STEEL)
			for x in [-14.5, -13.0, -11.5]:
				ci.draw_line(Vector2(x, -4), Vector2(x, -1.5), DARK, 1.0)
			shine(ci, -10, -1, -3.7)
			box(ci, -1.5, -4, 0.5, -1, GOLD, 1.0)
		"revolver":
			grip(ci, -18, -13.5, 1, 9.5, WOOD)
			ci.draw_line(Vector2(-17, 3), Vector2(-15.5, 8), WOOD_HI, 1.0)
			box(ci, -19, -4, -16, 1.5, DARK)
			shape(ci, [Vector2(-18, -4), Vector2(-20.5, -6.5), Vector2(-19, -3)], DARK, 1.0)
			guard(ci, -15.5, -11.5, 1.5)
			box(ci, -16, -4.8, -10, 1.6, STEEL)
			for y in [-3.0, -1.0, 0.8]:
				ci.draw_line(Vector2(-15.5, y), Vector2(-10.5, y), DARK, 0.9)
			box(ci, -10, -3.6, 0, -0.8, STEEL)
			shine(ci, -9.5, -1, -3)
			box(ci, -1.5, -5.2, -0.3, -3.6, DARK, 1.0)
		"shotgun":
			shape(ci, [Vector2(-31, -3.5), Vector2(-31, 3), Vector2(-37, 4.5), Vector2(-41, 5.5), Vector2(-41.5, -2.5), Vector2(-36, -3.5)], WOOD)
			ci.draw_line(Vector2(-40, -1), Vector2(-33, -2.5), WOOD_HI, 1.0)
			box(ci, -31, -4, -24, 2, DARK)
			guard(ci, -30, -26, 2)
			box(ci, -24, -0.6, -3, 1.8, DARK)
			box(ci, -26, -3.2, 0, -0.6, STEEL)
			shine(ci, -25, -1, -2.5)
			box(ci, -17, -1.2, -7, 3.8, WOOD)
			for x in [-15.0, -12.5, -10.0]:
				ci.draw_line(Vector2(x, -0.5), Vector2(x, 3.2), Color(WOOD.darkened(0.35)), 1.0)
		"smg":
			ci.draw_polyline(PackedVector2Array([Vector2(-20, -3), Vector2(-28, -3), Vector2(-28, 2.5), Vector2(-21, 2.5)]), STEEL, 1.8, true)
			shape(ci, [Vector2(-13, 2), Vector2(-9.5, 2), Vector2(-8, 11), Vector2(-11.5, 11)], Color("c9952a"))
			grip(ci, -19, -15.5, 2, 9, DARK)
			box(ci, -8.5, 2, -5, 6, DARK)
			box(ci, -20, -4.5, -4, 2, DARK)
			box(ci, -18, -4.5, -8, -3, GOLD, 1.0)
			box(ci, -4, -3.2, 0, 0.2, STEEL)
			shine(ci, -3.5, -0.5, -2.6)
		"minigun":
			var spin := t * (34.0 if firing else 2.0)
			for k in range(3):
				var y := -3.4 + 2.4 * float(k)
				ci.draw_line(Vector2(-24, y), Vector2(0, y), INK, 2.8)
				ci.draw_line(Vector2(-24, y), Vector2(0, y), STEEL, 1.6)
			var hy := -3.4 + fposmod(spin, 1.0) * 4.8
			ci.draw_line(Vector2(-23, hy), Vector2(-1, hy), Color(STEEL_HI, 0.8), 1.0)
			box(ci, -4, -5, -2.4, 2.8, DARK, 1.0)
			box(ci, -15, -5, -13.4, 2.8, DARK, 1.0)
			box(ci, -35, 4.5, -26, 10.5, OLIVE.darkened(0.25))
			ci.draw_line(Vector2(-27, 6), Vector2(-24, 2), GOLD, 1.5)
			box(ci, -36, -6.5, -24, 4.5, OLIVE)
			for x in [-33.0, -31.0, -29.0]:
				ci.draw_line(Vector2(x, -4.5), Vector2(x, 2.5), OLIVE.darkened(0.4), 1.0)
			ci.draw_polyline(PackedVector2Array([Vector2(-32, -6.5), Vector2(-31, -10.5), Vector2(-25, -10.5), Vector2(-24, -6.5)]), INK, 2.4, true)
			box(ci, -39, -1, -36, 6, DARK)
		"sniper":
			shape(ci, [Vector2(-33, -3.5), Vector2(-33, 2), Vector2(-37, 3), Vector2(-44, 4.5), Vector2(-44, -2), Vector2(-39, -3.5)], OLIVE)
			ci.draw_line(Vector2(-42, -1), Vector2(-35, -2.5), OLIVE.lightened(0.3), 1.0)
			grip(ci, -33, -30, 1.5, 8, DARK)
			box(ci, -33, -3.5, -26, 1.5, OLIVE.darkened(0.15))
			box(ci, -26, -1.8, 0, 0.4, DARK)
			box(ci, -2.5, -2.6, 0, 1.2, STEEL, 1.0)
			ci.draw_line(Vector2(-18, 0.4), Vector2(-10, 2.6), STEEL, 1.2)
			box(ci, -31, -5.6, -30, -3.5, DARK, 1.0)
			box(ci, -27, -5.6, -26, -3.5, DARK, 1.0)
			box(ci, -34, -8.6, -23, -5.6, DARK)
			box(ci, -23, -9.6, -21, -4.6, DARK)
			ci.draw_line(Vector2(-21, -8.6), Vector2(-21, -5.6), Color("d8b8ff"), 1.5)
			shine(ci, -33, -24, -7.8, 0.35)
		"rocket":
			grip(ci, -19, -15.5, 4, 10, DARK)
			box(ci, -10.5, 4, -8, 8.5, DARK)
			box(ci, -32, -4, -30, 3, DARK)
			box(ci, -30, -5, -3, 4, OLIVE)
			shine(ci, -29, -4, -3.8, 0.35)
			box(ci, -8, -5, -6, 4, RED, 1.0)
			box(ci, -27, -5, -25, 4, RED, 1.0)
			box(ci, -16, -8, -14, -5, DARK, 1.0)
			shape(ci, [Vector2(-3, -5), Vector2(0, -6.5), Vector2(0, 5.5), Vector2(-3, 4)], DARK)
		"grenade":
			shape(ci, [Vector2(-24, -2.5), Vector2(-24, 3), Vector2(-34, 5), Vector2(-34, -1)], WOOD)
			grip(ci, -24, -20.5, 2, 9, WOOD)
			box(ci, -24, -3, -12, 2.5, DARK)
			box(ci, -12, -4, 0, 2.5, DARK)
			box(ci, -1.5, -4.6, 0.3, 3.1, STEEL, 1.0)
			var drum := Vector2(-17, -0.5)
			ci.draw_circle(drum, 6.4, INK)
			ci.draw_circle(drum, 5.3, Color("6a7a3a"))
			for k in range(6):
				var a := float(k) * TAU / 6.0 + t * 0.6
				ci.draw_circle(drum + Vector2.from_angle(a) * 3.2, 1.1, Color("2f361a"))
		"laser":
			grip(ci, -20, -15.5, 3, 10, DARK)
			box(ci, -10, 3, -7.5, 6.5, DARK)
			box(ci, -26, -3, -24, 2, DARK)
			shape(ci, [Vector2(-24, -4), Vector2(-6, -5.5), Vector2(-3, -3), Vector2(-3, 1.5), Vector2(-6, 3.5), Vector2(-24, 3)], Color("3c6fe0"))
			shape(ci, [Vector2(-18, -4.3), Vector2(-14, -8.5), Vector2(-10, -5)], DARK, 1.0)
			var cell := 0.6 + 0.4 * sin(t * 6.0)
			box(ci, -20, -2, -9, 0.6, Color(Color("c58cff"), cell), 1.0)
			shape(ci, [Vector2(-3, -3.5), Vector2(0.5, -1), Vector2(-3, 1.5)], Color("c58cff"), 1.0)
			ci.draw_line(Vector2(-2.5, -1), Vector2(0, -1), Color.WHITE, 1.0)
		"tesla":
			grip(ci, -21, -17, 3, 10, WOOD)
			box(ci, -22, -4, -10, 3, Color("c9933a"))
			box(ci, -20, -8, -12, -4.5, Color(Color("8fc8ff"), 0.7), 1.0)
			ci.draw_polyline(PackedVector2Array([Vector2(-19, -6), Vector2(-17, -7.2), Vector2(-15.5, -5.5), Vector2(-13.5, -7)]), Color.WHITE, 1.0)
			box(ci, -10, -1.5, -1.5, 0.5, STEEL, 1.0)
			for x in [-9.0, -6.5, -4.0]:
				box(ci, x, -3.5, x + 1.6, 2.5, Color("d4732c"), 1.0)
			ci.draw_circle(Vector2(-0.5, -0.5), 3.2, INK)
			ci.draw_circle(Vector2(-0.5, -0.5), 2.4, Color("8fc8ff"))
			ci.draw_circle(Vector2(-0.5, -0.5), 1.1, Color.WHITE)
			if fposmod(t * 7.0, 1.0) < 0.5 or firing:
				var a := t * 13.0
				ci.draw_polyline(PackedVector2Array([Vector2(-0.5, -0.5), Vector2(-0.5, -0.5) + Vector2.from_angle(a) * 3.0 + Vector2(1, 1),
					Vector2(-0.5, -0.5) + Vector2.from_angle(a) * 5.5]), Color("cfeaff"), 1.0)
		"flame":
			grip(ci, -26.5, -23, 0, 8.5, DARK)
			box(ci, -25, -4.5, -12, 2.5, Color("3a3f4a"))
			ci.draw_circle(Vector2(-14, -6), 2.4, INK)
			ci.draw_circle(Vector2(-14, -6), 1.6, RED)
			shape(ci, [Vector2(-22, 2.5), Vector2(-11, 2.5), Vector2(-10, 5.5), Vector2(-11, 8.5), Vector2(-22, 8.5), Vector2(-23, 5.5)], Color("d83a2e"))
			box(ci, -21, 4.6, -12, 5.6, Color(1, 1, 1, 0.55), 0.0)
			box(ci, -11.5, 2.5, -9, 5, DARK, 1.0)
			box(ci, -12, -2, -2, 0.2, DARK)
			shape(ci, [Vector2(-2, -2.5), Vector2(0, -3.4), Vector2(0, 1.1), Vector2(-2, 0.7)], STEEL, 1.0)
			var flick := 0.7 + 0.3 * sin(t * 40.0)
			ci.draw_circle(Vector2(1.6, -1.1), 1.8 * flick + (1.5 if firing else 0.0), Color(1.0, 0.55, 0.15, 0.9))
			ci.draw_circle(Vector2(1.3, -1.1), 0.9 * flick, Color("fff1a0"))
		"disc":
			grip(ci, -20, -16, 2.5, 9.5, DARK)
			shape(ci, [Vector2(-22, -3), Vector2(-2, -3), Vector2(0.5, -0.5), Vector2(-2, 2.5), Vector2(-22, 2.5)], RED)
			ci.draw_line(Vector2(-21, -1), Vector2(-3, -1), GOLD, 1.2)
			var c := Vector2(-9, -6)
			var spin := t * (20.0 if firing else 3.0)
			var teeth := PackedVector2Array()
			for k in range(16):
				teeth.append(c + Vector2.from_angle(spin + float(k) * TAU / 16.0) * (6.0 if k % 2 == 0 else 4.6))
			shape(ci, Array(teeth), STEEL_HI, 1.0)
			ci.draw_circle(c, 1.8, Color("7dffb2"))
		"boomerang":
			var arm := PackedVector2Array([Vector2(-2, -9), Vector2(-12, 1), Vector2(0, 3)])
			ci.draw_polyline(arm, INK, 6.0, true)
			ci.draw_polyline(arm, RED, 4.0, true)
			ci.draw_line(Vector2(-11, 0), Vector2(-3, -8), GOLD, 1.0)
			ci.draw_circle(Vector2(-2, -9), 2.0, GOLD)
			ci.draw_circle(Vector2(0, 3), 2.0, GOLD)
		"rail":
			shape(ci, [Vector2(-38, -3.5), Vector2(-44, -2), Vector2(-44, 4), Vector2(-38, 3)], DARK)
			grip(ci, -36, -32.5, 3, 9.5, DARK)
			box(ci, -20, 2.6, -17, 6.5, DARK, 1.0)
			box(ci, -38, -4.5, -29, 3, Color("2b303c"))
			ci.draw_line(Vector2(-37, -2.5), Vector2(-30, -2.5), RED, 1.4)
			var charge := clampf(float(st.get("charge", 0.0)), 0.0, 1.0)
			ci.draw_line(Vector2(-29, -0.8), Vector2(0, -0.8), Color(Color("7fd8ff"), 0.3 + 0.7 * charge), 2.2)
			box(ci, -30, -4.4, 0, -2.6, DARK, 1.0)
			box(ci, -30, 1.0, 0, 2.8, DARK, 1.0)
			for x in [-24.0, -16.0, -8.0]:
				box(ci, x, -5.2, x + 2.0, 3.6, RED, 1.0)
				if charge > 0.0:
					ci.draw_circle(Vector2(x + 1.0, -0.8), 1.4 * charge, Color("bff0ff"))
		"bees":
			shape(ci, [Vector2(-27, -3), Vector2(-21, -3), Vector2(-21, 2.5), Vector2(-27, 2.5)], WOOD)
			grip(ci, -22, -18.5, 2.5, 9.5, WOOD)
			var hive := PackedVector2Array()
			for k in range(20):
				var a := float(k) * TAU / 20.0
				hive.append(Vector2(-12, -0.5) + Vector2(cos(a) * 10.0, sin(a) * 6.2))
			shape(ci, Array(hive), Color("f2b63a"))
			for x in [-18.0, -14.0, -10.0, -6.0]:
				var hh := 6.2 * sqrt(maxf(0.0, 1.0 - pow((x + 12.0) / 10.0, 2.0)))
				ci.draw_line(Vector2(x, -0.5 - hh + 0.8), Vector2(x, -0.5 + hh - 0.8), Color("8a5418"), 1.2)
			box(ci, -2.5, -2.2, 0.5, 1.2, DARK, 1.0)
			for k in range(3):
				var bp := Vector2(4.0 + cos(t * 9.0 + k * 2.1) * 4.0, sin(t * 11.0 + k * 1.7) * 4.5)
				ci.draw_circle(bp, 1.6, Color("ffd94d"))
				ci.draw_line(bp - Vector2(0.4, 1.2), bp + Vector2(0.4, 1.2), INK, 0.8)
		"bowling":
			grip(ci, -22, -18.5, 5, 11, DARK)
			box(ci, -11, 5, -8, 9.5, DARK, 1.0)
			box(ci, -30, -5, -24, 4, DARK)
			ci.draw_circle(Vector2(-1.5, -0.5), 4.6, Color("9a6ad8"))
			box(ci, -24, -6, -2, 5, Color("3f7a3a"))
			shine(ci, -23, -3, -4.8, 0.35)
			box(ci, -18, -6, -16, 5, RED, 1.0)
			box(ci, -2, -7, 0.5, 6, DARK)
		"nailgun":
			shape(ci, [Vector2(-12, 1.5), Vector2(-4, 1.5), Vector2(-1, 8), Vector2(-9, 8)], STEEL)
			for k in range(4):
				var x := -10.0 + float(k) * 2.2
				ci.draw_line(Vector2(x, 2.2), Vector2(x + 1.8, 7.4), STEEL_HI, 0.8)
			grip(ci, -18, -13, 1.5, 10, DARK)
			box(ci, -20, -6.5, -3, 1.5, Color("f2c230"))
			box(ci, -20, -6.5, -17, 1.5, DARK, 1.0)
			shape(ci, [Vector2(-3, -4.5), Vector2(0, -3.5), Vector2(0, -1), Vector2(-3, 0)], DARK, 1.0)
			ci.draw_line(Vector2(0, -2.2), Vector2(2.2, -2.2), STEEL_HI, 1.0)
		"chicken":
			grip(ci, -15, -11.5, 2.5, 9.5, RED.darkened(0.25))
			box(ci, -16, -3.5, -3, 2.5, RED)
			box(ci, -3, -3, 0, 1.8, Color("ffd23a"), 1.0)
			var bob := sin(t * 8.0) * 0.8
			var head := Vector2(-9, -7 + bob)
			for k in range(3):
				ci.draw_circle(head + Vector2(-1.5 + k * 1.5, -3), 1.2, RED)
			ci.draw_circle(head, 3.4, INK)
			ci.draw_circle(head, 2.7, Color("fff27a"))
			shape(ci, [head + Vector2(2.4, -0.8), head + Vector2(5.0, 0.2), head + Vector2(2.4, 1.0)], Color("ff9d2e"), 0.8)
			ci.draw_circle(head + Vector2(0.8, -0.8), 0.7, INK)
		"bubble":
			grip(ci, -20, -16, 3, 10, Color("5a2fa8"))
			shape(ci, [Vector2(-21, -2.5), Vector2(-4, -2.5), Vector2(-2, 0), Vector2(-4, 3), Vector2(-21, 3)], Color("8a4fd8"))
			shape(ci, [Vector2(-4, -2), Vector2(0, -1), Vector2(0, 0.8), Vector2(-4, 1.5)], Color("5ad0ff"), 1.0)
			box(ci, -19, -10, -7, -2.5, Color(Color("9fe8ff"), 0.6))
			for k in range(3):
				var by := -3.5 - fposmod(t * 1.5 + k * 0.33, 1.0) * 5.5
				ci.draw_arc(Vector2(-16 + k * 4.0, by), 1.1, 0.0, TAU, 8, Color(1, 1, 1, 0.8), 0.8)
		"pinball":
			grip(ci, -17, -13, 3, 10, DARK)
			box(ci, -19, -4, -3, 3, RED)
			box(ci, -18, -1.2, -4, 0.4, Color("ff9df0"), 0.0)
			var pull := 0.5 + 0.5 * sin(t * 3.0)
			var spring := PackedVector2Array()
			for k in range(7):
				spring.append(Vector2(-19 - k * (0.8 + pull * 0.2), -0.5 + (1.6 if k % 2 == 0 else -1.6)))
			ci.draw_polyline(spring, STEEL_HI, 1.0)
			ci.draw_circle(Vector2(-25.5 - pull, -0.5), 2.2, INK)
			ci.draw_circle(Vector2(-25.5 - pull, -0.5), 1.6, Color("ff9df0"))
			box(ci, -3, -4.5, 0, 3.5, DARK)
			ci.draw_circle(Vector2(-1, -0.5), 2.4, STEEL_HI)
		"splitbow":
			var bow := PackedVector2Array()
			for k in range(13):
				var a := lerpf(-1.15, 1.15, float(k) / 12.0)
				bow.append(Vector2(-16, 0) + Vector2(cos(a) * 14.0, sin(a) * 14.0))
			var pull_back := 0.0 if firing else 2.5
			ci.draw_line(bow[0], Vector2(-13 - pull_back, 0), Color(1, 1, 1, 0.8), 1.0)
			ci.draw_line(bow[12], Vector2(-13 - pull_back, 0), Color(1, 1, 1, 0.8), 1.0)
			ci.draw_polyline(bow, INK, 4.0, true)
			ci.draw_polyline(bow, WOOD, 2.6, true)
			ci.draw_circle(bow[0], 1.6, GOLD)
			ci.draw_circle(bow[12], 1.6, GOLD)
			if not firing:
				ci.draw_line(Vector2(-13 - pull_back, 0), Vector2(1, 0), STEEL_HI, 1.2)
				for a2 in [-0.35, 0.0, 0.35]:
					var tip := Vector2(1, 0) + Vector2.from_angle(a2) * (2.5 if a2 != 0.0 else 0.0)
					shape(ci, [tip + Vector2.from_angle(a2) * 3.0, tip + Vector2.from_angle(a2 + 2.4) * 2.2, tip + Vector2.from_angle(a2 - 2.4) * 2.2], Color("9dffa8"), 0.8)
		"snow":
			grip(ci, -21, -17, 3.5, 10, Color("3a6fb8"))
			box(ci, -22, -4.5, -7, 3.5, Color("e6f4ff"))
			ci.draw_line(Vector2(-21, 2), Vector2(-8, 2), Color("7fc8ff"), 1.2)
			for a3 in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var d3 := Vector2.from_angle(a3) * 2.4
				ci.draw_line(Vector2(-14, -1) - d3, Vector2(-14, -1) + d3, Color("5aa8e8"), 1.0)
			shape(ci, [Vector2(-7, -4.5), Vector2(0, -7.5), Vector2(0, 6.5), Vector2(-7, 3.5)], Color("7fc8ff"))
			ci.draw_line(Vector2(0, -6.5), Vector2(0, 5.5), Color("1d3a5a"), 1.5)
			for k in range(3):
				var m := fposmod(t * 1.2 + k * 0.33, 1.0)
				ci.draw_circle(Vector2(2.0 + m * 6.0, (k - 1) * 3.0 * (1.0 + m)), 1.2 + m, Color(1, 1, 1, 0.5 * (1.0 - m)))
		_:
			box(ci, -16, -3, 0, 2, STEEL)
			grip(ci, -14, -10, 2, 9, DARK)
	if bool(st.get("evolved", false)):
		var length := float(LENGTH.get(id, 16.0))
		var glint := fposmod(t * 0.7, 1.0)
		var x := -length + glint * (length + 4.0)
		ci.draw_line(Vector2(x, -3.5), Vector2(x + 3.0, 1.5), Color(1.0, 0.92, 0.55, 0.85), 1.6)
