extends RefCounted
## Generic behavior-graft interpreter: one module per donor and one actual base AI.
## Every combination is derived from species data, never from pair IDs.
static var _schema: Dictionary = {}

static func schema() -> Dictionary:
	if _schema.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/mutation_modules.json"))
		if parsed is Dictionary:
			_schema = parsed
	return _schema

static func body_caps(body: String) -> Array:
	return schema().get("receivers", {}).get(body, [])

static func donor_spec(donor: String) -> Dictionary:
	return schema().get("donors", {}).get(donor, {})

static func compatible(body: String, donor: String) -> bool:
	if body == donor:
		return false
	var caps: Array = body_caps(body)
	var spec: Dictionary = donor_spec(donor)
	if caps.is_empty() or spec.is_empty():
		return false
	for required in spec.get("requires_any", []):
		if caps.has(required):
			return true
	return false

static func inherited(g, e: Dictionary) -> Dictionary:
	var info: Dictionary = g.enemy_db.get(str(e.get("mut_of", e.get("kind", ""))), {})
	var parents: Array = info.get("mix", [])
	if parents.size() != 2 or not compatible(str(parents[0]), str(parents[1])):
		return {}
	return donor_spec(str(parents[1]))

static func donor_is(g, e: Dictionary, species: String) -> bool:
	var info: Dictionary = g.enemy_db.get(str(e.get("mut_of", e.get("kind", ""))), {})
	var parents: Array = info.get("mix", [])
	return parents.size() == 2 and str(parents[1]) == species and compatible(str(parents[0]), species)

static func trait_name(body: String, donor: String) -> String:
	var spec: Dictionary = donor_spec(donor)
	return str(spec.get("label", "unknown trait")) if compatible(body, donor) else "INCOMPATIBLE"

static func description(body: String, donor: String) -> String:
	if not compatible(body, donor):
		return "This body cannot receive that donor's required combat behavior."
	return "Retains " + body.capitalize() + " combat AI. Inherits " + trait_name(body, donor) + " from " + donor.capitalize() + ". The graft has its own cooldown and counterplay."

static func warning_radius(module: String) -> float:
	match module:
		"belly_shock": return 120.0
		"death_fuse": return 85.0
		"parasite_latch": return 78.0
		"coin_snatch": return 80.0
		"impact_charge": return 100.0
		_: return 52.0

static func tick(g, e: Dictionary, dt: float) -> void:
	var spec := inherited(g, e)
	if spec.is_empty():
		return
	e["graft_cd"] = maxf(0.0, float(e.get("graft_cd", 2.3)) - dt)
	var id: String = str(spec.get("module", ""))
	# Sustained states have real start/end and cannot run indefinitely.
	if float(e.get("graft_tunnel_t", 0.0)) > 0.0:
		e["graft_tunnel_t"] = maxf(0.0, float(e["graft_tunnel_t"]) - dt)
		if float(e["graft_tunnel_t"]) <= 0.0:
			e["burrowing"] = false
			e["exposed_t"] = 1.2
			g.spawn_ring_fx(e["pos"], Color(str(e.get("mut_col", "c29e77"))), 68.0)
			if Vector2(e["pos"]).distance_to(g.hero["pos"]) < 65.0:
				g.hurt(float(e["dmg"]) * 0.65, e["pos"], "a tunnel ambush")
	if float(e.get("graft_orbit_t", 0.0)) > 0.0:
		e["graft_orbit_t"] = maxf(0.0, float(e["graft_orbit_t"]) - dt)
	if float(e.get("graft_ward_t", 0.0)) > 0.0:
		e["graft_ward_t"] = maxf(0.0, float(e["graft_ward_t"]) - dt)
	if float(e.get("graft_guard_t", 0.0)) > 0.0:
		e["graft_guard_t"] = maxf(0.0, float(e["graft_guard_t"]) - dt)
	if float(e.get("graft_latch_t", 0.0)) > 0.0:
		e["graft_latch_t"] = maxf(0.0, float(e["graft_latch_t"]) - dt)
		if Vector2(e["pos"]).distance_to(g.hero["pos"]) < 70.0:
			g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 0.18)
	if float(e.get("graft_link_t", 0.0)) > 0.0:
		e["graft_link_t"] = maxf(0.0, float(e["graft_link_t"]) - dt)
		if Vector2(e["pos"]).distance_to(g.hero["pos"]) > 340.0:
			e["graft_link_t"] = 0.0
		else:
			e["graft_link_tick"] = float(e.get("graft_link_tick", 0.0)) - dt
			if float(e["graft_link_tick"]) <= 0.0:
				e["graft_link_tick"] = 0.55
				var EI = load("res://scripts/EnemyIdentity.gd")
				if not EI.covered(g, e["pos"], g.hero["pos"]) and g.hurt(float(e["dmg"]) * 0.18, e["pos"], "a fused blood conduit"):
					e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.025)
					g.beams.append({"a": e["pos"], "b": g.hero["pos"], "t": 0.15, "w": 2.5, "color": Color("ad80ea"), "zig": false})
	if float(e["graft_cd"]) <= 0.0 and Vector2(e["pos"]).distance_to(g.hero["pos"]) < 560.0:
		cast(g, e)

static func cast(g, e: Dictionary) -> void:
	var spec := inherited(g, e)
	if spec.is_empty() or bool(e.get("dead", false)) or g.delayed.size() >= 112:
		return
	if float(e.get("graft_cd", 0.0)) > 0.0:
		return
	e["graft_cd"] = float(spec.get("cooldown", 5.5)) * (0.86 if g.hard_mode else 1.0)
	var module: String = str(spec.get("module", ""))
	# One telegraphed event, not a generic N-point bomb/laser barrage.
	var target: Vector2 = g.hero["pos"]
	var origin: Vector2 = e["pos"]
	var pos: Vector2 = target if module in ["aimed_shell", "sticky_throw", "piercing_lance", "coin_snatch"] else origin
	var col: String = str(e.get("mut_col", str(g.enemy_db.get(str(e["kind"]), {}).get("color", "e3c2ff"))))
	g.delayed.append({"fn": "genome_graft", "src_enemy": e, "owner": int(e["id"]),
		"module": module, "pos": pos, "t": 0.68, "life": 0.68,
		"tele": warning_radius(module), "color": col})
	g.say(origin + Vector2(0, -float(e["r"]) - 24.0), str(spec.get("label", "GRAFT")).to_upper() + "!", Color(col), 14)

static func motion(g, e: Dictionary, desired: Vector2) -> Vector2:
	var spec := inherited(g, e)
	if spec.is_empty():
		return desired
	var kind := str(spec.get("module", ""))
	if kind == "orbit_sprint" and float(e.get("graft_orbit_t", 0.0)) > 0.0:
		var turn := -1.0 if int(e["id"]) % 2 == 0 else 1.0
		var dir: Vector2 = desired.normalized()
		return (dir * 0.40 + dir.orthogonal() * turn).normalized() * 1.2
	if kind == "aim_evasion" and float(e.get("graft_evade_t", 0.0)) > 0.0:
		e["graft_evade_t"] = maxf(0.0, float(e["graft_evade_t"]) - 0.016)
		return (desired.normalized() + Vector2(desired.y, -desired.x).normalized()).normalized() * 1.15
	return desired

static func decorate_projectile(g, e: Dictionary, shot: Dictionary) -> void:
	var spec := inherited(g, e)
	match str(spec.get("module", "")):
		"ricochet_dash":
			shot["bounce"] = maxi(int(shot.get("bounce", 0)), 1)
		"piercing_lance":
			shot["pierce"] = maxi(int(shot.get("pierce", 0)), 2)
		"acid_track":
			shot["acid_trail"] = true
			shot["acid_trail_w"] = 22.0

static func may_reflect(g, e: Dictionary) -> bool:
	return donor_is(g, e, "mirror") and float(e.get("mirror_cd", 0.0)) <= 0.0

static func may_guard(g, e: Dictionary) -> bool:
	return donor_is(g, e, "riot") and float(e.get("graft_guard_t", 0.0)) > 0.0

static func try_rebirth(g, e: Dictionary) -> bool:
	if not donor_is(g, e, "ashwing") or bool(e.get("graft_rebirth_used", false)):
		return false
	e["graft_rebirth_used"] = true
	e["rebirth_t"] = 1.65
	e["cocoon_hp"] = maxf(8.0, float(e["max_hp"]) * 0.28)
	e["hp"] = maxf(1.0, float(e["max_hp"]) * 0.3)
	e["wind"] = 0.0
	e["charge"] = 0.0
	e["kb"] = Vector2.ZERO
	e["vel"] = Vector2.ZERO
	g.say(e["pos"] + Vector2(0, -42), "BREAK THE EGG!", Color("ffac76"), 15)
	return true

static func resolve(g, item: Dictionary) -> void:
	var e = item.get("src_enemy")
	if e == null or bool(e.get("dead", false)):
		return
	var spec := inherited(g, e)
	var module: String = str(item.get("module", ""))
	if spec.is_empty() or str(spec.get("module", "")) != module:
		return
	var C = load("res://scripts/Combat.gd")
	var EI = load("res://scripts/EnemyIdentity.gd")
	var origin: Vector2 = e["pos"]
	var hero: Vector2 = g.hero["pos"]
	var dir: Vector2 = (hero - origin).normalized() if hero.distance_to(origin) > 0.5 else Vector2.DOWN
	var dmg: float = float(e["dmg"])
	var col: String = str(item.get("color", "cdd3ff"))
	match module:
		"pack_link":
			for ally in g.enemies_near(origin, 115.0):
				if ally != e and not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["siphon_empowered_t"] = maxf(float(ally.get("siphon_empowered_t", 0.0)), 1.1)
					g.beams.append({"a":origin,"b":ally["pos"],"t":0.15,"w":3.0,"color":Color(col)})
					break
		"orbit_sprint":
			e["graft_orbit_t"] = 1.8
		"belly_shock":
			C.schedule_boss_blast(g, origin, 115.0, dmg * 0.52, 0.48, col)
			e["recover"] = maxf(float(e.get("recover", 0.0)), 0.7)
		"acid_track":
			var from := origin - dir * 75.0
			for i in range(3):
				EI.place(g, "acid", from + dir * float(i) * 48.0, 27.0, dmg * 0.18, 2.1, 0.0, col)
		"death_fuse":
			# One bomb per activation, with a clear warning and no bomblet cascade.
			C.schedule_boss_blast(g, origin, 85.0, dmg * 0.8, 0.9, col)
		"cell_bud":
			if g.enemies.size() < g.enemy_cap():
				var mini = g.spawn_enemy("mini", origin + Vector2(randf_range(-24.0, 24.0), -25.0), false, false)
				mini["summon"] = true
		"aim_evasion":
			e["graft_evade_t"] = 1.0
			e["kb"] = Vector2(e["kb"]) + dir.orthogonal() * 155.0
		"front_guard":
			e["graft_guard_t"] = 2.6
			e["shield_hp"] = maxf(float(e.get("shield_hp", 0.0)), float(e["max_hp"]) * 0.26)
		"impact_charge":
			e["charge"] = maxf(float(e.get("charge", 0.0)), 0.36)
			e["cdir"] = dir
		"lay_egg":
			if g.enemy_hazards.size() < 100:
				EI.place(g, "egg", origin - dir * 26.0, 18.0, 0.0, 3.0, 0.0, col)
		"aimed_shell":
			C.schedule_boss_blast(g, item["pos"], 65.0, dmg * 0.64, 0.65, col)
		"ward_link":
			for ally in g.enemies_near(origin, 190.0):
				if ally != e and not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["siphon_empowered_t"] = maxf(float(ally.get("siphon_empowered_t", 0.0)), 2.0)
					g.beams.append({"a": origin, "b": ally["pos"], "t":0.25, "w":3.0, "color":Color(col)})
					break
		"rift_slash":
			var land: Vector2 = hero - dir * 95.0
			land.x = clampf(land.x, -g.road_half + float(e["r"]), g.road_half - float(e["r"]))
			e["pos"] = land
			C.schedule_boss_line(g, origin, land, 25.0, dmg * 0.55, 0.62, col, "rift")
		"parasite_latch":
			e["graft_latch_t"] = 1.55
		"coin_snatch":
			if origin.distance_to(hero) < 90.0 and g.gold > 0:
				g.gold -= 1
				g.say(hero + Vector2(0, -32), "-1 GOLD", Color("ffe15d"), 14)
		"phoenix_egg", "reflect_shot":
			g.spawn_ring_fx(origin, Color(col), 46.0)
		"burrow_ambush":
			e["burrowing"] = true
			e["graft_tunnel_t"] = 1.05
			e["graft_tunnel_target"] = hero
		"command_pulse":
			for ally in g.enemies_near(origin, 190.0):
				if ally != e and not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["siren_haste"] = maxf(float(ally.get("siren_haste", 0.0)), 2.3)
		"ricochet_dash":
			e["charge"] = maxf(float(e.get("charge", 0.0)), 0.34)
			e["cdir"] = dir
			e["graft_bounces"] = 1
		"sticky_throw":
			var bomb = C.shot(g, origin, dir, dmg * 0.85, {"friendly": false, "speed": 325.0, "life": 1.1, "r": 8.0, "kind":"enemy", "color":Color(col), "src":"a fused sticky charge"})
			if bomb != null:
				bomb["sticky_bomb"] = true
		"piercing_lance":
			var spear = C.shot(g, origin, dir, dmg * 0.7, {"friendly": false, "speed": 850.0, "life": 1.0, "r": 7.0, "kind":"enemy", "color":Color(col), "src":"a fused lance"})
			if spear != null:
				spear["pierce"] = 3
				spear["spear"] = true
		"blood_link":
			e["graft_link_t"] = 2.3
			e["graft_link_tick"] = 0.1
		"triage":
			if float(e.get("stun", 0.0)) <= 0.0:
				var best: Dictionary = {}
				var lowest := 1.0
				for ally in g.enemies_near(origin, 220.0):
					var ratio: float = float(ally["hp"]) / maxf(1.0, float(ally["max_hp"]))
					if ally != e and not bool(ally["dead"]) and not bool(ally.get("boss", false)) and ratio < lowest:
						lowest = ratio
						best = ally
				if not best.is_empty():
					best["hp"] = minf(float(best["max_hp"]), float(best["hp"]) + float(best["max_hp"]) * 0.12)
					g.beams.append({"a":origin,"b":best["pos"],"t":0.25,"w":4.0,"color":Color("96ffe0")})
		"overheat_beam":
			var end: Vector2 = EI.clip_beam(g, origin, origin + dir * 580.0)
			C.schedule_boss_line(g, origin, end, 10.0, dmg * 0.65, 0.55, col, "beam")
			e["overheat_t"] = maxf(float(e.get("overheat_t", 0.0)), 1.3)
