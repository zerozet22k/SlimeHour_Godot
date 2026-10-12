## v0.1.119 — Every boss hunts you; tides you have to run for

- **Every tide works like Chonkzilla's shockwave ring:**
  - The gap is on the far side from you, so you have to run for it.
  - The waves are denser.
  - Every boss ends its tide with its own 46-bullet ring in its own bullet shape (skulls, shards, gears, stingers…), with the gap turned away from you.
- **Hunter layer:** during every attack, each boss (apart from Chonkzilla) keeps dropping its own hazard where you're heading. It comes faster each phase, and faster still during attacks that would otherwise only spray around the boss.
  - Sky Reaper: bombs
  - Grave Lord: Grave Hands
  - King Blob: jelly splats
  - Coil Queen: venom pools
  - Glass Oracle: shard bursts on your trail
  - Void Weaver: rifts
  - Dread Engine: mortar shells
  - Storm Titan: lightning pillars
  - Hive Empress: honey cells
- **Boss benchmark:** now also counts hits taken, HP per hit, dodges (bullets that came within 40px without hitting), blocked hits and dodge rate. This separates few big hits from many small ones.

## v0.1.118 — Grave Lord, Sky Reaper and Glass Oracle hit harder

Benchmark bots lost about 107% HP against Chonkzilla but only 11% against the Grave Lord, so the soft bosses now hunt you the way Chonkzilla does.

- **Grave Lord:**
  - **New Grave Hands** burst out of the ground where you're heading, during Skull Waltz and Death Bloom.
  - Skull Waltz has 4–6 faster spiral arms.
  - Soul Harvest closes 3–5 tighter rings around you.
  - Grave March sweeps back the other way from phase 2.
  - Wards fire 3-skull homing fans more often but heal it about half as fast.
  - Bots now lose about 98% HP on Normal (was 11%).
- **Sky Reaper:** strafing runs also bomb where you're running, and Missile Salvo fans are wider.
- **Glass Oracle:** mirrors fire more often, and Echo Volley bursts shards along your recent path.

## v0.1.117 — Area-wide boss attacks, tougher early bosses, boss benchmark

- **Boss attacks reach the whole area:**
  - Boss bullets live long enough to cross the full road. Rings and spirals no longer fizzle out halfway.
  - **Chonkzilla's Belly Roll** rolls wall to wall, bouncing off the road edges 3–5 times. Before, it stopped mid-road.
  - **Quake Slam, Kaiju Rage and King Blob's Belly Flop** send shockwave bands out to the far edge of the road.
  - **Goo Mortar** lands globs all over the road, not just around you.
  - **Boulders** roll the full width.
- **Early bosses are tougher:** +50% HP for bosses up to sector 15, tapering off by sector 25. Bots with typical builds killed the Sky Reaper in 15–65s and Chonkzilla in 35–110s.
- **Fixed:** Chonkzilla's Belly Roll could get stuck at the arena edge and flood 1,500+ bullets.
- **New: boss benchmark.** Bots with typical builds for each boss's sector fight every boss, dodging like an average player, with no invulnerability. It reports kill times, wins and deaths, HP lost and peak bullets.
  - Run `run_boss_benchmark.bat` for the live scoreboard and summary table.
  - Run `run_boss_benchmark.bat watch` to watch the bots fight in a window.

## v0.1.116 — Bosses overhaul, two new bosses, UI pass

**Bosses**
- **The fight covers the whole road.** Boss patterns span the full road and the full visible height, so you can't walk out of them.
- **Every boss has its own mechanic.** Most bosses used to share the same "find the safe square" checkerboard. Now:
  - Chonkzilla: meteors stalk your path and burst into rock rings.
  - Sky Reaper: bombing runs ripple across the road.
  - Void Weaver: spins a spider web of spokes and snapping rings around you.
- **Full-screen tides:** each boss has its own wave, e.g. the Sky Reaper's strafe curtain, Grave Lord's skull curtain, Coil Queen's serpent tide and Void Weaver's spiral arms. Bosses throw a tide at every phase change, every other attack in phase 2 and every attack in the final phase.
- **Later bosses scale up.** They fire more bullets (×1.25 at sector 5 up to ×3 at sector 50), faster bullets (up to +32%) and rest less between attacks.
- **Two new bosses complete the road to sector 50:**
  - **Storm Titan** (sector 45): forked lightning, stalking storm pillars, tempest walls, Eye of the Storm.
  - **Hive Empress** (sector 50): honeycomb blooms, homing stingers, drone swarms, Royal Jelly, Hive Storm.
- **Hard mode boss mechanics:**
  - **Shadow Echo:** from phase 2, every boss bullet is fired again, mirrored across the road.
  - **Desperation:** at 15% HP the boss turns invulnerable for 7 seconds and throws everything. Survive it, then finish it.
- Heli-Copter is now the **Sky Reaper** and Necro-Dad is the **Grave Lord**.

**UI**
- **Main menu:** a left-hand menu column over a dark fade, so the key art is no longer hidden behind a panel. The bouncing blobs that ran behind footer text on menu screens are gone.
- **Upgrades:** grouped into OFFENSE, SURVIVAL, CARDS and ECONOMY columns, with price pills instead of a wall of yellow buttons. The BACK button no longer overlaps the list.
- **Pause menu:** adds BESTIARY and CARDS buttons, also on the B and C keys, so you can check them mid-run.
- **Gun comparison:** hovering a gun offer at level-up or in the shop shows bars for DPS, damage, fire rate, magazine and reload, new vs your gun (or before vs after an upgrade). The numbers are no longer crammed into the card text.
- **Cards list every element they belong to,** e.g. "STATUS & COMBOS · FIRE · ICE".
- **Buttons:** the decorative notch and stripe marks are removed.
- **Clicks:** one click can no longer trigger two actions.

**Guns and cards**
- **Bigger magazines** for guns that ran dry fast. Deadeye stays at 6 and Gauss Lance at 3.
  - Breacher 4 → 6, Payload 3 → 5, Longshot 4 → 5, Cinder 110 → 170, Service Nine 12 → 15, Cyclone 36 → 45.
  - Hydra Bow, Pressure Pop, Ricochet, Frostcaster, Rebound, Impact Cannon and Fowl Play also get more shots.
- **Clearer card names**, for example:
  - Licked a Battery → High Voltage
  - Ghost of Bullets Past → Bullet Ghosts
  - Bullets With a Degree → Smart Rounds
  - Mutually Assured Destruction → Mutual Doom
  - Honey I Shrunk Me → Shrink Ray

## v0.1.115 — Gun info in numbers; status combos toned down

- **Gun offers show real numbers for your build**, including your cards, level, tier and character:
  - **New gun:** DPS, damage per shot (×pellets), fire rate and magazine, plus your best current gun's DPS to compare against. Shown at level-up and in the shop.
  - **Gun upgrade:** before → after, e.g. "DPS 205 > 244 (+19%)", then damage and fire rate.
  - **Evolution:** the DPS jump.
- **The shop is fully opaque.** The route map no longer shows through, and the "ROUTE STOP" label sits above the SHOP title instead of under it.
- **Status combos toned down.** A full Bleed build with Hemophilia and Blood Boil reached ~366/s on a 1000 HP elite, about 7.6× a pistol. It's now about 3×.
  - The max-HP part of any status tick is capped at 0.3% of max HP, so stacking can't shred tanky enemies by percentage.
  - Blood Boil, Superconductor and Arc Wound give +50% (was double). Toxic Water gives +40% (was +60%).
  - Hemophilia raises the bleed cap to 12 (was 16).

## v0.1.114 — DUO cards: element combos

Eleven new **DUO** cards, one for each element pair that had no combo. Each only shows up once your build already has both elements:

- **Combustion** (Fire + Poison, Epic): burning a poisoned enemy detonates its poison, dealing 6 base damage per stack in a 75 radius.
- **Blood Boil** (Fire + Bleed, Epic): burning enemies take double bleed damage.
- **Scald** (Fire + Wet, Rare): burning a soaked enemy, or soaking a burning one, bursts into scalding steam: 24 base damage in a 70 radius.
- **Cryo Toxin** (Ice + Poison, Rare): poisoned enemies chill 50% faster, and poison doesn't fade while they're frozen.
- **Brittle Blood** (Ice + Bleed, Rare): chilling a bleeding enemy adds a bleed stack.
- **Superconductor** (Ice + Shock, Epic): double shock damage to chilled or frozen enemies.
- **Electrolysis** (Shock + Poison, Epic): shocking a poisoned enemy arcs half its poison stacks to everything within 120 range.
- **Septic Wounds** (Poison + Bleed, Rare): cutting a poisoned enemy also poisons it, and poisoning a bleeding enemy also cuts it.
- **Blood in the Water** (Bleed + Wet, Rare): soaked enemies always bleed as if moving, so double bleed damage.
- **Arc Wound** (Shock + Bleed, Rare): double shock damage to bleeding enemies.
- **Toxic Water** (Poison + Wet, Rare): soaked enemies take +60% poison damage.

The existing combos (Steam Engine, Thermal Shock, Overload, Conductor) are now labelled DUO too. All duos are listed under STATUS & COMBOS and under both of their elements in the Collection. A new automated test checks every duo actually works.

## v0.1.113 — Card types and new Bleed and Ice cards

- **ELEMENTS is split into FIRE, ICE, POISON, BLEED, SHOCK and STATUS & COMBOS.** Each element has its own colour.
- **Collection type filter:** a second row of tabs filters by card type. It works with the rarity tabs, e.g. EPIC + BLEED.
  - Cards are filed by what they actually do, so Ice Skates shows under ICE and Steam Engine under both FIRE and ICE.
  - On phones, the arrow selector steps through the types too.
- **5 new Bleed cards:**
  - Paper Cuts (Common): +15% bleed chance, +20% bleed damage.
  - Open Wounds (Rare): bleeding enemies take +15% damage from everything.
  - Contagious Cuts (Rare): when a bleeding enemy dies, nearby enemies start bleeding.
  - Vampire Fang (Rare): killing a bleeding enemy heals 1 HP.
  - Hemophilia (Epic): bleed stacks up to 16.
- **5 new Ice cards:**
  - Snow Day (Common): 20% chill chance.
  - Cold Snap (Common): +40% chill buildup.
  - Permafrost (Rare): enemies stay frozen 50% longer.
  - Flash Freeze (Rare): a freezing enemy chills everything within 100 range.
  - Glacier (Epic): +50% damage to frozen enemies.
- New cards show their category icon until their art is made.

## v0.1.112 — Each status has its own role

Numbers are per second on a 1000 HP elite with one card and a pistol (about 48 DPS of its own):

- **Burn: short and fierce.** One 2s stack with the most damage per second, ~30/s right away. Keep hitting to keep it alight.
- **Poison: long and creeping.** Stacks to 12 and lasts 8s, reaching ~27/s at the cap after ~8s. When the timer runs out it loses half its stacks every 2s instead of vanishing, so it keeps ticking after you stop hitting.
- **Bleed: punishes movement.** Stacks to 8 (was 10): ~21/s standing, ~42/s while the enemy moves. Since enemies are almost always moving, it was the strongest status at ~64/s.
- Incendiary, Venom and Serrated describe their new behavior.

## v0.1.111 — Smaller, linear crowds; Hard mode fields fewer

- **Crowds grow in a straight line:** 40 monsters in sector 1, +4 per sector, topping out at 160 from sector 31. The rush wave adds a third on top. A sector is now 53 monsters at sector 1, 101 at 10, 154 at 20 and 213 from 31 on. Before, it was about 200 by sector 8 and 265 by sector 25.
- **The alive cap follows the crowd:** about 60% of the sector's crowd can be on screen at once, between 22 and 90.
- **Each kill pays more EXP and gold** to make up for fewer monsters. It's scaled by how much smaller the crowd is (about ×2 mid-game, ×1.24 late), so cards and gold per sector stay where they were.
- **Hard mode** sends the same count as Normal, since every monster is already a mutant. It allows 80% of Normal's alive cap, up to 72 at once, and spawns no faster than Normal.

## v0.1.110 — Hard mode is all mutants

- **In Hard mode every monster is a mutation, from sector 1.** Each rolled species becomes the body, and a species you've already met donates its graft. There's no sector-25 wait and no 3-alive cap. Bosses stay bosses.
- On Elite and Hell roads in Hard mode the mutants are insane: they also fire their signature move.
- Mutants can be elites in Hard mode.
- Each species gets at most 2 donors per Hard run, about 50 mutant kinds per run. That keeps runs varied without hundreds of sprite rebakes.
- Normal mode is unchanged: no mutations on normal roads, and a few capped mutations on Elite and Hell roads from sector 25.

## v0.1.109 — Status effect balance

Numbers are per second on a 1000 HP elite with one card and a pistol (about 48 DPS of its own):

- **Poison** now stacks to 12 (was 30). Every hit refreshes the timer, so stacks never fell off and poison climbed to ~80/s, more than the gun itself. It's now ~32/s at the cap, in line with Bleed. Venom's text says so.
- **Burn** roughly doubled, ~9 → ~17/s. It was the weakest status by far: it only has one stack, but it's the easiest to keep up and has the most combo cards (Wildfire, Chain Reaction, Napalm, Steam, Overload).
- **Shock** neighbour zaps are 25% stronger.
- **Charm** (Hypnotic, Mutiny) no longer works on elites or mutants. Bosses were already immune. A charm takes a monster out of the fight, which made fast guns delete elites.
- **Bleed**, **Freeze**, **Slow**, **Wet** and **Mark** are unchanged. They're already in line.

## v0.1.108 — Fair economy: card values, bounties, skip and lock

- **Every card has a value at each stage:** its shop price for its rarity in that sector. Skip, lock and sell all follow it.

  | Sector | Common | Rare | Epic | Legendary |
  |---|---|---|---|---|
  | 1 | 37 | 59 | 127 | 219 |
  | 10 | 64 | 95 | 190 | 300 |
  | 20 | 94 | 135 | 260 | 390 |
  | 30 | 124 | 175 | 330 | 480 |

- **Skip** pays 25% of the average value of the cards you pass on, e.g. 9 gold at sector 1 and 16 at sector 10. More if the offer had rare cards. It was a flat 3 + sector.
- **Lock** costs 35% of that card's value, so Commons are cheap to lock and Epics cost more. In the shop, locking costs 25% of the item's price. It was a flat 15 + 4 × sector for everything.
- **Selling** still returns 40% of the card's value.
- **Monster bounties:** tougher monsters drop gold more often. For example, a Blob drops a coin on about 12% of kills, a Chonk about 32%, and mutants more. Overall income stays about the same as before: roughly 20–35 gold per sector early, 60–90 mid-run and 100–130 late.
- **Card fixes based on that income:**
  - **Lottery Ticket:** 20% → 10% chest chance per level-up, max 1 copy. It was far too strong now that every level gives a card.
  - **Bounty Board:** 12 → 5 gold per elite. **Blood Money:** 15 → 6 gold per elite, still heals 10 HP. Elites are about 10% of mid-game crowds, so these were paying 150–200 gold per sector.
  - **Gold Rush:** 6% → 12% of kills. It was strictly worse than Piñata at the same rarity.
  - **Jackpot:** 0.05% → 0.15% of kills drop a chest. It almost never paid out.
  - **Level-up cards** fire less often now that levels after 4 are longer, so they hit harder: Cashback 3 → 8 gold, Growth Spurt heal 25 → 40, Field Dressing heal 15 → 25, Eureka 30 → 45 damage per bullet.

## v0.1.107 — Mutations by mode and road; a card every level

- **Where mutations appear:**
  - **Normal mode:** only on hard roads (Elite and Hell). Normal roads have none.
  - **Hard mode:** on every road. On normal roads they're regular mutations.
  - **Hard mode on Elite/Hell roads:** mutations are *insane*. They keep their graft and also fire the combined signature move (Prism Beam, Mend Beam…).
  - Elite and Hell node descriptions say mutations roam there from sector 25.
- **A card on every level-up.** Before, you only got a card on every other level after level 4. Levels after 4 now need more XP, so you get about the same number of cards per run as before. Your max HP still grows at the same pace.
- A **NEXT CARD %** label next to your level shows how close your next card is.
- The setup screen says NORMAL MODE / HARD MODE, so "road" always means the map path.
- v0.1.106 briefly limited mutations to Hard mode only. That's reverted.

## v0.1.106 — Mutations are a Hard Road feature

- **Mutations now only appear on the Hard Road.** Normal runs never unlock or spawn them. The Mutation Book marks locked entries "HARD ROAD ONLY".
- **On the Hard Road, mutants also fire a signature move.** They keep their behavior graft and also charge a combined move built from both parents. The body decides what the move does and the other parent decides how it's delivered, e.g. Prism Beam or Mend Beam.
  - The mutant calls out the move's name.
  - The whole move uses the mutant's own colour.
  - It fires about every 3.4 seconds, or early with the body's attack.
- Bestiary mutation entries name each mutant's signature move.

## v0.1.105 — Preserve zero-damage bodies with functional offensive grafts

- Totem and Gold Goblin body kits remain non-contact-damaging, even when they inherit an offensive donor mechanic.
- Added separate, scaled `graft_dmg`: inherited spear, artillery, ambush and blood-link abilities carry bounded power without changing the receiver's normal contact attack.
- Audit regressions assert both ordered cases. No special pair combat logic or changes to the 25-species graft data.
- Retains the continuous Spitter ribbon, procedural per-run fusion selection, reactive/interruptible behaviors and encounter budgets from v0.1.104.

## v0.1.104 — Continuous inherited acid and full-monster CI gate

- Make Spitter inheritance one continuous acid ribbon with a matching segment collision zone rather than three circular ground patches. It reuses the normal Spitter trail renderer and coloring.
- Verify this exact behavior in the genome regression suite.
- Add the full monster-rework regression to the fast enemy identity workflow, so obsolete expectations or broken inherited behavior are caught before the slower Windows packaging.
- All pair selection and effect generation remain generic; no hardcoded pair combat cases.

## v0.1.103 — Full-release regression and mutation metadata fix

- Replace obsolete combat regression expectations that demanded ten radiating healing lasers and explosion fans from old effect/shape mutations. Verify the new Medic triage graft on Laser Larry and Kaboomba without generic spamming.
- Initialize color metadata on every spawned mutant, including F3 Debug Lab spawns; donated Mama eggs inherit the real mutation color.
- Existing dash/bash controls now cancel the inherited Tick latch window so a detached parasite cannot immediately reattach on the same activation.
- Keep procedural pair selection and all 25 data-driven behavior exports from v0.1.101–102.

## v0.1.102 — Bounded graft mobility and real counterplay

- Inherited charges have finite duration, Skitter's donated ricochet works on non-Skitter bodies with a one-bounce dizzy recovery, and ordinary Skitter retains its normal three-bounce attack.
- Donated Mirror reflection recharges on non-Mirror bodies; reactive reflection and Ashwing's limited resurrection no longer create empty timed warnings.
- Donated Lil Tick can attach to the hero and is detached by the existing dash behavior. Donated Burrower emerges from the marked target after its temporary underground travel.
- A body's actual attack can trigger a nearly ready graft; generated enemy names reference the real donated behavior, not the old broad power labels.
- Stronger grafts (cost 4+) consume two units of the existing per-sector mutation spawn limit. A structural regression audits all 25 monster exports and compatible ordered pairings.

## v0.1.101 — Procedural behavior grafts (no pair-specific combat recipes)

- Added `FusionGenome` and `data/mutation_modules.json`: all 25 normal monsters export a distinctive, transferable gameplay mechanic, with receiver capabilities and power costs. No combination IDs are hardcoded in combat.
- Live mutations retain their actual body-parent AI and add a timed **behavior graft**, replacing the old body-effect multiplied by donor-shape spam. Grafts include Skitter ricochet, Zoomer orbit, Mirror reflection, Riot shield, Burrower tunnel, Blinky rift slash, Ashwing breakable one-time resurrection, Leech conduit, Medic triage, Lancer piercing weapons, Siren rally, eggs, and sticky bombs.
- Unusable donor/body capabilities are rejected rather than silently converted to unrelated lasers or explosions. All supported ordered combinations may be built on demand in F3 Debug Lab.
- New runs shuffle compatible species pairings, keep a fixed count of unlock slots, rotate previously found pairs and preserve per-sector/live spawn caps. Permanent historical mutation discoveries remain in the Mutation Book.
- Base-parent HP and speed now dominate fused stats rather than blending entirely unrelated movement identities. No new mutations acquire natural elite affixes.
- Update encounter and enemy-identity regression tests to verify the graft interpreter and procedural plans.

## v0.1.100 — Mutation encounters are rare, bounded events

- Fix the actual cause of mutation swarms: the spawn selector was replacing every spawn of either parent once a recipe unlocked, ignoring the declared mutation encounter probabilities entirely.
- Normal mutations now obey their intended 5% starting chance and gradual encounter ramp, with **2 living mutants maximum**, **5 mutant spawns per sector**, and **2 active fusion recipes per sector**.
- Hard raises those limits to **3 living**, **10 per sector**, and **3 active recipes**; it keeps the higher Hard-mode mutation chance.
- The newest unlocked fusion stays in rotation; earlier unlocked recipes rotate between sectors, so the Mutation Book and ongoing run unlock progression remain intact.
- Ordinary monsters keep spawning after their parents combine. Natural mutants cannot roll extra elite affixes on top of their already combined abilities. F3 Debug Lab can still spawn any mutation manually.
- Add encounter-probability, live-cap, sector-budget, rotation and run-reset tests to continuous integration.

## v0.1.99 — Lancer's real two-mode reach and dual-power fusions

- Lancer switches between wide directional spear melee and piercing javelin at the actual hitbox boundary. No more wasted melee sweeps against players 180–240 units away; the visual arc and damage share the same reach.
- Every mutation now carries both parents' gameplay abilities: the body supplies the main move, and the other parent contributes one restrained impact follow-through. Line-based attacks no longer discard the donor's special power.
- Prism attacks can glue, fire spreads acid, fissures can launch real spears, and brood fusions can hatch or split. Secondary effects are limited to a single anchor per move to avoid bullet spam.
- Shock attacks use warned electric paths rather than disguised round explosions; mutant spears are targeted piercing volleys rather than generic radial bullets. Mortar shells land at the actual delivery points.
- Added automated checks for two Lancer attack ranges and distinct fusion donor mechanics.

## v0.1.98 — Mutation body color and parent attacks

- The first parent now supplies every mutation's main body color, held weapon color, warnings, projectiles, explosions, and delayed effects.
- Mortar shells, Burrower mounds and eruptions, Mama eggs, Sapper sticky bombs, Spitter acid, and mutation fire keep that color through their full lifetimes.
- Mini, Mama, and other non-laser parents no longer draw generic laser beams for support effects. Laser beams belong to Laser Larry combinations.

## v0.1.97 — Two sides to every mutation

- Each authored fusion can now appear in both parent orders. The first parent supplies the body and its attack; the second supplies the delivery shape and inherited parts. Both versions unlock together and appear separately in the Mutation Book.
- Mutant warning colors now carry through to their resulting attack effects.
- Spear, shock, quake, and rush fusion strikes have their own visuals instead of sharing the laser beam effect. Laser beams remain on laser attacks.

## v0.1.96 — Mutant warnings match the mutant

- **A mutant's warnings now use its exact body colour.** This covers its own attack tells (Laser Larry's aim line, Lancer's sweep cone, Blinky's rift, Leech's tether and the rest) and the rims of its danger circles and lines. Before, they kept the parent's colour or a lighter tint, so a red Blinky + Larry mutant flashed purple warnings.
- Other monsters' warnings are unchanged.

## v0.1.95 — Real fusion moves

- **Mutations now have one signature move that combines both parents.** Mutants no longer swap between their two parents.
  - The **body** parent decides **what** the move does. The **other** parent decides **how** it's delivered.
  - Laser Larry + Medic: lasers spin out all around it.
  - Laser Larry + Mirror: points fly out and hang in a ring around you, then each one fires a laser at you.
  - Mirror + Riot: a shield wall slams down across your path and every shield bursts into mirror shards.
  - Spitter + Ashwing: a bombing run of acid pools across you.
  - Support bodies like Medic aim their move at their friends, e.g. healing lasers.
- The mutant calls out its move name (e.g. "PRISM BEAM!").
- Everything a mutant does, including its normal attacks, uses one colour: the colour it's drawn in.
- Between signature moves, a mutant fights like its body parent.
- Riot now lends its shield wall.
- A bomber-bodied mutant fires its move as it blows up.
- Every fusion is built from data (`data/fusion.json` plus each monster's `gives`), so new monsters combine with all the others automatically.
- **F3 Debug Lab:** pick one monster, then a second, to spawn their fusion. The old long mutation list and the "AS X" labels are gone.
- **All enemy ground hazards are one shared red.** This covers acid pools, acid trails, Spitter globs and their splashes, and hellfire. Your own poison stays teal and your fire stays orange.
- Mutant acid and fire make one big pool instead of a scatter of small patches.

## v0.1.94 — Mutants are really both parents

- **Mutations fight as both halves.** A mutant spends about 6 seconds fighting as its body parent, flashes, then about 4 seconds using its other parent's attacks, and so on. For example, Tunnel Harpoon burrows and erupts like a Burrower, then switches to Lancer spear throws and sweeps. Before, mutants played almost exactly like their body parent.
- Every attack still carries the other parent's augment.
- Bestiary entries for mutations explain the switch.
- **F3 Debug Lab:**
  - Mutations list both parents, e.g. "Tunnel Harpoon (Burrower + Lancer)".
  - The spawn notice says which parent is the body.
  - In debug runs, every mutant shows a small "AS LANCER" / "AS BURROWER" label, so you can check it is acting correctly.

## v0.1.93 — Uncapped boss bullets, Monster Eyes option

- **Bullets are not capped:** the per-boss bullet limit is gone and enemy bullets no longer share your shot budget, so dense late patterns always fire in full. Monsters stay capped.
- **New setting, MONSTER EYES:** STATIC (FAST) by default bakes the pupils into the sprites, which is cheaper in big fights. FOLLOW YOU brings back eyes that track you. This replaces the Sensitivity setting, which no longer did anything.

## v0.1.92 — Late bosses fill the screen

- Late boss bullet patterns keep getting denser after sector 30: up to 2.6x the shots by sector 50 (was capped at 1.7x). The per-boss bullet limit grows with them.

## v0.1.91 — Late game fixed, map-wide bosses, smarter roads

- **Fixed: the game froze around sector 53+.** A mutant with the Frenzied (rush) augment never ended its speed burst, sped up every frame until it flew off to infinity, and drawing it at an infinite position froze the game. Sprints now last their real duration. As safety nets, knockback speed is capped and a broken position is reset.
- **Fewer, tougher monsters:**
  - Late sectors have about 200 monsters per sector instead of 400+.
  - At most 72-90 are alive at once (100 hard limit), and spawning pauses until there is room.
  - Late monsters get up to +60% HP.
- **Every normal monster comes first:** a new species debuts every sector from 6 to 23, then mutations start at sector 25.
- **Mutations lock their halves:** once two species fuse in a run, those two parents only appear as the mutation from then on.
- **Boss fights are map wide:** no more arena walls.
- **Each sector is a fixed stretch of road:** a ROAD CLOSED barrier ahead stops you running forward forever.
- **Bosses hit harder and last longer:**
  - 3.5x HP, plus 8% more per sector after 12, so sector 10-25 and later bosses are real fights.
  - Their bullet patterns fire up to 70% more shots by sector 30.
- **Obstacles:**
  - The small target-like traffic cones are gone.
  - Roadblocks and parked cars slide when you shoot them, and a dash shoves them out of the way.
  - Dashing slips past trees, and walking slides around them instead of getting stuck.
- **Fixed:** a shot destroying a roadblock could remove the wrong obstacle.

## v0.1.90 — Lancer early, Spitter later

- **Lancer and Spitter swapped places:** Lancer is now a starting monster and Spitter arrives later, around sector 26.
- **Spitter always lobs one acid glob.** It used to jump from one glob to three at sector 6. Now it gets more dangerous by firing more often in later sectors.
- **Second mutation is Needle Hunter** (Lancer + Skitter) instead of Toxic Artillery, since Spitter now arrives later. Toxic Artillery moved later in the order.

## v0.1.89 — HP grows with your level

- Max HP now grows with your level (+22 per level-up, and the new HP comes filled) instead of with the sector. Levelling up is what makes you sturdier.

## v0.1.88 — Clearer screens

- **Collection:** opens on ALL CARDS together, sorted by rarity. The other tabs are Common, Rare, Epic, Legendary+, Gun Cards (cards for one gun) and Guns.
- **Debug Lab:** fills the whole screen, and the Weapons filter uses gun classes (Sidearm, Long Range...) instead of internal types.
- **Random encounters:** a one-line description plus an outcome table showing which dice roll gives what. After the roll, the result you landed on lights up. The dice are chunkier, toss and bounce, and the rolled result is colour-coded.
- **HUD on PC:** the Pause and Arsenal buttons are gone (use Esc and Tab); they stay on touch screens. The card strip is smaller and shows how many cards you have.
- **Controls guide:** the first-sector hint is now a row of keycaps (WASD MOVE, LMB GUN 1, ...) that fades out, instead of a line of text.
- **Mirror:** reflected shots keep the look of your own projectile and deal 20% of its damage.

## v0.1.87 — Bigger collection pages

- The Collection now shows 18 cards per page (6 x 3) instead of 8, so a whole category fits in one or two pages.

## v0.1.86 — Lock, banish, sell and a real economy

- **Lock cards:** pay gold to lock a level-up card (it comes back at your next level-up) or a shop item (it stays in every shop until you buy it).
- **Banish cards:** remove a card from an offer or the shop so it never shows up again this run. You start with 1 banish; the new GRUDGE LIST upgrade adds up to 4 more, and the Grudge List card gives +2.
- **Sell cards:** in the Arsenal (outside a fight), inspect a card and sell one copy for 40% of its price.
- **A bigger shop:** 8 stalls in two rows: 4 cards (one Rare or better, one premium stall with extra luck), a gun, a heal, a max HP upgrade and the mystery card.
- **Less late-game gold:** kill gold thins out after sector 8, and the sector stipend grows more slowly after sector 10.
- **Campfire:** resting heals 60% (was 40%), or FORTIFY for +30 max HP.
- **Random encounters:** rewards now scale with the sector, card rewards are a tier better from sector 10, and there are 4 new encounters: Arms Dealer, Field Medic, Treasure Map and Card Trader.
- **20 new cards:**
  - Every gun now has at least two cards of its own.
  - New general cards: Grudge List, Second Skin, Adrenaline Shot, Blood Money, Static Shield, Hot Streak, Field Dressing and Scrap Collector.
- **Card text:** the "how this works with your guns" notes are now written in plain language instead of developer wording.
- **Fixed: enemy attacks looked like faint discs.** Explosions no longer leave smoke puffs that read like projectiles.
- **Runners hold their guns close:** no more long arms. Guns sit under the body, shoulders and head, and only the barrels poke out.
- **Hard limit of 110 monsters alive at once:** spawns wait until there is room, which keeps late sectors smooth.
- **Elite labels** (TURRET · REGEN · ARMORED) only show for elites near you.
- **Fixed:** the treasure chest icon overlapped the TREASURE! title.

## v0.1.85 — Readable attacks, sturdier runner

- **Fixed: enemy attacks showed as faint brown discs.** v0.1.84's circle batching made small bullets and circles render dark and see-through. Circles now use their own clean texture.
- **Enemy projectiles stand out; yours step back.** Enemy shots get a dark contrast rim and a stronger glow. Your shots and explosions are toned down, and explosions leave only a small, short wisp of smoke instead of big lingering discs.
- **Heli is now the first boss (sector 5) and Chonkzilla the second (sector 10).** Chonkzilla's base damage is trimmed (30 to 24) for its new slot.
- **Mirror nerfed:** its reflect recharges in 1.8s (was 1.1s), and reflected shots are slower and hit no harder than the Mirror itself.
- **Returner fixed:** it no longer curls away the moment it leaves your hand. It sweeps across where you aim, reaches it, and comes back. While a Returner or Razor Disc is in flight, your hand is empty.
- **Fixed: stretched arms.** A target very close to you could spin a long gun around and stretch the arm across the screen.
- **Guns have categories:** Sidearm, Rapid Fire, Close Range, Long Range, Explosive, Energy, Thrown and Special. They show on gun cards, the HUD and the arsenal.
- **Bigger, easier-to-see obstacles:** traffic cones are much larger and brighter, and roadblocks are 25% bigger.
- **Charmed monsters no longer count as enemies left.** They fight for you, then collapse when the charm wears off.
- **More survivable:** 130 base HP plus 18 per sector (was 100 plus 12), heart drops twice as often, and clearing a sector heals 25% of your max HP.
- **Fixed: King Blob dropped many chests.** It splits into pieces, and each piece used to drop full boss loot. Now only the last piece drops the chest.

## v0.1.84 — Much smoother, and the late game is fun again

- **Big frame-rate boost in crowded fights.** In the same heavy test fight, frames went from 8 fps to about 45 fps. Typical busy fights now run at 70-90 fps.
  - Circles (eyes, shadows, sparks, puddles, bubbles) now batch into a few draw calls instead of one call each.
  - Monster bodies are drawn in one batch, then their extras on top.
  - Obstacle checks only look at nearby trees and cars, not the whole street.
  - Crowd separation searches a smaller area.
  - Mutant body lookups are cached, and lost-monster checks run less often.
  - Spitter acid is far cheaper: at most 14 acid trails at once, simpler globs, and cached puddle shapes.
  - Effects and floating numbers have tighter limits.
- **The late game is fun again.** Past sector 12, monster health now grows steadily instead of exploding: about 19% less at sector 15 (Necro Dad) and 42% less by sector 20. Fewer monsters are alive at once (at most 105-115 from sector 13, down from 135-150) and tougher individually.
- **No more card cap.** You could only hold 32 cards. That limit is gone (each card still has its own stack limit).
- **Mystery crates never come up empty.** If no card fits your build, one of your guns levels up instead. If every gun is maxed, you get gold that scales with the roll plus a 25% heal.
- **Your mouse stays yours.** Mouse aim no longer captures or locks the cursor. It is only hidden over the game, where the crosshair replaces it.

## v0.1.83 — No more running away

- **Outrunning monsters no longer clears a sector.** Before, any monster that fell far behind you was silently deleted and counted as killed. Now a left-behind sector monster comes back just off-screen, usually ahead of you, so you have to deal with it.
- Only extras that don't count toward the sector (like Mitosis minis) still vanish when left behind.
- A monster that gets lost again and again (6 times) is finally cleared, so a sector can never get stuck.

## v0.1.82 — Every card checked

- **All 300 cards were re-checked against what they actually do.** Every card's effect is wired up, and every number in a description matches the real value.
- **Gun cards used old gun names.** 25 cards still said Boomstick, Lawnmower, Long Goodbye, Six Shooter, Peashooter, Party Starter, Zapper, Hot Take, Beam Me, Frisbee of Doom and so on. They now use the current names (Breacher, Vulcan, Longshot, Deadeye, Service Nine, Payload, Arc Caster, Cinder, Prism Beam, Razor Disc and the rest).
- **About 90 descriptions are more detailed.** Cards that only said things like "zaps enemies", "a meteor crashes" or "burning enemies explode" now say how hard and how big: base damage, radius, duration, count and range.
- **Fixed inaccurate text:**
  - Blood Bank: the shield comes from overhealing by 10+ HP.
  - Sticky Bombs: the bomb hits for the hit's full damage.
  - Hydra and Ghost Walk no longer contain developer notes.
- **Stat lines:** show all of a card's stats (up to 4). Timed effects now read "EVERY 5S" instead of "5.0 PER TRIGGER", and walking effects read "EVERY 90PX".

## v0.1.81 — Whose fire is it? Cards you can read

- **Your poison and fire vs enemies':**
  - **Yours:** teal toxin and orange flames, with no rim.
  - **Enemies':** sickly yellow-olive acid and crimson hellfire, both with a pulsing red danger rim.
  - Spitter's acid line uses the same hostile palette.
- **New enemy fire:** mutants with the Burning augment (Ashwing, Kaboomba and Larry parts) now leave a hellfire patch on the ground after the blast. It burns you while you stand in it.
- **Your projectiles are a little dimmer**, so enemy bullets always read first. Enemy shots are unchanged.
- **Card text never gets cut off:**
  - The card art shrinks to make room, and the description shrinks only if it still needs to.
  - Stat lines wrap onto extra rows, and cards now show all their stats (up to 4) instead of the first 2.
  - This fixes cards like Hot & Cold and Rainbow Rounds.

## v0.1.80 — Hands on the gun, every mob its own colour

- **Hands fixed:** the head no longer covers the hands holding the guns. A single gun is held in front of the chest with both hands on it, instead of off to one side with an arm crossing the face.
- **Portraits:** each runner holds their starting gun across the chest in the middle of the portrait.
- **Every street mob now has its own colour:**
  - Mirror (pale glass blue) and Skitter (teal) no longer share one, and Riot (navy) is clearly apart from Totem (bright blue).
  - Larry, Chonk, Siren, Ashwing, Goblin, Sapper, Burrower, Bull, Tick, Mini, Nurse, Lancer and Leech were also moved apart.
  - Mutations pick up the new colours automatically.

## v0.1.79 — Five real runners

- **Five distinct characters**, each with their own model that turns with your aim:
  - **Scout:** street runner with a cap, red scarf and messenger bag.
  - **Ember:** firefighter with a helmet, reflective coat and twin fuel tanks. A hose runs to the flamethrower.
  - **Ace:** gunslinger with a wide-brim hat, flapping duster coat and spurs. Ace holds a single gun one-handed.
  - **Vector:** operator with a helmet, night vision, plate carrier and radio antenna.
  - **Coil:** hooded technomancer with a glowing visor, rippling cloak and a power coil on the back. With the rail gun, a cable runs from the coil to the gun.
- **Guns are redrawn** for all 22 weapons and actually held: arms reach the real grip, and the support hand takes the foregrip of long guns. Shots come out of the drawn muzzle, so a sniper reaches further than a pistol. A third gun rides a back mount.
- **Each runner has their own bash:** Scout swings a baseball bat, Ember chops with a fire axe, Ace cracks a bullwhip, Vector shoves with a riot shield and Coil fires a shock palm. The hit area is unchanged.
- **Character select** shows a front-facing portrait of each runner with their starting gun.

## v0.1.78 — Spitter acid line

- Spitter's acid line is now a real spilled-acid puddle instead of a glowing tube: wobbly liquid edges with a dark rim, a flat pool with a wet sheen, tapered ends and bubbles that swell and pop. The tail dries up by shrinking.
- Only the main glob leaves the acid line. The two side hooks (sector 6+) splash a puddle where they land, so trails no longer pile into a bundle.
- Fixed the Windows build check that failed on v0.1.77.

## v0.1.77 — Monsters use their weapons, guns follow your cursor

- **Lancer actually uses its lance:** it holds the spear at its side, pulls it back and up to throw (glint before release), and its hand is empty until a new spear appears. For the close sweep it cocks the spear back and swings it through the slash. The thrown shot is a real spear in flight.
- **Mortar** aims its tube at you and kicks back with a puff of smoke when it fires.
- **Sapper** raises its bomb overhead for a moment before lobbing it, then its hand is empty for a bit. The bomb in the air spins with a lit fuse.
- Mutants holding these weapons animate the same way.
- **Your guns:** with auto aim and nothing in range, your guns now follow the cursor instead of freezing. Both guns now converge on the target, and the off-hand gun is no longer drawn upside down. Guns are held at the shoulders instead of across your face.

## v0.1.76 — Spitter acid globs

- Spitter's shot is now a wobbling acid glob lobbed through the air over its ground shadow (the shadow marks where it really is), dripping as it flies and splashing into a poison puddle where it lands.

## v0.1.75 — Effects that actually look good

- **Real glow:** lasers, beams, sparks, explosion cores, enemy bullets and fire now glow on an additive light layer.
- **Explosions:** a fireball with a ragged edge, a white-hot flash, a thinning shockwave, flying debris streaks and smoke that drifts up afterwards.
- **Lightning** forks and flickers with a white-hot core; **lasers** flare at both ends.
- **Leechling's drain** is a sagging blood stream with droplets flowing into the leech.
- **Lancer's sweep** cuts a crescent slash; rings are thick shockwaves that thin as they grow.

## v0.1.74 — Mutants show their attacks

- Mutants now show every tell and effect of their body parent's attack. A Leechling-bodied mutant (like Blood Chaser) draws its wind-up and blood tether; Skitter, Zoomer and Bull bodies keep their ricochet, sprint cap and shove; Riot bodies show their shield, Larry bodies their overheat.

## v0.1.73 — Better fusions

- Every species now has a **main part** it always keeps as a body (Spitter's neck, Ashwing's wings, Sapper's bomb pack, Siren's fin ears, Mama's egg pack...) and **parts it gives**, each with a slot (top, hand, legs, wings, head, tail, spikes, back).
- A fusion keeps the body's shape, eyes and main part and adds the other parent's colours, mouth, pattern and every given part whose slot is free, so pieces never collide. Ember Spore is a Spitter with Ashwing's wings and beak; Toxic Artillery keeps its neck and carries Sapper's bomb pack; Brood Bastion carries Mama's eggs.
- Blinky, Mitosis and Mirror now give parts too (ghost wisp, cell buds, prism spikes). Kaboomba has a proper bomb cap.

## v0.1.72 — True fusion mutations

- Street monsters are now built from layers. The **body parent** gives the silhouette, its own anatomy (Spitter's neck and bulb, Bull's horns, Tick's legs, Ashwing's wings, Kaboomba's fuse...) and its eyes. The **other parent** gives its colours, surface pattern, mouth and decorations (Kaboomba's black skin, red grin and bomb spikes; Riot's armour; Leechling's sucker mouth...).
- A mutation is a true fusion of the two, baked into its own sprite in game and in the Mutation Book: Phoenix Bomb is an Ashwing in Kaboomba's black, grinning, spiked skin; Bulwark Ram is a horned Bull in Riot armour.
- Mutation Book portraits no longer crop off wings and legs.

## v0.1.71 — Mutations built from body parts

- Every monster's base model now **gives two parts** (one for each augment it can pass on: Kaboomba's lit fuse or bomb spikes, Larry's laser lens or heat vents, Medic's nurse cap or cross pack...) and **receives one part** in a fixed slot on its own body (on its head, side or underneath).
- A mutation is the body parent's model with the giver's part plugged into that slot, so you can see both parents and what its attacks carry at a glance. Replaces the colour spots and emblem badges from v0.1.70.

## v0.1.70 — Mutations you can read at a glance

- **Mutation art:** a mutant keeps its body parent's silhouette, wears patches of the other parent's colour, and shows an emblem of the augment its attacks carry: a red laser lens, a green heal cross, a lit fuse, poison drips, a guard hex, lightning, a sticky bomb and more. The same look is used in game and in the Mutation Book.
- **Spitter** has a curved neck and dripping acid bulb instead of the straight spout.
- Fix the Windows release check that still expected mutants to run both parents' AIs.

## v0.1.69 — Full-width streets, reworked monsters and real mutations

- **Streets fill the screen** with real proportions: traffic lanes, bike lane, parking lane, kerb, grass verge with trees and pavement, with houses along the edges. Trees only collide at the trunk so you never get stuck, and only stand in the verge. Street lights no longer look like targets.
- **Mirror Mimic** reflects your shots straight back at you. **Riot**'s shield stops frontal shots until it breaks, and it shield-bashes up close. **Lancer** spears are fast.
- **Burrower** tunnels as a dirt mound, rumbles briefly under you and erupts, then stays exposed. No more fissure lines.
- **Sapper** throws sticky bombs that latch onto you; dash or bash to shake them off. **Skitter** ricochets off walls and props, then gets dizzy. **Spitter** acid leaves a poison trail and pools where it lands.
- Modelled **Mama Blob** and **Ashwing** eggs. Small monsters have 10% more health and damage.
- **Mutations feel like one monster:** the body parent attacks the way it always does, and every attack carries an augment from the other parent (heal, explode, poison, laser, sticky bomb, drain and more). Each species can pass on one of two augments depending on the mutation. Monsters that never attack deliver it as a warned pulse; line augments like lasers fire as a 6-way star.

## v0.1.68 — Real streets, unique boss attacks, gun and monster identities

- **Real streets:** every sector is a proper road cross-section (two-lane street, four-lane road, tree-lined boulevard or wide avenue) with the right number of lanes. The rest of the width is walkable paved pavement with street trees in tree pits, street lights and building fronts. Asphalt has wear, manholes and patches; markings include edge lines, lane dashes, yellow centre lines and arrows. Cross streets have zebra crossings and stop lines. Roadworks only close the kerb lane, and parked cars sit along the kerb.
- **No repeated boss attacks:** each attack now belongs to one boss. New: Goo Mortar, Boulder Roll and chained Kaiju Rage shockwaves (Chonkzilla); Grave March (Necro-Dad); Jelly Fountain and Bounce House (King Blob); Prism Split (Glass Oracle); Assembly Line (Dread Engine). Boss phases no longer slip back when a boss heals.
- **Guns with real mechanics:** Deadeye Quickdraw (the first shot after a pause is a sure piercing crit), Cyclone run-and-gun (fires faster while you move) and Rivet Driver caltrops (missed nails stick in the road and slow enemies).
- **Evolutions do something new** instead of adding stats: ricochet rounds, ricocheting crits, slugs, incendiary rounds, kill refunds, rivet bursts, multiball, shockwave craters, feather darts, minibubbles, frost trails, queen bees, sticky grenades and catch shockwaves.
- **Every gun sounds and looks different:** its own firing voice and bullet shape.
- **Monsters you can tell apart:** new silhouettes for Blob, Zoomer, Mini, Mitosis, Spitter, Leechling, Siren, Medic, Skitter and Chonk, each with a mutation part that can combine with any monster. Lil Tick now hops at you; Mitosis splits into halves that re-merge unless you kill both.

## v0.1.67 — Real streets: two-way roads, boulevards and roadworks

- **Street layouts:** every sector is now a proper street, chosen per sector: two-way roads with a double yellow line and jersey-barrier dividers, boulevards with a tree-lined grass island, split carriageways around a wide park strip, or open multi-lane road. Islands are walkable with crosswalk gaps; their trees and dividers are the obstacles.
- **More trees:** clumps of trees line both verges along the whole sector.
- **Roadworks:** construction zones close part of one carriageway with sawhorse roadblocks and rows of traffic cones, always leaving a lane open. Cones and roadblocks can be shot down.
- **More parked cars** from Sector 12, along the kerb and sometimes in a lane.
- Boss arenas stay open roads with no roadblocks, cars or dividers.
- Slow Spitter acid no longer draws an aim line before it fires; the slow shot is easy to watch. Fast shots (Mirror Mimic, Lancer spear, laser) keep theirs.

## v0.1.66 — Continuous fire and poison trails, redrawn road props

- **One trail, not a row of circles:** a dash with fire trail now leaves a single continuous burning ribbon that burns out from its tail, and a Spitter's acid shot paints one growing poison ribbon instead of dozens of overlapping segments. Each trail is one hitbox along its whole length.
- **Puddles merge:** overlapping fire, poison and ice zones of the same element combine into one larger puddle instead of stacking see-through circles.
- **New ground art:** fire burns with flickering flame tongues and embers, poison bubbles in an irregular toxic puddle, and ice forms a cracked, sparkling frost sheet.
- **Redrawn road props:** leafy trees that sway, parked cars with glass, wheels, lights and smoking damage, sawhorse roadblocks with blinking amber lamps, and concrete dividers with hazard chevrons.

## v0.1.65 — Bounded late-game crowds, tougher monsters

- Keep sectors 1-12 population and spawn pacing intact, including the sector 9-11 relief band.
- From sector 13, replace exponential crowd growth with a gently increasing, fixed sector budget. Normal reaches fewer than 500 scheduled monsters per sector by sector 25 and stays capped thereafter. Hard and route modifiers still alter the bounded baseline.
- Cap late normal spawn throughput at 12.25-15 enemies per second (Hard: up to 17.25) and slow late Crowd Rush deployment to 10 per second (Hard: 13).
- Cap simultaneous normal enemies at 150 by sector 20 (Hard: no more than 173); reduce the late Rush overflow allowance from 25 to 15.
- Shift late difficulty from raw mob quantity into ordinary-enemy HP, ramping by 2% per sector after 12 to a maximum +25%. Bosses, which already have separate 2x HP, and noncombat Gold Goblins receive no extra HP.
- Leave mutation encounter chances, unlock schedules, enemy mechanics, and XP/loot per actual enemy kill unchanged. Extend the roster test to cover progression, hard-mode caps, and boss HP isolation.

## v0.1.64 — Zoomer recovery and shorter Leechling blood link

- Cap Zoomer's boosted sprint speed at 310 units/s (Normal) or 350 units/s (Hard) even during Siren/HASTED/late-sector scaling.
- Return far-away Zoomers toward the hero and constrain them inside the road and reachable forward/rear sector boundaries, rather than letting lateral orbiting strands leave combat.
- Preserve Zoomer's distinctive orbit-and-sprint movement, separately from Skitter's committed dash.
- Reduce Leechling blood conduit acquisition range from 525 to 340 world units and active-link breaking distance from 565 to 370; adjust its preferred positioning accordingly. Taking cover still breaks the tether.
- Extend Godot regression tests for Zoomer bounds, speed caps and Leechling tether range.

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

