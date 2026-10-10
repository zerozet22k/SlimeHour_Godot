extends Node
## In-game release picker and streaming downloader. Installation of locked Windows
## files is deliberately delegated to the existing SHA256-validating PowerShell
## applier AFTER the game closes, launched through a hidden WScript process.
signal update_found(version: String)
signal status_changed()
signal update_error(message: String)

const RELEASE_API = "https://api.github.com/repos/zerozet22k/SlimeHour_Godot/releases/latest"
const ASSET_ROOT = "https://github.com/zerozet22k/SlimeHour_Godot/releases/download/"
const FULL = "SlimeHour-Windows.zip"
const DELTA = "SlimeHour-Delta.zip"
const MAX_MEMORY_ZIP = 16 * 1024 * 1024

var status = "idle"
var message = ""
var latest = ""
var total_bytes = 0
var transferred_bytes = 0
var download_name = ""
var use_delta = false
var local_version = ""
var sha256 = ""
var pending_zip = ""
var zip_in_memory = false
var pending_release: Dictionary = {}
var assets: Dictionary = {}
var current_step = ""
var http: HTTPRequest
var staging = ""

static func version_is_newer(next: String, previous: String) -> bool:
	var a = next.trim_prefix("v").split(".")
	var b = previous.trim_prefix("v").split(".")
	if a.size() != 3 or b.size() != 3:
		return false
	for i in range(3):
		if not a[i].is_valid_int() or not b[i].is_valid_int():
			return false
		if int(a[i]) != int(b[i]):
			return int(a[i]) > int(b[i])
	return false

static func trusted_asset(asset: Dictionary, name: String, release_tag: String) -> bool:
	if str(asset.get("name", "")) != name:
		return false
	if not release_tag.begins_with("v") or not release_tag.trim_prefix("v").replace(".", "").is_valid_int():
		return false
	var url = ASSET_ROOT + release_tag + "/" + name
	return str(asset.get("browser_download_url", "")) == url and int(asset.get("size", 0)) > 0

static func parse_checksum(body: String, file_name: String) -> String:
	var parts = body.strip_edges().split(" ", false)
	if parts.size() < 2:
		return ""
	var hash_value = str(parts[0]).to_lower()
	if hash_value.length() != 64 or not hash_value.is_valid_hex_number():
		return ""
	var filename = str(parts[parts.size() - 1]).strip_edges().trim_prefix("*")
	return hash_value if filename == file_name else ""

static func zip_use_memory(size: int) -> bool:
	return size > 0 and size <= MAX_MEMORY_ZIP

static func disk_body_limit() -> int:
	return -1

static func describe_result(code: int) -> String:
	match code:
		HTTPRequest.RESULT_SUCCESS: return "success"
		HTTPRequest.RESULT_CANT_CONNECT: return "connection refused"
		HTTPRequest.RESULT_CANT_RESOLVE: return "DNS lookup failed"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "connection lost during transfer"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLS handshake failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "could not open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "failed writing download file"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "response exceeds size limit"
		HTTPRequest.RESULT_TIMEOUT: return "request timed out"
		_: return "request error %d" % code

static func delta_matches(meta: Dictionary, installed: String, wanted: String) -> bool:
	return str(meta.get("base_version", "")) == installed and str(meta.get("target_version", "")) == wanted

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 30.0
	http.max_redirects = 8
	add_child(http)
	http.request_completed.connect(_on_request_complete)
	staging = OS.get_user_data_dir().path_join("updates")
	DirAccess.make_dir_recursive_absolute(staging)

func _process(_delta: float) -> void:
	if current_step == "zip":
		transferred_bytes = mini(total_bytes, http.get_downloaded_bytes())
		status_changed.emit()

func _set_status(next: String, description: String) -> void:
	status = next
	message = description
	status_changed.emit()

func check(installed: String) -> void:
	if current_step != "" or status in ["downloading", "verifying", "ready"]:
		return
	local_version = installed
	_set_status("checking", "Checking for Slime Hour updates...")
	_send("release", RELEASE_API, 1024 * 1024)

func _send(step: String, url: String, max_body: int = 0, output: String = "") -> void:
	current_step = step
	# Small incremental archives download to memory first, avoiding Godot's
	# download-file failures on some Windows installations. Large files still
	# stream to disk without buffering hundreds of megabytes.
	zip_in_memory = step == "zip" and zip_use_memory(total_bytes)
	http.download_file = "" if zip_in_memory else output
	# In Godot, -1 disables the response size limit. Zero means ZERO bytes,
	# which caused the old full-game downloader to fail at HTTP 200 / 0%.
	http.body_size_limit = (total_bytes + 1) if zip_in_memory else (disk_body_limit() if step == "zip" else max_body)
	http.timeout = 900.0 if step == "zip" else 30.0
	var headers = PackedStringArray(["User-Agent: SlimeHour-InGame-Updater", "Accept: application/vnd.github+json"])
	var result = http.request(url, headers)
	if result != OK:
		_fail("Could not start network request (%d)." % result)

func _asset(name: String) -> Dictionary:
	return assets.get(name, {})

func _on_request_complete(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var step = current_step
	current_step = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if step == "delta_meta":
			_begin_asset(FULL)
			return
		_fail("Download %s failed: %s (HTTP %d). Retry or download the release ZIP manually." % [step, describe_result(result), response_code])
		return
	match step:
		"release":
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if not parsed is Dictionary:
				_fail("Invalid release information.")
				return
			latest = str(parsed.get("tag_name", ""))
			if not version_is_newer(latest, local_version):
				_set_status("up_to_date", "You're running the latest version.")
				return
			pending_release = parsed
			assets.clear()
			for item in parsed.get("assets", []):
				if item is Dictionary:
					assets[str(item.get("name", ""))] = item
			if not trusted_asset(_asset(FULL), FULL, latest) or not trusted_asset(_asset(FULL + ".sha256"), FULL + ".sha256", latest):
				_fail("This release has no verified Windows download.")
				return
			_set_status("available", "Update %s is available." % latest)
			update_found.emit(latest)
		"delta_meta":
			var meta = JSON.parse_string(body.get_string_from_utf8())
			if meta is Dictionary and delta_matches(meta, local_version, latest):
				use_delta = true
				_begin_asset(DELTA)
			else:
				_begin_asset(FULL)
		"checksum":
			sha256 = parse_checksum(body.get_string_from_utf8(), download_name)
			if sha256 == "":
				_fail("The release checksum is missing or invalid.")
				return
			_set_status("downloading", "Downloading " + download_name + "...")
			_send("zip", str(_asset(download_name)["browser_download_url"]), 0, pending_zip)
		"zip":
			if zip_in_memory:
				if body.size() != total_bytes:
					_fail("Incomplete patch: received %d of %d bytes." % [body.size(), total_bytes])
					return
				var patch_file = FileAccess.open(pending_zip, FileAccess.WRITE)
				if patch_file == null:
					_fail("Could not save the patch to disk (error %d)." % FileAccess.get_open_error())
					return
				patch_file.store_buffer(body)
				patch_file.close()
			if not FileAccess.file_exists(pending_zip):
				_fail("Downloaded update file was not saved.")
				return
			var file_handle = FileAccess.open(pending_zip, FileAccess.READ)
			var size = file_handle.get_length() if file_handle != null else -1
			if file_handle != null:
				file_handle.close()
			if size != total_bytes:
				_fail("Incomplete download. Expected %d bytes, got %d." % [total_bytes, size])
				return
			_set_status("verifying", "Checking SHA-256 integrity...")
			# A bounded, disk-backed archive: never load hundreds of MB into RAM.
			var digest = FileAccess.get_sha256(pending_zip).to_lower()
			if digest != sha256:
				_fail("Checksum mismatch: update was discarded.")
				return
			transferred_bytes = total_bytes
			_set_status("ready", "Verified. Install and restart when ready.")

func begin_download() -> void:
	if status not in ["available", "error"]:
		return
	if latest == "":
		check(local_version)
		return
	use_delta = false
	sha256 = ""
	transferred_bytes = 0
	var base = OS.get_executable_path().get_base_dir().path_join("release_manifest.json")
	var can_patch = false
	if FileAccess.file_exists(base):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(base))
		can_patch = manifest is Dictionary and str(manifest.get("version", "")) == local_version
	if can_patch and trusted_asset(_asset(DELTA), DELTA, latest) and trusted_asset(_asset(DELTA + ".sha256"), DELTA + ".sha256", latest) and trusted_asset(_asset("SlimeHour-Delta.json"), "SlimeHour-Delta.json", latest):
		_set_status("checking", "Checking for a smaller incremental download...")
		_send("delta_meta", str(_asset("SlimeHour-Delta.json")["browser_download_url"]), 4096)
	else:
		_begin_asset(FULL)

func _begin_asset(name: String) -> void:
	download_name = name
	var target: Dictionary = _asset(name)
	if not trusted_asset(target, name, latest):
		_fail("Invalid GitHub update asset.")
		return
	total_bytes = int(target["size"])
	if total_bytes > 1024 * 1024 * 1024:
		_fail("Release size exceeds the safety limit.")
		return
	pending_zip = staging.path_join(latest + "-" + name)
	if FileAccess.file_exists(pending_zip):
		DirAccess.remove_absolute(pending_zip)
	_set_status("checking", "Fetching SHA-256 checksum...")
	_send("checksum", str(_asset(name + ".sha256")["browser_download_url"]), 512)

func retry() -> void:
	if status == "error" and latest != "":
		status = "available"
		begin_download()
	elif current_step == "":
		check(local_version)

func cancel() -> void:
	if current_step != "":
		http.cancel_request()
		current_step = ""
	if pending_zip != "" and FileAccess.file_exists(pending_zip) and status != "ready":
		DirAccess.remove_absolute(pending_zip)
	_set_status("available" if latest != "" else "idle", "Download cancelled.")

func _fail(why: String) -> void:
	current_step = ""
	if pending_zip != "" and FileAccess.file_exists(pending_zip):
		DirAccess.remove_absolute(pending_zip)
	_set_status("error", why)
	update_error.emit(why)

func install_and_restart() -> bool:
	if status != "ready" or pending_zip == "" or not FileAccess.file_exists(pending_zip):
		_fail("No verified update has been downloaded.")
		return false
	if FileAccess.get_sha256(pending_zip).to_lower() != sha256:
		_fail("The downloaded file changed after verification.")
		return false
	if not OS.has_feature("windows"):
		_fail("Automatic restart is available only in Windows releases.")
		return false
	var installed_dir = OS.get_executable_path().get_base_dir()
	var updater_script = installed_dir.path_join("update_and_run.ps1")
	if not FileAccess.file_exists(updater_script):
		_fail("Installation helper is missing. Download the full game from GitHub Releases.")
		return false
	var arguments = ' -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -InstallDownloaded "%s" -InstallVersion "%s" -ExpectedSha256 "%s" -BaseDirectory "%s" -WaitPid %d -DownloadKind "%s"' % [
		updater_script, pending_zip, latest, sha256, installed_dir, OS.get_process_id(), "delta" if use_delta else "full"]
	# wscript.exe creates a genuinely hidden process. No cmd or PowerShell UI appears.
	# All paths originate locally or from a strictly validated release tag.
	var script_file = staging.path_join("apply_in_background.vbs")
	var line = 'CreateObject("WScript.Shell").Run "powershell.exe%s", 0, False\r\n' % arguments.replace('"', '""')
	var file = FileAccess.open(script_file, FileAccess.WRITE)
	if file == null:
		_fail("Could not prepare the hidden updater.")
		return false
	file.store_string(line)
	file.close()
	var pid = OS.create_process("wscript.exe", PackedStringArray([script_file]))
	if pid <= 0:
		_fail("Could not launch the update installer. The game has not been changed.")
		return false
	_set_status("installing", "Applying verified update, restarting Slime Hour...")
	return true
