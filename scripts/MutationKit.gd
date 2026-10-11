extends RefCounted
## Mutations combine into ONE ability: the body parent (taker) keeps its own
## way of attacking — its DELIVERY — and the second parent (giver) supplies a
## PAYLOAD that every one of those attacks carries.
##   Laser Larry body + Medic   -> its laser heals monsters it passes
##   Medic body + Kaboomba      -> it pulses a warned ring that explodes
##   Lancer body + Spitter      -> its spear leaves a poison puddle
## Species that never attack the player deliver through a warned pulse.

## Each species can give one of two augments; the mutation decides which.
const GIVES = {
	"blob": ["glue", "guard"], "zoomer": ["rush", "shove"], "chonk": ["slam", "quake"],
	"spitter": ["poison", "glue"], "kaboomba": ["explode", "fire"], "mitosis": ["split", "heal"],
	"mini": ["rush", "split"], "riot": ["guard", "shove"], "bull": ["shove", "slam"],
	"mama": ["hatch", "split"], "mortar": ["shell", "explode"], "totem": ["guard", "heal"],
	"blinky": ["blink", "shards"], "tick": ["latch", "drain"], "goblin": ["steal", "rush"],
	"ashwing": ["fire", "explode"], "mirror": ["shards", "laser"], "burrower": ["quake", "shell"],
	"siren": ["rally", "shock"], "skitter": ["shock", "rush"], "sapper": ["sticky", "explode"],
	"lancer": ["spear", "laser"], "leech": ["drain", "heal"], "nurse": ["heal", "guard"],
	"larry": ["laser", "fire"],
}
## Bodies that do not attack the player themselves deliver by pulsing.
const PULSE_TAKERS = ["nurse", "totem", "siren", "goblin", "mama"]
const PAYLOAD_NAMES = {
	"glue": "Gluey", "rush": "Frenzied", "slam": "Quaking", "poison": "Toxic",
	"explode": "Volatile", "split": "Budding", "guard": "Guarded", "shove": "Ramming",
	"hatch": "Brooding", "shell": "Shelling", "blink": "Blinking", "latch": "Clinging",
	"steal": "Thieving", "fire": "Burning", "shards": "Shattering", "quake": "Tremor",
	"rally": "Rallying", "shock": "Shocking", "sticky": "Sticky", "spear": "Piercing",
	"drain": "Draining", "heal": "Healing", "laser": "Lasing",
}
const PAYLOAD_DESC = {
	"glue": "glue that slows you", "rush": "a speed burst after it hits", "slam": "a knockback quake",
	"poison": "a poison puddle", "explode": "a delayed explosion", "split": "a Mini that buds off",
	"guard": "a shield for nearby monsters", "shove": "a hard shove", "hatch": "an egg that hatches",
	"shell": "an artillery shell on your position", "blink": "a teleport next to you", "latch": "a long slow",
	"steal": "a gold theft", "fire": "a burst of flame", "shards": "mirror shards fired back at you",
	"quake": "an eruption under you", "rally": "a speed rally for nearby monsters", "shock": "a stagger",
	"sticky": "a sticky bomb", "spear": "a fast piercing spear", "drain": "a life drain that heals it",
	"heal": "healing for nearby monsters", "laser": "a laser line",
}

## Parents in the same order EnemyMixes.ensure assigns them (body first).
static func parents_for_id(id: String) -> Array:
	var pair: Array = Array(id.trim_prefix("mix_").split("_"))
	if pair.size() != 2:
		return []
	pair.sort()
	if posmod(id.hash(), 2) == 1:
		pair.reverse()
	return pair

## Payloads that help monsters instead of hurting you.
const SUPPORT = ["heal", "guard", "rally"]

static func is_mutant(g, e: Dictionary) -> bool:
	return e.has("mut_of") or str(e.get("kind", "")).begins_with("mix_")

static func parents(g, kind: String) -> Array:
	if not kind.begins_with("mix_") or not g.enemy_db.has(kind):
		return []
	return g.enemy_db[kind].get("mix", [])

static func primary(g, kind: String) -> String:
	var p := parents(g, kind)
	return str(p[0]) if not p.is_empty() else kind

## The augment a giver passes on in this particular mutation.
static func payload_index(kind: String, giver: String) -> int:
	var options: Array = GIVES.get(giver, [])
	return 0 if options.is_empty() else posmod(kind.hash() >> 3, options.size())

static func payload_for(kind: String, giver: String) -> String:
	var options: Array = GIVES.get(giver, [])
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

## Per-frame extras for mutants whose body never attacks: a warned pulse.
static func tick(g, e: Dictionary, dt: float) -> void:
	var kind := str(e["kind"])
	if not kind.begins_with("mix_") or not primary(g, kind) in PULSE_TAKERS:
		return
	e["mut_pulse_t"] = float(e.get("mut_pulse_t", 2.5)) - dt
	if float(e["mut_pulse_t"]) > 0.0:
		return
	e["mut_pulse_t"] = 4.5 if not g.hard_mode else 3.6
	var payload := payload_of(g, e)
	if payload in SUPPORT:
		apply(g, e, e["pos"], payload, false)
		return
	# Line-shaped payloads pulse as a 360-degree star: six long lines 60
	# degrees apart, rotated each pulse so the safe gaps move.
	if payload in ["laser", "spear", "shards"]:
		var C = load("res://scripts/Combat.gd")
		var before: int = g.delayed.size()
		e["mut_spin"] = float(e.get("mut_spin", 0.0)) + PI / 6.0
		for k in range(6):
			var d := Vector2.from_angle(float(e["mut_spin"]) + TAU * float(k) / 6.0)
			var from: Vector2 = Vector2(e["pos"]) + d * float(e["r"])
			var color: String = {"laser": "ff3a5a", "spear": "c8d5ff", "shards": "bff8ff"}[payload]
			C.schedule_boss_line(g, from, from + d * 560.0, 12.0 if payload == "laser" else 9.0, float(e["dmg"]) * 0.6, 0.9, color)
		for k in range(before, g.delayed.size()):
			g.delayed[k]["mut_payload"] = true
		return
	g.delayed.append({"fn": "mut_pulse", "pos": e["pos"], "t": 0.85, "life": 0.85, "tele": 115.0,
		"color": "c8ff8a", "src_enemy": e, "payload": payload})

static func resolve(g, item: Dictionary) -> void:
	var src = item.get("src_enemy")
	if src == null or bool(src.get("dead", false)):
		return
	var pos: Vector2 = item["pos"]
	g.spawn_ring_fx(pos, Color("c8ff8a"), float(item["tele"]))
	var hit: bool = Vector2(g.hero["pos"]).distance_to(pos) <= float(item["tele"]) + 11.0
	if hit:
		g.hurt(float(src["dmg"]) * 0.6, pos, "a mutant pulse")
	apply(g, src, Vector2(g.hero["pos"]) if hit else pos, str(item["payload"]), hit)

## A mutant's attack landed (hit_player) or finished at `pos`: apply the payload.
static func on_attack(g, e: Dictionary, pos: Vector2, hit_player: bool) -> void:
	if e == null or bool(e.get("dead", false)):
		return
	var payload := payload_of(g, e)
	if payload == "":
		return
	if g.run_time < float(e.get("mut_cd", -1.0)):
		return
	e["mut_cd"] = g.run_time + 0.6
	apply(g, e, pos, payload, hit_player)

static func apply(g, e: Dictionary, pos: Vector2, payload: String, hit_player: bool) -> void:
	var before: int = g.delayed.size()
	apply_effect(g, e, pos, payload, hit_player)
	for k in range(before, g.delayed.size()):
		g.delayed[k]["mut_payload"] = true

static func apply_effect(g, e: Dictionary, pos: Vector2, payload: String, hit_player: bool) -> void:
	var C = load("res://scripts/Combat.gd")
	var EI = load("res://scripts/EnemyIdentity.gd")
	var dmg: float = float(e["dmg"])
	var hero: Vector2 = g.hero["pos"]
	match payload:
		"heal":
			for ally in g.enemies_near(pos, 130.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["hp"] = minf(float(ally["max_hp"]), float(ally["hp"]) + float(ally["max_hp"]) * 0.12)
			g.spawn_ring_fx(pos, Color("83ffac"), 130.0)
		"guard":
			for ally in g.enemies_near(pos, 140.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["siphon_empowered_t"] = maxf(float(ally.get("siphon_empowered_t", 0.0)), 2.5)
			g.spawn_ring_fx(pos, Color("8fdcff"), 140.0)
		"rally":
			for ally in g.enemies_near(pos, 160.0):
				if not bool(ally["dead"]) and not bool(ally.get("boss", false)):
					ally["sprint_t"] = maxf(float(ally.get("sprint_t", 0.0)), 1.8)
			g.spawn_ring_fx(pos, Color("ffb0e8"), 160.0)
		"explode":
			C.schedule_boss_blast(g, pos, 64.0, dmg * 0.8, 0.45, "ff704d")
		"poison":
			EI.place(g, "acid", pos, 44.0, dmg * 0.3, 4.0, 0.15)
		"laser":
			var dir: Vector2 = (pos - Vector2(e["pos"])).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2.DOWN
			C.schedule_boss_line(g, e["pos"], Vector2(e["pos"]) + dir * 700.0, 12.0, dmg * 0.7, 0.55, "ff3a5a")
		"glue":
			if hit_player:
				g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 1.6)
		"latch":
			if hit_player:
				g.hero["arena_corrosion_t"] = maxf(float(g.hero.get("arena_corrosion_t", 0.0)), 2.4)
		"shock":
			if hit_player:
				g.hero["arena_stagger_t"] = maxf(float(g.hero.get("arena_stagger_t", 0.0)), 1.0)
		"drain":
			if hit_player:
				e["hp"] = minf(float(e["max_hp"]), float(e["hp"]) + float(e["max_hp"]) * 0.15)
				g.spawn_ring_fx(e["pos"], Color("b77dff"), 30.0)
		"shove", "slam":
			if hit_player or hero.distance_to(pos) < 120.0:
				g.hero["push"] = Vector2(g.hero.get("push", Vector2.ZERO)) + (hero - Vector2(e["pos"])).normalized() * (420.0 if payload == "shove" else 300.0)
			if payload == "slam":
				g.spawn_ring_fx(pos, Color("ffb88a"), 90.0)
		"rush":
			e["sprint_t"] = maxf(float(e.get("sprint_t", 0.0)), 1.4)
		"split":
			if g.enemies.size() < g.enemy_cap():
				var m = g.spawn_enemy("mini", pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), false, false)
				m["summon"] = true
		"hatch":
			EI.place(g, "egg", pos, 18.0, 0.0, 3.0, 0.0)
		"shell":
			C.schedule_boss_blast(g, hero + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 58.0, dmg * 0.7, 1.0, "f2ad6b")
		"blink":
			e["pos"] = pos + (Vector2(e["pos"]) - pos).normalized() * 60.0
			g.spawn_ring_fx(e["pos"], Color("c79cff"), 28.0)
		"steal":
			if hit_player and g.gold > 0:
				var taken: int = mini(g.gold, 3)
				g.gold -= taken
				g.say(hero + Vector2(0, -30), "-%d GOLD" % taken, Color("ffd24d"), 16)
		"fire":
			C.schedule_boss_blast(g, pos, 52.0, dmg * 0.5, 0.35, "ff8a3d")
		"shards":
			for k in range(3):
				var d := (hero - pos).normalized().rotated((float(k) - 1.0) * 0.35)
				C.shot(g, pos + d * 10.0, d, dmg * 0.4, {"friendly": false, "speed": 320.0, "life": 1.6, "r": 4.0,
					"kind": "enemy", "color": Color("bff8ff"), "src": "mirror shards"})
		"quake":
			C.schedule_boss_blast(g, hero, 56.0, dmg * 0.8, 0.7, "e4b873")
		"sticky":
			if hit_player and not g.hero.has("sticky_bomb"):
				g.hero["sticky_bomb"] = {"t": 2.2, "dmg": dmg * 1.2}
				g.say(hero + Vector2(0, -40), "STICKY BOMB! DASH!", Color("ffb07a"), 18)
		"spear":
			var sd: Vector2 = (hero - Vector2(e["pos"])).normalized()
			var sp = C.shot(g, Vector2(e["pos"]) + sd * float(e["r"]), sd, dmg * 0.8, {"friendly": false, "speed": 950.0,
				"life": 1.2, "r": 7.0, "kind": "enemy", "color": Color("c8d5ff"), "src": "a mutant spear"})
			if sp != null:
				sp["pierce"] = 3
