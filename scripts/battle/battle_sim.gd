class_name BattleSim
extends RefCounted
## The battle itself, with no drawing. It moves forward in fixed ticks, which means pausing,
## slowing down or speeding up only changes how often step() is called and never changes the result.
## Positions are in tiles, with the player at the bottom of an 18 by 32 arena.

var units: Array[Unit] = []
var tick := 1.0 / 30.0
var time := 0.0

var _battle := {}
var _arena := {}


func _init() -> void:
	_battle = Data.table("battle")
	_arena = _battle.arena
	tick = 1.0 / float(_battle.tick_rate)
	_place_towers()


## Puts a card on the field. Swarm cards spawn several copies spread around the spot.
func spawn(card_id: String, team: Unit.Team, at: Vector2, level := 1) -> void:
	var card: Dictionary = Data.table("cards").cards[card_id]
	var count := int(card.get("count", 1))
	for i in count:
		var offset := Vector2.ZERO
		if count > 1:
			offset = Vector2.from_angle(TAU * i / count) * float(_battle.swarm_spread_tiles)
		var unit := _make(card_id, card.get("type", "troop"), card.name, team, _clamp_to_arena(at + offset), level)
		unit.deploy_left = float(_battle.deploy_time)


## Re-reads every unit's numbers, which is how Admin Mode edits reach a match that is already running.
func refresh_stats() -> void:
	_battle = Data.table("battle")
	for unit in units:
		unit.apply_stats(_stats_for(unit), _battle)


func step() -> void:
	time += tick
	for unit in units:
		unit.prev_pos = unit.pos
	for unit in units:
		if unit.alive():
			_update(unit)
	_keep_apart()
	drop_dead()


## Takes every unit with no health left off the field.
func drop_dead() -> void:
	var survivors: Array[Unit] = []
	for unit in units:
		if unit.alive():
			survivors.append(unit)
	units = survivors


## Drops every link between units, which lets Godot free them when the battle screen closes.
func clear() -> void:
	for unit in units:
		unit.target = null
		unit.last_attacker = null
	units.clear()


func _place_towers() -> void:
	var towers := Data.table("towers")
	for kind in ["side", "main"]:
		for spot in towers[kind].positions:
			for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
				var at := Vector2(spot[0], spot[1])
				if team == Unit.Team.ENEMY:
					at.y = float(_arena.length_tiles) - at.y
				var tower := _make(kind, kind, "", team, at, 1)
				tower.awake = kind != "main"


func _make(id: String, kind: String, label: String, team: Unit.Team, at: Vector2, level: int) -> Unit:
	var unit := Unit.new()
	unit.id = id
	unit.kind = kind
	unit.label = label
	unit.team = team
	unit.level = level
	unit.pos = at
	unit.prev_pos = at
	unit.apply_stats(_stats_for(unit), _battle)
	units.append(unit)
	return unit


func _stats_for(unit: Unit) -> Dictionary:
	if unit.is_tower():
		return Data.table("towers")[unit.kind]
	return Data.table("cards").cards.get(unit.id, {})


func _update(unit: Unit) -> void:
	unit.flash = maxi(unit.flash - 1, 0)
	if unit.deploy_left > 0.0:
		unit.deploy_left -= tick
		return
	if not unit.awake:
		unit.awake = _should_wake(unit)
		if not unit.awake:
			return
	unit.cooldown = maxf(unit.cooldown - tick, 0.0)

	# A unit keeps hitting what it is already in range of, and otherwise looks for the best target again.
	if not (_can_target(unit, unit.target) and _in_range(unit, unit.target)):
		unit.target = _find_target(unit)

	var goal := unit.target
	if goal == null and unit.speed > 0.0:
		goal = _nearest(unit, func(other: Unit) -> bool: return other.is_building(), INF)
	if goal == null:
		return
	if _in_range(unit, goal):
		if goal == unit.target and unit.cooldown <= 0.0 and unit.damage > 0.0:
			_hit(unit, goal)
	elif unit.speed > 0.0:
		unit.pos = unit.pos.move_toward(_waypoint(unit, goal.pos), unit.speed * tick)


## The main tower sleeps until it takes damage or one of its side towers falls.
func _should_wake(tower: Unit) -> bool:
	if tower.hp < tower.max_hp:
		return true
	var side_towers := 0
	for other in units:
		if other.team == tower.team and other.kind == "side":
			side_towers += 1
	return side_towers < Data.table("towers").side.positions.size()


func _hit(attacker: Unit, victim: Unit) -> void:
	victim.hp -= attacker.damage
	victim.flash = 2
	victim.last_attacker = attacker
	attacker.cooldown = attacker.hit_speed


## Troops pick the closest thing they can attack within sight, and fall back to the nearest building.
## Towers only look within their own range.
func _find_target(unit: Unit) -> Unit:
	match unit.targets:
		"none":
			return null
		"attackers_only":
			return unit.last_attacker if _can_target(unit, unit.last_attacker) else null
	var can := func(other: Unit) -> bool: return _can_target(unit, other)
	if unit.is_tower():
		return _nearest(unit, can, unit.attack_range)
	var seen := _nearest(unit, can, float(_battle.sight_range_tiles))
	if seen != null:
		return seen
	return _nearest(unit, func(other: Unit) -> bool: return other.is_building() and _can_target(unit, other), INF)


## Flying units can only be hit by ranged attackers, other flyers and towers. Building-only troops ignore everything else.
func _can_target(unit: Unit, other: Unit) -> bool:
	if other == null or not other.alive() or other.team == unit.team:
		return false
	if unit.targets == "buildings":
		return other.is_building()
	if other.flying:
		return unit.targets == "air_ground" and (unit.ranged or unit.flying)
	return true


func _nearest(unit: Unit, accept: Callable, max_gap: float) -> Unit:
	var best: Unit = null
	var best_gap := max_gap
	for other in units:
		if other.team == unit.team or not other.alive() or not accept.call(other):
			continue
		var gap := _gap(unit, other)
		if gap <= best_gap:
			best = other
			best_gap = gap
	return best


## The space between the edges of two units, which is what attack range is measured against.
func _gap(a: Unit, b: Unit) -> float:
	return a.pos.distance_to(b.pos) - a.radius - b.radius


func _in_range(unit: Unit, other: Unit) -> bool:
	return other != null and _gap(unit, other) <= unit.attack_range


## Ground troops cannot cross the river, so they head for the nearest bridge first, walk over it, then go straight for the goal.
func _waypoint(unit: Unit, goal: Vector2) -> Vector2:
	if unit.flying or _river_side(unit.pos.y) == _river_side(goal.y):
		return goal
	var bridge := _nearest_bridge(unit.pos.x)
	var heading_up := goal.y < unit.pos.y
	var top := float(_arena.river_top) - 0.5
	var bottom := float(_arena.river_bottom) + 0.5
	if absf(unit.pos.x - bridge) > _bridge_slack(unit):
		return Vector2(bridge, bottom if heading_up else top)
	return Vector2(bridge, top if heading_up else bottom)


## Returns minus one above the river, one below it, and zero inside it.
func _river_side(y: float) -> int:
	if y < float(_arena.river_top):
		return -1
	if y > float(_arena.river_bottom):
		return 1
	return 0


func _nearest_bridge(x: float) -> float:
	var best := INF
	for bridge in _arena.bridge_x:
		if absf(bridge - x) < absf(best - x):
			best = bridge
	return best


func _bridge_slack(unit: Unit) -> float:
	return maxf(float(_arena.bridge_width) / 2.0 - unit.radius, 0.1)


## Pushes overlapping units apart. Buildings never move, and ground troops are kept out of the water and inside the arena.
func _keep_apart() -> void:
	for i in units.size():
		var a := units[i]
		for j in range(i + 1, units.size()):
			var b := units[j]
			if a.flying != b.flying or (a.is_building() and b.is_building()):
				continue
			var overlap := a.radius + b.radius - a.pos.distance_to(b.pos)
			if overlap <= 0.0:
				continue
			var push := (b.pos - a.pos).normalized() if a.pos != b.pos else Vector2.RIGHT
			if a.is_building():
				b.pos += push * overlap
			elif b.is_building():
				a.pos -= push * overlap
			else:
				a.pos -= push * overlap / 2.0
				b.pos += push * overlap / 2.0
	for unit in units:
		if unit.is_building():
			continue
		unit.pos = _clamp_to_arena(unit.pos)
		if not unit.flying and _river_side(unit.pos.y) == 0:
			var bridge := _nearest_bridge(unit.pos.x)
			var slack := _bridge_slack(unit)
			unit.pos.x = clampf(unit.pos.x, bridge - slack, bridge + slack)


func _clamp_to_arena(at: Vector2) -> Vector2:
	return at.clamp(Vector2(0.5, 0.5), Vector2(float(_arena.width_tiles) - 0.5, float(_arena.length_tiles) - 0.5))
