extends Ability
## The Devil In The Forest is too charming to shoot from afar. Enemy ranged troops that can see it feel the urge
## to walk over and say hi, which means they lose their range advantage. Towers and buildings are not fooled.


func tick(_sim: BattleSim) -> void:
	unit.charming = true
