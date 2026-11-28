class_name CardEditor
extends VBoxContainer
## Admin Mode's editor for any card or tower. Search for one by name or kind, or show them all, and tap it to edit.
## Powers can be added from every power in the game, or removed, and the evolution's button power can be swapped,
## added or taken away.
## Edited ones carry a star after their name. Tokens, such as Broodlings, can be edited too.
## Any card can also be the starting point for a brand new card, which then works like every other card
## and can be renamed, described, given a Codex entry, tuned and deleted again.
## Every main number can be changed (cost, health, damage, seconds per hit, range and so on), as can its type,
## movement, attack, targets and speed, and every number of its abilities and its evolution.
## Edits save straight away and reach battles already running. A changed value shows its default and can be reset
## on its own, and the whole card can be reset at once.

## The numbers shown for each kind of card, in this order. Any other number the card has is shown after them.
const NUMBERS := {
	"troop": ["cost", "health", "damage", "hit_speed", "range", "count", "size", "threat", "unlock_arena"],
	"building": ["cost", "health", "lifetime", "damage", "threat", "unlock_arena"],
	"spell": ["cost", "damage", "radius", "threat", "unlock_arena"],
	"tower": ["health", "damage", "hit_speed", "range", "size"],
}
## The settings that are picked from a list rather than typed, with the options for each.
const CHOICES := {
	"type": [["troop", "Troop"], ["building", "Building"], ["spell", "Spell"]],
	"movement": [["ground", "Ground"], ["flying", "Flying"]],
	"attack": [["melee", "Melee"], ["ranged", "Ranged"], ["none", "None"]],
	"targets": [["ground", "Ground"], ["air_ground", "Air and ground"], ["buildings", "Buildings"], ["living", "Living only"], ["attackers_only", "Attackers only"], ["none", "Nothing"]],
	"speed": [["slow", "Slow"], ["medium", "Medium"], ["fast", "Fast"], ["very_fast", "Very fast"]],
	"class": [["CLAM", "CLAM"], ["REKNA", "REKNA"], ["RINNER", "RINNER"], ["HEIMER", "HEIMER"]],
}
const CHOICES_FOR := {"troop": ["type", "class", "movement", "attack", "targets", "speed"], "building": ["type", "class", "movement"], "spell": ["type", "class"], "tower": []}
## Friendlier names for a few keys. Everything else is shown with its key written out.
const NAMES := {"hit_speed": "Seconds per hit", "count": "Group size", "size": "Unit size", "unlock_arena": "Unlocks at place number", "lifetime": "Lifetime (s)", "radius": "Area radius", "threat": "Threat (sets rarity)"}
## The text a card has that can be rewritten, with the name shown for each.
const TEXTS := [["name", "Name"], ["short_name", "Short name on the card"], ["how_it_works", "How it works"]]
const TOWERS := [["side", "Side tower"], ["main", "Main tower"], ["core", "Defense core"]]
## Evolution buttons that work by driving another power on the same card. Picking one adds that power too if it is missing.
const EVOLUTION_NEEDS := {
	"close_the_lid": "comfortable_end", "drop": "snatch", "flurry_on_demand": "flurry",
	"deeper_into_the_woods": "happy_face", "feather_storm": "sharp_wings", "storm": "lightning_strike",
	"last_toll": "toll", "swarming_season": "spawner", "return_pool": "take_and_give", "flay": "skin_stealer",
}

var _query := ""
var _show_all := false
var _picker := VBoxContainer.new()
var _fields := VBoxContainer.new()
var _show_button: Button
## What is being edited, such as "cards/hobb" or "towers/side". Empty until something is picked.
var _subject := ""
## A new type waiting for its second tap, and when the first tap was. Changing the type can break a card,
## such as a troop turned into a spell, so it never happens from one stray tap.
var _pending_type := ""
## Which list of powers to pick from is open under the card: "power", "evolution", or nothing.
var _adding := ""
var _pending_at := -10000

const CONFIRM_MS := 3000


func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	add_child(Ui.search("Search cards and towers", _on_search))
	_show_button = Ui.button("Show all", _toggle_show_all)
	add_child(_show_button)
	add_child(_picker)
	add_child(_fields)
	_show_picker()


func _on_search(text: String) -> void:
	_query = text
	_show_picker()


func _toggle_show_all() -> void:
	_show_all = not _show_all
	_show_button.text = "Hide all" if _show_all else "Show all"
	_show_picker()


## The list to pick from: nothing until something is searched for or Show all is on, then towers and cards that match.
## Anything with an edit carries a star after its name, such as The Pardoned One*.
func _show_picker() -> void:
	_clear(_picker)
	if not _show_all and _query.strip_edges() == "":
		_picker.add_child(Ui.label("Search, or press Show all, then tap a card or tower to edit it. Edited ones have a star after their name.", "MutedLabel"))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	var edited := _edited()
	var words := _query.to_lower().strip_edges()
	var subjects := []
	for tower in TOWERS:
		if words == "" or String(tower[1]).to_lower().contains(words):
			subjects.append("towers/" + tower[0])
	for id in CardSearch.find(_query, ""):
		subjects.append("cards/" + id)
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		if cards[id].get("token", false) and (words == "" or String(cards[id].name).to_lower().contains(words)):
			subjects.append("cards/" + id)
	for subject in subjects:
		var text := _name_of(subject) + ("*" if subject in edited else "")
		grid.add_child(Ui.button(text, func() -> void: _pick(subject)))
	_picker.add_child(grid)


## Every card and tower with an Admin edit, apart from a neutralize switch on its own. Cards made in the game count too.
static func _edited() -> Array:
	var found := []
	for kind in TOWERS:
		if Data.overrides.get("towers", {}).has(kind[0]):
			found.append("towers/" + kind[0])
	var cards: Dictionary = Data.overrides.get("cards", {}).get("cards", {})
	for id in cards:
		var keys: Array = cards[id].keys() if cards[id] is Dictionary else []
		keys.erase("neutralized")
		if not keys.is_empty() and Data.table("cards").cards.has(id):
			found.append("cards/" + id)
	return found


static func _name_of(subject: String) -> String:
	var id := subject.get_slice("/", 1)
	if subject.begins_with("towers/"):
		for kind in TOWERS:
			if kind[0] == id:
				return kind[1]
	var card: Dictionary = Data.table("cards").cards.get(id, {})
	return String(card.get("name", id)) + (" (token)" if card.get("token", false) else "")


func _pick(subject: String) -> void:
	_subject = subject
	_show_fields()


func _file() -> String:
	return _subject.get_slice("/", 0)


## Where the subject lives in its data file, such as ["cards", "hobb"] or ["side"].
func _path() -> Array:
	var id := _subject.get_slice("/", 1)
	return [id] if _file() == "towers" else ["cards", id]


func _values() -> Dictionary:
	var table := Data.table(_file())
	var id := _subject.get_slice("/", 1)
	return table[id] if _file() == "towers" else table.cards[id]


func _default(key: String) -> Variant:
	return Data.default_value(_file(), _path() + [key])


## Everything editable about the picked card or tower, rebuilt after every change so defaults and resets stay in step.
func _show_fields() -> void:
	_clear(_fields)
	if _subject == "":
		return
	var values := _values()
	var kind := "tower" if _file() == "towers" else String(values.get("type", "troop"))
	var title := "%s" % values.get("name", _subject.get_slice("/", 1).capitalize())
	_fields.add_child(Ui.spacer(12))
	_fields.add_child(Ui.label(title, "HeadingLabel"))
	_fields.add_child(Ui.label("Changes save straight away and apply in battles already running. A new type or movement applies to cards played after the change.", "MutedLabel"))
	if kind != "tower":
		for entry in TEXTS:
			_fields.add_child(Ui.text(entry[1], String(values.get(entry[0], "")), func(value: String) -> void: _change(entry[0], value)))
		var codex: String = Data.table("codex").entries.get(_id(), "")
		_fields.add_child(Ui.text("Codex entry", codex, func(value: String) -> void: _set_codex(value)))
	for key in CHOICES_FOR.get(kind, []):
		var current: Variant = values.get(key, CHOICES[key][0][0])
		_fields.add_child(Ui.choice(_label(key), CHOICES[key], current, func(value: String) -> void: _choose(key, value), 3))
		_add_reset(key)
	var shown := []
	for key in NUMBERS.get(kind, []):
		shown.append(key)
		_number(key, values.get(key, _fallback(key)))
	for key in values:
		if not key in shown and (values[key] is float or values[key] is int) and key != "number":
			_number(key, values[key])
	var abilities: Array = values.get("abilities", [])
	if kind != "tower":
		_fields.add_child(Ui.label("Powers", "TitleLabel"))
	for i in abilities.size():
		var row := HBoxContainer.new()
		row.add_child(Ui.label(_power_name(String(abilities[i].id)), "HeadingLabel"))
		var remove := Ui.button("Remove", func() -> void: _remove_power(i))
		remove.size_flags_horizontal = SIZE_FILL
		row.add_child(remove)
		_fields.add_child(row)
		for key in abilities[i]:
			if abilities[i][key] is float or abilities[i][key] is int:
				_fields.add_child(Ui.number(String(key).capitalize(), abilities[i][key], func(v: float) -> void: _set_ability(abilities, i, key, v)))
	if kind != "tower":
		_fields.add_child(Ui.button("Add a power", func() -> void: _open_list("power")))
		if _adding == "power":
			_add_choices(_catalog(false), func(id: String) -> void: _add_power(id))
		_fields.add_child(Ui.button("Reset powers", func() -> void: _reset("abilities")))
	if kind in ["troop", "building"]:
		_fields.add_child(Ui.label("Evolution", "TitleLabel"))
		if values.has("evolution") and values.evolution is Dictionary:
			var evolution: Dictionary = values.evolution
			_fields.add_child(Ui.label("%s: %s" % [evolution.get("name", ""), _power_name(String(evolution.get("ability", "")))], "HeadingLabel"))
			_fields.add_child(Ui.text("Evolution name", String(evolution.get("name", "")), func(value: String) -> void: _set_path(["evolution", "name"], value)))
			_fields.add_child(Ui.text("Evolution how it works", String(evolution.get("how_it_works", "")), func(value: String) -> void: _set_path(["evolution", "how_it_works"], value)))
			for key in evolution:
				if evolution[key] is float or evolution[key] is int:
					_fields.add_child(Ui.number(String(key).capitalize(), evolution[key], func(v: float) -> void: _set_path(["evolution", key], v)))
			_fields.add_child(Ui.button("Change the evolution's button power", func() -> void: _open_list("evolution")))
			_fields.add_child(Ui.button("Remove the evolution", func() -> void: _set_path(["evolution"], null)))
		else:
			_fields.add_child(Ui.button("Add an evolution", func() -> void: _open_list("evolution")))
		if _adding == "evolution":
			_add_choices(_catalog(true), func(id: String) -> void: _set_evolution(id))
		_fields.add_child(Ui.button("Reset evolution", func() -> void: _reset("evolution")))
	_fields.add_child(Ui.spacer(12))
	if kind != "tower":
		_fields.add_child(Ui.button("Make a new card from this one", _make_copy))
	if _is_custom():
		_fields.add_child(Ui.button("Delete this card", _delete))
	else:
		_fields.add_child(Ui.button("Reset this %s" % ("tower" if kind == "tower" else "card"), func() -> void: _reset("")))


## What a number is when the card does not set it, which is what battles use for it.
func _fallback(key: String) -> float:
	var battle := Data.table("battle")
	match key:
		"range":
			return float(battle.melee_range_tiles)
		"hit_speed":
			return float(battle.default_hit_speed)
		"count":
			return 1.0
		"size":
			return float(battle.unit_radius_tiles) * 2.0
		"unlock_arena":
			return 1.0
	return 0.0


## One number box. A changed number shows its default in the name and gets its own reset.
func _number(key: String, value: Variant) -> void:
	_fields.add_child(Ui.number(_label(key), float(value), func(v: float) -> void: _change(key, v)))
	_add_reset(key)


func _label(key: String) -> String:
	var text: String = NAMES.get(key, String(key).capitalize())
	var original: Variant = _default(key)
	var now: Variant = _values().get(key)
	if not _is_custom() and now != null and original != now:
		text += " (default %s)" % (str(original) if original != null else "none")
	return text


func _add_reset(key: String) -> void:
	var original: Variant = _default(key)
	var now: Variant = _values().get(key)
	if not _is_custom() and now != null and original != now:
		_fields.add_child(Ui.button("Reset " + NAMES.get(key, String(key).capitalize()).to_lower(), func() -> void: _reset(key)))


## Picking an option. A new type needs a second tap on the same option within a few seconds.
func _choose(key: String, value: String) -> void:
	if value == _values().get(key, CHOICES[key][0][0]):
		return
	if key == "type":
		var now := Time.get_ticks_msec()
		if _pending_type != value or now - _pending_at > CONFIRM_MS:
			_pending_type = value
			_pending_at = now
			Nav.toast("Tap %s again to change the type. A card's abilities may not work as another type." % value)
			_show_fields.call_deferred()
			return
		_pending_type = ""
	_change(key, value)


## Every power in the game, found on the cards that use it, with the numbers that card starts it with.
## Evolution powers are the ones evolution buttons use. Each entry is an id, a name to show, and its starting numbers.
static func _catalog(evolutions: bool) -> Array:
	var found := {}
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		var card: Dictionary = cards[id]
		if evolutions:
			var evolution: Variant = card.get("evolution")
			if evolution is Dictionary and evolution.has("ability") and not found.has(evolution.ability):
				var settings: Dictionary = evolution.duplicate(true)
				for key in ["name", "how_it_works", "ability"]:
					settings.erase(key)
				found[evolution.ability] = [evolution.ability, "%s (from %s)" % [_power_name(evolution.ability), card.name], settings]
		else:
			for ability in card.get("abilities", []):
				if not found.has(ability.id):
					found[ability.id] = [ability.id, "%s (from %s)" % [_power_name(ability.id), card.name], ability.duplicate(true)]
	var list := found.values()
	list.sort_custom(func(a: Array, b: Array) -> bool: return String(a[1]) < String(b[1]))
	return list


static func _power_name(id: String) -> String:
	return id.capitalize()


func _open_list(which: String) -> void:
	_adding = "" if _adding == which else which
	_show_fields.call_deferred()


## The list of powers to pick from, two to a row.
func _add_choices(options: Array, on_pick: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	for option in options:
		var button := Ui.button(option[1], func() -> void: on_pick.call(option[0]))
		button.clip_text = true
		grid.add_child(button)
	_fields.add_child(grid)


## Adds a power to the card with the numbers its own card starts it with.
func _add_power(id: String) -> void:
	for option in _catalog(false):
		if option[0] == id:
			var abilities: Array = (_values().get("abilities", []) as Array).duplicate(true)
			abilities.append(option[2].duplicate(true))
			_adding = ""
			Data.set_override(_file(), _path() + ["abilities"], abilities)
			Nav.toast("Added %s" % _power_name(id))
			_refresh()
			return


func _remove_power(index: int) -> void:
	var abilities: Array = (_values().get("abilities", []) as Array).duplicate(true)
	if index < abilities.size():
		var gone: String = abilities[index].id
		abilities.remove_at(index)
		Data.set_override(_file(), _path() + ["abilities"], abilities)
		Nav.toast("Removed %s" % _power_name(gone))
		_refresh()


## Gives the card an evolution whose button fires the picked power, or changes the power of the one it has.
## A button power that drives another power brings that power along if the card does not have it yet.
func _set_evolution(id: String) -> void:
	for option in _catalog(true):
		if option[0] != id:
			continue
		var current: Variant = _values().get("evolution")
		var evolution: Dictionary = option[2].duplicate(true)
		evolution["ability"] = id
		evolution["name"] = current.get("name", "Evolved") if current is Dictionary else "Evolved"
		evolution["how_it_works"] = current.get("how_it_works", "") if current is Dictionary else "Its button uses %s." % _power_name(id)
		_adding = ""
		Data.set_override(_file(), _path() + ["evolution"], evolution)
		var needs: String = EVOLUTION_NEEDS.get(id, "")
		var has_it := (_values().get("abilities", []) as Array).any(func(a: Dictionary) -> bool: return a.get("id") == needs)
		if needs != "" and not has_it:
			_add_power(needs)
			Nav.toast("This button needs %s, so that was added too" % _power_name(needs))
		_refresh()
		return


func _refresh() -> void:
	_show_fields.call_deferred()
	_show_picker.call_deferred()


func _id() -> String:
	return _subject.get_slice("/", 1)


## True for a card made in the game, which only exists as an Admin edit and has no shipped defaults.
func _is_custom() -> bool:
	return _file() == "cards" and Data.default_value("cards", ["cards", _id()]) == null


func _set_codex(text: String) -> void:
	Data.set_override("codex", ["entries", _id()], text)


## Makes a brand new card that starts as a copy of this one: same stats, abilities and evolution,
## the next free card number, a name ending in Copy, and a Codex entry to rewrite. It opens straight away for editing.
func _make_copy() -> void:
	var cards: Dictionary = Data.table("cards").cards
	var card: Dictionary = _values().duplicate(true)
	card.erase("neutralized")
	card.erase("token")
	var count := 1
	while cards.has("custom_%d" % count):
		count += 1
	var id := "custom_%d" % count
	var top := 0
	for other in cards:
		if cards[other].get("item", false) == card.get("item", false) and not cards[other].get("token", false):
			top = maxi(top, int(cards[other].get("number", 0)))
	card.number = top + 1
	card.name = "%s Copy" % card.get("name", "Card")
	card.short_name = "%s Copy" % card.get("short_name", "Card")
	card.unlock_arena = int(card.get("unlock_arena", 1))
	Data.set_override("cards", ["cards", id], card)
	Data.set_override("codex", ["entries", id], "A new anomaly. Write its Codex entry here.")
	Nav.toast("Made %s" % card.name)
	_pick("cards/" + id)
	_show_picker.call_deferred()


## Removes a card made in the game, with its Codex entry. Decks that held it fall back to a playable deck.
func _delete() -> void:
	var id := _id()
	Data.reset_override("cards", ["cards", id])
	Data.reset_override("codex", ["entries", id])
	_subject = ""
	Nav.toast("Card deleted")
	_show_fields.call_deferred()
	_show_picker.call_deferred()


func _change(key: String, value: Variant) -> void:
	_set_path([key], value)


func _set_path(keys: Array, value: Variant) -> void:
	Data.set_override(_file(), _path() + keys, value)
	_show_fields.call_deferred()
	_show_picker.call_deferred()


## Abilities are a list in cards.json, so a change stores the card's whole ability list with that one number changed.
func _set_ability(abilities: Array, index: int, key: String, value: float) -> void:
	var changed := abilities.duplicate(true)
	changed[index][key] = value
	Data.set_override(_file(), _path() + ["abilities"], changed)
	_show_fields.call_deferred()


## Puts one value back to default, or the whole card or tower when no key is given.
func _reset(key: String) -> void:
	Data.reset_override(_file(), _path() + ([key] if key != "" else []))
	Nav.toast("Back to default")
	_show_fields.call_deferred()
	_show_picker.call_deferred()


static func _clear(box: Node) -> void:
	for child in box.get_children():
		child.queue_free()
