extends Ability
## The evolved Kardemosh, God of Flesh, enters already wearing some skin.
## Its button, Flay, rips the skin off the nearest enemy troop for big damage and wears it straight away.


func on_spawn(_sim: BattleSim) -> void:
	unit.shield = number("starting_skin")


func on_activate(sim: BattleSim) -> void:
	var victims := sim.enemies_near(unit, unit.pos, unit.radius + number("flay_range"))
	var nearest: Unit = null
	for victim in victims:
		if victim.kind == "troop" and (nearest == null or unit.pos.distance_to(victim.pos) < unit.pos.distance_to(nearest.pos)):
			nearest = victim
	if nearest == null:
		return
	var taken := minf(number("flay_damage"), nearest.hp + nearest.shield)
	sim.deal_damage(unit, nearest, number("flay_damage"))
	var skin := sibling("skin_stealer")
	var cap := skin.number("max_skin") if skin != null else taken
	unit.shield = minf(unit.shield + taken, cap)
