extends RefCounted
## Permanent unlock receipts. Progression can advance during a run, before
## end-of-run kill/XP totals are saved. Never let already-awarded unlocks be
## shown again after restart or forgotten when the run is exited early.

static func normalized(data: Variant) -> Dictionary:
	var ids: Dictionary = {}
	if data is Dictionary:
		for id in data.keys():
			if bool(data[id]):
				ids[str(id)] = true
	elif data is Array:
		for id in data:
			ids[str(id)] = true
	return ids

static func backfill(profile: Dictionary, available_cards: Dictionary, available_guns: Array) -> bool:
	var cards = normalized(profile.get("known_cards", {}))
	var guns = normalized(profile.get("known_guns", {}))
	var changed = not profile.has("known_cards") or not profile.has("known_guns")
	# First boot / migration: old saves already unlocked some content via XP and
	# lifetime kills; treat those as received silently, without 110 NEW popups.
	for id in available_cards:
		if not cards.has(str(id)):
			cards[str(id)] = true
			changed = true
	for id in available_guns:
		if not guns.has(str(id)):
			guns[str(id)] = true
			changed = true
	profile["known_cards"] = cards
	profile["known_guns"] = guns
	return changed

static func collect_new(profile: Dictionary, before_cards: Dictionary, after_cards: Dictionary, before_guns: Array, after_guns: Array) -> Array:
	var already_cards = normalized(profile.get("known_cards", {}))
	var already_guns = normalized(profile.get("known_guns", {}))
	var unlocked: Array = []
	for id in after_cards:
		var key = str(id)
		if not before_cards.has(key) and not already_cards.has(key):
			already_cards[key] = true
			unlocked.append({"type": "card", "id": key})
	for id in after_guns:
		var key = str(id)
		if not before_guns.has(key) and not already_guns.has(key):
			already_guns[key] = true
			unlocked.append({"type": "gun", "id": key})
	profile["known_cards"] = already_cards
	profile["known_guns"] = already_guns
	return unlocked
