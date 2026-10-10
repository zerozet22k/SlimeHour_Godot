extends SceneTree
## Release-gate check: a GDScript parse error on Visuals.gd previously caused
## the HUD to render while the entire world remained invisible in Windows.
## Unlike the full framebuffer test, this runs in --headless Windows CI.
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var visual: Script = load("res://scripts/Visuals.gd")
	if visual == null or not visual.can_instantiate():
		push_error("World renderer script failed to parse/load!")
		failed = true
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Main game scene failed to load!")
		failed = true
	else:
		var game = packed.instantiate()
		if game == null:
			push_error("Main game scene could not instantiate!")
			failed = true
		else:
			var world: Node = game.get_node_or_null("Visuals")
			var hud: Node = game.get_node_or_null("Hud")
			if world == null or world.get_script() == null:
				push_error("World layer has no compiled GDScript; the player/road/enemies will be invisible!")
				failed = true
			if hud == null or hud.get_script() == null:
				push_error("HUD layer is missing!")
				failed = true
			game.free()
	print("WORLD SCENE SCRIPT: ", "PASS" if not failed else "FAIL")
	quit(1 if failed else 0)
