extends Ability
## The Cloud strikes lightning straight down at an enemy troop below it, then waits a random few seconds before the next strike.
## The strike goes through shields such as Kardemosh's skin and stuns the troop for a moment.
## Anything that hurts The Cloud irritates it, which means its next strike goes to that attacker if it is close enough.

## When and where the last strike landed, so the screen can draw the bolt.
var last_strike := -INF
var last_spot := Vector2.ZERO
var _wait := 0.0
var _irritated: Unit = null
var _rng := RandomNumberGenerator.new()


func on_spawn(_sim: BattleSim) -> void:
	_rng.seed = unit.group * 7919 + 17


func tick(sim: BattleSim) -> void:
	_wait -= sim.tick
	if _wait <= 0.0:
		strike_now(sim)


func on_hurt(_sim: BattleSim, attacker: Unit, amount: float) -> float:
	if attacker != null and attacker.kind == "troop":
		_irritated = attacker
	return amount


## Strikes straight away if anything is below. Nothing below means it stays ready and strikes the moment something comes.
func strike_now(sim: BattleSim) -> void:
	var victim: Unit = _irritated if _below(_irritated) else _closest(sim)
	if victim == null:
		return
	sim.deal_damage(unit, victim, unit.damage, true, false, true)
	sim.stun(victim, number("stun"))
	last_strike = sim.time
	last_spot = victim.pos
	_irritated = null
	_wait = _rng.randf_range(number("min_wait"), number("max_wait"))
	sim.events.append({"type": "lightning", "pos": victim.pos, "from": unit.pos})


func _below(other: Unit) -> bool:
	if other == null or other.team == unit.team or other.kind != "troop" or not other.alive() or other.carrier != null or other.hidden_left > 0.0:
		return false
	return unit.pos.distance_to(other.pos) <= number("radius")


func _closest(sim: BattleSim) -> Unit:
	var best: Unit = null
	for other in sim.units:
		if _below(other) and (best == null or unit.pos.distance_to(other.pos) < unit.pos.distance_to(best.pos)):
			best = other
	return best
