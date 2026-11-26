class_name Celebration
extends CanvasLayer
## Base for the full screen celebrations, such as a card levelling up or reaching a new Lab or Site.
## It lays a dark cover over everything with a column in the middle: a title, a burst of rays behind a centre piece,
## and lines of text underneath, plus a white flash on top. The first tap skips to the end, and the next one closes it.
## Children fill in the centre and the lines in build(), play the animation in play() and show the end in finish().
## Reduced motion goes straight to the end, rays and all.

signal closed

var cover := Panel.new()
var column := VBoxContainer.new()
var burst := Burst.new()
var flash := ColorRect.new()
var holder := CenterContainer.new()
var title: Label
var hint: Label
## True once the celebration is showing its end, after which a tap closes it.
var done := false


func _init() -> void:
	layer = 60
	add_to_group(Pager.MODAL_GROUP)


func _ready() -> void:
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.theme = Settings.current_theme
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(Settings.palette().bg, 0.96)
	cover.add_theme_stylebox_override("panel", fill)
	cover.gui_input.connect(_on_tap)
	add_child(cover)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(column)
	title = line("", "TitleLabel")
	holder.custom_minimum_size.y = 480
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	burst.custom_minimum_size = Vector2(480, 480)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(burst)
	build()
	hint = line("", "MutedLabel")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(flash)
	if Settings.reduced_motion():
		_end()
	else:
		play()


func build() -> void:
	pass


func play() -> void:
	_end()


func finish() -> void:
	pass


func _end() -> void:
	done = true
	burst.strength = 1.0
	finish()
	hint.text = "Tap to continue"


## A centred line of text in the column.
func line(text: String, variation: String) -> Label:
	var label := Ui.label(text, variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return label


## A white flash over the whole screen that fades out.
func flash_screen(strength := 0.8) -> void:
	flash.color.a = strength
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


## Slams a control down from big, with a little overshoot.
func slam(node: Control, from: float) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE * from
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(node, "scale", Vector2.ONE, 0.3)


func buzz(ms: int) -> void:
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(ms)


## The first tap skips to the end, and the next one closes.
func _on_tap(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not done:
		_end()
		return
	closed.emit()
	queue_free()
