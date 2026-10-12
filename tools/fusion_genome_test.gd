extends SceneTree
## Verify reusable donor modules without handwritten pair combat rules.
const Genome = preload("res://scripts/FusionGenome.gd")
const Mixes = preload("res://scripts/EnemyMixes.gd")
const Main = preload("res://scripts/Main.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var db: Dictionary = {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var species: Array = []
	for rec in raw:
		db[str(rec["id"])] = rec
		if not bool(rec.get("boss", false)):
			species.append(str(rec["id"]))
	check(species.size() == 25, "All normal monster species retain a kit")
	check(Genome.schema().get("donors", {}).size() == species.size(), "Every monster exports a donor module")
	var traits: Dictionary = {}
	var combinations := 0
	for body in species:
		check(not Genome.body_caps(str(body)).is_empty(), "Receiver capabilities: " + str(body))
		var own: Dictionary = Genome.donor_spec(str(body))
		check(not own.is_empty() and int(own.get("cost", 0)) >= 2, "Bounded donor kit: " + str(body))
		traits[str(own.get("module", ""))] = true
		for donor in species:
			if body == donor:
				continue
			if not Genome.compatible(str(body), str(donor)):
				check(Mixes.ensure(db, str(body), str(donor)) == "", "Incompatible graft rejected")
				continue
			var id := Mixes.ensure(db, str(body), str(donor))
			check(id != "" and str(db[id].get("graft", "")) == str(Genome.donor_spec(str(donor)).get("module", "")),
				"Correct graft on " + id)
			check(is_equal_approx(float(db[id]["dmg"]), float(db[str(body)]["dmg"]) * 1.10),
				"Body parent retains its attack foundation")
			combinations += 1
	var ward_lancer: String = Mixes.ensure(db, "totem", "lancer")
	check(ward_lancer != "" and is_zero_approx(float(db[ward_lancer]["dmg"]))
		and float(db[ward_lancer].get("graft_dmg", 0.0)) > 0.0,
		"Totem stays non-contact while its inherited piercing attack deals damage")
	var thief_mortar: String = Mixes.ensure(db, "goblin", "mortar")
	check(thief_mortar != "" and is_zero_approx(float(db[thief_mortar]["dmg"]))
		and float(db[thief_mortar].get("graft_dmg", 0.0)) > 0.0,
		"Goblin keeps zero contact damage but can inherit an actual artillery attack")
	check(traits.size() == 25, "Distinct donor kits; Zoomer, Mini and Skitter no longer share rush")
	check(combinations >= 450 and combinations < 600, "Most ordered combinations work without pair-specific branches")
	var g = Main.new()
	g.no_save = true
	g.enemy_db = db
	g.hero = {"pos": Vector2.ZERO}
	var triggers := 0
	for donor in species:
		var body := "blob" if Genome.compatible("blob", str(donor)) and str(donor) != "blob" else "lancer"
		if body == str(donor) or not Genome.compatible(body, str(donor)):
			continue
		var id := Mixes.ensure(g.enemy_db, body, str(donor))
		var e := {"id": triggers + 1, "kind": id, "mut_of": id, "pos": Vector2(100, 50), "r": 18.0,
			"dmg": 10.0, "hp": 40.0, "max_hp": 40.0, "dead": false, "graft_cd": 0.0}
		g.delayed.clear()
		Genome.cast(g, e)
		var module: String = str(Genome.donor_spec(str(donor)).get("module", ""))
		if module in ["phoenix_egg", "reflect_shot"]:
			check(g.delayed.is_empty(), "Reactive graft " + module + " has no fake timed attack")
		else:
			check(g.delayed.size() == 1 and str(g.delayed[0].get("module", "")) == module,
				"One triggered graft event for " + module)
		triggers += 1
	check(triggers == 25, "All 25 donor kits have a compatible test carrier")
	# Spitter donor paints one real line hazard; it must not regress to
	# three disconnected circular poison patches.
	var acid_id := Mixes.ensure(g.enemy_db, "lancer", "spitter")
	var acid_e := {"id": 99, "kind": acid_id, "mut_of": acid_id, "pos": Vector2(100, 50),
		"r": 18.0, "dmg": 10.0, "dead": false}
	g.enemy_hazards.clear()
	Genome.resolve(g, {"src_enemy": acid_e, "module":"acid_track", "color":"9aff77"})
	check(g.enemy_hazards.size() == 1 and str(g.enemy_hazards[0].get("kind", "")) == "acid_trail"
		and g.enemy_hazards[0].has("a") and g.enemy_hazards[0].has("b"),
		"Spitter inheritance is one continuous ribbon-shaped hazard")
	g.free()
	print("FUSION GENOME: ", "PASS" if failures == 0 else str(failures) + " failures",
		" / ", combinations, " valid directed pairings")
	quit(1 if failures else 0)
