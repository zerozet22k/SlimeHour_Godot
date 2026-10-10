extends RefCounted
## A developer sandbox. This is intentionally not a profile progression system:
## first opening the lab snapshots persistent progress and disables disk saves.
## Leaving to the menu restores the original profile/records and clears the sandbox.
const MAX_DEBUG_SECTOR = 100
const ITEM_PAGE_SIZE = 10

static func enter(g) -> void:
	if g.debug_session:
		return
	g.debug_snapshot = {
		"profile": g.profile.duplicate(true),
		"best": g.best.duplicate(true),
		"unlocked_cards": g.unlocked_cards.duplicate(true),
		"unlocked_guns": g.unlocked_guns.duplicate(),
		"next_unlock_kills": g.next_unlock_kills,
	}
	g.debug_session = true
	g.no_save = true

static func restore(g) -> void:
	if not g.debug_session:
		return
	var backup: Dictionary = g.debug_snapshot
	g.profile = backup["profile"].duplicate(true)
	g.best = backup["best"].duplicate(true)
	g.unlocked_cards = backup["unlocked_cards"].duplicate(true)
	g.unlocked_guns = backup["unlocked_guns"].duplicate()
	g.next_unlock_kills = int(backup["next_unlock_kills"])
	g.debug_session = false
	g.debug_panel_open = false
	g.debug_godmode = false
	g.debug_snapshot.clear()
	g.no_save = false
	g.run_unlocks.clear()
	g.unlock_toasts.clear()

static func enter_run(g) -> void:
	enter(g)
	if g.hero.is_empty() or g.state in ["menu", "lost", "victory", "updating"]:
		g.start_run()
	g.debug_panel_open = true

static func jump(g, destination: int, kind: String = "fight") -> void:
	enter_run(g)
	var where = clampi(destination, 1, MAX_DEBUG_SECTOR)
	if kind == "boss" and where % 5 != 0 and where <= g.WIN_SECTOR:
		where = mini(MAX_DEBUG_SECTOR, int(ceil(float(where) / 5.0)) * 5)
	g.sector = where
	g.bosses_beaten = mini(g.ENEMY_TIERS.size() - 1, int((where - 1) / 5))
	g.fresh_tier_sector = -1
	g.gen_map(where + 19)
	g.map_at = 0
	g.map_pick = -1
	g.map_full = false
	g.map_view_first = maxi(0, where - 2)
	g.map_path = [Vector2i(where - 1, 0)]
	g.hero["pos"] = Vector2.ZERO
	g.hero["vel"] = Vector2.ZERO
	g.hero["push"] = Vector2.ZERO
	g.cam_x = 0.0
	g.cam_y = -g.hero_offset()
	g.pending_levels = 0
	g.pending_chests = 0
	g.levelup_delay = 0.0
	g.dying_t = 0.0
	g.gates.clear()
	g.pickups.clear()
	g.shots.clear()
	g.fx.clear()
	g.delayed.clear()
	g.enemies.clear()
	g.buffs.clear()
	g.route_risk = 0
	g.event = {}
	g.phase = "fight"
	g.state = "playing"
	match kind:
		"map":
			g.begin_sector()
			g.open_map()
		"shop":
			g.begin_sector()
			g.open_shop()
		"rest":
			g.begin_sector()
			g.phase = "rest"
			g.state = "rest"
		"treasure":
			g.begin_sector()
			g.phase = "treasure"
			g.pending_chests = 1
			g.open_offers("chest")
		"event":
			g.begin_sector()
			g.start_event()
		"elite", "hell":
			g.start_node_fight(kind)
		_:
			g.start_node_fight("boss" if kind == "boss" else "fight")
	g.debug_notice = "SECTOR %d / %s" % [g.sector, kind.to_upper()]

static func give_card(g, id: String) -> bool:
	if not g.card_by_id.has(id):
		return false
	enter_run(g)
	# Force is explicitly limited to the debug lab; normal card choices still
	# respect prerequisite checks, rarity, inventory caps and stack limits.
	var before = int(g.owned.get(id, 0))
	g.Effects.add_card(g, id, true)
	g.debug_notice = "CARD: " + str(g.card_by_id[id]["name"])
	return int(g.owned.get(id, 0)) > before

static func give_gun(g, id: String) -> bool:
	if not g.weapon_db.has(id):
		return false
	enter_run(g)
	var slot = mini(g.debug_slot, g.guns.size())
	var gun = g.Weapons.new_gun(g, id)
	if slot < g.guns.size():
		g.guns[slot] = gun
	else:
		g.guns.append(gun)
	g.stats_dirty = true
	g.Effects.recalc(g)
	g.debug_notice = "GUN %d: %s" % [slot + 1, g.weapon_db[id]["name"]]
	return true

static func spawn(g, id: String, elite: bool = false) -> bool:
	if not g.enemy_db.has(id):
		return false
	enter_run(g)
	# Spawning from a hub moves to combat without clearing the debug inventory.
	if g.state != "playing":
		g.start_node_fight("fight")
	var distance = 200.0 + 35.0 * float(g.enemies.size() % 3)
	var x = -100.0 + float(g.enemies.size() % 3) * 100.0
	var pos: Vector2 = g.hero["pos"] + Vector2(x, -distance)
	g.spawn_enemy(id, pos, bool(g.enemy_db[id].get("boss", false)), elite)
	g.debug_notice = "SPAWNED: " + str(g.enemy_db[id]["name"])
	return true

static func items(g, tab: String) -> Array:
	var result: Array = []
	match tab:
		"CARDS":
			for c in g.db_cards:
				result.append({"id": str(c["id"]), "label": str(c.get("name", c["id"]))})
		"WEAPONS":
			for id in g.weapon_ids:
				result.append({"id": str(id), "label": str(g.weapon_db[id].get("name", id))})
		"ENEMIES":
			for id in g.enemy_db:
				result.append({"id": str(id), "label": str(g.enemy_db[id].get("name", id))})
	return result

static func run_action(g, action: String) -> void:
	if not g.debug_panel_open:
		return
	if action == "debug_close":
		g.debug_panel_open = false
		return
	if action == "debug_start":
		enter_run(g)
		return
	if action == "debug_god":
		enter(g)
		g.debug_godmode = not g.debug_godmode
		g.debug_notice = "INVINCIBLE ON" if g.debug_godmode else "INVINCIBLE OFF"
		return
	if action == "debug_heal":
		enter_run(g)
		g.hero["hp"] = float(g.hero["maxhp"])
		g.debug_notice = "HEALED"
		return
	if action == "debug_gold":
		enter_run(g)
		g.gold += 500
		g.debug_notice = "+500 GOLD"
		return
	if action == "debug_kill":
		enter_run(g)
		for e in g.enemies:
			e["dead"] = true
		g.enemies.clear()
		g.shots.clear()
		g.debug_notice = "ENEMIES CLEARED"
		return
	if action == "debug_map":
		jump(g, g.sector, "map")
		return
	if action.begins_with("debug_tab_"):
		g.debug_tab = action.trim_prefix("debug_tab_")
		g.debug_page = 0
		return
	if action == "debug_prev":
		g.debug_page = maxi(0, g.debug_page - 1)
		return
	if action == "debug_next":
		g.debug_page += 1
		return
	if action.begins_with("debug_slot_"):
		g.debug_slot = clampi(int(action.trim_prefix("debug_slot_")), 0, 2)
		return
	if action.begins_with("debug_sector_"):
		jump(g, int(action.trim_prefix("debug_sector_")), "fight")
		return
	if action.begins_with("debug_step_"):
		jump(g, g.sector + int(action.trim_prefix("debug_step_")), "fight")
		return
	if action.begins_with("debug_place_"):
		jump(g, g.sector, action.trim_prefix("debug_place_"))
		return
	if action.begins_with("debug_card_"):
		give_card(g, action.trim_prefix("debug_card_"))
		return
	if action.begins_with("debug_gun_"):
		give_gun(g, action.trim_prefix("debug_gun_"))
		return
	if action.begins_with("debug_spawn_"):
		spawn(g, action.trim_prefix("debug_spawn_"))
