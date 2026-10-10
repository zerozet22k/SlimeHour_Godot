## v0.1.9 — Collection text cleanup

- Removed the unnecessary Bestiary instruction from the Collection footer. Bestiary remains available directly from the main menu.

## v0.1.8 — Verified partial-download rollout

- First production incremental release using the external Godot content pack introduced in v0.1.7.
- CI publishes changed chunks as a small separate patch when worthwhile; oversized patch candidates automatically fall back to a full download.
- Update installation keeps the old version available until the new executable and pack pass SHA256 verification.

## v0.1.7 — Incremental game downloads

- Export SlimeHour.exe and SlimeHour.pck separately instead of embedding the full game pack into every new executable.
- Windows updater downloads only changed content-addressed chunks for consecutive version updates with an available patch; unchanged chunks are reused from the installed version.
- Every downloaded archive and every reconstructed file is SHA256 checked. Incomplete or incompatible patches fall back to verified full-download installs.
- GitHub Actions generates manifests, optional partial patches, and a full offline ZIP; tests both the Python reference implementation and the production PowerShell patch applier.
- Older integrated-executable builds need one full transition download; existing save files stay untouched.

## v0.1.6 — Build-aware card prerequisites

- Dependents cannot appear until their requirements exist in the current run: fragment generation before fragment modifiers, elemental sources before damage/reactive cards, explosions before explosion triggers, orbiting blades before blade upgrades, and wall bounces before wall-splatter cards.
- Dual-element reactions need both statuses, not just one. Weapons with natural status effects count as valid sources.
- Gate bonuses also count as sources while active. Startup Head Start cards use the same eligibility rules as shops, level-up rewards, and chests.
- Added card prerequisite regression tests, including tests against dead-end prerequisite chains.

## v0.1.5 — Dedicated Bestiary

- Added a standalone Bestiary tab to desktop and portrait main menus.
- Removed monsters from Collection. Every monster has a discoverable full-page entry.
- Unlocked entries show portrait, base HP, damage, speed, ability, counterplay, XP and lifetime kills.
- Added All, Street, Bosses and Discovered filters with paginated grids and hidden undiscovered enemies.
- Included v0.1.4 status scaling, detailed card bonuses, and reduced Sector 8 enemy HP.

## v0.1.4 — Status scaling and readable card benefits

- Smoothed enemy HP growth: Sector 8 now targets about 4x base HP rather than 26x, compensating for the reduced card economy.

- Burn, poison, bleed and shock gain main damage-build scaling plus controlled target-health scaling; bosses receive only one-quarter of the target-health bonus.
- Stacked poison and bleed continue to matter against tougher crowds and in Endless without making damage-over-time an unlimited percent-health execute.
- Card offers now display quantified gains on the first copy, diminishing stack totals on later copies, and proc damage/chance/radius for proc-only cards.
- Collection cards show actual owned effects; percent-valued stats no longer appear as raw integer counts.
- Godot CI runs regression checks for status balance and card preview formatting before publishing a Windows release.

## v0.1.3 — Beam edge correction and updater safeguards

- Railgun and Beam Me now handle shots originating at or beyond a road edge when wall reflection is active (fix already on main).
- Added regression checks for left/right edges, reflected hits, rail piercing and enemy ricochet target selection.
- Ignore empty aim rays, and compare update versions numerically to avoid accidental downgrades.
- Added automated Windows export and SHA256-checked GitHub release publishing for new game versions.

# Harder enemies, kill-all sectors, PC controls (2026-10-09)

- **No finish line**: a sector ends when its whole crowd (and boss) is dead. The HUD shows ENEMIES LEFT. The crowd is finite and arrives over time and as you kill.
- **Road bonuses moved to the map**: the old pick-a-door gates are now bonuses (or risky deals) shown on fight nodes.
- **New PC route map**: left-to-right roads, labelled nodes, details panel with GO.
- **Controls**: left click fires gun 1, right click gun 2 (a 3rd gun fires with either), R reloads, Space/Shift dash (no more right-click dash). Auto-fire defaults off on PC.
- **Harder enemies**: Laser Larry locks on, then fires an instant beam. Chonks belly-slam (sector 4+), Spitters triple-shot (6+), Zoomers lunge (7+). Elites roll affixes: Hasted, Armored, Volatile, Splitter, Regen, Turret (2 from sector 8, 3 from 14).
- **New mobs**: Mortar Mike (lobbed shells), Hype Totem (halves damage to nearby enemies), Blinky (teleports next to you), Lil Tick (latches on, slows and drains; dash to shake it off).
- **Mid/late scaling**: enemy HP compounds an extra 6% per sector from sector 6; free player damage scaling is +6% per sector (was +10%).
- Arsenal text fixes (stats fit, perks wrap, card names on two lines).

# Route map, economy and balance rework (2026-10-09)

- **Route map** (Slay the Spire style) replaces the walk-in pit stop: Fight, Elite (+gold, chest), Hell Lane, Shop, Campfire (heal or train a gun), Treasure, "?" events with real dice rolls, Boss every 5th sector. The column after a boss always has a shop; Elite/Hell roads improve the next shop's odds.
- **No farming / no skipping**: each sector has a fixed crowd that unlocks as you advance; boss and Mama minions drop nothing; the exit stays locked until ~70% of the crowd is beaten.
- **Damage**: "+X% damage" sources (cards, gun level, mastery, situational bonuses) now add together; only a few cards (Glass Cannon, Overclocked, Cursed Doll) and evolutions give "+X% TOTAL damage". Percent bonuses diminish per extra copy; offers show the change (e.g. DAMAGE +10% » +17%).
- **Rarity odds** are a fixed table (Common 72 / Rare 24.5 / Epic 3 / Legendary 0.45 / Mythic 0.045 / Ascendant 0.005%); each luck point moves a small slice up. Chests are "at least Rare" without inflating Epic+. Shop Mystery Card is the place Epics show up.
- **Economy**: less gold everywhere (kill coins, elites, goblins, bosses, stipend, skip, gold cards; on-hit gold has a cooldown). Shop prices by rarity, no guaranteed Epic slot.
- **Difficulty**: gentler start (enemy HP ~base in sector 1, fewer spawns, faster first levels), steady compounding later.
- **Profile unlocks**: start with 110 cards and 8 guns; each profile level unlocks 10 cards and a gun. **Hard Mode**: tougher enemies and 25% of cards secretly sealed per run, 1.5x profile XP.
- **UI**: bundled fonts (Lilita One, Nunito, OFL), rounded chunky buttons, new cards (no "card inside a card" placeholders; category icons instead), Ascendant shimmers, portrait HUD with floating joystick.
- **Performance**: enemies are baked into one atlas and batch-drawn (about 10 fps -> 65 fps with 200 enemies at 1080p); status timers tick at 10 Hz; physics catch-up capped at 3 steps. Sound: max 3 copies per sound, ducking, master limiter.
- Funnier names for ~60 cards; CHAOS is back to BAD IDEAS.
- Game art is included in `assets/`.

# Mobile & Touch Controls (2026-10-09)

- **Full mobile gameplay**: the game is now completely playable on phones, tablets, and touchscreen devices.
- **Virtual Joystick**: floating thumbstick on the left side of the screen with directional indicators that dynamically follows the thumb and controls movement.
- **Dedicated Dash Button**: prominent neon touch button on the bottom right with charges display, active cooldown arc, and instant dodge activation.
- **Touch-friendly UI**:
  - Top-right on-screen **Pause button** (`||`).
  - Bottom-right **Arsenal button** (`ARSENAL`) to inspect weapons, cards, and stats on mobile.
  - Pit stop stalls have an on-screen **BUY button** on their info card for one-tap purchasing.
  - Level-up screen includes a **PEEK BUILD** button to check owned cards without a keyboard.
  - Collection and Arsenal cards can be tapped directly to inspect stats and descriptions.
  - Multi-touch support with duplicate click prevention.
- **Mobile settings**:
  - `TOUCH CONTROLS`: toggle between **AUTO**, **ON**, and **OFF** in Settings.
  - Sensor landscape orientation enabled in `project.godot`.
  - Auto-aim defaults to ON for mobile/touchscreen devices.

# Tiers, victory and endless scaling (2026-10-09)

- **Win at sector 20**: clearing it shows a victory screen. You can continue the same run into sector 21+ or go back to the menu.
- **Endless mode is brutal**: past sector 20, every sector has a boss, and boss HP multiplies by 1.8x per sector (sector 21 boss is about 1.8x the sector 20 boss).
- **Tougher enemies**: regular enemy HP is 1.6x and also rises as you go deeper into a sector. Bosses have far more base HP.
- **Less XP**: the level curve is now `20 + 18*(L-1) + (L-1)^2.5`.
- **Two new rarities above Legendary**: Mythic (pink) and Ascendant (white). Base weights are 75 / 20 / 4 / 0.55 / 0.08 / 0.008; Luck scales the higher tiers.
- **Projectile-count cards are Epic or higher**, and a few top cards moved up to Mythic or Ascendant.
- **Gun tiers**: each new gun rolls a rarity tier when you pick it up. Higher tiers deal more damage (up to 2.4x) and fire faster (up to 1.25x). The tier shows on the HUD, the Arsenal screen and the shop.
- **Rarity colours only**: card borders use the rarity colour. Category colours are gone so Epic and above stand out.
- **Bigger, longer fights**: buff gates only appear every 10th sector and give less. Sectors are longer (4800), the road is wider, and up to 320 enemies can be on screen.
- **Growing limits**: max HP, the visible projectile cap and the friendly-shot cap all rise with sector progress. Projectile size is capped so big builds stay readable.
- Card and gun artwork is bundled with the project.

# Balance pass (2026-10-09)

Runs were snowballing on free power. Measured with the new `pace` autotest over 10 sectors:

- **XP curve is much steeper**: `15 + 14*(L-1) + (L-1)^2.4` per level (was `6 + 5*(L-1) + (L-1)^1.6`). Level at sector 10 went from about 28 to about 14.
- **Elites drop a chest 10% of the time** instead of always. Chest screens per 10 sectors went from about 70 to about 9.
- **Rarer high tiers**: base rarity weights are now 66 / 26 / 6 / 1 (was 60 / 28 / 10 / 2.2). Luck still scales them up.
- New `--autotest=pace` mode: the bot plays without free cards and logs level and offer rarities per sector.

# Slime Hour: Rebuild (2026-10-08)

Rewrote the squad shooter as a single-hero, weapon-driven action roguelite.

- **Hero**: one character with free movement, dash charges, i-frames, and a perfect-dodge mechanic that triggers counter cards.
- **22 guns** with distinct firing rules (beam heat, rail charge, minigun spin-up, returning discs, lobbed grenades, bowling-ball knockback, bouncing chickens, trapping bubbles, growing snowballs...), dual-wielded, levels 1-5 with per-gun level 3/5 perks, and evolutions.
- **Multi-attack as a build system**: fan multishot, parallel lines, rear/side shots, burst repeats, delayed echoes, a ghost twin that mirrors you, autonomous weapons (blades, drones, turrets, mines, saws, bees, an intern, a chicken, a dog) and on-hit/on-kill chains.
- **300 cards** in 10 categories, all data-driven through one proc engine and validated against the source. The autotest checks each card at max stacks for runtime errors.
- **Elements and reactions**: burn, chill/freeze, shock, poison, bleed, slow, charm, wet and mark, plus steam, overload, conductor, shatter, wildfire, plague, hemorrhage and brainwash.
- **Physical chaos**: knockback with mass, enemies flung into each other (bowling), explosive barrels, oil that ignites, banana peels, anvils, pianos, a clown car.
- **13 enemy types** with their own behaviour (riot shields block from the front, bulls charge, nurses heal, mamas spawn minis, kaboombas blow up their friends, gold goblins run away) plus elites with treasure chests and 4 bosses.
- **Sector flow**: buff gates, a Slime Hour horde event, boss every 5th sector, a walk-in pit stop shop and route choice.
- **New UI**: chunky HUD, animated level-up cards with art, treasure picks, gun replace prompt, Arsenal (Tab), a Collection browser for all 300 cards and guns, settings with sound and music volume.
- **Procedural audio**: every sound and a looping beat are synthesized at startup. There are no audio files.
- **Art** is bundled with the project.
- Removed: the old 70-card catalog, squad soldiers and active powers.
