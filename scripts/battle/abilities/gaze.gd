extends Ability
## The Individuals stare at the troop they are fighting, which fills it with dread and slows its attacks.
## Several Individuals staring at the same troop do not stack, and every few seconds they blink and the dread pauses.


func tick(sim: BattleSim) -> void:
	var every := number("blink_every")
	var blinking := fmod(sim.time - unit.spawn_time, every) >= every - number("blink_time")
	unit.blinking = blinking
	if blinking or unit.target == null or unit.target.is_building():
		return
	unit.target.dread = maxf(unit.target.dread, number("attack_speed_penalty"))
