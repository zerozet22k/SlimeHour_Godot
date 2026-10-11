extends RefCounted
## Individually-authored level-five weapon signatures.
## These are gameplay reactions, not the same explosion, extra bullets or ricochet with a different tint.
## Run via Combat hooks; every area effect is bounded to prevent proc storms.

static var _combat = null

static func C():
	if _combat == null:
		_combat = load("res://scripts/Combat.gd")
	return _combat

## Evolution reactions: one mechanic per evolved gun.
static func evolved_hit(g, s: Dictionary, e: Dictionary, pos: Vector2) -> void:
	var flags: Dictionary = s["flags"]
	if flags.has("ricochet_round") and not flags.has("ricochet_done"):
		flags["ricochet_done"] = true
		C().zap(g, pos, 2, float(s["dmg"]) * 0.8, 2, e)
	if flags.has("incendiary"):
		g.add_zone("fire", pos, 30.0, 1.6)
	if flags.has("last_word") and bool(e["dead"]) and int(flags.get("last_word_n", 0)) < 3:
		flags["last_word_n"] = int(flags.get("last_word_n", 0)) + 1
		s["dmg"] = float(s["dmg"]) * 1.5
		var gun = s.get("gun")
		if gun != null:
			gun["ammo"] = mini(int(gun["mag_max"]), int(gun["ammo"]) + 1)
		g.say(pos + Vector2(0, -24), "+1", Color("e5bcff"), 18)
	if flags.has("rivet_burst") and not bool(e["dead"]):
		e["rivets"] = int(e.get("rivets", 0)) + 1
		if int(e["rivets"]) >= 5:
			e["rivets"] = 0
			C().fragments(g, pos, 5, float(s["dmg"]) * 1.2, "ring", Vector2.UP, 2, e, false, Color("f2dbad"))
			g.spawn_ring_fx(pos, Color("f2dbad"), 30.0)
	if flags.has("queen") and not flags.has("queen_done"):
		flags["queen_done"] = true
		C().add_bees(g, pos, 2, float(s["dmg"]) * 0.7, 2)

static func projectile_hit(g, s: Dictionary, e: Dictionary, pos: Vector2) -> void:
	evolved_hit(g, s, e, pos)
	if bool(e["dead"]) and str(s["src"]) != "sniper":
		return
	var flags: Dictionary = s["flags"]
	var id = str(s["src"])
	match id:
		"pistol":
			if flags.has("verdict"):
				e["mark"] = maxf(float(e["mark"]), 2.5)
				g.spawn_ring_fx(pos, Color("f4eea0"), 24.0)
		"shotgun":
			if flags.has("breach") and pos.distance_to(g.hero["pos"]) < 145.0 and g.run_time >= float(e.get("breach_lock", -1.0)):
				e["breach_lock"] = g.run_time + 0.8
				e["stun"] = maxf(float(e["stun"]), 0.12 if bool(e["boss"]) else 0.65)
				e["kb"] += (e["pos"] - g.hero["pos"]).normalized() * (90.0 if bool(e["boss"]) else 360.0)
				g.spawn_ring_fx(pos, Color("ffc68e"), 42.0)
		"smg":
			if flags.has("suppress"):
				e["slow"] = maxf(float(e["slow"]), 0.8)
				# Level-five suppression is a visible periodic SHOCKWAVE, not
				# an invisible slow on single victims. Gate it per weapon so
				# high-rate SMG builds do not trigger a proc storm.
				var owner = s.get("gun")
				if owner != null and g.run_time >= float(owner.get("suppress_pulse_t", -1.0)):
					owner["suppress_pulse_t"] = g.run_time + 0.55
					var affected = 0
					for nearby in g.enemies_near(pos, 100.0):
						if bool(nearby["dead"]) or nearby == e:
							continue
						nearby["slow"] = maxf(float(nearby["slow"]), 0.55)
						affected += 1
						if affected >= 5:
							break
					g.spawn_ring_fx(pos, Color("79dfff"), 94.0)
					g.sfx.play_projectile("status", "shock", "", 0.24)
		"minigun":
			if flags.has("vulcan_sweep") and g.run_time >= float(e.get("vulcan_lock", -1.0)):
				e["vulcan_lock"] = g.run_time + 1.1
				var side: Vector2 = s["vel"].normalized().orthogonal()
				e["kb"] += side * (120.0 if bool(e["boss"]) else 340.0)
				g.spawn_ring_fx(pos, Color("ffe6a4"), 36.0)
		"sniper":
			if flags.has("collateral"):
				s["dmg"] = minf(float(s["base_dmg"]) * 2.5, float(s["dmg"]) + float(s["base_dmg"]) * 0.24)
				g.beams.append({"a": s["last"], "b": pos, "t": 0.13, "w": 3.0, "color": Color("cbb6ff")})
		"bees":
			if flags.has("hive_scent"):
				e["hive_scent"] = g.run_time + 2.6
				if g.run_time >= float(e.get("hive_fx", -1.0)):
					e["hive_fx"] = g.run_time + 0.8
					g.spawn_ring_fx(pos, Color("ffe46b"), 36.0)
		"bowling":
			if flags.has("perfect_strike") and not flags.has("strike_done"):
				flags["strike_hits"] = int(flags.get("strike_hits", 0)) + 1
				if int(flags["strike_hits"]) >= 3:
					flags["strike_done"] = true
					var pushed = 0
					for other in g.enemies_near(pos, 135.0):
						if bool(other["dead"]) or bool(other["boss"]) or other == e:
							continue
						other["kb"] += (other["pos"] - pos).normalized() * 340.0
						other["flung"] = maxf(float(other["flung"]), 0.7)
						pushed += 1
						if pushed >= 6:
							break
					g.spawn_ring_fx(pos, Color("e2b9ff"), 130.0)
					g.say(pos, "STRIKE!", Color("e9cdff"), 23)
		"nailgun":
			if flags.has("rivet_tether") and g.run_time >= float(e.get("rivet_cd", -1.0)):
				e["rivet_cd"] = g.run_time + 1.1
				var linked = 0
				for other in g.enemies_near(pos, 125.0):
					if other == e or bool(other["dead"]) or bool(other["boss"]) or float(other["pinned"]) > 0.0:
						continue
					other["pinned"] = maxf(float(other["pinned"]), 0.9)
					other["stun"] = maxf(float(other["stun"]), 0.35)
					g.beams.append({"a": pos, "b": other["pos"], "t": 0.4, "w": 4.0, "color": Color("f3e2bd")})
					linked += 1
					if linked >= 1:
						break
		"chicken":
			if flags.has("panic") and not flags.has("panic_done"):
				flags["panic_done"] = true
				var panicked = 0
				for other in g.enemies_near(pos, 135.0):
					if bool(other["dead"]) or bool(other["boss"]) or other == e:
						continue
					other["charm"] = maxf(float(other["charm"]), 1.15)
					panicked += 1
					if panicked >= 3:
						break
				g.spawn_ring_fx(pos, Color("fff189"), 132.0)
				g.say(pos, "PANIC!", Color("ffed93"), 21)
		"pinball":
			var charged = int(flags.get("bank_charge", 0))
			if charged > 0:
				flags["bank_charge"] = 0
				e["stun"] = maxf(float(e["stun"]), 0.1 if bool(e["boss"]) else 0.23 * charged)
				e["kb"] += s["vel"].normalized() * float(charged) * 130.0
				g.spawn_ring_fx(pos, Color("ff9df0"), 24.0 + charged * 15.0)
		"snow":
			if flags.has("whiteout") and not flags.has("whiteout_done"):
				flags["whiteout_done"] = true
				g.add_zone("ice", pos, 78.0, 2.0)
				g.spawn_ring_fx(pos, Color("d8fbff"), 78.0)

static func critical_hit(g, e: Dictionary, ctx: Dictionary) -> void:
	var s = ctx.get("shot")
	if s != null and s["flags"].has("ricochet_crit") and not s["flags"].has("ricochet_child"):
		# Deadeye Prime: the crit ricochets into the nearest other enemy.
		var best = null
		var best_d = 320.0 * 320.0
		for other in g.enemies_near(e["pos"], 320.0):
			if other == e or bool(other["dead"]):
				continue
			var d2: float = Vector2(other["pos"]).distance_squared_to(e["pos"])
			if d2 < best_d:
				best_d = d2
				best = other
		if best != null:
			var dir: Vector2 = (Vector2(best["pos"]) - Vector2(e["pos"])).normalized()
			C().shot(g, Vector2(e["pos"]) + dir * (float(e["r"]) + 4.0), dir, float(s["base_dmg"]),
				{"friendly": true, "kind": "bullet", "speed": 1300.0, "life": 0.4, "r": 4.5, "crit": 1.0,
				"color": Color("ffe36b"), "src": "revolver", "flags": {"ricochet_child": true}, "gen": 2})
			g.beams.append({"a": e["pos"], "b": best["pos"], "t": 0.1, "w": 2.0, "color": Color("ffe36b")})
	if s != null and str(ctx.get("src", "")) == "revolver" and s["flags"].has("duelist"):
		e["stun"] = maxf(float(e["stun"]), 0.15 if bool(e["boss"]) else 0.9)
		g.spawn_ring_fx(e["pos"], Color("ffe9a6"), 36.0)

static func wall_bounce(g, s: Dictionary) -> void:
	var flags: Dictionary = s["flags"]
	match str(s["src"]):
		"grenade":
			if flags.has("bank_guidance") and not flags.has("guided"):
				var target = g.nearest_enemy(s["pos"], 340.0)
				if target != null:
					flags["guided"] = true
					s["speed"] = maxf(float(s["speed"]), 560.0)
					s["vel"] = (target["pos"] - s["pos"]).normalized() * float(s["speed"])
					s["homing"] = 7.0
					s["life"] = maxf(float(s["life"]), 0.5)
					g.spawn_ring_fx(s["pos"], Color("b5ff6b"), 40.0)
		"pinball":
			if flags.has("multiball_split") and int(flags.get("splits", 0)) < 2:
				flags["splits"] = int(flags.get("splits", 0)) + 1
				var child_flags: Dictionary = flags.duplicate()
				child_flags["splits"] = 2
				var v: Vector2 = Vector2(s["vel"]).rotated(0.45 * (1.0 if randf() < 0.5 else -1.0))
				C().shot(g, s["pos"], v.normalized(), float(s["dmg"]) * 0.8,
					{"friendly": true, "kind": str(s["kind"]), "speed": float(s["speed"]), "life": maxf(0.4, float(s["life"])),
					"r": float(s["r"]), "bounce": maxi(1, int(s["bounce"])), "color": s["color"], "src": "pinball",
					"flags": child_flags, "gen": 2, "gun": s.get("gun")})
			if flags.has("perfect_bank"):
				flags["bank_charge"] = mini(3, int(flags.get("bank_charge", 0)) + 1)
				g.spawn_ring_fx(s["pos"], Color("ff9df0"), 18.0 + 12.0 * int(flags["bank_charge"]))

static func rocket_collapse(g, s: Dictionary, pos: Vector2) -> void:
	if not s["flags"].has("thermobaric"):
		return
	# A two-stage attack: normal initial blast, then a clearly telegraphed inward shock.
	# The second stage deals no damage and is not another explosion.
	g.delayed.append({"fn": "payload_vacuum", "t": 0.48, "life": 0.48, "tele": 125.0,
		"pos": pos, "color": "ffa174"})

static func vacuum(g, pos: Vector2) -> void:
	var pulled = 0
	for e in g.enemies_near(pos, 135.0):
		if bool(e["dead"]) or bool(e["boss"]):
			continue
		e["kb"] += (pos - e["pos"]).normalized() * 350.0
		e["slow"] = maxf(float(e["slow"]), 0.75)
		pulled += 1
		if pulled >= 12:
			break
	g.spawn_ring_fx(pos, Color("ffb27d"), 125.0)
	g.sfx.play("whoosh")

static func disc_recall(g, s: Dictionary, dt: float) -> void:
	if not s["flags"].has("vortex_recall") or not bool(s["back"]):
		return
	s["vortex_cd"] = float(s.get("vortex_cd", 0.0)) - dt
	if float(s["vortex_cd"]) > 0.0:
		return
	s["vortex_cd"] = 0.18
	var pulled = 0
	for e in g.enemies_near(s["pos"], 95.0):
		if bool(e["dead"]) or bool(e["boss"]):
			continue
		e["kb"] += (s["pos"] - e["pos"]).normalized() * 120.0
		pulled += 1
		if pulled >= 5:
			break
	if pulled > 0:
		g.spawn_ring_fx(s["pos"], Color("7dffb2"), 85.0)

static func return_catch(g, s: Dictionary, caught: bool) -> void:
	if caught and s["flags"].has("catch_wave"):
		C().shockwave(g, g.hero["pos"], 130.0, float(s["base_dmg"]) * 0.6, 320.0, 2)
	var w = s.get("gun")
	if w == null or str(s["src"]) != "boomerang" or not s["flags"].has("momentum_catch") or not bool(s["flags"].get("owner", false)):
		return
	if caught:
		w["catch_streak"] = mini(3, int(w.get("catch_streak", 0)) + 1)
		g.spawn_ring_fx(g.hero["pos"], Color("ffcf6b"), 26.0 + 8.0 * int(w["catch_streak"]))
	else:
		w["catch_streak"] = 0

## Shots that end without hitting anything (range out or road wall).
static func on_expire(g, s: Dictionary) -> void:
	var flags: Dictionary = s["flags"]
	var pos: Vector2 = s["pos"]
	match str(s["src"]):
		"nailgun":
			# Missed nails stick in the road as caltrops that slow and nick enemies.
			var nails := 0
			for z in g.zones:
				if str(z["kind"]) == "nails":
					nails += 1
			if nails < 24:
				g.add_zone("nails", pos, 18.0, 5.0, {"dmg": float(s["base_dmg"]) * 0.25})
		"bowling":
			if flags.has("crater"):
				C().shockwave(g, pos, 110.0, float(s["base_dmg"]) * 0.5, 280.0, 2)
		"chicken":
			if flags.has("feathers"):
				C().fragments(g, pos, 4, float(s["base_dmg"]) * 0.35, "ring", Vector2.UP, 2, null, false, Color("fff076"))

## Frostcaster evolution: a snowball paints one continuous ice ribbon.
static func frost_trail(g, s: Dictionary) -> void:
	var z = s.get("frost_z")
	var Tr = load("res://scripts/Trails.gd")
	if z == null or not g.zones.has(z):
		z = g.add_zone("ice", s["pos"], 22.0, 1.6, {"pts": [], "born": []})
		Tr.start(z, s["pos"], g.run_time)
		s["frost_z"] = z
	Tr.extend(z, s["pos"], g.run_time)
	z["t"] = z["life"]

static func flame_death(g, e: Dictionary, pos: Vector2) -> void:
	if float(e["burn"]) <= 0.0:
		return
	var active = false
	for w in g.guns:
		if str(w["id"]) == "flame" and int(w["lvl"]) >= 5:
			active = true
			break
	if not active:
		return
	var spread = 0
	for other in g.enemies_near(pos, 165.0):
		if bool(other["dead"]) or other == e or float(other["burn"]) > 0.0:
			continue
		other["burn"] = maxf(float(other["burn"]), 3.0 * (1.0 + g.st("dur")))
		g.beams.append({"a": pos, "b": other["pos"], "t": 0.17, "w": 3.5, "color": Color("ff8a3d")})
		spread += 1
		if spread >= 3:
			break
	if spread > 0:
		g.spawn_ring_fx(pos, Color("ff8a3d"), 45.0)

static func bubble_transfer(g, e: Dictionary) -> void:
	var hops = int(e.get("bubble_chain", 0))
	if hops <= 0:
		return
	for other in g.enemies_near(e["pos"], 145.0):
		if other == e or bool(other["dead"]) or float(other["bubble"]) > 0.0 or bool(other["boss"]):
			continue
		other["bubble"] = 1.25
		other["bubble_dmg"] = float(e.get("bubble_dmg", 20.0)) * 0.75
		other["bubble_r"] = float(e.get("bubble_r", 55.0)) * 0.85
		other["bubble_mini"] = false
		other["bubble_chain"] = hops - 1
		g.beams.append({"a": e["pos"], "b": other["pos"], "t": 0.22, "w": 4.0, "color": Color("9fe8ff")})
		g.spawn_ring_fx(other["pos"], Color("9fe8ff"), 38.0)
		break
