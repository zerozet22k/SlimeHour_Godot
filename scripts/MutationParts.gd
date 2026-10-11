extends RefCounted
## Every monster's base model GIVES two parts (one per augment it can pass
## on) and RECEIVES one part in a fixed slot on its own body.
## A mutation = the taker's base model + one of the giver's parts in the
## taker's slot. Parts are drawn pointing "up" (-y) from their slot, sized in
## units of the taker's radius.

const INK := Color(0.08, 0.05, 0.09)

## Giver: [part for augment 0, part for augment 1] (matches MutationKit.GIVES).
const GIVE_PARTS = {
	"blob": ["goo_drip", "jelly_dome"], "zoomer": ["speed_fins", "ram_nose"],
	"chonk": ["topknot", "fist"], "spitter": ["acid_bulb", "spit_nozzle"],
	"kaboomba": ["lit_fuse", "bomb_spikes"], "mitosis": ["cell_bud", "nucleus"],
	"mini": ["spiky_tuft", "mini_buds"], "riot": ["riot_shield", "visor_helmet"],
	"bull": ["bull_horns", "nose_ring"], "mama": ["egg_sac", "bow"],
	"mortar": ["mortar_tube", "ammo_belt"], "totem": ["totem_crown", "rune_stone"],
	"blinky": ["ghost_tail", "rift_eye"], "tick": ["tick_legs", "proboscis"],
	"goblin": ["gold_sack", "goblin_ears"], "ashwing": ["phoenix_wings", "flame_crest"],
	"mirror": ["crystal_spines", "prism_lens"], "burrower": ["drill_claws", "miner_lamp"],
	"siren": ["megaphone", "siren_fins"], "skitter": ["beetle_legs", "antennae"],
	"sapper": ["bomb_pack", "hard_hat"], "lancer": ["spear", "lance_visor"],
	"leech": ["sucker_mouth", "blood_sac"], "nurse": ["nurse_cap", "cross_pack"],
	"larry": ["laser_lens", "heat_vents"],
}

## Taker: where a received part attaches. pos in r units, rot in radians
## (0 = pointing up), scale multiplies the part.
const SLOTS = {
	"blob": {"pos": Vector2(0, -0.85), "rot": 0.0, "scale": 1.0},
	"zoomer": {"pos": Vector2(0, -1.05), "rot": 0.0, "scale": 0.9},
	"chonk": {"pos": Vector2(-1.05, -0.2), "rot": -1.1, "scale": 1.0},
	"spitter": {"pos": Vector2(-0.9, -0.35), "rot": -0.9, "scale": 0.95},
	"kaboomba": {"pos": Vector2(0.95, -0.1), "rot": 1.2, "scale": 0.95},
	"mitosis": {"pos": Vector2(0, -0.8), "rot": 0.0, "scale": 1.0},
	"mini": {"pos": Vector2(0.9, -0.2), "rot": 1.1, "scale": 0.9},
	"riot": {"pos": Vector2(0, -0.95), "rot": 0.0, "scale": 1.0},
	"bull": {"pos": Vector2(-1.0, 0.15), "rot": -1.3, "scale": 0.95},
	"mama": {"pos": Vector2(0.95, -0.2), "rot": 1.1, "scale": 1.0},
	"mortar": {"pos": Vector2(-0.9, -0.2), "rot": -1.0, "scale": 1.0},
	"totem": {"pos": Vector2(0, -1.4), "rot": 0.0, "scale": 1.0},
	"blinky": {"pos": Vector2(0, -0.9), "rot": 0.0, "scale": 1.0},
	"tick": {"pos": Vector2(0, -0.9), "rot": 0.0, "scale": 0.9},
	"goblin": {"pos": Vector2(0, -0.9), "rot": 0.0, "scale": 1.0},
	"ashwing": {"pos": Vector2(0, 0.95), "rot": PI, "scale": 0.9},
	"mirror": {"pos": Vector2(0, -1.15), "rot": 0.0, "scale": 0.9},
	"burrower": {"pos": Vector2(0, -0.9), "rot": 0.0, "scale": 1.0},
	"siren": {"pos": Vector2(0, -1.15), "rot": 0.0, "scale": 0.9},
	"skitter": {"pos": Vector2(0, -0.75), "rot": 0.0, "scale": 0.95},
	"sapper": {"pos": Vector2(0.95, -0.15), "rot": 1.2, "scale": 1.0},
	"lancer": {"pos": Vector2(-0.95, -0.2), "rot": -1.0, "scale": 1.0},
	"leech": {"pos": Vector2(0, -0.95), "rot": 0.0, "scale": 0.95},
	"nurse": {"pos": Vector2(-0.6, -0.75), "rot": -0.5, "scale": 1.0},
	"larry": {"pos": Vector2(0.95, -0.3), "rot": 1.1, "scale": 1.0},
}

static func part_for(giver: String, payload_index: int) -> String:
	var parts: Array = GIVE_PARTS.get(giver, ["goo_drip", "goo_drip"])
	return str(parts[clampi(payload_index, 0, parts.size() - 1)])

## Draws the giver's part in the taker's slot. `c` is the body centre.
static func draw_received(ci: CanvasItem, taker: String, giver: String, payload_index: int, c: Vector2, r: float, giver_color: Color, t: float = 0.0) -> void:
	var slot: Dictionary = SLOTS.get(taker, SLOTS["blob"])
	var at: Vector2 = c + Vector2(slot["pos"]) * r
	ci.draw_set_transform(at, float(slot["rot"]), Vector2.ONE * float(slot["scale"]) * 1.5)
	draw_part(ci, part_for(giver, payload_index), r, giver_color, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func poly(ci: CanvasItem, pts: Array, fill: Color, w: float = 2.0) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, fill)
	p.append(p[0])
	ci.draw_polyline(p, INK, w, true)

## One part, drawn at the origin pointing up (-y), in units of r.
static func draw_part(ci: CanvasItem, part: String, r: float, col: Color, t: float) -> void:
	var dark := col.darkened(0.45)
	var glow := 0.5 + 0.5 * sin(t * 5.0)
	match part:
		"goo_drip":
			ci.draw_circle(Vector2(0, -r * 0.25), r * 0.3, dark)
			ci.draw_circle(Vector2(0, -r * 0.27), r * 0.24, col)
			ci.draw_line(Vector2(0, -r * 0.05), Vector2(0, r * 0.25 + sin(t * 3.0) * r * 0.06), col, r * 0.12)
		"jelly_dome":
			ci.draw_arc(Vector2(0, r * 0.2), r * 0.55, PI, TAU, 16, Color(col, 0.9), r * 0.12, true)
			ci.draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.08, Color(1, 1, 1, 0.6))
		"speed_fins":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.08, 0), Vector2(s * r * 0.45, -r * 0.5), Vector2(s * r * 0.3, 0)], col)
		"ram_nose":
			poly(ci, [Vector2(-r * 0.25, 0), Vector2(0, -r * 0.6), Vector2(r * 0.25, 0)], col)
			ci.draw_line(Vector2(0, -r * 0.15), Vector2(0, -r * 0.5), col.lightened(0.4), 2.0)
		"topknot":
			ci.draw_circle(Vector2(0, -r * 0.25), r * 0.24, INK)
			ci.draw_circle(Vector2(0, -r * 0.25), r * 0.18, Color("2a1418"))
			ci.draw_line(Vector2(-r * 0.15, -r * 0.05), Vector2(r * 0.15, -r * 0.05), col, 3.0)
		"fist":
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.3, INK)
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.25, col)
			for k in range(3):
				ci.draw_line(Vector2((k - 1) * r * 0.1, -r * 0.48), Vector2((k - 1) * r * 0.1, -r * 0.35), dark, 2.0)
		"acid_bulb":
			ci.draw_line(Vector2.ZERO, Vector2(r * 0.1, -r * 0.4), INK, r * 0.24)
			ci.draw_line(Vector2.ZERO, Vector2(r * 0.1, -r * 0.4), col, r * 0.16)
			ci.draw_circle(Vector2(r * 0.12, -r * 0.55), r * 0.25, INK)
			ci.draw_circle(Vector2(r * 0.12, -r * 0.55), r * 0.2, Color("d8ff91"))
			ci.draw_circle(Vector2(r * 0.28, -r * 0.3), r * 0.07, Color("d8ff91"))
		"spit_nozzle":
			poly(ci, [Vector2(-r * 0.18, 0), Vector2(-r * 0.24, -r * 0.5), Vector2(r * 0.24, -r * 0.5), Vector2(r * 0.18, 0)], col)
			ci.draw_circle(Vector2(0, -r * 0.5), r * 0.16, Color("e8f4ff"))
		"lit_fuse":
			ci.draw_line(Vector2.ZERO, Vector2(r * 0.15, -r * 0.5), Color("c8a060"), 3.0)
			for k in range(5):
				var a := TAU * float(k) / 5.0 + t * 7.0
				ci.draw_line(Vector2(r * 0.15, -r * 0.5), Vector2(r * 0.15, -r * 0.5) + Vector2.from_angle(a) * r * (0.15 + 0.06 * glow), Color("ffd24d"), 2.0)
			ci.draw_circle(Vector2(r * 0.15, -r * 0.5), r * 0.08, Color.WHITE)
		"bomb_spikes":
			for k in range(3):
				var x := (k - 1) * r * 0.28
				poly(ci, [Vector2(x - r * 0.1, 0), Vector2(x, -r * 0.45 + absf(k - 1) * r * 0.1), Vector2(x + r * 0.1, 0)], Color("342630"))
				ci.draw_circle(Vector2(x, -r * 0.42 + absf(k - 1) * r * 0.1), r * 0.05, Color("ff704d"))
		"cell_bud":
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.3, dark)
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.25, Color(col, 0.9))
			ci.draw_circle(Vector2(r * 0.05, -r * 0.28), r * 0.08, dark)
		"nucleus":
			ci.draw_circle(Vector2(0, -r * 0.3), r * (0.22 + 0.04 * glow), Color(0.6, 1.0, 0.7, 0.35))
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.15, Color("8dffb8"))
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.06, Color.WHITE)
		"spiky_tuft":
			for k in range(3):
				var x2 := (k - 1) * r * 0.22
				poly(ci, [Vector2(x2 - r * 0.12, 0), Vector2(x2, -r * 0.5 + absf(k - 1) * r * 0.12), Vector2(x2 + r * 0.12, 0)], col)
		"mini_buds":
			for s in [-1.0, 1.0]:
				ci.draw_circle(Vector2(s * r * 0.2, -r * 0.22), r * 0.18, dark)
				ci.draw_circle(Vector2(s * r * 0.2, -r * 0.24), r * 0.14, col)
				ci.draw_circle(Vector2(s * r * 0.2 - r * 0.04, -r * 0.26), r * 0.04, INK)
				ci.draw_circle(Vector2(s * r * 0.2 + r * 0.04, -r * 0.26), r * 0.04, INK)
		"riot_shield":
			poly(ci, [Vector2(-r * 0.4, -r * 0.05), Vector2(r * 0.4, -r * 0.05), Vector2(r * 0.4, -r * 0.35), Vector2(-r * 0.4, -r * 0.35)], Color("a8c0ff"), 2.5)
			ci.draw_line(Vector2(-r * 0.32, -r * 0.2), Vector2(r * 0.32, -r * 0.2), Color("2a3a60"), 2.0)
		"visor_helmet":
			ci.draw_arc(Vector2(0, r * 0.1), r * 0.5, PI, TAU, 14, Color("344765"), r * 0.18, true)
			ci.draw_line(Vector2(-r * 0.35, -r * 0.05), Vector2(r * 0.35, -r * 0.05), Color("b7d8f9"), 3.0)
		"bull_horns":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.08, 0), Vector2(s * r * 0.55, -r * 0.55), Vector2(s * r * 0.3, 0)], Color("fff0cf"))
		"nose_ring":
			ci.draw_arc(Vector2(0, -r * 0.25), r * 0.2, 0.0, TAU, 16, Color("ffd24d"), 3.5, true)
		"egg_sac":
			for k in range(3):
				var ep := Vector2((k - 1) * r * 0.25, -r * (0.25 + 0.12 * float(k % 2)))
				ci.draw_circle(ep, r * 0.17, INK)
				ci.draw_circle(ep, r * 0.14, Color("ffd9e6"))
				ci.draw_circle(ep + Vector2(r * 0.04, r * 0.03), r * 0.04, Color("ff8bb8"))
		"bow":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(0, -r * 0.2), Vector2(s * r * 0.4, -r * 0.4), Vector2(s * r * 0.4, -r * 0.02)], Color("ff3a8a"))
			ci.draw_circle(Vector2(0, -r * 0.2), r * 0.09, Color("ff9ac4"))
		"mortar_tube":
			ci.draw_line(Vector2.ZERO, Vector2(0, -r * 0.65), INK, r * 0.36)
			ci.draw_line(Vector2.ZERO, Vector2(0, -r * 0.6), Color("6a6656"), r * 0.26)
			ci.draw_circle(Vector2(0, -r * 0.62), r * 0.1, Color("1a1a16"))
		"ammo_belt":
			for k in range(4):
				var x3 := (k - 1.5) * r * 0.16
				ci.draw_rect(Rect2(Vector2(x3 - r * 0.05, -r * 0.4), Vector2(r * 0.1, r * 0.35)), Color("c8a060"))
				ci.draw_rect(Rect2(Vector2(x3 - r * 0.05, -r * 0.45), Vector2(r * 0.1, r * 0.1)), Color("8a6a30"))
		"totem_crown":
			poly(ci, [Vector2(-r * 0.35, 0), Vector2(-r * 0.35, -r * 0.3), Vector2(-r * 0.12, -r * 0.15), Vector2(0, -r * 0.42), Vector2(r * 0.12, -r * 0.15), Vector2(r * 0.35, -r * 0.3), Vector2(r * 0.35, 0)], Color("7ad1ff"))
		"rune_stone":
			poly(ci, [Vector2(-r * 0.22, 0), Vector2(-r * 0.25, -r * 0.45), Vector2(r * 0.25, -r * 0.45), Vector2(r * 0.22, 0)], Color("1d3550"))
			ci.draw_line(Vector2(-r * 0.1, -r * 0.35), Vector2(r * 0.1, -r * 0.1), Color(0.5, 1.0, 0.7, 0.6 + 0.4 * glow), 2.5)
		"ghost_tail":
			var tail := PackedVector2Array()
			for k in range(7):
				var u := float(k) / 6.0
				tail.append(Vector2(sin(u * PI * 2.0 + t * 4.0) * r * 0.15, -u * r * 0.7))
			ci.draw_polyline(tail, Color(col, 0.8), r * 0.22, true)
		"rift_eye":
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.24, Color("24103a"))
			ci.draw_arc(Vector2(0, -r * 0.3), r * 0.2, t * 3.0, t * 3.0 + PI * 1.4, 12, Color("c79cff"), 2.5, true)
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.07, Color("f0e0ff"))
		"tick_legs":
			for s in [-1.0, 1.0]:
				for k in range(2):
					ci.draw_polyline(PackedVector2Array([Vector2(s * r * 0.1, -k * r * 0.12), Vector2(s * r * 0.4, -r * 0.3 - k * r * 0.12), Vector2(s * r * 0.55, -r * 0.05 - k * r * 0.12)]), Color("24331c"), 2.5, true)
		"proboscis":
			ci.draw_line(Vector2.ZERO, Vector2(0, -r * 0.6), Color("4a2a1c"), 4.0)
			ci.draw_circle(Vector2(0, -r * 0.6), r * 0.06, Color("ff3a5a"))
		"gold_sack":
			ci.draw_circle(Vector2(0, -r * 0.32), r * 0.3, Color("8a6a30"))
			ci.draw_circle(Vector2(0, -r * 0.32), r * 0.25, Color("c8a040"))
			ci.draw_circle(Vector2(r * 0.1, -r * 0.42), r * 0.08, Color("ffd24d"))
		"goblin_ears":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.1, 0), Vector2(s * r * 0.6, -r * 0.35), Vector2(s * r * 0.3, r * 0.05)], col)
		"phoenix_wings":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.08, 0), Vector2(s * r * 0.75, -r * 0.45), Vector2(s * r * 0.5, -r * 0.05), Vector2(s * r * 0.6, r * 0.2)], Color("ff632f"))
		"flame_crest":
			for k in range(3):
				var fx := (k - 1) * r * 0.2
				var flick := 0.8 + 0.2 * sin(t * 12.0 + k)
				poly(ci, [Vector2(fx - r * 0.1, 0), Vector2(fx, -r * 0.5 * flick), Vector2(fx + r * 0.1, 0)], Color("ffb347"), 1.5)
		"crystal_spines":
			for k in range(3):
				var a2 := (k - 1) * 0.5
				var tip := Vector2.from_angle(-PI * 0.5 + a2) * r * 0.55
				poly(ci, [Vector2.from_angle(-PI * 0.5 + a2 + PI * 0.5) * r * 0.08, tip, Vector2.from_angle(-PI * 0.5 + a2 - PI * 0.5) * r * 0.08], Color("bff8ff"), 1.5)
		"prism_lens":
			poly(ci, [Vector2(0, 0), Vector2(r * 0.25, -r * 0.3), Vector2(0, -r * 0.6), Vector2(-r * 0.25, -r * 0.3)], Color("c6f6ff"))
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.08, Color(1, 1, 1, 0.6 + 0.4 * glow))
		"drill_claws":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.1, 0), Vector2(s * r * 0.25, -r * 0.5), Vector2(s * r * 0.35, -r * 0.05)], Color("ffe2a3"))
		"miner_lamp":
			ci.draw_rect(Rect2(Vector2(-r * 0.15, -r * 0.3), Vector2(r * 0.3, r * 0.3)), Color("4a4e5a"))
			ci.draw_circle(Vector2(0, -r * 0.18), r * 0.1, Color("fff1a8"))
			ci.draw_circle(Vector2(0, -r * 0.18), r * 0.25, Color(1.0, 0.95, 0.6, 0.15 + 0.1 * glow))
		"megaphone":
			poly(ci, [Vector2(-r * 0.1, 0), Vector2(-r * 0.3, -r * 0.55), Vector2(r * 0.3, -r * 0.55), Vector2(r * 0.1, 0)], Color("ffb0e8"))
			for k in range(2):
				ci.draw_arc(Vector2(0, -r * 0.55), r * (0.18 + k * 0.14), PI * 1.2, PI * 1.8, 8, Color(1, 0.7, 0.9, 0.6 * glow), 2.0, true)
		"siren_fins":
			for s in [-1.0, 1.0]:
				poly(ci, [Vector2(s * r * 0.08, 0), Vector2(s * r * 0.5, -r * 0.5), Vector2(s * r * 0.45, r * 0.05)], Color("ad4f9b"))
		"beetle_legs":
			for s in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([Vector2(s * r * 0.1, 0), Vector2(s * r * 0.4, -r * 0.3), Vector2(s * r * 0.6, -r * 0.1)]), Color("d6faff"), 3.0, true)
		"antennae":
			for s in [-1.0, 1.0]:
				ci.draw_line(Vector2(s * r * 0.1, 0), Vector2(s * r * 0.35, -r * 0.55), Color("2a3048"), 2.5)
				ci.draw_circle(Vector2(s * r * 0.35, -r * 0.55), r * 0.08, Color("83eaff"))
		"bomb_pack":
			ci.draw_circle(Vector2(0, -r * 0.28), r * 0.26, Color("1d1f26"))
			ci.draw_circle(Vector2(0, -r * 0.54), r * 0.07, Color("ff3b3b") if glow > 0.5 else Color("5a1414"))
		"hard_hat":
			ci.draw_arc(Vector2(0, r * 0.05), r * 0.42, PI, TAU, 14, Color("ffc23d"), r * 0.22, true)
			ci.draw_line(Vector2(-r * 0.5, -r * 0.02), Vector2(r * 0.5, -r * 0.02), Color("c8902a"), 3.0)
		"spear":
			ci.draw_line(Vector2(0, r * 0.2), Vector2(0, -r * 0.8), Color("e4e8ff"), 3.0)
			poly(ci, [Vector2(-r * 0.12, -r * 0.7), Vector2(0, -r * 1.0), Vector2(r * 0.12, -r * 0.7)], Color("9caaff"), 1.5)
		"lance_visor":
			ci.draw_rect(Rect2(Vector2(-r * 0.4, -r * 0.22), Vector2(r * 0.8, r * 0.2)), Color("3a4268"))
			ci.draw_rect(Rect2(Vector2(-r * 0.32, -r * 0.18), Vector2(r * 0.64, r * 0.08)), Color("ff3a5a"))
		"sucker_mouth":
			ci.draw_circle(Vector2(0, -r * 0.28), r * 0.26, Color("3c145a"))
			for k in range(6):
				var a3 := TAU * float(k) / 6.0
				ci.draw_line(Vector2(0, -r * 0.28) + Vector2.from_angle(a3) * r * 0.26, Vector2(0, -r * 0.28) + Vector2.from_angle(a3) * r * 0.14, Color("f2e6ff"), 2.0)
		"blood_sac":
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.26, Color("4a0f1c"))
			ci.draw_circle(Vector2(0, -r * 0.3), r * 0.2, Color(0.85, 0.1, 0.2, 0.75 + 0.25 * glow))
		"nurse_cap":
			ci.draw_rect(Rect2(Vector2(-r * 0.32, -r * 0.35), Vector2(r * 0.64, r * 0.33)), Color("f2f6f8"))
			ci.draw_rect(Rect2(Vector2(-r * 0.32, -r * 0.35), Vector2(r * 0.64, r * 0.33)), INK, false, 2.0)
			ci.draw_rect(Rect2(Vector2(-r * 0.05, -r * 0.31), Vector2(r * 0.1, r * 0.25)), Color("e8394a"))
			ci.draw_rect(Rect2(Vector2(-r * 0.13, -r * 0.23), Vector2(r * 0.26, r * 0.09)), Color("e8394a"))
		"cross_pack":
			ci.draw_rect(Rect2(Vector2(-r * 0.3, -r * 0.45), Vector2(r * 0.6, r * 0.45)), Color("e7f2f6"))
			ci.draw_rect(Rect2(Vector2(-r * 0.3, -r * 0.45), Vector2(r * 0.6, r * 0.45)), INK, false, 2.0)
			ci.draw_circle(Vector2(0, -r * 0.22), r * 0.12, Color("5dff8f"))
		"laser_lens":
			ci.draw_line(Vector2.ZERO, Vector2(0, -r * 0.3), Color("2a2d36"), r * 0.2)
			ci.draw_circle(Vector2(0, -r * 0.4), r * 0.24, Color("2a0b14"))
			ci.draw_circle(Vector2(0, -r * 0.4), r * 0.17, Color("ff3a5a"))
			ci.draw_circle(Vector2(0, -r * 0.4), r * 0.07, Color("ffe0e8"))
		"heat_vents":
			for k in range(3):
				var vx := (k - 1) * r * 0.2
				ci.draw_rect(Rect2(Vector2(vx - r * 0.07, -r * 0.35), Vector2(r * 0.14, r * 0.35)), Color("4a4e5a"))
				ci.draw_rect(Rect2(Vector2(vx - r * 0.05, -r * 0.33), Vector2(r * 0.1, r * 0.1)), Color(1.0, 0.5, 0.15, 0.6 + 0.4 * glow))
