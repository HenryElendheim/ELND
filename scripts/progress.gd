class_name Progress
## Everything about the player's progress: reputation, arenas, player level, card levels, wild cards and chests.
## It all lives in the save game, and every number comes from progression.json, chests.json and economy.json.

## The chest that comes every few games and holds Evolution Injections.
const INJECTION_CHEST := "injection"


static func _table(name: String) -> Dictionary:
	return Data.table(name)


static func reputation() -> int:
	return int(_read("reputation", 0))


## Arena 1 starts at zero reputation, and a new arena opens every few hundred reputation.
static func arena() -> int:
	return 1 + reputation() / int(_table("progression").reputation.per_arena)


## The name of a Lab or Site on the reputation road, such as "Site 49". Past the named ones they are numbered Sites.
static func arena_name(index: int) -> String:
	var names: Array = _table("progression").get("arena_names", [])
	return String(names[index - 1]) if index >= 1 and index <= names.size() else "Site %d" % index


## How many Labs and Sites the reputation road has.
static func arena_count() -> int:
	var names: Array = _table("progression").get("arena_names", [])
	return maxi(names.size(), 1 + int(_table("progression").road_top_reputation) / int(_table("progression").reputation.per_arena))


## The reputation needed to reach a Lab or Site.
static func reputation_for(index: int) -> int:
	return (index - 1) * int(_table("progression").reputation.per_arena)


static func player_level() -> int:
	return int(_read("player_level", 1))


static func xp() -> int:
	return int(_read("xp", 0))


static func gold() -> int:
	return int(_read("gold", 0))


static func wild_cards() -> int:
	return int(_read("wild_cards", 0))


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
	var cards: Dictionary = _read("cards", {})
	if cards.has(id):
		return {"level": int(cards[id].level), "copies": int(cards[id].copies)}
	var unlocked := int(Data.table("cards").cards[id].get("unlock_arena", 1)) <= arena()
	return {"level": 1 if unlocked else 0, "copies": 0}


## A card's rarity, which follows its Codex threat level.
static func card_rarity(id: String) -> String:
	var cards_table := Data.table("cards")
	return cards_table.rarity_by_threat.get(str(int(cards_table.cards[id].threat)), "common")


static func copies_for_next(level: int) -> int:
	return int(_table("progression").cards.copies_per_level_step) * level


static func max_card_level() -> int:
	return int(_table("progression").cards.max_level)


## The level a card fights at. Pure Balance mode puts everything at level 1.
static func battle_level(id: String) -> int:
	return 1 if Settings.get_value("pure_balance") else maxi(int(card(id).level), 1)


## The bot's cards scale with how far along the reputation road the player is, and match the player at the top.
static func bot_level() -> int:
	if Settings.get_value("pure_balance"):
		return 1
	var total := 0
	var cards := BattleSim.available_cards()
	for id in cards:
		total += maxi(int(card(id).level), 1)
	var average := float(total) / maxf(cards.size(), 1)
	var share := clampf(float(reputation()) / float(_table("progression").road_top_reputation), 0.0, 1.0)
	return maxi(roundi(lerpf(1.0, average, share)), 1)


## Buys a chest from the Shop with gold. It returns false when there is not enough gold.
static func buy_chest(rarity: String) -> bool:
	var price := int(_table("economy").shop_prices[rarity])
	if gold() < price:
		return false
	add_gold(-price)
	queue_chest(rarity)
	return true


## Records a finished Defense run and the best wave. No reputation changes hands. Destroying the enemy core gives a chest
## that is better the faster it fell, and a run that ends with your main tower down gives one that is better the further it got.
static func record_defense(reached: int, won := false, seconds := 0.0) -> void:
	queue_chest(Waves.win_chest(seconds) if won else Waves.chest_for(reached))
	_count_game()
	Stats.record_wave(reached)


## Records a finished match. A win gives reputation, XP and gold, and a loss takes reputation away.
## Pure Balance gives the chest but no reputation, which keeps the reputation road meaningful. Every match ends with a chest.
static func record_match(result: String) -> void:
	var progression: Dictionary = _table("progression")
	var won := result == "player"
	if not Settings.get_value("pure_balance") and result != "draw":
		var change := int(progression.reputation.win) if won else int(progression.reputation.loss)
		_write("reputation", maxi(reputation() + change, 0))
	if won:
		add_xp(int(progression.xp.per_win))
		add_gold(int(_table("economy").gold.per_win))
	queue_chest(roll_chest())
	_count_game()


## Counts a finished game. Every few games an Injection chest is waiting too.
static func _count_game() -> void:
	var games := int(_read("games", 0)) + 1
	_write("games", games)
	if games % injection_chest_every() == 0:
		queue_chest(INJECTION_CHEST)


static func injection_chest_every() -> int:
	return maxi(int(_table("chests").get("injection_chest", {}).get("every_games", 10)), 1)


## How many more finished games until the next Injection chest.
static func games_to_injection_chest() -> int:
	var every := injection_chest_every()
	return every - int(_read("games", 0)) % every


static func add_gold(amount: int) -> void:
	_write("gold", gold() + amount)


## Adds XP and handles every level up it causes. Each level gives gold, and every other level gives a rank up chest.
static func add_xp(amount: int) -> void:
	var economy: Dictionary = _table("economy")
	var current := xp() + amount
	while current >= xp_to_next():
		current -= xp_to_next()
		_write("player_level", player_level() + 1)
		add_gold(int(economy.gold.per_player_level))
		if player_level() % int(economy.rank_up_chest.every_player_levels) == 0:
			queue_chest(economy.rank_up_chest.chest)
			add_gold(int(economy.rank_up_chest.gold))
	_write("xp", current)


## Picks the chest rarity from the odds, with a guaranteed Legendary if none came in the last stretch of games.
static func roll_chest() -> String:
	var chests: Dictionary = _table("chests")
	var dry := int(_read("games_since_legendary", 0)) + 1
	var rarity := "legendary" if dry >= int(chests.legendary_pity_games) else _weighted(chests.odds)
	_write("games_since_legendary", 0 if rarity == "legendary" else dry)
	return rarity


static func queue_chest(rarity: String) -> void:
	var waiting: Array = _read("chests_waiting", []).duplicate()
	waiting.append(rarity)
	_write("chests_waiting", waiting)


static func chests_waiting() -> Array:
	return _read("chests_waiting", [])


## Opens the first waiting chest and returns what came out, as a list of {"id", "count"} entries plus any extras.
## Chests give more cards in higher arenas. Copies are added straight away, and cards level up on their own.
static func open_next_chest() -> Dictionary:
	var waiting: Array = chests_waiting().duplicate()
	if waiting.is_empty():
		return {}
	var rarity: String = waiting.pop_front()
	_write("chests_waiting", waiting)
	# An Injection chest holds Evolution Injections and nothing else.
	if rarity == INJECTION_CHEST:
		var count := int(_table("chests").injection_chest.get("injections", 1))
		for i in count:
			add_injection()
		Stats.record_chest(rarity, 0)
		return {"rarity": rarity, "cards": [{"text": "Evolution Injection x%d" % count}]}
	var legendaries := 0
	var chests: Dictionary = _table("chests")
	var contents: Dictionary = chests.contents[rarity]
	var count := roundi(float(contents.cards) * (1.0 + float(chests.arena_scaling) * (arena() - 1)))
	var pool := _unlocked_by_rarity()
	var drops := {}
	for i in count:
		var drop_rarity := _weighted(chests.rarity_weights[rarity])
		var options: Array = pool.get(drop_rarity, [])
		if options.is_empty():
			options = pool.get("common", [])
		var id: String = options[randi() % options.size()]
		drops[id] = int(drops.get(id, 0)) + 1
		legendaries += 1 if pool.get("legendary", []).has(id) else 0
	var extras := []
	for extra in contents.guaranteed:
		for i in int(contents.guaranteed[extra]):
			if extra == "evolution":
				extras.append(grant_random_evolution())
			elif extra == "injection":
				add_injection()
				extras.append("Evolution Injection")
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
	for line in extras:
		if line != "":
			opened.append({"text": line})
	Stats.record_chest(rarity, legendaries)
	return {"rarity": rarity, "cards": opened}


## Every card that has an evolved form in cards.json.
static func evolvable_cards() -> Array:
	var cards: Dictionary = Data.table("cards").cards
	return cards.keys().filter(func(id: String) -> bool: return cards[id].has("evolution"))


static func has_evolution(id: String) -> bool:
	return id in _read("evolutions", [])


static func injections() -> int:
	return int(_read("injections", 0))


static func shards() -> int:
	return int(_read("shards", 0))


## Unlocks a random evolution. Rolling one the player already has turns it into an Injection Shard instead,
## which means no evolution is ever wasted. It returns a short line for the chest screen.
static func grant_random_evolution() -> String:
	var options := evolvable_cards()
	if options.is_empty():
		return ""
	var id: String = options[randi() % options.size()]
	var card_name: String = Data.table("cards").cards[id].name
	if has_evolution(id):
		add_shard()
		return "Injection Shard (%s already evolved)" % card_name
	_unlock_evolution(id)
	return "Evolution unlocked: %s" % card_name


## Three shards make one Evolution Injection.
static func add_shard() -> void:
	var total := shards() + 1
	var per := int(_table("chests").injection_shards_per_injection)
	_write("injections", injections() + total / per)
	_write("shards", total % per)


static func add_injection() -> void:
	_write("injections", injections() + 1)


## Spends an Evolution Injection to unlock the evolution of any card that has one.
static func use_injection(id: String) -> void:
	if injections() > 0 and not has_evolution(id) and id in evolvable_cards():
		_write("injections", injections() - 1)
		_unlock_evolution(id)


static func _unlock_evolution(id: String) -> void:
	var unlocked: Array = _read("evolutions", []).duplicate()
	unlocked.append(id)
	_write("evolutions", unlocked)


## How many decks the player can keep. The one picked last is the one battles use, and it is also kept under "deck",
## which means everything that reads the battle deck works the same as with a single deck.
static func deck_slots() -> int:
	return int(_table("battle").deck.get("slots", 3))


static func active_deck() -> int:
	return clampi(int(_read("deck_index", 0)), 0, deck_slots() - 1)


## Every saved deck, one list per slot. A slot never used is an empty list.
static func decks() -> Array:
	var raw: Variant = _read("decks", [])
	var stored: Array = raw.duplicate(true) if raw is Array else []
	while stored.size() < deck_slots():
		stored.append([])
	var current: Variant = _read("deck", null)
	if current is Array and not current.is_empty():
		stored[active_deck()] = current.duplicate()
	return stored


static func save_deck(index: int, cards: Array) -> void:
	var all := decks()
	all[index] = cards.duplicate()
	_write("decks", all)
	if index == active_deck():
		_write("deck", cards.duplicate())


## Picks the deck battles use from now on.
static func select_deck(index: int) -> void:
	var all := decks()
	_write("decks", all)
	_write("deck_index", index)
	_write("deck", all[index].duplicate())


## How many evolution slots a deck has. They are the first places in the deck.
static func evolution_slots() -> int:
	return int(Data.table("battle").evolution.slots)


## The evolutions a deck plays with: the cards in its evolution slots whose evolution is unlocked, and no others.
static func evolutions_in(deck: Array) -> Array:
	var picked := []
	for id in deck.slice(0, evolution_slots()):
		if has_evolution(id):
			picked.append(id)
	return picked


static func deck_evolutions() -> Array:
	return evolutions_in(BattleSim.starting_deck())


## Adds copies of a card and levels it up as far as they allow. Copies of a maxed card become wild cards.
static func add_copies(id: String, amount: int) -> void:
	var cards: Dictionary = _read("cards", {}).duplicate(true)
	var entry: Dictionary = card(id)
	entry.level = maxi(int(entry.level), 1)
	entry.copies = int(entry.copies) + amount
	_level_up(id, entry)
	cards[id] = entry
	_write("cards", cards)


## Spends wild cards on one card, as many as it needs for its next level or as many as there are.
static func use_wild_cards(id: String) -> void:
	var entry: Dictionary = card(id)
	if int(entry.level) >= max_card_level() or wild_cards() <= 0:
		return
	var needed := maxi(copies_for_next(int(entry.level)) - int(entry.copies), 0)
	var spent := mini(needed, wild_cards())
	_write("wild_cards", wild_cards() - spent)
	add_copies(id, spent)


static func _level_up(id: String, entry: Dictionary) -> void:
	var progression: Dictionary = _table("progression")
	while int(entry.level) < max_card_level() and int(entry.copies) >= copies_for_next(int(entry.level)):
		entry.copies = int(entry.copies) - copies_for_next(int(entry.level))
		entry.level = int(entry.level) + 1
		add_xp(int(progression.xp.per_card_level_up))
		add_gold(int(_table("economy").gold.per_card_upgrade_times_level) * int(entry.level))
	if int(entry.level) >= max_card_level() and int(entry.copies) > 0:
		_write("wild_cards", wild_cards() + int(entry.copies))
		entry.copies = 0


## Unlocked cards grouped by rarity, which is worked out from each card's Codex threat level.
static func _unlocked_by_rarity() -> Dictionary:
	var cards_table := Data.table("cards")
	var groups := {}
	for id in cards_table.cards:
		var entry: Dictionary = cards_table.cards[id]
		if int(entry.get("unlock_arena", 1)) > arena() or not BattleSim.is_collectable(entry):
			continue
		groups.get_or_add(card_rarity(id), []).append(id)
	return groups


static func _never_seen(id: String) -> bool:
	return not id in _read("seen_cards", [])


static func _mark_seen(ids: Array) -> void:
	var seen: Array = _read("seen_cards", []).duplicate()
	for id in ids:
		if not id in seen:
			seen.append(id)
	_write("seen_cards", seen)


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


static func _read(key: String, fallback: Variant) -> Variant:
	var value: Variant = Save.get_value(key)
	return fallback if value == null else value


static func _write(key: String, value: Variant) -> void:
	Save.set_value(key, value)
