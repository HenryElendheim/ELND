class_name ArenaView
extends Control
## Draws the battle with placeholder shapes until real pixel art exists.
## It only reads the simulation and never changes it, apart from reporting taps.

## A finger going down, moving and lifting on the arena, in tiles.
signal touch_started(tile: Vector2)
signal touch_moved(tile: Vector2)
signal touch_ended(tile: Vector2)

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
## While a card is picked, the tiles it cannot go on are covered in red. While a finger is down, a preview of the card
## and a ring showing how far its effect reaches follow the finger.
var placing_card := ""
var placing_team := Unit.Team.PLAYER
var preview_at: Variant = null

const BLOCKED := Color(0.9, 0.1, 0.1, 0.28)
## Short-lived effects made from battle events: damage numbers and impact rings. Each lives well under a second.
var _effects := []
var _shake := 0.0

const EFFECT_TIME := 0.6
const SHAKE_TIME := 0.35

var _tile := 1.0
var _origin := Vector2.ZERO
## Groups whose level has already been drawn this frame, so a swarm shows it once.
var _level_shown := {}
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
			"placed":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "burst": true, "team": event.team})
			"death":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "puff": true})
			"cast":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "cast": true, "radius": event.radius, "card": event.card})
			"toll":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "toll": true, "radius": event.radius})
			"backlash":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "backlash": true})
			"cloned":
				_effects.append({"pos": event.pos, "from": event.from, "amount": 0.0, "age": 0.0, "cloned": true})
			"lightning":
				_effects.append({"pos": event.pos, "from": event.from, "amount": 0.0, "age": 0.0, "bolt": true})
			"tower_down":
				_effects.append({"pos": event.pos, "amount": 0.0, "age": 0.0, "debris": true, "seed": randi()})
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
	_level_shown.clear()

	for y in int(length):
		for x in int(width):
			draw_rect(Rect2(_to_screen(Vector2(x, y)), Vector2.ONE * _tile), GRASS[(x + y) % 2])
	var river_top := float(arena.river_top)
	var river_height := float(arena.river_bottom) - river_top
	draw_rect(Rect2(_to_screen(Vector2(0, river_top)), Vector2(width, river_height) * _tile), RIVER)
	for bridge in arena.bridge_x:
		var half := float(arena.bridge_width) / 2.0
		draw_rect(Rect2(_to_screen(Vector2(bridge - half, river_top)), Vector2(half * 2.0, river_height) * _tile), BRIDGE)

	if placing_card != "" and not BattleSim.is_spell_card(placing_card):
		_draw_blocked(width, length)
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
	if placing_card != "" and preview_at != null:
		_draw_preview(preview_at)
	if show_fps:
		draw_string(ThemeDB.fallback_font, Vector2(16, 48), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 36)


func _draw_unit(unit: Unit) -> void:
	var motion := not Settings.reduced_motion()
	var at := _to_screen(unit.prev_pos.lerp(unit.pos, blend)) + UnitArt.offset(unit, sim, _tile, motion)
	var r := unit.radius * _tile * UnitArt.size_scale(unit, float(Data.table("battle").deploy_time), motion)
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

	if unit.flying:
		draw_circle(at + Vector2(0, r * 0.6), r * 0.8, SHADOW)
		at.y -= r * 0.6
	if unit.evolved:
		_draw_evolution_glow(at, r, unit.is_building(), motion)
	_draw_status(unit, at, r, motion, false)
	UnitArt.draw_ability_art(self, unit, sim, at, r, _tile, motion, false)
	if unit.is_building():
		var box := Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(box, fill)
		draw_rect(box, team_colour, false, 4.0)
	else:
		if unit.hidden_left > 0.0:
			fill.a = 0.3
		draw_circle(at, r, fill)
		draw_arc(at, r, 0, TAU, 32, team_colour, 4.0)
		_draw_label(at, CardTile.short_name(unit.id), r)
	UnitArt.draw_ability_art(self, unit, sim, at, r, _tile, motion, true)
	_draw_status(unit, at, r, motion, true)

	if show_hitboxes:
		draw_arc(at, r, 0, TAU, 32, Color.YELLOW, 2.0)
	if unit.is_tower() or unit.hp < unit.max_hp:
		_draw_health(at - Vector2(r, r + 14), r * 2.0, unit.hp / unit.max_hp, team_colour)
	var top := r + 14
	if unit.shield > 0.0:
		top = r + 26
		_draw_health(at - Vector2(r, top), r * 2.0, unit.shield / unit.max_hp, Color("#E8D9C0"))
	# Towers all share group zero, so they are told apart by the unit itself.
	var key: Variant = unit.group if unit.group > 0 else unit
	if not _level_shown.has(key):
		_level_shown[key] = true
		_draw_level(unit, at - Vector2(0, top + 4), team_colour)


## The level sits just above the health bar in small text with a dark outline. Towers show theirs a little bigger.
## A swarm shows its level once, over the first member drawn, which keeps a crowd readable.
func _draw_level(unit: Unit, bottom: Vector2, team_colour: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := maxi(int(_tile * (0.55 if unit.is_tower() else 0.4)), 12)
	var text := "Lv %d" % unit.level
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spot := bottom - Vector2(width / 2.0, 0)
	draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(font_size / 5, 3), Color.BLACK)
	draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, team_colour.lightened(0.45))


## Shows what spells and abilities are doing to a unit right now. Behind it: a red flickering aura while enraged,
## a ring of dark spikes while slowed, a dark haze while filled with dread, and a grey ring while chained.
## In front: yellow sparks circling over its head while stunned. Without motion everything stays still but still shows.
func _draw_status(unit: Unit, at: Vector2, r: float, motion: bool, front: bool) -> void:
	var wobble := sin(sim.time * 14.0 + unit.group) if motion else 0.0
	if front:
		if unit.stun_left > 0.0 and unit.alive():
			for i in 3:
				var angle := TAU * i / 3.0 + (sim.time * 5.0 if motion else 0.0)
				draw_circle(at + Vector2(cos(angle) * r * 0.7, -r * 1.1 + sin(angle) * r * 0.2), maxf(r * 0.14, 3.0), Color("#FFE45C"))
		return
	if unit.enraged:
		draw_circle(at, r * (1.3 + 0.08 * wobble), Color(1.0, 0.25, 0.15, 0.35))
	if unit.slowed:
		for i in 8:
			var direction := Vector2.from_angle(TAU * i / 8.0)
			var base := at + direction * r * 1.05
			draw_colored_polygon(PackedVector2Array([base - direction.orthogonal() * r * 0.12, base + direction * r * 0.35, base + direction.orthogonal() * r * 0.12]), Color(0.1, 0.1, 0.12, 0.85))
	if unit.dread > 0.0:
		draw_circle(at, r * 1.2, Color(0.25, 0.1, 0.35, 0.35))
	if unit.link_until > sim.time:
		draw_arc(at, r * 1.15, 0, TAU, 24, Color("#C8C8D0"), 3.0)
	# A flyer pulled down by The Weight has heavy grey bars pressing down on it.
	if unit.grounded_left > 0.0 and unit.base_flying:
		for i in 3:
			var x := (i - 1) * r * 0.6
			draw_line(at + Vector2(x, -r * 1.7), at + Vector2(x, -r * 1.15), Color(0.6, 0.6, 0.65, 0.9), maxf(r * 0.15, 3.0))


## An evolved unit sits in a soft purple glow with a bright purple ring, which pulses gently unless reduced motion is on.
## Buildings get the same glow, shaped as a square.
func _draw_evolution_glow(at: Vector2, r: float, square: bool, motion: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0) if motion else 0.5
	var glow := CardTile.EVOLUTION_GLOW
	for layer in 3:
		var reach := r * (1.25 + 0.2 * layer + 0.1 * pulse)
		var faint := Color(glow, 0.3 - 0.08 * layer)
		if square:
			draw_rect(Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0), faint)
		else:
			draw_circle(at, reach, faint)
	var ring := r * (1.15 + 0.05 * pulse)
	if square:
		draw_rect(Rect2(at - Vector2(ring, ring), Vector2(ring, ring) * 2.0), glow, false, 5.0)
	else:
		draw_arc(at, ring, 0, TAU, 40, glow, 5.0)


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
	var motion := not Settings.reduced_motion()
	# Placing a card sends a ring in its team colour out from the spot.
	if effect.get("burst", false):
		var team_colour := PLAYER_COLOUR if effect.team == Unit.Team.PLAYER else ENEMY_COLOUR
		var reach := share if motion else 0.6
		draw_arc(at, _tile * (0.3 + 1.2 * reach), 0, TAU, 32, Color(team_colour, 0.9 * (1.0 - share)), 5.0)
		return
	# A spell lands with a flash over its whole area and a ring that sweeps out to its edge, in the card's class colour.
	if effect.get("cast", false):
		var colour := Color(_class_colours.get(Data.table("cards").cards[effect.card].get("class", ""), "#FFFFFF"))
		var reach: float = effect.radius * _tile
		draw_circle(at, reach, Color(colour.lightened(0.3), 0.35 * (1.0 - share)))
		draw_arc(at, reach * (0.3 + 0.7 * share if motion else 1.0), 0, TAU, 48, Color(Color.WHITE, 1.0 - share), 5.0)
		return
	# The Toll's ring is a bronze wave that spreads out to the edge of its reach.
	if effect.get("toll", false):
		var reach: float = effect.radius * _tile * (share if motion else 1.0)
		draw_arc(at, maxf(reach, _tile * 0.3), 0, TAU, 48, Color(0.85, 0.6, 0.25, 1.0 - share), 6.0)
		return
	# The Danger Zone's backlash cracks each troop it enraged, with short red lines bursting out.
	if effect.get("backlash", false):
		for i in 6:
			var direction := Vector2.from_angle(TAU * i / 6.0 + 0.4)
			var length := _tile * (0.4 + 0.5 * (share if motion else 0.5))
			draw_line(at + direction * _tile * 0.25, at + direction * length, Color(1, 0.25, 0.2, 1.0 - share), 4.0)
		return
	# A clone appears with a cyan streak from its original and a soft cyan puff.
	if effect.get("cloned", false):
		draw_line(_to_screen(effect.from), at, Color(UnitArt.CYAN, 0.8 * (1.0 - share)), 4.0)
		draw_circle(at, _tile * (0.3 + 0.4 * (share if motion else 0.5)), Color(UnitArt.CYAN, 0.4 * (1.0 - share)))
		return
	# The Cloud's lightning is a jagged pale bolt from the cloud down to the troop, with a flash where it lands.
	if effect.get("bolt", false):
		var top := _to_screen(effect.from)
		var points := PackedVector2Array()
		for i in 7:
			var along := top.lerp(at, i / 6.0)
			var jag := 0.0 if i == 0 or i == 6 else (0.25 if i % 2 == 0 else -0.25) * _tile
			points.append(along + Vector2(jag, 0))
		draw_polyline(points, Color(1, 0.97, 0.7, 1.0 - share), maxf(_tile * 0.12, 3.0))
		draw_circle(at, _tile * 0.5, Color(1, 0.97, 0.7, 0.5 * (1.0 - share)))
		return
	# A fallen tower flashes and throws stone chunks that fly out and fall.
	if effect.get("debris", false):
		draw_circle(at, _tile * 1.6 * (1.0 - share), Color(1, 1, 0.85, 0.6 * (1.0 - share)))
		var rng := RandomNumberGenerator.new()
		rng.seed = effect.seed
		for i in 14:
			var direction := Vector2.from_angle(rng.randf() * TAU)
			var distance := rng.randf_range(0.8, 2.4) * _tile * (share if motion else 0.5)
			var fall := Vector2(0, share * share * _tile * 1.5) if motion else Vector2.ZERO
			var chunk := rng.randf_range(0.12, 0.28) * _tile
			draw_rect(Rect2(at + direction * distance + fall - Vector2.ONE * chunk / 2.0, Vector2.ONE * chunk), Color(0.55, 0.55, 0.6, 1.0 - share))
		return
	# A troop that dies leaves a soft grey puff that spreads and fades.
	if effect.get("puff", false):
		var spread := share if not Settings.reduced_motion() else 0.5
		draw_circle(at, _tile * (0.3 + 0.5 * spread), Color(0.85, 0.85, 0.9, 0.5 * (1.0 - share)))
		return
	var grow := 0.0 if Settings.reduced_motion() else share
	draw_arc(at, _tile * (0.25 + 0.35 * grow), 0, TAU, 16, Color(1, 1, 1, 0.8 * (1.0 - share)), 3.0)
	if Settings.get_value("damage_numbers"):
		var rise := 0.0 if Settings.reduced_motion() else share * _tile
		var text := str(roundi(effect.amount))
		draw_string(ThemeDB.fallback_font, at + Vector2(-_tile * 0.3, -_tile * 0.6 - rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_tile * 0.5), Color(1, 1, 1, 1.0 - share))


func _draw_blocked(width: float, length: float) -> void:
	for y in int(length):
		for x in int(width):
			var spot := Vector2(x + 0.5, y + 0.5)
			if not sim.can_place(placing_team, spot):
				draw_rect(Rect2(_to_screen(Vector2(x, y)), Vector2.ONE * _tile), BLOCKED)


## The tile the card would land on, outlined, with the reach of its effect around it.
## The ring is white where the card can go and red where it cannot.
func _draw_preview(at: Vector2) -> void:
	var allowed := sim.can_place(placing_team, at, BattleSim.is_spell_card(placing_card))
	var colour := Color.WHITE if allowed else Color(1, 0.3, 0.3)
	var corner := _to_screen(at - Vector2(0.5, 0.5))
	draw_rect(Rect2(corner, Vector2.ONE * _tile), Color(colour, 0.35))
	draw_rect(Rect2(corner, Vector2.ONE * _tile), colour, false, 3.0)
	var reach := BattleSim.effect_radius(placing_card)
	if reach > 0.0:
		draw_circle(_to_screen(at), reach * _tile, Color(colour, 0.12))
		draw_arc(_to_screen(at), reach * _tile, 0, TAU, 64, Color(colour, 0.85), 3.0)


## Spells show as a soft circle over the area they cover, in their class colour.
func _draw_spell(spell: Unit) -> void:
	var at := _to_screen(spell.pos)
	var colour := _fill_for(spell)
	draw_circle(at, spell.radius * _tile, Color(colour, 0.25))
	draw_arc(at, spell.radius * _tile, 0, TAU, 48, Color(colour, 0.8), 3.0)
	for ability in spell.abilities:
		match String(ability.params.get("id")):
			"spike_field":
				UnitArt.draw_spikes(self, spell, sim, at, _tile, not Settings.reduced_motion())
			"enrage":
				# The Danger Zone glows an angry red that pulses, or stays steady with reduced motion.
				var pulse := 0.5 + 0.5 * sin(sim.time * 6.0) if not Settings.reduced_motion() else 0.5
				draw_circle(at, spell.radius * _tile, Color(1.0, 0.3, 0.2, 0.12 + 0.1 * pulse))
				draw_arc(at, spell.radius * _tile, 0, TAU, 48, Color(1.0, 0.35, 0.25, 0.9), 4.0)


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
	if unit.kind == "core":
		return Color("#7A2E3A")
	if unit.is_tower():
		return Color("#6B6B73") if unit.awake else Color("#4A4A50")
	var card: Dictionary = Data.table("cards").cards.get(unit.id, {})
	return Color(_class_colours.get(card.get("class", ""), "#8A8A8A"))


func _to_screen(tile: Vector2) -> Vector2:
	return _origin + tile * _tile


func _gui_input(event: InputEvent) -> void:
	if _tile <= 0.0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tile: Vector2 = (event.position - _origin) / _tile
		if event.pressed:
			touch_started.emit(tile)
		else:
			touch_ended.emit(tile)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		touch_moved.emit((event.position - _origin) / _tile)
		accept_event()
