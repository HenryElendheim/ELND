class_name DragScroll
extends Node
## Makes a list scroll with a finger drag that starts anywhere on it, buttons included.
## A press that does not move still reaches the button. Once the finger has clearly moved along the list,
## it becomes a scroll and the button underneath is let go. A quick flick keeps the list moving for a moment,
## unless reduced motion is on. Lists scroll up and down, or sideways for a row such as the collection filters.
## A sideways row joins a group that page swipes leave alone, which means dragging it never flips the page.

const START := 20.0
const FRICTION := 6.0

var _scroll: ScrollContainer
var _sideways := false
var _press_at: Variant = null
var _start_value := 0.0
var _dragging := false
var _speed := 0.0
var _last_y := 0.0


## Adds drag scrolling to a list and returns the list, so it can be used inline.
static func attach(scroll: ScrollContainer, sideways := false) -> ScrollContainer:
	var helper := DragScroll.new()
	helper._scroll = scroll
	helper._sideways = sideways
	if sideways:
		scroll.add_to_group(Touch.SIDEWAYS_GROUP)
	scroll.add_child(helper)
	return scroll


## How far along the list the finger is, up and down or sideways.
func _along(point: Vector2) -> float:
	return point.x if _sideways else point.y


func _value() -> int:
	return _scroll.scroll_horizontal if _sideways else _scroll.scroll_vertical


func _set_value(value: int) -> void:
	if _sideways:
		_scroll.scroll_horizontal = value
	else:
		_scroll.scroll_vertical = value


func _input(event: InputEvent) -> void:
	if Touch.cancelling or Touch.holding or not _scroll.is_visible_in_tree() or Touch.blocked(_scroll):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _scroll.get_global_rect().has_point(event.position):
			_press_at = event.position
			_start_value = _value()
			_last_y = _along(event.position)
			_speed = 0.0
			_dragging = false
		elif not event.pressed and _press_at != null:
			if _dragging:
				get_viewport().set_input_as_handled()
			_press_at = null
			_dragging = false
	elif event is InputEventMouseMotion and _press_at != null and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved: Vector2 = event.position - _press_at
		var along := _along(moved)
		var across := moved.y if _sideways else moved.x
		if not _dragging and absf(along) > START and absf(along) > absf(across):
			_dragging = true
			Touch.cancel_press(get_viewport())
		if _dragging:
			_set_value(int(_start_value - along))
			_speed = (_last_y - _along(event.position)) / maxf(get_process_delta_time(), 0.001)
			_last_y = _along(event.position)
			get_viewport().set_input_as_handled()


## After the finger lifts, a flick keeps scrolling and slows down smoothly.
func _process(delta: float) -> void:
	if _dragging or _press_at != null or absf(_speed) < 20.0 or Settings.reduced_motion():
		_speed = 0.0 if _press_at == null and Settings.reduced_motion() else _speed
		return
	_set_value(_value() + int(_speed * delta))
	_speed = lerpf(_speed, 0.0, minf(FRICTION * delta, 1.0))
