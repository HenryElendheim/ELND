extends Ability
## After The Spiker erupts, a field of black spikes stays for a few seconds. Anything standing in it is hurt and slowed,
## and the damage grows the longer something stays inside.

var _age := 0.0
var _inside := {}


func tick(sim: BattleSim) -> void:
	_age += sim.tick
	if _age >= number("duration"):
		unit.hp = 0.0
		return
	var still_inside := {}
	for victim in sim.enemies_near(unit, unit.pos, unit.radius):
		var stay: float = _inside.get(victim, 0.0) + sim.tick
		still_inside[victim] = stay
		victim.move_speed *= 1.0 - number("slow")
		victim.slowed = true
		var grow := 1.0 + floorf(stay) * number("growth_per_second")
		sim.deal_damage(unit, victim, number("damage_per_second") * grow * sim.tick, false)
	_inside = still_inside
