# Slime Hour

Windows Godot action game. Source lives in this repository; playable releases are published under [GitHub Releases](https://github.com/zerozet22k/SlimeHour_Godot/releases/latest).

## Install and update

1. Download **SlimeHour-Windows.zip** from the latest release.
2. Extract **all** files together: `SlimeHour.exe`, `SlimeHour.pck`, `Start_Slime_Hour.bat`, `update_and_run.ps1`, `updater_config.json`, and `release_manifest.json`.
3. Launch `SlimeHour.exe`. When a new version is available, the **UPDATE** option appears on the main menu. Alternatively, run `Start_Slime_Hour.bat` to check and launch.

**Incremental updates (v0.1.7+):** Starting in v0.1.7 the Windows export splits the engine executable and Godot content pack. The updater compares the local version with the newest GitHub Release. If it has a matching `SlimeHour-Delta.zip`, it downloads only changed chunks, reconstructs the new executable and .pck from the old files, and verifies every file's SHA-256 checksum. Unchanged chunks stay local. If players skipped versions, downloaded corrupted data, or use an older v0.1.6-or-earlier install, the updater transparently uses the full ZIP.

**Important:** Updating *to* v0.1.7 is a one-time full download because older builds embedded the .pck in the executable and cannot serve as chunk-patch bases. Partial updates become available from subsequent releases. Download size depends on how much data actually changed; unchanged game assets generally do not need downloading again. Existing saves remain in Godot's normal user data location. No admin permissions or Git LFS are required to play.

To edit the game, clone the Git repository with Git LFS installed and open `project.godot` in Godot 4.7.2. The CI system builds and tests Windows releases on version bumps. Android exports are deferred.
