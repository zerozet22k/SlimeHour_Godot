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
