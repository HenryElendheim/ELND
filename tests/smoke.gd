extends Node
## A quick automatic check run by the build. It opens the battle with Admin Mode tools, puts every troop on both sides,
## runs one minute of battle, and makes sure towers took damage. It prints a pass line that the build looks for.

const TICKS := 30 * 60


func _ready() -> void:
	Settings.set_value("admin_mode", true)
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	var sim: BattleSim = battle.sim
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		if cards[id].type == "troop":
			sim.spawn(id, Unit.Team.PLAYER, Vector2(4, 24))
			sim.spawn(id, Unit.Team.ENEMY, Vector2(14, 8))

	Data.set_override("cards", ["cards", "hobb", "health"], 400.0)
	Data.reset_override("cards", ["cards", "hobb"])
	for i in TICKS:
		sim.step()
	for i in 3:
		await get_tree().process_frame

	var hurt := 0
	for unit in sim.units:
		if unit.is_tower() and unit.hp < unit.max_hp:
			hurt += 1
	var towers_left := sim.units.filter(func(u: Unit) -> bool: return u.is_tower()).size()
	print("Towers damaged: %d, towers standing: %d, units left: %d" % [hurt, towers_left, sim.units.size()])
	if hurt > 0 or towers_left < 6:
		print("Smoke test passed")
	Settings.set_value("admin_mode", false)
	get_tree().quit()
