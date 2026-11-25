extends Ability
## The evolved Dargalean's button, Cuddle, makes every enemy near it stop attacking anything for a short while.


func on_activate(sim: BattleSim) -> void:
	for other in sim.units:
		if other.team != unit.team and other.alive() and not other.is_spell() and other.pos.distance_to(unit.pos) <= number("radius"):
			other.calm_left = maxf(other.calm_left, number("duration"))
