# Slime Hour: projectile VFX language

This feature extends the existing dictionary-driven projectile renderer. It does not create extra Nodes or particles for each bullet and it does not change projectile damage or game balance.

## Changed files

- scripts/ProjectileVfx.gd: palette, event router, lifetimes and effect budget.
- scripts/Weapons.gd: fired-pattern tags for Double Tap, Parallel and Burst; rail/beam hit FX.
- scripts/Combat.gd: critical, pierce, split, ricochet, projectile expiry, barrel hits and boss projectile FX.
- scripts/Visuals.gd: distinctive trails, effects, boss bullets, laser contacts and timed explosion telegraphs.
- scripts/Main.gd and scripts/Hud.gd: LOW / MEDIUM / HIGH VFX quality selection, saved with game settings.

## VFX identities

| Combat signal | Visual language |
| --- | --- |
| Normal bullet | Compact warm tail and impact spark |
| Double Tap | Staggered twin strokes and twin muzzle flash |
| Parallel Shot | Two parallel ruled travel lanes and dual muzzle rail |
| SMG / Minigun | Tight cool-color high-velocity tracer |
| Shotgun / Nailgun | Wider amber heavy impact |
| Fire | Layered orange flame and embers |
| Poison | Lime slime droplets, toxic dots on impact |
| Freeze | Cyan shards, crystalline rays |
| Shock / Tesla | Jagged white-blue trail, chain hit flash |
| Rocket / Grenade | Ember exhaust with normal blast shockwave |
| Rail / Sniper | Narrow high-energy streak and pierce slice |
| Laser | Shimmering core and contact hotspot |
| Fragment | Small green shard, brief split radial pop |
| Wall bounce / ricochet | Distinct directional corner spark |
| Critical | Golden star that only appears on actual critical hits |
| Barrel / Bomber | Fuse, radial warning and delayed blast |
| Boss shots | Ember / void / frost / storm signatures |

## Performance / readability

Travel accents are optional. Projectile geometry and hitbox silhouettes remain visible with particles disabled. Crits, impacts, bounce, split and boss attack tells are retained. There is one shared budget for transient effects. Low quality decreases travel details, and offscreen spawns are culled.

## Verification

Run from the repo root with Godot installed:

    godot --headless --path . --script res://tests/test_projectile_vfx.gd

Also playtest Double Tap and Parallel Shot together, rapid-fire builds, elemental proc cards, boss battles, barrel chains, laser/rail weapons, low/high VFX and particles disabled. Tests are not claimed to have passed until actually executed.


## Matching synthesized sound effects

The projectile VFX are now accompanied by 39 dedicated original synthesized SFX clips in `scripts/Sfx.gd`.

- One firing sound per volley, NOT per pellet. Double Tap is two staggered transients in one sample; Parallel Shot is two simultaneous layers. Burst has its own compact repeat sample.
- Peashooter, SMG/minigun, heavy bullets, shotgun, sniper, sustained laser, railgun charge and discharge, flamethrower, poison/bee, ice, Tesla, rocket, bubbles, pinball and void attacks each receive recognizable sounds.
- Impact sounds distinguish regular hits, heavy hits, pierce, fire, toxic, frost, shock, water and void. Critical hits have their own higher-priority flourish.
- Real burn/poison/freeze/shock applications trigger their proc sound. Bounce, pierce and fragment split trigger their own effects.
- Boss bullets, warnings and blasts have distinct signatures. Barrel fuse warning and layered barrel explosion complement the existing timed kaboom.

The existing 16 player voice pool, per-key cooldown, per-event cooldown, voice cap, pitch variation, and dynamic gain attenuation remain. This is combat audio, not a change to the soundtrack. The existing SFX setting controls volume independently of music.

Run the new headless sound test:

    godot --headless --path . --script res://tests/test_projectile_sfx.gd

For complete verification, run both SFX and VFX smoke scripts and manually check mix clarity with many simultaneous enemies and projectiles. Committed changes are not proof that Godot or a Windows release build passed.
