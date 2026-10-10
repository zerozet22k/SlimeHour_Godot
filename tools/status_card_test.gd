extends SceneTree
## Run with Godot 4: godot --headless --path . --script tools/status_card_test.gd
const Combat = preload("res://scripts/Combat.gd")
const Effects = preload("res://scripts/Effects.gd")
const Main = preload("res://scripts/Main.gd")

class FakeGame:
	extends RefCounted
	var S: Dictionary = {}
	var card_by_id: Dictionary = {}
	var owned: Dictionary = {}
	var multiplier := 1.0
	func st(key: String) -> float:
		return float(S.get(key, 0.0))
	func sector_scale() -> float:
		return 1.0
	func dmg_mult() -> float:
		return multiplier

var failed := 0

func _check(ok: bool, name: String) -> void:
	if ok:
		print("PASS: ", name)
	else:
		failed += 1
		push_error("FAIL: " + name)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = FakeGame.new()
	var mob = {"max_hp": 100.0, "boss": false}
	var tank = {"max_hp": 10000.0, "boss": false}
	var boss = {"max_hp": 10000.0, "boss": true}
	for kind in ["burn", "poison", "bleed", "shock"]:
		var first = Combat.status_tick_damage(g, mob, kind, 2.0)
		_check(first > 0.0, kind + " deals damage")
		g.multiplier = 3.0
		_check(Combat.status_tick_damage(g, mob, kind, 2.0) > first, kind + " scales with player's damage")
		g.multiplier = 1.0
		_check(Combat.status_tick_damage(g, tank, kind, 2.0) > first, kind + " grows with high-health enemies")
		_check(Combat.status_tick_damage(g, boss, kind, 2.0) < Combat.status_tick_damage(g, tank, kind, 2.0), kind + " percent HP bonus reduced for bosses")
	g.S = {"poisonpow": 0.6, "burnpow": 0.6, "bleedpow": 0.6, "shockpow": 0.6}
	for kind in ["burn", "poison", "bleed", "shock"]:
		var boosted = Combat.status_tick_damage(g, mob, kind, 2.0)
		g.S[kind + "pow"] = 0.0
		_check(boosted > Combat.status_tick_damage(g, mob, kind, 2.0), kind + " responds to its matching power card")
		g.S[kind + "pow"] = 0.6
	_check(Combat.status_tick_damage(g, tank, "poison", 5.0) > Combat.status_tick_damage(g, tank, "poison", 1.0), "poison stacks remain meaningful")
	_check(Combat.status_tick_damage(g, tank, "bleed", 5.0, true) > Combat.status_tick_damage(g, tank, "bleed", 5.0, false), "moving enemies bleed faster")
	_check(is_equal_approx(Combat.status_tick_damage(g, mob, "unknown"), 0.0), "unknown status deals no damage")

	g.card_by_id["fire"] = {"mods": {"burn": 0.35}, "procs": []}
	g.card_by_id["power"] = {"mods": {"burnpow": 0.6}, "procs": []}
	g.card_by_id["proc"] = {"mods": {}, "procs": [{"on": "reload", "do": "shockwave", "dmg": 15, "r": 120}]}
	g.card_by_id["total"] = {"mods": {"tdmg": 0.2}, "procs": []}
	_check(Effects.stack_preview(g, "fire").contains("35%"), "new burn chance card displays percentage")
	_check(Effects.stack_preview(g, "power").contains("60%"), "new burn power card displays percentage")
	_check(Effects.stack_preview(g, "proc").contains("15 BASE DMG"), "trigger-only card displays quantified damage")
	_check(Effects.stack_preview(g, "total").contains("20%"), "total damage card displays percentage")
	g.owned["fire"] = 1
	_check(Effects.stack_preview(g, "fire").contains("35% > +60%"), "second copy previews diminished return")
	_check(Effects.stack_preview(g, "fire", true).contains("+35%"), "collection view shows current card value")
	# Sector health should not become an early-game HP wall after reducing card rewards.
	var game = Main.new()
	var last_hp = 0.0
	for sector in [1, 5, 6, 8, 10, 12, 20, 30]:
		game.sector = sector
		var hp = game.enemy_scale()
		_check(hp >= last_hp, "sector %d health scales monotonically" % sector)
		if sector == 8:
			_check(hp > 3.5 and hp < 5.0, "sector 8 normal enemy health near 4x base")
		last_hp = hp
	game.free()
	print("STATUS / CARD TESTS: ", "PASS" if failed == 0 else str(failed) + " failed")
	quit(1 if failed > 0 else 0)
