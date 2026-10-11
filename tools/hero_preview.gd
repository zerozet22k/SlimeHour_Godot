extends SceneTree
## The five runners in several poses, plus every gun, saved to
## tools/art_review/hero_preview.png and gun_sheet.png.
## Needs a real window:  Godot --path . --script tools/hero_preview.gd
const HeroModels = preload("res://scripts/HeroModels.gd")
const GunModels = preload("res://scripts/GunModels.gd")
const Characters = preload("res://scripts/Characters.gd")

class Sheet extends Node2D:
	var mode := "heroes"
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("23262e"))
		if mode == "guns":
			var ids: Array = GunModels.GRIPS.keys()
			for i in range(ids.size()):
				var c := Vector2(150 + (i % 6) * 200, 90 + (i / 6) * 170)
				draw_set_transform(c, 0.0, Vector2.ONE * 3.0)
				GunModels.draw(self, str(ids[i]), {"t": 0.3})
				var g: Array = GunModels.grips(str(ids[i]))
				draw_circle(g[0], 1.5, Color(0, 1, 0, 0.8))
				if g[1] != null:
					draw_circle(g[1], 1.5, Color(1, 0, 1, 0.8))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_string(ThemeDB.fallback_font, c + Vector2(-60, 60), str(ids[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			return
		var aims := [Vector2(0.55, 0.83), Vector2(-0.7, -0.7), Vector2(1, -0.2), Vector2(0.2, 1), Vector2(0.2, 1)]
		for row in range(Characters.ROSTER.size()):
			var ch: Dictionary = Characters.ROSTER[row]
			var id := str(ch["id"])
			for col in range(5):
				var p := Vector2(110 + col * 240, 75 + row * 140)
				var f: Vector2 = aims[col].normalized()
				var k := float(OS.get_environment("HERO_K")) if OS.get_environment("HERO_K") != "" else 1.6
				var guns: Array = []
				var ids: Array = ["shotgun", "sniper"] if col == 2 else [str(ch["weapon"])]
				if OS.get_environment("HERO_GUNS") != "":
					ids = Array(OS.get_environment("HERO_GUNS").split(","))
				for i in range(ids.size()):
					guns.append({"id": ids[i], "aim": f, "muzzle": HeroModels.muzzle_for(p, f, k, str(ids[i]), i, ids.size())})
				var o := {"t": 0.4 + row, "step": 2.0}
				if col == 3:
					o["bash"] = 0.3
					o["bash_dir"] = f
				if col == 4:
					o["bash"] = 0.6
					o["bash_dir"] = f
				HeroModels.draw_rig(self, id, p, f, k, guns, o)

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var sheet := Sheet.new()
	root.add_child(sheet)
	for mode in ["heroes", "guns"]:
		sheet.mode = mode
		sheet.queue_redraw()
		for k in range(4):
			await process_frame
		var name := "hero_preview.png" if mode == "heroes" else "gun_sheet.png"
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/art_review/" + name))
	quit()
