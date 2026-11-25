class_name Backup
## Packs settings, progress and Admin Mode overrides into one JSON file the player can keep,
## and lets the player pick where that file goes on the device.

const FORMAT := 1
const FILE_NAME := "elnd-backup.json"
const IMPORTED := "Backup imported"


static func collect() -> Dictionary:
	return {
		"format": FORMAT,
		"settings": Settings.values,
		"save": Save.values,
		"overrides": Data.overrides,
	}


## Puts a backup back in place. It returns false when the file is not an ELND backup, which means nothing is changed.
static func restore(backup: Dictionary) -> bool:
	var format: Variant = backup.get("format", 0)
	if typeof(format) != TYPE_FLOAT or int(format) != FORMAT:
		return false
	Settings.replace_all(_section(backup, "settings"))
	Save.replace_all(_section(backup, "save"))
	Data.replace_overrides(_section(backup, "overrides"))
	return true


## Asks the system where to save the backup and writes it there. The callback gets a short message for the player.
static func export_to_device(done: Callable) -> void:
	_pick(DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, func(path: String) -> void: _write(path, done), done)


## Asks the system which backup file to open and restores it.
static func import_from_device(done: Callable) -> void:
	_pick(DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, func(path: String) -> void: _read(path, done), done)


static func _write(path: String, done: Callable) -> void:
	var saved := JsonFile.write(path, collect())
	done.call("Backup saved" if saved else "Could not save the backup")


static func _read(path: String, done: Callable) -> void:
	var restored := restore(JsonFile.read(path, {}))
	done.call(IMPORTED if restored else "That file is not an ELND backup")


## Opens the phone's own file picker when it has one. Without it, the file goes to the Downloads folder instead.
static func _pick(mode: DisplayServer.FileDialogMode, on_path: Callable, done: Callable) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		on_path.call(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(FILE_NAME))
		return
	var start_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var filters := PackedStringArray(["*.json"])
	DisplayServer.file_dialog_show("ELND backup", start_dir, FILE_NAME, false, mode, filters,
		func(picked: bool, paths: PackedStringArray, _filter: int) -> void: _picked(picked, paths, on_path, done))


## The picker may answer from outside the main loop, so the work is pushed to the next frame to stay safe.
static func _picked(picked: bool, paths: PackedStringArray, on_path: Callable, done: Callable) -> void:
	if picked and not paths.is_empty():
		on_path.call_deferred(paths[0])
	else:
		done.call_deferred("Cancelled")


## Returns one part of the backup, or an empty dictionary when that part is missing or broken.
static func _section(backup: Dictionary, key: String) -> Dictionary:
	var part: Variant = backup.get(key, {})
	return part if part is Dictionary else {}
