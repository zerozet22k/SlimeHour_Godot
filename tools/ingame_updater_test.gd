extends SceneTree
## No internet, no real files touched: verify release parsing and asset trust.
const Updater = preload("res://scripts/InGameUpdater.gd")
var failed := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failed += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	check(Updater.version_is_newer("v0.1.17", "v0.1.16"), "semantic version newer")
	check(not Updater.version_is_newer("v0.1.16", "v0.1.16"), "same version ignored")
	check(not Updater.version_is_newer("v0.1.15", "v0.1.16"), "downgrade forbidden")
	check(not Updater.version_is_newer("vX", "v0.1.16"), "non-numeric tags ignored")
	var asset = {"name": "SlimeHour-Delta.zip", "size": 4525,
		"browser_download_url": "https://github.com/zerozet22k/SlimeHour_Godot/releases/download/v0.1.17/SlimeHour-Delta.zip"}
	check(Updater.trusted_asset(asset, "SlimeHour-Delta.zip", "v0.1.17"), "exact official GitHub asset accepted")
	var hostile = asset.duplicate()
	hostile["browser_download_url"] = "https://example.com/SlimeHour-Delta.zip"
	check(not Updater.trusted_asset(hostile, "SlimeHour-Delta.zip", "v0.1.17"), "untrusted domain rejected")
	check(not Updater.trusted_asset(asset, "../game.exe", "v0.1.17"), "asset path cannot escape installation")
	var digest = "a".repeat(64)
	check(Updater.parse_checksum(digest + "  SlimeHour-Delta.zip", "SlimeHour-Delta.zip") == digest, "valid SHA256 checksum")
	check(Updater.parse_checksum("not-a-hash SlimeHour-Delta.zip", "SlimeHour-Delta.zip") == "", "invalid checksum rejected")
	check(Updater.parse_checksum(digest + "  unrelated.zip", "SlimeHour-Delta.zip") == "", "wrong checksum filename rejected")
	check(Updater.delta_matches({"base_version": "v0.1.16", "target_version": "v0.1.17"}, "v0.1.16", "v0.1.17"), "matching delta selected")
	# Cached verified ZIPs must survive updater restarts; incorrect bytes
	# or lengths must never be accepted as downloaded releases.
	var cache_path = OS.get_user_data_dir().path_join("slime_updater_cache_test.bin")
	var cache = FileAccess.open(cache_path, FileAccess.WRITE)
	check(cache != null, "Can create updater cache regression fixture")
	if cache != null:
		cache.store_string("existing release bytes")
		cache.close()
		var digest_cache = FileAccess.get_sha256(cache_path)
		check(Updater.cached_archive_matches(cache_path, 22, digest_cache), "Matching verified ZIP reused instead of downloading again")
		check(not Updater.cached_archive_matches(cache_path, 23, digest_cache), "Wrong cached archive length rejected")
		check(not Updater.cached_archive_matches(cache_path, 22, "0".repeat(64)), "Incorrect cached archive hash rejected")
		DirAccess.remove_absolute(cache_path)
	check(not Updater.delta_matches({"base_version": "v0.1.15", "target_version": "v0.1.17"}, "v0.1.16", "v0.1.17"), "wrong base needs full update")
	print("IN-GAME UPDATER: " + ("PASS" if failed == 0 else str(failed) + " failed"))
	quit(1 if failed else 0)
