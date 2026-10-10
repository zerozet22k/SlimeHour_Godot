# Slime Hour

Windows Godot action game. Source lives in this repository; playable releases are published under [GitHub Releases](https://github.com/zerozet22k/SlimeHour_Godot/releases/latest).

## Install and update

1. Download **SlimeHour-Windows.zip** from the latest release.
2. Extract **all** files together: `SlimeHour.exe`, `SlimeHour.pck`, `Start_Slime_Hour.bat`, `update_and_run.ps1`, `updater_config.json`, and `release_manifest.json`.
3. Launch **`SlimeHour.exe` directly**. New updates appear on the main menu; click **UPDATE**, watch the progress inside the game, then choose **INSTALL & RESTART** after checksum verification. No visible command window is used.
4. The optional `Start_Slime_Hour.bat` shortcut now only starts the EXE; it no longer runs the old command-window updater.

**Incremental updates (v0.1.19+):** The in-game updater checks GitHub Releases on startup, selects a matching `SlimeHour-Delta.zip` when possible, downloads it directly to disk with progress, verifies SHA-256, and offers **INSTALL & RESTART**. When you exit the game, a hidden Windows helper reconstructs the new version into a separate folder, verifies its manifest and contents, and restarts Slime Hour. Otherwise it uses the full release ZIP. It never overwrites the running game, and existing saves remain intact.

**Important:** Updating *to* v0.1.7 is a one-time full download because older builds embedded the .pck in the executable and cannot serve as chunk-patch bases. Partial updates become available from subsequent releases. Download size depends on how much data actually changed; unchanged game assets generally do not need downloading again. Existing saves remain in Godot's normal user data location. No admin permissions or Git LFS are required to play.

To edit the game, clone the Git repository with Git LFS installed and open `project.godot` in Godot 4.7.2. The CI system builds and tests Windows releases on version bumps. Android exports are deferred.
