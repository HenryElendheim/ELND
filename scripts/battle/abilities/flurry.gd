extends Ability
## When John Arms is provoked after being left alone, it spins, hitting everything around it and knocking enemies back.
## Then it is exhausted for a while, which means it moves slowly and cannot attack. That is the window to kill it.

enum State { CALM, SPINNING, EXHAUSTED }

var state := State.CALM
var _left := 0.0
var _next_spin_hit := 0.0
var _last_hurt := -INF


func on_hurt(sim: BattleSim, _attacker: Unit, amount: float) -> float:
	if state == State.CALM and sim.time - _last_hurt >= number("calm_after"):
		state = State.SPINNING
		_left = number("spin_time")
		_next_spin_hit = 0.0
	_last_hurt = sim.time
	return amount


func tick(sim: BattleSim) -> void:
	if state == State.CALM:
		return
	_left -= sim.tick
	unit.can_attack = false
	if state == State.SPINNING:
		_next_spin_hit -= sim.tick
		if _next_spin_hit <= 0.0:
			_next_spin_hit = number("hit_interval")
			for victim in sim.enemies_near(unit, unit.pos, number("radius")):
				sim.deal_damage(unit, victim, unit.damage)
				sim.knock_back(victim, unit.pos, number("knockback_tiles"))
		if _left <= 0.0:
			state = State.EXHAUSTED
			_left = number("exhausted_time")
	else:
		unit.move_speed *= number("exhausted_speed")
		if _left <= 0.0:
			state = State.CALM
