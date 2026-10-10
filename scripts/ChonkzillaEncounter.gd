extends RefCounted
## Chonkzilla's own encounter director. No shared fullscreen events or generic ring spam.
## Four coupled systems: committed rush, destructible stone anchors, pulsing faults,
## and player-earned armor breaks. Stage 1 chains attacks; stage 2 changes the rhythm.

const STONE_LIMIT := 3
const FAULT_LIMIT := 7
const STONE_COLOR := Color("d7aa79")
const FAULT_COLOR := "ff9670"
const OWNED_PROJECTILE_LIMIT := 104
const VOLLEY_BUFFER := 24

## Projectile descriptions are returned to Combat, keeping the boss director
## independent of Combat.gd and avoiding circular preloads.
static func bullet(result: Array, where: Vector2, direction: Vector2, speed: float,
		damage_scale: float, radius: float, life: float, color: String, turn: float = 0.0) -> void:
	result.append({"pos": where, "dir": direction.normalized(), "speed": speed,
		"dmg_scale": damage_scale, "r": radius, "life": life, "color": color,
		"curve": turn})

static func owned_bullets(g, boss: Dictionary) -> int:
	var alive = 0
	for projectile in g.shots:
		if not bool(projectile.get("dead", false)) and int(projectile.get("boss_owner", -1)) == int(boss["id"]):
			alive += 1
	return alive

## The primary encounter pressure happens BETWEEN charges, not every 7 seconds.
## Spiral curtains, aimed interceptions and conditional stone crossfire form
## overlapping but dodgeable decisions. The shots themselves communicate danger;
## only committed body charges and fault pulses need ground-level tells.
static func barrage(g, boss: Dictionary, stage: int, dt: float) -> Array:
	var result: Array = []
	if str(boss.get("chonk_state", "")) == "stagger" or bool(boss.get("dead", false)):
		return result
	var capacity: int = mini(VOLLEY_BUFFER, OWNED_PROJECTILE_LIMIT - owned_bullets(g, boss))
	if capacity <= 0:
		return result
	var body: Vector2 = boss["pos"]
	var player: Vector2 = g.hero["pos"]
	var movement: Vector2 = Vector2(g.hero.get("vel", Vector2.ZERO))
	var state: String = str(boss.get("chonk_state", "approach"))
	# Sustained spiral, including during windup and charge. It does not turn
	# off simply because Chonkzilla is preparing another physical attack.
	var interval: float = 0.28 if stage == 0 else (0.23 if stage == 1 else 0.205)
	if state == "rush":
		interval *= 1.16
	boss["spiral_t"] = float(boss.get("spiral_t", 0.35)) - dt
	var pulses := 0
	while float(boss["spiral_t"]) <= 0.0 and pulses < 2 and result.size() < capacity:
		boss["spiral_t"] = float(boss["spiral_t"]) + interval
		boss["spiral_angle"] = float(boss.get("spiral_angle", 0.0)) + (0.40 if stage == 0 else (0.49 if stage == 1 else 0.55))
		var arms: int = 2 if stage < 2 else 3
		for arm in range(arms):
			if result.size() >= capacity:
				break
			var angle = float(boss["spiral_angle"]) + TAU * float(arm) / float(arms)
			var dir: Vector2 = Vector2.from_angle(angle)
			var bend: float = 0.0 if stage == 0 else (0.27 if (arm + int(boss.get("spiral_turn", 0))) % 2 == 0 else -0.27)
			if stage == 2:
				bend *= 1.5
			bullet(result, body + dir * (float(boss["r"]) + 6.0), dir,
				252.0 + 16.0 * stage, 0.32, 6.0, 3.5, "ffbd78", bend)
		pulses += 1
	boss["spiral_turn"] = int(boss.get("spiral_turn", 0)) + pulses
	# Precise aimed fans interrupt mindless circular running. Direction locks
	# when fired, never during travel; standing at max range isn't safe.
	boss["intercept_t"] = float(boss.get("intercept_t", 1.55)) - dt
	if float(boss["intercept_t"]) <= 0.0 and result.size() < capacity:
		boss["intercept_t"] = 2.15 if stage == 0 else (1.74 if stage == 1 else 1.43)
		var aim: Vector2 = player + movement * (0.22 + 0.05 * stage) - body
		if aim.length_squared() <= 1.0:
			aim = Vector2.DOWN
		var count: int = 3 if stage == 0 else (5 if stage == 1 else 7)
		for n in range(count):
			if result.size() >= capacity:
				break
			var spread = (float(n) - float(count - 1) * 0.5) * (0.205 if stage < 2 else 0.182)
			var direction: Vector2 = aim.normalized().rotated(spread)
			bullet(result, body + direction * (float(boss["r"]) + 8.0), direction,
				345.0 + stage * 29.0, 0.40, 6.5, 3.3, "fff0b8")
		# Rock anchors shoot IN from their own physical positions. Destroying
		# them stops this pressure and also removes useful stagger targets.
		if stage >= 1:
			for rock in stones(g, boss):
				if result.size() >= capacity:
					break
				var origin: Vector2 = rock["pos"]
				if origin.distance_to(player) < 135.0:
					continue
				var rock_dir: Vector2 = (player + movement * 0.16 - origin).normalized()
				bullet(result, origin, rock_dir, 285.0 + stage * 18.0,
					0.27, 6.0, 3.0, "ffc48d")
	# Escalating rings have a readable missing wedge toward the player's
	# locked bearing. They are traveling projectiles, not instant floor damage.
	boss["ring_t"] = float(boss.get("ring_t", 3.9)) - dt
	if stage >= 1 and float(boss["ring_t"]) <= 0.0 and result.size() < capacity:
		boss["ring_t"] = 3.8 if stage == 1 else 3.0
		var count: int = 15 if stage == 1 else 19
		var opening: float = (player - body).angle()
		var rotation: float = float(boss.get("ring_rotation", 0.0))
		boss["ring_rotation"] = rotation + 0.28
		# Never emit a chopped, asymmetrical ring when the projectile cap is near.
		# Reserve the full burst; a delayed ring is preferable to fake geometry.
		var needed := 0
		for n in range(count):
			var candidate_angle: float = rotation + TAU * float(n) / float(count)
			if absf(wrapf(candidate_angle - opening, -PI, PI)) >= (0.38 if stage == 1 else 0.34):
				needed += 1
		if result.size() + needed > capacity:
			boss["ring_t"] = 0.42
		else:
			for n in range(count):
				var angle: float = rotation + TAU * float(n) / float(count)
				if absf(wrapf(angle - opening, -PI, PI)) < (0.38 if stage == 1 else 0.34):
					continue
				var shot_dir: Vector2 = Vector2.from_angle(angle)
				bullet(result, body + shot_dir * (float(boss["r"]) + 10.0), shot_dir,
					228.0 + stage * 14.0, 0.34, 5.6, 3.55, "f88e69")
	# Never emit beyond the per-call cap. 
	return result

static func stones(g, boss: Dictionary) -> Array:
	var result: Array = []
	for mob in g.enemies:
		if not bool(mob.get("dead", false)) and int(mob.get("chonk_owner", -1)) == int(boss["id"]):
			result.append(mob)
	return result

static func setpiece(g, boss: Dictionary, stage: int, dt: float) -> void:
	boss["stone_t"] = float(boss.get("stone_t", 1.8)) - dt
	if float(boss["stone_t"]) > 0.0:
		return
	boss["stone_t"] = 10.5 if stage == 0 else (8.3 if stage == 1 else 7.2)
	var existing = stones(g, boss)
	var available = mini(STONE_LIMIT - existing.size(), 1 if stage == 0 else 2)
	if available <= 0:
		return
	# Put stones ON the likely path of the next rush, not around a remote edge.
	var player: Vector2 = g.hero["pos"]
	var forward: Vector2 = (player - boss["pos"]).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.DOWN
	var lateral: Vector2 = forward.orthogonal()
	for k in range(available):
		if g.enemies.size() >= g.enemy_cap():
			break
		var sign_side = 1.0 if (int(boss.get("stone_cycle", 0)) + k) % 2 == 0 else -1.0
		var center: Vector2 = boss["pos"] + forward * minf(260.0, boss["pos"].distance_to(player) * 0.58)
		var pos: Vector2 = center + lateral * sign_side * (160.0 if player.distance_to(boss["pos"]) < 320.0 else (56.0 if k == 0 else 115.0))
		pos.x = clampf(pos.x, -g.road_half + 65.0, g.road_half - 65.0)
		if pos.distance_to(player) < 100.0 or pos.distance_to(boss["pos"]) < float(boss["r"]) + 78.0:
			continue
		var rock = g.spawn_enemy("blob", pos, false, false)
		rock["chonk_pillar"] = true
		rock["chonk_owner"] = int(boss["id"])
		rock["summon"] = true
		rock["speed"] = 0.0
		rock["r"] = 37.0
		rock["mass"] = 10000.0
		rock["hp"] = maxf(12.0, float(boss["max_hp"]) * 0.038)
		rock["max_hp"] = float(rock["hp"])
		rock["dmg"] = 0.0
		rock["color"] = STONE_COLOR
		rock["vel"] = Vector2.ZERO
		rock["kb"] = Vector2.ZERO
		g.spawn_ring_fx(pos, STONE_COLOR, 42.0)
	boss["stone_cycle"] = int(boss.get("stone_cycle", 0)) + 1

static func start_rush(boss: Dictionary, player: Vector2, stage: int, speed: float) -> void:
	var distance = boss["pos"].distance_to(player)
	var lead: Vector2 = player
	var aim: Vector2 = lead - boss["pos"]
	if aim.length_squared() < 25.0:
		aim = Vector2.DOWN * 60.0
	boss["lock"] = lead
	boss["chonk_dir"] = aim.normalized()
	boss["chonk_speed"] = speed
	boss["chonk_charge_t"] = clampf((distance + 115.0) / speed, 0.55, 1.8)
	boss["chonk_state"] = "rush"
	boss["wind"] = 0.0

static func start_windup(g, boss: Dictionary, player: Vector2, stage: int) -> void:
	var lead: Vector2 = player + Vector2(g.hero.get("vel", Vector2.ZERO)) * (0.24 + stage * 0.06)
	lead.x = clampf(lead.x, -g.road_half + 65.0, g.road_half - 65.0)
	boss["lock"] = lead
	boss["chonk_state"] = "windup"
	boss["wind"] = 0.79 if stage == 0 else (0.70 if stage == 1 else 0.61)
	boss["chonk_wind_initial"] = float(boss["wind"])
	boss["chonk_combo"] = (0 if stage == 0 else (1 if stage == 1 else 2))
	g.sfx.play("boss_warn")

static func think(g, boss: Dictionary, direction: Vector2, distance: float, dt: float, stage: int) -> Vector2:
	var previous_stage: int = int(boss.get("chonk_last_stage", 0))
	if stage > previous_stage:
		boss["chonk_last_stage"] = stage
		g.spawn_ring_fx(boss["pos"], Color("ff8355") if stage == 2 else STONE_COLOR, 165.0)
		g.add_shake(10.0 if stage == 2 else 6.0)
		g.say(boss["pos"] + Vector2(0, -110),
			"EARTHBREAKER UNBOUND!" if stage == 2 else "THE ARMOR CRACKS!",
			Color("ff8355") if stage == 2 else Color("ffe0a5"), 23)
	var state = str(boss.get("chonk_state", "approach"))
	if state == "stagger":
		boss["boss_recover"] = maxf(0.0, float(boss.get("boss_recover", 0.0)) - dt)
		if float(boss["boss_recover"]) <= 0.0:
			boss["chonk_state"] = "approach"
			boss["cd"] = maxf(0.60, float(boss.get("cd", 0.0)))
		return Vector2.ZERO
	if state == "recover":
		boss["chonk_recover_t"] = float(boss.get("chonk_recover_t", 0.0)) - dt
		if float(boss["chonk_recover_t"]) <= 0.0:
			if int(boss.get("chonk_combo", 0)) > 0:
				var remaining: int = int(boss["chonk_combo"]) - 1
				start_windup(g, boss, g.hero["pos"], stage)
				boss["chonk_combo"] = remaining
			else:
				boss["chonk_state"] = "approach"
				boss["cd"] = 0.26 if stage == 2 else (0.43 if stage == 1 else 0.68)
		return Vector2.ZERO
	if state == "windup":
		boss["wind"] = maxf(0.0, float(boss["wind"]) - dt)
		if float(boss["wind"]) <= 0.0:
			start_rush(boss, boss["lock"], stage, 490.0 + 62.0 * stage)
		return Vector2.ZERO
	if state == "rush":
		boss["chonk_charge_t"] = maxf(0.0, float(boss.get("chonk_charge_t", 0.0)) - dt)
		return Vector2.ZERO
	if float(boss.get("cd", 0.0)) <= 0.0:
		start_windup(g, boss, g.hero["pos"], stage)
		return Vector2.ZERO
	# The old slow pursuit was trivially beaten by holding a direction.
	# Chonkzilla closes distance while firing; the rush remains committed.
	return direction * (5.3 if distance > 430.0 else (2.8 if distance > 280.0 else 1.45))

static func fault(g, boss: Dictionary, a: Vector2, b: Vector2, stage: int) -> void:
	var existing = 0
	for item in g.delayed:
		if str(item.get("fn", "")) == "chonk_fault" and int(item.get("owner", -1)) == int(boss["id"]):
			existing += 1
	if existing >= FAULT_LIMIT or g.delayed.size() >= 120:
		return
	a.x = clampf(a.x, -g.road_half + 25.0, g.road_half - 25.0)
	b.x = clampf(b.x, -g.road_half + 25.0, g.road_half - 25.0)
	var duration = 3.35 + float(stage) * 0.55
	g.delayed.append({"fn": "chonk_fault", "owner": int(boss["id"]), "pos": (a + b) * 0.5,
		"a": a, "b": b, "tele": 20.0, "color": FAULT_COLOR,
		"arm": 0.78, "pulse": 0.78, "t": duration, "life": duration,
		"dmg": float(boss["dmg"]) * 0.56, "stage": stage})

static func quake(g, boss: Dictionary, stage: int) -> void:
	var at: Vector2 = boss["pos"]
	var travel: Vector2 = Vector2(boss.get("chonk_dir", Vector2.DOWN)).normalized()
	if travel.length_squared() < 0.01:
		travel = Vector2.DOWN
	# Intersecting cracks persist and PULSE, instead of a whole-room hit.
	var perpendicular: Vector2 = travel.orthogonal()
	fault(g, boss, at - perpendicular * 230.0, at + perpendicular * 230.0, stage)
	fault(g, boss, at - travel * 110.0, at + travel * (255.0 + stage * 38.0), stage)
	if stage >= 2:
		fault(g, boss, at + (perpendicular - travel).normalized() * 190.0,
			at + (travel - perpendicular).normalized() * 245.0, stage)

static func finish_rush(g, boss: Dictionary, collision: bool, rock: Dictionary = {}) -> void:
	if str(boss.get("chonk_state", "")) != "rush":
		return
	boss["chonk_charge_t"] = 0.0
	boss["chonk_state"] = "recover"
	boss["chonk_recover_t"] = 0.30 if int(boss.get("chonk_combo", 0)) > 0 else 0.49
	boss["vel"] = Vector2.ZERO
	quake(g, boss, 0 if float(boss.get("max_hp", 1.0)) <= 0.0 else (2 if float(boss["hp"]) / float(boss["max_hp"]) <= 0.32 else (1 if float(boss["hp"]) / float(boss["max_hp"]) <= 0.65 else 0)))
	g.spawn_ring_fx(boss["pos"], STONE_COLOR, 110.0)
	g.add_shake(8.0)
	if collision:
		if not rock.is_empty():
			rock["dead"] = true
		boss["chonk_state"] = "stagger"
		boss["chonk_combo"] = 0
		boss["boss_recover"] = 2.15
		# Armor-breaking collision is a skill reward, never lethal by itself.
		boss["hp"] = maxf(1.0, float(boss["hp"]) - float(boss["max_hp"]) * 0.07)
		g.spawn_ring_fx(boss["pos"], Color("ffe79b"), 150.0)
		g.say(boss["pos"] + Vector2(0, -110), "ARMOR SHATTERED!", Color("ffe79b"), 22)
	else:
		# A miss still exposes Chonkzilla briefly; an obstacle crash is far better.
		boss["boss_recover"] = 0.0

static func after_motion(g, boss: Dictionary, before: Vector2) -> void:
	if str(boss.get("chonk_state", "")) != "rush":
		return
	var at: Vector2 = boss["pos"]
	# The committed rush has a continuous sweep to avoid tunneling through stone.
	for rock in stones(g, boss):
		var radius = float(boss["r"]) + float(rock["r"]) * 0.72
		if distance_to_segment(before, at, rock["pos"]) < radius:
			finish_rush(g, boss, true, rock)
			return
	if absf(at.x) >= g.road_half - float(boss["r"]) - 1.0:
		finish_rush(g, boss, true)
		return
	if float(boss.get("chonk_charge_t", 0.0)) <= 0.0:
		finish_rush(g, boss, false)

static func distance_to_segment(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var portion: float = clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	return (a + ab * portion).distance_to(p)
