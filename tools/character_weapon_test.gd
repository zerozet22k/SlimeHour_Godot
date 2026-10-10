extends SceneTree
## Run with: godot --headless --path . --script tools/character_weapon_test.gd
const Characters = preload("res://scripts/Characters.gd")
const Weapons = preload("res://scripts/Weapons.gd")
const Main = preload("res://scripts/Main.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var game = Main.new()
	game.hero = {"hp": 100.0, "maxhp": 100.0, "moving": false, "pos": Vector2.ZERO, "aim": Vector2.UP}
	var ids = {}
	if data is Array:
		for w in data:
			game.weapon_db[str(w["id"])] = w
			ids[str(w["id"])] = true
	check(ids.size() >= 22, "Existing gun catalog remains intact")
	check(game.selected_character == Characters.DEFAULT, "Legacy players default to Scout")
	check(Characters.ROSTER.size() == 5, "Five balanced character options")
	var seen = {}
	for ch in Characters.ROSTER:
		var id = str(ch["id"])
		var weapon = str(ch["weapon"])
		check(not seen.has(id) and ids.has(weapon), id + " has a unique identity and valid starting weapon")
		seen[id] = true
		check(Characters.xp_multiplier(id) >= 0.95 and Characters.xp_multiplier(id) <= 1.0, id + " has a modest XP adjustment")
		check(Characters.affinity(id, weapon, "weapon_damage") <= 1.06, id + " has a small damage bonus")
		check(Characters.affinity(id, "shotgun", "weapon_damage") == 1.0, id + " does not globally buff unrelated guns")
	check(not Characters.valid("unknown"), "Unknown character cannot be selected")
	check(Characters.get_character("unknown")["id"] == Characters.DEFAULT, "Invalid save safely falls back to Scout")
	game.do_action("play")
	check(game.state == "characters" and not game.hard_mode, "Play enters selection, not combat")
	game.do_action("play_hard")
	check(game.state == "characters" and game.hard_mode, "Hard Mode retains its difficulty during selection")
	game.do_action("character_back")
	check(game.state == "menu", "Back returns to menu")
	var pistol = Weapons.new_gun(game, "pistol")
	game.selected_character = "scout"
	var scout_damage = Weapons.shot_damage(game, pistol)
	game.selected_character = "ember"
	var other_damage = Weapons.shot_damage(game, pistol)
	check(scout_damage > other_damage and is_equal_approx(scout_damage / other_damage, 1.04), "Sidearm affinity only buffs Scout's pistol")
	var flame = Weapons.new_gun(game, "flame")
	var ember_damage = Weapons.shot_damage(game, flame)
	game.selected_character = "scout"
	check(ember_damage > Weapons.shot_damage(game, flame), "Ember's flamethrower affinity works")
	var revolver = Weapons.new_gun(game, "revolver")
	game.selected_character = "ace"
	var crit = Weapons.base_opts(game, revolver, game.weapon_db["revolver"])
	game.selected_character = "scout"
	var base_crit = Weapons.base_opts(game, revolver, game.weapon_db["revolver"])
	check(is_equal_approx(float(crit["crit"]) - float(base_crit["crit"]), 0.03), "Ace adds only 3 percentage points to revolver critical chance")
	var smg = Weapons.new_gun(game, "smg")
	var normal_rate = Weapons.fire_rate(game, smg)
	game.selected_character = "vector"
	check(is_equal_approx(Weapons.fire_rate(game, smg) / normal_rate, 1.05), "Vector buffs only SMG firing speed")
	var rail = Weapons.new_gun(game, "rail")
	game.selected_character = "scout"
	var base_charge = Weapons.rail_charge_seconds(game, rail)
	game.selected_character = "coil"
	check(Weapons.rail_charge_seconds(game, rail) < base_charge and base_charge > 0.6, "Coil gets 5% shorter Railgun wind-up")
	check(not bool(rail["rail_needs_release"]) and float(rail["cd"]) == 0.0, "Railgun starts armed with no post-shot cooldown")
	check(game.weapon_db["pistol"]["name"] == "Service Nine", "Starter sidearm has a professional name")
	check(game.weapon_db["rail"]["name"] == "Gauss Lance", "Railgun keeps a recognizable identity")
	game.free()
	print("CHARACTER / WEAPON TESTS: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures else 0)
