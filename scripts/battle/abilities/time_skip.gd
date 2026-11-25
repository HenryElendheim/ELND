extends Ability
## The evolved Spacefarer's button, Time Skip, blinks it a few tiles back toward its own side, away from danger,
## and it keeps its ramped-up attack speed.


func on_activate(sim: BattleSim) -> void:
	sim.push_back(unit, number("blink_tiles"))
	unit.prev_pos = unit.pos
