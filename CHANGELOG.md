## v0.1.26 — Horizontal Collection browsing and Windows patch-download repair

- Make the Collection truly horizontal: desktop shows four cards left-to-right and portrait shows two side-by-side; Next/Previous advances by one item instead of jumping an entire 12-card page.
- Reserve the right-hand desktop details panel so collection cards no longer overlap its artwork. Keyboard arrows and mouse wheel use the same sequence.
- Download incremental patches up to 16 MiB into bounded memory before writing them to disk. This bypasses the file-stream errors that displayed HTTP 200 but zero bytes in the previous updater.
- Report the real request error alongside the HTTP response code to separate download-file, DNS, TLS, timeout and network failures.
- Preserve existing ZIP size and SHA-256 verification, large-file streaming, delta compatibility checks and verified restart.
- Add regression checks for scrolling order, horizontal viewport bounds, small-patch buffering and updater error diagnostics.

## v0.1.25 — Interactive developer Debug Lab

- Open the in-game Debug Lab with F3 from menus, combat, card picks, shops, map, and boss result screens. F4 now independently shows performance counters.
- Route and sector test controls: jump ahead or backward, enter Elite/Hell roads, boss sectors, shops, campfires, treasures, events, or the full route map without replaying.
- All-card and all-weapon browsers for quickly testing builds and card combinations, plus spawn-any-enemy testing.
- Invincibility, full heal, 500 gold, clear enemies and an instant test-run button.
- The fight pauses while the Lab is open; permanent progress is snapshotted, saves are disabled, and profile/records are restored on returning to the menu.
- Add regression tests for scene-navigation bounds, persistent-save isolation and catalog selection.

## v0.1.23 — Precision cursor aiming and correctly oriented weapon art

- Correct all weapon sprite art rotation when aiming left. The old vertical flip reversed the sprite's barrel tilt without reversing its compensating angle (especially visible on the sniper).
- Calculate gun-specific projectile and instant beam trajectories from each actual muzzle toward the cursor rather than sending parallel bullets from an offset hand.
- Align sprite barrel tips, muzzle flashes and charged rail effects with the shared muzzle position and corrected per-slot direction.
- Reproject the mouse world coordinate after camera motion and let captured mouse cursors reach both edges of expanded ultrawide viewports.
- Add headless regression checks for every gun's barrel orientation at eight angles, both left and right aim, three muzzle slots, and auto-aim fallback.

## v0.1.22 — Visible version and truly permanent unlock receipts

- Show the exact game version on desktop and portrait main menus, settings, and desktop pause overlay.
- Fix repeating NEW CARD and NEW GUN alerts: persist a receipt for each unlock immediately when earned, not only at the end of a run.
- Retain cards and guns earned in a run even if the player quits before the run ends. Existing save files are silently migrated by registering everything already unlocked, without repeated popups.
- Add an automated regression test covering migration, repeated recomputation, mid-run restart persistence, and one-time unlock announcements.

## v0.1.21 — Full route overview, readable campfires, expanding playable road

- Fix fullscreen between-sector screens: campfires now use an opaque menu backdrop, the title no longer overlays ROUTE MAP, and gun training fits within 720p/16:9 without clipping.
- Add FULL MAP route overview with ten sector columns per page and previous/next controls. M or Esc toggles the overview, and left/right arrows browse it. Only adjacent reachable nodes can be selected, preserving progression.
- Expand the actual playable road at later sectors rather than stretching the same fixed arena. A horizontal-follow camera allows the player to explore the extra space on desktop or portrait screens.
- Generate deterministic physical roadside hazards: trees first, short median dividers in Sector 3+, breakable construction barriers in Sector 6+, and tougher destroyable parked cars only from Sector 12 onward.
- Make trees/cars/medians block both enemies and players, while bullets collide and can clear breakable barriers/cars. Continuous movement collision prevents dashes tunneling through obstacles.
- Add a Godot regression suite for road expansion, biome obstacle placement, projectile blocking, hero dash collision, and basic route map state.

## v0.1.19 — Direct-launch Windows game

- Change the legacy `Start_Slime_Hour.bat` helper to launch the game directly without invoking the old PowerShell command-window downloader.
- Prefer `SlimeHour.exe` as the desktop entry point; GitHub release checks, download progress, verification, and installation prompts now take place inside Godot.
- Keep the standalone repair/install script solely as a hidden installer after an in-game download or for manual recovery.

## v0.1.18 — Final in-game updater validation

- Add regression checks for in-game release discovery and integrity verification.
- Validate the hidden PowerShell install-only route end to end using both full and content-addressed delta archives in CI.
- Correct the installer script and projectile VFX parser defects caught during v0.1.17 development.

## v0.1.17 — In-game Windows updater

- Check GitHub Releases inside the game and display a dedicated download interface, with the actual file size, MiB progress, verification, retry, and cancel controls.
- Automatically prefer compatible incremental patches when available; otherwise download the full Windows game once.
- Download files directly to disk, verify the exact SHA256 checksum and advertised file size, then prompt for Install & Restart.
- Apply verified patches after the game exits using a hidden Windows helper, so no CMD or PowerShell console appears during game updates.
- Preserve previous versions and saves. The installer validates every output file and launches the previous game if an installation fails.
- Add unit tests for trusted release URLs, semantic versions, checksums, and matching patch metadata, plus an installer test for delta and full archives.

## v0.1.16 — Expressive weapon effects and gentler early-mid sectors

- Separate kinetic, rapid, heavy, piercing, fragment, fire, ice, poison, shock, explosive, ricochet and enemy-projectile travel/impact styles; add muzzle flashes, bounce flashes, critical hit flashes and element-specific procs.
- VFX reuse the bounded existing CanvasItem/Fx renderer, with a hard budget and the Particles setting respected.
- A modest easing around Sectors 7-11 reduces HP and crowd spikes while retaining late-game scaling. Two elite affixes now begin in Sector 10, not Sector 8.
- Route map, boss-result, shops and rewards softly carry the current biome's music across transitions, without combat percussion.
- Fix repeat monster-unlock alerts across runs using persistent announcement history, and correctly compare old and new card/gun unlocks at run completion.

## v0.1.15 — Confirmed boss results and deliberate route transitions

- After a boss dies, collect pending rewards, then present a dedicated BOSS DEFEATED result screen. Continue to the route map only when the player presses Continue; the final Sector 20 victory screen remains its own confirmation.
- Selecting a map node only highlights it: double-clicking can no longer accidentally skip past the map. GO shows a 1.4-second route departure sequence before entering the new sector or stop.
- Shops, campfires, events, intermission card rewards and weapon replacements now share the route-map visual context instead of displaying the battlefield behind them.
- Combat music stops when leaving the fight, including between-sector shops, map navigation, treasure selections, and route-related arsenal screens.
- Added regression tests for clear/reward ordering, boss confirmations, transition timing and context-sensitive combat music.

## v0.1.13 — Explosive barrels, treasure art, evolving music and boss encounters

- Replaced placeholder chest and barrel drawings with original gold-and-neon artwork; treasure selection highlights the chest.
- Barrels flash and display a visible 0.85-second blast warning after being shot, struck during a dash, or ignited by a chain explosion. Barrel blasts damage both slimes and the player; previously intact barrels are not deleted instantly.
- Seven distinct original synthesized songs: Neon Outskirts, Frostline, Ashlands, Candy District, Void Lane, boss and low-HP boss climax. Crossfade on scene changes.
- Adaptive danger percussion grows when the player is surrounded or cornered, with a restrained warning sound; music continues respecting the settings slider.
- Four boss types gain distinct attack rotations, ground telegraphs and stronger 65% and 32% HP stages; boss attack warnings are audible.
- Added headless regression tests for fuse timing, attack phases and song composition.

## v0.1.12 — Clear, safe Windows download progress

- Replace PowerShell's misleading "Writing web request stream" display with accurate file names, MiB transferred and percentage.
- Stream downloads into temporary files; reject content whose length differs from GitHub's published asset size.
- Reject patch metadata larger than 4 KiB, preventing unexpected huge downloads when fetching a tiny JSON file.
- Preserve SHA256 verification, safe staging, and compatible-patch/full-download fallback.
- CI now verifies that the production downloader fetches actual release metadata with the expected size.

## v0.1.11 — Ultrawide fullscreen and volley art

- Landscape windows now use the actual horizontal display width for both menus and gameplay, without distorting sprites or changing normal 16:9 proportions.
- Expanded road and playable collision walls for wide screens, including enemy spawns, projectiles, scenery and lane markings.
- New Double Tap and Parallel Shots card illustrations appear on card offers, collection tiles and HUD.
- Existing projectile range mechanic is intentional: distance is approximately velocity × lifetime, and range cards extend the lifetime.
- Included MC's directional bash and Kaboomba's timed, visible detonation from v0.1.10.

## v0.1.10 — Card art, MC melee bash and reactive bombers

- New Double Tap and Parallel Shots card illustrations.
- Main character has an innate directional bash (F, middle mouse, or touch button) with knockback, short stun, cooldown and animated melee swipe.
- Dashing into Kaboombas activates their 0.8-second visible fuse instead of deleting the enemy without its explosion.
- Swept dash collision prevents fast dashes from skipping bombers; lethal gunshots also arm the delayed explosion.
- Regression tests for bash hit arc and bomb countdown.

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
