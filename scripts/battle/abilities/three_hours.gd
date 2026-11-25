extends Ability
## The Spacefarer never tires. Every few seconds of non-stop attacking makes it attack a little faster, up to a limit,
## and the bonus is lost once it stops attacking for a moment.

var _streak := 0.0


func tick(sim: BattleSim) -> void:
	var still_attacking := sim.time - unit.last_attack_time <= unit.hit_speed * 1.5
	_streak = _streak + sim.tick if still_attacking else 0.0
	var bonus := minf(floorf(_streak / number("every")) * number("step"), number("max_bonus"))
	unit.attack_speed *= 1.0 + bonus
