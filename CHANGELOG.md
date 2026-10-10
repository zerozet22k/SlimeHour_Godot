## v0.1.63 — Skitter bounds, last-enemy arrows, and boss HP

- Keep Skitter's committed through-player dash, but stop it at the road edge, forward pursuit limit, and rear sector barrier, including after crowd separation.
- Remove broken or unreachable off-screen enemies after a grace period without awarding kill rewards, and preserve sector-clear progress for budget-spawned enemies.
- Show grouped directional arrows to off-screen monsters only after all wave spawns are complete and five or fewer living threats remain; no arrows during the boss intro.
- Double the final HP of bosses on Normal and Hard, leaving regular enemies' HP unchanged.
- Extend the automated Skitter regression suite to cover boundaries, stranded-enemy cleanup, boss exceptions and arrow thresholds.

## v0.1.62 — Boss fights and projectile trails

- Add a three-phase boss fight director with distinct attacks, counterplay, bounded bullet patterns, and new boss models.
- Make Chonkzilla larger and have Spitter poison follow the actual path of each acid projectile.
- Export Windows and Android builds through the release workflows.

## v0.1.56 — Cinematic boss entrances and lethal arena ultimates

- **No overlapping waves and bosses:** every scheduled normal enemy and Rush wave must be exhausted and every living regular enemy defeated before the boss enters. Gold goblins cannot interrupt the reveal.
- **Cinematic entrances:** after the crowd is defeated, freeze the entire battle for a 3.6-second death-camera-style pan to the arriving boss, display a full-width threat title card, then pan back and resume combat.
- **World-wide dodge pressure:** each of the eight bosses starts using a signature road-covering ultimate roughly 2.6 seconds after combat begins, with a high-visibility impact timer. Walking to the edge cannot escape the blast; timed dash invulnerability does.
- **Second shockwaves:** Chonkzilla, Heli-Copter, Glass Oracle and Dread Engine strike twice with 1.85 seconds between hits, deliberately challenging timing and dash recharge.
- **Distinct failure consequences:** Necro-Dad's Eclipse heals him if it lands, King Blob's Tsunami grows him, Coil Queen's venom slows players, Void Weaver's rift pulls them, and Dread Engine's lockdown staggers them.
- Hard Mode tightens arena-ultimate warning time to 1.75 seconds instead of 2.15; normal attacks and boss-specific weak-point mechanics continue throughout the fight.
- Full-road telegraphs and large HUD countdowns work on portrait and landscape; real dodge windows, crowd-clear gating and cinematic combat-freeze behavior are covered by `tools/boss_encounter_test.gd` in the boss and Windows release CI suites.
- Preserve the separately shipped v0.1.55 F3 Debug Lab improvements.

## v0.1.54 — Eight genuinely different boss encounters

- Replace the shared colored ring/lane/explosion rotations with eight distinct combat systems and visible counterplay.
- **Chonkzilla:** committed seismic stomp, paired fissures and a staggered weak-point window.
- **Heli-Copter:** actual directional strafing flight and timed bombs dropped along its flight path.
- **Necro-Dad:** killable soul anchors that heal him while alive; eliminate linked leeches to stop regeneration.
- **King Blob:** consumes its own small blobs to regenerate HP and grow, while retaining its marked jumps and death splits.
- **Coil Queen:** independently moving inward venom walls with collision-accurate warnings and bending fang shots.
- **Glass Oracle:** killable mirror nodes that shield the boss and fire fixed-origin refraction beams.
- **Void Weaver:** two telegraphed portal mouths and a position swap; shot bursts come from the remote portals.
- **Dread Engine:** plated damage mitigation, escalating heat, delayed vent burst and a high-damage exposed core.
- Show boss-specific states, linked support bodies, live telegraphs and weak points in-world and in the Bestiary.
- Test actual mechanics, damage multipliers and phase transitions with `tools/boss_identity_test.gd`; run it in the Windows production release gate.

## v0.1.53 — Distinct enemy AI and separate Mutation Book

- Separate true monster species from generated mutations in the Bestiary. Historic hybrid kills remain in the Mutation Book; mutation encounter unlocks still reset each run.
- Give Blinky a destination teleport with a delayed echo beam and secondary shot; give Burrower an actual underground phase with a warned exit quake and collapsing tunnel lane.
- Make Zoomer strafe-sprint rather than copying Skitter's long committed charge. Spitter launches curving acid hooks, Sapper plants staggered mines, and Leech channels a breakable health-draining tether.
- Ashwing creates a delayed ember nova when resurrected, and Riot's frontal shield rotates slowly enough to flank.
- Update in-game enemy descriptions and warnings; add automated enemy-identity, boss, Skitter and rendering regressions.
- Android release publishing now waits for the Windows GitHub Release to become available rather than racing and failing.

## v0.1.52 — Hype Totem shield aura actually protects nearby enemies

- Fix Hype Totem's "SHIELDS NEARBY" aura: protected enemies now take **50% less direct damage and 50% less burn/poison/bleed damage-over-time**. Previously status ticks bypassed the shield, making it appear ineffective with several weapon builds.
- Ensure a newly spawned Hype Totem protects allies immediately. Clear stale totem references when changing sectors or starting a new run; destroying or charming a totem immediately removes its protection.
- Render a subtle blue protective outline on allied enemies within the 230-unit aura and an inexpensive shield-impact flash when attacks are absorbed. Clarify the totem's label and Bestiary counterplay description.
- Overlapping Hype Totems **do not** stack their damage reduction; the totem itself is not protected.
- Add `tools/hype_totem_aura_test.gd` to compatibility and Windows release suites. Combat regression and graphical-world smoke checks pass.
- No weapon balance, mutation schedule, boss attacks or updater changes.

## v0.1.51 — Mutation Book and controlled per-run enemy fusions

- Introduce **18 named mutations** as designed enemy fusions rather than randomly combining every pair of previously encountered monsters. Each inherits only a single anatomical feature, preserving the original face and readable silhouette.
- **Normal:** One new mutation introduced every four sectors, starting at sector 16. Mutation encounters ramp gently from 5% at sector 16 to 14% at sector 40, with seven recipes eligible by sector 40.
- **Hard:** One new mutation every two sectors from sector 16, with encounter chance rising from 19% toward ~45% by sector 40, where thirteen recipes are eligible.
- **Spawn unlocks last for that run only.** New runs always start with the entire mutation pool locked regardless of previous victories, kills, Bestiary discoveries or sector records. A future recipe cannot spawn before its introduction.
- Add a dedicated **Mutation Book** entry to desktop and mobile menus: locked entries, run-specific availability, introduction-sector requirements (Normal/Hard), and permanent discovered enemies with kill counts, stats and actionable combat advice.
- Mutations adopt one bounded, telegraphed attack identity (predicted flank, mines, echo volley, or brood generation) instead of stacking both parents' complete AI. Previously discovered historical hybrids remain readable in old saves but do not join the new random encounter pool.
- Add regression tests for per-run lock resets, difficulty-specific unlock cadence, old-save discovery migration and gameplay compatibility; validated with a graphical world smoke test.
- Weapons, cards, bosses, updater and existing save-file formats remain compatible.

## v0.1.50 — Boss combat overhaul: eight unique bosses

- Add four individually designed bosses to the active rotation: **Coil Queen** (constricting lane patterns and coiling volleys), **Glass Oracle** (crossing laser lattices and mirrored barrages), **Void Weaver** (portal repositioning, void traps and Burrower summons), and **Dread Engine** (heavy piston lanes, shock bursts and Sappers).
- Chonkzilla, Heli-Copter, Necro-Dad and King Blob each gain two new special attacks, bringing their cycles to six distinct patterns, with faster cadence and harder 65%/32% HP phases.
- Introduce collision-accurate, fully telegraphed beam lanes, staggered dodge corridors, fixed cross-hair attacks and projectile circles that retain genuine escape gaps. Large warnings resolve where they appeared; they never secretly track the player after locking.
- Mirror Mimics predict player motion and fire independent multi-shot attacks and faster reactive counter-volley patterns. Burrowers tunnel faster, land at a visibly marked predicted destination and trigger a dodgeable delayed collapse; late-game Burrowers also fire flanking shots.
- Give the new bosses distinct procedurally rendered appearances and animated accents. Projectiles use existing boss audio palettes to avoid asset bloat.
- Add `tools/boss_aggression_test.gd`, validating all eight boss patterns and elite attacks, with projectile/telegraph caps in pull-request and Windows release CI. Graphical Godot rendering checks passed.
- No gun stats, card mechanics, save data or in-place updater changes.

## v0.1.49 — Clearer weapon descriptions and upgrade previews

- Rewrite all 22 guns' base descriptions to explain their unique firing patterns and effects in plain, specific language.
- Rewrite Level 3, Level 5 and Evolution explanations, including accurate numeric bonuses and conditions.
- In Arsenal, show short Level 5 summaries instead of clipping long paragraphs.
- In Collection, display full base, Level 3, Level 5 and Evolution details together in a bounded weapon inspector.
- Give weapon-related level-up cards more room for text by reducing decorative artwork height.
- Add automated copy-coverage and UI integration tests. No weapon stats, status effects, firing behavior or balance were changed.

## v0.1.48 — Fix invisible gameplay world

- Fix a GDScript parse error in `scripts/Visuals.gd` that prevented Godot from attaching the world renderer. Symptoms: the HUD remained visible but the road, player, enemies, pickups and attacks disappeared into the background.
- Preserve enemy anatomical mixing by renaming the incompatible hybrid-drawing parameter identifiers; no new enemy behavior or balance changes.
- Add a graphical Xvfb/Godot regression test that instantiates the real game scene and verifies multiple visible road pixels instead of a blank viewport.
- Add a headless scene-compile regression to the Windows release gate so a broken `Visuals.gd` can no longer silently ship despite other gameplay tests passing.
- Keep Cinder's v0.1.47 nerf, Infinite Ammo, modern enemy generation and updater persistence unchanged.

## v0.1.47 — Cinder balance and repository branch consolidation

- Adjust Cinder's base direct flame tick from 4.0 to 3.6 damage (-10%) and its maximum enemies hit per tick from 24 to 20; keep its 30-Hz fire rhythm, range, fuel, burn application and visual flame effects unchanged.
- Add a documented base-DPS comparison for all 22 guns in `docs/WEAPON_DPS_AUDIT.md`; distinguish ideal single-target direct DPS from crowd damage, status procs, recall weapons and sustained heat weapons.
- Add `tools/cinder_balance_test.gd` to the Windows release regression checks. Preserve Hydra Bow's original non-poison splitting bolts.
- Audit four non-default branches. The Infinite Ammo work is already merged; updater changes are byte-for-byte present on main; old weapon-overflow and dynamic-enemy implementations are superseded by newer main. Do not merge old Nurse/Larry behavior back into the game.
- After a verified v0.1.47 Windows release is published, prune only the four audited obsolete branch heads that have not changed since inspection; refuse to delete any concurrently updated branch.

## v0.1.46 — Infinite Ammo and weapon-card compatibility

- Preserve Infinite Ammo without consuming normal magazines, interrupting attacks, or restarting reloads when firing. Manual reload cannot reintroduce ammunition delays.
- Reload-triggered cards (Fan the Hammer, Shell Shock, Kazoo) activate on rate-limited virtual magazine cycles under Infinite Ammo. Heatless max-level Prism Beam also supports reload-triggered cards; returning discs and boomerangs still require their real physical recall slots.
- Returning weapons activate reload-related cards on successful catches without Infinite Ammo. Tactical Roll with Infinite Ammo grants a short +15% fire-rate bonus rather than an irrelevant instant refill.
- Arc Caster translates extra wall bounces into up to two chain jumps, and Splinter/Cluster into up to two controlled electric forks.
- Rocket and grenade ricochets produce bounded weaker secondary blast transfers; bubbles can link one weaker extra trap.
- Excess pierce gains a capped payoff on Gauss Lance and returning weapons; Tight Choke reduces multishot fan spread even on zero-spread weapons.
- Add targeted compatibility regressions and a Godot headless pull-request test workflow. Retain the v0.1.45 persistent in-place Windows updater.

## v0.1.45 — Persistent Windows in-game updater

- FIX: The in-game installer previously placed updated Slime Hour files only in `%LOCALAPPDATA%\\SlimeHour\\versions\\vX.Y.Z` and launched that temporary copy. Restarting from the original desktop shortcut reopened the outdated executable and appeared to undo the update.
- After the old game exits, install the verified release into the ORIGINAL game folder (`SlimeHour.exe`, `SlimeHour.pck`, helper scripts, launcher and manifest). The existing shortcut now points to the updated files across restarts.
- Stage every file on the original installation's volume. Replace files atomically and restore backups on a failed replacement or failed manifest verification, leaving unrelated files intact.
- Preserve a verified update ZIP on installation failure so a retry does not require another 200–300 MiB download. Remove the archive only after successful installation.
- Keep chunk-based delta reconstruction and SHA-256 verification. Add PowerShell regression tests that validate full and delta in-place installations, persistent version manifests, unrelated-file preservation and intentional mid-install rollback.
- ONE-TIME MIGRATION: Copies installed by the old (v0.1.44 or earlier) updater are still launched from AppData. Since that already-shipped helper cannot retrofit itself, close the game and extract the v0.1.45 FULL release ZIP over the ORIGINAL game folder once. From then on future in-game updates replace the original installation automatically. Saves and settings remain in the user's data directory.

## v0.1.44 — Final hybrid integrity and 22-weapon projectile-card translations

- Stabilize hybrid parent roles across roll order and historical saves; vary the body donor deterministically across pairings to avoid late-sector crowds dominated by one starter silhouette. Each hybrid still inherits a single peripheral anatomical trait instead of another full face.
- Snake Shot, Wobbly Bullets, and Spin to Win use bounded physical trajectory changes on conventional bullets, reduced wobble on grenades, bowling balls, swarms and other heavy/summon actors, and outward-only movement on returning discs and boomerangs.
- Hitscan Prism Beam, Gauss Lance and Arc Caster convert Snake-style wobbles into synchronized sweeping aim geometry, never invisible bullet entities; Arc Caster converts piercing modifiers into capped extra chain jumps.
- Speed cards enhance beam/rail/electric reach; Road Rage accelerates downrange beam/rail damage and slightly strengthens later Tesla chain hops. Beam visual length and actual hit line use the same adjusted reach.
- Explain Snake, trajectories, bounce, split, pierce, velocity and acceleration for each equipped weapon in card tooltips; continue excluding Return to Sender when all equipped weapons have no valid return physics.
- Add a 22-gun by 30-projectile-card regression suite and enforce it, the anatomical hybrid tests and barrel ignition tests in the Windows release workflow.

## v0.1.43 — Anatomical enemy hybrids and one consistent unlit barrel

- Remove Nurse and Laser Larry from the actual 27-enemy database, not just the default spawn table. Retire all existing Nurse/Larry combinations during old-profile migration; preserve unrelated Bestiary history.
- Remove Nurse/Larry from automated sector and soak spawns so testing cannot reintroduce them.
- Replace whole-face/"chimera" compositing with a single inherited secondary-parent body part: ears, horns, antennae, wings, tail, shell, buds, shoulder armor, head crest, spikes, legs, claws, fins or tentacles. The base monster keeps its face and distinctive silhouette.
- Preserve both parents' existing combat abilities, but introduce named anatomical variants and selectable inherited features per encounter. Sector-40 hybrid frequency increases gradually to 43%; new main enemy types still appear on their own before becoming eligible to mix.
- Bestiary thumbnails and enemy portraits use the same inherited part system; hybrid descriptions explain the inherited feature and danger instead of generic pasted-face mashups.
- A barrel now uses ONE identical unlit sprite whether armed or dormant. The burning fuse is added as a small overlay only after a real hit, followed by the existing countdown and explosion.
- Add regression coverage for all 210 possible main-enemy pairings, retired profile entries, parent-face preservation and anatomical rendering. Update the barrel sprite consistency test.

## v0.1.42 — Unlit explosive barrels and consistent hits from all 22 guns

- Add a dedicated unlit explosive barrel SVG; the default world sprite has no burning fuse or ignition spark. Swap to the original lit artwork only when a weapon, dash or explosion actually arms the barrel.
- Fix missing barrel hit detection for continuous Cinder flame cones, Prism Beam hitscan segments and refractions, Arc Caster lightning chains (including barrels without nearby enemies), and Gauss Lance's rail segments.
- Give Gauss Lance's lingering ionized corridor and weapon shockwaves the same barrel ignition behavior.
- Preserve the existing 0.85-second warning fuse and chain reactions rather than detonating immediately on contact. Ignore falling/previously armed barrels and require true geometrical intersection.
- Add a dedicated barrel-weapon regression script covering projectile guns, each nonprojectile weapon type, barrel geometry, the fuse timer and unlit/lit asset selection.

## v0.1.41 — Readable gun notes, identifiable evolutions, fixed ion scars and safe update caching

- Rebuild the Collection's desktop weapon inspector so Level 3 and Level 5 notes fit inside the right-hand panel, fully above the Back button. Portrait gun inspection also reserves space for upgrade notes.
- Replace the stale “bullet count stays unchanged” evolution descriptions with 22 actual weapon-specific traits and individually colored projectile styles.
- Cyclone X now tightens its spread dramatically while firing, retains accuracy when releasing the trigger, and fires a penetrating turquoise tracer every sixth trigger. Breachmaster tightens the shotgun choke and hits harder; evolved minigun, sniper, grenade, bee, nailgun, bubble, Hydra, snow, and other weapons gain their listed distinctive effects.
- Gauss Lance's Level 5 Ion Scar now visibly occupies a pulsing electrically active corridor, with line-segment radius and endpoint collision matching its drawn width for 1.5 seconds.
- The in-game updater now keeps previously downloaded ZIP archives until the SHA-256 checksum is fetched, verifies both cached size and digest, and avoids downloading verified identical archives again. It also refuses to download a release not newer than the running game.
- Expand collection layout, weapon identity, ion-zone and updater-cache regression checks.

## v0.1.40 — Restored Cinder fire and recognizable Swarmcaster bees

- Bring back Cinder's original flowing flame-puff look: moving orange/red/yellow overlapping combustion sprites, glowing hot cores and slight curling turbulence, replacing triangular/fanned weapon shapes.
- Cinder's particles live only in the bounded visual FX array (2-4 per firing tick, shared global cap). The flamethrower still uses one efficient cone for actual damage with no physics bullet objects.
- Redraw the Swarmcaster's projectile as a clearly readable bee: yellow abdomen with two black bands, translucent fluttering wings, round head, eyes, antennae, and stinger. Existing bee homing and poison damage remain unchanged.
- Add regression coverage for projectile-free flame damage, moving flame visuals and striped bee rendering.

## v0.1.39 — 22-weapon resource identities and corrected Cinder flame rendering

- Constrain every weapon to its own magazine, fuel, physical return slot, and per-volley budget. Deadeye always holds six rounds and Gauss Lance three charge cells.
- All 22 IDs define distinct overflow specialties. Overflow improves accuracy, staggers, spin retention, blasts, arcs, burns, returns, charge, poison, impact, pinning, traps, banking, tracking or freezing, not one universal damage stat.
- Prism Beam interprets magazine bonuses as up to 4.5 seconds of heat reserve; reload upgrades shorten cooling. At Level 5 otherwise obsolete cooling/heat cards convert into capped beam focus.
- Add live actor caps for bees, heavy balls, chickens, trap bubbles, ricochets and snowballs; overflow reinforces actors rather than multiplying expensive scene objects.
- Service Nine's triple-damage special shot works every 12 real shots, including with larger magazines and Infinite Ammo. Burst/Echo attacks do not increment that cadence.
- Hydra can spawn no more than eight shards from one root bolt. Return to Sender rocket aftershocks cannot repeat the full thermobaric collapse.
- Cinder renders a layered soft flame plume instead of a triangle with a giant end arc, and no longer displays bullet-style Double Tap particles for its flame cone. Continuous flame attacks remain collision-free and share the damage-cone geometry.
- Expand resource regressions, correct weapon descriptions, and fix the false-failure compatibility test result.

## v0.1.38 — Weapon compatibility, legendary Hydra, and procedural enemy variety

- Railgun supports HOLD ATTACK: repeatedly wind up and fire while the trigger is held, interrupted only by reload or pause. No mandatory trigger release or artificial post-shot cooldown.
- Introduce per-weapon magazine, return-slot, fuel, and volley budgets for all 22 weapon IDs. Revolver hard-stops at six rounds. Excess capacity cards convert to at most +18% damage, rather than silently expanding hardware.
- Hydra card becomes one-stack Legendary, retaining +2 projectiles and +1 parallel lane; large explosive volleys are explicitly capped, with at most +18% limited overflow compensation.
- Return to Sender becomes Legendary. Returning explosive payloads have weaker secondary blast/radius and cannot infinitely recurse. It is unavailable for a loadout with only returning or nonprojectile weapons.
- Burst/Echo on explosive weapons no longer trigger full-power multiplicative splash attacks. Other weapons retain their prior firing patterns subject to resource limits.
- Card selection descriptions display active weapon interpretation for ammo, Hydra, homing, Return to Sender, and Infinite Ammo.
- Remove Nurse and Laser Larry from active new-run introductions while preserving their data for historical encounters and saves. New base enemies (Skitter/Sapper/Mirror/Burrower/Ashwing/Siren, etc.) are introduced before random two-parent chimeras unlock at sector 16.
- Give generated enemy chimeras pair-specific armor geometry, visual markings, naming and short repeat protection. Pairing remains canonical and any two introduced base types can combine.
- Add a new stylized Hydra card illustration via assets/cards/hydra.svg, used in card selection, collection and HUD.
- Add complete 22-weapon compatibility tests and update staged roster regression checks.

## v0.1.37 — Modifiers adapted to physical and nonprojectile weapon systems

- Returning-disc and boomerang homing, curve, and wave effects apply only on the outward trip. The return trip always steers home; no card may silently break retrieval.
- Double Tap increases returning-weapon capacity through the existing explicit slot rule, while Twin Barrels, rear-fire, and side-fire cards strengthen a single physical throw instead of secretly creating additional uncounted blades.
- Burst Mode and Echo Chamber on returning weapons store limited bonus power for the next actual throw; they do not spawn free unlimited blades.
- Homing applies narrow aim correction to instant rail, sustained lasers, chain arcs, and flamethrower cones; physical projectiles retain their real homing steering.
- Flamethrowers use one real damage cone rather than many invisible flame projectiles. Double Tap improves stream saturation, parallel fire widens coverage, and rear/side fire creates weak directional vents instead of duplicate full-strength streams.
- Split and ricochet cards produce capped secondary heat transfers. Bounce can generate one weakened wall-reflected flame sheet, while curved/wavy rounds gently oscillate the cone. Size improves cone width, projectile speed extends reach slightly, piercing extends penetration depth, and acceleration increases heat farther downrange.
- Add card synergy regressions to guard the 22-weapon resource behavior against further generic projectile changes.

## v0.1.36 — Weapon resource identities and correct evolution bonuses

- Evolution never adds a generic projectile to every gun: magazine guns gain firing speed, rockets and grenades gain blast radius, laser gains reach, minigun spools faster, and rail charges faster.
- Razor Disc remains limited to two returning slots by default; Returner has one. Both wait for their blades to return rather than reloading. Evolution makes their recall travel 30% faster and increases damage, without increasing the number in flight.
- Cinder's flamethrower is a real damage cone using fuel, not a stream of invisible 30Hz projectile colliders. Its transparent widening fire cone is drawn efficiently using one temporary graphic per fuel tick.
- Cinder evolution adds 25% to reach and tank capacity; laser continues to use heat/overheat instead of an ammo magazine; rail retains a three-round charged magazine.
- All 22 evolution descriptions now state the real weapon-specific bonuses in the level-up UI.
- Add dedicated 22-gun resource/evolution regression tests to Windows CI.

## v0.1.35 — Collection grid, natural scrolling and corrected card art

- Replace the desktop four-card horizontal sliding strip with an eight-card two-row gallery; retain category tabs and the fixed selected/hover detail pane.
- Mouse wheel and arrow/PageUp/PageDown/Home/End keys scroll the full category vertically by row; a visible proportional scrollbar supports direct jumps; remove old Previous/Next paging controls.
- Portrait collection now shows a two-column vertical gallery with touch swipe scrolling and a tap-to-expand details overlay, without sideways-clipped cards.
- Scale all card art to *contain* its original aspect ratio inside its image frame; increase collection card art space and selected-card art height, avoiding the old squashed horizontal stretch.
- The total item count and visible range are always shown; every one of the 300 cards and 22 guns remains reachable within its category.
- Add grid reachability and aspect-ratio tests to the Windows release workflow.

## v0.1.34 — Twenty-two signature max-level weapon mechanics

- Replace generic Level 5 damage splashes, multishot counts, reload triggers and extra ricochets with separate behavioral signatures for all 22 guns.
- Service Nine's sixth shot now fires a marking piercing tracer; Deadeye crits stun; Breacher gives point-blank crowd stagger; Cyclone suppresses/slow; Vulcan at full spin shoves enemies sideways; Longshot gains collateral damage across successive pierced targets.
- Payload's explosion gets a telegraphed non-damaging vacuum phase rather than just a fire puddle. Rebound banks into a guided grenade, retaining its Level 3 bomblets.
- Prism Beam now refracts at first impact, Arc Caster overloads every third chained victim, Cinder spreads ember links instead of death explosions.
- Razor Disc's return pulls in monsters. Returner's caught boomerangs build power up to +45%, with misses resetting the streak. Gauss Lance keeps its charged persistent lightning corridor.
- Swarmcaster uses true homing bee projectiles and pheromone target prioritization. Impact Cannon's third strike creates a kinetic blast. Rivet Driver tethers enemies, Fowl Play panics foes into infighting, Pressure Pop transfers its trap, Ricochet charges banked stun, Hydra Bow fragments hunt fresh targets, and Frostcaster lays down a freezing whiteout zone.
- Update all in-game Level 5 descriptions to describe these actual effects, and add a dedicated weapon-signature regression test to the Windows build.

## v0.1.33 — Weapon identities and playable starting characters

- Replace placeholder and overly jokey gun names with concise distinctive names, without changing stable weapon IDs or artwork paths.
- Service Nine (formerly Peashooter) keeps its accurate baseline and triple-damage last round. Cyclone SMG now tightens its spray after sustained fire.
- Gauss Lance (Railgun) charges for a single immediate hitscan attack. It no longer adds a second firing cooldown after charging. On mouse/keyboard each hold fires one charged shot until released; accessibility auto-fire and touch repeat charges automatically. Its magazine still reloads normally.
- Character selection before Standard or Hard Mode: Scout / Service Nine (+4% sidearm damage), Ember / Cinder (+6% flamethrower damage, -3% run XP), Ace / Deadeye (+3 percentage points revolver crit, -2% run XP), Vector / Cyclone (+5% SMG fire rate, -3% run XP), Coil / Gauss Lance (-5% charge time, -5% run XP).
- Character affinity applies only to the listed signature weapon, including if found later; it does not globally increase damage. All five share standard HP, dashes, economy rules and permanent-unlock progress.
- Retain the previously selected runner in user settings, fallback safely for older saves, and apply distinct costume colors in combat.
- Add character and gun regression tests to the Windows release workflow.

## v0.1.29 — Midgame pressure rebalance and four new mob families

- Smooth the rapid HP scaling at Sectors 9–11, reduce their attack damage, soften elite frequency, and delay double-affix elites until Sector 13.
- Limit simultaneous enemies through the midgame bottleneck and stream Slime Hour rush enemies over time rather than spawning six every frame.
- Introduce an additional enemy at each existing five-sector roster milestone: Ashwing (6), Mirror Mimic (11), Burrower (16), Siren (21).
- Ashwing resurrects once with a 1.35-second visible cocoon and never duplicates loot. Mirror Mimic counters weapon fire with a delayed aim-line shot. Burrower marks a landing spot then ambushes after a warning. Siren buffs nearby ordinary mobs for a short period, never bosses.
- Draw distinctive enemy silhouettes and ability telegraphs, add bestiary strategies, and guard their progression with new automated checks.

## v0.1.28 — Opposite-hand pistol silhouettes

- Mirror the off-hand weapon grip relative to the primary weapon, so two equipped guns read as L and reverse-L shapes around the MC.
- Update sprite-angle compensation per mirrored hand to keep sniper and other barrels accurately on target; center-slot sprites retain their directional behavior.
- Test both hand grips and muzzle directions for multiple weapon types and four hero facings.
- Includes horizontal Collection browsing and corrected full/incremental in-game downloads from v0.1.26–v0.1.27.

## v0.1.27 — Mirrored gun-holding pose and full-update transfer repair

- Add mirrored L-shaped left and reverse-L-shaped right support arms and hands to the MC, matching the weapons' existing muzzle locations, including a center-slot brace.
- Preserve exact cursor, beam and projectile alignment; the holding arms only affect the visuals and are tested with four aim directions.
- Fix the HTTP 200 / 0% download failure for full Windows archives: Godot's HTTPRequest `body_size_limit = 0` disallowed all bytes. Use -1 for unlimited streaming instead, retaining a bounded memory fallback for small incremental patches.
- Extend headless regression tests for mirrored gun grips, forearm bends, and large-file download limits.

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
