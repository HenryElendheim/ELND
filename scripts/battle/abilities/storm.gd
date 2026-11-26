extends Ability
## The evolved Cloud, Thunderhead. Its button, Storm, drifts it a few tiles toward the enemy side and strikes straight away.


func on_activate(sim: BattleSim) -> void:
	var toward := -1.0 if unit.team == Unit.Team.PLAYER else 1.0
	var length := float(Data.table("battle").arena.length_tiles)
	unit.pos.y = clampf(unit.pos.y + toward * number("drift_tiles"), 0.5, length - 0.5)
	var lightning := sibling("lightning_strike")
	if lightning != null:
		lightning.call("strike_now", sim)
