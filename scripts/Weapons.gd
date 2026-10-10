extends RefCounted
## Gun behaviour. Each gun has a "kind" that decides how it fires; volley() decides the
## pattern (fan, parallel, rear, side, burst, echo, ghost twin) and emit() spawns one unit.

const Combat = preload("res://scripts/Combat.gd")
const ProjectileVfx = preload("res://scripts/ProjectileVfx.gd")
const WeaponAim = preload("res://scripts/WeaponAim.gd")
const Effects = preload("res://scripts/Effects.gd")
const Characters = preload("res://scripts/Characters.gd")
const Compatibility = preload("res://scripts/WeaponCompatibility.gd")

const EVOLVED_NAMES = {"pistol": "Service Nine Mk II", "revolver": "Deadeye Prime", "shotgun": "Breachmaster",
	"smg": "Cyclone X", "minigun": "Vulcan Overdrive", "sniper": "Last Word", "rocket": "Payload Zero",
	"grenade": "Ricochet Storm", "laser": "Prism Core", "tesla": "Arc Reactor", "flame": "Inferno",
	"disc": "Razorstorm", "boomerang": "Return Protocol", "rail": "Gauss Breaker", "bees": "Hive Mind",
	"bowling": "Impact Prime", "nailgun": "Rivetstorm", "chicken": "Fowl Play", "bubble": "Pressure Chamber",
	"pinball": "Overdrive", "splitbow": "Hydra Bow", "snow": "Absolute Zero"}

static func new_gun(g, id: String, tier: int = 0) -> Dictionary:
	var w = {"id": id, "lvl": 1, "tier": clampi(tier, 0, 5), "ammo": 0, "reload": 0.0, "reload_max": 1.0, "cd": 0.0, "spin": 0.0, "heat": 0.0,
		"over": false, "charge": 0.0, "rail_needs_release": false, "focus": 0.0, "count": 0, "evolved": false, "wm": {}, "mag_max": 1, "flash": 0.0}
	w["mag_max"] = mag_size(g, w)
	w["ammo"] = w["mag_max"]
	return w

static func display_name(g, w: Dictionary) -> String:
	if bool(w["evolved"]):
		return str(EVOLVED_NAMES.get(w["id"], "EX " + str(g.weapon_db[w["id"]]["name"])))
	return str(g.weapon_db[w["id"]]["name"])

static func wm(w: Dictionary, k: String) -> float:
	return float(w["wm"].get(k, 0.0))

static func kind_of(g, w: Dictionary) -> String:
	return str(g.weapon_db[w["id"]]["kind"])

static func mag_size(g, w: Dictionary) -> int:
	return Compatibility.capacity(g, w)

## Gun tier raises base damage/rate (like a higher-rarity unit), it is not a damage modifier.
const TIER_DMG = [1.0, 1.1, 1.22, 1.36, 1.55, 1.8]
const TIER_RATE = [1.0, 1.03, 1.06, 1.1, 1.14, 1.2]
const LEVEL_DMG = 0.15
const EVOLVE_MORE = 1.3

## Evolution enhances the gun's existing resource loop, not all guns with another projectile.
const EVOLUTION_DESCRIPTIONS = {
	"pistol": "FAST DRAW: Every 9th trigger strikes with triple power. Improved critical precision.",
	"revolver": "SHOWDOWN: +8% critical chance and stronger knockback. Exactly six chambers.",
	"shotgun": "BREACHMASTER: Tighter spread, heavier impact, and stronger point-blank control.",
	"smg": "CYCLONE X: Locks accuracy twice as fast. Every sixth volley fires piercing electric-blue tracers.",
	"minigun": "OVERDRIVE: Spins up faster, retains momentum and penetrates at high spool.",
	"sniper": "LAST WORD: Higher critical chance and two more enemies pierced per shot.",
	"rocket": "PAYLOAD ZERO: Larger explosions ignite a short-lived burning zone.",
	"grenade": "RICOCHET STORM: Larger explosions and two additional wall banks.",
	"laser": "PRISM CORE: Longer reach and a wider continuous cutting beam.",
	"tesla": "ARC REACTOR: Longer arcs chain through two additional targets.",
	"flame": "INFERNO: Extra fuel, longer reach and hotter burn buildup.",
	"disc": "RAZORSTORM: Faster returns, harder cutting and stronger impact.",
	"boomerang": "RETURN PROTOCOL: Faster catches and a heavier returning strike.",
	"rail": "GAUSS BREAKER: Faster charge; Level 5 leaves a damaging ion scar.",
	"bees": "HIVE MIND: Faster-targeting bees deliver stronger venom.",
	"bowling": "IMPACT PRIME: Heavier bowling balls fling enemies farther.",
	"nailgun": "RIVETSTORM: Faster nails with a higher pinning chance.",
	"chicken": "FOWL PLAY: Wider blasts from every bouncing chicken.",
	"bubble": "PRESSURE CHAMBER: Entrap enemies longer through tougher bubbles.",
	"pinball": "OVERDRIVE: Two additional banks on every steel ball.",
	"splitbow": "HYDRA BOW: Fragments home toward nearby enemies earlier.",
	"snow": "ABSOLUTE ZERO: Snowballs accumulate freeze significantly faster."
}
## Evolved builds have distinct visual identities, not a single gold tint
## that makes 22 completely different weapons look identical.
const EVOLVED_COLORS = {
	"pistol": "eaffb7", "revolver": "ffd272", "shotgun": "ff9359",
	"smg": "6be8ff", "minigun": "ffe9a3", "sniper": "e5bcff",
	"rocket": "ff8355", "grenade": "c8ff72", "laser": "ffdb78",
	"tesla": "86c9ff", "flame": "ffac52", "disc": "8dffd3",
	"boomerang": "ffdc80", "rail": "bce8ff", "bees": "ffe06c",
	"bowling": "d9b4ff", "nailgun": "f2dbad", "chicken": "fff076",
	"bubble": "97f4ff", "pinball": "ff9ddf", "splitbow": "a5fca1",
	"snow": "d7f8ff"
}
static func evolution_description(w: Dictionary) -> String:
	return str(EVOLUTION_DESCRIPTIONS.get(str(w["id"]), "+30% damage."))
static func resource_type(g, w: Dictionary) -> String:
	match kind_of(g, w):
		"disc", "boomerang": return "RETURN"
		"beam": return "HEAT"
		"flame": return "FUEL"
		"rail": return "CHARGE"
		_: return "AMMO"
static func flame_range(g, w: Dictionary) -> float:
	return 195.0 * maxf(0.4, 1.0 + g.st("range")) * maxf(0.75, 1.0 + g.st("pspeed") * 0.1) * (1.4 if int(w["lvl"]) >= 3 else 1.0) * (1.25 if bool(w["evolved"]) else 1.0)
static func flame_cone_contains(a: Vector2, dir: Vector2, point: Vector2, reach: float, half_angle: float, target_radius: float = 0.0) -> bool:
	var offset = point - a
	var distance = offset.length()
	if distance > reach + target_radius:
		return false
	if distance <= target_radius + 15.0:
		return true
	if dir.length_squared() < 0.001:
		return false
	var radius_padding = asin(clampf(target_radius / maxf(1.0, distance), 0.0, 0.6))
	return dir.normalized().dot(offset / distance) >= cos(half_angle + radius_padding)


static func base_damage(g, w: Dictionary) -> float:
	return float(g.weapon_db[w["id"]]["dmg"]) * TIER_DMG[clampi(int(w.get("tier", 0)), 0, 5)]

## Additive "+% damage" for this gun: card damage, gun level and weapon mastery all add up.
static func dmg_pool(g, w: Dictionary) -> float:
	return g.dmg_pool(LEVEL_DMG * (int(w["lvl"]) - 1) + wm(w, "dmg") + Compatibility.resource_damage_bonus(g, w))

static func character_id(g) -> String:
	var value = g.get("selected_character")
	return str(value) if value != null else Characters.DEFAULT

static func shot_damage(g, w: Dictionary) -> float:
	var dmg = base_damage(g, w) * dmg_pool(g, w) * g.more_mult()
	if bool(w["evolved"]):
		dmg *= EVOLVE_MORE
	return dmg * g.sector_scale() * Characters.affinity(character_id(g), str(w["id"]), "weapon_damage")

static func rail_charge_seconds(g, w: Dictionary) -> float:
	# One wind-up is the only rate limit between individual Railgun shots.
	var bonus = Characters.affinity(character_id(g), "rail", "rail_charge")
	var speed = (1.0 / 0.7) * (1.0 + wm(w, "charge") + Compatibility.support_bonus(g, w)) * (2.0 if int(w["lvl"]) >= 3 else 1.0) * maxf(0.4, 1.0 + g.st("rate") * 0.5) * bonus * (1.2 if bool(w["evolved"]) else 1.0)
	return 1.0 / maxf(0.2, speed)

static func fire_rate(g, w: Dictionary) -> float:
	var d = g.weapon_db[w["id"]]
	var r = float(d["rate"]) * maxf(0.25, 1.0 + 0.06 * (int(w["lvl"]) - 1) + wm(w, "rate") + g.st("rate"))
	r *= TIER_RATE[clampi(int(w.get("tier", 0)), 0, 5)]
	if bool(w["evolved"]) and str(d["kind"]) not in ["disc", "boomerang", "rail", "beam", "flame", "spin", "chain"]:
		r *= 1.2
	return r * Characters.affinity(character_id(g), str(w["id"]), "weapon_rate")

static func reload_time(g, w: Dictionary) -> float:
	var d = g.weapon_db[w["id"]]
	return maxf(0.15, float(d["reload"]) / maxf(0.3, 1.0 + g.st("reload") + wm(w, "reload")))

static func hand_pos(g, slot: int) -> Vector2:
	var aim: Vector2 = g.hero["aim"]
	var side = [11.0, -11.0, 0.0][clampi(slot, 0, 2)]
	var back = -6.0 if slot == 2 else 0.0
	return g.hero["pos"] + aim.orthogonal() * side + aim * back

## All guns share a single origin contract for the sprite and the projectile.
static func muzzle_pos(g, slot: int) -> Vector2:
	return WeaponAim.muzzle(hand_pos(g, slot), g.hero["aim"])

## Cursor aim must converge from the actual muzzle, not run parallel to the
## hero-to-cursor ray. This matters most for precise weapons and close targets.
static func aim_for_slot(g, slot: int) -> Vector2:
	var base: Vector2 = g.hero["aim"]
	if str(g.settings.get("aim", "auto")) == "mouse" and g.autotest == "" and not g.is_touch_active():
		var target: Vector2 = g.screen_to_world(g.aim_screen)
		base = WeaponAim.shot_direction(base, muzzle_pos(g, slot), target)
	# Homing has no physical bullet to steer on cone/hitscan weapons. Convert
	# it to a SMALL capped aim correction toward a target already near the reticle.
	if not g.has_method("st") or g.st("homing") <= 0.0 or slot >= g.guns.size():
		return base
	var kind = kind_of(g, g.guns[slot])
	if kind not in ["flame", "beam", "rail", "chain"]:
		return base
	var reach = 340.0 if kind == "flame" else (1000.0 if kind == "rail" else 600.0)
	var max_angle = minf(0.30 if kind == "flame" else 0.17, float(g.st("homing")) * 0.05)
	var origin = muzzle_pos(g, slot)
	var best = INF
	var correction = 0.0
	for enemy in g.enemies_near(origin, reach):
		if bool(enemy["dead"]):
			continue
		var toward: Vector2 = enemy["pos"] - origin
		if toward.length_squared() < 1.0:
			continue
		var delta = wrapf(toward.angle() - base.angle(), -PI, PI)
		if absf(delta) > max_angle * 2.0:
			continue
		var score = absf(delta) * reach + toward.length() * 0.3
		if score < best:
			best = score
			correction = clampf(delta, -max_angle, max_angle)
	return base.rotated(correction).normalized()

# ================================================================= per frame
static func update(g, dt: float) -> void:
	var aim: Vector2 = g.hero["aim"]
	for b in g.beams:
		b["t"] = float(b["t"]) - dt
	g.beams = g.beams.filter(func(b): return float(b["t"]) > 0.0)
	for i in range(g.guns.size()):
		var w = g.guns[i]
		var d = g.weapon_db[w["id"]]
		var kind = str(d["kind"])
		var want = g.fire_wanted(i)
		# Sustained SMG fire tightens its spray; lifting the trigger resets control.
		if w["id"] == "smg":
			w["focus"] = minf(1.0, float(w.get("focus", 0.0)) + dt * (1.6 if bool(w["evolved"]) else 0.8)) if want else maxf(0.0, float(w.get("focus", 0.0)) - dt * (0.85 if bool(w["evolved"]) else 2.2))
		w["cd"] = float(w["cd"]) - dt
		w["flash"] = maxf(0.0, float(w["flash"]) - dt)
		var gun_aim = aim_for_slot(g, i)
		var muzzle = muzzle_pos(g, i)
		if kind == "spin":
			var spin_speed = (2.0 if int(w["lvl"]) >= 3 else 1.0) / 1.3 * (1.3 if bool(w["evolved"]) else 1.0) * (1.0 + Compatibility.support_bonus(g, w))
			if wm(w, "prespun") > 0:
				w["spin"] = 1.0 if want else maxf(0.0, float(w["spin"]) - dt)
			elif want and float(w["reload"]) <= 0.0:
				w["spin"] = minf(1.0, float(w["spin"]) + dt * spin_speed)
			else:
				w["spin"] = maxf(0.0, float(w["spin"]) - dt * 1.5 / (1.0 + Compatibility.support_bonus(g, w)))
		if kind == "beam":
			update_beam(g, w, i, dt, want, muzzle, gun_aim)
			continue
		if float(w["reload"]) > 0.0:
			w["reload"] = float(w["reload"]) - dt
			if float(w["reload"]) <= 0.0:
				finish_reload(g, w)
			continue
		if kind == "rail":
			# Holding attack continually charges then fires. No artificial
			# release gate and no cooldown beyond charge and magazine reload.
			# World simulation already stops while paused.
			if not want:
				w["charge"] = maxf(0.0, float(w["charge"]) - dt * 2.0)
			elif int(w["ammo"]) > 0:
				if float(w["charge"]) <= 0.001:
					g.sfx.play_projectile("rail_charge")
				w["charge"] = minf(1.0, float(w["charge"]) + dt / rail_charge_seconds(g, w))
			if float(w["charge"]) < 1.0:
				continue
		if not want or (kind != "rail" and float(w["cd"]) > 0.0) or int(w["ammo"]) <= 0:
			continue
		var rate = fire_rate(g, w)
		if kind == "spin":
			rate *= lerpf(0.18, 1.0, float(w["spin"]))
		if kind == "rail":
			w["cd"] = 0.0
			w["charge"] = 0.0
			w["rail_needs_release"] = false
		else:
			w["cd"] = float(w["cd"]) + 1.0 / maxf(0.2, rate)
			if float(w["cd"]) < -0.2:
				w["cd"] = 0.0
		var mul = 1.0
		if w["id"] == "pistol" and (int(w.get("count", 0)) + 1) % (9 if bool(w["evolved"]) else 12) == 0:
			# Signature last-round payoff survives magazine growth and Infinite Ammo.
			mul = 3.0
		if g.st("goldshot") > 0 and g.gold > 0:
			g.gold -= 1
			mul *= 1.0 + 0.6 / dmg_pool(g, w)
		volley(g, w, i, muzzle, gun_aim, {"mul": mul})
		if kind in ["disc", "boomerang"]:
			w["ammo"] = int(w["ammo"]) - 1
		elif g.st("infammo") <= 0:
			w["ammo"] = int(w["ammo"]) - 1
			if int(w["ammo"]) <= 0:
				start_reload(g, w)

static func start_reload(g, w: Dictionary) -> void:
	w["reload"] = reload_time(g, w)
	w["reload_max"] = w["reload"]
	g.sfx.play("reload")
	Effects.trigger(g, "reload", {"pos": g.hero["pos"], "gen": 0, "dir": g.hero["aim"]})

static func finish_reload(g, w: Dictionary) -> void:
	var k = kind_of(g, w)
	if k in ["disc", "boomerang"]:
		return
	w["reload"] = 0.0
	w["mag_max"] = mag_size(g, w)
	w["ammo"] = w["mag_max"]

# ================================================================= volleys
static func volley(g, w: Dictionary, slot: int, origin: Vector2, dir: Vector2, opts: Dictionary) -> void:
	var d = g.weapon_db[w["id"]]
	var kind = str(d["kind"])
	var dmg = shot_damage(g, w) * float(opts.get("mul", 1.0))
	var echo = bool(opts.get("echo", false))
	if kind in ["disc", "boomerang"]:
		if echo:
			# Burst / Echo / Ghost cards grant stored resonance instead of
			# spawning physical returning weapons without using their slots.
			w["return_resonance"] = minf(0.9, float(w.get("return_resonance", 0.0)) + minf(0.35, 0.18 * float(opts.get("mul", 0.6))))
			g.spawn_ring_fx(g.hero["pos"], Color("a4d5ff"), 22.0)
			return
		dmg *= 1.0 + float(w.get("return_resonance", 0.0))
		w["return_resonance"] = 0.0
	# A perfect returning catch builds momentum for the NEXT throw.
	if w["id"] == "boomerang" and int(w["lvl"]) >= 5 and not echo:
		dmg *= 1.0 + 0.15 * float(w.get("catch_streak", 0))
	if not echo:
		w["count"] = int(w["count"]) + 1
		g.volley_count += 1
	var big = false
	if g.st("bigshot") > 0 and g.volley_count % 5 == 0 and not echo:
		big = true
		dmg *= 2.0 + g.st("bigshot")
	var mult = int(g.st("mult"))
	var pellets = int(d["pellets"]) + int(wm(w, "pellets"))
	# Card-based multishot stays available; evolution never adds a generic projectile.
	var n = pellets + mult
	match kind:
		"pellet":
			n = pellets + 2 * mult + (3 if int(w["lvl"]) >= 3 else 0)
		"bees":
			n = pellets + 2 * mult + (2 if int(w["lvl"]) >= 3 else 0)
		"disc", "boomerang":
			n = 1
		"rocket":
			n = pellets + mult + (1 if int(w["lvl"]) >= 3 else 0)
		"grenade":
			n = pellets + mult + (2 if int(w["lvl"]) >= 5 else 0)
		"ball":
			n = pellets + mult + (1 if int(w["lvl"]) >= 3 else 0)
		"beam":
			n = pellets + mult + (1 if int(w["lvl"]) >= 3 else 0)
		_:
			if w["id"] == "pistol" and int(w["lvl"]) >= 3:
				n += 1
	n = maxi(n, 1)
	var lines = 1 + int(g.st("par"))
	var rear = mini(int(g.st("rear")), 6)
	var side = mini(int(g.st("side")), 4)
	# The volley budget rises with sectors; excess multishot becomes damage.
	var units = n * lines + rear + side * 2
	# Calculate recall conversion before the one-disc limit trims the geometry.
	var recall_power = maxf(0.0, float(lines - 1)) * 0.12 + float(rear) * 0.08 + float(side) * 0.14
	var natural_units = maxi(1, pellets)
	if kind == "pellet":
		natural_units += (3 if int(w["lvl"]) >= 3 else 0)
	elif kind == "bees":
		natural_units += (2 if int(w["lvl"]) >= 3 else 0)
	elif kind in ["rocket", "ball"]:
		natural_units += (1 if int(w["lvl"]) >= 3 else 0)
	elif kind == "grenade":
		natural_units += (2 if int(w["lvl"]) >= 5 else 0)
	elif kind == "beam":
		natural_units += (1 if int(w["lvl"]) >= 3 else 0)
	var max_units = maxi(natural_units, Compatibility.budget(g, w))
	if units > max_units:
		var before = units
		while n * lines + rear + side * 2 > max_units:
			if lines > 1 and lines * 3 >= n:
				lines -= 1
			elif n > 1:
				n -= 1
			elif rear > 0:
				rear -= 1
			else:
				side = maxi(0, side - 1)
		# Hard limits and diminishing compensation: a capped grenade volley
		# must not convert twelve missing explosions into 12x damage.
		var overflow = before - (n * lines + rear + side * 2)
		dmg *= 1.0 + minf(0.18, 0.025 * float(overflow))
	if kind in ["disc", "boomerang"]:
		# A REAL throw always occupies exactly one slot. Parallel/rear/side
		# cards improve momentum of that throw; they never mint free blades.
		dmg *= 1.0 + minf(0.85, recall_power)
		lines = 1
		rear = 0
		side = 0
	if kind == "flame":
		# Multishot is cone saturation, parallel is cone coverage; side and rear
		# modifiers will be separate low-damage vents, not N extra fire streams.
		dmg *= 1.0 + minf(0.45, 0.085 * float(maxi(0, n - 1)))
		n = 1
		lines = 1
		rear = mini(rear, 1)
		side = mini(side, 1)
	if g.shots.size() > g.shot_cap() - 40 and kind not in ["beam", "chain", "rail", "flame"]:
		return
	var spread = float(d["spread"]) * maxf(0.0, 1.0 + g.st("spreadp"))
	if w["id"] == "smg":
		spread *= lerpf(1.0, 0.30 if bool(w["evolved"]) else 0.55, float(w.get("focus", 0.0))) * (1.0 - Compatibility.support_bonus(g, w) * 0.65)
	if w["id"] == "shotgun" and bool(w["evolved"]):
		spread *= 0.7
	var random_spread = kind in ["pellet", "flame"] or w["id"] == "smg" and n == 1
	if n > 1 and not random_spread:
		spread = clampf(maxf(spread, 0.1 * (n - 1)), 0.0, 1.5)
	var perp = dir.orthogonal()
	var eopts = {"big": big, "free": bool(opts.get("free", false)), "o": base_opts(g, w, d)}
	if w["id"] == "pistol" and int(w["lvl"]) >= 5 and int(w["count"]) % 6 == 0:
		# A marked precision tracer replaces the old generic eight-bullet radial spam.
		eopts["o"]["flags"]["verdict"] = true
		eopts["o"]["pierce"] = int(eopts["o"]["pierce"]) + 3
		eopts["o"]["color"] = Color("fff6ad")
	# Patterns describe the actual fired geometry; never infer parallel from a sprite.
	var fire_pattern = str(opts.get("pattern", ""))
	if fire_pattern == "":
		if lines > 1:
			fire_pattern = "parallel"
		elif int(g.st("mult")) > 0:
			fire_pattern = "double_tap"
	eopts["pattern"] = fire_pattern
	if fire_pattern != "" and kind != "flame":
		# Cinder has a continuous cone; no fake Double Tap bullet flashes.
		ProjectileVfx.pattern(g, origin, dir, ProjectileVfx.style_for(kind, str(w["id"]), eopts["o"].get("st", {})), fire_pattern)
	for j in range(n):
		var a = 0.0
		if random_spread:
			a = randf_range(-spread * 0.5, spread * 0.5)
		elif n > 1:
			a = -spread * 0.5 + spread * float(j) / float(n - 1)
		for k in range(lines):
			var off = (float(k) - float(lines - 1) * 0.5) * 13.0
			emit(g, w, origin + perp * off, dir.rotated(a), dmg, eopts)
	for j in range(rear):
		emit(g, w, origin - dir * 30.0, (-dir).rotated((float(j) - float(rear - 1) * 0.5) * 0.2), dmg * (0.30 if kind == "flame" else 1.0), eopts)
	for j in range(side):
		var a2 = (float(j) - float(side - 1) * 0.5) * 0.2
		emit(g, w, origin, perp.rotated(a2), dmg * (0.30 if kind == "flame" else 1.0), eopts)
		emit(g, w, origin, (-perp).rotated(a2), dmg * (0.30 if kind == "flame" else 1.0), eopts)
	# Weapon-specific max level upgrades are applied through projectile signatures.
	if echo:
		# Burst echoes have their own sharp double impulse; routine ghost echoes stay quiet.
		if fire_pattern == "burst":
			g.sfx.play_projectile("fire", ProjectileVfx.style_for(kind, str(w["id"]), eopts["o"].get("st", {})), "burst", 0.5)
		return
	w["flash"] = 0.06
	var recoil = float(d["recoil"]) * (1.0 + wm(w, "recoil"))
	if recoil > 0.0:
		g.hero["push"] -= dir * recoil
		g.add_shake(recoil / 60.0)
		if wm(w, "recoilblast") > 0:
			Combat.fragments(g, origin - dir * 20.0, 8, dmg * 0.6, "forward", -dir, 1, null, false, Color("ffc66b"))
	# Play ONE distinctive synthesized gun voice per volley, never per pellet.
	# The old gun's quirky honk is retained as a quiet novelty accent.
	var sound_style = ProjectileVfx.style_for(kind, str(w["id"]), eopts["o"].get("st", {}))
	if kind == "beam":
		sound_style = "laser"
	elif kind == "rail":
		sound_style = "rail"
	elif str(w["id"]) == "shotgun":
		sound_style = "shotgun"
	g.sfx.play_projectile("fire", sound_style, fire_pattern)
	if str(d.get("sfx", "")) == "honk":
		g.sfx.play("honk", 0.05, 0.28)
	# Burst/echo on 20-shots-a-second guns would flood the screen; scale by chance instead (same DPS).
	var copy_chance = minf(1.0, 5.0 / maxf(1.0, fire_rate(g, w)))
	var aoe_weapon = kind in ["rocket", "grenade", "chicken"]
	# Burst and Echo must not restore uncapped whole-rocket damage via the
	# 1/chance compensation formula when many additional AoE hits are possible.
	var burst_copy_mul = 0.55 if aoe_weapon else 1.0 / copy_chance
	var echo_copy_mul = 0.32 if aoe_weapon else 0.6 / copy_chance
	for b in range(int(g.st("burst"))):
		if randf() < copy_chance:
			g.delayed.append({"t": 0.07 * (b + 1), "fn": "burst", "slot": slot, "mul": burst_copy_mul})
	for e in range(int(g.st("echo"))):
		if randf() < copy_chance:
			g.delayed.append({"t": 0.35 * (e + 1), "fn": "echo", "slot": slot, "pos": origin, "dir": dir, "mul": echo_copy_mul})
	if g.st("ghost") > 0:
		var mirror = Vector2(-origin.x, origin.y)
		var mdir = Vector2(-dir.x, dir.y)
		volley(g, w, slot, mirror, mdir, {"echo": true, "mul": 0.7, "free": true})
	# Fast guns (minigun, flamer, beam) would fire "on volley" cards 20-30x a second; cap at 4/s.
	if g.run_time >= float(w.get("proc_t", -1.0)):
		w["proc_t"] = g.run_time + 0.25
		Effects.trigger(g, "fire", {"pos": origin, "dir": dir, "gen": 0, "dmg": dmg})

static func free_volley(g, dir: Vector2, gen: int) -> void:
	for i in range(g.guns.size()):
		var w = g.guns[i]
		volley(g, w, i, hand_pos(g, i) + dir * 22.0, dir, {"echo": true, "free": true})

static func burst(g, slot: int, item_mul: float = 1.0) -> void:
	if slot >= g.guns.size():
		return
	var w = g.guns[slot]
	var aim: Vector2 = aim_for_slot(g, slot)
	volley(g, w, slot, muzzle_pos(g, slot), aim, {"echo": true, "free": true, "mul": float(item_mul), "pattern": "burst"})

static func echo(g, item: Dictionary) -> void:
	var slot = int(item["slot"])
	if slot >= g.guns.size():
		return
	g.fx.append({"kind": "ghostflash", "pos": item["pos"], "vel": Vector2.ZERO, "t": 0.0, "life": 0.25, "color": Color("9fb8ff"), "size": 18.0})
	volley(g, g.guns[slot], slot, item["pos"], item["dir"], {"echo": true, "mul": float(item.get("mul", 0.6)), "free": true})

# ================================================================= emitting
static func base_opts(g, w: Dictionary, d: Dictionary) -> Dictionary:
	var lvl = int(w["lvl"])
	var evolved = bool(w["evolved"])
	var specialty = Compatibility.support_bonus(g, w)
	var size = float(d["size"]) * (1.0 + g.st("size") * 0.6 + wm(w, "size")) * (1.3 if evolved and str(d["kind"]) not in ["beam", "flame", "rail"] else 1.0)
	var o = {
		"kind": str(d["kind"]), "speed": float(d["speed"]) * maxf(0.3, 1.0 + g.st("pspeed") + wm(w, "speed")),
		"life": float(d["life"]) * maxf(0.3, 1.0 + g.st("range") + wm(w, "life")), "r": size,
		"pierce": int(d["pierce"]) + int(g.st("pierce")) + int(wm(w, "pierce")),
		"bounce": int(d["bounce"]) + int(g.st("bounce")) + int(wm(w, "bounce")),
		"rico": int(d["rico"]) + int(g.st("rico")) + int(wm(w, "rico")),
		"homing": g.st("homing"), "boomer": g.st("boomer") > 0,
		"wave": Compatibility.projectile_wave(g, w), "curve": Compatibility.projectile_curve(g, w),
		"accel": g.st("accel") > 0, "split": int(g.st("split")) + int(wm(w, "split")),
		"knock": float(d["knock"]), "crit": float(d["crit"]) + wm(w, "crit"),
		"blast": float(d["blast"]) * (1.0 + wm(w, "blast")) * (1.0 + g.st("area")),
		"src": w["id"], "color": Color(str(EVOLVED_COLORS.get(str(w["id"]), "ffd75e"))) if evolved else Color(str(d["color"])), "gen": 0, "lvl": lvl, "pool": dmg_pool(g, w),
		"st": {}, "flags": {}, "gun": w,
	}
	var flags = o["flags"]
	match w["id"]:
		"revolver":
			o["crit"] += Characters.affinity(character_id(g), "revolver", "crit", 0.0)
			if lvl >= 3:
				o["pierce"] += 2
			if lvl >= 5:
				flags["duelist"] = true
		"shotgun":
			if lvl >= 5:
				flags["breach"] = true
		"minigun":
			if lvl >= 5 and float(w["spin"]) >= (0.75 if evolved else 0.92):
				flags["vulcan_sweep"] = true
				o["pierce"] += 1
		"sniper":
			flags["full_bonus"] = true
			if lvl >= 3:
				flags["killshot"] = true
			if lvl >= 5:
				flags["collateral"] = true
		"rocket":
			if lvl >= 5:
				flags["thermobaric"] = true
			if wm(w, "cluster") > 0:
				flags["cluster"] = true
		"grenade":
			if lvl >= 3:
				flags["bomblets"] = true
			if lvl >= 5:
				flags["bank_guidance"] = true
			if wm(w, "sticky") > 0:
				flags["sticky"] = true
		"flame":
			o["st"] = {"burn": 1.0}
			if lvl >= 3:
				o["life"] *= 1.4
			if wm(w, "dragon") > 0:
				flags["dragon"] = true
		"tesla":
			o["st"] = {"shock": 1.0}
		"bees":
			o["st"] = {"poison": 0.7}
			if lvl >= 5:
				flags["hive_scent"] = true
		"bowling":
			flags["fling"] = true
			if lvl >= 5:
				flags["perfect_strike"] = true
		"nailgun":
			flags["pin"] = (0.7 if lvl >= 3 else 0.35) + wm(w, "pin")
			if lvl >= 5:
				flags["rivet_tether"] = true
		"chicken":
			if lvl >= 3:
				o["rico"] += 3
			if lvl >= 5:
				flags["panic"] = true
		"bubble":
			o["st"] = {"wet": 1.0}
			flags["trap"] = (3 if lvl >= 3 else 1) + int(wm(w, "trap"))
			if lvl >= 5:
				flags["pressure_chain"] = 2
		"pinball":
			flags["bounce_dmg"] = true
			if lvl >= 3:
				o["bounce"] += 4
			if lvl >= 5:
				flags["perfect_bank"] = true
			if wm(w, "multiball") > 0:
				flags["multiball"] = true
		"splitbow":
			flags["split_first"] = (5 if lvl >= 3 else 3) + int(wm(w, "split"))
			if lvl >= 5:
				flags["hydra_seek"] = true
			if wm(w, "fraghome") > 0:
				flags["frag_home"] = true
		"snow":
			o["st"] = {"freeze": 1.0}
			flags["grow"] = 2.5
			if lvl >= 3:
				flags["shatter_aoe"] = true
			if lvl >= 5:
				flags["whiteout"] = true
			if wm(w, "instafreeze") > 0:
				flags["instafreeze"] = true
		"smg":
			if lvl >= 5:
				flags["suppress"] = true
		"disc":
			if lvl >= 5:
				flags["vortex_recall"] = true
		"boomerang":
			if lvl >= 5:
				flags["momentum_catch"] = true
	# Evolution adds a weapon-native attack effect, not an indiscriminate
	# projectile-count increase. Secondary procs obey their original budgets.
	if evolved:
		match str(w["id"]):
			"pistol":
				o["crit"] += 0.06
			"revolver":
				o["crit"] += 0.08
				o["knock"] *= 1.30
			"shotgun":
				o["knock"] *= 1.45
			"smg":
				if int(w["count"]) % 6 == 0:
					o["pierce"] += 2
					o["color"] = Color("72dfff")
					flags["cyclone_tracer"] = true
			"minigun":
				if float(w["spin"]) >= 0.8:
					o["pierce"] += 1
					o["color"] = Color("ffe88b")
			"sniper":
				o["crit"] += 0.15
				o["pierce"] += 2
			"rocket":
				flags["fire_puddle"] = true
			"grenade":
				o["bounce"] += 2
			"bees":
				o["homing"] = maxf(float(o["homing"]), 6.5)
				o["st"]["poison"] = float(o["st"].get("poison", 0.7)) + 0.4
			"bowling":
				o["knock"] *= 1.45
			"nailgun":
				flags["pin"] = minf(0.95, float(flags.get("pin", 0.35)) + 0.18)
			"chicken":
				o["blast"] *= 1.24
			"bubble":
				flags["trap_bonus"] = maxf(0.22, float(flags.get("trap_bonus", 0.0)))
			"pinball":
				o["bounce"] += 2
			"splitbow":
				flags["frag_home"] = true
			"snow":
				o["st"]["freeze"] = float(o["st"].get("freeze", 1.0)) + 0.4
			"disc", "boomerang":
				o["knock"] *= 1.35
	# A capped magazine doesn't mean a dead card: each gun interprets
	# the virtual overflow through its existing signature behavior.
	match str(w["id"]):
		"pistol":
			o["crit"] += specialty * 0.32
		"revolver":
			o["crit"] += specialty * 0.20
		"shotgun", "bowling":
			o["knock"] *= 1.0 + specialty
		"rocket", "grenade", "chicken":
			o["blast"] *= 1.0 + specialty * 0.8
		"bees":
			o["st"]["poison"] = float(o["st"].get("poison", 0.7)) + specialty
		"nailgun":
			o["flags"]["pin"] = minf(0.95, float(o["flags"].get("pin", 0.35)) + specialty * 0.6)
		"bubble":
			o["flags"]["trap_bonus"] = maxf(float(o["flags"].get("trap_bonus", 0.0)), specialty)
		"pinball":
			o["flags"]["bank_bonus"] = specialty
		"splitbow":
			if specialty > 0.0:
				o["flags"]["frag_home"] = true
		"snow":
			o["st"]["freeze"] = float(o["st"].get("freeze", 1.0)) + specialty
	if evolved and w["id"] in ["rocket", "grenade"]:
		o["blast"] *= 1.2
	if wm(w, "critpierce") > 0:
		flags["critpierce"] = true
	return o

static func emit(g, w: Dictionary, pos: Vector2, dir: Vector2, dmg: float, eopts: Dictionary) -> void:
	var d = g.weapon_db[w["id"]]
	var kind = str(d["kind"])
	if kind in ["rail", "beam", "chain"]:
		ProjectileVfx.muzzle(g, pos, dir, ProjectileVfx.style_for(kind, str(w["id"])), 12.0)
	match kind:
		"beam":
			fire_beam(g, w, pos, dir, dmg)
			return
		"chain":
			fire_chain(g, w, pos, dir, dmg)
			return
		"rail":
			fire_rail(g, w, pos, dir, dmg)
			return
		"flame":
			fire_flame(g, w, pos, dir, dmg)
			return
	var o = eopts["o"].duplicate() if eopts.has("o") else base_opts(g, w, d)
	o["vfx_pattern"] = str(eopts.get("pattern", ""))
	if kind == "pellet":
		o["speed"] *= randf_range(0.82, 1.15)
		o["life"] *= randf_range(0.85, 1.1)
	if kind == "bees":
		# Bee bullets are true homing bee actors, not generic straight projectiles.
		o["kind"] = "bee"
		o["homing"] = maxf(float(o["homing"]), 5.0)
	if bool(eopts.get("big", false)):
		o["r"] *= 2.5
		o["knock"] *= 2.0
		o["flags"]["big"] = true
	if kind in ["disc", "boomerang"]:
		o["flags"]["owner"] = not bool(eopts.get("free", false))
	if kind == "bubble":
		o["flags"]["trapped"] = 0
	# A cap for *live* actors is independent of the magazine and volley caps.
	# Overflow reinforces an existing actor instead of silently spawning 100 bees.
	var live_limit = Compatibility.active_cap(str(w["id"]))
	if live_limit > 0:
		var live_count = 0
		var reinforced = null
		for active in g.shots:
			if bool(active.get("dead", false)) or str(active.get("src", "")) != str(w["id"]):
				continue
			live_count += 1
			if reinforced == null:
				reinforced = active
		if live_count >= live_limit:
			if reinforced != null:
				reinforced["dmg"] = minf(float(reinforced["base_dmg"]) * 1.3, float(reinforced["dmg"]) * 1.025)
			return
	Combat.shot(g, pos, dir, dmg, o)

static func fire_flame(g, w: Dictionary, origin: Vector2, direction: Vector2, damage: float, can_bank: bool = true) -> void:
	# A true continuous area cone: NO flame bullet entities in Combat.shot().
	# Each fuel tick tests nearby enemies once, not 30 short-lived colliders.
	var reach = flame_range(g, w) * (1.0 + minf(0.18, 0.03 * float(maxi(0, int(g.st("pierce"))))))
	damage *= 1.0 + 0.6 * Compatibility.support_bonus(g, w)
	var half_angle = maxf(0.12, 0.23 * (1.0 + g.st("spreadp") * 0.35) + minf(0.28, 0.04 * float(g.st("par")) + 0.018 * float(g.st("mult")) + 0.045 * float(g.st("size"))))
	# Curving and wavy rounds are a gently oscillating flame sheet, not bullets.
	if can_bank and (g.st("curve") != 0.0 or g.st("wave") > 0.0):
		direction = direction.rotated(sin(g.run_time * 7.0) * minf(0.12, absf(g.st("curve")) * 0.025 + g.st("wave") * 0.0005))
	# Cinder is a cone, not a bullet: test the barrel's actual angular
	# footprint directly. A few fuel ticks can ignite its normal fuse.
	for barrel in g.barrels:
		if float(barrel["hp"]) <= 0.0 or bool(barrel.get("armed", false)) or float(barrel["drop"]) > 0.0:
			continue
		if flame_cone_contains(origin, direction, barrel["pos"], reach, half_angle, 20.0):
			barrel["hp"] = maxf(0.0, float(barrel["hp"]) - damage)
	var hits = 0
	var anchor = null
	for enemy in g.enemies_near(origin, reach + 30.0):
		if bool(enemy["dead"]) or float(enemy.get("charm", 0.0)) > 0.0:
			continue
		if not flame_cone_contains(origin, direction, enemy["pos"], reach, half_angle, float(enemy["r"])):
			continue
		var distance_ratio = clampf(origin.distance_to(enemy["pos"]) / maxf(1.0, reach), 0.0, 1.0)
		var travelling_heat = 1.0 + (0.20 * distance_ratio if g.st("accel") > 0.0 else 0.0)
		Combat.hit(g, enemy, damage * travelling_heat, {"pos": enemy["pos"], "gen": 0, "dir": direction,
			"knock": 8.0, "src": "flame", "st": {"burn": 1.0 + Compatibility.support_bonus(g, w) + (0.35 if bool(w["evolved"]) else 0.0)}, "pool": dmg_pool(g, w)})
		if anchor == null and not bool(enemy["dead"]):
			anchor = enemy
		hits += 1
		if hits >= 24:
			break
	# Restore the original moving-flame silhouette without restoring the
	# old 30Hz physics projectiles. These are visual-only, bounded sprites in
	# the existing FX list; damage is handled solely by the cone above.
	flame_visuals(g, origin, direction, reach, half_angle, can_bank)
	# Splinter / Cluster Rounds adapt into heat jumping to fresh targets at a
	# capped interval; they do not create phantom flame projectiles.
	if anchor != null and int(g.st("split")) > 0 and g.run_time >= float(w.get("flame_arc_t", -1.0)):
		w["flame_arc_t"] = g.run_time + 0.3
		var transferred = 0
		for other in g.enemies_near(anchor["pos"], 130.0):
			if bool(other["dead"]) or other == anchor or float(other["burn"]) > 0.0:
				continue
			Combat.hit(g, other, damage * 0.4, {"pos": other["pos"], "gen": 1, "dir": Vector2.ZERO,
				"knock": 0.0, "src": "flame", "st": {"burn": 1.0}, "pool": dmg_pool(g, w), "noproc": true})
			g.beams.append({"a": anchor["pos"], "b": other["pos"], "t": 0.13, "w": 2.0, "color": Color("ffb26b")})
			transferred += 1
			if transferred >= mini(3, int(g.st("split"))):
				break
	# Enemy ricochet becomes a short heat jump to another victim. This is
	# capped separately from Splinter's burning spread to limit proc chains.
	if can_bank and anchor != null and g.st("rico") > 0.0 and g.run_time >= float(w.get("flame_rico_t", -1.0)):
		w["flame_rico_t"] = g.run_time + 0.36
		for other in g.enemies_near(anchor["pos"], 165.0):
			if bool(other["dead"]) or other == anchor:
				continue
			Combat.hit(g, other, damage * 0.52, {"pos": other["pos"], "gen": 1, "dir": Vector2.ZERO,
				"knock": 0.0, "src": "flame", "st": {"burn": 1.0}, "pool": dmg_pool(g, w), "noproc": true})
			g.beams.append({"a": anchor["pos"], "b": other["pos"], "t": 0.11, "w": 2.4, "color": Color("ffd16b")})
			break
	# Wall bounces turn into ONE bounded reflected fire sheet. This is NOT
	# a wall-spawned fire bullet, and cannot recursively reflect.
	if can_bank and g.st("bounce") > 0.0 and absf(direction.x) > 0.12 and g.run_time >= float(w.get("flame_bank_t", -1.0)):
		var wall_x = (g.road_half - 5.0) if direction.x > 0.0 else (-g.road_half + 5.0)
		var wall_distance = (wall_x - origin.x) / direction.x
		if wall_distance > 0.0 and wall_distance < reach:
			w["flame_bank_t"] = g.run_time + 0.30
			var bank_at = origin + direction * wall_distance
			var bank_dir = Vector2(-direction.x, direction.y).normalized()
			g.spawn_ring_fx(bank_at, Color("ffc46a"), 23.0)
			fire_flame(g, w, bank_at, bank_dir, damage * 0.3, false)
	# The Dragon mastery still ignites occasional ground fires.
	if wm(w, "dragon") > 0.0 and randf() < 0.015:
		g.add_zone("fire", origin + direction * reach * 0.75, 34.0, 2.0)

## Flame sprites are NOT Combat.shot projectiles: no hit tests, homing, bounces
## or collision components. A persistent stream of overlapping fire puffs,
## matching the earlier flamethrower look, has a small fixed VFX budget.
static func flame_visuals(g, origin: Vector2, direction: Vector2, reach: float, half_angle: float, primary: bool) -> void:
	if g.fx.size() >= 320:
		return
	var quality = str(g.settings.get("vfx_quality", "medium"))
	var count = 2 if quality == "low" else (4 if quality == "high" else 3)
	if not primary:
		count = maxi(1, count - 1)
	var unit = direction.normalized()
	if unit.length_squared() < 0.001:
		return
	for i in range(count):
		if g.fx.size() >= 320:
			break
		var life = randf_range(0.24, 0.35)
		var travel = reach * randf_range(0.88, 1.05)
		var flame_dir = unit.rotated(randf_range(-half_angle * 0.45, half_angle * 0.45))
		var radius = randf_range(12.0, 19.0) * (0.78 if not primary else 1.0)
		g.fx.append({"kind": "cinder_flame", "pos": origin + unit * randf_range(2.0, 14.0),
			"vel": flame_dir * (travel / life), "t": 0.0, "life": life,
			"color": Color("ff9331"), "size": radius, "seed": randf() * TAU})


static func update_beam(g, w: Dictionary, slot: int, dt: float, want: bool, muzzle: Vector2, aim: Vector2) -> void:
	var lvl = int(w["lvl"])
	var no_heat = lvl >= 5 or g.st("infammo") > 0
	if bool(w["over"]):
		w["heat"] = float(w["heat"]) - dt * 1.4 * Compatibility.cooling_speed(g)
		if float(w["heat"]) <= 0.0:
			w["heat"] = 0.0
			w["over"] = false
		return
	if not want:
		w["heat"] = maxf(0.0, float(w["heat"]) - dt * 1.6 * Compatibility.cooling_speed(g))
		return
	if not no_heat:
		w["heat"] = float(w["heat"]) + dt
		if float(w["heat"]) >= Compatibility.heat_limit(g):
			w["over"] = true
			w["heat"] = 1.2
			g.sfx.play("deny")
			Effects.trigger(g, "reload", {"pos": g.hero["pos"], "gen": 0, "dir": aim})
			return
	if float(w["cd"]) > 0.0:
		# Keep drawing the beam between damage ticks.
		var n_vis = 1 + int(g.st("mult")) + int(wm(w, "pellets")) + (1 if lvl >= 3 else 0)
		for j in range(n_vis):
			var a = 0.0 if n_vis == 1 else (-0.18 * (n_vis - 1) * 0.5 + 0.18 * j)
			beam_visual(g, w, muzzle, aim.rotated(a))
		return
	w["cd"] = 1.0 / fire_rate(g, w)
	volley(g, w, slot, muzzle, aim, {})

static func beam_visual(g, w: Dictionary, a: Vector2, dir: Vector2) -> void:
	# Keep displayed laser geometry identical to the snake-card hit path.
	dir = dir.rotated(Compatibility.instant_sway(g, w))
	var length = 560.0 * (1.0 + g.st("range")) * (1.25 if bool(w["evolved"]) else 1.0) * (1.0 + Compatibility.instant_reach_bonus(g, w))
	var width = minf(g.projectile_size_cap() * 2.0, 9.0 * (2.0 if int(w["lvl"]) >= 5 else 1.0) * (1.0 + g.st("size") * 0.5) * (1.22 if bool(w["evolved"]) else 1.0) * (1.0 + minf(0.16, maxf(0.0, g.st("wave")) * 0.002)))
	for segment in line_segments(g, a, dir, length, line_bounces(g, w)):
		g.beams.append({"a": segment["a"], "b": segment["b"], "t": 0.05, "w": width,
			"color": Color("ffd75e") if bool(w["evolved"]) else Color(str(g.weapon_db[w["id"]]["color"]))})

static func line_bounces(g, w: Dictionary) -> int:
	return mini(12, maxi(0, int(g.weapon_db[w["id"]]["bounce"]) + int(g.st("bounce")) + int(wm(w, "bounce"))))

static func line_ricochets(g, w: Dictionary) -> int:
	return mini(12, maxi(0, int(g.weapon_db[w["id"]]["rico"]) + int(g.st("rico")) + int(wm(w, "rico"))))

## Instant-hit weapons need their own wall path; they never create Combat.shot projectiles.
static func line_segments(g, from: Vector2, direction: Vector2, length: float, bounces: int) -> Array:
	var segments = []
	# Avoid zero-length tracer/hit segments when aim is temporarily unset.
	if length <= 0.1 or direction.length_squared() < 0.000001:
		return segments
	var wall = float(g.road_half) - 5.0
	var start = Vector2(clampf(from.x, -wall, wall), from.y)
	var dir = direction.normalized()
	var remaining = length
	var turns = 0
	while remaining > 0.1:
		var to_wall = INF
		if absf(dir.x) > 0.0001:
			to_wall = ((wall if dir.x > 0.0 else -wall) - start.x) / dir.x
		if to_wall <= 0.001:
			if turns >= bounces:
				break
			dir.x = -dir.x
			turns += 1
			continue
		var distance = minf(remaining, to_wall)
		var finish = start + dir * distance
		segments.append({"a": start, "b": finish})
		remaining -= distance
		if remaining <= 0.1 or to_wall > distance or turns >= bounces:
			break
		start = finish
		dir.x = -dir.x
		turns += 1
	return segments

static func line_targets(g, segments: Array, width: float, limit: int) -> Array:
	var targets = []
	var seen = {}
	for segment in segments:
		var start: Vector2 = segment["a"]
		var finish: Vector2 = segment["b"]
		var length = start.distance_to(finish)
		var candidates = []
		for e in g.enemies_near((start + finish) * 0.5, length * 0.5 + 30.0):
			if bool(e["dead"]) or seen.has(e["id"]):
				continue
			if Combat.seg_dist2(start, finish, e["pos"]) < pow(float(e["r"]) + width, 2):
				candidates.append(e)
		candidates.sort_custom(func(x, y): return start.distance_squared_to(x["pos"]) < start.distance_squared_to(y["pos"]))
		for e in candidates:
			seen[e["id"]] = true
			targets.append({"enemy": e, "dir": (finish - start).normalized()})
			if targets.size() >= limit:
				return targets
	return targets

static func chain_line(g, targets: Array, jumps: int, dmg: float, knock: float, source: String, pool: float, color: Color) -> void:
	if jumps <= 0 or targets.is_empty():
		return
	var seen = {}
	for target in targets:
		seen[target["enemy"]["id"]] = true
	var from: Vector2 = targets[-1]["enemy"]["pos"]
	for i in range(jumps):
		var next = next_chain_target(g, from, seen)
		if next == null:
			break
		seen[next["id"]] = true
		var direction: Vector2 = (next["pos"] - from).normalized()
		g.beams.append({"a": from, "b": next["pos"], "t": 0.12, "w": 5.0, "color": color})
		Combat.hit(g, next, dmg * pow(0.7, i + 1), {"pos": next["pos"], "gen": 1, "dir": direction, "knock": knock, "src": source, "pool": pool})
		from = next["pos"]

static func next_chain_target(g, from: Vector2, seen: Dictionary) -> Variant:
	var nearest = null
	var best = 260.0 * 260.0
	for e in g.enemies_near(from, 260.0):
		if bool(e["dead"]) or seen.has(e["id"]):
			continue
		var distance = from.distance_squared_to(e["pos"])
		if distance < best:
			best = distance
			nearest = e
	return nearest

static func fire_beam(g, w: Dictionary, a: Vector2, dir: Vector2, dmg: float) -> void:
	dir = dir.rotated(Compatibility.instant_sway(g, w))
	var length = 560.0 * (1.0 + g.st("range")) * (1.25 if bool(w["evolved"]) else 1.0) * (1.0 + Compatibility.instant_reach_bonus(g, w))
	var width = minf(g.projectile_size_cap() * 2.0, 9.0 * (2.0 if int(w["lvl"]) >= 5 else 1.0) * (1.0 + g.st("size") * 0.5) * (1.0 + minf(0.16, maxf(0.0, g.st("wave")) * 0.002)))
	var segments = line_segments(g, a, dir, length, line_bounces(g, w))
	var max_hits = 1 + int(g.st("pierce")) + int(wm(w, "pierce")) + int(g.weapon_db[w["id"]]["pierce"])
	var targets = line_targets(g, segments, width, max_hits)
	# Prism Beam uses hitscan segments; it never enters projectile collisions.
	for segment in segments:
		Combat.damage_barrels_segment(g, segment["a"], segment["b"], width, dmg)
	for target in targets:
		var e = target["enemy"]
		var distance_part = a.distance_to(e["pos"]) / maxf(1.0, length)
		Combat.hit(g, e, dmg * Compatibility.instant_acceleration(g, w, distance_part), {"pos": e["pos"], "gen": 0, "dir": target["dir"], "knock": 14.0, "src": w["id"], "pool": dmg_pool(g, w)})
		ProjectileVfx.impact(g, e["pos"], target["dir"], "fire", 7.0)
		if g.st("split") > 0 and randf() < 0.25:
			Combat.fragments(g, e["pos"], int(g.st("split")), dmg * (0.4 + g.st("fragdmg")), "forward", target["dir"], 1, null, false, Color("d9b8ff"))
	# Max-level prism catches the first enemy and refracts into two short, weaker side-rays.
	# Unlike increasing width, this attacks new angles; only one fork per beam tick.
	if int(w["lvl"]) >= 5 and not targets.is_empty():
		var fork_at: Vector2 = targets[0]["enemy"]["pos"]
		var seen = {targets[0]["enemy"]["id"]: true}
		for target in targets:
			seen[target["enemy"]["id"]] = true
		for side in [-1.0, 1.0]:
			var fork_dir = dir.rotated(side * 0.65)
			var ray = line_segments(g, fork_at, fork_dir, 220.0, 0)
			for branch_segment in ray:
				Combat.damage_barrels_segment(g, branch_segment["a"], branch_segment["b"], 9.0, dmg * 0.45)
			for hit_info in line_targets(g, ray, 9.0, 2):
				var victim = hit_info["enemy"]
				if seen.has(victim["id"]):
					continue
				seen[victim["id"]] = true
				Combat.hit(g, victim, dmg * 0.45, {"pos": victim["pos"], "gen": 1, "dir": fork_dir, "knock": 8.0, "src": "laser", "pool": dmg_pool(g, w), "noproc": true})
			g.beams.append({"a": fork_at, "b": fork_at + fork_dir * 220.0, "t": 0.1, "w": 4.0, "color": Color("e5baff")})
	var color = Color("ffd75e") if bool(w["evolved"]) else Color(str(g.weapon_db[w["id"]]["color"]))
	for segment in segments:
		g.beams.append({"a": segment["a"], "b": segment["b"], "t": 0.07, "w": width, "color": color})
	chain_line(g, targets, line_ricochets(g, w), dmg, 14.0, str(w["id"]), dmg_pool(g, w), color)

static func fire_chain(g, w: Dictionary, a: Vector2, dir: Vector2, dmg: float) -> void:
	dir = dir.rotated(Compatibility.instant_sway(g, w))
	var lvl = int(w["lvl"])
	var reach = 330.0 * (1.0 + g.st("range")) * (1.25 if bool(w["evolved"]) else 1.0) * (1.0 + Compatibility.support_bonus(g, w) * 0.8 + Compatibility.instant_reach_bonus(g, w))
	var first = null
	var best = INF
	for e in g.enemies_near(a, reach):
		if bool(e["dead"]) or float(e["charm"]) > 0.0:
			continue
		var off: Vector2 = e["pos"] - a
		var dist = off.length()
		if dist > reach:
			continue
		var score = dist * (1.0 + (1.0 - off.normalized().dot(dir)) * 1.5)
		if score < best:
			best = score
			first = e
	# Arc Caster should be able to pick an explosive barrel even without
	# a nearby enemy. A barrel can be selected as the arc's primary target,
	# but cannot participate in enemy-only chain routing.
	var nearest_barrel = null
	var barrel_score = best
	for barrel in g.barrels:
		if float(barrel["hp"]) <= 0.0 or bool(barrel.get("armed", false)) or float(barrel["drop"]) > 0.0:
			continue
		var to_barrel: Vector2 = barrel["pos"] - a
		var distance = to_barrel.length()
		if distance < 1.0 or distance > reach:
			continue
		var heading = to_barrel.normalized().dot(dir)
		if heading < 0.72:
			continue
		var score = distance * (1.0 + (1.0 - heading) * 1.5)
		if score < barrel_score:
			barrel_score = score
			nearest_barrel = barrel
	if nearest_barrel != null:
		var endpoint: Vector2 = nearest_barrel["pos"]
		Combat.damage_barrels_segment(g, a, endpoint, 5.0, dmg)
		g.beams.append({"a": a, "b": endpoint, "t": 0.13, "w": 3.5, "color": Color("9fd8ff"), "zig": true})
		ProjectileVfx.impact(g, endpoint, dir, "shock", 9.0)
		g.sfx.play("zap")
		return
	if first == null:
		g.beams.append({"a": a, "b": a + dir * reach * 0.6, "t": 0.06, "w": 3.0, "color": Color("8fc8ff"), "zig": true})
		return
	var jumps = mini(12, int(g.weapon_db[w["id"]]["rico"]) + int(g.st("rico")) + int(wm(w, "rico")) + (3 if lvl >= 3 else 0) + (2 if bool(w["evolved"]) else 0) + Compatibility.adapted_pierce(g, w))
	chain_from(g, a, first, jumps, dmg, lvl >= 5, {})

static func chain_from(g, a: Vector2, first: Dictionary, jumps: int, dmg: float, fork: bool, visited: Dictionary) -> void:
	var cur = first
	var prev = a
	for j in range(jumps + 1):
		if cur == null:
			break
		visited[cur["id"]] = true
		g.beams.append({"a": prev, "b": cur["pos"], "t": 0.1, "w": 3.5, "color": Color("9fd8ff"), "zig": true})
		Combat.damage_barrels_segment(g, prev, cur["pos"], 3.5, dmg)
		Combat.hit(g, cur, dmg, {"pos": cur["pos"], "gen": 0, "dir": (cur["pos"] - prev).normalized(), "knock": 40.0, "st": {"shock": 1.0}, "src": "tesla"})
		ProjectileVfx.impact(g, cur["pos"], (cur["pos"] - prev).normalized(), "shock", 9.0)
		prev = cur["pos"]
		var nxt = null
		var best = 175.0 * 175.0
		for e in g.enemies_near(prev, 175.0):
			if bool(e["dead"]) or visited.has(e["id"]):
				continue
			var dd = prev.distance_squared_to(e["pos"])
			if dd < best:
				best = dd
				nxt = e
		# Level-five conductor: every third connected victim gets a brief static stun.
		if fork and j > 0 and j % 3 == 2 and not bool(cur["dead"]):
			cur["stun"] = maxf(float(cur["stun"]), 0.12 if bool(cur["boss"]) else 0.65)
			g.spawn_ring_fx(cur["pos"], Color("e4f7ff"), 58.0)
			g.sfx.play_projectile("status", "shock", "", 0.5)
		dmg *= 0.92 + minf(0.045, maxf(0.0, g.st("accel")) * 0.03)
		cur = nxt
	g.sfx.play("zap")

static func fire_rail(g, w: Dictionary, a: Vector2, dir: Vector2, dmg: float) -> void:
	dir = dir.rotated(Compatibility.instant_sway(g, w))
	var length = 1100.0 * (1.0 + Compatibility.instant_reach_bonus(g, w))
	var width = 14.0 * (1.0 + g.st("size") * 0.5) * (1.0 + minf(0.16, maxf(0.0, g.st("wave")) * 0.002))
	var segments = line_segments(g, a, dir, length, line_bounces(g, w))
	var targets = line_targets(g, segments, width, 999)
	for target in targets:
		var e = target["enemy"]
		Combat.hit(g, e, dmg * Compatibility.instant_acceleration(g, w, a.distance_to(e["pos"]) / maxf(1.0, length)), {"pos": e["pos"], "gen": 0, "dir": target["dir"], "knock": float(g.weapon_db["rail"]["knock"]), "src": "rail", "pool": dmg_pool(g, w)})
		ProjectileVfx.pierce(g, e["pos"], target["dir"], "pierce")
	var color = Color("ffd75e") if bool(w["evolved"]) else Color("8fe4ff")
	for segment in segments:
		Combat.damage_barrels_segment(g, segment["a"], segment["b"], width, dmg)
		g.beams.append({"a": segment["a"], "b": segment["b"], "t": 0.22, "w": width * 1.6, "color": color, "rail": true})
		if int(w["lvl"]) >= 5:
			g.add_zone("lightning", segment["a"], 14.0, 1.5, {"a": segment["a"], "b": segment["b"]})
	chain_line(g, targets, line_ricochets(g, w), dmg, float(g.weapon_db["rail"]["knock"]), "rail", dmg_pool(g, w), color)
	g.flash_screen(Color("bfefff"), 0.08)
