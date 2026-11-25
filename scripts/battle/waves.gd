class_name Waves
extends RefCounted
## Runs Defense mode. Whenever the field is clear of attackers, a short break follows and then the next wave walks in.
## A wave that takes too long does not hold things up: the next one comes anyway once the wave timer runs out.
## Each wave spends a bigger Ephrocity budget on random troops, and every few waves the attackers gain a level.
## All of these numbers come from defense.json.

var wave := 0

var _break := 0.0
var _wave_age := 0.0
var _rng := RandomNumberGenerator.new()


## The first wave waits one break too, which gives the player a moment to get ready.
func _init(rng_seed: int) -> void:
	_rng.seed = rng_seed
	_break = float(Data.table("defense").break_seconds)


func tick(sim: BattleSim) -> void:
	var rules := Data.table("defense")
	_wave_age += sim.tick
	var overdue := wave > 0 and _wave_age >= float(rules.max_wave_seconds)
	if not overdue:
		for unit in sim.units:
			if unit.team == Unit.Team.ENEMY and not unit.is_tower() and unit.alive():
				return
		_break -= sim.tick
		if _break > 0.0:
			return
	_wave_age = 0.0
	wave += 1
	_break = float(rules.break_seconds)
	_spawn_wave(sim, rules)


func _spawn_wave(sim: BattleSim, rules: Dictionary) -> void:
	var cards: Dictionary = Data.table("cards").cards
	var troops := BattleSim.available_cards().filter(func(id: String) -> bool: return cards[id].get("type") == "troop")
	if troops.is_empty():
		return
	var budget := float(rules.first_wave_budget) + float(rules.budget_per_wave) * (wave - 1)
	var level := 1 + (wave - 1) / int(rules.waves_per_level)
	var lanes: Array = Data.table("battle").arena.bridge_x
	var cheapest := INF
	for id in troops:
		cheapest = minf(cheapest, float(cards[id].cost))
	while budget >= cheapest:
		var id: String = troops[_rng.randi() % troops.size()]
		var cost := float(cards[id].cost)
		if cost > budget:
			continue
		budget -= cost
		var x := float(lanes[_rng.randi() % lanes.size()]) + _rng.randf_range(-1.0, 1.0)
		sim.spawn(id, Unit.Team.ENEMY, Vector2(x, float(rules.spawn_row_from_back) + _rng.randf_range(0.0, 2.0)), level)


## The chest a run earns, which gets better the further the player got.
static func chest_for(reached: int) -> String:
	var chest := "common"
	for step in Data.table("defense").chest_by_wave:
		if reached >= int(step.from_wave):
			chest = step.chest
	return chest
