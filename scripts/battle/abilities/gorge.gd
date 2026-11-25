extends Ability
## The evolved Hobb, Insatiable, eats anything: a building it bites is devoured outright.
## Its button, Gorge, instantly devours a small enemy troop right in front of it and fills a stomach.


func on_hit(_sim: BattleSim, victim: Unit, amount: float) -> float:
	return victim.hp + victim.shield + 1.0 if victim.kind == "building" else amount


func on_activate(sim: BattleSim) -> void:
	for victim in sim.enemies_near(unit, unit.pos, unit.radius + number("gorge_range")):
		if victim.kind == "troop" and victim.max_hp <= number("gorge_max_health"):
			sim.deal_damage(unit, victim, victim.hp + victim.shield + 1.0)
			return
