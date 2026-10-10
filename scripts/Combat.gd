extends RefCounted
## Simulation: projectiles, enemies, statuses, explosions, zones and every autonomous ally.
## Entities are plain dictionaries drawn by Visuals.gd in one canvas pass.

const Effects = preload("res://scripts/Effects.gd")
const ProjectileVfx = preload("res://scripts/ProjectileVfx.gd")
const RoadObstacles = preload("res://scripts/RoadObstacles.gd")
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
				explode(g, item["pos"], 72.0, 0.0, 9, Color("ffb84d"))
				if g.hero["pos"].distance_to(item["pos"]) < 72.0 + 11.0:
					g.hurt(float(item["dmg"]), item["pos"], "a Mortar Mike shell")
			"kaboomba_boom":
				kaboom(g, item["pos"], float(item["tele"]), float(item["dmg"]))
			"boss_blast":
				var radius = float(item["tele"])
				explode(g, item["pos"], radius, 0.0, 9, Color(str(item.get("color", "ff9944"))))
				ProjectileVfx.boss_impact(g, item["pos"], "boss_ember" if str(item.get("color", "")) == "ff9944" else "boss_void", radius)
				g.sfx.play_projectile("boss_impact")
				if g.hero["pos"].distance_to(item["pos"]) <= radius + 11.0:
					g.hurt(float(item["dmg"]), item["pos"], "a boss attack")
			"boss_line":
				# Telegraph exactly the same segment and collision width as the strike.
				var a: Vector2 = item["a"]
				var b: Vector2 = item["b"]
				var w: float = float(item["tele"])
				var col = Color(str(item.get("color", "ff9944")))
				g.beams.append({"a": a, "b": b, "t": 0.24, "w": w * 2.0, "color": col, "zig": false})
				g.spawn_ring_fx((a + b) * 0.5, col, w * 2.0)
				g.sfx.play_projectile("boss_impact")
				if seg_dist2(a, b, g.hero["pos"]) <= pow(w + 11.0, 2.0):
					g.hurt(float(item["dmg"]), (a + b) * 0.5, "a boss lane attack")
			"elite_boom":
				explode(g, item["pos"], float(item["tele"]), 0.0, 9, Color("ff5a4a"))
				if g.hero["pos"].distance_to(item["pos"]) < float(item["tele"]) + 11.0:
					g.hurt(float(item["dmg"]), item["pos"], "a Volatile elite")
			"payload_vacuum":
				WeaponSignatures.vacuum(g, item["pos"])

# ================================================================= projectiles
static func shot(g, pos: Vector2, dir: Vector2, dmg: float, o: Dictionary) -> Variant:
	var friendly = bool(o.get("friendly", true))
	if friendly and g.shots.size() >= g.shot_cap():
		return null
	if not friendly and g.shots.size() >= g.shot_cap():
		return null
	var spd = float(o.get("speed", 700.0))
	var radius = minf(float(o.get("r", 4.0)), g.projectile_size_cap()) if friendly else float(o.get("r", 4.0))
	var s = {"pos": pos, "last": pos, "vel": dir.normalized() * spd, "speed": spd, "dmg": dmg,
		"r": radius, "life": float(o.get("life", 1.0)), "max_life": float(o.get("life", 1.0)), "t": 0.0,
		"pierce": int(o.get("pierce", 0)), "bounce": int(o.get("bounce", 0)), "rico": int(o.get("rico", 0)),
		"homing": float(o.get("homing", 0.0)), "boomer": bool(o.get("boomer", false)), "back": false,
		"wave": float(o.get("wave", 0.0)), "curve": float(o.get("curve", 0.0)) * (1.0 if randf() < 0.5 else -1.0),
		"accel": bool(o.get("accel", false)), "split": int(o.get("split", 0)), "kind": str(o.get("kind", "bullet")),
		"gen": int(o.get("gen", 0)), "friendly": friendly, "hit": {}, "color": o.get("color", Color("8ff8ff")),
		"knock": float(o.get("knock", 60.0)), "crit": float(o.get("crit", 0.0)), "blast": float(o.get("blast", 0.0)),
		"src": str(o.get("src", "")), "st": o.get("st", {}), "flags": o.get("flags", {}).duplicate(), "frag": bool(o.get("frag", false)),
		"gun": o.get("gun"), "phase": randf() * TAU, "base_r": radius, "base_dmg": dmg, "dead": false, "pool": float(o.get("pool", 0.0)),
		"spin": randf() * TAU}
	# Carry the source style/pattern from the weapon; spawned fragments may override it.
	s["vfx_style"] = str(o.get("vfx_style", ProjectileVfx.style_for(str(s["kind"]), str(s["src"]), s["st"])))
	s["vfx_pattern"] = str(o.get("vfx_pattern", ""))
	g.shots.append(s)
	if friendly and int(s["gen"]) <= 1:
		ProjectileVfx.muzzle(g, pos, dir, str(s["vfx_style"]), radius + 2.0)
	return s

static func player_shot(g, pos: Vector2, dir: Vector2, dmg: float, kind: String = "bullet", extra: Dictionary = {}) -> Variant:
	var o = {"kind": kind, "speed": 760.0 * maxf(0.3, 1.0 + g.st("pspeed")), "life": 0.75 * maxf(0.3, 1.0 + g.st("range")),
		"r": 3.5 * (1.0 + g.st("size") * 0.6), "pierce": int(g.st("pierce")), "bounce": int(g.st("bounce")),
		"rico": int(g.st("rico")), "homing": g.st("homing"), "split": int(g.st("split")), "knock": 50.0,
		"wave": g.st("wave"), "accel": g.st("accel") > 0, "color": Color("bfffef"), "gen": 1}
	o.merge(extra, true)
	return shot(g, pos, dir, dmg, o)

static func update_shots(g, dt: float) -> void:
	var hero_pos: Vector2 = g.hero["pos"]
	var count = g.shots.size()
	for i in range(count):
		var s = g.shots[i]
		if bool(s["dead"]):
			continue
		s["t"] = float(s["t"]) + dt
		s["life"] = float(s["life"]) - dt
		s["spin"] = float(s["spin"]) + dt * 14.0
		var kind = str(s["kind"])
		if float(s["life"]) <= 0.0:
			if s["friendly"] and bool(s["boomer"]) and not bool(s["back"]) and kind not in ["disc", "boomerang"]:
				s["back"] = true
				s["boomer"] = false # One return; never recycle the same explosive payload.
				s["life"] = float(s["max_life"]) * 1.2
				s["hit"] = {}
				if kind in ["grenade", "egg", "rocket", "chicken"]:
					# Legendary Return to Sender: second explosive contact is
					# a weaker aftershock, not a duplicate full-power detonation.
					s["flags"]["return_aftershock"] = true
					s["dmg"] = float(s["dmg"]) * 0.42
					s["blast"] = float(s["blast"]) * 0.75
			else:
				expire(g, s)
				continue
		s["last"] = s["pos"]
		var vel: Vector2 = s["vel"]
		# ---- behaviours
		if bool(s["accel"]):
			vel *= 1.0 + 1.2 * dt
			s["dmg"] = float(s["dmg"]) * (1.0 + 0.6 * dt)
		match kind:
			"grenade", "egg":
				# Guided max-level bankshots stay fast enough to reach their locked prey.
				vel *= exp((-0.3 if s["flags"].has("guided") else -2.4) * dt)
				if s["flags"].has("stuck"):
					var host = s["flags"]["stuck"]
					if host != null and not bool(host["dead"]):
						s["pos"] = host["pos"]
						vel = Vector2.ZERO
			"flame":
				vel *= exp(-3.2 * dt)
				s["r"] = minf(g.projectile_size_cap(), float(s["r"]) + 26.0 * dt)
			"snow":
				var grow = float(s["flags"].get("grow", 2.5))
				var k = clampf(float(s["t"]) / 1.0, 0.0, 1.0)
				s["r"] = minf(g.projectile_size_cap(), float(s["base_r"]) * lerpf(1.0, grow, k))
				s["dmg"] = float(s["base_dmg"]) * lerpf(1.0, grow, k)
			"rocket":
				if vel.length() < 950.0:
					vel *= 1.0 + 2.2 * dt
				s["homing"] = maxf(float(s["homing"]), 2.0)
			"bee":
				vel = vel.rotated(sin(float(s["t"]) * 9.0 + float(s["phase"])) * 6.0 * dt)
			"disc", "boomerang":
				var out_time = float(s["max_life"])
				if not bool(s["back"]):
					if kind == "boomerang":
						vel = vel.rotated(2.6 * dt)
					if float(s["t"]) > out_time:
						s["back"] = true
						s["hit"] = {}
						if s["flags"].has("grow_back"):
							s["r"] = minf(g.projectile_size_cap(), float(s["r"]) * 2.0)
				else:
					var to_hero = hero_pos - s["pos"]
					var owner_gun = s.get("gun")
					var return_bonus = 1.3 if owner_gun != null and bool(owner_gun.get("evolved", false)) else 1.0
					if owner_gun != null:
						return_bonus *= Compatibility.return_speed(g, owner_gun)
					vel = vel.lerp(to_hero.normalized() * float(s["speed"]) * 1.15 * return_bonus, minf(1.0, dt * 7.0))
					WeaponSignatures.disc_recall(g, s, dt)
					if to_hero.length() < 26.0:
						catch(g, s, true)
						continue
				s["life"] = maxf(float(s["life"]), 0.5)
				if float(s["t"]) > 4.0:
					catch(g, s, false)
					continue
			"car":
				pass
		if s["friendly"] and bool(s["back"]) and kind not in ["disc", "boomerang"]:
			var to_h = hero_pos - s["pos"]
			vel = vel.lerp(to_h.normalized() * float(s["speed"]), minf(1.0, dt * 6.0))
			if to_h.length() < 20.0:
				s["dead"] = true
				continue
		# Returning weapons must actually get home: homing, curve and wave
		# can steer an outbound disc, but never override its return steering.
		var is_returning = bool(s["back"]) and kind in ["disc", "boomerang"]
		var homing = 0.0 if is_returning else float(s["homing"])
		if homing > 0.0:
			var tgt = null
			if s["friendly"]:
				tgt = g.nearest_enemy(s["pos"], 300.0)
				if s["flags"].has("hydra_seek"):
					var best_dist = INF
					for candidate in query(g, s["pos"], 300.0):
						if bool(candidate["dead"]) or s["hit"].has(candidate["id"]):
							continue
						var dist2 = s["pos"].distance_squared_to(candidate["pos"])
						if dist2 < best_dist:
							best_dist = dist2
							tgt = candidate
				elif s["flags"].has("hive_scent"):
					for candidate in query(g, s["pos"], 300.0):
						if bool(candidate["dead"]) or s["hit"].has(candidate["id"]) or float(candidate.get("hive_scent", 0.0)) < g.run_time:
							continue
						tgt = candidate
						break
			elif not g.hero.is_empty():
				tgt = g.hero
			if tgt != null:
				var want = (tgt["pos"] - s["pos"]).angle()
				var diff = wrapf(want - vel.angle(), -PI, PI)
				vel = vel.rotated(clampf(diff, -homing * dt, homing * dt))
		if not is_returning and float(s["curve"]) != 0.0:
			vel = vel.rotated(float(s["curve"]) * dt)
		s["vel"] = vel
		var step_v = vel * dt
		if not is_returning and float(s["wave"]) > 0.0:
			var perp = vel.normalized().orthogonal()
			step_v += perp * cos(float(s["t"]) * 16.0 + float(s["phase"])) * float(s["wave"]) * 16.0 * dt
		s["pos"] += step_v
		# ---- road walls
		var p: Vector2 = s["pos"]
		if absf(p.x) > g.road_half - 4.0:
			if int(s["bounce"]) > 0 or kind in ["disc", "boomerang", "saw", "chicken", "bubble", "bee", "grenade", "egg"]:
				if int(s["bounce"]) > 0:
					s["bounce"] = int(s["bounce"]) - 1
				vel.x = -vel.x
				s["vel"] = vel
				p.x = clampf(p.x, -g.road_half + 5.0, g.road_half - 5.0)
				s["pos"] = p
				on_wall(g, s)
			elif kind == "car":
				pass
			else:
				expire(g, s)
				continue
		if absf(p.y - hero_pos.y) > 1000.0:
			s["dead"] = true
			continue
		if not g.obstacles.is_empty():
			var obstacle_idx = RoadObstacles.bullet_target(s["last"], s["pos"], float(s["r"]), g.obstacles)
			if obstacle_idx >= 0:
				var hazard: Dictionary = g.obstacles[obstacle_idx]
				# Destructible car wrecks and barriers take full projectile damage.
				if bool(s["friendly"]) and float(hazard["hp"]) > 0.0:
					hazard["hp"] = float(hazard["hp"]) - float(s["dmg"])
					if float(hazard["hp"]) <= 0.0:
						g.spawn_burst(hazard["pos"], Color("ffaa64"), 13 if hazard["kind"] == "car" else 6, 220.0, 4.0)
						g.sfx.play("boom" if hazard["kind"] == "car" else "thunk")
						g.obstacles.remove_at(obstacle_idx)
				ProjectileVfx.impact(g, s["pos"], s["vel"].normalized(), "heavy", 11.0)
				s["dead"] = true
				continue
		if s["friendly"]:
			collide_enemies(g, s)
			if not bool(s["dead"]) and not g.barrels.is_empty():
				collide_barrels(g, s)
		else:
			collide_hero(g, s)

static func catch(g, s: Dictionary, caught: bool = true) -> void:
	WeaponSignatures.return_catch(g, s, caught)
	s["dead"] = true
	var w = s.get("gun")
	if w != null and bool(s["flags"].get("owner", false)):
		w["ammo"] = mini(int(w["mag_max"]), int(w["ammo"]) + 1)
		if caught:
			Weapons.return_catch_card_cycle(g, w)

## Explosive rounds consume their collider on contact, so ordinary ricochet
## never executes. Convert a ricochet card into at most two small, visible,
## non-recursive blast transfers rather than additional full rockets.
static func explosive_ricochet(g, s: Dictionary, impact: Vector2) -> void:
	if int(s.get("rico", 0)) <= 0 or int(s["gen"]) >= Effects.max_gen(g):
		return
	var seen: Dictionary = s["hit"].duplicate()
	var current: Vector2 = impact
	for hop in range(mini(2, int(s["rico"]))):
		var next_target = null
		var best = 210.0 * 210.0
		for candidate in query(g, current, 210.0):
			if bool(candidate["dead"]) or seen.has(candidate["id"]):
				continue
			var dist = current.distance_squared_to(candidate["pos"])
			if dist < best:
				best = dist
				next_target = candidate
		if next_target == null:
			break
		seen[next_target["id"]] = true
		var endpoint: Vector2 = next_target["pos"]
		g.beams.append({"a": current, "b": endpoint, "t": 0.15, "w": 3.0, "color": Color("ffbe7a")})
		var radius = clampf(float(s["blast"]) * 0.48, 30.0, 70.0)
		explode(g, endpoint, radius, float(s["dmg"]) * 0.30 * pow(0.7, hop), int(s["gen"]) + 1, Color("ffbe7a"))
		current = endpoint

static func expire(g, s: Dictionary) -> void:
	s["dead"] = true
	var kind = str(s["kind"])
	if bool(s["friendly"]) and kind not in ["disc", "boomerang"]:
		ProjectileVfx.expire(g, s["pos"], s["vel"], str(s.get("vfx_style", "kinetic")))
	if not s["friendly"]:
		return
	match kind:
		"grenade", "egg", "rocket", "chicken":
			var r = float(s["blast"]) if float(s["blast"]) > 0.0 else 60.0
			explode(g, s["pos"], r, float(s["dmg"]), int(s["gen"]), Color(s["color"]))
			if kind in ["rocket", "grenade"] and not s["flags"].has("return_aftershock"):
				explosive_ricochet(g, s, s["pos"])
			if kind == "rocket" and not s["flags"].has("return_aftershock"):
				WeaponSignatures.rocket_collapse(g, s, s["pos"])
			if s["flags"].has("bomblets") and not s["flags"].has("return_aftershock"):
				fragments(g, s["pos"], 4, float(s["dmg"]) * 0.45, "ring", Vector2.UP, int(s["gen"]) + 1, null, false, Color("b5ff6b"), "grenade")
		"bubble":
			pop_bubble(g, s["pos"], float(s["dmg"]), float(s["blast"]), int(s["gen"]), s["flags"].has("minibubbles"))
		"disc", "boomerang":
			catch(g, s)
		"flame":
			if s["flags"].has("dragon") and randf() < 0.12:
				g.add_zone("fire", s["pos"], 34.0, 2.0)

static func on_wall(g, s: Dictionary) -> void:
	ProjectileVfx.ricochet(g, s["pos"], s["vel"], str(s.get("vfx_style", "ricochet")))
	g.sfx.play_projectile("bounce", str(s.get("vfx_style", "ricochet")))
	var f = s["flags"]
	WeaponSignatures.wall_bounce(g, s)
	if f.has("bounce_dmg"):
		s["dmg"] = float(s["dmg"]) * (1.15 + minf(0.10, float(f.get("bank_bonus", 0.0)) * 0.4))
	var ws = int(g.st("wallsplit")) + int(f.get("wallsplit", 0))
	if ws > 0 and int(s["gen"]) < Effects.max_gen(g):
		fragments(g, s["pos"], ws, float(s["dmg"]) * 0.5, "forward", s["vel"].normalized(), int(s["gen"]) + 1, s, false, s["color"])
	if f.has("multiball") and g.shots.size() < g.shot_cap() - 400 and int(s["gen"]) < 2:
		var o = {"kind": s["kind"], "speed": s["speed"], "life": float(s["life"]), "r": s["r"], "bounce": 2, "gen": int(s["gen"]) + 1, "color": s["color"], "knock": s["knock"], "flags": {"bounce_dmg": true}}
		shot(g, s["pos"], s["vel"].normalized().rotated(randf_range(-0.6, 0.6)), float(s["dmg"]), o)
	if f.has("wall_split3") and not f.has("did_split"):
		f["did_split"] = true
		for a in [-0.5, 0.5]:
			var o2 = {"kind": "ball", "speed": s["speed"], "life": 1.2, "r": float(s["r"]) * 0.7, "pierce": 999, "gen": int(s["gen"]) + 1, "color": s["color"], "knock": s["knock"], "flags": {"fling": true, "did_split": true}}
			shot(g, s["pos"], s["vel"].normalized().rotated(a), float(s["dmg"]) * 0.7, o2)
	if str(s["kind"]) == "chicken":
		g.sfx.play("honk")

## Reusable weapon/barrel collision for hitscan beams, electric arcs and
## lingering fields. Bullets keep their own pierce and impact handling below.
## Any genuine weapon hit arms the normal 0.85 s fuse via update_barrels().
static func damage_barrels_segment(g, start: Vector2, stop: Vector2, width: float, damage: float) -> int:
	if damage <= 0.0 or g.barrels.is_empty():
		return 0
	var struck = 0
	for barrel in g.barrels:
		if float(barrel["hp"]) <= 0.0 or bool(barrel.get("armed", false)) or float(barrel["drop"]) > 0.0:
			continue
		var radius = 20.0 + maxf(0.0, width)
		if seg_dist2(start, stop, barrel["pos"]) <= radius * radius:
			barrel["hp"] = maxf(0.0, float(barrel["hp"]) - damage)
			struck += 1
	return struck

static func collide_barrels(g, s: Dictionary) -> void:
	for b in g.barrels:
		if float(b["hp"]) <= 0.0 or bool(b.get("armed", false)) or float(b["drop"]) > 0.0:
			continue
		if seg_dist2(s["last"], s["pos"], b["pos"]) < pow(20.0 + float(s["r"]), 2):
			b["hp"] = float(b["hp"]) - float(s["dmg"])
			ProjectileVfx.impact(g, b["pos"], s["vel"], "heavy", 8.0)
			g.sfx.play_projectile("impact", "heavy", "", 0.58)
			if str(s["kind"]) not in ["disc", "boomerang", "ball", "flame", "car", "saw"]:
				if int(s["pierce"]) <= 0:
					s["dead"] = true
					return
				s["pierce"] = int(s["pierce"]) - 1

static func collide_enemies(g, s: Dictionary) -> void:
	var a: Vector2 = s["last"]
	var b: Vector2 = s["pos"]
	var mid = (a + b) * 0.5
	var reach = a.distance_to(b) * 0.5 + float(s["r"])
	var cands = query(g, mid, reach)
	if cands.is_empty():
		return
	var now = float(s["t"])
	for attempt in range(6):
		var best = null
		var best_t = INF
		for e in cands:
			if bool(e["dead"]):
				continue
			if float(e["charm"]) > 0.0:
				continue
			var hit_until = s["hit"].get(e["id"])
			if hit_until != null and now < float(hit_until):
				continue
			var rr = float(e["r"]) + float(s["r"])
			if seg_dist2(a, b, e["pos"]) <= rr * rr:
				var t = seg_t(a, b, e["pos"])
				if t < best_t:
					best_t = t
					best = e
		if best == null:
			return
		on_hit(g, s, best, a.lerp(b, best_t))
		if bool(s["dead"]):
			return

static func on_hit(g, s: Dictionary, e: Dictionary, impact: Vector2) -> void:
	var kind = str(s["kind"])
	var f = s["flags"]
	var repeat = kind in ["disc", "boomerang", "flame", "ball", "saw", "car"]
	s["hit"][e["id"]] = float(s["t"]) + (0.25 if repeat else 9999.0)
	if kind == "car":
		s["hit"][e["id"]] = float(s["t"]) + 9999.0
	var dir: Vector2 = s["vel"].normalized()
	var ctx = {"shot": s, "pos": impact, "gen": int(s["gen"]), "dir": dir, "knock": float(s["knock"]),
		"crit": float(s["crit"]), "src": s["src"], "st": s["st"], "pool": float(s["pool"])}
	if f.has("fling"):
		ctx["fling"] = true
	var crit = hit(g, e, float(s["dmg"]), ctx)
	WeaponSignatures.projectile_hit(g, s, e, impact)
	if crit:
		ProjectileVfx.critical(g, impact, dir, maxf(12.0, float(s["r"]) * 2.6))
	else:
		ProjectileVfx.impact(g, impact, dir, str(s.get("vfx_style", "kinetic")), maxf(5.0, float(s["r"]) * 1.5))
	match kind:
		"rocket":
			explode(g, impact, maxf(40.0, float(s["blast"])), float(s["dmg"]), int(s["gen"]), Color("ff8f6b"))
			explosive_ricochet(g, s, impact)
			WeaponSignatures.rocket_collapse(g, s, impact)
			if f.has("fire_puddle"):
				g.add_zone("fire", impact, 55.0, 3.0)
			if f.has("cluster"):
				fragments(g, impact, 4, float(s["dmg"]) * 0.4, "ring", dir, int(s["gen"]) + 1, null, false, Color("ffb07a"), "grenade")
			s["dead"] = true
			return
		"grenade", "egg":
			if f.has("sticky") and not f.has("stuck"):
				f["stuck"] = e
				s["life"] = minf(float(s["life"]), 0.5)
				return
			expire(g, s)
			return
		"bubble":
			var trapped = int(f.get("trapped", 0)) + 1
			f["trapped"] = trapped
			e["bubble"] = 1.6 * (1.0 + g.st("dur") + minf(0.25, float(f.get("trap_bonus", 0.0))))
			e["bubble_dmg"] = float(s["dmg"])
			e["bubble_r"] = maxf(45.0, float(s["blast"]))
			e["bubble_mini"] = f.has("minibubbles")
			e["bubble_chain"] = int(f.get("pressure_chain", 0))
			# Bubble traps have no ordinary ricochet phase. A ricochet card
			# creates one weaker linked trap instead of a phantom bubble shot.
			if int(s["rico"]) > 0 and not f.has("trap_ricochet_done"):
				for candidate in query(g, impact, 170.0):
					if bool(candidate["dead"]) or candidate == e or float(candidate.get("bubble", 0.0)) > 0.0:
						continue
					candidate["bubble"] = maxf(float(candidate["bubble"]), 0.9)
					candidate["bubble_dmg"] = float(s["dmg"]) * 0.40
					candidate["bubble_r"] = maxf(35.0, float(s["blast"]) * 0.6)
					candidate["bubble_mini"] = false
					candidate["bubble_chain"] = 0
					f["trap_ricochet_done"] = true
					g.beams.append({"a": impact, "b": candidate["pos"], "t": 0.15, "w": 3.0, "color": Color("9fe8ff")})
					break
			if trapped >= int(f.get("trap", 1)):
				s["dead"] = true
			return
		"chicken":
			if f.has("eggs"):
				var o = {"kind": "egg", "speed": 160.0, "life": 0.8, "r": 6.0, "blast": 55.0, "gen": int(s["gen"]) + 1, "color": Color("fff8e0")}
				shot(g, impact, -dir, float(s["dmg"]) * 0.6, o)
			if randf() < 0.3:
				g.sfx.play("honk")
		"bolt":
			if f.has("split_first") and not f.has("did_split"):
				f["did_split"] = true
				# Each root Hydra bolt owns at most eight children, even with
				# stacked split modifiers. Children cannot split again.
				var nsplit = mini(8, int(f["split_first"]))
				for k in range(nsplit):
					var ang = (float(k) - float(nsplit - 1) * 0.5) * 0.35
					var o2 = {"kind": "frag", "speed": float(s["speed"]) * 0.8, "life": 0.5, "r": 3.5, "gen": int(s["gen"]) + 1,
						"color": s["color"], "knock": 50.0, "frag": true, "src": str(s.get("src", "splitbow")),
						"homing": 5.0 if f.has("frag_home") else 0.0}
					if f.has("hydra_seek"):
						o2["homing"] = 6.0
						o2["flags"] = {"hydra_seek": true}
					var fs = shot(g, impact, dir.rotated(ang), float(s["dmg"]) * 0.5, o2)
					if fs != null:
						fs["hit"][e["id"]] = 9999.0
		"bullet":
			if f.has("pin") and randf() < float(f["pin"]):
				e["pinned"] = 0.7
				e["stun"] = maxf(float(e["stun"]), 0.5)
	if float(s["blast"]) > 0.0 and kind in ["bullet", "spin", "pellet", "frag"]:
		explode(g, impact, float(s["blast"]), float(s["dmg"]) * 0.8, int(s["gen"]) + 1, Color("ffb07a"))
	# Splitting: fragments carry this projectile's payload.
	var split = int(s["split"])
	if split > 0 and int(s["gen"]) < Effects.max_gen(g) and g.shots.size() < g.shot_cap() - 200:
		var frag_dmg = float(s["dmg"]) * (0.4 + g.st("fragdmg"))
		fragments(g, impact, split, frag_dmg, "forward", dir, int(s["gen"]) + 1, s, false, s["color"])
		if not bool(s["frag"]):
			s["split"] = maxi(0, split - 1) if kind in ["disc", "boomerang", "ball"] else split
	if crit and f.has("critpierce"):
		return
	# Ricochet: redirect to the next enemy.
	if int(s["rico"]) > 0:
		var nxt = null
		var best = 240.0 * 240.0
		for o in query(g, impact, 240.0):
			if bool(o["dead"]) or o == e or s["hit"].has(o["id"]) or float(o["charm"]) > 0.0:
				continue
			var dd = impact.distance_squared_to(o["pos"])
			if dd < best:
				best = dd
				nxt = o
		if nxt != null:
			s["rico"] = int(s["rico"]) - 1
			s["vel"] = (nxt["pos"] - impact).normalized() * maxf(float(s["speed"]), s["vel"].length())
			s["pos"] = impact
			ProjectileVfx.ricochet(g, impact, s["vel"], str(s.get("vfx_style", "ricochet")))
			g.sfx.play_projectile("bounce", str(s.get("vfx_style", "ricochet")))
			if kind == "coin":
				s["dmg"] = float(s["dmg"]) * 1.25
				g.sfx.play("ping")
			if kind != "chicken":
				return
			return
		if kind == "chicken":
			expire(g, s)
			return
	if repeat or kind in ["coin"] and int(s["rico"]) > 0:
		return
	if int(s["pierce"]) > 0:
		ProjectileVfx.pierce(g, impact, dir, str(s.get("vfx_style", "pierce")))
		g.sfx.play_projectile("pierce", str(s.get("vfx_style", "pierce")))
		s["pierce"] = int(s["pierce"]) - 1
		return
	if kind == "chicken":
		expire(g, s)
		return
	s["dead"] = true

static func collide_hero(g, s: Dictionary) -> void:
	if g.hero.is_empty():
		return
	var hr = 11.0 * (0.6 if g.st("tiny") > 0 else 1.0)
	var rr = hr + float(s["r"])
	if seg_dist2(s["last"], s["pos"], g.hero["pos"]) > rr * rr:
		return
	if float(g.hero["dash_window"]) > 0.0 or float(g.hero["iframe"]) > 0.0:
		if float(g.hero["dash_window"]) > 0.0:
			g.perfect_dodge()
		return
	if randf() < g.st("reflect"):
		s["friendly"] = true
		s["vel"] = -s["vel"] * 1.3
		s["dmg"] = float(s["dmg"]) * 2.0
		s["color"] = Color("8ff8ff")
		s["vfx_style"] = "shock"
		s["hit"] = {}
		s["homing"] = 0.0
		s["gen"] = 1
		g.say(g.hero["pos"] + Vector2(0, -30), "NOPE", Color("8ff8ff"), 20)
		return
	if g.hurt(float(s["dmg"]), s["pos"], str(s["src"]) if str(s["src"]) != "" else "a stray bullet"):
		s["dead"] = true

# ================================================================= hitting
static func hit(g, e: Dictionary, dmg: float, ctx: Dictionary) -> bool:
	if bool(e["dead"]):
		return false
	var dir: Vector2 = ctx.get("dir", Vector2.ZERO)
	var aoe = bool(ctx.get("aoe", false))
	var gen = int(ctx.get("gen", 0))
	if has_role(g, e, "riot") and g.st("ap") <= 0.0 and dir != Vector2.ZERO and not aoe and float(e["stun"]) <= 0.0:
		if dir.dot(e["aim"]) < -0.35:
			dmg *= 0.15
			if randf() < 0.15:
				g.spawn_burst(ctx.get("pos", e["pos"]), Color("c8d8ff"), 3, 140.0, 3.0)
	# Situational bonuses are "+% damage": they join the attacker's additive pool instead of multiplying.
	var m = 1.0
	if float(e["mark"]) > 0.0:
		m += 0.25 + g.st("markpow")
	if float(e["chill"]) > 0.0 or float(e["frozen"]) > 0.0:
		m += g.st("chilldmg")
		if float(e["burn"]) > 0.0:
			m += g.st("thermal")
	if bool(e["boss"]) or bool(e["elite"]):
		m += g.st("boss")
	if float(e["pinned"]) > 0.0:
		var sh = ctx.get("shot")
		if sh != null and sh["flags"].has("pin_bonus"):
			m += 0.6
	var dist = e["pos"].distance_to(g.hero["pos"])
	if dist < 160.0:
		m += g.st("closedmg")
	elif dist > 350.0:
		m += g.st("fardmg")
	var shot_ref = ctx.get("shot")
	if shot_ref != null and shot_ref["flags"].has("full_bonus") and float(e["hp"]) >= float(e["max_hp"]) * 0.99:
		m += 1.0
	var crit = false
	if gen <= 1:
		var chance = 0.05 + g.st("crit") + float(ctx.get("crit", 0.0))
		crit = randf() < chance
	var pool = float(ctx.get("pool", 0.0))
	if pool <= 0.0:
		pool = g.dmg_pool()
	var amount = dmg * (1.0 + (m - 1.0) / pool)
	if crit:
		WeaponSignatures.critical_hit(g, e, ctx)
		var cm = 2.0 + g.st("critdmg")
		if str(ctx.get("src", "")) == "revolver":
			cm += 1.0
		amount *= cm
	damage(g, e, amount, crit, ctx)
	# Knockback (also what turns enemies into bowling balls).
	var knock = float(ctx.get("knock", 0.0))
	if knock > 0.0 and dir != Vector2.ZERO:
		var kb_mul = (1.0 + g.st("knock")) / maxf(0.5, float(e["mass"]))
		if bool(e["boss"]):
			kb_mul *= 0.15
		if crit and g.st("homerun") > 0.0:
			kb_mul *= 3.0
			e["flung"] = 1.2
		e["kb"] += dir * knock * kb_mul
		if bool(ctx.get("fling", false)) or g.st("fling") > 0.0 and e["kb"].length() > 380.0:
			e["flung"] = 1.0
		if g.st("yeet") > 0.0 and e["kb"].length() > 520.0 and randf() < 0.12:
			g.say(e["pos"] + Vector2(0, -20), "YEET!", Color("ffe14d"), 22)
	if bool(e["dead"]):
		return crit
	# Status effects: weapon payload + card chances. Secondary hits roll at half chance.
	var payload: Dictionary = ctx.get("st", {})
	var k = 1.0 if gen == 0 and not aoe else 0.5
	for st_name in STATUSES:
		var chance2 = (g.st(st_name) + float(payload.get(st_name, 0.0))) * k
		if chance2 > 0.0 and randf() < chance2:
			apply_status(g, e, st_name, 1.0)
			if st_name in ["burn", "freeze", "shock", "poison"]:
				var effect_name = {"burn": "fire", "freeze": "frost", "shock": "shock", "poison": "toxic"}[st_name]
				ProjectileVfx.impact(g, ctx.get("pos", e["pos"]), dir, effect_name, 9.0)
				g.sfx.play_projectile("status", effect_name)
			if bool(e["dead"]):
				break
	if shot_ref != null and shot_ref["flags"].has("instafreeze"):
		apply_status(g, e, "freeze", 100.0)
	if not bool(ctx.get("noproc", false)):
		var pctx = {"pos": ctx.get("pos", e["pos"]), "enemy": e, "dmg": amount, "gen": gen, "dir": dir, "shot": shot_ref}
		Effects.trigger(g, "hit", pctx)
		if crit:
			Effects.trigger(g, "crit", pctx)
	return crit

## Return the live shielding totem (or {} when none). Cached totems are
## rebuilt per simulation step and updated on spawn/death/sector transitions.
## Charmed totems no longer protect hostile enemies.
static func protecting_totem(g, e: Dictionary) -> Dictionary:
	if bool(e.get("dead", false)) or has_role(g, e, "totem"):
		return {}
	if g.totems.is_empty():
		return {}
	var at: Vector2 = e["pos"]
	for source in g.totems:
		if bool(source.get("dead", false)) or float(source.get("charm", 0.0)) > 0.0:
			continue
		if source["pos"].distance_squared_to(at) <= TOTEM_R * TOTEM_R:
			return source
	return {}

## Hype Totem support must apply to bullets, explosion transfers and all
## burn/poison/bleed ticks. Shield visuals are rate-limited for dense waves.
static func totem_protected_damage(g, e: Dictionary, amount: float) -> float:
	if amount <= 0.0:
		return amount
	if protecting_totem(g, e).is_empty():
		return amount
	if g.run_time >= float(e.get("shield_fx_next", 0.0)):
		e["shield_fx_next"] = g.run_time + 0.8
		e["shield_flash_t"] = 0.22
		# A restrained local feedback spark; never one per projectile/tick.
		g.spawn_burst(e["pos"], Color("79d7ff"), 2, 90.0, 2.2)
	return amount * 0.5

static func damage(g, e: Dictionary, amount: float, crit: bool, ctx: Dictionary) -> void:
	if bool(e["dead"]) or float(e.get("rebirth_t", 0.0)) > 0.0:
		return
	# Armored elites shrug off 40%. A nearby Hype Totem halves incoming
	# damage; the SAME helper protects against DOT, never just direct bullets.
	if e.has("affix") and e["affix"].has("ARMORED"):
		amount *= 0.6
	amount = totem_protected_damage(g, e, amount)
	e["hp"] = float(e["hp"]) - amount
	# Mirror Mimic copies one incoming weapon shot as a delayed, dodgeable countershot.
	# It still takes the full hit; there is no instant damage reflection.
	var mirror_state: Dictionary = e.get("mix_state_mirror", e)
	if has_role(g, e, "mirror") and float(e["hp"]) > 0.0 and ctx.get("shot") != null and float(mirror_state.get("cd", 0.0)) <= 0.0 and float(mirror_state.get("wind", 0.0)) <= 0.0 and float(e["charm"]) <= 0.0:
		# The mimic reacts to pressure quickly, but its counterfire is fully
		# warned and cannot deflect the incoming damage itself.
		e["wind"] = 0.70
		e["cd"] = 2.9
		e["lock"] = g.hero["pos"] + g.hero["vel"] * 0.25
		e["mirror_shots"] = mini(4, maxi(2, int(ctx["shot"].get("split", 0)) + 2))
		if str(e["kind"]).begins_with("mix_"):
			mirror_state["wind"] = e["wind"]
			mirror_state["cd"] = e["cd"]
			mirror_state["lock"] = e["lock"]
			e["mix_state_mirror"] = mirror_state
		g.spawn_ring_fx(e["pos"], Color("82e9ef"), 30.0)
	e["flash"] = 0.09
	e["squash"] = maxf(float(e["squash"]), 0.25 if crit else 0.14)
	g.damage_dealt += amount
	# Pool small hits into one number per enemy every 0.2s so the screen stays readable.
	e["numacc"] = float(e.get("numacc", 0.0)) + amount
	if crit or g.run_time >= float(e.get("num_t", 0.0)) or float(e["hp"]) <= 0.0:
		g.number(e["pos"] + Vector2(0, -float(e["r"])), float(e["numacc"]), crit)
		e["numacc"] = 0.0
		e["num_t"] = g.run_time + 0.2
	if crit:
		g.spawn_burst(e["pos"], Color("ffe14d"), 4, 220.0, 3.0)
		g.sfx.play_projectile("crit")
	else:
		var context_shot = ctx.get("shot")
		if context_shot != null:
			g.sfx.play_projectile("impact", str(context_shot.get("vfx_style", "kinetic")))
		elif str(ctx.get("src", "")) in ["laser", "tesla", "rail"]:
			var beam_style = "shock" if str(ctx.get("src", "")) == "tesla" else "pierce"
			g.sfx.play_projectile("impact", beam_style, "", 0.5)
		else:
			g.sfx.play("hit")
	var ex = g.st("execute")
	if ex > 0.0 and not bool(e["boss"]) and float(e["hp"]) > 0.0 and float(e["hp"]) < float(e["max_hp"]) * ex:
		e["hp"] = 0.0
		if randf() < 0.3:
			g.say(e["pos"] + Vector2(0, -24), "EXECUTED", Color("ff5a6a"), 18)
	if float(e["hp"]) <= 0.0:
		kill(g, e, ctx, -float(e["hp"]))

## Damage-over-time scales with the player's damage build and the target's durability.
## Percent-of-HP contribution keeps statuses relevant in Endless; bosses receive 25%.
## This is damage per 0.25-second status tick, not damage per second.
static func status_tick_damage(g, e: Dictionary, kind: String, stacks: float = 1.0, moving: bool = false) -> float:
	var base = 0.0
	var hp_ratio = 0.0
	var bonus = 1.0
	match kind:
		"burn":
			base = 1.6
			hp_ratio = 0.0008
			bonus = maxf(0.0, 1.0 + g.st("burnpow"))
		"poison":
			base = 0.45 * stacks
			hp_ratio = 0.00022 * stacks
			bonus = maxf(0.0, 1.0 + g.st("poisonpow"))
		"bleed":
			var movement = 2.0 if moving else 1.0
			base = 0.55 * stacks * movement
			hp_ratio = 0.00025 * stacks * movement
			bonus = maxf(0.0, 1.0 + g.st("bleedpow"))
		"shock":
			base = 4.0
			hp_ratio = 0.0005
			bonus = maxf(0.0, 1.0 + g.st("shockpow"))
		_:
			return 0.0
	var flat = base * g.sector_scale() * g.dmg_mult()
	var durability = maxf(0.0, float(e.get("max_hp", 0.0))) * hp_ratio
	if bool(e.get("boss", false)):
		durability *= 0.25
	return maxf(0.0, (flat + durability) * bonus)

static func dot(g, e: Dictionary, amount: float, color: Color, label: String = "") -> void:
	if bool(e["dead"]):
		return
	# DOT formerly bypassed Hype Totem's shield entirely. Use the exact
	# mitigation path shared with direct damage and report actual HP loss.
	amount = totem_protected_damage(g, e, amount)
	e["hp"] = float(e["hp"]) - amount
	g.damage_dealt += amount
	if label != "" and bool(g.settings.get("numbers", true)):
		# Aggregate four DOT ticks/sec into legible 0.5-second damage numbers.
		# This avoids a floating-text node per status per simulation tick.
		var key = "dot_acc_" + label
		var timer = "dot_at_" + label
		e[key] = float(e.get(key, 0.0)) + amount
		if g.run_time >= float(e.get(timer, 0.0)) or float(e["hp"]) <= 0.0:
			g.dot_number(e["pos"], float(e[key]), color, label)
			e[key] = 0.0
			e[timer] = g.run_time + 0.5
	if float(e["hp"]) <= 0.0:
		kill(g, e, {"gen": 1, "pos": e["pos"]}, 0.0)

static func kill(g, e: Dictionary, ctx: Dictionary, overkill: float) -> void:
	if bool(e["dead"]):
		return
	# Zombie-phoenix: one clearly telegraphed rebirth, with no first-death loot
	# or kill-count credit. It cannot resurrect a second time.
	if has_role(g, e, "ashwing") and not bool(e.get("reborn", false)):
		e["reborn"] = true
		e["rebirth_t"] = 1.35
		e["hp"] = maxf(1.0, float(e["max_hp"]) * 0.42)
		e["wind"] = 0.0
		e["charge"] = 0.0
		e["kb"] = Vector2.ZERO
		e["vel"] = Vector2.ZERO
		g.say(e["pos"] + Vector2(0, -float(e["r"]) - 15.0), "REBIRTH!", Color("ffae61"), 20)
		g.spawn_ring_fx(e["pos"], Color("ffae61"), 48.0)
		g.sfx.play("whoosh")
		return
	e["dead"] = true
	var pos: Vector2 = e["pos"]
	var gen = int(ctx.get("gen", 0))
	g.kills += 1
	g.note_mob(str(e["kind"]))
	if e.has("budget"):
		g.sector_kills += 1
	g.combo += 1
	g.combo_t = 2.6
	g.best_combo = maxi(g.best_combo, g.combo)
	var kind = str(e["kind"])
	# Loot
	var xp_value = int(e["xp"]) * (5 if bool(e["elite"]) else 1)
	if e.has("affix"):
		if e["affix"].has("VOLATILE"):
			g.delayed.append({"t": 0.9, "life": 0.9, "fn": "elite_boom", "pos": pos, "tele": 120.0, "dmg": float(e["dmg"]) * 1.5})
		if e["affix"].has("SPLITTER") and g.enemies.size() < g.MAX_ENEMIES:
			for k in range(3):
				var m = g.spawn_enemy("mini", pos + Vector2.from_angle(k * TAU / 3.0) * 20.0, false, false)
				m["kb"] = Vector2.from_angle(k * TAU / 3.0) * 260.0
				m["summon"] = true
	if e.has("summon"):
		pass  # boss / Mama minions: no loot, so stalling a fight never pays
	elif bool(e["boss"]):
		for i in range(12):
			g.spawn_pickup("xp", pos, maxi(1, int(e["xp"]) / 6))
		for i in range(8):
			g.spawn_pickup("gold", pos, 2)
		g.spawn_pickup("chest", pos, 1)
	else:
		g.spawn_pickup("xp", pos, xp_value)
		if randf() < 0.14:
			g.spawn_pickup("gold", pos, 1)
		if bool(e["elite"]):
			for i in range(4):
				g.spawn_pickup("gold", pos, 1)
			var chest_chance = 0.012 if g.hard_mode else 0.02
			if g.sector_elite_chests < 1 and randf() < chest_chance:
				g.sector_elite_chests += 1
				g.spawn_pickup("chest", pos, 1)
		if kind == "goblin":
			for i in range(12):
				g.spawn_pickup("gold", pos, 1)
			g.say(pos + Vector2(0, -30), "CHA-CHING!", Color("ffd24d"), 26)
		if kind == "nurse":
			if randf() < (0.75 if g.hard_mode else 0.90):
				g.spawn_pickup("heart", pos, 1)
		elif randf() < (0.0025 if g.hard_mode else 0.004) + g.st("heartdrop"):
			g.spawn_pickup("heart", pos, 1)
	if g.st("lifesteal") > 0.0:
		g.hero["hp"] = minf(float(g.hero["maxhp"]), float(g.hero["hp"]) + g.st("lifesteal"))
	# Juice
	g.spawn_burst(pos, e["color"], 7 if not bool(e["boss"]) else 40, 240.0, 4.5)
	g.fx.append({"kind": "splat", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 3.0, "color": e["color"], "size": float(e["r"]) * 1.2, "rot": randf() * TAU})
	g.sfx.play("pop")
	# Kind-specific deaths
	match "mitosis" if has_role(g, e, "mitosis") else kind:
		"mitosis":
			for k in range(2):
				var m = g.spawn_enemy("mini", pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)), false, false)
				m["kb"] = Vector2.from_angle(randf() * TAU) * 220.0
		"kaboomba":
			# Keep a visible, armed body after death instead of vanishing or exploding instantly.
			g.delayed.append(kaboomba_fuse(pos, float(e["dmg"])))
		"kingblob":
			if int(e["gen"]) < 2:
				for k in range(2):
					var kb = g.spawn_enemy("kingblob", pos + Vector2(-30 + 60 * k, 0), true)
					kb["gen"] = int(e["gen"]) + 1
					kb["hp"] = float(e["max_hp"]) * 0.4
					kb["max_hp"] = kb["hp"]
					kb["r"] = float(e["r"]) * 0.7
					kb["kb"] = Vector2(-300 + 600 * k, -100)
				g.say(pos, "SPLIT!", Color("ff7b93"), 30)
	if bool(e["boss"]) and not g.boss_alive():
		g.slowmo_t = 0.8
		g.add_shake(18.0)
		g.flash_screen(Color.WHITE, 0.35)
		g.banner("BOSS DOWN", "", 2.2)
		explode(g, pos, 160.0, 0.0, 9, Color("ffd24d"))
	if bool(e["elite"]):
		g.add_shake(6.0)
	# Reactions on death
	var mg = Effects.max_gen(g)
	if gen < mg:
		if float(e["burn"]) > 0.0:
			if g.st("wildfire") > 0.0:
				for o in query(g, pos, 95.0):
					if not bool(o["dead"]) and o["pos"].distance_to(pos) < 95.0:
						apply_status(g, o, "burn", 1.0)
				g.spawn_ring_fx(pos, Color("ff8a3d"), 95.0)
			WeaponSignatures.flame_death(g, e, pos)
		if float(e["poison"]) > 0.0 and g.st("plague") > 0.0:
			var z = g.add_zone("poison", pos, 70.0, 3.0)
			z["gen"] = gen + 1
		if (float(e["frozen"]) > 0.0 or float(e["chill"]) >= 50.0):
			if g.st("shatter") > 0.0:
				fragments(g, pos, 6, 10.0 * g.dmg_mult() * g.sector_scale(), "ring", Vector2.UP, gen + 1, null, false, Color("c8f4ff"))
			var sh = ctx.get("shot")
			if sh != null and sh["flags"].has("shatter_aoe"):
				explode(g, pos, 70.0, float(sh["dmg"]), gen + 1, Color("c8f4ff"))
		if float(e["charm"]) > 0.0 and g.st("brainwash") > 0.0:
			explode(g, pos, 80.0, 30.0 * g.dmg_mult() * g.sector_scale(), gen + 1, Color("ff8ad8"))
		if g.st("splitkill") > 0.0 and g.shots.size() < g.shot_cap() - 250:
			fragments(g, pos, int(g.st("splitkill")), 9.0 * g.dmg_mult() * g.sector_scale() * (1.0 + g.st("fragdmg")), "ring", Vector2.UP, gen + 1, ctx.get("shot"), false, Color("fff1a8"))
		var shot_ref = ctx.get("shot")
		if shot_ref != null:
			if shot_ref["flags"].has("killshot"):
				var nxt = g.nearest_enemy(pos, 500.0, e)
				if nxt != null:
					shot(g, pos, (nxt["pos"] - pos).normalized(), float(shot_ref["base_dmg"]), {"kind": "bullet", "speed": 1800.0, "life": 0.5, "r": 4.0, "pierce": 2, "gen": gen + 1, "color": Color("d8b8ff"), "knock": 120.0})
	if g.st("overkill") > 0.0 and overkill > 1.0:
		var o2 = g.nearest_enemy(pos, 220.0, e)
		if o2 != null:
			g.beams.append({"a": pos, "b": o2["pos"], "t": 0.12, "w": 3.0, "color": Color("ff9de0")})
			damage(g, o2, overkill, false, {"gen": gen + 1, "pos": o2["pos"]})
	Effects.trigger(g, "kill", {"pos": pos, "enemy": e, "gen": gen, "dmg": float(e["max_hp"]), "shot": ctx.get("shot"), "dir": ctx.get("dir", Vector2.UP)})

## One armed Kaboomba corpse per real death. Kills/loot are awarded immediately;
## this explosion resolves 0.8s later so the player can react and dodge.
static func kaboomba_fuse(pos: Vector2, damage: float) -> Dictionary:
	return {"fn": "kaboomba_boom", "pos": pos, "t": 0.8, "life": 0.8, "tele": 85.0, "dmg": damage}

## A forward-only melee sweep; enemy radius softens the angle and reach.
static func bash_in_arc(origin: Vector2, forward: Vector2, target: Vector2, radius: float) -> bool:
	var delta = target - origin
	var dist = delta.length()
	if dist > 90.0 + radius:
		return false
	if dist <= radius + 16.0:
		return true
	if forward.length_squared() < 0.001:
		return false
	return forward.normalized().dot(delta / dist) >= cos(deg_to_rad(72.0))

static func kaboom(g, pos: Vector2, r: float, dmg: float) -> void:
	# Kaboombas hurt you AND their friends. Lure them in.
	explode(g, pos, r, dmg * 2.0, 1, Color("ff5a4a"))
	if g.hero["pos"].distance_to(pos) < r + 10.0:
		g.hurt(dmg, pos, "a Kaboomba")

# ================================================================= statuses
static func apply_status(g, e: Dictionary, s: String, amt: float) -> void:
	if bool(e["dead"]):
		return
	var dur = 1.0 + g.st("dur")
	var ss = g.sector_scale()
	match s:
		"burn":
			e["burn"] = maxf(float(e["burn"]), 3.0 * dur)
			if (float(e["chill"]) > 0.0 or float(e["frozen"]) > 0.0) and g.st("steam") > 0.0:
				e["chill"] = 0.0
				e["frozen"] = 0.0
				explode(g, e["pos"], 75.0, 26.0 * ss * g.dmg_mult(), 2, Color("eef6ff"))
				g.say(e["pos"] + Vector2(0, -26), "STEAM!", Color("eef6ff"), 20)
			if float(e["shock"]) > 0.0 and g.st("overload") > 0.0:
				e["shock"] = 0.0
				explode(g, e["pos"], 80.0, 30.0 * ss * g.dmg_mult(), 2, Color("c58cff"))
				g.say(e["pos"] + Vector2(0, -26), "OVERLOAD!", Color("c58cff"), 20)
		"freeze":
			var add = amt if amt > 1.0 else 34.0 * (1.0 + g.st("freezepow"))
			if float(e["wet"]) > 0.0:
				add *= 2.0
			if bool(e["boss"]):
				add *= 0.3
			e["chill"] = float(e["chill"]) + add
			if float(e["chill"]) >= 100.0:
				e["chill"] = 0.0
				e["frozen"] = (0.6 if bool(e["boss"]) else 1.6) * dur
				if randf() < 0.3:
					g.say(e["pos"] + Vector2(0, -24), "FROZEN", Color("9fe8ff"), 16)
			if float(e["burn"]) > 0.0 and g.st("steam") > 0.0:
				apply_status(g, e, "burn", 1.0)
		"shock":
			e["shock"] = 3.0 * dur
			if float(e["wet"]) > 0.0 and g.st("conduct") > 0.0 and not e.has("conducting"):
				e["conducting"] = true
				for o in query(g, e["pos"], 260.0):
					if o != e and not bool(o["dead"]) and float(o["wet"]) > 0.0 and o["pos"].distance_to(e["pos"]) < 260.0:
						g.beams.append({"a": e["pos"], "b": o["pos"], "t": 0.12, "w": 3.0, "color": Color("9fd0ff"), "zig": true})
						damage(g, o, status_tick_damage(g, o, "shock") * 6.0, false, {"gen": 2, "pos": o["pos"]})
				e.erase("conducting")
			if float(e["burn"]) > 0.0 and g.st("overload") > 0.0:
				apply_status(g, e, "burn", 1.0)
		"poison":
			e["poison"] = minf(30.0, float(e["poison"]) + 1.0)
			e["poison_t"] = 4.0 * dur
		"bleed":
			e["bleed"] = minf(10.0, float(e["bleed"]) + 1.0)
			e["bleed_t"] = 4.0 * dur
			if g.st("hemorrhage") > 0.0 and float(e["bleed"]) >= 5.0:
				var burst = 9.0 * ss * float(e["bleed"]) * (1.0 + g.st("bleedpow"))
				e["bleed"] = 0.0
				g.spawn_burst(e["pos"], Color("ff4d6a"), 10, 200.0)
				g.say(e["pos"] + Vector2(0, -26), "HEMORRHAGE", Color("ff4d6a"), 18)
				damage(g, e, burst, false, {"gen": 2, "pos": e["pos"]})
		"slow":
			e["slow"] = 2.5 * dur
		"stun":
			e["stun"] = maxf(float(e["stun"]), amt)
		"charm":
			if not bool(e["boss"]):
				e["charm"] = 5.0 * dur * (2.0 if g.st("brainwash") > 0.0 else 1.0)
				g.say(e["pos"] + Vector2(0, -24), "<3", Color("ff8ad8"), 22)
		"wet":
			e["wet"] = 4.0 * dur
		"mark":
			e["mark"] = 4.0 * dur

# ================================================================= enemies
static func has_role(g, e: Dictionary, role: String) -> bool:
	var kind = str(e["kind"])
	return kind == role or (kind.begins_with("mix_") and g.enemy_db[kind]["mix"].has(role))

static func update_enemies(g, dt: float) -> void:
	var hero_pos: Vector2 = g.hero["pos"]
	var hero_r = 11.0 * (0.6 if g.st("tiny") > 0 else 1.0)
	var ss = g.sector_scale()
	var decoy = null
	for p in g.pets:
		if p["kind"] == "decoy":
			decoy = p
	g.totems.clear()
	g.latched_ticks = 0
	for e in g.enemies:
		if has_role(g, e, "totem") and not bool(e["dead"]):
			g.totems.append(e)
		elif has_role(g, e, "tick") and bool(e.get("latched", false)):
			g.latched_ticks += 1
	var count = g.enemies.size()
	for idx in range(count):
		var e = g.enemies[idx]
		if bool(e["dead"]):
			continue
		e["t"] = float(e["t"]) + dt
		# A rebirthing Ashwing stays in the enemy roster so a room cannot clear
		# while its resurrection is pending; it is harmless and untargetable.
		if float(e.get("rebirth_t", 0.0)) > 0.0:
			e["rebirth_t"] = maxf(0.0, float(e["rebirth_t"]) - dt)
			e["vel"] = Vector2.ZERO
			e["kb"] = Vector2.ZERO
			if float(e["rebirth_t"]) <= 0.0:
				g.spawn_ring_fx(e["pos"], Color("ff9d59"), 52.0)
				g.sfx.play("whoosh")
			continue
		e["flash"] = maxf(0.0, float(e["flash"]) - dt)
		e["squash"] = maxf(0.0, float(e["squash"]) - dt * 1.5)
		e["spawn"] = minf(1.0, float(e["spawn"]) + dt * 3.0)
		# ---- statuses (ticks 4x per second)
		e["tick"] = float(e["tick"]) - dt
		if float(e["tick"]) <= 0.0:
			e["tick"] = 0.25
			if e.has("affix"):
				elite_tick(g, e)
			if float(e["burn"]) > 0.0:
				dot(g, e, status_tick_damage(g, e, "burn"), Color("ff8a3d"), "BURN")
			if float(e["poison"]) > 0.0:
				dot(g, e, status_tick_damage(g, e, "poison", float(e["poison"])), Color("8dff6b"), "POISON")
			if float(e["bleed"]) > 0.0:
				var moving = e["vel"].length() > 10.0
				dot(g, e, status_tick_damage(g, e, "bleed", float(e["bleed"]), moving), Color("ff4d6a"))
			if float(e["shock"]) > 0.0 and randf() < 0.5:
				var o = null
				for c in query(g, e["pos"], 120.0):
					if c != e and not bool(c["dead"]) and c["pos"].distance_to(e["pos"]) < 120.0:
						o = c
						break
				if o != null:
					g.beams.append({"a": e["pos"], "b": o["pos"], "t": 0.08, "w": 2.0, "color": Color("9fd0ff"), "zig": true})
					dot(g, o, status_tick_damage(g, o, "shock"), Color("9fd0ff"))
			if bool(e["dead"]):
				continue
		# Status timers count down 10x a second (not every physics step): same durations, far less work.
		e["sdt"] = float(e["sdt"]) + dt
		if float(e["sdt"]) >= 0.1:
			var sdt = float(e["sdt"])
			e["sdt"] = 0.0
			for key in ["burn", "frozen", "shock", "slow", "stun", "charm", "wet", "mark", "pinned", "flung", "dance"]:
				if float(e.get(key, 0.0)) > 0.0:
					e[key] = maxf(0.0, float(e[key]) - sdt)
			e["chill"] = maxf(0.0, float(e["chill"]) - sdt * 14.0)
			if float(e["poison"]) > 0.0:
				e["poison_t"] = float(e.get("poison_t", 0.0)) - sdt
				if float(e["poison_t"]) <= 0.0:
					e["poison"] = 0.0
			if float(e["bleed"]) > 0.0:
				e["bleed_t"] = float(e.get("bleed_t", 0.0)) - sdt
				if float(e["bleed_t"]) <= 0.0:
					e["bleed"] = 0.0
		if float(e["bubble"]) > 0.0:
			e["bubble"] = float(e["bubble"]) - dt
			if float(e["bubble"]) <= 0.0:
				pop_bubble(g, e["pos"], float(e.get("bubble_dmg", 20.0)), float(e.get("bubble_r", 50.0)), 1, bool(e.get("bubble_mini", false)))
				WeaponSignatures.bubble_transfer(g, e)
		var disabled = float(e["frozen"]) > 0.0 or float(e["stun"]) > 0.0 or float(e["bubble"]) > 0.0 or float(e["pinned"]) > 0.0
		var speed_mul = 1.0
		# Siren pulse speeds up nearby ordinary mobs briefly, not bosses.
		if float(e.get("siren_haste", 0.0)) > 0.0:
			e["siren_haste"] = maxf(0.0, float(e["siren_haste"]) - dt)
			speed_mul *= 1.22
		if float(e["slow"]) > 0.0:
			speed_mul *= 0.55
		speed_mul *= 1.0 - minf(0.6, float(e["chill"]) / 100.0 * 0.6)
		# ---- targeting
		var charmed = float(e["charm"]) > 0.0
		var target_pos = hero_pos
		var target_enemy = null
		if charmed:
			target_enemy = g.nearest_enemy(e["pos"], 500.0, e)
			target_pos = target_enemy["pos"] if target_enemy != null else hero_pos + Vector2(0, -60)
		elif decoy != null and e["pos"].distance_to(decoy["pos"]) < 450.0:
			target_pos = decoy["pos"]
		var to_t: Vector2 = target_pos - e["pos"]
		var dist = to_t.length()
		var dir = to_t / dist if dist > 0.1 else Vector2.DOWN
		e["aim"] = e["aim"].lerp(dir, minf(1.0, dt * 6.0)).normalized()
		var desired = Vector2.ZERO
		if not disabled:
			desired = ai(g, e, dir, dist, dt, charmed)
		if bool(e["dead"]):
			continue
		e["vel"] = e["vel"].lerp(desired * float(e["speed"]) * speed_mul, 1.0 - exp(-8.0 * dt))
		if disabled:
			e["vel"] = Vector2.ZERO
		if float(e["charge"]) > 0.0 and not disabled:
			e["vel"] = e["cdir"] * 560.0
		var skitter_dashing = str(e["kind"]) == "skitter" and float(e["charge"]) > 0.0 and not disabled
		var before_dash_move: Vector2 = e["pos"]
		e["pos"] += (e["vel"] + e["kb"]) * dt
		var kb_len = e["kb"].length()
		e["kb"] = e["kb"] * exp(-5.5 * dt)
		# Road walls
		var p: Vector2 = e["pos"]
		if absf(p.x) > g.road_half - float(e["r"]):
			p.x = signf(p.x) * (g.road_half - float(e["r"]))
			if kb_len > 200.0:
				e["kb"].x = -e["kb"].x * 0.6
				if float(e["flung"]) > 0.0:
					damage(g, e, kb_len * 0.04 * ss, false, {"gen": 2, "pos": p})
			e["pos"] = p
		# Dense trees, medians and parked traffic block monsters as well.
		var before_obstacle_push: Vector2 = e["pos"]
		if not g.obstacles.is_empty():
			if skitter_dashing:
				# Sweep the dash to prevent tunneling through thin obstacles.
				e["pos"] = RoadObstacles.resolve_movement(before_dash_move, e["pos"], float(e["r"]), g.obstacles)
			else:
				e["pos"] = RoadObstacles.push_circle(e["pos"], float(e["r"]), g.obstacles)
		# Skitter flies past the player, stopping only on a solid obstacle or road edge.
		# The charge timer is a safety limit for long empty stretches, not a short lunge.
		if skitter_dashing and (absf(e["pos"].x) >= g.road_half - float(e["r"]) - 0.5 or e["pos"].distance_squared_to(before_obstacle_push) > 0.25):
			e["charge"] = 0.0
			e["vel"] = Vector2.ZERO
			e["wind"] = 0.0
		# Separation + bowling collisions
		var flung = float(e["flung"]) > 0.0 and kb_len > 260.0 or float(e["charge"]) > 0.0
		# Crowd separation runs for half the crowd each step (alternating); flung enemies always check.
		var neigh = query(g, e["pos"], float(e["r"]) + 30.0) if flung or (int(e["id"]) + g.sim_step) % 2 == 0 else []
		var checked = 0
		for o in neigh:
			if o == e or bool(o["dead"]):
				continue
			checked += 1
			if checked > 12:
				break
			var off: Vector2 = e["pos"] - o["pos"]
			var d2 = off.length_squared()
			var rr = float(e["r"]) + float(o["r"])
			if d2 < rr * rr and d2 > 0.01:
				var d = sqrt(d2)
				var push = off / d * (rr - d) * 0.5
				var me = float(e["mass"])
				var them = float(o["mass"])
				e["pos"] += push * (them / (me + them)) * 2.0
				o["pos"] -= push * (me / (me + them)) * 2.0
				if flung and not o.has("bonked_by") or flung and o.get("bonked_by") != e["id"]:
					o["bonked_by"] = e["id"]
					var force = maxf(kb_len, 400.0)
					o["kb"] += (o["pos"] - e["pos"]).normalized() * force * 0.8 / maxf(0.5, them)
					o["flung"] = 0.6 if g.st("fling") > 0.0 else 0.0
					var bonk = (12.0 + force * 0.03) * ss * g.dmg_mult()
					if float(e["charge"]) > 0.0:
						bonk *= 0.5
					damage(g, o, bonk, false, {"gen": 1, "pos": o["pos"]})
					if randf() < 0.18:
						g.say(o["pos"] + Vector2(0, -20), "BONK", Color("ffe14d"), 18)
						g.sfx.play("bonk")
		# Contact damage
		if charmed:
			if target_enemy != null and dist < float(e["r"]) + float(target_enemy["r"]) + 4.0:
				e["cd"] = float(e["cd"]) - dt
				if float(e["cd"]) <= 0.0:
					e["cd"] = 0.5
					damage(g, target_enemy, float(e["dmg"]) * 2.0 + 10.0 * ss, false, {"gen": 1, "pos": target_enemy["pos"]})
		elif not disabled and e["pos"].distance_to(hero_pos) < float(e["r"]) + hero_r and float(e["dmg"]) > 0.0:
			if e["kind"] == "kaboomba":
				# kill() must see a live enemy or it silently returns without a fuse.
				kill(g, e, {"gen": 1, "pos": e["pos"]}, 0.0)
				continue
			if has_role(g, e, "tick"):
				# Ticks latch on instead of bumping: they slow you and drain until you dash.
				if not bool(e.get("latched", false)):
					e["latched"] = true
					e["latch_off"] = (e["pos"] - hero_pos).limit_length(14.0)
					g.say(hero_pos + Vector2(0, -40), "TICKED! DASH!", Color("9dff6b"), 20)
				g.hurt(float(e["dmg"]), e["pos"], "a Lil Tick")
				continue
			var contact_hurt = g.hurt(float(e["dmg"]), e["pos"], "a " + str(g.enemy_db[e["kind"]]["name"]))
			if contact_hurt and has_role(g, e, "leech"):
				var stolen = minf(float(e["max_hp"]) * 0.12, float(e["dmg"]) * 1.5)
				e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + stolen)
				g.spawn_ring_fx(e["pos"], Color("a783ff"), 22.0)
			if contact_hurt and g.st("thorns") > 0.0:
				damage(g, e, g.st("thorns") * ss, false, {"gen": 1, "pos": e["pos"]})
			elif g.st("thorns") > 0.0 and float(e.get("thorn_cd", 0.0)) <= 0.0:
				e["thorn_cd"] = 0.5
				damage(g, e, g.st("thorns") * ss * 0.5, false, {"gen": 1, "pos": e["pos"]})
		if e.has("thorn_cd"):
			e["thorn_cd"] = float(e["thorn_cd"]) - dt
		if g.state != "playing":
			return
		# Despawn far stragglers so the road ahead stays fresh.
		if e["pos"].y > hero_pos.y + 900.0 and not bool(e["boss"]):
			e["dead"] = true
			if e.has("budget"):
				g.budget_spawned = maxi(0, g.budget_spawned - 1)

## Threat phases create new patterns, not inflated damage. Phase thresholds at 65% and 32%.
static func boss_stage(e: Dictionary) -> int:
	if not bool(e.get("boss", false)):
		return 0
	var ratio = float(e.get("hp", 0.0)) / maxf(1.0, float(e.get("max_hp", 1.0)))
	if ratio <= 0.32:
		return 2
	if ratio <= 0.65:
		return 1
	return 0

static func schedule_boss_blast(g, pos: Vector2, radius: float, damage: float, timer: float, color: String = "ff9944") -> void:
	g.delayed.append({"fn": "boss_blast", "pos": pos, "t": timer, "life": timer,
		"tele": radius, "dmg": damage, "color": color})
	g.sfx.play_projectile("boss_warn")

static func boss_ring(g, e: Dictionary, count: int, speed: float, offset: float = 0.0) -> void:
	for i in range(count):
		enemy_fire(g, e, Vector2.from_angle(offset + TAU * float(i) / count), 1, 0.0, speed)

## Line strikes are warned, fixed-in-world and dodgeable; never instantly
## follow a player after the telegraph starts.
static func schedule_boss_line(g, a: Vector2, b: Vector2, width: float, dmg: float, delay: float, color: String = "ff9944") -> void:
	if g.delayed.size() >= 145:
		return
	var t = maxf(0.48, delay)
	g.delayed.append({"fn": "boss_line", "pos": (a + b) * 0.5, "a": a, "b": b,
		"tele": width, "t": t, "life": t, "dmg": dmg, "color": color})

## Predict movement once when the attack is committed. Narrow sequential
## lines overlap lanes only partially, leaving a skill-based safe route.
static func boss_lane_sequence(g, e: Dictionary, target: Vector2, stage: int, horizontal: bool, color: String) -> void:
	var count = 3 + stage
	var spacing = 105.0 if horizontal else 120.0
	for k in range(count):
		var offset = (float(k) - (count - 1) * 0.5) * spacing
		var a: Vector2
		var b: Vector2
		if horizontal:
			a = Vector2(-g.road_half + 8.0, target.y + offset)
			b = Vector2(g.road_half - 8.0, target.y + offset)
		else:
			var x = clampf(target.x + offset, -g.road_half + 15.0, g.road_half - 15.0)
			a = Vector2(x, target.y - 330.0)
			b = Vector2(x, target.y + 330.0)
		schedule_boss_line(g, a, b, 22.0 + stage * 2.0, float(e["dmg"]) * 0.65, 0.92 + float(k) * 0.22, color)

## Radial attacks have a persistent player-sized opening: heavy bullet curtains
## should be difficult without becoming unavoidable at close distance.
static func boss_gapped_ring(g, e: Dictionary, count: int, speed: float, gap: float, offset: float = 0.0) -> void:
	var avoid = (g.hero["pos"] - e["pos"]).angle() + gap
	var half_gap = maxf(0.14, TAU / float(maxi(6, count)) * 1.2)
	for k in range(count):
		var ang = offset + TAU * float(k) / float(count)
		if absf(wrapf(ang - avoid, -PI, PI)) < half_gap:
			continue
		enemy_fire(g, e, Vector2.from_angle(ang), 1, 0.0, speed)

static func boss_cross(g, e: Dictionary, target: Vector2, stage: int, color: String) -> void:
	var span = 200.0 + 25.0 * stage
	for turn in [-1.0, 1.0]:
		schedule_boss_line(g, target + Vector2(-span, -span * turn),
			target + Vector2(span, span * turn), 20.0 + stage * 2.0,
			float(e["dmg"]) * 0.68, 1.05 if turn < 0 else 1.28, color)

## Authored mutations have one signature behavior instead of simply running
## the full A and B enemy brains together. Their body part is inherited for
## appearance, but the attack must remain legible, warned and bounded.
static func mutation_ai(g, e: Dictionary, dir: Vector2, dist: float, dt: float, charmed: bool) -> Vector2:
	var style = str(g.enemy_db[str(e["kind"])].get("fusion_style", ""))
	var target: Vector2 = g.hero["pos"]
	e["cd"] = float(e["cd"]) - dt
	if charmed:
		return dir
	var hard_factor = 0.80 if g.hard_mode else 1.0
	match style:
		"flank":
			if float(e.get("charge", 0.0)) > 0.0:
				e["charge"] = maxf(0.0, float(e["charge"]) - dt)
				return Vector2.ZERO
			if float(e.get("wind", 0.0)) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					e["charge"] = 0.24
					e["cdir"] = (e.get("lock", target) - e["pos"]).normalized()
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 500.0:
				e["cd"] = 3.9 * hard_factor
				e["wind"] = 0.69
				e["lock"] = target + g.hero["vel"] * 0.26
				return Vector2.ZERO
			return (dir * 0.72 + dir.orthogonal() * sin(float(e["t"]) * 3.6) * 0.75).normalized()
		"mine":
			if float(e["cd"]) <= 0.0 and dist < 650.0:
				e["cd"] = 3.65 * hard_factor
				if g.delayed.size() < 125:
					var impact = target + g.hero["vel"] * 0.32
					impact.x = clampf(impact.x, -g.road_half + 35.0, g.road_half - 35.0)
					schedule_boss_blast(g, impact, 49.0, float(e["dmg"]) * 0.83, 1.18, "f2ad6b")
			return (dir * 0.45 + dir.orthogonal() * sin(float(e["t"]) * 2.1) * 0.85).normalized()
		"echo":
			if float(e.get("wind", 0.0)) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					var aim = (e.get("lock", target) - e["pos"]).normalized()
					if aim.length_squared() < 0.05:
						aim = dir
					enemy_fire(g, e, aim, 3 if not g.hard_mode else 5,
						0.42 if not g.hard_mode else 0.68, 285.0, 5.2)
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 620.0:
				e["cd"] = 3.7 * hard_factor
				e["wind"] = 0.79
				e["lock"] = target + g.hero["vel"] * 0.30
				return Vector2.ZERO
			return dir * 0.68
		"brood":
			if float(e["cd"]) <= 0.0 and dist < 600.0:
				e["cd"] = 5.8 * hard_factor
				var count = 2 if g.hard_mode else 1
				for k in range(count):
					if g.enemies.size() >= g.enemy_cap():
						break
					var spawn_pos: Vector2 = e["pos"] + Vector2(40.0 if k == 0 else -40.0, 30.0)
					var child = g.spawn_enemy("mini", spawn_pos, false, false)
					child["summon"] = true
				g.spawn_ring_fx(e["pos"], Color("c58dff"), 56.0)
			return dir * 0.55
	return dir

static func ai(g, e: Dictionary, dir: Vector2, dist: float, dt: float, charmed: bool) -> Vector2:
	var kind = str(e["kind"])
	if kind.begins_with("mix_"):
		if str(g.enemy_db[kind].get("fusion_style", "")) != "":
			return mutation_ai(g, e, dir, dist, dt, charmed)
		# Legacy already-discovered cross-product hybrids keep their original
		# behavior for backward-compatible saves and Debug Lab.
		var pair: Array = g.enemy_db[kind]["mix"]
		var motion = Vector2.ZERO
		var shown_wind = 0.0
		var shown_lock: Vector2 = g.hero["pos"]
		for part in pair:
			var state_key = "mix_state_" + str(part)
			var state: Dictionary = e.get(state_key, {})
			if state.is_empty():
				e["cd"] = randf_range(0.5, 2.0)
				e["wind"] = 0.0
				e["charge"] = 0.0
			for key in ["cd", "wind", "charge", "cdir", "lock", "tele"]:
				if state.has(key):
					e[key] = state[key]
			e["kind"] = str(part)
			motion += ai(g, e, dir, dist, dt, charmed)
			state = {}
			for key in ["cd", "wind", "charge", "cdir", "lock", "tele"]:
				if e.has(key):
					state[key] = e[key]
			e[state_key] = state
			if float(e.get("wind", 0.0)) > shown_wind:
				shown_wind = float(e["wind"])
				shown_lock = e.get("lock", g.hero["pos"])
		e["kind"] = kind
		e["wind"] = shown_wind
		e["lock"] = shown_lock
		return (motion / float(pair.size())).normalized()
	e["cd"] = float(e["cd"]) - dt
	if charmed:
		return dir
	var hero_pos: Vector2 = g.hero["pos"]
	var ss = g.sector_scale()
	match kind:
		"skitter":
			# Nimble flank attacker: short wind-up, diagonal burst and a real dodge window.
			if float(e["charge"]) > 0.0:
				e["charge"] = maxf(0.0, float(e["charge"]) - dt)
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					# Lock direction once, then overshoot rather than tracking the player.
					e["charge"] = 2.5
					e["cdir"] = (e["lock"] - e["pos"]).normalized()
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist > 80.0 and dist < 300.0:
				e["cd"] = 3.2
				e["wind"] = 0.40
				e["lock"] = hero_pos
				return Vector2.ZERO
			return (dir * 0.7 + dir.orthogonal() * sin(float(e["t"]) * 7.0 + float(e["phase"])) * 0.95).normalized()
		"sapper":
			# Ranged ground denial, but every mine is telegraphed before dealing damage.
			if float(e["cd"]) <= 0.0 and dist < 460.0 and g.delayed.size() < 140:
				e["cd"] = 4.4
				var lead = hero_pos + g.hero["vel"] * 0.25
				schedule_boss_blast(g, lead, 46.0, float(e["dmg"]) * 1.25, 1.3, "ffbb61")
				e["squash"] = 0.4
			return dir if dist > 320.0 else (-dir if dist < 205.0 else dir.orthogonal() * 0.5)
		"lancer":
			# Long-range spear burst: stationary aiming tell and fast pierce shot.
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					var aim = (Vector2(e.get("lock", hero_pos)) - e["pos"]).normalized()
					var dart = enemy_fire(g, e, aim, 1, 0.0, 520.0, 4.0)
					if dart != null:
						dart["pierce"] = 1
						dart["life"] = 1.8
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 520.0:
				e["cd"] = 3.4
				e["wind"] = 0.68
				e["lock"] = hero_pos + g.hero["vel"] * 0.23
				return Vector2.ZERO
			return dir if dist > 360.0 else -dir * 0.45
		"leech":
			# Rush into melee; actual HP drain is resolved only on successful contact.
			return (dir * 0.85 + dir.orthogonal() * sin(float(e["t"]) * 4.0 + float(e["phase"])) * 0.24).normalized()
		"ashwing":
			# A twitchy chaser that must be killed twice, with a long visible pause.
			return (dir + dir.orthogonal() * sin(float(e["t"]) * 4.0 + float(e["phase"])) * 0.3).normalized()
		"mirror":
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					var locked: Vector2 = e.get("lock", hero_pos)
					var aim = (locked - e["pos"]).normalized()
					if aim.length_squared() < 0.1:
						aim = dir
					var volley = mini(4, int(e.get("mirror_shots", 3)))
					enemy_fire(g, e, aim, volley, 0.46, 385.0, 5.0)
					# A second diagonal salvo closes the obvious sideways dodge
					# but is slower, so players can weave between both.
					if g.sector >= 12:
						enemy_fire(g, e, aim.rotated(0.42 if int(e["id"]) % 2 == 0 else -0.42), 2, 0.2, 300.0, 4.5)
					g.sfx.play("whoosh")
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist < 500.0:
				e["cd"] = 3.5
				e["wind"] = 0.8
				e["mirror_shots"] = 3
				e["lock"] = hero_pos + g.hero["vel"] * 0.33
				return Vector2.ZERO
			return (dir * 0.5 + dir.orthogonal() * sin(float(e["t"]) * 3.8 + float(e["phase"])) * 0.95).normalized()
		"burrower":
			# Disappear into the ground and ambush predicted position with a
			# visible collapse warning. The aftershock has a safe dodge window.
			if float(e.get("emerge_t", 0.0)) > 0.0:
				e["emerge_t"] = maxf(0.0, float(e["emerge_t"]) - dt)
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					g.spawn_ring_fx(e["pos"], Color("c8a66e"), 24.0)
					e["pos"] = e.get("lock", e["pos"])
					e["kb"] = Vector2.ZERO
					e["vel"] = Vector2.ZERO
					e["emerge_t"] = 0.42
					g.spawn_ring_fx(e["pos"], Color("ffe2a3"), 56.0)
					# The collapse detonates after a visible ring: a teleport
					# itself is not an unannounced hit.
					schedule_boss_blast(g, e["pos"], 66.0, float(e["dmg"]) * 0.86, 0.53, "e7a75b")
					if g.sector >= 12:
						for side in [-1.0, 1.0]:
							var d = Vector2(side, -0.28).normalized()
							enemy_fire(g, e, d, 2, 0.18, 265.0, 4.0)
					g.sfx.play("thunk")
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0 and dist > 115.0 and dist < 610.0:
				e["cd"] = 3.6
				e["wind"] = 0.87
				var target = hero_pos + g.hero["vel"] * 0.32
				target += Vector2(randf_range(-36.0, 36.0), randf_range(-15.0, 15.0))
				target.x = clampf(target.x, -g.road_half + float(e["r"]) + 14.0, g.road_half - float(e["r"]) - 14.0)
				e["lock"] = target
				return Vector2.ZERO
			return dir * 1.15
		"siren":
			# Rally nearby ordinary mobs only. The pulse does not stack or buff bosses.
			if float(e["cd"]) <= 0.0:
				e["cd"] = 5.5
				var boosted = false
				for o in query(g, e["pos"], 180.0):
					if o != e and not bool(o["dead"]) and not bool(o["boss"]) and o["pos"].distance_to(e["pos"]) <= 180.0:
						o["siren_haste"] = maxf(float(o.get("siren_haste", 0.0)), 2.3)
						boosted = true
				if boosted:
					g.spawn_ring_fx(e["pos"], Color("f194da"), 180.0)
					e["squash"] = 0.55
					g.sfx.play("gate")
			return dir if dist > 280.0 else -dir * 0.45
		"zoomer", "mini":
			# From sector 7 zoomers wind up and lunge (telegraphed line).
			if kind == "zoomer" and g.sector >= 7:
				if float(e["charge"]) > 0.0:
					e["charge"] = float(e["charge"]) - dt
					return Vector2.ZERO
				if float(e["wind"]) > 0.0:
					e["wind"] = float(e["wind"]) - dt
					if float(e["wind"]) <= 0.0:
						e["charge"] = 0.32
						e["cdir"] = (hero_pos - e["pos"]).normalized()
					return Vector2.ZERO
				if e["cd"] <= 0.0 and dist < 230.0:
					e["cd"] = 3.0
					e["wind"] = 0.45
					return Vector2.ZERO
			return (dir + dir.orthogonal() * sin(float(e["t"]) * 5.0 + float(e["phase"])) * 0.7).normalized()
		"chonk":
			# From sector 4 chonks belly-slam when you get close.
			if g.sector >= 4:
				if float(e["wind"]) > 0.0:
					e["wind"] = float(e["wind"]) - dt
					if float(e["wind"]) <= 0.0:
						e.erase("tele")
						g.add_shake(7.0)
						g.spawn_ring_fx(e["pos"], Color("ff6b7a"), 115.0)
						if g.hero["pos"].distance_to(e["pos"]) < 115.0:
							g.hurt(float(e["dmg"]), e["pos"], "a Chonk belly flop")
					return Vector2.ZERO
				if e["cd"] <= 0.0 and dist < 130.0:
					e["cd"] = 3.2
					e["wind"] = 0.8
					e["tele"] = 115.0
					return Vector2.ZERO
			return dir
		"mortar":
			# Lobs shells where you are heading; the landing spot is marked first.
			if e["cd"] <= 0.0 and dist < 640.0:
				e["cd"] = maxf(1.6, 3.0 - 0.08 * float(maxi(0, g.sector - 5)))
				var at = hero_pos + g.hero["vel"] * 0.5
				var m_t = maxf(0.8, 1.15 - 0.02 * float(maxi(0, g.sector - 5)))
				g.delayed.append({"t": m_t, "life": m_t, "fn": "mortar", "pos": at, "tele": 72.0, "dmg": float(e["dmg"])})
				e["squash"] = 0.5
				g.sfx.play("thunk")
			if dist < 360.0:
				return -dir * 0.8
			return dir if dist > 470.0 else dir.orthogonal() * 0.4
		"totem":
			return Vector2.ZERO
		"blinky":
			# Shimmers in place, then teleports next to you (destination ring shown).
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					g.spawn_ring_fx(e["pos"], Color("c58cff"), 30.0)
					e["pos"] = e.get("lock", hero_pos)
					e["kb"] = Vector2.ZERO
					g.spawn_ring_fx(e["pos"], Color("c58cff"), 40.0)
					g.sfx.play("whoosh")
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 520.0 and dist > 140.0:
				e["cd"] = 3.6
				e["wind"] = 0.7
				e["lock"] = hero_pos + Vector2.from_angle(randf() * TAU) * 85.0
				return Vector2.ZERO
			return dir
		"tick":
			if bool(e.get("latched", false)):
				e["pos"] = hero_pos + e.get("latch_off", Vector2.ZERO)
				e["kb"] = Vector2.ZERO
				return Vector2.ZERO
			return dir
		"spitter":
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					# From sector 6 spitters fire a three-shot spread.
					if g.sector >= 6:
						enemy_fire(g, e, dir, 3, 0.5, 270.0)
					else:
						enemy_fire(g, e, dir, 1, 0.0, 270.0)
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 360.0:
				e["cd"] = 2.4 if g.sector < 6 else maxf(1.4, 2.4 - 0.06 * float(g.sector - 5))
				e["wind"] = maxf(0.2, 0.35 - 0.01 * float(maxi(0, g.sector - 5)))
			if dist < 220.0:
				return -dir * 0.6
			return dir if dist > 280.0 else dir.orthogonal() * 0.5
		"larry":
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) > 0.3:
					e["lock"] = hero_pos
				if float(e["wind"]) <= 0.0:
					larry_beam(g, e, (e.get("lock", hero_pos) - e["pos"]).normalized())
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 520.0:
				e["cd"] = 3.2
				e["wind"] = 1.0
				e["lock"] = hero_pos
			if dist < 330.0:
				return -dir * 0.7
			return dir if dist > 430.0 else Vector2.ZERO
		"bull":
			if float(e["charge"]) > 0.0:
				e["charge"] = float(e["charge"]) - dt
				return Vector2.ZERO
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					e["charge"] = 0.75
					e["cdir"] = (hero_pos - e["pos"]).normalized()
					g.sfx.play("whoosh")
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 330.0:
				e["cd"] = 3.5
				e["wind"] = 0.6
			return dir
		"nurse":
			if e["cd"] <= 0.0:
				e["cd"] = 2.5
				var healed = false
				for o in query(g, e["pos"], 170.0):
					if o != e and not bool(o["dead"]) and o["pos"].distance_to(e["pos"]) < 170.0 and float(o["hp"]) < float(o["max_hp"]):
						o["hp"] = minf(float(o["max_hp"]), float(o["hp"]) + float(o["max_hp"]) * 0.12)
						healed = true
				if healed:
					g.spawn_ring_fx(e["pos"], Color("7dff9a"), 170.0)
			return dir if dist > 260.0 else -dir * 0.4
		"mama":
			if e["cd"] <= 0.0 and g.enemies.size() < g.MAX_ENEMIES:
				e["cd"] = 4.0
				for k in range(2):
					var m = g.spawn_enemy("mini", e["pos"] + Vector2(randf_range(-20, 20), 10), false, false)
					m["kb"] = Vector2(randf_range(-200, 200), 160)
					m["summon"] = true
				e["squash"] = 0.5
			return dir
		"goblin":
			if float(e["t"]) > 12.0:
				e["dead"] = true
				g.say(e["pos"], "ESCAPED!", Color("ffd24d"), 22)
				return Vector2.ZERO
			var away = -dir
			if float(e["pos"].y) < g.cam_y - 300.0:
				away = (away + Vector2(0, 1)).normalized()
			return (away + away.orthogonal() * sin(float(e["t"]) * 3.0) * 0.6).normalized()
		"kaboomba":
			return dir
		"coilqueen":
			# COIL QUEEN: moving serpent lanes, coils of seeking shots and
			# sequential constriction. Moving diagonally is the safe answer.
			var stage = boss_stage(e)
			if float(e["cd"]) <= 0.0:
				e["cd"] = 2.45 - stage * 0.27
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var p = int(e["pattern"]) % 5
				var lead = hero_pos + g.hero["vel"] * 0.30
				if p == 0:
					boss_lane_sequence(g, e, lead, stage, false, "57e5aa")
				elif p == 1:
					# Tight coils followed by venom-colored side volleys.
					boss_gapped_ring(g, e, 19 + stage * 6, 270.0 + stage * 25.0, 0.1, float(e["t"]) * 0.47)
					enemy_fire(g, e, dir, 3 + stage, 0.62, 300.0, 5.5)
				elif p == 2:
					for k in range(6 + stage * 2):
						var at = lead + Vector2.from_angle(TAU * k / float(6 + stage * 2)) * 125.0
						schedule_boss_blast(g, at, 42.0, float(e["dmg"]) * 0.67, 0.9 + 0.08 * k, "81ffba")
					schedule_boss_blast(g, lead, 48.0, float(e["dmg"]) * 0.62, 1.65, "3eeab3")
				elif p == 3:
					boss_cross(g, e, lead, stage, "6affe0")
					if stage >= 1:
						enemy_fire(g, e, dir, 6, 0.75, 340.0, 5.0)
				else:
					for k in range(4 + stage):
						var x = clampf(lead.x + (k - 2) * 113.0, -g.road_half + 18.0, g.road_half - 18.0)
						schedule_boss_line(g, Vector2(x, lead.y - 340), Vector2(x + (65.0 if k % 2 == 0 else -65.0), lead.y + 340),
							20.0, float(e["dmg"]) * 0.64, 0.85 + 0.2 * k, "60dcab")
			return (dir * 0.5 + dir.orthogonal() * sin(float(e["t"]) * 1.7) * 1.1).normalized() if dist > 185.0 else dir.orthogonal() * 0.8
		"glassoracle":
			# GLASS ORACLE: fixed mirror-geometry beams and prismatic shots;
			# its beams cross, but never rotate after locking onto a position.
			var stage = boss_stage(e)
			if float(e["cd"]) <= 0.0:
				e["cd"] = 2.62 - stage * 0.24
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var p = int(e["pattern"]) % 6
				var lead = hero_pos + g.hero["vel"] * 0.3
				if p == 0:
					boss_cross(g, e, lead, stage, "7beeff")
				elif p == 1:
					for k in range(3 + stage):
						var off = (k - 1 - stage * 0.5) * 90.0
						schedule_boss_line(g, Vector2(-g.road_half, lead.y - 220.0 + off),
							Vector2(g.road_half, lead.y + 220.0 + off), 17.0 + stage,
							float(e["dmg"]) * 0.64, 0.86 + 0.24 * k, "89daff")
				elif p == 2:
					enemy_fire(g, e, dir, 7 + stage * 2, 1.15, 360.0, 5.0)
					boss_gapped_ring(g, e, 16 + stage * 4, 250.0, 0.3, float(e["t"]) * 0.45)
				elif p == 3:
					boss_lane_sequence(g, e, lead, stage, true, "7cfcff")
				elif p == 4:
					for k in [-1, 1]:
						boss_cross(g, e, lead + Vector2(k * 85.0, k * 70.0), stage, "9de9ff")
				else:
					boss_lane_sequence(g, e, lead, stage, false, "84a9ff")
					enemy_fire(g, e, dir, 5, 0.8, 330.0, 5.0)
			var orbit = Vector2(sin(float(e["t"]) * 0.95) * 250.0, hero_pos.y - 270.0)
			return (orbit - e["pos"]).limit_length(110.0) / 110.0
		"voidweaver":
			# VOID WEAVER: ambush teleports and summoned tunnel hunters, with
			# lock-on runes that point to a fixed destination before moving.
			var stage = boss_stage(e)
			if float(e["wind"]) > 0.0:
				e["wind"] = maxf(0.0, float(e["wind"]) - dt)
				if float(e["wind"]) <= 0.0:
					g.spawn_ring_fx(e["pos"], Color("9871f5"), 70.0)
					e["pos"] = e.get("lock", e["pos"])
					e["vel"] = Vector2.ZERO
					e["kb"] = Vector2.ZERO
					g.spawn_ring_fx(e["pos"], Color("e2b0ff"), 105.0)
					boss_gapped_ring(g, e, 17 + stage * 5, 255.0, 0.2, float(e["t"]) * 0.17)
				return Vector2.ZERO
			if float(e["cd"]) <= 0.0:
				e["cd"] = 2.7 - stage * 0.27
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var p = int(e["pattern"]) % 6
				var lead = hero_pos + g.hero["vel"] * 0.23
				if p == 0:
					e["wind"] = 0.95 - stage * 0.09
					var side = -1.0 if int(e["pattern"]) % 2 == 0 else 1.0
					var lock_pos: Vector2 = lead + Vector2(side * 165.0, -85.0)
					lock_pos.x = clampf(lock_pos.x, -g.road_half + float(e["r"]), g.road_half - float(e["r"]))
					e["lock"] = lock_pos
					e["tele"] = 70.0
					g.sfx.play("boss_warn")
				elif p == 1:
					boss_cross(g, e, lead, stage, "a476ff")
					for k in range(2 + stage):
						if g.enemies.size() >= g.enemy_cap():
							break
						var spawn_at = e["pos"] + Vector2.from_angle(TAU * k / float(2 + stage)) * 100.0
						g.spawn_enemy("burrower", spawn_at, false, false)["summon"] = true
				elif p == 2:
					boss_lane_sequence(g, e, lead, stage, false, "a875ff")
				elif p == 3:
					boss_gapped_ring(g, e, 23 + stage * 4, 260.0, 0.12, float(e["t"]) * 0.5)
					enemy_fire(g, e, dir, 4 + stage, 0.52, 335.0, 6.0)
				elif p == 4:
					for k in range(5 + stage):
						var at = lead + Vector2.from_angle(float(k) * TAU / float(5 + stage)) * 115.0
						schedule_boss_blast(g, at, 49.0, float(e["dmg"]) * 0.72, 0.88 + k * 0.14, "bf88ff")
				else:
					boss_lane_sequence(g, e, lead, stage, true, "c28dff")
					if stage >= 1:
						boss_cross(g, e, lead, stage, "dba7ff")
			return (dir * 0.5 + dir.orthogonal() * sin(float(e["t"]) * 2.0) * 0.8).normalized() if dist > 240.0 else -dir * 0.4
		"dreadengine":
			# DREAD ENGINE: crushing pistons and alternating kill lanes,
			# with stronger but slower telegraphed consequences than flyers.
			var stage = boss_stage(e)
			if float(e["cd"]) <= 0.0:
				e["cd"] = 2.85 - stage * 0.28
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var p = int(e["pattern"]) % 6
				var lead = hero_pos + g.hero["vel"] * 0.34
				if p == 0:
					boss_lane_sequence(g, e, lead, stage, true, "ffa46b")
				elif p == 1:
					boss_lane_sequence(g, e, lead, stage, false, "ffbd67")
				elif p == 2:
					boss_cross(g, e, lead, stage, "ff935d")
					for k in [-1.0, 1.0]:
						schedule_boss_blast(g, lead + Vector2(k * 105.0, -40.0), 59.0, float(e["dmg"]) * 0.68, 1.38, "ffc084")
				elif p == 3:
					for k in range(5 + stage):
						var at = lead + Vector2((k - 2) * 87.0, (1.0 if k % 2 == 0 else -1.0) * 87.0)
						schedule_boss_blast(g, at, 56.0, float(e["dmg"]) * 0.77, 0.87 + k * 0.20, "ffa65e")
				elif p == 4:
					boss_gapped_ring(g, e, 21 + stage * 6, 235.0, 0.2, float(e["t"]) * 0.33)
					enemy_fire(g, e, dir, 5 + stage, 0.6, 305.0, 7.5)
				else:
					boss_lane_sequence(g, e, lead, stage, true, "ffc46d")
					for k in range(2 + stage):
						if g.enemies.size() >= g.enemy_cap():
							break
						g.spawn_enemy("sapper", e["pos"] + Vector2(-100.0 + 90.0 * k, 70.0), false, false)["summon"] = true
			return dir * 0.9 if dist > 255.0 else -dir * 0.23
		"chonkzilla":
			var stage = boss_stage(e)
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					g.add_shake(12.0)
					g.spawn_ring_fx(e["pos"], Color("ff6b7a"), 160.0)
					if g.hero["pos"].distance_to(e["pos"]) < 160.0:
						g.hurt(float(e["dmg"]), e["pos"], "CHONKZILLA's belly flop")
					boss_ring(g, e, 18 + stage * 5, 210.0 + stage * 28.0, float(e["t"]) * 0.4)
					if stage >= 1:
						boss_ring(g, e, 10 + stage * 3, 295.0, PI / 12.0 + float(e["t"]) * 0.4)
				return Vector2.ZERO
			if e["cd"] <= 0.0:
				e["cd"] = 3.0 - stage * 0.38
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var attack = int(e["pattern"]) % 6
				if attack == 4:
					# QUAKELINE: marching horizontal crushers force timed movement.
					boss_lane_sequence(g, e, hero_pos + g.hero["vel"] * 0.28, stage, true, "ff5a6e")
				elif attack == 5:
					# CRUSHING WALLS: alternating safe corridors with a delayed
					# cross strike at high phase, not an unavoidable full screen.
					boss_lane_sequence(g, e, hero_pos, stage, false, "ff8550")
					if stage >= 1:
						boss_cross(g, e, hero_pos, stage, "ffb15c")
				elif attack == 1:
					# Alternating offset slams force a lateral dodge.
					for k in range(3 + stage):
						var point = hero_pos + Vector2((k - 1) * 115.0, -35.0)
						schedule_boss_blast(g, point, 53.0, float(e["dmg"]) * 0.6, 1.15 + k * 0.16)
				elif attack == 3:
					# New move: alternating diagonal quake lanes with visible exits.
					for k in range(5 + stage):
						var at = hero_pos + Vector2((k - 2) * 98.0, (1.0 if k % 2 == 0 else -1.0) * 90.0)
						schedule_boss_blast(g, at, 54.0, float(e["dmg"]) * 0.57, 1.15 + 0.17 * k, "ff754b")
				else:
					e["wind"] = 1.0 - stage * 0.13
					e["tele"] = 160.0
				g.sfx.play("boss_warn")
			if fmod(float(e["t"]), 8.0) < dt:
				for k in range(4):
					g.spawn_enemy("blob", e["pos"] + Vector2.from_angle(k * TAU / 4.0) * 70.0, false, false)["summon"] = true
			return dir
		"heli":
			var stage = boss_stage(e)
			var anchor = Vector2(sin(float(e["t"]) * 0.7) * 300.0, hero_pos.y - 280.0)
			if e["cd"] <= 0.0:
				e["cd"] = 2.35 - stage * 0.25
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var pattern = int(e["pattern"]) % 6
				if pattern == 4:
					# STRAFE RUN: vertical attack corridors are laid one after
					# another, making the player shift and reverse directions.
					boss_lane_sequence(g, e, hero_pos + g.hero["vel"] * 0.35, stage, false, "ffbb5e")
				elif pattern == 5:
					# SKY PINS: cross-lane shots followed by a small precision
					# carpet, with visible warning for each impact.
					boss_cross(g, e, hero_pos + g.hero["vel"] * 0.3, stage, "fda65a")
					for k in range(2 + stage):
						var pin = hero_pos + Vector2((k - stage * 0.5) * 85.0, -80.0)
						schedule_boss_blast(g, pin, 42.0, float(e["dmg"]) * 0.5, 1.1 + 0.25 * k, "ffd17a")
				elif pattern == 0:
					e["burst"] = 10 + stage * 3
				elif pattern == 3:
					# New move: staggered bombing lanes cross where the hero stood.
					for k in range(6 + stage):
						var left_to_right = -1.0 if k % 2 == 0 else 1.0
						var point = hero_pos + Vector2(left_to_right * (175.0 - k * 13.0), (k - 3) * 78.0)
						schedule_boss_blast(g, point, 45.0, float(e["dmg"]) * 0.6, 0.95 + 0.18 * k, "ffb36b")
				elif pattern == 1:
					# A visible carpet of bombs across the escape route.
					for k in range(4 + stage):
						var at = hero_pos + Vector2((k - 2) * 96.0, -65.0)
						schedule_boss_blast(g, at, 46.0, float(e["dmg"]) * 0.55, 0.95 + k * 0.12)
				else:
					boss_ring(g, e, 12 + stage * 4, 235.0 + stage * 30.0, float(e["t"]))
				g.sfx.play("boss_warn")
			if int(e.get("burst", 0)) > 0 and fmod(float(e["t"]), 0.09) < dt:
				e["burst"] = int(e["burst"]) - 1
				enemy_fire(g, e, dir.rotated(randf_range(-0.25, 0.25)), 1, 0.0, 380.0)
			if fmod(float(e["t"]), 7.0) < dt:
				for k in range(3):
					g.spawn_enemy("kaboomba", e["pos"] + Vector2(-60 + 60 * k, 30), false, false)["summon"] = true
			return (anchor - e["pos"]).limit_length(80.0) / 80.0
		"necro":
			var stage = boss_stage(e)
			if e["cd"] <= 0.0:
				e["cd"] = 2.55 - stage * 0.26
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var pattern = int(e["pattern"]) % 6
				if pattern == 4:
					# GRAVE LATTICE: cursed paths cross in a warned X.
					boss_cross(g, e, hero_pos, stage, "c07bff")
					if stage >= 1:
						boss_gapped_ring(g, e, 13 + stage * 4, 235.0, 0.0, float(e["t"]) * 0.6)
				elif pattern == 5:
					# SPIRIT CORRIDORS: radial homing pursuit paired with a
					# narrow moving gap in a cursed lane sequence.
					boss_lane_sequence(g, e, hero_pos + g.hero["vel"] * 0.2, stage, true, "b57bff")
					for k in range(3 + stage):
						var ghost = enemy_fire(g, e, dir.rotated((k - 1 - stage * 0.5) * 0.27), 1, 0.0, 220.0, 6.0)
						if ghost != null:
							ghost["homing"] = 0.9
							ghost["life"] = 3.0
				elif pattern == 3:
					# New move: summon fast leeches to force displacement.
					for k in range(2 + stage):
						if g.enemies.size() >= g.enemy_cap():
							break
						var minion = g.spawn_enemy("leech", e["pos"] + Vector2.from_angle(k * TAU / (2.0 + stage)) * 92.0, false, false)
						minion["summon"] = true
					g.spawn_ring_fx(e["pos"], Color("a783ff"), 98.0)
				elif pattern == 0:
					for k in range(5 + stage * 2):
						var a = float(k - 2 - stage) * 0.27
						var s = enemy_fire(g, e, dir.rotated(a), 1, 0.0, 190.0 + stage * 25.0)
						if s != null:
							s["homing"] = 1.1 + stage * 0.13
							s["life"] = 4.0
							s["kind"] = "skull"
				elif pattern == 1:
					# Rotating cursed spiral; outer lanes have gaps to escape.
					boss_ring(g, e, 13 + stage * 3, 220.0, float(e["t"]) * 0.8)
				else:
					for k in range(3 + stage):
						var at = hero_pos + Vector2.from_angle(float(k) * TAU / (3 + stage)) * 95.0
						schedule_boss_blast(g, at, 49.0, float(e["dmg"]) * 0.55, 1.2)
				g.sfx.play("boss_warn")
			if fmod(float(e["t"]), 6.0) < dt:
				for k in range(6):
					var m = g.spawn_enemy("blob", e["pos"] + Vector2.from_angle(k * TAU / 6.0) * 90.0, false, false)
					m["spawn"] = 0.0
					m["summon"] = true
				g.spawn_ring_fx(e["pos"], Color("b48cff"), 120.0)
			if dist < 280.0:
				return -dir
			return dir if dist > 380.0 else dir.orthogonal() * 0.6
		"kingblob":
			var stage = boss_stage(e)
			if float(e["wind"]) > 0.0:
				e["wind"] = float(e["wind"]) - dt
				if float(e["wind"]) <= 0.0:
					e["pos"] = e.get("lock", hero_pos)
					g.add_shake(10.0)
					g.spawn_ring_fx(e["pos"], Color("ff7b93"), 120.0)
					if g.hero["pos"].distance_to(e["pos"]) < 110.0:
						g.hurt(float(e["dmg"]), e["pos"], "KING BLOB's butt")
				return Vector2.ZERO
			if e["cd"] <= 0.0 and dist < 480.0:
				e["cd"] = 3.1 - stage * 0.38
				e["pattern"] = int(e.get("pattern", -1)) + 1
				var king_attack = int(e["pattern"]) % 6
				if king_attack == 4:
					# ROYAL PINS: staggered edge-to-edge pressure lanes.
					boss_lane_sequence(g, e, hero_pos, stage, true, "ff7fa7")
				elif king_attack == 5:
					# SPLIT CROWN: cross-lanes and a gapped outward barrage.
					boss_cross(g, e, hero_pos + g.hero["vel"] * 0.2, stage, "ff6aba")
					boss_gapped_ring(g, e, 14 + stage * 5, 230.0 + stage * 20.0, 0.2, float(e["t"]) * 0.15)
				elif king_attack == 3:
					# New move: spawn flanking skitters and force repositioning.
					for k in range(2 + stage):
						if g.enemies.size() >= g.enemy_cap():
							break
						var skit = g.spawn_enemy("skitter", e["pos"] + Vector2(-85.0 + k * 65.0, 40.0), false, false)
						skit["summon"] = true
					g.spawn_ring_fx(e["pos"], Color("ff7b93"), 110.0)
				elif king_attack % 2 == 0:
					e["wind"] = 0.95 - stage * 0.13
					e["lock"] = hero_pos
					e["tele"] = 110.0
				else:
					# Three sequential impacts chase the player's predicted route.
					var projected = hero_pos + g.hero["vel"] * 0.35
					for k in range(3 + stage):
						var at = projected + Vector2((k - 1) * 90.0, 0)
						schedule_boss_blast(g, at, 61.0, float(e["dmg"]) * 0.65, 1.05 + k * 0.25, "ff6aaf")
				g.sfx.play("boss_warn")
			return dir
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

## Laser Larry: after the aim line locks, an instant beam along it. Dash through it for a PERFECT.
static func larry_beam(g, e: Dictionary, dir: Vector2) -> void:
	var a: Vector2 = e["pos"] + dir * float(e["r"])
	var b: Vector2 = a + dir * 950.0
	g.beams.append({"a": a, "b": b, "t": 0.22, "w": 12.0, "color": Color("ff3a5a")})
	g.beams.append({"a": a, "b": b, "t": 0.22, "w": 4.0, "color": Color("ffe0e8")})
	g.sfx.play("rail")
	g.add_shake(3.0)
	if seg_dist2(a, b, g.hero["pos"]) < pow(12.0 + 11.0, 2):
		g.hurt(float(e["dmg"]) * 1.2, e["pos"], "Laser Larry")

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
