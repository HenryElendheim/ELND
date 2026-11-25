class_name Screen
extends Control
## Base for every full screen menu. It sets up safe margins and a scrolling column,
## so each screen only has to fill content with its own controls inside build().

const SIDE_MARGIN := 56
const TOP_MARGIN := 120

var content := VBoxContainer.new()


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", TOP_MARGIN)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(content)
	build()


func build() -> void:
	pass


## Adds a control to the bottom of the column and hands it back, so it can be adjusted further.
func add(node: Control) -> Control:
	content.add_child(node)
	return node


## Called when the Android back button is pressed. Returning false means there is nowhere to go back to.
func go_back() -> bool:
	return false
