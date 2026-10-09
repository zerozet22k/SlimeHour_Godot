# Testing

All commands run from the project folder with the bundled Godot exe.

| What | Command |
| --- | --- |
| Card data matches the engine | `python tools/validate.py` |
| Every card, at max stacks, in a live fight (~4 min) | `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest=cards` |
| Bot plays many sectors with all guns and a growing build | `set SOAK_SECONDS=300` then `... --headless --path . -- --autotest=soak` |
| Leveling and card-rarity pace per sector (no free cards) | `set PACE_SECTORS=10` then `... --headless --path . -- --autotest=pace` |
| Sector caps, gate spacing, in-wave HP growth (seconds) | `... --headless --path . --script res://tools/progression_check.gd` |
| Boss HP past sector 20, gun tiers (seconds) | `... --headless --path . --script res://tools/balance_check.gd` |
| Desktop touch controls stay hidden despite old saved settings | `... --headless --path . --script res://tools/touch_check.gd` |
| Kill unlocks, unlock popups, late healing cards | `... --headless --path . --script res://tools/unlock_check.gd` |
| Portrait joystick, dash, camera follow, and rotation | `... --path . --script res://tools/mobile_controls_check.gd -- --portrait-preview` |
| Portrait menu, play, choices, collection, and settings screenshots | `... --path . --script res://tools/portrait_preview.gd -- --portrait-preview` (writes `build/portrait-*.png`) |
| Screenshots of every screen into `%APPDATA%/Godot/app_userdata/SLIME HOUR/shots` | `... --path . -- --autotest=shots` (needs a window, no `--headless`) |

Look for `SCRIPT ERROR` in the output; each run ends with an `AUTOTEST DONE` summary line.

The autotests show the game runs without errors. They don't tell you whether it's fun or fair. Difficulty and pacing still need human play.

## Responsive UI checks

Run `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/responsive_ui_check.gd -- --portrait-preview` to check navigation bounds and capture menu, settings, collection, offers, and pause at phone (390x844), portrait tablet (768x1024), landscape tablet (1024x768), and desktop (1920x1080) sizes. Screenshots are written to `build/ui-*.png`. This simulates viewport sizes; physical mobile device testing is still needed.
