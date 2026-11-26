extends Ability
## The evolved Toll, Last Toll. Its button rings the bell straight away, and the stun lasts twice as long.


func on_activate(sim: BattleSim) -> void:
	var bell := sibling("toll")
	if bell != null:
		bell.call("ring", sim, number("strength"))
