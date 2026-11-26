extends Ability
## The Danger Zone enrages every living troop inside it, from both sides: they attack and move faster and barely feel hits.
## When the zone ends, everyone it enraged pays for it with broken bones, losing part of their max health.
## Towers, buildings and lifeless troops are not affected.

var _age := 0.0
var _enraged := {}


func tick(sim: BattleSim) -> void:
	_age += sim.tick
	if _age >= number("duration"):
		for troop in _enraged:
			if troop.alive():
				sim.deal_damage(null, troop, troop.max_hp * number("backlash"))
				sim.events.append({"type": "backlash", "pos": troop.pos})
		_enraged.clear()
		unit.hp = 0.0
		return
	var haste := 1.0 + number("haste")
	for troop in sim.units:
		if troop.is_living_troop() and troop.pos.distance_to(unit.pos) <= unit.radius:
			troop.attack_speed *= haste
			troop.move_speed *= haste
			troop.damage_taken *= number("damage_taken")
			troop.enraged = true
			_enraged[troop] = true
