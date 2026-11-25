extends Ability
## While it is empty, The Gasket lures the nearest enemy ground troop, which drops what it is doing and walks inside.
## The troop inside cannot act and slowly loses health until it dies. Only one fits at a time, and after it dies
## the coffin waits a moment before luring again. Flying troops and troops that only attack buildings are never lured.
## If The Gasket is destroyed, the troop inside is freed but dazed for a moment.

var _guest: Unit = null
var _trapped := false
var _wait := 0.0


func tick(sim: BattleSim) -> void:
	if _guest != null and not _guest.alive():
		_guest = null
		_trapped = false
		_wait = number("relure_delay")
	_wait -= sim.tick
	if _guest == null:
		if _wait <= 0.0:
			_guest = _find_guest(sim)
		return
	if _trapped:
		sim.deal_damage(unit, _guest, _guest.max_hp * number("drain_percent_per_second") * sim.tick, false)
	elif _guest.pos.distance_to(unit.pos) <= unit.radius:
		_trapped = true
		_guest.carrier = unit
		_guest.release_daze = number("freed_daze")
	else:
		_guest.goal_override = unit.pos


## The evolved Gasket's button: a burst of damage to the troop inside, and the lid opens again with no waiting.
func close_lid(sim: BattleSim, damage: float) -> void:
	if _guest == null or not _trapped:
		return
	sim.deal_damage(unit, _guest, damage)
	if _guest.alive():
		_guest.carrier = null
		sim.stun(_guest, number("freed_daze"))
	_guest = null
	_trapped = false
	_wait = 0.0


func _find_guest(sim: BattleSim) -> Unit:
	var best: Unit = null
	for other in sim.units:
		if other.team == unit.team or not other.alive() or other.flying or other.kind != "troop":
			continue
		if other.targets == "buildings" or other.carrier != null or other.deploy_left > 0.0:
			continue
		var distance := other.pos.distance_to(unit.pos)
		if distance <= number("lure_radius") and (best == null or distance < best.pos.distance_to(unit.pos)):
			best = other
	return best
