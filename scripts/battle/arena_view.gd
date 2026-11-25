class_name ArenaView
extends Control
## Draws the battle with placeholder shapes until real pixel art exists.
## It only reads the simulation and never changes it, apart from reporting taps.

signal tapped(tile: Vector2)

const PLAYER_COLOUR := Color("#3D7BFF")
const ENEMY_COLOUR := Color("#FF4D4D")
const GRASS := [Color("#1D2820"), Color("#212D24")]
const RIVER := Color("#1F3B5E")
const BRIDGE := Color("#5A4632")
const SHADOW := Color(0, 0, 0, 0.35)

var sim: BattleSim
## How far between the last tick and the next one the screen is, from zero to one, used to slide units smoothly.
var blend := 0.0
var show_hitboxes := false
var show_ranges := false
var show_targets := false
var show_fps := false
## Short-lived effects made from battle events: damage numbers and impact rings. Each lives well under a second.
var _effects := []
var _shake := 0.0

const EFFECT_TIME := 0.45
const SHAKE_TIME := 0.35

var _tile := 1.0
var _origin := Vector2.ZERO
var _class_colours := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	clip_contents = true


## Turns the battle's new events into effects, sounds and buzzes. Called once per frame by the battle screen.
func take_events(delta: float) -> void:
	for event in sim.events:
		match event.type:
			"hit":
				_effects.append({"pos": event.pos, "amount": event.amount, "age": 0.0})
				Sfx.play("hit")
			"tower_down":
				Sfx.play("tower_down")
				if not Settings.reduced_motion():
					_shake = SHAKE_TIME
				if Settings.get_value("vibration"):
					Input.vibrate_handheld(250)
	sim.events.clear()
	for effect in _effects:
		effect.age += delta
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return effect.age < EFFECT_TIME)
	_shake = maxf(_shake - delta, 0.0)


func _draw() -> void:
	if sim == null:
		return
	if _shake > 0.0:
		var strength := 10.0 * _shake / SHAKE_TIME
		draw_set_transform(Vector2(randf_range(-strength, strength), randf_range(-strength, strength)))
	else:
		draw_set_transform(Vector2.ZERO)
	var arena: Dictionary = Data.table("battle").arena
	var width := float(arena.width_tiles)
	var length := float(arena.length_tiles)
	# Tiles are whole pixels wide, which keeps pixel art sharp once real sprites are added.
	_tile = floorf(minf(size.x / width, size.y / length))
	_origin = ((size - Vector2(width, length) * _tile) / 2.0).floor()
	_class_colours = Data.table("cards").classes

	for y in int(length):
		for x in int(width):
			draw_rect(Rect2(_to_screen(Vector2(x, y)), Vector2.ONE * _tile), GRASS[(x + y) % 2])
	var river_top := float(arena.river_top)
	var river_height := float(arena.river_bottom) - river_top
	draw_rect(Rect2(_to_screen(Vector2(0, river_top)), Vector2(width, river_height) * _tile), RIVER)
	for bridge in arena.bridge_x:
		var half := float(arena.bridge_width) / 2.0
		draw_rect(Rect2(_to_screen(Vector2(bridge - half, river_top)), Vector2(half * 2.0, river_height) * _tile), BRIDGE)

	for unit in sim.units:
		if unit.is_spell():
			_draw_spell(unit)
	for unit in sim.units:
		if unit.link_until > sim.time:
			_draw_links(unit)
	for unit in sim.units:
		if not unit.flying and not unit.is_spell():
			_draw_unit(unit)
	for unit in sim.units:
		if unit.flying:
			_draw_unit(unit)
	for shot in sim.projectiles:
		_draw_projectile(shot)
	for effect in _effects:
		_draw_effect(effect)
	if show_fps:
		draw_string(ThemeDB.fallback_font, Vector2(16, 48), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 36)


func _draw_unit(unit: Unit) -> void:
	var at := _to_screen(unit.prev_pos.lerp(unit.pos, blend))
	var r := unit.radius * _tile
	var team_colour := PLAYER_COLOUR if unit.team == Unit.Team.PLAYER else ENEMY_COLOUR
	var fill := _fill_for(unit)
	if unit.deploy_left > 0.0:
		fill.a = 0.45
	if unit.flash > 0:
		fill = Color.WHITE

	if show_ranges:
		draw_arc(at, (unit.attack_range + unit.radius) * _tile, 0, TAU, 48, Color(team_colour, 0.5), 2.0)
	if show_targets and unit.target != null and unit.target.alive():
		draw_line(at, _to_screen(unit.target.pos), Color(team_colour, 0.7), 3.0)

	if unit.is_building():
		var box := Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(box, fill)
		draw_rect(box, team_colour, false, 4.0)
	else:
		if unit.flying:
			draw_circle(at + Vector2(0, r * 0.6), r * 0.8, SHADOW)
			at.y -= r * 0.6
		if unit.evolved:
			draw_circle(at, r * 1.35, Color("#A33B4C", 0.45))
		if unit.hidden_left > 0.0:
			fill.a = 0.3
		draw_circle(at, r, fill)
		draw_arc(at, r, 0, TAU, 32, team_colour, 4.0)
		_draw_label(at, CardTile.short_name(unit.id), r)

	if show_hitboxes:
		draw_arc(at, r, 0, TAU, 32, Color.YELLOW, 2.0)
	if unit.is_tower() or unit.hp < unit.max_hp:
		_draw_health(at - Vector2(r, r + 14), r * 2.0, unit.hp / unit.max_hp, team_colour)
	if unit.shield > 0.0:
		_draw_health(at - Vector2(r, r + 26), r * 2.0, unit.shield / unit.max_hp, Color("#E8D9C0"))


## Shots are drawn on top of everything so they are never hidden. Every shot has an edge in its team colour.
## An orb is a round shot with a short trail, which is what towers fire. A bolt is a short bright streak, like a blaster.
func _draw_projectile(shot: Projectile) -> void:
	var at := _to_screen(shot.prev_pos.lerp(shot.pos, blend))
	var heading := (shot.target.pos - shot.pos).normalized() if shot.target.pos != shot.pos else Vector2.UP
	var team_colour := PLAYER_COLOUR if shot.team == Unit.Team.PLAYER else ENEMY_COLOUR
	var colour := Color(shot.look.get("colour", "#FFFFFF"))
	var size := float(shot.look.get("size", 0.2)) * _tile
	if shot.look.get("style") == "bolt":
		var tail := at - heading * size
		draw_line(tail, at, team_colour, maxf(size * 0.28, 4.0))
		draw_line(tail, at, colour, maxf(size * 0.16, 2.0))
		draw_circle(at, maxf(size * 0.1, 2.0), Color.WHITE)
		return
	draw_line(at - heading * size * 2.5, at, Color(team_colour, 0.55), maxf(size * 0.9, 3.0))
	draw_circle(at, size, team_colour)
	draw_circle(at, size * 0.65, colour)


## A hit shows a small white ring that grows and fades, and the damage number floats up when damage numbers are on.
## Reduced motion keeps the ring still and only fades it.
func _draw_effect(effect: Dictionary) -> void:
	var share: float = effect.age / EFFECT_TIME
	var at := _to_screen(effect.pos)
	var grow := 0.0 if Settings.reduced_motion() else share
	draw_arc(at, _tile * (0.25 + 0.35 * grow), 0, TAU, 16, Color(1, 1, 1, 0.8 * (1.0 - share)), 3.0)
	if Settings.get_value("damage_numbers"):
		var rise := 0.0 if Settings.reduced_motion() else share * _tile
		var text := str(roundi(effect.amount))
		draw_string(ThemeDB.fallback_font, at + Vector2(-_tile * 0.3, -_tile * 0.6 - rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_tile * 0.5), Color(1, 1, 1, 1.0 - share))


## Spells show as a soft circle over the area they cover, in their class colour.
func _draw_spell(spell: Unit) -> void:
	var at := _to_screen(spell.pos)
	var colour := _fill_for(spell)
	draw_circle(at, spell.radius * _tile, Color(colour, 0.25))
	draw_arc(at, spell.radius * _tile, 0, TAU, 48, Color(colour, 0.8), 3.0)


## Linked troops are joined by a grey chain line to every other troop in the same link.
func _draw_links(unit: Unit) -> void:
	for other in sim.units:
		if other != unit and other.link_group == unit.link_group and other.link_until > sim.time and other.get_instance_id() > unit.get_instance_id():
			draw_line(_to_screen(unit.pos), _to_screen(other.pos), Color("#C8C8D0"), 4.0)


func _draw_label(at: Vector2, text: String, r: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := maxi(int(r * 0.7), 10)
	var short := text.left(5)
	var width := font.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width / 2.0, font_size * 0.35), short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)


func _draw_health(top_left: Vector2, width: float, share: float, colour: Color) -> void:
	draw_rect(Rect2(top_left, Vector2(width, 8)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top_left, Vector2(width * clampf(share, 0.0, 1.0), 8)), colour)


## Troops are filled with their containment class colour, and towers use a plain stone grey.
func _fill_for(unit: Unit) -> Color:
	if unit.is_tower():
		return Color("#6B6B73") if unit.awake else Color("#4A4A50")
	var card: Dictionary = Data.table("cards").cards.get(unit.id, {})
	return Color(_class_colours.get(card.get("class", ""), "#8A8A8A"))


func _to_screen(tile: Vector2) -> Vector2:
	return _origin + tile * _tile


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _tile > 0.0:
		tapped.emit((event.position - _origin) / _tile)
		accept_event()
