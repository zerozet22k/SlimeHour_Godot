extends Node
## Automated play-testing.   Godot --path . -- --autotest=soak | cards | shots
##   soak  : a bot plays for several sectors with god mode, piling on random cards and every gun.
##   cards : every one of the 300 cards is applied (at max stacks) and simulated for a few seconds.
##   shots : renders each screen to user://shots/*.png (needs a real window, not --headless).
##   pace  : a bot plays honestly (god mode only, no free cards) and logs level-ups and offer rarities per sector.

const Effects = preload("res://scripts/Effects.gd")
const Weapons = preload("res://scripts/Weapons.gd")

var g
var mode = "soak"
var t = 0.0
var step_t = 0.0
var card_index = 0
var gun_index = 0
var max_shots = 0
var max_enemies = 0
var max_fx = 0
var slow_frames = 0
var frames = 0
var shot_step = 0
var report: Array = []
var prev_state = ""
var pace_sector = 1
var pace_levels = 0
var rar_level = [0, 0, 0, 0, 0, 0]
var rar_chest = [0, 0, 0, 0, 0, 0]

func _ready() -> void:
	g = get_tree().root.get_node("SlimeHour")
	mode = g.autotest
	Engine.max_fps = 0
	if mode != "shots":
		# Run the simulation 4x faster than real time.
		Engine.physics_ticks_per_second = 60
		Engine.max_physics_steps_per_frame = 16
		Engine.time_scale = 4.0
	g.settings["sfx"] = 0.0
	g.settings["music"] = 0.0
	g.sfx.set_volumes(0.0, 0.0)
	print("AUTOTEST mode=", mode)
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	else:
		g.start_run()

static func move_dir(g) -> Vector2:
	var hp: Vector2 = g.hero["pos"]
	var dir = Vector2(sin(g.run_time * 0.7) * 0.6, -0.8)
	for e in g.enemies_near(hp, 140.0):
		var off: Vector2 = hp - e["pos"]
		if off.length() < 140.0:
			dir += off.normalized() * (1.2 - off.length() / 140.0) * 2.0
	if g.run_time > 1.0 and fmod(g.run_time, 2.3) < 0.02:
		g.try_dash()
	return dir.normalized()

func _process(delta: float) -> void:
	frames += 1
	t += delta
	if delta > 1.0 / 30.0:
		slow_frames += 1
	match mode:
		"soak":
			soak(delta)
		"cards":
			cards(delta)
		"shots":
			shots(delta)
		"pace":
			pace(delta)
		"curve":
			curve(delta)

func auto_ui() -> void:
	match g.state:
		"map":
			var nxt: Array = g.map_cols[g.sector - 1][g.map_at]["next"]
			g.map_select(int(nxt[randi() % nxt.size()]))
			g.map_go()
			return
		"shop":
			for i in range(g.shop_items.size()):
				if not bool(g.shop_items[i]["sold"]) and g.gold >= int(g.shop_items[i]["price"]):
					g.buy_shop(i)
			if g.state == "shop":
				g.open_map()
			return
		"rest":
			if float(g.hero["hp"]) < float(g.hero["maxhp"]) * 0.7:
				g.rest_heal()
			else:
				g.rest_train(randi() % g.guns.size())
				if g.state == "rest":
					g.rest_heal()
			return
		"event":
			if g.event_stage == "choose":
				g.event_choose(0 if int(g.event["opts"][0].get("cost", 0)) <= g.gold else 1)
			elif g.event_stage == "result":
				g.do_action("event_continue")
			return
	if g.state == "levelup" and g.offer_t > 0.4:
		g.choose_offer(randi() % g.offers.size())
	elif g.state == "replace":
		g.replace_slot(randi() % g.guns.size())
	elif g.state == "lost":
		g.start_run()

func track() -> void:
	max_shots = maxi(max_shots, g.shots.size())
	max_enemies = maxi(max_enemies, g.enemies.size())
	max_fx = maxi(max_fx, g.fx.size())

func soak(delta: float) -> void:
	auto_ui()
	if g.state != "playing":
		return
	g.hero["hp"] = g.hero["maxhp"]
	track()
	step_t += delta
	if step_t >= 0.6:
		step_t = 0.0
		var pool = []
		for c in g.db_cards:
			if Effects.eligible(g, c):
				pool.append(c)
		if not pool.is_empty():
			Effects.add_card(g, str(pool[randi() % pool.size()]["id"]))
		gun_index += 1
		if gun_index % 4 == 0:
			var id = g.weapon_ids[(gun_index / 4) % g.weapon_ids.size()]
			var slot = (gun_index / 4) % 2
			var w = Weapons.new_gun(g, id)
			w["lvl"] = 1 + randi() % 5
			w["evolved"] = randf() < 0.3
			if g.guns.size() < 2:
				g.guns.append(w)
			else:
				g.guns[slot] = w
			g.stats_dirty = true
	# Push the bot forward through sectors quickly.
	g.hero["pos"].y -= 140.0 * delta
	if int(t) % 10 == 0 and fmod(t, 10.0) < delta:
		var parts = []
		for k in g.prof:
			parts.append("%s=%dms" % [k, int(float(g.prof[k]) / 1000.0)])
		print("   prof(10s): ", " ".join(parts), "  delayed=%d pets=%d zones=%d" % [g.delayed.size(), g.pets.size(), g.zones.size()])
		g.prof.clear()
		print("t=%d sector=%d phase=%s cards=%d guns=%s enemies=%d shots=%d fx=%d fps=%d" % [t, g.sector, g.phase, g.owned_order.size(), str(g.guns.map(func(w): return w["id"])), g.enemies.size(), g.shots.size(), g.fx.size(), Engine.get_frames_per_second()])
	if t > float(OS.get_environment("SOAK_SECONDS") if OS.get_environment("SOAK_SECONDS") != "" else "240"):
		finish()

func pace(_delta: float) -> void:
	if g.state == "levelup" and prev_state != "levelup":
		var tally = rar_chest if g.offer_mode == "chest" else rar_level
		for o in g.offers:
			tally[clampi(Effects.offer_rarity(g, o), 0, 5)] += 1
	prev_state = g.state
	auto_ui()
	if g.state == "playing":
		g.hero["hp"] = g.hero["maxhp"]
	if g.sector != pace_sector:
		print("PACE sector=%d time=%ds level=%d (+%d) kills=%d  level offers C/R/E/L/M/A=%s  chest offers C/R/E/L/M/A=%s" % [pace_sector, int(g.run_time), g.level, g.level - pace_levels, g.kills, str(rar_level), str(rar_chest)])
		pace_sector = g.sector
		pace_levels = g.level
	var last = int(OS.get_environment("PACE_SECTORS") if OS.get_environment("PACE_SECTORS") != "" else "10")
	if g.sector > last:
		finish()

# curve: honest bot (random picks, buys what it can), logs difficulty and economy per sector.
var cv = {}
var last_gold = 0
func curve(_delta: float) -> void:
	if cv.is_empty():
		cv = {"taken": 0.0, "kills": g.kills, "serial": g.serial, "earn": 0, "spent": 0, "t": g.run_time, "dealt": 0.0, "hpspawn": 0.0}
		last_gold = g.gold
	if g.state == "levelup" and prev_state != "levelup":
		var tally = rar_chest if g.offer_mode == "chest" else rar_level
		for o in g.offers:
			tally[clampi(Effects.offer_rarity(g, o), 0, 5)] += 1
	prev_state = g.state
	auto_ui()
	if g.state == "victory":
		g.state = "playing"
	if g.gold > last_gold:
		cv["earn"] = int(cv["earn"]) + g.gold - last_gold
	elif g.gold < last_gold:
		cv["spent"] = int(cv["spent"]) + last_gold - g.gold
	last_gold = g.gold
	if g.state == "playing":
		if float(g.hero["hp"]) < float(g.hero["maxhp"]):
			cv["taken"] = float(cv["taken"]) + float(g.hero["maxhp"]) - float(g.hero["hp"])
		g.hero["hp"] = g.hero["maxhp"]
	if g.sector != pace_sector:
		var owned_r = [0, 0, 0, 0, 0, 0]
		for id in g.owned:
			if g.card_by_id.has(id):
				owned_r[int(g.card_by_id[id]["rarity"])] += int(g.owned[id])
		var secs = maxf(1.0, g.run_time - float(cv["t"]))
		var tiers = g.guns.map(func(w): return "%s:t%d:l%d" % [w["id"], int(w.get("tier", 0)), int(w["lvl"])])
		print("CURVE s=%d secs=%d lvl=%d taken=%d (%.2f maxhp) kills=%d spawned=%d killrate=%.2f gold+%d -%d bank=%d dmgmult=%.2f owned C/R/E/L/M/A=%s offersL=%s offersC=%s guns=%s" % [pace_sector, int(secs), g.level, int(cv["taken"]), float(cv["taken"]) / float(g.hero["maxhp"]), g.kills - int(cv["kills"]), g.serial - int(cv["serial"]), float(g.kills - int(cv["kills"])) / maxf(1.0, float(g.serial - int(cv["serial"]))), int(cv["earn"]), int(cv["spent"]), g.gold, g.dmg_mult(), str(owned_r), str(rar_level), str(rar_chest), str(tiers)])
		rar_level = [0, 0, 0, 0, 0, 0]
		rar_chest = [0, 0, 0, 0, 0, 0]
		cv = {"taken": 0.0, "kills": g.kills, "serial": g.serial, "earn": 0, "spent": 0, "t": g.run_time}
		pace_sector = g.sector
	var last = int(OS.get_environment("PACE_SECTORS") if OS.get_environment("PACE_SECTORS") != "" else "20")
	if g.sector > last:
		finish()

func cards(delta: float) -> void:
	auto_ui()
	if g.state != "playing":
		return
	g.hero["hp"] = g.hero["maxhp"]
	track()
	step_t += delta
	if step_t < 2.5 and card_index > 0:
		return
	step_t = 0.0
	if card_index >= g.db_cards.size():
		finish()
		return
	var c = g.db_cards[card_index]
	g.start_run()
	# Satisfy requirements so weapon-specific cards are actually exercised.
	var req: Dictionary = c.get("req", {})
	if req.has("weapon"):
		g.guns = [Weapons.new_gun(g, str(req["weapon"][0]))]
	else:
		g.guns = [Weapons.new_gun(g, g.weapon_ids[card_index % g.weapon_ids.size()])]
		g.guns.append(Weapons.new_gun(g, g.weapon_ids[(card_index * 7 + 3) % g.weapon_ids.size()]))
	if req.has("stat"):
		Effects.add_card(g, {"drone": "gun_drone", "orbit": "spinny_blade"}.get(req["stat"], "gun_drone"))
	for k in range(int(c["max"])):
		Effects.add_card(g, str(c["id"]))
	g.stats_dirty = true
	for i in range(14):
		g.spawn_enemy(["blob", "chonk", "riot", "spitter", "kaboomba", "mitosis", "bull"][i % 7], g.hero["pos"] + Vector2(randf_range(-300, 300), randf_range(-320, -120)))
	g.spawn_barrel(g.hero["pos"] + Vector2(60, -150))
	# Exercise every trigger type at least once.
	g.try_dash()
	g.hero["iframe"] = 0.0
	g.hurt(5.0, g.hero["pos"], "autotest")
	for w in g.guns:
		Weapons.start_reload(g, w)
	g.gain_xp(float(g.xp_need))
	report.append(str(c["id"]))
	if card_index % 25 == 0:
		print("cards tested: %d / %d" % [card_index, g.db_cards.size()])
	card_index += 1

func shots(delta: float) -> void:
	step_t += delta
	if step_t < 1.2:
		return
	step_t = 0.0
	var names = ["menu", "play1", "play2", "levelup", "arsenal", "map", "collection", "lost", "boss"]
	g.pending_levels = 0
	g.pending_chests = 0
	g.levelup_delay = 0.0
	if shot_step > 0:
		var img = get_viewport().get_texture().get_image()
		img.save_png("user://shots/%02d_%s.png" % [shot_step - 1, names[shot_step - 1]])
	if shot_step >= names.size():
		print("SHOTS DIR ", ProjectSettings.globalize_path("user://shots"))
		finish()
		return
	match names[shot_step]:
		"menu":
			g.state = "menu"
		"play1":
			g.start_run()
			for id in ["double_tap", "spinny_blade", "incendiary", "splinter", "gun_drone"]:
				Effects.add_card(g, id)
			g.guns.append(Weapons.new_gun(g, "shotgun"))
			for i in range(30):
				g.spawn_enemy(["blob", "zoomer", "chonk", "spitter", "riot", "kaboomba", "tick", "mitosis"][i % 8], g.hero["pos"] + Vector2(randf_range(-420, 420), randf_range(-360, -60)))
		"play2":
			for id in ["ricochet", "rubber_chicken", "pet_chicken", "good_boy", "cryo_rounds", "bowling_pins", "acme_anvils", "halo"]:
				Effects.add_card(g, id)
			g.guns[1] = Weapons.new_gun(g, "bowling")
			g.hero["pos"].y -= 700.0
			for i in range(40):
				g.spawn_enemy(["blob", "zoomer", "bull", "lancer", "mama", "goblin"][i % 6], g.hero["pos"] + Vector2(randf_range(-420, 420), randf_range(-360, -60)))
			g.spawn_gate_pair(g.hero["pos"].y - 220.0)
		"levelup":
			g.open_offers("level")
			g.offer_t = 2.0
		"arsenal":
			g.state = "arsenal"
		"map":
			g.state = "playing"
			g.open_map()
		"collection":
			g.state = "collection"
			g.hud.collection_cat = "chaos"
		"lost":
			g.state = "lost"
		"boss":
			g.start_run()
			g.sector = 5
			g.begin_sector()
			g.spawn_enemy("chonkzilla", g.hero["pos"] + Vector2(0, -260), true)
			for id in ["blade_storm", "meteor_buddy", "tesla_coil"]:
				Effects.add_card(g, id)
	shot_step += 1

func finish() -> void:
	print("AUTOTEST DONE mode=%s frames=%d time=%.1f max_shots=%d max_enemies=%d max_fx=%d slow_frames=%d sector=%d kills=%d cards_tested=%d" % [mode, frames, t, max_shots, max_enemies, max_fx, slow_frames, g.sector, g.kills, report.size()])
	get_tree().quit()
