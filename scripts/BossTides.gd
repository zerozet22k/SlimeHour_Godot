extends RefCounted
## Boss escalation on top of BossFight's movesets:
##   * TIDES: each boss's own full-screen wave pattern, thrown between attacks
##     from phase 2 (every attack in the final phase). Always leaves a gap.
##   * HARD MODE: SHADOW ECHO (phase 2+: every boss bullet is repeated,
##     mirrored across the arena) and DESPERATION (at 15% HP: 7s of
##     invulnerable survival barrage).
##   * The attacks of the two late bosses, Storm Titan and Hive Empress.

static func BF():
	return load("res://scripts/BossFight.gd")

const NEW_ATTACKS = ["thunder_lattice", "chain_bolts", "storm_pillars", "tempest_wall", "eye_of_storm",
	"honeycomb", "stinger_volley", "drone_swarm", "royal_jelly", "hive_storm"]

# ================================================================= tides
const TIDE_NAMES = {"heli": "STRAFE CURTAIN", "chonkzilla": "SHOCKWAVE", "necro": "SKULL CURTAIN",
	"kingblob": "JELLY RAIN", "coilqueen": "SERPENT TIDE", "glassoracle": "PRISM CROSS",
	"voidweaver": "SPIRAL ARMS", "dreadengine": "CONVEYOR", "stormtitan": "LIGHTNING SWEEP", "hiveempress": "HONEY FLOOD"}

## Throw this boss's tide: `waves` timed waves, each one a full-width pattern.
static func throw(g, e: Dictionary, stage: int) -> void:
	var kind := str(e["kind"])
	if not TIDE_NAMES.has(kind):
		return
	var waves: int = 2 + stage + (1 if int(g.sector) >= 30 else 0)
	for w in range(waves):
		BF().event(g, e, "bf_tide", e["pos"], 0.35 + 0.75 * float(w), {"wave": w, "stage": stage})
	if kind != "chonkzilla":
		BF().event(g, e, "bf_tide", e["pos"], 0.35 + 0.75 * float(waves), {"wave": -1, "stage": stage})
	g.say(Vector2(e["pos"]) + Vector2(0, -float(e["r"]) - 52.0), str(TIDE_NAMES[kind]) + "!", Color(BF().PALETTE.get(kind, "ffffff")).lightened(0.3), 22)

## Bullets every `step` px across [left, right], skipping a `gap`-wide hole.
## A spot on the far side of the road from x: at least ~220 px away.
static func away_x(x: float, left: float, right: float) -> float:
	var cx := (left + right) * 0.5
	if x < cx:
		return randf_range(minf(right - 80.0, x + 220.0), right - 70.0)
	return randf_range(left + 70.0, maxf(left + 80.0, x - 220.0))

## The signature finisher every tide ends with: a dense ring from the boss
## with its gap turned away from you (Chonkzilla's shockwave, in each boss's
## own bullet shape).
const RING_SHAPE = {"heli": "rice", "chonkzilla": "orb", "necro": "skull", "kingblob": "big", "coilqueen": "rice",
	"glassoracle": "shard", "voidweaver": "orb", "dreadengine": "gear", "stormtitan": "shard", "hiveempress": "missile"}

static func finisher_ring(g, e: Dictionary, stage: int) -> void:
	var B = BF()
	var hero: Vector2 = g.hero["pos"]
	var gap_a: float = (hero - Vector2(e["pos"])).angle() + (0.9 if randf() < 0.5 else -0.9)
	var kind := str(e["kind"])
	B.ring(g, e, e["pos"], 46, 185.0 + 15.0 * stage, randf() * TAU, {"r": 7.0, "shape": str(RING_SHAPE.get(kind, "orb")),
		"color": Color(B.PALETTE_ALT.get(kind, "ffffff")), "life": 5.0}, gap_a, 0.32)

static func row_points(left: float, right: float, step: float, gap_x: float, gap: float) -> Array:
	var out: Array = []
	var x := left
	while x <= right:
		if absf(x - gap_x) > gap * 0.5:
			out.append(x)
		x += step
	return out

static func resolve_tide(g, e: Dictionary, item: Dictionary) -> void:
	var B = BF()
	var a: Dictionary = B.arena(g)
	var kind := str(e["kind"])
	var wave := int(item.get("wave", 0))
	var stage := int(item.get("stage", 0))
	var col := Color(B.PALETTE[kind])
	var alt := Color(B.PALETTE_ALT[kind])
	var hero: Vector2 = g.hero["pos"]
	var left: float = float(a["left"]) - 10.0
	var right: float = float(a["right"]) + 10.0
	var top: float = float(a["top"]) - 70.0
	var bottom: float = float(a["bottom"]) + 30.0
	# Like Chonkzilla's shockwave, the way out is AWAY from you: run for it.
	var gap_x: float = away_x(hero.x, left, right)
	var speed_k: float = 1.0 + 0.1 * float(stage)
	if wave < 0:
		finisher_ring(g, e, stage)
		return
	match kind:
		"heli":
			# A curtain of rounds sweeping down the road with one gap.
			for x in row_points(left, right, 22.0, gap_x, 96.0):
				B.fire(g, e, Vector2(x, top), Vector2.DOWN, 230.0 * speed_k, {"r": 5.0, "color": col if wave % 2 == 0 else alt, "life": 4.0})
		"chonkzilla":
			# Expanding shockwave rings out of the kaiju, gap turned away from you.
			var gap_a: float = (hero - Vector2(e["pos"])).angle() + (0.9 if wave % 2 == 0 else -0.9)
			B.ring(g, e, e["pos"], 46, 190.0 * speed_k, randf() * TAU, {"r": 7.0, "color": col if wave % 2 == 0 else alt, "life": 5.0}, gap_a, 0.32)
		"necro":
			# Falling columns of skulls that weave side to side.
			var x2 := left + (35.0 if wave % 2 == 0 else 0.0)
			while x2 <= right:
				if absf(x2 - gap_x) > 50.0:
					for k in range(2):
						B.fire(g, e, Vector2(x2, top - k * 40.0), Vector2.DOWN, 150.0 * speed_k, {"shape": "skull", "r": 6.0, "wave": 26.0, "color": col if k == 0 else alt, "life": 6.0})
				x2 += 52.0
		"kingblob":
			# Jelly blobs lobbed up from the King that rain back down everywhere.
			var count: int = int(float(26 + 6 * stage) * B.density(g))
			for i in range(count):
				var land_x: float = randf_range(left, right)
				if absf(land_x - gap_x) < 60.0:
					continue
				B.fire(g, e, Vector2(land_x, top - randf() * 140.0), Vector2.DOWN, 90.0, {"shape": "big", "r": 10.0, "grav": Vector2(0.0, 320.0), "color": col if i % 2 == 0 else alt, "life": 5.0})
		"coilqueen":
			# A serpent of venom slithering across the whole road from one side.
			var from_left: bool = wave % 2 == 0
			var gap_y: float = clampf(hero.y + (-1.0 if hero.y > (top + bottom) * 0.5 else 1.0) * randf_range(180.0, 260.0), top + 90.0, bottom - 60.0)
			var y := top
			while y <= bottom:
				if absf(y - gap_y) > 48.0:
					B.fire(g, e, Vector2(left if from_left else right, y), Vector2.RIGHT if from_left else Vector2.LEFT, 210.0 * speed_k,
						{"r": 6.0, "wave": 34.0, "color": col if int(y / 30.0) % 2 == 0 else alt, "life": 6.0})
				y += 22.0
		"glassoracle":
			# Two crystal walls crossing diagonally from the top corners.
			for side in [-1.0, 1.0]:
				var origin := Vector2(float(a["cx"]) - side * (float(a["half"]) + 40.0), top)
				var dir := Vector2(side, 1.0).normalized()
				var normal := dir.orthogonal()
				for k in range(-14, 15):
					var gap_k: int = roundi((gap_x - origin.x) * side / 34.0 * 0.7)
					if abs(k - clampi(gap_k, -12, 12)) <= 1:
						continue
					B.fire(g, e, origin + normal * float(k) * 34.0, dir, 200.0 * speed_k, {"shape": "shard", "r": 5.0, "color": col if side > 0.0 else alt, "life": 5.0})
		"voidweaver":
			# A burst of spiral arms that sweep the whole arena.
			var arms: int = 6 + stage
			for arm in range(arms):
				var base: float = float(wave) * 0.35 + TAU * float(arm) / float(arms)
				for k in range(6):
					var d := Vector2.from_angle(base + float(k) * 0.06)
					B.fire(g, e, Vector2(e["pos"]) + d * 30.0, d, (130.0 + 26.0 * k) * speed_k, {"turn": 0.5 if arm % 2 == 0 else -0.5, "r": 5.0, "color": col if arm % 2 == 0 else alt, "life": 6.0})
		"dreadengine":
			# Conveyor rows rolling in from both sides at different heights.
			for r in range(3):
				var y2: float = top + 80.0 + (float(r) + (0.5 if wave % 2 == 1 else 0.0)) * (bottom - top - 120.0) / 3.0
				var from_left2: bool = (r + wave) % 2 == 0
				var gap_x2: float = away_x(hero.x, left, right)
				for x3 in row_points(left, right, 28.0, gap_x2, 110.0):
					var start_x: float = left - (right - left) + (x3 - left) if from_left2 else right + (x3 - left)
					B.fire(g, e, Vector2(start_x, y2), Vector2.RIGHT if from_left2 else Vector2.LEFT, 260.0 * speed_k, {"shape": "boulder" if int(x3) % 5 == 0 else "orb", "r": 7.0, "color": col if from_left2 else alt, "life": 7.0})
		"stormtitan":
			# A horizontal lightning sweep, then sparks raining through it.
			var row_y: float = clampf(hero.y + (110.0 if wave % 2 == 0 else -110.0), top + 60.0, bottom - 40.0)
			B.line(g, e, Vector2(left, row_y), Vector2(right, row_y), 22.0, 0.75, 0.6, {"web": true})
			for x4 in row_points(left, right, 30.0, gap_x, 100.0):
				B.fire(g, e, Vector2(x4, top), Vector2.DOWN, 240.0 * speed_k, {"r": 5.0, "shape": "shard", "color": alt, "life": 4.0})
		"hiveempress":
			# A wall of honey flooding down with stingers zipping across it.
			for x5 in row_points(left, right, 22.0, gap_x, 100.0):
				B.fire(g, e, Vector2(x5, top), Vector2.DOWN, 180.0 * speed_k, {"shape": "big", "r": 7.0, "color": col, "life": 5.0})
			for side in [-1.0, 1.0]:
				var y3: float = clampf(hero.y + randf_range(-140.0, 40.0), top + 60.0, bottom - 40.0)
				B.fire(g, e, Vector2(float(a["cx"]) - side * (float(a["half"]) + 30.0), y3), Vector2(side, 0.0), 360.0, {"shape": "missile", "r": 6.0, "color": alt, "life": 4.0})

# ================================================================= hunter layer
## Chonkzilla is the bar: nearly everything it does hunts you. Every other
## boss keeps dropping its own hazard where you are heading during every
## attack, faster each phase and faster again during the attacks that would
## otherwise only spray around the boss or straight at you.
const HUNT_INTERVAL = {"heli": 1.15, "necro": 1.0, "kingblob": 1.0, "coilqueen": 1.0, "glassoracle": 0.95,
	"voidweaver": 1.0, "dreadengine": 0.95, "stormtitan": 0.9, "hiveempress": 0.85}
const SOFT_ATTACKS = ["minigun_sweep", "missile_salvo", "jelly_fountain", "royal_decree", "summon_court",
	"serpent_stream", "prism_lasers", "shard_bloom", "hall_of_mirrors", "void_pinwheel", "rift_crossfire",
	"furnace_breath", "assembly_line", "chain_bolts", "stinger_volley", "drone_swarm", "raise_wards", "skull_waltz", "eye_of_storm"]

static func hunt(g, e: Dictionary, attack: String, stage: int, dt: float) -> void:
	var kind := str(e["kind"])
	if not HUNT_INTERVAL.has(kind):
		return
	var B = BF()
	var interval: float = float(HUNT_INTERVAL[kind]) * (1.0 - 0.15 * float(stage)) * (0.6 if attack in SOFT_ATTACKS else 1.0)
	for _i in range(B.every(e, "hunt_layer", interval, dt, 0.6)):
		var at: Vector2 = B.lead(g, 0.7) + Vector2(randf_range(-60.0, 60.0), randf_range(-45.0, 45.0))
		match kind:
			"heli":
				B.circle(g, e, at, 60.0, 0.85, 0.6, {"bomb": true, "burst": 6})
			"necro":
				B.grave_hand(g, e, stage)
			"kingblob":
				B.circle(g, e, at, 74.0, 0.85, 0.65, {"burst": 10, "burst_shape": "big"})
			"coilqueen":
				B.circle(g, e, at, 64.0, 0.8, 0.6, {"burst": 8, "burst_shape": "rice"})
				load("res://scripts/EnemyIdentity.gd").place(g, "acid", at, 46.0, float(e["dmg"]) * 0.25, 3.0, 0.85)
			"glassoracle":
				var hist: Array = e.get("bf_hist", [])
				var past: Vector2 = hist[maxi(0, hist.size() - 3)] if not hist.is_empty() else at
				B.circle(g, e, past, 62.0, 0.65, 0.6, {"burst": 10, "burst_shape": "shard"})
			"voidweaver":
				B.circle(g, e, at, 66.0, 0.8, 0.6, {"blink": true, "burst": 10})
			"dreadengine":
				B.circle(g, e, at, 64.0, 0.9, 0.65, {"mortar": true, "burst": 8, "burst_shape": "gear"})
			"stormtitan":
				var a: Dictionary = B.arena(g)
				B.line(g, e, Vector2(at.x, float(a["top"]) - 40.0), Vector2(at.x, float(a["bottom"]) + 40.0), 30.0, 0.65, 0.6, {"piston": true})
			"hiveempress":
				B.circle(g, e, at, 58.0, 0.75, 0.6, {"burst": 8, "burst_shape": "missile"})

# ================================================================= hard mode
## SHADOW ECHO: a hard-mode boss in phase 2+ repeats each bullet, mirrored
## across the arena, a moment later.
static func echo_bullet(g, e: Dictionary, pos: Vector2, dir: Vector2, speed: float, o: Dictionary) -> void:
	if not g.hard_mode or int(e.get("bf_phase", 0)) < 1 or o.has("echo") or g.shots.size() > 300 + 12 * int(g.sector):
		return
	var a: Dictionary = BF().arena(g)
	var cx: float = float(a["cx"])
	var copy: Dictionary = o.duplicate()
	copy["echo"] = true
	copy["color"] = Color(BF().PALETTE_ALT.get(str(e["kind"]), "ffffff"))
	g.delayed.append({"fn": "bf_mirror", "pos": Vector2(2.0 * cx - pos.x, pos.y), "t": 0.35, "life": 0.35,
		"owner": int(e["id"]), "boss": e, "dir": Vector2(-dir.x, dir.y), "speed": speed, "o": copy})

## DESPERATION: at 15% HP a hard-mode boss turns invulnerable for 7 seconds
## and throws everything it has. Survive it, then finish the boss.
const DESPERATION_TIME := 7.0

static func check_desperation(g, e: Dictionary) -> bool:
	if not g.hard_mode or bool(e.get("bf_desperate_done", false)):
		return false
	if float(e["hp"]) / maxf(1.0, float(e["max_hp"])) > 0.15:
		return false
	e["bf_desperate_done"] = true
	e["bf_state"] = "desperate"
	e["bf_t"] = DESPERATION_TIME
	e["bfe"] = {}
	e["bf_ang"] = 0.0
	var col := Color(BF().PALETTE[str(e["kind"])])
	g.flash_screen(Color("ff2a3a"), 0.35)
	g.add_shake(16.0)
	g.banner("DESPERATION", "survive 7 seconds", 2.0)
	g.say(Vector2(e["pos"]) + Vector2(0, -float(e["r"]) - 44.0), "DESPERATION!", col.lightened(0.3), 34)
	g.sfx.play("horn")
	return true

static func desperate_step(g, e: Dictionary, dt: float) -> Vector2:
	var B = BF()
	var me: Vector2 = e["pos"]
	var col := Color(B.PALETTE[str(e["kind"])])
	var alt := Color(B.PALETTE_ALT[str(e["kind"])])
	var T: float = DESPERATION_TIME - float(e["bf_t"])
	for _i in range(B.every(e, "dspin", 0.13, dt)):
		e["bf_ang"] = float(e["bf_ang"]) + 0.23
		for arm in range(3):
			var d := Vector2.from_angle(float(e["bf_ang"]) + TAU * float(arm) / 3.0)
			B.fire(g, e, me + d * 34.0, d, 175.0, {"r": 5.0, "turn": 0.35, "color": col if arm % 2 == 0 else alt, "life": 6.0, "echo": true})
	for _i in range(B.every(e, "dtide", 2.3, dt, 0.6)):
		throw(g, e, 2)
	for _i in range(B.every(e, "dring", 2.3, dt, 1.2)):
		B.ring(g, e, me, 30, 150.0, randf() * TAU, {"r": 8.0, "shape": "big", "color": alt, "echo": true}, (Vector2(g.hero["pos"]) - me).angle() + PI, 0.4)
	return B.seek(e, B.home_spot(g, e), 0.9 if T > 0.5 else 1.4)

# ================================================================= new bosses
static func begin(g, e: Dictionary, attack: String, stage: int) -> void:
	var B = BF()
	var a: Dictionary = B.arena(g)
	match attack:
		"thunder_lattice":
			# Forked lightning: jagged bolts crawl from the Titan to where you are
			# heading, splitting into branches at every joint.
			var bolts: int = 3 + stage
			for b in range(bolts):
				var t0: float = 0.8 + float(b) * 0.55
				var from: Vector2 = e["pos"]
				var target: Vector2 = B.lead(g, 0.6 + 0.2 * float(b)) + Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))
				var joints: int = 4
				var prev: Vector2 = from
				for k in range(1, joints + 1):
					var u: float = float(k) / float(joints)
					var side: Vector2 = (target - from).orthogonal().normalized() * randf_range(-90.0, 90.0) * (1.0 - u)
					var p: Vector2 = from.lerp(target, u) + side
					B.line(g, e, prev, p, 13.0, t0 + 0.06 * k, 0.55, {"web": true})
					if k < joints:
						var fork: Vector2 = p + (p - prev).rotated(randf_range(0.7, 1.2) * (1.0 if randf() < 0.5 else -1.0)).normalized() * 220.0
						B.line(g, e, p, fork, 10.0, t0 + 0.06 * k + 0.1, 0.45, {"web": true})
					prev = p
				B.circle(g, e, target, 70.0, t0 + 0.35, 0.6, {"burst": 10})
			e["bf_len"] = 0.8 + float(bolts) * 0.55 + 0.6
		"honeycomb":
			# Honeycomb flowers bloom where you stand: a centre cell, then its six
			# neighbours a beat later, chasing you round the road.
			var blooms: int = 3 + stage
			for bl in range(blooms):
				var t0: float = 0.9 + float(bl) * 0.75
				var c: Vector2 = B.lead(g, 0.5 + 0.75 * float(bl))
				B.circle(g, e, c, 58.0, t0, 0.7, {"burst": 6})
				for k in range(6):
					B.circle(g, e, c + Vector2.from_angle(TAU * float(k) / 6.0 + PI / 6.0) * 112.0, 58.0, t0 + 0.4, 0.6)
			e["bf_len"] = 0.9 + float(blooms) * 0.75 + 0.6
		"drone_swarm":
			for i in range(3 + stage):
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var pos := Vector2(float(a["cx"]) + side * (float(a["half"]) - 40.0), float(a["top"]) + 40.0 + float(i) * 60.0)
				var m = B.spawn_minion(g, e, "mini", pos, "drone", 1.2, false)
				if m != null:
					m["speed"] = float(m["speed"]) * 1.3
			B.ring(g, e, e["pos"], 24, 170.0, randf() * TAU, {"r": 6.0, "shape": "missile"})
		"royal_jelly":
			var orbs: int = 3 + stage
			for o in range(orbs):
				var d := Vector2.from_angle(PI * 0.2 + PI * 0.6 * float(o) / float(maxi(1, orbs - 1)) + randf_range(-0.2, 0.2))
				B.fire(g, e, Vector2(e["pos"]) + d * float(e["r"]), d, 190.0,
					{"shape": "big", "r": 26.0, "dmg": 0.55, "life": 6.0,
					"box": [float(a["left"]), float(a["right"]), float(a["top"]) - 60.0, float(a["bottom"]) + 40.0]})

static func step(g, e: Dictionary, attack: String, stage: int, T: float, dt: float) -> void:
	var B = BF()
	var me: Vector2 = e["pos"]
	var a: Dictionary = B.arena(g)
	var hero: Vector2 = g.hero["pos"]
	var col := Color(B.PALETTE[str(e["kind"])])
	var alt := Color(B.PALETTE_ALT[str(e["kind"])])
	match attack:
		"chain_bolts":
			# Bolts that burst into crackling rings where they stop.
			for _i in range(B.every(e, "bolt", 0.38 - 0.06 * stage, dt)):
				B.fan(g, e, me, B.aim_from(g, me), 3 + stage, 0.55, 300.0,
					{"r": 6.0, "shape": "shard", "color": col, "life": 0.9, "split": 6, "split_speed": 150.0, "split_shape": "orb"})
		"storm_pillars":
			# Lightning columns that stalk you: each one lands where you are heading.
			for _i in range(B.every(e, "pillar", 0.42 - 0.05 * stage, dt, 0.1)):
				var x: float = B.lead(g, 0.5).x
				B.line(g, e, Vector2(x, float(a["top"]) - 40.0), Vector2(x, float(a["bottom"]) + 40.0), 34.0, 0.62, 0.65, {"piston": true})
				if stage >= 1:
					var y: float = B.lead(g, 0.5).y
					B.line(g, e, Vector2(float(a["left"]), y), Vector2(float(a["right"]), y), 22.0, 0.75, 0.55, {"web": true})
		"tempest_wall":
			for _i in range(B.every(e, "wall", 0.75, dt, 0.2)):
				var gap_x: float = clampf(hero.x + randf_range(-170.0, 170.0), float(a["left"]) + 70.0, float(a["right"]) - 70.0)
				for x in row_points(float(a["left"]), float(a["right"]), 32.0, gap_x, 100.0):
					B.fire(g, e, Vector2(x, float(a["top"]) - 60.0), Vector2.DOWN, 210.0, {"r": 5.0, "wave": 18.0, "color": col, "life": 4.5})
			for _i in range(B.every(e, "gust", 0.5, dt)):
				for side in [-1.0, 1.0]:
					var y2: float = randf_range(float(a["top"]), float(a["bottom"]))
					B.fire(g, e, Vector2(float(a["cx"]) - side * (float(a["half"]) + 30.0), y2), Vector2(side, 0.0), 280.0, {"r": 5.0, "shape": "shard", "color": alt, "life": 4.0})
		"eye_of_storm":
			for _i in range(B.every(e, "eye", 0.1, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.16
				for arm in range(3):
					var d := Vector2.from_angle(float(e["bf_ang"]) + TAU * float(arm) / 3.0)
					B.fire(g, e, me + d * 34.0, d, 185.0, {"r": 5.0, "turn": -0.4, "color": col if arm == 0 else alt, "life": 6.0})
			for _i in range(B.every(e, "eyering", 1.4, dt, 0.7)):
				B.ring(g, e, me, 28, 140.0, randf() * TAU, {"r": 7.0, "shape": "big", "color": alt}, (hero - me).angle() + PI, 0.35)
			for _i in range(B.every(e, "eyestrike", 0.9, dt, 0.4)):
				B.circle(g, e, B.lead(g, 0.5), 70.0, 0.7, 0.75)
		"stinger_volley":
			for _i in range(B.every(e, "sting", 0.24 - 0.03 * stage, dt)):
				B.fan(g, e, me, B.aim_from(g, me), 3, 0.5, 260.0,
					{"shape": "missile", "r": 5.0, "color": alt, "homing": 1.4, "homing_t": 0.7, "accel": 160.0, "max": 460.0, "life": 3.5})
		"hive_storm":
			# Honey pours from above while the Empress spins stinger rings.
			for _i in range(B.every(e, "rain", 0.12, dt)):
				var x2: float = randf_range(float(a["left"]), float(a["right"]))
				if absf(x2 - hero.x) > 40.0 or randf() < 0.35:
					B.fire(g, e, Vector2(x2, float(a["top"]) - 60.0), Vector2.DOWN, 120.0, {"shape": "big", "r": 8.0, "grav": Vector2(0.0, 220.0), "color": col, "life": 5.0})
			for _i in range(B.every(e, "hivering", 0.85, dt, 0.3)):
				B.ring(g, e, me, 20, 200.0, T * 0.9, {"shape": "missile", "r": 5.0, "color": alt})
			for _i in range(B.every(e, "hivesting", 0.45, dt)):
				B.fan(g, e, me, B.aim_from(g, me), 5, 0.7, 280.0, {"shape": "shard", "r": 5.0, "color": alt})
