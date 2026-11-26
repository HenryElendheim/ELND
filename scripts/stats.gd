class_name Stats
## Keeps the player's statistics in the save game: results per mode and per difficulty, reputation, streaks,
## the cards that get played and how often they win, decks, chests, play time and the best Defense wave.


static func all() -> Dictionary:
	var value: Variant = Save.get_value("stats")
	return value.duplicate(true) if value is Dictionary else {}


static func _store(stats: Dictionary) -> void:
	Save.set_value("stats", stats)


## Adds one to a counter inside nested dictionaries, for example bump(stats, ["by_mode", "battle", "wins"]).
static func bump(stats: Dictionary, path: Array, amount := 1.0) -> void:
	var node := stats
	for key in path.slice(0, -1):
		node = node.get_or_add(key, {})
	node[path[-1]] = float(node.get(path[-1], 0.0)) + amount


## Records one finished match with everything the stats screen shows.
static func record_match(mode: String, result: String, cores: int, played: Array, deck: Array, seconds: float) -> void:
	var stats := all()
	var outcome: String = {"player": "wins", "enemy": "losses"}.get(result, "draws")
	bump(stats, ["games"])
	bump(stats, [outcome])
	bump(stats, ["by_mode", mode, outcome])
	bump(stats, ["by_difficulty", Settings.get_value("bot_difficulty"), outcome])
	bump(stats, ["seconds"], seconds)
	if result == "player":
		bump(stats, ["streak"])
		stats.best_streak = maxf(float(stats.get("best_streak", 0)), float(stats.streak))
		if cores >= 3:
			bump(stats, ["three_cores"])
	else:
		stats.streak = 0.0
	stats.highest_reputation = maxf(float(stats.get("highest_reputation", 0)), float(Progress.reputation()))
	var counted := {}
	for id in played:
		bump(stats, ["card_plays", id])
		if not counted.has(id):
			counted[id] = true
			bump(stats, ["card_games", id])
			if result == "player":
				bump(stats, ["card_wins", id])
	var deck_key := ",".join(PackedStringArray(deck.duplicate().map(func(id: Variant) -> String: return str(id))))
	bump(stats, ["decks", deck_key])
	_store(stats)


## A match the player left. It counts on its own and never touches wins, losses or the win streak.
static func record_cancel(mode: String) -> void:
	var stats := all()
	bump(stats, ["cancelled"])
	bump(stats, ["by_mode", mode, "cancelled"])
	_store(stats)


static func record_chest(rarity: String, legendary_cards: int) -> void:
	var stats := all()
	bump(stats, ["chests", rarity])
	bump(stats, ["legendaries_pulled"], legendary_cards)
	_store(stats)


static func record_wave(wave: int) -> void:
	var stats := all()
	stats.best_wave = maxf(float(stats.get("best_wave", 0)), float(wave))
	_store(stats)


## The key with the biggest number in a dictionary of counters, or an empty string when there are none.
static func top(counters: Dictionary) -> String:
	var best := ""
	for key in counters:
		if best == "" or float(counters[key]) > float(counters[best]):
			best = key
	return best
