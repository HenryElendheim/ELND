class_name AdminPanel
extends PanelContainer
## The basic Admin Mode tools shown over the lower part of the battle screen:
## time controls, debug overlays, clearing the field, and live stat editing for every card and tower.

const SPEEDS := [[0.0, "Pause"], [0.25, "0.25x"], [0.5, "0.5x"], [1.0, "1x"], [2.0, "2x"]]
const SIDES := [[Unit.Team.PLAYER, "You"], [Unit.Team.ENEMY, "Enemy"]]
const OVERLAYS := [["Hitboxes", "show_hitboxes"], ["Attack ranges", "show_ranges"], ["Targeting lines", "show_targets"], ["FPS", "show_fps"]]

var _battle: Node
var _view: ArenaView
var _fields := VBoxContainer.new()


func _init(battle: Node, view: ArenaView) -> void:
	_battle = battle
	_view = view


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	anchor_top = 0.45
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	DragScroll.attach(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)

	var header := HBoxContainer.new()
	header.add_child(Ui.label("Admin Mode", "HeadingLabel"))
	var close := Ui.button("Close", hide)
	close.size_flags_horizontal = SIZE_FILL
	header.add_child(close)
	column.add_child(header)

	column.add_child(Ui.choice("Speed", SPEEDS, _battle.get("speed"), func(value: float) -> void: _battle.set("speed", value)))

	# The spawn tool drops any troop anywhere for free, on either side.
	var troops := [["", "Off"]]
	var cards: Dictionary = Data.table("cards").cards
	for id in BattleSim.starting_deck():
		troops.append([id, CardTile.short_name(id)])
	column.add_child(Ui.choice("Spawn tool", troops, "", func(id: String) -> void: _battle.set("spawn_card", id), 4))
	column.add_child(Ui.choice("Spawn for", SIDES, Unit.Team.PLAYER, func(team: int) -> void: _battle.set("spawn_team", team)))
	var sim: BattleSim = _battle.get("sim")
	column.add_child(Ui.toggle("Bot plays", true, func(on: bool) -> void: sim.bot.enabled = on))
	var hands: Array = sim.hands
	for side in SIDES:
		var hand: Hand = hands[side[0]]
		column.add_child(Ui.toggle("Endless Ephrocity: " + side[1], false, func(on: bool) -> void: hand.infinite = on))
	for overlay in OVERLAYS:
		column.add_child(Ui.toggle(overlay[0], _view.get(overlay[1]), func(on: bool) -> void: _view.set(overlay[1], on)))
	column.add_child(Ui.button("Clear troops", Callable(_battle, "clear_troops")))
	column.add_child(Ui.button("Give an Evolution Injection", _give_injection))

	var subjects := [["towers/side", "Side tower"], ["towers/main", "Main tower"]]
	for id in cards:
		subjects.append(["cards/" + id, CardTile.short_name(id)])
	column.add_child(Ui.label("Edits save by themselves and stay in normal games too, until you reset them.", "MutedLabel"))
	column.add_child(Ui.button("Export balance", func() -> void: Backup.export_balance(Nav.toast)))
	column.add_child(Ui.choice("Edit stats", subjects, subjects[0][0], _show_fields))
	column.add_child(_fields)
	_show_fields(subjects[0][0])


## Lists every number of one card or tower as an editable box. A subject looks like "cards/hobb" or "towers/side".
func _show_fields(subject: String) -> void:
	for child in _fields.get_children():
		child.queue_free()
	var parts := subject.split("/")
	var file := parts[0]
	var path := [parts[1]] if file == "towers" else ["cards", parts[1]]
	var stats: Dictionary = Data.table(file)[path[0]] if file == "towers" else Data.table(file).cards[parts[1]]
	_number_fields(stats, func(key: String, v: float) -> void: Data.set_override(file, path + [key], v))
	# Each ability gets its own block of numbers. Abilities are a list in cards.json, so a change stores
	# the card's whole ability list with that one number changed, and Reset to default puts it all back.
	var abilities: Array = stats.get("abilities", [])
	for i in abilities.size():
		_fields.add_child(Ui.label(String(abilities[i].id).capitalize(), "HeadingLabel"))
		_number_fields(abilities[i], func(key: String, v: float) -> void: _set_ability(path, abilities, i, key, v))
	if stats.has("evolution"):
		_fields.add_child(Ui.label("Evolution: %s" % stats.evolution.get("name", ""), "HeadingLabel"))
		_number_fields(stats.evolution, func(key: String, v: float) -> void: Data.set_override(file, path + ["evolution", key], v))
	_fields.add_child(Ui.button("Reset to default", func() -> void: _reset(file, path, subject)))


## Adds an editable box for every number in a dictionary. The change callback gets the key and the new value.
func _number_fields(values: Dictionary, on_change: Callable) -> void:
	for key in values:
		var value: Variant = values[key]
		if value is float or value is int:
			_fields.add_child(Ui.number(String(key).capitalize(), value, func(v: float) -> void: on_change.call(key, v)))


func _set_ability(path: Array, abilities: Array, index: int, key: String, value: float) -> void:
	var changed := abilities.duplicate(true)
	changed[index][key] = value
	abilities[index][key] = value
	Data.set_override("cards", path + ["abilities"], changed)


func _give_injection() -> void:
	Progress.add_injection()
	Nav.toast("Injection added")


func _reset(file: String, path: Array, subject: String) -> void:
	Data.reset_override(file, path)
	_show_fields(subject)
