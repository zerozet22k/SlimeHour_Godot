# SLIME HOUR

One hero, two guns, 300 cards, and a road full of idiots running at you.
Godot 4 (standard build, not .NET). The Godot exe in this folder runs it: double-click `PLAY_WINDOWS.bat`, or open `project.godot` in the editor and press F5.

## Controls

On Windows, double-click `PLAY_ANDROID.bat` to install and launch `build/CrowdRush-debug.apk` on a connected Android phone or running emulator. Enable USB debugging and accept the phone's authorization prompt first. The script finds Android Platform Tools through your SDK environment variables, Android Studio's default SDK location, a local `platform-tools` folder, or PATH. With multiple devices, use `PLAY_ANDROID.bat device-serial` (list serials with `adb devices`). It installs the existing APK; export Android from Godot again to include newer source changes.

| Input | Action |
| --- | --- |
| WASD / arrows / Left Stick / **Lower-left touch drag** | Move |
| Mouse | Aim (adjustable sensitivity in Settings). **Left click fires gun 1, right click fires gun 2**, a 3rd gun fires with either. Auto-fire is a setting (default on for touch). |
| R | Reload every gun that isn't full |
| Space / Shift / **DASH Button** | Dash. Dodging something mid-dash is a **PERFECT** dodge, which triggers counter cards |
| Tab / **ARSENAL Button** | Arsenal: your guns, every card you own, all your stats |
| 1-4, R, X / **Tap Card** | Level-up: pick a card, reroll, skip for gold, peek build |
| Esc / **|| Button** | Pause · F11 fullscreen · F3 debug overlay |

> **Mobile & Touch Support:** Sensor rotation supports landscape and portrait. Portrait fills the screen with a vertical road view, a top HUD, and thumb controls at the bottom; the camera follows sideways movement. Touch and mouse events are handled separately to avoid double taps. Press or drag in the lower-left thumb zone to move, use DASH on the lower right, and drag the right side to aim when manual aim is selected. Pause, arsenal, buy, cards, settings, and collection have touch targets in portrait. Touch controls can be set to **AUTO / ON / OFF** on mobile. Desktop builds keep the virtual controls off, including when an older saved setting says ON.

## How a run works

- **Sectors** are a stretch of road. Push forward to the finish line while the director spawns enemies ahead (and some behind).
- Every 10th sector, about 28% in: **buff gates**, the classic pick-a-door. Walk through the left or right one for a bonus that lasts the rest of the sector (+1 multishot, +1 blade, explosive rounds, or a risky -30 HP for an epic card...).
- About 55% in: **SLIME HOUR**, a horde of 40+ blobs, zoomers and kaboombas streaming down the road.
- Every 5th sector has a **boss** (Chonkzilla, Heli-copter, Necro-Dad, King Blob, who splits).
- **Clear sector 20 to win.** You can then keep going: every sector after 20 has a boss, and boss HP grows 1.8x per sector.
- Past the finish line is the **pit stop**: walk up to stalls and press E (cards, guns, upgrades, heals, restock). Then walk through one of three **route gates**: Highway, Toll Road (+gold, more elites), Scenic Route (heal), Hell Lane (2x enemies, 2x EXP, free epic), Casino Strip (rerolls + free card).
- Level-ups pause the game and show cards. Elites and bosses drop **treasure chests** (a free rare+ pick).
- Rarities: Common, Rare, Epic, Legendary, then the very rare **Mythic** and **Ascendant**. Guns roll one of these tiers when you get them.

## Guns (22)

Each gun has its own firing rules, and multishot means something different on each one.

Peashooter, Six Shooter, Boomstick (recoil shoves you back), Buzz SMG, Lawnmower (spins up, slows you), Long Goodbye (pierces 6), Party Starter (rockets), Bouncer (grenades bounce), Beam Me (continuous beam, overheats), Zapper (chain lightning), Hot Take (flamethrower), Frisbee of Doom (discs return and must come back before you can throw again), Boomer, Railgun (charge-up line), Beehive, Strike Cannon (bowling balls fling enemies into each other), Nail Gun (pins), Poultry Launcher (rubber chickens bounce between enemies, then explode), Bubble Blaster (traps, then pops), Pinball, Splitbow, Snow Cannon (snowballs grow in flight).

Guns level 1 to 5 (+damage and rate; level 3 and level 5 unlock a perk unique to each gun), then **evolve** into a named form. You hold 2 guns (3 with the *Arsenal* legendary) and they fire together.

## The 300 cards

Ten categories of 30: Volley, Bullets, Chain Reaction, Elements, Auto-Weapons, Movement, Defense, Loot, Chaos, Mastery. Browse them all in-game under **Collection**.

Cards are built from two parts the engine actually runs (`scripts/Effects.gd`):
- **stat mods** (multishot, pierce, ricochet, fragments, burn chance, orbit blades, ...)
- **procs**: *on [fire / hit / crit / kill / dash / perfect dodge / hurt / reload / level / explosion / timer / walking / standing still] → do [explode, fragments, nova, chain lightning, anvil, piano, clown car, bees, black hole, ...]*

Projectiles carry their payload, so effects combine. A frozen-burning enemy erupts in steam; its shards split; the fragments ricochet and can split again with *Fractal*. Generation caps and a per-frame budget keep chain reactions from spiralling.

## Art

Art comes from the local AI Studio (`http://127.0.0.1:7860`). Any image that's missing gets a drawn placeholder, so the game is fully playable without art. AI Studio offers Z-Image Turbo and FLUX.2 Klein as alternate local styles.

- All prompts are in **`tools/art_prompts.txt`**, one per line: `output path | mode | prompt`. Each prompt is sent exactly as written. Edit freely.
- `python tools/gen_assets.py` generates missing images. `--redo name1,name2` regenerates specific ones; `--redo` alone regenerates everything.
- `python tools/gen_assets.py --model flux-klein --stage --cards --direct` stages local card images without replacing game assets or filling AI Studio's conversation list. Review results before using them in the game.
- After new art, open the project in the Godot editor once (or run `Godot... --headless --path . --import`) so the images get imported.

## For developers

- `python tools/build_data.py` writes `data/*.json` from the single content source (weapons, enemies, cards).
- `python tools/validate.py` checks that every card only uses stats, triggers, actions and conditions the engine handles.
- Automated play-tests (see TESTING.md): `--autotest=cards` runs all 300 cards, `--autotest=soak` has a bot play many sectors, `--autotest=shots` renders screenshots.
