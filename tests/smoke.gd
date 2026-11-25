extends Node
## A quick automatic check run by the build. It first loads every script and opens every screen,
## which means a broken file fails the build even if the battle never touches it.
## Then it opens the battle with Admin Mode tools, puts every troop on both sides,
## runs one minute of battle, and makes sure towers took damage. It prints a pass line that the build looks for.

const TICKS := 30 * 60


func _ready() -> void:
	Settings.set_value("admin_mode", true)
	var broken := _load_everything("res://scenes") + _load_everything("res://scripts")
	for scene in ["splash", "main_menu", "settings_menu", "deck"]:
		var screen: Node = load("res://scenes/%s.tscn" % scene).instantiate()
		add_child(screen)
		await get_tree().process_frame
		screen.queue_free()

	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	var sim: BattleSim = battle.sim
	var cards: Dictionary = Data.table("cards").cards
	# Every card goes in for the enemy, spells and buildings included, so every ability runs at least once.
	for id in cards:
		sim.spawn(id, Unit.Team.ENEMY, Vector2(14, 8))
	# The player side plays its whole hand through the normal rules, which checks costs, placement and cycling.
	var hand := sim.hands[Unit.Team.PLAYER]
	hand.infinite = true
	for i in 8:
		if not sim.play(Unit.Team.PLAYER, 0, Vector2(4, 24)):
			print("Broken file: playing a card failed")
			broken += 1
	if sim.play(Unit.Team.PLAYER, 0, Vector2(4, 8)):
		print("Broken file: placing on the enemy half was allowed")
		broken += 1

	Data.set_override("cards", ["cards", "hobb", "health"], 400.0)
	Data.reset_override("cards", ["cards", "hobb"])
	for i in TICKS:
		sim.step()
	for i in 3:
		await get_tree().process_frame

	broken += _check_win_rules()
	broken += _check_bot_counters()

	var hurt := 0
	for unit in sim.units:
		if unit.is_tower() and unit.hp < unit.max_hp:
			hurt += 1
	var towers_left := sim.units.filter(func(u: Unit) -> bool: return u.is_tower()).size()
	print("Towers damaged: %d, towers standing: %d, units left: %d" % [hurt, towers_left, sim.units.size()])
	if broken == 0 and (hurt > 0 or towers_left < 6):
		print("Smoke test passed")
	Settings.set_value("admin_mode", false)
	get_tree().quit()


## Checks that more crowns win once time is up, and that the tiebreaker always ends the match.
func _check_win_rules() -> int:
	var broken := 0
	var regular := float(Data.table("battle").match.regular_seconds)
	var lead := BattleSim.new()
	lead.bot.enabled = false
	for unit in lead.units:
		if unit.kind == "side" and unit.team == Unit.Team.ENEMY:
			unit.hp = 0.0
			break
	lead.drop_dead()
	lead.time = regular
	lead.step()
	if lead.result != "player":
		print("Broken file: one crown up at full time did not win, result was '%s'" % lead.result)
		broken += 1
	var tied := BattleSim.new()
	tied.bot.enabled = false
	tied.time = regular + float(Data.table("battle").match.overtime_seconds)
	for i in 30 * 30:
		tied.step()
	if tied.result == "":
		print("Broken file: the tiebreaker never ended the match")
		broken += 1
	print("Tiebreaker result: " + tied.result)
	lead.clear()
	tied.clear()
	return broken


## Checks that the bot never thinks a ground melee card answers a flying troop, and prefers an anti-air card.
func _check_bot_counters() -> int:
	var cards: Dictionary = Data.table("cards").cards
	var flyer := Unit.new()
	flyer.flying = true
	flyer.max_hp = 800.0
	var threats: Array[Unit] = [flyer]
	var melee := Bot.counter_score(cards.hobb, threats)
	var anti_air := Bot.counter_score(cards.spacefarer, threats)
	if melee > -50.0 or anti_air <= melee:
		print("Broken file: bot counters are wrong, melee %.1f, anti-air %.1f" % [melee, anti_air])
		return 1
	return 0


## Loads every script and scene in a folder and its subfolders, and counts the ones that fail.
func _load_everything(folder: String) -> int:
	var broken := 0
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			var path := folder.path_join(file)
			var loaded: Resource = load(path)
			var ok := loaded != null and (not loaded is GDScript or (loaded as GDScript).can_instantiate())
			if not ok:
				print("Broken file: " + path)
				broken += 1
	for sub in DirAccess.get_directories_at(folder):
		broken += _load_everything(folder.path_join(sub))
	return broken
