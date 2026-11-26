class_name TapGuard
extends Node
## Makes a button react only to a clean tap: the finger goes down and comes up again on the button without moving away.
## Holding a button, sliding off and letting go does nothing, and neither does a finger that moves to scroll or swipe.
## Every button in the app gets one as it appears (see Nav), so they all work the same way.
## A normal button keeps doing its own pressing, and the guard only watches the finger: once it slides away or moves
## too far, the guard lets go of the button far off screen, which cancels the press, the same way scrolling does.
## A button can instead be given its own tap action, and an action for holding still a moment, such as picking up
## a card to move it. Such a button stops pressing itself, lets touches pass on to the list around it,
## and the guard decides what a tap is.

const HOLD_MS := 450
const MOVE_SLACK := 24.0
## Buttons that already have a guard, or should be left alone, carry this mark.
const MARK := "tap_guard"

var _on_tap: Callable
var _on_hold: Callable
var _button: BaseButton
var _custom := false
var _down_at: Variant = null
var _down_ms := 0
var _moved := false
var _held := false


## Gives a button a guard. Without a tap action, the button keeps pressing itself and the guard only cancels slides.
static func attach(button: BaseButton, on_tap := Callable(), on_hold := Callable()) -> TapGuard:
	var guard := TapGuard.new()
	guard._on_tap = on_tap
	guard._on_hold = on_hold
	guard._button = button
	guard._custom = on_tap.is_valid() or on_hold.is_valid()
	button.set_meta(MARK, true)
	# Card tiles and sideways rows let touches pass on, so a swipe that starts on them still scrolls the list behind.
	if guard._custom:
		button.button_mask = 0
		button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.gui_input.connect(guard._on_input)
	# The guard joins once the button has settled in, which is safe even while the button itself is being added.
	button.add_child.call_deferred(guard)
	return guard


func _ready() -> void:
	set_process(_on_hold.is_valid())


func _on_input(event: InputEvent) -> void:
	if Touch.cancelling:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down_at = event.position
			_down_ms = Time.get_ticks_msec()
			_moved = false
			_held = false
		elif _down_at != null:
			_down_at = null
			if _custom and not _moved and not _held and not _button.disabled and _inside(event.position):
				_on_tap.call()
	elif event is InputEventMouseMotion and _down_at != null and not _moved:
		if event.position.distance_to(_down_at) > MOVE_SLACK or not _inside(event.position):
			_moved = true
			# A normal button is still pressed, so it is let go far away, which means it will not fire.
			if not _custom:
				_down_at = null
				Touch.cancel_press(_button.get_viewport())


func _inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, _button.size).has_point(point)


func _process(_delta: float) -> void:
	if _down_at != null and not _moved and not _held and Time.get_ticks_msec() - _down_ms >= HOLD_MS:
		_held = true
		_on_hold.call()
