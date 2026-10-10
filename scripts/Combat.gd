extends RefCounted
## Simulation: projectiles, enemies, statuses, explosions, zones and every autonomous ally.
## Entities are plain dictionaries drawn by Visuals.gd in one canvas pass.

const Effects = preload("res://scripts/Effects.gd")
const ProjectileVfx = preload("res://scripts/ProjectileVfx.gd")
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
const EnemyIdentity = preload("res://scripts/EnemyIdentity.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const WeaponSignatures = preload("res://scripts/WeaponSignatures.gd")
const Compatibility = preload("res://scripts/WeaponCompatibility.gd")
const CELL = 72.0
const TOTEM_R = 230.0
const STATUSES = ["burn", "freeze", "shock", "poison", "bleed", "slow", "charm", "wet", "mark"]

# ================================================================= grid
static func build_grid(g) -> void:
	var grid = {}
	for e in g.enemies:
		if bool(e["dead"]):
			continue
		var k = Vector2i(floori(e["pos"].x / CELL), floori(e["pos"].y / CELL))
		if grid.has(k):
			grid[k].append(e)
		else:
			grid[k] = [e]
	g.grid = grid

static func query(g, p: Vector2, r: float) -> Array:
	var out = []
	var m = r + 70.0
	var x0 = floori((p.x - m) / CELL)
	var x1 = floori((p.x + m) / CELL)
	var y0 = floori((p.y - m) / CELL)
	var y1 = floori((p.y + m) / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var arr = g.grid.get(Vector2i(cx, cy))
			if arr != null:
				out.append_array(arr)
	return out

static func seg_dist2(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab = b - a
	var t = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_squared_to(p)

static func seg_t(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab = b - a
	return clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)

static func random_enemy(g, p: Vector2, r: float) -> Variant:
	var pool = []
	for e in query(g, p, r):
		if not bool(e["dead"]) and float(e["charm"]) <= 0.0 and e["pos"].distance_to(p) < r:
			pool.append(e)
	return null if pool.is_empty() else pool[randi() % pool.size()]

static func crowd_center(g) -> Vector2:
	var sum = Vector2.ZERO
	var n = 0
	for e in g.enemies:
		if not bool(e["dead"]) and g.on_screen(e["pos"], 0.0):
			sum += e["pos"]
			n += 1
	return sum / n if n > 0 else g.hero["pos"] + Vector2(0, -260)

static func status_color(s: String) -> Color:
	return {"burn": Color("ff8a3d"), "freeze": Color("9fe8ff"), "ice": Color("9fe8ff"), "shock": Color("9fd0ff"),
		"poison": Color("8dff6b"), "bleed": Color("ff4d6a"), "slow": Color("b0a0ff"), "charm": Color("ff8ad8"),
		"wet": Color("6bb8ff"), "mark": Color("ff5a5a"), "stun": Color("fff27a")}.get(s, Color.WHITE)

# ================================================================= step
static func step(g, dt: float) -> void:
	var t0 = Time.get_ticks_usec()
	update_delayed(g, dt)
	EnemyIdentity.update_hazards(g, dt)
	var t1 = Time.get_ticks_usec()
	update_enemies(g, dt)
	var t2 = Time.get_ticks_usec()
	update_shots(g, dt)
	var t3 = Time.get_ticks_usec()
	update_zones(g, dt)
	update_allies(g, dt)
	update_barrels(g, dt)
	update_fx(g, dt)
	var t4 = Time.get_ticks_usec()
	g.prof["c.delayed"] = float(g.prof.get("c.delayed", 0.0)) + (t1 - t0)
	g.prof["c.enemies"] = float(g.prof.get("c.enemies", 0.0)) + (t2 - t1)
	g.prof["c.shots"] = float(g.prof.get("c.shots", 0.0)) + (t3 - t2)
	g.prof["c.rest"] = float(g.prof.get("c.rest", 0.0)) + (t4 - t3)
	g.enemies = g.enemies.filter(func(e): return not bool(e["dead"]))
	g.shots = g.shots.filter(func(s): return not bool(s.get("dead", false)))

# ================================================================= delayed actions
static func update_delayed(g, dt: float) -> void:
	var due = []
	for i in range(g.delayed.size() - 1, -1, -1):
		var item = g.delayed[i]
		# Coil walls actually advance: both warning and collision follow this
		# segment, so the visual never lies about the hitbox.
		if str(item.get("fn", "")) == "coil_wall":
			var remaining: float = absf(float(item["a"].x) - float(item["stop_x"]))
			var amount: float = minf(remaining, float(item["move"]) * dt)
			var shift: Vector2 = Vector2(-float(item["side"]) * amount, 0.0)
			item["pos"] += shift
			item["a"] += shift
			item["b"] += shift
		item["t"] = float(item["t"]) - dt
		if float(item["t"]) <= 0.0:
			due.append(item)
			g.delayed.remove_at(i)
	for item in due:
		match item["fn"]:
			"proc":
				Effects.act(g, item["p"], int(item["stacks"]), item["ctx"])
			"free_volley":
				Weapons.free_volley(g, item["dir"], int(item["gen"]))
			"burst":
				Weapons.burst(g, int(item["slot"]), float(item.get("mul", 1.0)))
			"echo":
				Weapons.echo(g, item)
			"meteor":
				explode(g, item["pos"], float(item["r"]), float(item["dmg"]), int(item["gen"]), Color("ff8a3d"))
				g.add_zone("fire", item["pos"], float(item["r"]) * 0.6, 2.0)
				g.add_shake(8.0)
			"anvil":
				var pos: Vector2 = item["pos"]
				var tgt = item.get("enemy")
				if tgt != null and not bool(tgt["dead"]):
					pos = tgt["pos"]
				for e in query(g, pos, float(item["r"])):
					if not bool(e["dead"]) and e["pos"].distance_to(pos) < float(item["r"]) + float(e["r"]):
						hit(g, e, float(item["dmg"]), {"pos": pos, "gen": int(item["gen"]), "dir": Vector2.ZERO, "knock": 0.0, "aoe": true})
						e["stun"] = maxf(float(e["stun"]), 1.0)
						e["squash"] = 0.6
				g.fx.append({"kind": "anvil_hit", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 0.6, "color": Color.WHITE, "size": float(item["r"]), "piano": item.get("piano", false)})
				g.spawn_burst(pos, Color("d0d8e8"), 14, 260.0)
				g.add_shake(10.0)
				g.sfx.play("bonk")
			"airbomb":
				explode(g, item["pos"], 75.0, float(item["dmg"]), int(item["gen"]), Color("ffb84d"))
			"potato":
				potato_hop(g, item)
			"mortar":
			# Artillery salvos anticipate the player's escape, rather than leaving mines.
			if float(e["cd"]) <= 0.0 and dist < 640.0:
				e["cd"] = maxf(2.4, 4.1 - 0.045 * float(maxi(0, g.sector - 5)))
				var lead: Vector2 = hero_pos + g.hero["vel"] * 0.48
				var side: Vector2 = g.hero["vel"].normalized().orthogonal() if g.hero["vel"].length() > 10.0 else Vector2.RIGHT
				for i in range(2 + int(g.hard_mode)):
					if g.delayed.size() >= 125:
						break
					var where: Vector2 = lead + side * (float(i) - 0.5) * 94.0
					var timer: float = 1.0 + float(i) * 0.32
					g.delayed.append({"t": timer, "life": timer, "fn": "mortar", "pos": where, "tele": 58.0, "dmg": float(e["dmg"]) * 0.72})
				g.sfx.play("thunk")
			return -dir * 0.8 if dist < 360.0 else (dir if dist > 470.0 else dir.orthogonal() * 0.4)
		"totem":
			return Vector2.ZERO
		"blinky":
			# Dimensional crossfire from two different positions. Blinky's
			# old location fires a warned echo-beam while the new position
			# sprays into the gap. No instantaneous or invisible hits.
			if float(e.get("blink_recover", 0.0)) > 0.0:
				e["blink_recover"] = maxf(0.0, float(e["blink_recover"]) - dt)
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					var origin: Vector2 = e.get("rift_origin", e["pos"])
					var echo_target: Vector2 = e.get("rift_target", hero_pos)
					g.spawn_ring_fx(origin, Color("c58cff"), 39.0)
					e["pos"] = e.get("lock", hero_pos)
					e["kb"] = Vector2.ZERO
					e["vel"] = Vector2.ZERO
					e["blink_recover"] = 0.28
					g.spawn_ring_fx(e["pos"], Color("c58cff"), 45.0)
					if g.delayed.size() < 140:
						schedule_boss_line(g, origin, echo_target, 14.0, float(e["dmg"]) * 0.78, 0.96, "b88bff")
					var shot_dir: Vector2 = (echo_target - e["pos"]).normalized()
					if shot_dir.length_squared() < 0.01:
						shot_dir = dir
					if g.sector >= 12:
						enemy_fire(g, e, shot_dir, 3 if g.hard_mode else 2, 0.38, 320.0, 4.5)
					else:
						enemy_fire(g, e, shot_dir, 1, 0.0, 290.0, 4.5)
					g.sfx.play("whoosh")
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 520.0 and dist > 135.0:
				e["cd"] = 4.2 if not g.hard_mode else 3.35
				e["wind"] = 0.78
				e["rift_origin"] = e["pos"]
				e["rift_target"] = hero_pos + g.hero["vel"] * 0.30
				var approach: Vector2 = (hero_pos - e["pos"]).normalized()
				var flank_sign = -1.0 if int(e.get("id", 0)) % 2 == 0 else 1.0
				var destination: Vector2 = hero_pos + approach * 105.0 + approach.orthogonal() * flank_sign * 45.0
				destination.x = clampf(destination.x, -g.road_half + float(e["r"]) + 10.0, g.road_half - float(e["r"]) - 10.0)
				e["lock"] = destination
				return Vector2.ZERO
			return (dir * 0.67 + dir.orthogonal() * sin(float(e["t"]) * 2.5) * 0.35).normalized()
		"tick":
			if bool(e.get("latched", false)):
				e["pos"] = hero_pos + e.get("latch_off", Vector2.ZERO)
				e["kb"] = Vector2.ZERO
				return Vector2.ZERO
			return dir
		"spitter":
			# Spitters launch curving acid hooks around the player's flank,
			# not Mirror's reflective frontal shotgun. Lock the aim on wind-up.
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					var lock: Vector2 = e.get("lock", hero_pos)
					var aim: Vector2 = (lock - e["pos"]).normalized()
					if aim.length_squared() < 0.01:
						aim = dir
					var stream = enemy_fire(g, e, aim, 1, 0.0, 245.0, 5.5)
					if stream != null:
						stream["color"] = Color("a2ff83")
					for step_i in range(3):
						var blot: Vector2 = e["pos"].lerp(lock, 0.42 + float(step_i) * 0.20)
						EnemyIdentity.place(g, "acid", blot, 22.0, float(e["dmg"]) * 0.23, 2.7, 0.10)
					if g.sector >= 6:
						for side in [-1.0, 1.0]:
							var hook = enemy_fire(g, e, aim.rotated(side * 0.31), 1, 0.0, 225.0, 5.5)
							if hook != null:
								hook["curve"] = -side * 0.60
								hook["color"] = Color("a2ff83")
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 420.0:
				e["cd"] = maxf(1.75, 3.1 - 0.04 * float(maxi(0, g.sector - 6)))
				e["wind"] = 0.58
				e["lock"] = hero_pos + g.hero["vel"] * 0.17
				return Vector2.ZERO
			if dist < 210.0:
				return -dir * 0.75
			return dir if dist > 340.0 else dir.orthogonal() * 0.65
		"larry":
			# Retain charged laser identity; upgrade to an uninterrupted sweeping beam.
			if float(e.get("overheat_t", 0.0)) > 0.0:
				e["overheat_t"] = maxf(0.0, float(e["overheat_t"]) - dt)
				return Vector2.ZERO
			if float(e.get("laser_t", 0.0)) > 0.0:
				e["laser_t"] = maxf(0.0, float(e["laser_t"]) - dt)
				var sweep: float = float(e.get("laser_side", 1.0))
				e["laser_dir"] = Vector2(e.get("laser_dir", dir)).rotated(sweep * dt * (0.52 if g.hard_mode else 0.37))
				if float(e.get("laser_tick", 0.0)) <= 0.0:
					larry_beam(g, e, Vector2(e["laser_dir"]))
					e["laser_tick"] = 0.13
				e["laser_tick"] = float(e["laser_tick"]) - dt
				if float(e["laser_t"]) <= 0.0:
					e["overheat_t"] = 2.0
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) > 0.40:
					e["lock"] = hero_pos
				if float(e["wind"]) <= 0.0:
					e["laser_dir"] = (Vector2(e.get("lock", hero_pos)) - e["pos"]).normalized()
					e["laser_side"] = 1.0 if int(e["id"]) % 2 == 0 else -1.0
					e["laser_t"] = 2.2 if not g.hard_mode else 2.8
					e["laser_tick"] = 0.0
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 870.0:
				e["cd"] = 4.4
				e["wind"] = 1.25
				e["lock"] = hero_pos
			if dist < 350.0:
				return -dir * 0.48
			return dir if dist > 580.0 else Vector2.ZERO
		"bull":
			if float(e["charge"]) > 0.0:
				e["charge"] = float(e["charge"]) - dt
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					e["charge"] = 0.98
					e["cdir"] = (hero_pos - e["pos"]).normalized()
					g.sfx.play("whoosh")
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 330.0:
				e["cd"] = 3.5
				e["wind"] = 0.6
			return dir
		"nurse":
			# Medic reaches a single critically damaged patient then finishes treatment.
			var patient = e.get("patient")
			if patient != null and (bool(patient.get("dead", false)) or float(patient.get("hp", 0.0)) >= float(patient.get("max_hp", 1.0)) * 0.95):
				patient = null
				e.erase("patient")
				e["treat_t"] = 0.0
			if patient == null and float(e["cd"]) <= 0.0:
				var lowest = 0.70
				for ally in query(g, e["pos"], 270.0):
					if ally == e or bool(ally["dead"]) or bool(ally["boss"]):
						continue
					var ratio = float(ally["hp"]) / maxf(1.0, float(ally["max_hp"]))
					if ratio < lowest:
						lowest = ratio
						patient = ally
				if patient != null:
					e["patient"] = patient
					e["treat_t"] = 0.0
					e["cd"] = 4.4
			if patient != null:
					var to_patient: Vector2 = Vector2(patient["pos"]) - Vector2(e["pos"])
					if to_patient.length() > 58.0:
						e["treat_t"] = 0.0
						return to_patient.normalized()
					e["treat_t"] = float(e.get("treat_t", 0.0)) + dt
					if float(e["treat_t"]) >= 1.15:
						patient["hp"] = minf(float(patient["max_hp"]), float(patient["hp"]) + float(patient["max_hp"]) * 0.28)
						patient["kb"] = -dir * 155.0
						g.spawn_ring_fx(patient["pos"], Color("7dff9a"), 49.0)
						e.erase("patient")
						e["treat_t"] = 0.0
					return Vector2.ZERO
			return dir if dist > 275.0 else -dir * 0.45
		"mama":
			# Destroyable hatchery eggs replace immediate extra mobs.
			if float(e["cd"]) <= 0.0 and g.enemies.size() < g.MAX_ENEMIES:
				e["cd"] = 5.0
				for k in range(2):
					var egg_pos: Vector2 = e["pos"] + Vector2(-24.0 if k == 0 else 24.0, 10.0)
					EnemyIdentity.place(g, "egg", egg_pos, 18.0, 0.0, 3.0 if not g.hard_mode else 2.2, 0.0)
				e["squash"] = 0.5
			return dir
		"goblin":
			if float(e["t"]) > 12.0:
				e["dead"] = true
				g.say(e["pos"], "ESCAPED!", Color("ffd24d"), 22)
				return Vector2.ZERO
			if not e.has("escape_x"):
				e["escape_x"] = (g.road_half - 22.0) * (1.0 if int(e["id"]) % 2 == 0 else -1.0)
			var escape: Vector2 = Vector2(float(e["escape_x"]), hero_pos.y - 200.0)
			var retreat: Vector2 = (escape - e["pos"]).normalized()
			if dist < 220.0:
				retreat = (retreat * 0.6 - dir * 1.1).normalized()
			return retreat
		"kaboomba":
			return dir
		"chonkzilla", "heli", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine":
			return boss_identity_ai(g, e, dir, dist, dt)
	return dir

## Elite affixes that act over time (called 4x a second).
static func elite_tick(g, e: Dictionary) -> void:
	var af: Array = e["affix"]
	if af.has("REGEN") and float(e["hp"]) < float(e["max_hp"]):
		e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.008)
	if af.has("TURRET"):
		e["turret_t"] = float(e.get("turret_t", 3.0)) - 0.25
		if float(e["turret_t"]) <= 0.0:
			e["turret_t"] = 3.0
			var base = randf() * TAU
			for k in range(8):
				enemy_fire(g, e, Vector2.from_angle(base + k * TAU / 8.0), 1, 0.0, 220.0)

## Larry retains his powerful laser. Cover blocks it; overheating exposes him.
static func larry_beam(g, e: Dictionary, dir: Vector2) -> void:
	var a: Vector2 = e["pos"] + dir * float(e["r"])
	var b: Vector2 = EnemyIdentity.clip_beam(g, a, a + dir * 950.0)
	g.beams.append({"a": a, "b": b, "t": 0.16, "w": 12.0, "color": Color("ff3a5a")})
	g.beams.append({"a": a, "b": b, "t": 0.16, "w": 4.0, "color": Color("ffe0e8")})
	if float(e.get("laser_sound_cd", 0.0)) <= 0.0:
		g.sfx.play("rail")
		e["laser_sound_cd"] = 0.58
	e["laser_sound_cd"] = float(e.get("laser_sound_cd", 0.0)) - 0.13
	if seg_dist2(a, b, g.hero["pos"]) < pow(12.0 + 11.0, 2):
		g.hurt(float(e["dmg"]) * 0.52, e["pos"], "Laser Larry")

static func enemy_fire(g, e: Dictionary, dir: Vector2, n: int, spread: float, speed: float, r: float = 6.0) -> Variant:
	var last = null
	for k in range(n):
		var a = 0.0 if n == 1 else -spread * 0.5 + spread * k / (n - 1)
		var enemy_kind = str(e["kind"])
		var boss_style = "boss_ember" if enemy_kind in ["chonkzilla", "dreadengine"] else ("boss_void" if enemy_kind in ["kingblob", "voidweaver"] else ("boss_frost" if enemy_kind in ["necro", "glassoracle"] else ("boss_storm" if enemy_kind in ["heli", "coilqueen"] else "enemy")))
		var shot_color = ProjectileVfx.tint(boss_style)
		last = shot(g, e["pos"] + dir * float(e["r"]), dir.rotated(a), float(e["dmg"]) * 0.8,
			{"friendly": false, "speed": speed, "life": 3.0, "r": r, "kind": "enemy", "color": shot_color,
			"vfx_style": boss_style, "src": "a " + str(g.enemy_db[e["kind"]]["name"]) + "'s shot"})
		if k == 0 and last != null and boss_style.begins_with("boss_"):
			g.sfx.play_projectile("boss_fire", boss_style)
	return last

# ================================================================= area effects
static func explode(g, pos: Vector2, r: float, dmg: float, gen: int, color: Color, opts: Dictionary = {}) -> void:
	g.frame_booms += 1
	var big = r > 100.0
	g.fx.append({"kind": "blast", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 0.4 if not big else 0.6, "color": color, "size": r})
	if g.frame_booms < 12:
		g.spawn_burst(pos, color, 10 if not big else 24, r * 3.0, 5.0)
		g.add_shake(minf(14.0, r / 14.0))
		g.sfx.play("boom" if r > 70.0 else "boom_small")
	if dmg > 0.0:
		for e in query(g, pos, r):
			if bool(e["dead"]):
				continue
			var d = e["pos"].distance_to(pos)
			if d < r + float(e["r"]):
				var falloff = lerpf(1.0, 0.6, clampf(d / r, 0.0, 1.0))
				hit(g, e, dmg * falloff, {"pos": e["pos"], "gen": gen, "dir": (e["pos"] - pos).normalized(),
					"knock": 160.0 + r * 1.5, "aoe": true, "noproc": gen >= Effects.max_gen(g)})
	for b in g.barrels:
		if float(b["hp"]) > 0.0 and float(b["drop"]) <= 0.0 and b["pos"].distance_to(pos) < r + 20.0:
			b["hp"] = 0.0
	for z in g.zones:
		if z["kind"] == "oil" and z["pos"].distance_to(pos) < r + float(z["r"]):
			ignite_oil(g, z)
	if gen < Effects.max_gen(g) and dmg > 0.0:
		Effects.trigger(g, "explosion", {"pos": pos, "gen": gen, "r": r})

static func confetti(g, pos: Vector2, r: float, dmg: float, gen: int) -> void:
	var colors = [Color("ff5a8a"), Color("ffd24d"), Color("5bead8"), Color("b48cff"), Color("7dff9a")]
	for i in range(22 if bool(g.settings["particles"]) else 6):
		g.fx.append({"kind": "confetti", "pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(80, r * 4.0),
			"t": 0.0, "life": randf_range(0.6, 1.2), "color": colors[randi() % colors.size()], "size": randf_range(3, 6), "rot": randf() * TAU})
	for e in query(g, pos, r):
		if not bool(e["dead"]) and e["pos"].distance_to(pos) < r + float(e["r"]):
			hit(g, e, dmg, {"pos": e["pos"], "gen": gen, "dir": (e["pos"] - pos).normalized(), "knock": 220.0, "aoe": true})
	g.sfx.play("confetti")

static func shockwave(g, pos: Vector2, r: float, dmg: float, push: float, gen: int) -> void:
	g.fx.append({"kind": "shock", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 0.35, "color": Color("dff6ff"), "size": r})
	# Weapon-generated shockwaves can set off explosive barrels too.
	if dmg > 0.0:
		for barrel in g.barrels:
			if float(barrel["hp"]) > 0.0 and float(barrel["drop"]) <= 0.0 and not bool(barrel.get("armed", false)) and pos.distance_to(barrel["pos"]) <= r + 20.0:
				barrel["hp"] = maxf(0.0, float(barrel["hp"]) - dmg)
	for e in query(g, pos, r):
		if bool(e["dead"]):
			continue
		var d = e["pos"].distance_to(pos)
		if d < r + float(e["r"]):
			hit(g, e, dmg, {"pos": e["pos"], "gen": gen, "dir": (e["pos"] - pos).normalized(), "knock": push, "aoe": true})
	for s in g.shots:
		if not s["friendly"] and s["pos"].distance_to(pos) < r:
			s["dead"] = true
	g.add_shake(5.0)
	g.sfx.play("whoosh")

static func fragments(g, pos: Vector2, n: int, dmg: float, pattern: String, dir: Vector2, gen: int, src = null, colorful = false, color = Color("fff1a8"), kind = "frag") -> void:
	if n <= 0 or g.shots.size() > g.shot_cap() - 20:
		return
	if n > 1 and gen <= 3:
		ProjectileVfx.split(g, pos, dir, "shard" if src == null else str(src.get("vfx_style", "shard")))
		g.sfx.play_projectile("split")
	var colors = [Color("ff5a8a"), Color("ffd24d"), Color("5bead8"), Color("b48cff"), Color("7dff9a")]
	var base = dir.angle()
	var fdmg = dmg * (1.0 + g.st("fragdmg") * 0.5) if src == null else dmg
	for i in range(n):
		var a = 0.0
		match pattern:
			"ring":
				a = i * TAU / n + randf_range(-0.15, 0.15)
			"forward":
				a = base + randf_range(-0.7, 0.7)
			_:
				a = randf() * TAU
		var o = {"kind": kind, "speed": randf_range(420, 600), "life": 0.5, "r": 3.0, "gen": gen, "frag": true,
			"color": colors[randi() % colors.size()] if colorful else color, "knock": 50.0}
		if kind == "grenade":
			o["life"] = 0.5
			o["blast"] = 50.0
			o["r"] = 5.0
			o["speed"] = 300.0
		if src != null:
			o["st"] = src["st"]
			o["flags"] = {"pin": src["flags"].get("pin", 0.0)} if src["flags"].has("pin") else {}
		if g.st("fragbounce") > 0.0:
			o["bounce"] = 2
			o["rico"] = 1
		if g.st("fraghome") > 0.0:
			o["homing"] = 5.0
		if g.st("fragboom") > 0.0:
			o["blast"] = 32.0
		if g.st("fractal") > 0.0 and gen < Effects.max_gen(g):
			o["split"] = 2
		var s = shot(g, pos, Vector2.from_angle(a), fdmg, o)
		if s != null and src != null and src.has("hit"):
			# Never instantly re-hit the enemy that spawned the fragments.
			for k in src["hit"]:
				s["hit"][k] = 0.15
	if pattern == "ring" and n >= 6:
		g.sfx.play("pop")

static func nova(g, pos: Vector2, n: int, dmg: float, gen: int) -> void:
	for i in range(n):
		player_shot(g, pos, Vector2.from_angle(i * TAU / n + randf_range(-0.05, 0.05)), dmg, "bullet", {"gen": gen, "color": Color("fff1a8"), "life": 0.7})
	g.spawn_ring_fx(pos, Color("fff1a8"), 40.0)

static func zap(g, pos: Vector2, n: int, dmg: float, gen: int, first = null) -> void:
	var cur = first
	if cur == null or bool(cur["dead"]):
		cur = g.nearest_enemy(pos, 280.0)
	var prev = pos
	var seen = {}
	for i in range(n):
		if cur == null:
			break
		seen[cur["id"]] = true
		g.beams.append({"a": prev, "b": cur["pos"], "t": 0.12, "w": 3.0, "color": Color("9fd8ff"), "zig": true})
		hit(g, cur, dmg, {"pos": cur["pos"], "gen": gen, "dir": (cur["pos"] - prev).normalized(), "knock": 30.0})
		prev = cur["pos"]
		var nxt = null
		var best = 200.0 * 200.0
		for o in query(g, prev, 200.0):
			if bool(o["dead"]) or seen.has(o["id"]):
				continue
			var d = prev.distance_squared_to(o["pos"])
			if d < best:
				best = d
				nxt = o
		cur = nxt
	g.sfx.play("zap")

static func strike(g, e: Dictionary, dmg: float, gen: int) -> void:
	var top = e["pos"] + Vector2(randf_range(-40, 40), -420)
	g.beams.append({"a": top, "b": e["pos"], "t": 0.18, "w": 5.0, "color": Color("e8f4ff"), "zig": true})
	g.spawn_ring_fx(e["pos"], Color("e8f4ff"), 40.0)
	hit(g, e, dmg, {"pos": e["pos"], "gen": gen, "dir": Vector2.ZERO, "knock": 0.0})
	e["stun"] = maxf(float(e["stun"]), 0.3)
	g.sfx.play("zap")

static func laser(g, from: Vector2, e: Dictionary, dmg: float, gen: int) -> void:
	g.beams.append({"a": from, "b": e["pos"], "t": 0.12, "w": 6.0, "color": Color("ff4d6a")})
	hit(g, e, dmg, {"pos": e["pos"], "gen": gen, "dir": (e["pos"] - from).normalized(), "knock": 90.0})
	g.sfx.play("rail")

static func meteor(g, pos: Vector2, dmg: float, r: float, gen: int) -> void:
	g.delayed.append({"t": 0.75, "fn": "meteor", "pos": pos, "dmg": dmg, "r": r, "gen": gen, "tele": r, "life": 0.75})

static func anvil(g, dmg: float, r: float, piano: bool, gen: int) -> void:
	var target = null
	if piano:
		var best = -1.0
		for e in g.enemies:
			if not bool(e["dead"]) and g.on_screen(e["pos"], -40.0) and float(e["hp"]) > best:
				best = float(e["hp"])
				target = e
	else:
		target = random_enemy(g, g.hero["pos"], 520.0)
	if target == null:
		return
	g.delayed.append({"t": 0.6, "fn": "anvil", "pos": target["pos"], "enemy": target, "dmg": dmg, "r": r, "gen": gen, "tele": r, "life": 0.6, "piano": piano})

static func airstrike(g, n: int, dmg: float, gen: int) -> void:
	var y = g.hero["pos"].y - randf_range(180, 300)
	for i in range(n):
		var x = -g.road_half + 60.0 + (g.road_half * 2.0 - 120.0) * float(i) / maxf(1.0, float(n - 1))
		g.delayed.append({"t": 0.5 + i * 0.07, "fn": "airbomb", "pos": Vector2(x, y + randf_range(-30, 30)), "dmg": dmg, "gen": gen, "tele": 70.0, "life": 0.5 + i * 0.07})
	g.fx.append({"kind": "jet", "pos": Vector2(-g.road_half - 100, y), "vel": Vector2(2400, 0), "t": 0.0, "life": 0.9, "color": Color.WHITE, "size": 30.0})
	g.sfx.play("whoosh")

static func blackhole(g, pos: Vector2, r: float, t: float, weak: bool) -> void:
	var z = g.add_zone("blackhole", pos, r, t)
	z["weak"] = weak
	g.sfx.play("whoosh")

static func spikes(g, pos: Vector2, n: int, dmg: float, gen: int) -> void:
	for ring in [70.0, 125.0]:
		for i in range(n):
			var p = pos + Vector2.from_angle(i * TAU / n + ring * 0.01) * ring
			g.fx.append({"kind": "spike", "pos": p, "vel": Vector2.ZERO, "t": 0.0, "life": 0.45, "color": Color("e8e8f0"), "size": 16.0})
			for e in query(g, p, 34.0):
				if not bool(e["dead"]) and e["pos"].distance_to(p) < 34.0 + float(e["r"]):
					hit(g, e, dmg, {"pos": p, "gen": gen, "dir": (e["pos"] - pos).normalized(), "knock": 160.0, "aoe": true})
	g.sfx.play("thunk")

static func clown_car(g, dmg: float, gen: int) -> void:
	var from_left = randf() < 0.5
	var y = g.hero["pos"].y - randf_range(120, 300)
	var x = -g.road_half - 40.0 if from_left else g.road_half + 40.0
	var s = shot(g, Vector2(x, y), Vector2.RIGHT if from_left else Vector2.LEFT, dmg,
		{"kind": "car", "speed": 560.0, "life": 2.4, "r": 30.0, "pierce": 999, "knock": 900.0, "gen": gen, "color": Color("ff5a8a"), "flags": {"fling": true}})
	g.sfx.play("honk")

static func potato(g, dmg: float, gen: int) -> void:
	var e = random_enemy(g, g.hero["pos"], 500.0)
	if e == null:
		return
	g.delayed.append({"t": 0.3, "fn": "potato", "enemy": e, "hops": 4, "dmg": dmg, "gen": gen, "from": g.hero["pos"]})
	g.fx.append({"kind": "arc", "pos": g.hero["pos"], "to": e["pos"], "vel": Vector2.ZERO, "t": 0.0, "life": 0.3, "color": Color("ffb84d"), "size": 8.0})

static func potato_hop(g, item: Dictionary) -> void:
	var e = item["enemy"]
	var pos: Vector2 = e["pos"]
	if int(item["hops"]) <= 0 or bool(e["dead"]):
		explode(g, pos, 105.0, float(item["dmg"]), int(item["gen"]), Color("ffb84d"))
		g.say(pos + Vector2(0, -30), "HOT POTATO!", Color("ffb84d"), 24)
		return
	hit(g, e, float(item["dmg"]) * 0.15, {"pos": pos, "gen": int(item["gen"]), "dir": Vector2.ZERO, "knock": 0.0, "st": {"burn": 1.0}})
	var nxt = g.nearest_enemy(pos, 260.0, e)
	if nxt == null:
		nxt = e
	g.fx.append({"kind": "arc", "pos": pos, "to": nxt["pos"], "vel": Vector2.ZERO, "t": 0.0, "life": 0.25, "color": Color("ffb84d"), "size": 8.0})
	g.delayed.append({"t": 0.25, "fn": "potato", "enemy": nxt, "hops": int(item["hops"]) - 1, "dmg": item["dmg"], "gen": item["gen"]})

static func coin(g, pos: Vector2, dir: Vector2, dmg: float, gen: int) -> void:
	var t = g.nearest_enemy(pos, 600.0)
	var d = dir if t == null else (t["pos"] - pos).normalized()
	shot(g, pos, d, dmg, {"kind": "coin", "speed": 760.0, "life": 1.4, "r": 6.0, "rico": 4, "gen": gen, "color": Color("ffd24d"), "knock": 80.0})
	g.sfx.play("coin")

static func saw(g, pos: Vector2, dmg: float, gen: int) -> void:
	shot(g, pos, Vector2.from_angle(randf() * TAU), dmg, {"kind": "saw", "speed": 380.0, "life": 3.0, "r": 13.0, "pierce": 999, "bounce": 6, "gen": gen, "color": Color("e8e8f0"), "knock": 60.0, "st": {"bleed": 0.5}})

static func chicken(g, pos: Vector2, dir: Vector2, dmg: float, gen: int) -> void:
	shot(g, pos, dir, dmg, {"kind": "chicken", "speed": 540.0, "life": 1.6, "r": 9.0, "rico": 4, "blast": 60.0, "gen": gen, "color": Color("fff27a"), "knock": 120.0})
	g.sfx.play("honk")

static func rocket(g, pos: Vector2, dir: Vector2, dmg: float, gen: int) -> void:
	shot(g, pos, dir, dmg, {"kind": "rocket", "speed": 300.0, "life": 1.6, "r": 6.0, "blast": 70.0, "homing": 3.0, "gen": gen, "color": Color("ff8f6b"), "knock": 200.0})

static func boomerang(g, pos: Vector2, dir: Vector2, dmg: float, gen: int) -> void:
	shot(g, pos, dir, dmg, {"kind": "boomerang", "speed": 620.0, "life": 0.55, "r": 13.0, "pierce": 999, "gen": gen, "color": Color("ffcf6b"), "knock": 120.0})

static func bubbles(g, pos: Vector2, n: int, dmg: float, gen: int) -> void:
	for i in range(n):
		shot(g, pos, Vector2.from_angle(randf() * TAU), dmg, {"kind": "bubble", "speed": 150.0, "life": 3.0, "r": 12.0, "blast": 50.0, "gen": gen, "color": Color("9fe8ff"), "flags": {"trap": 1, "trapped": 0}, "homing": 1.5})

static func pop_bubble(g, pos: Vector2, dmg: float, r: float, gen: int, mini: bool) -> void:
	g.spawn_burst(pos, Color("d8f6ff"), 8, 160.0, 3.0)
	g.sfx.play("bloop")
	explode(g, pos, maxf(40.0, r), dmg, gen, Color("9fe8ff"))
	if mini and gen < 2:
		for i in range(6):
			shot(g, pos, Vector2.from_angle(i * TAU / 6.0), dmg * 0.3, {"kind": "bubble", "speed": 160.0, "life": 1.0, "r": 7.0, "blast": 30.0, "gen": gen + 1, "color": Color("9fe8ff"), "flags": {"trap": 1, "trapped": 0}})

static func add_bees(g, pos: Vector2, n: int, dmg: float, gen: int) -> void:
	for i in range(n):
		shot(g, pos, Vector2.from_angle(randf() * TAU), dmg, {"kind": "bee", "speed": 300.0, "life": 3.5, "r": 4.0, "pierce": 2, "homing": 6.0, "gen": gen, "color": Color("ffd94d"), "st": {"poison": 0.6}, "knock": 15.0})

static func drop_mine(g, pos: Vector2) -> void:
	var count = 0
	for p in g.pets:
		if p["kind"] == "mine":
			count += 1
	if count < 30:
		g.pets.append({"kind": "mine", "pos": pos, "life": 25.0, "arm": 0.5})

static func ignite_oil(g, z: Dictionary) -> void:
	if z["kind"] != "oil":
		return
	z["kind"] = "blaze"
	z["r"] = float(z["r"]) * 1.35
	z["t"] = 4.0
	z["life"] = 4.0
	g.say(z["pos"] + Vector2(0, -30), "WHOOSH", Color("ff8a3d"), 26)
	g.add_shake(6.0)

# ================================================================= zones
static func update_zones(g, dt: float) -> void:
	var ss = g.sector_scale()
	for i in range(g.zones.size() - 1, -1, -1):
		var z = g.zones[i]
		z["t"] = float(z["t"]) - dt
		if float(z["t"]) <= 0.0:
			g.zones.remove_at(i)
			continue
		var kind = str(z["kind"])
		if kind == "blackhole":
			var strength = 160.0 if bool(z.get("weak", false)) else 420.0
			for e in query(g, z["pos"], float(z["r"]) * 1.6):
				if bool(e["dead"]) or bool(e["boss"]):
					continue
				var off: Vector2 = z["pos"] - e["pos"]
				if off.length() < float(z["r"]) * 1.6:
					e["pos"] += off.normalized() * minf(off.length(), strength * dt)
		z["tick"] = float(z["tick"]) - dt
		if float(z["tick"]) > 0.0:
			continue
		z["tick"] = 0.25
		var gen = int(z.get("gen", 1))
		if kind == "lightning":
			# Ion Scar can also electrify an explosive barrel in its path.
			damage_barrels_segment(g, z["a"], z["b"], float(z["r"]), 8.0 * ss * g.dmg_mult())
			# Ion Scar is an actual line-segment AREA for its entire lifetime,
			# not a circle centred at the shot origin. Scan the segment plus
			# the zone width and each enemy's body radius.
			var start: Vector2 = z["a"]
			var stop: Vector2 = z["b"]
			var field_radius = maxf(8.0, float(z["r"]))
			var midpoint = (start + stop) * 0.5
			var search_radius = start.distance_to(stop) * 0.5 + field_radius + 48.0
			for e in query(g, midpoint, search_radius):
				if bool(e["dead"]):
					continue
				var hit_radius = float(e["r"]) + field_radius
				if seg_dist2(start, stop, e["pos"]) <= hit_radius * hit_radius:
					dot(g, e, 8.0 * ss * g.dmg_mult(), Color("9fd0ff"))
					apply_status(g, e, "shock", 1.0)
			continue
		var r = float(z["r"])
		for e in query(g, z["pos"], r):
			if bool(e["dead"]) or e["pos"].distance_to(z["pos"]) > r + float(e["r"]) * 0.5:
				continue
			match kind:
				"fire":
					apply_status(g, e, "burn", 1.0)
				"blaze":
					apply_status(g, e, "burn", 1.0)
					dot(g, e, 6.0 * ss * g.dmg_mult(), Color("ff8a3d"))
				"poison":
					apply_status(g, e, "poison", 1.0)
				"ice":
					apply_status(g, e, "freeze", 18.0)
				"oil":
					e["slow"] = maxf(float(e["slow"]), 0.5)
					if float(e["burn"]) > 0.0:
						ignite_oil(g, z)
				"banana":
					if float(e["stun"]) <= 0.0 and not bool(e["boss"]):
						e["stun"] = 1.4
						e["spin"] = 1.4
						e["kb"] = Vector2.from_angle(randf() * TAU) * 260.0
						g.say(e["pos"] + Vector2(0, -20), "SLIP!", Color("fff27a"), 20)
						g.sfx.play("slip")
						z["t"] = 0.0
						break
				"blackhole":
					if not bool(z.get("weak", false)):
						dot(g, e, 5.0 * ss * g.dmg_mult(), Color("b48cff"))
		if kind == "fire":
			for oz in g.zones:
				if oz["kind"] == "oil" and oz["pos"].distance_to(z["pos"]) < float(oz["r"]) + r:
					ignite_oil(g, oz)

# ================================================================= allies
static func sync_pets(g) -> void:
	var want = {"drone": int(g.st("drone")), "intern": int(g.st("minion")), "chicken": int(g.st("chickenpet")), "dog": int(g.st("dog")), "saw": int(g.st("sawblade")), "ghost": mini(3, int(g.st("ghostwalk")))}
	var have = {}
	for p in g.pets:
		have[p["kind"]] = int(have.get(p["kind"], 0)) + 1
	for k in want:
		var diff = int(want[k]) - int(have.get(k, 0))
		for i in range(diff):
			var p = {"kind": k, "pos": g.hero["pos"] + Vector2(randf_range(-30, 30), 40), "cd": randf_range(0.2, 1.0), "vel": Vector2.ZERO, "t": 0.0, "state": "follow", "slot": int(have.get(k, 0)) + i}
			if k == "saw":
				p["vel"] = Vector2.from_angle(randf() * TAU) * 360.0
				p["hits"] = {}
			g.pets.append(p)
		if diff < 0:
			var removed = 0
			for i in range(g.pets.size() - 1, -1, -1):
				if g.pets[i]["kind"] == k and removed < -diff:
					g.pets.remove_at(i)
					removed += 1

static func update_allies(g, dt: float) -> void:
	var hero_pos: Vector2 = g.hero["pos"]
	var ss = g.sector_scale()
	var dm = g.dmg_mult() * ss
	sync_pets(g)
	# ---- orbiting blades
	for i in range(g.temp_orbitals.size() - 1, -1, -1):
		g.temp_orbitals[i]["t"] = float(g.temp_orbitals[i]["t"]) - dt
		if float(g.temp_orbitals[i]["t"]) <= 0.0:
			g.temp_orbitals.remove_at(i)
	var n_orb = int(g.st("orbit")) + g.temp_orbitals.size()
	g.orbit_angle += dt * 2.6 * (1.0 + g.st("orbspeed"))
	if n_orb > 0:
		var radius = 74.0 * (1.0 + g.st("orbitr"))
		var odmg = 14.0 * (1.0 + g.st("orbitdmg")) * dm
		for i in range(n_orb):
			var bp = hero_pos + Vector2.from_angle(g.orbit_angle + i * TAU / n_orb) * radius
			for e in query(g, bp, 22.0):
				if bool(e["dead"]) or float(e["charm"]) > 0.0:
					continue
				if e["pos"].distance_to(bp) < float(e["r"]) + 14.0:
					var key = int(e["id"]) * 64 + i
					if float(g.orbit_hits.get(key, -1.0)) > g.run_time:
						continue
					g.orbit_hits[key] = g.run_time + 0.35
					var ctx = {"pos": bp, "gen": 1, "dir": (e["pos"] - hero_pos).normalized(), "knock": 150.0}
					if g.st("orbitbleed") > 0.0:
						ctx["st"] = {"bleed": 1.0}
					hit(g, e, odmg, ctx)
			if g.st("orbitguns") > 0.0 and fmod(g.run_time + i * 0.17, 1.0) < dt:
				var t = g.nearest_enemy(bp, 320.0)
				if t != null:
					player_shot(g, bp, (t["pos"] - bp).normalized(), 8.0 * dm)
		if g.orbit_hits.size() > 4000:
			g.orbit_hits.clear()
	# ---- bullet-blocking orbs
	var n_shield = int(g.st("orbshield"))
	if n_shield > 0:
		for i in range(n_shield):
			var sp = hero_pos + Vector2.from_angle(-g.orbit_angle * 1.3 + i * TAU / n_shield) * 44.0
			for s in g.shots:
				if not s["friendly"] and not bool(s["dead"]) and s["pos"].distance_to(sp) < 14.0 + float(s["r"]):
					s["dead"] = true
					g.spawn_burst(sp, Color("8ff8ff"), 3, 120.0, 2.5)
	# ---- turrets
	for i in range(g.turrets.size() - 1, -1, -1):
		var t = g.turrets[i]
		t["t"] = float(t["t"]) - dt
		t["cd"] = float(t["cd"]) - dt
		if float(t["t"]) <= 0.0:
			g.turrets.remove_at(i)
			continue
		if float(t["cd"]) <= 0.0:
			var tgt = g.nearest_enemy(t["pos"], 460.0)
			if tgt != null:
				t["cd"] = 0.2
				t["aim"] = (tgt["pos"] - t["pos"]).normalized()
				player_shot(g, t["pos"] + t["aim"] * 16.0, t["aim"], 9.0 * dm)
	# ---- pets
	var idx = {"drone": 0, "intern": 0, "chicken": 0, "dog": 0, "ghost": 0}
	var counts = {"drone": int(g.st("drone")), "intern": int(g.st("minion"))}
	for i in range(g.pets.size() - 1, -1, -1):
		var p = g.pets[i]
		p["t"] = float(p.get("t", 0.0)) + dt
		p["cd"] = float(p.get("cd", 0.0)) - dt
		var k = str(p["kind"])
		match k:
			"ghost":
				# Actual spectral follower, not a mirrored volley on the other road.
				var gi = int(idx["ghost"])
				idx["ghost"] = gi + 1
				var side = -1.0 if gi % 2 == 0 else 1.0
				var row = int(gi / 2)
				var home = hero_pos + Vector2(side * (42.0 + row * 23.0), 30.0 + row * 22.0)
				p["pos"] = p["pos"].lerp(home, 1.0 - exp(-5.0 * dt))
				if float(p["cd"]) <= 0.0:
					var target = g.nearest_enemy(p["pos"], 440.0)
					if target != null:
						p["cd"] = 0.86
						var aim = (target["pos"] - p["pos"]).normalized()
						p["aim"] = aim
						player_shot(g, p["pos"] + aim * 11.0, aim, (10.0 + g.st("ghostwalk") * 3.0) * dm, "bullet",
							{"r": 3.0, "color": Color("b6a6ff"), "src": "ghost_walker", "vfx_style": "magic", "gen": 1})
						g.sfx.play_projectile("fire", "magic", "", 0.35)
			"drone":
				var di = int(idx["drone"])
				idx["drone"] = di + 1
				var home = hero_pos + Vector2.from_angle(g.anim_t * 1.2 + di * TAU / maxi(1, counts["drone"])) * 46.0 + Vector2(0, -24)
				p["pos"] = p["pos"].lerp(home, 1.0 - exp(-8.0 * dt))
				if float(p["cd"]) <= 0.0:
					var tgt = g.nearest_enemy(p["pos"], 460.0)
					if tgt != null:
						p["cd"] = 0.6 / (1.0 + g.st("dronerate"))
						var d = (tgt["pos"] - p["pos"]).normalized()
						p["aim"] = d
						if g.st("dronerocket") > 0.0:
							rocket(g, p["pos"], d, 20.0 * dm, 1)
							p["cd"] = 1.2 / (1.0 + g.st("dronerate"))
						else:
							player_shot(g, p["pos"], d, 11.0 * dm)
			"intern":
				var ii = int(idx["intern"])
				idx["intern"] = ii + 1
				var home2 = hero_pos + Vector2(-50 + (ii % 3) * 50, 52 + int(ii / 3) * 30)
				p["pos"] = p["pos"].lerp(home2, 1.0 - exp(-5.0 * dt))
				if float(p["cd"]) <= 0.0:
					var tgt2 = g.nearest_enemy(p["pos"], 420.0)
					if tgt2 != null:
						p["cd"] = 0.55
						p["aim"] = (tgt2["pos"] - p["pos"]).normalized()
						player_shot(g, p["pos"], p["aim"], 9.0 * dm, "bullet", {"r": 3.0, "color": Color("9dff9a")})
			"chicken":
				var home3 = hero_pos + Vector2(36, 30)
				if p["pos"].distance_to(home3) > 30.0:
					p["pos"] = p["pos"].move_toward(home3, 230.0 * dt)
				if float(p["cd"]) <= 0.0:
					var tgt3 = g.nearest_enemy(p["pos"], 280.0)
					if tgt3 != null:
						p["cd"] = 3.0 / maxf(1.0, g.st("chickenpet"))
						var o = {"kind": "egg", "speed": 420.0, "life": 0.8, "r": 6.0, "blast": 70.0, "gen": 1, "color": Color("fff8e0"), "knock": 100.0}
						shot(g, p["pos"], (tgt3["pos"] - p["pos"]).normalized(), 35.0 * dm, o)
						if randf() < 0.4:
							g.say(p["pos"] + Vector2(0, -20), "BAWK", Color("fff27a"), 16)
			"dog":
				if p["state"] == "follow":
					var home4 = hero_pos + Vector2(-38, 26)
					p["pos"] = p["pos"].move_toward(home4, 260.0 * dt) if p["pos"].distance_to(home4) > 20.0 else p["pos"]
					if float(p["cd"]) <= 0.0:
						var tgt4 = g.nearest_enemy(p["pos"], 320.0)
						if tgt4 != null:
							p["state"] = "attack"
							p["target"] = tgt4
				else:
					var tgt5 = p.get("target")
					if tgt5 == null or bool(tgt5["dead"]) or float(p["t"]) > 30.0 and false:
						p["state"] = "follow"
						p["cd"] = 0.4
					else:
						p["pos"] = p["pos"].move_toward(tgt5["pos"], 680.0 * dt)
						if p["pos"].distance_to(tgt5["pos"]) < float(tgt5["r"]) + 10.0:
							hit(g, tgt5, 26.0 * dm, {"pos": tgt5["pos"], "gen": 1, "dir": (tgt5["pos"] - hero_pos).normalized(), "knock": 160.0, "st": {"bleed": 1.0}})
							p["state"] = "follow"
							p["cd"] = 1.1 / maxf(1.0, g.st("dog"))
							if randf() < 0.25:
								g.say(p["pos"] + Vector2(0, -20), "WOOF", Color("ffcf6b"), 16)
			"saw":
				p["pos"] += p["vel"] * dt
				var sp2: Vector2 = p["pos"]
				if absf(sp2.x) > g.road_half - 14.0:
					p["vel"].x = -p["vel"].x
					sp2.x = clampf(sp2.x, -g.road_half + 14.0, g.road_half - 14.0)
				var top = g.cam_y - 330.0
				var bottom = g.cam_y + 330.0
				if sp2.y < top or sp2.y > bottom:
					p["vel"].y = absf(p["vel"].y) * (1.0 if sp2.y < top else -1.0)
					sp2.y = clampf(sp2.y, top, bottom)
				p["pos"] = sp2
				for e in query(g, sp2, 20.0):
					if bool(e["dead"]) or e["pos"].distance_to(sp2) > float(e["r"]) + 16.0:
						continue
					if float(p["hits"].get(e["id"], -1.0)) > g.run_time:
						continue
					p["hits"][e["id"]] = g.run_time + 0.3
					hit(g, e, 18.0 * dm, {"pos": sp2, "gen": 1, "dir": p["vel"].normalized(), "knock": 120.0, "st": {"bleed": 0.4}})
				if p["hits"].size() > 300:
					p["hits"].clear()
			"decoy":
				p["left"] = float(p.get("left", 1.5)) - dt
				if float(p["left"]) <= 0.0:
					explode(g, p["pos"], 110.0, float(p["dmg"]), int(p.get("gen", 1)), Color("b48cff"))
					g.pets.remove_at(i)
			"mine":
				p["arm"] = float(p["arm"]) - dt
				var life = float(p.get("life", 25.0)) - dt
				p["life"] = life
				if life <= 0.0:
					g.pets.remove_at(i)
					continue
				if float(p["arm"]) <= 0.0:
					for e in query(g, p["pos"], 36.0):
						if not bool(e["dead"]) and e["pos"].distance_to(p["pos"]) < 34.0 + float(e["r"]):
							explode(g, p["pos"], 80.0, 40.0 * dm, 1, Color("ffb84d"))
							g.pets.remove_at(i)
							break

## Detonates only after an observable fuse, including blast-chain and dash triggers.
## Chain blasts arm nearby barrels first rather than triggering same-frame explosions.
static func barrel_arm(barrel: Dictionary) -> void:
	barrel["armed"] = true
	barrel["fuse"] = 0.85

static func barrel_countdown(barrel: Dictionary, dt: float) -> bool:
	barrel["fuse"] = maxf(0.0, float(barrel["fuse"]) - dt)
	return float(barrel["fuse"]) <= 0.0

static func update_barrels(g, dt: float) -> void:
	for i in range(g.barrels.size() - 1, -1, -1):
		var barrel = g.barrels[i]
		if float(barrel["drop"]) > 0.0:
			barrel["drop"] = float(barrel["drop"]) - dt
			if float(barrel["drop"]) <= 0.0:
				g.add_shake(3.0)
				g.sfx.play("thunk")
			continue
		if float(barrel["hp"]) <= 0.0 and not bool(barrel.get("armed", false)):
			barrel_arm(barrel)
			g.sfx.play("fuse")
			continue
		if bool(barrel.get("armed", false)):
			var previous_fuse = float(barrel["fuse"])
			if barrel_countdown(barrel, dt):
				var pos: Vector2 = barrel["pos"]
				g.barrels.remove_at(i)
				# Barrels hurt both the player and their nearby monsters.
				explode(g, pos, 115.0, 55.0 * g.sector_scale() * g.dmg_mult(), 1, Color("ff6b3d"))
				g.sfx.play_projectile("barrel_boom")
				if g.hero["pos"].distance_to(pos) < 125.0:
					g.hurt(12.0 + minf(32.0, g.sector * 1.1), pos, "an explosive barrel")
				g.add_zone("fire", pos, 60.0, 2.5)
			elif previous_fuse > 0.34 and float(barrel["fuse"]) <= 0.34:
				g.sfx.play_projectile("barrel_warn")
			continue
		if barrel["pos"].y > g.hero["pos"].y + 900.0:
			g.barrels.remove_at(i)

static func update_fx(g, dt: float) -> void:
	for i in range(g.fx.size() - 1, -1, -1):
		var f = g.fx[i]
		f["t"] = float(f["t"]) + dt
		if float(f["t"]) >= float(f["life"]):
			g.fx.remove_at(i)
			continue
		f["pos"] += f["vel"] * dt
		if f["kind"] == "cinder_flame":
			# Visual-only turbulence: old-school fire puffs roll and curl
			# instead of flying in straight, separated projectile lanes.
			var velocity: Vector2 = f["vel"]
			var age = float(f["t"]) / maxf(0.01, float(f["life"]))
			var wobble = sin(float(f["seed"]) + float(f["t"]) * 25.0)
			f["pos"] += velocity.normalized().orthogonal() * wobble * 32.0 * dt * (0.3 + age)
		if f["kind"] in ["spark", "confetti"]:
			f["vel"] = f["vel"] * exp(-4.0 * dt)
			if f["kind"] == "confetti":
				f["vel"].y += 120.0 * dt
