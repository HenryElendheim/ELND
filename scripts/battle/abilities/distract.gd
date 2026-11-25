extends Ability
## When any one of The Individuals is hit, the whole group turns toward whoever hit it.


func on_hurt(sim: BattleSim, attacker: Unit, amount: float) -> float:
	if attacker == null:
		return amount
	for other in sim.units:
		if other.group == unit.group and other.alive() and sim.can_target(other, attacker):
			other.target = attacker
	return amount
