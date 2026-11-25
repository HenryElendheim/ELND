extends Ability
## Any stun on Kardemosh makes it stop dead and reset, which lasts much longer than a normal stun.
## It adapts, though: the second Halt in the same life only lasts half as long, and after that stuns do nothing.

var _halts := 0


func on_stunned(_sim: BattleSim, _seconds: float) -> float:
	_halts += 1
	if _halts > int(number("max_halts")):
		return 0.0
	return number("stun_time") * pow(number("repeat_factor"), _halts - 1)
