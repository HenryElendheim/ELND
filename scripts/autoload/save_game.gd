extends StoredDict
## The player's progress. It only holds a format number for now, and later milestones add cards, gold, trophies and stats.


func _init() -> void:
	path = "user://save.json"
	defaults = {"format": 1}
