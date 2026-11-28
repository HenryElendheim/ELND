class_name CardSearch
## Finds cards by name or by what kind of card they are, such as flying, ranged, spell or legendary.
## Every card gets a list of plain tags worked out from its data, which means new cards are searchable without extra setup.

## The categories offered as quick filters, as pairs of a tag and the text shown. An empty tag means every card.
const CATEGORIES := [
	["", "All"], ["troop", "Troop"], ["building", "Building"], ["spell", "Spell"],
	["ground", "Ground"], ["flying", "Flying"], ["melee", "Melee"], ["ranged", "Ranged"],
	["hits air", "Hits air"], ["swarm", "Swarm"], ["no attack", "No attack"],
	["common", "Common"], ["rare", "Rare"], ["epic", "Epic"], ["legendary", "Legendary"],
	["clam", "CLAM"], ["rekna", "REKNA"], ["rinner", "RINNER"], ["heimer", "HEIMER"], ["item", "Foundation Item"],
	["neutralized", "Neutralized"],
]


## The categories in groups. Picking several in one group means any of them, such as troops or spells,
## and picking in several groups means all of those at once, such as flying and legendary.
const GROUPS := [
	["Kind", ["troop", "building", "spell"]],
	["Moves", ["ground", "flying"]],
	["Attack", ["melee", "ranged", "no attack"]],
	["Reach", ["hits air"]],
	["Group", ["swarm"]],
	["Rarity", ["common", "rare", "epic", "legendary"]],
	["Class", ["clam", "rekna", "rinner", "heimer"]],
	["Origin", ["item"]],
]


## The shown name of a category tag, such as "Hits air" for "hits air".
static func category_name(tag: String) -> String:
	for option in CATEGORIES:
		if option[0] == tag:
			return option[1]
	return tag.capitalize()


## True when a card fits every group that has something picked in it, which means it has at least one of the
## picked tags in each of those groups. Nothing picked lets every card through.
static func fits(id: String, picked: Array) -> bool:
	var card_tags := tags(id)
	for group in GROUPS:
		var wanted: Array = group[1].filter(func(tag: String) -> bool: return tag in picked)
		if not wanted.is_empty() and not wanted.any(func(tag: String) -> bool: return tag in card_tags):
			return false
	return true


## The tags for one card, in the order they read best: kind, movement, attack, reach, rarity and class.
static func tags(id: String) -> Array:
	var card: Dictionary = Data.table("cards").cards[id]
	var result := [String(card.type)]
	if card.type == "troop" or card.has("movement"):
		result.append(String(card.get("movement", "ground")))
	if card.type == "troop":
		var attack := String(card.get("attack", "melee"))
		result.append("no attack" if attack == "none" else attack)
		if card.get("targets") == "air_ground":
			result.append("hits air")
		if int(card.get("count", 1)) > 1:
			result.append("swarm")
	result.append(Progress.card_rarity(id))
	result.append(String(card["class"]).to_lower())
	if card.get("item", false):
		result.append("item")
	if card.get("neutralized", false):
		result.append("neutralized")
	return result


## The tags as a short line to show under a card's name, for example "Troop, ground, melee, epic, RINNER".
static func describe(id: String) -> String:
	var shown := []
	for tag in tags(id):
		var upper := String(tag).to_upper()
		shown.append(upper if Data.table("cards").classes.has(upper) else tag)
	var line := ", ".join(shown)
	return line.left(1).to_upper() + line.substr(1)


## True when the card fits the picked category and every word typed matches either its name or the start of a word in one of its tags.
## So "fly" finds the flying cards, "air" finds the ones that hit air, "hobb" finds The Hobb, and "ranged troop" needs both.
static func matches(id: String, query: String, category: String) -> bool:
	var card_tags := tags(id)
	if category != "" and not card_tags.has(category):
		return false
	var card_name := String(Data.table("cards").cards[id].name).to_lower()
	for word in query.to_lower().split(" ", false):
		if not (word in card_name or _tag_has_word(card_tags, word)):
			return false
	return true


static func _tag_has_word(card_tags: Array, word: String) -> bool:
	for tag in card_tags:
		if (" " + String(tag)).contains(" " + word):
			return true
	return false


## Every card id that matches, in card number order.
static func find(query: String, category: String) -> Array:
	var cards: Dictionary = Data.table("cards").cards
	var ids := []
	for id in cards:
		if BattleSim.is_collectable(cards[id]) and matches(id, query, category):
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return _by_number(a, b))
	return ids


static func _by_number(a: String, b: String) -> bool:
	var cards: Dictionary = Data.table("cards").cards
	return order(cards[a]) < order(cards[b])


## A card's place in number order: anomalies by their ELND number first, then Foundation Items by their own.
static func order(card: Dictionary) -> int:
	return int(card.get("number", 0)) + (1000 if card.get("item", false) else 0)


## The number shown on a card's Codex page, such as ELND-012 for an anomaly or FI-001 for a Foundation Item.
static func code(card: Dictionary) -> String:
	return ("FI-%03d" if card.get("item", false) else "ELND-%03d") % int(card.get("number", 0))
