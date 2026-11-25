extends Ability
## The Hobb devours every enemy troop it kills. One full stomach heals it, two also add damage,
## and with all three full it grows bigger, with more health and damage for the rest of its life.

var stomachs := 0


func on_kill(sim: BattleSim, victim: Unit) -> void:
	if victim.is_building() or stomachs >= int(number("stomachs")):
		return
	stomachs += 1
	unit.hp = minf(unit.hp + unit.max_hp * number("heal_share"), unit.max_hp)
	if stomachs == int(number("stomachs")):
		unit.growth = number("full_growth")
		sim.refresh_unit(unit)


func on_hit(_sim: BattleSim, _victim: Unit, amount: float) -> float:
	return amount * (1.0 + number("damage_bonus")) if stomachs >= 2 else amount
