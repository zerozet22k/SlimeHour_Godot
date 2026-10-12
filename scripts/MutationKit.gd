extends RefCounted
## Mutations fuse their parents' signature powers into ONE combined move
## (see "fusion moves" below and data/fusion.json). The body decides WHAT
## the move does, the other parent HOW it is delivered:
##   Laser Larry body + Medic  -> lasers spun out all round it
##   Medic body + Laser Larry  -> healing lasers shot into its friends
##   Laser Larry body + Mirror -> points hang round you, each fires a laser
## Between moves a mutant fights like its body parent.

## What each species lends to a fusion comes from data/enemies.json:
## "gives" (its own signature power, e.g. Lancer: spear) and "pulse" (bodies
## that do not attack directly and unleash it as a warned pulse instead).
## A new monster only needs those fields to combine with every other one.
static var _species: Dictionary = {}

static func species_data() -> Dictionary:
	if _species.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
		if parsed is Array:
			for rec in parsed:
				_species[str(rec["id"])] = rec
	return _species

static func gives_of(species: String) -> Array:
	return species_data().get(species, {}).get("gives", [])

static func pulses(species: String) -> bool:
	return bool(species_data().get(species, {}).get("pulse", false))
const PAYLOAD_NAMES = {
	"glue": "Gluey", "rush": "Frenzied", "slam": "Quaking", "poison": "Toxic",
	"explode": "Volatile", "split": "Budding", "guard": "Guarded", "shove": "Ramming",
	"hatch": "Brooding", "shell": "Shelling", "blink": "Blinking", "latch": "Clinging",
	"steal": "Thieving", "fire": "Burning", "shards": "Shattering", "quake": "Tremor",
	"rally": "Rallying", "shock": "Shocking", "sticky": "Sticky", "spear": "Piercing", "shield": "Shielded",
	"drain": "Draining", "heal": "Healing", "laser": "Lasing",
}

## Parents in the same order EnemyMixes.ensure assigns them (body first).
static func parents_for_id(id: String) -> Array:
	var pair: Array = Array(id.trim_prefix("mix_").split("_"))
	return pair if pair.size() == 2 else []

## Payloads that help monsters instead of hurting you.
const SUPPORT = ["heal", "guard", "rally"]

static func is_mutant(g, e: Dictionary) -> bool:
	return e.has("mut_of") or str(e.get("kind", "")).begins_with("mix_")

static func parents(g, kind: String) -> Array:
	if not kind.begins_with("mix_") or not g.enemy_db.has(kind):
		return []
	return g.enemy_db[kind].get("mix", [])

## The parent whose moves a mutant uses: its body parent.
static func acting(g, e: Dictionary) -> String:
	var kind := str(e["kind"])
	if not kind.begins_with("mix_"):
		return kind
	return primary(g, kind)

static func primary(g, kind: String) -> String:
	# Fast path: ordinary monsters are their own body.
	if not kind.begins_with("mix_"):
		return kind
	var p := parents(g, kind)
	return str(p[0]) if not p.is_empty() else kind

## The augment a giver passes on in this particular mutation.
static func payload_index(kind: String, giver: String) -> int:
	var options: Array = gives_of(giver)
	return 0 if options.is_empty() else posmod(kind.hash() >> 3, options.size())

static func payload_for(kind: String, giver: String) -> String:
	var options: Array = gives_of(giver)
	if options.is_empty():
		return ""
	return str(options[posmod(kind.hash() >> 3, options.size())])

static func payload_of(g, e: Dictionary) -> String:
	var kind: String = str(e.get("mut_of", e.get("kind", "")))
	var p := parents(g, kind)
	if p.size() < 2:
		return ""
	return payload_for(kind, str(p[1]))

static func display_name(g, kind: String) -> String:
	var p := parents(g, kind)
	if p.size() < 2:
		return ""
	return str(PAYLOAD_NAMES.get(payload_for(kind, str(p[1])), "Mutant")) + " " + str(g.enemy_db[str(p[0])]["name"])

## ---------------------------------------------------------------- fusion moves
## Nothing here knows any particular pair: a new monster only needs "gives"
## in enemies.json, and a brand-new power an entry in fusion.json plus its
## effect in apply_effect below.
const MOVE_CD := 4.2
static var _sigs: Dictionary = {}

static func sig_data() -> Dictionary:
	if _sigs.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/fusion.json"))
		if parsed is Dictionary:
			_sigs = parsed
	return _sigs

static func sig(name: String) -> Dictionary:
	var d = sig_data().get(name, {})
	return d if d is Dictionary else {}

static func mut_kind(e: Dictionary) -> String:
	return str(e.get("mut_of", e.get("kind", "")))

## The powers a mutation fuses, body first.
static func signatures(g, kind: String) -> Array:
	var out: Array = []
	for p in parents(g, kind):
		var s := payload_for(kind, str(p))
		if s != "":
			out.append(s)
	return out

## The BODY decides WHAT the move does (its own power, aimed at you, or at its
## friends for a support power); the other parent decides HOW it is delivered
## (the shape it lends). Swap the parents and you get a different move:
##   Laser Larry body + Medic  -> lasers spun out all round it (Medic's ring)
##   Medic body + Laser Larry  -> healing lasers shot into its friends
static func plan_for(sigs: Array) -> Dictionary:
	var effect: String = str(sigs[0]) if sigs.size() > 0 else ""
	var lender: String = str(sigs[1]) if sigs.size() > 1 else effect
	var shape = sig(lender).get("shape", {})
	var skin = sig(effect).get("skin", {})
	return {"effect": effect, "lender": lender, "shape": shape if shape is Dictionary and not shape.is_empty() else {"pattern": "target"},
		"skin": skin if skin is Dictionary else {}, "support": bool(sig(effect).get("support", false))}

static func move_name_for(sigs: Array) -> String:
	var p := plan_for(sigs)
	return (str(sig(p["lender"]).get("noun", "")) + " " + str(sig(p["effect"]).get("noun", ""))).strip_edges().to_upper()

static func move_desc_for(sigs: Array) -> String:
	var p := plan_for(sigs)
	var how := str(sig(p["lender"]).get("shape_desc", "attacks"))
	if bool(p["support"]):
		how = how.replace("onto you", "onto its friends").replace("at you", "at its friends").replace("around you", "around its friends").replace("through you", "through its friends").replace("toward you", "toward its friends").replace("beside you", "beside its friends").replace("on top of you", "on top of its friends").replace("across you", "across its friends").replace("to you", "to its friends")
	return "It " + how + ", and every strike " + str(sig(p["effect"]).get("does", p["effect"])) + "."

static func move_name(g, kind: String) -> String:
	return move_name_for(signatures(g, kind))

## Every mutant charges its signature move on a timer; the body's own attack
## sets it off early once it is nearly ready, so the two read as one.
static func tick(g, e: Dictionary, dt: float) -> void:
	if not str(e["kind"]).begins_with("mix_"):
		return
	e["mut_move_t"] = float(e.get("mut_move_t", 2.2)) - dt
	if float(e["mut_move_t"]) <= 0.0 and Vector2(e["pos"]).distance_to(g.hero["pos"]) < 640.0:
		fusion_move(g, e)

static func on_attack(g, e, pos: Vector2, hit_player: bool) -> void:
	if e == null or bool(e.get("dead", false)) or not is_mutant(g, e):
		return
	if float(e.get("mut_move_t", 2.2)) <= 1.2:
		fusion_move(g, e)

## The body attacked without a projectile (a dash, a slam, a sweep...).
static func strike(g, e: Dictionary) -> void:
	on_attack(g, e, e["pos"], false)

static func resolve_strike(g, item: Dictionary) -> void:
	on_attack(g, item.get("src_enemy"), item["pos"], false)

## One fusion, one colour: every line, point and blast of the move uses the
## colour the mutant is drawn in, so you read it as ONE monster's attack.
static func move_color(g, kind: String) -> String:
	var p := parents(g, kind)
	var MK = load("res://scripts/MonsterKit.gd")
	if p.size() >= 2 and MK.SPECS.has(str(p[0])):
		return str(MK.SPECS[str(p[0])]["body"])
	return str(g.enemy_db.get(kind, {}).get("color", "ffffff"))

static func _c(e: Dictionary, fallback: String) -> String:
	return str(e.get("mut_col", fallback))

static func fusion_move(g, e: Dictionary) -> void:
	var sigs := signatures(g, mut_kind(e))
	e["mut_col"] = move_color(g, mut_kind(e))
	e["mut_move_t"] = MOVE_CD * (0.8 if g.hard_mode else 1.0)
	if sigs.is_empty() or g.delayed.size() >= 110:
		return
	e["mut_budget"] = 2
	var before: int = g.delayed.size()
	launch(g, e, sigs)
	for k in range(before, g.delayed.size()):
		g.delayed[k]["mut_payload"] = true
		g.delayed[k]["mut_col"] = str(e["mut_col"])
	g.say(Vector2(e["pos"]) + Vector2(0, -float(e["r"]) - 28.0), move_name_for(sigs) + "!", Color(str(e["mut_col"])), 16)

## Friends a support move is aimed at (nearest first), or itself if alone.
static func friends(g, e: Dictionary, n: int) -> Array:
	var near: Array = []
	for ally in g.enemies_near(e["pos"], 420.0):
		if ally != e and not bool(ally["dead"]) and not bool(ally.get("boss", false)):
			near.append(ally)
	near.sort_custom(func(a, b): return Vector2(a["pos"]).distance_squared_to(e["pos"]) < Vector2(b["pos"]).distance_squared_to(e["pos"]))
	var out: Array = []
	for ally in near.slice(0, maxi(1, n)):
		out.append(Vector2(ally["pos"]))
	if out.is_empty():
		out.append(Vector2(e["pos"]))
	return out

static func launch(g, e: Dictionary, sigs: Array) -> void:
	var C = load("res://scripts/Combat.gd")
	var p := plan_for(sigs)
	var shape: Dictionary = p["shape"]
	var skin: Dictionary = p["skin"]
	var support: bool = p["support"]
	var pattern := str(shape.get("pattern", "target"))
	var n := int(shape.get("count", 1))
	var col: String = _c(e, "ffffff")
	var dmg: float = float(e["dmg"])
	var from: Vector2 = e["pos"]
	var targets: Array = friends(g, e, n) if support else [Vector2(g.hero["pos"])]
	var target: Vector2 = targets[0]
	var aim: Vector2 = (target - from).normalized()
	if aim.length_squared() < 0.01:
		aim = Vector2.DOWN
	var lines: Array = []   # [a, b, delay]
	var points: Array = []  # [pos, delay, travels-from or null]
	match pattern:
		"beam":
			var length := float(shape.get("length", 700.0))
			if support:
				for t in targets:
					lines.append([from, t, 0.5])
					points.append([t, 0.5, null])
			else:
				for i in range(n):
					var b: Vector2 = from + aim.rotated((float(i) - float(n - 1) * 0.5) * 0.3) * length
					lines.append([from, b, 0.65])
					for j in range(1, 4):
						points.append([from.lerp(b, float(j) / 4.0), 0.65 + 0.08 * j, null])
		"sweep", "aura":
			# Spokes spun round the mutant one after another: a rage spin.
			var reach := float(shape.get("reach", 175.0))
			var step := float(shape.get("step", 0.0))
			var a0: float = aim.angle() + (randf() * TAU if pattern == "aura" else 0.0)
			var spin := 1.0 if randf() < 0.5 else -1.0
			for i in range(n):
				var d := Vector2.from_angle(a0 + spin * TAU * float(i) / float(n))
				var t := 0.55 + step * float(i)
				lines.append([from + d * float(e["r"]), from + d * reach, t])
				if i % 2 == 0:
					points.append([from + d * reach, t, from])
		"cage":
			var radius := float(shape.get("radius", 190.0))
			var base := randf() * TAU
			for i in range(n):
				points.append([target + Vector2.from_angle(base + TAU * float(i) / float(n)) * radius, 0.75 + 0.04 * i, from])
		"wall":
			var span := float(shape.get("span", 230.0))
			var center: Vector2 = target - aim * 40.0
			var side := aim.orthogonal()
			lines.append([center - side * span * 0.5, center + side * span * 0.5, 0.7])
			for i in range(n):
				points.append([center + side * span * (float(i) / float(maxi(1, n - 1)) - 0.5), 0.75, null])
		"lob":
			var tt := float(shape.get("time", 0.9))
			var sc := float(shape.get("scatter", 120.0))
			for i in range(n):
				var land: Vector2 = target if i == 0 else target + Vector2.from_angle(TAU * float(i) / float(maxi(1, n - 1)) + randf()) * sc * randf_range(0.6, 1.0)
				points.append([land, tt + 0.12 * i, from])
		"burst":
			var radius := float(shape.get("radius", 100.0))
			points.append([target, 0.8, from])
			for i in range(n - 1):
				points.append([target + Vector2.from_angle(TAU * float(i) / float(n - 1) + randf() * 0.4) * radius, 0.95, from])
		"chain":
			var prev := from
			for i in range(n):
				var hop: Vector2 = from.lerp(target, float(i + 1) / float(n))
				var t := 0.4 + float(shape.get("step", 0.2)) * i
				lines.append([prev, hop, t])
				points.append([hop, t, null])
				prev = hop
		"blink":
			var away: Vector2 = (from - target).normalized() if from.distance_squared_to(target) > 1.0 else Vector2.UP
			var land: Vector2 = target + away.rotated(randf_range(-1.2, 1.2)) * 95.0
			e["pos"] = land
			g.spawn_ring_fx(from, Color(col), 34.0)
			g.spawn_ring_fx(land, Color(col), 34.0)
			lines.append([from, land, 0.5])
			points.append([from, 0.45, null])
			points.append([land, 0.6, null])
		"fissure":
			var length := float(shape.get("length", 430.0))
			lines.append([from, from + aim * length, 0.75])
			for i in range(n):
				points.append([from + aim * length * float(i + 1) / float(n), 0.8 + 0.12 * i, null])
		"dash":
			var end: Vector2 = from + (target - from) * 1.25
			e["sprint_t"] = maxf(float(e.get("sprint_t", 0.0)), 1.0)
			lines.append([from, end, 0.55])
			for i in range(n):
				points.append([from.lerp(end, float(i + 1) / float(n)), 0.35 + 0.15 * i, null])
		"carpet":
			# A bombing run sweeping across you.
			var span := float(shape.get("span", 340.0))
			var side := aim.orthogonal()
			var a: Vector2 = target - side * span * 0.5
			var b: Vector2 = target + side * span * 0.5
			lines.append([a, b, 0.6])
			for i in range(n):
				points.append([a.lerp(b, float(i) / float(maxi(1, n - 1))), 0.55 + 0.12 * i, from])
		"cling":
			for i in range(n):
				points.append([target, 0.5 + 0.45 * i, null])
		_:
			points.append([target, 0.75, from])
	# A line power (laser, spear, quake...) IS the shape's lines; anything else
	# goes off at the shape's points. Support moves link to friends as beams.
	if not support and not skin.is_empty() and not lines.is_empty():
		var extend := float(skin.get("extend", 0.0))
		for l in lines:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			if extend > 0.0 and a.distance_to(b) < extend:
				b = a + (b - a).normalized() * extend
			C.schedule_boss_line(g, a, b, float(skin.get("width", 12.0)), dmg * 0.55, l[2], col, str(p["effect"]))
		# A line power no longer deletes the second parent's actual signature.
		# Give its donor ONE telegraphed follow-through, not a barrage per spoke.
		if not lines.is_empty():
			var tt: float = float(lines[0][2]) + 0.12
			g.delayed.append({"fn": "mut_anchor", "pos": target, "t": tt, "life": tt,
				"src_enemy": e, "effect": "", "lender": str(p["lender"]),
				"k": 0.42, "color": col, "support": false})
		return
	var k := clampf(1.3 / sqrt(float(maxi(1, points.size()))), 0.45, 1.0)
	for index in range(points.size()):
		var pt = points[index]
		var item := {"fn": "mut_anchor", "pos": pt[0], "t": pt[1], "life": pt[1], "src_enemy": e,
			"effect": p["effect"], "k": k, "color": col}
		# The first impact carries the donor's real power; remaining impacts
		# only carry the body effect, preventing 12× duplicate bombs/lasers.
		if index == 0:
			item["lender"] = str(p["lender"])
		if pt[2] != null:
			item["from"] = pt[2]
		if support:
			item["support"] = true
			if str(p["lender"]) == "laser":
				item["link"] = from
		g.delayed.append(item)

static func resolve_anchor(g, item: Dictionary) -> void:
	# A move already in flight finishes even if the mutant just died.
	var src = item.get("src_enemy")
	if src == null:
		return
	var pos: Vector2 = item["pos"]
	var col := Color(str(item.get("color", "ffffff")))
	if item.has("link"):
		g.beams.append({"a": item["link"], "b": pos, "t": 0.3, "w": 7.0, "color": col, "zig": false})
	elif bool(item.get("support", false)):
		g.spawn_ring_fx(pos, col, 24.0)
	g.spawn_ring_fx(pos, col, 26.0)
	var before: int = g.delayed.size()
	if str(item.get("effect", "")) != "":
		apply_effect(g, src, pos, str(item["effect"]), false, float(item.get("k", 1.0)))
	if str(item.get("lender", "")) != "":
		inherited_strike(g, src, pos, str(item["lender"]), bool(item.get("support", false)), col)
	for k in range(before, g.delayed.size()):
		g.delayed[k]["mut_payload"] = true
		if src.has("mut_col"):
			g.delayed[k]["mut_col"] = str(src["mut_col"])

## Second-parent abilities are delivered at ONE impact of the body move.
## This makes fusion mechanical: glue traps follow prism shards, acid follows
## fire, a lancer's fissure sprouts actual spears, and brood powers really hatch.
## Keep the donor intentionally lighter than the body power.
static func inherited_strike(g, e: Dictionary, pos: Vector2, lender: String, support: bool, col: Color) -> void:
	var C = load("res://scripts/Combat.gd")
	var EI = load("res://scripts/EnemyIdentity.gd")
	var hero: Vector2 = g.hero["pos"]
	var toward: Vector2 = (hero - pos).normalized() if hero.distance_squared_to(pos) > 1.0 else Vector2.DOWN
	var dmg: float = float(e["dmg"])
	# A support-body mutation must not turn its friend's buff into player damage.
	if support:
		for ally in g.enemies_near(pos, 160.0):
			if bool(ally.get("dead", false)) or bool(ally.get("boss", false)):
				continue
			match lender:
				"rush", "shove", "blink", "spear":
					ally["sprint_t"] = maxf(float(ally.get("sprint_t", 0.0)), 1.6)
				"shield", "shell", "guard", "slam":
					ally["siphon_empowered_t"] = maxf(float(ally.get("siphon_empowered_t", 0.0)), 1.8)
				_:
					ally["hp"] = minf(float(ally["max_hp"]), float(ally["hp"]) + float(ally["max_hp"]) * 0.05)
		g.spawn_ring_fx(pos, col, 58.0)
		return
	match lender:
		"glue", "latch":
			# Actual slowing hazard rather than an unrelated explosion.
			if hero.distance_to(pos) < 75.0:
				g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 1.0)
			g.spawn_ring_fx(pos, col, 72.0)
		"poison":
			EI.place(g, "acid", pos, 65.0, dmg * 0.18, 2.6, 0.24, col.to_html(false))
		"fire":
			EI.place(g, "fire", pos, 66.0, dmg * 0.18, 1.8, 0.34, col.to_html(false))
		"shards":
			# Mirror contribution: a compact pinwheel of real projectiles.
			for i in range(4):
				var sd := toward.rotated((float(i) - 1.5) * 0.43)
				C.shot(g, pos, sd, dmg * 0.22, {"friendly": false, "speed": 430.0,
					"life": 1.0, "r": 4.0, "kind": "enemy", "color": col, "src": "mutant mirror shards"})
		"spear":
			var sp = C.shot(g, pos, toward, dmg * 0.45, {"friendly": false,
				"speed": 740.0, "life": 1.15, "r": 7.0, "kind": "enemy", "color": col, "src": "a mutant lance"})
			if sp != null:
				sp["pierce"] = 3
				sp["spear"] = true
		"quake":
			C.schedule_boss_line(g, pos, pos + toward * 185.0, 11.0, dmg * 0.35, 0.35, col.to_html(false), "quake")
		"shock":
			var side := toward.orthogonal()
			C.schedule_boss_line(g, pos, pos + toward * 190.0 + side * 45.0, 7.0, dmg * 0.3, 0.35, col.to_html(false), "shock")
		"rush":
			# Skitter / Zoomer blood: a short dash that changes the body's attack
			# position, with a retained speed buff after the strike.
			e["sprint_t"] = maxf(float(e.get("sprint_t", 0.0)), 1.5)
			g.spawn_ring_fx(pos, col, 36.0)
		"shove", "slam", "shield":
			if hero.distance_to(pos) < 110.0:
				g.hero["push"] = Vector2(g.hero.get("push", Vector2.ZERO)) + toward * 200.0
			g.spawn_ring_fx(pos, col, 90.0)
		"split", "hatch":
			# Budget is per move. No infinite mini/egg multiplication.
			apply_effect(g, e, pos, lender, false, 0.65)
		"heal", "guard", "rally":
			apply_effect(g, e, pos, lender, false, 0.5)
		"drain":
			if hero.distance_to(pos) < 90.0:
				e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.07)
				g.spawn_ring_fx(pos, col, 50.0)
		"blink":
			# The body keeps control; the donor leaves a visible rift on impact.
			g.spawn_ring_fx(pos, col, 80.0)
		"sticky":
			# Sticky payload on the hit position; must catch the player first.
			g.delayed.append({"fn": "mut_hit", "pos": pos, "t": 0.5, "life": 0.5,
				"tele": 53.0, "color": col.to_html(false), "src_enemy": e, "payload": "sticky"})
		"shell", "explode":
			C.schedule_boss_blast(g, pos, 48.0, dmg * 0.33, 0.48, col.to_html(false))
		"laser":
			C.schedule_boss_line(g, pos, pos + toward * 380.0, 6.0, dmg * 0.28, 0.55, col.to_html(false))
		"steal":
			if hero.distance_to(pos) <= 70.0 and g.gold > 0:
				g.gold -= 1
				g.say(hero + Vector2(0, -28), "-1 GOLD", col, 15)

## On-hit powers (glue, steal, sticky...) landing away from you become a warned
## circle that applies them if it catches you.
const ON_HIT = ["glue", "latch", "steal", "drain", "sticky"]

static func resolve_hit(g, item: Dictionary) -> void:
	var src = item.get("src_enemy")
	if src == null or bool(src.get("dead", false)):
		return
	g.spawn_ring_fx(item["pos"], Color(str(item.get("color", "ffffff"))), float(item["tele"]))
	if Vector2(g.hero["pos"]).distance_to(item["pos"]) <= float(item["tele"]) + 11.0:
		if g.hurt(float(src["dmg"]) * 0.4, item["pos"], "a mutant's " + str(item["payload"])):
			apply_effect(g, src, item["pos"], str(item["payload"]), true)

static func apply(g, e: Dictionary, pos: Vector2, payload: String, hit_player: bool) -> void:
	var before: int = g.delayed.size()
	apply_effect(g, e, pos, payload, hit_player)
	for k in range(before, g.delayed.size()):
		g.delayed[k]["mut_payload"] = true

## One power going off at `pos`. `k` < 1 when it fires from many anchors at
## once, so a ring of eight stays fair.
static func apply_effect(g, e: Dictionary, pos: Vector2, payload: String, hit_player: bool, k: float = 1.0) -> void:
	var C = load("res://scripts/Combat.gd")
	var EI = load("res://scripts/EnemyIdentity.gd")
	var dmg: float = float(e["dmg"])
	var hero: Vector2 = g.hero["pos"]
	var toward: Vector2 = (hero - pos).normalized() if hero.distance_squared_to(pos) > 1.0 else Vector2.DOWN
	if payload in ON_HIT and not hit_player:
		g.delayed.append({"fn": "mut_hit", "pos": pos, "t": 0.55, "life": 0.55, "tele": maxf(48.0, 80.0 * k),
			"color": _c(e, str(sig(payload).get("color", "ffffff"))), "src_enemy": e, "payload": payload})
		return
	match payload:
		"heal":
			for ally in g.enemies_near(pos, 130.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["hp"] = minf(float(ally["max_hp"]), float(ally["hp"]) + float(ally["max_hp"]) * 0.12 * k)
			g.spawn_ring_fx(pos, Color(_c(e, "83ffac")), 130.0)
		"guard":
			for ally in g.enemies_near(pos, 140.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["siphon_empowered_t"] = maxf(float(ally.get("siphon_empowered_t", 0.0)), 2.5)
			g.spawn_ring_fx(pos, Color(_c(e, "8fdcff")), 140.0)
		"rally":
			for ally in g.enemies_near(pos, 160.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["sprint_t"] = maxf(float(ally.get("sprint_t", 0.0)), 1.8)
			g.spawn_ring_fx(pos, Color(_c(e, "ffb0e8")), 160.0)
		"explode":
			# A big warned blast, then bomblets thrown out of it.
			C.schedule_boss_blast(g, pos, maxf(50.0, 84.0 * k), dmg * 0.9, 0.5, _c(e, "ff704d"))
			var bombs := maxi(1, roundi(4.0 * k))
			for b in range(bombs):
				var bd := Vector2.from_angle(TAU * float(b) / float(bombs) + randf() * 0.6)
				C.schedule_boss_blast(g, pos + bd * 105.0 * maxf(k, 0.6), 46.0 * maxf(k, 0.7), dmg * 0.5, 0.95, _c(e, "ffa04d"))
		"poison":
			EI.place(g, "acid", pos, maxf(46.0, 92.0 * k), dmg * 0.3, 4.5, 0.15, _c(e, ""))
		"laser":
			if pos.distance_to(hero) > 140.0:
				# From a far anchor: a beam straight through where you stand.
				var spread := 1 if k < 1.0 else 3
				for b in range(spread):
					C.schedule_boss_line(g, pos, pos + toward.rotated((float(b) - float(spread - 1) * 0.5) * 0.3) * 760.0, 12.0, dmg * 0.6, 0.65, _c(e, "ff3a5a"))
			else:
				var dir: Vector2 = (hero - Vector2(e["pos"])).normalized()
				if dir.length_squared() < 0.01:
					dir = Vector2.DOWN
				for b in range(3):
					C.schedule_boss_line(g, e["pos"], Vector2(e["pos"]) + dir.rotated((float(b) - 1.0) * 0.32) * 700.0, 12.0, dmg * 0.6, 0.6, _c(e, "ff3a5a"))
		"glue":
			g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 1.6)
		"latch":
			g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 2.4)
		"shock":
			if hit_player:
				g.hero["arena_stagger_t"] = maxf(float(g.hero.get("arena_stagger_t", 0.0)), 1.0)
			else:
				var hops := maxi(1, roundi(3.0 * k))
				var prev: Vector2 = pos
				for b in range(hops):
					var next: Vector2 = pos.lerp(hero, float(b + 1) / float(hops))
					C.schedule_boss_line(g, prev, next, 9.0, dmg * 0.38, 0.4 + 0.16 * b, _c(e, "9fd0ff"), "shock")
					prev = next
		"drain":
			e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.15)
			g.spawn_ring_fx(e["pos"], Color(_c(e, "b77dff")), 30.0)
		"shove", "slam", "shield":
			# A shockwave that hits and throws you away from it.
			var rad: float = (110.0 if payload == "slam" else 90.0) * maxf(k, 0.6)
			C.schedule_boss_blast(g, pos, rad, dmg * 0.6, 0.4, _c(e, "8fdcff" if payload == "shield" else "ffb88a"))
			if hit_player or hero.distance_to(pos) < rad + 30.0:
				g.hero["push"] = Vector2(g.hero.get("push", Vector2.ZERO)) + toward * (460.0 if payload != "slam" else 340.0) * maxf(k, 0.6)
		"rush":
			# A stampede: a warned charge lane from the spot straight through you.
			C.schedule_boss_line(g, pos, pos + toward * 300.0, 20.0, dmg * 0.6, 0.55, _c(e, "ffb06a"), "rush")
			e["sprint_t"] = maxf(float(e.get("sprint_t", 0.0)), 1.4)
		"split":
			if int(e.get("mut_budget", 2)) > 0 and g.enemies.size() < g.enemy_cap():
				e["mut_budget"] = int(e.get("mut_budget", 2)) - 1
				var m = g.spawn_enemy("mini", pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), false, false)
				m["summon"] = true
		"hatch":
			if int(e.get("mut_budget", 2)) > 0:
				e["mut_budget"] = int(e.get("mut_budget", 2)) - 1
				var hazards_before: int = g.enemy_hazards.size()
				EI.place(g, "egg", pos, 18.0, 0.0, 3.0, 0.0)
				if e.has("mut_col") and g.enemy_hazards.size() > hazards_before:
					g.enemy_hazards[-1]["mut_col"] = str(e["mut_col"])
		"shell":
			# Land on the delivery anchors, not three generic bombs at the
			# hero's *current* position regardless of the inherited pattern.
			for b in range(maxi(1, roundi(2.0 * k))):
				var spread: Vector2 = Vector2.ZERO if b == 0 else Vector2(randf_range(-48, 48), randf_range(-48, 48))
				C.schedule_boss_blast(g, pos + spread, 54.0, dmg * 0.58, 0.75 + 0.18 * b, _c(e, "f2ad6b"))
		"blink":
			var from: Vector2 = e["pos"]
			e["pos"] = pos
			g.spawn_ring_fx(pos, Color(_c(e, "c79cff")), 30.0)
			C.schedule_boss_blast(g, from, 70.0 * maxf(k, 0.7), dmg * 0.6, 0.6, _c(e, "c79cff"))
		"steal":
			if g.gold > 0:
				var taken: int = mini(g.gold, 3)
				g.gold -= taken
				g.say(hero + Vector2(0, -30), "-%d GOLD" % taken, Color("ffd24d"), 16)
		"fire":
			C.schedule_boss_blast(g, pos, maxf(40.0, 60.0 * k), dmg * 0.6, 0.4, _c(e, "ff2a2e"))
			EI.place(g, "fire", pos, maxf(48.0, 100.0 * k), dmg * 0.25, 2.6, 0.5, _c(e, ""))
		"shards":
			# Mirror shards bounce out in every direction.
			var count := maxi(5, roundi(8.0 * k))
			var off := randf() * TAU
			for b in range(count):
				var d := Vector2.from_angle(off + TAU * float(b) / float(count))
				C.shot(g, pos + d * 10.0, d, dmg * 0.4, {"friendly": false, "speed": 320.0, "life": 1.6, "r": 4.0,
					"kind": "enemy", "color": Color(_c(e, "bff8ff")), "src": "mirror shards"})
		"quake":
			C.schedule_boss_line(g, pos, pos + toward * 420.0 * maxf(k, 0.6), 18.0, dmg * 0.6, 0.7, _c(e, "e4b873"), "quake")
			if k >= 1.0:
				C.schedule_boss_blast(g, hero, 56.0, dmg * 0.7, 0.95, _c(e, "e4b873"))
		"sticky":
			if not g.hero.has("sticky_bomb"):
				g.hero["sticky_bomb"] = {"t": 2.2, "dmg": dmg * 1.2, "color": _c(e, "ff7a46")}
				g.say(hero + Vector2(0, -40), "STICKY BOMB! DASH!", Color("ffb07a"), 18)
		"spear":
			# Targeted piercing javelins, NOT the same eight-way radial burst
			# inherited by every mutation. Wide sweep lives in Lancer's melee mode.
			var count := maxi(1, roundi(3.0 * k))
			for b in range(count):
				var offset: float = (float(b) - float(count - 1) * 0.5) * 0.21
				var sd: Vector2 = toward.rotated(offset)
				var sp = C.shot(g, pos + sd * 14.0, sd, dmg * 0.62, {"friendly": false, "speed": 700.0,
					"life": 1.4, "r": 7.0, "kind": "enemy", "color": Color(_c(e, "c8d5ff")), "src": "a mutant spear"})
				if sp != null:
					sp["pierce"] = 3
					sp["spear"] = true
