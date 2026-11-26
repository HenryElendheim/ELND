extends Ability
## The Weight makes everything airborne in the area unbearably heavy. Every enemy flyer inside, hovering buildings included,
## slams to the ground, takes the impact and stays down for a few seconds, which means melee ground troops can hit it.


func tick(sim: BattleSim) -> void:
	for other in sim.units:
		if other.team != unit.team and other.alive() and other.base_flying and not other.is_tower() and other.pos.distance_to(unit.pos) <= unit.radius + other.radius:
			other.grounded_left = maxf(other.grounded_left, number("grounded_time"))
			sim.deal_damage(unit, other, number("impact_damage") * unit.power)
	unit.hp = 0.0
