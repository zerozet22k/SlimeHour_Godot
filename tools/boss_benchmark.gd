extends SceneTree
## BOSS BENCHMARK: bots fight each boss with a typical build for its sector.
## Each trial rolls a fresh random build (cards for the levels you would have
## by then, two random guns levelled and tiered like a real run). The bot
## dodges (AutoTest.dodge_dir); no god mode. Reports time to kill, whether it
## died, and how much HP it lost.
##
##   run_boss_benchmark.bat                 all bosses, Normal and Hard, in parallel
##   Godot --headless --path . --script tools/boss_benchmark.gd
##     BENCH_BOSSES=heli,necro   which bosses (default: all)
##     BENCH_TRIALS=4            bots per boss (default 4)
##     BENCH_HARD=1              Hard mode
##     BENCH_OUT=path.csv        where rows are written (default tools/benchmarks/boss_ttk.csv)
const Effects = preload("res://scripts/Effects.gd")
const Weapons = preload("res://scripts/Weapons.gd")

const BOSSES = ["heli", "chonkzilla", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine", "stormtitan", "hiveempress"]
## Player level a normal run reaches by each boss (one card per level).
const LEVELS = {5: 6, 10: 9, 15: 12, 20: 14, 25: 16, 30: 18, 35: 20, 40: 21, 45: 22, 50: 23}
const TIME_LIMIT := 240.0

func _initialize() -> void:
	call_deferred("go")

func env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback

func build(g, sector: int, level: int) -> String:
	g.owned.clear()
	g.owned_order.clear()
	g.level = level
	for k in range(level - 1):
		var pool: Array = []
		for c in g.db_cards:
			if Effects.eligible(g, c):
				pool.append(c)
		if not pool.is_empty():
			Effects.add_card(g, str(pool[randi() % pool.size()]["id"]))
	g.guns.clear()
	var ids: Array = g.weapon_ids.duplicate()
	ids.shuffle()
	for i in range(2):
		var w = Weapons.new_gun(g, str(ids[i]), mini(3, sector / 12))
		w["lvl"] = clampi(1 + sector / 6, 1, 5)
		g.guns.append(w)
	g.stats_dirty = true
	Effects.recalc(g)
	return "%s+%s" % [ids[0], ids[1]]

## WATCH MODE (BENCH_WATCH=1): a real window at watchable speed with a live
## scoreboard over the fight.
var board: RichTextLabel = null
var history: Array = []

func make_board() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(430, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.07, 0.86)
	style.border_color = Color("4fe0ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	board = RichTextLabel.new()
	board.bbcode_enabled = true
	board.position = Vector2(14, 10)
	board.size = Vector2(404, 310)
	board.add_theme_font_size_override("normal_font_size", 15)
	board.add_theme_font_size_override("bold_font_size", 17)
	board.scroll_active = false
	panel.add_child(board)

func bar(frac: float, width: int, col: String) -> String:
	var n := clampi(roundi(frac * float(width)), 0, width)
	return "[color=%s]%s[/color][color=#33405a]%s[/color]" % [col, "█".repeat(n), "█".repeat(width - n)]

func update_board(g, e, boss: String, s: int, trial: int, trials: int, hard: bool, guns: String, t: float, lost: float, max_hp: float, bullets: int) -> void:
	if board == null:
		return
	var hero_frac: float = float(g.hero["hp"]) / maxf(1.0, float(g.hero["maxhp"]))
	var boss_frac: float = float(e["hp"]) / maxf(1.0, float(e["max_hp"]))
	var txt := "[b][color=#4fe0ff]BOSS BENCHMARK[/color]  ·  [color=%s]%s[/color][/b]\n" % ["#ff6b7a" if hard else "#7dff9a", "HARD" if hard else "NORMAL"]
	txt += "[b]%s[/b]  ·  sector %d  ·  bot %d/%d\n" % [str(g.enemy_db[boss]["name"]), s, trial + 1, trials]
	txt += "[color=#9fb8d0]%s  ·  %d cards  ·  %d bullets[/color]\n\n" % [guns.to_upper().replace("+", " + "), g.owned_order.size(), bullets]
	txt += "BOSS %s %d%%\n" % [bar(boss_frac, 22, "#ffb84d"), roundi(boss_frac * 100.0)]
	txt += "BOT  %s %d%%\n" % [bar(hero_frac, 22, "#7dff9a" if hero_frac > 0.35 else "#ff6b7a"), roundi(hero_frac * 100.0)]
	txt += "[color=#9fb8d0]%.1fs  ·  HP lost so far %d%%[/color]\n\n" % [t, roundi(lost / max_hp * 100.0)]
	for h in history.slice(maxi(0, history.size() - 6)):
		txt += str(h) + "\n"
	board.text = txt

func go() -> void:
	# Same screen shape as a 16:9 monitor, so the road is the real width.
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var g = load("res://scenes/Main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.sfx.set_volumes(0.0, 0.0)
	g.autotest = "bench"
	g.settings["autofire"] = true
	var watch := env("BENCH_WATCH", "0") == "1"
	Engine.time_scale = float(env("BENCH_SPEED", "1.5")) if watch else 4.0
	if watch:
		make_board()
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 0
	var hard := env("BENCH_HARD", "0") == "1"
	var trials := int(env("BENCH_TRIALS", "4"))
	var list: Array = Array(env("BENCH_BOSSES", ",".join(BOSSES)).split(",", false))
	var out_path := env("BENCH_OUT", ProjectSettings.globalize_path("res://tools/benchmarks/boss_ttk.csv"))
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var new_file := not FileAccess.file_exists(out_path)
	var f := FileAccess.open(out_path, FileAccess.READ_WRITE if not new_file else FileAccess.WRITE)
	f.seek_end()
	if new_file:
		f.store_line("boss,sector,mode,trial,guns,cards,seconds,killed,died,hp_lost_pct,peak_bullets")
	for boss in list:
		var s := 5 * (BOSSES.find(boss) + 1)
		for trial in range(trials):
			seed(hash(boss) + trial * 7919 + (1 if hard else 0))
			g.hard_mode = hard
			g.start_run()
			g.hard_mode = hard
			g.sector = s
			g.enemies.clear()
			g.shots.clear()
			g.delayed.clear()
			var guns := build(g, s, int(LEVELS[s]))
			if OS.get_environment("BENCH_DEBUG") != "":
				print("  viewport=", g.get_viewport_rect().size, " road_half=", g.road_half)
			g.hero["hp"] = g.hero["maxhp"]
			var max_hp: float = float(g.hero["maxhp"])
			var e = g.spawn_enemy(boss, g.hero["pos"] + Vector2(0, -320), true, false)
			g.boss_spawned = true
			g.state = "playing"
			var t := 0.0
			var lost := 0.0
			var last_hp: float = float(g.hero["hp"])
			var died := false
			var peak := 0
			var peak_by := {}
			while not bool(e["dead"]) and t < TIME_LIMIT:
				await physics_frame
				t += Engine.time_scale / 60.0
				var hp: float = float(g.hero["hp"])
				if hp < last_hp:
					lost += last_hp - hp
				last_hp = hp
				var n := 0
				var by := {}
				for sh in g.shots:
					if not bool(sh["friendly"]):
						n += 1
						by[str(sh.get("src", "?"))] = int(by.get(str(sh.get("src", "?")), 0)) + 1
				if n > peak:
					peak = n
					peak_by = by
				if hp <= 0.0 or float(g.dying_t) > 0.0 or g.state == "lost":
					died = true
					break
				if g.state != "playing":
					g.state = "playing"
				update_board(g, e, boss, s, trial, trials, hard, guns, t, lost, max_hp, n)
				if OS.get_environment("BENCH_DEBUG") != "" and fmod(t, 10.0) < Engine.time_scale / 60.0:
					print("  t=%d boss=%s state=%s attack=%s hp=%d%% dist=%d boss_pos=%s hero_pos=%s bullets=%d" % [int(t), str(e["kind"]), str(e.get("bf_state", "")), str(e.get("bf_attack", "")), roundi(float(e["hp"]) / float(e["max_hp"]) * 100.0), roundi(Vector2(e["pos"]).distance_to(g.hero["pos"])), str(Vector2(e["pos"]).round()), str(Vector2(g.hero["pos"]).round()), n])
			var row := "%s,%d,%s,%d,%s,%d,%.1f,%d,%d,%d,%d" % [boss, s, "hard" if hard else "normal", trial, guns,
				g.owned_order.size(), t, 1 if bool(e["dead"]) else 0, 1 if died else 0, roundi(lost / max_hp * 100.0), peak]
			history.append(("[color=#7dff9a]WON[/color]  %s in %.0fs  (%s, lost %d%% HP)" if bool(e["dead"]) else ("[color=#ff6b7a]DIED[/color] to %s after %.0fs  (%s, lost %d%% HP)" if died else "[color=#ffd24d]TIMEOUT[/color] %s at %.0fs  (%s, lost %d%% HP)")) % [str(g.enemy_db[boss]["name"]), t, guns, roundi(lost / max_hp * 100.0)])
			f.store_line(row)
			f.flush()
			print("BENCH ", row)
			if OS.get_environment("BENCH_DEBUG") != "":
				print("  peak by source: ", peak_by, "  cards: ", g.owned_order)
	f.close()
	quit()
