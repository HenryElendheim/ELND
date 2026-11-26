extends Ability
## The evolved Swarm, Formation. Its button pulls every surviving member together into a tight group around their middle,
## and they charge faster for a few seconds.

var _charge_until := -INF


func tick(sim: BattleSim) -> void:
	if sim.time < _charge_until:
		unit.move_speed *= number("charge_speed")


func on_activate(sim: BattleSim) -> void:
	_charge_until = sim.time + number("charge_time")
	var members: Array[Unit] = []
	for other in sim.units:
		if other.group == unit.group and other.alive():
			members.append(other)
	# Every member gets the button press, so only the first one gathers the group.
	if members.is_empty() or members[0] != unit:
		return
	var middle := Vector2.ZERO
	for member in members:
		middle += member.pos
	middle /= members.size()
	for i in members.size():
		members[i].pos = middle + Vector2.from_angle(i * 2.4) * 0.3 * sqrt(float(i))
