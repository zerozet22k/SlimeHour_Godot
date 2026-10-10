extends RefCounted
## Virtualized collection grid: every item is reachable by vertical row scrolling.
## Pure layout/scroll calculations keep desktop and portrait input consistent.
const DESKTOP_COLUMNS = 4
const PORTRAIT_COLUMNS = 2
const DESKTOP_ROWS = 2
const PORTRAIT_TILE_HEIGHT = 258.0
const PORTRAIT_STEP = 270.0

static func columns(portrait: bool) -> int:
	return PORTRAIT_COLUMNS if portrait else DESKTOP_COLUMNS

static func visible_rows(portrait: bool, screen_height: float = 720.0) -> int:
	if not portrait:
		return DESKTOP_ROWS
	return maxi(1, int(floor((screen_height - 365.0) / PORTRAIT_STEP)))

static func total_rows(total: int, cols: int) -> int:
	return int(ceil(float(maxi(0, total)) / float(maxi(1, cols))))

static func max_start_row(total: int, cols: int, rows: int) -> int:
	return maxi(0, total_rows(total, cols) - maxi(1, rows))

static func clamp_row(total: int, cols: int, rows: int, start: int) -> int:
	return clampi(start, 0, max_start_row(total, cols, rows))

static func scroll_row(total: int, cols: int, rows: int, start: int, delta: int) -> int:
	return clamp_row(total, cols, rows, start + delta)

static func indices(total: int, cols: int, rows: int, start: int) -> Array:
	var first = clamp_row(total, cols, rows, start) * maxi(1, cols)
	var result: Array = []
	for index in range(first, mini(maxi(0, total), first + maxi(1, cols) * maxi(1, rows))):
		result.append(index)
	return result

static func view_label(total: int, cols: int, rows: int, start: int) -> String:
	if total <= 0:
		return "0 / 0"
	var shown = indices(total, cols, rows, start)
	return "%d-%d / %d" % [int(shown[0]) + 1, int(shown[-1]) + 1, total]

static func aspect_fit(source: Vector2, bounds: Rect2) -> Rect2:
	## Fit inside the supplied rectangle without distorting intrinsic proportions.
	if source.x <= 0.0 or source.y <= 0.0:
		return Rect2(bounds.get_center(), Vector2.ZERO)
	var scale = minf(bounds.size.x / source.x, bounds.size.y / source.y)
	var size = source * scale
	return Rect2(bounds.get_center() - size * 0.5, size)
