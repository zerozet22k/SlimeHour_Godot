extends SceneTree
const Flow = preload("res://scripts/RouteFlow.gd")
const Main = preload("res://scripts/Main.gd")
const Hud = preload("res://scripts/Hud.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(not Flow.ready_after_clear(0.2, 0, 0), "cleared timer must finish")
	check(not Flow.ready_after_clear(-0.1, 1, 0), "pending level precedes boss result")
	check(not Flow.ready_after_clear(-0.1, 0, 1), "pending chest precedes boss result")
	check(Flow.ready_after_clear(-0.1, 0, 0), "ready after all rewards")
	check(Flow.requires_boss_result(true, 10, 20), "boss sector requires confirmation")
	check(not Flow.requires_boss_result(true, 20, 20), "victory already serves as a result")
	check(not Flow.requires_boss_result(false, 11, 20), "regular fights retain flow")
	check(Flow.TRAVEL_DURATION >= 1.1 and Flow.RESULT_MIN_WAIT >= 0.6, "visible transitions")
	for menu in ["map", "shop", "rest", "event", "travel", "boss_result"]:
		check(not Flow.should_play_combat_music(menu, "fight"), menu + " is silent")
	for overlay in ["levelup", "replace", "arsenal", "paused"]:
		check(not Flow.should_play_combat_music(overlay, "treasure"), overlay + " in hub is silent")
		check(Flow.should_play_combat_music(overlay, "fight"), overlay + " during fight retains music")
	check(not Flow.should_play_combat_music("playing", "cleared"), "music stops after clear")
	check(Flow.should_play_combat_music("playing", "fight"), "combat music still plays")
	check(Flow.is_hub_reward_context("treasure") and Flow.is_hub_reward_context("shop"), "reward UI uses route backdrop")
	check(not Flow.is_hub_reward_context("fight"), "combat reward retains battlefield")
	var instance = Main.new()
	check(instance.map_pick == -1 and instance.travel_t == 0.0, "transition starts inactive")
	instance.free()
	print("ROUTE FLOW TESTS: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures else 0)
