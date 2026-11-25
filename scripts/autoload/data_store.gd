extends Node
## Every game number comes from here. The defaults ship in res://data/, which is read-only on Android,
## so any edits made in Admin Mode are kept in user://overrides.json and laid on top of the defaults.

signal changed

const FILES := ["cards", "towers", "battle", "chests", "economy", "progression", "bot"]
const OVERRIDES_PATH := "user://overrides.json"

var _defaults := {}
var _tables := {}
var overrides := {}


func _ready() -> void:
	for file in FILES:
		_defaults[file] = JsonFile.read("res://data/%s.json" % file, {})
	overrides = JsonFile.read(OVERRIDES_PATH, {})
	_rebuild()


## Returns one data file with its overrides already applied, for example Data.table("towers").
func table(file: String) -> Dictionary:
	return _tables.get(file, {})


## Replaces every override at once, which is what importing a backup does.
func replace_overrides(new_overrides: Dictionary) -> void:
	overrides = new_overrides
	JsonFile.write(OVERRIDES_PATH, overrides)
	_rebuild()


func _rebuild() -> void:
	for file in FILES:
		_tables[file] = _deep_merge(_defaults[file], overrides.get(file, {}))
	changed.emit()


## Copies the base and then lays the changes over it, going into nested dictionaries
## so that changing one stat of one card keeps all its other stats.
static func _deep_merge(base: Dictionary, changes: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in changes:
		if result.get(key) is Dictionary and changes[key] is Dictionary:
			result[key] = _deep_merge(result[key], changes[key])
		else:
			result[key] = changes[key]
	return result
