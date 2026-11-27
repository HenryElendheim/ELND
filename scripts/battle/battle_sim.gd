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
## Things to do once the current tick is over, such as The Pardoned One being born anew,
## which means nothing is added to the field while the field is being looped over.
var _after_tick: Array[Callable] = []


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
	# The bot gets as many evolutions as the player has in their evolution slot, which keeps the match fair.
	var bot_deck := bot.pick_deck_for(available_cards(), int(_battle.deck.size), Bot.knobs())
	var bot_evolutions := bot_deck.filter(func(id: String) -> bool: return id in Progress.evolvable_cards())
	hands.append(Hand.new(bot_deck, _battle, bot_evolutions.slice(0, hands[0].evolutions.size())))


## Switches the match to real levels from the player's progress: the player's own card levels and tower level,
## and the bot's level from how far along the reputation road the player is.
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
		if is_collectable(cards[id]) and int(cards[id].get("unlock_arena", 1)) <= Progress.arena():
			found.append(id)
	return found


## True for a card that can be collected and played. Tokens, such as the Broodlings The Brood spawns,
## only ever appear on the field and never in chests, decks or the collection.
static func is_collectable(card: Dictionary) -> bool:
	return card.get("type") in Data.table("battle").playable_types and not card.get("token", false)


## The player's saved deck when it is still valid, and otherwise the first cards that are available.
static func starting_deck() -> Array:
	return valid_deck(Save.get_value("deck"))


## A saved deck as it is when it is full and every card in it can be played, and otherwise the first cards that are available.
static func valid_deck(saved: Variant) -> Array:
	var size := int(Data.table("battle").deck.size)
	var available := available_cards()
	var cards: Array = saved if saved is Array else []
	if cards.size() == mini(size, available.size()) and cards.all(func(id: Variant) -> bool: return id in available):
		return cards
	return available.slice(0, size)


## How many times faster than normal Ephrocity is filling right now, which is 1, 2 or 3.
func ephrocity_rate() -> float:
	var rate := 1.0
	for phase in _battle.ephrocity.phases:
		if time >= float(phase.from_second):
			rate = float(phase.rate)
	return rate


## Moves a spot to the centre of the tile it is on, which means everything is placed neatly on the tiles.
static func snap(at: Vector2) -> Vector2:
	return at.floor() + Vector2(0.5, 0.5)


## How far a card's effect reaches from where it is placed, for the range preview while placing.
## A troop shows its attack range, a spell the area it hits, and a building the reach of its ability.
static func effect_radius(card_id: String) -> float:
	var battle := Data.table("battle")
	var card: Dictionary = Data.table("cards").cards[card_id]
	match card.get("type"):
		"spell":
			return float(card.get("radius", 1.0))
		"building":
			var reach := 0.0
			for ability in card.get("abilities", []):
				for key in ["lure_radius", "watch_radius", "radius"]:
					reach = maxf(reach, float(ability.get(key, 0.0)))
			return reach
	var range_tiles := float(card.get("range", battle.melee_range_tiles)) if card.get("attack") == "ranged" else float(battle.melee_range_tiles)
	return range_tiles + float(battle.unit_radius_tiles)


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
	# Nothing can be placed on the tiles a tower stands on.
	for unit in units:
		if unit.is_tower() and absf(at.x - unit.pos.x) < unit.radius and absf(at.y - unit.pos.y) < unit.radius:
			return false
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
	at = snap(at)
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


## Puts a card on the field and hands back the units it made. Swarm cards spawn several copies spread around the spot,
## in rings when there are many of them.
func spawn(card_id: String, team: Unit.Team, at: Vector2, level := 1, evolved := false) -> Array[Unit]:
	var card: Dictionary = Data.table("cards").cards[card_id]
	var count := int(card.get("count", 1))
	_next_group += 1
	events.append({"type": "placed", "pos": at, "team": team})
	var made: Array[Unit] = []
	for i in count:
		var unit := _make(card_id, card.get("type", "troop"), card.name, team, _clamp_to_arena(at + _swarm_offset(i, count)), level)
		unit.deploy_left = 0.0 if unit.is_spell() else float(_battle.deploy_time)
		unit.spawn_time = time + unit.deploy_left
		unit.group = _next_group
		_give_abilities(unit, card, evolved)
		made.append(unit)
		if unit.is_spell():
			events.append({"type": "cast", "pos": unit.pos, "radius": unit.radius, "card": card_id})
			_cast(unit, card)
	return made


## Where one member of a swarm stands around the spot. The first ring holds up to eight, and the rest go in a wider ring.
func _swarm_offset(i: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spread := float(_battle.swarm_spread_tiles)
	var inner := mini(count, 8)
	if i < inner:
		return Vector2.from_angle(TAU * i / inner) * spread
	return Vector2.from_angle(TAU * (i - inner) / (count - inner) + 0.3) * spread * 2.0


func _give_abilities(unit: Unit, card: Dictionary, evolved: bool) -> void:
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


## Makes a weaker copy of a troop next to it, as The Clone does. The copy has the same abilities in their base form,
## with its health and its damage each cut by their own share, and it is never evolved.
func clone_unit(original: Unit, at: Vector2, health_share: float, damage_share: float) -> Unit:
	_next_group += 1
	var copy := Unit.new()
	copy.id = original.id
	copy.kind = original.kind
	copy.label = original.label
	copy.team = original.team
	copy.level = original.level
	copy.strength = health_share
	copy.damage_strength = damage_share
	copy.is_clone = true
	copy.pos = _clamp_to_arena(at)
	copy.prev_pos = copy.pos
	copy.apply_stats(_stats_for(copy), _battle)
	copy.deploy_left = float(_battle.deploy_time)
	copy.spawn_time = time + copy.deploy_left
	copy.group = _next_group
	units.append(copy)
	_give_abilities(copy, Data.table("cards").cards[copy.id], false)
	events.append({"type": "cloned", "pos": copy.pos, "from": original.pos})
	return copy


## The main tower of a team, or null once it has fallen.
func main_tower(team: Unit.Team) -> Unit:
	for unit in units:
		if unit.kind == "main" and unit.team == team and unit.alive():
			return unit
	return null


## True when a spot is over the river, where ground troops cannot stand except on the bridges.
func in_river(at: Vector2) -> bool:
	return _river_side(at.y) == 0


## True when two spots are on the same side of the river, which means a ground troop can go straight between them.
func same_river_side(a: Vector2, b: Vector2) -> bool:
	return _river_side(a.y) == _river_side(b.y)


## A spell's instant hit when it lands. Towers take only part of it when the card says so.
func _cast(spell: Unit, card: Dictionary) -> void:
	if spell.damage <= 0.0:
		if spell.abilities.is_empty():
			spell.hp = 0.0
		return
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


## Re-reads a unit's numbers, including the settings of every ability it has,
## which means an ability number changed in Admin Mode takes effect on troops already on the field.
func refresh_unit(unit: Unit) -> void:
	var stats := _stats_for(unit)
	unit.apply_stats(stats, _battle)
	for ability in unit.abilities:
		if ability == unit.evolution:
			ability.params = stats.get("evolution", {}).merged({"id": ability.params.get("id")})
			continue
		for entry in stats.get("abilities", []):
			if entry.get("id") == ability.params.get("id"):
				ability.params = entry


## How many of a team's towers have been destroyed, which is the core count for the other team.
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
		elif not units.any(func(unit: Unit) -> bool: return unit.kind == "core" and unit.alive()):
			result = "player"
		return
	var player_main := _main_standing(Unit.Team.PLAYER)
	var enemy_main := _main_standing(Unit.Team.ENEMY)
	if not player_main or not enemy_main:
		result = "draw" if player_main == enemy_main else ("player" if player_main else "enemy")
		return
	if phase() == "regular":
		return
	var player_cores := towers_lost(Unit.Team.ENEMY)
	var enemy_cores := towers_lost(Unit.Team.PLAYER)
	if player_cores != enemy_cores:
		result = "player" if player_cores > enemy_cores else "enemy"


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
		# A flyer pulled down by The Weight walks on the ground until it wears off, but never over the river.
		unit.grounded_left = maxf(unit.grounded_left - tick, 0.0)
		unit.flying = unit.base_flying and not (unit.grounded_left > 0.0 and not in_river(unit.pos))
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
	for unit in units:
		unit.last_step = unit.pos - unit.prev_pos
	drop_dead()
	var waiting := _after_tick
	_after_tick = []
	for action in waiting:
		action.call()
	_check_result()


## Runs something once the current tick is over.
func later(action: Callable) -> void:
	_after_tick.append(action)


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
		unit.charmed_by = null
		unit.approach_goal = null
		unit.abilities.clear()
		unit.evolution = null
	units.clear()
	projectiles.clear()
	_after_tick.clear()


## Both sides get their side towers and main tower. In Defense mode the enemy instead has a single core
## where its main tower would be, which hits harder and faster but has a little less health.
func _place_towers() -> void:
	var towers := Data.table("towers")
	for kind in ["side", "main"]:
		for spot in towers[kind].positions:
			for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
				if team == Unit.Team.ENEMY and mode == "defense":
					continue
				_place_tower(kind, team, Vector2(spot[0], spot[1]))
	if mode == "defense":
		for spot in towers.core.positions:
			_place_tower("core", Unit.Team.ENEMY, Vector2(spot[0], spot[1]))


func _place_tower(kind: String, team: Unit.Team, at: Vector2) -> void:
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
	# Forced moves, such as being lured into The Gasket or carried off, go straight to their spot.
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
		goal = _nearest(unit, func(other: Unit) -> bool: return other.is_building() and not other.flying, INF)
	if goal == null:
		return
	if _in_range(unit, goal):
		if goal == unit.target and unit.can_attack and unit.cooldown <= 0.0 and unit.damage > 0.0:
			_hit(unit, goal)
	elif unit.speed > 0.0:
		if unit.approach_goal != goal or time >= unit.approach_until:
			unit.approach_goal = goal
			unit.approach_spot = _approach_spot(unit, goal)
			unit.approach_until = time + float(_battle.steering.rethink_seconds)
		var aim: Vector2 = goal.pos if unit.approach_spot == null else unit.approach_spot
		unit.pos = _steer(unit, _waypoint(unit, aim), step_length, goal)


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
## A victim linked by The Chain passes the same damage on to every other troop in its link.
## Piercing damage, such as The Cloud's lightning, skips shields and goes straight to health.
func deal_damage(attacker: Unit, victim: Unit, amount: float, flash := true, shared := false, pierce := false) -> void:
	if not victim.alive():
		return
	if not shared and victim.link_until > time:
		for other in units:
			if other != victim and other.link_group == victim.link_group and other.link_until > time:
				deal_damage(attacker, other, amount, flash, true, pierce)
	if attacker != null:
		for ability in attacker.abilities:
			amount = ability.on_hit(self, victim, amount)
	for ability in victim.abilities:
		amount = ability.on_hurt(self, attacker, amount)
	amount *= victim.damage_taken
	var absorbed := 0.0 if pierce else minf(victim.shield, amount)
	victim.shield -= absorbed
	victim.hp -= amount - absorbed
	if flash:
		victim.flash = 2
		events.append({"type": "hit", "pos": victim.pos, "amount": amount, "team": victim.team})
	if victim.kind == "troop" and not victim.alive():
		events.append({"type": "death", "pos": victim.pos, "team": victim.team})
	if not victim.alive():
		for ability in victim.abilities:
			ability.on_death(self)
	if victim.is_tower() and not victim.alive():
		events.append({"type": "tower_down", "pos": victim.pos, "team": victim.team})
		# When a main tower falls, the other towers on its side fall with it, which means it is worth every core.
		if victim.kind == "main":
			for other in units:
				if other.is_tower() and other.team == victim.team and other.alive():
					other.hp = 0.0
					events.append({"type": "tower_down", "pos": other.pos, "team": other.team})
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


## Flying units, hovering buildings included, can only be hit by ranged attackers, other flyers and towers.
## Building-only troops ignore everything else, and troops that only eat the living ignore buildings and lifeless troops.
func can_target(unit: Unit, other: Unit) -> bool:
	if other == null or not other.alive() or other.team == unit.team or other.carrier != null or other.is_spell() or other.hidden_left > 0.0:
		return false
	if other.flying and not (unit.flying or unit.ranged):
		return false
	match unit.targets:
		"buildings":
			return other.is_building()
		"living":
			return other.kind == "troop" and other.living
	if other.flying:
		return unit.targets == "air_ground"
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


## A ranged troop charmed by a unit walks right up to it instead of shooting from afar.
func _in_range(unit: Unit, other: Unit) -> bool:
	if other == null:
		return false
	var reach := unit.attack_range
	if unit.charmed_by == other:
		reach = minf(reach, float(_battle.melee_range_tiles))
	return _gap(unit, other) <= reach


## Where a unit should head to attack its goal. Far away, that is simply the goal. Close by, it is a free spot
## on a ring around the goal at attacking distance, starting from the side the unit comes from and trying further round
## each way until one is open. That way attackers spread around a tower or a big troop instead of queuing behind each other.
## Null means there is no need for a spot, so the unit heads for the goal itself.
func _approach_spot(unit: Unit, goal: Unit) -> Variant:
	if not unit.flying and not same_river_side(unit.pos, goal.pos):
		return null
	var reach := unit.attack_range
	if _gap(unit, goal) > reach + float(_battle.steering.approach_tiles):
		return null
	var standoff := goal.radius + unit.radius + reach * 0.8
	var base := (unit.pos - goal.pos).angle() if unit.pos != goal.pos else PI / 2.0
	var turn := float(_battle.steering.approach_turn)
	var tries := int(PI / turn)
	for i in tries * 2 + 1:
		var side := 1.0 if i % 2 == 1 else -1.0
		var spot := goal.pos + Vector2.from_angle(base + side * turn * ceilf(i / 2.0)) * standoff
		if _spot_free(unit, goal, spot):
			return spot
	return null


## A spot is free when no other unit on the same layer already stands there, it is inside the arena,
## and a ground unit would not be standing in the river.
func _spot_free(unit: Unit, goal: Unit, spot: Vector2) -> bool:
	if spot != _clamp_to_arena(spot) or (not unit.flying and in_river(spot)):
		return false
	for other in units:
		if other == unit or other == goal or other.flying != unit.flying or other.is_spell() or other.carrier != null or not other.alive():
			continue
		if other.pos.distance_to(spot) < (unit.radius + other.radius) * 0.9:
			return false
	return true


## Moves a unit one step toward a spot, stepping around anything standing in its way.
## Units walking on ahead in the same direction are not in the way, so groups still move together.
## When something blocks the path, the unit sidesteps to the more open side and keeps that side for a moment.
func _steer(unit: Unit, toward: Vector2, step_length: float, goal: Unit) -> Vector2:
	if unit.pos.distance_to(toward) <= step_length:
		return toward
	var heading := (toward - unit.pos).normalized()
	var blocker := _blocker(unit, heading, step_length, goal)
	if blocker == null:
		if time >= unit.steer_until:
			unit.steer_side = 0.0
		return unit.pos + heading * step_length
	if unit.steer_side == 0.0 or time >= unit.steer_until:
		unit.steer_side = _open_side(unit, heading, blocker, step_length, goal)
		unit.steer_until = time + float(_battle.steering.keep_side_seconds)
	var side := Vector2(-heading.y, heading.x) * unit.steer_side
	var around := (heading * float(_battle.steering.forward_share) + side).normalized()
	return unit.pos + around * step_length


## The closest unit just ahead that would bump into this one, leaving out the goal itself and anything moving on
## in the same direction at a similar pace.
func _blocker(unit: Unit, heading: Vector2, step_length: float, goal: Unit) -> Unit:
	var best: Unit = null
	var best_ahead := INF
	var look := float(_battle.steering.look_ahead_tiles)
	for other in units:
		if other == unit or other == goal or other.flying != unit.flying or other.is_spell() or other.carrier != null or not other.alive():
			continue
		var offset := other.pos - unit.pos
		var ahead := offset.dot(heading)
		var room := unit.radius + other.radius
		if ahead <= 0.0 or ahead > room + look or absf(offset.cross(heading)) >= room * 0.95:
			continue
		if not other.is_building() and other.last_step.dot(heading) >= step_length * 0.6:
			continue
		if ahead < best_ahead:
			best = other
			best_ahead = ahead
	return best


## Picks which way to go around a blocker: away from the side it leans to, unless that side is blocked too
## or would walk into the river. A blocker dead ahead is passed on a side that depends on the unit's group,
## which spreads a crowd out both ways.
func _open_side(unit: Unit, heading: Vector2, blocker: Unit, step_length: float, goal: Unit) -> float:
	var lean := (blocker.pos - unit.pos).cross(heading)
	var first := 1.0 if lean > 0.05 else (-1.0 if lean < -0.05 else (1.0 if unit.group % 2 == 0 else -1.0))
	for side: float in [first, -first]:
		var perpendicular: Vector2 = Vector2(-heading.y, heading.x) * side
		var probe: Vector2 = unit.pos + perpendicular * (unit.radius + blocker.radius)
		if (unit.flying or not in_river(probe)) and probe == _clamp_to_arena(probe) and _blocker(unit, perpendicular, step_length, goal) == null:
			return side
	return first


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
