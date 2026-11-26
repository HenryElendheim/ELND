extends Ability
## The evolved Devil In The Forest, Deeper Into the Woods. Its button switches the drain to a new troop straight away
## and drains it much faster for a few seconds.


func on_activate(sim: BattleSim) -> void:
	var drain := sibling("happy_face")
	if drain != null:
		drain.call("rush", sim, number("boost"), number("boost_time"))
