extends SceneTree
## Regression: only offer upgrades after a source exists, including weapon built-ins.
const Effects = preload("res://scripts/Effects.gd")

class FakeRun:
	extends RefCounted
	var owned: Dictionary = {}
	var card_by_id: Dictionary = {}
	var db_cards: Array = []
	var guns: Array = [{"id": "pistol", "lvl": 1}]
	var weapon_db: Dictionary = {}
	var gate_mods: Dictionary = {}
	func st(key: String) -> float:
		var value = 0.0
		for id in owned:
			if card_by_id.has(id):
				value += float(card_by_id[id].get("mods", {}).get(key, 0.0)) * int(owned[id])
		return value
	func card_available(_id: String) -> bool:
		return true

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g = FakeRun.new()
	var files = FileAccess.get_file_as_string("res://data/cards.json")
	var parsed: Dictionary = JSON.parse_string(files)
	g.db_cards = parsed["cards"]
	for c in g.db_cards:
		g.card_by_id[c["id"]] = c
	var weapon_data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	for w in weapon_data:
		g.weapon_db[w["id"]] = w

	# Startup must have meaningful unrestricted choices.
	for id in ["splinter", "shrapnel", "incendiary", "venom", "cryo_rounds", "taser_tips", "spinny_blade", "gun_drone"]:
		check(Effects.eligible(g, g.card_by_id[id]), id + " is a valid starter")
	for id in ["fractal", "razor_fragments", "bouncy_fragments", "hot_sauce", "neurotoxin", "high_voltage", "deep_freeze", "sharpened_steel", "rocket_drones", "aftershock", "wall_splatter"]:
		check(not Effects.eligible(g, g.card_by_id[id]), id + " blocked without prerequisite")
	check(not Effects.eligible(g, g.card_by_id["steam_engine"]), "steam requires both burn AND chill")
	check(not Effects.eligible(g, g.card_by_id["conductor"]), "conductor requires shock AND wet")

	g.owned["splinter"] = 1
	check(Effects.eligible(g, g.card_by_id["razor_fragments"]), "fragments unlock fragment damage")
	check(Effects.eligible(g, g.card_by_id["fractal"]), "fragments unlock fractal splitting")
	g.owned.erase("splinter")
	g.owned["popcorn"] = 1
	check(Effects.eligible(g, g.card_by_id["bouncy_fragments"]), "fragment-producing proc unlocks fragment mods")
	g.owned.erase("popcorn")
	g.guns = [{"id": "splitbow", "lvl": 1}]
	check(Effects.eligible(g, g.card_by_id["seeker_fragments"]), "splitbow generates fragments without a fragment card")
	g.guns = [{"id": "pistol", "lvl": 1}]

	g.owned["incendiary"] = 1
	check(Effects.eligible(g, g.card_by_id["hot_sauce"]), "burn source unlocks burn damage card")
	check(not Effects.eligible(g, g.card_by_id["thermal_shock"]), "burn alone does not unlock dual-element damage")
	g.owned["cryo_rounds"] = 1
	check(Effects.eligible(g, g.card_by_id["steam_engine"]), "burn and chill unlock steam")
	check(Effects.eligible(g, g.card_by_id["thermal_shock"]), "both elemental statuses unlock thermal shock")
	g.owned.clear()
	g.guns = [{"id": "flame", "lvl": 1}, {"id": "snow", "lvl": 1}]
	check(Effects.eligible(g, g.card_by_id["steam_engine"]), "native flame and snow gun statuses unlock combos")
	g.guns = [{"id": "pistol", "lvl": 1}]
	g.owned["taser_tips"] = 1
	check(not Effects.eligible(g, g.card_by_id["conductor"]), "shock without wet must not unlock conductor")
	g.owned["water_balloons"] = 1
	check(Effects.eligible(g, g.card_by_id["conductor"]), "shock and wet unlock conductor")
	g.owned.clear()
	g.owned["spinny_blade"] = 1
	check(Effects.eligible(g, g.card_by_id["sharpened_steel"]), "orbit source unlocks blade damage")
	g.owned.clear()
	g.owned["gun_drone"] = 1
	check(Effects.eligible(g, g.card_by_id["overclocked_drones"]), "drone source should allow existing req.stat if stat is recalculated")
	g.owned.clear()
	g.gate_mods = {"burn": 0.25, "bounce": 2}
	check(Effects.eligible(g, g.card_by_id["hot_sauce"]), "burn gate unlocks burn upgrade")
	check(Effects.eligible(g, g.card_by_id["wall_splatter"]), "wall bounce gate unlocks wall splatter")
	g.gate_mods.clear()
	g.owned["rubber_bullets"] = 1
	check(Effects.eligible(g, g.card_by_id["wall_splatter"]), "wall bounce card unlocks wall splatter")
	g.owned.clear()
	g.guns = [{"id": "rocket", "lvl": 1}]
	check(Effects.eligible(g, g.card_by_id["aftershock"]), "rocket gun supplies explosions")
	g.guns = [{"id": "pistol", "lvl": 1}]
	check(not Effects.eligible(g, g.card_by_id["aftershock"]), "no explosion source means no explosion modifier")

	# Every source requirement must be backed by at least one independent card.
	var all_sources: Dictionary = {}
	for c in g.db_cards:
		for source in c.get("req", {}).get("source", []):
			all_sources[str(source)] = true
	for source in all_sources:
		var providers := 0
		for c in g.db_cards:
			if c.get("req", {}).has("source"):
				continue
			if Effects.source_from_card(c, str(source)):
				providers += 1
		check(providers > 0, source + " source has a standalone card")
	print("PREREQUISITE TESTS: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(1 if failures > 0 else 0)
