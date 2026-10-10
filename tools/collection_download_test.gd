extends SceneTree
const Paging = preload("res://scripts/CollectionPaging.gd")
const Updater = preload("res://scripts/InGameUpdater.gd")
var failed = 0
func check(ok: bool, name: String) -> void:
	if ok:
		print("PASS: ", name)
	else:
		failed += 1
		push_error("FAIL: " + name)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(Paging.window_size(false) == 4, "desktop collection has horizontal cards")
	check(Paging.window_size(true) == 2, "portrait collection has horizontal cards")
	check(Paging.range_indices(10, 4, 0) == [0, 1, 2, 3], "first display reads left to right")
	var cursor = Paging.offset(10, 4, 0, 1)
	check(cursor == 1, "NEXT advances by ONE item")
	check(Paging.range_indices(10, 4, cursor) == [1, 2, 3, 4], "horizontal strip shifts left")
	check(Paging.offset(10, 4, cursor, -1) == 0, "PREVIOUS shifts strip right")
	check(Paging.offset(10, 4, 6, 1) == 6, "can't scroll beyond final window")
	check(Paging.range_indices(2, 4, 500) == [0, 1], "small category never leaves empty spaces")
	check(Paging.range_indices(0, 4, 0).is_empty(), "empty collection is safe")
	check(Paging.range_indices(6, 2, 2) == [2, 3], "portrait sequence matches catalog order")
	check(Updater.zip_use_memory(865288), "GitHub's 0.8 MB delta uses safe memory path")
	check(not Updater.zip_use_memory(305951030), "large Windows ZIP streams to disk")
	check(Updater.disk_body_limit() == -1, "full downloads have NO HTTP size-limit restriction")
	check(Updater.describe_result(HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN).find("file") >= 0, "file-open errors have specific diagnostics")
	check(Updater.describe_result(HTTPRequest.RESULT_CONNECTION_ERROR).find("connection") >= 0, "network errors are distinguished from HTTP status")
	print("COLLECTION / DOWNLOAD: ", "PASS" if failed == 0 else str(failed) + " failures")
	quit(1 if failed else 0)
