extends RefCounted
## Street monsters built from swappable layers, so a mutation is a true
## fusion instead of a sticker:
##   BODY parent (taker): silhouette, signature appendage, eye style
##   SKIN parent (giver): colours, surface pattern, mouth, decorations
## A pure monster is draw(kind, kind). Spitter + Kaboomba is a Spitter-shaped
## monster (round body, curved neck and bulb) in Kaboomba's black skin with
## its red grin, bomb spikes and lit fuse.
## Eyes always sit at the standard spots (+-0.36r, -0.18r) so live pupils line up.

const INK := Color(0.08, 0.05, 0.09)

## Body: shape, eyes and a MAIN part it always keeps. Giver: colours,
## pattern, mouth and the PARTS it gives, each in a slot (top, hand, legs,
## wings, head, tail, spikes). A giver part only goes where the body's own
## main part leaves the slot free, so nothing ever overlaps.
const SPECS = {
	"blob": {"shape": "drip", "main": ["drip_tail", "tail"], "gives": [["drip_tail", "tail"]], "eyes": "two", "body": "ff7b93", "dark": "8a2a44", "accent": "6c2946", "pattern": "gloss", "mouth": "smile"},
	"zoomer": {"shape": "dart", "main": ["speed_tail", "tail"], "gives": [["swept_fins", "wings"]], "eyes": "two", "body": "ffb36b", "dark": "8a4a1c", "accent": "66323c", "pattern": "gloss", "mouth": "flat"},
	"chonk": {"shape": "sumo", "main": ["topknot", "top"], "gives": [["stubby_feet", "legs"], ["topknot", "top"]], "eyes": "two", "body": "e86a8a", "dark": "7a2a40", "accent": "201018", "pattern": "belly", "mouth": "frown"},
	"spitter": {"shape": "round", "main": ["neck_bulb", "top"], "gives": [["neck_bulb", "top"]], "eyes": "two", "body": "b6ff6b", "dark": "4a7a20", "accent": "d8ff91", "pattern": "bubbles", "mouth": "o_mouth"},
	"kaboomba": {"shape": "bomb", "main": ["fuse", "top"], "gives": [["bomb_spikes", "spikes"], ["fuse", "top"]], "eyes": "two", "body": "3a3037", "dark": "1a1016", "accent": "ff704d", "pattern": "shine", "mouth": "red_grin"},
	"mitosis": {"shape": "cell", "main": ["", ""], "gives": [["cell_buds", "side"]], "eyes": "two", "body": "7dffcf", "dark": "2a8a6a", "accent": "276c64", "pattern": "nuclei", "mouth": "small_o"},
	"mini": {"shape": "round", "main": ["tuft", "top"], "gives": [["tuft", "top"]], "eyes": "two", "body": "7dffcf", "dark": "2a8a6a", "accent": "66323c", "pattern": "gloss", "mouth": "flat"},
	"riot": {"shape": "box", "main": ["visor_band", "face"], "gives": [["visor_band", "face"]], "eyes": "two", "body": "8fb0ff", "dark": "263650", "accent": "b7d8f9", "pattern": "plate", "mouth": "grill"},
	"bull": {"shape": "wide", "main": ["horns", "head"], "gives": [["horns", "head"]], "eyes": "two", "body": "ff9157", "dark": "7a3a18", "accent": "fff0cf", "pattern": "belly", "mouth": "snout"},
	"mama": {"shape": "lobes", "main": ["egg_pack", "back"], "gives": [["egg_pack", "back"], ["bow", "top"]], "eyes": "two", "body": "ff9ad1", "dark": "8a3a6a", "accent": "ff3a8a", "pattern": "gloss", "mouth": "smile"},
	"mortar": {"shape": "round", "main": ["mortar_tube", "hand"], "gives": [["army_helmet", "top"], ["mortar_tube", "hand"]], "eyes": "two", "body": "c9b27a", "dark": "5a4a28", "accent": "6a6656", "pattern": "", "mouth": "flat"},
	"totem": {"shape": "pillar", "main": ["", ""], "gives": [["crown", "top"]], "eyes": "two", "body": "7ad1ff", "dark": "1d3550", "accent": "e8f8ff", "pattern": "stripes", "mouth": "grill"},
	"blinky": {"shape": "ghost", "main": ["ghost_wisp", "tail"], "gives": [["ghost_wisp", "tail"]], "eyes": "two", "body": "c58cff", "dark": "5a2a8a", "accent": "3a1450", "pattern": "gloss", "mouth": "small_o"},
	"tick": {"shape": "round", "main": ["six_legs", "legs"], "gives": [["six_legs", "legs"]], "eyes": "two", "body": "9dff6b", "dark": "24331c", "accent": "24331c", "pattern": "back_shell", "mouth": "fangs"},
	"goblin": {"shape": "round", "main": ["gold_sack", "hand"], "gives": [["pointy_ears", "head"], ["gold_sack", "hand"]], "eyes": "two", "body": "ffd24d", "dark": "8a6a20", "accent": "fff4a3", "pattern": "", "mouth": "gold_grin"},
	"ashwing": {"shape": "round", "main": ["flame_wings", "wings"], "gives": [["flame_wings", "wings"], ["flame_crest", "top"]], "eyes": "two", "body": "ff9d59", "dark": "6d291c", "accent": "ffe19c", "pattern": "", "mouth": "beak"},
	"mirror": {"shape": "diamond", "main": ["", ""], "gives": [["prism_spikes", "spikes"]], "eyes": "two", "body": "82e9ef", "dark": "24899c", "accent": "c0faff", "pattern": "facets", "mouth": "flat"},
	"burrower": {"shape": "round", "main": ["dig_claws", "legs"], "gives": [["dig_claws", "legs"]], "eyes": "two", "body": "c8a66e", "dark": "72502d", "accent": "ffe2a3", "pattern": "face_patch", "mouth": "nose_dot"},
	"siren": {"shape": "cone", "main": ["fin_ears", "head"], "gives": [["fin_ears", "head"]], "eyes": "two", "body": "f194da", "dark": "7d3d76", "accent": "ffd6f5", "pattern": "stripes", "mouth": "megaphone"},
	"skitter": {"shape": "beetle", "main": ["four_legs", "legs"], "gives": [["antennae", "top"], ["four_legs", "legs"]], "eyes": "two", "body": "63dbff", "dark": "1c5a7a", "accent": "d6faff", "pattern": "shell_split", "mouth": ""},
	"sapper": {"shape": "round", "main": ["bomb_pack", "hand"], "gives": [["hard_hat", "top"], ["bomb_pack", "hand"]], "eyes": "visor", "body": "ffbb61", "dark": "7a4a14", "accent": "ff7a46", "pattern": "", "mouth": ""},
	"lancer": {"shape": "round", "main": ["spear", "hand"], "gives": [["plume", "top"], ["spear", "hand"]], "eyes": "visor", "body": "bfc7ff", "dark": "3a4268", "accent": "9caaff", "pattern": "", "mouth": ""},
	"leech": {"shape": "round", "main": ["worm_tail", "tail"], "gives": [["worm_tail", "tail"]], "eyes": "two", "body": "a783ff", "dark": "4a2a8a", "accent": "f2e6ff", "pattern": "gloss", "mouth": "sucker"},
	"nurse": {"shape": "round", "main": ["cross_satchel", "hand"], "gives": [["nurse_cap", "top"], ["cross_satchel", "hand"]], "eyes": "two", "body": "9af0cd", "dark": "2a7a5a", "accent": "e8394a", "pattern": "", "mouth": "smile"},
	"larry": {"shape": "round", "main": ["laser_lens", "top"], "gives": [["heat_vents", "wings"], ["laser_lens", "top"]], "eyes": "two", "body": "f35a8a", "dark": "6a1a3a", "accent": "ff3a5a", "pattern": "", "mouth": "grit"},
}

static func has(kind: String) -> bool:
	return SPECS.has(kind)

static func poly(ci: CanvasItem, pts, fill: Color, line: Color = INK, w: float = 2.5) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, fill)
	p.append(p[0])
	ci.draw_polyline(p, line, w, true)

static func ell(c: Vector2, rx: float, ry: float, n: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var th := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(th) * rx, sin(th) * ry))
	return pts

## Parts drawn behind the silhouette.
const BEHIND = ["six_legs", "four_legs", "dig_claws", "stubby_feet", "flame_wings", "swept_fins",
	"bomb_spikes", "horns", "pointy_ears", "fin_ears", "egg_pack", "heat_vents", "ghost_wisp", "prism_spikes"]

## Which parts a fusion of BODY and SKIN wears: the body's main part, then
## every skin part whose slot is still free.
static func parts_for(body_kind: String, skin_kind: String) -> Array:
	var b: Dictionary = SPECS.get(body_kind, SPECS["blob"])
	var s: Dictionary = SPECS.get(skin_kind, b)
	var result: Array = []
	var taken := {}
	if str(b["main"][0]) != "":
		result.append(str(b["main"][0]))
		taken[str(b["main"][1])] = true
	for g in s["gives"]:
		if not taken.has(str(g[1])) and not result.has(str(g[0])):
			result.append(str(g[0]))
			taken[str(g[1])] = true
	return result

## Draws BODY's silhouette, eyes and main part wearing SKIN's colours,
## pattern, mouth and the skin's parts that fit.
static func draw(ci: CanvasItem, body_kind: String, skin_kind: String, r: float, flash: bool = false) -> void:
	var b: Dictionary = SPECS.get(body_kind, SPECS["blob"])
	var s: Dictionary = SPECS.get(skin_kind, b)
	var body := Color.WHITE if flash else Color(str(s["body"]))
	var dark := Color(str(s["dark"]))
	var accent := Color(str(s["accent"]))
	var shape := str(b["shape"])
	var parts := parts_for(body_kind, skin_kind)
	for part in parts:
		if part in BEHIND:
			signature(ci, part, r, body, dark, accent, shape)
	silhouette(ci, shape, r, body, dark)
	pattern(ci, str(s["pattern"]), shape, r, body, dark, accent)
	for part in parts:
		if not part in BEHIND:
			signature(ci, part, r, body, dark, accent, shape)
	eyes(ci, str(b["eyes"]), r)
	mouth(ci, str(s["mouth"]) if str(s["mouth"]) != "" else str(b["mouth"]), r, body, dark, accent)

# ------------------------------------------------------------------ silhouettes
static func silhouette(ci: CanvasItem, shape: String, r: float, body: Color, dark: Color) -> void:
	match shape:
		"drip":
			var pts := PackedVector2Array()
			for i in range(28):
				var th := TAU * float(i) / 28.0
				var up := maxf(0.0, -sin(th))
				pts.append(Vector2(cos(th) * r * (1.05 - 0.3 * up), sin(th) * r * 0.95 * (1.0 + 0.22 * up * up)))
			poly(ci, pts, body, dark.darkened(0.3), 3.0)
		"dart":
			poly(ci, [Vector2(0, -r * 1.2), Vector2(r * 0.85, -r * 0.1), Vector2(r * 0.7, r * 0.7), Vector2(0, r * 1.05),
				Vector2(-r * 0.7, r * 0.7), Vector2(-r * 0.85, -r * 0.1)], body, dark.darkened(0.3), 3.0)
		"sumo":
			poly(ci, ell(Vector2(0, r * 0.08), r * 1.15, r * 0.92), body, dark.darkened(0.25), 3.5)
		"wide":
			poly(ci, ell(Vector2(0, r * 0.05), r * 1.1, r * 0.95), body, dark.darkened(0.25), 3.0)
		"cell":
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.45, r * 0.05), r * 0.82, dark)
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.45, r * 0.05), r * 0.76, body)
			ci.draw_line(Vector2(0, -r * 0.55), Vector2(0, r * 0.65), Color(dark, 0.6), 2.0)
		"lobes":
			for k in range(5):
				var a := TAU * float(k) / 5.0
				var lobe := Vector2(cos(a) * r * 0.62, sin(a) * r * 0.58)
				ci.draw_circle(lobe, r * (0.43 if k % 2 == 0 else 0.36), dark)
			for k in range(5):
				var a2 := TAU * float(k) / 5.0
				ci.draw_circle(Vector2(cos(a2) * r * 0.62, sin(a2) * r * 0.58) + Vector2(0, -2), r * (0.39 if k % 2 == 0 else 0.32), body)
			ci.draw_circle(Vector2.ZERO, r * 0.7, body)
		"box":
			ci.draw_rect(Rect2(-r * 0.86, -r * 0.88, r * 1.72, r * 1.76), dark)
			ci.draw_rect(Rect2(-r * 0.72, -r * 0.74, r * 1.44, r * 1.48), body)
		"pillar":
			ci.draw_rect(Rect2(-r * 0.8, -r * 1.35, r * 1.6, r * 2.4), dark)
			ci.draw_rect(Rect2(-r * 0.68, -r * 1.23, r * 1.36, r * 2.16), body)
		"ghost":
			var pts2 := PackedVector2Array()
			for i in range(15):
				var th2 := PI + PI * float(i) / 14.0
				pts2.append(Vector2(cos(th2) * r, sin(th2) * r * 1.0))
			for k in range(7):
				var x := r - float(k) * r * 2.0 / 6.0
				pts2.append(Vector2(x, r * (0.95 if k % 2 == 0 else 0.65)))
			poly(ci, pts2, body, dark, 2.5)
		"diamond":
			poly(ci, [Vector2(-r * 1.1, 0), Vector2(0, -r * 1.3), Vector2(r * 1.1, 0), Vector2(0, r * 1.25)], body, dark, 3.0)
		"cone":
			poly(ci, [Vector2(0, -r * 1.2), Vector2(r * 1.0, r * 0.75), Vector2(-r * 1.0, r * 0.75)], body, dark, 3.0)
		"beetle":
			poly(ci, ell(Vector2(0, r * 0.15), r * 0.9, r * 1.05), body, dark.darkened(0.3), 3.0)
		"bomb":
			# A round bomb with a riveted metal cap where the fuse goes in.
			ci.draw_circle(Vector2.ZERO, r, INK)
			ci.draw_circle(Vector2(0, -1), r - 2.5, body)
			ci.draw_rect(Rect2(-r * 0.32, -r * 1.12, r * 0.64, r * 0.3), INK)
			ci.draw_rect(Rect2(-r * 0.26, -r * 1.07, r * 0.52, r * 0.2), Color("8a8f9c"))
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.16, -r * 0.97), r * 0.04, Color("4a4e5a"))
		_:
			ci.draw_circle(Vector2.ZERO, r, dark)
			ci.draw_circle(Vector2(0, -1), r - 2.0, body)

# ------------------------------------------------------------------ body appendages (taker)
static func signature(ci: CanvasItem, sig: String, r: float, body: Color, dark: Color, accent: Color, shape: String = "round") -> void:
	if sig in ["fuse", "six_legs", "flame_wings", "dig_claws", "laser_lens", "four_legs", "horns", "egg_pack",
			"bomb_spikes", "swept_fins", "speed_tail", "stubby_feet", "bow", "army_helmet", "crown", "pointy_ears",
			"flame_crest", "fin_ears", "antennae", "hard_hat", "plume", "nurse_cap", "heat_vents",
			"ghost_wisp", "prism_spikes", "cell_buds"]:
		decor(ci, sig, shape, r, body, dark, accent)
		return
	match sig:
		"drip_tail":
			ci.draw_line(Vector2(r * 0.66, r * 0.6), Vector2(r * 0.72, r * 0.82), body, r * 0.22)
			ci.draw_circle(Vector2(r * 0.72, r * 0.86), r * 0.17, body)
		"topknot":
			ci.draw_circle(Vector2(0, -r * 1.0), r * 0.22, INK)
			ci.draw_circle(Vector2(0, -r * 1.0), r * 0.16, dark)
		"neck_bulb":
			var neck := PackedVector2Array()
			for i in range(9):
				var u := float(i) / 8.0
				neck.append(Vector2(sin(u * PI * 0.9) * r * 0.45, -r * 0.6 - u * r * 0.85))
			ci.draw_polyline(neck, INK, r * 0.46, true)
			ci.draw_polyline(neck, body.darkened(0.15), r * 0.34, true)
			var bulb: Vector2 = neck[neck.size() - 1]
			ci.draw_circle(bulb, r * 0.36, INK)
			ci.draw_circle(bulb, r * 0.3, body)
			ci.draw_circle(bulb + Vector2(r * 0.05, -r * 0.05), r * 0.17, accent)
			ci.draw_circle(bulb + Vector2(r * 0.2, r * 0.32), r * 0.08, accent)
		"tuft":
			for k in range(3):
				var x := (k - 1) * r * 0.32
				poly(ci, [Vector2(x - r * 0.18, -r * 0.82), Vector2(x, -r * 1.35 + absf(k - 1) * r * 0.15), Vector2(x + r * 0.18, -r * 0.82)], body, dark, 2.0)
		"visor_band":
			ci.draw_rect(Rect2(-r * 0.72, -r * 0.92, r * 1.44, r * 0.3), dark)
			ci.draw_rect(Rect2(-r * 0.62, -r * 0.84, r * 1.24, r * 0.13), accent)
		"snout":
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.4, body.lightened(0.18))
			ci.draw_arc(Vector2(0, r * 0.42), r * 0.4, 0.0, TAU, 20, dark, 2.0, true)
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.14, r * 0.45), r * 0.07, INK)
		"mortar_tube":
			ci.draw_line(Vector2(r * 0.2, -r * 0.3), Vector2(r * 0.85, -r * 1.25), INK, r * 0.55)
			ci.draw_line(Vector2(r * 0.2, -r * 0.3), Vector2(r * 0.8, -r * 1.15), dark.lightened(0.15), r * 0.38)
		"gold_sack":
			ci.draw_circle(Vector2(r * 0.7, r * 0.25), r * 0.6, Color("8a6a20"))
			ci.draw_circle(Vector2(r * 0.7, r * 0.25), r * 0.48, Color("c8a040"))
			ci.draw_circle(Vector2(r * 0.85, r * 0.1), r * 0.15, Color("ffd24d"))
		"bomb_pack":
			ci.draw_circle(Vector2(r * 0.85, r * 0.35), r * 0.32, Color("1d1f26"))
			ci.draw_circle(Vector2(r * 0.85, r * 0.05), r * 0.08, Color("ff3b3b"))
		"spear":
			ci.draw_line(Vector2(r * 0.4, r * 0.9), Vector2(r * 1.35, -r * 1.5), Color("e4e8ff"), 4.0)
			poly(ci, [Vector2(r * 1.35, -r * 1.55), Vector2(r * 1.0, -r * 0.9), Vector2(r * 1.7, -r * 0.9)], accent, INK, 1.5)
		"worm_tail":
			for k in range(3):
				var c := Vector2(0, r * (0.95 + k * 0.45))
				ci.draw_circle(c, r * (0.62 - k * 0.12), dark)
				ci.draw_circle(c, r * (0.54 - k * 0.12), body.darkened(0.08 * k))
		"cross_satchel":
			ci.draw_line(Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.7, r * 0.2), Color(1, 1, 1, 0.5), 3.0)
			ci.draw_rect(Rect2(r * 0.45, -r * 0.05, r * 0.75, r * 0.65), Color("e7f2f6"))
			ci.draw_rect(Rect2(r * 0.45, -r * 0.05, r * 0.75, r * 0.65), INK, false, 2.0)
			ci.draw_rect(Rect2(r * 0.74, r * 0.03, r * 0.16, r * 0.49), Color("e8394a"))
			ci.draw_rect(Rect2(r * 0.58, r * 0.2, r * 0.48, r * 0.16), Color("e8394a"))

# ------------------------------------------------------------------ skin decorations (giver)
static func decor(ci: CanvasItem, d: String, shape: String, r: float, body: Color, dark: Color, accent: Color) -> void:
	# Reach adapts to the body shape so decorations hug any silhouette.
	var reach: float = 1.25 if shape in ["dart", "diamond", "pillar", "cone"] else 1.05
	match d:
		"bomb_spikes":
			for k in range(8):
				var a := TAU * float(k) / 8.0 + PI / 8.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a - 0.16) * r * 0.85, Vector2.from_angle(a) * r * (reach + 0.2), Vector2.from_angle(a + 0.16) * r * 0.85]), dark)
				ci.draw_circle(Vector2.from_angle(a) * r * (reach + 0.18), r * 0.06, accent)
		"fuse":
			var top := Vector2(r * 0.05, -r * (reach + 0.02))
			ci.draw_line(top, top + Vector2(r * 0.22, -r * 0.42), Color("c8a060"), 3.0)
			ci.draw_circle(top + Vector2(r * 0.24, -r * 0.46), r * 0.12, Color("ffd24d"))
			ci.draw_circle(top + Vector2(r * 0.24, -r * 0.46), r * 0.06, Color.WHITE)
		"swept_fins":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(side * r * 0.55, r * 0.1), Vector2(side * r * 1.35, r * 0.75), Vector2(side * r * 0.6, r * 0.65)], dark)
		"speed_tail":
			for k in range(3):
				ci.draw_line(Vector2((k - 1) * r * 0.25, r * 1.05), Vector2((k - 1) * r * 0.35, r * 1.5), Color(body, 0.55), 2.0)
		"stubby_feet":
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.55, r * 0.85), r * 0.3, dark)
		"horns":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(side * r * 0.6, -r * 0.5), Vector2(side * r * 1.25, -r * 1.5), Vector2(side * r * 0.95, -r * 0.12)], Color("fff0cf"), INK, 2.0)
		"egg_pack":
			for k in range(3):
				var ep := Vector2((k - 1) * r * 0.55, -r * 1.02 - float(k % 2) * r * 0.2)
				ci.draw_circle(ep, r * 0.3, INK)
				ci.draw_circle(ep, r * 0.26, Color("ffd9e6"))
				ci.draw_circle(ep + Vector2(r * 0.06, r * 0.04), r * 0.06, accent)
		"bow":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(-r * 0.32, -r * 0.92), Vector2(-r * 0.32 + side * r * 0.32, -r * 1.12), Vector2(-r * 0.32 + side * r * 0.32, -r * 0.72)], accent, INK, 1.5)
			ci.draw_circle(Vector2(-r * 0.32, -r * 0.92), r * 0.1, accent.lightened(0.3))
		"army_helmet":
			ci.draw_arc(Vector2(0, -r * 0.35), r * 0.85, PI * 1.08, PI * 1.92, 16, Color("4a5a36"), r * 0.32, true)
			ci.draw_line(Vector2(-r * 0.85, -r * 0.42), Vector2(r * 0.85, -r * 0.42), Color("2f3a22"), 3.0)
		"crown":
			poly(ci, [Vector2(-r * 0.6, -r * 1.25), Vector2(-r * 0.6, -r * 1.6), Vector2(-r * 0.2, -r * 1.42), Vector2(0, -r * 1.8),
				Vector2(r * 0.2, -r * 1.42), Vector2(r * 0.6, -r * 1.6), Vector2(r * 0.6, -r * 1.25)], accent, INK, 2.0)
		"six_legs":
			for k in range(6):
				var lx := -1.0 if k < 3 else 1.0
				var ly := (k % 3 - 1) * r * 0.55
				ci.draw_line(Vector2(lx * r * 0.5, ly), Vector2(lx * r * 1.45, ly + r * 0.35), dark, 2.5)
		"pointy_ears":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(side * r * 0.65, -r * 0.15), Vector2(side * r * 1.4, -r * 0.65), Vector2(side * r * 1.0, r * 0.35)], body.darkened(0.15), INK, 2.0)
		"flame_wings":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(side * r * 0.5, 0), Vector2(side * r * 1.7, -r * 0.8), Vector2(side * r * 1.2, r * 0.25), Vector2(side * r * 1.35, r * 0.7)], Color("ff632f"), INK, 2.0)
				ci.draw_line(Vector2(side * r * 0.5, 0), Vector2(side * r * 1.35, -r * 0.55), accent, maxf(2.0, r * 0.12))
		"flame_crest":
			poly(ci, [Vector2(-r * 0.4, -r * 0.75), Vector2(0, -r * 1.85), Vector2(r * 0.4, -r * 0.75)], accent, INK, 2.0)
		"dig_claws":
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.85, r * 0.48), r * 0.4, dark)
				for k in range(3):
					ci.draw_line(Vector2(side * r * 1.0, r * (0.35 + k * 0.15)), Vector2(side * r * 1.45, r * (0.5 + k * 0.18)), accent, 3.0)
		"fin_ears":
			for side in [-1.0, 1.0]:
				poly(ci, [Vector2(side * r * 0.7, -r * 0.25), Vector2(side * r * 1.4, -r * 0.92), Vector2(side * r * 1.25, r * 0.4)], dark.lightened(0.15), INK, 2.0)
		"four_legs":
			for side in [-1.0, 1.0]:
				for k in range(2):
					var hip := Vector2(side * r * 0.6, r * (-0.1 + k * 0.55))
					ci.draw_polyline(PackedVector2Array([hip, hip + Vector2(side * r * 0.65, -r * 0.25 + k * r * 0.5), hip + Vector2(side * r * 1.0, r * 0.25 + k * r * 0.35)]), accent, 3.0, true)
		"antennae":
			for side in [-1.0, 1.0]:
				ci.draw_line(Vector2(side * r * 0.25, -r * 0.8), Vector2(side * r * 0.6, -r * 1.45), dark, 2.5)
				ci.draw_circle(Vector2(side * r * 0.6, -r * 1.45), r * 0.12, accent)
		"hard_hat":
			ci.draw_arc(Vector2(0, -r * 0.3), r * 0.85, PI * 1.05, PI * 1.95, 16, Color("ffc23d"), r * 0.34, true)
			ci.draw_line(Vector2(-r * 0.95, -r * 0.35), Vector2(r * 0.95, -r * 0.35), Color("c8902a"), 4.0)
		"plume":
			poly(ci, [Vector2(-r * 0.12, -r * 0.9), Vector2(r * 0.3, -r * 1.55), Vector2(r * 0.12, -r * 0.88)], Color("ff3a5a"), INK, 1.5)
		"nurse_cap":
			ci.draw_rect(Rect2(-r * 0.4, -r * 1.25, r * 0.8, r * 0.42), Color("f2f6f8"))
			ci.draw_rect(Rect2(-r * 0.4, -r * 1.25, r * 0.8, r * 0.42), INK, false, 2.0)
			ci.draw_rect(Rect2(-r * 0.06, -r * 1.2, r * 0.12, r * 0.32), accent)
			ci.draw_rect(Rect2(-r * 0.16, -r * 1.1, r * 0.32, r * 0.12), accent)
		"laser_lens":
			ci.draw_line(Vector2(0, -r * 0.7), Vector2(0, -r * 1.0), Color("2a2d36"), r * 0.25)
			ci.draw_circle(Vector2(0, -r * 1.1), r * 0.3, INK)
			ci.draw_circle(Vector2(0, -r * 1.1), r * 0.22, accent)
			ci.draw_circle(Vector2(0, -r * 1.1), r * 0.09, Color("ffe0e8"))
		"ghost_wisp":
			var skirt := PackedVector2Array([Vector2(-r * 0.75, r * 0.4), Vector2(r * 0.75, r * 0.4)])
			for k in range(7):
				var x := r * 0.75 - float(k) * r * 1.5 / 6.0
				skirt.append(Vector2(x, r * (1.25 if k % 2 == 0 else 0.95)))
			poly(ci, skirt, Color(body, 0.85), dark, 2.0)
		"prism_spikes":
			for k in range(6):
				var a2 := TAU * float(k) / 6.0 + PI / 6.0
				poly(ci, [Vector2.from_angle(a2 - 0.14) * r * 0.85, Vector2.from_angle(a2) * r * (reach + 0.35), Vector2.from_angle(a2 + 0.14) * r * 0.85], Color("c6f6ff"), Color("1b4b66"), 1.5)
		"cell_buds":
			for side in [-1.0, 1.0]:
				var bc := Vector2(side * r * 0.85, r * 0.55)
				ci.draw_circle(bc, r * 0.32, dark)
				ci.draw_circle(bc, r * 0.26, body)
				ci.draw_circle(bc + Vector2(r * 0.04, r * 0.02), r * 0.09, Color(dark, 0.7))
		"heat_vents":
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(side * r * 1.0 - r * 0.18, -r * 0.35, r * 0.36, r * 0.7), Color("4a4e5a"))
				for k in range(3):
					ci.draw_line(Vector2(side * r * 1.0 - r * 0.12, -r * 0.2 + k * r * 0.2), Vector2(side * r * 1.0 + r * 0.12, -r * 0.2 + k * r * 0.2), accent, 2.0)

# ------------------------------------------------------------------ surface patterns (giver)
static func pattern(ci: CanvasItem, p: String, shape: String, r: float, body: Color, dark: Color, accent: Color) -> void:
	match p:
		"gloss":
			ci.draw_circle(Vector2(-r * 0.42, -r * 0.5), maxf(2.0, r * 0.14), Color(1, 1, 1, 0.42))
		"shine":
			ci.draw_arc(Vector2.ZERO, r * 0.72, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.3), 3.0, true)
			ci.draw_circle(Vector2(-r * 0.45, -r * 0.45), r * 0.1, Color(1, 1, 1, 0.5))
		"belly":
			ci.draw_circle(Vector2(0, r * 0.4), r * 0.48, body.lightened(0.16))
		"bubbles":
			for k in range(3):
				ci.draw_circle(Vector2((k - 1) * r * 0.45, r * 0.55 - absf(k - 1) * r * 0.1), r * 0.1, Color(accent, 0.75))
			ci.draw_circle(Vector2(-r * 0.42, -r * 0.5), maxf(2.0, r * 0.13), Color(1, 1, 1, 0.4))
		"nuclei":
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.55, r * 0.35), r * 0.2, Color(dark, 0.55))
		"plate":
			ci.draw_rect(Rect2(-r * 0.6, r * 0.1, r * 1.2, r * 0.24), dark.lightened(0.2))
		"stripes":
			for k in range(3):
				ci.draw_line(Vector2(-r * (0.3 + k * 0.2), -r * 0.4 + k * r * 0.35), Vector2(r * (0.3 + k * 0.2), -r * 0.4 + k * r * 0.35), Color(dark, 0.45), 2.0)
		"back_shell":
			ci.draw_circle(Vector2(0, r * 0.35), r * 0.5, body.darkened(0.25))
		"facets":
			ci.draw_line(Vector2(-r * 0.5, r * 0.2), Vector2(r * 0.45, -r * 0.45), Color(1, 1, 1, 0.75), 2.2)
			ci.draw_line(Vector2(-r * 0.2, r * 0.6), Vector2(r * 0.3, r * 0.1), Color(1, 1, 1, 0.4), 1.8)
		"face_patch":
			ci.draw_circle(Vector2(0, r * 0.15), r * 0.6, body.lightened(0.2))
		"shell_split":
			ci.draw_line(Vector2(0, -r * 0.2), Vector2(0, r * 1.15), dark, 2.5)
			ci.draw_arc(Vector2(0, r * 0.15), r * 0.75, PI * 0.15, PI * 0.85, 12, Color(1, 1, 1, 0.25), 2.0, true)

# ------------------------------------------------------------------ eyes (taker) and mouth (giver)
static func eyes(ci: CanvasItem, style: String, r: float) -> void:
	var ey := -r * 0.18
	var er := maxf(3.5, r * 0.3)
	if style == "visor":
		ci.draw_rect(Rect2(-r * 0.8, ey - er * 0.7, r * 1.6, er * 1.4), Color("200810"))
		return
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(side * r * 0.36, ey), er, Color.WHITE)

static func mouth(ci: CanvasItem, m: String, r: float, body: Color, dark: Color, accent: Color) -> void:
	match m:
		"smile":
			ci.draw_arc(Vector2(0, r * 0.35), r * 0.28, 0.25, PI - 0.25, 10, dark.darkened(0.3), 2.5, true)
		"flat":
			ci.draw_line(Vector2(-r * 0.32, r * 0.36), Vector2(r * 0.4, r * 0.26), dark.darkened(0.3), 2.5)
		"frown":
			var ey := -r * 0.18
			ci.draw_line(Vector2(-r * 0.55, ey - r * 0.36), Vector2(-r * 0.15, ey - r * 0.2), INK, 3.0)
			ci.draw_line(Vector2(r * 0.55, ey - r * 0.36), Vector2(r * 0.15, ey - r * 0.2), INK, 3.0)
			ci.draw_arc(Vector2(0, r * 0.45), r * 0.3, PI + 0.3, TAU - 0.3, 10, INK, 3.0, true)
		"o_mouth":
			ci.draw_circle(Vector2(0, r * 0.38), r * 0.22, dark.darkened(0.3))
			ci.draw_circle(Vector2(0, r * 0.38), r * 0.12, accent)
		"red_grin":
			ci.draw_arc(Vector2(0, r * 0.1), r * 0.62, 0.3, PI - 0.3, 16, accent, 3.5, true)
		"small_o":
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.15, accent)
		"grill":
			ci.draw_rect(Rect2(-r * 0.3, r * 0.3, r * 0.6, r * 0.2), dark)
			for k in range(3):
				ci.draw_line(Vector2(-r * 0.2 + k * r * 0.2, r * 0.3), Vector2(-r * 0.2 + k * r * 0.2, r * 0.5), body, 1.5)
		"fangs":
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(side * r * 0.12, r * 0.4), Vector2(side * r * 0.04, r * 0.4), Vector2(side * r * 0.08, r * 0.6)]), Color.WHITE)
		"gold_grin":
			ci.draw_arc(Vector2(0, r * 0.3), r * 0.3, 0.3, PI - 0.3, 10, dark.darkened(0.3), 3.0, true)
			ci.draw_rect(Rect2(r * 0.05, r * 0.52, r * 0.12, r * 0.1), Color("ffd24d"))
		"beak":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.2, r * 0.25), Vector2(r * 0.2, r * 0.25), Vector2(0, r * 0.55)]), accent)
		"nose_dot":
			ci.draw_circle(Vector2(0, r * 0.45), r * 0.2, Color("503b2b"))
		"megaphone":
			poly(ci, [Vector2(-r * 0.18, r * 0.42), Vector2(-r * 0.45, r * 0.95), Vector2(r * 0.45, r * 0.95), Vector2(r * 0.18, r * 0.42)], accent, dark, 2.0)
		"sucker":
			ci.draw_circle(Vector2(0, r * 0.4), r * 0.34, Color("3c145a"))
			for k in range(8):
				var a := TAU * float(k) / 8.0
				ci.draw_line(Vector2(0, r * 0.4) + Vector2.from_angle(a) * r * 0.34, Vector2(0, r * 0.4) + Vector2.from_angle(a) * r * 0.2, accent, 2.0)
		"snout":
			ci.draw_circle(Vector2(0, r * 0.42), r * 0.4, body.lightened(0.18))
			ci.draw_arc(Vector2(0, r * 0.42), r * 0.4, 0.0, TAU, 20, dark, 2.0, true)
			for side in [-1.0, 1.0]:
				ci.draw_circle(Vector2(side * r * 0.14, r * 0.45), r * 0.07, INK)
		"grit":
			ci.draw_rect(Rect2(-r * 0.32, r * 0.3, r * 0.64, r * 0.18), Color("2a0b14"))
			for k in range(4):
				ci.draw_line(Vector2(-r * 0.24 + k * r * 0.16, r * 0.3), Vector2(-r * 0.24 + k * r * 0.16, r * 0.48), Color.WHITE, 1.5)
