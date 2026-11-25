extends Ability
## The Creeler grabs an enemy ground troop that comes within reach and flies it all the way back to that troop's own back line,
## then returns to the towers. While carrying it cannot attack and takes extra damage. It can only carry one troop at a time.

var carrying: Unit = null
var _cooldown := 0.0


func tick(sim: BattleSim) -> void:
	_cooldown = maxf(_cooldown - sim.tick, 0.0)
	if carrying != null and (not carrying.alive() or carrying.carrier != unit):
		carrying = null
	if carrying == null:
		if _cooldown <= 0.0:
			_grab(sim)
		return
	unit.can_attack = false
	unit.damage_taken *= number("carry_damage_taken")
	var drop := Vector2(carrying.pos.x, sim.back_line(carrying.team))
	if unit.pos.distance_to(drop) < 0.2:
		release(sim)
		return
	unit.goal_override = drop
	unit.move_speed = number("carry_speed") / maxf(unit.speed, 0.01)


## Lets go of the carried troop where it is and starts the cooldown. It returns the troop that was let go.
func release(_sim: BattleSim) -> Unit:
	var dropped := carrying
	dropped.carrier = null
	dropped.target = null
	carrying = null
	_cooldown = number("cooldown")
	return dropped


func _grab(sim: BattleSim) -> void:
	for victim in sim.enemies_near(unit, unit.pos, unit.radius + unit.attack_range + 0.5):
		if not victim.flying and not victim.is_building() and victim.carrier == null and victim.deploy_left <= 0.0:
			carrying = victim
			victim.carrier = unit
			victim.target = null
			return
