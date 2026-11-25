extends Control
## Opens waiting chests one at a time. Tap the chest and it shakes while Ephrocity leaks out, longer for rarer chests.
## Its glow only turns to the rarity colour at the very last moment. A Legendary chest sets off a full containment breach.
## Then the cards come out one per tap, and a new card gets the codex stamp. Reduced motion skips the shaking and fades.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const WINE := Color("#A33B4C")

var _chest := ColorRect.new()
var _title: Label
var _detail: Label
var _stamp: Label
var _alarm := ColorRect.new()
var _skip: Button
var _opened := {}
var _reveal := -1
var _busy := false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_alarm.set_anchors_preset(PRESET_FULL_RECT)
	_alarm.color = Color(0.7, 0, 0, 0)
	_alarm.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_alarm)

	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 40)
	# The layout ignores taps so they reach this screen, and only the Skip button catches its own.
	column.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(column)
	_title = _centered(column, "TitleLabel")
	var holder := CenterContainer.new()
	holder.custom_minimum_size.y = 420
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(holder)
	_chest.mouse_filter = MOUSE_FILTER_IGNORE
	_chest.custom_minimum_size = Vector2(360, 300)
	_chest.pivot_offset = _chest.custom_minimum_size / 2.0
	holder.add_child(_chest)
	_detail = _centered(column, "HeadingLabel")
	_stamp = _centered(column, "HeadingLabel")
	_skip = Ui.button("Skip", _skip_to_end)
	_skip.size_flags_horizontal = SIZE_SHRINK_CENTER
	_skip.custom_minimum_size.x = 400
	column.add_child(_skip)
	_show_waiting()


func _centered(column: Container, variation: String) -> Label:
	var node := Ui.label("", variation)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(node)
	return node


## Shows the next closed chest, or goes back to the menu when none are left.
func _show_waiting() -> void:
	var waiting := Progress.chests_waiting()
	if waiting.is_empty():
		Nav.go(MENU_SCENE)
		return
	_opened = {}
	_reveal = -1
	_title.text = "%s chest" % String(waiting[0]).capitalize()
	_detail.text = "Tap to open"
	_stamp.text = ""
	_chest.color = Color("#2A2A33")
	_chest.rotation = 0.0
	_skip.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _busy:
		if _opened.is_empty():
			_open()
		else:
			_next_card()


## The build-up before the reveal. Rarer chests shake longer and harder, and Legendary ones go dark with alarm lights.
func _open() -> void:
	_busy = true
	_opened = Progress.open_next_chest()
	if _opened.is_empty():
		Nav.go(MENU_SCENE)
		return
	var rarity: String = _opened.rarity
	var chests := Data.table("chests")
	var colour := Color(chests.colours[rarity])
	var build_up := float(chests.build_up_seconds[rarity])
	_detail.text = ""
	if not Settings.reduced_motion():
		if rarity == "legendary":
			_title.text = "CONTAINMENT BREACH"
			var alarm := create_tween().set_loops(3)
			alarm.tween_property(_alarm, "color:a", 0.45, build_up / 6.0)
			alarm.tween_property(_alarm, "color:a", 0.0, build_up / 6.0)
		var shake := create_tween()
		var steps := int(build_up / 0.05)
		for i in steps:
			var strength := 0.04 + 0.12 * float(i) / steps
			shake.tween_property(_chest, "rotation", strength * (1 if i % 2 == 0 else -1), 0.05)
			shake.parallel().tween_property(_chest, "color", Color("#2A2A33").lerp(WINE, float(i) / steps), 0.05)
		await shake.finished
	_chest.rotation = 0.0
	_chest.color = colour
	Sfx.play("chest")
	_title.text = "%s chest" % rarity.capitalize()
	_buzz(400 if rarity in ["epic", "legendary"] else 120)
	_skip.visible = rarity in ["common", "rare"]
	_busy = false
	_next_card()


## Shows the next card from the chest, then the next chest once every card has been seen.
func _next_card() -> void:
	_reveal += 1
	var cards: Array = _opened.cards
	if _reveal >= cards.size():
		_show_waiting()
		return
	var drop: Dictionary = cards[_reveal]
	if drop.has("text"):
		_detail.text = drop.text
		_stamp.text = ""
		_buzz(250)
		return
	var card: Dictionary = Data.table("cards").cards[drop.id]
	_detail.text = "%s  x%d\nLevel %d" % [card.name, drop.count, drop.level]
	_stamp.text = "NEW ANOMALY ACQUIRED" if drop.new else ("Level up" if drop.levelled else "")
	if drop.new or drop.levelled:
		_buzz(150)


func _skip_to_end() -> void:
	_reveal = _opened.get("cards", []).size() - 1
	_next_card()


func _buzz(ms: int) -> void:
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(ms)


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
