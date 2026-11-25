class_name JsonFile
## Small helpers for reading and writing JSON, so every system saves files the same way.


## Reads a whole text file and returns an empty string when the file cannot be opened.
static func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## Writes text to a file and returns true when it worked.
static func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## Turns JSON text into data. If the text is broken or the wrong shape, the fallback is returned instead.
static func parse(text: String, fallback: Variant) -> Variant:
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if typeof(parsed) == typeof(fallback) else fallback


static func read(path: String, fallback: Variant) -> Variant:
	return parse(read_text(path), fallback)


static func write(path: String, data: Variant) -> bool:
	return write_text(path, JSON.stringify(data, "\t"))
