extends Ability
## Mrs. Give & Take. Take: she drains one enemy at a time and stores the life in her pool, and with her pool over half full
## she drains faster. She goes first for whoever is attacking the ally she looks after. Give: she keeps healing the most hurt
## ally in range from her pool, and once the pool is empty she pays with her own health, even if it kills her.
## Lifeless troops can be neither drained nor healed.

var pool := 0.0
var prey: Unit = null
var patient: Unit = null


func tick(sim: BattleSim) -> void:
	var cap := number("pool_max") * unit.power
	patient = _most_hurt(sim)
	prey = _pick_prey(sim)
	if prey != null:
		var rate := number("drain_per_second") * unit.power
		if pool > cap * number("empowered_above"):
			rate *= number("empowered_rate")
		var before := prey.hp + prey.shield
		sim.deal_damage(unit, prey, rate * sim.tick, false)
		pool = minf(pool + before - maxf(prey.hp, 0.0) - prey.shield, cap)
	if patient != null:
		heal(sim, patient, number("heal_per_second") * unit.power * sim.tick)


## Heals an ally from the pool first and then from her own health. It returns how much was healed.
func heal(sim: BattleSim, ally: Unit, amount: float) -> float:
	var need := minf(amount, ally.max_hp - ally.hp)
	if need <= 0.0:
		return 0.0
	var from_pool := minf(need, pool)
	pool -= from_pool
	ally.hp += need
	if need > from_pool:
		sim.deal_damage(null, unit, need - from_pool, false)
	return need


## Allies she can reach, which is anyone living of her own side within her range.
func allies_in_reach(sim: BattleSim) -> Array[Unit]:
	var found: Array[Unit] = []
	for other in sim.units:
		if other != unit and other.team == unit.team and other.is_living_troop() and _reaches(other):
			found.append(other)
	return found


func _reaches(other: Unit) -> bool:
	return unit.pos.distance_to(other.pos) - unit.radius - other.radius <= unit.attack_range


func _most_hurt(sim: BattleSim) -> Unit:
	var best: Unit = null
	for ally in allies_in_reach(sim):
		if ally.hp < ally.max_hp and (best == null or ally.hp / ally.max_hp < best.hp / best.max_hp):
			best = ally
	return best


## Whoever is attacking her patient comes first, then the troop she is already draining, then the closest one.
func _pick_prey(sim: BattleSim) -> Unit:
	if patient != null and patient.last_attacker != null and patient.last_attacker.target == patient and _drainable(sim, patient.last_attacker):
		return patient.last_attacker
	if _drainable(sim, prey):
		return prey
	var best: Unit = null
	for other in sim.units:
		if _drainable(sim, other) and (best == null or unit.pos.distance_to(other.pos) < unit.pos.distance_to(best.pos)):
			best = other
	return best


func _drainable(sim: BattleSim, other: Unit) -> bool:
	return other != null and other.is_living_troop() and sim.can_target(unit, other) and _reaches(other)
