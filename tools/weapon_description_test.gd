extends SceneTree
## Weapon copy regression: every gun must explain its base identity and all
## three upgrade tiers. No gameplay/balance change is part of this patch.
const Weapons = preload("res://scripts/Weapons.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	check(roster is Array and roster.size() == 22, "All 22 guns still defined")
	if not (roster is Array):
		quit(1)
		return
	var found: Dictionary = {}
	for w in roster:
		var id = str(w.get("id", ""))
		check(not found.has(id), id + ": no duplicated gun IDs")
		found[id] = true
		var desc = str(w.get("desc", ""))
		var lv3 = str(w.get("lv3", ""))
		var lv5 = str(w.get("lv5", ""))
		var brief = str(w.get("lv5_brief", ""))
		var evo = Weapons.evolution_description({"id": id})
		check(desc.length() >= 40 and desc.length() <= 128, id + ": meaningful and concise base effect")
		check(lv3.length() >= 15 and lv3.length() <= 75, id + ": level 3 summary fits UI")
		check(lv5.contains(" — ") and lv5.length() < 126, id + ": named level 5 signature")
		check(brief.length() >= 18 and brief.length() <= 48, id + ": compact Arsenal level 5")
		check(evo.contains(" — ") and evo.length() < 139, id + ": detailed Evolution card")
	check(found.size() == 22 and Weapons.EVOLUTION_DESCRIPTIONS.size() == 22, "All 22 guns have upgrade descriptions")
	var ui = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	check(ui.contains("lv5_brief"), "Arsenal reads compact level-five text")
	check(ui.contains("Weapons.evolution_description({\"id\": gun[\"id\"]})"), "Collection displays Evolution notes")
	check(ui.contains("weapon_offer"), "Weapon offers reserve sufficient space for descriptions")
	print("WEAPON DESCRIPTION TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
