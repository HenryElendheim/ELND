class_name TapGuard
extends Node
## Makes a button react only to a clean tap: the finger goes down and comes up again in the same place.
## A finger that moves is left to scroll or swipe whatever is around the button, and nothing gets picked.
## Holding still for a moment can do something else, such as picking up a card to move it.
## The button itself stops reacting to presses and lets touches pass on to the list around it.

const HOLD_MS := 450
const MOVE_SLACK := 18.0

var _on_tap: Callable
var _on_hold: Callable
var _button: Control
var _down_at: Variant = null
var _down_ms := 0
var _moved := false
var _held := false


static func attach(button: BaseButton, on_tap: Callable, on_hold := Callable()) -> TapGuard:
	var guard := TapGuard.new()
	guard._on_tap = on_tap
	guard._on_hold = on_hold
	guard._button = button
	button.button_mask = 0
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.gui_input.connect(guard._on_input)
	button.add_child(guard)
	return guard


func _ready() -> void:
	set_process(_on_hold.is_valid())


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down_at = event.position
			_down_ms = Time.get_ticks_msec()
			_moved = false
			_held = false
		elif _down_at != null:
			if not _moved and not _held and Rect2(Vector2.ZERO, _button.size).has_point(event.position):
				_on_tap.call()
			_down_at = null
	elif event is InputEventMouseMotion and _down_at != null and event.position.distance_to(_down_at) > MOVE_SLACK:
		_moved = true


func _process(_delta: float) -> void:
	if _down_at != null and not _moved and not _held and Time.get_ticks_msec() - _down_ms >= HOLD_MS:
		_held = true
		_on_hold.call()
