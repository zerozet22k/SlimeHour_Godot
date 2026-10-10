extends SceneTree
## Run: godot --headless --path . --script res://tests/test_projectile_vfx.gd
const Vfx = preload("res://scripts/ProjectileVfx.gd")

class FakeWorld:
	extends Node2D
	var settings = {"particles": true, "vfx_quality": "medium"}
	var fx: Array = []
	var sim_step = 0
	func on_screen(_pos: Vector2, _margin: float = 60.0) -> bool:
		return true

func _initialize() -> void:
	var world = FakeWorld.new()
	assert(Vfx.style_for("bullet", "pistol") == "kinetic")
	assert(Vfx.style_for("bullet", "pistol", {"burn": 1.0}) == "fire")
	assert(Vfx.style_for("bullet", "pistol", {"poison": 1.0}) == "toxic")
	assert(Vfx.style_for("bullet", "pistol", {"freeze": 1.0}) == "frost")
	assert(Vfx.style_for("bullet", "pistol", {"shock": 1.0}) == "shock")
	assert(Vfx.style_for("rocket", "rocket") == "blast")
	assert(Vfx.style_for("frag", "splitbow") == "shard")
	assert(Vfx.tint("boss_void") != Vfx.tint("boss_ember"))
	Vfx.pattern(world, Vector2.ZERO, Vector2.RIGHT, "kinetic", "parallel")
	assert(world.fx.size() == 1)
	assert(world.fx[0]["event"] == "parallel")
	Vfx.pattern(world, Vector2.ZERO, Vector2.RIGHT, "kinetic", "double_tap")
	assert(world.fx.size() == 2)
	Vfx.critical(world, Vector2.ZERO, Vector2.RIGHT)
	assert(world.fx.back()["event"] == "crit")
	Vfx.pierce(world, Vector2.ZERO, Vector2.RIGHT, "pierce")
	Vfx.split(world, Vector2.ZERO, Vector2.RIGHT, "shard")
	Vfx.ricochet(world, Vector2.ZERO, Vector2.RIGHT, "ricochet")
	assert(world.fx.size() == 6)
	world.settings["particles"] = false
	var previous = world.fx.size()
	Vfx.pattern(world, Vector2.ZERO, Vector2.RIGHT, "kinetic", "parallel")
	Vfx.expire(world, Vector2.ZERO, Vector2.RIGHT, "kinetic")
	assert(world.fx.size() == previous)
	Vfx.impact(world, Vector2.ZERO, Vector2.RIGHT, "kinetic")
	assert(world.fx.size() == previous + 1)
	world.fx.clear()
	world.settings["particles"] = true
	world.settings["vfx_quality"] = "low"
	for i in range(300):
		Vfx.impact(world, Vector2.ZERO, Vector2.RIGHT, "kinetic")
	assert(world.fx.size() <= 190)
	print("Projectile VFX smoke tests passed.")
	quit(0)
