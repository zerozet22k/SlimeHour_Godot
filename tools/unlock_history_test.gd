extends SceneTree
const UnlockHistory = preload("res://scripts/UnlockHistory.gd")
const Main = preload("res://scripts/Main.gd")

var failures := 0
func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Old saves have no receipt fields: seed current unlocked content without
	# incorrectly presenting it all as a newly unlocked batch.
	var legacy = {"level": 7, "kills": 2500}
	var baseline = {"starter": true, "rare_a": true}
	check(UnlockHistory.backfill(legacy, baseline, ["pistol", "smg"]), "old save migrates")
	check(legacy["known_cards"].has("starter") and legacy["known_cards"].has("rare_a"), "preexisting cards are grandfathered")
	check(legacy["known_guns"].has("pistol"), "preexisting guns are grandfathered")
	check(not UnlockHistory.backfill(legacy, baseline, ["pistol", "smg"]), "idempotent migration")
	# A kill milestone while playing announces exactly one new card.
	var extended = baseline.duplicate()
	extended["new_fire"] = true
	var first = UnlockHistory.collect_new(legacy, baseline, extended, ["pistol", "smg"], ["pistol", "smg", "rail"])
	check(first.size() == 2, "one new card and gun reported once")
	check(first[0]["id"] == "new_fire" and first[1]["id"] == "rail", "precise unlock identities")
	var second = UnlockHistory.collect_new(legacy, baseline, extended, ["pistol", "smg"], ["pistol", "smg", "rail"])
	check(second.is_empty(), "repeated calculations do not reannounce")
	# Simulate leaving mid-run: saved receipts keep the items permanently even
	# if the old run's unbanked kills were not written to the profile.
	var disk_copy: Dictionary = JSON.parse_string(JSON.stringify(legacy))
	var restarted_baseline = baseline.duplicate()
	for id in disk_copy["known_cards"]:
		restarted_baseline[id] = true
	check(restarted_baseline.has("new_fire"), "unlocks survive mid-run restart")
	check(UnlockHistory.collect_new(disk_copy, restarted_baseline, restarted_baseline.duplicate(), ["pistol", "smg", "rail"], ["pistol", "smg", "rail"]).is_empty(), "no duplicate cards after restart")
	# Malformed/older receipt data must be normalized safely.
	check(UnlockHistory.normalized(["a", "b"]).size() == 2, "array histories migrate")
	check(not UnlockHistory.normalized({"a": false, "b": true}).has("a"), "false receipts are ignored")
	check(Main.GAME_VERSION.begins_with("v"), "version string exposed to UI")
	print("PERSISTENT UNLOCK HISTORY: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
