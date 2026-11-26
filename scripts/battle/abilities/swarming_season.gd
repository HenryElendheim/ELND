extends Ability
## The evolved Brood, Swarming Season. Its button lets several young out at once.


func on_activate(sim: BattleSim) -> void:
	var brood := sibling("spawner")
	if brood != null:
		brood.call("release", sim, int(number("count")))
