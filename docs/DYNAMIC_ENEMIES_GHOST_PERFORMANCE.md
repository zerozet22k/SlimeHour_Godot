# Slime Hour — Dynamic enemies, Ghost Walk, readable DoT and pickup performance

## Sector 12 no longer means Nurse + Larry

The seven hardcoded enemy recipes are replaced with lazy, generated hybrids. Every two **different** base enemy types already seen in an earlier sector can combine. For example, any of Nurse, Larry, Skitter, Blob, Zoomer, Spitter, Kaboomba and other unlocked base enemies can be paired. Canonical combination IDs prevent duplicate reversed pairs. This is a general combination system, not a list of seven hand-authored units.

Base enemies start with four starters. After that a new species debuts every two sectors. Combinations become possible from sector 11, but never include a species in its first sector. Hybrid chance begins at ~9% and grows to a max of 25%. Each hybrid inherits the movement and attacks of both parents, with separate internal cooldown states. The game stores only encountered hybrid definitions, and reuses baked parent atlas images to avoid creating N² textures. Existing saved hybrid encounters are retained in the bestiary.

## Four new base enemies

- **Skitter:** flanks laterally, then visibly winds up before a fast dash.
- **Sapper:** predicts the player and plants a delayed, marked explosive circle.
- **Lancer:** locks an aim line, then fires a fast piercing dart.
- **Leechling:** rushes into melee, drains HP only on successful contact, and heals itself.

Each has stats, visual identity, game AI, and a bestiary entry.

## Boss mechanics

- Chonkzilla: new diagonal alternating quake-lane pattern.
- Heli-Copter: additional staggered crossing bomb pattern.
- Necro-Dad: summons Leechlings in a new attack phase.
- King Blob: can summon Skitters to flank the player.

Boss attacks retain warning windows. The new summon patterns check the enemy population cap. Existing boss HP stages remain unchanged.

## Ghost Walk (replaces the old mirrored Ghost Twin effect)

Ghost Walk is now a translucent follower near the hero, with autonomous targeting and low-power lavender shots. One card stack summons one ghost up to three, rather than reflecting weapon volleys across the road.

The old card ID "ghost_twin" is intentionally kept for save/unlock compatibility; its card name and description now say "Ghost Walk". The original defensive "ghost_walk" card is now displayed as "Phase Veil", retaining its invulnerability behavior. The former "ghost" stat is migrated at stat recalculation, so the mirror shooting in Weapons.gd is disabled **without modifying that file**.

## Readable damage ticks

Burn and poison damage now show colored, short, aggregated numbers every 0.5 seconds per enemy/status. Small values show one decimal place. A cap suppresses excessive text during crowded fights. The numbers reflect actual applied DoT damage.

## Performance changes

- Gold coin and XP pickups merge into nearby stacks using a 72-unit spatial grid every 0.45 seconds, rather than doing all-pairs checks each frame.
- Individual gold denominations/counts remain in each stack so gold percentage bonuses have exactly the same rounding and payout as collecting individual coins.
- Coin sprites visually grow with stack size. Hearts and treasure chests never merge.
- Friendly bullet opacity reduced to 62% for ordinary bullet colors.
- Standard bullets reuse the white-dot region of the existing enemy sprite atlas, improving CanvasItem GPU batching.
- Optional projectile trails are sampled when >140 and >280 shots are active; essential bullet bodies and enemy attacks still render. Offscreen transient VFX are culled.
- Dynamic enemy combinations reuse parent sprites rather than creating and uploading hundreds of unique textures.

**GPU utilization caution:** 20 FPS at ~20% GPU strongly suggests CPU simulation/render submission is a possible bottleneck, although GPU percentages alone are not proof. These changes reduce CPU draw/submission and pickup overhead while retaining gameplay; they do not force GPU utilization upward. Godot's 2D rendering already uses the GPU. Confirm the bottleneck with the game's F4 profiler, Godot profiler, a desktop build and driver/cpu measurements.

## Tests

Run from the repo root with Godot 4.x:

    godot --headless --path . --script res://tests/test_dynamic_enemies.gd

Also run the existing projectile VFX and SFX tests. Then play-test sectors 10–16, all boss phases, new unit wind-ups, Ghost Walk with 1–3 stacks, low-end crowds, and both normal/bonus-gold pickup collections.

The code has been source-reviewed. Without an available Godot executable or CI result, do not treat it as a runtime-verified build.
