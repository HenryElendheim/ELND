extends Ability
## The evolved Gasket's button, Close the Lid, hits the troop inside with a big burst of damage,
## and the lid opens again right away so the next troop can be lured in.


func on_activate(sim: BattleSim) -> void:
	var coffin := sibling("comfortable_end")
	if coffin != null:
		coffin.call("close_lid", sim, number("lid_damage"))
