extends SceneTree
## DUO status cards: each one actually does its combined effect.
##   Godot --headless --path . --script tools/duo_card_test.gd
const Combat = preload("res://scripts/Combat.gd")
const Effects = preload("res://scripts/Effects.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("DUO FAIL: " + label)

func _initialize() -> void:
	call_deferred("go")

func fresh(g) -> Dictionary:
	g.enemies.clear()
	var e = g.spawn_enemy("chonk", g.hero["pos"] + Vector2(0, -300), false, false)
	e["hp"] = 1e7
	e["max_hp"] = 1e7
	return e

func owning(g, id: String) -> void:
	g.owned.clear()
	g.owned_order.clear()
	Effects.add_card(g, id, true)
	Effects.recalc(g)

func go() -> void:
	var g = load("res://scenes/Main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.sfx.set_volumes(0.0, 0.0)
	g.start_run()
	var ids := ["combustion", "blood_boil", "scald", "cryo_toxin", "brittle_blood", "superconductor", "electrolysis", "septic_wounds", "blood_in_the_water", "arc_wound", "toxic_water"]
	for id in ids:
		check(g.card_by_id.has(id) and str(g.card_by_id[id]["desc"]).begins_with("DUO"), id + " exists and says DUO")
		check(Effects.card_themes(g.card_by_id[id]).has("status"), id + " is filed under STATUS & COMBOS")
	owning(g, "combustion")
	var e := fresh(g)
	for k in range(5):
		Combat.apply_status(g, e, "poison", 1.0)
	Combat.apply_status(g, e, "burn", 1.0)
	check(float(e["poison"]) == 0.0, "Combustion detonates the poison")
	owning(g, "scald")
	e = fresh(g)
	Combat.apply_status(g, e, "wet", 1.0)
	Combat.apply_status(g, e, "burn", 1.0)
	check(float(e["wet"]) == 0.0, "Scald boils the water off")
	owning(g, "brittle_blood")
	e = fresh(g)
	Combat.apply_status(g, e, "bleed", 1.0)
	Combat.apply_status(g, e, "freeze", 1.0)
	check(float(e["bleed"]) == 2.0, "Brittle Blood: chilling a bleeder adds a stack")
	owning(g, "septic_wounds")
	e = fresh(g)
	Combat.apply_status(g, e, "poison", 1.0)
	Combat.apply_status(g, e, "bleed", 1.0)
	check(float(e["poison"]) == 2.0 and float(e["bleed"]) == 1.0, "Septic Wounds: a cut also poisons")
	owning(g, "electrolysis")
	e = fresh(g)
	var other = g.spawn_enemy("blob", e["pos"] + Vector2(40, 0), false, false)
	other["hp"] = 1e7
	other["max_hp"] = 1e7
	# Neighbour lookups use the spatial grid, rebuilt each frame.
	Combat.build_grid(g)
	for k in range(6):
		Combat.apply_status(g, e, "poison", 1.0)
	Combat.apply_status(g, e, "shock", 1.0)
	check(float(other["poison"]) == 3.0, "Electrolysis arcs half the poison stacks to a neighbour")
	owning(g, "cryo_toxin")
	e = fresh(g)
	Combat.apply_status(g, e, "poison", 1.0)
	Combat.apply_status(g, e, "freeze", 1.0)
	check(is_equal_approx(float(e["chill"]), 34.0 * 1.5), "Cryo Toxin: poisoned enemies chill 50% faster")
	# Damage duos: compare a tick with and without the card.
	for pair in [["blood_boil", "bleed", "burn"], ["superconductor", "shock", "chill"], ["arc_wound", "shock", "bleed"], ["toxic_water", "poison", "wet"]]:
		g.owned.clear()
		Effects.recalc(g)
		e = fresh(g)
		e[str(pair[2])] = 50.0
		var base: float = Combat.status_tick_damage(g, e, str(pair[1]), 3.0)
		owning(g, str(pair[0]))
		var boosted: float = Combat.status_tick_damage(g, e, str(pair[1]), 3.0)
		check(boosted > base * 1.5, str(pair[0]) + " boosts " + str(pair[1]) + " damage")
	g.free()
	print("DUO CARDS: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures else 0)
