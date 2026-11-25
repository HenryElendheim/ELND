extends Ability
## The evolved John Arms, No Hard Feelings, can Flurry whenever the player asks, even if nobody has attacked it yet,
## and its exhaustion afterwards is shorter.


func on_spawn(_sim: BattleSim) -> void:
	var flurry := sibling("flurry")
	if flurry != null:
		flurry.params = flurry.params.merged({"exhausted_time": number("exhausted_time")}, true)


func on_activate(sim: BattleSim) -> void:
	var flurry := sibling("flurry")
	if flurry != null:
		flurry.call("start", sim)
