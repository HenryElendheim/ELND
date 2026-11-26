class_name CardText
## Fills a card's description with its real numbers, so the text always matches the data, Admin edits included.
## A description holds placeholders such as {happy_face.drain_per_second} or {damage|lvl}, which read:
## a stat of the card itself ({damage}), a setting of one of its abilities ({happy_face.range}),
## its evolution ({evolution.boost}), or a stat of another card such as a token ({broodling.health}).
## After a bar comes how to show it: pct shows 0.35 as 35, more shows 1.5 as 50 (how much more),
## less shows 0.75 as 25 (how much less), and lvl scales it by the card's level the same way battles do.

const MISSING := "?"

static var _pattern: RegEx


static func fill(id: String, text: String, level := 1) -> String:
	if _pattern == null:
		_pattern = RegEx.create_from_string("\\{([a-z_\\.]+)(?:\\|([a-z]+))?\\}")
	var out := text
	for found in _pattern.search_all(text):
		var value: Variant = _lookup(id, found.get_string(1))
		var shown := MISSING if value == null else _show(float(value), found.get_string(2), level)
		out = out.replace(found.get_string(0), shown)
	return out


## True when every placeholder in a text points at a real number, which the smoke test checks for every card.
static func complete(id: String, text: String) -> bool:
	return not fill(id, text).contains("{") and not fill(id, text).contains(MISSING)


static func _lookup(id: String, path: String) -> Variant:
	var cards: Dictionary = Data.table("cards").cards
	var card: Dictionary = cards[id]
	var parts := path.split(".")
	if parts.size() == 1:
		return _number(card.get(parts[0]))
	var owner := parts[0]
	var key := parts[1]
	if owner == "evolution":
		return _number(card.get("evolution", {}).get(key))
	for ability in card.get("abilities", []):
		if ability.get("id") == owner:
			return _number(ability.get(key))
	if cards.has(owner):
		return _number(cards[owner].get(key))
	return null


static func _number(value: Variant) -> Variant:
	return value if (value is float or value is int) and not value is bool else null


static func _show(value: float, how: String, level: int) -> String:
	match how:
		"pct":
			value *= 100.0
		"more":
			value = (value - 1.0) * 100.0
		"less":
			value = (1.0 - value) * 100.0
		"lvl":
			value *= pow(1.0 + float(Data.table("battle").level_scaling.per_level), maxi(level, 1) - 1)
	if absf(value - roundf(value)) < 0.05:
		return str(roundi(value))
	return str(snappedf(value, 0.1))
