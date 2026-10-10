extends RefCounted
## Boss fight director. Every boss runs ONE named attack at a time:
##   rest -> tell (boss winds up, attack name shown) -> attack -> rest
## Attacks are hand-authored bullet-hell patterns, map-wide ground hazards and
## each boss's signature mechanic. Each health phase (65% / 32%) swaps in a
## harder moveset, opening with that phase's new attack; the final phase leads
## with an ultimate. Phase changes are a short invulnerable transition that
## clears the boss's bullets so the new pattern always starts readable.
##
## Fairness rules every attack follows:
##  * Ground hazards lock their position when warned and never track.
##  * Map-wide hazards always leave safe cells / lanes / corridors.
##  * Bullet rings leave room to slip between bullets or a deliberate gap.
##  * Bullets and hazards are owned by the boss and vanish with it.

const OWNED_CAP := 210
const HAZARD_CAP := 96
const TRANSITION_TIME := 1.5

## Body / bullet colour per boss.
const PALETTE = {
	"chonkzilla": "ff8a5c", "heli": "ffc14d", "necro": "c79bff", "kingblob": "ff7fb8",
	"coilqueen": "5ff0a8", "glassoracle": "7fe8ff", "voidweaver": "b48cff", "dreadengine": "ffaa55",
}
## Second bullet colour, used to separate interleaved patterns.
const PALETTE_ALT = {
	"chonkzilla": "ffd36b", "heli": "ff7a4d", "necro": "9dffcf", "kingblob": "ffd0ea",
	"coilqueen": "d8ff6b", "glassoracle": "e6d0ff", "voidweaver": "ff7ad9", "dreadengine": "ff6a3d",
}

## Movesets per phase. The first attack of phases 2 and 3 is the one the
## phase introduces, so a phase change is immediately felt.
const MOVES = {
	"chonkzilla": [
		["quake_slam", "goo_geyser", "boulder_toss"],
		["meteor_shower", "quake_slam", "belly_roll", "goo_geyser", "boulder_toss"],
		["kaiju_rage", "belly_roll", "meteor_shower", "quake_slam", "goo_geyser"]],
	"heli": [
		["strafe_run", "missile_salvo", "minigun_sweep"],
		["carpet_bomb", "strafe_run", "missile_salvo", "minigun_sweep"],
		["danger_close", "carpet_bomb", "minigun_sweep", "missile_salvo", "strafe_run"]],
	"necro": [
		["raise_wards", "skull_waltz", "soul_harvest"],
		["grave_field", "raise_wards", "skull_waltz", "soul_harvest"],
		["death_bloom", "grave_field", "raise_wards", "soul_harvest", "skull_waltz"]],
	"kingblob": [
		["royal_slam", "jelly_juggle", "summon_court"],
		["crown_rain", "royal_slam", "jelly_juggle", "summon_court"],
		["royal_decree", "crown_rain", "royal_slam", "jelly_juggle"]],
	"coilqueen": [
		["burrow_strike", "serpent_stream", "venom_squeeze"],
		["constrict", "burrow_strike", "serpent_stream", "venom_squeeze"],
		["hydra_frenzy", "constrict", "burrow_strike", "serpent_stream"]],
	"glassoracle": [
		["hall_of_mirrors", "prism_lasers", "shard_bloom"],
		["echo_volley", "hall_of_mirrors", "prism_lasers", "shard_bloom"],
		["kaleidoscope", "prism_lasers", "hall_of_mirrors", "shard_bloom", "echo_volley"]],
	"voidweaver": [
		["rift_crossfire", "void_pinwheel", "blink_strike"],
		["web_lattice", "rift_crossfire", "gravity_well", "void_pinwheel", "blink_strike"],
		["event_horizon", "web_lattice", "blink_strike", "rift_crossfire", "void_pinwheel"]],
	"dreadengine": [
		["piston_bank", "gear_grinder", "furnace_breath"],
		["mortar_barrage", "piston_bank", "gear_grinder", "furnace_breath"],
		["overdrive", "piston_bank", "mortar_barrage", "gear_grinder", "furnace_breath"]],
}

## [display name, tell seconds, base duration, rest after]
const ATTACKS = {
	"quake_slam": ["QUAKE SLAM", 0.75, 1.5, 0.8],
	"goo_geyser": ["GOO GEYSER", 0.65, 3.4, 0.9],
	"boulder_toss": ["BOULDER TOSS", 0.6, 2.4, 0.8],
	"meteor_shower": ["METEOR SHOWER", 0.8, 3.9, 0.9],
	"belly_roll": ["BELLY ROLL", 0.75, 1.3, 0.4],
	"kaiju_rage": ["KAIJU RAGE", 1.0, 6.0, 1.0],
	"strafe_run": ["STRAFING RUN", 0.9, 2.3, 0.6],
	"missile_salvo": ["MISSILE SALVO", 0.6, 2.3, 0.8],
	"minigun_sweep": ["MINIGUN SWEEP", 0.75, 2.6, 0.8],
	"carpet_bomb": ["CARPET BOMBING", 0.8, 3.5, 0.9],
	"danger_close": ["DANGER CLOSE", 1.0, 5.6, 1.0],
	"raise_wards": ["RAISE THE DEAD", 0.8, 1.6, 0.6],
	"skull_waltz": ["SKULL WALTZ", 0.6, 3.6, 0.9],
	"soul_harvest": ["SOUL HARVEST", 0.5, 3.4, 0.8],
	"grave_field": ["GRAVE FIELD", 0.8, 3.4, 0.9],
	"death_bloom": ["DEATH BLOOM", 1.0, 6.0, 1.0],
	"royal_slam": ["ROYAL BELLY FLOP", 0.7, 1.7, 0.8],
	"jelly_juggle": ["JELLY JUGGLE", 0.6, 2.8, 0.9],
	"summon_court": ["SUMMON THE COURT", 0.6, 3.0, 0.7],
	"crown_rain": ["CROWN JEWEL RAIN", 0.8, 4.2, 0.9],
	"royal_decree": ["ROYAL DECREE", 1.0, 6.0, 1.0],
	"burrow_strike": ["BURROW STRIKE", 0.5, 1.3, 0.7],
	"serpent_stream": ["SERPENT STREAM", 0.6, 3.0, 0.9],
	"venom_squeeze": ["VENOM SQUEEZE", 0.6, 2.4, 0.8],
	"constrict": ["CONSTRICTION", 0.8, 4.0, 0.9],
	"hydra_frenzy": ["HYDRA FRENZY", 1.0, 6.0, 1.0],
	"hall_of_mirrors": ["HALL OF MIRRORS", 0.6, 1.4, 0.6],
	"prism_lasers": ["PRISM LASERS", 0.6, 3.4, 0.9],
	"shard_bloom": ["SHARD BLOOM", 0.5, 2.8, 0.9],
	"echo_volley": ["ECHO VOLLEY", 0.6, 2.6, 0.8],
	"kaleidoscope": ["KALEIDOSCOPE", 1.0, 6.5, 1.0],
	"rift_crossfire": ["RIFT CROSSFIRE", 0.5, 2.8, 0.8],
	"void_pinwheel": ["VOID PINWHEEL", 0.6, 3.6, 0.9],
	"blink_strike": ["BLINK STRIKE", 0.3, 1.0, 0.8],
	"web_lattice": ["WEB LATTICE", 0.8, 3.3, 0.9],
	"gravity_well": ["GRAVITY WELL", 0.7, 4.0, 0.9],
	"event_horizon": ["EVENT HORIZON", 1.0, 6.5, 1.0],
	"piston_bank": ["PISTON BANK", 0.8, 2.8, 0.8],
	"gear_grinder": ["GEAR GRINDER", 0.7, 3.2, 0.8],
	"furnace_breath": ["FURNACE BREATH", 0.6, 2.6, 0.8],
	"mortar_barrage": ["MORTAR BARRAGE", 0.6, 3.0, 0.8],
	"overdrive": ["OVERDRIVE", 1.0, 6.5, 0.4],
}

const HEAT_COST = {"piston_bank": 30.0, "gear_grinder": 25.0, "furnace_breath": 30.0,
	"mortar_barrage": 25.0, "overdrive": 100.0}

static var _combat = null

static func C():
	if _combat == null:
		_combat = load("res://scripts/Combat.gd")
	return _combat

# ================================================================= queries
static func is_boss_kind(kind: String) -> bool:
	return MOVES.has(kind)

static func stage_of(e: Dictionary) -> int:
	var ratio: float = float(e.get("hp", 0.0)) / maxf(1.0, float(e.get("max_hp", 1.0)))
	if ratio <= 0.32:
		return 2
	if ratio <= 0.65:
		return 1
	return 0

static func attack_label(e: Dictionary) -> String:
	var state: String = str(e.get("bf_state", ""))
	if state == "transition":
		return "FINAL PHASE" if int(e.get("bf_phase", 0)) >= 2 else "PHASE 2"
	if state == "vent":
		return "CORE EXPOSED"
	if state in ["tell", "attack"]:
		return str(ATTACKS[str(e["bf_attack"])][0])
	return ""

static func tell_progress(e: Dictionary) -> float:
	if str(e.get("bf_state", "")) != "tell":
		return 0.0
	var tell: float = float(ATTACKS[str(e["bf_attack"])][1])
	return clampf(1.0 - float(e["bf_t"]) / maxf(0.01, tell), 0.0, 1.0)

static func minions(g, e: Dictionary, role: String = "") -> Array:
	var result: Array = []
	for m in g.enemies:
		if bool(m.get("dead", false)) or int(m.get("minion_owner", -1)) != int(e["id"]):
			continue
		if role == "" or str(m.get("minion_role", "")) == role:
			result.append(m)
	return result

static func owned_hazards(g, e: Dictionary) -> int:
	var n := 0
	for d in g.delayed:
		if int(d.get("owner", -1)) == int(e["id"]):
			n += 1
	return n

## Bosses ignore contact while airborne, burrowed or blinked out.
static func contact_safe(e: Dictionary) -> bool:
	return bool(e.get("bf_air", false)) or bool(e.get("burrowing", false)) or bool(e.get("bf_vanish", false))

## Armour and vulnerability windows. Shared by bullets, AoE and DoT.
static func damage_factor(g, e: Dictionary) -> float:
	if str(e.get("bf_state", "")) == "transition":
		return 0.0
	match str(e["kind"]):
		"chonkzilla":
			return 1.7 if float(e.get("bf_dizzy", 0.0)) > 0.0 else 1.0
		"glassoracle":
			return 0.45 if not minions(g, e, "mirror").is_empty() else 1.0
		"dreadengine":
			if str(e.get("bf_state", "")) == "vent":
				return 1.8
			return 0.6 if not minions(g, e, "pod").is_empty() else 0.9
	return 1.0

# ================================================================= arena helpers
## The fight happens in the visible part of the road around the player.
static func arena(g) -> Dictionary:
	var hero: Vector2 = g.hero["pos"]
	var visible_half: float = 360.0 if bool(g.portrait) else float(g.landscape_width) * 0.5
	var half: float = minf(float(g.road_half) - 30.0, visible_half - 70.0)
	var cx: float = clampf(float(g.cam_x), -float(g.road_half) + half + 30.0, float(g.road_half) - half - 30.0)
	return {"cx": cx, "half": half, "y": hero.y, "top": hero.y - 330.0, "bottom": hero.y + 215.0,
		"left": cx - half, "right": cx + half}

static func lead(g, seconds: float) -> Vector2:
	var p: Vector2 = g.hero["pos"] + Vector2(g.hero.get("vel", Vector2.ZERO)) * seconds
	var a: Dictionary = arena(g)
	p.x = clampf(p.x, float(a["left"]) + 20.0, float(a["right"]) - 20.0)
	return p

static func aim_from(g, from: Vector2) -> Vector2:
	var v: Vector2 = g.hero["pos"] - from
	return v.normalized() if v.length_squared() > 1.0 else Vector2.DOWN

static func home_spot(g, e: Dictionary) -> Vector2:
	var a: Dictionary = arena(g)
	var sway: float = sin(float(e["t"]) * 0.45 + float(e.get("phase", 0.0))) * float(a["half"]) * 0.42
	return Vector2(float(a["cx"]) + sway, float(a["y"]) - 290.0)

## Desired-velocity helper toward a point, scaled so slow bosses still arrive.
static func seek(e: Dictionary, target: Vector2, urgency: float = 1.0) -> Vector2:
	var off: Vector2 = target - e["pos"]
	var want: float = clampf(off.length() / 70.0, 0.0, 1.6) * urgency
	return off.normalized() * want if off.length() > 4.0 else Vector2.ZERO

## Countdown emitter: returns how many times it fired this frame.
static func every(e: Dictionary, key: String, interval: float, dt: float, first: float = 0.0) -> int:
	var timers: Dictionary = e["bfe"]
	var t: float = float(timers.get(key, first)) - dt
	var n := 0
	while t <= 0.0 and n < 3:
		t += interval
		n += 1
	timers[key] = t
	return n

# ================================================================= spawning
static func boss_name(g, e: Dictionary) -> String:
	return str(g.enemy_db[str(e["kind"])]["name"])

static func src(g, e: Dictionary) -> String:
	var attack: String = str(e.get("bf_attack", ""))
	var label: String = str(ATTACKS[attack][0]).capitalize() if ATTACKS.has(attack) else "attack"
	return boss_name(g, e).capitalize() + "'s " + label

## One boss bullet. Options: shape, r, color, dmg (scale), life, bounce,
## accel/min/max (speed change), turn (rad/s), stop_t, aim_t, aim_speed,
## aim_point, homing + homing_t, wave, split (+ split_speed/split_shape).
static func fire(g, e: Dictionary, pos: Vector2, dir: Vector2, speed: float, o: Dictionary = {}) -> Variant:
	if int(e.get("bf_owned", 0)) >= OWNED_CAP or g.shots.size() >= g.shot_cap() - 6:
		return null
	var kind: String = str(e["kind"])
	var color: Color = o.get("color", Color(PALETTE.get(kind, "ff9944")))
	var s = C().shot(g, pos, dir, float(e["dmg"]) * float(o.get("dmg", 0.3)),
		{"friendly": false, "kind": "bossbullet", "speed": speed, "life": float(o.get("life", 5.0)),
		"r": float(o.get("r", 5.0)), "color": color, "bounce": int(o.get("bounce", 0)),
		"src": src(g, e)})
	if s == null:
		return null
	s["curve"] = 0.0
	s["boss_owner"] = int(e["id"])
	s["shape"] = str(o.get("shape", "orb"))
	if o.has("homing"):
		s["homing"] = float(o["homing"])
	if o.has("wave"):
		s["wave"] = float(o["wave"])
	var bh := {"dir": dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN}
	for key in ["accel", "min", "max", "turn", "stop_t", "aim_t", "aim_speed", "aim_point",
			"homing_t", "split", "split_speed", "split_shape"]:
		if o.has(key):
			bh[key] = o[key]
	s["bh"] = bh
	e["bf_owned"] = int(e.get("bf_owned", 0)) + 1
	return s

static func ring(g, e: Dictionary, origin: Vector2, count: int, speed: float, offset: float, o: Dictionary = {},
		gap_angle: float = INF, gap_half: float = 0.0, start_r: float = -1.0) -> void:
	var lift: float = float(e["r"]) * 0.8 if start_r < 0.0 else start_r
	for i in range(count):
		var angle: float = offset + TAU * float(i) / float(count)
		if gap_angle != INF and absf(wrapf(angle - gap_angle, -PI, PI)) < gap_half:
			continue
		var d := Vector2.from_angle(angle)
		fire(g, e, origin + d * lift, d, speed, o)

static func fan(g, e: Dictionary, origin: Vector2, dir: Vector2, count: int, spread: float, speed: float, o: Dictionary = {}) -> void:
	for i in range(count):
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		fire(g, e, origin, dir.rotated(t * spread), speed, o)

## Warned circle that detonates once. Optional "burst" fires a bullet ring.
static func circle(g, e: Dictionary, pos: Vector2, radius: float, delay: float, dmg_scale: float, extra: Dictionary = {}) -> void:
	if owned_hazards(g, e) >= HAZARD_CAP:
		return
	var item := {"fn": "boss_blast", "pos": pos, "t": delay, "life": delay, "tele": radius,
		"dmg": float(e["dmg"]) * dmg_scale, "color": str(PALETTE.get(str(e["kind"]), "ff9944")),
		"owner": int(e["id"]), "style": str(e["kind"]), "boss": e, "src": src(g, e)}
	item.merge(extra, true)
	g.delayed.append(item)

## Warned straight strike with exact collision width (half-width = w).
static func line(g, e: Dictionary, a: Vector2, b: Vector2, w: float, delay: float, dmg_scale: float, extra: Dictionary = {}) -> void:
	if owned_hazards(g, e) >= HAZARD_CAP:
		return
	var item := {"fn": "boss_line", "pos": (a + b) * 0.5, "a": a, "b": b, "tele": w,
		"t": delay, "life": delay, "dmg": float(e["dmg"]) * dmg_scale,
		"color": str(PALETTE.get(str(e["kind"]), "ff9944")), "owner": int(e["id"]),
		"style": str(e["kind"]), "src": src(g, e)}
	item.merge(extra, true)
	g.delayed.append(item)

## Boss-owned delayed event resolved by BossFight.resolve (portals, locks...).
static func event(g, e: Dictionary, fn: String, pos: Vector2, delay: float, extra: Dictionary = {}) -> void:
	if owned_hazards(g, e) >= HAZARD_CAP:
		return
	var item := {"fn": fn, "pos": pos, "t": delay, "life": delay, "owner": int(e["id"]),
		"boss": e, "style": str(e["kind"]), "color": str(PALETTE.get(str(e["kind"]), "ff9944"))}
	item.merge(extra, true)
	g.delayed.append(item)

static func spawn_minion(g, e: Dictionary, kind: String, pos: Vector2, role: String, hp_mult: float, still: bool) -> Variant:
	if g.enemies.size() >= g.enemy_cap() + 6:
		return null
	var a: Dictionary = arena(g)
	pos.x = clampf(pos.x, float(a["left"]) + 25.0, float(a["right"]) - 25.0)
	var m = g.spawn_enemy(kind, pos, false, false)
	m["summon"] = true
	m["minion_owner"] = int(e["id"])
	m["minion_role"] = role
	m["minion_static"] = still
	m["hp"] = float(m["hp"]) * hp_mult
	m["max_hp"] = float(m["hp"])
	g.spawn_ring_fx(pos, Color(PALETTE[str(e["kind"])]), 40.0)
	return m

# ================================================================= main loop
## Called every simulation step for a living boss (even while stunned).
## Returns the desired movement vector for Combat's normal steering.
static func update(g, e: Dictionary, dir: Vector2, dist: float, dt: float) -> Vector2:
	var kind: String = str(e["kind"])
	if not MOVES.has(kind):
		return dir
	if not e.has("bf_state"):
		e["bf_state"] = "rest"
		e["bf_t"] = 1.2
		e["bf_phase"] = stage_of(e)
		e["bf_i"] = 0
		e["bf_attack"] = ""
		e["bfe"] = {}
		e["bf_heat"] = 0.0
		e["bf_hist"] = []
		e["bf_trail"] = []
	var owned := 0
	for s in g.shots:
		if int(s.get("boss_owner", -1)) == int(e["id"]) and not bool(s.get("dead", false)):
			owned += 1
	e["bf_owned"] = owned
	e["bf_dizzy"] = maxf(0.0, float(e.get("bf_dizzy", 0.0)) - dt)
	track_history(g, e, dt)
	update_minions(g, e, dt)
	var stage: int = stage_of(e)
	if stage > int(e["bf_phase"]) and str(e["bf_state"]) != "transition":
		begin_transition(g, e, stage)
	e["bf_t"] = float(e["bf_t"]) - dt
	var move := Vector2.ZERO
	match str(e["bf_state"]):
		"transition":
			move = seek(e, home_spot(g, e), 1.4)
			if float(e["bf_t"]) <= 0.0:
				e["bf_state"] = "rest"
				e["bf_t"] = 0.35
		"vent":
			if float(e["bf_t"]) <= 0.0:
				e["bf_state"] = "rest"
				e["bf_t"] = 0.4
		"rest":
			move = rest_move(g, e, dir, dist)
			if float(e["bf_t"]) <= 0.0:
				start_tell(g, e, stage)
		"tell":
			move = tell_move(g, e, dt)
			if float(e["bf_t"]) <= 0.0:
				start_attack(g, e, stage)
		"attack":
			var attack: String = str(e["bf_attack"])
			var elapsed: float = float(e["bf_len"]) - float(e["bf_t"])
			step(g, e, attack, stage, elapsed, dt)
			move = attack_move(g, e, attack, stage, elapsed, dt, dir)
			if float(e["bf_t"]) <= 0.0 and not bool(e.get("bf_air", false)):
				finish_attack(g, e)
	if bool(e.get("bf_air", false)) or bool(e.get("burrowing", false)) or bool(e.get("bf_vanish", false)):
		e["kb"] = Vector2.ZERO
	return move

static func begin_transition(g, e: Dictionary, stage: int) -> void:
	e["bf_phase"] = stage
	e["bf_i"] = 0
	e["bf_state"] = "transition"
	e["bf_t"] = TRANSITION_TIME
	e["bf_air"] = false
	e["bf_hop"] = 0.0
	e["bf_vanish"] = false
	e["burrowing"] = false
	e["bfe"] = {}
	# Cancel the boss's bullets and pending hazards: the new phase starts clean.
	var col := Color(PALETTE[str(e["kind"])])
	var sparkles := 0
	for s in g.shots:
		if int(s.get("boss_owner", -1)) == int(e["id"]) and not bool(s.get("dead", false)):
			s["dead"] = true
			if sparkles < 60:
				sparkles += 1
				g.spawn_burst(s["pos"], Color("fff4c2"), 1, 60.0, 3.0)
	g.delayed = g.delayed.filter(func(d): return int(d.get("owner", -1)) != int(e["id"]))
	var hero_off: Vector2 = g.hero["pos"] - e["pos"]
	if hero_off.length() < 190.0:
		g.hero["push"] = Vector2(g.hero.get("push", Vector2.ZERO)) + hero_off.normalized() * 520.0
	g.spawn_ring_fx(e["pos"], col, 160.0)
	g.spawn_ring_fx(e["pos"], Color.WHITE, 90.0)
	g.add_shake(14.0)
	g.flash_screen(col, 0.25)
	g.say(e["pos"] + Vector2(0, -float(e["r"]) - 40.0), "FINAL PHASE" if stage >= 2 else "PHASE 2", col.lightened(0.35), 30)
	g.sfx.play("horn")

static func start_tell(g, e: Dictionary, stage: int) -> void:
	var kind: String = str(e["kind"])
	if kind == "dreadengine" and float(e.get("bf_heat", 0.0)) >= 100.0:
		e["bf_heat"] = 0.0
		e["bf_state"] = "vent"
		e["bf_t"] = 3.2 if stage < 2 else 2.6
		e["bf_attack"] = ""
		g.spawn_ring_fx(e["pos"], Color("fff2ae"), 110.0)
		g.say(e["pos"] + Vector2(0, -float(e["r"]) - 34.0), "VENTING!", Color("ffe78a"), 24)
		g.sfx.play("whoosh")
		return
	var moves: Array = MOVES[kind][stage]
	var attack: String = str(moves[int(e["bf_i"]) % moves.size()])
	e["bf_i"] = int(e["bf_i"]) + 1
	e["bf_attack"] = attack
	e["bf_state"] = "tell"
	e["bf_t"] = float(ATTACKS[attack][1])
	e["bf_lock"] = lead(g, 0.25)
	e["bf_aim"] = aim_from(g, e["pos"]).angle()
	e["bf_side"] = -1.0 if float(e["pos"].x) > float(arena(g)["cx"]) else 1.0
	g.sfx.play("boss_warn")

static func start_attack(g, e: Dictionary, stage: int) -> void:
	var attack: String = str(e["bf_attack"])
	e["bf_state"] = "attack"
	e["bf_len"] = float(ATTACKS[attack][2])
	e["bf_t"] = float(e["bf_len"])
	e["bf_k"] = 0
	e["bfe"] = {}
	e["bf_ang"] = 0.0
	e["bf_ang2"] = 0.0
	begin(g, e, attack, stage)
	e["bf_t"] = float(e["bf_len"])

static func finish_attack(g, e: Dictionary) -> void:
	var attack: String = str(e["bf_attack"])
	e["bf_state"] = "rest"
	e["bf_t"] = float(ATTACKS[attack][3]) * (0.85 if g.hard_mode else 1.0)
	e["bf_vanish"] = false
	e["burrowing"] = false
	e["bf_hop"] = 0.0
	if str(e["kind"]) == "dreadengine":
		e["bf_heat"] = float(e.get("bf_heat", 0.0)) + float(HEAT_COST.get(attack, 25.0))

static func rest_move(g, e: Dictionary, dir: Vector2, dist: float) -> Vector2:
	match str(e["kind"]):
		"chonkzilla":
			# The kaiju plods after the player between attacks.
			return dir * 2.0 if dist > 170.0 else Vector2.ZERO
		"kingblob":
			return dir * 0.6 if dist > 210.0 else Vector2.ZERO
		"coilqueen":
			var spot: Vector2 = home_spot(g, e)
			return seek(e, spot + Vector2(sin(float(e["t"]) * 2.1) * 90.0, 0.0), 1.2)
	return seek(e, home_spot(g, e))

static func tell_move(g, e: Dictionary, dt: float) -> Vector2:
	var attack: String = str(e["bf_attack"])
	match attack:
		"strafe_run":
			# Swing out to the starting edge of the run.
			var a: Dictionary = arena(g)
			var start := Vector2(float(a["cx"]) - float(e["bf_side"]) * (float(a["half"]) - 40.0), float(a["y"]) - 300.0)
			e["pos"] = Vector2(e["pos"]).lerp(start, 1.0 - exp(-5.5 * dt))
			return Vector2.ZERO
		"kaiju_rage", "royal_decree", "death_bloom", "kaleidoscope", "event_horizon", "hydra_frenzy", "overdrive":
			var a2: Dictionary = arena(g)
			return seek(e, Vector2(float(a2["cx"]), float(a2["y"]) - 280.0), 2.0)
	return Vector2.ZERO

# ================================================================= history & minions
static func track_history(g, e: Dictionary, dt: float) -> void:
	e["bf_hist_t"] = float(e.get("bf_hist_t", 0.0)) - dt
	if float(e["bf_hist_t"]) <= 0.0:
		e["bf_hist_t"] = 0.2
		var hist: Array = e["bf_hist"]
		hist.append(g.hero["pos"])
		if hist.size() > 14:
			hist.pop_front()
	# Coil Queen's body segments follow the head's real path.
	if str(e["kind"]) == "coilqueen":
		var trail: Array = e["bf_trail"]
		if trail.is_empty() or Vector2(trail[0]).distance_to(e["pos"]) > 16.0:
			trail.push_front(e["pos"])
			if trail.size() > 14:
				trail.pop_back()

static func update_minions(g, e: Dictionary, dt: float) -> void:
	var kind: String = str(e["kind"])
	var calm: bool = str(e.get("bf_state", "")) in ["transition", "vent"]
	match kind:
		"necro":
			var wards: Array = minions(g, e, "ward")
			if not wards.is_empty() and float(e["hp"]) < float(e["max_hp"]):
				e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.0045 * wards.size() * dt)
			for ward in wards:
				ward["ward_t"] = float(ward.get("ward_t", randf_range(0.8, 2.0))) - dt
				if float(ward["ward_t"]) <= 0.0 and not calm:
					ward["ward_t"] = 2.8
					fire(g, e, ward["pos"], aim_from(g, ward["pos"]), 165.0,
						{"shape": "skull", "r": 6.0, "homing": 0.7, "homing_t": 1.4, "life": 4.0})
		"glassoracle":
			var mirrors: Array = minions(g, e, "mirror")
			for i in range(mirrors.size()):
				var node: Dictionary = mirrors[i]
				node["ward_t"] = float(node.get("ward_t", 1.6 + i * 0.7)) - dt
				if float(node["ward_t"]) <= 0.0 and not calm:
					node["ward_t"] = 3.2
					var from: Vector2 = node["pos"]
					var to: Vector2 = from + aim_from(g, from) * 820.0
					line(g, e, from, to, 13.0, 0.95, 0.5, {"source": node})
		"dreadengine":
			if not bool(e.get("bf_pods", false)):
				e["bf_pods"] = true
				for side in [-1.0, 1.0]:
					var pod = spawn_minion(g, e, "mirror", e["pos"] + Vector2(side * (float(e["r"]) + 30.0), 6.0), "pod", 2.2, true)
					if pod != null:
						pod["pod_side"] = side
			for pod in minions(g, e, "pod"):
				pod["pos"] = Vector2(e["pos"]) + Vector2(float(pod.get("pod_side", 1.0)) * (float(e["r"]) + 30.0), 6.0)
				pod["ward_t"] = float(pod.get("ward_t", 1.2 + float(pod.get("pod_side", 1.0)) * 0.4)) - dt
				if float(pod["ward_t"]) <= 0.0 and not calm:
					pod["ward_t"] = 1.9
					fan(g, e, pod["pos"], aim_from(g, pod["pos"]), 3, 0.22, 290.0, {"shape": "rice", "r": 4.5, "dmg": 0.24})
		"kingblob":
			# Royal fragments crawl home. Any that arrive are devoured.
			for frag in minions(g, e, "fragment"):
				if Vector2(frag["pos"]).distance_to(e["pos"]) < float(e["r"]) + 16.0:
					frag["dead"] = true
					var base_r: float = float(g.enemy_db["kingblob"]["r"])
					e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.03)
					e["r"] = minf(base_r * 1.45, float(e["r"]) + 3.0)
					e["squash"] = 0.5
					g.spawn_ring_fx(e["pos"], Color("ff8bc2"), float(e["r"]) + 20.0)
					g.say(e["pos"] + Vector2(0, -float(e["r"]) - 24.0), "+MASS", Color("ffc1db"), 18)

## Steering for a boss minion; null means "use normal AI".
static func minion_move(g, m: Dictionary, dir: Vector2) -> Variant:
	if bool(m.get("minion_static", false)):
		return Vector2.ZERO
	if str(m.get("minion_role", "")) == "fragment":
		for boss in g.enemies:
			if int(boss["id"]) == int(m["minion_owner"]) and not bool(boss.get("dead", false)):
				var to: Vector2 = Vector2(boss["pos"]) - Vector2(m["pos"])
				return to.normalized() * 1.25 if to.length() > 1.0 else Vector2.ZERO
	return null

# ================================================================= leaps
static func leap(g, e: Dictionary, target: Vector2, air: float, radius: float, dmg_scale: float) -> void:
	var a: Dictionary = arena(g)
	target.x = clampf(target.x, float(a["left"]) + float(e["r"]), float(a["right"]) - float(e["r"]))
	e["bf_from"] = e["pos"]
	e["bf_to"] = target
	e["bf_air_t"] = 0.0
	e["bf_air_dur"] = air
	e["bf_air"] = true
	circle(g, e, target, radius, air, dmg_scale, {"landing": true})

## Advances an active leap; true on the frame the boss lands.
static func update_leap(g, e: Dictionary, dt: float) -> bool:
	if not bool(e.get("bf_air", false)):
		return false
	e["bf_air_t"] = float(e["bf_air_t"]) + dt
	var u: float = clampf(float(e["bf_air_t"]) / float(e["bf_air_dur"]), 0.0, 1.0)
	var eased: float = u * u * (3.0 - 2.0 * u)
	e["pos"] = Vector2(e["bf_from"]).lerp(e["bf_to"], eased)
	e["bf_hop"] = sin(PI * u) * 120.0
	if u >= 1.0:
		e["bf_air"] = false
		e["bf_hop"] = 0.0
		e["squash"] = 0.8
		g.add_shake(12.0)
		g.sfx.play("bonk")
		return true
	return false

# ================================================================= attacks: begin
static func begin(g, e: Dictionary, attack: String, stage: int) -> void:
	var a: Dictionary = arena(g)
	var hero: Vector2 = g.hero["pos"]
	match attack:
		"quake_slam":
			e["bf_len"] = 1.35 * float(1 + stage) + 0.35
		"royal_slam":
			e["bf_len"] = 1.55 * float(1 + (1 if stage >= 2 else 0)) + 0.35
		"burrow_strike":
			e["bf_len"] = 1.3 * float(1 + stage) + 0.1
		"blink_strike":
			e["bf_len"] = 1.0 * float(2 + stage) + 0.2
		"strafe_run":
			e["bf_len"] = 2.3 if stage == 0 else 4.4
		"meteor_shower":
			var waves: int = 3 if stage < 2 else 4
			grid_waves(g, e, 6, 4, waves, 1.25, 0.85, 0.75, 2)
			e["bf_len"] = 1.25 + 0.85 * waves + 0.2
		"grave_field":
			var graves: int = 2 if stage < 2 else 3
			grid_waves(g, e, 6, 4, graves, 1.25, 0.9, 0.7, 2, {"burst": 3 if stage >= 2 else 0, "burst_shape": "skull"})
			e["bf_len"] = 1.25 + 0.9 * graves + 0.3
		"crown_rain":
			var jewels: int = 3 if stage < 2 else 4
			grid_waves(g, e, 6, 4, jewels, 1.3, 0.8, 0.7, 3, {"burst": 4, "burst_shape": "shard"})
			e["bf_len"] = 1.3 + 0.8 * jewels + 0.3
		"carpet_bomb":
			var cols := 7
			var rows := 5
			var w: float = 2.0 * float(a["half"]) / float(cols)
			var h: float = (float(a["bottom"]) - float(a["top"])) / float(rows)
			var gap: int = clampi(int(round((hero.x - float(a["left"])) / w - 0.5)) + (2 if randf() < 0.5 else -2), 0, cols - 1)
			for r in range(rows):
				for c in range(cols):
					if c == gap:
						continue
					var pos := Vector2(float(a["left"]) + (c + 0.5) * w, float(a["top"]) + (r + 0.5) * h)
					circle(g, e, pos, minf(w, h) * 0.5, 1.2 + r * 0.34, 0.6)
				gap = clampi(gap + (1 if randf() < 0.5 else -1), 0, cols - 1)
			e["bf_len"] = 1.2 + rows * 0.34 + 0.6
		"piston_bank":
			var lanes := 5
			var passes: int = 2 + mini(stage, 1)
			var lane_w: float = 2.0 * float(a["half"]) / float(lanes)
			var gap2: int = randi() % lanes
			for p in range(passes):
				for c in range(lanes):
					if c == gap2:
						continue
					var x: float = float(a["left"]) + (c + 0.5) * lane_w
					line(g, e, Vector2(x, float(a["top"]) - 40.0), Vector2(x, float(a["bottom"]) + 40.0),
						lane_w * 0.5 - 6.0, 1.15 + p * 0.75, 0.55, {"piston": true})
				gap2 = (gap2 + 2 + randi() % 2) % lanes
			if stage >= 1:
				var row_y: float = hero.y + (110.0 if randf() < 0.5 else -110.0)
				line(g, e, Vector2(float(a["left"]), row_y), Vector2(float(a["right"]), row_y), 26.0,
					1.15 + passes * 0.75, 0.5, {"piston": true})
			e["bf_len"] = 1.15 + passes * 0.75 + 0.4
		"web_lattice":
			var waves2: int = 2 if stage < 2 else 3
			for wv in range(waves2):
				var t0: float = 1.25 + wv * 1.0
				var shift: float = 0.5 if wv % 2 == 1 else 0.0
				for r in range(3):
					var y: float = float(a["top"]) + (r + 0.5 + shift) * (float(a["bottom"]) - float(a["top"])) / 3.5
					line(g, e, Vector2(float(a["left"]) - 20.0, y), Vector2(float(a["right"]) + 20.0, y), 14.0, t0, 0.5, {"web": true})
				for c in range(4):
					var x2: float = float(a["left"]) + (c + 0.5 + shift) * 2.0 * float(a["half"]) / 4.5
					line(g, e, Vector2(x2, float(a["top"]) - 20.0), Vector2(x2, float(a["bottom"]) + 20.0), 14.0, t0 + 0.3, 0.5, {"web": true})
			e["bf_len"] = 1.25 + waves2 * 1.0 + 0.4
		"constrict":
			pass # squeezes are staggered in step()
		"venom_squeeze":
			squeeze(g, e, 1.7)
		"raise_wards":
			var have: int = minions(g, e, "ward").size()
			var want: int = mini(5, 3 + stage) - have
			for i in range(want):
				var angle: float = TAU * float(i) / float(maxi(1, want)) + randf() * 0.6
				var pos: Vector2 = hero + Vector2.from_angle(angle) * randf_range(200.0, 290.0)
				pos.y = clampf(pos.y, float(a["top"]) + 20.0, float(a["bottom"]) - 20.0)
				spawn_minion(g, e, "leech", pos, "ward", 1.5, true)
			ring(g, e, e["pos"], 16, 150.0, randf() * TAU, {"shape": "skull", "r": 6.0})
		"hall_of_mirrors":
			var have2: int = minions(g, e, "mirror").size()
			var want2: int = mini(4, 2 + stage) - have2
			var spots: Array = [Vector2(-0.75, -0.55), Vector2(0.75, -0.55), Vector2(-0.8, 0.35), Vector2(0.8, 0.35)]
			spots.shuffle()
			for i in range(want2):
				var s: Vector2 = spots[i]
				var where := Vector2(float(a["cx"]) + s.x * float(a["half"]), hero.y + s.y * 260.0)
				spawn_minion(g, e, "mirror", where, "mirror", 1.4, true)
			ring(g, e, e["pos"], 12, 230.0, randf() * TAU, {"shape": "shard"})
		"summon_court":
			for i in range(4 + stage):
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var pos2 := Vector2(float(a["cx"]) + side * (float(a["half"]) - 30.0), hero.y - 220.0 + float(i / 2) * 150.0)
				var frag = spawn_minion(g, e, "blob", pos2, "fragment", 1.0, false)
				if frag != null:
					frag["speed"] = float(frag["speed"]) * 1.15
		"gravity_well":
			var center: Vector2 = Vector2(clampf(hero.x + (120.0 if randf() < 0.5 else -120.0), float(a["left"]) + 180.0, float(a["right"]) - 180.0), hero.y - 60.0)
			g.delayed.append({"fn": "boss_gravity", "pos": center, "arm": 0.9, "t": 4.0, "life": 4.0,
				"tele": 185.0, "color": PALETTE["voidweaver"], "owner": int(e["id"]), "style": "voidweaver"})
			e["bf_center"] = center
		"event_horizon":
			var center2 := Vector2(float(a["cx"]), hero.y - 40.0)
			g.delayed.append({"fn": "boss_gravity", "pos": center2, "arm": 0.6, "t": 6.4, "life": 6.4,
				"tele": 230.0, "color": PALETTE["voidweaver"], "owner": int(e["id"]), "style": "voidweaver", "weak": true})
			e["bf_center"] = center2
		"missile_salvo":
			var count: int = 3 + stage
			for i in range(count):
				var angle2: float = TAU * float(i) / float(count) + randf() * 0.5
				var lock: Vector2 = hero + (Vector2.from_angle(angle2) * 70.0 if i > 0 else Vector2.ZERO)
				event(g, e, "bf_lock", lock, 0.85 + i * 0.16, {"tele": 34.0})
		"rift_crossfire":
			var portals: int = 4 + stage
			for i in range(portals):
				var side2: float = -1.0 if i % 2 == 0 else 1.0
				var pos3 := Vector2(float(a["cx"]) + side2 * (float(a["half"]) - 20.0),
					float(a["top"]) + 40.0 + float(i) * (float(a["bottom"]) - float(a["top"]) - 80.0) / float(maxi(1, portals - 1)))
				event(g, e, "bf_portal", pos3, 0.9 + i * 0.28, {"tele": 34.0, "stage": stage})
		"echo_volley":
			var hist: Array = e["bf_hist"]
			for i in range(3):
				var idx: int = hist.size() - 3 - i * 3
				var at: Vector2 = hist[idx] if idx >= 0 and idx < hist.size() else hero
				event(g, e, "bf_echo", at, 0.85 + i * 0.4, {"tele": 26.0, "stage": stage})

## Map-wide grid hazard: alternating cells on each wave, so a safe cell
## always exists one step away. modulo 2 = checkerboard, 3 = diagonal stripes.
static func grid_waves(g, e: Dictionary, cols: int, rows: int, waves: int, first: float, spacing: float,
		dmg_scale: float, modulo: int, extra: Dictionary = {}) -> void:
	var a: Dictionary = arena(g)
	var w: float = 2.0 * float(a["half"]) / float(cols)
	var h: float = (float(a["bottom"]) - float(a["top"])) / float(rows)
	var radius: float = minf(w, h) * 0.5 * 0.86
	var flip: int = randi() % modulo
	for wave in range(waves):
		for r in range(rows):
			for c in range(cols):
				var cell: int = (c + r + wave + flip) % modulo
				# Checkerboard hits half the cells; stripes hit two of every three.
				if (modulo == 2 and cell != 0) or (modulo != 2 and cell == 0):
					continue
				var pos := Vector2(float(a["left"]) + (c + 0.5) * w, float(a["top"]) + (r + 0.5) * h)
				circle(g, e, pos, radius, first + wave * spacing, dmg_scale, extra)

## Coil Queen: venom floods in from both road edges, leaving one corridor.
static func squeeze(g, e: Dictionary, delay: float, corridor_x: float = INF) -> void:
	var a: Dictionary = arena(g)
	var hero: Vector2 = g.hero["pos"]
	var cx: float = corridor_x
	if cx == INF:
		cx = hero.x + (1.0 if randf() < 0.5 else -1.0) * randf_range(120.0, 220.0)
	cx = clampf(cx, float(a["left"]) + 90.0, float(a["right"]) - 90.0)
	event(g, e, "bf_squeeze", Vector2(cx, hero.y), delay,
		{"left": float(a["left"]) - 30.0, "right": float(a["right"]) + 30.0, "gap": 70.0,
		"top": float(a["top"]) - 80.0, "bottom": float(a["bottom"]) + 80.0,
		"dmg": float(e["dmg"]) * 0.7, "src": src(g, e)})

# ================================================================= attacks: per-frame
static func step(g, e: Dictionary, attack: String, stage: int, T: float, dt: float) -> void:
	var me: Vector2 = e["pos"]
	var a: Dictionary = arena(g)
	var hero: Vector2 = g.hero["pos"]
	var col := Color(PALETTE[str(e["kind"])])
	var alt := Color(PALETTE_ALT[str(e["kind"])])
	match attack:
		# ---------------------------------------------------------- CHONKZILLA
		"quake_slam":
			var jumps: int = 1 + stage
			if not bool(e.get("bf_air", false)) and int(e["bf_k"]) < jumps and T >= float(e["bf_k"]) * 1.35:
				e["bf_k"] = int(e["bf_k"]) + 1
				leap(g, e, lead(g, 0.35), 0.8, 108.0, 0.8)
			if update_leap(g, e, dt):
				var n: int = 16 + 4 * stage
				var off: float = randf() * TAU
				ring(g, e, e["pos"], n, 175.0, off, {"r": 5.5}, INF, 0.0, 30.0)
				ring(g, e, e["pos"], n, 120.0, off + PI / float(n), {"r": 5.5, "color": alt}, INF, 0.0, 30.0)
		"goo_geyser":
			var arms: int = 2 + stage
			for _i in range(every(e, "spiral", 0.1, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.23
				for arm in range(arms):
					var d := Vector2.from_angle(float(e["bf_ang"]) + TAU * float(arm) / float(arms))
					fire(g, e, me + d * float(e["r"]) * 0.7, d, 165.0, {"accel": 35.0, "max": 250.0, "r": 5.5})
			if stage >= 2:
				for _i in range(every(e, "counter", 0.18, dt)):
					e["bf_ang2"] = float(e["bf_ang2"]) - 0.31
					for arm in range(3):
						var d2 := Vector2.from_angle(float(e["bf_ang2"]) + TAU * float(arm) / 3.0)
						fire(g, e, me + d2 * float(e["r"]) * 0.7, d2, 120.0, {"r": 7.0, "shape": "big", "color": alt})
		"boulder_toss":
			var tosses: int = 3 + stage
			for _i in range(every(e, "toss", 0.36, dt)):
				if int(e["bf_k"]) >= tosses:
					break
				e["bf_k"] = int(e["bf_k"]) + 1
				var spot: Vector2 = lead(g, 0.5) + Vector2(randf_range(-60.0, 60.0), randf_range(-50.0, 50.0))
				circle(g, e, spot, 72.0, 1.05, 0.7, {"burst": 8 + 2 * stage, "burst_shape": "orb", "boulder": true, "from": me})
		"meteor_shower":
			for _i in range(every(e, "aim", 0.95, dt, 0.4)):
				fan(g, e, me, aim_from(g, me), 3, 0.5, 210.0, {"r": 5.5})
		"belly_roll":
			roll_step(g, e, stage, T, dt)
		"kaiju_rage":
			for _i in range(every(e, "flower", 0.45, dt)):
				e["bf_k"] = int(e["bf_k"]) + 1
				var off2: float = float(e["bf_k"]) * 0.19
				for i in range(22):
					var d3 := Vector2.from_angle(off2 + TAU * float(i) / 22.0)
					fire(g, e, me + d3 * float(e["r"]) * 0.7, d3, 150.0 if i % 2 == 0 else 205.0,
						{"r": 5.5, "color": col if i % 2 == 0 else alt})
			for _i in range(every(e, "meteor", 0.75, dt, 0.5)):
				circle(g, e, lead(g, 0.45), 72.0, 0.95, 0.7)
		# ---------------------------------------------------------- HELI
		"strafe_run":
			var pass_len: float = 2.2
			var going: float = float(e["bf_side"]) * (1.0 if T < pass_len else -1.0)
			for _i in range(every(e, "gun", 0.075, dt)):
				for s in [-1.0, 1.0]:
					var d4 := Vector2(s * 0.13 + randf_range(-0.04, 0.04), 1.0).normalized()
					fire(g, e, me + Vector2(s * 16.0, 30.0), d4, 330.0, {"shape": "rice", "r": 4.0, "dmg": 0.24})
			for _i in range(every(e, "bomb", 0.3, dt, 0.15)):
				var drop := Vector2(me.x + going * 50.0, hero.y + randf_range(-70.0, 70.0))
				circle(g, e, drop, 54.0, 0.9, 0.6, {"bomb": true})
		"missile_salvo":
			for _i in range(every(e, "fan", 0.9, dt, 0.25)):
				fan(g, e, me, aim_from(g, me), 5, 0.7, 260.0, {"shape": "rice", "r": 4.5})
		"minigun_sweep":
			var sweeps: int = 1 if stage < 2 else 2
			var dur: float = float(e["bf_len"])
			var u: float = clampf(T / dur * float(sweeps), 0.0, float(sweeps))
			var phase_u: float = fmod(u, 1.0) if u < float(sweeps) else 1.0
			if int(u) % 2 == 1:
				phase_u = 1.0 - phase_u
			var dir_sign: float = 1.0 if int(e["bf_i"]) % 2 == 0 else -1.0
			e["bf_gun"] = float(e["bf_aim"]) + dir_sign * lerpf(-1.05, 1.05, phase_u)
			for _i in range(every(e, "stream", 0.08, dt)):
				var d5 := Vector2.from_angle(float(e["bf_gun"]))
				fire(g, e, me + d5 * 34.0, d5, 380.0, {"shape": "rice", "r": 4.0, "dmg": 0.24})
				if stage >= 1:
					fire(g, e, me + d5 * 34.0 + d5.orthogonal() * 16.0, d5.rotated(0.05), 380.0, {"shape": "rice", "r": 4.0, "dmg": 0.24, "color": alt})
		"carpet_bomb":
			for _i in range(every(e, "fan", 0.8, dt, 0.5)):
				fan(g, e, me, aim_from(g, me), 3, 0.35, 240.0, {"shape": "rice", "r": 4.5})
		"danger_close":
			for _i in range(every(e, "burst", 0.42, dt, 0.3)):
				fan(g, e, me, aim_from(g, me), 3, 0.32, 290.0, {"shape": "rice", "r": 4.5})
			for _i in range(every(e, "wash", 1.2, dt, 0.8)):
				ring(g, e, me, 18, 170.0, randf() * TAU, {"r": 5.0, "color": alt})
			for _i in range(every(e, "bomb", 0.95, dt, 0.6)):
				circle(g, e, lead(g, 0.5), 60.0, 0.95, 0.6, {"bomb": true})
		# ---------------------------------------------------------- NECRO
		"skull_waltz":
			var arms2: int = 3 + mini(stage, 1)
			for _i in range(every(e, "a", 0.12, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.19
				e["bf_ang2"] = float(e["bf_ang2"]) - 0.19
				for arm in range(arms2):
					var off3: float = TAU * float(arm) / float(arms2)
					var d6 := Vector2.from_angle(float(e["bf_ang"]) + off3)
					var d7 := Vector2.from_angle(float(e["bf_ang2"]) + off3 + 0.3)
					fire(g, e, me + d6 * 30.0, d6, 115.0, {"accel": 55.0, "max": 235.0, "shape": "skull", "r": 6.0})
					fire(g, e, me + d7 * 30.0, d7, 115.0, {"accel": 55.0, "max": 235.0, "r": 5.0, "color": alt})
		"soul_harvest":
			var waves3: int = 2 + (1 if stage >= 2 else 0)
			for _i in range(every(e, "wave", 1.2, dt)):
				if int(e["bf_k"]) >= waves3:
					break
				e["bf_k"] = int(e["bf_k"]) + 1
				soul_ring(g, e, hero, 22, 265.0, 3)
		"raise_wards", "grave_field", "hall_of_mirrors", "web_lattice", "piston_bank":
			# The setpiece is already on the ground; keep light aimed pressure.
			for _i in range(every(e, "poke", 0.85, dt, 0.5)):
				fan(g, e, me, aim_from(g, me), 3, 0.45, 220.0, {"r": 5.0, "shape": "shard" if attack == "hall_of_mirrors" else "orb"})
		"death_bloom":
			for _i in range(every(e, "bloom", 0.22, dt)):
				e["bf_k"] = int(e["bf_k"]) + 1
				var off4: float = sin(T * 1.7) * 0.9 + T * 0.4
				for i in range(10):
					var d8 := Vector2.from_angle(off4 + TAU * float(i) / 10.0)
					fire(g, e, me + d8 * 26.0, d8, 160.0, {"r": 5.0, "color": col if int(e["bf_k"]) % 2 == 0 else alt,
						"shape": "skull" if i % 5 == 0 else "orb"})
			for _i in range(every(e, "harvest", 1.7, dt, 0.8)):
				soul_ring(g, e, hero, 16, 235.0, 3)
		# ---------------------------------------------------------- KING BLOB
		"royal_slam":
			var flops: int = 1 + (1 if stage >= 2 else 0)
			if not bool(e.get("bf_air", false)) and int(e["bf_k"]) < flops and T >= float(e["bf_k"]) * 1.55:
				e["bf_k"] = int(e["bf_k"]) + 1
				leap(g, e, lead(g, 0.4), 0.95, 92.0 + float(e["r"]) * 0.6, 0.85)
			if update_leap(g, e, dt):
				var off5: float = randf() * TAU
				for k in range(3):
					ring(g, e, e["pos"], 14, 125.0 + 48.0 * k, off5 + k * 0.11,
						{"r": 6.0, "shape": "big" if k == 0 else "orb", "color": col if k != 1 else alt}, INF, 0.0, 40.0)
				for side in [-1.0, 1.0]:
					spawn_minion(g, e, "blob", Vector2(e["pos"]) + Vector2(side * (float(e["r"]) + 50.0), 20.0), "fragment", 0.8, false)
		"jelly_juggle":
			for _i in range(every(e, "lob", 0.8, dt)):
				fan(g, e, me, aim_from(g, me), 4 + stage, 1.2, 205.0,
					{"shape": "big", "r": 11.0, "bounce": 2, "life": 2.5, "dmg": 0.4,
					"split": 7, "split_speed": 160.0, "split_shape": "orb"})
		"summon_court":
			for _i in range(every(e, "spokes", 0.25, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.13
				ring(g, e, me, 8, 150.0, float(e["bf_ang"]), {"r": 5.5, "color": alt})
		"crown_rain":
			for _i in range(every(e, "poke", 1.0, dt, 0.5)):
				fan(g, e, me, aim_from(g, me), 3, 0.5, 200.0, {"r": 6.0, "shape": "big"})
		"royal_decree":
			for _i in range(every(e, "spiral", 0.13, dt)):
				e["bf_k"] = int(e["bf_k"]) + 1
				var turn: float = 1.0 if int(T / 1.5) % 2 == 0 else -1.0
				e["bf_ang"] = float(e["bf_ang"]) + 0.17 * turn
				for arm in range(5):
					var d9 := Vector2.from_angle(float(e["bf_ang"]) + TAU * float(arm) / 5.0)
					if int(e["bf_k"]) % 2 == 0:
						fire(g, e, me + d9 * float(e["r"]) * 0.7, d9, 140.0, {"shape": "big", "r": 9.0})
					else:
						fire(g, e, me + d9 * float(e["r"]) * 0.7, d9, 210.0, {"r": 5.0, "color": alt})
			for _i in range(every(e, "jelly", 2.0, dt, 1.0)):
				fan(g, e, me, aim_from(g, me), 3, 0.9, 200.0,
					{"shape": "big", "r": 11.0, "bounce": 2, "life": 2.4, "dmg": 0.4, "split": 6, "split_speed": 150.0})
		# ---------------------------------------------------------- COIL QUEEN
		"burrow_strike":
			var strikes: int = 1 + stage
			var k: int = int(e["bf_k"])
			if k < strikes and T >= float(k) * 1.3:
				e["bf_k"] = k + 1
				e["burrowing"] = true
				e["bf_from"] = e["pos"]
				var target: Vector2 = lead(g, 0.45)
				e["bf_to"] = target
				e["bf_dig_t"] = 0.0
				circle(g, e, target, 82.0, 1.05, 0.85, {"emerge": true})
			if bool(e.get("burrowing", false)):
				e["bf_dig_t"] = float(e["bf_dig_t"]) + dt
				var u2: float = clampf(float(e["bf_dig_t"]) / 1.05, 0.0, 1.0)
				e["pos"] = Vector2(e["bf_from"]).lerp(e["bf_to"], u2 * u2)
				if u2 >= 1.0:
					e["burrowing"] = false
					e["squash"] = 0.7
					g.add_shake(9.0)
					ring(g, e, e["pos"], 16, 190.0, randf() * TAU, {"shape": "rice", "r": 4.5, "wave": 0.8}, INF, 0.0, 30.0)
					if stage >= 1 and minions(g, e, "hatchling").size() < 4:
						for side2 in [-1.0, 1.0]:
							spawn_minion(g, e, "mini", Vector2(e["pos"]) + Vector2(side2 * 70.0, 30.0), "hatchling", 1.0, false)
		"serpent_stream":
			var streams: int = 3 + stage
			for _i in range(every(e, "retarget", 0.6, dt)):
				e["bf_aim"] = aim_from(g, me).angle()
			for _i in range(every(e, "stream", 0.09, dt)):
				var swing: float = sin(T * 1.6) * 0.35
				for sidx in range(streams):
					var spread: float = (float(sidx) - float(streams - 1) * 0.5) * 0.42
					var d10 := Vector2.from_angle(float(e["bf_aim"]) + spread + swing)
					fire(g, e, me + d10 * 30.0, d10, 250.0, {"shape": "rice", "r": 4.5, "wave": 1.4,
						"color": col if sidx % 2 == 0 else alt})
		"venom_squeeze":
			for _i in range(every(e, "fang", 0.5, dt, 0.2)):
				fan(g, e, me, aim_from(g, me), 3, 0.4, 240.0, {"shape": "rice", "r": 4.5})
		"constrict":
			var squeezes := 3
			if int(e["bf_k"]) < squeezes and T >= float(e["bf_k"]) * 1.15:
				var order: Array = [-0.55, 0.55, 0.0] if int(e["bf_i"]) % 2 == 0 else [0.55, -0.55, 0.0]
				var cx: float = float(a["cx"]) + float(order[int(e["bf_k"])]) * float(a["half"])
				e["bf_k"] = int(e["bf_k"]) + 1
				squeeze(g, e, 1.55, cx)
		"hydra_frenzy":
			for _i in range(every(e, "stream", 0.1, dt)):
				for h in range(3):
					var base: float = T * 0.7 + TAU * float(h) / 3.0
					var d11 := Vector2.from_angle(base)
					fire(g, e, me + d11 * 30.0, d11, 220.0, {"shape": "rice", "r": 4.5, "wave": 1.6,
						"color": col if h % 2 == 0 else alt})
			for _i in range(every(e, "pool", 0.8, dt, 0.5)):
				circle(g, e, lead(g, 0.5), 64.0, 0.9, 0.65)
		# ---------------------------------------------------------- GLASS ORACLE
		"prism_lasers":
			var beams: int = 3 + stage
			var turn2: float = 1.0 if int(e["bf_i"]) % 2 == 0 else -1.0
			for _i in range(every(e, "sweep", 0.3, dt)):
				var k2: int = int(e["bf_k"])
				if k2 >= 10:
					break
				e["bf_k"] = k2 + 1
				for b in range(beams):
					var ang: float = float(e["bf_aim"]) + turn2 * float(k2) * 0.2 + TAU * float(b) / float(beams)
					var d12 := Vector2.from_angle(ang)
					line(g, e, me + d12 * (float(e["r"]) + 6.0), me + d12 * 900.0, 12.0, 0.7, 0.5, {"prism": true})
		"shard_bloom":
			for _i in range(every(e, "bloom", 0.8, dt)):
				var n2: int = 14 + 4 * stage
				ring(g, e, me, n2, 290.0, randf() * TAU,
					{"shape": "shard", "r": 5.0, "stop_t": 0.4, "aim_t": 1.15, "aim_speed": 300.0, "life": 4.0})
		"echo_volley":
			for _i in range(every(e, "fan", 0.9, dt, 0.4)):
				fan(g, e, me, aim_from(g, me), 4, 0.5, 230.0, {"shape": "shard", "r": 5.0})
		"kaleidoscope":
			for _i in range(every(e, "spin", 0.12, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.14
				for arm in range(6):
					var base2: float = TAU * float(arm) / 6.0
					var d13 := Vector2.from_angle(float(e["bf_ang"]) + base2)
					var d14 := Vector2.from_angle(-float(e["bf_ang"]) + base2)
					fire(g, e, me + d13 * 26.0, d13, 165.0, {"shape": "shard", "r": 5.0})
					fire(g, e, me + d14 * 26.0, d14, 135.0, {"shape": "shard", "r": 5.0, "color": alt})
			for _i in range(every(e, "prism", 1.7, dt, 1.0)):
				var off6: float = randf() * TAU
				for b in range(6):
					var d15 := Vector2.from_angle(off6 + TAU * float(b) / 6.0)
					line(g, e, me + d15 * (float(e["r"]) + 6.0), me + d15 * 900.0, 12.0, 0.8, 0.5, {"prism": true})
		# ---------------------------------------------------------- VOID WEAVER
		"void_pinwheel":
			var arms3: int = 5 + mini(stage, 1)
			for _i in range(every(e, "spin", 0.11, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.12
				for arm in range(arms3):
					var d16 := Vector2.from_angle(float(e["bf_ang"]) + TAU * float(arm) / float(arms3))
					var bend: float = 0.55 if stage == 0 or arm % 2 == 0 else -0.55
					fire(g, e, me + d16 * 30.0, d16, 165.0, {"turn": bend, "r": 5.0,
						"color": col if arm % 2 == 0 else alt, "life": 4.5})
		"blink_strike":
			var blinks: int = 2 + stage
			var k3: int = int(e["bf_k"])
			if k3 < blinks and T >= float(k3) * 1.0:
				e["bf_k"] = k3 + 1
				var to: Vector2 = lead(g, 0.4) + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0))
				e["bf_to"] = to
				e["bf_vanish"] = true
				ring(g, e, me, 8, 140.0, randf() * TAU, {"r": 5.0, "color": alt})
				circle(g, e, to, 74.0, 0.8, 0.8, {"blink": true})
				g.spawn_ring_fx(me, col, 50.0)
		"gravity_well":
			for _i in range(every(e, "ring", 0.65, dt, 0.4)):
				ring(g, e, me, 12, 175.0, randf() * TAU, {"r": 5.0})
		"event_horizon":
			var center: Vector2 = e.get("bf_center", hero)
			for _i in range(every(e, "inflow", 0.13, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.47
				for q in range(3):
					var ang2: float = float(e["bf_ang"]) + TAU * float(q) / 3.0
					var pos: Vector2 = center + Vector2.from_angle(ang2) * 430.0
					var inward: Vector2 = (center - pos).normalized().rotated(0.55)
					fire(g, e, pos, inward, 115.0, {"accel": 35.0, "max": 200.0, "r": 5.0,
						"color": col if q % 2 == 0 else alt, "life": 6.0})
			for _i in range(every(e, "pin", 0.4, dt, 0.2)):
				e["bf_ang2"] = float(e["bf_ang2"]) + 0.3
				ring(g, e, me, 6, 150.0, float(e["bf_ang2"]), {"turn": 0.5, "r": 5.0})
		# ---------------------------------------------------------- DREAD ENGINE
		"gear_grinder":
			var spokes: int = 8 + 2 * stage
			for _i in range(every(e, "spokes", 0.2, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.16
				ring(g, e, me, spokes, 205.0, float(e["bf_ang"]), {"r": 5.5, "shape": "gear"})
		"furnace_breath":
			var dir_sign2: float = 1.0 if int(e["bf_i"]) % 2 == 0 else -1.0
			var u3: float = clampf(T / float(e["bf_len"]), 0.0, 1.0)
			e["bf_gun"] = float(e["bf_aim"]) + dir_sign2 * lerpf(-0.95, 0.95, u3)
			for _i in range(every(e, "flame", 0.035, dt)):
				var d17 := Vector2.from_angle(float(e["bf_gun"]) + randf_range(-0.2, 0.2))
				fire(g, e, me + d17 * (float(e["r"]) * 0.8), d17, randf_range(300.0, 390.0),
					{"shape": "flame", "r": 6.5, "life": 0.85, "dmg": 0.22, "color": col if randf() < 0.6 else alt})
		"mortar_barrage":
			for _i in range(every(e, "volley", 0.95, dt)):
				var k4: int = int(e["bf_k"])
				if k4 >= 3:
					break
				e["bf_k"] = k4 + 1
				var c: Vector2 = lead(g, 0.4)
				if k4 % 2 == 0:
					circle(g, e, c, 60.0, 1.0, 0.65, {"mortar": true})
				for j in range(6):
					var pos2: Vector2 = c + Vector2.from_angle(TAU * float(j) / 6.0 + k4 * 0.5) * 150.0
					circle(g, e, pos2, 60.0, 1.0 + 0.1 * (j % 2), 0.65, {"mortar": true})
		"overdrive":
			for _i in range(every(e, "spokes", 0.24, dt)):
				e["bf_ang"] = float(e["bf_ang"]) + 0.2
				ring(g, e, me, 10, 195.0, float(e["bf_ang"]), {"r": 5.5, "shape": "gear"})
			for _i in range(every(e, "piston", 2.0, dt, 0.4)):
				var lanes2 := 5
				var lane_w2: float = 2.0 * float(a["half"]) / float(lanes2)
				var gap3: int = randi() % lanes2
				for c2 in range(lanes2):
					if c2 == gap3:
						continue
					var x3: float = float(a["left"]) + (c2 + 0.5) * lane_w2
					line(g, e, Vector2(x3, float(a["top"]) - 40.0), Vector2(x3, float(a["bottom"]) + 40.0),
						lane_w2 * 0.5 - 6.0, 1.1, 0.55, {"piston": true})
			for _i in range(every(e, "flame", 0.05, dt)):
				var d18 := Vector2.from_angle(aim_from(g, me).angle() + randf_range(-0.3, 0.3))
				fire(g, e, me + d18 * float(e["r"]) * 0.8, d18, randf_range(280.0, 360.0),
					{"shape": "flame", "r": 6.5, "life": 0.75, "dmg": 0.2, "color": alt})

## Souls appear on a circle around the player, hang for a beat, then converge.
static func soul_ring(g, e: Dictionary, center: Vector2, count: int, radius: float, gap: int) -> void:
	var start: int = randi() % count
	var off: float = randf() * TAU
	for i in range(count):
		if (i - start + count) % count < gap:
			continue
		var angle: float = off + TAU * float(i) / float(count)
		var pos: Vector2 = center + Vector2.from_angle(angle) * radius
		fire(g, e, pos, (center - pos).normalized(), 0.0,
			{"shape": "skull", "r": 6.0, "aim_t": 0.85, "aim_point": center, "aim_speed": 215.0, "life": 4.2})

static func roll_step(g, e: Dictionary, stage: int, T: float, dt: float) -> void:
	var rolls: int = 1 + (1 if stage >= 2 else 0)
	if not e.has("bf_roll_v") or T <= dt * 1.5:
		var d: Vector2 = (Vector2(e["bf_lock"]) - Vector2(e["pos"])).normalized()
		if d.length_squared() < 0.01:
			d = Vector2.DOWN
		e["bf_roll_v"] = d * 560.0
		e["bf_len"] = 1.3 * float(rolls)
		e["bf_t"] = float(e["bf_len"]) - T
	var a: Dictionary = arena(g)
	var v: Vector2 = e["bf_roll_v"]
	var p: Vector2 = Vector2(e["pos"]) + v * dt
	var r: float = float(e["r"])
	var bounced := false
	if p.x < float(a["left"]) + r - 30.0 or p.x > float(a["right"]) - r + 30.0:
		v.x = -v.x
		bounced = true
	if p.y < float(a["top"]) - 80.0 or p.y > float(a["bottom"]) + 30.0:
		v.y = -v.y
		bounced = true
	if bounced:
		p = Vector2(e["pos"])
		g.add_shake(8.0)
		ring(g, e, p, 12, 160.0, randf() * TAU, {"r": 5.5}, INF, 0.0, r * 0.6)
		g.sfx.play("bonk")
	e["bf_roll_v"] = v
	e["pos"] = p
	e["bf_spin"] = float(e.get("bf_spin", 0.0)) + dt * 9.0
	for _i in range(every(e, "trail", 0.07, dt)):
		var side: Vector2 = v.normalized().orthogonal()
		for s in [-1.0, 1.0]:
			fire(g, e, p + side * s * r * 0.6, side * s, 70.0, {"accel": 70.0, "max": 200.0, "r": 5.0,
				"color": Color(PALETTE_ALT["chonkzilla"])})
	# Second roll re-aims at the player.
	if rolls == 2 and int(e["bf_k"]) == 0 and T >= 1.3:
		e["bf_k"] = 1
		e["bf_roll_v"] = aim_from(g, p) * 560.0
	if float(e["bf_t"]) <= dt:
		e.erase("bf_roll_v")
		e["bf_dizzy"] = 1.8
		g.say(p + Vector2(0, -r - 30.0), "DIZZY!", Color("ffe07f"), 22)

# ================================================================= attacks: movement
const STATIONARY = ["kaiju_rage", "royal_decree", "death_bloom", "kaleidoscope", "event_horizon",
	"hydra_frenzy", "overdrive", "goo_geyser", "skull_waltz", "prism_lasers", "gear_grinder",
	"furnace_breath", "minigun_sweep"]

static func attack_move(g, e: Dictionary, attack: String, stage: int, T: float, dt: float, dir: Vector2) -> Vector2:
	var a: Dictionary = arena(g)
	if attack in STATIONARY:
		return Vector2.ZERO
	match attack:
		"quake_slam", "royal_slam", "burrow_strike", "belly_roll":
			return Vector2.ZERO
		"blink_strike":
			# Reappear exactly where the warned circle detonates.
			if bool(e.get("bf_vanish", false)):
				var pending := false
				for d in g.delayed:
					if int(d.get("owner", -1)) == int(e["id"]) and bool(d.get("blink", false)):
						pending = true
						break
				if not pending:
					e["bf_vanish"] = false
					e["pos"] = e["bf_to"]
					ring(g, e, e["pos"], 14, 180.0, randf() * TAU, {"r": 5.0})
			return Vector2.ZERO
		"strafe_run":
			var pass_len: float = 2.2
			var going: float = float(e["bf_side"]) * (1.0 if T < pass_len else -1.0)
			var run_speed: float = (2.0 * float(a["half"]) - 80.0) / pass_len
			var p: Vector2 = e["pos"]
			p.x = clampf(p.x + going * run_speed * dt, float(a["left"]) + 30.0, float(a["right"]) - 30.0)
			p.y = lerpf(p.y, float(a["y"]) - 300.0, 1.0 - exp(-3.0 * dt))
			e["pos"] = p
			e["bf_bank"] = going
			return Vector2.ZERO
		"danger_close":
			e["bf_ang2"] = float(e.get("bf_ang2", 0.0)) + 0.85 * dt
			var hero: Vector2 = g.hero["pos"]
			var want: Vector2 = hero + Vector2.from_angle(-PI * 0.5 + sin(float(e["bf_ang2"])) * 1.2) * 270.0
			e["pos"] = Vector2(e["pos"]).lerp(want, 1.0 - exp(-2.5 * dt))
			e["bf_bank"] = cos(float(e["bf_ang2"]))
			return Vector2.ZERO
		"serpent_stream", "venom_squeeze", "constrict":
			return seek(e, home_spot(g, e) + Vector2(sin(T * 2.4) * 120.0, 0.0), 1.3)
		"void_pinwheel", "gravity_well":
			return seek(e, home_spot(g, e), 0.6)
	return seek(e, home_spot(g, e), 0.8)

# ================================================================= bullets
## Scripted motion for boss bullets (called from Combat.update_shots).
static func move_bullet(g, s: Dictionary, vel: Vector2, dt: float) -> Vector2:
	var bh: Dictionary = s["bh"]
	var t: float = float(s["t"])
	var speed: float = vel.length()
	var dir: Vector2 = vel / speed if speed > 0.5 else Vector2(bh["dir"])
	if bh.has("aim_t") and not bool(bh.get("aimed", false)):
		if t >= float(bh["aim_t"]):
			bh["aimed"] = true
			var target: Vector2 = bh.get("aim_point", g.hero["pos"])
			var to: Vector2 = target - Vector2(s["pos"])
			dir = to.normalized() if to.length_squared() > 1.0 else dir
			speed = float(bh.get("aim_speed", 260.0))
		elif bh.has("stop_t") and t >= float(bh["stop_t"]):
			speed = move_toward(speed, 0.0, 900.0 * dt)
	elif bh.has("accel"):
		speed = clampf(speed + float(bh["accel"]) * dt, float(bh.get("min", 0.0)), float(bh.get("max", 600.0)))
	if bh.has("turn"):
		dir = dir.rotated(float(bh["turn"]) * dt)
	if bh.has("homing_t") and t >= float(bh["homing_t"]):
		s["homing"] = 0.0
	bh["dir"] = dir
	return dir * speed

## Big jelly balls burst into a small ring when they expire.
static func on_bullet_expire(g, s: Dictionary) -> void:
	var bh: Dictionary = s.get("bh", {})
	if not bh.has("split"):
		return
	var boss = null
	for e in g.enemies:
		if int(e["id"]) == int(s.get("boss_owner", -1)) and not bool(e.get("dead", false)):
			boss = e
			break
	if boss == null:
		return
	var n: int = int(bh["split"])
	var off: float = randf() * TAU
	for i in range(n):
		var d := Vector2.from_angle(off + TAU * float(i) / float(n))
		fire(g, boss, Vector2(s["pos"]) - Vector2(s["vel"]).normalized() * 6.0, d,
			float(bh.get("split_speed", 160.0)), {"r": 4.5, "shape": str(bh.get("split_shape", "orb"))})

# ================================================================= hazards
## Extra effects when a boss circle detonates (bullet bursts, emergence).
static func on_blast(g, item: Dictionary) -> void:
	var boss = item.get("boss")
	if boss == null or bool(boss.get("dead", false)):
		return
	if int(item.get("burst", 0)) > 0:
		ring(g, boss, item["pos"], int(item["burst"]), 150.0, randf() * TAU,
			{"r": 5.0, "shape": str(item.get("burst_shape", "orb")),
			"color": Color(PALETTE_ALT.get(str(boss["kind"]), "ffffff"))}, INF, 0.0, 12.0)

## Boss-specific delayed events (anything with an fn starting "bf_").
static func resolve(g, item: Dictionary) -> void:
	var boss = item.get("boss")
	if boss == null or bool(boss.get("dead", false)):
		return
	var pos: Vector2 = item["pos"]
	match str(item["fn"]):
		"bf_lock":
			# Missile launches from the aircraft toward the locked reticle and
			# only steers for a moment, so a late sidestep beats it.
			var from: Vector2 = boss["pos"]
			fire(g, boss, from, (pos - from).normalized(), 230.0,
				{"shape": "missile", "r": 8.0, "dmg": 0.55, "accel": 280.0, "max": 520.0,
				"homing": 1.6, "homing_t": 1.0, "life": 3.2})
			g.sfx.play_projectile("boss_fire")
		"bf_portal":
			var aim: Vector2 = aim_from(g, pos)
			fan(g, boss, pos, aim, 4 + int(item.get("stage", 0)), 0.42, 285.0, {"r": 5.0})
			g.spawn_ring_fx(pos, Color(PALETTE["voidweaver"]), 40.0)
		"bf_echo":
			fan(g, boss, pos, aim_from(g, pos), 5, 0.6, 300.0, {"shape": "shard", "r": 5.0})
			g.spawn_ring_fx(pos, Color(PALETTE["glassoracle"]), 30.0)
		"bf_squeeze":
			var hero: Vector2 = g.hero["pos"]
			var gap: float = float(item["gap"])
			var outside: bool = absf(hero.x - pos.x) > gap - 4.0
			var inside_band: bool = hero.y > float(item["top"]) and hero.y < float(item["bottom"])
			for side in [-1.0, 1.0]:
				var x: float = pos.x + side * (gap + 30.0)
				g.beams.append({"a": Vector2(x, float(item["top"])), "b": Vector2(x, float(item["bottom"])),
					"t": 0.25, "w": 26.0, "color": Color(PALETTE["coilqueen"]), "zig": true})
			if outside and inside_band:
				g.hurt(float(item["dmg"]), Vector2(hero.x, pos.y), str(item.get("src", "Coil Queen's squeeze")))
			g.sfx.play_projectile("boss_impact")
			g.add_shake(7.0)
