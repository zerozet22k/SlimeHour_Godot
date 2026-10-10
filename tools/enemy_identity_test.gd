extends SceneTree
## Tests identity separation and actual enemy attacks, not just text in data.
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const Mixes = preload("res://scripts/EnemyMixes.gd")

class SilentSfx:
	extends RefCounted
	func play(_name: String) -> void:
		pass
	func play_projectile(_name: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var failures := 0

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error("ENEMY IDENTITY FAIL: " + why)
	else:
		print("PASS: " + why)

func specimen(g, kind: String, id: int = 10) -> Dictionary:
	var d: Dictionary = g.enemy_db[kind]
	return {"kind": kind, "id": id, "pos": Vector2(0, -260), "vel": Vector2.ZERO,
		"kb": Vector2.ZERO, "r": float(d["r"]), "dmg": float(d["dmg"]),
		"hp": float(d["hp"]), "max_hp": float(d["hp"]), "speed": float(d["speed"]),
		"mass": float(d["mass"]), "boss": false, "elite": false, "dead": false,
		"cd": 0.0, "wind": 0.0, "charge": 0.0, "cdir": Vector2.ZERO,
		"t": 1.0, "phase": 0.0, "stun": 0.0, "aim": Vector2.DOWN,
		"charm": 0.0, "flash": 0.0, "squash": 0.0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.hero = {"pos": Vector2.ZERO, "vel": Vector2(85, 0), "hp": 220.0,
		"maxhp": 220.0, "iframe": 0.0, "dash_window": 0.0, "aim": Vector2.UP}
	g.state = "playing"
	g.sector = 18
	g.road_half = 420.0
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for d in data:
		g.enemy_db[str(d["id"])] = d
	var fusion = Mixes.ensure(g.enemy_db, "blinky", "mirror")
	g.profile["mobs"][fusion] = 10
	check(not g.mob_order().has(fusion), "Mutations are excluded from the monster species list, even when historically discovered")
	check(g.mutation_book_ids().has(Mixes.recipe_id(0)), "Curated mutations stay in the separate Mutation Book")
	check(not g.mutation_is_unlocked(Mixes.recipe_id(0)), "Mutation run locks are preserved")
	var hud_source = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	check(hud_source.contains('var filters = ["ALL", "STREET", "BOSSES", "FOUND"]'), "Bestiary tabs cannot mix mutations into normal monsters")
	g.shots.clear()
	var spitter = specimen(g, "spitter")
	Combat.ai(g, spitter, Vector2.DOWN, 260.0, 0.016, false)
	check(float(spitter["wind"]) > 0.0 and spitter.has("lock"), "Spitter warns and locks a predicted acid attack")
	Combat.ai(g, spitter, Vector2.DOWN, 260.0, 0.75, false)
	check(g.shots.size() == 3 and g.shots.any(func(s): return absf(float(s["curve"])) > 0.2), "Spitter fires true curving projectiles")
	g.shots.clear()
	var zoomer = specimen(g, "zoomer")
	Combat.ai(g, zoomer, Vector2.DOWN, 200.0, 0.016, false)
	check(float(zoomer.get("sprint_t", 0.0)) > 0.0 and float(zoomer["charge"]) == 0.0, "Zoomer strafes instead of copying the Skitter charge")
	var leech = specimen(g, "leech")
	Combat.ai(g, leech, Vector2.DOWN, 155.0, 0.016, false)
	check(float(leech["wind"]) > 0.0 and leech.has("lock"), "Leech begins a breakable channeled siphon")
	g.hero["pos"] = Vector2(340, 0)
	var original_hp = float(leech["hp"])
	Combat.ai(g, leech, Vector2.RIGHT, 400.0, 1.1, false)
	check(is_equal_approx(float(leech["hp"]), original_hp), "Breaking leash range prevents Leech healing")
	g.hero["pos"] = Vector2.ZERO
	g.delayed.clear()
	var blink = specimen(g, "blinky")
	Combat.ai(g, blink, Vector2.DOWN, 260.0, 0.016, false)
	check(float(blink["wind"]) > 0.0 and blink.has("rift_origin"), "Blinky marks a teleport with a persistent departure point")
	Combat.ai(g, blink, Vector2.DOWN, 260.0, 0.95, false)
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_line") and g.shots.size() > 0, "Blinky creates an old-position echo beam plus new-position projectile threat")
	g.delayed.clear()
	g.shots.clear()
	var mole = specimen(g, "burrower")
	Combat.ai(g, mole, Vector2.DOWN, 260.0, 0.016, false)
	check(bool(mole.get("burrowing", false)) and mole.has("tunnel_start"), "Burrower excavates a distinct underground tunnel")
	check(not Combat.hit(g, mole, 10.0, {"dir": Vector2.UP, "gen": 0}), "Direct fire cannot hit underground Burrower")
	Combat.ai(g, mole, Vector2.DOWN, 260.0, 1.05, false)
	check(not bool(mole.get("burrowing", true)), "Burrower resurfaces at the marked exit")
	check(g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_line") and g.delayed.any(func(d): return str(d.get("fn", "")) == "boss_blast"), "Burrower warns an exit quake and a separate tunnel collapse")
	var visuals = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(visuals.contains('e["kind"] == "leech"') and visuals.contains('e.get("burrowing", false)'), "Unique warning geometry is actually drawn")
	g.free()
	print("ENEMY IDENTITY: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
