extends SceneTree
## Run: godot --headless --path . --script res://tests/test_dynamic_enemies.gd
const Mixes = preload("res://scripts/EnemyMixes.gd")
const Game = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")

class DotWorld:
	extends Node2D
	var settings = {"numbers": true}
	var damage_dealt = 0.0
	var run_time = 0.0
	var seen: Array = []
	func dot_number(_pos: Vector2, amount: float, _color: Color, label: String) -> void:
		seen.append({"damage": amount, "label": label})

func _initialize() -> void:
	var db: Dictionary = {}
	var file = FileAccess.get_file_as_string("res://data/enemies.json")
	var entries = JSON.parse_string(file)
	assert(entries is Array)
	for e in entries:
		db[str(e["id"])] = e

	var basic = ["blob", "zoomer", "spitter", "kaboomba", "nurse", "skitter", "larry", "leech"]
	assert(Mixes.roll(db, basic, 10) == "")
	assert(Mixes.id_for("nurse", "larry") == Mixes.id_for("larry", "nurse"))
	for a in basic:
		for b in basic:
			if a == b:
				continue
			var id = Mixes.ensure(db, a, b)
			assert(id != "")
			assert(db[id]["mix"].has(a) and db[id]["mix"].has(b))
			assert(db[id]["look"].has("second_color"))
	assert(Mixes.id_for("nurse", "larry") != Mixes.id_for("nurse", "skitter"))
	assert(Mixes.id_for("larry", "leech") != "")
	var encountered = {}
	for i in range(220):
		var hybrid = Mixes.roll(db, basic, 12)
		assert(hybrid != "")
		assert(not db[hybrid].get("boss", false))
		encountered[hybrid] = true
	assert(encountered.size() >= 8, "Hybrids must not be a fixed Nurse + Larry recipe.")

	var g = Game.new()
	g.pickups = [
		{"kind": "gold", "pos": Vector2(5, 6), "value": 1},
		{"kind": "gold", "pos": Vector2(25, 10), "value": 9},
		{"kind": "xp", "pos": Vector2(9, 10), "value": 3},
		{"kind": "xp", "pos": Vector2(18, 12), "value": 7},
		{"kind": "heart", "pos": Vector2(12, 12), "value": 1}
	]
	g.merge_nearby_pickups()
	var gold = 0
	var xp = 0
	var hearts = 0
	for pk in g.pickups:
		match str(pk["kind"]):
			"gold": gold += int(pk["value"])
			"xp": xp += int(pk["value"])
			"heart": hearts += 1
	assert(gold == 10 and xp == 10 and hearts == 1)
	assert(g.pickups.size() == 3)
	assert(Game.introduction_for(6) == "nurse")
	assert(Game.introduction_for(8) == "skitter")
	assert(Game.introduction_for(10) == "larry")
	assert(Game.introduction_for(14) == "leech")

	var world = DotWorld.new()
	var monster = {"pos": Vector2.ZERO, "hp": 100.0, "dead": false}
	for i in range(4):
		world.run_time = float(i) * 0.25
		Combat.dot(world, monster, 2.5, Color("ff8a3d"), "BURN")
	assert(is_equal_approx(float(monster["hp"]), 90.0))
	assert(is_equal_approx(float(world.damage_dealt), 10.0))
	assert(world.seen.size() == 2, "DOT text should coalesce ticks, not spawn every tick.")
	g.free()
	world.free()
	print("Dynamic enemy mixtures, currency merging and damage tick tests passed.")
	quit(0)
