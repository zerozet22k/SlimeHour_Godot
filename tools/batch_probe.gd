extends SceneTree
## Counts draw calls for 500 of each primitive type, to learn what batches.

class Probe extends Node2D:
	var mode := ""
	var tex: Texture2D
	func _draw() -> void:
		for i in range(500):
			var p := Vector2(20 + (i % 40) * 30, 20 + (i / 40) * 30)
			match mode:
				"rect":
					draw_rect(Rect2(p, Vector2(10, 10)), Color(randf(), 0.5, 0.5))
				"texrect":
					draw_texture_rect_region(tex, Rect2(p, Vector2(10, 10)), Rect2(0, 0, 8, 8), Color(randf(), 0.5, 0.5))
				"circle":
					draw_circle(p, 6.0, Color(randf(), 0.5, 0.5))
				"line":
					draw_line(p, p + Vector2(10, 5), Color(randf(), 0.5, 0.5), 2.0)
				"line_aa":
					draw_line(p, p + Vector2(10, 5), Color(randf(), 0.5, 0.5), 2.0, true)
				"polygon":
					draw_colored_polygon(PackedVector2Array([p, p + Vector2(10, 0), p + Vector2(5, 9)]), Color(randf(), 0.5, 0.5))
				"arc":
					draw_arc(p, 6.0, 0.0, TAU, 12, Color(randf(), 0.5, 0.5), 2.0)
				"mixed":
					draw_texture_rect_region(tex, Rect2(p, Vector2(10, 10)), Rect2(0, 0, 8, 8), Color.WHITE)
					draw_rect(Rect2(p, Vector2(4, 4)), Color.RED)
				"xform":
					draw_set_transform(p, 0.3, Vector2.ONE)
					draw_texture_rect_region(tex, Rect2(0, 0, 10, 10), Rect2(0, 0, 8, 8), Color.WHITE)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var probe := Probe.new()
	probe.tex = ImageTexture.create_from_image(img)
	root.add_child(probe)
	for mode in ["rect", "texrect", "circle", "line", "line_aa", "polygon", "arc", "mixed", "xform"]:
		probe.mode = mode
		probe.queue_redraw()
		for k in range(4):
			await process_frame
		print("%-8s draw_calls=%d" % [mode, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	quit()
