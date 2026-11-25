class_name BattleSim
extends RefCounted
## The battle itself, with no drawing. It moves forward in fixed ticks, which means pausing,
## slowing down or speeding up only changes how often step() is called and never changes the result.
## Positions are in tiles, with the player at the bottom of an 18 by 32 arena.

var units: Array[Unit] = []
## One hand per team, in the same order as Unit.Team, so hands[Unit.Team.ENEMY] is the enemy's.
var hands: Array[Hand] = []
var bot := Bot.new(randi())
var tick := 1.0 / 30.0
var time := 0.0
## Empty while the match is going. Once it ends it says which team won, or "draw".
var result := ""

var _battle := {}
var _arena := {}
var _next_group := 0


func _init() -> void:
	_battle = Data.table("battle")
	_arena = _battle.arena
	tick = 1.0 / float(_battle.tick_rate)
	_place_towers()
	for team in Unit.Team.size():
		hands.append(Hand.new(starting_deck(), _battle))


## Every card that can be played so far, up to the deck size. Later milestones replace this with the player's own deck.
static func starting_deck() -> Array:
	var battle := Data.table("battle")
	var cards: Dictionary = Data.table("cards").cards
	var deck := []
	for id in cards:
		if cards[id].get("type") in battle.playable_types and deck.size() < int(battle.deck.size):
			deck.append(id)
	return deck


## How many times faster than normal Ephrocity is filling right now, which is 1, 2 or 3.
func ephrocity_rate() -> float:
	var rate := 1.0
	for phase in _battle.ephrocity.phases:
		if time >= float(phase.from_second):
			rate = float(phase.rate)
	return rate


## Checks whether a team may put a troop at a spot. Each side has its own half, and once an enemy
## side tower falls, that lane on the enemy's half opens up too, as deep as the pocket setting allows.
func can_place(team: Unit.Team, at: Vector2) -> bool:
	var length := float(_arena.length_tiles)
	if at.x < 0.0 or at.y < 0.0 or at.x > float(_arena.width_tiles) or at.y > length:
		return false
	# Flipping the enemy's spot means the same rules can be written once from the player's side.
	var y := at.y if team == Unit.Team.PLAYER else length - at.y
	if y > float(_arena.river_bottom):
		return true
	if y < float(_arena.river_top) - float(_battle.pocket_depth_tiles) or y > float(_arena.river_top):
		return false
	var left_lane := at.x < float(_arena.width_tiles) / 2.0
	for unit in units:
		if unit.kind == "side" and unit.team != team and (unit.pos.x < float(_arena.width_tiles) / 2.0) == left_lane:
			return false
	return true


## Plays the card in a hand slot at a spot, paying its Ephrocity cost. It returns false when the spot or the cost is not allowed.
func play(team: Unit.Team, slot: int, at: Vector2) -> bool:
	var hand := hands[team]
	if not can_place(team, at) or not hand.can_afford(slot):
		return false
	spawn(hand.play(slot), team, at)
	return true


## Puts a card on the field. Swarm cards spawn several copies spread around the spot.
func spawn(card_id: String, team: Unit.Team, at: Vector2, level := 1) -> void:
	var card: Dictionary = Data.table("cards").cards[card_id]
	var count := int(card.get("count", 1))
	_next_group += 1
	for i in count:
		var offset := Vector2.ZERO
		if count > 1:
			offset = Vector2.from_angle(TAU * i / count) * float(_battle.swarm_spread_tiles)
		var unit := _make(card_id, card.get("type", "troop"), card.name, team, _clamp_to_arena(at + offset), level)
		unit.deploy_left = float(_battle.deploy_time)
		unit.spawn_time = time + unit.deploy_left
		unit.group = _next_group
		for entry in card.get("abilities", []):
			var ability := Ability.create(entry, unit)
			if ability != null:
				unit.abilities.append(ability)


## Re-reads every unit's numbers, which is how Admin Mode edits reach a match that is already running.
func refresh_stats() -> void:
	_battle = Data.table("battle")
	for unit in units:
		refresh_unit(unit)


func refresh_unit(unit: Unit) -> void:
	unit.apply_stats(_stats_for(unit), _battle)


## How many of a team's towers have been destroyed, which is the crown count for the other team.
func towers_lost(team: Unit.Team) -> int:
	var standing := 0
	for unit in units:
		if unit.is_tower() and unit.team == team:
			standing += 1
	var towers := Data.table("towers")
	return towers.side.positions.size() + towers.main.positions.size() - standing


func seconds_left() -> float:
	return maxf(float(_battle.match.regular_seconds) - time, 0.0)


## Destroying the main tower wins straight away. When time runs out, whoever destroyed more towers wins.
## Overtime and the tiebreaker come in the next milestone, so for now an even count is a draw.
func _check_result() -> void:
	for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
		var main_standing := false
		for unit in units:
			if unit.kind == "main" and unit.team == team:
				main_standing = true
		if not main_standing:
			result = "enemy" if team == Unit.Team.PLAYER else "player"
			return
	if seconds_left() <= 0.0:
		var player_crowns := towers_lost(Unit.Team.ENEMY)
		var enemy_crowns := towers_lost(Unit.Team.PLAYER)
		result = "draw" if player_crowns == enemy_crowns else ("player" if player_crowns > enemy_crowns else "enemy")


func step() -> void:
	if result != "":
		return
	time += tick
	bot.think(self)
	var bars := tick * ephrocity_rate() / float(_battle.ephrocity.seconds_per_bar)
	for hand in hands:
		hand.regenerate(bars)
	for unit in units:
		unit.prev_pos = unit.pos
		unit.reset_effects()
	# Abilities run before anyone moves, so every effect they set is in place for the whole tick.
	for unit in units:
		if unit.alive() and unit.deploy_left <= 0.0:
			for ability in unit.abilities:
				ability.tick(self)
	for unit in units:
		unit.attack_speed *= 1.0 - unit.dread
	for unit in units:
		if unit.alive():
			_update(unit)
	_keep_apart()
	drop_dead()
	_check_result()


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
		unit.carrier = null
		unit.abilities.clear()
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
	if unit.carrier != null:
		if unit.carrier.alive():
			unit.pos = unit.carrier.pos
			return
		unit.carrier = null
	var step_length := unit.speed * unit.move_speed * tick
	if unit.goal_override != null:
		unit.pos = unit.pos.move_toward(unit.goal_override, step_length)
		return

	# A unit keeps hitting what it is already in range of, and otherwise looks for the best target again.
	# A nearby lure such as The Dargalean always wins.
	var lure := _lure_for(unit)
	if lure != null:
		unit.target = lure
	elif not (can_target(unit, unit.target) and _in_range(unit, unit.target)):
		unit.target = _find_target(unit)

	var goal := unit.target
	if goal == null and unit.speed > 0.0:
		goal = _nearest(unit, func(other: Unit) -> bool: return other.is_building(), INF)
	if goal == null:
		return
	if _in_range(unit, goal):
		if goal == unit.target and unit.can_attack and unit.cooldown <= 0.0 and unit.damage > 0.0:
			_hit(unit, goal)
	elif unit.speed > 0.0:
		unit.pos = unit.pos.move_toward(_waypoint(unit, goal.pos), step_length)


## The main tower sleeps until it takes damage or one of its side towers falls.
func _should_wake(tower: Unit) -> bool:
	if tower.hp < tower.max_hp:
		return true
	var side_towers := 0
	for other in units:
		if other.team == tower.team and other.kind == "side":
			side_towers += 1
	return side_towers < Data.table("towers").side.positions.size()


## One attack. Area attackers also hit every enemy they could target close to the main victim.
func _hit(attacker: Unit, victim: Unit) -> void:
	attacker.cooldown = attacker.hit_speed / maxf(attacker.attack_speed, 0.05)
	attacker.last_attack_time = time
	var victims: Array[Unit] = [victim]
	if attacker.area:
		victims = enemies_near(attacker, victim.pos, float(_battle.area_radius_tiles) + victim.radius)
	for each in victims:
		deal_damage(attacker, each, attacker.damage)


## Every bit of damage goes through here, which means abilities, shields and damage taken changes always apply.
func deal_damage(attacker: Unit, victim: Unit, amount: float) -> void:
	if not victim.alive():
		return
	if attacker != null:
		for ability in attacker.abilities:
			amount = ability.on_hit(self, victim, amount)
	for ability in victim.abilities:
		amount = ability.on_hurt(self, attacker, amount)
	amount *= victim.damage_taken
	var absorbed := minf(victim.shield, amount)
	victim.shield -= absorbed
	victim.hp -= amount - absorbed
	victim.flash = 2
	if attacker == null:
		return
	victim.last_attacker = attacker
	if not victim.alive():
		if not victim.is_building():
			attacker.last_kill_time = time
		for ability in attacker.abilities:
			ability.on_kill(self, victim)


## Every living enemy of a unit that the unit could attack and that stands within a distance of a spot.
func enemies_near(unit: Unit, at: Vector2, distance: float) -> Array[Unit]:
	var found: Array[Unit] = []
	for other in units:
		if can_target(unit, other) and at.distance_to(other.pos) - other.radius <= distance:
			found.append(other)
	return found


## Pushes a troop straight away from a spot. Buildings and towers stay where they are.
func knock_back(unit: Unit, from: Vector2, distance: float) -> void:
	if not unit.is_building():
		unit.pos = _clamp_to_arena(unit.pos + (unit.pos - from).normalized() * distance)


## The row at the very back of a team's own side.
func back_line(team: Unit.Team) -> float:
	return float(_arena.length_tiles) - 1.0 if team == Unit.Team.PLAYER else 1.0


## The closest enemy lure whose pull reaches this unit, if the unit is a troop that could attack it.
func _lure_for(unit: Unit) -> Unit:
	if unit.is_building() or unit.targets == "buildings":
		return null
	return _nearest(unit, func(other: Unit) -> bool: return _pulls(other, unit), INF)


func _pulls(lure: Unit, unit: Unit) -> bool:
	return lure.taunt_radius > 0.0 and can_target(unit, lure) and _gap(unit, lure) <= lure.taunt_radius


## Troops pick the closest thing they can attack within sight, and fall back to the nearest building.
## Towers only look within their own range.
func _find_target(unit: Unit) -> Unit:
	match unit.targets:
		"none":
			return null
		"attackers_only":
			return unit.last_attacker if can_target(unit, unit.last_attacker) else null
	var can := func(other: Unit) -> bool: return can_target(unit, other)
	if unit.is_tower():
		return _nearest(unit, can, unit.attack_range)
	var seen := _nearest(unit, can, float(_battle.sight_range_tiles))
	if seen != null:
		return seen
	return _nearest(unit, func(other: Unit) -> bool: return other.is_building() and can_target(unit, other), INF)


## Flying units can only be hit by ranged attackers, other flyers and towers. Building-only troops ignore everything else.
func can_target(unit: Unit, other: Unit) -> bool:
	if other == null or not other.alive() or other.team == unit.team or other.carrier != null:
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
			if a.flying != b.flying or (a.is_building() and b.is_building()) or a.carrier != null or b.carrier != null:
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
		if unit.is_building() or unit.carrier != null:
			continue
		unit.pos = _clamp_to_arena(unit.pos)
		if not unit.flying and _river_side(unit.pos.y) == 0:
			var bridge := _nearest_bridge(unit.pos.x)
			var slack := _bridge_slack(unit)
			unit.pos.x = clampf(unit.pos.x, bridge - slack, bridge + slack)


func _clamp_to_arena(at: Vector2) -> Vector2:
	return at.clamp(Vector2(0.5, 0.5), Vector2(float(_arena.width_tiles) - 0.5, float(_arena.length_tiles) - 0.5))
