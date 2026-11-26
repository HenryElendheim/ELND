class_name Burst
extends Control
## Rays of light that spin behind a card, with a soft glow in the middle, in a colour of choice.
## Strength runs from 0 to 1, and the rays turn slowly unless reduced motion is on.
## Used when cards come out of chests and when a card levels up.

var colour := Color.WHITE
var strength := 0.0
var rays := 0
var spin := 0.0


func _process(delta: float) -> void:
	if strength > 0.0:
		if not Settings.reduced_motion():
			spin += delta * 0.6
		queue_redraw()


func _draw() -> void:
	if strength <= 0.0:
		return
	var middle := size / 2.0
	# The rays reach well past the edges, which keeps the layout small while the light fills the screen.
	var reach := minf(size.x, size.y) * 0.8
	draw_circle(middle, reach * 0.55, Color(colour, 0.35 * strength))
	draw_circle(middle, reach * 0.35, Color(colour.lightened(0.4), 0.4 * strength))
	for i in rays:
		var angle := spin + TAU * i / rays
		var tip := middle + Vector2.from_angle(angle) * reach
		var side := Vector2.from_angle(angle + PI / 2.0) * reach * 0.08
		draw_colored_polygon(PackedVector2Array([middle, tip + side, tip - side]), Color(colour, 0.3 * strength))
