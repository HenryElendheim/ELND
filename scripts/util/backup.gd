class_name Backup
## Packs settings, progress and Admin Mode overrides into one JSON file the player can keep,
## and lets the player pick where that file goes on the device.

const FORMAT := 1
const FILE_NAME := "elnd-backup.json"
const IMPORTED := "Imported"


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


const BALANCE_FILE_NAME := "elnd-balance.json"


## Asks the system where to save the backup and writes it there. The callback gets a short message for the player.
static func export_to_device(done: Callable) -> void:
	_pick(DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, FILE_NAME, func(path: String) -> void: _write(path, collect(), done), done)


## Asks the system which backup file to open and restores it.
static func import_from_device(done: Callable) -> void:
	_pick(DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, FILE_NAME, func(path: String) -> void: _read(path, "backup", done), done)


## A balance setup is only the Admin Mode edits, so it can be shared or swapped without touching progress or settings.
static func export_balance(done: Callable) -> void:
	var balance := {"format": FORMAT, "balance": Data.overrides}
	_pick(DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, BALANCE_FILE_NAME, func(path: String) -> void: _write(path, balance, done), done)


static func import_balance(done: Callable) -> void:
	_pick(DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, BALANCE_FILE_NAME, func(path: String) -> void: _read(path, "balance", done), done)


static func restore_balance(file: Dictionary) -> bool:
	if not file.get("balance") is Dictionary:
		return false
	Data.replace_overrides(file.balance)
	return true


static func _write(path: String, contents: Dictionary, done: Callable) -> void:
	done.call("Saved" if JsonFile.write(path, contents) else "Could not save the file")


## Reads a file and puts it in place as a full backup or as a balance setup, depending on kind.
static func _read(path: String, kind: String, done: Callable) -> void:
	var contents: Dictionary = JsonFile.read(path, {})
	var applied := restore_balance(contents) if kind == "balance" else restore(contents)
	done.call(IMPORTED if applied else "That file is not an ELND file")


## Opens the phone's own file picker when it has one. Without it, the file goes to the Downloads folder instead.
static func _pick(mode: DisplayServer.FileDialogMode, file_name: String, on_path: Callable, done: Callable) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		on_path.call(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(file_name))
		return
	var start_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var filters := PackedStringArray(["*.json"])
	DisplayServer.file_dialog_show("ELND", start_dir, file_name, false, mode, filters,
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
