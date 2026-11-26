extends StoredDict
## The player's progress. It only holds a format number for now, and later milestones add cards, gold, reputation and stats.


func _init() -> void:
	path = "user://save.json"
	defaults = {"format": 1}


## Trophies were renamed to reputation, so older saves and backups get their numbers moved across.
func upgrade(loaded: Dictionary) -> Dictionary:
	JsonFile.rename_key(loaded, "trophies", "reputation")
	if loaded.get("stats") is Dictionary:
		JsonFile.rename_key(loaded.stats, "highest_trophies", "highest_reputation")
	return loaded
