extends SceneTree
const Bestiary = preload("res://scripts/Bestiary.gd")
const Main = preload("res://scripts/Main.gd")
const Hud = preload("res://scripts/Hud.gd")
func _initialize() -> void:
	call_deferred("_check")
func _check() -> void:
	var main = Main.new()
	var missing = 0
	for id in main.mob_order():
		if not Bestiary.NOTES.has(id) and not id.begins_with("mix_"):
			missing += 1
			push_error("BESTIARY MISSING: " + str(id))
		elif Bestiary.info(id).size() != 3:
			missing += 1
	# One base joins every four map choices; each pair's mix follows next.
	var introductions = {"nurse": 6, "larry": 10, "mortar": 14, "bull": 18,
		"mix_nurse_larry": 11, "mix_mortar_bull": 19}
	var roster_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var ids = {}
	if roster_data is Array:
		for spec in roster_data:
			ids[str(spec["id"])] = spec
	for id in introductions:
		if Main.introduction_for(int(introductions[id])) != id:
			missing += 1
			push_error("BAD ROUTE INTRO: " + str(id))
		elif not id.begins_with("mix_") and not ids.has(id):
			missing += 1
			push_error("MISSING BASE ENEMY DATA: " + str(id))
		elif not Main.available_enemies(int(introductions[id])).has(id) or Main.available_enemies(int(introductions[id]) - 1).has(id):
			missing += 1
			push_error("BAD AVAILABILITY WINDOW: " + str(id))
	# Regression: the old Sectors 9-11 HP and enemy flood spike stays softened.
	main.sector = 8
	var hp8 = main.enemy_scale()
	main.sector = 9
	var hp9 = main.enemy_scale()
	var cap9 = main.enemy_cap()
	main.sector = 10
	var hp10 = main.enemy_scale()
	var cap10 = main.enemy_cap()
	main.sector = 11
	var hp11 = main.enemy_scale()
	if not (hp8 < hp9 and hp9 < hp10 and hp10 < hp11 and hp11 < 5.0):
		missing += 1
		push_error("SECTOR 9-11 HEALTH CURVE REGRESSION")
	if not (cap9 <= 110 and cap10 <= 115 and main.enemy_cap() <= 120):
		missing += 1
		push_error("SECTOR 9-11 CROWD CAP REGRESSION")
	if not (main.midgame_relief(10) < main.midgame_relief(8) and main.midgame_relief(13) > main.midgame_relief(11)):
		missing += 1
		push_error("MIDGAME RECOVERY CURVE REGRESSION")
	print("BESTIARY CHECK: ", main.mob_order().size(), " monsters - ", missing, " missing")
	main.free()
	quit(1 if missing else 0)
