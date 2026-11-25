class_name EphrocityMeter
extends Control
## The wine red Ephrocity bar under the hand. Each of the ten segments fills up smoothly,
## and full segments glow brighter so the count can be read at a glance.

const EMPTY := Color("#2A1518")
const FILLING := Color("#722F37")
const FULL := Color("#A33B4C")
const GAP := 6.0

var hand: Hand
var bars := 10


func _ready() -> void:
	custom_minimum_size.y = 64


func _draw() -> void:
	if hand == null:
		return
	var amount := hand.ephrocity
	var number_width := 72.0
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, size.y * 0.72), str(floori(amount)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.7), FULL.lightened(0.3))
	var width := (size.x - number_width - GAP * (bars - 1)) / bars
	for i in bars:
		var box := Rect2(number_width + i * (width + GAP), 0, width, size.y)
		draw_rect(box, EMPTY)
		var fill := clampf(amount - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(box.position, Vector2(width * fill, size.y)), FULL if fill >= 1.0 else FILLING)
