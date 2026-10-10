extends Node2D
## SLIME HOUR - one hero, two guns, 300 effects, a road full of idiots running at you.
## Main owns run state and flow. Combat/Weapons/Effects are static helpers that act on it.

const Combat = preload("res://scripts/Combat.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const Effects = preload("res://scripts/Effects.gd")
const SfxScript = preload("res://scripts/Sfx.gd")
const AutoTest = preload("res://scripts/AutoTest.gd")
const ScreenFit = preload("res://scripts/ScreenFit.gd")
const RouteFlow = preload("res://scripts/RouteFlow.gd")
const GAME_VERSION = "v0.1.16"
const RELEASE_URL = "https://github.com/zerozet22k/SlimeHour_Godot/releases/latest"
const RELEASE_API = "https://api.github.com/repos/zerozet22k/SlimeHour_Godot/releases/latest"

const DESIGN = Vector2(1280, 720)
const ROAD_HALF = 530.0
var road_half = ROAD_HALF
var landscape_width = 1280.0
var landscape_left = 0.0
func landscape_rect() -> Rect2:
	return Rect2(landscape_left, 0.0, landscape_width, 720.0)
const SECTOR_LEN = 4800.0
const HERO_SCREEN_Y = 470.0
const MAX_ENEMIES = 200
const MAX_SHOTS = 500
const MAX_SHOTS_LIMIT = 500
## Clear this sector to win; the run can continue after it (every sector is then a boss).
const WIN_SECTOR = 50

# ---------------------------------------------------------------- databases
var db_cards: Array = []
var card_by_id: Dictionary = {}
var categories: Dictionary = {}
var weapon_db: Dictionary = {}
var weapon_ids: Array = []
var enemy_db: Dictionary = {}

# ---------------------------------------------------------------- app state
var state = "menu"          # menu settings collection playing paused levelup replace arsenal lost
var settings_back = "menu"
var phase = "fight"         # fight | cleared | map | shop | rest | treasure
var arsenal_back = "playing"
var settings = {"sfx": 0.7, "music": 0.45, "sensitivity": 1.0, "cursor": 1.0, "shake": 1.0, "numbers": true, "particles": true,
	"aim": "auto" if OS.has_feature("mobile") else "mouse",
	"autofire": OS.has_feature("mobile"), "hints": true, "touch": "auto", "controls_v2": true}
var best = {"sector": 0, "kills": 0, "level": 0}
var profile = {"xp": 0, "level": 0, "goo": 0, "ups": {}, "mobs": {}, "announced_mobs": {}}
var unlocked_cards: Dictionary = {}
var unlock_level: Dictionary = {}
var unlocked_guns: Array = []
var sealed: Dictionary = {}
var hard_mode = false
var run_awarded = false
var last_award: Dictionary = {}
var run_unlocks: Array = []          # {"type": "card"|"gun", "id"} unlocked during this run
var unlock_toasts: Array = []        # same, waiting to pop up in the HUD
var unlock_index: Dictionary = {}    # card id -> position in the unlock order
var next_unlock_kills = 0
var bosses_beaten = 0
var fresh_tier_sector = -1
var dying_t = 0.0                    # real seconds left in the slow-mo death moment
var lost_t = 0.0                     # real seconds the result screen has been up
var killer_kind = ""
var killer_ref: Dictionary = {}     # the monster the death camera focuses on
const DYING_TIME = 2.6
var debug_mode = false
var sfx = null
var music_refresh_t = 0.0
var autotest = ""
var no_save = false            # tool scripts set this so checks never touch the real save
var update_available = false
var update_version = ""
var autotest_t = 0.0
var shot_queue: Array = []

# ---------------------------------------------------------------- run state
var hero: Dictionary = {}
var guns: Array = []
var owned: Dictionary = {}
var owned_order: Array = []
var S: Dictionary = {}
var procs: Dictionary = {}
var proc_state: Dictionary = {}
var buffs: Array = []
var gate_mods: Dictionary = {}
var route: Dictionary = {}

var enemies: Array = []
var shots: Array = []
var fx: Array = []
var zones: Array = []
var pickups: Array = []
var texts: Array = []
var delayed: Array = []
var barrels: Array = []
var gates: Array = []
var shop_items: Array = []
var map_cols: Array = []
var map_at = 0
var map_pick = -1
var map_path: Array = []
var clear_t = 0.0
var boss_result_t = 0.0
var travel_t = 0.0
var travel_title = ""
var route_risk = 0
var shop_bonus = 0.0
var event: Dictionary = {}
var event_stage = "choose"
var event_opt = 0
var event_dice: Array = []
var event_faces: Array = []
var event_roll_t = 0.0
var event_face_t = 0.0
var event_result = ""
var turrets: Array = []
var saws: Array = []
var pets: Array = []
var temp_orbitals: Array = []
var beams: Array = []
var grid: Dictionary = {}
var orbit_hits: Dictionary = {}

var cam_y = 0.0
var cam_x = 0.0
var mouse_screen = Vector2.ZERO
var aim_screen = Vector2.ZERO
var mouse_world = Vector2.ZERO
var mouse_moved_t = 0.0
var aim_mouse_active = false
var anim_t = 0.0
var run_time = 0.0
var sector = 1
var kills = 0
var gold = 0
var xp = 0.0
var xp_need = 6
var level = 1
var combo = 0
var combo_t = 0.0
var best_combo = 0
var damage_dealt = 0.0
var damage_taken = 0.0
var last_hit_by = "the road"
var sector_start_y = 0.0
var finish_y = -SECTOR_LEN
var spawn_acc = 0.0
var sector_budget = 0
var budget_spawned = 0
var sector_kills = 0
var front_y = 0.0
var sector_time = 0.0
var rush_queue = 0
var rush_done = false
var gate_done = false
var boss_spawned = false
var goblin_t = 0.0
var hitstop = 0.0
var slowmo_t = 0.0
var shake = 0.0
var banner_text = ""
var banner_sub = ""
var banner_t = 0.0
var flash_t = 0.0
var flash_color = Color.WHITE
var serial = 0
var frame_procs = 0
var sim_step = 0
var totems: Array = []
var latched_ticks = 0
var frame_booms = 0
var levelup_delay = 0.0
var pending_levels = 0
var pending_chests = 0
var sector_elite_chests = 0
var offers: Array = []
var offer_mode = "level"
var offer_t = 0.0
var offer_sel = 0
var rerolls = 2
var replace_gun = ""
var replace_tier = 0
var shop_reroll_cost = 15
var orbit_angle = 0.0
var walk_acc = 0.0
var still_t = 0.0
var volley_count = 0
var mine_acc = 0.0
var turret_t = 0.0
var hive_t = 0.0
var stats_dirty = true
var prof: Dictionary = {}

@onready var visuals = $Visuals
@onready var hud = $Hud

var stick_touch_id = -1
var stick_center = Vector2(160, 520)
var stick_knob = Vector2(160, 520)
var touch_move_dir = Vector2.ZERO
var aim_touch_id = -1
var touch_aim_dir = Vector2.ZERO
var dash_touch_id = -1
var dash_btn_pos = Vector2(1140, 510)
var bash_btn_pos = Vector2(980, 510)
var bash_btn_r = 51.0
var dash_btn_r = 50.0
var dash_pressed = false
var portrait = false
var portrait_preview = false
var ui_height = 720.0
var view_top = 0.0
var view_bottom = 720.0

func default_stick() -> Vector2:
	return Vector2(150, ui_height - 230.0) if portrait else Vector2(190, 560)

## How far below screen centre the hero sits; portrait shows more road ahead.
func hero_offset() -> float:
	return 190.0 if portrait else HERO_SCREEN_Y - 360.0

func is_touch_active() -> bool:
	return (OS.has_feature("mobile") or portrait_preview) and str(settings.get("touch", "auto")) != "off"

func _ready() -> void:
	randomize()
	var data = CrowdCatalog.load_all()
	db_cards = data["cards"].get("cards", [])
	categories = data["cards"].get("categories", {})
	for c in db_cards:
		card_by_id[str(c["id"])] = c
	for w in data["weapons"]:
		weapon_db[str(w["id"])] = w
		weapon_ids.append(str(w["id"]))
	for e in data["enemies"]:
		enemy_db[str(e["id"])] = e
	sfx = SfxScript.new()
	add_child(sfx)
	var args = OS.get_cmdline_user_args()
	portrait_preview = args.has("--portrait-preview")
	load_options()
	if not OS.has_feature("mobile") and not portrait_preview:
		settings["touch"] = "off"
	elif portrait_preview:
		settings["touch"] = "auto"
	sfx.set_volumes(float(settings["sfx"]), float(settings["music"]))
	get_window().title = "SLIME HOUR"
	for a in args:
		if a.begins_with("--autotest"):
			autotest = a.trim_prefix("--autotest").trim_prefix("=")
			if autotest == "":
				autotest = "soak"
	compute_unlocks()
	if autotest != "":
		get_node("/root").add_child.call_deferred(AutoTest.new())
	elif OS.has_feature("windows"):
		check_for_updates()

func check_for_updates() -> void:
	var request = HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_update_checked.bind(request))
	var headers = PackedStringArray(["User-Agent: SlimeHour-Game", "Accept: application/vnd.github+json"])
	if request.request(RELEASE_API, headers) != OK:
		request.queue_free()

func _on_update_checked(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if response_code != 200:
		return
	var release = JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary:
		return
	var latest = str(release.get("tag_name", ""))
	if latest.begins_with("v") and version_is_newer(latest, GAME_VERSION):
		update_version = latest
		update_available = true

## Compare numeric major.minor.patch so old releases never appear as upgrades.
static func version_is_newer(candidate: String, installed: String) -> bool:
	var next_parts = candidate.trim_prefix("v").split(".")
	var current_parts = installed.trim_prefix("v").split(".")
	if next_parts.size() != 3 or current_parts.size() != 3:
		return false
	for i in range(3):
		if not next_parts[i].is_valid_int() or not current_parts[i].is_valid_int():
			return false
		var next_value = int(next_parts[i])
		var current_value = int(current_parts[i])
		if next_value != current_value:
			return next_value > current_value
	return false

func install_update() -> void:
	var updater = OS.get_executable_path().get_base_dir().path_join("update_and_run.ps1")
	if FileAccess.file_exists(updater):
		var args = PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", updater])
		if OS.create_process("powershell.exe", args) != -1:
			get_tree().quit()
			return
	OS.shell_open(RELEASE_URL)

# ================================================================= frame loop
func _process(delta: float) -> void:
	anim_t += delta
	var vp = get_viewport_rect().size
	var was_portrait = portrait
	portrait = vp.y > vp.x * 1.1
	var k: float
	if portrait:
		road_half = ROAD_HALF
		landscape_width = 1280.0
		landscape_left = 0.0
		k = vp.x / 720.0
		ui_height = vp.y / k
		view_top = 360.0 - ui_height * 0.5
		view_bottom = 360.0 + ui_height * 0.5
		visuals.scale = Vector2.ONE * k
		visuals.position = vp * 0.5 - Vector2(640, 360) * k
		hud.scale = Vector2.ONE * k
		hud.position = Vector2.ZERO
	else:
		k = ScreenFit.landscape_scale(vp)
		landscape_width = ScreenFit.canvas_width(vp)
		landscape_left = ScreenFit.canvas_left(vp)
		road_half = ScreenFit.road_half(vp)
		ui_height = 720.0
		view_top = 0.0
		view_bottom = 720.0
		for layer in [visuals, hud]:
			layer.scale = Vector2.ONE * k
			layer.position = (vp - DESIGN * k) * 0.5
	if was_portrait != portrait:
		stick_touch_id = -1
		aim_touch_id = -1
		dash_touch_id = -1
		touch_move_dir = Vector2.ZERO
		dash_pressed = false
	if stick_touch_id == -1:
		stick_center = default_stick()
		stick_knob = stick_center
	dash_btn_pos = Vector2(596, ui_height - 210.0) if portrait else Vector2(1150, 560)
	dash_btn_r = 70.0 if portrait else 58.0
	bash_btn_pos = Vector2(450, ui_height - 221.0) if portrait else Vector2(1000, 560)
	bash_btn_r = 51.0
	var m = hud.get_local_mouse_position()
	var captured = state == "playing" and settings["aim"] == "mouse" and not is_touch_active() and autotest == ""
	var mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse_mode:
		if not captured and aim_mouse_active:
			# Hand the OS cursor back where the crosshair was.
			Input.mouse_mode = mouse_mode
			get_viewport().warp_mouse(hud.get_global_transform_with_canvas() * aim_screen)
			m = aim_screen
		else:
			Input.mouse_mode = mouse_mode
	if captured and aim_mouse_active:
		m = aim_screen
	if m.distance_squared_to(mouse_screen) > 4.0:
		mouse_moved_t = 0.0
	mouse_moved_t += delta
	if aim_touch_id == -1 and not is_touch_active():
		if state == "playing" and settings["aim"] == "mouse":
			if not aim_mouse_active:
				aim_screen = m
				aim_mouse_active = true
			mouse_world = screen_to_world(aim_screen)
		else:
			aim_mouse_active = false
			aim_screen = m
			mouse_world = screen_to_world(m)
		mouse_screen = m
	if state in ["playing", "levelup", "replace", "arsenal", "paused"] and not hero.is_empty():
		# Death camera: swing over to whoever killed you, at real-time speed despite the slow-mo.
		var focus: Vector2 = hero["pos"]
		var cdt = delta
		if dying_t > 0.0:
			cdt = delta / maxf(0.01, Engine.time_scale)
			if not killer_ref.is_empty():
				focus = killer_ref["pos"]
		var target = focus.y - hero_offset()
		cam_y = lerpf(cam_y, target, 1.0 - exp(-7.0 * cdt))
		var side_limit = maxf(0.0, road_half - 360.0 + 28.0)
		var target_x = clampf(float(focus.x), -side_limit, side_limit) if portrait else 0.0
		cam_x = lerpf(cam_x, target_x, 1.0 - exp(-7.0 * cdt))
	shake = maxf(0.0, shake - delta * 30.0)
	banner_t = maxf(0.0, banner_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	offer_t += delta
	var real_dt = delta / maxf(0.01, Engine.time_scale)
	if dying_t > 0.0:
		dying_t -= real_dt
		if dying_t <= 0.0:
			finish_game_over()
	if state == "lost":
		lost_t += real_dt
	if not unlock_toasts.is_empty() and state == "playing":
		unlock_toasts[0]["t"] = float(unlock_toasts[0]["t"]) - delta
		if float(unlock_toasts[0]["t"]) <= 0.0:
			unlock_toasts.pop_front()
	if state == "event":
		update_event(delta)
	if state == "boss_result":
		boss_result_t += real_dt
	if state == "travel":
		travel_t -= real_dt
		if travel_t <= 0.0:
			finish_travel()
	# Adaptive combat mix is sampled rather than recomputed every draw frame.
	music_refresh_t -= delta
	if music_refresh_t <= 0.0:
		music_refresh_t = 0.45
		var near_count = 0
		var cornered = false
		var danger = 0.0
		var boss_now = false
		var boss_rage = false
		if state == "playing" and phase == "fight" and not hero.is_empty():
			var hp_ratio = float(hero["hp"]) / maxf(1.0, float(hero["maxhp"]))
			for enemy in enemies:
				if bool(enemy["dead"]):
					continue
				if enemy["pos"].distance_squared_to(hero["pos"]) < 205.0 * 205.0:
					near_count += 1
				if bool(enemy["boss"]):
					boss_now = true
					boss_rage = boss_rage or Combat.boss_stage(enemy) >= 2
			cornered = (absf(float(hero["pos"].x)) > road_half - 110.0 and near_count >= 3) or near_count >= 10
			danger = clampf(float(near_count) / 11.0 + (0.22 if hp_ratio < 0.35 else 0.0), 0.0, 1.0)
			if str(route.get("name", "")) == "HELL LANE":
				danger = minf(1.0, danger + 0.12)
		# The route map continues the current biome theme softly instead of
		# hard-cutting to silence; no combat pressure or warnings between stops.
		sfx.music_context(biome_index(), boss_now, boss_rage, danger, cornered)
	var is_route_music = RouteFlow.should_play_route_music(state, phase)
	sfx.set_route_mix(is_route_music)
	sfx.music_on(RouteFlow.should_play_combat_music(state, phase) or is_route_music)
	visuals.queue_redraw()
	hud.queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	frame_procs = 0
	frame_booms = 0
	sim_step += 1
	if next_unlock_kills > 0 and lifetime_kills() >= next_unlock_kills:
		refresh_unlocks()
	if hitstop > 0.0:
		hitstop -= delta
		return
	slowmo_t = maxf(0.0, slowmo_t - delta)
	var dt = delta * (0.35 if slowmo_t > 0.0 else 1.0)
	run_time += dt
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	update_buffs(dt)
	if stats_dirty:
		Effects.recalc(self)
	var t0 = Time.get_ticks_usec()
	move_hero(dt)
	Combat.build_grid(self)
	var t1 = Time.get_ticks_usec()
	Weapons.update(self, dt)
	var t2 = Time.get_ticks_usec()
	Combat.step(self, dt)
	var t3 = Time.get_ticks_usec()
	Effects.tick(self, dt)
	update_pickups(dt)
	var t4 = Time.get_ticks_usec()
	prof["hero+grid"] = float(prof.get("hero+grid", 0.0)) + (t1 - t0)
	prof["weapons"] = float(prof.get("weapons", 0.0)) + (t2 - t1)
	prof["combat"] = float(prof.get("combat", 0.0)) + (t3 - t2)
	prof["tick+pickups"] = float(prof.get("tick+pickups", 0.0)) + (t4 - t3)
	update_director(dt)
	update_texts(dt)
	if state != "playing":
		return
	if levelup_delay > 0.0:
		levelup_delay -= delta
	elif pending_chests > 0:
		open_offers("chest")
	elif pending_levels > 0:
		open_offers("level")

# ================================================================= coordinates
func world_to_screen(p: Vector2) -> Vector2:
	return Vector2(640.0 + p.x - cam_x, 360.0 + p.y - cam_y)

func screen_to_world(p: Vector2) -> Vector2:
	if portrait:
		return Vector2(p.x - 360.0 + cam_x, p.y - ui_height * 0.5 + cam_y)
	return Vector2(p.x - 640.0 + cam_x, p.y - 360.0 + cam_y)

func on_screen(p: Vector2, margin = 60.0) -> bool:
	var y = p.y - cam_y
	var half_h = ui_height * 0.5 if portrait else 360.0
	return y > -half_h - margin and y < half_h + margin

# ================================================================= run setup
func start_run() -> void:
	state = "playing"
	phase = "fight"
	boss_result_t = 0.0
	travel_t = 0.0
	travel_title = ""
	cam_x = 0.0
	touch_aim_dir = Vector2.ZERO
	for arr in [enemies, shots, fx, zones, pickups, texts, delayed, barrels, gates, turrets, saws, pets, temp_orbitals, beams, buffs]:
		arr.clear()
	owned.clear()
	owned_order.clear()
	S.clear()  # Never allow stale stat prerequisites from the previous run.
	proc_state.clear()
	gate_mods.clear()
	orbit_hits.clear()
	route = {"name": "HIGHWAY"}
	run_awarded = false
	last_award = {}
	run_unlocks.clear()
	unlock_toasts.clear()
	bosses_beaten = 0
	fresh_tier_sector = -1
	dying_t = 0.0
	Engine.time_scale = 1.0
	seal_cards()
	map_cols.clear()
	gen_map(8)
	map_at = 0
	map_path = [Vector2i(0, 0)]
	route_risk = 0
	shop_bonus = 0.0
	shop_items.clear()
	hero = {"pos": Vector2(0, 0), "vel": Vector2.ZERO, "push": Vector2.ZERO, "hp": 100.0, "maxhp": 100.0,
		"iframe": 0.0, "shield": 0, "shield_t": 0.0, "dash_t": 0.0, "dash_dir": Vector2.UP, "dash_charges": 1,
		"dash_cd": 0.0, "dash_window": 0.0, "perfect_used": false, "bash_cd": 0.0, "bash_t": 0.0, "bash_dir": Vector2.UP, "aim": Vector2.UP, "moving": false,
		"flash": 0.0, "revives": 0, "dash_hits": {}, "trail_acc": 0.0, "last_pos": Vector2.ZERO}
	guns = [Weapons.new_gun(self, "pistol")]
	sector = 1
	kills = 0
	gold = 0
	xp = 0.0
	level = 1
	xp_need = xp_for(1)
	combo = 0
	best_combo = 0
	damage_dealt = 0.0
	damage_taken = 0.0
	run_time = 0.0
	rerolls = 2 + meta_level("reroll")
	gold += int(15 * meta_level("gold"))
	pending_levels = 0
	pending_chests = 0
	levelup_delay = 0.0
	volley_count = 0
	shop_reroll_cost = 15 - 4 * meta_level("haggle")
	last_hit_by = "the road"
	for i in range(meta_level("startcard")):
		var id = random_start_card()
		if id != "":
			Effects.add_card(self, id)
	stats_dirty = true
	Effects.recalc(self)
	hero["hp"] = hero["maxhp"]
	hero["shield"] = int(S.get("shield", 0))
	hero["dash_charges"] = 1 + int(S.get("dashes", 0))
	cam_y = hero["pos"].y - hero_offset()
	begin_sector()
	sfx.play("level")

func xp_for(l: int) -> int:
	# Quick first levels, then steep parabolic/cubic curve that prevents card bloat.
	var m = float(l - 1)
	return int(8 + m * 14 + 6.0 * pow(m, 2.0) + 0.6 * pow(m, 3.0))

## Player-side scaling: guns, card procs, statuses and allies all grow by this per sector.
func sector_scale() -> float:
	return 1.0 + 0.06 * (sector - 1)

## A smoother health curve for a deliberately low-card economy.
## Normal Sector 8 is ~4x base HP, not ~26x; density and elites still create pressure.
## Keep later sectors progressively tougher without early enemies becoming HP walls.
func enemy_scale() -> float:
	var s = sector - 1
	if s <= 4:
		return 1.0 + 0.07 * float(s)
	var early_base = 1.0 + 0.07 * 4.0
	var m = float(s - 4)
	var scale = early_base * (1.0 + 0.30 * m + 0.12 * m * m + 0.008 * m * m * m)
	# A short 7-11 breathing window after the initial card-reward slowdown.
	# Preserve the later curve; avoid an abrupt difficulty cliff at Sector 11.
	var relief = 1.0
	match sector:
		7: relief = 0.94
		8: relief = 0.90
		9: relief = 0.88
		10: relief = 0.90
		11: relief = 0.96
	scale *= relief
	if sector > WIN_SECTOR:
		scale *= pow(1.35, float(mini(sector - WIN_SECTOR, 20)))
	return scale

## Mid/late crowd size: +4% monsters per sector after sector 5, up to double at sector 30.
func crowd_ramp(s: int = -1) -> float:
	var x = sector if s < 0 else s
	# A few fewer simultaneous enemies in the 7-10 spike, reaching
	# the original ramp again by Sector 12.
	var normal = minf(2.0, 1.0 + 0.04 * float(maxi(0, x - 5)))
	var relief = 0.0
	match x:
		7: relief = 0.025
		8: relief = 0.045
		9: relief = 0.06
		10: relief = 0.06
		11: relief = 0.03
	return normal - relief

## Concurrent monster limit per sector. Kept lower in early game and ramps into high-density hordes.
func enemy_cap() -> int:
	if sector <= 5:
		return 22 + (sector - 1) * 14
	return mini(MAX_ENEMIES, 80 + (sector - 5) * 20)

func shot_cap() -> int:
	return mini(MAX_SHOTS_LIMIT, MAX_SHOTS + 50 * maxi(0, sector - 1))

func volley_cap() -> int:
	return mini(80, 36 + 4 * maxi(0, sector - 1))

func projectile_size_cap() -> float:
	return minf(128.0, 80.0 + 3.0 * maxi(0, sector - 1))

func proc_cap() -> int:
	return mini(120, 70 + 3 * maxi(0, sector - 1))

func begin_sector() -> void:
	phase = "fight"
	sector_start_y = hero["pos"].y
	finish_y = sector_start_y - SECTOR_LEN
	spawn_acc = 0.0
	rush_queue = 0
	rush_done = false
	sector_budget = budget_for(sector)
	front_y = hero["pos"].y
	sector_time = 0.0
	budget_spawned = 0
	sector_kills = 0
	sector_elite_chests = 0
	gate_done = false
	boss_spawned = false
	goblin_t = randf_range(10.0, 25.0)
	gate_mods.clear()
	stats_dirty = true
	enemies.clear()
	gates.clear()
	barrels.clear()
	# No stale bomb or boss telegraph may carry into the next sector.
	delayed.clear()
	for i in range(6 + mini(sector, 8)):
		spawn_barrel(Vector2(randf_range(-road_half + 50, road_half - 50), sector_start_y - randf_range(350, SECTOR_LEN - 150)))
	if route.get("heal", 0) > 0:
		heal(hero["maxhp"] * float(route["heal"]))
	var title = "SECTOR %d" % sector
	var sub = biome_name() + "  //  " + str(route.get("name", "HIGHWAY"))
	if is_boss_sector():
		sub = "BOSS SECTOR  //  " + sub
	banner(title, sub, 2.6)
	Effects.trigger(self, "sector", {"pos": hero["pos"], "gen": 0})
	if sector == fresh_tier_sector:
		# Wait for the sector banner, then introduce each new monster.
		var delay = 2.4
		for k in ENEMY_TIERS[bosses_beaten]:
			# Tier introduction is informative only once per permanent profile.
			# Existing saves already record discovered monsters in profile.mobs.
			if profile.get("mobs", {}).has(k) or profile.get("announced_mobs", {}).has(k):
				continue
			profile["announced_mobs"][k] = true
			unlock_toasts.append({"type": "enemy", "id": k, "t": 2.6 + delay})
			delay = 0.0
		save_options()

func is_boss_sector() -> bool:
	return sector > WIN_SECTOR or sector % 5 == 0

func biome_name() -> String:
	var names = ["NEON OUTSKIRTS", "FROSTLINE", "ASHLANDS", "CANDY DISTRICT", "THE VOID LANE"]
	return names[int((sector - 1) / 5) % names.size()]

func biome_index() -> int:
	return int((sector - 1) / 5) % 5

# ================================================================= hero
func move_hero(dt: float) -> void:
	var h = hero
	if dying_t > 0.0:
		return
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	var joy = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() > 0.25:
		dir = joy
	if autotest != "":
		dir = AutoTest.move_dir(self)
	if touch_move_dir.length_squared() > 0.01:
		dir = touch_move_dir
	dir = dir.limit_length(1.0)
	var speed = 255.0 * maxf(0.3, 1.0 + S.get("speed", 0.0))
	if latched_ticks > 0:
		speed *= pow(0.75, float(mini(latched_ticks, 3)))
	for w in guns:
		if weapon_db[w["id"]]["kind"] == "spin" and float(w["spin"]) > 0.2:
			speed *= 0.62
	var accel = 3.2 if S.get("drift", 0) > 0 else 18.0
	h["vel"] = h["vel"].lerp(dir * speed, 1.0 - exp(-accel * dt))
	h["moving"] = dir.length_squared() > 0.01
	h["push"] = h["push"] * exp(-7.0 * dt)
	var prev: Vector2 = h["pos"]
	if float(h["dash_t"]) > 0.0:
		h["dash_t"] = float(h["dash_t"]) - dt
		var dist = 175.0 * (1.0 + S.get("dashdist", 0.0))
		h["pos"] += h["dash_dir"] * (dist / 0.16) * dt
		h["trail_acc"] = float(h["trail_acc"]) + dist / 0.16 * dt
		if S.get("dashtrail", 0) > 0 and float(h["trail_acc"]) > 34.0:
			h["trail_acc"] = 0.0
			add_zone("fire", h["pos"], 34.0, 2.5)
		dash_contact_line(prev, h["pos"])
		if float(h["dash_t"]) <= 0.0:
			Effects.trigger(self, "dashend", {"pos": h["pos"], "gen": 0})
	else:
		h["pos"] += (h["vel"] + h["push"]) * dt
	h["bash_cd"] = maxf(0.0, float(h.get("bash_cd", 0.0)) - dt)
	h["bash_t"] = maxf(0.0, float(h.get("bash_t", 0.0)) - dt)
	h["dash_window"] = maxf(0.0, float(h["dash_window"]) - dt)
	h["iframe"] = maxf(0.0, float(h["iframe"]) - dt)
	h["flash"] = maxf(0.0, float(h["flash"]) - dt)
	clamp_hero()
	var moved = prev.distance_to(h["pos"])
	if moved > 0.5:
		Effects.walked(self, moved)
		still_t = 0.0
	else:
		still_t += dt
	# Dash charges
	var max_charges = 1 + int(S.get("dashes", 0))
	if int(h["dash_charges"]) < max_charges:
		h["dash_cd"] = float(h["dash_cd"]) + dt * (1.0 + S.get("dashcd", 0.0))
		if float(h["dash_cd"]) >= 1.5:
			h["dash_cd"] = 0.0
			h["dash_charges"] = int(h["dash_charges"]) + 1
	# Regeneration & shields
	if S.get("regen", 0.0) > 0.0:
		h["hp"] = minf(float(h["maxhp"]), float(h["hp"]) + S["regen"] * dt)
	if int(h["shield"]) < int(S.get("shield", 0)):
		h["shield_t"] = float(h["shield_t"]) + dt
		if float(h["shield_t"]) >= 8.0:
			h["shield_t"] = 0.0
			h["shield"] = int(h["shield"]) + 1
	# Aim
	var aim = h["aim"]
	if settings["aim"] == "auto" or autotest != "":
		var t = nearest_enemy(h["pos"], 620.0)
		if t != null:
			aim = (t["pos"] - h["pos"]).normalized()
	elif is_touch_active():
		if touch_aim_dir.length_squared() > 0.01:
			aim = touch_aim_dir
	else:
		var off: Vector2 = mouse_world - h["pos"]
		if off.length_squared() > 64.0:
			aim = off.normalized()
	h["aim"] = aim

func clamp_hero() -> void:
	var p: Vector2 = hero["pos"]
	var half = road_half - 18.0
	p.x = clampf(p.x, -half, half)
	# Walk anywhere in this sector; the barrier behind the sector start blocks the previous one.
	front_y = minf(front_y, p.y)
	p.y = minf(p.y, back_limit())
	hero["pos"] = p

## R: reload every gun that is not full (beams and returning discs have nothing to reload).
func manual_reload() -> void:
	for w in guns:
		var k = Weapons.kind_of(self, w)
		if k in ["beam", "disc", "boomerang"] or float(w["reload"]) > 0.0 or int(w["ammo"]) >= int(w["mag_max"]):
			continue
		Weapons.start_reload(self, w)

func back_limit() -> float:
	return sector_start_y + 380.0

func try_dash() -> void:
	var h = hero
	if dying_t > 0.0:
		return
	if int(h["dash_charges"]) <= 0 or float(h["dash_t"]) > 0.0:
		return
	h["dash_charges"] = int(h["dash_charges"]) - 1
	for e in enemies:
		if bool(e.get("latched", false)):
			e["latched"] = false
			e["kb"] = (e["pos"] - h["pos"]).normalized() * 700.0
			e["stun"] = 0.8
	var dir: Vector2 = h["vel"].normalized() if h["vel"].length() > 30.0 else h["aim"]
	h["dash_dir"] = dir
	h["dash_hits"] = {}
	h["perfect_used"] = false
	h["dash_window"] = 0.16 + 0.1 + S.get("perfect", 0.0)
	h["iframe"] = maxf(float(h["iframe"]), 0.2)
	if S.get("blink", 0) > 0:
		var dist = 175.0 * (1.0 + S.get("dashdist", 0.0))
		spawn_ring_fx(h["pos"], Color("b48cff"), 26.0)
		h["pos"] += dir * dist
		clamp_hero()
		spawn_ring_fx(h["pos"], Color("b48cff"), 26.0)
		h["dash_t"] = 0.0
		dash_contact_line(h["pos"] - dir * dist, h["pos"])
		Effects.trigger(self, "dash", {"pos": h["pos"], "gen": 0, "dir": dir})
		Effects.trigger(self, "dashend", {"pos": h["pos"], "gen": 0})
	else:
		h["dash_t"] = 0.16
		Effects.trigger(self, "dash", {"pos": h["pos"], "gen": 0, "dir": dir})
	if S.get("dashreload", 0) > 0:
		for w in guns:
			Weapons.finish_reload(self, w)
	sfx.play("dash")

func dash_contact() -> void:
	if S.get("dashdmg", 0) <= 0 and S.get("dashpush", 0) <= 0:
		return
	for e in enemies_near(hero["pos"], 40.0):
		if bool(e["dead"]) or hero["dash_hits"].has(e["id"]):
			continue
		if e["pos"].distance_to(hero["pos"]) < float(e["r"]) + 22.0:
			hero["dash_hits"][e["id"]] = true
			dash_hit(e)

func dash_contact_line(a: Vector2, b: Vector2) -> void:
	# Even a vanilla dash activates Kaboomba's fuse; use swept contact, not just
	# the final frame position, so high-speed dashes cannot pass through unseen.
	var damaging = S.get("dashdmg", 0) > 0 or S.get("dashpush", 0) > 0
	# Barreling through an explosive arms it; the player has time to escape.
	for barrel in barrels:
		if float(barrel["drop"]) <= 0.0 and not bool(barrel.get("armed", false)):
			if Combat.seg_dist2(a, b, barrel["pos"]) < pow(20.0 + 22.0, 2):
				barrel["hp"] = 0.0
	for e in enemies:
		if bool(e["dead"]) or hero["dash_hits"].has(e["id"]):
			continue
		if not damaging and e["kind"] != "kaboomba":
			continue
		if Combat.seg_dist2(a, b, e["pos"]) < pow(float(e["r"]) + 22.0, 2):
			hero["dash_hits"][e["id"]] = true
			dash_hit(e)

func dash_hit(e: Dictionary) -> void:
	if e["kind"] == "kaboomba":
		# Do not suppress kill() by marking it dead first. Always arm the fuse.
		Combat.kill(self, e, {"gen": 1, "pos": e["pos"]}, 0.0)
		return
	var dir = (e["pos"] - hero["pos"]).normalized()
	if S.get("dashpush", 0) > 0:
		e["kb"] += dir * 900.0 / maxf(0.6, float(e["mass"]))
		e["flung"] = 1.0
	if S.get("dashdmg", 0) > 0:
		Combat.hit(self, e, 30.0 * S["dashdmg"] * dmg_mult(), {"pos": e["pos"], "gen": 1, "dir": dir, "knock": 200.0})

## Innate close-range bash (F, middle mouse or BASH touch button).
## Short frontal sweep, a real cooldown, stagger, knockback and a visible impact.
func try_bash() -> void:
	if state != "playing" or dying_t > 0.0 or hero.is_empty():
		return
	if float(hero.get("bash_cd", 0.0)) > 0.0 or float(hero["dash_t"]) > 0.0:
		return
	var forward: Vector2 = hero["aim"].normalized()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP
	hero["bash_cd"] = 1.25
	hero["bash_t"] = 0.23
	hero["bash_dir"] = forward
	var origin: Vector2 = hero["pos"]
	var impact_count = 0
	for e in enemies:
		if bool(e["dead"]) or not Combat.bash_in_arc(origin, forward, e["pos"], float(e["r"])):
			continue
		var direction: Vector2 = (e["pos"] - origin).normalized()
		if direction == Vector2.ZERO:
			direction = forward
		var dmg = 27.0 * pow(enemy_scale(), 0.55) * dmg_mult()
		Combat.hit(self, e, dmg, {"gen": 1, "pos": e["pos"], "dir": direction, "knock": 560.0})
		if not bool(e["dead"]):
			e["stun"] = maxf(float(e["stun"]), 0.10 if bool(e["boss"]) else 0.32)
		impact_count += 1
		if impact_count >= 8:
			break
	if impact_count > 0:
		spawn_burst(origin + forward * 49.0, Color("fff2b0"), mini(impact_count * 3, 18), 175.0, 3.5)
		add_shake(3.0 + mini(impact_count, 5))
		sfx.play("bonk")
	else:
		sfx.play("whoosh", 0.15, 0.65)

func perfect_dodge() -> void:
	if bool(hero["perfect_used"]):
		return
	hero["perfect_used"] = true
	slowmo_t = maxf(slowmo_t, 0.18)
	say(hero["pos"] + Vector2(0, -40), "PERFECT!", Color("9ff8ff"), 30)
	spawn_ring_fx(hero["pos"], Color("9ff8ff"), 60.0)
	sfx.play("perfect")
	Effects.trigger(self, "perfect", {"pos": hero["pos"], "gen": 0})

func hurt(amount: float, src: Vector2, who: String = "something") -> bool:
	var h = hero
	if dying_t > 0.0:
		return false
	if state != "playing" or float(h["iframe"]) > 0.0:
		if float(h["dash_window"]) > 0.0:
			perfect_dodge()
		return false
	if float(h["dash_window"]) > 0.0:
		perfect_dodge()
		return false
	if randf() < S.get("dodge", 0.0):
		say(h["pos"] + Vector2(0, -30), "DODGE", Color("a8c8ff"), 20)
		h["iframe"] = 0.25
		return false
	if int(h["shield"]) > 0:
		h["shield"] = int(h["shield"]) - 1
		h["iframe"] = 0.5
		say(h["pos"] + Vector2(0, -30), "BLOCKED", Color("8ff8ff"), 20)
		spawn_ring_fx(h["pos"], Color("8ff8ff"), 34.0)
		sfx.play("block")
		return false
	var dmg = amount * (1.0 + S.get("dmgtaken", 0.0)) * float(route.get("taken", 1.0)) - S.get("armor", 0.0)
	dmg = maxf(1.0, dmg)
	h["hp"] = float(h["hp"]) - dmg
	damage_taken += dmg
	h["iframe"] = 0.65 + S.get("iframe", 0.0)
	h["flash"] = 0.25
	last_hit_by = who
	add_shake(9.0)
	hitstop = 0.05
	flash_screen(Color(1, 0.2, 0.25), 0.18)
	say(h["pos"] + Vector2(randf_range(-10, 10), -34), "-%d" % roundi(dmg), Color("ff6b7a"), 22)
	sfx.play("hurt")
	Effects.trigger(self, "hurt", {"pos": h["pos"], "gen": 0, "dmg": dmg})
	if float(h["hp"]) <= 0.0:
		if int(h["revives"]) < int(S.get("revive", 0)):
			h["revives"] = int(h["revives"]) + 1
			h["hp"] = float(h["maxhp"]) * (0.5 if int(h["revives"]) == 1 else 0.3)
			h["iframe"] = 2.0
			banner("SECOND WIND", "", 1.8)
			slowmo_t = 1.0
			if S.get("mad", 0) > 0:
				Combat.explode(self, h["pos"], 900.0, 400.0 * dmg_mult(), 1, Color("fff1a8"))
				flash_screen(Color.WHITE, 0.6)
				say(h["pos"] + Vector2(0, -60), "NUKED.", Color("fff1a8"), 46)
			sfx.play("level")
		else:
			game_over()
	return true

func heal(amount: float) -> void:
	if amount <= 0:
		return
	var h = hero
	var before = float(h["hp"])
	var after = before + amount
	if after > float(h["maxhp"]) and S.get("overheal", 0) > 0:
		var extra = after - float(h["maxhp"])
		if extra >= 10.0 and int(h["shield"]) < 3:
			h["shield"] = int(h["shield"]) + 1
	h["hp"] = minf(float(h["maxhp"]), after)
	if after - before >= 3.0:
		say(h["pos"] + Vector2(0, -36), "+%d" % roundi(minf(amount, float(h["maxhp"]) - before)), Color("7dff9a"), 18)

func add_shield(n: int) -> void:
	hero["shield"] = mini(maxi(3, int(S.get("shield", 0)) + 2), int(hero["shield"]) + n)

func game_over() -> void:
	if autotest != "":
		finish_game_over()
		return
	if dying_t > 0.0:
		return
	dying_t = DYING_TIME
	killer_kind = ""
	for k in enemy_db:
		if last_hit_by.contains(str(enemy_db[k]["name"])):
			killer_kind = k
	# The closest monster of that kind is the one that got you (for shots: the shooter nearby).
	killer_ref = {}
	var best_d = INF
	for e in enemies:
		if str(e["kind"]) == killer_kind:
			var d = (e["pos"] as Vector2).distance_squared_to(hero["pos"])
			if d < best_d:
				best_d = d
				killer_ref = e
	Engine.time_scale = 0.3
	sfx.play("lose")
	add_shake(14.0)

func finish_game_over() -> void:
	dying_t = 0.0
	lost_t = 0.0
	Engine.time_scale = 1.0
	state = "lost"
	award_profile()
	best["sector"] = maxi(int(best["sector"]), sector)
	best["kills"] = maxi(int(best["kills"]), kills)
	best["level"] = maxi(int(best["level"]), level)
	save_options()

# ================================================================= stats helpers
func st(key: String) -> float:
	return float(S.get(key, 0.0))

## Damage = base x (1 + every "+X% damage" added together) x each "+X% TOTAL damage".
## dmg_pool() is the additive part, more_mult() the few multiplicative ones.
func dmg_pool(extra: float = 0.0) -> float:
	var m = 1.0 + st("dmg") + extra
	if st("golddmg") > 0:
		m += minf(0.5, float(gold) / 1000.0)
	if st("combodmg") > 0:
		m += minf(0.4, combo * 0.01)
	if st("lowhpdmg") > 0:
		m += st("lowhpdmg") * (1.0 - float(hero["hp"]) / maxf(1.0, float(hero["maxhp"])))
	if st("speeddmg") > 0:
		m += maxf(0.0, st("speed"))
	if bool(hero.get("moving", false)):
		m += st("movedmg")
	elif still_t > 0.25:
		m += st("stilldmg")
	return maxf(0.1, m)

func more_mult() -> float:
	return float(S.get("more", 1.0))

func dmg_mult() -> float:
	return dmg_pool() * more_mult()

func update_buffs(dt: float) -> void:
	var changed = false
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i]["t"] = float(buffs[i]["t"]) - dt
		if float(buffs[i]["t"]) <= 0.0:
			buffs.remove_at(i)
			changed = true
	if changed:
		stats_dirty = true

func add_buff(stat: String, amt: float, t: float) -> void:
	buffs.append({"stat": stat, "amt": amt, "t": t})
	stats_dirty = true

# ================================================================= director
## Sector progress = share of the crowd you have killed. There is no finish line: kill them all.
func progress() -> float:
	return clampf(float(sector_kills) / maxf(1.0, float(crowd_total())), 0.0, 1.0)

func crowd_total() -> int:
	return sector_budget + rush_size()

func enemies_left() -> int:
	return maxi(0, crowd_total() - sector_kills)

func boss_alive() -> bool:
	for e in enemies:
		if bool(e["boss"]) and not bool(e["dead"]):
			return true
	return false

func update_director(dt: float) -> void:
	if phase == "cleared":
		clear_t -= dt
		if RouteFlow.ready_after_clear(clear_t, pending_levels, pending_chests):
			if RouteFlow.requires_boss_result(is_boss_sector(), sector, WIN_SECTOR):
				state = "boss_result"
				boss_result_t = 0.0
			else:
				open_map()
		return
	if phase != "fight":
		return
	var p = progress()
	var hero_y = float(hero["pos"].y)
	var alive = enemies.size()
	var cap = enemy_cap()
	var rate = (1.6 + (sector - 1) * 0.75 + p * 2.2) * pow(1.035, float(maxi(0, sector - 5))) * float(route.get("spawns", 1.0))
	if is_boss_sector() and boss_spawned:
		rate *= 0.3
	# Each sector has a fixed crowd. It unlocks as you push forward, so standing still
	# (or stalling a boss) cannot farm endless gold and EXP.
	sector_time += dt
	var unlocked = int(ceil(float(sector_budget) * minf(1.0, 0.25 + p * 1.2 + sector_time / 40.0)))
	spawn_acc += dt * rate
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive >= cap or budget_spawned >= unlocked:
			spawn_acc = minf(spawn_acc, 1.0)
			break
		budget_spawned += 1
		var behind = randf() < 0.14
		var edge = maxf(420.0, ui_height * 0.5 + 80.0)
		var y = cam_y - edge - randf_range(0, 160) if not behind else cam_y + edge + randf_range(0, 80)
		spawn_enemy(pick_enemy(), Vector2(randf_range(-road_half + 30, road_half - 30), y))["budget"] = true
		alive += 1
	# The crowd rush: a horde streams down the road.
	if not rush_done and (p > 0.45 or sector_time > 30.0):
		rush_done = true
		rush_queue = rush_size()
		banner("SLIME HOUR!!", "RUN.", 2.2)
		sfx.play("horn")
		add_shake(6.0)
	var rush_cap = mini(MAX_ENEMIES, cap + (10 if sector <= 5 else 25))
	if rush_queue > 0 and enemies.size() < rush_cap:
		for i in range(mini(rush_queue, 6)):
			var kind = "zoomer" if randf() < 0.3 else ("blob" if randf() < 0.8 else "kaboomba")
			spawn_enemy(kind, Vector2(randf_range(-road_half + 25, road_half - 25), cam_y - maxf(400.0, ui_height * 0.5 + 80.0) - randf_range(0, 120)))["budget"] = true
			rush_queue -= 1
	# Buff gates: classic pick-a-door, applies for the rest of the sector.
	goblin_t -= dt * (1.0 + st("goblins") * 1.5)
	if goblin_t <= 0.0:
		goblin_t = randf_range(22.0, 40.0)
		spawn_enemy("goblin", Vector2(randf_range(-300, 300), cam_y - maxf(380.0, ui_height * 0.5 + 80.0)))
		say(hero["pos"] + Vector2(0, -80), "A GOLD GOBLIN!", Color("ffd24d"), 24)
	if is_boss_sector() and not boss_spawned and (p > 0.75 or sector_time > 50.0):
		boss_spawned = true
		var bosses = ["chonkzilla", "heli", "necro", "kingblob"]
		var kind = bosses[((sector - WIN_SECTOR - 1) if sector > WIN_SECTOR else (int(sector / 5) - 1)) % bosses.size()]
		spawn_enemy(kind, Vector2(0, cam_y - maxf(330.0, ui_height * 0.5 + 40.0)), true)
		banner(str(enemy_db[kind]["name"]), "BOSS", 2.5)
		sfx.play("horn")
		add_shake(14.0)
	update_gates()
	if crowd_cleared():
		sector_clear()

## Cleared when the whole crowd (and the boss) is dead. Gold goblins may run away.
func crowd_cleared() -> bool:
	if budget_spawned < sector_budget or not rush_done or rush_queue > 0:
		return false
	if is_boss_sector() and not boss_spawned:
		return false
	for e in enemies:
		if not bool(e["dead"]) and e["kind"] != "goblin":
			return false
	return true

## Regular crowd for this sector (the Crowd Rush horde comes on top).
## Early-game ease: `start` in sector 1, climbing evenly to 1.0 at sector 6; later sectors are untouched.
func early_ease(start: float, s: int = -1) -> float:
	var x = sector if s < 0 else s
	if x >= 6:
		return 1.0
	return start + (1.0 - start) * float(x - 1) / 5.0

## Monsters per sector. Sector 1 sends ~55% of the old crowd and ramps back to the full count by sector 6.
func budget_for(s: int) -> int:
	var hard_mul = 1.25 if hard_mode else 1.0
	return int((60 + 12 * mini(s, 25) + 4 * maxi(0, s - 25)) * float(route.get("spawns", 1.0)) * early_ease(0.55, s) * crowd_ramp(s) * hard_mul)

func rush_size() -> int:
	var hard_mul = 1.25 if hard_mode else 1.0
	return int((30 + 9 * mini(sector, 25) + 3 * maxi(0, sector - 25)) * float(route.get("spawns", 1.0)) * early_ease(0.55) * crowd_ramp() * hard_mul)

## The street roster grows only when you kill a boss: tier N opens after N bosses.
const ENEMY_TIERS = [["blob", "zoomer", "nurse", "spitter"], ["kaboomba", "chonk", "mitosis"],
	["riot", "bull", "larry"], ["tick", "mama", "mortar"], ["totem", "blinky"]]
const ENEMY_WEIGHT = {"blob": 10.0, "zoomer": 4.0, "nurse": 0.8, "spitter": 2.0, "kaboomba": 1.5, "chonk": 1.5,
	"mitosis": 2.0, "riot": 1.2, "bull": 1.2, "larry": 1.0, "tick": 1.2, "mama": 0.7, "mortar": 1.0, "totem": 0.35, "blinky": 1.0}

func pick_enemy() -> String:
	var pool = {}
	for t in range(mini(bosses_beaten, ENEMY_TIERS.size() - 1) + 1):
		for k in ENEMY_TIERS[t]:
			if k == "totem" and totems.size() >= 2:
				continue
			var w = float(ENEMY_WEIGHT[k])
			# The newest tier shows up a lot in its first sector so you actually meet it.
			if t == bosses_beaten and t > 0 and sector == fresh_tier_sector:
				w = maxf(w * 2.5, 2.0)
			pool[k] = w
	var total = 0.0
	for k in pool:
		total += pool[k]
	var r = randf() * total
	for k in pool:
		r -= pool[k]
		if r <= 0.0:
			return k
	return "blob"

func spawn_enemy(kind: String, pos: Vector2, force_boss = false, elite = null) -> Dictionary:
	var d: Dictionary = enemy_db.get(kind, enemy_db["blob"])
	var scale = enemy_scale()
	var is_boss = bool(d.get("boss", false)) or force_boss
	var is_elite = false
	if elite == null:
		var base_elite = (0.02 + mini(sector, 20) * 0.005 + maxi(0, sector - 20) * 0.003) * (1.4 if hard_mode else 1.0)
		is_elite = not is_boss and kind != "goblin" and randf() < base_elite * (1.0 + st("elitechance")) * float(route.get("elites", 1.0))
	else:
		is_elite = bool(elite)
	# Enemy HP follows enemy_scale(); it grows a little toward the end of each sector.
	var late = maxi(0, sector - 5)
	var hp = float(d["hp"]) * scale * (1.0 + progress() * 0.3) * (3.0 if is_elite else 1.0) * (1.5 if hard_mode else 1.0)
	if is_boss:
		hp = float(d["hp"]) * scale * (1.5 if hard_mode else 1.0)
		if sector > WIN_SECTOR:
			hp *= pow(1.8, float(mini(sector - WIN_SECTOR, 20)))
	serial += 1
	var e = {"id": serial, "kind": kind, "pos": pos, "vel": Vector2.ZERO, "kb": Vector2.ZERO,
		"hp": hp, "max_hp": hp, "r": float(d["r"]) * (1.3 if is_elite else 1.0),
		"speed": float(d["speed"]) * randf_range(0.9, 1.1) * (1.0 + 0.02 * float(late)) * (1.15 if hard_mode else 1.0) * (1.0 + st("enemyspeed")),
		"dmg": float(d["dmg"]) * early_ease(0.65) * (1.0 + (sector - 1) * 0.07) * (1.0 + 0.024 * float(late * late)) * (1.4 if is_elite else 1.0) * (1.4 if hard_mode else 1.0),
		"mass": float(d["mass"]) * (2.0 if is_elite else 1.0) * (1.0 + 0.03 * float(late)), "color": Color(str(d["color"])),
		"elite": is_elite, "boss": is_boss, "dead": false, "flash": 0.0, "t": 0.0, "cd": randf_range(0.5, 2.0),
		"wind": 0.0, "charge": 0.0, "cdir": Vector2.ZERO, "phase": randf() * TAU, "xp": int(d["xp"]),
		"burn": 0.0, "chill": 0.0, "frozen": 0.0, "shock": 0.0, "poison": 0.0, "bleed": 0.0, "slow": 0.0,
		"stun": 0.0, "charm": 0.0, "wet": 0.0, "mark": 0.0, "pinned": 0.0, "bubble": 0.0, "flung": 0.0,
		"tick": randf() * 0.5, "sdt": randf() * 0.1, "aim": Vector2.DOWN, "gen": 0, "squash": 0.0, "spawn": 0.0}
	if is_elite:
		# Elite affixes: 1 early, 2 from sector 8, 3 from sector 14.
		var pool = ["HASTED", "ARMORED", "VOLATILE", "SPLITTER", "REGEN", "TURRET"]
		pool.shuffle()
		e["affix"] = pool.slice(0, 1 + int(sector >= 10) + int(sector >= 14))
		if e["affix"].has("HASTED"):
			e["speed"] = float(e["speed"]) * 1.6
	enemies.append(e)
	return e

func spawn_barrel(pos: Vector2, dropped = false) -> void:
	barrels.append({"pos": pos, "hp": 12.0, "drop": 0.6 if dropped else 0.0, "id": -1, "armed": false, "fuse": 0.0})

func gate_options() -> Array:
	return [
		{"label": "+1 MULTISHOT", "mods": {"mult": 1}, "good": true},
		{"label": "+25% FIRE RATE", "mods": {"rate": 0.25}, "good": true},
		{"label": "+30% DAMAGE", "mods": {"dmg": 0.3}, "good": true},
		{"label": "+1 PIERCE", "mods": {"pierce": 1}, "good": true},
		{"label": "+1 BLADE", "mods": {"orbit": 1}, "good": true},
		{"label": "+1 RICOCHET", "mods": {"rico": 1}, "good": true},
		{"label": "BURN 25%", "mods": {"burn": 0.25}, "good": true},
		{"label": "FREEZE 25%", "mods": {"freeze": 0.25}, "good": true},
		{"label": "SPLIT x1", "mods": {"split": 1}, "good": true},
		{"label": "+1 DRONE", "mods": {"drone": 1}, "good": true},
		{"label": "BIGGER BULLETS", "mods": {"size": 0.4, "knock": 0.3}, "good": true},
		{"label": "EXPLOSIVE", "mods": {}, "boom": true, "good": true},
		{"label": "HEAL 25", "heal": 25, "good": true},
		{"label": "+12 GOLD", "gold": 12, "good": true},
		{"label": "BACKSHOTS +1", "mods": {"rear": 1}, "good": true},
	]

func spawn_gate_pair(y: float) -> void:
	var options = gate_options()
	options.shuffle()
	var left = options[0]
	var right = options[1]
	if randf() < 0.3:
		right = {"label": "-30 HP  /  +1 TREASURE", "hurt": 30, "chest": 1, "good": false}
	gates.append({"y": y, "left": left, "right": right, "used": false})

func update_gates() -> void:
	for gate in gates:
		if bool(gate["used"]):
			continue
		if float(hero["pos"].y) < float(gate["y"]):
			gate["used"] = true
			var opt = gate["left"] if float(hero["pos"].x) < 0.0 else gate["right"]
			gate["picked"] = "left" if float(hero["pos"].x) < 0.0 else "right"
			apply_gate(opt)

func apply_gate(opt: Dictionary) -> void:
	var mods: Dictionary = opt.get("mods", {})
	for k in mods:
		gate_mods[k] = float(gate_mods.get(k, 0.0)) + float(mods[k])
	if opt.get("boom", false):
		gate_mods["gate_boom"] = 1.0
	if opt.has("heal"):
		heal(float(opt["heal"]))
	if opt.has("gold"):
		gold += int(opt["gold"])
	if opt.has("hurt"):
		hero["hp"] = maxf(1.0, float(hero["hp"]) - float(opt["hurt"]))
	if opt.has("chest"):
		pending_chests += int(opt["chest"])
	stats_dirty = true
	flash_screen(Color(0.4, 1, 0.8) if opt.get("good", true) else Color(1, 0.3, 0.3), 0.25)
	banner(str(opt["label"]), "road bonus for this sector", 1.6)
	sfx.play("gate")

func sector_clear() -> void:
	if is_boss_sector() and bosses_beaten < ENEMY_TIERS.size() - 1:
		bosses_beaten += 1
		fresh_tier_sector = sector + 1
	phase = "cleared"
	clear_t = 1.6
	# Every remaining enemy pops into gems: the reward for punching through.
	for e in enemies:
		if not bool(e["dead"]):
			e["dead"] = true
			if not e.has("summon"):
				spawn_pickup("xp", e["pos"], int(e["xp"]))
			spawn_burst(e["pos"], e["color"], 6)
	enemies.clear()
	for s in shots.duplicate():
		if not bool(s["friendly"]):
			shots.erase(s)
	for pk in pickups:
		pk["vacuum"] = true
	var stipend = 5 + sector * 2
	gold += stipend
	if st("interest") > 0:
		var interest = mini(15 * int(st("interest")), int(gold * 0.1 * st("interest")))
		gold += interest
		say(hero["pos"] + Vector2(0, -90), "+%d INTEREST" % interest, Color("ffd24d"), 22)
	if route.has("clear_chest"):
		pending_chests += int(route["clear_chest"])
	banner("SECTOR CLEARED", "+%d gold" % stipend, 2.0)
	sfx.play("clear")
	best["sector"] = maxi(int(best["sector"]), sector)
	if sector == WIN_SECTOR:
		state = "victory"
		award_profile()

# ================================================================= route map
## One column per sector. Every 5th sector is a single boss node; past WIN_SECTOR, every sector is.
const NODE_INFO = {
	"fight": {"name": "FIGHT", "desc": "A normal stretch of road.", "color": "5bead8"},
	"elite": {"name": "ELITE ROAD", "desc": "Many more elites. +30% gold and a treasure chest at the end.", "color": "ffb84d"},
	"hell": {"name": "HELL LANE", "desc": "60% more enemies that hit 20% harder. +80% EXP and a treasure chest at the end.", "color": "ff5a6a"},
	"shop": {"name": "SHOP", "desc": "Buy cards, guns and healing. Better stock after Elite or Hell roads. No fight.", "color": "ffd24d"},
	"rest": {"name": "CAMPFIRE", "desc": "Heal 40% of max HP, or train a gun one level. No fight.", "color": "7dff9a"},
	"treasure": {"name": "TREASURE", "desc": "Pick a free card, Rare or better. No fight.", "color": "c58cff"},
	"event": {"name": "UNKNOWN", "desc": "A random encounter. Could be a deal, a gamble or a trap. No fight.", "color": "b8c8ff"},
	"boss": {"name": "BOSS", "desc": "A boss blocks the road. The next column always has a shop.", "color": "ff4d6a"},
}
const NODE_WEIGHTS = {"fight": 42.0, "elite": 12.0, "hell": 9.0, "shop": 8.0, "rest": 9.0, "treasure": 5.0, "event": 15.0}
const NODE_FROM = {"fight": 1, "elite": 3, "hell": 4, "shop": 2, "rest": 3, "treasure": 2, "event": 2}

func gen_map(upto: int) -> void:
	while map_cols.size() < upto:
		var c = map_cols.size()
		var s = c + 1
		var single = s == 1 or s % 5 == 0 or s > WIN_SECTOR
		var n = 1 if single else randi_range(2, 4)
		var nodes = []
		for i in range(n):
			var t = "fight"
			if s > WIN_SECTOR or s % 5 == 0:
				t = "boss"
			elif s > 1:
				t = roll_node(s)
			var node = {"type": t, "x": (i + 0.5) / n, "next": []}
			# Fight roads often come with a bonus for that sector (the old pick-a-door gates), or a risky deal.
			if t in ["fight", "elite", "hell"] and s > 1 and randf() < 0.55:
				if randf() < 0.2:
					node["mod"] = {"label": "-30 HP / +1 TREASURE", "hurt": 30, "chest": 1, "good": false}
				else:
					var opts = gate_options()
					node["mod"] = opts[randi() % opts.size()]
			nodes.append(node)
		if not single:
			var combat = nodes.filter(func(nd): return nd["type"] in ["fight", "elite", "hell"])
			if combat.is_empty():
				nodes[randi() % n]["type"] = "fight"
			if s % 5 == 4 and nodes.filter(func(nd): return nd["type"] == "rest").is_empty():
				nodes[randi() % n]["type"] = "rest"
			# Right after a boss, one of the roads is always a shop: spend now, or fight on for a better one.
			if s % 5 == 1 and nodes.filter(func(nd): return nd["type"] == "shop").is_empty():
				var k = randi() % n
				if nodes.filter(func(nd): return nd["type"] in ["fight", "elite", "hell"]).size() == 1 and nodes[k]["type"] in ["fight", "elite", "hell"]:
					k = (k + 1) % n
				nodes[k]["type"] = "shop"
		if c > 0:
			link_cols(map_cols[c - 1], nodes)
		map_cols.append(nodes)

func roll_node(s: int) -> String:
	var total = 0.0
	for k in NODE_WEIGHTS:
		if s >= int(NODE_FROM[k]):
			total += float(NODE_WEIGHTS[k])
	var r = randf() * total
	for k in NODE_WEIGHTS:
		if s >= int(NODE_FROM[k]):
			r -= float(NODE_WEIGHTS[k])
			if r <= 0.0:
				return k
	return "fight"

func link_cols(a: Array, b: Array) -> void:
	var incoming = {}
	for i in range(a.size()):
		var j = clampi(roundi(float(a[i]["x"]) * b.size() - 0.5), 0, b.size() - 1)
		a[i]["next"].append(j)
		incoming[j] = true
		var side = j + (1 if randf() < 0.5 else -1)
		if randf() < 0.55 and side >= 0 and side < b.size() and not a[i]["next"].has(side):
			a[i]["next"].append(side)
			incoming[side] = true
	for j in range(b.size()):
		if incoming.has(j):
			continue
		var best_i = 0
		for i in range(a.size()):
			if absf(float(a[i]["x"]) - float(b[j]["x"])) < absf(float(a[best_i]["x"]) - float(b[j]["x"])):
				best_i = i
		a[best_i]["next"].append(j)

## The boss-clear intermission remains until the player explicitly continues.
func continue_after_boss() -> void:
	if state != "boss_result" or boss_result_t < RouteFlow.RESULT_MIN_WAIT:
		return
	open_map()

func open_map() -> void:
	gen_map(sector + 7)
	phase = "map"
	state = "map"
	map_pick = -1
	var nxt: Array = map_cols[sector - 1][map_at]["next"]
	if nxt.size() == 1:
		map_pick = int(nxt[0])
	sfx.play("pick")

## Select a route without moving. GO starts a non-interactive map departure.
func map_select(i: int) -> void:
	if state != "map":
		return
	var nxt: Array = map_cols[sector - 1][map_at]["next"]
	if not nxt.has(i):
		return
	if map_pick != i:
		map_pick = i
		sfx.play("pick")

func map_go() -> void:
	if state != "map" or map_pick < 0:
		return
	if not map_cols[sector - 1][map_at]["next"].has(map_pick):
		return
	travel_title = str(NODE_INFO[str(map_cols[sector][map_pick]["type"])]["name"])
	travel_t = RouteFlow.TRAVEL_DURATION
	state = "travel"
	sfx.play("gate")

## Change the scene only after the route animation has finished.
func finish_travel() -> void:
	if state != "travel":
		return
	var node = map_cols[sector][map_pick]
	map_at = map_pick
	map_path.append(Vector2i(sector, map_pick))
	sector += 1
	travel_t = 0.0
	match str(node["type"]):
		"shop":
			open_shop()
		"rest":
			phase = "rest"
			state = "rest"
		"event":
			start_event()
		"treasure":
			phase = "treasure"
			pending_chests += 1
			open_offers("chest")
			if state != "levelup":
				pending_chests = 0
				open_map()
		_:
			start_node_fight(str(node["type"]))
			if node.has("mod"):
				apply_gate(node["mod"])

func start_node_fight(t: String) -> void:
	if t in ["elite", "hell"]:
		route_risk += 1
	match t:
		"elite":
			route = {"name": "ELITE ROAD", "elites": 3.0, "gold": 1.3, "clear_chest": 1}
		"hell":
			route = {"name": "HELL LANE", "spawns": 1.6, "xpmul": 1.8, "taken": 1.2, "clear_chest": 1}
		"boss":
			route = {"name": "BOSS ROAD"}
		_:
			route = {"name": "HIGHWAY"}
	state = "playing"
	begin_sector()

## Where to go after a card pick / gun swap: back to the fight, the shop, or the map.
func after_offer() -> void:
	state = "playing"
	if pending_chests > 0 or pending_levels > 0:
		return
	if phase == "treasure":
		open_map()
	elif phase == "shop":
		state = "shop"

# ================================================================= shop & campfire
## Shops are map nodes. Riskier roads since the last shop (Elite, Hell Lane) stock it with better cards.
func open_shop() -> void:
	phase = "shop"
	state = "shop"
	shop_bonus = 3.0 * route_risk
	route_risk = 0
	shop_items = make_shop_items()

func shop_luck() -> float:
	return shop_bonus
func make_shop_items() -> Array:
	var items = Effects.make_shop(self)
	items.append({"kind": "mystery", "price": roundi((70 + sector * 6) * clampf(1.0 - st("discount"), 0.7, 1.0))})
	for it in items:
		it["sold"] = false
	return items

func buy_shop(i: int) -> void:
	if state != "shop" or i < 0 or i >= shop_items.size():
		return
	var item = shop_items[i]
	if bool(item["sold"]):
		return
	var price = int(item["price"])
	if gold < price:
		sfx.play("deny")
		return
	gold -= price
	item["sold"] = true
	sfx.play("buy")
	match item["kind"]:
		"heal":
			heal(float(hero["maxhp"]) * 0.4)
		"maxhp":
			owned["_shop_hp"] = int(owned.get("_shop_hp", 0)) + 1
			stats_dirty = true
			Effects.recalc(self)
			heal(25)
		"mystery":
			var c = Effects.mystery_card(self)
			if c != null:
				item["revealed"] = str(c["id"])
				Effects.add_card(self, str(c["id"]))
				flash_screen(offer_color({"type": "card", "id": c["id"]}), 0.3)
		_:
			take_offer(item["offer"])

func reroll_shop() -> void:
	if state != "shop" or gold < shop_reroll_cost:
		sfx.play("deny")
		return
	gold -= shop_reroll_cost
	shop_reroll_cost += 12
	shop_items = make_shop_items()
	sfx.play("buy")

func rest_heal() -> void:
	if state != "rest":
		return
	heal(float(hero["maxhp"]) * 0.4)
	sfx.play("heal")
	open_map()

func rest_train(slot: int) -> void:
	if state != "rest" or slot < 0 or slot >= guns.size() or int(guns[slot]["lvl"]) >= 5:
		return
	guns[slot]["lvl"] = int(guns[slot]["lvl"]) + 1
	stats_dirty = true
	Effects.recalc(self)
	sfx.play("level")
	open_map()

# ================================================================= random encounters ("?" nodes)
## Options with "dice" roll that many d6 on screen before the outcome is applied.
const EVENTS = [
	{"id": "gambler", "title": "ROADSIDE GAMBLER", "text": "A man at a folding table shakes a cup. Bet 30 gold: roll 4 or more and he pays you 75.",
		"opts": [{"label": "BET 30 G", "dice": 1, "cost": 30}, {"label": "WALK AWAY"}]},
	{"id": "crate", "title": "MYSTERY CRATE", "text": "A sealed crate sits in the road. Roll to open it. 1: it explodes. 2-3: Common card. 4-5: Rare card. 6: Epic card.",
		"opts": [{"label": "OPEN IT", "dice": 1}, {"label": "LEAVE IT"}]},
	{"id": "mechanic", "title": "SHADY MECHANIC", "text": "\"40 gold and I'll tune one of your guns. No refunds.\" A random gun gains a level.",
		"opts": [{"label": "PAY 40 G", "cost": 40}, {"label": "NO THANKS"}]},
	{"id": "altar", "title": "BLOOD ALTAR", "text": "An altar asks for blood. Lose 25% of your max HP to take a free card, Rare or better.",
		"opts": [{"label": "OFFER BLOOD"}, {"label": "LEAVE"}]},
	{"id": "fountain", "title": "WISHING FOUNTAIN", "text": "Toss in 10 gold and roll. 6: a Four-Leaf Clover. 3-5: heal 25% HP. 1-2: nothing.",
		"opts": [{"label": "TOSS 10 G", "dice": 1, "cost": 10}, {"label": "LEAVE"}]},
	{"id": "dummy", "title": "TRAINING YARD", "text": "Free target practice. Roll the dice: each pip is worth 15% of a level in EXP.",
		"opts": [{"label": "TRAIN", "dice": 1}, {"label": "SKIP"}]},
	{"id": "double", "title": "DOUBLE OR NOTHING", "text": "Roll two dice. Doubles: an Epic card. Total 9 or more: a Rare card. Anything else: lose 15% max HP.",
		"opts": [{"label": "ROLL TWO DICE", "dice": 2}, {"label": "LEAVE"}]},
	{"id": "traveler", "title": "STRANDED DRIVER", "text": "A driver needs help pushing a car out of the crowd. You will take some hits (15 HP). Pays 35 gold.",
		"opts": [{"label": "HELP (-15 HP)"}, {"label": "IGNORE"}]},
]

func start_event() -> void:
	phase = "event"
	state = "event"
	event = EVENTS[randi() % EVENTS.size()].duplicate(true)
	event_stage = "choose"
	event_dice = []
	event_roll_t = 0.0
	event_result = ""

func event_choose(i: int) -> void:
	if state != "event" or event_stage != "choose" or i < 0 or i >= event["opts"].size():
		return
	var opt: Dictionary = event["opts"][i]
	if int(opt.get("cost", 0)) > gold:
		sfx.play("deny")
		return
	gold -= int(opt.get("cost", 0))
	event_opt = i
	if int(opt.get("dice", 0)) > 0:
		event_dice = []
		for k in range(int(opt["dice"])):
			event_dice.append(randi_range(1, 6))
		event_faces = event_dice.duplicate()
		event_roll_t = 1.3
		event_stage = "rolling"
		sfx.play("pick")
	else:
		resolve_event()

## Called from _process while the dice tumble.
func update_event(delta: float) -> void:
	if event_stage != "rolling":
		return
	event_roll_t -= delta
	event_face_t -= delta
	if event_face_t <= 0.0 and event_roll_t > 0.15:
		event_face_t = 0.075
		for k in range(event_faces.size()):
			event_faces[k] = randi_range(1, 6)
		sfx.play("bonk" if randf() < 0.3 else "pick")
	if event_roll_t <= 0.0:
		event_faces = event_dice.duplicate()
		resolve_event()

func resolve_event() -> void:
	event_stage = "result"
	var id = str(event["id"])
	var first = event_opt == 0
	var roll = 0
	for d in event_dice:
		roll += int(d)
	var msg = "You move on."
	if first:
		match id:
			"gambler":
				if roll >= 4:
					gold += 75
					msg = "You rolled %d. He pays you 75 gold." % roll
				else:
					msg = "You rolled %d. He keeps your 30 gold." % roll
			"crate":
				if roll == 1:
					hurt_pct(0.2)
					msg = "You rolled 1. The crate explodes in your face."
				else:
					msg = "You rolled %d. " % roll + event_card(0 if roll <= 3 else (1 if roll <= 5 else 2))
			"mechanic":
				var up = []
				for k in range(guns.size()):
					if int(guns[k]["lvl"]) < 5:
						up.append(k)
				if up.is_empty():
					gold += 40
					msg = "Your guns are already maxed. He gives the money back."
				else:
					var w = guns[up[randi() % up.size()]]
					w["lvl"] = int(w["lvl"]) + 1
					stats_dirty = true
					msg = "%s is now level %d." % [Weapons.display_name(self, w), int(w["lvl"])]
			"altar":
				hurt_pct(0.25)
				var c = Effects.random_card(self, 1, 5, Effects.CHEST_LUCK)
				msg = "The altar drinks. " + (take_card_msg(c) if c != null else "Nothing happens.")
			"fountain":
				if roll == 6 and Effects.eligible(self, card_by_id["four_leaf"]):
					Effects.add_card(self, "four_leaf")
					msg = "You rolled 6. A Four-Leaf Clover floats up. +1 luck."
				elif roll >= 3:
					heal(float(hero["maxhp"]) * 0.25)
					msg = "You rolled %d. The water heals you." % roll
				else:
					msg = "You rolled %d. Nothing happens." % roll
			"dummy":
				gain_xp(float(xp_need) * 0.15 * roll / 0.7)
				msg = "You rolled %d. +%d%% of a level." % [roll, roll * 15]
			"double":
				if event_dice.size() == 2 and event_dice[0] == event_dice[1]:
					msg = "Doubles! " + event_card(2)
				elif roll >= 9:
					msg = "You rolled %d. " % roll + event_card(1)
				else:
					hurt_pct(0.15)
					msg = "You rolled %d. That hurt." % roll
			"traveler":
				hero["hp"] = maxf(1.0, float(hero["hp"]) - 15.0)
				gold += 35
				msg = "The car rolls free. +35 gold."
	event_result = msg
	Effects.recalc(self)
	sfx.play("buy" if first else "pick")

func hurt_pct(p: float) -> void:
	hero["hp"] = maxf(1.0, float(hero["hp"]) - float(hero["maxhp"]) * p)
	flash_screen(Color(1, 0.2, 0.25), 0.25)
	sfx.play("hurt")

func event_card(rarity: int) -> String:
	return take_card_msg(Effects.card_of_rarity(self, rarity, 0, 5))

func take_card_msg(c) -> String:
	if c == null:
		gold += 25
		return "Nothing fits your build. +25 gold instead."
	Effects.add_card(self, str(c["id"]))
	return "You got %s (%s)." % [str(c["name"]), ["Common", "Rare", "Epic", "Legendary", "Mythic", "Ascendant"][int(c["rarity"])]]

# ================================================================= profile, unlocks, hard mode
## Cards and guns unlock by playing: each profile level opens CARDS_PER_LEVEL more cards
## (lowest rarity first) and one more gun.
const START_CARDS = 110
const CARDS_PER_LEVEL = 10
const START_GUNS = 8
## Kills count too: every KILLS_PER_CARD lifetime kills opens one more card, and guns also open at kill milestones.
const KILLS_PER_CARD = 250
## Healing cards come last in the unlock order and only show up once the run reaches this level.
const HEAL_MIN_LEVEL = 10
## The result screen ignores input this long, so mashing through the death doesn't skip it.
const LOST_LOCK = 1.4

## Permanent upgrades bought with GOO in the main menu. Cost of the next level = cost * (level + 1).
## "stat" levels add per-level to the run stats (same keys as card mods); gold/reroll are applied at run start.
const META_UPS = [
	{"id": "hp", "name": "THICK SKIN", "desc": "+10 max HP", "stat": "maxhp", "per": 10.0, "max": 5, "cost": 20},
	{"id": "dmg", "name": "BIGGER BULLETS", "desc": "+5% damage", "stat": "dmg", "per": 0.05, "max": 5, "cost": 25},
	{"id": "rate", "name": "TWITCHY FINGER", "desc": "+4% fire rate", "stat": "rate", "per": 0.04, "max": 5, "cost": 25},
	{"id": "speed", "name": "NEW SNEAKERS", "desc": "+3% move speed", "stat": "speed", "per": 0.03, "max": 5, "cost": 15},
	{"id": "armor", "name": "CARDBOARD VEST", "desc": "-1 damage per hit", "stat": "armor", "per": 1.0, "max": 3, "cost": 40},
	{"id": "revive", "name": "NOT TODAY", "desc": "Revive once per run", "stat": "revive", "per": 1.0, "max": 2, "cost": 150},
	{"id": "dash", "name": "SPARE LEGS", "desc": "+1 dash charge", "stat": "dashes", "per": 1.0, "max": 1, "cost": 120},
	{"id": "reroll", "name": "SECOND OPINION", "desc": "+1 card reroll per run", "stat": "", "per": 1.0, "max": 5, "cost": 30},
	{"id": "choices", "name": "INDECISIVE", "desc": "+1 card to pick from", "stat": "choices", "per": 1.0, "max": 1, "cost": 200},
	{"id": "luck", "name": "LUCKY SOCKS", "desc": "+1.5 luck (rarer cards)", "stat": "luck", "per": 1.5, "max": 4, "cost": 30},
	{"id": "startcard", "name": "HEAD START", "desc": "Start with a free card", "stat": "", "per": 1.0, "max": 2, "cost": 60},
	{"id": "xp", "name": "BOOK SMARTS", "desc": "+5% EXP", "stat": "xp", "per": 0.05, "max": 5, "cost": 20},
	{"id": "magnet", "name": "STICKY HANDS", "desc": "+15% pickup range", "stat": "magnet", "per": 0.15, "max": 4, "cost": 10},
	{"id": "gold", "name": "POCKET MONEY", "desc": "+15 gold at the start", "stat": "", "per": 15.0, "max": 5, "cost": 10},
	{"id": "haggle", "name": "HAGGLER", "desc": "Shop rerolls -4 gold", "stat": "", "per": 4.0, "max": 3, "cost": 15},
]

func meta_level(id: String) -> int:
	return int(profile.get("ups", {}).get(id, 0))

func meta_cost(u: Dictionary) -> int:
	return int(u["cost"]) * (meta_level(str(u["id"])) + 1)

## Stat bonuses from bought upgrades, merged into S by Effects.rebuild like gate buffs.
func meta_mods() -> Dictionary:
	var m = {}
	for u in META_UPS:
		var lv = meta_level(str(u["id"]))
		if lv > 0 and str(u["stat"]) != "":
			m[str(u["stat"])] = float(u["per"]) * lv
	return m

func buy_meta(i: int) -> void:
	if i < 0 or i >= META_UPS.size():
		return
	var u = META_UPS[i]
	var id = str(u["id"])
	if meta_level(id) >= int(u["max"]) or int(profile["goo"]) < meta_cost(u):
		sfx.play("block")
		return
	profile["goo"] = int(profile["goo"]) - meta_cost(u)
	var ups: Dictionary = profile.get("ups", {})
	ups[id] = meta_level(id) + 1
	profile["ups"] = ups
	sfx.play("level")
	save_options()

## HEAD START: a random unlocked common or rare card that needs nothing else to work.
func random_start_card() -> String:
	var pool = []
	for c in db_cards:
		var id = str(c["id"])
		if int(c["rarity"]) <= 1 and not bool(c.get("cursed", false)) and not owned.has(id) and Effects.eligible(self, c):
			pool.append(id)
	return "" if pool.is_empty() else str(pool[randi() % pool.size()])

## Bestiary: lifetime kills per monster kind. The first kill of a kind unlocks its entry.
func note_mob(kind: String) -> void:
	var mobs: Dictionary = profile["mobs"]
	if not mobs.has(kind):
		mobs[kind] = 0
		if autotest == "":
			unlock_toasts.append({"type": "mob", "id": kind, "t": 2.6})
			profile["announced_mobs"][kind] = true
	mobs[kind] = int(mobs[kind]) + 1

## Collection order: street tiers, the extras, then bosses.
func mob_order() -> Array:
	var out = []
	for t in ENEMY_TIERS:
		out.append_array(t)
	out.append_array(["mini", "goblin"])
	for k in enemy_db:
		if bool(enemy_db[k].get("boss", false)):
			out.append(k)
	return out

func mob_tier(kind: String) -> int:
	for t in range(ENEMY_TIERS.size()):
		if ENEMY_TIERS[t].has(kind):
			return t
	return 1 if kind == "mini" else 0

## GOO for a finished run: deeper sectors and boss kills pay the most.
func goo_for_run() -> int:
	var goo = sector * 4 + int(kills / 40) + bosses_beaten * 20
	return int(goo * 1.5) if hard_mode else goo

func gun_kill_need(k: int) -> int:
	return 150 * k * (k + 1)

func lifetime_kills() -> int:
	return int(profile.get("kills", 0)) + (0 if run_awarded else kills)
## Hard mode seals this share of your unlocked cards at random for the whole run (you never see which).
const HARD_SEALED = 0.35

func profile_need(lv: int) -> int:
	return 100 + 30 * lv

func compute_unlocks() -> void:
	var order = db_cards.duplicate()
	var idx = {}
	for i in range(db_cards.size()):
		idx[str(db_cards[i]["id"])] = i
	order.sort_custom(func(a, b):
		var ha = bool(a.get("heal", false))
		var hb = bool(b.get("heal", false))
		if ha != hb:
			return hb
		return int(a["rarity"]) < int(b["rarity"]) or int(a["rarity"]) == int(b["rarity"]) and idx[str(a["id"])] < idx[str(b["id"])])
	var lv = int(profile["level"])
	var lk = lifetime_kills()
	var n = mini(order.size(), START_CARDS + CARDS_PER_LEVEL * lv + int(lk / KILLS_PER_CARD))
	if autotest in ["soak", "cards"]:
		n = order.size()
	unlocked_cards.clear()
	for i in range(order.size()):
		var id = str(order[i]["id"])
		unlock_level[id] = 0 if i < START_CARDS else int(ceil(float(i - START_CARDS + 1) / CARDS_PER_LEVEL))
		unlock_index[id] = i
		if i < n:
			unlocked_cards[id] = true
	var kg = 0
	while gun_kill_need(kg + 1) <= lk:
		kg += 1
	var ng = mini(weapon_ids.size(), START_GUNS + maxi(lv, kg))
	unlocked_guns = weapon_ids.slice(0, ng)
	next_unlock_kills = 0
	if n < order.size():
		next_unlock_kills = (int(lk / KILLS_PER_CARD) + 1) * KILLS_PER_CARD
	if ng < weapon_ids.size():
		var gk = gun_kill_need(kg + 1)
		next_unlock_kills = gk if next_unlock_kills == 0 else mini(next_unlock_kills, gk)
	if autotest in ["soak", "cards"]:
		unlocked_guns = weapon_ids.duplicate()

func card_available(id: String) -> bool:
	if bool(card_by_id[id].get("heal", false)) and level < HEAL_MIN_LEVEL:
		return false
	return unlocked_cards.has(id) and not sealed.has(id)

## Recompute unlocks and queue whatever is new for the HUD popup and the result screen.
func refresh_unlocks() -> void:
	if autotest != "":
		return
	var had_cards = unlocked_cards.duplicate()
	var had_guns = unlocked_guns.duplicate()
	compute_unlocks()
	for id in unlocked_cards.keys():
		if not had_cards.has(id) and not run_unlocks.has({"type": "card", "id": id}):
			run_unlocks.append({"type": "card", "id": id})
			unlock_toasts.append({"type": "card", "id": id, "t": 2.6})
	for id in unlocked_guns:
		if not had_guns.has(id) and not run_unlocks.has({"type": "gun", "id": id}):
			run_unlocks.append({"type": "gun", "id": id})
			unlock_toasts.append({"type": "gun", "id": id, "t": 2.6})
	if unlock_toasts.size() > 6:
		# A big batch (like a profile level-up) would take forever one by one; keep the newest few.
		unlock_toasts = unlock_toasts.slice(unlock_toasts.size() - 6)

func seal_cards() -> void:
	sealed.clear()
	if not hard_mode:
		return
	var pool = unlocked_cards.keys()
	pool.shuffle()
	for i in range(int(pool.size() * HARD_SEALED)):
		sealed[pool[i]] = true

## Called once when a run ends (death or victory). Returns nothing; fills last_award for the result screen.
func award_profile() -> void:
	if run_awarded or autotest != "":
		return
	run_awarded = true
	var gain = sector * 12 + int(kills / 40) + int(sector / 5) * 30
	if hard_mode:
		gain = int(gain * 1.5)
	var levels = 0
	profile["kills"] = int(profile.get("kills", 0)) + kills
	var goo = goo_for_run()
	profile["goo"] = int(profile.get("goo", 0)) + goo
	profile["xp"] = int(profile["xp"]) + gain
	while int(profile["xp"]) >= profile_need(int(profile["level"])):
		profile["xp"] = int(profile["xp"]) - profile_need(int(profile["level"]))
		profile["level"] = int(profile["level"]) + 1
		levels += 1
	# refresh_unlocks() must compare against the previous set before recomputing.
	# Calling compute_unlocks() first used to erase genuine new-unlock events.
	refresh_unlocks()
	last_award = {"xp": gain, "levels": levels, "cards": run_unlocks.size(), "goo": goo}
	save_options()

# ================================================================= pickups & xp
func spawn_pickup(kind: String, pos: Vector2, value: int) -> void:
	if pickups.size() > 320 and kind == "xp":
		# Merge into an existing gem so the floor never turns into a lag carpet.
		var target = pickups[randi() % pickups.size()]
		if target["kind"] == "xp":
			target["value"] = int(target["value"]) + value
			return
	pickups.append({"kind": kind, "pos": pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)),
		"vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 140), "value": value, "t": 0.0, "vacuum": false})

func update_pickups(dt: float) -> void:
	var hp: Vector2 = hero["pos"]
	var radius = 90.0 * (1.0 + st("magnet"))
	for i in range(pickups.size() - 1, -1, -1):
		var p = pickups[i]
		p["t"] = float(p["t"]) + dt
		p["vel"] = p["vel"] * exp(-5.0 * dt)
		var d = p["pos"].distance_to(hp)
		if bool(p["vacuum"]) or d < radius:
			var pull = 420.0 + (radius - minf(d, radius)) * 6.0 + float(p["t"]) * 120.0
			p["pos"] = p["pos"].move_toward(hp, pull * dt)
		else:
			p["pos"] += p["vel"] * dt
		if d < 24.0:
			collect(p)
			pickups.remove_at(i)

func collect(p: Dictionary) -> void:
	match p["kind"]:
		"xp":
			gain_xp(float(p["value"]))
			sfx.play("gem")
			if procs.has("xp"):
				Effects.trigger(self, "xp", {"pos": p["pos"], "gen": 0})
		"gold":
			var amount = maxi(1, roundi(float(p["value"]) * (1.0 + st("goldp")) * float(route.get("gold", 1.0))))
			gold += amount
			sfx.play("coin")
		"heart":
			heal(18.0)
			sfx.play("heal")
		"chest":
			pending_chests += 1
			banner("TREASURE!", "pick a free card", 1.4)
			sfx.play("chest")

func gain_xp(amount: float) -> void:
	xp += amount * 0.7 * (1.0 + st("xp")) * float(route.get("xpmul", 1.0))
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = xp_for(level)
		if level <= 4 or level % 2 == 0:
			pending_levels += 1
		levelup_delay = 0.35
		say(hero["pos"] + Vector2(0, -60), "LEVEL UP!", Color("d6a8ff"), 34)
		spawn_ring_fx(hero["pos"], Color("d6a8ff"), 90.0)
		Effects.trigger(self, "level", {"pos": hero["pos"], "gen": 0})

# ================================================================= offers
func open_offers(mode: String) -> void:
	offer_mode = mode
	if dying_t > 0.0:
		return
	offers = Effects.make_offers(self, mode)
	if offers.is_empty():
		if mode == "chest":
			pending_chests = 0
		else:
			pending_levels = 0
		return
	offer_t = 0.0
	offer_sel = 0
	state = "levelup"
	sfx.play("chest" if mode == "chest" else "level")

func choose_offer(i: int) -> void:
	if state != "levelup" or i < 0 or i >= offers.size() or offer_t < 0.35:
		return
	var o = offers[i]
	sfx.play("pick")
	if offer_mode == "chest":
		pending_chests = maxi(0, pending_chests - 1)
	else:
		pending_levels = maxi(0, pending_levels - 1)
	after_offer()
	take_offer(o)
	flash_screen(offer_color(o), 0.2)

func offer_color(o: Dictionary) -> Color:
	var r = Effects.offer_rarity(self, o)
	return hud.RCOL[clampi(r, 0, 5)]

func take_offer(o: Dictionary) -> void:
	match o["type"]:
		"card":
			Effects.add_card(self, str(o["id"]))
		"gun_new":
			if guns.size() < 2 + int(st("slots")):
				guns.append(Weapons.new_gun(self, str(o["gun"]), int(o.get("tier", 0))))
				stats_dirty = true
			else:
				replace_gun = str(o["gun"])
				replace_tier = int(o.get("tier", 0))
				state = "replace"
		"gun_up":
			var w = guns[int(o["slot"])]
			w["lvl"] = mini(5, int(w["lvl"]) + 1)
			stats_dirty = true
		"evolve":
			var w2 = guns[int(o["slot"])]
			w2["evolved"] = true
			stats_dirty = true
			flash_screen(Color("ffcf4d"), 0.4)
			banner("EVOLVED!", Weapons.display_name(self, w2), 2.0)
	Effects.recalc(self)

func skip_gold() -> int:
	return 3 + sector

func reroll_offers() -> void:
	if state != "levelup" or rerolls <= 0:
		return
	rerolls -= 1
	offers = Effects.make_offers(self, offer_mode)
	offer_t = 0.2
	sfx.play("pick")

func skip_offer() -> void:
	if state != "levelup":
		return
	gold += skip_gold()
	if offer_mode == "chest":
		pending_chests = maxi(0, pending_chests - 1)
	else:
		pending_levels = maxi(0, pending_levels - 1)
	after_offer()
	sfx.play("coin")

func replace_slot(slot: int) -> void:
	if state != "replace":
		return
	if slot >= 0 and slot < guns.size():
		guns[slot] = Weapons.new_gun(self, replace_gun, replace_tier)
		stats_dirty = true
		Effects.recalc(self)
	after_offer()

# ================================================================= fx helpers
func banner(t: String, sub: String = "", secs: float = 2.0) -> void:
	banner_text = t
	banner_sub = sub
	banner_t = secs

func add_shake(v: float) -> void:
	shake = maxf(shake, v * float(settings["shake"]))

func flash_screen(c: Color, t: float) -> void:
	flash_color = c
	flash_t = t

func say(pos: Vector2, t: String, c: Color = Color.WHITE, size: int = 22) -> void:
	if texts.size() > 90:
		texts.remove_at(0)
	texts.append({"pos": pos, "text": t, "color": c, "size": size, "t": 0.0, "life": 1.1, "vel": Vector2(randf_range(-20, 20), -70)})

func number(pos: Vector2, amount: float, crit: bool) -> void:
	if not bool(settings["numbers"]):
		return
	if texts.size() > 80 and not crit:
		return
	var txt = str(roundi(amount))
	texts.append({"pos": pos + Vector2(randf_range(-8, 8), -10), "text": txt + ("!" if crit else ""),
		"color": Color("ffe14d") if crit else Color("ffffff"), "size": 22 if crit else 15, "t": 0.0,
		"life": 0.7, "vel": Vector2(randf_range(-40, 40), -110 if crit else -80), "num": true})

func update_texts(dt: float) -> void:
	for i in range(texts.size() - 1, -1, -1):
		var t = texts[i]
		t["t"] = float(t["t"]) + dt
		t["pos"] += t["vel"] * dt
		t["vel"] = t["vel"] * exp(-3.0 * dt)
		if float(t["t"]) >= float(t["life"]):
			texts.remove_at(i)

func spawn_burst(pos: Vector2, c: Color, n: int, speed = 200.0, size = 4.0) -> void:
	if not bool(settings["particles"]):
		n = mini(n, 2)
	if fx.size() > 650:
		n = mini(n, 1)
		if fx.size() > 900:
			return
	for i in range(n):
		var a = randf() * TAU
		var life = randf_range(0.25, 0.6)
		fx.append({"kind": "spark", "pos": pos, "vel": Vector2.from_angle(a) * randf_range(speed * 0.3, speed),
			"t": 0.0, "life": life, "color": c, "size": randf_range(size * 0.5, size)})

func spawn_ring_fx(pos: Vector2, c: Color, r: float) -> void:
	fx.append({"kind": "ring", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 0.35, "color": c, "size": r})

func add_zone(kind: String, pos: Vector2, r: float, t: float, extra = {}) -> Dictionary:
	if zones.size() > 90:
		zones.remove_at(0)
	var z = {"kind": kind, "pos": pos, "r": r * (1.0 + st("area") * 0.5), "t": t * (1.0 + st("dur")), "life": t * (1.0 + st("dur")), "tick": 0.0}
	z.merge(extra)
	zones.append(z)
	return z

# ================================================================= textures
var tex_cache: Dictionary = {}

func tex(path: String) -> Texture2D:
	if tex_cache.has(path):
		return tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img != null:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	tex_cache[path] = t
	return t

# ================================================================= queries
func enemies_near(p: Vector2, r: float) -> Array:
	return Combat.query(self, p, r)

func nearest_enemy(p: Vector2, r: float, exclude = null) -> Variant:
	var best_e = null
	var best_d = r * r
	for e in enemies:
		if bool(e["dead"]) or e == exclude or float(e["charm"]) > 0.0:
			continue
		var d = p.distance_squared_to(e["pos"])
		if d < best_d:
			best_d = d
			best_e = e
	return best_e

## Left mouse fires gun 1, right mouse gun 2, a third gun fires with either. Auto-fire (setting,
## default on touch screens) fires everything when an enemy is in range.
func fire_wanted(slot: int = 0) -> bool:
	if dying_t > 0.0:
		return false
	if autotest != "":
		return true
	var lmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if (slot == 0 and lmb) or (slot == 1 and rmb) or (slot >= 2 and (lmb or rmb)):
		return true
	if bool(settings["autofire"]) or is_touch_active():
		return nearest_enemy(hero["pos"], 700.0) != null
	return false

# ================================================================= input
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and aim_mouse_active:
		var rel = hud.get_global_transform_with_canvas().affine_inverse().basis_xform(event.relative)
		aim_screen += rel * float(settings["sensitivity"])
		aim_screen.x = clampf(aim_screen.x, 0.0, 720.0 if portrait else 1280.0)
		aim_screen.y = clampf(aim_screen.y, view_top, view_bottom)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.keycode
		if code == KEY_F11:
			var win = get_window()
			win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_EXCLUSIVE_FULLSCREEN
			return
		if code == KEY_F3:
			debug_mode = not debug_mode
			return
		match state:
			"menu":
				if code in [KEY_ENTER]:
					start_run()
			"playing":
				if dying_t > 0.0:
					return
				if code in [KEY_ESCAPE, KEY_P]:
					state = "paused"
				elif code in [KEY_SPACE, KEY_SHIFT]:
					try_dash()
				elif code == KEY_TAB:
					do_action("open_arsenal")
				elif code == KEY_F:
					try_bash()
				elif code == KEY_R:
					manual_reload()
			"boss_result":
				if code in [KEY_ENTER, KEY_SPACE]:
					continue_after_boss()
			"map":
				if code >= KEY_1 and code <= KEY_4:
					map_select(code - KEY_1)
				elif code == KEY_ENTER:
					map_go()
				elif code == KEY_TAB:
					do_action("open_arsenal")
			"shop":
				if code >= KEY_1 and code <= KEY_6:
					buy_shop(code - KEY_1)
				elif code == KEY_R:
					reroll_shop()
				elif code in [KEY_ENTER, KEY_ESCAPE]:
					open_map()
			"event":
				if code >= KEY_1 and code <= KEY_3 and event_stage == "choose":
					event_choose(code - KEY_1)
				elif code == KEY_ENTER and event_stage == "result":
					open_map()
			"rest":
				if code == KEY_H:
					rest_heal()
				elif code >= KEY_1 and code <= KEY_3:
					rest_train(code - KEY_1)
			"paused":
				if code in [KEY_ESCAPE, KEY_P, KEY_ENTER]:
					state = "playing"
			"arsenal":
				if code in [KEY_ESCAPE, KEY_TAB]:
					do_action("arsenal_close")
			"levelup":
				if code >= KEY_1 and code <= KEY_4:
					choose_offer(code - KEY_1)
				elif code in [KEY_LEFT, KEY_A]:
					offer_sel = posmod(offer_sel - 1, maxi(1, offers.size()))
				elif code in [KEY_RIGHT, KEY_D]:
					offer_sel = posmod(offer_sel + 1, maxi(1, offers.size()))
				elif code in [KEY_ENTER]:
					choose_offer(offer_sel)
				elif code == KEY_R:
					reroll_offers()
				elif code == KEY_X:
					skip_offer()
				elif code == KEY_TAB:
					hud.peek = not hud.peek
			"replace":
				if code >= KEY_1 and code <= KEY_3:
					replace_slot(code - KEY_1)
				elif code == KEY_ESCAPE:
					after_offer()
			"lost":
				if lost_t < LOST_LOCK:
					return
				if code == KEY_ENTER:
					start_run()
				elif code == KEY_ESCAPE:
					state = "menu"
			"victory":
				if code == KEY_ENTER:
					open_map()
				elif code == KEY_ESCAPE:
					state = "menu"
			"upgrades":
				if code == KEY_ESCAPE:
					state = "menu"
			"settings", "collection", "bestiary":
				if code == KEY_ESCAPE:
					state = settings_back
				elif state == "collection":
					hud.collection_key(code)
				elif state == "bestiary":
					if code == KEY_LEFT:
						hud.bestiary_page = maxi(0, hud.bestiary_page - 1)
					elif code == KEY_RIGHT:
						hud.bestiary_page += 1
	if event is InputEventScreenTouch:
		var p = hud.to_local(event.position)
		if is_touch_active():
			if event.pressed:
				_touch_down(event.index, p)
			else:
				_touch_up(event.index, p)
		elif event.pressed:
			hud.click(p)
	elif event is InputEventScreenDrag:
		if is_touch_active():
			var p = hud.to_local(event.position)
			_touch_drag(event.index, p)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if state == "playing" and is_touch_active() and mouse_screen.distance_to(bash_btn_pos) <= bash_btn_r * 1.2:
				try_bash()
			elif state == "playing" and is_touch_active() and mouse_screen.distance_to(dash_btn_pos) <= dash_btn_r * 1.35:
				try_dash()
			else:
				hud.click(mouse_screen)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and state == "playing":
			try_bash()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and state in ["collection", "bestiary"]:
			if state == "bestiary":
				hud.bestiary_page = maxi(0, hud.bestiary_page + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			else:
				hud.scroll(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)

## Floating joystick: the first finger down anywhere (not on a button) becomes the stick.
## With manual aim, the right half of the screen aims instead.
func _touch_down(id: int, p: Vector2) -> void:
	if state == "playing":
		for b in hud.buttons:
			if b["rect"].has_point(p):
				hud.click(p)
				return
		if p.distance_to(bash_btn_pos) <= bash_btn_r * 1.25:
			try_bash()
			return
		if p.distance_to(dash_btn_pos) <= dash_btn_r * 1.3:
			dash_touch_id = id
			dash_pressed = true
			try_dash()
			return
		var screen_w = 720.0 if portrait else 1280.0
		var manual_aim = str(settings["aim"]) != "auto"
		var aim_side = manual_aim and p.x > screen_w * 0.5
		if stick_touch_id == -1 and not aim_side:
			stick_touch_id = id
			stick_center = p
			stick_knob = p
			touch_move_dir = Vector2.ZERO
			return
		if manual_aim:
			if aim_touch_id == -1:
				aim_touch_id = id
			_set_touch_aim(p)
	else:
		hud.click(p)

func _touch_drag(id: int, p: Vector2) -> void:
	if state == "playing":
		if id == stick_touch_id:
			var diff = p - stick_center
			var max_r = 78.0 if portrait else 70.0
			var dist = diff.length()
			if dist > max_r * 1.35:
				stick_center = p - diff.normalized() * (max_r * 1.35)
				diff = p - stick_center
				dist = diff.length()
			if dist > max_r:
				stick_knob = stick_center + diff.normalized() * max_r
			else:
				stick_knob = p
			if dist > 8.0:
				touch_move_dir = diff.normalized() * minf(1.0, dist / max_r)
			else:
				touch_move_dir = Vector2.ZERO
		elif id == aim_touch_id:
			_set_touch_aim(p)

func _set_touch_aim(p: Vector2) -> void:
	mouse_screen = p
	aim_screen = p
	mouse_world = screen_to_world(p)
	if not hero.is_empty():
		var off: Vector2 = mouse_world - hero["pos"]
		if off.length_squared() > 64.0:
			touch_aim_dir = off.normalized()

func _touch_up(id: int, _p: Vector2) -> void:
	if id == stick_touch_id:
		stick_touch_id = -1
		touch_move_dir = Vector2.ZERO
		stick_center = default_stick()
		stick_knob = stick_center
	if id == aim_touch_id:
		aim_touch_id = -1
	if id == dash_touch_id:
		dash_touch_id = -1
		dash_pressed = false

func do_action(action: String) -> void:
	match action:
		"play":
			hard_mode = false
			start_run()
		"play_hard":
			hard_mode = true
			start_run()
		"settings":
			settings_back = state
			state = "settings"
		"upgrades":
			state = "upgrades"
		"collection":
			settings_back = state
			state = "collection"
			hud.collection_page = 0
			hud.selected_collection_item = null
		"bestiary":
			settings_back = state
			state = "bestiary"
			hud.bestiary_page = 0
			hud.bestiary_filter = "ALL"
			hud.bestiary_selected = ""
		"bestiary_close":
			hud.bestiary_selected = ""
		"bestiary_prev":
			hud.bestiary_page = maxi(0, hud.bestiary_page - 1)
		"bestiary_next":
			hud.bestiary_page += 1
		"quit":
			get_tree().quit()
		"update":
			install_update()
		"resume":
			state = "playing"
		"menu":
			state = "menu"
		"continue_run":
			open_map()
		"boss_continue":
			continue_after_boss()
		"back":
			state = settings_back
		"reroll":
			reroll_offers()
		"skip":
			skip_offer()
		"arsenal_close":
			state = arsenal_back
			hud.inspected_card_id = ""
		"close_inspect":
			hud.inspected_card_id = ""
		"open_arsenal":
			if state in ["playing", "map", "shop", "rest", "event"]:
				arsenal_back = state
				state = "arsenal"
		"pause":
			if state == "playing":
				state = "paused"
		"toggle_peek":
			hud.peek = not hud.peek
			hud.inspected_card_id = ""
		"mobile_cat_prev":
			hud.portrait_collection_cat(-1)
		"mobile_cat_next":
			hud.portrait_collection_cat(1)
		"mobile_close_detail":
			hud.selected_collection_item = null
		"map_go":
			map_go()
		"event_continue":
			if state == "event" and event_stage == "result":
				open_map()
		"shop_reroll":
			reroll_shop()
		"map_continue":
			open_map()
		"rest_heal":
			rest_heal()
		"dash":
			if state == "playing":
				try_dash()
		"keep":
			after_offer()
		_:
			if action.begins_with("offer"):
				choose_offer(int(action.trim_prefix("offer")))
			elif action.begins_with("event_opt_"):
				event_choose(int(action.trim_prefix("event_opt_")))
			elif action.begins_with("map_node_"):
				map_select(int(action.trim_prefix("map_node_")))
			elif action.begins_with("shop_buy_"):
				buy_shop(int(action.trim_prefix("shop_buy_")))
			elif action.begins_with("rest_train_"):
				rest_train(int(action.trim_prefix("rest_train_")))
			elif action.begins_with("slot"):
				replace_slot(int(action.trim_prefix("slot")))
			elif action.begins_with("meta_"):
				buy_meta(int(action.trim_prefix("meta_")))
			elif action.begins_with("set_"):
				toggle_setting(action.trim_prefix("set_"))
			elif action.begins_with("cat_"):
				hud.collection_cat = action.trim_prefix("cat_")
				hud.collection_page = 0
				hud.selected_collection_item = null
			elif action.begins_with("page"):
				hud.scroll(int(action.trim_prefix("page")))
				hud.selected_collection_item = null
			elif action.begins_with("select_card_"):
				hud.select_collection_index(int(action.trim_prefix("select_card_")))
			elif action.begins_with("bestiary_filter_"):
				hud.bestiary_filter = action.trim_prefix("bestiary_filter_")
				hud.bestiary_page = 0
				hud.bestiary_selected = ""
			elif action.begins_with("bestiary_select_"):
				hud.bestiary_select(int(action.trim_prefix("bestiary_select_")), 9 if portrait else 12)
			elif action.begins_with("inspect_card_"):
				hud.inspected_card_id = action.trim_prefix("inspect_card_")

func toggle_setting(key: String) -> void:
	match key:
		"sfx_up":
			settings["sfx"] = minf(1.0, float(settings["sfx"]) + 0.1)
		"sfx_down":
			settings["sfx"] = maxf(0.0, float(settings["sfx"]) - 0.1)
		"music_up":
			settings["music"] = minf(1.0, float(settings["music"]) + 0.1)
		"music_down":
			settings["music"] = maxf(0.0, float(settings["music"]) - 0.1)
		"sensitivity_up":
			settings["sensitivity"] = minf(3.0, snappedf(float(settings["sensitivity"]) + 0.1, 0.1))
		"sensitivity_down":
			settings["sensitivity"] = maxf(0.2, snappedf(float(settings["sensitivity"]) - 0.1, 0.1))
		"cursor":
			var sizes = [0.7, 1.0, 1.4, 1.9]
			var at = sizes.find(snappedf(float(settings["cursor"]), 0.1))
			settings["cursor"] = sizes[(at + 1) % sizes.size()]
		"shake":
			settings["shake"] = 0.0 if float(settings["shake"]) > 0.6 else (0.5 if float(settings["shake"]) == 0.0 else 1.0)
		"aim":
			settings["aim"] = "auto" if settings["aim"] == "mouse" else "mouse"
		"touch":
			if OS.has_feature("mobile"):
				var cur = str(settings.get("touch", "auto"))
				settings["touch"] = "on" if cur == "auto" else ("off" if cur == "on" else "auto")
			else:
				settings["touch"] = "off"
			if not is_touch_active():
				stick_touch_id = -1
				aim_touch_id = -1
				dash_touch_id = -1
				touch_move_dir = Vector2.ZERO
				dash_pressed = false
				stick_center = default_stick()
				stick_knob = stick_center
		"fullscreen":
			var win = get_window()
			win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			if settings.has(key):
				settings[key] = not bool(settings[key])
	sfx.set_volumes(float(settings["sfx"]), float(settings["music"]))
	sfx.play("pick")
	save_options()

func save_options() -> void:
	if autotest != "" or no_save:
		return
	var f = FileAccess.open("user://slime_hour_options.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"settings": settings, "best": best, "profile": profile}))

func load_options() -> void:
	if not FileAccess.file_exists("user://slime_hour_options.json"):
		var old = ProjectSettings.globalize_path("user://crowd_rush_options.json")
		if not FileAccess.file_exists(old):
			old = OS.get_user_data_dir().get_base_dir().path_join("CROWD RUSH -- NEON FRONT/crowd_rush_options.json")
		if FileAccess.file_exists(old):
			DirAccess.copy_absolute(old, ProjectSettings.globalize_path("user://slime_hour_options.json"))
	if not FileAccess.file_exists("user://slime_hour_options.json"):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://slime_hour_options.json"))
	if parsed is Dictionary:
		var s = parsed.get("settings", {})
		if s is Dictionary:
			if not s.has("controls_v2"):
				s["autofire"] = OS.has_feature("mobile")
			for k in settings.keys():
				if s.has(k) and typeof(s[k]) == typeof(settings[k]):
					settings[k] = s[k]
		var pf = parsed.get("profile", {})
		if pf is Dictionary:
			profile["xp"] = int(pf.get("xp", 0))
			profile["level"] = int(pf.get("level", 0))
			profile["kills"] = int(pf.get("kills", -1))
			profile["goo"] = int(pf.get("goo", -1))
			var ups = pf.get("ups", {})
			profile["ups"] = ups if ups is Dictionary else {}
			var mobs = pf.get("mobs", null)
			profile["mobs"] = mobs if mobs is Dictionary else {}
			var announced = pf.get("announced_mobs", {})
			profile["announced_mobs"] = announced if announced is Dictionary else {}
			if mobs == null and int(profile["level"]) >= 20:
				# Veterans from before the bestiary have met everything already.
				for k in enemy_db:
					profile["mobs"][k] = 0
		var b = parsed.get("best", {})
		if b is Dictionary:
			for k in best.keys():
				if b.has(k):
					best[k] = int(b[k])
	if int(profile.get("kills", -1)) < 0:
		# Saves from before lifetime kills existed start from the best run.
		profile["kills"] = int(best["kills"])
	if int(profile.get("goo", -1)) < 0:
		# Back pay for saves from before GOO existed.
		profile["goo"] = int(best["sector"]) * 4
