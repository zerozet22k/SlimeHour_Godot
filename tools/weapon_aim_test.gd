extends SceneTree
## Regressions for visual barrel orientation, muzzle-origin accuracy,
## left/right mirroring, independent gun slots and ultrawide cursor.
const WeaponAim = preload("res://scripts/WeaponAim.gd")
const Weapons = preload("res://scripts/Weapons.gd")

var failed := 0
class FakeGame:
	extends RefCounted
	var hero = {"pos": Vector2.ZERO, "aim": Vector2.RIGHT}
	var settings = {"aim": "mouse"}
	var autotest = ""
	var aim_screen = Vector2(300, 240)
	func screen_to_world(p: Vector2) -> Vector2:
		return p
	func is_touch_active() -> bool:
		return false

func verify(value: bool, name: String) -> void:
	if value:
		print("PASS: " + name)
	else:
		failed += 1
		push_error("FAIL: " + name)

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var test_angles = [0.0, 0.7, 1.57, 2.5, PI, -2.5, -1.57, -0.7]
	for gun in WeaponAim.ART_ANGLE_DEG:
		for angle in test_angles:
			var direction = Vector2.from_angle(angle)
			var flip = WeaponAim.is_mirrored(direction)
			var rotation = WeaponAim.art_rotation(direction, str(gun))
			var actual = WeaponAim.barrel_axis(rotation, str(gun), flip)
			verify(actual.dot(direction) > 0.99999, str(gun) + " art aligns in direction " + str(angle))
	var fake = FakeGame.new()
	for slot in [0, 1, 2]:
		var origin = Weapons.muzzle_pos(fake, slot)
		var shot = Weapons.aim_for_slot(fake, slot)
		var distance = (fake.aim_screen - origin).length()
		verify(origin.distance_to(fake.aim_screen) > 8.0 and shot.dot((fake.aim_screen - origin).normalized()) > 0.999999, "cursor convergence for slot " + str(slot))
		verify(absf((fake.aim_screen - origin).cross(shot)) < 0.05, "muzzle shot intersects cursor for slot " + str(slot))
		verify(distance > 0.0, "muzzle origin is distinct from target")
	fake.hero["aim"] = Vector2.LEFT
	fake.aim_screen = Vector2(-380, -145)
	for slot in [0, 1]:
		var origin = Weapons.muzzle_pos(fake, slot)
		verify(Weapons.aim_for_slot(fake, slot).dot((fake.aim_screen - origin).normalized()) > 0.999999, "left-aim muzzle geometry " + str(slot))
	fake.settings["aim"] = "auto"
	verify(Weapons.aim_for_slot(fake, 0).is_equal_approx(Vector2.LEFT), "auto aim keeps its own target direction")
	var muzzle = Vector2(45, 20)
	var gun_dir = Vector2.LEFT.rotated(0.27)
	verify((WeaponAim.sprite_anchor(muzzle, gun_dir) + gun_dir * WeaponAim.SPRITE_TIP_DISTANCE).distance_to(muzzle) < 0.001, "sprite muzzle and shot origin share anchor")
	print("WEAPON AIM TESTS: " + ("PASS" if failed == 0 else str(failed) + " failed"))
	quit(1 if failed else 0)
