class_name AdminPanel
extends PanelContainer
## The basic Admin Mode tools shown over the lower part of the battle screen:
## time controls, debug overlays, clearing the field, and live stat editing for every card and tower.

const SPEEDS := [[0.0, "Pause"], [0.25, "0.25x"], [0.5, "0.5x"], [1.0, "1x"], [2.0, "2x"]]
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
	for overlay in OVERLAYS:
		column.add_child(Ui.toggle(overlay[0], _view.get(overlay[1]), func(on: bool) -> void: _view.set(overlay[1], on)))
	column.add_child(Ui.button("Clear troops", Callable(_battle, "clear_troops")))

	var subjects := [["towers/side", "Side tower"], ["towers/main", "Main tower"]]
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		subjects.append(["cards/" + id, cards[id].name.trim_prefix("The ")])
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
	for key in stats:
		var value: Variant = stats[key]
		if value is float or value is int:
			_fields.add_child(Ui.number(key.capitalize(), value, func(v: float) -> void: Data.set_override(file, path + [key], v)))
	_fields.add_child(Ui.button("Reset to default", func() -> void: _reset(file, path, subject)))


func _reset(file: String, path: Array, subject: String) -> void:
	Data.reset_override(file, path)
	_show_fields(subject)
