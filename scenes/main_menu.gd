extends Control
## The main menu: four pages you slide between, with tabs along the bottom. It opens on the Battle page,
## or on whichever page the previous screen asked for.

const PAGES := [
	["Shop", "res://scenes/shop.tscn"],
	["Cards", "res://scenes/deck.tscn"],
	["Battle", "res://scenes/home.tscn"],
	["Stats", "res://scenes/stats.tscn"],
]
const HOME := 2

var _pager := Pager.new()


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_pager)
	var names := []
	for entry in PAGES:
		var screen: Screen = load(entry[1]).instantiate()
		screen.embedded = true
		_pager.add_page(screen)
		names.append(entry[0])
	_pager.page = int(Nav.params.get("page", HOME))
	column.add_child(_pager.make_tabs(names))
	_pager.go_to(_pager.page, false)


## The Android back gesture goes to the Battle page first, and only closes the app from there.
func go_back() -> bool:
	if _pager.page != HOME:
		_pager.go_to(HOME)
		return true
	return false
