extends Ability
## Kardemosh wears the skin of the troops it kills as a shield on top of its health, and the skin slowly rots away.
## With little skin it hunts troops and moves faster. Once it is dressed in enough skin it calms down and walks for buildings.


func on_kill(_sim: BattleSim, victim: Unit) -> void:
	if not victim.is_building():
		unit.shield = minf(unit.shield + number("skin_per_kill"), number("max_skin"))


func tick(sim: BattleSim) -> void:
	unit.shield = maxf(unit.shield - number("decay_per_second") * sim.tick, 0.0)
	if unit.shield > number("calm_above"):
		unit.targets = "buildings"
	else:
		unit.targets = "ground"
		unit.move_speed *= number("hunting_speed")
