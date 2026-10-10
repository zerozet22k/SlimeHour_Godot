extends Node2D
## All UI: HUD, level-up cards, arsenal, collection, menus. Buttons register themselves each
## frame while drawing; click() resolves them.

const Weapons = preload("res://scripts/Weapons.gd")
const Compatibility = preload("res://scripts/WeaponCompatibility.gd")
const Characters = preload("res://scripts/Characters.gd")
const DebugLab = preload("res://scripts/DebugLab.gd")
const CollectionGrid = preload("res://scripts/CollectionGrid.gd")
const Effects = preload("res://scripts/Effects.gd")
const CardArt = preload("res://scripts/CardArt.gd")

var g
var bold: Font
var body: Font
var buttons: Array = []
var peek = false
var collection_cat = "volley"
var collection_page = 0  # first visible GRID ROW, not a four-card page
var collection_track := Rect2()
var collection_touch_id := -1
var collection_touch_y := 0.0
var collection_touch_distance := 0.0
var collection_touch_accum := 0.0
var bestiary_page = 0
var bestiary_filter = "ALL"
var bestiary_selected = ""
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
	if g.state == "collection" and collection_track.has_point(pos) and (not g.portrait or selected_collection_item == null):
		var total = get_collection_items().size()
		var cols = CollectionGrid.columns(g.portrait)
		var rows = CollectionGrid.visible_rows(g.portrait, g.ui_height)
		var max_row = CollectionGrid.max_start_row(total, cols, rows)
		var relative_y = clampf((pos.y - collection_track.position.y) / maxf(1.0, collection_track.size.y), 0.0, 1.0)
		collection_page = clampi(roundi(relative_y * max_row), 0, max_row)
		return
	for i in range(buttons.size() - 1, -1, -1):
		if buttons[i]["rect"].has_point(pos):
			press_action = str(buttons[i]["action"])
			press_t = g.anim_t
			g.do_action(buttons[i]["action"])
			return

func scroll(d: int) -> void:
	var total = get_collection_items().size()
	var cols = CollectionGrid.columns(g.portrait)
	var rows = CollectionGrid.visible_rows(g.portrait, g.ui_height)
	collection_page = CollectionGrid.scroll_row(total, cols, rows, collection_page, d)

func collection_key(code: int) -> void:
	match code:
		KEY_UP, KEY_LEFT, KEY_W, KEY_A:
			scroll(-1)
		KEY_DOWN, KEY_RIGHT, KEY_S, KEY_D:
			scroll(1)
		KEY_PAGEUP:
			scroll(-CollectionGrid.visible_rows(g.portrait, g.ui_height))
		KEY_PAGEDOWN:
			scroll(CollectionGrid.visible_rows(g.portrait, g.ui_height))
		KEY_HOME:
			collection_page = 0
		KEY_END:
			collection_page = CollectionGrid.max_start_row(get_collection_items().size(), CollectionGrid.columns(g.portrait), CollectionGrid.visible_rows(g.portrait, g.ui_height))

func collection_touch_begin(id: int, pos: Vector2) -> void:
	collection_touch_id = id
	collection_touch_y = pos.y
	collection_touch_distance = 0.0
	collection_touch_accum = 0.0

func collection_touch_move(id: int, pos: Vector2) -> void:
	if id != collection_touch_id or selected_collection_item != null:
		return
	var delta = pos.y - collection_touch_y
	collection_touch_y = pos.y
	collection_touch_distance += absf(delta)
	collection_touch_accum += delta
	# Swipe up to scroll DOWN, swipe down to scroll UP. One row per 88px.
	if absf(collection_touch_accum) >= 88.0:
		var rows = maxi(1, int(absf(collection_touch_accum) / 88.0))
		scroll(-rows if collection_touch_accum > 0.0 else rows)
		collection_touch_accum -= signf(collection_touch_accum) * rows * 88.0

func collection_touch_end(id: int, pos: Vector2) -> void:
	if id != collection_touch_id:
		return
	var moved = collection_touch_distance
	collection_touch_id = -1
	collection_touch_accum = 0.0
	if moved < 18.0:
		click(pos)

## A visible proportional scroll thumb. Cards stay inside the grid: no clipping artifacts.
func collection_scrollbar(r: Rect2, total: int, cols: int, rows: int) -> void:
	collection_track = r
	var max_row = CollectionGrid.max_start_row(total, cols, rows)
	rbox(r, Color("26334a"), 4)
	var fraction = minf(1.0, float(rows) / maxf(1.0, float(CollectionGrid.total_rows(total, cols))))
	var thumb_h = maxf(34.0, r.size.y * fraction)
	var t = float(collection_page) / float(maxi(1, max_row))
	var thumb_y = r.position.y + (r.size.y - thumb_h) * t
	rbox(Rect2(r.position.x, thumb_y, r.size.x, thumb_h), Color("6be7ee") if max_row > 0 else Color("52707d"), 4)

# ================================================================= main draw
func _draw() -> void:
	RCOL[5] = Color.from_hsv(fmod(g.anim_t * 0.3, 1.0), 0.6, 1.0)
	buttons.clear()
	hover_card = null
	if g.state in ["map", "shop", "rest", "event", "travel", "boss_result"] or g.state == "arsenal" and g.arsenal_back != "playing" and not g.portrait:
		match g.state:
			"event":
				paint_event()
			"boss_result":
				paint_boss_result()
			"travel":
				paint_map()
				buttons.clear()
				paint_travel_overlay()
			"map":
				paint_map()
			"shop":
				paint_shop()
			"rest":
				paint_rest()
			"arsenal":
				paint_hub_backdrop()
				paint_arsenal()
		if g.debug_panel_open:
			buttons.clear()
			paint_debug_panel()
		return
	if g.portrait:
		if g.state in ["levelup", "replace", "arsenal"] and g.phase in ["shop", "rest", "event", "treasure", "cleared", "map"]:
			paint_hub_backdrop()
		paint_portrait()
		if g.debug_panel_open:
			buttons.clear()
			paint_debug_panel()
		return
	# Shop rewards and weapon replacement belong to the route interface, not the battlefield.
	if g.state in ["levelup", "replace", "arsenal"] and g.phase in ["shop", "rest", "event", "treasure", "cleared", "map"]:
		paint_hub_backdrop()
		match g.state:
			"levelup":
				if peek:
					paint_arsenal()
				else:
					paint_levelup()
			"replace":
				paint_replace()
			"arsenal":
				paint_arsenal()
		if g.debug_panel_open:
			buttons.clear()
			paint_debug_panel()
		return
	match g.state:
		"menu":
			paint_menu()
		"characters":
			paint_characters()
		"updating":
			paint_update_screen()
		"collection":
			paint_collection()
		"bestiary":
			paint_bestiary()
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
	if g.debug_panel_open:
		buttons.clear()
		paint_debug_panel()
	if g.debug_mode and not g.debug_panel_open:
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
			button(Rect2(130, h * 0.39, 460, 86), "PLAY", "play", true, 42)
			button(Rect2(130, h * 0.39 + 102, 460, 66), "HARD MODE", "play_hard", false, 28)
			button(Rect2(130, h * 0.39 + 183, 460, 66), "UPGRADES", "upgrades", false, 28)
			button(Rect2(130, h * 0.39 + 264, 460, 66), "COLLECTION", "collection", false, 28)
			button(Rect2(130, h * 0.39 + 345, 224, 66), "BESTIARY", "bestiary", false, 25)
			button(Rect2(366, h * 0.39 + 345, 224, 66), "MUTATION BOOK", "mutation_book", false, 20)
			button(Rect2(130, h * 0.39 + 426, 460, 66), "SETTINGS", "settings", false, 28)
			goo_chip(Vector2(360, h * 0.39 + 530))
			profile_bar(Vector2(360, h * 0.39 - 72), 460.0)
			var best = "BEST  SECTOR %d   ·   %d KILLS" % [int(g.best["sector"]), int(g.best["kills"])]
			rbox(Rect2(110, h - 168, 500, 52), Color(0, 0, 0, 0.45), 26)
			txt(best, Vector2(360, h - 133), 21, Color("ffd24d"), 1, bold)
			txt("SLIME HOUR  " + g.GAME_VERSION, Vector2(360, h - 34), 18, Color("9db2ce"), 1, bold)
			button(Rect2(16, 22, 174, 44), "DEBUG LAB", "debug_open", false, 18)
		"characters":
			paint_portrait_characters()
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
		"bestiary":
			paint_portrait_bestiary()
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
			# Preserve source aspect ratio. The old rectangular stretch visibly squashed card art.
			var source_size: Vector2 = art.get_size()
			if source_size.x > 0.0 and source_size.y > 0.0:
				draw_texture_rect(art, CollectionGrid.aspect_fit(source_size, r.grow(-3)), false)
		rbox(r, Color(0, 0, 0, 0), 14, Color(rc, 0.9), 2)
	else:
		var cat = str(info.get("catid", ""))
		CardArt.glyph(self, cat, r.get_center(), minf(r.size.x, r.size.y) * 0.36, CardArt.hue(cat))

## A card that is ONLY its picture (arsenal grid, result screen): tinted tile + icon when art is missing.
func card_tile(r: Rect2, id: String) -> void:
	var c = g.card_by_id[id]
	var rc: Color = RCOL[int(c["rarity"])]
	var art = (g.tex("res://assets/cards/hydra.svg") if id == "hydra" else (g.tex("res://assets/cards/%s.webp" % id) if id in ["double_tap", "twin_barrels"] else g.tex("res://assets/cards/%s.png" % id)))
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
	if chest:
		var treasure_icon = g.tex("res://assets/ui/chest.svg")
		if treasure_icon != null:
			draw_texture_rect(treasure_icon, Rect2(574, 32, 90, 90), false)
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
		["VFX QUALITY", str(g.settings.get("vfx_quality", "medium")).to_upper(), "vfx_quality"],
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
	txt("VERSION  " + g.GAME_VERSION, Vector2(360, g.ui_height - 20), 18, Color("9db2ce"), 1, bold)

func portrait_collection_cat(delta: int) -> void:
	var cats = g.categories.keys()
	cats.append("weapons")
	var idx = cats.find(collection_cat)
	collection_cat = str(cats[posmod(idx + delta, cats.size())])
	collection_page = 0
	selected_collection_item = null

func paint_portrait_collection() -> void:
	var h = g.ui_height
	portrait_bg()
	txt("COLLECTION", Vector2(360, 92), 56, Color.WHITE, 1, bold, 6)
	button(Rect2(28, 124, 96, 72), "<", "mobile_cat_prev", false, 34)
	var cat_label = {"weapons": "GUNS"}.get(collection_cat, str(g.categories.get(collection_cat, "")).to_upper())
	rbox(Rect2(140, 128, 440, 62), Color(0, 0, 0, 0.5), 31)
	txt(cat_label, Vector2(360, 170), fit(cat_label, 420, 28), Color("ffd24d"), 1, bold, 3)
	button(Rect2(596, 124, 96, 72), ">", "mobile_cat_next", false, 34)
	var items = get_collection_items()
	var cols = CollectionGrid.columns(true)
	var rows = CollectionGrid.visible_rows(true, h)
	collection_page = CollectionGrid.clamp_row(items.size(), cols, rows, collection_page)
	var shown = CollectionGrid.indices(items.size(), cols, rows, collection_page)
	for i in range(shown.size()):
		var index = int(shown[i])
		var col = i % cols
		var row = int(i / cols)
		var tile = Rect2(30.0 + col * 336.0, 213.0 + row * CollectionGrid.PORTRAIT_STEP, 318.0, CollectionGrid.PORTRAIT_TILE_HEIGHT)
		mini_card(tile, collection_info(items[index]), items[index] == selected_collection_item)
		buttons.append({"rect": tile, "action": "select_card_%d" % index})
	if items.is_empty():
		txt("NO CARDS IN THIS CATEGORY", Vector2(360, 376), 24, Color("aab7d2"), 1, bold)
	collection_scrollbar(Rect2(702, 213, 8, maxf(110.0, h - 398.0)), items.size(), cols, rows)
	txt("SWIPE UP OR DOWN TO BROWSE  ·  " + CollectionGrid.view_label(items.size(), cols, rows, collection_page),
		Vector2(360, h - 186), 19, Color("bbd4e6"), 1, bold)
	button(Rect2(190, h - 122, 340, 78), "BACK", "back", true, 32)
	if selected_collection_item != null:
		var info = collection_info(selected_collection_item)
		buttons.clear()
		collection_track = Rect2()
		dim(0.9)
		if selected_collection_item["type"] == "gun_new":
			var gun = g.weapon_db[selected_collection_item["gun"]]
			# Use the full portrait viewport, reserving the bottom for CLOSE.
			panel(Rect2(72, 118, 576, h - 278), PANEL, PANEL_EDGE, 3)
			var ar = Rect2(105, 172, 510, minf(360.0, maxf(190.0, h * 0.27)))
			card_art(ar, info, Color("9adbf8"))
			txt(str(info["title"]).to_upper(), Vector2(360, ar.end.y + 45),
				fit(str(info["title"]).to_upper(), 520, 35, bold, 18), Color.WHITE, 1, bold)
			var desc_bottom = wrap_text(str(info["desc"]), 101, ar.end.y + 78,
				518, 22, Color("dbe7f2"), 28, body, true, 4)
			var lv3_top = desc_bottom + 26
			txt("LEVEL 3", Vector2(105, lv3_top), 22, Color("94dfff"), 0, bold)
			var lv5_top = wrap_text(str(gun["lv3"]), 105, lv3_top + 34, 505, 20,
				Color("e4f3ff"), 26, body, false, 3) + 27
			txt("LEVEL 5", Vector2(105, lv5_top), 22, Color("ffd24d"), 0, bold)
			wrap_text(str(gun["lv5"]), 105, lv5_top + 34, 505, 19,
				Color("fff1b9"), 25, body, false, 4)
		else:
			var detail_h = minf(640.0, h - 420.0)
			draw_card(Rect2(100, 130, 520, detail_h), info, false, 1.0, -1)
		button(Rect2(190, h - 130, 340, 84), "CLOSE", "mobile_close_detail", true, 32)

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
	rbox(Rect2(448, 8, 384, 82), Color(0.03, 0.06, 0.14, 0.9), 12, Color("355477"), 1)
	txt("SECTOR %d" % g.sector, Vector2(640, 36), 28, Color.WHITE, 1, bold, 5)
	var pw = 360.0
	var px = 640.0 - pw * 0.5
	var prog = g.progress() if g.phase == "fight" else 1.0
	rbox(Rect2(px, 44, pw, 12), Color(0, 0, 0, 0.6), 6)
	rbox(Rect2(px, 44, maxf(12.0, pw * prog), 12), Color("4fe0ff"), 6)
	if g.phase == "fight":
		var left = g.enemies_left()
		var lt = "BOSS INCOMING" if g.is_boss_sector() and not g.boss_spawned and prog > 0.6 else ("%d ENEMIES LEFT" % left if left > 0 else "FINISH THEM")
		txt(lt, Vector2(640, 78), 15, Color("ffd24d") if left < 15 else Color("c8d8eb"), 1, bold, 3)
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
			txt("DRAG LOWER LEFT TO MOVE   ·   TAP DASH TO DODGE   ·   TAP BASH TO STRIKE   ·   GUNS AUTO-TARGET & FIRE", Vector2(640, 600), 17, Color(1, 1, 1, 0.85), 1, body, 4)
		else:
			txt("WASD move   ·   LEFT CLICK gun 1   ·   RIGHT CLICK gun 2   ·   R reload   ·   SPACE dash   ·   F bash   ·   TAB arsenal", Vector2(640, 600), 17, Color(1, 1, 1, 0.85), 1, body, 4)
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
	var weapon_name = Weapons.display_name(g, w).to_upper()
	txt(weapon_name, pos + Vector2(72, 27), fit(weapon_name, 102, 15, bold, 10), Color.WHITE, 0, bold, 3)
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
		if kind in ["disc", "boomerang"]:
			txt("READY", bar.position + Vector2(50, 9), 10, Color("d2ffd6"), 1, bold, 2)
		elif kind == "flame":
			txt("FUEL", bar.position + Vector2(50, 9), 10, Color("ffce85"), 1, bold, 2)

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
	# Bash button: independent melee cooldown, separate from dash charges.
	var bp: Vector2 = g.bash_btn_pos
	var br: float = g.bash_btn_r
	var bash_ready = float(h.get("bash_cd", 0.0)) <= 0.0
	draw_circle(bp + Vector2(0, 7), br, Color(0, 0, 0, 0.35))
	draw_circle(bp, br, Color("d29a36") if bash_ready else Color("273142"))
	draw_circle(bp, br * 0.75, Color("ffdda0") if bash_ready else Color("495367"))
	if not bash_ready:
		var elapsed = 1.0 - clampf(float(h.get("bash_cd", 0.0)) / 1.25, 0.0, 1.0)
		draw_arc(bp, br + 6, -PI * 0.5, -PI * 0.5 + TAU * elapsed, 32, Color("7dffcf"), 5.0)
	txt("BASH", bp + Vector2(0, 9), 24, Color("42230f") if bash_ready else Color("9da7b8"), 1, bold, 3)
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
			var desc_text = str(c["desc"])
			if not owned_view:
				var adapted = Compatibility.card_interaction(g, str(o["id"]))
				if adapted != "":
					desc_text += "  ACTIVE: " + adapted
			return {"title": c["name"], "desc": desc_text, "rar": int(c["rarity"]), "cat": g.categories.get(c["cat"], ""),
				"catc": CAT_COLOR, "catid": str(c["cat"]), "art": (g.tex("res://assets/cards/hydra.svg") if str(o["id"]) == "hydra" else (g.tex("res://assets/cards/%s.webp" % o["id"]) if str(o["id"]) in ["double_tap", "twin_barrels"] else g.tex("res://assets/cards/%s.png" % o["id"]))), "foot": foot,
				"stack": Effects.stack_preview(g, str(o["id"]), owned_view),
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
			return {"title": "EVOLVE: " + str(Weapons.EVOLVED_NAMES.get(w2["id"], "EX")), "desc": Weapons.evolution_description(w2),
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
	# Weapon descriptions need more readable lines than decorative artwork.
	var weapon_offer = str(info.get("cat", "")) in ["NEW GUN", "GUN UPGRADE", "EVOLUTION"]
	var art_height = minf(r.size.x - 24, r.size.y * (0.36 if weapon_offer else 0.53))
	var art_r = Rect2(r.position + Vector2(12, 46), Vector2(r.size.x - 24, art_height))
	card_art(art_r, info, rc)
	# title + desc
	var ty = art_r.end.y + 34
	var title = str(info["title"]).to_upper()
	txt(title, Vector2(r.get_center().x, ty), fit(title, r.size.x - 24, 26, bold, 14), Color.WHITE, 1, bold, 4)
	var stack = str(info.get("stack", ""))
	var foot = str(info.get("foot", ""))
	var has_stats = foot.contains("DMG") or foot.contains("MAG")
	var lines = maxi(2, int((r.end.y - (68 if has_stats else 44) - (ty + 26) - (22 if stack != "" else 0)) / 20.0))
	var y = wrap_text(str(info["desc"]), r.position.x + 16, ty + 26, r.size.x - 32, 16, Color("dbe4f5"), 20, body, true, lines)
	if stack != "":
		txt(stack, Vector2(r.get_center().x, minf(y + 4, r.end.y - 40)), fit(stack, r.size.x - 24, 15, bold, 10), Color("7dff9a"), 1, bold, 3)
	# footer: rarity chip + owned/new
	var rl = str(info.get("rarlabel", RARITY[rar])) if not bool(info.get("cursed", false)) else "CURSED"
	var cw = bold.get_string_size(rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20
	rbox(Rect2(r.position.x + 12, r.end.y - 36, cw, 24), rc, 12)
	txt(rl, Vector2(r.position.x + 12 + cw * 0.5, r.end.y - 19), 14, Color("0b1224"), 1, bold)
	if foot != "":
		var is_new = foot == "NEW"
		if has_stats:
			txt(foot, Vector2(r.get_center().x, r.end.y - 48), fit(foot, r.size.x - 24, 13, bold, 10), Color("ffd24d"), 1, bold, 2)
		else:
			txt(foot + ("!" if is_new else ""), Vector2(r.end.x - 14, r.end.y - 17), fit(foot, r.size.x - cw - 40, 15, bold, 10), Color("7dff9a") if is_new else Color("ffd24d"), 2, bold, 3)

func paint_levelup() -> void:
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, minf(0.78, g.offer_t * 3.0)))
	var chest = g.offer_mode == "chest"
	var head = "TREASURE!" if chest else "LEVEL UP!"
	if chest:
		var treasure_icon = g.tex("res://assets/ui/chest.svg")
		if treasure_icon != null:
			draw_texture_rect(treasure_icon, Rect2(492, 42, 82, 82), false)
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
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.8))
	txt("YOUR HANDS ARE FULL", Vector2(640, 90), 48, Color("ffd24d"), 1, bold, 7)
	txt("drop a gun for the new one", Vector2(640, 122), 18, Color.WHITE, 1, bold, 4)
	draw_card(Rect2(515, 150, 250, 380), offer_info({"type": "gun_new", "gun": g.replace_gun, "tier": g.replace_tier}), false, 1.0, -1)
	for i in range(g.guns.size()):
		var w = g.guns[i]
		button(Rect2(140 + i * 360 if g.guns.size() > 2 else (200 + i * 640), 560, 300, 56), "DROP %s [%d]" % [Weapons.display_name(g, w).to_upper(), i + 1], "slot%d" % i, false, 20)
	button(Rect2(540, 640, 200, 50), "KEEP MINE", "keep", true, 20)

# ================================================================= arsenal
func paint_arsenal() -> void:
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.88))
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
		wrap_text(str(d["desc"]), r.position.x + 12, r.position.y + 102, 336, 12, Color("9fb0c8"), 15, body, false, 2)
		# Avoid clipping the full level-five paragraph in a 172px Arsenal tile.
		# Full details (including Evolution) live in the Collection inspector.
		if int(w["lvl"]) >= 3:
			var bonus3 = "LV3: " + str(d["lv3"])
			txt(bonus3, r.position + Vector2(12, 142), fit(bonus3, 336, 12, body, 10), Color("94dfff"), 0, body)
		if int(w["lvl"]) >= 5:
			var bonus5 = "LV5: " + str(d.get("lv5_brief", d["lv5"]))
			txt(bonus5, r.position + Vector2(12, 158), fit(bonus5, 336, 12, body, 10), Color("ffd24d"), 0, body)
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
## Development sandbox: always overlays every game state, including treasure
## choices, boss results, route map and shops. Only its own buttons stay live.
func paint_debug_panel() -> void:
	var w = sw()
	var h = sh()
	var px = 15.0 if g.portrait else 122.0
	var pw = w - 30.0 if g.portrait else 1036.0
	var py = 28.0 if g.portrait else 27.0
	var ph = h - 56.0 if g.portrait else 665.0
	draw_rect(Rect2(0, 0, w, h), Color("020714", 0.95))
	panel(Rect2(px, py, pw, ph), Color("111d35"), Color("5beaff"), 3.0)
	var heading = "DEBUG LAB  //  " + g.GAME_VERSION
	txt(heading, Vector2(px + 22, py + 44), fit(heading, pw - 180, 35, bold), Color("8ff2ff"), 0, bold, 2)
	button(Rect2(px + pw - 143, py + 12, 122, 48), "CLOSE  F3", "debug_close", false, 19)
	var progress_label = "SANDBOX / NO SAVES   |   SECTOR %d   |   FPS %d" % [g.sector, Engine.get_frames_per_second()]
	txt(progress_label, Vector2(px + 22, py + 81), fit(progress_label, pw - 44, 17, bold, 12), Color("ffd268"), 0, bold)
	var tabs = ["ROUTE", "CARDS", "WEAPONS", "ENEMIES", "TOOLS"]
	var pad = 13.0
	var tabw = (pw - 42.0 - pad * 4.0) / 5.0
	for i in range(tabs.size()):
		button(Rect2(px + 20 + i * (tabw + pad), py + 103, tabw, 47), tabs[i], "debug_tab_" + tabs[i], g.debug_tab == tabs[i], 19)
	var y = py + 177.0
	match g.debug_tab:
		"ROUTE":
			txt("JUMP DIRECTLY TO ANY SECTOR", Vector2(px + 24, y), 24, Color.WHITE, 0, bold)
			var quick = [1, 5, 8, 10, 15, 20, 25, 30, 40]
			var gridw = (pw - 65.0) / 3.0
			for i in range(quick.size()):
				var row = int(i / 3)
				var col = i % 3
				button(Rect2(px + 22.0 + col * (gridw + 8.0), y + 20.0 + row * 49.0, gridw, 42.0), "SECTOR %d" % quick[i], "debug_sector_%d" % quick[i], false, 19)
			var by = y + 178.0
			var stepw = (pw - 65.0) / 4.0
			for i in range(4):
				var steps = [-5, -1, 1, 5]
				var n = int(steps[i])
				button(Rect2(px + 22.0 + i * (stepw + 8.0), by, stepw, 43.0), "%+d SECTORS" % n, "debug_step_%d" % n, false, 18)
			txt("ENTER ANY ROAD OR STOP", Vector2(px + 24, by + 76.0), 24, Color.WHITE, 0, bold)
			var destinations = ["map", "fight", "elite", "hell", "boss", "shop", "rest", "treasure", "event"]
			for i in range(destinations.size()):
				var row = int(i / 3)
				var col = i % 3
				var label = destinations[i].to_upper()
				if label == "REST":
					label = "CAMPFIRE"
				button(Rect2(px + 22.0 + col * (gridw + 8.0), by + 91.0 + row * 50.0, gridw, 44.0), label, "debug_place_" + destinations[i], destinations[i] == "boss", 19)
		"TOOLS":
			txt("TEST A FIGHT WITHOUT GRINDING", Vector2(px + 24, y), 24, Color.WHITE, 0, bold)
			var hw = (pw - 65.0) * 0.5
			button(Rect2(px + 22, y + 37, hw, 60), "START DEBUG RUN", "debug_start", true, 23)
			button(Rect2(px + 30 + hw, y + 37, hw, 60), "OPEN ROUTE MAP", "debug_map", false, 23)
			button(Rect2(px + 22, y + 116, hw, 60), "FULL HEAL", "debug_heal", false, 23)
			button(Rect2(px + 30 + hw, y + 116, hw, 60), "+500 GOLD", "debug_gold", false, 23)
			button(Rect2(px + 22, y + 195, hw, 60), "INVINCIBLE: ON" if g.debug_godmode else "INVINCIBLE: OFF", "debug_god", g.debug_godmode, 22)
			button(Rect2(px + 30 + hw, y + 195, hw, 60), "CLEAR ENEMIES", "debug_kill", false, 23)
			wrap_text("F3: close/open the Lab  |  F4: performance numbers  |  Debug runs never overwrite your normal save or record.", px + 24, y + 321, pw - 50, 20, Color("b8c6e3"), 26, body, false, 3)
		_:
			var groups: Array = DebugLab.categories(g, g.debug_tab)
			if not groups.has(g.debug_category):
				g.debug_category = "ALL"
			if g.debug_tab == "WEAPONS":
				txt("EQUIP INTO SLOT:", Vector2(px + 24, y - 1), 20, Color("d7faff"), 0, bold)
				for i in range(3):
					button(Rect2(px + 240 + i * 124, y - 26, 112, 42), "SLOT %d" % (i + 1), "debug_slot_%d" % i, g.debug_slot == i, 18)
			elif g.debug_tab == "CARDS":
				txt("GRANT ANY CARD  //  FILTER BY EFFECT TYPE", Vector2(px + 24, y - 1), 18, Color("d7faff"), 0, bold)
			else:
				txt("SPAWN ENEMIES  //  NORMAL, BOSSES OR MUTATIONS", Vector2(px + 24, y - 1), 18, Color("d7faff"), 0, bold)
			if g.debug_tab == "ENEMIES":
				var catw = (pw - 53.0) / 4.0
				for i in range(groups.size()):
					var cat = str(groups[i])
					var count = DebugLab.items(g, g.debug_tab, cat, g.debug_query).size()
					button(Rect2(px + 22.0 + i * (catw + 3.0), y + 25, catw, 37),
						"%s  %d" % [cat, count], "debug_category_" + cat, cat == g.debug_category, 16)
			else:
				var cat_index = maxi(0, groups.find(g.debug_category))
				button(Rect2(px + 22, y + 25, 72, 37), "<", "debug_cat_prev", false, 22, groups.size() > 1)
				button(Rect2(px + pw - 94, y + 25, 72, 37), ">", "debug_cat_next", false, 22, groups.size() > 1)
				var current_category = "%s   (%d / %d)" % [g.debug_category.replace("_", " "), cat_index + 1, groups.size()]
				rbox(Rect2(px + 105, y + 25, pw - 210, 37), Color("203b58"), 9, Color("3d7291"), 1)
				txt(current_category, Vector2(px + pw * 0.5, y + 49), fit(current_category, pw - 235, 17, bold, 11), Color("d9f9ff"), 1, bold)
			var search_rect = Rect2(px + 22, y + 72, pw - 241, 43)
			rbox(search_rect, Color("0c1729"), 9, Color("5b91b6"), 2)
			var search_value = "SEARCH:  " + (g.debug_query if g.debug_query != "" else "type a name, ID or ability...")
			txt(search_value, Vector2(search_rect.position.x + 13, search_rect.position.y + 28),
				fit(search_value, search_rect.size.x - 25, 18, body, 11),
				Color.WHITE if g.debug_query != "" else Color("91a9c6"), 0, body)
			button(Rect2(px + pw - 208, y + 72, 186, 43), "CLEAR SEARCH", "debug_search_clear", false, 17, g.debug_query != "")
			var entries: Array = DebugLab.items(g, g.debug_tab, g.debug_category, g.debug_query)
			var n = entries.size()
			var page_count = maxi(1, int(ceil(float(n) / float(DebugLab.ITEM_PAGE_SIZE))))
			var page = clampi(g.debug_page, 0, page_count - 1)
			var first = page * DebugLab.ITEM_PAGE_SIZE
			var cw = (pw - 56.0) * 0.5
			var row_start = y + 125.0
			if n == 0:
				txt("NO RESULTS - TRY A DIFFERENT CATEGORY OR SEARCH", Vector2(px + pw * 0.5, row_start + 105),
					fit("NO RESULTS - TRY A DIFFERENT CATEGORY OR SEARCH", pw - 60, 19, bold, 11),
					Color("a9bfd8"), 1, bold)
			for i in range(first, mini(n, first + DebugLab.ITEM_PAGE_SIZE)):
				var entry: Dictionary = entries[i]
				var col = (i - first) % 2
				var row = int((i - first) / 2)
				var id = str(entry["id"])
				var label = str(entry["label"]).to_upper()
				if g.debug_tab == "CARDS":
					label += "  x%d" % int(g.owned.get(id, 0))
				var action = ("debug_card_" if g.debug_tab == "CARDS" else ("debug_gun_" if g.debug_tab == "WEAPONS" else "debug_spawn_")) + id
				var tile = Rect2(px + 22.0 + col * (cw + 12.0), row_start + row * 52.0, cw, 46.0)
				var hovered = tile.has_point(g.mouse_screen)
				var accent = Color("dd9eff") if str(entry["category"]) == "MUTATIONS" else (Color("ffb59a") if str(entry["category"]) == "BOSSES" else Color("5beaff"))
				rbox(tile, Color("223a57") if hovered else Color("16273f"), 9, accent, 2 if hovered else 1)
				txt(label, Vector2(tile.position.x + 13, tile.position.y + 20), fit(label, tile.size.x - 26, 17, bold, 10), Color.WHITE, 0, bold)
				var detail = str(entry.get("detail", ""))
				if detail.length() > 64:
					detail = detail.substr(0, 61) + "..."
				txt(detail, Vector2(tile.position.x + 13, tile.position.y + 37), fit(detail, tile.size.x - 26, 13, body, 9), Color("a8c5dc"), 0, body)
				buttons.append({"rect": tile, "action": action})
			button(Rect2(px + 23.0, y + 390.0, 178.0, 43), "PREVIOUS", "debug_prev", false, 18, page > 0)
			var pager = "PAGE %d / %d   -   %d RESULTS" % [page + 1, page_count, n]
			txt(pager, Vector2(px + pw * 0.5, y + 418), fit(pager, pw - 420, 17, bold, 12), Color("ffd268"), 1, bold)
			button(Rect2(px + pw - 201.0, y + 390.0, 178.0, 43), "NEXT", "debug_next", false, 18, page < page_count - 1)
	var status = "LAST: " + g.debug_notice if g.debug_notice != "" else "Choose a tab or jump directly to a test sector."
	txt(status, Vector2(px + 24, py + ph - 30), fit(status, pw - 48, 18, bold, 12), Color("a8ffc1"), 0, bold)

func paint_menu_bg() -> void:
	draw_rect(g.landscape_rect(), Color("07080f"))
	var art = g.tex("res://assets/ui/title.png")
	if art != null:
		var drift = sin(g.anim_t * 0.2) * 12.0
		draw_texture_rect(art, Rect2(g.landscape_left - 20.0 + drift, -12, g.landscape_width + 40.0, 744), false, Color(0.6, 0.6, 0.7))
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.35))
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
	panel(Rect2(380, 50, 520, 620), Color(0.025, 0.045, 0.09, 0.92), Color("304868"), 2)
	glitch_txt("SLIME HOUR", Vector2(640, 172), 92, Color.WHITE)
	txt("//  D O N ' T   S T O P   S H O O T I N G  //", Vector2(640, 212), 20, NEON, 1, body)
	profile_bar(Vector2(640, 262), 380.0)
	button(Rect2(450, 290, 380, 70), "PLAY", "play", true, 34)
	button(Rect2(450, 376, 185, 56), "HARD MODE", "play_hard", false, 22)
	button(Rect2(645, 376, 185, 56), "UPGRADES", "upgrades", false, 22)
	button(Rect2(450, 448, 121, 56), "COLLECTION", "collection", false, 17)
	button(Rect2(580, 448, 121, 56), "BESTIARY", "bestiary", false, 17)
	button(Rect2(710, 448, 121, 56), "MUTATIONS", "mutation_book", false, 16)
	button(Rect2(450, 520, 185, 50), "SETTINGS", "settings", false, 20)
	button(Rect2(645, 520, 185, 50), "QUIT", "quit", false, 20)
	if g.update_available:
		button(Rect2(510, 577, 260, 42), "UPDATE " + g.update_version, "update", true, 19)
	goo_chip(Vector2(640, 635))
	txt("BEST  SECTOR %d   /   %d KILLS   /   LV %d" % [g.best["sector"], g.best["kills"], g.best["level"]], Vector2(640, 688), 16, MUTED, 1, body)
	txt(g.GAME_VERSION, Vector2(1244, 699), 16, Color("adc0d7"), 2, bold)
	button(Rect2(32, 640, 175, 44), "DEBUG LAB  F3", "debug_open", false, 17)


## Character identities are presentation/data, not permanent power unlocks.
func paint_characters() -> void:
	paint_menu_bg()
	panel(Rect2(28, 38, 1224, 632), Color("0a1020", 0.95), Color("467f95"), 2)
	txt("CHOOSE YOUR RUNNER", Vector2(640, 112), 54, Color.WHITE, 1, bold, 4)
	txt(("HARD ROAD" if g.hard_mode else "STANDARD ROAD") + "  /  STARTING WEAPON AND A SMALL TRADE-OFF", Vector2(640, 148), 18, Color("a4bed2"), 1, bold)
	var selected = Characters.get_character(g.selected_character)
	for i in range(Characters.ROSTER.size()):
		var ch = Characters.ROSTER[i]
		var active = g.selected_character == str(ch["id"])
		var x = 55.0 + i * 236.0
		var y = 182.0
		var r = Rect2(x, y, 222.0, 315.0)
		var accent = Color(str(ch["color"]))
		rbox(r, Color("243750") if active else Color("111b2c"), 14, accent if active else Color("3a4e65"), 3 if active else 1)
		draw_circle(Vector2(x + 111, y + 58), 38, Color("101a2c"))
		draw_circle(Vector2(x + 111, y + 58), 27, accent.darkened(0.25))
		draw_circle(Vector2(x + 100, y + 53), 4, Color.WHITE)
		draw_circle(Vector2(x + 122, y + 53), 4, Color.WHITE)
		draw_line(Vector2(x + 104, y + 72), Vector2(x + 118, y + 72), Color("152035"), 3.0)
		var art = g.tex("res://assets/weapons/%s.png" % str(ch["weapon"]))
		if art != null:
			draw_texture_rect(art, Rect2(x + 137, y + 48, 57, 57), false)
		txt(str(ch["name"]), Vector2(x + 111, y + 135), 25, Color.WHITE, 1, bold)
		txt(str(ch["role"]).to_upper(), Vector2(x + 111, y + 158), fit(str(ch["role"]), 196, 14, bold, 11), accent, 1, bold)
		txt(str(g.weapon_db[ch["weapon"]]["name"]).to_upper(), Vector2(x + 111, y + 189), 17, Color("e3ecf5"), 1, bold)
		txt(str(ch["perks"]), Vector2(x + 111, y + 224), fit(str(ch["perks"]), 198, 16, body, 12), Color("b0f4c0"), 1, body)
		txt(str(ch["tradeoff"]), Vector2(x + 111, y + 253), fit(str(ch["tradeoff"]), 198, 16, body, 12), Color("ffbaad") if str(ch["tradeoff"]) != "No drawback" else MUTED, 1, body)
		button(Rect2(x + 15, y + 270, 192, 35), "SELECTED" if active else "SELECT", "character_pick_" + str(ch["id"]), active, 15)
	txt("STARTING WEAPONS DO NOT PERMANENTLY UNLOCK THE GUN", Vector2(640, 533), 16, Color("92aec4"), 1, body)
	txt("READY:  " + str(selected["name"]) + "  /  " + str(g.weapon_db[selected["weapon"]]["name"]), Vector2(640, 567), 20, Color("e9fbff"), 1, bold)
	button(Rect2(370, 592, 540, 59), "START RUN", "character_start", true, 26)
	button(Rect2(73, 593, 235, 54), "BACK", "character_back", false, 21)

func paint_portrait_characters() -> void:
	var h = g.ui_height
	portrait_bg()
	txt("CHOOSE YOUR RUNNER", Vector2(360, 90), 42, Color.WHITE, 1, bold, 3)
	txt("SMALL AFFINITIES  /  BALANCED STARTS", Vector2(360, 124), 19, Color("9db4c9"), 1, bold)
	var row_h = minf(155.0, maxf(94.0, (h - 355.0) / 5.0 - 10.0))
	var top = 150.0
	for i in range(Characters.ROSTER.size()):
		var ch = Characters.ROSTER[i]
		var active = g.selected_character == str(ch["id"])
		var y = top + i * (row_h + 8.0)
		var accent = Color(str(ch["color"]))
		rbox(Rect2(30.0, y, 660.0, row_h), Color("243750") if active else Color("111b2c"), 13, accent if active else Color("405670"), 3 if active else 1)
		draw_circle(Vector2(83.0, y + 43.0), 27.0, accent.darkened(0.28))
		draw_circle(Vector2(74.0, y + 37.0), 3.6, Color.WHITE)
		draw_circle(Vector2(92.0, y + 37.0), 3.6, Color.WHITE)
		txt(str(ch["name"]) + "   /   " + str(g.weapon_db[ch["weapon"]]["name"]), Vector2(137.0, y + 29.0), fit(str(ch["name"]) + str(g.weapon_db[ch["weapon"]]["name"]), 340, 22, bold, 15), Color.WHITE, 0, bold)
		txt(str(ch["perks"]), Vector2(137.0, y + 56.0), 17, Color("b0f4c0"), 0, body)
		txt(str(ch["tradeoff"]), Vector2(137.0, y + 80.0), 16, Color("ffbaad") if str(ch["tradeoff"]) != "No drawback" else MUTED, 0, body)
		button(Rect2(505, y + row_h * 0.5 - 23.0, 160, 46), "SELECTED" if active else "SELECT", "character_pick_" + str(ch["id"]), active, 17)
	txt("GUN CHOICES DO NOT GRANT UNLOCKS", Vector2(360, h - 191.0), 15, Color("95b0c4"), 1, body)
	button(Rect2(67, h - 164.0, 585, 75.0), "START RUN", "character_start", true, 29)
	button(Rect2(170, h - 79.0, 380, 54.0), "BACK", "character_back", false, 19)

## Fully in-game update panel: accurate bytes, source, download stage,
## recovery and explicit verified install. No console or external browser.
func paint_update_screen() -> void:
	paint_menu_bg()
	var client = g.in_game_updater
	var r = Rect2(326, 75, 628, 566)
	panel(r, Color("101b34"), Color("5ce5e9"), 3.0)
	glitch_txt("GAME UPDATE", Vector2(640, 172), 64, Color.WHITE)
	txt("SLIME HOUR  " + str(client.local_version) + "  ->  " + str(client.latest),
		Vector2(640, 225), 21, Color("ffd24d"), 1, bold)
	var phase_text = str(client.status)
	var headline = "GETTING READY"
	match phase_text:
		"checking": headline = "FINDING THE BEST DOWNLOAD"
		"downloading": headline = "DOWNLOADING UPDATE"
		"verifying": headline = "VERIFYING FILE INTEGRITY"
		"ready": headline = "UPDATE VERIFIED"
		"error": headline = "UPDATE INTERRUPTED"
		"installing": headline = "RESTARTING SLIME HOUR"
		"available": headline = "UPDATE AVAILABLE"
	txt(headline, Vector2(640, 301), 27, Color("83f2ff") if phase_text != "error" else Color("ff718b"), 1, bold)
	var downloaded = float(client.transferred_bytes)
	var total = float(client.total_bytes)
	var ratio = clampf(downloaded / maxf(1.0, total), 0.0, 1.0)
	var line = Rect2(392, 335, 496, 30)
	rbox(line, Color("263752"), 10.0)
	if phase_text in ["downloading", "verifying", "ready", "installing"] and total > 0.0:
		rbox(Rect2(line.position, Vector2(maxf(6.0, line.size.x * ratio), line.size.y)),
			Color("6cefee") if phase_text != "ready" else Color("a4ff99"), 8.0)
	var percent = int(round(ratio * 100.0))
	var size_label = ""
	if total > 0.0:
		size_label = "%.1f / %.1f MiB   (%d%%)" % [downloaded / 1048576.0, total / 1048576.0, percent]
	else:
		size_label = "CHECKING RELEASE..."
	txt(size_label, Vector2(640, 400), 21, Color("dde9f5"), 1, bold)
	var description = str(client.message)
	wrap_text(description, 402, 424, 470, 20, Color("acc1d3"), 26, body, false, 3)
	var foot = "VERIFIED GITHUB RELEASE  /  SHA-256 CHECKED"
	txt(foot, Vector2(640, 509), 17, Color("89a8bf"), 1, body)
	match phase_text:
		"ready":
			button(Rect2(414, 548, 452, 64), "INSTALL & RESTART", "update_restart", true, 28)
		"error":
			button(Rect2(414, 548, 218, 62), "RETRY", "update_retry", true, 22)
			button(Rect2(649, 548, 218, 62), "BACK", "update_cancel", false, 22)
		"installing":
			txt("CLOSING THE GAME SAFELY...", Vector2(640, 581), 20, Color("9bffd6"), 1, bold)
		_:
			button(Rect2(414, 548, 452, 62), "CANCEL", "update_cancel", false, 23)

func paint_pause() -> void:
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.75))
	txt("PAUSED", Vector2(640, 200), 80, Color.WHITE, 1, bold, 10)
	button(Rect2(500, 260, 280, 62), "RESUME", "resume", true, 30)
	button(Rect2(500, 336, 280, 54), "SETTINGS", "settings", false, 24)
	button(Rect2(500, 402, 280, 54), "MAIN MENU", "menu", false, 24)
	txt("SLIME HOUR  " + g.GAME_VERSION, Vector2(1244, 696), 16, Color("adc0d7"), 2, bold)

func cursor_label() -> String:
	var c = float(g.settings["cursor"])
	return "S" if c < 0.9 else ("M" if c < 1.2 else ("L" if c < 1.6 else "XL"))

func paint_settings() -> void:
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.8))
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
		["VFX QUALITY", str(s.get("vfx_quality", "medium")).to_upper(), "vfx_quality"],
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
	txt("SLIME HOUR  " + g.GAME_VERSION, Vector2(1244, 695), 16, Color("adc0d7"), 2, bold)

## Locked cards show their rarity but not what they do.
func collection_info(item: Dictionary) -> Dictionary:
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
	draw_rect(g.landscape_rect(), Color(0.02, 0.02, 0.06, 0.78))
	txt("COLLECTION", Vector2(640, 60), 52, Color.WHITE, 1, bold, 7)
	var cats = g.categories.keys()
	cats.append("weapons")
	var tx = 30.0
	for c in cats:
		var label = {"weapons": "GUNS"}.get(c, str(g.categories.get(c, c)))
		var w = bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		var rect = Rect2(tx, 80, w, 32)
		var sel = c == collection_cat
		var color = Color("ffd24d") if sel else CAT_COLOR
		slant(rect, color if sel else Color(color, 0.25), Color(0, 0, 0, 0), 8)
		txt(label, rect.get_center() + Vector2(0, 6), 16, Color("0a0e1a") if sel else Color.WHITE, 1, bold)
		buttons.append({"rect": rect, "action": "cat_" + c})
		tx += w + 5
	var items = get_collection_items()
	if selected_collection_item == null or not items.has(selected_collection_item):
		selected_collection_item = items[0] if not items.is_empty() else null
	var cols = CollectionGrid.columns(false)
	var rows = CollectionGrid.visible_rows(false)
	collection_page = CollectionGrid.clamp_row(items.size(), cols, rows, collection_page)
	var shown = CollectionGrid.indices(items.size(), cols, rows, collection_page)
	txt("SCROLL TO EXPLORE  /  SELECT ANY CARD  /  " + CollectionGrid.view_label(items.size(), cols, rows, collection_page),
		Vector2(32, 165), 18, Color("b1cbdf"), 0, bold)
	for i in range(shown.size()):
		var index = int(shown[i])
		var col = i % cols
		var row = int(i / cols)
		var tile = Rect2(30.0 + col * 219.0, 198.0 + row * 219.0, 206.0, 207.0)
		var item = items[index]
		mini_card(tile, collection_info(item), item == selected_collection_item)
		buttons.append({"rect": tile, "action": "select_card_%d" % index})
		if tile.has_point(g.mouse_screen):
			hover_card = item
	if items.is_empty():
		txt("NO CARDS IN THIS CATEGORY", Vector2(470, 390), 24, Color("aab7d2"), 1, bold)
	collection_scrollbar(Rect2(908, 200, 9, 424), items.size(), cols, rows)
	if hover_card == null and selected_collection_item != null:
		hover_card = selected_collection_item
	if hover_card != null:
		if hover_card["type"] == "gun_new":
			# Level-three / Level-five weapon notes must stay ABOVE the Back
			# button rather than spilling beneath the viewport.
			draw_collection_gun_details(Rect2(944, 124, 296, 505), collection_info(hover_card),
				g.weapon_db[hover_card["gun"]])
		else:
			draw_card(Rect2(944, 124, 296, 484), collection_info(hover_card), true, 1.0, -1)
	else:
		txt("HOVER OR SELECT A CARD", Vector2(1095, 380), 20, Color("6a7a98"), 1, bold)
	txt("%d cards  ·  %d guns   ·   MOUSE WHEEL / UP / DOWN" % [g.db_cards.size(), g.weapon_ids.size()],
		Vector2(32, 667), 17, Color("9fb8d0"), 0, bold, 3)
	button(Rect2(1028, 651, 215, 55), "BACK", "back", true, 24)

## Collection-only gun inspector: art, description and BOTH upgrade tiers in
## one bounded panel. No tooltip text is drawn behind the navigation buttons.
## Collection inspector: base identity plus ALL three upgrade tiers.
## Labels and text stay inside the 505px panel above the Back button.
func draw_collection_gun_details(r: Rect2, info: Dictionary, gun: Dictionary) -> void:
	panel(r, PANEL, Color("9fb5c7"), 3)
	rbox(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 33)),
		Color("354153"), 10)
	txt("WEAPON DETAILS", r.position + Vector2(18, 27),
		17, Color("e4edf5"), 0, bold)
	var art_rect = Rect2(r.position + Vector2(12, 49), Vector2(r.size.x - 24, 120))
	card_art(art_rect, info, Color("d7e9fc"))
	var name = str(info["title"]).to_upper()
	txt(name, Vector2(r.get_center().x, r.position.y + 199),
		fit(name, r.size.x - 25, 23, bold, 13), Color.WHITE, 1, bold)
	wrap_text(str(info["desc"]), r.position.x + 14, r.position.y + 222,
		r.size.x - 28, 13, Color("e4e9f2"), 17, body, true, 3)
	var div = r.position.y + 286
	draw_line(Vector2(r.position.x + 13, div), Vector2(r.end.x - 13, div), Color("637588"), 1.2)
	txt("LEVEL 3", r.position + Vector2(15, 307),
		14, Color("94dfff"), 0, bold)
	wrap_text(str(gun["lv3"]), r.position.x + 15, r.position.y + 325,
		r.size.x - 30, 13, Color("e4f3ff"), 16, body, false, 2)
	txt("LEVEL 5", r.position + Vector2(15, 377),
		14, Color("ffd24d"), 0, bold)
	wrap_text(str(gun["lv5"]), r.position.x + 15, r.position.y + 395,
		r.size.x - 30, 12, Color("fff1b9"), 16, body, false, 3)
	txt("EVOLUTION", r.position + Vector2(15, 446),
		14, Color("7dff9a"), 0, bold)
	var evo = Weapons.evolution_description({"id": gun["id"]})
	wrap_text(evo, r.position.x + 15, r.position.y + 467,
		r.size.x - 30, 12, Color("d5fce3"), 15, body, false, 3)


func mini_card(r: Rect2, info: Dictionary, selected: bool = false) -> void:
	var rc: Color = RCOL[int(info["rar"])]
	if bool(info.get("cursed", false)):
		rc = Color("ff3a4a")
	var hover = r.has_point(g.mouse_screen)
	rbox(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.48), 13)
	rbox(r, Color("142139") if selected else PANEL, 13, Color("f3e600") if selected else rc, 3 if selected or hover else 2)
	var art_h = minf(r.size.x - 18.0, r.size.y - 54.0)
	card_art(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, art_h)), info, rc)
	var name = str(info["title"]).to_upper()
	txt(name, Vector2(r.get_center().x, r.end.y - 29), fit(name, r.size.x - 16, 17, bold, 11), Color.WHITE, 1, bold, 2)
	var rarity = str(info.get("rarlabel", RARITY[int(info["rar"])]))
	txt(rarity, Vector2(r.get_center().x, r.end.y - 9), 12, rc, 1, bold)

## Tiny owned-card chip for the HUD strip: art, or category colour + icon.
func mini_tile(r: Rect2, id: String) -> void:
	var c = g.card_by_id[id]
	var art = (g.tex("res://assets/cards/hydra.svg") if id == "hydra" else (g.tex("res://assets/cards/%s.webp" % id) if id in ["double_tap", "twin_barrels"] else g.tex("res://assets/cards/%s.png" % id)))
	if art != null:
		draw_texture_rect(art, r, false)
	else:
		var hue = CardArt.hue(str(c["cat"]))
		rbox(r, hue.darkened(0.65), 6)
		CardArt.glyph(self, str(c["cat"]), r.get_center(), r.size.y * 0.32, hue)
	rbox(r.grow(1), Color(0, 0, 0, 0), 6, RCOL[int(c["rarity"])], 2)


# ================================================================= BESTIARY — dedicated enemy encyclopedia
const Bestiary = preload("res://scripts/Bestiary.gd")
const MutationRecipes = preload("res://scripts/EnemyMixes.gd")

func mutation_unlocked(kind: String) -> bool:
	return g.mutation_is_unlocked(kind)

func bestiary_entries() -> Array:
	if bestiary_filter == "MUTATIONS":
		return g.mutation_book_ids()
	var entries: Array = []
	for kind in g.mob_order():
		if str(kind).begins_with("mix_"):
			continue # Historical mutations belong to the dedicated book.
		var is_boss = bool(g.enemy_db[kind].get("boss", false))
		var found = int(g.profile["mobs"].get(kind, 0)) > 0
		if bestiary_filter == "BOSSES" and not is_boss:
			continue
		if bestiary_filter == "STREET" and is_boss:
			continue
		if bestiary_filter == "FOUND" and not found:
			continue
		entries.append(kind)
	return entries

func bestiary_select(index: int, page_size: int) -> void:
	var entries = bestiary_entries()
	var idx = bestiary_page * page_size + index
	if idx >= 0 and idx < entries.size():
		bestiary_selected = str(entries[idx])

func bestiary_filters(x: float, y: float, tile_width: float) -> void:
	# Mutation Book is a separate menu destination, not a Bestiary tab.
	if bestiary_filter == "MUTATIONS":
		txt("MUTATIONS ARE NOT BASE SPECIES", Vector2(x + 3, y + 24), 16, Color("8feaba"), 0, bold)
		return
	var filters = ["ALL", "STREET", "BOSSES", "FOUND"]
	for i in range(filters.size()):
		var key = str(filters[i])
		var r = Rect2(x + float(i) * (tile_width + 7.0), y, tile_width, 34)
		rbox(r, Color("2a5a7b") if bestiary_filter == key else Color("1a2840"), 9)
		txt(key, r.get_center() + Vector2(0, 6), fit(key, tile_width - 12, 15), Color.WHITE, 1, bold)
		buttons.append({"rect": r, "action": "bestiary_filter_" + key})

func bestiary_tile(r: Rect2, kind: String) -> void:
	var found = int(g.profile["mobs"].get(kind, 0)) > 0
	var recipe = MutationRecipes.recipe_for_id(kind)
	if bestiary_filter == "MUTATIONS" and not recipe.is_empty():
		var available = mutation_unlocked(kind)
		var known = found or available
		rbox(r, Color("243450") if found else (Color("18273c") if available else Color("0d1425")),
			13, Color("ffdb75") if bestiary_selected == kind else (Color("73d8b2") if available else Color("40536b")),
			3 if bestiary_selected == kind else 1)
		if found:
			enemy_icon(kind, Rect2(r.position + Vector2(10, 7), r.size - Vector2(20, 40)))
		else:
			txt("?" if available else "X", r.get_center() + Vector2(0, 7),
				52, Color("7bd9bd") if available else Color("44566e"), 1, bold)
		var label = str(recipe["name"]).to_upper() if known else "LOCKED"
		txt(label, Vector2(r.get_center().x, r.end.y - 23),
			fit(label, r.size.x - 10, 15, bold, 11), Color.WHITE if known else Color("8997af"), 1, bold)
		var status = "ACTIVE THIS RUN" if available else ("KNOWN / RUN LOCKED" if found else "N%d / H%d" % [int(recipe["normal_sector"]), int(recipe["hard_sector"])])
		txt(status, Vector2(r.get_center().x, r.end.y - 5), fit(status, r.size.x - 10, 10, body, 9),
			Color("91efbd") if available else Color("9caac0"), 1, body)
		return
	rbox(r, Color("1b2c42") if found else Color("10192b"), 13, Color("ffdb75") if bestiary_selected == kind else Color("456782"), 3 if bestiary_selected == kind else 1)
	if found:
		enemy_icon(kind, Rect2(r.position + Vector2(10, 7), r.size - Vector2(20, 40)))
		var label = str(g.enemy_db[kind]["name"]).to_upper()
		txt(label, Vector2(r.get_center().x, r.end.y - 12), fit(label, r.size.x - 12, 16, bold, 11), Color.WHITE, 1, bold)
	else:
		txt("?", r.get_center() + Vector2(0, 10), 58, Color("52617a"), 1, bold)
		txt("UNKNOWN", Vector2(r.get_center().x, r.end.y - 12), 14, Color("9aacc5"), 1, bold)

func bestiary_detail(kind: String, r: Rect2) -> void:
	rbox(r, Color("111d31"), 19, Color("4a6f8d"), 2)
	if kind == "":
		txt("SELECT AN ENEMY", r.get_center(), 24, Color("adbed3"), 1, bold)
		return
	var found = int(g.profile["mobs"].get(kind, 0)) > 0
	var recipe = MutationRecipes.recipe_for_id(kind)
	if not recipe.is_empty() and not found:
		var revealed = mutation_unlocked(kind)
		txt("ACTIVE THIS RUN" if revealed else "LOCKED THIS RUN",
			Vector2(r.get_center().x, r.position.y + 75), 27,
			Color("7dffcf") if revealed else Color("98a9bf"), 1, bold)
		txt(str(recipe["name"]).to_upper() if revealed else "???",
			Vector2(r.get_center().x, r.position.y + 133), 29, Color.WHITE, 1, bold)
		if revealed:
			txt("%s  +  %s" % [str(recipe["a"]).to_upper(), str(recipe["b"]).to_upper()],
				Vector2(r.get_center().x, r.position.y + 186), 19, Color("ffd28d"), 1, bold)
			wrap_text("Unlocked for the CURRENT run only. Defeat it to add a permanent entry to the Mutation Book.",
				r.position.x + 32, r.position.y + 220, r.size.x - 64, 19,
				Color("c9e8de"), 27, body, false, 5)
		else:
			txt("NORMAL  SECTOR %d" % int(recipe["normal_sector"]),
				Vector2(r.get_center().x, r.position.y + 184), 20, Color("e1d4aa"), 1, bold)
			txt("HARD  SECTOR %d" % int(recipe["hard_sector"]),
				Vector2(r.get_center().x, r.position.y + 225), 20, Color("ffb29a"), 1, bold)
			wrap_text("This mutation cannot spawn in the current run yet. Each run starts locked, even when a previous run discovered this mutation.",
				r.position.x + 32, r.position.y + 280, r.size.x - 64, 18,
				Color("b5c5d9"), 26, body, false, 5)
		return
	if not found:
		txt("UNDISCOVERED", Vector2(r.get_center().x, r.position.y + 70), 32, Color("a9bed2"), 1, bold)
		txt("?", r.get_center(), 110, Color("53647a"), 1, bold)
		wrap_text("Defeat this enemy to unlock its stats, abilities and tactics.", r.position.x + 25, r.end.y - 110, r.size.x - 50, 18, Color("bfd0de"), 22, body, false, 3)
		return
	var enemy: Dictionary = g.enemy_db[kind]
	var note: Array = Bestiary.info(kind)
	var x = r.position.x
	var y = r.position.y
	var ww = r.size.x
	var art_h = minf(154.0, r.size.y * 0.29)
	var species_label = "MUTATION" if not recipe.is_empty() else ("BOSS" if bool(enemy.get("boss", false)) else "MONSTER")
	txt(species_label, Vector2(x + 22, y + 27), 16, Color("8feaba") if not recipe.is_empty() else (Color("ffb1c1") if bool(enemy.get("boss", false)) else Color("8ed8ff")), 0, bold)
	enemy_icon(kind, Rect2(x + ww * 0.3, y + 34, ww * 0.4, art_h))
	var title = str(enemy["name"]).to_upper()
	txt(title, Vector2(r.get_center().x, y + art_h + 61), fit(title, ww - 30, 28, bold, 15), Color.WHITE, 1, bold)
	var stat_y = y + art_h + 81
	for i in range(3):
		var key = ["hp", "dmg", "speed"][i]
		var chip = Rect2(x + 14 + float(i) * (ww - 28) / 3.0, stat_y, (ww - 42) / 3.0, 50)
		rbox(chip, Color("273750"), 7)
		txt(["BASE HP", "ATK", "SPEED"][i], Vector2(chip.get_center().x, chip.position.y + 16), 12, Color("b5cee4"), 1, bold)
		txt("%d" % int(enemy[key]), Vector2(chip.get_center().x, chip.position.y + 40), 21, Color.WHITE, 1, bold)
	var ty = stat_y + 76
	txt(str(note[0]), Vector2(x + 20, ty), 18, Color("ffd38a"), 0, bold)
	wrap_text(str(note[1]), x + 20, ty + 27, ww - 40, 16, Color("daeaff"), 20, body, false, 3)
	txt("COUNTERPLAY", Vector2(x + 20, ty + 105), 17, Color("8ed8ff"), 0, bold)
	wrap_text(str(note[2]), x + 20, ty + 132, ww - 40, 16, Color("c8ddf3"), 19, body, false, 3)
	if not recipe.is_empty():
		var status = "CURRENT RUN: UNLOCKED" if mutation_unlocked(kind) else "CURRENT RUN: LOCKED"
		txt(status, Vector2(r.get_center().x, r.end.y - 38),
			fit(status, ww - 32, 14), Color("8feaba") if mutation_unlocked(kind) else Color("f0b4a1"), 1, bold)
	txt("KILLS  %d    •    XP  %d    •    BASE STATS" % [int(g.profile["mobs"][kind]), int(enemy["xp"])], Vector2(r.get_center().x, r.end.y - 14), fit("KILLS %d XP %d BASE" % [int(g.profile["mobs"][kind]), int(enemy["xp"])], ww - 32, 14), Color("a4b8ce"), 1, body)

func paint_bestiary() -> void:
	paint_menu_bg()
	draw_rect(g.landscape_rect(), Color(0.01, 0.02, 0.06, 0.77))
	txt("MUTATION BOOK" if bestiary_filter == "MUTATIONS" else "BESTIARY",
		Vector2(34, 64), 52, Color.WHITE, 0, bold, 4)
	var known = 0
	for id in g.mob_order():
		if int(g.profile["mobs"].get(id, 0)) > 0:
			known += 1
	if bestiary_filter == "MUTATIONS":
		var unlocked = 0
		var defeated = 0
		for id in g.mutation_book_ids():
			if mutation_unlocked(str(id)):
				unlocked += 1
			if int(g.profile["mobs"].get(id, 0)) > 0:
				defeated += 1
		txt("%d RUN UNLOCKED  /  %d PERMANENTLY FOUND  /  %d TOTAL" % [unlocked, defeated, MutationRecipes.RECIPES.size()],
			Vector2(36, 99), 18, Color("a6d8f5"), 0, bold)
	else:
		txt("%d / %d SPECIES DISCOVERED" % [known, g.mob_order().size()], Vector2(36, 99), 18, Color("a6d8f5"), 0, bold)
	bestiary_filters(35, 111, 110)
	var items = bestiary_entries()
	if bestiary_selected == "" or not items.has(bestiary_selected):
		bestiary_selected = ""
		for id in items:
			if int(g.profile["mobs"].get(id, 0)) > 0:
				bestiary_selected = str(id)
				break
		if bestiary_selected == "" and bestiary_filter == "MUTATIONS" and not items.is_empty():
			bestiary_selected = str(items[0])
	var pages = maxi(1, ceili(float(items.size()) / 12.0))
	bestiary_page = clampi(bestiary_page, 0, pages - 1)
	for i in range(12):
		var idx = bestiary_page * 12 + i
		if idx >= items.size():
			break
		var rect = Rect2(35 + float(i % 4) * 182, 155 + float(int(i / 4)) * 151, 170, 140)
		bestiary_tile(rect, str(items[idx]))
		buttons.append({"rect": rect, "action": "bestiary_select_%d" % i})
	bestiary_detail(bestiary_selected, Rect2(793, 118, 454, 512))
	button(Rect2(150, 633, 75, 45), "<", "bestiary_prev", false, 26, bestiary_page > 0)
	txt("PAGE %d / %d" % [bestiary_page + 1, pages], Vector2(358, 665), 21, Color.WHITE, 1, bold)
	button(Rect2(501, 633, 75, 45), ">", "bestiary_next", false, 26, bestiary_page < pages - 1)
	button(Rect2(990, 650, 210, 48), "BACK", "back", true, 24)

func paint_portrait_bestiary() -> void:
	var h = g.ui_height
	portrait_bg()
	dim(0.7)
	txt("MUTATION BOOK" if bestiary_filter == "MUTATIONS" else "BESTIARY",
		Vector2(360, 68), 48, Color.WHITE, 1, bold, 5)
	var known = 0
	for id in g.mob_order():
		if int(g.profile["mobs"].get(id, 0)) > 0:
			known += 1
	if bestiary_filter == "MUTATIONS":
		var unlocked = 0
		var defeated = 0
		for id in g.mutation_book_ids():
			if mutation_unlocked(str(id)):
				unlocked += 1
			if int(g.profile["mobs"].get(id, 0)) > 0:
				defeated += 1
		txt("%d RUN UNLOCKED  /  %d FOUND  /  %d TOTAL" % [unlocked, defeated, MutationRecipes.RECIPES.size()],
			Vector2(360, 110), 20, Color("a6d8f5"), 1, bold)
	else:
		txt("%d / %d DISCOVERED" % [known, g.mob_order().size()], Vector2(360, 110), 21, Color("a6d8f5"), 1, bold)
	bestiary_filters(22, 128, 127)
	var items = bestiary_entries()
	var pages = maxi(1, ceili(float(items.size()) / 9.0))
	bestiary_page = clampi(bestiary_page, 0, pages - 1)
	for i in range(9):
		var idx = bestiary_page * 9 + i
		if idx >= items.size():
			break
		var rect = Rect2(24 + float(i % 3) * 232, 186 + float(int(i / 3)) * 179, 216, 165)
		bestiary_tile(rect, str(items[idx]))
		buttons.append({"rect": rect, "action": "bestiary_select_%d" % i})
	button(Rect2(110, h - 192, 105, 68), "<", "bestiary_prev", false, 30, bestiary_page > 0)
	txt("%d / %d" % [bestiary_page + 1, pages], Vector2(360, h - 146), 25, Color.WHITE, 1, bold)
	button(Rect2(505, h - 192, 105, 68), ">", "bestiary_next", false, 30, bestiary_page < pages - 1)
	button(Rect2(190, h - 108, 340, 77), "BACK", "back", true, 30)
	if bestiary_selected != "":
		buttons.clear()
		dim(0.93)
		bestiary_detail(bestiary_selected, Rect2(50, 120, 620, minf(775.0, h - 280.0)))
		button(Rect2(190, h - 111, 340, 76), "CLOSE", "bestiary_close", true, 30)

func paint_victory() -> void:
	draw_rect(g.landscape_rect(), Color("090e1c"))
	draw_rect(Rect2(16, 16, 1248, 688), Color("ffcf4d"), false, 4.0)
	txt("SECTOR %d CLEARED" % g.WIN_SECTOR, Vector2(640, 172), 64, Color("ffcf4d"), 1, bold, 7)
	txt("YOU WON!", Vector2(640, 258), 78, Color.WHITE, 1, bold, 8)
	txt("%d kills   ·   level %d   ·   %d:%02d" % [g.kills, g.level, int(g.run_time) / 60, int(g.run_time) % 60], Vector2(640, 330), 25, Color("c8d8ef"), 1, bold)
	txt("Your run can keep going. Enemies will keep scaling.", Vector2(640, 397), 21, Color("aebdd2"), 1, body)
	button(Rect2(428, 468, 424, 68), "CONTINUE TO SECTOR %d" % (g.WIN_SECTOR + 1), "continue_run", true, 28)
	button(Rect2(505, 564, 270, 52), "MAIN MENU", "menu", false, 22)

func paint_lost() -> void:
	draw_rect(g.landscape_rect(), Color("0a0610"))
	draw_rect(g.landscape_rect(), Color(0.3, 0.0, 0.05, 0.3 + 0.05 * sin(g.anim_t * 2.0)))
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

## All between-sector decisions remain visually anchored to the route map.
## Remove map hitboxes before overlay controls are added.
func paint_hub_backdrop() -> void:
	if g.map_cols.size() >= g.sector and g.sector > 0:
		paint_map()
		buttons.clear()
	else:
		screen_bg()
	draw_rect(g.landscape_rect() if not g.portrait else Rect2(0, 0, 720, g.ui_height),
		Color(0.016, 0.025, 0.063, 0.985))
	var w = sw()
	var y = 42.0 if not g.portrait else 38.0
	txt("ROUTE STOP  //  SECTOR %d" % g.sector, Vector2(w * 0.5, y), 15, Color("7b9abd"), 1, bold)

## A deliberate pause after every normal boss. The win screen still owns Sector 20.
func paint_boss_result() -> void:
	paint_hub_backdrop()
	var w = sw()
	var h = sh()
	var bw = 544.0 if not g.portrait else 622.0
	var bh = 482.0 if not g.portrait else 500.0
	var r = Rect2(w * 0.5 - bw * 0.5, h * 0.5 - bh * 0.5, bw, bh)
	panel(r, Color("111629"), Color("ffca50"), 3)
	var center = Vector2(r.get_center().x, r.position.y + 124.0)
	draw_circle(center, 75.0, Color("52283c"))
	draw_arc(center, 75.0, 0, TAU, 56, Color("ff6886"), 5.0)
	CardArt.node_icon(self, "boss", center, 43.0, Color("ff8198"))
	txt("BOSS DEFEATED", Vector2(r.get_center().x, r.position.y + 253.0),
		fit("BOSS DEFEATED", bw - 38, 44, bold, 27), Color("ffcf69"), 1, bold, 6)
	txt("SECTOR %d  //  ROAD SECURED" % g.sector, Vector2(r.get_center().x, r.position.y + 294.0),
		21, Color("b8cbe2"), 1, bold, 3)
	txt("THE ROAD OPENS WHEN YOU'RE READY", Vector2(r.get_center().x, r.position.y + 350.0),
		fit("THE ROAD OPENS WHEN YOU'RE READY", bw - 45, 18), Color("8db4c6"), 1, body)
	var ready = g.boss_result_t >= 0.8
	button(Rect2(r.position.x + 58.0, r.end.y - 92.0, bw - 116.0, 63.0),
		"CONTINUE TO ROUTE MAP", "boss_continue", ready, 25, ready)

## Route remains visible while departure animation completes.
func paint_travel_overlay() -> void:
	var w = sw()
	var h = sh()
	draw_rect(g.landscape_rect() if not g.portrait else Rect2(0, 0, 720, g.ui_height),
		Color(0.015, 0.02, 0.05, 0.77))
	var bw = 540.0 if not g.portrait else 625.0
	var r = Rect2(w * 0.5 - bw * 0.5, h * 0.5 - 128.0, bw, 246.0)
	panel(r, Color("121a2b"), Color("66e5f0"), 3)
	txt("TAKING THE ROAD", Vector2(w * 0.5, r.position.y + 71.0), 39, Color.WHITE, 1, bold, 5)
	txt("NEXT STOP  //  " + g.travel_title.to_upper(), Vector2(w * 0.5, r.position.y + 110.0),
		fit("NEXT STOP  //  " + g.travel_title.to_upper(), bw - 40.0, 22), Color("ffd24d"), 1, bold)
	var progress = 1.0 - clampf(g.travel_t / 1.40, 0.0, 1.0)
	var bar = Rect2(r.position.x + 43.0, r.position.y + 146.0, bw - 86.0, 18.0)
	rbox(bar, Color("293b4f"), 8)
	var filled = Rect2(bar.position, Vector2(maxf(7.0, bar.size.x * progress), bar.size.y))
	rbox(filled, Color("5de5e8"), 8)
	txt("DEPARTING...", Vector2(w * 0.5, r.end.y - 35.0), 18, Color("9dbbd2"), 1, body)

func screen_bg() -> void:
	draw_rect(g.landscape_rect() if not g.portrait else Rect2(0, 0, sw(), sh()), Color(0.03, 0.04, 0.1, 0.94))
	var start_x = floori(g.landscape_left / 60.0) * 60 if not g.portrait else 0
	var end_x = ceili((g.landscape_left + g.landscape_width) / 60.0) * 60 if not g.portrait else int(sw())
	for x in range(start_x, end_x + 1, 60):
		draw_line(Vector2(x, 0), Vector2(x, sh()), Color(0.3, 0.65, 0.9, 0.04))
	for y in range(0, int(sh()) + 1, 60):
		draw_line(Vector2(start_x, y), Vector2(end_x, y), Color(0.3, 0.65, 0.9, 0.04))

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
	paint_hub_backdrop()
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
	paint_hub_backdrop()
	var c = Vector2(W * 0.5, 250 if g.portrait else 150)
	# a little campfire
	for k in range(3):
		var fl = sin(g.anim_t * (7.0 + k)) * 6.0
		CardArt.glyph(self, "element", c + Vector2((k - 1) * 26, fl * 0.3), 46.0 - k * 6.0, [Color("ff8a3d"), Color("ffd24d"), Color("ff5a4a")][k])
	draw_line(c + Vector2(-60, 60), c + Vector2(60, 40), Color("8a5a3a"), 14)
	draw_line(c + Vector2(-60, 40), c + Vector2(60, 60), Color("6b4329"), 14)
	txt("CAMPFIRE", Vector2(W * 0.5, 82 if g.portrait else 64), 58 if g.portrait else 48, Color("7dff9a"), 1, bold, 6)
	status_chips(c.y + (92 if g.portrait else 65))
	var y = c.y + (170 if g.portrait else 145)
	var bw = 560.0 if g.portrait else 520.0
	var bx = W * 0.5 - bw * 0.5
	var heal_amt = roundi(float(g.hero["maxhp"]) * 0.4)
	button(Rect2(bx, y, bw, 78 if g.portrait else 72), "REST: HEAL %d HP" % heal_amt, "rest_heal", true, 30)
	txt("OR TRAIN A GUN (+1 LEVEL)", Vector2(W * 0.5, y + (140 if g.portrait else 119)), 22, Color.WHITE, 1, bold, 3)
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var lv = int(w["lvl"])
		var label = "%s  LV %d » %d" % [Weapons.display_name(g, w).to_upper(), lv, lv + 1] if lv < 5 else "%s  MAX LEVEL" % Weapons.display_name(g, w).to_upper()
		var row_gap = 96.0 if g.portrait else 77.0
		button(Rect2(bx, y + (166 if g.portrait else 140) + i * row_gap, bw, 76 if g.portrait else 65), label, "rest_train_%d" % i, false, 24, lv < 5)
	if g.portrait:
		icon_button(Vector2(660, 62), 28, "open_arsenal", "bag")

func paint_event() -> void:
	var W = sw()
	var H = sh()
	paint_hub_backdrop()
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
	if u["type"] in ["enemy", "mob", "mutation", "mutation_found"]:
		return str(g.enemy_db[u["id"]]["name"])
	if u["type"] == "gun":
		return str(g.weapon_db[u["id"]].get("name", u["id"]))
	return str(g.card_by_id[u["id"]]["name"])

var _mob_tex: Dictionary = {}

## Portrait cut from the baked enemy atlas, usable anywhere a card expects art.
func mob_tex(kind: String) -> Texture2D:
	var v = g.visuals
	var preview = str(g.enemy_db[kind].get("mix", [kind])[0])
	if v.atlas == null or not v.atlas_cell.has(preview):
		return null
	if not _mob_tex.has(kind):
		var at = AtlasTexture.new()
		at.atlas = v.atlas
		at.region = v.atlas_cell[preview]
		_mob_tex[kind] = at
	return _mob_tex[kind]

func mob_info(kind: String) -> Dictionary:
	var d = g.enemy_db[kind]
	var boss = bool(d.get("boss", false))
	var tier = g.mob_tier(kind)
	var rar = 4 if boss else (3 if kind == "goblin" else mini(tier, 3))
	var tag = "BOSS" if boss else ("RARE" if kind == "goblin" else "TIER %d" % (tier + 1))
	if not g.profile["mobs"].has(kind):
		var hint = "A boss. Keep going." if boss else ("Shows up on the street." if tier == 0 else "Appears as you advance through route choices.")
		return {"title": "???", "desc": "Not met yet. " + hint, "rar": rar, "cat": "MONSTER", "catid": "locked",
			"art": null, "foot": "LOCKED", "icon": false, "rarlabel": "LOCKED"}
	var desc = "HP %d · DMG %d · SPEED %d.  You killed %d." % [int(d["hp"]), int(d["dmg"]), int(d["speed"]), int(g.profile["mobs"][kind])]
	return {"title": str(d["name"]), "desc": desc, "rar": rar, "cat": "MONSTER", "catid": "chaos",
		"art": mob_tex(kind), "foot": tag, "icon": true, "rarlabel": tag}

## Enemy portrait from the baked atlas (nothing in headless runs).
func enemy_icon(kind: String, r: Rect2, a: float = 1.0) -> void:
	var v = g.visuals
	var description: Dictionary = g.enemy_db.get(kind, {})
	var pair: Array = description.get("mix", [])
	var preview = str(pair[0]) if not pair.is_empty() else kind
	if v.atlas != null and v.atlas_cell.has(preview):
		var size = minf(r.size.x, r.size.y)
		var dst = Rect2(r.get_center() - Vector2(size, size) * 0.5, Vector2(size, size))
		var src: Rect2 = v.atlas_cell[preview]
		var accent = Color(str(description["color"]))
		draw_circle(dst.get_center() + Vector2(0, size * 0.18), size * 0.42, Color(0, 0, 0, 0.35 * a))
		draw_circle(dst.get_center() + Vector2(0, -size * 0.04), size * 0.37, Color(accent, 0.11 * a))
		draw_texture_rect_region(v.atlas, dst, Rect2(src.position + Vector2(50, 50), Vector2(100, 100)), Color(1, 1, 1, a))
		if pair.size() == 2:
			var parts: Dictionary = description.get("look", {})
			var second = Color(str(g.enemy_db[str(pair[1])]["color"]))
			v.draw_hybrid_trait(self, dst.get_center(), size * 0.34,
				str(parts.get("trait", "ears")), Color(second, a), int(parts.get("variant", 0)))
		var face = str(description.get("look", {}).get("face", ""))
		if face != "visor" and kind not in ["heli", "necro", "totem", "riot"]:
			for side in [-1.0, 1.0]:
				draw_circle(dst.get_center() + Vector2(side * size * 0.14, -size * 0.07), maxf(2.0, size * 0.033), Color("142035"))
				draw_circle(dst.get_center() + Vector2(side * size * 0.14 - 1.0, -size * 0.09), maxf(1.0, size * 0.011), Color.WHITE)

const KILL_LINES = {"blob": "blob.", "zoomer": "too slow.", "spitter": "ptooey.",
	"kaboomba": "worth it.", "chonk": "oops. sat on you.", "mitosis": "we won.", "mini": "small but mighty.",
	"riot": "denied.", "bull": "moo.", "tick": "tick tock.", "mama": "go to your room.",
	"mortar": "incoming.", "totem": "hype!", "blinky": "boo.", "goblin": "mine now.",
	"ashwing": "I always come back.", "mirror": "right back at you.", "burrower": "surprise!", "siren": "follow my lead.",
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
	var col = {"gun": Color("ffcf4d"), "enemy": ALERT, "mob": Color("7dff9a"),
		"mutation": Color("80eec4"), "mutation_found": Color("80eec4")}.get(u["type"], NEON)
	cbox(r, Color(0.03, 0.05, 0.08, 0.94 * slide), 12, Color(col, slide), 2)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 14, 4, r.size.y - 22), Color(col, slide))
	var label = {"gun": "UNLOCKED // NEW GUN", "enemy": "BOSS DOWN // NEW THREAT",
		"mob": "BESTIARY // NEW ENTRY", "mutation": "MUTATION BOOK // RUN UNLOCKED", "mutation_found": "MUTATION BOOK // DISCOVERED"}.get(u["type"], "UNLOCKED // NEW CARD")
	txt(label, r.position + Vector2(22, 24), 15, Color(col, slide), 0, bold)
	if u["type"] in ["enemy", "mob", "mutation", "mutation_found"]:
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

## Complete route exploration, ten sectors per page, independent of 16:9 size.
## Nonadjacent nodes are previews only; they do not bypass the selection rules.
func paint_map_overview() -> void:
	var cols = g.map_cols
	if cols.is_empty():
		return
	var cur = g.sector - 1
	var first = clampi(g.map_view_first, 0, maxi(0, cols.size() - 10))
	var last = mini(cols.size() - 1, first + 9)
	var left = g.landscape_left + 62.0
	var width = g.landscape_width - 124.0
	var step = width / 10.0
	draw_rect(g.landscape_rect(), Color("090f20"))
	for i in range(12):
		var y = 135.0 + i * 43.0
		draw_line(Vector2(g.landscape_left, y), Vector2(g.landscape_left + g.landscape_width, y), Color("2c496d", 0.08), 1.0)
	txt("FULL ROUTE MAP", Vector2(left, 68), 42, Color.WHITE, 0, bold, 5)
	var subtitle = "SECTORS %d - %d / %d  ·  ARROW KEYS TO BROWSE" % [first + 1, last + 1, cols.size()]
	txt(subtitle, Vector2(left, 103), 19, Color("ffce61"), 0, bold)
	var reachable: Array = cols[cur][g.map_at]["next"] if cur >= 0 and cur < cols.size() else []
	var positions = {}
	for c in range(first, last + 1):
		var n = cols[c].size()
		for i in range(n):
			positions[Vector2i(c, i)] = Vector2(left + step * (float(c - first) + 0.5), 190.0 + (float(i) + 0.5) / float(n) * 400.0)
	for c in range(first, last):
		for i in range(cols[c].size()):
			for j in cols[c][i]["next"]:
				var a: Vector2 = positions[Vector2i(c, i)]
				var b: Vector2 = positions[Vector2i(c + 1, int(j))]
				var active = c == cur and i == g.map_at
				draw_line(a, b, Color("ffcd58", 0.86) if active else Color("426083", 0.36), 4.0 if active else 2.0, true)
	for c in range(first, last + 1):
		for i in range(cols[c].size()):
			var node: Dictionary = cols[c][i]
			var p: Vector2 = positions[Vector2i(c, i)]
			var info: Dictionary = g.NODE_INFO[str(node["type"])]
			var col = Color(str(info["color"]))
			var current = c == cur and i == g.map_at
			var reach = c == cur + 1 and reachable.has(i)
			var chosen = reach and g.map_pick == i
			var radius = 25.0 if str(node["type"]) == "boss" else 19.0
			draw_circle(p, radius + 4.0, Color("ffffff") if chosen else Color(col, 0.65 if current or reach else 0.2))
			draw_circle(p, radius, col.darkened(0.55) if current or reach else Color("233047"))
			CardArt.node_icon(self, str(node["type"]), p, radius * 0.65, col)
			if current:
				txt("YOU", p + Vector2(0, radius + 23), 16, Color("57eaff"), 1, bold)
			elif reach:
				buttons.append({"rect": Rect2(p - Vector2(25, 25), Vector2(50, 50)), "action": "map_node_%d" % i})
			if c == last or c == first or str(node["type"]) == "boss":
				var label = str(info["name"])
				txt(label, p + Vector2(0, radius + 19), fit(label, step - 4.0, 12, bold, 9), Color(col, 0.88), 1, bold)
	for c in range(first, last + 1):
		var x = left + step * (float(c - first) + 0.5)
		txt("S%d" % (c + 1), Vector2(x, 644), 19, Color("ff758a") if (c + 1) % 5 == 0 else Color("a0b5d2"), 1, bold)
	button(Rect2(left, 670, 180, 43), "PREV  <<", "map_prev", false, 19, first > 0)
	button(Rect2(left + width * 0.5 - 110, 670, 220, 43), "RETURN TO MAP", "map_full", true, 18)
	button(Rect2(left + width - 180.0, 670, 180, 43), "NEXT  >>", "map_next", false, 19, last < cols.size() - 1)
	if g.map_pick >= 0:
		var node = cols[cur + 1][g.map_pick]
		var note = "SELECTED: " + str(g.NODE_INFO[str(node["type"])]["name"]) + "  ·  Return to map to depart"
		txt(note, Vector2(g.landscape_left + g.landscape_width * 0.5, 111), 15, Color("d8ffe6"), 1, bold)

func paint_map_wide() -> void:
	if g.map_full:
		paint_map_overview()
		return
	var cols = g.map_cols
	var cur = g.sector - 1
	var last = mini(cols.size() - 1, cur + 5)
	var nxt: Array = cols[cur][g.map_at]["next"]
	# backdrop
	draw_rect(g.landscape_rect(), Color("0a0f22"))
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
	if g.state == "map":
		button(Rect2(728, 88, 158, 39), "FULL MAP", "map_full", false, 17)

func paint_map_node(node: Dictionary, p: Vector2, c: int, i: int, cur: int, nxt: Array) -> void:
	var t = str(node["type"])
	var info = g.NODE_INFO[t]
	var col = Color(str(info["color"]))
	var reach = c == cur + 1 and nxt.has(i)
	var here = c == cur and i == g.map_at
	var past = c <= cur and not here
	var size = 96.0 if t == "boss" else 64.0
	var hovered = reach and Rect2(p - Vector2(size, size) * 0.6, Vector2(size, size) * 1.2).has_point(g.mouse_screen)
	if g.state == "map" and hovered and not g.is_touch_active():
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
