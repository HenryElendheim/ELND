extends Ability
## The evolved Editor's button, Rewrite, is a bigger revision: every enemy troop in The Editor's lane is pushed back at once.


func on_activate(sim: BattleSim) -> void:
	var middle := float(Data.table("battle").arena.width_tiles) / 2.0
	for other in sim.units:
		if other.team != unit.team and other.kind == "troop" and other.alive() and (other.pos.x < middle) == (unit.pos.x < middle):
			sim.push_back(other, number("push_back_tiles"))
