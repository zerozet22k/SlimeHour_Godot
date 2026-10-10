extends RefCounted
## The card engine. A card is stat mods + procs ("on X, do Y").
## Every stat key and every proc trigger/action used in data/cards.json is handled here or
## read by Combat/Weapons via g.st(key). tools/validate.py enforces that.

const Combat = preload("res://scripts/Combat.gd")
const Weapons = preload("res://scripts/Weapons.gd")

const TRIGGERS = ["fire", "hit", "crit", "kill", "dash", "dashend", "perfect", "hurt", "reload", "xp",
	"level", "timer", "explosion", "sector", "walk", "still", "lowhp"]

# ================================================================= stats
static func recalc(g) -> void:
	var S = {}
	for id in g.owned:
		var n = int(g.owned[id])
		if id == "_shop_hp":
			S["maxhp"] = float(S.get("maxhp", 0.0)) + SHOP_MAXHP * n
			continue
		var c = g.card_by_id.get(id)
		if c == null:
			continue
		var mods: Dictionary = c.get("mods", {})
		for k in mods:
			S[k] = float(S.get(k, 0.0)) + stack_total(float(mods[k]), n)
		# "+X% TOTAL damage" multiplies with everything else (and with each other).
		if mods.has("tdmg"):
			S["more"] = float(S.get("more", 1.0)) * pow(1.0 + float(mods["tdmg"]), n)
	for b in g.buffs:
		S[b["stat"]] = float(S.get(b["stat"], 0.0)) + float(b["amt"])
	for k in g.gate_mods:
		S[k] = float(S.get(k, 0.0)) + float(g.gate_mods[k])
	var meta = g.meta_mods()
	for k in meta:
		S[k] = float(S.get(k, 0.0)) + float(meta[k])
	if float(S.get("ambi", 0.0)) > 0.0 and g.guns.size() >= 2:
		S["rate"] = float(S.get("rate", 0.0)) + 0.2 * float(S["ambi"])
		S["mult"] = float(S.get("mult", 0.0)) + float(S["ambi"])
	g.S = S
	# Max HP changes keep the current missing HP the same.
	if not g.hero.is_empty():
		var maxhp = maxf(20.0, 100.0 + 12.0 * maxi(0, g.sector - 1) + float(S.get("maxhp", 0.0)))
		var diff = maxhp - float(g.hero["maxhp"])
		g.hero["maxhp"] = maxhp
		if diff > 0:
			g.hero["hp"] = float(g.hero["hp"]) + diff
		g.hero["hp"] = minf(float(g.hero["hp"]), maxhp)
	# Weapon-specific mastery mods.
	for w in g.guns:
		var wm = {}
		for id in g.owned:
			var c = g.card_by_id.get(id)
			if c == null or not c.has("wmods"):
				continue
			var allowed: Array = c.get("req", {}).get("weapon", [])
			if not allowed.has(w["id"]):
				continue
			for k in c["wmods"]:
				wm[k] = float(wm.get(k, 0.0)) + stack_total(float(c["wmods"][k]), int(g.owned[id]))
		w["wm"] = wm
		w["mag_max"] = Weapons.mag_size(g, w)
	# Proc table, keeping counters/timers alive across recalcs.
	var table = {}
	for id in g.owned_order:
		var c = g.card_by_id.get(id)
		if c == null:
			continue
		var plist: Array = c.get("procs", [])
		for i in range(plist.size()):
			var key = id + ":" + str(i)
			var rt = g.proc_state.get(key)
			if rt == null:
				rt = {"count": 0, "acc": 0.0, "icd": 0.0}
				g.proc_state[key] = rt
			rt["p"] = plist[i]
			rt["stacks"] = int(g.owned[id])
			rt["card"] = id
			var on = str(plist[i]["on"])
			if not table.has(on):
				table[on] = []
			table[on].append(rt)
	if float(S.get("gate_boom", 0.0)) > 0.0:
		var key = "gate:boom"
		if not g.proc_state.has(key):
			g.proc_state[key] = {"count": 0, "acc": 0.0, "icd": 0.0}
		var rt2 = g.proc_state[key]
		rt2["p"] = {"on": "hit", "do": "explode", "chance": 0.3, "r": 50, "rel": 0.5}
		rt2["stacks"] = 1
		rt2["card"] = "gate"
		if not table.has("hit"):
			table["hit"] = []
		table["hit"].append(rt2)
	g.procs = table
	g.stats_dirty = false

## Percent bonuses diminish per extra copy: 1st copy 100%, 2nd 70%, 3rd 49%...
## Whole-number bonuses (projectiles, pierce, blades, luck...) always stack fully.
const STACK_FALLOFF = 0.7

static func stack_total(v: float, n: int) -> float:
	if n <= 0:
		return 0.0
	if absf(v) >= 1.0 and is_equal_approx(v, roundf(v)):
		return v * n
	return v * (1.0 - pow(STACK_FALLOFF, n)) / (1.0 - STACK_FALLOFF)

## Names and units here match actual mod math. Proc-only cards expose their trigger numbers too.
const STAT_NAMES = {"dmg": "DMG", "rate": "FIRE RATE", "crit": "CRIT CHANCE", "critdmg": "CRIT DMG",
	"speed": "MOVE SPEED", "pspeed": "SHOT SPEED", "size": "SHOT SIZE", "range": "RANGE",
	"knock": "KNOCKBACK", "reload": "RELOAD", "magnet": "PICKUP RANGE", "goldp": "GOLD",
	"xp": "EXP", "burn": "BURN CHANCE", "freeze": "CHILL CHANCE", "shock": "SHOCK CHANCE",
	"poison": "POISON CHANCE", "bleed": "BLEED CHANCE", "slow": "SLOW CHANCE",
	"wet": "WET CHANCE", "charm": "CHARM CHANCE", "mark": "MARK CHANCE",
	"burnpow": "BURN DMG", "poisonpow": "POISON DMG", "bleedpow": "BLEED DMG",
	"shockpow": "SHOCK DMG", "freezepow": "CHILL BUILDUP", "dur": "STATUS DURATION",
	"dodge": "DODGE", "maxhp": "MAX HP", "armor": "ARMOR", "regen": "REGEN",
	"mult": "PROJECTILES", "par": "PARALLEL", "rear": "BACK SHOTS", "side": "SIDE SHOTS",
	"pierce": "PIERCE", "rico": "RICOCHET", "bounce": "WALL BOUNCE",
	"orbit": "BLADES", "drone": "DRONES", "luck": "LUCK", "fardmg": "FAR DMG",
	"closedmg": "CLOSE DMG", "fragdmg": "FRAG DMG", "orbitdmg": "BLADE DMG",
	"discount": "DISCOUNT", "mag": "MAGAZINE", "split": "FRAGMENTS", "dashcd": "DASH CD",
	"heartdrop": "HEARTS", "chilldmg": "CHILLED DMG", "spreadp": "SPREAD",
	"tdmg": "TOTAL DMG", "pellets": "PELLETS", "blast": "BLAST",
	"dronerate": "DRONE RATE", "orbitr": "ORBIT RADIUS", "orbspeed": "ORBIT SPEED",
	"dashdist": "DASH DISTANCE", "perfect": "PERFECT WINDOW", "dmgtaken": "DAMAGE TAKEN",
	"life": "PROJECTILE LIFE", "pin": "PIN CHANCE", "homing": "HOMING STRENGTH",
	"dashes": "DASH CHARGES", "slots": "GUN SLOTS", "shield": "SHIELDS",
	"rerolls": "REROLLS", "choices": "CHOICES", "critdmg": "CRIT DMG"}
const PERCENT_STATS = ["dmg", "rate", "crit", "critdmg", "speed", "pspeed", "size", "range",
	"knock", "reload", "goldp", "xp", "burn", "freeze", "shock", "poison", "bleed", "slow",
	"wet", "charm", "mark", "burnpow", "poisonpow", "bleedpow", "shockpow", "freezepow",
	"dur", "dodge", "fardmg", "closedmg", "fragdmg", "orbitdmg", "discount", "mag",
	"heartdrop", "chilldmg", "spreadp", "tdmg", "blast", "dronerate", "orbitr",
	"orbspeed", "dashcd", "dmgtaken", "life", "pin", "perfect"]
const PASSIVE_FLAGS = ["boomer", "overkill", "accel", "fractal", "fragbounce", "fraghome",
	"fragboom", "fling", "steam", "overload", "conduct", "shatter", "wildfire", "plague",
	"hemorrhage", "brainwash", "dronerocket", "orbitguns", "orbitbleed", "dashtrail",
	"dashreload", "dashpush", "speeddmg", "goblins", "mad", "infammo", "ghost", "instafreeze"]

static func format_mod(key: String, value: float) -> String:
	if PERCENT_STATS.has(key):
		return "%+d%%" % roundi(value * 100.0)
	if is_equal_approx(value, roundf(value)):
		return "%+d" % roundi(value)
	return "%+.2f" % value

static func proc_preview(c: Dictionary) -> String:
	for proc in c.get("procs", []):
		var parts: Array[String] = []
		if proc.has("chance"):
			parts.append("%d%% CHANCE" % roundi(float(proc["chance"]) * 100.0))
		if proc.has("dmg"):
			parts.append("%d BASE DMG" % roundi(float(proc["dmg"])))
		if proc.has("r"):
			parts.append("%d RADIUS" % roundi(float(proc["r"])))
		if proc.has("every"):
			parts.append("%s PER TRIGGER" % str(proc["every"]))
		if proc.has("n"):
			parts.append("%d SHOTS/HITS" % int(proc["n"]))
		if proc.has("t") and parts.size() < 2:
			parts.append("%.1f SECONDS" % float(proc["t"]))
		if not parts.is_empty():
			return "  |  ".join(parts.slice(0, 2))
	return ""

## Show quantified improvements on first picks, upgrades, and collection cards.
## Stack increases follow STACK_FALLOFF; TOTAL damage uses its multiplicative rule.
static func stack_preview(g, id: String, owned_view: bool = false) -> String:
	var c = g.card_by_id.get(id)
	if c == null:
		return ""
	var have = int(g.owned.get(id, 0))
	var mods: Dictionary = c.get("mods", {}).duplicate()
	mods.merge(c.get("wmods", {}))
	var parts: Array[String] = []
	for key in mods:
		if not STAT_NAMES.has(key) or PASSIVE_FLAGS.has(key):
			continue
		var v = float(mods[key])
		var old_value = stack_total(v, have)
		var new_value = stack_total(v, have + 1)
		if key == "tdmg":
			old_value = pow(1.0 + v, have) - 1.0
			new_value = pow(1.0 + v, have + 1) - 1.0
		if owned_view and have > 0:
			parts.append("%s %s" % [STAT_NAMES[key], format_mod(key, old_value)])
		elif have > 0:
			parts.append("%s %s > %s" % [STAT_NAMES[key], format_mod(key, old_value), format_mod(key, new_value)])
		else:
			parts.append("%s %s" % [STAT_NAMES[key], format_mod(key, new_value)])
		if parts.size() >= 2:
			break
	if not parts.is_empty():
		return "  |  ".join(parts)
	var proc_text = proc_preview(c)
	if proc_text != "":
		return proc_text
	if have > 0 and not owned_view:
		return "STACKS %d > %d" % [have, have + 1]
	return ""


static func add_card(g, id: String) -> void:
	var c = g.card_by_id.get(id)
	if c == null or not eligible(g, c):
		return
	if not g.owned.has(id):
		g.owned_order.append(id)
	g.owned[id] = int(g.owned.get(id, 0)) + 1
	match str(c.get("on_pick", "")):
		"rerolls":
			g.rerolls += int(c["mods"].get("rerolls", 0))
		"levelall":
			for w in g.guns:
				w["lvl"] = mini(5, int(w["lvl"]) + 1)
	g.stats_dirty = true
	recalc(g)
	if c["mods"].has("shield"):
		g.hero["shield"] = int(g.hero["shield"]) + int(c["mods"]["shield"])
	if c["mods"].has("dashes"):
		g.hero["dash_charges"] = int(g.hero["dash_charges"]) + int(c["mods"]["dashes"])

# ================================================================= triggers
static func max_gen(g) -> int:
	return 2 + int(g.st("fractal"))

static func trigger(g, on: String, ctx: Dictionary) -> void:
	var list = g.procs.get(on)
	if list == null:
		return
	var gen = int(ctx.get("gen", 0))
	if gen >= max_gen(g):
		return
	for rt in list:
		var p: Dictionary = rt["p"]
		if float(rt["icd"]) > 0.0:
			continue
		if p.has("if") and not condition(g, str(p["if"]), ctx):
			continue
		if p.has("nth"):
			rt["count"] = int(rt["count"]) + 1
			if int(rt["count"]) % int(p["nth"]) != 0:
				continue
		var stacks = int(rt["stacks"])
		var chance = float(p.get("chance", 1.0)) * (1.0 + 0.5 * (stacks - 1))
		if chance < 1.0 and randf() > chance:
			continue
		if g.frame_procs >= g.proc_cap():
			return
		g.frame_procs += 1
		if p.has("icd"):
			rt["icd"] = float(p["icd"])
		if p.has("delay"):
			g.delayed.append({"t": float(p["delay"]), "fn": "proc", "p": p, "stacks": stacks, "ctx": ctx.duplicate()})
		else:
			act(g, p, stacks, ctx)

static func condition(g, cond: String, ctx: Dictionary) -> bool:
	var e = ctx.get("enemy")
	if e == null:
		return false
	match cond:
		"burning":
			return float(e["burn"]) > 0.0
		"frozen":
			return float(e["frozen"]) > 0.0 or float(e["chill"]) >= 50.0
		"shocked":
			return float(e["shock"]) > 0.0
		"poisoned":
			return float(e["poison"]) > 0.0
		"wet":
			return float(e["wet"]) > 0.0
		"elite":
			return bool(e["elite"]) or bool(e["boss"])
		"boss":
			return bool(e["boss"])
	return false

static func tick(g, dt: float) -> void:
	for key in g.proc_state:
		var rt = g.proc_state[key]
		if float(rt["icd"]) > 0.0:
			rt["icd"] = float(rt["icd"]) - dt
	var hero_ctx = {"pos": g.hero["pos"], "gen": 0}
	for on in ["timer", "still", "lowhp"]:
		var list = g.procs.get(on)
		if list == null:
			continue
		for rt in list:
			var p = rt["p"]
			if on == "still" and g.still_t < 0.2:
				rt["acc"] = 0.0
				continue
			if on == "lowhp" and float(g.hero["hp"]) > float(g.hero["maxhp"]) * 0.35:
				continue
			var every = float(p.get("every", 5.0)) / (1.0 + 0.35 * (int(rt["stacks"]) - 1))
			rt["acc"] = float(rt["acc"]) + dt
			if float(rt["acc"]) >= every:
				rt["acc"] = float(rt["acc"]) - every
				if float(p.get("chance", 1.0)) < 1.0 and randf() > float(p["chance"]):
					continue
				act(g, p, int(rt["stacks"]), hero_ctx)
	# Built-in autonomous timers that are stat driven.
	if g.st("turret") > 0:
		g.turret_t += dt
		if g.turret_t >= 12.0:
			g.turret_t = 0.0
			for i in range(int(g.st("turret"))):
				g.turrets.append({"pos": g.hero["pos"] + Vector2(randf_range(-40, 40), randf_range(-20, 30)), "t": 8.0 * (1.0 + g.st("dur")), "cd": 0.0, "aim": Vector2.UP})
			g.sfx.play("thunk")
	if g.st("beehive") > 0:
		g.hive_t += dt
		if g.hive_t >= 3.0:
			g.hive_t = 0.0
			Combat.add_bees(g, g.hero["pos"], 2 * int(g.st("beehive")), 8.0 * g.dmg_mult() * g.sector_scale() * 0.6, 1)

static func walked(g, dist: float) -> void:
	var list = g.procs.get("walk")
	if list != null:
		for rt in list:
			rt["acc"] = float(rt["acc"]) + dist
			var every = float(rt["p"].get("every", 150.0)) / (1.0 + 0.35 * (int(rt["stacks"]) - 1))
			if float(rt["acc"]) >= every:
				rt["acc"] = 0.0
				act(g, rt["p"], int(rt["stacks"]), {"pos": g.hero["pos"], "gen": 0})
	if g.st("mine") > 0:
		g.mine_acc += dist
		if g.mine_acc >= 150.0 / g.st("mine"):
			g.mine_acc = 0.0
			Combat.drop_mine(g, g.hero["pos"])

# ================================================================= actions
static func act(g, p: Dictionary, stacks: int, ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", g.hero["pos"])
	if str(p.get("at", "")) == "hero":
		pos = g.hero["pos"]
	var stack_mul = 1.0 + 0.5 * (stacks - 1)
	var dmg = float(p.get("dmg", 0.0)) * stack_mul * g.dmg_mult() * g.sector_scale() * 0.75
	if p.has("rel"):
		dmg = float(ctx.get("dmg", 10.0)) * float(p["rel"]) * stack_mul
	var gen = int(ctx.get("gen", 0)) + 1
	var n = int(p.get("n", 1))
	var r = float(p.get("r", 60.0))
	var enemy = ctx.get("enemy")
	var dir: Vector2 = ctx.get("dir", g.hero["aim"])
	match str(p["do"]):
		"explode":
			var at = pos
			if p.has("offset"):
				at += Vector2.from_angle(randf() * TAU) * float(p["offset"])
			var col = Color(str(p.get("color", "ffa24d")))
			Combat.explode(g, at, r, dmg, gen, col)
		"frags":
			var col2 = Color(str(p.get("color", "fff1a8")))
			Combat.fragments(g, pos, n, dmg, str(p.get("pattern", "ring")), dir, gen, ctx.get("shot"), int(p.get("colorful", 0)) > 0, col2)
		"nova":
			Combat.nova(g, g.hero["pos"], n, dmg, gen)
		"zap":
			Combat.zap(g, pos, n + stacks - 1, dmg, gen, enemy)
		"status":
			if enemy != null and not bool(enemy["dead"]):
				Combat.apply_status(g, enemy, str(p["s"]), float(p.get("amt", 1.0)))
		"status_area":
			var s = str(p["s"])
			for e in g.enemies_near(pos, r):
				if e["pos"].distance_to(pos) < r + float(e["r"]):
					if s == "stun":
						e["stun"] = maxf(float(e["stun"]), float(p.get("t", 1.0)) * (1.0 + g.st("dur")))
						if int(p.get("disco", 0)) > 0:
							e["dance"] = float(p.get("t", 1.5))
					else:
						Combat.apply_status(g, e, s, float(p.get("amt", 1.0)))
			g.spawn_ring_fx(pos, Combat.status_color(s), r)
			if int(p.get("disco", 0)) > 0:
				g.fx.append({"kind": "disco", "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "life": 1.5, "color": Color.WHITE, "size": r})
		"heal":
			g.heal(float(p.get("hp", 5)) * stack_mul)
		"shield":
			g.add_shield(n)
		"orbital":
			for i in range(n):
				g.temp_orbitals.append({"t": float(p.get("t", 3.0)) * (1.0 + g.st("dur"))})
		"meteor":
			var target = Combat.random_enemy(g, g.hero["pos"], 520.0)
			if target != null:
				Combat.meteor(g, target["pos"], dmg, r, gen)
		"airstrike":
			Combat.airstrike(g, n, dmg, gen)
		"anvil":
			Combat.anvil(g, dmg, r, int(p.get("piano", 0)) > 0, gen)
		"bees":
			Combat.add_bees(g, pos, n * stacks, 8.0 * g.dmg_mult() * g.sector_scale() * 0.6, gen)
		"blackhole":
			Combat.blackhole(g, pos if p.get("at", "") == "hero" or ctx.has("enemy") else Combat.crowd_center(g), r, float(p.get("t", 2.0)), int(p.get("weak", 0)) > 0)
		"shockwave":
			Combat.shockwave(g, pos, r, dmg, float(p.get("push", 250.0)), gen)
		"slowmo":
			g.slowmo_t = maxf(g.slowmo_t, float(p.get("t", 0.5)))
		"drop":
			var count = n
			if p.has("nmax"):
				count = randi_range(n, int(p["nmax"]))
			var kind = str(p.get("kind", "gold"))
			if kind == "chest":
				g.spawn_pickup("chest", pos, 1)
			elif kind == "gold" and count > 4:
				for i in range(mini(count, 12)):
					g.spawn_pickup("gold", pos, int(ceil(float(count) / mini(count, 12))))
			else:
				for i in range(count):
					g.spawn_pickup(kind, pos, 1)
		"volley":
			var aim = dir
			if str(p.get("aim", "")) == "nearest":
				var t = g.nearest_enemy(g.hero["pos"], 700.0)
				if t != null:
					aim = (t["pos"] - g.hero["pos"]).normalized()
			var repeats = int(p.get("x", 1))
			for k in range(repeats):
				g.delayed.append({"t": 0.08 * k, "fn": "free_volley", "dir": aim, "gen": gen})
		"saw":
			Combat.saw(g, pos, dmg, gen)
		"puddle":
			var z = g.add_zone(str(p["s"]), pos, r, float(p.get("t", 3.0)))
			z["gen"] = gen
		"strike":
			for i in range(n):
				var t2 = Combat.random_enemy(g, pos, 300.0)
				if t2 != null:
					Combat.strike(g, t2, dmg, gen)
		"chicken":
			for i in range(n):
				Combat.chicken(g, pos, Vector2.from_angle(randf() * TAU), 24.0 * g.dmg_mult() * g.sector_scale(), gen)
		"rocket":
			for i in range(n):
				var t3 = Combat.random_enemy(g, g.hero["pos"], 600.0)
				var d3 = Vector2.from_angle(randf() * TAU) if t3 == null else (t3["pos"] - g.hero["pos"]).normalized().rotated(randf_range(-0.6, 0.6))
				Combat.rocket(g, g.hero["pos"], d3, dmg, gen)
		"boomerang":
			Combat.boomerang(g, g.hero["pos"], g.hero["aim"], dmg, gen)
		"laser":
			var t4 = g.nearest_enemy(g.hero["pos"], 520.0)
			if t4 != null:
				Combat.laser(g, g.hero["pos"] + Vector2(0, -10), t4, dmg, gen)
		"dashreset":
			g.hero["dash_charges"] = maxi(int(g.hero["dash_charges"]), 1 + int(g.st("dashes")))
		"magnet":
			for pk in g.pickups:
				if pk["pos"].distance_to(g.hero["pos"]) < 900.0:
					pk["vacuum"] = true
		"confetti":
			Combat.confetti(g, pos, r, dmg, gen)
		"coin":
			Combat.coin(g, g.hero["pos"], g.hero["aim"], dmg, gen)
		"buff":
			g.add_buff(str(p["stat"]), float(p["amt"]) * stack_mul, float(p.get("t", 3.0)))
		"decoy":
			g.pets.append({"kind": "decoy", "pos": g.hero["pos"], "left": float(p.get("t", 1.5)) * (1.0 + g.st("dur")), "dmg": dmg, "gen": gen})
		"spikes":
			Combat.spikes(g, g.hero["pos"], n, dmg, gen)
		"car":
			Combat.clown_car(g, dmg, gen)
		"potato":
			Combat.potato(g, dmg, gen)
		"barrel":
			g.spawn_barrel(Vector2(randf_range(-ROAD(), ROAD()), g.cam_y - randf_range(80, 260)), true)
		"bubbles":
			Combat.bubbles(g, pos, n, dmg, gen)
		"coinflip":
			if randf() < 0.5:
				g.add_buff("dmg", 0.4, 9999.0)
				g.banner("HEADS!", "+40% damage this sector", 1.8)
			else:
				g.add_buff("dmg", -0.15, 9999.0)
				g.banner("TAILS...", "-15% damage this sector", 1.8)
		"random":
			var options = [
				{"do": "explode", "r": 90, "dmg": 30, "color": "ff6bd6"},
				{"do": "frags", "n": 12, "dmg": 10, "pattern": "ring"},
				{"do": "zap", "n": 5, "dmg": 16},
				{"do": "bees", "n": 4},
				{"do": "chicken", "n": 2},
				{"do": "anvil", "dmg": 80, "r": 55},
				{"do": "meteor", "dmg": 60, "r": 85},
				{"do": "confetti", "dmg": 20, "r": 110},
				{"do": "blackhole", "r": 150, "t": 1.2},
				{"do": "nova", "n": 16, "dmg": 12},
				{"do": "car", "dmg": 50},
				{"do": "slowmo", "t": 0.8},
			]
			var pick = options[randi() % options.size()].duplicate()
			pick["on"] = "random"
			act(g, pick, stacks, ctx)
	if p.has("say") and randf() < 0.85:
		g.say(pos + Vector2(0, -30), str(p["say"]), Color("fff1a8"), 26)

static func ROAD() -> float:
	return 420.0

# ================================================================= offers
static func eligible(g, c: Dictionary) -> bool:
	var id = str(c["id"])
	if card_count(g) >= 32:
		return false
	if not g.card_available(id):
		return false
	var stack_limits = [4, 3, 2, 1, 1, 1]
	var max_stacks = mini(int(c.get("max", 1)), stack_limits[clampi(int(c["rarity"]), 0, 5)])
	if int(g.owned.get(id, 0)) >= max_stacks:
		return false
	var req: Dictionary = c.get("req", {})
	if req.has("weapon"):
		var ok = false
		for w in g.guns:
			if req["weapon"].has(w["id"]):
				ok = true
		if not ok:
			return false
	if req.has("stat") and g.st(str(req["stat"])) <= 0.0:
		return false
	if id == "arsenal" and g.guns.size() < 2:
		return false
	return true

static func card_count(g) -> int:
	var total = 0
	for id in g.owned:
		if g.card_by_id.has(id):
			total += int(g.owned[id])
	return total

## Fixed odds per roll, like a gacha summon table (percent). Common / Rare / Epic / Legendary / Mythic / Ascendant.
const ODDS = [72.0, 24.5, 3.0, 0.45, 0.045, 0.005]
## Each point of luck moves a small, fixed slice of the Common odds up the table.
const LUCK_ODDS = [0.0, 0.6, 0.12, 0.02, 0.002, 0.0002]
const LUCK_CAP = 12.0
## Chests and the shop's premium stall roll as if you had this much extra luck.
const CHEST_LUCK = 6.0
const SHOP_MAXHP = 12.0

static func rarity_odds(g, extra_luck: float = 0.0) -> Array:
	var luck = clampf(g.st("luck") + extra_luck, 0.0, LUCK_CAP + extra_luck)
	var w = []
	var moved = 0.0
	for i in range(ODDS.size()):
		var add = LUCK_ODDS[i] * luck
		moved += add
		w.append(ODDS[i] + add)
	w[0] = maxf(0.0, w[0] - moved)
	return w

## min_rarity upgrades low rolls instead of re-weighting, so a chest is "at least Rare"
## without making Epic+ any more common than the table says.
static func roll_rarity(g, min_rarity: int, extra_luck: float = 0.0) -> int:
	var w = rarity_odds(g, extra_luck)
	var total = 0.0
	for weight in w:
		total += weight
	var r = randf() * total
	for i in range(w.size()):
		r -= w[i]
		if r <= 0.0:
			return maxi(i, min_rarity)
	return maxi(0, min_rarity)

static func random_card(g, min_rarity: int, max_rarity: int = 5, extra_luck: float = 0.0) -> Variant:
	return card_of_rarity(g, clampi(roll_rarity(g, min_rarity, extra_luck), min_rarity, max_rarity), min_rarity, max_rarity)

## Shop gamble: never Common, and the one place an Epic (or better) shows up often.
const MYSTERY_ODDS = [0.0, 68.0, 26.0, 5.0, 0.9, 0.1]

static func mystery_card(g) -> Variant:
	var r = randf() * 100.0
	var rolled = 1
	for i in range(MYSTERY_ODDS.size()):
		r -= MYSTERY_ODDS[i]
		if r <= 0.0:
			rolled = i
			break
	return card_of_rarity(g, maxi(1, rolled), 1, 5)

static func card_of_rarity(g, rolled: int, min_rarity: int, max_rarity: int) -> Variant:
	# If nothing is left at the rolled rarity, fall back DOWN first so empty pools never upgrade a roll.
	var order = []
	for r in range(rolled, min_rarity - 1, -1):
		order.append(r)
	for r in range(rolled + 1, max_rarity + 1):
		order.append(r)
	for rarity in order:
		var pool = []
		for c in g.db_cards:
			if int(c["rarity"]) == rarity and eligible(g, c):
				pool.append(c)
		if not pool.is_empty():
			return pool[randi() % pool.size()]
	return null

static func roll_offer(g, mode: String) -> Variant:
	if mode == "level":
		for i in range(g.guns.size()):
			var w = g.guns[i]
			if int(w["lvl"]) >= 5 and not bool(w["evolved"]) and randf() < 0.45:
				return {"type": "evolve", "slot": i}
		var r = randf()
		var slots = 2 + int(g.st("slots"))
		if g.guns.size() < slots and r < (0.34 if g.guns.size() == 1 else 0.16):
			var choices = []
			for id in g.unlocked_guns:
				var have = false
				for w in g.guns:
					if w["id"] == id:
						have = true
				if not have:
					choices.append(id)
			if not choices.is_empty():
				return {"type": "gun_new", "gun": choices[randi() % choices.size()], "tier": roll_rarity(g, 0)}
		if r < 0.42:
			var up = []
			for i in range(g.guns.size()):
				if int(g.guns[i]["lvl"]) < 5:
					up.append(i)
			if not up.is_empty():
				return {"type": "gun_up", "slot": up[randi() % up.size()]}
	var c = random_card(g, 1, 5, CHEST_LUCK) if mode == "chest" else random_card(g, 0)
	if c == null:
		return null
	return {"type": "card", "id": c["id"]}

static func make_offers(g, mode: String) -> Array:
	var n = 3 + int(g.st("choices"))
	var out = []
	var tries = 0
	while out.size() < n and tries < 80:
		tries += 1
		var o = roll_offer(g, mode)
		if o == null:
			continue
		var dup = false
		for x in out:
			if x["type"] == o["type"] and x.get("id") == o.get("id") and x.get("gun") == o.get("gun") and x.get("slot") == o.get("slot"):
				dup = true
		if not dup:
			out.append(o)
	return out

static func offer_rarity(g, o: Dictionary) -> int:
	match o["type"]:
		"card":
			return int(g.card_by_id[o["id"]]["rarity"])
		"gun_new":
			return int(o.get("tier", 0))
		"gun_up":
			return int(g.guns[int(o["slot"])].get("tier", 0))
		"evolve":
			return maxi(3, int(g.guns[int(o["slot"])].get("tier", 0)))
	return 0

## Card prices by rarity: Common, Rare, Epic, Legendary, Mythic, Ascendant (+ per sector).
const CARD_PRICE = [34, 55, 120, 210, 320, 480]
const CARD_PRICE_SECTOR = [3, 4, 7, 9, 11, 13]

static func card_price(g, rarity: int) -> int:
	var r = clampi(rarity, 0, 5)
	return CARD_PRICE[r] + CARD_PRICE_SECTOR[r] * g.sector

static func make_shop(g) -> Array:
	var s = g.sector
	# Coupons cap at 30% off so the shop never becomes a free card dispenser.
	var discount = clampf(1.0 - g.st("discount"), 0.7, 1.0)
	var items = []
	# Two card stalls on the normal odds; the second one is at least Rare (rolls like a chest).
	var c1 = random_card(g, 0, 5, g.shop_luck())
	if c1 != null:
		items.append({"kind": "offer", "offer": {"type": "card", "id": c1["id"]}, "price": card_price(g, int(c1["rarity"]))})
	var slots = 2 + int(g.st("slots"))
	if g.guns.size() < slots or randf() < 0.4:
		var choices = []
		for id in g.unlocked_guns:
			var have = false
			for w in g.guns:
				if w["id"] == id:
					have = true
			if not have:
				choices.append(id)
		if not choices.is_empty():
			var gun_offer = {"type": "gun_new", "gun": choices[randi() % choices.size()], "tier": roll_rarity(g, 0)}
			items.append({"kind": "offer", "offer": gun_offer, "price": 55 + s * 7 + int(gun_offer["tier"]) * 35})
	else:
		var up = []
		for i in range(g.guns.size()):
			if int(g.guns[i]["lvl"]) < 5:
				up.append(i)
		if not up.is_empty():
			items.append({"kind": "offer", "offer": {"type": "gun_up", "slot": up[randi() % up.size()]}, "price": 45 + s * 6})
	if randf() < 0.6:
		items.append({"kind": "heal", "price": 24 + s * 4})
	else:
		items.append({"kind": "maxhp", "price": 40 + s * 5})
	var c2 = random_card(g, 1, 5, CHEST_LUCK + g.shop_luck())
	if c2 != null and (c1 == null or c2["id"] != c1["id"]):
		items.append({"kind": "offer", "offer": {"type": "card", "id": c2["id"]}, "price": roundi(card_price(g, int(c2["rarity"])) * 1.1)})
	for it in items:
		it["price"] = maxi(5, roundi(float(it["price"]) * discount))
	return items
