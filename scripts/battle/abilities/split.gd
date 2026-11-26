extends Ability
## The Splitter does not die so much as divide. When it falls, it splits into smaller copies of itself,
## and the halves split once more into quarters. A clone made by The Clone never splits.


func on_death(sim: BattleSim) -> void:
	if unit.is_clone:
		return
	var into := String(params.get("into"))
	var count := int(number("count"))
	var team := unit.team
	var level := unit.level
	var at := unit.pos
	sim.later(func() -> void: _divide(sim, into, count, team, level, at))


static func _divide(sim: BattleSim, into: String, count: int, team: Unit.Team, level: int, at: Vector2) -> void:
	for i in count:
		var side := Vector2.from_angle(TAU * i / count) * 0.5
		for part in sim.spawn(into, team, at + side, level):
			part.deploy_left = 0.3
			part.spawn_time = sim.time + part.deploy_left
