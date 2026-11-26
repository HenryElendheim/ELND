extends Ability
## The Clone bursts over the area and copies every troop of its own side inside it. Each copy stands next to its original
## with part of its health and damage and the same abilities, in the base form. Buildings are not copied.


func tick(sim: BattleSim) -> void:
	for troop in sim.units.duplicate():
		if troop.team == unit.team and troop.kind == "troop" and troop.alive() and troop.carrier == null and troop.pos.distance_to(unit.pos) <= unit.radius:
			sim.clone_unit(troop, troop.pos + Vector2(troop.radius * 2.0 + 0.1, 0), number("strength"))
	unit.hp = 0.0
