extends Ability
## The evolved Pardoned One, A Thousand Years. Its button, Feather Storm, fires every feather she has left at once,
## spread over every enemy in range. They all come back and heal her, but she is grounded for a few seconds afterwards.


func on_activate(sim: BattleSim) -> void:
	var wings := sibling("sharp_wings")
	if wings == null:
		return
	var targets := sim.enemies_near(unit, unit.pos, unit.radius + unit.attack_range)
	var left: int = wings.call("feathers_left")
	if targets.is_empty() or left <= 0:
		return
	for i in left:
		sim.deal_damage(unit, targets[i % targets.size()], unit.damage)
		wings.call("launch", sim, unit.damage)
	wings.set("grounded_until", sim.time + number("grounded_time"))
