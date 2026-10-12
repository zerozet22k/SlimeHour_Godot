# Monster behavior graft system (v0.1.105)

## What actually runs

A fusion is **receiver/body + donor/giver**, and order matters. The receiver keeps its normal combat AI, base movement rules, signature attack, counters, and visually identifiable body. The donor exports exactly one real behavioral module from `data/mutation_modules.json`. `scripts/FusionGenome.gd` interprets that module via reusable Godot events and tracks its cooldown, attack warnings, support effects, and recovery. `scripts/EnemyMixes.gd` composes stats and validates compatibility, without containing pair-specific combat rules.

The old effect/shape parser in `MutationKit.gd` and `data/fusion.json` remains as legacy code for compatibility and development history; the **live enemy AI uses FusionGenome** rather than executing that old pattern generator.

### The 25 donor kits

| Species | Donated gameplay mechanic |
|---|---|
| Blob | One ally-link protection |
| Zoomer | Distinct lateral orbit sprint |
| Chonk | Heavy belly-shock with recovery |
| Spitter | One continuous damaging acid ribbon |
| Kaboomba | One delayed fuse, without recursive bomblets |
| Mitosis | One spawned Mini |
| Mini | Evasive lateral reposition |
| Riot | Temporary directional shield |
| Bull | Time-limited forceful charge |
| Mama | Breakable hatching egg |
| Mortar | One predicted artillery shell |
| Totem | Visible ally-protection link |
| Blinky | Teleported departure-to-arrival slash |
| Tick | Real removable attachment to the hero |
| Goblin | Conditional close-range gold theft |
| Ashwing | One additional breakable egg resurrection |
| Mirror | Reflective guard with cooldown |
| Burrower | Temporary underground approach, exposed on emergence |
| Siren | Nearby ally-command haste pulse |
| Skitter | A committed single-ricochet charge and ricocheting ammunition |
| Sapper | Sticky explosive projectile |
| Lancer | Fast piercing spear |
| Leech | Range/cover-breakable health conduit |
| Nurse | Interruptible targeted ally healing |
| Laser Larry | Single warned beam with overheat |

Ashwing's **base** resurrection remains unlimited; its **donated** resurrection is limited once per fused monster. Skitter's base dash still ricochets up to three times; its donated version is one bounce. Lancer keeps two attack modes as a receiver (sweep nearby, throw far away).

## Compatibility, generation, and balance

- The receiver exports capabilities in `mutation_modules.json` such as `mobile`, `projectile`, `contact`, and `support`. The donor exports `requires_any`, `cost`, and `cooldown`. The generator rejects incompatible grafts rather than replacing them with generic lasers or explosions.
- 25 species produce **592 mechanically compatible ordered pairs** (from 600 possible without same-species fusions). Eight incompatible cases are stationary Totem receivers with movement-dependent donors. These numbers are checked by the automated source-level integration suite.
- Each fresh run samples up to **18 distinct unordered fusion recipes** from the compatible roster, with **two possible body orders**. Unlocks begin at sector 25. Normal reveals another every three sectors; Hard every two sectors.
- A Normal sector permits **2 active pairs**, **2 living mutants**, and a **5-point encounter budget**. Hard permits **3 active pairs**, **3 living mutants**, and a **10-point budget**. A donor with threat cost 4+ spends two encounter units; others spend one. The most recent recipe stays active; other unlocked recipes rotate. Standard enemies continue spawning independently.
- The body's normal damage remains its body's damage; a separate `graft_dmg` lets 0-damage Totem/Goblin bodies inherit functional offensive attacks without changing their normal contact behavior.
- Rebirths, minions, self-movement and projectile effects have independent cooldowns or limits. An attack can trigger a nearly-ready graft, rather than every effect being a clockwork bullet burst.

## How to find a broken combination

1. Open **F3 Debug Lab > ENEMIES > MUTATIONS**. Select the body monster first and the donor monster second. Swap the selection order to compare the inverse mutant.
2. Watch the monster's **normal base attack** (it must remain recognizable), the **single timed graft** (or a passive trigger such as reflection/rebirth), warning geometry, damage/status, and recovery. Some support abilities need another nearby monster to show their effect.
3. Specific counterplay checks: **Skitter graft** stops after its bounded charge and one ricochet; **Mirror graft** reflects again after cooldown; **Ashwing donor** permits only one rebirth; **Tick graft** detaches on dash/bash; **Burrower graft** leaves an exposed recovery; **Spitter graft** paints a continuous red ribbon; **Leech graft** breaks at range or behind cover; **Nurse graft** can be interrupted.
4. If the combination refuses to spawn, inspect `FusionGenome.compatible(body, donor)`: incompatible behavior is **intentionally rejected**, never silently changed to an unrelated attack.

### Automated Godot 4.7.2 checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/fusion_genome_test.gd
godot --headless --path . --script tools/mutation_progression_test.gd
godot --headless --path . --script tools/enemy_identity_test.gd
godot --headless --path . --script tools/monster_rework_test.gd
godot --headless --path . --script tools/skitter_dash_test.gd
```

These tests enumerate and validate compatibility, data, initial casts, select real hazards, cooldown budgets, and base-monster regression cases. **They do not mean all 592 pairs have been playtested end-to-end.** Future work should expand scenario simulations and human playtests for movement/obstacle interactions and special-case counterplay. Add new species by defining a new donor module plus receiver capabilities, not by writing `if monsterA + monsterB` branches.
