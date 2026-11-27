extends Ability
## The evolved Gazers, Unblinking. Their button makes them stop blinking altogether for a few seconds,
## and they shoot that much faster.

var _until := -INF


func tick(sim: BattleSim) -> void:
	if sim.time < _until:
		unit.attack_speed *= number("haste")


func on_activate(sim: BattleSim) -> void:
	_until = sim.time + number("duration")
