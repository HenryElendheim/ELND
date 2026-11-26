extends Ability
## The evolved Mrs. Give & Take, Return. Its button pours her whole life pool out at once, shared between every ally in range.


func on_activate(sim: BattleSim) -> void:
	var take := sibling("take_and_give")
	if take == null:
		return
	var allies: Array[Unit] = take.call("allies_in_reach", sim)
	if allies.is_empty():
		return
	var share: float = float(take.get("pool")) / allies.size()
	for ally in allies:
		take.call("heal", sim, ally, minf(share, float(take.get("pool"))))
	take.set("pool", 0.0)
