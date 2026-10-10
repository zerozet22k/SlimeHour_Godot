# Slime Hour — Base weapon damage audit (v0.1.47)

This is a **rough base-level theoretical comparison**, calculated from `data/weapons.json` and `scripts/Weapons.gd` with no cards, rarity/tier bonuses, crits, evolutions, bonus enemies hit, missed pellets, ricochets, or status damage. **Do not treat these as measured gameplay DPS.** Primary-target DPS versus crowd-clearing strength is a major distinction.

For ordinary magazine guns:
- Raw direct DPS while firing = base damage × base fire rate × nominal pellets per volley.
- Ideal sustained direct DPS = damage per magazine ÷ (magazine ÷ fire rate + reload seconds).
- `Gauss Lance` instead fires once per **0.7-second charge** at level 1, not the `rate` JSON value; this calculation accounts for its 3 cells and 2.2-second reload.
- `Prism Beam` uses heat/cooling, not a normal magazine. `Razor Disc` and `Returner` reuse real catch slots, so no fair numerical sustained figure is given.
- For `Vulcan`, 120 is **fully spun-up** firing DPS; spin ramp makes actual DPS lower. `Breacher` assumes every pellet connects on one enemy.

| Base weapon | Firing direct DPS | Ideal sustained direct DPS | Important exclusions |
|---|---:|---:|---|
| Service Nine | 48.0 | 37.4 | Excludes secondary hits and status effects |
| Deadeye | 79.2 | 51.1 | Excludes secondary hits and status effects |
| Breacher | 85.0 | 59.8 | Requires all 7 pellets to land |
| Cyclone | 72.0 | 49.7 | Excludes secondary hits and status effects |
| Vulcan | 120.0 | 90.6 | Excludes secondary hits and status effects |
| Longshot | 80.8 | 58.4 | Excludes secondary hits and status effects |
| Payload | 50.6 | 29.8 | Excludes blast/AoE |
| Rebound | 58.8 | 42.8 | Excludes blast/AoE |
| Prism Beam | 98.0 | — | Heat and cooldown; sustained not comparable |
| Arc Caster | 48.0 | 37.5 | Primary target only; chaining omitted |
| Cinder | 108.0 | 69.9 | Excludes burn; up to 20 cone targets |
| Razor Disc | 66.0 | — | Physical return slots; sustained depends on catch timing |
| Returner | 56.0 | — | Physical return slots; sustained depends on catch timing |
| Gauss Lance | 214.3 | 104.7 | Actual 0.7s charge, not JSON rate; no extra line hits |
| Swarmcaster | 33.6 | 25.6 | Excludes poison and multiple pierce hits |
| Impact Cannon | 36.0 | 22.5 | Excludes secondary hits and status effects |
| Rivet Driver | 81.0 | 59.6 | Excludes secondary hits and status effects |
| Fowl Play | 38.4 | 25.4 | Excludes secondary hits and status effects |
| Pressure Pop | 54.0 | 37.2 | Excludes secondary hits and status effects |
| Ricochet | 65.0 | 47.3 | Excludes secondary hits and status effects |
| Hydra Bow | 60.0 | 41.9 | Excludes 3–8 splitting fragments |
| Frostcaster | 36.0 | 26.7 | Excludes freeze and size growth |

## Cinder: measured code-path math, not simulation

- Before: 4 direct damage per flame tick × 30 ticks/s = **120 DPS firing**.
- After: 3.6 × 30 = **108 DPS firing** (**-10%**).
- Base fuel 110 ÷ 30 = **3.67 seconds** continuously firing, followed by **2 seconds** reload.
- Before: 4 × 110 ÷ (110/30 + 2) = **77.65 ideal sustained direct DPS**.
- After: 3.6 × 110 ÷ (110/30 + 2) = **69.88 ideal sustained direct DPS**.
- The cone's per-tick enemy hit cap changes **24 → 20**, limiting peak dense-crowd hit throughput by **16.7%**, on top of the 10% direct-damage decrease. Theoretical instantaneous 20-enemy total is 108 × 20 = **2160 direct damage/s** *if all 20 remain in range and cone*, before status effects.
- Innate burn still refreshes on each hit. At unmodified scale its flat component is **1.6 damage per 0.25-second status tick = 6.4 burn DPS per affected enemy**, plus the target-HP component. Burn does not stack per flame tick; duration is refreshed. This makes nominal direct DPS an incomplete balance indicator.
- The 30-Hz animation/firing rhythm, flame range, geometry, fuel, reload, and burn identity are unchanged.

**Interpretation:** Cinder's pressure is primarily excellent multi-target coverage and reliable burn application rather than uniquely high single-target raw DPS; this modest nerf trims both the single-target and crowd extremes without changing its handling. Future decisions should be based on frame-by-frame playtests across sector levels, per-weapon hit counts, and status contribution rather than this theoretical table alone.

**Branch audit:** older updater and weapon-overflow changes are already present or superseded on current `main`. The obsolete enemy branch includes retired Nurse/Larry data and cannot safely be wholesale-merged. Their branch tips were audited before a commit-SHA-guarded cleanup in the v0.1.47 release pipeline.
