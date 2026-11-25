extends Node
## Every game number comes from here. The defaults ship in res://data/, which is read-only on Android,
## so any edits made in Admin Mode are kept in user://overrides.json and laid on top of the defaults.

signal changed

const FILES := ["cards", "towers", "battle", "chests", "economy", "progression", "bot", "defense"]
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


## Changes one value, for example set_override("cards", ["cards", "hobb", "health"], 300).
## Only the changed value is stored, which means the rest still follows the shipped defaults.
func set_override(file: String, path: Array, value: Variant) -> void:
	var node: Dictionary = overrides.get_or_add(file, {})
	for key in path.slice(0, -1):
		node = node.get_or_add(key, {})
	node[path[-1]] = value
	_store()


## Throws away the overrides under one path, which puts that part back to the shipped defaults.
func reset_override(file: String, path: Array) -> void:
	var node: Variant = overrides.get(file, {})
	for key in path.slice(0, -1):
		node = node.get(key, {}) if node is Dictionary else {}
	if node is Dictionary:
		node.erase(path[-1])
	_store()


## Returns the shipped default for one path, so Admin Mode can show what a value was before editing.
func default_value(file: String, path: Array) -> Variant:
	var node: Variant = _defaults.get(file, {})
	for key in path:
		node = node.get(key) if node is Dictionary else null
	return node


## Replaces every override at once, which is what importing a backup does.
func replace_overrides(new_overrides: Dictionary) -> void:
	overrides = new_overrides
	_store()


func _store() -> void:
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
