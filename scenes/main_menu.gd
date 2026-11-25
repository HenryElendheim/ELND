extends Control
## The main menu: five pages you slide between, with tabs along the bottom. It opens on the Battle page,
## or on whichever page the previous screen asked for.

const PAGES := [
	["Shop", "res://scenes/shop.tscn"],
	["Cards", "res://scenes/deck.tscn"],
	["Battle", "res://scenes/home.tscn"],
	["Codex", "res://scenes/codex.tscn"],
	["Stats", "res://scenes/stats.tscn"],
]
const HOME := 2

var _pager := Pager.new()
var _tabs: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_pager)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var screen: Screen = load(PAGES[i][1]).instantiate()
		screen.embedded = true
		_pager.add_page(screen)
		var tab := Ui.button(PAGES[i][0], func() -> void: _pager.go_to(i))
		tab.toggle_mode = true
		tab.button_group = group
		tab.clip_text = true
		tab.custom_minimum_size.y = 130
		_tabs.append(tab)
		tab_row.add_child(tab)
	column.add_child(tab_row)
	_pager.page_changed.connect(_show_tab)
	_pager.go_to(int(Nav.params.get("page", HOME)), false)


func _show_tab(index: int) -> void:
	_tabs[index].set_pressed_no_signal(true)


## The Android back gesture goes to the Battle page first, and only closes the app from there.
func go_back() -> bool:
	if _pager.page != HOME:
		_pager.go_to(HOME)
		return true
	return false
