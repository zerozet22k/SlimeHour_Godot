extends RefCounted
## Tested progression rules: no automatic boss-map jump or accidental hub combat music.
const TRAVEL_DURATION = 1.40
const RESULT_MIN_WAIT = 0.80

static func ready_after_clear(seconds_left: float, pending_levels: int, pending_chests: int) -> bool:
	return seconds_left <= 0.0 and pending_levels <= 0 and pending_chests <= 0

static func requires_boss_result(boss_sector: bool, sector: int, win_sector: int) -> bool:
	return boss_sector and sector != win_sector

static func should_play_combat_music(state: String, phase: String) -> bool:
	return phase == "fight" and state in ["playing", "paused", "levelup", "replace", "arsenal"]

static func is_hub_reward_context(phase: String) -> bool:
	return phase in ["treasure", "shop", "rest", "event", "cleared", "map"]
