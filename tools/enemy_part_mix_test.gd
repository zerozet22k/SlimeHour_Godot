extends SceneTree
## Run: godot --headless --path . --script res://tools/enemy_part_mix_test.gd
## Validate late-stage mutations are body PARTS, not whole faces pasted together.
const Mixes = preload("res://scripts/EnemyMixes.gd")
const Main = preload("res://scripts/Main.gd")
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
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	check(raw is Array and raw.size() >= 24, "All modern main monster archetypes remain available")
	var db = {}
	for monster in raw:
		db[str(monster["id"])] = monster
	check(not db.has("nurse") and not db.has("larry"), "Retired Nurse and Laser Larry are removed from the actual roster")
	check(not Mixes.usable("nurse") and not Mixes.usable("larry"), "Retired enemies never qualify for new hybrids")
	check(not Mixes.usable("mix_larry_nurse") and not Mixes.usable("mix_blob_nurse"),
		"Historical Nurse/Larry hybrids are excluded from restores and Bestiary")
	check(not Mixes.allowed(["blob", "bull"], 15) and Mixes.allowed(["blob", "bull"], 16),
		"New main archetypes are introduced before mixtures can spawn")
	check(Mixes.ensure(db, "blob", "nurse") == "" and Mixes.ensure(db, "larry", "bull") == "",
		"Retired parents are never created even by explicit ensure calls")

	var basics = []
	for id in Main.STARTER_ENEMIES:
		basics.append(str(id))
	for id in Main.ROUTE_INTRO_ORDER:
		basics.append(str(id))
	check(basics.size() == 21, "Twenty-one original combat main types remain with no retired faces")
	var seen_traits = {}
	var created = 0
	for i in range(basics.size()):
		for j in range(i + 1, basics.size()):
			var id = Mixes.ensure(db, basics[i], basics[j])
			if id == "":
				continue
			created += 1
			var mixed = db[id]
			var parents: Array = mixed["mix"]
			var look: Dictionary = mixed["look"]
			var base: Dictionary = db[str(parents[0])].get("look", {})
			check(look.has("trait") and str(look["trait"]) in Mixes.traits_for(str(parents[1])),
				"Hybrid inherits one part from second parent: " + id)
			check(str(look.get("face", "")) == str(base.get("face", "normal")),
				"Hybrid never replaces primary face: " + id)
			check(look.get("gear", []) == base.get("gear", []),
				"Hybrid does not stack second face/cap/visor: " + id)
			seen_traits[str(look["trait"])] = true
	check(created == 210, "All 210 distinct base-type pairings can be generated")
	check(seen_traits.size() >= 12, "Pairs produce many visually distinct anatomical mutations")
	check(Mixes.id_for("blob", "bull") == Mixes.id_for("bull", "blob"), "Pair IDs are canonical")

	var visual = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	var hud = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	var main = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var autotest = FileAccess.get_file_as_string("res://scripts/AutoTest.gd")
	check(visual.contains("draw_hybrid_trait") and not visual.contains("Organic split horns and offset eyes"),
		"Gameplay uses inherited body part renderer, not generic pasted monster overlays")
	check(hud.contains("v.draw_hybrid_trait(self"), "Bestiary previews render the inherited part")
	check(main.contains('for key in ["mobs", "announced_mobs"]') and main.contains("records.erase(known)"),
		"Old save bestiary and announcement records are migrated")
	check(not autotest.contains('"nurse"') and not autotest.contains('"larry"'),
		"Automated high-level mob spawning does not reintroduce retired enemies")

	var r = Mixes.roll(db, basics, 40)
	check(r != "" and r.begins_with("mix_") and db.has(r), "Sector 40 generates modern combinations")
	print("ENEMY PART MIX TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
