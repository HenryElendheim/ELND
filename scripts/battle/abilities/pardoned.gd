extends Ability
## The evolved Pardoned One cannot die. Killed while flying, she is born anew once at her side's main tower
## with some of her health, still evolved. Killed while grounded, kept in one spot, she is gone for good.
## Her base form is never reborn, and neither is a clone, which was never really her.

## True for the new body she is born into, which cannot be reborn again.
var reborn := false


func on_death(sim: BattleSim) -> void:
	if reborn or unit.is_clone or not unit.evolved or not unit.flying:
		return
	var team := unit.team
	var card_id := unit.id
	var level := unit.level
	var share := number("reborn_health")
	sim.later(func() -> void: _rise(sim, card_id, team, level, share))


static func _rise(sim: BattleSim, card_id: String, team: Unit.Team, level: int, share: float) -> void:
	var tower := sim.main_tower(team)
	if tower == null:
		return
	var forward := -2.5 if team == Unit.Team.PLAYER else 2.5
	for body in sim.spawn(card_id, team, tower.pos + Vector2(0, forward), level, true):
		body.hp = body.max_hp * share
		for ability in body.abilities:
			if ability.params.get("id") == "pardoned":
				ability.set("reborn", true)
