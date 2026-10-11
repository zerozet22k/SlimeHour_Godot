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
	check(db.has("nurse") and db.has("larry"), "Medic and Laser Larry are active base monsters")
	check(Mixes.usable("nurse") and Mixes.usable("larry"), "Medic and Laser Larry are eligible mutation parents")
	check(Mixes.usable("mix_larry_nurse") and Mixes.usable("mix_blob_nurse"),
		"Old Medic/Larry hybrid records stay compatible with player saves")
	check(not Mixes.allowed(["blob", "bull"], 15) and Mixes.allowed(["blob", "bull"], 16),
		"New main archetypes are introduced before mixtures can spawn")
	check(Mixes.ensure(db, "blob", "nurse") != "" and Mixes.ensure(db, "larry", "bull") != "",
		"Medic and Larry can both contribute a single anatomical hybrid feature")

	var basics = []
	for id in Main.STARTER_ENEMIES:
		basics.append(str(id))
	basics.append("nurse")
	for id in Main.ROUTE_INTRO_ORDER:
		basics.append(str(id))
	check(basics.size() == 23, "Twenty-three core combat types including Medic and Larry")
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
	check(created == 253, "All 253 distinct non-boss core-type pairings can be generated")
	check(seen_traits.size() >= 12, "Pairs produce many visually distinct anatomical mutations")
	check(Mixes.id_for("blob", "bull") == Mixes.id_for("bull", "blob"), "Pair IDs are canonical")

	var visual = FileAccess.get_file_as_string("res://scripts/Visuals.gd")
	var hud = FileAccess.get_file_as_string("res://scripts/Hud.gd")
	var main = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var autotest = FileAccess.get_file_as_string("res://scripts/AutoTest.gd")
	check(visual.contains("draw_hybrid_trait") and not visual.contains("Organic split horns and offset eyes"),
		"Gameplay uses inherited body part renderer, not generic pasted monster overlays")
	check(hud.contains("v.MutationParts.draw_received(self") and visual.contains("MutationParts.draw_received(self"), "Game and Bestiary plug the giver's part into the body's slot")
	check(main.contains('for key in ["mobs", "announced_mobs"]') and main.contains("records.erase(known)"),
		"Old save bestiary and announcement records are migrated")
	check(not autotest.contains('"nurse"') and not autotest.contains('"larry"'),
		"Automated mob roster requires explicit species definitions")

	var r = Mixes.roll(db, basics, 40)
	check(r != "" and r.begins_with("mix_") and db.has(r), "Sector 40 generates modern combinations")
	print("ENEMY PART MIX TESTS: ", "PASS" if failures == 0 else str(failures) + " failure(s)")
	quit(1 if failures > 0 else 0)
