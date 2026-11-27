extends Ability
## The Devil In The Forest drains one enemy troop at a time that stands close to it, and heals itself by a share of it.
## The troop being drained barely hurts it back. A troop with its eyes closed, because it is stunned or blinking,
## is safe from the drain, and lifeless troops have nothing to drain. When the victim dies, the next closest one is picked.

var victim: Unit = null
var _boost := 1.0
var _boost_until := -INF


func tick(sim: BattleSim) -> void:
	if not _can_drain(victim):
		victim = _closest(sim, null)
	if victim == null:
		return
	var rate := number("drain_per_second") * unit.power * (_boost if sim.time < _boost_until else 1.0)
	var before := victim.hp + victim.shield
	sim.deal_damage(unit, victim, rate * sim.tick, false)
	var taken := before - maxf(victim.hp, 0.0) - victim.shield
	unit.hp = minf(unit.hp + taken * number("heal_share", 1.0), unit.max_hp)


func on_hurt(_sim: BattleSim, attacker: Unit, amount: float) -> float:
	return amount * number("drained_damage_taken") if attacker != null and attacker == victim else amount


## The evolved Devil's button switches the drain to a new troop and drains it much faster for a few seconds.
func rush(sim: BattleSim, boost: float, seconds: float) -> void:
	var other := _closest(sim, victim)
	if other != null:
		victim = other
	_boost = boost
	_boost_until = sim.time + seconds


func _can_drain(other: Unit) -> bool:
	if other == null or other.team == unit.team or not other.is_living_troop() or other.flying or other.hidden_left > 0.0:
		return false
	if other.eyes_closed():
		return false
	return unit.pos.distance_to(other.pos) - unit.radius - other.radius <= number("range")


func _closest(sim: BattleSim, skip: Unit) -> Unit:
	var best: Unit = null
	for other in sim.units:
		if other != skip and _can_drain(other) and (best == null or unit.pos.distance_to(other.pos) < unit.pos.distance_to(best.pos)):
			best = other
	return best
