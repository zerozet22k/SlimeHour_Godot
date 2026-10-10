extends SceneTree
## Source-level gameplay VFX/early-sector tuning and persistent unlocking regression.
const Main = preload("res://scripts/Main.gd")
const RouteFlow = preload("res://scripts/RouteFlow.gd")
const Vfx = preload("res://scripts/ProjectileVfx.gd")
var failed := 0

class Dummy:
	extends Node2D
	var fx: Array = []
	var settings = {"particles": true}
	var sim_step = 3

	func on_screen(_pos: Vector2, _margin: float = 0.0) -> bool:
		return true

func check(condition: bool, message: String) -> void:
	if not condition:
		failed += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var types = {
		"pistol": "kinetic", "smg": "rapid", "shotgun": "heavy",
		"sniper": "pierce", "rocket": "blast", "splitbow": "shard",
		"tesla": "shock", "flame": "fire", "snow": "frost",
		"bees": "toxic", "pinball": "ricochet"
	}
	for gun_id in types:
		check(Vfx.style_for("bullet", str(gun_id)) == str(types[gun_id]), "Distinct VFX: " + str(gun_id))
	check(Vfx.style_for("frag", "") == "shard", "Fragments use shard effects")
	check(Vfx.style_for("enemy", "") == "enemy", "Enemy bullet style differs")
	check(Vfx.style_for("bullet", "", {"burn": 1}) == "fire", "Elemental burn projectile style")
	var dummy = Dummy.new()
	Vfx.muzzle(dummy, Vector2.ZERO, Vector2.RIGHT, "kinetic", 6.0)
	Vfx.impact(dummy, Vector2(15, 0), Vector2.RIGHT, "frost")
	Vfx.ricochet(dummy, Vector2(20, 0), Vector2.UP, "ricochet")
	check(dummy.fx.size() == 3, "Muzzle, impact and ricochet all emit")
	check(str(dummy.fx[1]["kind"]) == "projectile_vfx", "Fx uses the bounded shared renderer")
	dummy.settings["particles"] = false
	var count_before = dummy.fx.size()
	Vfx.muzzle(dummy, Vector2.ZERO, Vector2.RIGHT, "kinetic", 6)
	check(dummy.fx.size() == count_before, "Particles-off removes optional muzzle effects")
	Vfx.impact(dummy, Vector2.ZERO, Vector2.UP, "toxic")
	check(dummy.fx.size() == count_before + 1, "Critical impact marker remains accessible")
	dummy.free()
	var game = Main.new()
	var prev = 0.0
	for sector in range(1, 13):
		game.sector = sector
		var hp = game.enemy_scale()
		check(hp > prev, "Sector %d HP scales progressively" % sector)
		prev = hp
	game.sector = 8
	check(game.enemy_scale() < 2.3 and game.enemy_scale() > 1.9, "Sector 8 eases into midgame")
	check(game.crowd_ramp(8) < 1.12, "Sector 8 crowd slightly softened")
	check(game.crowd_ramp(13) >= game.crowd_ramp(11), "Late crowd scaling resumes")
	check(RouteFlow.should_play_route_music("map", "map"), "Route music persists on map")
	check(RouteFlow.should_play_route_music("shop", "shop"), "Shop retains quiet biome music")
	check(RouteFlow.should_play_route_music("levelup", "treasure"), "Treasure selection retains ambience")
	check(not RouteFlow.should_play_route_music("playing", "fight"), "Gameplay stays in combat mix")
	check(not RouteFlow.should_play_route_music("menu", "fight"), "Main menu never plays route music")
	check(game.profile.has("announced_mobs"), "Unlocked monster notifications track persistent history")
	game.free()
	print("VFX / BALANCE / MUSIC / UNLOCK TESTS: ", "PASS" if failed == 0 else str(failed) + " failed")
	quit(1 if failed > 0 else 0)
