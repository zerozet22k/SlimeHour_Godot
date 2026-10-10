extends SceneTree
## Renders live boss fights (all three phases) to tools/art_review/boss_fights/.
## Needs a real window:  Godot --path . --script tools/boss_fight_preview.gd -- --boss=heli
## Omit --boss to capture every boss in sequence.

const BOSSES = ["chonkzilla", "heli", "necro", "kingblob", "coilqueen", "glassoracle", "voidweaver", "dreadengine"]
const SHOTS = [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]

var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			only = a.trim_prefix("--boss=")
	var out := ProjectSettings.globalize_path("res://tools/art_review/boss_fights")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings["sfx"] = 0.0
	game.settings["music"] = 0.0
	game.sfx.set_volumes(0.0, 0.0)
	for kind in (BOSSES if only == "" else [only]):
		await fight(kind, out)
	quit()

func fight(kind: String, out: String) -> void:
	game.start_run()
	game.debug_session = true
	game.debug_godmode = true
	game.autotest = "preview" # dodge-bot movement, no AutoTest driver
	game.sector = 5
	game.budget_spawned = game.sector_budget
	game.rush_done = true
	game.rush_queue = 0
	game.enemies.clear()
	game.boss_spawned = true
	game.boss_arena_on = true
	game.boss_arena_y = float(game.hero["pos"].y)
	var boss = game.spawn_enemy(kind, game.hero["pos"] + Vector2(0, -330), true)
	boss["cd"] = 1.0
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		if bool(boss.get("dead", false)):
			break
		# Phase 1 for the first third, then 2, then 3.
		var want := 1.0 if t < 5.0 else (0.5 if t < 10.0 else 0.2)
		if float(boss["hp"]) / float(boss["max_hp"]) > want:
			boss["hp"] = float(boss["max_hp"]) * want
		game.hero["hp"] = game.hero["maxhp"]
		if t >= SHOTS[shot]:
			await process_frame
			var img = root.get_texture().get_image()
			if img != null:
				img.save_png(out.path_join("%s_%02d.png" % [kind, shot]))
			shot += 1
	print("captured ", kind)
