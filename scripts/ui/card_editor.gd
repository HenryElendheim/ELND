class_name CardEditor
extends VBoxContainer
## Admin Mode's editor for any card or tower. Search for one by name or kind, or show them all, and tap it to edit.
## Every main number can be changed (cost, health, damage, seconds per hit, range and so on), as can its type,
## movement, attack, targets and speed, and every number of its abilities and its evolution.
## Edits save straight away and reach battles already running. A changed value shows its default and can be reset
## on its own, and the whole card can be reset at once.

## The numbers shown for each kind of card, in this order. Any other number the card has is shown after them.
const NUMBERS := {
	"troop": ["cost", "health", "damage", "hit_speed", "range", "count", "size", "unlock_arena"],
	"building": ["cost", "health", "lifetime", "damage", "unlock_arena"],
	"spell": ["cost", "damage", "radius", "unlock_arena"],
	"tower": ["health", "damage", "hit_speed", "range", "size"],
}
## The settings that are picked from a list rather than typed, with the options for each.
const CHOICES := {
	"type": [["troop", "Troop"], ["building", "Building"], ["spell", "Spell"]],
	"movement": [["ground", "Ground"], ["flying", "Flying"]],
	"attack": [["melee", "Melee"], ["ranged", "Ranged"], ["none", "None"]],
	"targets": [["ground", "Ground"], ["air_ground", "Air and ground"], ["buildings", "Buildings"], ["living", "Living only"], ["attackers_only", "Attackers only"], ["none", "Nothing"]],
	"speed": [["slow", "Slow"], ["medium", "Medium"], ["fast", "Fast"], ["very_fast", "Very fast"]],
}
const CHOICES_FOR := {"troop": ["type", "movement", "attack", "targets", "speed"], "building": ["type", "movement"], "spell": ["type"], "tower": []}
## Friendlier names for a few keys. Everything else is shown with its key written out.
const NAMES := {"hit_speed": "Seconds per hit", "count": "Group size", "size": "Unit size", "unlock_arena": "Unlocks at place number", "lifetime": "Lifetime (s)", "radius": "Area radius"}
const TOWERS := [["side", "Side tower"], ["main", "Main tower"], ["core", "Defense core"]]

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
## Cards and towers that have been edited are always listed first, so an edit is never forgotten.
func _show_picker() -> void:
	_clear(_picker)
	var edited := _edited()
	if not edited.is_empty():
		_picker.add_child(Ui.label("Edited", "HeadingLabel"))
		var row := GridContainer.new()
		row.columns = 2
		for subject in edited:
			row.add_child(Ui.button(_name_of(subject), func() -> void: _pick(subject)))
		_picker.add_child(row)
	if not _show_all and _query.strip_edges() == "":
		_picker.add_child(Ui.label("Search, or press Show all, then tap a card or tower to edit it.", "MutedLabel"))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	var words := _query.to_lower().strip_edges()
	for tower in TOWERS:
		if words == "" or String(tower[1]).to_lower().contains(words):
			grid.add_child(Ui.button(tower[1], func() -> void: _pick("towers/" + tower[0])))
	for id in CardSearch.find(_query, ""):
		grid.add_child(Ui.button(Data.table("cards").cards[id].name, func() -> void: _pick("cards/" + id)))
	_picker.add_child(grid)


## Every card and tower with an Admin edit, apart from a neutralize switch on its own.
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
	return String(Data.table("cards").cards.get(id, {}).get("name", id))


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
	for key in CHOICES_FOR.get(kind, []):
		var current: Variant = values.get(key, CHOICES[key][0][0])
		_fields.add_child(Ui.choice(_label(key), CHOICES[key], current, func(value: String) -> void: _choose(key, value), 3))
		_add_reset(key)
	var shown := []
	for key in NUMBERS.get(kind, []):
		shown.append(key)
		_number(key, values.get(key, _fallback(key)))
	for key in values:
		if not key in shown and (values[key] is float or values[key] is int) and key != "number" and key != "threat":
			_number(key, values[key])
	var abilities: Array = values.get("abilities", [])
	for i in abilities.size():
		_fields.add_child(Ui.label(String(abilities[i].id).capitalize(), "HeadingLabel"))
		for key in abilities[i]:
			if abilities[i][key] is float or abilities[i][key] is int:
				_fields.add_child(Ui.number(String(key).capitalize(), abilities[i][key], func(v: float) -> void: _set_ability(abilities, i, key, v)))
	if not abilities.is_empty():
		_fields.add_child(Ui.button("Reset abilities", func() -> void: _reset("abilities")))
	if values.has("evolution"):
		_fields.add_child(Ui.label("Evolution: %s" % values.evolution.get("name", ""), "HeadingLabel"))
		for key in values.evolution:
			if values.evolution[key] is float or values.evolution[key] is int:
				_fields.add_child(Ui.number(String(key).capitalize(), values.evolution[key], func(v: float) -> void: _set_path(["evolution", key], v)))
		_fields.add_child(Ui.button("Reset evolution", func() -> void: _reset("evolution")))
	_fields.add_child(Ui.spacer(12))
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
	if now != null and original != now:
		text += " (default %s)" % (str(original) if original != null else "none")
	return text


func _add_reset(key: String) -> void:
	var original: Variant = _default(key)
	var now: Variant = _values().get(key)
	if now != null and original != now:
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
