extends Ability
## The Devil In The Forest is too charming to shoot from afar. The closest enemy ranged troops that can see it,
## two at a time, feel the urge to walk over and say hi, which means they lose their range advantage.
## Towers, buildings and troops with their eyes closed are not fooled.


func tick(sim: BattleSim) -> void:
	var charmed: Array[Unit] = []
	for other in sim.units:
		if other.team != unit.team and other.kind == "troop" and other.ranged and other.alive() and not other.eyes_closed() and other.carrier == null:
			if unit.pos.distance_to(other.pos) <= number("sight"):
				charmed.append(other)
	charmed.sort_custom(func(a: Unit, b: Unit) -> bool: return unit.pos.distance_to(a.pos) < unit.pos.distance_to(b.pos))
	for other in charmed.slice(0, int(number("max_charmed"))):
		if other.charmed_by == null:
			other.charmed_by = unit
