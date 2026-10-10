extends SceneTree
const Main = preload("res://scripts/Main.gd")
const DebugLab = preload("res://scripts/DebugLab.gd")

var failures := 0
func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: ", label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DebugLab.sector_for(-10) == 1, "Sector range clamps at 1")
	check(DebugLab.sector_for(101) == 100, "Sector range clamps at the debug limit")
	check(DebugLab.sector_for(6, "boss") == 10, "Boss warp seeks the next boss sector")
	check(DebugLab.sector_for(15, "boss") == 15, "Existing boss sector remains unchanged")
	check(DebugLab.sector_for(66, "boss") == 66, "Endless boss mode supports every sector after 50")
	var game = Main.new()
	game.profile = {"level": 4, "xp": 23, "kills": 45, "goo": 11, "mobs": {"blob": 100}, "known_cards": {"starter": true}}
	game.best = {"sector": 12, "kills": 200, "level": 9}
	game.unlocked_cards = {"starter": true}
	game.unlocked_guns = ["pistol", "smg"]
	game.next_unlock_kills = 150
	DebugLab.enter(game)
	check(game.debug_session and game.no_save, "Entering debug mode suppresses disk saving")
	game.profile["level"] = 200
	game.profile["mobs"]["blob"] = 999
	game.best["sector"] = 88
	game.unlocked_cards["boss_power"] = true
	game.unlocked_guns.append("rail")
	game.next_unlock_kills = 9911
	DebugLab.enter(game)
	DebugLab.restore(game)
	check(not game.debug_session and not game.no_save, "Leaving Debug Lab restores normal saving")
	check(int(game.profile["level"]) == 4 and int(game.profile["mobs"]["blob"]) == 100, "Nested profile data is restored")
	check(game.best["sector"] == 12 and game.next_unlock_kills == 150, "Achievements and thresholds are restored")
	check(not game.unlocked_cards.has("boss_power") and not game.unlocked_guns.has("rail"), "Debug unlocks never persist")
	check(game.debug_snapshot.is_empty() and not game.debug_godmode, "Temporary debug flags are cleared")
	var cards = DebugLab.items(game, "CARDS")
	var guns = DebugLab.items(game, "WEAPONS")
	var enemies = DebugLab.items(game, "ENEMIES")
	check(cards.is_empty() and guns.is_empty() and enemies.is_empty(), "Empty data catalogs are handled safely")
	game.weapon_ids = ["pistol", "sniper"]
	game.weapon_db = {"pistol": {"name": "Peashooter"}, "sniper": {"name": "Final Goodbye"}}
	check(DebugLab.items(game, "WEAPONS").size() == 2, "All weapons are selectable in Debug Lab")
	game.db_cards = [{"id": "fake", "name": "Fake Card"}]
	check(DebugLab.items(game, "CARDS")[0]["label"] == "Fake Card", "Card picker labels show readable names")
	game.enemy_db = {"blob": {"name": "Blob"}}
	check(DebugLab.items(game, "ENEMIES")[0]["id"] == "blob", "Enemy picker uses actual enemy identifiers")
	game.free()
	print("DEBUG LAB TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
