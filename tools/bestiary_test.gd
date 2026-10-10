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
		if not Bestiary.NOTES.has(id):
			missing += 1
			push_error("BESTIARY MISSING: " + str(id))
		elif Bestiary.info(id).size() != 3:
			missing += 1
	print("BESTIARY CHECK: ", main.mob_order().size(), " monsters - ", missing, " missing")
	main.free()
	quit(1 if missing else 0)
