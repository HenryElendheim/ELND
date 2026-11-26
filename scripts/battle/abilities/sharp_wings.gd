extends Ability
## The Pardoned One shoots razor feathers. Each feather comes back to her a moment later carrying the victim's nutrients,
## which heals her for the damage of the shot. With too many feathers out at once she cannot fly,
## which means melee ground troops can reach her until enough feathers return. With every feather out she cannot shoot.

## Feathers that are out, each with the time it comes back and how much it heals.
var out: Array = []
## Feather Storm keeps her grounded until this time, whatever the feathers do.
var grounded_until := -INF
var _last_shot := -INF


func tick(sim: BattleSim) -> void:
	if unit.last_attack_time > _last_shot:
		_last_shot = unit.last_attack_time
		launch(sim, unit.damage)
	var still_out: Array = []
	for feather in out:
		if sim.time >= float(feather.back_at):
			unit.hp = minf(unit.hp + float(feather.heal), unit.max_hp)
		else:
			still_out.append(feather)
	out = still_out
	var grounded := out.size() > int(number("grounded_above")) or sim.time < grounded_until
	# She never lands in the river. She waits until she is over ground or a bridge.
	if not grounded or not sim.in_river(unit.pos):
		unit.flying = not grounded
	if out.size() >= int(number("feathers")):
		unit.can_attack = false


## Sends out one feather that will come back and heal her.
func launch(sim: BattleSim, heal: float) -> void:
	out.append({"back_at": sim.time + number("return_time"), "heal": heal})


func feathers_left() -> int:
	return maxi(int(number("feathers")) - out.size(), 0)
