extends Node
## A quick automatic check run by the build. It first loads every script and opens every screen,
## which means a broken file fails the build even if the battle never touches it.
## Then it opens the battle with Admin Mode tools, puts every troop on both sides,
## runs one minute of battle, and makes sure towers took damage. It prints a pass line that the build looks for.

const TICKS := 30 * 60


func _ready() -> void:
	Settings.set_value("admin_mode", true)
	var broken := _load_everything("res://scenes") + _load_everything("res://scripts")
	broken += _check_progress()
	# A waiting chest keeps the chest screen open instead of sending it back to the menu.
	Progress.queue_chest("common")
	Stats.record_match("battle", "player", 3, ["hobb", "chain"], BattleSim.starting_deck(), 120.0)
	Progress.add_gold(1000)
	if not Progress.buy_chest("common"):
		print("Broken file: buying a chest with enough gold failed")
		broken += 1
	broken += _check_placement()
	for scene in ["splash", "main_menu", "home", "settings_menu", "deck", "chest", "shop", "stats", "codex", "admin"]:
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
		if not sim.play(Unit.Team.PLAYER, 0, Vector2(6, 21)):
			print("Broken file: playing a card failed")
			broken += 1
	if sim.play(Unit.Team.PLAYER, 0, Vector2(4, 8)):
		print("Broken file: placing on the enemy half was allowed")
		broken += 1

	Data.set_override("cards", ["cards", "hobb", "health"], 400.0)
	Data.reset_override("cards", ["cards", "hobb"])
	var shots_seen := false
	for i in TICKS:
		sim.step()
		shots_seen = shots_seen or not sim.projectiles.is_empty()
	if not shots_seen:
		print("Broken file: no projectile was ever fired")
		broken += 1
	for i in 3:
		await get_tree().process_frame

	broken += _check_win_rules()
	broken += _check_bot_counters()
	broken += _check_evolutions()
	broken += _check_defense()

	var hurt := 0
	for unit in sim.units:
		if unit.is_tower() and unit.hp < unit.max_hp:
			hurt += 1
	var towers_left := sim.units.filter(func(u: Unit) -> bool: return u.is_tower()).size()
	print("Towers damaged: %d, towers standing: %d, units left: %d" % [hurt, towers_left, sim.units.size()])
	if broken == 0 and (hurt > 0 or towers_left < 6):
		print("Smoke test passed")
	Settings.set_value("admin_mode", false)
	Save.replace_all({})
	get_tree().quit()


## Checks that more cores win once time is up, and that the tiebreaker always ends the match.
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
		print("Broken file: one core up at full time did not win, result was '%s'" % lead.result)
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


## Plays out a win and opens the chest, then checks trophies went up, cards arrived, and level ups paid out.
func _check_progress() -> int:
	var before := Progress.trophies()
	Progress.record_match("player")
	var opened := Progress.open_next_chest()
	var got := 0
	for drop in opened.get("cards", []):
		got += int(drop.get("count", 0))
	Progress.add_copies("hobb", 40)
	var ok := Progress.trophies() > before and got > 0 and int(Progress.card("hobb").level) > 1
	print("Progress: %d trophies, %d cards from a %s chest, Hobb level %d" % [Progress.trophies(), got, opened.get("rarity", "?"), Progress.card("hobb").level])
	Save.replace_all({})
	if not ok:
		print("Broken file: progression did not pay out")
	return 0 if ok else 1


## Spawns every evolvable card evolved for both sides, runs a few seconds, presses every evolution button,
## and checks the cycle rule: a card costing 5 or more needs 2 cycles, cheaper cards need 1.
func _check_evolutions() -> int:
	var broken := 0
	var sim := BattleSim.new()
	sim.bot.enabled = false
	for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
		sim.hands[team].infinite = true
		for id in Progress.evolvable_cards():
			sim.spawn(id, team, Vector2(9, 20 if team == Unit.Team.PLAYER else 12), 1, true)
	for i in 30 * 3:
		sim.step()
	var pressed := 0
	for team in [Unit.Team.PLAYER, Unit.Team.ENEMY]:
		for unit in sim.evolution_buttons(team):
			if sim.activate_evolution(unit):
				pressed += 1
	for i in 30 * 3:
		sim.step()
	if pressed == 0:
		print("Broken file: no evolution button could be pressed")
		broken += 1
	if Hand.cycles_needed("john_arms") != 2 or Hand.cycles_needed("hobb") != 1:
		print("Broken file: evolution cycles do not follow the cost rule")
		broken += 1
	var hand := Hand.new(["hobb", "editor", "chain", "gasket", "dargalean"], Data.table("battle"), ["hobb"])
	hand.infinite = true
	var evolved_plays := 0
	# Hobb is played whenever it is in the hand, and otherwise the first card is played to cycle the deck.
	for i in 20:
		var slot := hand.cards.find("hobb")
		if slot < 0 or slot >= 4:
			slot = 0
		var played := hand.play(slot)
		if played == "hobb" and hand.played_evolved:
			evolved_plays += 1
	print("Evolutions pressed: %d, Hobb evolved plays: %d" % [pressed, evolved_plays])
	if evolved_plays == 0:
		print("Broken file: an evolution card never came out evolved")
		broken += 1
	sim.clear()
	return broken


## Runs Defense mode for a while and checks that waves come in and there are no enemy towers.
func _check_defense() -> int:
	var sim := BattleSim.new("defense")
	for i in 30 * 40:
		sim.step()
	var enemy_towers := sim.units.filter(func(u: Unit) -> bool: return u.is_tower() and u.team == Unit.Team.ENEMY).size()
	print("Defense: wave %d, result '%s'" % [sim.waves.wave, sim.result])
	sim.clear()
	if sim.waves.wave < 2 or enemy_towers > 0:
		print("Broken file: defense waves did not run properly")
		return 1
	return 0


## Checks the placement rules: spots snap to tile centres, tower tiles are blocked, the enemy half is blocked,
## and destroying a main tower takes the side towers with it for three cores.
func _check_placement() -> int:
	var broken := 0
	var sim := BattleSim.new()
	sim.bot.enabled = false
	if BattleSim.snap(Vector2(4.2, 24.9)) != Vector2(4.5, 24.5):
		print("Broken file: snapping to tiles is off")
		broken += 1
	if sim.can_place(Unit.Team.PLAYER, Vector2(3.5, 25.5)) or sim.can_place(Unit.Team.PLAYER, Vector2(9.5, 29.5)):
		print("Broken file: placing inside a tower was allowed")
		broken += 1
	if not sim.can_place(Unit.Team.PLAYER, Vector2(9.5, 21.5)) or sim.can_place(Unit.Team.PLAYER, Vector2(9.5, 8.5)):
		print("Broken file: the halves are not right for placing")
		broken += 1
	for unit in sim.units:
		if unit.kind == "main" and unit.team == Unit.Team.ENEMY:
			sim.deal_damage(null, unit, unit.hp + 1.0)
	sim.drop_dead()
	if sim.towers_lost(Unit.Team.ENEMY) != 3:
		print("Broken file: a fallen main tower gave %d cores" % sim.towers_lost(Unit.Team.ENEMY))
		broken += 1
	sim.clear()
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
