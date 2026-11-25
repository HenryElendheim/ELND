extends Ability
## The evolved Individuals' button, Flatten, turns them flat for a short while, which means nothing can target them.


func on_activate(_sim: BattleSim) -> void:
	unit.hidden_left = maxf(unit.hidden_left, number("duration"))
