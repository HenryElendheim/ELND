class_name DragScroll
extends Node
## Makes a list scroll with a finger drag that starts anywhere on it, buttons included.
## A press that does not move still reaches the button. Once the finger has clearly moved up or down,
## it becomes a scroll and the button underneath is let go. A quick flick keeps the list moving for a moment,
## unless reduced motion is on.

const START := 20.0
const FRICTION := 6.0

var _scroll: ScrollContainer
var _press_at: Variant = null
var _start_value := 0.0
var _dragging := false
var _speed := 0.0
var _last_y := 0.0


## Adds drag scrolling to a list and returns the list, so it can be used inline.
static func attach(scroll: ScrollContainer) -> ScrollContainer:
	var helper := DragScroll.new()
	helper._scroll = scroll
	scroll.add_child(helper)
	return scroll


func _input(event: InputEvent) -> void:
	if Touch.cancelling or Touch.holding or not _scroll.is_visible_in_tree() or Touch.blocked(_scroll):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _scroll.get_global_rect().has_point(event.position):
			_press_at = event.position
			_start_value = _scroll.scroll_vertical
			_last_y = event.position.y
			_speed = 0.0
			_dragging = false
		elif not event.pressed and _press_at != null:
			if _dragging:
				get_viewport().set_input_as_handled()
			_press_at = null
			_dragging = false
	elif event is InputEventMouseMotion and _press_at != null and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved: Vector2 = event.position - _press_at
		if not _dragging and absf(moved.y) > START and absf(moved.y) > absf(moved.x):
			_dragging = true
			Touch.cancel_press(get_viewport())
		if _dragging:
			_scroll.scroll_vertical = int(_start_value - moved.y)
			_speed = (_last_y - event.position.y) / maxf(get_process_delta_time(), 0.001)
			_last_y = event.position.y
			get_viewport().set_input_as_handled()


## After the finger lifts, a flick keeps scrolling and slows down smoothly.
func _process(delta: float) -> void:
	if _dragging or _press_at != null or absf(_speed) < 20.0 or Settings.reduced_motion():
		_speed = 0.0 if _press_at == null and Settings.reduced_motion() else _speed
		return
	_scroll.scroll_vertical += int(_speed * delta)
	_speed = lerpf(_speed, 0.0, minf(FRICTION * delta, 1.0))
