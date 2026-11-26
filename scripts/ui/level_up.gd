class_name LevelUp
extends CanvasLayer
## The celebration when a card levels up with wild cards, shown over everything.
## The card pops in and charges up with a shake and a rising tone. Then it bursts: a white flash, spinning rays
## in its rarity colour, sparks flying out, LEVEL UP slammed down, the level number ticking up, and health and damage
## counting up to their new values, with the gold it earned underneath. A tap skips to the end, and another tap closes it.
## Reduced motion shows the end straight away, rays and all, without any movement.

signal closed

const TILE_SIZE := Vector2(320, 400)
const SPARKS := 28

## Sparks that fly out from the middle and fall away, drawn by hand so they stay crisp at any size.
class Sparks extends Control:
	var colour := Color.WHITE
	var age := -1.0
	var _dirs: Array[Vector2] = []

	func fire(count: int) -> void:
		_dirs.clear()
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			_dirs.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.0))
		age = 0.0

	func _process(delta: float) -> void:
		if age >= 0.0:
			age += delta
			queue_redraw()
			if age > 1.2:
				age = -1.0

	func _draw() -> void:
		if age < 0.0:
			return
		var middle := size / 2.0
		var reach := minf(size.x, size.y) * 0.7
		var fade := 1.0 - age / 1.2
		for direction in _dirs:
			var at := middle + direction * reach * age + Vector2(0, 300.0 * age * age)
			draw_line(at, at - direction * 30.0, Color(colour.lightened(0.5), fade), 6.0)


var _id := ""
var _before := 1
var _after := 1
var _gold := 0
var _done := false
var _tile: CardTile
var _burst := Burst.new()
var _sparks := Sparks.new()
var _flash := ColorRect.new()
var _title: Label
var _level: Label
var _stats: Label
var _reward: Label
var _hint: Label


func _init(id: String, before: int, after: int, gold: int) -> void:
	_id = id
	_before = before
	_after = after
	_gold = gold
	layer = 60
	add_to_group(Pager.MODAL_GROUP)


func _ready() -> void:
	var rarity := Progress.card_rarity(_id)
	var colour := Color(Data.table("chests").colours.get(rarity, "#FFFFFF"))
	var cover := Panel.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.theme = Settings.current_theme
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(Settings.palette().bg, 0.96)
	cover.add_theme_stylebox_override("panel", fill)
	cover.gui_input.connect(_on_tap)
	add_child(cover)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(column)
	_title = _line(column, "", "TitleLabel")
	_title.add_theme_color_override("font_color", colour.lightened(0.3))
	var holder := CenterContainer.new()
	holder.custom_minimum_size.y = 480
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	for layer_node in [_burst, _sparks]:
		layer_node.custom_minimum_size = Vector2(480, 480)
		layer_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(layer_node)
	_burst.colour = colour
	_burst.rays = 16
	_sparks.colour = colour
	_tile = CardTile.new(_id)
	_tile.custom_minimum_size = TILE_SIZE
	_tile.pivot_offset = TILE_SIZE / 2.0
	_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_tile)
	_level = _line(column, "Level %d" % _before, "StatNumber")
	_stats = _line(column, _stats_text(_before), "HeadingLabel")
	_reward = _line(column, "", "")
	_hint = _line(column, "", "MutedLabel")
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(_flash)
	if Settings.reduced_motion():
		_finish()
	else:
		_play()


func _line(column: Container, text: String, variation: String) -> Label:
	var label := Ui.label(text, variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return label


## Health and damage at a level, the same way battles work them out.
func _stats_text(level: int) -> String:
	var card: Dictionary = Data.table("cards").cards[_id]
	var factor := pow(1.0 + float(Data.table("battle").level_scaling.per_level), level - 1)
	var parts := []
	if card.has("health"):
		parts.append("Health %d" % roundi(float(card.health) * factor))
	if float(card.get("damage", 0)) > 0.0:
		parts.append("Damage %d" % roundi(float(card.damage) * factor))
	return "     ".join(parts)


func _play() -> void:
	# The card pops in and starts to glow.
	_tile.scale = Vector2.ONE * 0.3
	var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_tile, "scale", Vector2.ONE, 0.3)
	pop.parallel().tween_property(_burst, "strength", 0.4, 0.3)
	await pop.finished
	if _done:
		return
	# It charges up: a faster and faster shake with a rising tone.
	Sfx.play("charge")
	var charge := create_tween()
	for i in 10:
		var lean := 0.02 + 0.01 * i
		charge.tween_property(_tile, "rotation", lean * (1 if i % 2 == 0 else -1), 0.05 - 0.003 * i)
	charge.tween_property(_tile, "rotation", 0.0, 0.03)
	await charge.finished
	if _done:
		return
	_burst_out()
	# The level ticks up one step at a time, then health and damage count up.
	for level in range(_before + 1, _after + 1):
		await get_tree().create_timer(0.18).timeout
		if _done:
			return
		_level.text = "Level %d" % level
		_slam(_level, 1.6)
		Sfx.play("tick")
	var count := create_tween()
	count.tween_method(func(share: float) -> void: _count_stats(share), 0.0, 1.0, 0.6)
	await count.finished
	if not _done:
		_finish()


## The big moment: a white flash, rays at full strength, sparks, LEVEL UP slammed down and a buzz.
func _burst_out() -> void:
	Sfx.play("level_up")
	_buzz(250)
	_flash.color.a = 0.8
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)
	_burst.strength = 1.0
	_sparks.fire(SPARKS)
	_title.text = "LEVEL UP"
	_slam(_title, 2.4)
	_tile.scale = Vector2.ONE * 1.25
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tile, "scale", Vector2.ONE, 0.35)


func _count_stats(share: float) -> void:
	var card: Dictionary = Data.table("cards").cards[_id]
	var per := float(Data.table("battle").level_scaling.per_level)
	var low := pow(1.0 + per, _before - 1)
	var high := pow(1.0 + per, _after - 1)
	var factor := lerpf(low, high, share)
	var parts := []
	if card.has("health"):
		parts.append("Health %d" % roundi(float(card.health) * factor))
	if float(card.get("damage", 0)) > 0.0:
		parts.append("Damage %d" % roundi(float(card.damage) * factor))
	_stats.text = "     ".join(parts)


## Everything as it ends up: the new level, the new numbers, the reward, and how to close.
func _finish() -> void:
	_done = true
	_burst.strength = 1.0
	_tile.scale = Vector2.ONE
	_tile.rotation = 0.0
	_title.text = "MAX LEVEL" if _after >= Progress.max_card_level() else "LEVEL UP"
	_level.text = "Level %d" % _after
	_stats.text = _stats_text(_after)
	_reward.text = "+%d gold" % _gold if _gold > 0 else ""
	_hint.text = "Tap to continue"


func _slam(label: Label, from: float) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * from
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(label, "scale", Vector2.ONE, 0.3)


## The first tap skips to the end, and the next one closes.
func _on_tap(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not _done:
		_finish()
		return
	closed.emit()
	queue_free()


func _buzz(ms: int) -> void:
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(ms)
