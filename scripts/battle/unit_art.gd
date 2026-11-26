class_name UnitArt
## Placeholder animations for units on the field, drawn on top of their basic shapes until real pixel art exists.
## Movement such as bobbing, lunging and spinning only happens when reduced motion is off,
## while still markers such as stomach dots, eyes and lids show either way so the information is never lost.
## All timing uses the battle clock, which means animations pause and slow down together with the battle.

const LUNGE_TIME := 0.15
const PINK := Color("#FF8FC8")
const CYAN := Color("#6FF2FF")


## How far a unit is drawn away from its real spot this frame: a small bob while walking,
## a lunge toward the target right after a melee hit, and a recoil after a ranged shot.
static func offset(unit: Unit, sim: BattleSim, tile: float, motion: bool) -> Vector2:
	if not motion or unit.is_building():
		return Vector2.ZERO
	var shift := Vector2.ZERO
	if unit.pos.distance_squared_to(unit.prev_pos) > 0.000001:
		shift.y -= absf(sin(sim.time * 10.0 + unit.group)) * tile * 0.08
	var since := sim.time - unit.last_attack_time
	if since < LUNGE_TIME and unit.target != null:
		var toward := (unit.target.pos - unit.pos).normalized()
		var push := (1.0 - since / LUNGE_TIME) * tile * (0.2 if not unit.ranged else -0.1)
		shift += toward * push
	return shift


## Units pop up from a little smaller while they deploy.
static func size_scale(unit: Unit, deploy_time: float, motion: bool) -> float:
	if not motion or unit.deploy_left <= 0.0 or deploy_time <= 0.0:
		return 1.0
	return lerpf(1.0, 0.6, unit.deploy_left / deploy_time)


## Extra drawing for each ability a unit has, under the body (behind) or over it (front).
static func draw_ability_art(canvas: CanvasItem, unit: Unit, sim: BattleSim, at: Vector2, r: float, tile: float, motion: bool, front: bool) -> void:
	for ability in unit.abilities:
		match String(ability.params.get("id", "")):
			"flurry":
				_flurry(canvas, unit, ability, sim, at, r, tile, motion, front)
			"three_stomachs":
				if front:
					_stomachs(canvas, int(ability.get("stomachs")), int(ability.number("stomachs")), at, r)
			"munchies":
				if not front and ability.call("hungry", sim):
					var pulse := 0.5 + 0.5 * sin(sim.time * 8.0) if motion else 1.0
					canvas.draw_arc(at, r * 1.15, 0, TAU, 32, Color(1, 0.2, 0.2, 0.5 + 0.4 * pulse), 4.0)
			"gaze":
				if front:
					var every := ability.number("blink_every")
					var blinking := fmod(sim.time - unit.spawn_time, every) >= every - ability.number("blink_time")
					_eyes(canvas, at, r, blinking)
			"snatch":
				if front and ability.get("carrying") != null:
					_cage(canvas, at, r)
			"comfortable_end":
				if front:
					_coffin(canvas, ability, at, r)
			"quiet_revision":
				var since: float = sim.time - float(ability.get("last_revision"))
				if not front and since < 0.5:
					var grow := since / 0.5 if motion else 0.5
					canvas.draw_arc(at, r + grow * ability.number("watch_radius") * tile, 0, TAU, 48, Color(1, 1, 1, 0.6 * (1.0 - grow)), 3.0)
			"irresistible":
				if not front:
					var pulse := 0.5 + 0.5 * sin(sim.time * 3.0) if motion else 0.5
					canvas.draw_arc(at, ability.number("radius") * tile, 0, TAU, 64, Color(PINK, 0.15 + 0.2 * pulse), 3.0)
			"three_hours":
				if not front and unit.attack_speed > 1.05:
					canvas.draw_circle(at, r * 1.3, Color(CYAN, clampf((unit.attack_speed - 1.0) * 0.8, 0.1, 0.45)))


## John Arms' Flurry. Spinning: a whirl of arms around him and a glow over the area he hits.
## Exhausted: drooping arms, a darker body and three dots above him. Calm: arms resting at his sides.
static func _flurry(canvas: CanvasItem, unit: Unit, ability: Ability, sim: BattleSim, at: Vector2, r: float, tile: float, motion: bool, front: bool) -> void:
	var state: int = ability.get("state")
	var arm_colour := Color("#E8C547")
	if state == 1:
		if not front:
			var area := ability.number("radius") * tile + r
			canvas.draw_circle(at, area, Color(arm_colour, 0.12))
			canvas.draw_arc(at, area, 0, TAU, 48, Color(arm_colour, 0.5), 3.0)
			return
		var spin := sim.time * 14.0 if motion else 0.0
		for i in 8:
			var angle := spin + TAU * i / 8.0
			var tip := at + Vector2.from_angle(angle) * r * 1.7
			canvas.draw_line(at + Vector2.from_angle(angle) * r * 0.8, tip, arm_colour, maxf(r * 0.18, 3.0))
			canvas.draw_circle(tip, maxf(r * 0.12, 2.0), arm_colour.lightened(0.3))
		if motion:
			for i in 3:
				var start := spin * 1.0 + TAU * i / 3.0
				canvas.draw_arc(at, r * 1.95, start, start + 0.9, 12, Color(1, 1, 1, 0.45), 3.0)
	elif state == 2:
		if not front:
			canvas.draw_circle(at, r, Color(0, 0, 0, 0.35))
			return
		var sway := sin(sim.time * 2.0) * 0.15 if motion else 0.0
		for side in [-1.0, 1.0]:
			var root := at + Vector2(side * r * 0.85, 0)
			canvas.draw_line(root, root + Vector2(side * r * 0.25, r * 0.8).rotated(sway), arm_colour.darkened(0.3), maxf(r * 0.16, 3.0))
		for i in 3:
			canvas.draw_circle(at + Vector2((i - 1) * r * 0.35, -r * 1.45), maxf(r * 0.09, 2.0), Color.WHITE)
	elif front:
		for side in [-1.0, 1.0]:
			var root := at + Vector2(side * r * 0.9, -r * 0.1)
			canvas.draw_line(root, root + Vector2(side * r * 0.2, r * 0.55), arm_colour, maxf(r * 0.15, 3.0))


## The Hobb's stomachs as three small dots under it, filled ones in red.
static func _stomachs(canvas: CanvasItem, full: int, total: int, at: Vector2, r: float) -> void:
	for i in total:
		var spot := at + Vector2((i - (total - 1) / 2.0) * r * 0.45, r * 1.25)
		canvas.draw_circle(spot, maxf(r * 0.13, 2.5), Color("#D64545") if i < full else Color(0, 0, 0, 0.5))
		canvas.draw_arc(spot, maxf(r * 0.13, 2.5), 0, TAU, 12, Color.WHITE, 1.5)


## Two staring eyes, which close into lines while The Individuals blink.
static func _eyes(canvas: CanvasItem, at: Vector2, r: float, blinking: bool) -> void:
	for side in [-1.0, 1.0]:
		var eye := at + Vector2(side * r * 0.35, -r * 0.3)
		if blinking:
			canvas.draw_line(eye - Vector2(r * 0.18, 0), eye + Vector2(r * 0.18, 0), Color.BLACK, maxf(r * 0.08, 2.0))
		else:
			canvas.draw_circle(eye, r * 0.2, Color.WHITE)
			canvas.draw_circle(eye, r * 0.09, Color.BLACK)


## The Creeler's ribcage closed around the troop it carries.
static func _cage(canvas: CanvasItem, at: Vector2, r: float) -> void:
	for i in 5:
		var x := (i - 2) * r * 0.35
		canvas.draw_line(at + Vector2(x, -r * 0.2), at + Vector2(x * 0.6, r * 1.3), Color("#E8E0D0"), maxf(r * 0.08, 2.0))
	canvas.draw_arc(at + Vector2(0, r * 1.2), r * 0.7, 0.2, PI - 0.2, 12, Color("#E8E0D0"), maxf(r * 0.08, 2.0))


## The Gasket: a closed lid while a troop lies inside.
static func _coffin(canvas: CanvasItem, ability: Ability, at: Vector2, r: float) -> void:
	if ability.get("_guest") == null or not ability.get("_trapped"):
		return
	var lid := Rect2(at - Vector2(r * 0.8, r * 0.8), Vector2(r * 1.6, r * 1.6))
	canvas.draw_rect(lid, Color("#3A2A20"))
	canvas.draw_line(lid.position + Vector2(r * 0.8, r * 0.3), lid.position + Vector2(r * 0.8, r * 1.3), Color("#C8A060"), 4.0)
	canvas.draw_line(lid.position + Vector2(r * 0.45, r * 0.65), lid.position + Vector2(r * 1.15, r * 0.65), Color("#C8A060"), 4.0)


## The Spiker's field: black spikes that rise over the first second, spread over the area.
static func draw_spikes(canvas: CanvasItem, spell: Unit, sim: BattleSim, at: Vector2, tile: float, motion: bool) -> void:
	var age := clampf(sim.time - spell.spawn_time, 0.0, 1.0) if motion else 1.0
	var spots := 12
	for i in spots:
		var angle := TAU * i / spots + float(spell.group)
		var spot := at + Vector2.from_angle(angle) * spell.radius * tile * (0.25 + 0.65 * float((i * 7) % spots) / spots)
		var height := tile * 0.5 * age
		var half := tile * 0.13
		canvas.draw_colored_polygon(PackedVector2Array([spot + Vector2(-half, 0), spot + Vector2(half, 0), spot + Vector2(0, -height)]), Color("#111114"))
