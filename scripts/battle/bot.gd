class_name Bot
extends RefCounted
## A simple opponent that plays the enemy hand. Every so often it looks at the field. If the player has troops on its half,
## it drops a card in front of them to defend. Otherwise it saves up Ephrocity and starts a push in a random lane.
## How long it waits and how much it saves come from the difficulty presets in bot.json.

var enabled := true

var _team := Unit.Team.ENEMY
var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int) -> void:
	_rng.seed = rng_seed


func think(sim: BattleSim) -> void:
	_wait -= sim.tick
	if not enabled or _wait > 0.0:
		return
	var bot := Data.table("bot")
	var preset: Dictionary = bot.presets.get(Settings.get_value("bot_difficulty"), bot.presets[bot.default_difficulty])
	_wait = float(preset.reaction_time) * _rng.randf_range(0.7, 1.3)

	var hand: Hand = sim.hands[_team]
	var choices := []
	for slot in hand.in_hand().size():
		if hand.can_afford(slot):
			choices.append(slot)
	if choices.is_empty():
		return
	var slot: int = choices[_rng.randi() % choices.size()]

	var threat := _closest_threat(sim)
	if threat != null:
		sim.play(_team, slot, _defend_spot(sim, threat, bot.placement))
		return
	# Saving up means waiting until Ephrocity is somewhere between the card's cost and full, and smarter bots wait longer.
	var full := float(Data.table("battle").ephrocity.max)
	var save_up := lerpf(Hand.cost_of(hand.cards[slot]), full, float(preset.ephrocity_smarts))
	if hand.ephrocity >= save_up:
		sim.play(_team, slot, _push_spot(sim, bot.placement))


## The player troop that has come furthest into the bot's half, if any.
func _closest_threat(sim: BattleSim) -> Unit:
	var arena: Dictionary = Data.table("battle").arena
	var best: Unit = null
	for unit in sim.units:
		if unit.team != _team and not unit.is_building() and unit.pos.y < float(arena.river_top):
			if best == null or unit.pos.y < best.pos.y:
				best = unit
	return best


func _defend_spot(sim: BattleSim, threat: Unit, placement: Dictionary) -> Vector2:
	var arena: Dictionary = Data.table("battle").arena
	var spot := threat.pos - Vector2(0, float(placement.defend_offset_tiles))
	spot.y = clampf(spot.y, 1.0, float(arena.river_top) - 0.5)
	return spot if sim.can_place(_team, spot) else Vector2(threat.pos.x, 1.0)


## A spot at the back of a random lane, or sometimes right at the bridge for a faster push.
func _push_spot(_sim: BattleSim, placement: Dictionary) -> Vector2:
	var arena: Dictionary = Data.table("battle").arena
	var lanes: Array = arena.bridge_x
	var x := float(lanes[_rng.randi() % lanes.size()]) + _rng.randf_range(-1.0, 1.0)
	if _rng.randf() < float(placement.push_at_bridge_chance):
		return Vector2(x, float(arena.river_top) - float(placement.bridge_row_from_river))
	return Vector2(x, float(placement.push_row_from_back))
