extends Ability
## If The Hobb goes too long without devouring anything, it gets hungry,
## which becomes faster bites and extra damage against buildings and towers.


func hungry(sim: BattleSim) -> bool:
	return sim.time - maxf(unit.spawn_time, unit.last_kill_time) >= number("hungry_after")


func tick(sim: BattleSim) -> void:
	if hungry(sim):
		unit.attack_speed *= number("hungry_haste")


func on_hit(sim: BattleSim, victim: Unit, amount: float) -> float:
	return amount * number("building_bonus") if victim.is_building() and hungry(sim) else amount
