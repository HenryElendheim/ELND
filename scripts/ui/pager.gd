class_name Pager
extends Control
## Pages side by side that you slide between with a finger, with a row of tabs underneath to jump straight to one.
## A sideways swipe is noticed before buttons and lists get it, so swiping works anywhere on a page,
## while an up and down drag is left alone for scrolling. Reduced motion jumps between pages instead of sliding.

signal page_changed(index: int)

const SWIPE_START := 24.0
const SLIDE_TIME := 0.22

var page := 0

var _strip := Control.new()
var _pages: Array[Control] = []
var _press_at: Variant = null
var _swiping := false
var _drag := 0.0
## Set while this pager sends its own pretend release, so it does not mistake it for the finger lifting.
var _cancelling := false
var _tween: Tween
var _tabs: Array[Button] = []

## Anything open on top of everything else, such as a card's details, joins this group.
## A pager underneath it ignores swipes, which means only the pager inside the open view slides.
const MODAL_GROUP := "modal"


func _ready() -> void:
	clip_contents = true
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_strip)
	resized.connect(_layout)


func add_page(node: Control) -> void:
	_pages.append(node)
	_strip.add_child(node)
	_layout()


## A row of tabs, one per page, that jumps to its page and lights up while that page is showing.
func make_tabs(names: Array, height := 130.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in names.size():
		var tab := Ui.button(names[i], func() -> void: go_to(i))
		tab.toggle_mode = true
		tab.button_group = group
		tab.clip_text = true
		tab.custom_minimum_size.y = height
		tab.set_pressed_no_signal(i == page)
		_tabs.append(tab)
		row.add_child(tab)
	return row


func go_to(index: int, animate := true) -> void:
	page = clampi(index, 0, _pages.size() - 1)
	_drag = 0.0
	if _tween != null:
		_tween.kill()
	var target := Vector2(-page * size.x, 0)
	if animate and not Settings.reduced_motion() and is_inside_tree():
		_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(_strip, "position", target, SLIDE_TIME)
	else:
		_strip.position = target
	# Every tab is set, not just the new one, which means exactly one tab is ever lit.
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == page)
	page_changed.emit(page)


## Lets go of whatever button the finger started on, far off screen, which means that button neither fires
## nor stays looking pressed once the touch has turned into a swipe.
func _cancel_press() -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-10000, -10000)
	release.global_position = release.position
	_cancelling = true
	get_viewport().push_input(release)
	_cancelling = false


func _layout() -> void:
	for i in _pages.size():
		_pages[i].set_anchors_preset(PRESET_TOP_LEFT)
		_pages[i].position = Vector2(i * size.x, 0)
		_pages[i].size = size
	_strip.position = Vector2(-page * size.x + _drag, 0)


## Watches every touch before the pages see it. Once a drag is clearly sideways, it becomes a swipe and the pages stop getting it.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for modal in get_tree().get_nodes_in_group(MODAL_GROUP):
		if not modal.is_ancestor_of(self):
			return
	if _cancelling:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_press_at = event.position
			_swiping = false
		elif not event.pressed and _press_at != null:
			if _swiping:
				var threshold := size.x * 0.2
				go_to(page + (1 if _drag < -threshold else (-1 if _drag > threshold else 0)))
				get_viewport().set_input_as_handled()
			_press_at = null
			_swiping = false
	elif event is InputEventMouseMotion and _press_at != null and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved: Vector2 = event.position - _press_at
		if not _swiping and absf(moved.x) > SWIPE_START and absf(moved.x) > absf(moved.y) * 1.5:
			_swiping = true
			get_viewport().gui_release_focus()
			_cancel_press()
		if _swiping:
			# Past the first and last page the strip only moves a little, which shows there is nothing further.
			var edge := (page == 0 and moved.x > 0) or (page == _pages.size() - 1 and moved.x < 0)
			_drag = moved.x * (0.25 if edge else 1.0)
			_strip.position = Vector2(-page * size.x + _drag, 0)
			get_viewport().set_input_as_handled()
