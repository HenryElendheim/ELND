extends Ability
## The Toll rings every few seconds. Every enemy troop within earshot, flying or not, is stunned for a moment and hurt a little.

## When the bell last rang, so the screen can draw the sound spreading out.
var last_ring := -INF
var _wait := 0.0


func on_spawn(_sim: BattleSim) -> void:
	_wait = number("first_ring")


func tick(sim: BattleSim) -> void:
	_wait -= sim.tick
	if _wait <= 0.0:
		ring(sim, 1.0)


## Rings the bell. A stronger ring stuns for longer.
func ring(sim: BattleSim, strength: float) -> void:
	_wait = number("interval")
	last_ring = sim.time
	sim.events.append({"type": "toll", "pos": unit.pos, "radius": number("radius")})
	for other in sim.units:
		if other.team != unit.team and other.kind == "troop" and other.alive() and other.carrier == null and other.pos.distance_to(unit.pos) <= number("radius"):
			sim.deal_damage(unit, other, number("damage") * unit.power)
			sim.stun(other, number("stun") * strength)
