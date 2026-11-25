extends Ability
## The evolved Creeler's button, Drop, lets go of the carried troop early, from height. The fall hurts that troop
## and everything around where it lands.


func on_activate(sim: BattleSim) -> void:
	var snatch := sibling("snatch")
	if snatch == null or snatch.get("carrying") == null:
		return
	var victim: Unit = snatch.call("release", sim)
	for other in sim.units:
		if other.team == victim.team and other.alive() and not other.is_spell() and other.pos.distance_to(victim.pos) <= number("drop_radius"):
			sim.deal_damage(unit, other, number("drop_damage"))
