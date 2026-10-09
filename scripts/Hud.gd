extends Node2D
## All UI: HUD, level-up cards, arsenal, collection, menus. Buttons register themselves each
## frame while drawing; click() resolves them.

const Weapons = preload("res://scripts/Weapons.gd")
const Effects = preload("res://scripts/Effects.gd")
const CardArt = preload("res://scripts/CardArt.gd")

var g
var bold: Font
var body: Font
var buttons: Array = []
var peek = false
var collection_cat = "volley"
var collection_page = 0
var hover_card = null
var hp_trail = 1.0
var last_click_frame = -1
var selected_collection_item = null
var inspected_card_id = ""
var press_action = ""
var press_t = -9.0

const INK = Color("06080d")
const SURFACE = Color("121722")
const MUTED = Color("8fa6b8")
const PANEL = Color("0a0d14")
const PANEL_EDGE = Color("2f7f8a")
const NEON = Color("5ef6ff")
const ALERT = Color("ff4655")
const BTN_PRIMARY = Color("f3e600")
const BTN_SECONDARY = NEON
const BTN_TEXT_DARK = Color("0a0a0f")

const RARITY = ["COMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "ASCENDANT"]
## Ascendant (index 5) shimmers through the rainbow; _draw() updates it every frame.
var RCOL = [Color("b9c6d6"), Color("4fe0ff"), Color("c07bff"), Color("ffcf4d"), Color("ff648c"), Color("7ff7ff")]
const CAT_COLOR = Color("607087")

func _ready() -> void:
	g = get_parent()
	bold = game_font()
	body = body_font()

## Bundled fonts so phones look the same as desktop (Android has no Impact/Segoe UI).
## Rajdhani: condensed and squared-off, so labels read as a HUD rather than a cartoon.
static func game_font() -> Font:
	if ResourceLoader.exists("res://assets/fonts/Rajdhani-Bold.ttf"):
		var fv = FontVariation.new()
		fv.base_font = load("res://assets/fonts/Rajdhani-Bold.ttf")
		fv.spacing_glyph = 1
		return fv
	var b = SystemFont.new()
	b.font_names = PackedStringArray(["Impact", "Arial Black", "Segoe UI Black"])
	return b

static func body_font() -> Font:
	if ResourceLoader.exists("res://assets/fonts/Rajdhani-SemiBold.ttf"):
		return load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	var t = SystemFont.new()
	t.font_names = PackedStringArray(["Segoe UI", "Arial", "Verdana"])
	t.font_weight = 600
	return t

# ================================================================= primitives
func txt(t: String, pos: Vector2, size: int, color: Color, align = 0, f: Font = null, outline = 0) -> void:
	var ff = f if f != null else bold
	var w = ff.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p = pos
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	if outline > 0:
		draw_string_outline(ff, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.02, 0.02, 0.07, color.a))
	draw_string(ff, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func wrap_text(t: String, x: float, y: float, width: float, size: int, color: Color, line_h: float, f: Font = null, center = false, max_lines = 99) -> float:
	var ff = f if f != null else body
	var line = ""
	var lines = []
	for word in t.split(" "):
		var test = word if line == "" else line + " " + word
		if ff.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			lines.append(line)
			line = word
		else:
			line = test
	if line != "":
		lines.append(line)
	for i in range(mini(lines.size(), max_lines)):
		if center:
			txt(lines[i], Vector2(x + width * 0.5, y + i * line_h), size, color, 1, ff)
		else:
			txt(lines[i], Vector2(x, y + i * line_h), size, color, 0, ff)
	return y + mini(lines.size(), max_lines) * line_h

func slant(r: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), skew = 10.0, width = 3.0) -> void:
	var pts = PackedVector2Array([r.position + Vector2(skew, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - skew, r.end.y), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(pts, fill)
	if edge.a > 0:
		pts.append(pts[0])
		draw_polyline(pts, edge, width)

func rbox(r: Rect2, fill: Color, radius: float = 14.0, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	CardArt.rbox(self, r, fill, radius, border, bw)

func cbox(r: Rect2, fill: Color, cut: float, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	CardArt.cbox(self, r, fill, cut, border, bw)

## Hard-edged frame: thin dim outline, bright corner brackets and short accent strips by the cut corner.
func panel(r: Rect2, fill: Color, edge: Color, w = 3.0) -> void:
	var cut = 22.0
	cbox(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.4 * fill.a), cut)
	cbox(r, fill, cut, Color(edge, 0.55 * edge.a), maxi(1, int(w) - 1))
	brackets(r, edge.lightened(0.25), 18.0, 2.0)
	var a = r.position
	draw_line(a + Vector2(cut + 6, 3), a + Vector2(cut + 70, 3), edge.lightened(0.3), 3.0)
	draw_line(a + Vector2(3, cut + 6), a + Vector2(3, cut + 40), edge.lightened(0.3), 3.0)

## Corner brackets on the two square corners of a cut box.
func brackets(r: Rect2, col: Color, len: float, w: float) -> void:
	var tr = Vector2(r.end.x, r.position.y)
	var bl = Vector2(r.position.x, r.end.y)
	draw_polyline(PackedVector2Array([tr + Vector2(-len, 0), tr, tr + Vector2(0, len)]), col, w)
	draw_polyline(PackedVector2Array([bl + Vector2(0, -len), bl, bl + Vector2(len, 0)]), col, w)

## Text size that fits max_w (never below min_size).
func fit(t: String, max_w: float, size: int, f: Font = null, min_size = 11) -> int:
	var ff = f if f != null else bold
	var s = size
	while s > min_size and ff.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s

## Flat neon button with cut corners. Primary is a solid yellow slab; secondary is a dark plate with a
## neon outline and edge strip. Nudges down-right when pressed.
func button(r: Rect2, label: String, action: String, primary = false, size = 24, enabled = true) -> bool:
	var hover = r.has_point(g.mouse_screen) and enabled and not g.is_touch_active()
	var pressed = enabled and press_action == action and g.anim_t - press_t < 0.15
	var accent = BTN_PRIMARY if primary else BTN_SECONDARY
	if not enabled:
		accent = Color("4a5368")
	var cut = clampf(r.size.y * 0.3, 6.0, 20.0)
	var fr = Rect2(r.position + (Vector2(2, 2) if pressed else Vector2.ZERO), r.size)
	cbox(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.45), cut)
	var tc: Color
	if primary and enabled:
		cbox(fr, accent.lightened(0.15) if hover else accent, cut)
		# Dark stripe along the bottom and a notch block, like a hazard plate.
		draw_rect(Rect2(fr.position.x + cut + 6, fr.end.y - 6, fr.size.x * 0.35, 2), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(fr.end.x - 16, fr.position.y + 6, 8, 4), Color(0, 0, 0, 0.45))
		tc = BTN_TEXT_DARK
	else:
		cbox(fr, Color(accent, 0.2) if hover else Color(0.03, 0.05, 0.08, 0.92), cut, Color(accent, 0.95 if hover else 0.7), 2)
		draw_rect(Rect2(fr.position.x + 5, fr.position.y + cut + 2, 3, fr.size.y - cut - 9), accent)
		tc = accent.lerp(Color.WHITE, 0.55 if hover else 0.25) if enabled else Color("6d768a")
	var fitted = fit(label, r.size.x - 28, size, bold, 12)
	txt(label, Vector2(fr.get_center().x, fr.get_center().y + fitted * 0.34), fitted, tc, 1, bold)
	if enabled:
		buttons.append({"rect": r, "action": action})
	return hover

## Square icon button (pause, bag) with cut corners, matching button().
func icon_button(c: Vector2, rad: float, action: String, icon: String) -> void:
	var r = Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	var pressed = press_action == action and g.anim_t - press_t < 0.15
	var p = c + (Vector2(2, 2) if pressed else Vector2.ZERO)
	var fr = Rect2(p - Vector2(rad, rad), r.size)
	cbox(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.45), rad * 0.45)
	cbox(fr, Color(0.03, 0.05, 0.08, 0.92), rad * 0.45, Color(NEON, 0.8), 2)
	match icon:
		"pause":
			draw_rect(Rect2(p + Vector2(-rad * 0.32, -rad * 0.38), Vector2(rad * 0.22, rad * 0.76)), NEON)
			draw_rect(Rect2(p + Vector2(rad * 0.1, -rad * 0.38), Vector2(rad * 0.22, rad * 0.76)), NEON)
		"bag":
			for k in range(3):
				var cr = Rect2(p + Vector2(-rad * 0.42 + k * rad * 0.2, -rad * 0.36 - k * 2.0), Vector2(rad * 0.46, rad * 0.66))
				cbox(cr, Color("06080d"), 4, [Color("4fe0ff"), Color("c07bff"), Color("ffcf4d")][k], 2)
	buttons.append({"rect": r.grow(6), "action": action})

func click(pos: Vector2) -> void:
	var f = Engine.get_process_frames()
	if f == last_click_frame:
		return
	last_click_frame = f
	for i in range(buttons.size() - 1, -1, -1):
		if buttons[i]["rect"].has_point(pos):
			press_action = str(buttons[i]["action"])
			press_t = g.anim_t
			g.do_action(buttons[i]["action"])
			return

func scroll(d: int) -> void:
	collection_page = maxi(0, collection_page + d)

func collection_key(code: int) -> void:
	if code == KEY_RIGHT:
		scroll(1)
	elif code == KEY_LEFT:
		scroll(-1)

# ================================================================= main draw
func _draw() -> void:
	RCOL[5] = Color.from_hsv(fmod(g.anim_t * 0.3, 1.0), 0.6, 1.0)
	buttons.clear()
	hover_card = null
	if g.state in ["map", "shop", "rest", "event"] or g.state == "arsenal" and g.arsenal_back != "playing" and not g.portrait:
		match g.state:
			"event":
				paint_event()
			"map":
				paint_map()
			"shop":
				paint_shop()
			"rest":
				paint_rest()
			"arsenal":
				screen_bg()
				paint_arsenal()
		return
	if g.portrait:
		paint_portrait()
		return
	match g.state:
		"menu":
			paint_menu()
		"collection":
			paint_collection()
		"upgrades":
			paint_menu_bg()
			paint_upgrades()
		"settings":
			if g.settings_back == "menu":
				paint_menu_bg()
			else:
				paint_hud()
			paint_settings()
		"playing":
			paint_hud()
		"paused":
			paint_hud()
			paint_pause()
		"arsenal":
			paint_hud()
			paint_arsenal()
		"levelup":
			paint_hud()
			if peek:
				paint_arsenal()
				txt("TAB  -  back to cards", Vector2(640, 700), 18, Color("ffd24d"), 1, bold, 4)
			else:
				paint_levelup()
		"replace":
			paint_hud()
			paint_replace()
		"lost":
			paint_lost()
		"victory":
			paint_victory()
	if g.debug_mode:
		panel(Rect2(10, 160, 230, 110), Color(0, 0, 0, 0.75), Color("4fe0ff"), 1.0)
		txt("FPS %d" % Engine.get_frames_per_second(), Vector2(20, 185), 16, Color.WHITE, 0, body)
		txt("enemies %d  shots %d" % [g.enemies.size(), g.shots.size()], Vector2(20, 207), 14, Color.WHITE, 0, body)
		txt("fx %d  zones %d  pickups %d" % [g.fx.size(), g.zones.size(), g.pickups.size()], Vector2(20, 228), 14, Color.WHITE, 0, body)
		txt("procs/frame %d" % g.frame_procs, Vector2(20, 249), 14, Color.WHITE, 0, body)

# ================================================================= portrait mobile layout
func dim(a: float = 0.84) -> void:
	draw_rect(Rect2(0, 0, 720, g.ui_height), Color(0.02, 0.03, 0.08, a))

func portrait_bg() -> void:
	var h = g.ui_height
	draw_rect(Rect2(0, 0, 720, h), Color("0a1022"))
	var art = g.tex("res://assets/ui/title.png")
	if art != null:
		# Cover-fit the wide title art into the tall screen and let it drift slowly.
		var sz = art.get_size()
		var w = sz.x * h / sz.y
		var drift = sin(g.anim_t * 0.15) * 40.0
		draw_texture_rect(art, Rect2(360 - w * 0.5 + drift, 0, w, h), false, Color(0.42, 0.42, 0.52))
	for i in range(12):
		var t = i / 12.0
		draw_rect(Rect2(0, h * t, 720, h / 12.0 + 1.0), Color(0.02, 0.03, 0.09, 0.3 + 0.5 * absf(t - 0.42)))

func paint_conga(y: float, width: float) -> void:
	for i in range(9):
		var x = fposmod(g.anim_t * 120.0 + i * 160.0, width + 160.0) - 80.0
		var by = y - absf(sin(g.anim_t * 8.0 + i)) * 10.0
		var c = [Color("ff7b93"), Color("ffb36b"), Color("7dffcf"), Color("ff5a4a")][i % 4]
		draw_circle(Vector2(x, by), 16, c.darkened(0.4))
		draw_circle(Vector2(x, by - 1), 14, c)
		draw_circle(Vector2(x - 5, by - 4), 5, Color.WHITE)
		draw_circle(Vector2(x + 5, by - 4), 5, Color.WHITE)
		draw_circle(Vector2(x - 3, by - 4), 2.5, Color.BLACK)
		draw_circle(Vector2(x + 7, by - 4), 2.5, Color.BLACK)

func logo(c: Vector2, scale: float) -> void:
	glitch_txt("SLIME", c, int(108 * scale), Color.WHITE)
	glitch_txt("HOUR", c + Vector2(0, 100 * scale), int(124 * scale), ALERT)

## Title text with a cyan/red channel split that jumps wider now and then.
func glitch_txt(t: String, pos: Vector2, size: int, col: Color) -> void:
	var j = 2.0 + (6.0 if fmod(g.anim_t, 3.7) < 0.12 else 0.0)
	txt(t, pos + Vector2(-j, 0), size, Color(NEON, 0.75 * col.a), 1, bold)
	txt(t, pos + Vector2(j, 0), size, Color(ALERT, 0.75 * col.a), 1, bold)
	txt(t, pos, size, col, 1, bold)

func paint_portrait() -> void:
	var h = g.ui_height
	match g.state:
		"menu":
			portrait_bg()
			paint_conga(h - 60.0, 720.0)
			logo(Vector2(360, h * 0.2), 1.0)
			button(Rect2(130, h * 0.46, 460, 100), "PLAY", "play", true, 46)
			button(Rect2(130, h * 0.46 + 122, 460, 80), "HARD MODE", "play_hard", false, 30)
			button(Rect2(130, h * 0.46 + 222, 460, 80), "COLLECTION", "collection", false, 30)
			button(Rect2(130, h * 0.46 + 322, 460, 80), "SETTINGS", "settings", false, 30)
			button(Rect2(130, h * 0.46 + 422, 460, 80), "UPGRADES", "upgrades", false, 30)
			goo_chip(Vector2(360, h * 0.46 + 540))
			profile_bar(Vector2(360, h * 0.46 - 70), 460.0)
			var best = "BEST  SECTOR %d   ·   %d KILLS" % [int(g.best["sector"]), int(g.best["kills"])]
			rbox(Rect2(110, h - 168, 500, 52), Color(0, 0, 0, 0.45), 26)
			txt(best, Vector2(360, h - 133), 21, Color("ffd24d"), 1, bold)
		"playing":
			paint_portrait_hud()
		"paused":
			paint_portrait_hud()
			dim(0.72)
			panel(Rect2(90, h * 0.3, 540, 470), PANEL, PANEL_EDGE, 3)
			txt("PAUSED", Vector2(360, h * 0.3 + 92), 70, Color.WHITE, 1, bold, 6)
			button(Rect2(140, h * 0.3 + 140, 440, 90), "RESUME", "resume", true, 38)
			button(Rect2(140, h * 0.3 + 254, 440, 76), "SETTINGS", "settings", false, 28)
			button(Rect2(140, h * 0.3 + 354, 440, 76), "MAIN MENU", "menu", false, 28)
		"levelup":
			if peek:
				paint_portrait_arsenal()
			else:
				paint_portrait_offers()
		"replace":
			paint_portrait_replace()
		"arsenal":
			paint_portrait_arsenal()
		"settings":
			paint_portrait_settings()
		"collection":
			paint_portrait_collection()
		"upgrades":
			portrait_bg()
			paint_upgrades()
		"lost", "victory":
			paint_portrait_result()

# ---------------------------------------------------------------- in-game HUD
func paint_portrait_hud() -> void:
	if g.hero.is_empty():
		return
	paint_unlock_toast(360, 230)
	if g.dying_t > 0.0:
		paint_dying()
	var h = g.ui_height
	var hero = g.hero
	for i in range(10):
		draw_rect(Rect2(0, i * 20, 720, 20), Color(0.01, 0.02, 0.06, 0.6 * (1.0 - i / 10.0)))
	# XP strip + level badge
	var xr = clampf(float(g.xp) / maxf(1.0, float(g.xp_need)), 0.0, 1.0)
	draw_rect(Rect2(0, 0, 720, 9), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(0, 0, 720 * xr, 9), Color("b48cff"))
	var lc = Vector2(56, 68)
	draw_circle(lc, 37, Color("0b1224"))
	draw_arc(lc, 33, -PI * 0.5, -PI * 0.5 + TAU * xr, 40, Color("b48cff"), 6.0)
	draw_circle(lc, 27, Color("3a2468"))
	txt("LV", lc + Vector2(0, -7), 14, Color("d6c2ff"), 1, bold)
	txt(str(g.level), lc + Vector2(0, 17), fit(str(g.level), 44, 26), Color.WHITE, 1, bold, 3)
	# HP bar
	var ratio = clampf(float(hero["hp"]) / maxf(1.0, float(hero["maxhp"])), 0.0, 1.0)
	hp_trail = lerpf(hp_trail, ratio, 0.04) if hp_trail > ratio else ratio
	var hr = Rect2(104, 44, 300, 32)
	rbox(hr.grow(3), Color(0, 0, 0, 0.7), 19)
	rbox(Rect2(hr.position, Vector2(hr.size.x * hp_trail, hr.size.y)), Color(1, 1, 1, 0.8), 16)
	var hpc = Color("ff4d6a") if ratio > 0.3 else Color("ff4d6a").lerp(Color.WHITE, 0.4 + 0.4 * sin(g.anim_t * 12.0))
	rbox(Rect2(hr.position, Vector2(maxf(hr.size.y, hr.size.x * ratio), hr.size.y)), hpc, 16)
	rbox(Rect2(hr.position + Vector2(8, 4), Vector2(maxf(0.0, hr.size.x * ratio - 16), 8)), Color(1, 1, 1, 0.25), 4)
	txt("%d / %d" % [ceili(float(hero["hp"])), int(hero["maxhp"])], hr.get_center() + Vector2(0, 8), 22, Color.WHITE, 1, bold, 4)
	# shields + dash pips under the bar
	var x = 110.0
	for i in range(int(hero["shield"])):
		draw_circle(Vector2(x + 8, 92), 8, Color("8ff8ff"))
		draw_circle(Vector2(x + 8, 92), 4.5, Color("2a6a80"))
		x += 20
	var charges = 1 + int(g.st("dashes"))
	for i in range(charges):
		var full = i < int(hero["dash_charges"])
		rbox(Rect2(x + 4 + i * 26, 86, 22, 11), Color("4fe0ff") if full else Color(0.2, 0.3, 0.4, 0.8), 5)
	# gold, bag, pause
	var gr = Rect2(420, 44, 124, 36)
	rbox(gr, Color(0, 0, 0, 0.6), 18)
	draw_circle(gr.position + Vector2(18, 18), 12, Color("b8860b"))
	draw_circle(gr.position + Vector2(18, 18), 9, Color("ffd24d"))
	txt("%d" % g.gold, Vector2(gr.end.x - 14, gr.position.y + 27), fit("%d" % g.gold, 80, 24), Color("ffd24d"), 2, bold, 3)
	icon_button(Vector2(590, 62), 28, "open_arsenal", "bag")
	icon_button(Vector2(664, 62), 28, "pause", "pause")
	# guns (left) + sector progress (right)
	for i in range(mini(g.guns.size(), 3)):
		gun_chip(g.guns[i], Rect2(20 + i * 68, 108, 60, 60))
	var px = 236.0 if g.guns.size() >= 3 else 172.0
	var pw = 700.0 - px
	var prog = g.progress() if g.phase == "fight" else 1.0
	var label = "SECTOR %d  ·  %d LEFT" % [g.sector, g.enemies_left()] if g.phase == "fight" else "SECTOR %d" % g.sector
	txt(label, Vector2(700, 130), 22, Color.WHITE, 2, bold, 3)
	if g.is_boss_sector() and g.phase == "fight":
		txt("BOSS", Vector2(px, 130), 18, Color("ff6b7a"), 0, bold, 3)
	rbox(Rect2(px, 142, pw, 12), Color(0, 0, 0, 0.6), 6)
	rbox(Rect2(px, 142, maxf(12.0, pw * prog), 12), Color("4fe0ff"), 6)
	for mk in [0.55, 0.8]:
		if mk == 0.8 and not g.is_boss_sector():
			continue
		draw_circle(Vector2(px + pw * mk, 148), 5, Color("ffd24d") if prog < mk else Color("4fe0ff"))
	# boss bar
	for e in g.enemies:
		if bool(e["boss"]) and not bool(e["dead"]) and int(e["gen"]) == 0:
			var br = clampf(float(e["hp"]) / float(e["max_hp"]), 0.0, 1.0)
			rbox(Rect2(60, 182, 600, 26), Color(0, 0, 0, 0.75), 13)
			rbox(Rect2(63, 185, maxf(20.0, 594 * br), 20), Color("ff4d6a"), 10)
			txt(str(g.enemy_db[e["kind"]]["name"]), Vector2(360, 202), 19, Color.WHITE, 1, bold, 4)
			break
	paint_portrait_banner()
	paint_combo(Vector2(704, 280))
	if g.is_touch_active() and g.state == "playing":
		paint_touch_controls()
		if bool(g.settings["hints"]) and g.sector == 1 and g.run_time < 9.0:
			rbox(Rect2(100, h * 0.6, 520, 54), Color(0, 0, 0, 0.5), 27)
			txt("DRAG ANYWHERE TO MOVE  ·  GUNS AUTO-FIRE", Vector2(360, h * 0.6 + 35), 20, Color.WHITE, 1, bold, 2)

func gun_chip(w: Dictionary, r: Rect2) -> void:
	var tier = clampi(int(w.get("tier", 0)), 0, 5)
	rbox(r, Color(0.04, 0.06, 0.13, 0.85), 12, RCOL[tier], 2)
	var icon = g.tex("res://assets/weapons/%s.png" % w["id"])
	if icon != null:
		draw_texture_rect(icon, r.grow(-7), false)
	txt(str(int(w["lvl"])), r.position + Vector2(6, 17), 15, Color("ffd24d"), 0, bold, 3)
	var bar = Rect2(r.position.x + 6, r.end.y - 10, r.size.x - 12, 5)
	draw_rect(bar, Color(0, 0, 0, 0.7))
	var kind = str(g.weapon_db[w["id"]]["kind"])
	var f = 1.0
	var col = Color("4fe0ff")
	if float(w["reload"]) > 0.0:
		f = 1.0 - float(w["reload"]) / maxf(0.01, float(w["reload_max"]))
		col = Color("ffd24d")
	elif kind == "beam":
		f = 1.0 - float(w["heat"]) / 3.0
		col = Color("ff4d6a") if bool(w["over"]) else Color("c58cff")
	else:
		f = float(w["ammo"]) / maxf(1.0, float(w["mag_max"]))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(f, 0.0, 1.0), bar.size.y)), col)

func paint_portrait_banner() -> void:
	if g.banner_t <= 0.0:
		return
	var a = clampf(g.banner_t / 0.4, 0.0, 1.0)
	var pop = 1.0 + maxf(0.0, g.banner_t - 1.6) * 0.5
	var y = g.ui_height * 0.27
	draw_rect(Rect2(0, y - 62, 720, 104), Color(0.02, 0.03, 0.08, 0.62 * a))
	draw_rect(Rect2(0, y - 62, 720, 3), Color(1, 0.82, 0.3, 0.8 * a))
	draw_rect(Rect2(0, y + 39, 720, 3), Color(1, 0.82, 0.3, 0.8 * a))
	var s = fit(g.banner_text, 680, int(56 * minf(pop, 1.25)))
	txt(g.banner_text, Vector2(360, y + 4), s, Color(1, 1, 1, a), 1, bold, 7)
	if g.banner_sub != "":
		txt(g.banner_sub.to_upper(), Vector2(360, y + 30), fit(g.banner_sub.to_upper(), 680, 19), Color(1, 0.85, 0.3, a), 1, bold, 3)

func paint_combo(anchor: Vector2) -> void:
	if g.combo < 8:
		return
	var words = [[8, "NICE"], [20, "SPICY"], [40, "UNHINGED"], [80, "MASSACRE"], [150, "WAR CRIME"], [300, "GOD MODE"]]
	var word = "NICE"
	for wd in words:
		if g.combo >= int(wd[0]):
			word = wd[1]
	var k = clampf(g.combo_t / 2.6, 0.0, 1.0)
	var wob = sin(g.anim_t * 18.0) * 2.0
	txt("x%d" % g.combo, anchor + Vector2(0, wob), 46, Color("ffd24d").lerp(Color("ff4d6a"), minf(1.0, g.combo / 150.0)), 2, bold, 6)
	txt(word, anchor + Vector2(0, 30), 24, Color.WHITE, 2, bold, 5)
	draw_rect(Rect2(anchor.x - 140 * k, anchor.y + 40, 140 * k, 5), Color("ffd24d"))

# ---------------------------------------------------------------- cards
## Art for a card, or (no art yet) its category icon painted straight onto the card: never a box in a box.
func card_art(r: Rect2, info: Dictionary, rc: Color) -> void:
	var art = info.get("art")
	if art != null:
		rbox(r, Color("0d1428"), 14)
		if bool(info.get("icon", false)):
			var s = minf(r.size.x, r.size.y) - 10
			var bob = sin(g.anim_t * 3.0) * 3.0
			draw_texture_rect(art, Rect2(r.get_center() - Vector2(s, s) * 0.5 + Vector2(0, bob), Vector2(s, s)), false)
		else:
			draw_texture_rect(art, r.grow(-3), false)
		rbox(r, Color(0, 0, 0, 0), 14, Color(rc, 0.9), 2)
	else:
		var cat = str(info.get("catid", ""))
		CardArt.glyph(self, cat, r.get_center(), minf(r.size.x, r.size.y) * 0.36, CardArt.hue(cat))

## A card that is ONLY its picture (arsenal grid, result screen): tinted tile + icon when art is missing.
func card_tile(r: Rect2, id: String) -> void:
	var c = g.card_by_id[id]
	var rc: Color = RCOL[int(c["rarity"])]
	var art = g.tex("res://assets/cards/%s.png" % id)
	if art != null:
		rbox(r, Color("0d1428"), 12)
		draw_texture_rect(art, r.grow(-3), false)
	else:
		var hue = CardArt.hue(str(c["cat"]))
		rbox(r, hue.darkened(0.7), 12)
		CardArt.glyph(self, str(c["cat"]), r.get_center() + Vector2(0, -6), minf(r.size.x, r.size.y) * 0.28, hue)
		var name = str(c["name"]).to_upper()
		var ns = maxi(8, int(r.size.y * 0.2))
		if bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x > r.size.x - 8 and name.contains(" "):
			var cut = name.find(" ", int(name.length() * 0.4))
			cut = name.find(" ") if cut < 0 else cut
			txt(name.substr(0, cut), Vector2(r.get_center().x, r.end.y - ns - 6), fit(name.substr(0, cut), r.size.x - 6, ns, bold, 7), Color.WHITE, 1, bold, 2)
			txt(name.substr(cut + 1), Vector2(r.get_center().x, r.end.y - 5), fit(name.substr(cut + 1), r.size.x - 6, ns, bold, 7), Color.WHITE, 1, bold, 2)
		else:
			txt(name, Vector2(r.get_center().x, r.end.y - 6), fit(name, r.size.x - 6, ns, bold, 7), Color.WHITE, 1, bold, 2)
	rbox(r, Color(0, 0, 0, 0), 12, rc, 3)

func portrait_offer_row(r: Rect2, info: Dictionary, appear: float = 1.0) -> void:
	if info.is_empty():
		return
	var rar = clampi(int(info["rar"]), 0, 5)
	var rc: Color = RCOL[rar]
	if bool(info.get("cursed", false)):
		rc = Color("ff3a4a")
	if rar >= 2:
		var pulse = 0.6 + 0.4 * sin(g.anim_t * 4.0)
		for k in range(3):
			rbox(r.grow(4 + k * 5), Color(rc, (0.2 - k * 0.06) * pulse * appear), 24 + k * 5)
	rbox(Rect2(r.position + Vector2(0, 7), r.size), Color(0, 0, 0, 0.45 * appear), 20)
	rbox(r, PANEL, 20, rc, 3)
	rbox(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 36)), Color(rc, 0.13), 17)
	var side = minf(r.size.y - 26, 168.0)
	var art_r = Rect2(r.position + Vector2(14, (r.size.y - side) * 0.5), Vector2(side, side))
	card_art(art_r, info, rc)
	var tx = art_r.end.x + 18
	var tw = r.end.x - tx - 16
	var rl = str(info.get("rarlabel", RARITY[rar])) if not bool(info.get("cursed", false)) else "CURSED"
	var cw = bold.get_string_size(rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24
	rbox(Rect2(r.end.x - cw - 12, r.position.y + 12, cw, 26), rc, 13)
	txt(rl, Vector2(r.end.x - 12 - cw * 0.5, r.position.y + 31), 15, Color("0b1224"), 1, bold)
	var title = str(info["title"]).to_upper()
	txt(title, Vector2(tx, r.position.y + 42), fit(title, tw - cw - 8, 30, bold, 16), Color.WHITE, 0, bold, 3)
	txt(str(info["cat"]).to_upper(), Vector2(tx, r.position.y + 66), 16, rc.lerp(Color.WHITE, 0.25), 0, bold)
	var stack = str(info.get("stack", ""))
	var lines = maxi(1, mini(4, int((r.size.y - 112 - (24 if stack != "" else 0)) / 24.0)))
	var y = wrap_text(str(info["desc"]), tx, r.position.y + 94, tw, 20, Color("dbe4f5"), 24, body, false, lines)
	if stack != "":
		txt(stack, Vector2(tx, minf(y + 4, r.end.y - 38)), fit(stack, tw, 18, bold, 12), Color("7dff9a"), 0, bold, 3)
	var foot = str(info.get("foot", ""))
	if foot != "":
		var is_new = foot == "NEW"
		txt(foot + ("!" if is_new else ""), Vector2(r.end.x - 16, r.end.y - 14), fit(foot, tw, 17), Color("7dff9a") if is_new else Color("ffd24d"), 2, bold, 3)

func paint_portrait_offers() -> void:
	var h = g.ui_height
	dim(minf(0.86, g.offer_t * 4.0))
	var chest = g.offer_mode == "chest"
	var pop = 1.0 + maxf(0.0, 0.3 - g.offer_t) * 2.0
	txt("TREASURE!" if chest else "LEVEL UP!", Vector2(360, 118), int(66 * pop), Color("ffd24d") if chest else Color("d6a8ff"), 1, bold, 8)
	txt("A FREE CARD  ·  CHOOSE ONE" if chest else "LEVEL %d  ·  CHOOSE ONE" % g.level, Vector2(360, 160), 22, Color.WHITE, 1, bold, 3)
	var n = maxi(1, g.offers.size())
	var top = 196.0
	var bottom = h - 200.0
	var row_h = minf(250.0, (bottom - top - (n - 1) * 22.0) / n)
	var y0 = top + maxf(0.0, (bottom - top - n * row_h - (n - 1) * 22.0) * 0.5)
	for i in range(g.offers.size()):
		var appear = clampf((g.offer_t - i * 0.08) * 4.0, 0.0, 1.0)
		var eased = 1.0 - pow(1.0 - appear, 3.0)
		var r = Rect2(24 + (1.0 - eased) * 720.0, y0 + i * (row_h + 22.0), 672, row_h)
		portrait_offer_row(r, offer_info(g.offers[i]), eased)
		if appear >= 1.0:
			buttons.append({"rect": r, "action": "offer%d" % i})
	button(Rect2(24, h - 166, 236, 82), "REROLL (%d)" % g.rerolls, "reroll", false, 26, g.rerolls > 0)
	button(Rect2(274, h - 166, 172, 82), "BUILD", "toggle_peek", false, 26)
	button(Rect2(460, h - 166, 236, 82), "SKIP +%d G" % g.skip_gold(), "skip", false, 24)

func paint_portrait_replace() -> void:
	var h = g.ui_height
	dim(0.88)
	txt("HANDS FULL!", Vector2(360, 110), 58, Color("ffd24d"), 1, bold, 6)
	txt("DROP A GUN FOR THE NEW ONE", Vector2(360, 150), 21, Color.WHITE, 1, bold, 3)
	var card_h = minf(240.0, h - 560.0)
	portrait_offer_row(Rect2(24, 180, 672, card_h), offer_info({"type": "gun_new", "gun": g.replace_gun, "tier": g.replace_tier}))
	for i in range(g.guns.size()):
		button(Rect2(80, 220 + card_h + i * 100, 560, 82), "DROP %s" % Weapons.display_name(g, g.guns[i]).to_upper(), "slot%d" % i, false, 26)
	button(Rect2(150, h - 160, 420, 86), "KEEP MINE", "keep", true, 32)

# ---------------------------------------------------------------- arsenal
func paint_portrait_arsenal() -> void:
	var h = g.ui_height
	dim(0.92)
	txt("ARSENAL", Vector2(360, 82), 56, Color.WHITE, 1, bold, 6)
	var y = 108.0
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var tier = clampi(int(w.get("tier", 0)), 0, 5)
		var r = Rect2(24, y, 672, 112)
		rbox(r, PANEL, 18, RCOL[tier], 3)
		var t = g.tex("res://assets/weapons/%s.png" % w["id"])
		if t != null:
			draw_texture_rect(t, Rect2(r.position + Vector2(12, 10), Vector2(92, 92)), false)
		var name = Weapons.display_name(g, w).to_upper()
		txt(name, r.position + Vector2(118, 40), fit(name, 360, 27), Color.WHITE, 0, bold, 3)
		var cw = bold.get_string_size(RARITY[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
		rbox(Rect2(r.end.x - cw - 12, r.position.y + 12, cw, 26), RCOL[tier], 13)
		txt(RARITY[tier], Vector2(r.end.x - 12 - cw * 0.5, r.position.y + 31), 15, Color("0b1224"), 1, bold)
		for s in range(5):
			draw_colored_polygon(star(r.position + Vector2(128 + s * 20, 62), 8.0), Color("ffd24d") if s < int(w["lvl"]) else Color(0.3, 0.3, 0.4))
		txt("%d DMG  ·  %.1f/s%s" % [roundi(Weapons.shot_damage(g, w)), Weapons.fire_rate(g, w), "  ·  EVOLVED" if bool(w["evolved"]) else ""], r.position + Vector2(118, 98), 19, Color("b8c8dc"), 0, body)
		y += 124
	# key stats, two columns
	var rows = arsenal_rows()
	var col_n = ceili(rows.size() / 2.0)
	var sr = Rect2(24, y, 672, col_n * 30 + 22)
	rbox(sr, PANEL, 18, PANEL_EDGE, 2)
	for i in range(rows.size()):
		var cx = 40.0 + int(i / col_n) * 336.0
		var cy = y + 34 + (i % col_n) * 30
		txt(rows[i][0], Vector2(cx, cy), 17, Color("9fb0c8"), 0, body)
		txt(rows[i][1], Vector2(cx + 300, cy), 18, Color.WHITE, 2, bold)
	y += sr.size.y + 18
	# cards
	txt("CARDS  (%d)" % g.owned_order.size(), Vector2(30, y + 20), 24, Color("ffd24d"), 0, bold, 3)
	y += 34
	var cols = 6
	for i in range(g.owned_order.size()):
		var id = g.owned_order[i]
		var cr = Rect2(24 + (i % cols) * 113, y + int(i / cols) * 92, 104, 84)
		if cr.end.y > h - 130:
			txt("+%d more" % (g.owned_order.size() - i), Vector2(360, h - 112), 18, MUTED, 1, bold)
			break
		card_tile(cr, id)
		if int(g.owned[id]) > 1:
			txt("x%d" % int(g.owned[id]), cr.position + Vector2(cr.size.x - 6, 22), 18, Color("ffd24d"), 2, bold, 4)
		buttons.append({"rect": cr, "action": "inspect_card_" + id})
	if g.state == "levelup":
		button(Rect2(150, h - 110, 420, 82), "BACK TO CARDS", "toggle_peek", true, 30)
	else:
		button(Rect2(190, h - 110, 340, 82), "BACK", "arsenal_close", true, 32)
	if inspected_card_id != "" and g.card_by_id.has(inspected_card_id):
		buttons.clear()
		dim(0.7)
		portrait_offer_row(Rect2(24, h * 0.5 - 130, 672, 240), offer_info({"type": "card", "id": inspected_card_id, "owned_view": true}))
		txt("TAP ANYWHERE TO CLOSE", Vector2(360, h * 0.5 + 160), 20, MUTED, 1, bold)
		buttons.append({"rect": Rect2(0, 0, 720, h), "action": "close_inspect"})

func arsenal_rows() -> Array:
	return [
		["Damage", "%+d%%" % roundi((g.dmg_pool() - 1.0) * 100)], ["Total damage", "x%.2f" % g.more_mult()],
		["Fire rate", "%+d%%" % roundi(g.st("rate") * 100)], ["Projectiles", "+%d" % int(g.st("mult"))],
		["Pierce", "+%d" % int(g.st("pierce"))], ["Crit", "%d%%  x%.1f" % [roundi((0.05 + g.st("crit")) * 100), 2.0 + g.st("critdmg")]],
		["Move speed", "%+d%%" % roundi(g.st("speed") * 100)], ["Armor / Regen", "%d / %.1f" % [int(g.st("armor")), g.st("regen")]],
		["Luck", "%d" % int(g.st("luck"))], ["Epic+ odds", "%.1f%%" % epic_plus_odds()],
		["Health", "%d / %d" % [ceili(float(g.hero["hp"])), ceili(float(g.hero["maxhp"]))]], ["Gold", "%d" % g.gold],
	]

# ---------------------------------------------------------------- settings / collection / results
func paint_portrait_settings() -> void:
	if g.settings_back == "menu":
		portrait_bg()
	else:
		dim(0.92)
	txt("SETTINGS", Vector2(360, 100), 60, Color.WHITE, 1, bold, 6)
	var rows = [
		["SOUND", "%d%%" % roundi(float(g.settings["sfx"]) * 100), "sfx"],
		["MUSIC", "%d%%" % roundi(float(g.settings["music"]) * 100), "music"],
		["SENSITIVITY", "%d%%" % roundi(float(g.settings["sensitivity"]) * 100), "sensitivity"],
		["CURSOR", cursor_label(), "cursor"],
		["TOUCH", str(g.settings["touch"]).to_upper(), "touch"],
		["AIM", "AUTO" if g.settings["aim"] == "auto" else "MANUAL", "aim"],
		["AUTO FIRE", "ON" if g.settings["autofire"] else "OFF", "autofire"],
		["SHAKE", "OFF" if float(g.settings["shake"]) == 0.0 else "ON", "shake"],
		["NUMBERS", "ON" if g.settings["numbers"] else "OFF", "numbers"],
		["PARTICLES", "ON" if g.settings["particles"] else "OFF", "particles"],
		["HINTS", "ON" if g.settings["hints"] else "OFF", "hints"],
	]
	var row_step = minf(96.0, (g.ui_height - 300.0) / rows.size())
	for i in range(rows.size()):
		var y = 140 + i * row_step
		var r = Rect2(36, y, 648, row_step - 12)
		rbox(r, PANEL, 18, PANEL_EDGE, 2)
		var mid = y + (row_step - 12) * 0.5
		txt(rows[i][0], Vector2(62, mid + 9), 26, Color.WHITE, 0, bold, 2)
		if rows[i][2] in ["sfx", "music", "sensitivity"]:
			txt(rows[i][1], Vector2(400, mid + 9), 24, Color("ffd24d"), 2, bold)
			button(Rect2(430, y + 8, 100, row_step - 30), "-", "set_%s_down" % rows[i][2], false, 34)
			button(Rect2(546, y + 8, 100, row_step - 30), "+", "set_%s_up" % rows[i][2], false, 34)
		else:
			var on = rows[i][1] in ["ON", "AUTO"]
			var pill = Rect2(500, mid - 20, 160, 40)
			rbox(pill, Color("2fbf71") if on else Color("3a4256"), 20)
			txt(rows[i][1], pill.get_center() + Vector2(0, 9), 22, Color.WHITE, 1, bold, 2)
			buttons.append({"rect": r, "action": "set_" + rows[i][2]})
	button(Rect2(190, g.ui_height - 130, 340, 84), "BACK", "back", true, 32)

func portrait_collection_cat(delta: int) -> void:
	var cats = g.categories.keys()
	cats.append("weapons")
	cats.append("mobs")
	var idx = cats.find(collection_cat)
	collection_cat = str(cats[posmod(idx + delta, cats.size())])
	collection_page = 0
	selected_collection_item = null

func paint_portrait_collection() -> void:
	var h = g.ui_height
	portrait_bg()
	txt("COLLECTION", Vector2(360, 92), 56, Color.WHITE, 1, bold, 6)
	button(Rect2(28, 124, 96, 72), "<", "mobile_cat_prev", false, 34)
	var cat_label = {"weapons": "GUNS", "mobs": "MONSTERS"}.get(collection_cat, str(g.categories.get(collection_cat, "")).to_upper())
	rbox(Rect2(140, 128, 440, 62), Color(0, 0, 0, 0.5), 31)
	txt(cat_label, Vector2(360, 170), fit(cat_label, 420, 28), Color("ffd24d"), 1, bold, 3)
	button(Rect2(596, 124, 96, 72), ">", "mobile_cat_next", false, 34)
	var items = get_collection_items()
	var row_h = 160.0
	var per_page = clampi(int((h - 420.0) / (row_h + 14.0)), 2, 8)
	var pages = maxi(1, ceili(float(items.size()) / per_page))
	collection_page = clampi(collection_page, 0, pages - 1)
	for i in range(per_page):
		var idx = collection_page * per_page + i
		if idx >= items.size():
			break
		var r = Rect2(24, 222 + i * (row_h + 14.0), 672, row_h)
		portrait_offer_row(r, collection_info(items[idx]))
		buttons.append({"rect": r, "action": "select_card_%d" % idx})
	if selected_collection_item != null:
		var info = collection_info(selected_collection_item)
		buttons.clear()
		dim(0.9)
		var detail_h = minf(640.0, h - 420.0)
		draw_card(Rect2(100, 130, 520, detail_h), info, false, 1.0, -1)
		if selected_collection_item["type"] == "gun_new":
			var gun = g.weapon_db[selected_collection_item["gun"]]
			wrap_text("LV3: " + str(gun["lv3"]), 70, 130 + detail_h + 40, 580, 21, Color("ffd24d"), 26, body, true, 2)
			wrap_text("LV5: " + str(gun["lv5"]), 70, 130 + detail_h + 100, 580, 21, Color("ffd24d"), 26, body, true, 2)
		button(Rect2(190, h - 130, 340, 84), "CLOSE", "mobile_close_detail", true, 32)
		return
	button(Rect2(150, h - 214, 110, 72), "<", "page-1", false, 34, collection_page > 0)
	txt("%d / %d" % [collection_page + 1, pages], Vector2(360, h - 166), 26, Color.WHITE, 1, bold, 3)
	button(Rect2(460, h - 214, 110, 72), ">", "page1", false, 34, collection_page < pages - 1)
	button(Rect2(190, h - 120, 340, 84), "BACK", "back", true, 32)

func paint_portrait_result() -> void:
	var h = g.ui_height
	portrait_bg()
	var won = g.state == "victory"
	txt("YOU WON!" if won else "FLATLINED", Vector2(360, h * 0.17), 84, Color("ffd24d") if won else Color("ff4d6a"), 1, bold, 9)
	var sub = "sector %d cleared" % g.WIN_SECTOR if won else "killed by " + g.last_hit_by
	txt(sub.to_upper(), Vector2(360, h * 0.17 + 48), fit(sub.to_upper(), 640, 22), Color.WHITE, 1, bold, 3)
	var stats = [["SECTOR", str(g.sector)], ["LEVEL", str(g.level)], ["KILLS", str(g.kills)],
		["COMBO", "x%d" % g.best_combo], ["TIME", "%d:%02d" % [int(g.run_time) / 60, int(g.run_time) % 60]], ["CARDS", str(g.owned_order.size())]]
	var sy = h * 0.17 + 90
	rbox(Rect2(40, sy, 640, 230), PANEL, 20, PANEL_EDGE, 2)
	for i in range(stats.size()):
		var c = Vector2(147 + (i % 3) * 213, sy + 74 + int(i / 3) * 110)
		txt(stats[i][1], c, fit(stats[i][1], 190, 44), Color("ffd24d"), 1, bold, 4)
		txt(stats[i][0], c + Vector2(0, 30), 17, Color("9fb0c8"), 1, bold)
	var n = mini(g.owned_order.size(), 12)
	for i in range(n):
		var cr = Rect2(360 - mini(n, 6) * 54 + (i % 6) * 108, sy + 252 + int(i / 6) * 86, 100, 78)
		card_tile(cr, g.owned_order[i])
	var aw = award_line()
	if aw != "":
		rbox(Rect2(40, h - 352, 640, 56), Color("3a2468"), 28)
		txt(aw, Vector2(360, h - 315), fit(aw, 610, 22), Color("e2d4ff"), 1, bold, 3)
	button(Rect2(130, h - 270, 460, 100), "CONTINUE" if won else "RUN IT BACK", "continue_run" if won else ("play_hard" if g.hard_mode else "play"), true, 40)
	button(Rect2(180, h - 146, 360, 80), "MAIN MENU", "menu", false, 28)
	if not won:
		result_lock()

# ================================================================= HUD
func paint_hud() -> void:
	if g.hero.is_empty():
		return
	paint_unlock_toast(640, 150)
	if g.dying_t > 0.0:
		paint_dying()
	var h = g.hero
	# --- health
	var ratio = clampf(float(h["hp"]) / float(h["maxhp"]), 0.0, 1.0)
	hp_trail = lerpf(hp_trail, ratio, 0.04) if hp_trail > ratio else ratio
	slant(Rect2(18, 16, 330, 34), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 12)
	slant(Rect2(22, 20, 322 * hp_trail, 26), Color("ffffff"), Color(0, 0, 0, 0), 10)
	var hpc = Color("ff4d6a") if ratio > 0.35 else Color("ff4d6a").lerp(Color.WHITE, 0.5 + 0.5 * sin(g.anim_t * 12.0))
	slant(Rect2(22, 20, maxf(12.0, 322 * ratio), 26), hpc, Color(0, 0, 0, 0), 10)
	txt("%d / %d" % [ceili(float(h["hp"])), int(h["maxhp"])], Vector2(36, 42), 20, Color.WHITE, 0, bold, 4)
	# shields + dashes
	var x = 26.0
	for i in range(int(h["shield"])):
		draw_circle(Vector2(x + 8, 64), 8, Color("8ff8ff"))
		draw_circle(Vector2(x + 8, 64), 5, Color("2a6a80"))
		x += 20
	var charges = 1 + int(g.st("dashes"))
	for i in range(charges):
		var full = i < int(h["dash_charges"])
		var r = Rect2(x + 6 + i * 26, 56, 22, 14)
		slant(r, Color("4fe0ff") if full else Color(0.2, 0.3, 0.4, 0.8), Color(0, 0, 0, 0), 5)
		if not full and i == int(h["dash_charges"]):
			slant(Rect2(r.position, Vector2(r.size.x * float(h["dash_cd"]) / 1.5, r.size.y)), Color("2a8aa0"), Color(0, 0, 0, 0), 5)
	txt("DASH", Vector2(x + 10 + charges * 26, 69), 13, Color("9fb8d0"), 0, bold, 3)
	# --- sector + kill progress (no finish line: kill the whole crowd)
	txt("SECTOR %d" % g.sector, Vector2(640, 36), 28, Color.WHITE, 1, bold, 5)
	var pw = 360.0
	var px = 640.0 - pw * 0.5
	var prog = g.progress() if g.phase == "fight" else 1.0
	rbox(Rect2(px, 44, pw, 12), Color(0, 0, 0, 0.6), 6)
	rbox(Rect2(px, 44, maxf(12.0, pw * prog), 12), Color("4fe0ff"), 6)
	if g.phase == "fight":
		var left = g.enemies_left()
		var lt = "BOSS INCOMING" if g.is_boss_sector() and not g.boss_spawned and prog > 0.6 else ("%d ENEMIES LEFT" % left if left > 0 else "FINISH THEM")
		txt(lt, Vector2(640, 76), 16, Color("ffd24d") if left < 15 else Color("c8d8eb"), 1, bold, 3)
	# --- gold, kills, time, pause
	var gx = 1205.0
	txt("%d" % g.gold, Vector2(gx, 40), 28, Color("ffd24d"), 2, bold, 5)
	var gw = bold.get_string_size("%d" % g.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_circle(Vector2(gx - gw - 16, 30), 10, Color("b8860b"))
	draw_circle(Vector2(gx - gw - 16, 30), 7.5, Color("ffd24d"))
	txt("%d KILLS   %d:%02d" % [g.kills, int(g.run_time) / 60, int(g.run_time) % 60], Vector2(gx, 64), 16, Color("c8d0e0"), 2, bold, 3)
	button(Rect2(1222, 16, 44, 40), "||", "pause", false, 18)
	# --- boss bar
	for e in g.enemies:
		if bool(e["boss"]) and not bool(e["dead"]) and int(e["gen"]) == 0:
			var br = clampf(float(e["hp"]) / float(e["max_hp"]), 0.0, 1.0)
			slant(Rect2(340, 76, 600, 22), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), 8)
			slant(Rect2(343, 79, 594 * br, 16), Color("ff4d6a"), Color(0, 0, 0, 0), 6)
			txt(str(g.enemy_db[e["kind"]]["name"]), Vector2(640, 94), 18, Color.WHITE, 1, bold, 4)
			break
	# --- xp bar
	var xr = clampf(float(g.xp) / float(g.xp_need), 0.0, 1.0)
	draw_rect(Rect2(0, 708, 1280, 12), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(0, 709, 1280 * xr, 10), Color("b48cff"))
	slant(Rect2(14, 682, 84, 30), Color("b48cff"), Color(0, 0, 0, 0), 8)
	txt("LV %d" % g.level, Vector2(56, 705), 22, Color.WHITE, 1, bold, 4)
	# --- weapons
	for i in range(g.guns.size()):
		paint_gun_slot(g.guns[i], i, Vector2(110 + i * 196, 636))
	# --- owned card strip
	var n = g.owned_order.size()
	var shown = mini(n, 12)
	for i in range(shown):
		var id = g.owned_order[n - shown + i]
		var c = g.card_by_id[id]
		var r = Rect2(1262 - (shown - i) * 42, 658, 38, 32)
		mini_tile(r, id)
		if int(g.owned[id]) > 1:
			txt("x%d" % int(g.owned[id]), r.position + Vector2(r.size.x - 2, r.size.y + 1), 13, Color.WHITE, 2, bold, 3)
	if n > 0:
		button(Rect2(1116, 616, 148, 32), "ARSENAL", "open_arsenal", false, 14)
		txt("(%d cards)" % n, Vector2(1262, 656), 13, Color("9fb8d0"), 2, bold, 3)
	# --- combo
	if g.combo >= 8:
		var words = [[8, "NICE"], [20, "SPICY"], [40, "UNHINGED"], [80, "MASSACRE"], [150, "WAR CRIME"], [300, "GOD MODE"]]
		var word = "NICE"
		for wd in words:
			if g.combo >= int(wd[0]):
				word = wd[1]
		var k = clampf(g.combo_t / 2.6, 0.0, 1.0)
		var wob = sin(g.anim_t * 18.0) * 2.0
		txt("x%d" % g.combo, Vector2(1250, 250 + wob), 46, Color("ffd24d").lerp(Color("ff4d6a"), minf(1.0, g.combo / 150.0)), 2, bold, 6)
		txt(word, Vector2(1250, 282), 24, Color.WHITE, 2, bold, 5)
		draw_rect(Rect2(1250 - 140 * k, 292, 140 * k, 5), Color("ffd24d"))
	# --- banner
	if g.banner_t > 0.0:
		var a = clampf(g.banner_t / 0.4, 0.0, 1.0)
		var pop = 1.0 + maxf(0.0, (g.banner_t - 1.6)) * 0.4
		var y = 170.0
		slant(Rect2(300, y - 52, 680, 86), Color(0.02, 0.03, 0.08, 0.7 * a), Color(0, 0, 0, 0), 24)
		txt(g.banner_text, Vector2(640, y), int(46 * minf(pop, 1.3)), Color(1, 1, 1, a), 1, bold, 7)
		if g.banner_sub != "":
			txt(g.banner_sub.to_upper(), Vector2(640, y + 26), 16, Color(1, 0.85, 0.3, a), 1, bold, 3)
	if bool(g.settings["hints"]) and g.run_time < 14.0 and g.sector == 1 and g.state == "playing":
		if g.is_touch_active():
			txt("DRAG LOWER LEFT TO MOVE   ·   TAP DASH TO DODGE   ·   GUNS AUTO-TARGET & FIRE", Vector2(640, 600), 17, Color(1, 1, 1, 0.85), 1, body, 4)
		else:
			txt("WASD move   ·   LEFT CLICK gun 1   ·   RIGHT CLICK gun 2   ·   R reload   ·   SPACE dash   ·   TAB arsenal", Vector2(640, 600), 17, Color(1, 1, 1, 0.85), 1, body, 4)
	if g.is_touch_active() and g.state == "playing":
		paint_touch_controls()

func paint_gun_slot(w: Dictionary, i: int, pos: Vector2) -> void:
	var d = g.weapon_db[w["id"]]
	var r = Rect2(pos, Vector2(186, 64))
	var tier = clampi(int(w.get("tier", 0)), 0, 5)
	slant(r, Color(0.02, 0.03, 0.08, 0.75), RCOL[tier], 10, 2.0)
	var icon = g.tex("res://assets/weapons/%s.png" % w["id"])
	if icon != null:
		draw_texture_rect(icon, Rect2(pos + Vector2(10, 4), Vector2(56, 56)), false)
	else:
		draw_circle(pos + Vector2(38, 32), 22, Color(str(d["color"])))
	txt(Weapons.display_name(g, w).to_upper(), pos + Vector2(72, 24), 16, Color.WHITE, 0, bold, 3)
	txt(RARITY[tier], pos + Vector2(176, 12), 10, RCOL[tier], 2, bold)
	for s in range(5):
		var filled = s < int(w["lvl"])
		draw_colored_polygon(star(pos + Vector2(80 + s * 15, 36), 6.0), Color("ffd24d") if filled else Color(0.3, 0.3, 0.4))
	var bar = Rect2(pos + Vector2(72, 46), Vector2(100, 9))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var kind = str(d["kind"])
	if float(w["reload"]) > 0.0:
		var k = 1.0 - float(w["reload"]) / maxf(0.01, float(w["reload_max"]))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color("ffd24d"))
		txt("RELOAD", bar.position + Vector2(50, 9), 11, Color.WHITE, 1, bold, 2)
	elif kind == "beam":
		var heat = float(w["heat"]) / 3.0
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(heat, 0, 1), bar.size.y)), Color("ff4d6a") if bool(w["over"]) else Color("c58cff"))
		if bool(w["over"]):
			txt("OVERHEAT", bar.position + Vector2(50, 9), 11, Color.WHITE, 1, bold, 2)
	elif kind == "spin" and float(w["spin"]) < 1.0 and float(w["spin"]) > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(w["spin"]), bar.size.y)), Color("ffb84d"))
	else:
		var am = clampf(float(w["ammo"]) / maxf(1.0, float(w["mag_max"])), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * am, bar.size.y)), Color("4fe0ff"))
		if kind != "beam":
			txt("%d" % int(w["ammo"]), bar.position + Vector2(bar.size.x + 4, 9), 12, Color.WHITE, 0, bold, 2)

func paint_touch_controls() -> void:
	var h = g.hero
	if h.is_empty():
		return
	# Floating joystick: full stick where the thumb is, a faint ghost at rest.
	var active: bool = g.stick_touch_id != -1
	var c: Vector2 = g.stick_center if active else g.default_stick()
	var knob: Vector2 = g.stick_knob if active else c
	var a = 1.0 if active else 0.35
	draw_circle(c, 78.0, Color(0.03, 0.06, 0.14, 0.45 * a))
	draw_arc(c, 78.0, 0, TAU, 48, Color(0.31, 0.88, 1.0, 0.55 * a), 3.0)
	if active and g.touch_move_dir.length() > 0.1:
		var ang = g.touch_move_dir.angle()
		draw_arc(c, 78.0, ang - 0.5, ang + 0.5, 16, Color(0.31, 0.88, 1.0, 0.95), 6.0)
	draw_circle(knob + Vector2(0, 4), 34.0, Color(0, 0, 0, 0.3 * a))
	draw_circle(knob, 34.0, Color(0.31, 0.88, 1.0, 0.85 * a))
	draw_circle(knob, 24.0, Color(0.75, 0.97, 1.0, 0.9 * a))
	# Dash button with cooldown ring and charge pips.
	var dp: Vector2 = g.dash_btn_pos
	var dr: float = g.dash_btn_r
	var charges = int(h.get("dash_charges", 0))
	var max_c = 1 + int(g.st("dashes"))
	var ready = charges > 0
	var down = 5.0 if g.dash_pressed else 0.0
	draw_circle(dp + Vector2(0, 8), dr, Color(0, 0, 0, 0.35))
	draw_circle(dp + Vector2(0, 6), dr, Color("7a1f33") if ready else Color("1c2333"))
	draw_circle(dp + Vector2(0, down), dr, Color("ff4d6a") if ready else Color("323b52"))
	draw_circle(dp + Vector2(0, down - dr * 0.25), dr * 0.7, Color(1, 1, 1, 0.12))
	if charges < max_c:
		var cd = clampf(float(h.get("dash_cd", 0.0)) / 1.5, 0.0, 1.0)
		draw_arc(dp + Vector2(0, down), dr + 7.0, -PI * 0.5, -PI * 0.5 + TAU * cd, 40, Color("4fe0ff"), 6.0)
	txt("DASH", dp + Vector2(0, down + 9), 26, Color.WHITE if ready else Color("8590a6"), 1, bold, 3)
	for i in range(max_c):
		var pc = dp + Vector2((i - (max_c - 1) * 0.5) * 18.0, dr + 20.0)
		draw_circle(pc, 6.0, Color("4fe0ff") if i < charges else Color(0.2, 0.3, 0.4, 0.8))

func star(c: Vector2, r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for k in range(10):
		pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * (r if k % 2 == 0 else r * 0.45))
	return pts

# ================================================================= cards
func offer_info(o: Dictionary) -> Dictionary:
	match o["type"]:
		"card":
			var c = g.card_by_id[o["id"]]
			var have = int(g.owned.get(o["id"], 0))
			var owned_view = bool(o.get("owned_view", false))
			var foot = "NEW" if have == 0 else ("OWNED x%d / %d" % [have, int(c["max"])] if owned_view else "x%d » x%d" % [have, have + 1])
			return {"title": c["name"], "desc": c["desc"], "rar": int(c["rarity"]), "cat": g.categories.get(c["cat"], ""),
				"catc": CAT_COLOR, "catid": str(c["cat"]), "art": g.tex("res://assets/cards/%s.png" % o["id"]), "foot": foot,
				"stack": "" if owned_view else Effects.stack_preview(g, str(o["id"])),
				"max": "MAX %d" % int(c["max"]), "cursed": c.get("cursed", false), "icon": false}
		"gun_new":
			var d = g.weapon_db[o["gun"]]
			var tier = int(o.get("tier", 0))
			var tdmg = float(d["dmg"]) * Weapons.TIER_DMG[clampi(tier, 0, 5)]
			var stats = "%d DMG  ·  %.1f/s  ·  MAG %d" % [roundi(tdmg), float(d["rate"]) * Weapons.TIER_RATE[clampi(tier, 0, 5)], int(d["mag"])]
			if d["kind"] == "beam":
				stats = "%d DMG/tick  ·  continuous" % roundi(tdmg)
			return {"title": d["name"], "desc": d["desc"], "rar": tier, "cat": "NEW GUN", "catc": CAT_COLOR,
				"art": g.tex("res://assets/weapons/%s.png" % o["gun"]), "foot": "" if bool(o.get("preview", false)) else stats,
				"rarlabel": "RANDOM TIER" if bool(o.get("preview", false)) else RARITY[tier], "max": "", "icon": true}
		"gun_up":
			var w = g.guns[int(o["slot"])]
			var d2 = g.weapon_db[w["id"]]
			var nl = int(w["lvl"]) + 1
			var desc = "+15% damage, +6% fire rate (adds to your other bonuses)."
			if nl == 3:
				desc += " UNLOCK: " + str(d2["lv3"])
			elif nl == 5:
				desc += " UNLOCK: " + str(d2["lv5"]) + ". Then it can EVOLVE."
			return {"title": Weapons.display_name(g, w) + " +", "desc": desc, "rar": int(w.get("tier", 0)), "cat": "GUN UPGRADE", "catc": CAT_COLOR,
				"art": g.tex("res://assets/weapons/%s.png" % w["id"]), "foot": "LV %d  >  LV %d" % [nl - 1, nl], "max": "", "icon": true}
		"evolve":
			var w2 = g.guns[int(o["slot"])]
			return {"title": "EVOLVE: " + str(Weapons.EVOLVED_NAMES.get(w2["id"], "EX")), "desc": "+30% TOTAL damage, +20% fire rate, +1 projectile, bigger golden shots.",
				"rar": maxi(3, int(w2.get("tier", 0))), "cat": "EVOLUTION", "catc": CAT_COLOR, "art": g.tex("res://assets/weapons/%s.png" % w2["id"]),
				"foot": str(g.weapon_db[w2["id"]]["name"]) + " is ready", "max": "", "icon": true}
	return {}

func stall_info(st: Dictionary) -> Dictionary:
	match st["kind"]:
		"heal":
			return {"title": "Hot Soup", "desc": "Heal 40% of your max HP.", "rar": 0, "cat": "HEAL", "catid": "heal", "catc": Color("7dff9a"), "art": null, "foot": "", "max": "", "icon": true}
		"maxhp":
			return {"title": "Protein Shake", "desc": "+12 max HP and heal 25.", "rar": 1, "cat": "HEAL", "catid": "heal", "catc": Color("7dff9a"), "art": null, "foot": "", "max": "", "icon": true}
		"reroll":
			return {"title": "Restock", "desc": "Reroll every stall. Price goes up each time.", "rar": 0, "cat": "SHOP", "catid": "shop", "catc": Color("ffd24d"), "art": null, "foot": "", "max": "", "icon": true}
	return offer_info(st["offer"])

func draw_card(r: Rect2, info: Dictionary, hover: bool, appear: float, index: int) -> void:
	if info.is_empty():
		return
	var rar = clampi(int(info["rar"]), 0, 5)
	var rc: Color = RCOL[rar]
	if bool(info.get("cursed", false)):
		rc = Color("ff3a4a")
	if rar >= 2 or hover:
		var gl = (0.22 if rar >= 2 else 0.12) * (0.7 + 0.3 * sin(g.anim_t * 4.0))
		for k in range(3):
			rbox(r.grow(5 + k * 5), Color(rc, gl * (1.0 - k / 3.0) * appear), 22 + k * 5)
	rbox(Rect2(r.position + Vector2(0, 9), r.size), Color(0, 0, 0, 0.5 * appear), 20)
	rbox(r, PANEL, 20, rc, 4 if hover else 3)
	# header band in rarity colour
	rbox(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 34)), Color(rc, 0.18), 16)
	txt(str(info["cat"]).to_upper(), r.position + Vector2(18, 28), fit(str(info["cat"]).to_upper(), r.size.x - 70, 16), rc.lerp(Color.WHITE, 0.3), 0, bold)
	if index >= 0:
		cbox(Rect2(r.position + Vector2(r.size.x - 39, 7), Vector2(30, 30)), Color("06080d"), 7, rc, 2)
		txt(str(index + 1), r.position + Vector2(r.size.x - 24, 30), 20, Color.WHITE, 1, bold)
	# art (or the category icon painted on the card)
	var art_r = Rect2(r.position + Vector2(12, 46), Vector2(r.size.x - 24, r.size.y * 0.4))
	card_art(art_r, info, rc)
	# title + desc
	var ty = art_r.end.y + 34
	var title = str(info["title"]).to_upper()
	txt(title, Vector2(r.get_center().x, ty), fit(title, r.size.x - 24, 26, bold, 14), Color.WHITE, 1, bold, 4)
	var stack = str(info.get("stack", ""))
	var lines = maxi(2, int((r.end.y - 44 - (ty + 26) - (22 if stack != "" else 0)) / 20.0))
	var y = wrap_text(str(info["desc"]), r.position.x + 16, ty + 26, r.size.x - 32, 16, Color("dbe4f5"), 20, body, true, lines)
	if stack != "":
		txt(stack, Vector2(r.get_center().x, minf(y + 4, r.end.y - 40)), fit(stack, r.size.x - 24, 15, bold, 10), Color("7dff9a"), 1, bold, 3)
	# footer: rarity chip + owned/new
	var rl = str(info.get("rarlabel", RARITY[rar])) if not bool(info.get("cursed", false)) else "CURSED"
	var cw = bold.get_string_size(rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20
	rbox(Rect2(r.position.x + 12, r.end.y - 36, cw, 24), rc, 12)
	txt(rl, Vector2(r.position.x + 12 + cw * 0.5, r.end.y - 19), 14, Color("0b1224"), 1, bold)
	var foot = str(info.get("foot", ""))
	if foot != "":
		var is_new = foot == "NEW"
		txt(foot + ("!" if is_new else ""), Vector2(r.end.x - 14, r.end.y - 17), fit(foot, r.size.x - cw - 40, 15, bold, 10), Color("7dff9a") if is_new else Color("ffd24d"), 2, bold, 3)

func paint_levelup() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, minf(0.78, g.offer_t * 3.0)))
	var chest = g.offer_mode == "chest"
	var head = "TREASURE!" if chest else "LEVEL UP!"
	var hc = Color("ffd24d") if chest else Color("d6a8ff")
	var pop = 1.0 + maxf(0.0, 0.3 - g.offer_t) * 2.0
	var wob = sin(g.anim_t * 3.0) * 3.0
	txt(head, Vector2(640, 96 + wob), int(64 * pop), hc, 1, bold, 8)
	txt("LEVEL %d  ·  PICK ONE" % g.level if not chest else "A FREE CARD. PICK ONE", Vector2(640, 128), 20, Color.WHITE, 1, bold, 4)
	var n = g.offers.size()
	var cw = 250.0 if n <= 3 else 230.0
	var gap = 24.0
	var total = n * cw + (n - 1) * gap
	for i in range(n):
		var appear = clampf((g.offer_t - i * 0.08) * 4.0, 0.0, 1.0)
		var eased = 1.0 - pow(1.0 - appear, 3.0)
		var r = Rect2(640 - total * 0.5 + i * (cw + gap), 160 + (1.0 - eased) * 400.0, cw, 400)
		var hover = r.has_point(g.mouse_screen) and appear >= 1.0
		if hover and g.mouse_moved_t < 0.3:
			g.offer_sel = i
		hover = hover or (i == g.offer_sel and appear >= 1.0)
		if hover:
			r.position.y -= 14
		draw_card(r, offer_info(g.offers[i]), hover, eased, i)
		if appear >= 1.0:
			buttons.append({"rect": r, "action": "offer%d" % i})
	button(Rect2(130, 608, 220, 52), "HIDE BUILD" if peek else "PEEK BUILD", "toggle_peek", false, 20)
	button(Rect2(390, 608, 230, 52), "REROLL (%d)" % g.rerolls, "reroll", false, 22, g.rerolls > 0)
	button(Rect2(660, 608, 230, 52), "SKIP  +%d G" % g.skip_gold(), "skip", false, 22)
	txt("Tap card to pick   ·   R reroll   ·   X skip" if g.is_touch_active() else "1-%d pick   ·   R reroll   ·   X skip   ·   TAB peek at your build" % n, Vector2(640, 690), 15, Color("9fb8d0"), 1, body, 3)

func paint_replace() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.8))
	txt("YOUR HANDS ARE FULL", Vector2(640, 90), 48, Color("ffd24d"), 1, bold, 7)
	txt("drop a gun for the new one", Vector2(640, 122), 18, Color.WHITE, 1, bold, 4)
	draw_card(Rect2(515, 150, 250, 380), offer_info({"type": "gun_new", "gun": g.replace_gun, "tier": g.replace_tier}), false, 1.0, -1)
	for i in range(g.guns.size()):
		var w = g.guns[i]
		button(Rect2(140 + i * 360 if g.guns.size() > 2 else (200 + i * 640), 560, 300, 56), "DROP %s [%d]" % [Weapons.display_name(g, w).to_upper(), i + 1], "slot%d" % i, false, 20)
	button(Rect2(540, 640, 200, 50), "KEEP MINE", "keep", true, 20)

# ================================================================= arsenal
func paint_arsenal() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.88))
	txt("ARSENAL", Vector2(640, 64), 48, Color.WHITE, 1, bold, 7)
	# guns
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var d = g.weapon_db[w["id"]]
		var r = Rect2(30, 100 + i * 182, 360, 172)
		var tier = clampi(int(w.get("tier", 0)), 0, 5)
		panel(r, Color("10162a"), RCOL[tier])
		var icon = g.tex("res://assets/weapons/%s.png" % w["id"])
		if icon != null:
			draw_texture_rect(icon, Rect2(r.position + Vector2(8, 8), Vector2(84, 84)), false)
		txt(Weapons.display_name(g, w).to_upper(), r.position + Vector2(100, 30), 22, Color.WHITE, 0, bold, 3)
		txt(RARITY[tier], r.position + Vector2(350, 20), 12, RCOL[tier], 2, bold)
		for s in range(5):
			draw_colored_polygon(star(r.position + Vector2(108 + s * 18, 46), 7.0), Color("ffd24d") if s < int(w["lvl"]) else Color(0.3, 0.3, 0.4))
		txt("%d dmg  ·  %.1f/s" % [roundi(Weapons.shot_damage(g, w)), Weapons.fire_rate(g, w)], r.position + Vector2(100, 76), 15, Color("c8d0e0"), 0, body)
		var dy = wrap_text(str(d["desc"]), r.position.x + 12, r.position.y + 102, 336, 13, Color("9fb0c8"), 16, body, false, 2)
		var perks = ""
		if int(w["lvl"]) >= 3:
			perks += "LV3: " + str(d["lv3"]) + "   "
		if int(w["lvl"]) >= 5:
			perks += "LV5: " + str(d["lv5"])
		if perks != "":
			wrap_text(perks, r.position.x + 12, dy + 2, 336, 12, Color("ffd24d"), 14, body, false, 2)
	# cards grid
	var gx = 410.0
	var gy = 100.0
	var cols = 8
	txt("CARDS  (%d)" % g.owned_order.size(), Vector2(gx, gy - 6), 20, Color("9fb8d0"), 0, bold, 3)
	for i in range(g.owned_order.size()):
		var id = g.owned_order[i]
		var c = g.card_by_id[id]
		var r2 = Rect2(gx + (i % cols) * 66, gy + 6 + int(i / cols) * 56, 62, 52)
		if r2.end.y > 700:
			break
		card_tile(r2, id)
		if int(g.owned[id]) > 1:
			txt("x%d" % int(g.owned[id]), r2.end + Vector2(-2, -2), 15, Color.WHITE, 2, bold, 3)
		buttons.append({"rect": r2, "action": "inspect_card_" + id})
		if r2.has_point(g.mouse_screen):
			hover_card = {"type": "card", "id": id}
	# stats
	var sx = 950.0
	panel(Rect2(sx, 100, 300, 590), Color("10162a"), Color("3a4a70"))
	txt("STATS", Vector2(sx + 150, 130), 22, Color.WHITE, 1, bold, 3)
	var rows = [
		["Damage", "%+d%%" % roundi((g.dmg_pool() - 1.0) * 100)], ["Total damage", "x%.2f" % g.more_mult()], ["Fire rate", "%+d%%" % roundi(g.st("rate") * 100)],
		["Projectiles", "+%d" % int(g.st("mult"))], ["Parallel", "+%d" % int(g.st("par"))], ["Back / Side", "%d / %d" % [int(g.st("rear")), int(g.st("side"))]],
		["Burst / Echo", "%d / %d" % [int(g.st("burst")), int(g.st("echo"))]], ["Pierce", "+%d" % int(g.st("pierce"))],
		["Ricochet / Bounce", "%d / %d" % [int(g.st("rico")), int(g.st("bounce"))]], ["Fragments", "%d hit / %d kill" % [int(g.st("split")), int(g.st("splitkill"))]],
		["Crit", "%d%%  x%.1f" % [roundi((0.05 + g.st("crit")) * 100), 2.0 + g.st("critdmg")]],
		["Blades / Drones", "%d / %d" % [int(g.st("orbit")), int(g.st("drone"))]], ["Move speed", "%+d%%" % roundi(g.st("speed") * 100)],
		["Armor / Regen", "%d / %.1f" % [int(g.st("armor")), g.st("regen")]], ["Shields", "%d" % int(g.st("shield"))],
		["Luck / Epic+ odds", "%d / %.1f%%" % [int(g.st("luck")), epic_plus_odds()]], ["Magnet", "+%d%%" % roundi(g.st("magnet") * 100)],
		["Burn/Ice/Shock/Psn", "%d/%d/%d/%d%%" % [roundi(g.st("burn") * 100), roundi(g.st("freeze") * 100), roundi(g.st("shock") * 100), roundi(g.st("poison") * 100)]],
		["Health", "%d / %d" % [ceili(float(g.hero["hp"])), ceili(float(g.hero["maxhp"]))]],
	]
	var row_h = minf(25.0, 540.0 / rows.size())
	for i in range(rows.size()):
		txt(rows[i][0], Vector2(sx + 16, 166 + i * row_h), 15, Color("9fb0c8"), 0, body)
		txt(rows[i][1], Vector2(sx + 284, 166 + i * row_h), fit(rows[i][1], 120, 16), Color.WHITE, 2, bold)
	if inspected_card_id != "" and g.card_by_id.has(inspected_card_id):
		hover_card = {"type": "card", "id": inspected_card_id}
	if hover_card != null:
		var mp: Vector2 = g.mouse_screen
		if inspected_card_id != "":
			mp = Vector2(480, 260)
		draw_card(Rect2(clampf(mp.x + 16, 0, 1020), clampf(mp.y - 150, 10, 300), 250, 390), offer_info(hover_card), true, 1.0, -1)
	if g.state == "arsenal":
		button(Rect2(540, 650, 200, 50), "BACK", "arsenal_close", true, 22)

# ================================================================= menus
func paint_menu_bg() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("07080f"))
	var art = g.tex("res://assets/ui/title.png")
	if art != null:
		var drift = sin(g.anim_t * 0.2) * 12.0
		draw_texture_rect(art, Rect2(-20 + drift, -12, 1320, 744), false, Color(0.6, 0.6, 0.7))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.35))
	# A conga line of blobs running across the bottom.
	for i in range(9):
		var x = fposmod(g.anim_t * 120.0 + i * 160.0, 1440.0) - 80.0
		var y = 676.0 - absf(sin(g.anim_t * 8.0 + i)) * 10.0
		var c = [Color("ff7b93"), Color("ffb36b"), Color("7dffcf"), Color("ff5a4a")][i % 4]
		draw_circle(Vector2(x, y), 16, c.darkened(0.4))
		draw_circle(Vector2(x, y - 1), 14, c)
		draw_circle(Vector2(x - 5, y - 4), 5, Color.WHITE)
		draw_circle(Vector2(x + 5, y - 4), 5, Color.WHITE)
		draw_circle(Vector2(x - 3, y - 4), 2.5, Color.BLACK)
		draw_circle(Vector2(x + 7, y - 4), 2.5, Color.BLACK)

func paint_menu() -> void:
	paint_menu_bg()
	panel(Rect2(380, 70, 520, 568), Color(0.025, 0.045, 0.09, 0.92), Color("304868"), 2)
	glitch_txt("SLIME HOUR", Vector2(640, 172), 92, Color.WHITE)
	txt("//  D O N ' T   S T O P   S H O O T I N G  //", Vector2(640, 212), 20, NEON, 1, body)
	profile_bar(Vector2(640, 262), 380.0)
	button(Rect2(450, 290, 380, 70), "PLAY", "play", true, 34)
	button(Rect2(450, 376, 185, 56), "HARD MODE", "play_hard", false, 22)
	button(Rect2(645, 376, 185, 56), "UPGRADES", "upgrades", false, 22)
	button(Rect2(450, 448, 185, 56), "COLLECTION", "collection", false, 22)
	button(Rect2(645, 448, 185, 56), "SETTINGS", "settings", false, 22)
	button(Rect2(548, 520, 185, 50), "QUIT", "quit", false, 20)
	goo_chip(Vector2(640, 588))
	txt("BEST  SECTOR %d   /   %d KILLS   /   LV %d" % [g.best["sector"], g.best["kills"], g.best["level"]], Vector2(640, 628), 16, MUTED, 1, body)

func paint_pause() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.75))
	txt("PAUSED", Vector2(640, 200), 80, Color.WHITE, 1, bold, 10)
	button(Rect2(500, 260, 280, 62), "RESUME", "resume", true, 30)
	button(Rect2(500, 336, 280, 54), "SETTINGS", "settings", false, 24)
	button(Rect2(500, 402, 280, 54), "MAIN MENU", "menu", false, 24)

func cursor_label() -> String:
	var c = float(g.settings["cursor"])
	return "S" if c < 0.9 else ("M" if c < 1.2 else ("L" if c < 1.6 else "XL"))

func paint_settings() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.8))
	txt("SETTINGS", Vector2(640, 105), 60, Color.WHITE, 1, bold, 8)
	var s = g.settings
	var rows = [
		["SOUND", "%d%%" % roundi(float(s["sfx"]) * 100), "sfx"],
		["MUSIC", "%d%%" % roundi(float(s["music"]) * 100), "music"],
		["SENSITIVITY", "%d%%" % roundi(float(s["sensitivity"]) * 100), "sensitivity"],
		["CURSOR SIZE", cursor_label(), "cursor"],
		["TOUCH CONTROLS", ("AUTO" if s.get("touch", "auto") == "auto" else str(s["touch"]).to_upper()) if OS.has_feature("mobile") else "OFF (DESKTOP)", "touch"],
		["AIM", "AUTO-TARGET" if s["aim"] == "auto" else ("TOUCH" if OS.has_feature("mobile") else "MOUSE"), "aim"],
		["AUTO-FIRE", "ON" if bool(s["autofire"]) else "OFF", "autofire"],
		["SCREEN SHAKE", "OFF" if float(s["shake"]) == 0.0 else ("LOW" if float(s["shake"]) < 0.9 else "FULL"), "shake"],
		["DAMAGE NUMBERS", "ON" if bool(s["numbers"]) else "OFF", "numbers"],
		["PARTICLES", "ON" if bool(s["particles"]) else "OFF", "particles"],
		["HINTS", "ON" if bool(s["hints"]) else "OFF", "hints"],
		["FULLSCREEN (F11)", "", "fullscreen"],
	]
	for i in range(rows.size()):
		var y = 128 + i * 38
		var r = Rect2(360, y, 560, 34)
		slant(r, Color("1e2a48") if not r.has_point(g.mouse_screen) else Color("2a3a60"), Color(0, 0, 0, 0), 10)
		txt(rows[i][0], Vector2(384, y + 28), 21, Color.WHITE, 0, bold, 3)
		txt(rows[i][1], Vector2(896, y + 28), 19, Color("ffd24d"), 2, bold, 3)
		if rows[i][2] in ["sfx", "music", "sensitivity"]:
			button(Rect2(660, y + 2, 44, 32), "-", "set_%s_down" % rows[i][2], false, 24)
			button(Rect2(712, y + 2, 44, 32), "+", "set_%s_up" % rows[i][2], false, 24)
		elif rows[i][2] == "touch" and not OS.has_feature("mobile"):
			pass
		else:
			buttons.append({"rect": r, "action": "set_" + rows[i][2]})
	button(Rect2(520, 626, 240, 54), "BACK", "back", true, 26)

## Locked cards show their rarity but not what they do.
func collection_info(item: Dictionary) -> Dictionary:
	if item["type"] == "mob":
		return mob_info(str(item["id"]))
	if item["type"] == "card" and not g.unlocked_cards.has(str(item["id"])):
		var c = g.card_by_id[item["id"]]
		var more = (int(g.unlock_index.get(str(item["id"]), 0)) - g.START_CARDS - g.CARDS_PER_LEVEL * int(g.profile["level"]) + 1) * g.KILLS_PER_CARD - g.lifetime_kills()
		return {"title": "???", "desc": "Locked. Unlocks at profile level %d, or in %d more kills." % [int(g.unlock_level.get(str(item["id"]), 0)), maxi(1, more)],
			"rar": int(c["rarity"]), "cat": g.categories.get(c["cat"], ""), "catid": "locked", "art": null, "foot": "LOCKED", "icon": false}
	if item["type"] == "gun_new" and not g.unlocked_guns.has(str(item["gun"])):
		var d = g.weapon_db[item["gun"]]
		return {"title": "???", "desc": "Locked gun. Unlocks at profile level %d." % (g.weapon_ids.find(str(item["gun"])) - g.START_GUNS + 1),
			"rar": 0, "cat": "GUN", "catid": "locked", "art": null, "foot": "LOCKED", "icon": true}
	return offer_info(item)

func get_collection_items() -> Array:
	var items = []
	if collection_cat == "weapons":
		for id in g.weapon_ids:
			items.append({"type": "gun_new", "gun": id, "preview": true})
	elif collection_cat == "mobs":
		for k in g.mob_order():
			items.append({"type": "mob", "id": k})
	else:
		for c in g.db_cards:
			if c["cat"] == collection_cat:
				items.append({"type": "card", "id": c["id"]})
	return items

func select_collection_index(idx: int) -> void:
	var items = get_collection_items()
	if idx >= 0 and idx < items.size():
		selected_collection_item = items[idx]

func paint_collection() -> void:
	paint_menu_bg()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06, 0.7))
	txt("COLLECTION", Vector2(640, 60), 52, Color.WHITE, 1, bold, 7)
	var cats = g.categories.keys()
	cats.append("weapons")
	cats.append("mobs")
	var tx = 30.0
	for c in cats:
		var label = {"weapons": "GUNS", "mobs": "MONSTERS"}.get(c, str(g.categories.get(c, c)))
		var w = bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		var r = Rect2(tx, 80, w, 32)
		var sel = c == collection_cat
		var col = Color("ffd24d") if sel else CAT_COLOR
		slant(r, col if sel else Color(col, 0.25), Color(0, 0, 0, 0), 8)
		txt(label, r.get_center() + Vector2(0, 6), 16, Color("0a0e1a") if sel else Color.WHITE, 1, bold)
		buttons.append({"rect": r, "action": "cat_" + c})
		tx += w + 5
	var items = get_collection_items()
	var per = 12
	var pages = maxi(1, ceili(float(items.size()) / per))
	collection_page = clampi(collection_page, 0, pages - 1)
	for i in range(per):
		var k = collection_page * per + i
		if k >= items.size():
			break
		var r2 = Rect2(30 + (i % 6) * 150, 130 + int(i / 6) * 270, 140, 258)
		var info = collection_info(items[k])
		mini_card(r2, info)
		buttons.append({"rect": r2, "action": "select_card_%d" % k})
		if r2.has_point(g.mouse_screen):
			hover_card = items[k]
	if selected_collection_item != null:
		hover_card = selected_collection_item
	if hover_card != null:
		draw_card(Rect2(950, 130, 300, 470), collection_info(hover_card), true, 1.0, -1)
		if hover_card["type"] == "gun_new":
			var d = g.weapon_db[hover_card["gun"]]
			wrap_text("LV3: " + str(d["lv3"]), 960, 622, 280, 14, Color("ffd24d"), 18, body)
			wrap_text("LV5: " + str(d["lv5"]), 960, 660, 280, 14, Color("ffd24d"), 18, body)
	else:
		txt("tap / hover a card", Vector2(1100, 360), 22, Color("6a7a98"), 1, bold)
	button(Rect2(330, 668, 60, 42), "<", "page-1", false, 26, collection_page > 0)
	txt("%d / %d" % [collection_page + 1, pages], Vector2(450, 698), 20, Color.WHITE, 1, bold, 3)
	button(Rect2(510, 668, 60, 42), ">", "page1", false, 26, collection_page < pages - 1)
	txt("%d cards  ·  %d guns  ·  %d / %d monsters" % [g.db_cards.size(), g.weapon_ids.size(), g.profile["mobs"].size(), g.mob_order().size()], Vector2(30, 698), 16, Color("9fb8d0"), 0, bold, 3)
	button(Rect2(1040, 660, 200, 48), "BACK", "back", true, 24)

func mini_card(r: Rect2, info: Dictionary) -> void:
	var rc: Color = RCOL[int(info["rar"])]
	if bool(info.get("cursed", false)):
		rc = Color("ff3a4a")
	var hover = r.has_point(g.mouse_screen)
	if hover:
		r.position.y -= 6
	rbox(Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.4), 14)
	rbox(r, PANEL, 14, rc, 3 if hover else 2)
	card_art(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 92)), info, rc)
	var y = wrap_text(str(info["title"]).to_upper(), r.position.x + 6, r.position.y + 124, r.size.x - 12, 16, Color.WHITE, 18, bold, true, 2)
	wrap_text(str(info["desc"]), r.position.x + 8, y + 4, r.size.x - 16, 12, Color("b8c4d8"), 15, body, true, 6)
	txt(str(info.get("rarlabel", RARITY[int(info["rar"])])), Vector2(r.get_center().x, r.end.y - 9), 13, rc, 1, bold)

## Tiny owned-card chip for the HUD strip: art, or category colour + icon.
func mini_tile(r: Rect2, id: String) -> void:
	var c = g.card_by_id[id]
	var art = g.tex("res://assets/cards/%s.png" % id)
	if art != null:
		draw_texture_rect(art, r, false)
	else:
		var hue = CardArt.hue(str(c["cat"]))
		rbox(r, hue.darkened(0.65), 6)
		CardArt.glyph(self, str(c["cat"]), r.get_center(), r.size.y * 0.32, hue)
	rbox(r.grow(1), Color(0, 0, 0, 0), 6, RCOL[int(c["rarity"])], 2)

func paint_victory() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("090e1c"))
	draw_rect(Rect2(16, 16, 1248, 688), Color("ffcf4d"), false, 4.0)
	txt("SECTOR %d CLEARED" % g.WIN_SECTOR, Vector2(640, 172), 64, Color("ffcf4d"), 1, bold, 7)
	txt("YOU WON!", Vector2(640, 258), 78, Color.WHITE, 1, bold, 8)
	txt("%d kills   ·   level %d   ·   %d:%02d" % [g.kills, g.level, int(g.run_time) / 60, int(g.run_time) % 60], Vector2(640, 330), 25, Color("c8d8ef"), 1, bold)
	txt("Your run can keep going. Enemies will keep scaling.", Vector2(640, 397), 21, Color("aebdd2"), 1, body)
	button(Rect2(428, 468, 424, 68), "CONTINUE TO SECTOR %d" % (g.WIN_SECTOR + 1), "continue_run", true, 28)
	button(Rect2(505, 564, 270, 52), "MAIN MENU", "menu", false, 22)

func paint_lost() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0a0610"))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.3, 0.0, 0.05, 0.3 + 0.05 * sin(g.anim_t * 2.0)))
	glitch_txt("FLATLINED", Vector2(640, 108), 80, ALERT)
	enemy_icon(g.killer_kind, Rect2(420, 122, 88, 88))
	var bub = Rect2(522, 132, 440, 66)
	cbox(bub, Color(0.03, 0.05, 0.08, 0.95), 12, ALERT, 2)
	draw_colored_polygon(PackedVector2Array([bub.position + Vector2(0, 26), bub.position + Vector2(-14, 36), bub.position + Vector2(0, 44)]), ALERT)
	txt("KILLED BY", bub.position + Vector2(18, 24), 15, MUTED, 0, bold)
	var tl = g.last_hit_by.to_upper()
	txt(tl, bub.position + Vector2(18, 54), fit(tl, 410, 28), Color.WHITE, 0, bold)
	var stats = [["SECTOR", str(g.sector)], ["LEVEL", str(g.level)], ["KILLS", str(g.kills)], ["BEST COMBO", "x%d" % g.best_combo],
		["DAMAGE", str(roundi(g.damage_dealt))], ["TIME", "%d:%02d" % [int(g.run_time) / 60, int(g.run_time) % 60]]]
	for i in range(stats.size()):
		var x = 190 + i * 180
		txt(stats[i][1], Vector2(x, 260), 40, Color("ffd24d"), 1, bold, 5)
		txt(stats[i][0], Vector2(x, 286), 15, Color("9fb0c8"), 1, bold, 3)
	txt("YOUR BUILD", Vector2(640, 340), 20, Color("9fb8d0"), 1, bold, 3)
	var n = mini(g.owned_order.size(), 16)
	for i in range(n):
		var id = g.owned_order[i]
		var c = g.card_by_id[id]
		var r = Rect2(640 - n * 34 + i * 68, 352, 64, 54)
		card_tile(r, id)
		if r.has_point(g.mouse_screen):
			hover_card = {"type": "card", "id": id}
	for i in range(g.guns.size()):
		var icon = g.tex("res://assets/weapons/%s.png" % g.guns[i]["id"])
		if icon != null:
			draw_texture_rect(icon, Rect2(560 + i * 90 - (g.guns.size() - 2) * 45, 420, 76, 76), false)
	var aw = award_line()
	if aw != "":
		txt(aw, Vector2(640, 525), 22, Color("d6c2ff"), 1, bold, 3)
	button(Rect2(500, 540, 280, 66), "RUN IT BACK", "play_hard" if g.hard_mode else "play", true, 32)
	button(Rect2(540, 620, 200, 50), "MAIN MENU", "menu", false, 22)
	result_lock()
	if hover_card != null:
		draw_card(Rect2(clampf(g.mouse_screen.x + 16, 0, 1020), 300, 250, 390), offer_info(hover_card), true, 1.0, -1)

## Fade the result screen in and keep its buttons dead until LOST_LOCK has passed.
func result_lock() -> void:
	var t = g.lost_t
	if t < 0.8:
		draw_rect(Rect2(0, 0, sw(), sh()), Color(0, 0, 0, 1.0 - t / 0.8))
	if t < g.LOST_LOCK:
		buttons.clear()

func goo_chip(c: Vector2) -> void:
	var t = "%d GOO" % int(g.profile.get("goo", 0))
	var w = bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 44
	var r = Rect2(c.x - w * 0.5, c.y - 16, w, 32)
	cbox(r, Color(0.03, 0.05, 0.08, 0.9), 8, Color("7dff9a"), 2)
	draw_colored_polygon(CardArt.cut_pts(Rect2(r.position + Vector2(10, 10), Vector2(12, 12)), 4), Color("7dff9a"))
	txt(t, c + Vector2(10, 7), 20, Color("7dff9a"), 1, bold)

## Permanent upgrade shop: one row per upgrade, two columns on wide screens.
func paint_upgrades() -> void:
	var w = sw()
	var hh = sh()
	draw_rect(Rect2(0, 0, w, hh), Color(0.02, 0.02, 0.05, 0.72))
	glitch_txt("UPGRADES", Vector2(w * 0.5, 92 if not g.portrait else 120), 64, Color.WHITE)
	goo_chip(Vector2(w * 0.5, 126 if not g.portrait else 160))
	var cols = 1 if g.portrait else 3
	var rw = 400.0 if not g.portrait else 648.0
	var rh = 84.0 if not g.portrait else minf(96.0, (hh - 420.0) / g.META_UPS.size())
	var x0 = w * 0.5 - (rw * cols + 20.0 * (cols - 1)) * 0.5
	var y0 = 156.0 if not g.portrait else 196.0
	for i in range(g.META_UPS.size()):
		var u = g.META_UPS[i]
		var lv = g.meta_level(str(u["id"]))
		var mx = int(u["max"])
		var r = Rect2(x0 + (i % cols) * (rw + 20.0), y0 + int(i / cols) * (rh + 8.0), rw, rh)
		var maxed = lv >= mx
		var can = not maxed and int(g.profile.get("goo", 0)) >= g.meta_cost(u)
		cbox(r, Color(0.03, 0.05, 0.08, 0.92), 14, Color(NEON if can else PANEL_EDGE, 0.8), 2)
		txt(str(u["name"]), r.position + Vector2(20, rh * 0.42), fit(str(u["name"]), rw - 190, 24), Color.WHITE, 0, bold)
		var sign = "-" if str(u["desc"]).begins_with("-") or str(u["desc"]).contains(" -") else "+"
		var now = (sign + ("%d" % roundi(float(u["per"]) * lv) if is_equal_approx(float(u["per"]) * lv, roundf(float(u["per"]) * lv)) else "%.1f" % (float(u["per"]) * lv))) if float(u["per"]) >= 1.0 else "%s%d%%" % [sign, roundi(float(u["per"]) * lv * 100)]
		var total = "%s  (now %s)" % [u["desc"], now]
		txt(total, r.position + Vector2(20, rh * 0.42 + 24), fit(total, rw - 180, 16, body, 11), MUTED, 0, body)
		for p in range(mx):
			draw_rect(Rect2(r.position.x + 20 + p * 18, r.end.y - 14, 14, 5), Color("7dff9a") if p < lv else Color(1, 1, 1, 0.15))
		var b = Rect2(r.end.x - 140, r.position.y + (rh - 50) * 0.5, 124, 50)
		button(b, "MAXED" if maxed else "%d GOO" % g.meta_cost(u), "meta_%d" % i, can, 20, not maxed)
	button(Rect2(w * 0.5 - 120, hh - (82 if not g.portrait else 130), 240, 56 if not g.portrait else 84), "BACK", "menu", true, 26)

func epic_plus_odds() -> float:
	var w = Effects.rarity_odds(g)
	var total = 0.0
	for x in w:
		total += x
	return (w[2] + w[3] + w[4] + w[5]) / maxf(0.001, total) * 100.0

# ================================================================= route map / shop / campfire
func sw() -> float:
	return 720.0 if g.portrait else 1280.0

func sh() -> float:
	return g.ui_height if g.portrait else 720.0

func screen_bg() -> void:
	draw_rect(Rect2(0, 0, sw(), sh()), Color(0.03, 0.04, 0.1, 0.94))
	for x in range(0, int(sw()) + 1, 60):
		draw_line(Vector2(x, 0), Vector2(x, sh()), Color(0.3, 0.65, 0.9, 0.04))
	for y in range(0, int(sh()) + 1, 60):
		draw_line(Vector2(0, y), Vector2(sw(), y), Color(0.3, 0.65, 0.9, 0.04))

## Gold + HP chips shared by the between-sector screens.
func status_chips(y: float) -> void:
	var W = sw()
	var hp = "%d / %d HP" % [ceili(float(g.hero["hp"])), int(g.hero["maxhp"])]
	rbox(Rect2(W * 0.5 - 250, y, 240, 44), Color(0, 0, 0, 0.55), 22)
	txt(hp, Vector2(W * 0.5 - 130, y + 31), fit(hp, 220, 22), Color("ff8a9a"), 1, bold, 2)
	rbox(Rect2(W * 0.5 + 10, y, 240, 44), Color(0, 0, 0, 0.55), 22)
	draw_circle(Vector2(W * 0.5 + 36, y + 22), 12, Color("b8860b"))
	draw_circle(Vector2(W * 0.5 + 36, y + 22), 9, Color("ffd24d"))
	txt("%d GOLD" % g.gold, Vector2(W * 0.5 + 140, y + 31), 22, Color("ffd24d"), 1, bold, 2)

func node_pos(col: int, i: int, n: int, first_col: int) -> Vector2:
	var W = sw()
	var H = sh()
	var top = 200.0 if g.portrait else 130.0
	var bottom = H - (330.0 if g.portrait else 170.0)
	var rows = 5
	var y = bottom - float(col - first_col) * (bottom - top) / rows
	var margin = 110.0 if g.portrait else 330.0
	var x = margin + (float(i) + 0.5) / n * (W - margin * 2.0)
	return Vector2(x, y)

func paint_map() -> void:
	if not g.portrait:
		paint_map_wide()
		return
	var W = sw()
	var H = sh()
	screen_bg()
	txt("ROUTE MAP", Vector2(W * 0.5, 74 if g.portrait else 58), 56 if g.portrait else 46, Color.WHITE, 1, bold, 6)
	status_chips(96 if g.portrait else 74)
	var cur = g.sector - 1
	var cols = g.map_cols
	var last = mini(cols.size() - 1, cur + 5)
	var nxt: Array = cols[cur][g.map_at]["next"]
	var visited = {}
	for v in g.map_path:
		visited[Vector2i(v)] = true
	var pulse = 0.5 + 0.5 * sin(g.anim_t * 5.0)
	# roads
	for c in range(cur, last):
		for i in range(cols[c].size()):
			var a = node_pos(c, i, cols[c].size(), cur)
			for j in cols[c][i]["next"]:
				var b = node_pos(c + 1, int(j), cols[c + 1].size(), cur)
				var live = c == cur and i == g.map_at
				var col = Color(1, 0.86, 0.35, 0.55 + 0.45 * pulse) if live else Color(0.45, 0.6, 0.85, 0.22)
				dashed(a, b, col, 6.0 if live else 4.0)
	# sector labels
	for c in range(cur, last + 1):
		var y = node_pos(c, 0, 1, cur).y
		var s = c + 1
		txt("S%d" % s, Vector2(30 if g.portrait else 290, y + 8), 20, Color("ff6b7a") if s % 5 == 0 or s > 20 else Color("7f93b5"), 0, bold, 2)
	# nodes
	for c in range(cur, last + 1):
		for i in range(cols[c].size()):
			var node = cols[c][i]
			var t = str(node["type"])
			var p = node_pos(c, i, cols[c].size(), cur)
			var info = g.NODE_INFO[t]
			var col = Color(str(info["color"]))
			var r = (46.0 if t == "boss" else 34.0) * (1.15 if g.portrait else 1.0)
			var reach = c == cur + 1 and nxt.has(i)
			var picked = reach and g.map_pick == i
			var here = c == cur and i == g.map_at
			var a = 1.0 if (reach or here) else 0.45
			if reach:
				draw_circle(p, r + 10.0 + pulse * 6.0, Color(col, 0.18))
			if picked:
				draw_circle(p, r + 12.0, Color(1, 1, 1, 0.9))
			draw_circle(p + Vector2(0, 5), r, Color(0, 0, 0, 0.4 * a))
			draw_circle(p, r, col.darkened(0.55 if not reach else 0.35) * Color(1, 1, 1, a))
			draw_arc(p, r, 0, TAU, 40, Color(col, a), 4.0)
			CardArt.node_icon(self, t, p, r * 0.55, Color(col.lightened(0.2), a))
			if here:
				CardArt.rbox(self, Rect2(p + Vector2(-34, r + 4), Vector2(68, 24)), Color("4fe0ff"), 12)
				txt("YOU", p + Vector2(0, r + 22), 16, Color("06223a"), 1, bold)
			if reach:
				buttons.append({"rect": Rect2(p - Vector2(r + 14, r + 14), Vector2(r + 14, r + 14) * 2.0), "action": "map_node_%d" % i})
	# info + go
	var pr = Rect2(24, H - 300, 672, 170) if g.portrait else Rect2(330, H - 142, 620, 120)
	if g.map_pick >= 0 and cur + 1 < cols.size():
		var t2 = str(cols[cur + 1][g.map_pick]["type"])
		var info2 = g.NODE_INFO[t2]
		var col2 = Color(str(info2["color"]))
		rbox(pr, PANEL, 20, col2, 3)
		CardArt.node_icon(self, t2, pr.position + Vector2(56, pr.size.y * 0.5), 28.0, col2)
		txt(str(info2["name"]), pr.position + Vector2(108, 46), 30, col2, 0, bold, 3)
		wrap_text(str(info2["desc"]), pr.position.x + 108, pr.position.y + 76, pr.size.x - 128, 18, Color("dbe4f5"), 22, body, false, 3)
		if g.portrait:
			button(Rect2(150, H - 116, 420, 88), "GO!", "map_go", true, 40)
		else:
			button(Rect2(970, H - 132, 250, 92), "GO!", "map_go", true, 40)
	else:
		rbox(pr, Color(0, 0, 0, 0.45), 20)
		txt("TAP A GLOWING ROAD", pr.get_center() + Vector2(0, 10), 26, Color.WHITE, 1, bold, 3)
	if g.portrait:
		icon_button(Vector2(660, 62), 28, "open_arsenal", "bag")
	else:
		button(Rect2(40, H - 110, 220, 64), "BUILD", "open_arsenal", false, 24)

func dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d = a.distance_to(b)
	var dir = (b - a) / maxf(1.0, d)
	var t = 0.0
	while t < d:
		draw_line(a + dir * t, a + dir * minf(d, t + 14.0), col, w)
		t += 24.0

func shop_item_info(item: Dictionary) -> Dictionary:
	if item["kind"] == "mystery":
		var info = {"title": "Mystery Card", "desc": "A random card: Rare 68%, Epic 26%, Legendary 5%, Mythic or better 1%.",
			"rar": 2, "cat": "GAMBLE", "catid": "shop", "art": null, "foot": "", "icon": true, "rarlabel": "???"}
		if item.has("revealed"):
			var got = offer_info({"type": "card", "id": item["revealed"]})
			got["foot"] = "YOU GOT IT"
			return got
		return info
	return stall_info(item)

func paint_shop() -> void:
	var W = sw()
	var H = sh()
	screen_bg()
	txt("SHOP", Vector2(W * 0.5, 74 if g.portrait else 58), 60 if g.portrait else 48, Color("ffd24d"), 1, bold, 6)
	status_chips(96 if g.portrait else 74)
	if g.shop_luck() > 0.0:
		txt("RISKY ROADS PAID OFF: +%d LUCK ON THIS SHOP" % roundi(g.shop_luck()), Vector2(W * 0.5, 156 if g.portrait else 134), 18, Color("7dff9a"), 1, bold, 2)
	var items = g.shop_items
	var n = maxi(1, items.size())
	if g.portrait:
		var top = 172.0
		var bottom = H - 150.0
		var row_h = minf(190.0, (bottom - top - (n - 1) * 14.0) / n)
		for i in range(items.size()):
			var r = Rect2(24, top + i * (row_h + 14.0), 672, row_h)
			shop_row(r, items[i], i)
		button(Rect2(24, H - 120, 320, 84), "REROLL %d G" % g.shop_reroll_cost, "shop_reroll", false, 28, g.gold >= g.shop_reroll_cost)
		button(Rect2(376, H - 120, 320, 84), "LEAVE", "map_continue", true, 34)
	else:
		var cw = minf(210.0, (W - 80.0 - (n - 1) * 16.0) / n)
		var x0 = W * 0.5 - (n * cw + (n - 1) * 16.0) * 0.5
		for i in range(items.size()):
			var r = Rect2(x0 + i * (cw + 16.0), 140, cw, 380)
			var item = items[i]
			draw_card(r, shop_item_info(item), r.has_point(g.mouse_screen), 1.0, -1)
			if bool(item["sold"]):
				rbox(r, Color(0, 0, 0, 0.6), 20)
				txt("SOLD", r.get_center() + Vector2(0, 14), 40, Color("9aabc3"), 1, bold, 4)
			else:
				var price = int(item["price"])
				button(Rect2(r.position.x, r.end.y + 16, cw, 56), "%d G" % price, "shop_buy_%d" % i, true, 26, g.gold >= price)
		button(Rect2(W * 0.5 - 330, H - 100, 300, 66), "REROLL  %d G" % g.shop_reroll_cost, "shop_reroll", false, 24, g.gold >= g.shop_reroll_cost)
		button(Rect2(W * 0.5 + 30, H - 100, 300, 66), "LEAVE", "map_continue", true, 30)
	if g.portrait:
		icon_button(Vector2(660, 62), 28, "open_arsenal", "bag")

func shop_row(r: Rect2, item: Dictionary, i: int) -> void:
	portrait_offer_row(r, shop_item_info(item))
	if bool(item["sold"]):
		rbox(r, Color(0, 0, 0, 0.62), 20)
		txt("SOLD", r.get_center() + Vector2(0, 16), 44, Color("9aabc3"), 1, bold, 4)
		return
	var price = int(item["price"])
	var can = g.gold >= price
	var pr = Rect2(r.end.x - 150, r.end.y - 58, 136, 46)
	rbox(pr, BTN_PRIMARY if can else Color("3a4256"), 23)
	txt("%d G" % price, pr.get_center() + Vector2(0, 10), 26, BTN_TEXT_DARK if can else Color("8590a6"), 1, bold)
	buttons.append({"rect": r, "action": "shop_buy_%d" % i})

func paint_rest() -> void:
	var W = sw()
	var H = sh()
	screen_bg()
	var c = Vector2(W * 0.5, 250 if g.portrait else 200)
	# a little campfire
	for k in range(3):
		var fl = sin(g.anim_t * (7.0 + k)) * 6.0
		CardArt.glyph(self, "element", c + Vector2((k - 1) * 26, fl * 0.3), 46.0 - k * 6.0, [Color("ff8a3d"), Color("ffd24d"), Color("ff5a4a")][k])
	draw_line(c + Vector2(-60, 60), c + Vector2(60, 40), Color("8a5a3a"), 14)
	draw_line(c + Vector2(-60, 40), c + Vector2(60, 60), Color("6b4329"), 14)
	txt("CAMPFIRE", Vector2(W * 0.5, 82 if g.portrait else 64), 58 if g.portrait else 48, Color("7dff9a"), 1, bold, 6)
	status_chips(c.y + 92)
	var y = c.y + 170
	var bw = 560.0 if g.portrait else 520.0
	var bx = W * 0.5 - bw * 0.5
	var heal_amt = roundi(float(g.hero["maxhp"]) * 0.4)
	button(Rect2(bx, y, bw, 96), "REST: HEAL %d HP" % heal_amt, "rest_heal", true, 32)
	txt("OR TRAIN A GUN (+1 LEVEL)", Vector2(W * 0.5, y + 150), 22, Color.WHITE, 1, bold, 3)
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var lv = int(w["lvl"])
		var label = "%s  LV %d » %d" % [Weapons.display_name(g, w).to_upper(), lv, lv + 1] if lv < 5 else "%s  MAX LEVEL" % Weapons.display_name(g, w).to_upper()
		button(Rect2(bx, y + 176 + i * 96, bw, 80), label, "rest_train_%d" % i, false, 26, lv < 5)
	if g.portrait:
		icon_button(Vector2(660, 62), 28, "open_arsenal", "bag")

func paint_event() -> void:
	var W = sw()
	var H = sh()
	screen_bg()
	var ev: Dictionary = g.event
	if ev.is_empty():
		return
	txt("?", Vector2(W * 0.5, 120 if g.portrait else 92), 90 if g.portrait else 70, Color("b8c8ff"), 1, bold, 6)
	txt(str(ev["title"]), Vector2(W * 0.5, 196 if g.portrait else 150), fit(str(ev["title"]), W - 60, 50 if g.portrait else 40), Color.WHITE, 1, bold, 5)
	status_chips(222 if g.portrait else 168)
	var pw = 640.0 if g.portrait else 760.0
	var pr = Rect2(W * 0.5 - pw * 0.5, 290 if g.portrait else 228, pw, 150 if g.portrait else 110)
	rbox(pr, PANEL, 20, PANEL_EDGE, 2)
	wrap_text(str(ev["text"]), pr.position.x + 26, pr.position.y + 42, pw - 52, 22 if g.portrait else 19, Color("dbe4f5"), 30 if g.portrait else 25, body, true, 4)
	var dice_y = pr.end.y + (150.0 if g.portrait else 95.0)
	var n = g.event_faces.size()
	if n > 0:
		var rolling = g.event_stage == "rolling"
		for k in range(n):
			var c = Vector2(W * 0.5 + (k - (n - 1) * 0.5) * 150.0, dice_y)
			var spin = 0.0
			if rolling:
				spin = g.event_roll_t * 9.0 + k * 1.3
				c.y -= absf(sin(g.event_roll_t * 11.0 + k)) * 40.0 * g.event_roll_t
			draw_die(c, 104.0 if g.portrait else 84.0, int(g.event_faces[k]), spin)
	var by = dice_y + (110.0 if g.portrait else 70.0) if n > 0 else pr.end.y + 40.0
	if g.event_stage == "choose":
		var opts: Array = ev["opts"]
		for i in range(opts.size()):
			var o: Dictionary = opts[i]
			var can = int(o.get("cost", 0)) <= g.gold
			var r = Rect2(W * 0.5 - 260, by + i * 104, 520, 86) if g.portrait else Rect2(W * 0.5 - 220, by + i * 82, 440, 66)
			button(r, str(o["label"]) if can else "%s (NOT ENOUGH)" % str(o["label"]), "event_opt_%d" % i, i == 0, 30 if g.portrait else 26, can)
	elif g.event_stage == "result":
		var rr = Rect2(W * 0.5 - pw * 0.5, by, pw, 100 if g.portrait else 76)
		rbox(rr, Color(0, 0, 0, 0.5), 20)
		wrap_text(g.event_result, rr.position.x + 20, rr.position.y + (40 if g.portrait else 32), pw - 40, 24 if g.portrait else 20, Color("ffd24d"), 30 if g.portrait else 26, bold, true, 3)
		var cb = Rect2(W * 0.5 - 210, rr.end.y + 40, 420, 88) if g.portrait else Rect2(W * 0.5 - 170, rr.end.y + 26, 340, 66)
		button(cb, "CONTINUE", "event_continue", true, 34 if g.portrait else 28)

## A d6 with pips; spin rotates it while it tumbles.
func draw_die(c: Vector2, size: float, face: int, spin: float) -> void:
	draw_set_transform(c, spin, Vector2.ONE)
	var r = Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size))
	rbox(Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.4), size * 0.2)
	rbox(r, Color("f4f1ea"), size * 0.2, Color("c9c2b4"), 4)
	var pips = {1: [Vector2.ZERO], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	for pp in pips.get(clampi(face, 1, 6), []):
		draw_circle(pp * size * 0.26, size * 0.09, Color("ff4d6a") if face == 1 else Color("1b2238"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Profile level, XP bar and how many cards are unlocked.
func profile_bar(c: Vector2, w: float) -> void:
	var lv = int(g.profile["level"])
	var need = g.profile_need(lv)
	var f = clampf(float(g.profile["xp"]) / float(need), 0.0, 1.0)
	var r = Rect2(c.x - w * 0.5, c.y - 22, w, 44)
	rbox(r, Color(0, 0, 0, 0.55), 22)
	rbox(Rect2(r.position + Vector2(4, 4), Vector2(maxf(36.0, (w - 8) * f), 36)), Color("6d4bd1"), 18)
	var t = "PROFILE LV %d   ·   %d / %d CARDS" % [lv, g.unlocked_cards.size(), g.db_cards.size()]
	txt(t, c + Vector2(0, 8), fit(t, w - 30, 21), Color.WHITE, 1, bold, 3)

## "+120 PROFILE XP · LEVEL UP! · NEW: Cryo Rounds, Laser +2 more" on the result screens.
func award_line() -> String:
	if g.last_award.is_empty():
		return ""
	var t = "+%d PROFILE XP  ·  +%d GOO" % [int(g.last_award["xp"]), int(g.last_award.get("goo", 0))]
	if int(g.last_award["levels"]) > 0:
		t += "  ·  LEVEL UP!"
	if not g.run_unlocks.is_empty():
		var names = []
		for u in g.run_unlocks.slice(0, 3):
			names.append(unlock_name(u))
		t += "  ·  NEW: " + ", ".join(names)
		if g.run_unlocks.size() > 3:
			t += " +%d more" % (g.run_unlocks.size() - 3)
	return t

func unlock_name(u: Dictionary) -> String:
	if u["type"] in ["enemy", "mob"]:
		return str(g.enemy_db[u["id"]]["name"])
	if u["type"] == "gun":
		return str(g.weapon_db[u["id"]].get("name", u["id"]))
	return str(g.card_by_id[u["id"]]["name"])

var _mob_tex: Dictionary = {}

## Portrait cut from the baked enemy atlas, usable anywhere a card expects art.
func mob_tex(kind: String) -> Texture2D:
	var v = g.visuals
	if v.atlas == null or not v.atlas_cell.has(kind):
		return null
	if not _mob_tex.has(kind):
		var at = AtlasTexture.new()
		at.atlas = v.atlas
		at.region = v.atlas_cell[kind]
		_mob_tex[kind] = at
	return _mob_tex[kind]

func mob_info(kind: String) -> Dictionary:
	var d = g.enemy_db[kind]
	var boss = bool(d.get("boss", false))
	var tier = g.mob_tier(kind)
	var rar = 4 if boss else (3 if kind == "goblin" else mini(tier, 3))
	var tag = "BOSS" if boss else ("RARE" if kind == "goblin" else "TIER %d" % (tier + 1))
	if not g.profile["mobs"].has(kind):
		var hint = "A boss. Keep going." if boss else ("Shows up on the street." if tier == 0 else "Shows up after %d boss kill%s." % [tier, "" if tier == 1 else "s"])
		return {"title": "???", "desc": "Not met yet. " + hint, "rar": rar, "cat": "MONSTER", "catid": "locked",
			"art": null, "foot": "LOCKED", "icon": false, "rarlabel": "LOCKED"}
	var desc = "HP %d · DMG %d · SPEED %d.  You killed %d." % [int(d["hp"]), int(d["dmg"]), int(d["speed"]), int(g.profile["mobs"][kind])]
	return {"title": str(d["name"]), "desc": desc, "rar": rar, "cat": "MONSTER", "catid": "chaos",
		"art": mob_tex(kind), "foot": tag, "icon": true, "rarlabel": tag}

## Enemy portrait from the baked atlas (nothing in headless runs).
func enemy_icon(kind: String, r: Rect2, a: float = 1.0) -> void:
	var v = g.visuals
	if v.atlas != null and v.atlas_cell.has(kind):
		draw_texture_rect_region(v.atlas, r, v.atlas_cell[kind], Color(1, 1, 1, a))

const KILL_LINES = {"blob": "blob.", "zoomer": "too slow.", "nurse": "no refunds.", "spitter": "ptooey.",
	"kaboomba": "worth it.", "chonk": "oops. sat on you.", "mitosis": "we won.", "mini": "small but mighty.",
	"riot": "denied.", "bull": "moo.", "larry": "pew.", "tick": "tick tock.", "mama": "go to your room.",
	"mortar": "incoming.", "totem": "hype!", "blinky": "boo.", "goblin": "mine now.",
	"chonkzilla": "BELLY FLOP.", "heli": "air support.", "necro": "rise. oh wait.", "kingblob": "kneel."}

## Death beat: the camera swings to the killer, locks on with brackets, and it says something in a chat bubble.
func paint_dying() -> void:
	var t = g.DYING_TIME - g.dying_t
	var k = clampf(t / 0.4, 0.0, 1.0)
	var w = sw()
	var hh = sh()
	draw_rect(Rect2(0, 0, w, hh), Color(0.25, 0.0, 0.03, 0.35 * k))
	for i in range(int(hh / 4)):
		draw_rect(Rect2(0, i * 4, w, 1), Color(0, 0, 0, 0.15 * k))
	var ke = g.killer_ref
	if not ke.is_empty():
		var p = g.world_to_screen(ke["pos"])
		var rr = float(ke.get("r", 18.0)) * 1.5 + 12.0
		var lock = clampf((t - 0.35) / 0.3, 0.0, 1.0)
		var s = rr * (1.6 - 0.6 * lock)
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var cp = p + c * s
			draw_polyline(PackedVector2Array([cp - Vector2(c.x * 14, 0), cp, cp - Vector2(0, c.y * 14)]), Color(ALERT, lock), 3.0)
		var nm = str(g.enemy_db[ke["kind"]]["name"]).to_upper()
		txt(nm, p + Vector2(-s, s + 22), 16, Color(ALERT, lock), 0, bold, 3)
		var a = clampf((t - 0.6) / 0.25, 0.0, 1.0)
		if a > 0.0:
			var line = str(KILL_LINES.get(str(ke["kind"]), "gg."))
			var bw = bold.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 36
			var br = Rect2(p.x - bw * 0.5, p.y - s - 74, bw, 52)
			cbox(br, Color(0.97, 0.97, 1.0, a), 10)
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 10, br.end.y - 1), Vector2(p.x + 10, br.end.y - 1), Vector2(p.x, br.end.y + 16)]), Color(0.97, 0.97, 1.0, a))
			txt(line, Vector2(p.x, br.position.y + 35), 26, Color(0.05, 0.05, 0.1, a), 1, bold)
	glitch_txt("FLATLINED", Vector2(w * 0.5, hh * 0.2), int(84 if not g.portrait else 76), Color(1, 1, 1, k))
	var by = "KILLED BY " + g.last_hit_by.to_upper()
	txt(by, Vector2(w * 0.5, hh * 0.2 + 42), fit(by, w - 60, 26), Color(ALERT, k), 1, bold, 4)

## Slide-in popup for each card or gun unlocked mid-run.
func paint_unlock_toast(center_x: float, y: float) -> void:
	if g.unlock_toasts.is_empty():
		return
	var u = g.unlock_toasts[0]
	var t = float(u["t"])
	var slide = clampf((2.6 - t) * 6.0, 0.0, 1.0) * clampf(t * 6.0, 0.0, 1.0)
	var r = Rect2(center_x - 190, y - 40 + slide * 40, 380, 64)
	var col = {"gun": Color("ffcf4d"), "enemy": ALERT, "mob": Color("7dff9a")}.get(u["type"], NEON)
	cbox(r, Color(0.03, 0.05, 0.08, 0.94 * slide), 12, Color(col, slide), 2)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 14, 4, r.size.y - 22), Color(col, slide))
	var label = {"gun": "UNLOCKED // NEW GUN", "enemy": "BOSS DOWN // NEW THREAT", "mob": "BESTIARY // NEW ENTRY"}.get(u["type"], "UNLOCKED // NEW CARD")
	txt(label, r.position + Vector2(22, 24), 15, Color(col, slide), 0, bold)
	if u["type"] in ["enemy", "mob"]:
		enemy_icon(u["id"], Rect2(r.end.x - 62, r.position.y + 4, 56, 56), slide)
	var nm = unlock_name(u).to_upper()
	txt(nm, r.position + Vector2(22, 52), fit(nm, 330, 26), Color(1, 1, 1, slide), 0, bold)

# ---------------------------------------------------------------- route map, PC layout (left -> right)
func map_node_pos_wide(col: int, i: int, n: int, first: int) -> Vector2:
	var x = 100.0 + float(col - first) * 150.0
	var y = 395.0 if n == 1 else 150.0 + (float(i) + 0.5) / n * 490.0
	return Vector2(x, y)

func road(a: Vector2, b: Vector2, col: Color, w: float, dashed_live: bool) -> void:
	var pts = PackedVector2Array()
	var c1 = a + Vector2((b.x - a.x) * 0.5, 0)
	var c2 = b - Vector2((b.x - a.x) * 0.5, 0)
	for k in range(13):
		var t = k / 12.0
		var p = a.lerp(c1, t).lerp(c1.lerp(c2, t), t).lerp(c1.lerp(c2, t).lerp(c2.lerp(b, t), t), t)
		pts.append(p)
	draw_polyline(pts, Color(0, 0, 0, 0.45), w + 6.0, true)
	draw_polyline(pts, col, w, true)
	if dashed_live:
		var off = fmod(g.anim_t * 2.0, 1.0)
		for k in range(12):
			var t = (k + off) / 12.0
			var idx = clampi(int(t * 12.0), 0, 11)
			var p = pts[idx].lerp(pts[idx + 1], t * 12.0 - idx)
			draw_circle(p, w * 0.32, Color(1, 1, 1, 0.8))

func paint_map_wide() -> void:
	var cols = g.map_cols
	var cur = g.sector - 1
	var last = mini(cols.size() - 1, cur + 5)
	var nxt: Array = cols[cur][g.map_at]["next"]
	# backdrop
	draw_rect(Rect2(0, 0, 1280, 720), Color("0a0f22"))
	var bi = int(cur / 5) % 5
	var tints = [Color("1b2f5a"), Color("1d3d52"), Color("3a2018"), Color("3a1d40"), Color("1a1430")]
	for k in range(14):
		draw_rect(Rect2(0, 100 + k * 40, 900, 40), Color(tints[bi], 0.25 + 0.2 * sin(k * 0.7 + g.anim_t * 0.3)))
	rbox(Rect2(20, 100, 870, 600), Color(0, 0, 0, 0), 26, Color(1, 1, 1, 0.08), 2)
	# header
	txt("ROUTE MAP", Vector2(30, 66), 46, Color.WHITE, 0, bold, 5)
	var boss_in = 5 - (cur + 1) % 5 if g.sector < g.WIN_SECTOR else 1
	var biome = ["NEON OUTSKIRTS", "FROSTLINE", "ASHLANDS", "CANDY DISTRICT", "THE VOID LANE"][int((cur + 1) / 5) % 5]
	var chip = "ACT %d  ·  %s  ·  BOSS IN %d" % [int(cur / 5) + 1, biome, boss_in]
	rbox(Rect2(300, 34, 560, 44), Color(0, 0, 0, 0.5), 22)
	txt(chip, Vector2(580, 64), fit(chip, 530, 21), Color("ffd24d"), 1, bold, 2)
	# roads
	for c in range(cur, last):
		for i in range(cols[c].size()):
			var a = map_node_pos_wide(c, i, cols[c].size(), cur)
			for j in cols[c][i]["next"]:
				var b = map_node_pos_wide(c + 1, int(j), cols[c + 1].size(), cur)
				var live = c == cur and i == g.map_at
				var picked = live and int(j) == g.map_pick
				var col = Color("ffd24d") if picked else (Color(1, 0.85, 0.4, 0.75) if live else Color(0.45, 0.6, 0.9, 0.22))
				road(a, b, col, 12.0 if live else 7.0, picked)
	# nodes
	for c in range(cur, last + 1):
		for i in range(cols[c].size()):
			paint_map_node(cols[c][i], map_node_pos_wide(c, i, cols[c].size(), cur), c, i, cur, nxt)
	# sector numbers along the bottom
	for c in range(cur, last + 1):
		var x = map_node_pos_wide(c, 0, 1, cur).x
		var s = c + 1
		txt("S%d" % s, Vector2(x, 680), 18, Color("ff6b7a") if s % 5 == 0 or s > 20 else Color("6f84a8"), 1, bold, 2)
	paint_map_panel(nxt, cols, cur)

func paint_map_node(node: Dictionary, p: Vector2, c: int, i: int, cur: int, nxt: Array) -> void:
	var t = str(node["type"])
	var info = g.NODE_INFO[t]
	var col = Color(str(info["color"]))
	var reach = c == cur + 1 and nxt.has(i)
	var here = c == cur and i == g.map_at
	var past = c <= cur and not here
	var size = 96.0 if t == "boss" else 64.0
	var hovered = reach and Rect2(p - Vector2(size, size) * 0.6, Vector2(size, size) * 1.2).has_point(g.mouse_screen)
	if hovered and not g.is_touch_active():
		g.map_pick = i
	var picked = reach and g.map_pick == i
	var lift = -6.0 if picked else 0.0
	var a = 1.0 if (reach or here) else (0.35 if past else 0.6)
	var r = Rect2(p - Vector2(size, size) * 0.5 + Vector2(0, lift), Vector2(size, size))
	if reach:
		var pulse = 0.5 + 0.5 * sin(g.anim_t * 5.0 + i)
		rbox(r.grow(8 + pulse * 4), Color(col, 0.16 + (0.18 if picked else 0.0)), 28)
	rbox(Rect2(r.position + Vector2(0, 7), r.size), Color(0, 0, 0, 0.45 * a), 22)
	rbox(r, col.darkened(0.62).lerp(col.darkened(0.4), 0.5 if reach else 0.0) * Color(1, 1, 1, a), 22, Color(col if (reach or here) else col.darkened(0.3), a), 4 if picked else 3)
	rbox(Rect2(r.position + Vector2(6, 5), Vector2(r.size.x - 12, r.size.y * 0.4)), Color(1, 1, 1, 0.07 * a), 16)
	CardArt.node_icon(self, t, r.get_center() + Vector2(0, -2), size * 0.3, Color(col.lightened(0.25), a))
	if here:
		var hero_tex = g.tex("res://assets/ui/hero.png")
		if hero_tex != null:
			draw_texture_rect(hero_tex, Rect2(r.position + Vector2(size * 0.45, -size * 0.45), Vector2(size * 0.7, size * 0.7)), false)
		rbox(Rect2(p.x - 32, r.end.y + 6, 64, 24), Color("4fe0ff"), 12)
		txt("YOU", Vector2(p.x, r.end.y + 24), 16, Color("06223a"), 1, bold)
		return
	if c > cur:
		var name = str(info["name"])
		txt(name, Vector2(p.x, r.end.y + 20), fit(name, 140, 16), Color(Color.WHITE, a), 1, bold, 3)
		if node.has("mod"):
			var m: Dictionary = node["mod"]
			var ml = str(m["label"])
			var good = bool(m.get("good", true))
			var mw = minf(150.0, bold.get_string_size(ml, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16)
			rbox(Rect2(p.x - mw * 0.5, r.end.y + 26, mw, 20), Color("1f6b4a" if good else "7a2434") * Color(1, 1, 1, a), 10)
			txt(ml, Vector2(p.x, r.end.y + 41), fit(ml, mw - 10, 12, bold, 9), Color(Color.WHITE, a), 1, bold)
	if reach:
		buttons.append({"rect": r.grow(10), "action": "map_node_%d" % i})

func paint_map_panel(nxt: Array, cols: Array, cur: int) -> void:
	var pr = Rect2(910, 100, 350, 600)
	rbox(pr, PANEL, 24, PANEL_EDGE, 2)
	status_chips_at(Vector2(pr.get_center().x, 24))
	if g.map_pick < 0 or cur + 1 >= cols.size():
		txt("CHOOSE YOUR ROAD", Vector2(pr.get_center().x, 150), 26, Color.WHITE, 1, bold, 3)
		var y = 190.0
		for t in ["fight", "elite", "hell", "event", "shop", "rest", "treasure", "boss"]:
			var info = g.NODE_INFO[t]
			CardArt.node_icon(self, t, Vector2(pr.position.x + 46, y + 18), 15.0, Color(str(info["color"])))
			txt(str(info["name"]), Vector2(pr.position.x + 80, y + 26), 19, Color(str(info["color"])).lightened(0.2), 0, bold, 2)
			y += 52
		button(Rect2(pr.position.x + 30, pr.end.y - 82, pr.size.x - 60, 60), "BUILD", "open_arsenal", false, 24)
		return
	var node = cols[cur + 1][g.map_pick]
	var t2 = str(node["type"])
	var info2 = g.NODE_INFO[t2]
	var col2 = Color(str(info2["color"]))
	var ic = Vector2(pr.get_center().x, 190)
	draw_circle(ic, 62, col2.darkened(0.6))
	draw_arc(ic, 62, 0, TAU, 48, col2, 4.0)
	CardArt.node_icon(self, t2, ic, 34.0, col2.lightened(0.2))
	txt(str(info2["name"]), Vector2(ic.x, 292), fit(str(info2["name"]), 320, 34), col2.lightened(0.2), 1, bold, 4)
	txt("SECTOR %d" % (cur + 2), Vector2(ic.x, 320), 17, MUTED, 1, bold)
	var y2 = wrap_text(str(info2["desc"]), pr.position.x + 24, 356, pr.size.x - 48, 18, Color("dbe4f5"), 24, body, true, 5)
	if node.has("mod"):
		var m: Dictionary = node["mod"]
		var good = bool(m.get("good", true))
		var mr = Rect2(pr.position.x + 24, y2 + 14, pr.size.x - 48, 64)
		rbox(mr, Color("1f6b4a") if good else Color("7a2434"), 16)
		txt("ROAD BONUS" if good else "RISKY DEAL", Vector2(mr.get_center().x, mr.position.y + 24), 15, Color(1, 1, 1, 0.75), 1, bold)
		txt(str(m["label"]), Vector2(mr.get_center().x, mr.position.y + 50), fit(str(m["label"]), mr.size.x - 20, 22), Color.WHITE, 1, bold, 2)
	button(Rect2(pr.position.x + 30, pr.end.y - 160, pr.size.x - 60, 74), "GO!", "map_go", true, 38)
	button(Rect2(pr.position.x + 30, pr.end.y - 74, pr.size.x - 60, 54), "BUILD", "open_arsenal", false, 22)

func status_chips_at(c: Vector2) -> void:
	var hp = "%d / %d HP" % [ceili(float(g.hero["hp"])), int(g.hero["maxhp"])]
	rbox(Rect2(c.x - 170, c.y, 170, 40), Color(0, 0, 0, 0.55), 20)
	txt(hp, Vector2(c.x - 85, c.y + 28), fit(hp, 150, 20), Color("ff8a9a"), 1, bold, 2)
	rbox(Rect2(c.x + 6, c.y, 164, 40), Color(0, 0, 0, 0.55), 20)
	txt("%d GOLD" % g.gold, Vector2(c.x + 88, c.y + 28), 20, Color("ffd24d"), 1, bold, 2)
