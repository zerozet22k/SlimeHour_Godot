# Slime Hour

Windows Godot action game. Source lives in this repository; playable releases are published under [GitHub Releases](https://github.com/zerozet22k/SlimeHour_Godot/releases/latest).

Enemy progression starts with four street types. After the first boss, each fourth route choice introduces one base type; the choice after every second new base introduces their hybrid. The new enemy is guaranteed to spawn in its introduction sector. Hybrids combine both parents' combat actions and show both colors in one body. Nurse + Laser Larry is the first mix, appearing in Sector 11.

## Install and update

1. Download **SlimeHour-Windows.zip** from the latest release.
2. Extract **all** files together: `SlimeHour.exe`, `SlimeHour.pck`, `Start_Slime_Hour.bat`, `update_and_run.ps1`, `updater_config.json`, and `release_manifest.json`.
3. Launch **`SlimeHour.exe` directly**. New updates appear on the main menu; click **UPDATE**, watch the progress inside the game, then choose **INSTALL & RESTART** after checksum verification. No visible command window is used.
4. The optional `Start_Slime_Hour.bat` shortcut now only starts the EXE; it no longer runs the old command-window updater.

**Incremental updates (v0.1.19+):** The in-game updater checks GitHub Releases on startup, selects a matching `SlimeHour-Delta.zip` when possible, downloads it directly to disk with progress, verifies SHA-256, and offers **INSTALL & RESTART**. When you exit the game, a hidden Windows helper reconstructs the new version into a separate folder, verifies its manifest and contents, and restarts Slime Hour. Otherwise it uses the full release ZIP. It never overwrites the running game, and existing saves remain intact.

**Important:** Updating *to* v0.1.7 is a one-time full download because older builds embedded the .pck in the executable and cannot serve as chunk-patch bases. Partial updates become available from subsequent releases. Download size depends on how much data actually changed; unchanged game assets generally do not need downloading again. Existing saves remain in Godot's normal user data location. No admin permissions or Git LFS are required to play.

To edit the game, clone the Git repository with Git LFS installed and open `project.godot` in Godot 4.7.2. The CI system builds and tests Windows releases on version bumps. Android exports are deferred.

## Developer Debug Lab (Windows)

Press **F3** anywhere (including while choosing a card or on the route map), or click **DEBUG LAB** on the title screen. The simulation pauses and the mouse is released while the Lab is open.

- **ROUTE:** jump to Sectors 1/5/8/10/15/20/25/30/40; step +/-1 or +/-5; enter the map, normal/Elite/Hell fights, boss, shop, campfire, treasure, or random event directly
- **CARDS:** page through the entire card catalog and test even prerequisite-dependent effects; this is debug-only and does not change normal card eligibility
- **WEAPONS:** choose gun slot 1, 2 or 3, then equip any unlocked or locked weapon
- **ENEMIES:** spawn specific monsters or bosses in front of the hero
- **TOOLS:** start a fresh test run, restore health, add 500 gold, toggle invincibility, clear enemies, and open the route map

**Saving safety:** Opening F3 creates a temporary test sandbox. Nothing from that session writes permanent profile progress, unlocks, or leaderboard records. Returning to the main menu restores the original in-memory profile. Restarting the game also loads the existing save. **F4** toggles performance stats independently.
