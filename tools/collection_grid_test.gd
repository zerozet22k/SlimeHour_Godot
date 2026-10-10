extends SceneTree
## Collection browsing regression: complete reachability and undistorted art.
const Grid = preload("res://scripts/CollectionGrid.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(Grid.columns(false) == 4 and Grid.columns(true) == 2, "Desktop four-column / portrait two-column layout")
	check(Grid.visible_rows(false) == 2, "Desktop shows two grid rows")
	check(Grid.visible_rows(true, 1280.0) >= 3, "Tall portrait shows at least three grid rows")
	check(Grid.visible_rows(true, 720.0) >= 1, "Small portrait never drops below one row")
	check(Grid.indices(0, 4, 2, 0).is_empty(), "An empty category remains safe")
	check(Grid.view_label(0, 4, 2, 0) == "0 / 0", "Empty category counter is readable")
	check(Grid.indices(7, 4, 2, 0) == [0, 1, 2, 3, 4, 5, 6], "Short categories expose every item without paging")
	check(Grid.indices(22, 4, 2, 0) == [0, 1, 2, 3, 4, 5, 6, 7], "First desktop viewport shows eight cards")
	check(Grid.scroll_row(22, 4, 2, 0, 1) == 1, "Wheel moves by one complete grid row")
	check(Grid.scroll_row(22, 4, 2, 0, -10) == 0, "Upward scroll clamps to top")
	check(Grid.scroll_row(22, 4, 2, 0, 999) == 4, "Scrolling clamps to final complete desktop viewport")
	check(Grid.indices(22, 4, 2, 4) == [16, 17, 18, 19, 20, 21], "All 22 weapon slots are reachable")
	for total in [1, 2, 7, 8, 9, 22, 30, 68, 300]:
		for portrait in [false, true]:
			var cols = Grid.columns(portrait)
			var rows = Grid.visible_rows(portrait, 1280.0 if portrait else 720.0)
			var visited = {}
			var valid_indices = true
			var has_no_blank_rows = true
			for start in range(Grid.max_start_row(total, cols, rows) + 1):
				var visible = Grid.indices(total, cols, rows, start)
				if visible.is_empty():
					has_no_blank_rows = false
				for index in visible:
					if index < 0 or index >= total:
						valid_indices = false
					visited[int(index)] = true
			check(has_no_blank_rows and valid_indices, "All scroll rows valid at %d cards / %s" % [total, "portrait" if portrait else "desktop"])
			check(visited.size() == total, "Every one of %d entries is reachable in %s" % [total, "portrait" if portrait else "desktop"])
	var square = Grid.aspect_fit(Vector2(1024, 1024), Rect2(0, 0, 190, 150))
	check(is_equal_approx(square.size.x, 150.0) and is_equal_approx(square.size.y, 150.0), "Square card art is never squashed into a 190x150 frame")
	var wide = Grid.aspect_fit(Vector2(1024, 512), Rect2(10, 20, 190, 150))
	check(is_equal_approx(wide.size.x, 190.0) and is_equal_approx(wide.size.y, 95.0), "Landscape card art retains original 2:1 ratio")
	var tall = Grid.aspect_fit(Vector2(512, 1024), Rect2(10, 20, 190, 150))
	check(is_equal_approx(tall.size.x, 75.0) and is_equal_approx(tall.size.y, 150.0), "Portrait art retains original 1:2 ratio")
	check(is_equal_approx(square.get_center().x, 95.0) and is_equal_approx(square.get_center().y, 75.0), "Contained card art is centered")
	print("COLLECTION GRID: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(1 if failures > 0 else 0)
