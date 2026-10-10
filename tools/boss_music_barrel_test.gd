extends SceneTree
## Regression: delayed barrel chain reactions, boss health phases, soundtrack variety.
const Combat = preload("res://scripts/Combat.gd")
const Sfx = preload("res://scripts/Sfx.gd")
var errors := 0
func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		errors += 1
		push_error("FAIL: " + description)

class MockBoss:
	extends RefCounted
	var delayed: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var barrel = {"hp": 0.0, "armed": false, "fuse": 0.0}
	Combat.barrel_arm(barrel)
	check(barrel["armed"] and is_equal_approx(float(barrel["fuse"]), 0.85), "barrel visibly arms, not an instant blast")
	check(not Combat.barrel_countdown(barrel, 0.5), "barrel survives half-second for dodge")
	check(not Combat.barrel_countdown(barrel, 0.30), "barrel survives until fuse finishes")
	check(Combat.barrel_countdown(barrel, 0.06), "barrel detonates when fuse finishes")
	var boss = {"boss": true, "hp": 100.0, "max_hp": 100.0}
	check(Combat.boss_stage(boss) == 0, "boss opens in stage 0")
	boss["hp"] = 64.0
	check(Combat.boss_stage(boss) == 1, "boss second patterns unlock at 65 percent HP")
	boss["hp"] = 31.0
	check(Combat.boss_stage(boss) == 2, "boss rage patterns unlock at 32 percent HP")
	var fake = MockBoss.new()
	Combat.schedule_boss_blast(fake, Vector2(4, 12), 55.0, 15.0, 0.9)
	check(fake.delayed.size() == 1, "boss attacks are registered as delayed telegraphs")
	check(fake.delayed[0]["fn"] == "boss_blast" and fake.delayed[0]["tele"] == 55.0, "boss warning radius matches attack")
	var audio = Sfx.new()
	var neon = audio.song_stream("neon")
	var frost = audio.song_stream("frost")
	var boss_track = audio.song_stream("boss")
	var panic = audio.song_stream("pressure")
	check(neon.data.size() > 200000, "neon music has a substantial composed loop")
	check(frost.data.size() == neon.data.size(), "world themes share a transition-safe length")
	check(boss_track.data.size() == neon.data.size(), "boss theme has aligned bar length")
	check(panic.data.size() == neon.data.size(), "danger percussion stays tempo synced")
	check(neon.data != frost.data and neon.data != boss_track.data, "biome and boss songs are distinct")
	audio.free()
	check(ResourceLoader.exists("res://assets/ui/chest.svg"), "new treasure chest graphic imports")
	check(ResourceLoader.exists("res://assets/ui/barrel.svg"), "new fuse barrel graphic imports")
	print("BOSS / MUSIC / BARREL: ", "PASS" if errors == 0 else str(errors) + " failures")
	quit(1 if errors > 0 else 0)
