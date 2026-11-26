extends Ability
## The Hanged One is tougher with company. While another troop of its own side is close by, it takes less damage.

var has_company := false


func tick(sim: BattleSim) -> void:
	has_company = false
	for other in sim.units:
		if other != unit and other.team == unit.team and other.kind == "troop" and other.alive() and other.pos.distance_to(unit.pos) <= number("radius"):
			has_company = true
			unit.damage_taken *= number("damage_taken")
			return
