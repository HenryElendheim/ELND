class_name BattleSim
extends RefCounted
## The battle itself, with no drawing. It moves forward in fixed ticks, which means pausing,
## slowing down or speeding up only changes how often step() is called and never changes the result.
## Positions are in tiles, with the player at the bottom of an 18 by 32 arena.

var units: Array[Unit] = []
var projectiles: Array[Projectile] = []
## One hand per team, in the same order as Unit.Team, so hands[Unit.Team.ENEMY] is the enemy's.
var hands: Array[Hand] = []
var bot := Bot.new(randi())
## "battle" is the normal match against the bot. "defense" has no enemy towers and sends waves instead.
var mode := "battle"
var waves: Waves = null
var tick := 1.0 / 30.0
var time := 0.0
## Empty while the match is going. Once it ends it says which team won, or "draw".
var result := ""
## Card levels for the player's cards, and one level for all of the bot's cards. Everything is level 1 until use_progress().
var player_levels := {}
## Things that just happened, such as hits and fallen towers, for the screen to show and play sounds for.
## The screen empties this list after reading it, so the battle itself never depends on it.
var events := []
## Every card the player has played this match, in order, which the stats screen counts.
var played_cards := []
var bot_level := 1

var _battle := {}
var _arena := {}
var _next_group := 0


func _init(match_mode := "battle") -> void:
	mode = match_mode
	if mode == "defense":
		waves = Waves.new(randi())
		bot.enabled = false
	_battle = Data.table("battle")
	_arena = _battle.arena
	tick = 1.0 / float(_battle.tick_rate)
	_place_towers()
	hands.append(Hand.new(starting_deck(), _battle, Progress.deck_evolutions()))
	# The bot gets as many evolutions as the player has switched on, which keeps the match fair.
	var bot_deck := bot.pick_deck_for(available_cards(), int(_battle.deck.size), Bot.knobs())
	var bot_evolutions := bot_deck.filter(func(id: String) -> bool: return id in Progress.evolvable_cards())
	hands.append(Hand.new(bot_deck, _battle, bot_evolutions.slice(0, hands[0].evolutions.size())))


## Switches the match to real levels from the player's progress: the player's own card levels and tower level,
## and the bot's level from how far along the trophy road the player is.
func use_progress() -> void:
	for id in available_cards():
		player_levels[id] = Progress.battle_level(id)
	bot_level = Progress.bot_level()
	var pure := bool(Settings.get_value("pure_balance"))
	for unit in units:
		if unit.is_tower():
			unit.level = 1 if pure else (Progress.tower_level() if unit.team == Unit.Team.PLAYER else mini(bot_level, Progress.tower_level()))
			refresh_unit(unit)


func level_for(team: Unit.Team, card_id: String) -> int:
	return int(player_levels.get(card_id, 1)) if team == Unit.Team.PLAYER else bot_level


## Every card the player has unlocked that can be played, in the order cards.json lists them.
static func available_cards() -> Array:
	var battle := Data.table("battle")
	var cards: Dictionary = Data.table("cards").cards
	var found := []
	for id in cards:
		if cards[id].get("neutralized", false):
			continue
		if cards[id].get("type") in battle.playable_types and int(cards[id].get("unlock_arena", 1)) <= Progress.arena():
			found.append(id)
	return found


## The player's saved deck when it is still valid, and otherwise the first cards that are available.
static func starting_deck() -> Array:
	var size := int(Data.table("battle").deck.size)
	var available := available_cards()
	var saved: Array = Save.get_value("deck") if Save.get_value("deck") is Array else []
	if saved.size() == mini(size, available.size()) and saved.all(func(id: Variant) -> bool: return id in available):
		return saved
	return available.slice(0, size)


## How many times faster than normal Ephrocity is filling right now, which is 1, 2 or 3.
func ephrocity_rate() -> float:
	var rate := 1.0
	for phase in _battle.ephrocity.phases:
		if time >= float(phase.from_second):
			rate = float(phase.rate)
	return rate


## Checks whether a team may put a troop at a spot. Each side has its own half, and once an enemy
## side tower falls, that lane on the enemy's half opens up too, as deep as the pocket setting allows.
func can_place(team: Unit.Team, at: Vector2, spell := false) -> bool:
	var length := float(_arena.length_tiles)
	if at.x < 0.0 or at.y < 0.0 or at.x > float(_arena.width_tiles) or at.y > length:
		return false
	# Flipping the enemy's spot means the same rules can be written once from the player's side.
	var y := at.y if team == Unit.Team.PLAYER else length - at.y
	if spell:
		return true
	if y > float(_arena.river_bottom):
		return true
	if mode == "defense":
		return false
	if y < float(_arena.river_top) - float(_battle.pocket_depth_tiles) or y > float(_arena.river_top):
		return false
	var left_lane := at.x < float(_arena.width_tiles) / 2.0
	for unit in units:
		if unit.kind == "side" and unit.team != team and (unit.pos.x < float(_arena.width_tiles) / 2.0) == left_lane:
			return false
	return true


static func is_spell_card(card_id: String) -> bool:
	return Data.table("cards").cards[card_id].get("type") == "spell"


## Plays the card in a hand slot at a spot, paying its Ephrocity cost. It returns false when the spot or the cost is not allowed.
func play(team: Unit.Team, slot: int, at: Vector2) -> bool:
	var hand := hands[team]
	if not can_place(team, at, is_spell_card(hand.cards[slot])) or not hand.can_afford(slot):
		return false
	var card_id := hand.play(slot)
	if team == Unit.Team.PLAYER:
		played_cards.append(card_id)
	spawn(card_id, team, at, level_for(team, card_id), hand.played_evolved)
	return true


## One button per evolved group of a team, such as all four evolved Individuals from one play.
## Each entry is the first living unit of that group, which stands for the whole group.
func evolution_buttons(team: Unit.Team) -> Array[Unit]:
	var seen := {}
	var found: Array[Unit] = []
	for unit in units:
		if unit.team == team and unit.evolved and unit.evolution != null and unit.alive() and not seen.has(unit.group):
			seen[unit.group] = true
			found.append(unit)
	return found


## What an evolution ability costs: 1 plus 1 for every 500 max health, rounded and kept between 1 and 4.
## Tankier evolutions pay more.
func evolution_cost(unit: Unit) -> int:
	var rule: Dictionary = _battle.evolution.ability_cost
	var cost := roundi(float(rule.base) + unit.max_hp / float(rule.health_per_point))
	return clampi(cost, int(rule.min), int(rule.max))


func evolution_ready(unit: Unit) -> bool:
	return unit.deploy_left <= 0.0 and time >= unit.evolution_ready_at


## Uses an evolved group's ability if it is off cooldown and the team can pay for it. It returns true when it fired.
func activate_evolution(unit: Unit) -> bool:
	var hand := hands[unit.team]
	var cost := float(evolution_cost(unit))
	if not evolution_ready(unit) or (not hand.infinite and hand.ephrocity < cost):
		return false
	if not hand.infinite:
		hand.ephrocity -= cost
	for member in units:
		if member.group == unit.group and member.alive() and member.evolution != null:
			member.evolution.on_activate(self)
			member.evolution_ready_at = time + float(_battle.evolution.cooldown)
	return true


## Puts a card on the field. Swarm cards spawn several copies spread around the spot.
func spawn(card_id: String, team: Unit.Team, at: Vector2, level := 1, evolved := false) -> void:
	var card: Dictionary = Data.table("cards").cards[card_id]
	var count := int(card.get("count", 1))
	_next_group += 1
	for i in count:
		var offset := Vector2.ZERO
		if count > 1:
			offset = Vector2.from_angle(TAU * i / count) * float(_battle.swarm_spread_tiles)
		var unit := _make(card_id, card.get("type", "troop"), card.name, team, _clamp_to_arena(at + offset), level)
		unit.deploy_left = 0.0 if unit.is_spell() else float(_battle.deploy_time)
		unit.spawn_time = time + unit.deploy_left
		unit.group = _next_group
		for entry in card.get("abilities", []):
			var ability := Ability.create(entry, unit)
			if ability != null:
				unit.abilities.append(ability)
		if evolved and card.has("evolution"):
			unit.evolved = true
			var entry: Dictionary = card.evolution.merged({"id": card.evolution.ability})
			unit.evolution = Ability.create(entry, unit)
			if unit.evolution != null:
				unit.abilities.append(unit.evolution)
		for ability in unit.abilities:
			ability.on_spawn(self)
		if unit.is_spell():
			_cast(unit, card)


## A spell's instant hit when it lands. Towers take only part of it when the card says so.
func _cast(spell: Unit, card: Dictionary) -> void:
	for victim in enemies_near(spell, spell.pos, spell.radius):
		var share := float(card.get("tower_damage_share", 1.0)) if victim.is_tower() else 1.0
		deal_damage(spell, victim, spell.damage * share)
	if spell.abilities.is_empty():
		spell.hp = 0.0


## Stuns a unit, letting its abilities change how long it lasts, as Kardemosh's Halt does.
func stun(unit: Unit, seconds: float) -> void:
	for ability in unit.abilities:
		seconds = ability.on_stunned(self, seconds)
	unit.stun_left = maxf(unit.stun_left, seconds)


## How far a troop has come along its path toward the other side, in tiles.
func progress(unit: Unit) -> float:
	return float(_arena.length_tiles) - unit.pos.y if unit.team == Unit.Team.PLAYER else unit.pos.y


## Shifts a troop back toward its own side.
func push_back(unit: Unit, tiles: float) -> void:
	var direction := 1.0 if unit.team == Unit.Team.PLAYER else -1.0
	unit.pos = _clamp_to_arena(unit.pos + Vector2(0, direction * tiles))


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


## Which part of the match is running: "regular", "overtime" or "tiebreaker".
func phase() -> String:
	if mode == "defense":
		return "regular"
	var regular := float(_battle.match.regular_seconds)
	if time < regular:
		return "regular"
	return "overtime" if time < regular + float(_battle.match.overtime_seconds) else "tiebreaker"


## Time left in the current part of the match. The tiebreaker has no clock.
func seconds_left() -> float:
	if mode == "defense":
		return 0.0
	var end := float(_battle.match.regular_seconds)
	if phase() != "regular":
		end += float(_battle.match.overtime_seconds)
	return maxf(end - time, 0.0)


func _main_standing(team: Unit.Team) -> bool:
	for unit in units:
		if unit.kind == "main" and unit.team == team:
			return true
	return false


## The win rules from the design doc, checked after every tick:
## destroying the main tower wins straight away. Once regular time is up, whoever has destroyed more towers wins,
## and during overtime that means the first tower to fall decides it. In the tiebreaker every tower drains,
## so the first tower to fall loses. If both sides lose their main tower at the same moment, it is a draw.
func _check_result() -> void:
	if mode == "defense":
		if not _main_standing(Unit.Team.PLAYER):
			result = "enemy"
		return
	var player_main := _main_standing(Unit.Team.PLAYER)
	var enemy_main := _main_standing(Unit.Team.ENEMY)
	if not player_main or not enemy_main:
		result = "draw" if player_main == enemy_main else ("player" if player_main else "enemy")
		return
	if phase() == "regular":
		return
	var player_crowns := towers_lost(Unit.Team.ENEMY)
	var enemy_crowns := towers_lost(Unit.Team.PLAYER)
	if player_crowns != enemy_crowns:
		result = "player" if player_crowns > enemy_crowns else "enemy"


## Every tower loses the same amount, which means the most damaged tower is the first to fall.
func _drain_towers() -> void:
	var amount := float(_battle.match.tiebreaker_drain_per_second) * tick
	for unit in units:
		if unit.is_tower():
			deal_damage(null, unit, amount, false)


func step() -> void:
	if result != "":
		return
	# Without a screen reading them, events would pile up forever, so old ones are dropped.
	if events.size() > 256:
		events.clear()
	time += tick
	bot.think(self)
	if waves != null:
		waves.tick(self)
	if phase() == "tiebreaker":
		_drain_towers()
	var bars := tick * ephrocity_rate() / float(_battle.ephrocity.seconds_per_bar)
	for hand in hands:
		hand.regenerate(bars)
	for unit in units:
		unit.prev_pos = unit.pos
		unit.reset_effects()
		unit.calm_left = maxf(unit.calm_left - tick, 0.0)
		unit.hidden_left = maxf(unit.hidden_left - tick, 0.0)
		if unit.calm_left > 0.0:
			unit.can_attack = false
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
	_move_projectiles()
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
		unit.evolution = null
	units.clear()
	projectiles.clear()


func _place_towers() -> void:
	var towers := Data.table("towers")
	for kind in ["side", "main"]:
		for spot in towers[kind].positions:
			for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
				if team == Unit.Team.ENEMY and mode == "defense":
					continue
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
	if unit.is_spell():
		return
	if unit.kind == "building":
		# A building's health drains over its lifetime, which means damage to it also shortens how long it stays.
		unit.hp -= unit.max_hp / maxf(float(_stats_for(unit).get("lifetime", 30.0)), 1.0) * tick
	unit.cooldown = maxf(unit.cooldown - tick, 0.0)
	if unit.carrier != null:
		if unit.carrier.alive():
			unit.pos = unit.carrier.pos
			return
		unit.carrier = null
		stun(unit, unit.release_daze)
	if unit.stun_left > 0.0:
		unit.stun_left -= tick
		return
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
	if attacker.ranged and not attacker.area and not attacker.projectile.is_empty():
		_fire(attacker, victim)
		return
	var victims: Array[Unit] = [victim]
	if attacker.area:
		victims = enemies_near(attacker, victim.pos, float(_battle.area_radius_tiles) + victim.radius)
	for each in victims:
		deal_damage(attacker, each, attacker.damage)


func _fire(attacker: Unit, victim: Unit) -> void:
	var shot := Projectile.new()
	shot.attacker = attacker
	shot.target = victim
	shot.team = attacker.team
	shot.damage = attacker.damage
	shot.pos = attacker.pos
	shot.prev_pos = attacker.pos
	shot.look = attacker.projectile
	projectiles.append(shot)


## Moves every shot toward its target and lands the ones that arrive this tick.
func _move_projectiles() -> void:
	var flying: Array[Projectile] = []
	for shot in projectiles:
		shot.prev_pos = shot.pos
		if not shot.target.alive():
			continue
		shot.pos = shot.pos.move_toward(shot.target.pos, float(shot.look.get("speed", 10.0)) * tick)
		if shot.pos.distance_to(shot.target.pos) <= 0.05:
			deal_damage(shot.attacker, shot.target, shot.damage)
		else:
			flying.append(shot)
	projectiles = flying


## Every bit of damage goes through here, which means abilities, shields and damage taken changes always apply.
## Small damage over time passes flash as false, so the white hit flash is kept for real hits.
## A victim linked by Chain passes the same damage on to every other troop in its link.
func deal_damage(attacker: Unit, victim: Unit, amount: float, flash := true, shared := false) -> void:
	if not victim.alive():
		return
	if not shared and victim.link_until > time:
		for other in units:
			if other != victim and other.link_group == victim.link_group and other.link_until > time:
				deal_damage(attacker, other, amount, flash, true)
	if attacker != null:
		for ability in attacker.abilities:
			amount = ability.on_hit(self, victim, amount)
	for ability in victim.abilities:
		amount = ability.on_hurt(self, attacker, amount)
	amount *= victim.damage_taken
	var absorbed := minf(victim.shield, amount)
	victim.shield -= absorbed
	victim.hp -= amount - absorbed
	if flash:
		victim.flash = 2
		events.append({"type": "hit", "pos": victim.pos, "amount": amount, "team": victim.team})
	if victim.is_tower() and not victim.alive():
		events.append({"type": "tower_down", "pos": victim.pos, "team": victim.team})
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
	if other == null or not other.alive() or other.team == unit.team or other.carrier != null or other.is_spell() or other.hidden_left > 0.0:
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
			if a.flying != b.flying or (a.is_building() and b.is_building()) or a.carrier != null or b.carrier != null or a.is_spell() or b.is_spell():
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
		if unit.is_building() or unit.is_spell() or unit.carrier != null:
			continue
		unit.pos = _clamp_to_arena(unit.pos)
		if not unit.flying and _river_side(unit.pos.y) == 0:
			var bridge := _nearest_bridge(unit.pos.x)
			var slack := _bridge_slack(unit)
			unit.pos.x = clampf(unit.pos.x, bridge - slack, bridge + slack)


func _clamp_to_arena(at: Vector2) -> Vector2:
	return at.clamp(Vector2(0.5, 0.5), Vector2(float(_arena.width_tiles) - 0.5, float(_arena.length_tiles) - 0.5))
