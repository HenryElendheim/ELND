extends Ability
## The Blinker speeds itself forward. When its target is a little way off, it dashes most of the way in an instant
## and bites on arrival. Every Zoom burns its lifespan and adds strain, which wears off slowly while it does not Zoom.
## It is careful on its own and stops before the strain that would kill it.

var strain := 0
var _since := 0.0
var _ready_at := 0.0


func tick(sim: BattleSim) -> void:
	_since += sim.tick
	if strain > 0 and _since >= number("recharge_every"):
		strain -= 1
		_since = 0.0
	var target := unit.target
	if strain >= int(number("max_strain")) or sim.time < _ready_at or unit.stun_left > 0.0 or unit.carrier != null:
		return
	if not sim.can_target(unit, target) or not sim.same_river_side(unit.pos, target.pos):
		return
	if unit.pos.distance_to(target.pos) - unit.radius - target.radius > number("trigger_distance"):
		dash(sim, target, 1.0)


## One Zoom toward a troop, biting it on arrival with the damage multiplied as asked.
## Reaching the deadly strain kills it straight after the bite.
func dash(sim: BattleSim, target: Unit, bite: float) -> void:
	var gap := unit.pos.distance_to(target.pos) - unit.radius - target.radius
	unit.pos = unit.pos.move_toward(target.pos, clampf(gap - 0.2, 0.0, number("zoom_tiles")))
	unit.prev_pos = unit.pos
	strain += 1
	_since = 0.0
	_ready_at = sim.time + number("zoom_gap")
	if unit.pos.distance_to(target.pos) - unit.radius - target.radius <= unit.attack_range:
		sim.deal_damage(unit, target, unit.damage * bite)
		unit.cooldown = unit.hit_speed
		unit.last_attack_time = sim.time
	if strain >= int(number("deadly_strain")):
		sim.deal_damage(null, unit, unit.hp + unit.shield + 1.0, false)
