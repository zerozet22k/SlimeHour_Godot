extends SceneTree
## Regression for the basic melee strike and Kaboomba's delayed contact explosion.
const Combat = preload("res://scripts/Combat.gd")
var fails := 0
func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		fails += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var origin = Vector2.ZERO
	check(Combat.bash_in_arc(origin, Vector2.RIGHT, Vector2(60, 0), 15.0), "bash hits directly in front")
	check(Combat.bash_in_arc(origin, Vector2.RIGHT, Vector2(50, 65), 15.0), "bash hits targets within swing arc")
	check(not Combat.bash_in_arc(origin, Vector2.RIGHT, Vector2(-70, 0), 15.0), "bash does not hit behind MC")
	check(not Combat.bash_in_arc(origin, Vector2.RIGHT, Vector2(200, 0), 15.0), "bash has fixed melee range")
	check(Combat.bash_in_arc(origin, Vector2.UP, Vector2(0, -30), 8.0), "bash rotates with aim")
	var bomb = Combat.kaboomba_fuse(Vector2(55, 33), 26.0)
	check(bomb["fn"] == "kaboomba_boom", "bomber uses delayed detonation")
	check(bomb["t"] >= 0.7 and bomb["t"] <= 1.0, "fuse gives player time to escape")
	check(bomb["pos"] == Vector2(55, 33) and bomb["dmg"] == 26.0, "detonation keeps actual collision position/damage")
	check(bomb["tele"] == 85.0 and bomb["life"] == bomb["t"], "visible warning matches explosion radius and countdown")
	print("BASH / BOMBER TESTS: ", "PASS" if fails == 0 else str(fails) + " failures")
	quit(0 if fails == 0 else 1)
