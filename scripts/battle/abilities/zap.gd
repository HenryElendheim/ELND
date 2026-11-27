extends Ability
## The Zap stuns everything it hits for a moment, towers included, then fizzles out.
## The damage itself lands when the spell is cast, like any spell. Its stun sets off Kardemosh's Halt
## and closes eyes against The Devil In The Forest.


func tick(sim: BattleSim) -> void:
	var hits := []
	for victim in sim.enemies_near(unit, unit.pos, unit.radius):
		sim.stun(victim, number("stun"))
		hits.append(victim.pos)
	sim.events.append({"type": "zap", "pos": unit.pos, "radius": unit.radius, "hits": hits})
	unit.hp = 0.0
