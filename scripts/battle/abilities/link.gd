extends Ability
## The Chain links up to a few enemy troops in the target area. For a while, damage dealt to any one of them
## is dealt in full to every other linked troop as well.


func tick(sim: BattleSim) -> void:
	var linked := 0
	for victim in sim.enemies_near(unit, unit.pos, unit.radius):
		if linked >= int(number("max_targets")) or victim.is_building():
			continue
		victim.link_group = unit.group
		victim.link_until = sim.time + number("duration")
		linked += 1
	unit.hp = 0.0
