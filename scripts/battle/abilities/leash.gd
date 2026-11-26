extends Ability
## The evolved Hanged One, The Rope. Its button, Leash, pulls the nearest troop of its own side right next to it,
## so it is never alone.


func on_activate(sim: BattleSim) -> void:
	var nearest: Unit = null
	for other in sim.units:
		if other == unit or other.team != unit.team or other.kind != "troop" or not other.alive() or other.carrier != null:
			continue
		var distance := other.pos.distance_to(unit.pos)
		if distance <= number("reach") and (nearest == null or distance < nearest.pos.distance_to(unit.pos)):
			nearest = other
	if nearest == null:
		return
	var behind := 1.0 if unit.team == Unit.Team.PLAYER else -1.0
	nearest.pos = unit.pos + Vector2(0, behind * (unit.radius + nearest.radius + 0.1))
