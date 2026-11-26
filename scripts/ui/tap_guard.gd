class_name TapGuard
extends Node
## Makes a button react only to a clean tap: the finger goes down and comes up again on the button without moving away.
## Holding a button, sliding off and letting go does nothing, and neither does a finger that moves to scroll or swipe.
## Every button in the app gets one as it appears (see Nav), so they all work the same way.
## By default a tap does what the button normally does: it flips a toggle and sends pressed. A button can be given its own
## tap action instead, and an action for holding still a moment, such as picking up a card to move it.
## The button stops reacting to presses itself, and the guard decides instead.

const HOLD_MS := 450
const MOVE_SLACK := 24.0
## Buttons that already have a guard, or should be left alone, carry this mark.
const MARK := "tap_guard"

var _on_tap: Callable
var _on_hold: Callable
var _button: BaseButton
var _down_at: Variant = null
var _down_ms := 0
var _moved := false
var _held := false


## Gives a button a guard. Without a tap action, a tap does what the button normally does.
static func attach(button: BaseButton, on_tap := Callable(), on_hold := Callable()) -> TapGuard:
	var guard := TapGuard.new()
	guard._on_tap = on_tap
	guard._on_hold = on_hold
	guard._button = button
	button.set_meta(MARK, true)
	button.button_mask = 0
	# Card tiles and sideways rows let touches pass on, so a swipe that starts on them still scrolls the list behind.
	if on_tap.is_valid() or on_hold.is_valid():
		button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.gui_input.connect(guard._on_input)
	# The guard joins once the button has settled in, which is safe even while the button itself is being added.
	button.add_child.call_deferred(guard)
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
			if not _button.disabled:
				_button.button_down.emit()
		elif _down_at != null:
			_down_at = null
			if not _button.disabled:
				_button.button_up.emit()
			if not _moved and not _held and not _button.disabled and Rect2(Vector2.ZERO, _button.size).has_point(event.position):
				_tap()
	elif event is InputEventMouseMotion and _down_at != null:
		if event.position.distance_to(_down_at) > MOVE_SLACK or not Rect2(Vector2.ZERO, _button.size).has_point(event.position):
			if not _moved and not _button.disabled:
				_button.button_up.emit()
			_moved = true


## What a clean tap does: the button's own tap action, or else what a normal press would do.
## A toggle flips, except a picked button in a group that has to keep one picked, and then pressed is sent.
func _tap() -> void:
	if _on_tap.is_valid():
		_on_tap.call()
		return
	if _button.toggle_mode:
		var group := _button.button_group
		if not (_button.button_pressed and group != null and not group.allow_unpress):
			_button.button_pressed = not _button.button_pressed
	_button.pressed.emit()


func _process(_delta: float) -> void:
	if _down_at != null and not _moved and not _held and Time.get_ticks_msec() - _down_ms >= HOLD_MS:
		_held = true
		_on_hold.call()
