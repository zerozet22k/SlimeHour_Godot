extends RefCounted
class_name CrowdCatalog

static func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open catalog: " + path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		push_error("Invalid catalog JSON: " + path)
		return []
	return data

static func load_all() -> Dictionary:
	var out := {}
	for key in ["cards", "weapons", "enemies"]:
		out[key] = read_json("res://data/" + key + ".json")
	return out
