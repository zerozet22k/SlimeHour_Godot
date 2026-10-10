extends SceneTree
## Chonkzilla-specific encounter regression: no other bosses modified.
## Run: godot --headless --path . --script tools/chonkzilla_encounter_test.gd
const Main = preload("res://scripts/Main.gd")
const Combat = preload("res://scripts/Combat.gd")
const Chonkzilla = preload("res://scripts/ChonkzillaEncounter.gd")

class SilentSfx:
	extends RefCounted
	func play(_name: String) -> void:
		pass
	func play_projectile(_name: String, _style: String = "", _weapon: String = "", _volume: float = 1.0) -> void:
		pass

var failures := 0
func check(ok: bool, title: String) -> void:
	if ok:
		print("PASS: ", title)
	else:
		failures += 1
		push_error("CHONKZILLA: " + title)

func make_chonk(g, hp_fraction: float = 1.0) -> Dictionary:
	var boss = g.spawn_enemy("chonkzilla", Vector2(0.0, -360.0), true)
	boss["max_hp"] = 2000.0
	boss["hp"] = 2000.0 * hp_fraction
	boss["cd"] = 0.0
	boss["t"] = 5.0
	return boss

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Main.new()
	g.no_save = true
	g.sfx = SilentSfx.new()
	g.state = "playing"
	g.sector = 5
	g.road_half = 490.0
	g.hero = {"pos": Vector2(100, 0), "vel": Vector2(100, 0), "push": Vector2.ZERO,
		"hp": 999.0, "maxhp": 999.0, "shield": 0, "dash_window": 0.0, "iframe": 0.0}
	for mob in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		g.enemy_db[str(mob["id"])] = mob

	var boss = make_chonk(g)
	Combat.ai(g, boss, Vector2.DOWN, 380.0, 0.016, false)
	check(str(boss.get("chonk_state", "")) == "windup", "Dedicated FSM begins a readable rush windup")
	var lock: Vector2 = boss["lock"]
	g.hero["pos"] = Vector2(-320, 20)
	Combat.ai(g, boss, Vector2.DOWN, 380.0, 1.0, false)
	check(str(boss.get("chonk_state", "")) == "rush" and boss["lock"] == lock,
		"Chonkzilla commits to the original target rather than cheating by tracking after warning")
	check(float(boss.get("chonk_speed", 0.0)) > 450.0, "Physical body charge is much faster than ordinary pursuit")

	g.hero["pos"] = Vector2(100, 0)
	boss["stone_t"] = 0.0
	Chonkzilla.setpiece(g, boss, 0, 0.02)
	var anchors = Chonkzilla.stones(g, boss)
	check(anchors.size() == 1 and float(anchors[0]["hp"]) > 0.0, "The setpiece creates one damageable rock")
	# Repeated calls and phase-2 double placements cannot exceed its prop budget.
	for i in range(10):
		boss["stone_t"] = 0.0
		Chonkzilla.setpiece(g, boss, 2, 0.03)
	check(Chonkzilla.stones(g, boss).size() <= Chonkzilla.STONE_LIMIT, "Persistent obstacles never exceed the cap")

	# The boss takes real damage if the player baits a committed rush into stone.
	var hit_rock = Chonkzilla.stones(g, boss)[0]
	boss["chonk_state"] = "rush"
	boss["chonk_charge_t"] = 0.7
	boss["chonk_dir"] = Vector2.DOWN
	boss["pos"] = hit_rock["pos"] + Vector2(0.0, -12.0)
	var hp_before: float = float(boss["hp"])
	Chonkzilla.after_motion(g, boss, hit_rock["pos"] + Vector2(0.0, -120.0))
	check(bool(hit_rock["dead"]) and str(boss["chonk_state"]) == "stagger", "Stones can actually stop the boss")
	check(float(boss.get("boss_recover", 0.0)) >= 2.0 and float(boss["hp"]) < hp_before,
		"Successful environment bait gives meaningful armor break and damage")
	check(Combat.boss_identity_damage_factor(g, boss) > 1.9, "The armor break increases incoming damage")
	var fault_count = g.delayed.filter(func(d): return str(d.get("fn", "")) == "chonk_fault").size()
	check(fault_count >= 2 and fault_count <= 3, "Rush collision creates a small network of persistent faults")
	var old_hp = float(g.hero["hp"])
	g.hero["pos"] = Vector2(-440.0, 900.0)
	Combat.update_delayed(g, 1.0)
	check(is_equal_approx(float(g.hero["hp"]), old_hp), "Seismic faults never damage the distant player")
	check(g.delayed.filter(func(d): return str(d.get("fn", "")) == "chonk_fault").size() <= 3,
		"Repeated pulses do not multiply hazard objects")

	# Different states, not simply shorter cooldowns, are unlocked at low HP.
	var phase_two = make_chonk(g, 0.50)
	Combat.ai(g, phase_two, Vector2.DOWN, 320.0, 0.016, false)
	check(int(phase_two.get("chonk_combo", -1)) == 1, "Phase 2 unlocks a follow-up charge")
	var phase_three = make_chonk(g, 0.20)
	Combat.ai(g, phase_three, Vector2.DOWN, 320.0, 0.016, false)
	check(int(phase_three.get("chonk_combo", -1)) == 2, "Phase 3 unlocks a three-charge assault")
	phase_three["chonk_state"] = "rush"
	phase_three["chonk_charge_t"] = 0.0
	phase_three["chonk_dir"] = Vector2.DOWN
	Chonkzilla.after_motion(g, phase_three, phase_three["pos"])
	check(str(phase_three.get("chonk_state", "")) == "recover", "Missed rush transitions to recovery")
	phase_three["chonk_recover_t"] = 0.01
	Combat.ai(g, phase_three, Vector2.DOWN, 320.0, 0.15, false)
	check(str(phase_three.get("chonk_state", "")) == "windup" and int(phase_three["chonk_combo"]) == 1,
		"Phase 3 chains into a newly telegraphed second attack")

	var visuals: String = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	check(visuals.contains('"chonk_fault"') and visuals.contains('"chonk_pillar"')
		and visuals.contains("CHARGE - MOVE SIDEWAYS"), "Actual rock hitboxes, fault pulses, and rush direction are visible")
	g.free()
	print("CHONKZILLA ENCOUNTER TEST: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
