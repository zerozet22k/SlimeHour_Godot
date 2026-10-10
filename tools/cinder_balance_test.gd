extends SceneTree
## Protect Cinder's small v0.1.47 damage adjustment without changing its
## short-range flame identity or the other 21 weapon definitions.
const Weapons = preload("res://scripts/Weapons.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	check(roster is Array and roster.size() == 22, "Roster preserves all 22 weapons")
	var by_id: Dictionary = {}
	for weapon in roster:
		by_id[str(weapon["id"])] = weapon
	check(by_id.size() == 22, "Weapon IDs remain distinct")
	var cinder: Dictionary = by_id.get("flame", {})
	var hydra: Dictionary = by_id.get("splitbow", {})
	var frost: Dictionary = by_id.get("snow", {})
	check(is_equal_approx(float(cinder.get("dmg", 0.0)), 3.6), "Cinder direct tick reduced 10 percent")
	check(is_equal_approx(float(cinder.get("rate", 0.0)), 30.0), "Cinder fire cadence unchanged")
	check(int(cinder.get("mag", 0)) == 110 and is_equal_approx(float(cinder.get("reload", 0.0)), 2.0), "Cinder fuel and reload unchanged")
	check(Weapons.CINDER_MAX_TARGETS == 20, "Cinder capped at 20 simultaneous target hits")
	var raw_dps = float(cinder.get("dmg", 0.0)) * float(cinder.get("rate", 0.0))
	var shoot_time = float(cinder.get("mag", 0)) / float(cinder.get("rate", 1.0))
	var averaged_dps = raw_dps * shoot_time / (shoot_time + float(cinder.get("reload", 0.0)))
	check(is_equal_approx(raw_dps, 108.0), "Cinder ideal direct firing DPS is 108")
	check(absf(averaged_dps - 69.88) < 0.06, "Cinder base sustained direct DPS is approximately 69.9")
	check(float(hydra.get("dmg", 0.0)) == 30.0 and str(hydra.get("kind", "")) == "bolt", "Hydra Bow damage and nature unchanged")
	check(float(frost.get("dmg", 0.0)) == 18.0, "Frostcaster damage remains unchanged")
	var source = FileAccess.get_file_as_string("res://scripts/Weapons.gd")
	check(source.contains("if hits >= CINDER_MAX_TARGETS:"), "Flame cone uses capped hit count")
	check(source.contains("fire_flame(g, w, pos, dir, dmg)"), "Continuous flame uses its native no-projectile attack")
	check(source.contains("\"burn\": 1.0") and source.contains("flame_visuals("), "Cinder retains fire status and flowing VFX")
	print("CINDER BALANCE REGRESSIONS: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
