extends Ability
## Every enemy troop near The Dargalean feels the urge to go to it, which means they all target it for as long as it lives.


func tick(_sim: BattleSim) -> void:
	unit.taunt_radius = number("radius")
