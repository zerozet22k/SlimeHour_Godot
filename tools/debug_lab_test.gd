extends SceneTree
const Main = preload("res://scripts/Main.gd")
const DebugLab = preload("res://scripts/DebugLab.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")

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
	check(DebugLab.categories(game, "ENEMIES") == ["ALL", "NORMAL", "BOSSES", "MUTATIONS"], "Enemy filter always exposes all four groups")
	check(DebugLab.items(game, "ENEMIES", "NORMAL").size() == 1 and DebugLab.items(game, "ENEMIES", "BOSSES").is_empty(), "Base enemies are separated from bosses")
	check(DebugLab.items(game, "ENEMIES", "NORMAL", "barricade").size() == 1, "Search can match combat-mechanic names")
	game.db_cards = [{"id": "fake", "name": "Fake Card", "cat": "volley", "desc": "Extra projectiles"}, {"id": "shield", "name": "Safe Card", "cat": "defense", "desc": "Block one hit"}]
	check(DebugLab.categories(game, "CARDS") == ["ALL", "DEFENSE", "VOLLEY"], "Cards are categorized by effect type")
	check(DebugLab.items(game, "CARDS", "VOLLEY", "projectile").size() == 1, "Card category and search work together")
	check(DebugLab.items(game, "CARDS", "DEFENSE", "projectile").is_empty(), "Search honors active card category")
	game.weapon_db["sniper"]["kind"] = "beam"
	game.weapon_db["pistol"]["kind"] = "bullet"
	check(DebugLab.items(game, "WEAPONS", "BEAM", "final").size() == 1, "Weapon type and name search work together")
	game.debug_panel_open = true
	game.debug_category = "BOSSES"
	game.debug_query = "unused"
	game.debug_page = 5
	DebugLab.run_action(game, "debug_tab_ENEMIES")
	check(game.debug_category == "ALL" and game.debug_query == "" and game.debug_page == 0, "Switching tabs clears stale search and category")
	DebugLab.run_action(game, "debug_category_MUTATIONS")
	check(game.debug_category == "MUTATIONS" and game.debug_page == 0, "Changing categories resets result pagination")
	# Authored mutations must be browseable without eagerly populating enemy_db,
	# then created with their actual named combat recipe when spawned.
	for id in ["blob", "mirror"]:
		game.enemy_db[id] = {"name": id, "hp": 40, "speed": 90, "dmg": 12,
			"r": 15, "xp": 2, "mass": 1.0, "color": "ff99aa"}
	game.enemy_db["chonkzilla"] = {"name": "Chonkzilla", "boss": true}
	var mutation_id = EnemyMixes.id_for("mirror", "blob")
	var mutation_list = DebugLab.items(game, "ENEMIES", "MUTATIONS")
	check(mutation_list.size() >= 1 and mutation_list[0]["id"] == mutation_id, "Mutations list contains authored uncreated recipes")
	check(not game.enemy_db.has(mutation_id), "Browsing the debug catalog does not generate mutations")
	check(DebugLab.items(game, "ENEMIES", "BOSSES", "earthbreaker").size() == 1, "Bosses are searchable by distinctive mechanics")
	check(DebugLab.items(game, "ENEMIES", "NORMAL", "mirror").size() == 1, "Normal monster search excludes mutation names")
	check(DebugLab.prepare_enemy(game, mutation_id), "Lazy recipe can be prepared for debug spawning")
	check(game.enemy_db.has(mutation_id) and str(game.enemy_db[mutation_id].get("fusion_style", "")) == "echo", "Debug-created mutations retain their combat behavior")
	check(DebugLab.items(game, "ENEMIES", "NORMAL").size() == 2, "Generated mutations do not leak into normal mob category")
	game.free()
	print("DEBUG LAB TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
