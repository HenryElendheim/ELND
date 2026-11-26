class_name LevelUp
extends Celebration
## The celebration when a card levels up with wild cards.
## The card pops in and charges up with a shake and a rising tone. Then it bursts: a white flash, spinning rays
## in its rarity colour, sparks flying out, LEVEL UP slammed down, the level number ticking up, and health and damage
## counting up to their new values, with the gold it earned underneath.

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
var _tile: CardTile
var _sparks := Sparks.new()
var _level: Label
var _stats: Label
var _reward: Label


func _init(id: String, before: int, after: int, gold: int) -> void:
	super()
	_id = id
	_before = before
	_after = after
	_gold = gold


func build() -> void:
	var colour := Color(Data.table("chests").colours.get(Progress.card_rarity(_id), "#FFFFFF"))
	title.add_theme_color_override("font_color", colour.lightened(0.3))
	_sparks.custom_minimum_size = burst.custom_minimum_size
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.colour = colour
	holder.add_child(_sparks)
	burst.colour = colour
	burst.rays = 16
	_tile = CardTile.new(_id)
	_tile.custom_minimum_size = TILE_SIZE
	_tile.pivot_offset = TILE_SIZE / 2.0
	_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_tile)
	_level = line("Level %d" % _before, "StatNumber")
	_stats = line(_stats_text(_before), "HeadingLabel")
	_reward = line("", "")


## Health and damage at a level, the same way battles work them out.
func _stats_text(level: int) -> String:
	return _stats_between(level, level, 1.0)


func _stats_between(low_level: int, high_level: int, share: float) -> String:
	var card: Dictionary = Data.table("cards").cards[_id]
	var per := float(Data.table("battle").level_scaling.per_level)
	var factor := lerpf(pow(1.0 + per, low_level - 1), pow(1.0 + per, high_level - 1), share)
	var parts := []
	if card.has("health"):
		parts.append("Health %d" % roundi(float(card.health) * factor))
	if float(card.get("damage", 0)) > 0.0:
		parts.append("Damage %d" % roundi(float(card.damage) * factor))
	return "     ".join(parts)


func play() -> void:
	# The card pops in and starts to glow.
	_tile.scale = Vector2.ONE * 0.3
	var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_tile, "scale", Vector2.ONE, 0.3)
	pop.parallel().tween_property(burst, "strength", 0.4, 0.3)
	await pop.finished
	if done:
		return
	# It charges up: a faster and faster shake with a rising tone.
	Sfx.play("charge")
	var charge := create_tween()
	for i in 10:
		var lean := 0.02 + 0.01 * i
		charge.tween_property(_tile, "rotation", lean * (1 if i % 2 == 0 else -1), 0.05 - 0.003 * i)
	charge.tween_property(_tile, "rotation", 0.0, 0.03)
	await charge.finished
	if done:
		return
	_burst_out()
	# The level ticks up one step at a time, then health and damage count up.
	for level in range(_before + 1, _after + 1):
		await get_tree().create_timer(0.18).timeout
		if done:
			return
		_level.text = "Level %d" % level
		slam(_level, 1.6)
		Sfx.play("tick")
	var count := create_tween()
	count.tween_method(func(share: float) -> void: _stats.text = _stats_between(_before, _after, share), 0.0, 1.0, 0.6)
	await count.finished
	if not done:
		_end()


## The big moment: a white flash, rays at full strength, sparks, LEVEL UP slammed down and a buzz.
func _burst_out() -> void:
	Sfx.play("level_up")
	buzz(250)
	flash_screen()
	burst.strength = 1.0
	_sparks.fire(SPARKS)
	title.text = "LEVEL UP"
	slam(title, 2.4)
	_tile.scale = Vector2.ONE * 1.25
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tile, "scale", Vector2.ONE, 0.35)


## Everything as it ends up: the new level, the new numbers and the reward.
func finish() -> void:
	_tile.scale = Vector2.ONE
	_tile.rotation = 0.0
	title.text = "MAX LEVEL" if _after >= Progress.max_card_level() else "LEVEL UP"
	_level.text = "Level %d" % _after
	_stats.text = _stats_text(_after)
	_reward.text = "+%d gold" % _gold if _gold > 0 else ""
