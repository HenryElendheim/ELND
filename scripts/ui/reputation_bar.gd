class_name ReputationBar
extends Control
## A bar showing how far your reputation is between the Lab or Site you are at and the next one,
## with both names above it and the points on it. It can play the change after a battle: the gain pops up,
## the bar fills with a glowing leading edge while the number counts up, and crossing into a new place
## flashes the bar, starts it again from the new place and sends place_reached. A loss drains the bar instead.
## Reduced motion jumps straight to the end, still sending place_reached for every place crossed.

signal place_reached(place: int)

const GOLD := Color("#F2C14E")
const FILL_SECONDS := 1.1

var points := 0.0
var _gain := 0
var _gain_age := -1.0
var _flash := 0.0


func _init(start := 0) -> void:
	points = float(start)
	custom_minimum_size = Vector2(0, 150)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE


## Plays the change from where the bar is to a new reputation.
func play_to(target: int) -> void:
	var start := int(points)
	_gain = target - start
	_gain_age = 0.0
	var reached_from := Progress.arena_at(start)
	if Settings.reduced_motion():
		points = float(target)
		queue_redraw()
		for place in range(reached_from + 1, Progress.arena_at(target) + 1):
			place_reached.emit(place)
		return
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.35)
	tween.tween_method(_move, float(start), float(target), FILL_SECONDS)


func _move(value: float) -> void:
	var before := Progress.arena_at(int(points))
	points = value
	var now := Progress.arena_at(int(points))
	if now > before:
		_flash = 1.0
		Sfx.play("level_up")
		if Settings.get_value("vibration"):
			Input.vibrate_handheld(200)
		place_reached.emit(now)
	elif int(value) % 5 == 0:
		Sfx.play("tick")
	queue_redraw()


func _process(delta: float) -> void:
	if _gain_age >= 0.0:
		_gain_age += delta
		if _gain_age > 1.8:
			_gain_age = -1.0
	_flash = maxf(_flash - delta * 2.0, 0.0)
	if _gain_age >= 0.0 or _flash > 0.0:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var place := Progress.arena_at(int(points))
	var last := place >= Progress.arena_count()
	var font_size := 40
	draw_string(font, Vector2(0, 44), Progress.arena_name(place), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var right := "Top of the road" if last else Progress.arena_name(place + 1)
	draw_string(font, Vector2(0, 44), right, HORIZONTAL_ALIGNMENT_RIGHT, size.x, font_size, Color(1, 1, 1, 0.7))
	var bar := Rect2(0, 64, size.x, 52)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var share := Progress.share_to_next(int(points))
	var filled := Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y))
	draw_rect(filled, GOLD.lerp(Color.WHITE, _flash * 0.7))
	# The leading edge glows, which makes the bar feel like it is pouring in.
	if share > 0.0 and share < 1.0:
		draw_rect(Rect2(filled.end.x - 10, bar.position.y, 10, bar.size.y), Color(1, 1, 1, 0.6))
	draw_rect(bar, Color(1, 1, 1, 0.35 + 0.5 * _flash), false, 3.0)
	var label := "%d reputation" % int(points) if last else "%d / %d" % [int(points), Progress.reputation_for(place + 1)]
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string_outline(font, Vector2((size.x - width) / 2.0, bar.position.y + 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Color.BLACK)
	draw_string(font, Vector2((size.x - width) / 2.0, bar.position.y + 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	# The gain floats up from the bar and fades.
	if _gain_age >= 0.0 and _gain != 0:
		var rise := 0.0 if Settings.reduced_motion() else _gain_age * 30.0
		var text := "%+d" % _gain
		var colour := GOLD if _gain > 0 else Color(1, 0.4, 0.4)
		var fade := clampf(1.8 - _gain_age, 0.0, 1.0)
		draw_string_outline(font, Vector2(size.x - 140, 140 - rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 6, Color(0, 0, 0, fade))
		draw_string(font, Vector2(size.x - 140, 140 - rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(colour, fade))
