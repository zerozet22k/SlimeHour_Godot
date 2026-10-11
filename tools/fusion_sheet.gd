extends SceneTree
## Large review sheet: body parent | skin parent | fusion, for each curated
## mutation, saved to tools/art_review/fusion_sheet.png.
## Needs a real window:  Godot --path . --script tools/fusion_sheet.gd

const MonsterKit = preload("res://scripts/MonsterKit.gd")
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const MutationKit = preload("res://scripts/MutationKit.gd")

class Sheet extends Node2D:
	var rows: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("141a2a"))
		for i in range(rows.size()):
			var row: Array = rows[i]
			var col := i % 3
			var line := i / 3
			var o := Vector2(40 + col * 410, 40 + line * 115)
			var kinds := [row[0], row[1]]
			for k in range(3):
				var c := o + Vector2(50 + k * 120, 50)
				draw_set_transform(c, 0.0, Vector2.ONE)
				if k < 2:
					MonsterKit.draw(self, str(kinds[k]), str(kinds[k]), 30.0)
				else:
					MonsterKit.draw(self, str(row[0]), str(row[1]), 34.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_string(ThemeDB.fallback_font, o + Vector2(110, 105), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string(ThemeDB.fallback_font, o + Vector2(230, 105), "= " + str(row[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var db := {}
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json")):
		db[str(record["id"])] = record
	var sheet := Sheet.new()
	for recipe in EnemyMixes.RECIPES.slice(0, 18):
		var id: String = EnemyMixes.ensure(db, str(recipe["a"]), str(recipe["b"]))
		if id == "":
			continue
		var pair: Array = db[id]["mix"]
		sheet.rows.append([str(pair[0]), str(pair[1]), str(recipe["name"])])
	root.add_child(sheet)
	for k in range(6):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/fusion_sheet.png"))
	print("rows ", sheet.rows.size())
	quit()
