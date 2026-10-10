extends RefCounted
## A Collection page is a horizontal WINDOW over the ordered catalog,
## not a vertical page. Next shifts by exactly one item.
const DESKTOP_VISIBLE = 4
const PORTRAIT_VISIBLE = 2

static func window_size(portrait: bool) -> int:
	return PORTRAIT_VISIBLE if portrait else DESKTOP_VISIBLE

static func max_start(total: int, visible: int) -> int:
	return maxi(0, total - visible)

static func offset(total: int, visible: int, current: int, delta: int) -> int:
	return clampi(current + delta, 0, max_start(total, visible))

static func range_indices(total: int, visible: int, current: int) -> Array:
	var start = clampi(current, 0, max_start(total, visible))
	var indices: Array = []
	for i in range(start, mini(total, start + visible)):
		indices.append(i)
	return indices
