class_name StoredDict
extends Node
## Base for the autoloads that keep one dictionary saved in a file under user://.
## Settings and the save game both work this way, which means the load, save and replace logic lives here once.

signal changed

## Each child sets these two before calling super._ready().
var path := ""
var defaults := {}

var values := {}


func _ready() -> void:
	values = defaults.merged(upgrade(JsonFile.read(path, {})), true)
	_on_values_changed()


func get_value(key: String) -> Variant:
	return values.get(key, defaults.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	_commit()


## Swaps everything at once, which is what importing a backup does.
func replace_all(new_values: Dictionary) -> void:
	values = defaults.merged(upgrade(new_values), true)
	_commit()


func _commit() -> void:
	JsonFile.write(path, values)
	_on_values_changed()
	changed.emit()


## Children override this to bring files saved by older versions up to date before they are used.
func upgrade(loaded: Dictionary) -> Dictionary:
	return loaded


## Children override this when they need to react, for example by rebuilding the theme.
func _on_values_changed() -> void:
	pass
