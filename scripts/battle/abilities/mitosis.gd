extends Ability
## The evolved Splitter, Mitosis. Its button splits it straight away, whatever health it has left.


func on_activate(sim: BattleSim) -> void:
	sim.deal_damage(null, unit, unit.hp + unit.shield + 1.0)
