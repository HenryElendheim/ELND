extends Ability
## The Brood gives birth every few seconds: a small troop crawls out toward the enemy and fights on its own.
## The young come out at the same level as The Brood.

var _wait := 0.0


func on_spawn(_sim: BattleSim) -> void:
	_wait = number("first_spawn")


func tick(sim: BattleSim) -> void:
	_wait -= sim.tick
	if _wait <= 0.0:
		_wait = number("interval")
		release(sim, 1)


## Lets a number of young out in front of The Brood.
func release(sim: BattleSim, count: int) -> void:
	var forward := -1.0 if unit.team == Unit.Team.PLAYER else 1.0
	for i in count:
		var spot := unit.pos + Vector2((i - (count - 1) / 2.0) * 0.6, forward * (unit.radius + 0.4))
		for young in sim.spawn(String(params.get("spawns")), unit.team, spot, unit.level):
			young.deploy_left = number("crawl_out")
			young.spawn_time = sim.time + young.deploy_left
