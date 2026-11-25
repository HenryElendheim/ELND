extends Ability
## Every few seconds The Editor quietly edits the arena: the enemy troop that has come furthest along its path
## is shifted back toward its own side. It only works while unobserved, which means any enemy troop close by stops it.

var _wait := 0.0
## When the last revision happened, so the screen can show a shimmer.
var last_revision := -INF


func tick(sim: BattleSim) -> void:
	_wait -= sim.tick
	if _wait > 0.0:
		return
	_wait = number("interval")
	var furthest: Unit = null
	for other in sim.units:
		if other.team == unit.team or other.is_building() or other.is_spell() or not other.alive():
			continue
		if unit.pos.distance_to(other.pos) <= number("watch_radius"):
			return
		if furthest == null or sim.progress(other) > sim.progress(furthest):
			furthest = other
	if furthest != null:
		sim.push_back(furthest, number("push_back_tiles"))
		last_revision = sim.time
