extends Ability
## The evolved Blinker, Quicker Than You Can Blink. Its button, Overzoom, forces one more Zoom past its limit for a huge bite,
## and then it dies. A sacrifice play.


func on_activate(sim: BattleSim) -> void:
	var zoom := sibling("zoom")
	if zoom == null:
		return
	var target: Unit = unit.target if sim.can_target(unit, unit.target) else null
	if target == null:
		var near := sim.enemies_near(unit, unit.pos, unit.radius + zoom.number("zoom_tiles"))
		target = near[0] if not near.is_empty() else null
	if target == null:
		return
	zoom.set("strain", int(zoom.number("deadly_strain")) - 1)
	zoom.call("dash", sim, target, number("bite_multiplier"))
