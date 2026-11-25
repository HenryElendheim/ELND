class_name Progress
## Everything about the player's progress: trophies, arenas, player level, card levels, wild cards and chests.
## It all lives in the save game, and every number comes from progression.json, chests.json and economy.json.


static func _table(name: String) -> Dictionary:
	return Data.table(name)


static func trophies() -> int:
	return int(_get("trophies", 0))


## Arena 1 starts at zero trophies, and a new arena opens every few hundred trophies.
static func arena() -> int:
	return 1 + trophies() / int(_table("progression").trophies.per_arena)


static func player_level() -> int:
	return int(_get("player_level", 1))


static func xp() -> int:
	return int(_get("xp", 0))


static func gold() -> int:
	return int(_get("gold", 0))


static func wild_cards() -> int:
	return int(_get("wild_cards", 0))


## XP needed to go from the current level to the next one.
static func xp_to_next() -> int:
	var xp_table: Dictionary = _table("progression").xp
	return int(xp_table.next_level_base) + int(xp_table.next_level_per_level) * player_level()


## Towers level up every few player levels, up to a cap.
static func tower_level() -> int:
	var towers: Dictionary = _table("progression").towers
	return mini(1 + (player_level() - 1) / int(towers.level_up_every_player_levels), int(towers.max_level))


## A card's level and spare copies. Every unlocked card starts at level 1. A locked card has level 0.
static func card(id: String) -> Dictionary:
	var cards: Dictionary = _get("cards", {})
	if cards.has(id):
		return {"level": int(cards[id].level), "copies": int(cards[id].copies)}
	var unlocked := int(Data.table("cards").cards[id].get("unlock_arena", 1)) <= arena()
	return {"level": 1 if unlocked else 0, "copies": 0}


static func copies_for_next(level: int) -> int:
	return int(_table("progression").cards.copies_per_level_step) * level


static func max_card_level() -> int:
	return int(_table("progression").cards.max_level)


## The level a card fights at. Pure Balance mode puts everything at level 1.
static func battle_level(id: String) -> int:
	return 1 if Settings.get_value("pure_balance") else maxi(int(card(id).level), 1)


## The bot's cards scale with how far along the trophy road the player is, and match the player at the top.
static func bot_level() -> int:
	if Settings.get_value("pure_balance"):
		return 1
	var total := 0
	var cards := BattleSim.available_cards()
	for id in cards:
		total += maxi(int(card(id).level), 1)
	var average := float(total) / maxf(cards.size(), 1)
	var share := clampf(float(trophies()) / float(_table("progression").road_top_trophies), 0.0, 1.0)
	return maxi(roundi(lerpf(1.0, average, share)), 1)


## Records a finished match. A win gives trophies, XP and gold, and a loss takes trophies away.
## Pure Balance gives the chest but no trophies, which keeps the trophy road meaningful. Every match ends with a chest.
static func record_match(result: String) -> void:
	var progression: Dictionary = _table("progression")
	var won := result == "player"
	if not Settings.get_value("pure_balance") and result != "draw":
		var change := int(progression.trophies.win) if won else int(progression.trophies.loss)
		_set("trophies", maxi(trophies() + change, 0))
	if won:
		add_xp(int(progression.xp.per_win))
		add_gold(int(_table("economy").gold.per_win))
	_set("games", int(_get("games", 0)) + 1)
	queue_chest(roll_chest())


static func add_gold(amount: int) -> void:
	_set("gold", gold() + amount)


## Adds XP and handles every level up it causes. Each level gives gold, and every other level gives a rank up chest.
static func add_xp(amount: int) -> void:
	var economy: Dictionary = _table("economy")
	var current := xp() + amount
	while current >= xp_to_next():
		current -= xp_to_next()
		_set("player_level", player_level() + 1)
		add_gold(int(economy.gold.per_player_level))
		if player_level() % int(economy.rank_up_chest.every_player_levels) == 0:
			queue_chest(economy.rank_up_chest.chest)
			add_gold(int(economy.rank_up_chest.gold))
	_set("xp", current)


## Picks the chest rarity from the odds, with a guaranteed Legendary if none came in the last stretch of games.
static func roll_chest() -> String:
	var chests: Dictionary = _table("chests")
	var dry := int(_get("games_since_legendary", 0)) + 1
	var rarity := "legendary" if dry >= int(chests.legendary_pity_games) else _weighted(chests.odds)
	_set("games_since_legendary", 0 if rarity == "legendary" else dry)
	return rarity


static func queue_chest(rarity: String) -> void:
	var waiting: Array = _get("chests_waiting", []).duplicate()
	waiting.append(rarity)
	_set("chests_waiting", waiting)


static func chests_waiting() -> Array:
	return _get("chests_waiting", [])


## Opens the first waiting chest and returns what came out, as a list of {"id", "count"} entries plus any extras.
## Chests give more cards in higher arenas. Copies are added straight away, and cards level up on their own.
static func open_next_chest() -> Dictionary:
	var waiting: Array = chests_waiting().duplicate()
	if waiting.is_empty():
		return {}
	var rarity: String = waiting.pop_front()
	_set("chests_waiting", waiting)
	var chests: Dictionary = _table("chests")
	var contents: Dictionary = chests.contents[rarity]
	var count := roundi(float(contents.cards) * (1.0 + float(chests.arena_scaling) * (arena() - 1)))
	var pool := _unlocked_by_rarity()
	var drops := {}
	for i in count:
		var card_rarity := _weighted(chests.rarity_weights[rarity])
		var options: Array = pool.get(card_rarity, [])
		if options.is_empty():
			options = pool.get("common", [])
		var id: String = options[randi() % options.size()]
		drops[id] = int(drops.get(id, 0)) + 1
	for extra in contents.guaranteed:
		if extra.ends_with("_card"):
			var options: Array = pool.get(extra.trim_suffix("_card"), [])
			if not options.is_empty():
				var id: String = options[randi() % options.size()]
				drops[id] = int(drops.get(id, 0)) + int(contents.guaranteed[extra])
	var opened := []
	for id in drops:
		var before: int = card(id).level
		var is_new := _never_seen(id)
		add_copies(id, drops[id])
		opened.append({"id": id, "count": drops[id], "new": is_new, "level": card(id).level, "levelled": card(id).level > before})
	_mark_seen(drops.keys())
	return {"rarity": rarity, "cards": opened}


## Adds copies of a card and levels it up as far as they allow. Copies of a maxed card become wild cards.
static func add_copies(id: String, amount: int) -> void:
	var cards: Dictionary = _get("cards", {}).duplicate(true)
	var entry: Dictionary = card(id)
	entry.level = maxi(int(entry.level), 1)
	entry.copies = int(entry.copies) + amount
	_level_up(id, entry)
	cards[id] = entry
	_set("cards", cards)


## Spends wild cards on one card, as many as it needs for its next level or as many as there are.
static func use_wild_cards(id: String) -> void:
	var entry: Dictionary = card(id)
	if int(entry.level) >= max_card_level() or wild_cards() <= 0:
		return
	var needed := maxi(copies_for_next(int(entry.level)) - int(entry.copies), 0)
	var spent := mini(needed, wild_cards())
	_set("wild_cards", wild_cards() - spent)
	add_copies(id, spent)


static func _level_up(id: String, entry: Dictionary) -> void:
	var progression: Dictionary = _table("progression")
	while int(entry.level) < max_card_level() and int(entry.copies) >= copies_for_next(int(entry.level)):
		entry.copies = int(entry.copies) - copies_for_next(int(entry.level))
		entry.level = int(entry.level) + 1
		add_xp(int(progression.xp.per_card_level_up))
		add_gold(int(_table("economy").gold.per_card_upgrade_times_level) * int(entry.level))
	if int(entry.level) >= max_card_level() and int(entry.copies) > 0:
		_set("wild_cards", wild_cards() + int(entry.copies))
		entry.copies = 0


## Unlocked cards grouped by rarity, which is worked out from each card's Codex threat level.
static func _unlocked_by_rarity() -> Dictionary:
	var cards_table := Data.table("cards")
	var groups := {}
	for id in cards_table.cards:
		var entry: Dictionary = cards_table.cards[id]
		if int(entry.get("unlock_arena", 1)) > arena() or not entry.get("type") in Data.table("battle").playable_types:
			continue
		var rarity: String = cards_table.rarity_by_threat[str(int(entry.threat))]
		groups.get_or_add(rarity, []).append(id)
	return groups


static func _never_seen(id: String) -> bool:
	return not id in _get("seen_cards", [])


static func _mark_seen(ids: Array) -> void:
	var seen: Array = _get("seen_cards", []).duplicate()
	for id in ids:
		if not id in seen:
			seen.append(id)
	_set("seen_cards", seen)


static func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += float(weights[key])
	var roll := randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return key
	return weights.keys()[-1]


static func _get(key: String, fallback: Variant) -> Variant:
	var value: Variant = Save.get_value(key)
	return fallback if value == null else value


static func _set(key: String, value: Variant) -> void:
	Save.set_value(key, value)
