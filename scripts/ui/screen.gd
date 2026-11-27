class_name Screen
extends Control
## Base for every full screen menu. It sets up safe margins and a scrolling column,
## so each screen only has to fill content with its own controls inside build().
## Screens opened on top of the main menu get a Back button fixed in the top left corner, which never scrolls away.

const SIDE_MARGIN := 56
const TOP_MARGIN := 120
const BACK_SIZE := Vector2(260, 110)
## How far down from the top of the screen the Back button sits.
const BACK_TOP := 64

var content := VBoxContainer.new()
## The scrolling area around the content, so a screen can scroll to a part of itself.
var scroll_box: ScrollContainer
## True when the screen sits inside a page of the main menu, which has its own tabs, so it needs no Back button.
var embedded := false

var _margin := MarginContainer.new()
var _back: Button


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := _margin
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", TOP_MARGIN)
	margin.add_theme_constant_override("margin_bottom", SIDE_MARGIN)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll_box = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	DragScroll.attach(scroll)

	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(content)
	_back = Ui.button("Back", func() -> void: go_back())
	_back.size_flags_horizontal = SIZE_FILL
	_back.custom_minimum_size = BACK_SIZE
	_back.position = Vector2(SIDE_MARGIN, BACK_TOP)
	add_child(_back)
	build()
	refresh_back()
	# The screen fades in as it opens, unless reduced motion is on.
	if not Settings.reduced_motion():
		content.modulate.a = 0.0
		create_tween().tween_property(content, "modulate:a", 1.0, 0.25)


func build() -> void:
	pass


## Whether the Back button in the top left shows. Screens on top of the main menu have it,
## and a page of the main menu can ask for it while it shows a deeper view, as the advanced stats do.
func wants_back() -> bool:
	return not embedded


## Shows or hides the Back button to match wants_back, and makes room for it above the content.
func refresh_back() -> void:
	var shown := wants_back()
	_back.visible = shown
	_margin.add_theme_constant_override("margin_top", TOP_MARGIN + (int(BACK_SIZE.y) + BACK_TOP - 24 if shown else 0))


## Adds a control to the bottom of the column and hands it back, so it can be adjusted further.
func add(node: Control) -> Control:
	content.add_child(node)
	return node


## Called when the Android back button is pressed. Returning false means there is nowhere to go back to.
func go_back() -> bool:
	return false
