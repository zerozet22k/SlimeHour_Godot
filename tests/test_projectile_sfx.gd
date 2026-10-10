extends SceneTree
## Run: godot --headless --path . --script res://tests/test_projectile_sfx.gd

const SfxScript = preload("res://scripts/Sfx.gd")

func _initialize() -> void:
	var sfx = SfxScript.new()
	sfx.build_all()
	# Every style and meaningful game event must resolve to a baked playable clip.
	var cases = [
		["fire", "kinetic", ""], ["fire", "kinetic", "double_tap"],
		["fire", "kinetic", "parallel"], ["fire", "kinetic", "burst"],
		["fire", "rapid", ""], ["fire", "heavy", ""], ["fire", "shotgun", ""],
		["fire", "laser", ""], ["fire", "rail", ""], ["fire", "fire", ""],
		["fire", "toxic", ""], ["fire", "frost", ""], ["fire", "shock", ""],
		["fire", "blast", ""], ["fire", "water", ""],
		["impact", "kinetic", ""], ["impact", "heavy", ""], ["impact", "pierce", ""],
		["impact", "fire", ""], ["impact", "toxic", ""],
		["impact", "frost", ""], ["impact", "shock", ""],
		["status", "fire", ""], ["status", "toxic", ""],
		["status", "frost", ""], ["status", "shock", ""],
		["crit", "kinetic", ""], ["bounce", "kinetic", ""],
		["pierce", "pierce", ""], ["split", "shard", ""],
		["boss_fire", "boss_void", ""], ["boss_fire", "boss_storm", ""],
		["boss_warn", "", ""], ["boss_impact", "", ""],
		["barrel_warn", "", ""], ["barrel_boom", "", ""],
		["rail_charge", "", ""],
	]
	for item in cases:
		var name = SfxScript.projectile_clip(item[0], item[1], item[2])
		assert(name != "", "Missing projectile mapping: %s" % str(item))
		assert(sfx.streams.has(name), "Missing audio sample: %s" % name)
		var audio: AudioStreamWAV = sfx.streams[name]
		assert(audio.data.size() > 100, "Empty audio sample: %s" % name)
	assert(SfxScript.projectile_clip("fire", "kinetic", "double_tap") != SfxScript.projectile_clip("fire", "kinetic", "parallel"))
	assert(sfx.streams["vfx_double"].data.size() > sfx.streams["vfx_pea"].data.size())
	assert(sfx.players.size() == 0) # constructing the bank doesn't spawn a voice
	sfx.free()
	print("Projectile SFX smoke tests passed: %d mapped cases" % cases.size())
	quit(0)
