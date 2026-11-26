extends Node
## A quick automatic check run by the build. It first loads every script and opens every screen,
## which means a broken file fails the build even if the battle never touches it.
## Then it opens the battle with Admin Mode tools, puts every troop on both sides,
## runs one minute of battle, and makes sure towers took damage. It prints a pass line that the build looks for.

const TICKS := 30 * 60

var _sims: Array[BattleSim] = []


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
	broken += _check_card_search()
	broken += _check_new_cards()
	broken += _check_decks()
	# Every card's details open and close cleanly, which checks the info and codex text for every card.
	for id in Data.table("cards").cards:
		var detail := CardDetail.new(id, [["Nothing", func() -> void: pass]])
		add_child(detail)
		await get_tree().process_frame
		detail.close()
	# The advanced stats view is opened too, with some recorded results so every section has rows.
	var stats_screen: Node = load("res://scenes/stats.tscn").instantiate()
	add_child(stats_screen)
	await get_tree().process_frame
	stats_screen.call("_switch")
	await get_tree().process_frame
	stats_screen.queue_free()
	for scene in ["splash", "main_menu", "home", "settings_menu", "deck", "chest", "shop", "stats", "admin", "road"]:
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
	# Changing an ability number in the middle of a battle has to reach the ability straight away.
	var stomachs: Array = Data.table("cards").cards.hobb.abilities.duplicate(true)
	stomachs[0]["heal_share"] = 0.9
	Data.set_override("cards", ["cards", "hobb", "abilities"], stomachs)
	for unit in sim.units:
		for ability in unit.abilities:
			if ability.params.get("id") == "three_stomachs" and not is_equal_approx(ability.number("heal_share"), 0.9):
				print("Broken file: an ability number change did not reach a live unit")
				broken += 1
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
	# Leaving a match through the confirm question must not record a win or a loss.
	var games_before := float(Stats.all().get("games", 0))
	battle.call("_ask_to_leave")
	battle.call("_keep_playing")
	Stats.record_cancel("battle")
	if float(Stats.all().get("games", 0)) != games_before or float(Stats.all().get("cancelled", 0)) < 1.0:
		print("Broken file: a cancelled match changed the results")
		broken += 1
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


## Plays out a win and opens the chest, then checks reputation went up, cards arrived, and level ups paid out.
func _check_progress() -> int:
	var before := Progress.reputation()
	Progress.record_match("player")
	var opened := Progress.open_next_chest()
	var got := 0
	for drop in opened.get("cards", []):
		got += int(drop.get("count", 0))
	Progress.add_copies("hobb", 40)
	var ok := Progress.reputation() > before and got > 0 and int(Progress.card("hobb").level) > 1
	print("Progress: %d reputation, %d cards from a %s chest, Hobb level %d" % [Progress.reputation(), got, opened.get("rarity", "?"), Progress.card("hobb").level])
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
	# A fresh hand shows Hobb needing one more play, and the evolution slot only ever gives the first card.
	var fresh := Hand.new(["hobb", "editor"], Data.table("battle"), ["hobb"])
	if fresh.cycles_left("hobb") != 1 or fresh.cycles_left("editor") != -1:
		print("Broken file: cycles left are wrong")
		broken += 1
	var owned: Array = Save.get_value("evolutions") if Save.get_value("evolutions") is Array else []
	Save.set_value("evolutions", Progress.evolvable_cards())
	var slotted := Progress.evolutions_in(["hobb", "john_arms", "gasket"])
	Save.set_value("evolutions", owned)
	if slotted != ["hobb"]:
		print("Broken file: the evolution slot gave %s" % [slotted])
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
## Checks the special rules of the cards from ELND-012 on, each in a quiet battle of its own away from the towers.
func _check_new_cards() -> int:
	var broken := 0
	var player := Unit.Team.PLAYER
	var enemy := Unit.Team.ENEMY

	# The Gasket never lures The Hanged One, which has no life in it.
	var sim := _quiet_sim()
	sim.spawn("gasket", player, Vector2(9, 20))
	var hanged: Unit = sim.spawn("hanged_one", enemy, Vector2(9, 19))[0]
	_run(sim, 3.0)
	broken += _expect(hanged.carrier == null and hanged.goal_override == null, "The Gasket lured The Hanged One")

	# The Devil drains the troop next to it and heals itself by the same amount.
	sim = _quiet_sim()
	var devil: Unit = sim.spawn("devil", player, Vector2(9, 20))[0]
	var prey: Unit = sim.spawn("spacefarer", enemy, Vector2(9, 19))[0]
	_run(sim, 1.2)
	devil.hp = devil.max_hp * 0.5
	_run(sim, 1.5)
	broken += _expect(prey.hp < prey.max_hp and devil.hp > devil.max_hp * 0.5, "The Devil did not drain and heal")

	# The Cloud's lightning goes through Kardemosh's skin and stuns it.
	sim = _quiet_sim()
	var kardemosh: Unit = sim.spawn("kardemosh", enemy, Vector2(9, 19))[0]
	sim.spawn("cloud", player, Vector2(9, 20))
	kardemosh.shield = 300.0
	_run(sim, 1.3)
	broken += _expect(kardemosh.hp < kardemosh.max_hp and kardemosh.stun_left > 0.0, "The Cloud's lightning missed or was blocked by skin")

	# The Pardoned One is born anew once when killed while flying, and the new body stays dead.
	sim = _quiet_sim()
	var first: Unit = sim.spawn("pardoned", player, Vector2(9, 21))[0]
	_run(sim, 1.2)
	sim.deal_damage(null, first, first.hp + 1.0)
	_run(sim, 0.1)
	var bodies := sim.units.filter(func(u: Unit) -> bool: return u.id == "pardoned")
	broken += _expect(bodies.size() == 1 and bodies[0].hp < bodies[0].max_hp * 0.5, "The Pardoned One was not born anew")
	if bodies.size() == 1:
		sim.deal_damage(null, bodies[0], bodies[0].hp + 1.0)
		_run(sim, 0.1)
		broken += _expect(not sim.units.any(func(u: Unit) -> bool: return u.id == "pardoned"), "The Pardoned One was born anew twice")

	# The Clone copies a troop at half strength.
	sim = _quiet_sim()
	var hobb: Unit = sim.spawn("hobb", player, Vector2(9, 21))[0]
	_run(sim, 1.2)
	sim.spawn("clone", player, Vector2(9, 21))
	_run(sim, 0.1)
	var copies := sim.units.filter(func(u: Unit) -> bool: return u.id == "hobb" and u.is_clone)
	broken += _expect(copies.size() == 1 and is_equal_approx(copies[0].max_hp, hobb.max_hp * 0.5), "The Clone did not make a half strength copy")

	# The Blinker zooms at a troop a few tiles away.
	sim = _quiet_sim()
	var blinker: Unit = sim.spawn("blinker", player, Vector2(9, 23))[0]
	sim.spawn("spacefarer", enemy, Vector2(9, 19))
	_run(sim, 1.5)
	broken += _expect(int(blinker.abilities[0].get("strain")) >= 1, "The Blinker never zoomed")

	# The Danger Zone enrages a troop, then breaks its bones when it ends.
	sim = _quiet_sim()
	var raged: Unit = sim.spawn("hobb", player, Vector2(9, 21))[0]
	raged.speed = 0.0
	_run(sim, 1.2)
	sim.spawn("danger_zone", player, Vector2(9, 21))
	_run(sim, 10.5)
	broken += _expect(raged.hp < raged.max_hp, "The Danger Zone backlash did not land")

	# Mrs. Give & Take heals a hurt ally.
	sim = _quiet_sim()
	sim.spawn("give_and_take", player, Vector2(9, 22))
	var patient: Unit = sim.spawn("hanged_one", player, Vector2(10, 22))[0]
	var friend: Unit = sim.spawn("hobb", player, Vector2(8, 22))[0]
	friend.speed = 0.0
	patient.speed = 0.0
	_run(sim, 1.1)
	friend.hp = friend.max_hp * 0.5
	patient.hp = patient.max_hp * 0.5
	_run(sim, 1.0)
	broken += _expect(friend.hp > friend.max_hp * 0.5 and is_equal_approx(patient.hp, patient.max_hp * 0.5), "Mrs. Give & Take healed the wrong troop")

	# The Weight pulls a flyer down so a melee ground troop can hit it, and it flies again once it wears off.
	sim = _quiet_sim()
	var flyer: Unit = sim.spawn("creeler", enemy, Vector2(9, 20))[0]
	_run(sim, 1.2)
	sim.spawn("weight", player, Vector2(9, 20))
	_run(sim, 0.2)
	var pulled := not flyer.flying and flyer.hp < flyer.max_hp
	_run(sim, 4.5)
	broken += _expect(pulled and flyer.flying, "The Weight did not pull a flyer down and let it go again")

	# The Toll stuns troops near it when it rings.
	sim = _quiet_sim()
	sim.spawn("toll", player, Vector2(9, 21))
	var rung: Unit = sim.spawn("hobb", enemy, Vector2(9, 19.5))[0]
	_run(sim, 2.4)
	broken += _expect(rung.stun_left > 0.0 and rung.hp < rung.max_hp, "The Toll did not stun a troop next to it")

	# The Brood lets out Broodlings, which never show up in the collection.
	sim = _quiet_sim()
	sim.spawn("brood", player, Vector2(9, 22))
	_run(sim, 2.5)
	var young := sim.units.filter(func(u: Unit) -> bool: return u.id == "broodling").size()
	broken += _expect(young >= 1 and not "broodling" in BattleSim.available_cards(), "The Brood did not spawn, or Broodlings are collectable")

	# The Splitter splits into two halves when it dies.
	sim = _quiet_sim()
	var splitter: Unit = sim.spawn("splitter", player, Vector2(9, 22))[0]
	_run(sim, 1.2)
	sim.deal_damage(null, splitter, splitter.hp + 1.0)
	_run(sim, 0.1)
	var halves := sim.units.filter(func(u: Unit) -> bool: return u.id == "splitter_half").size()
	broken += _expect(halves == 2, "The Splitter split into %d halves" % halves)

	# A troop placed right behind its own side tower walks around it instead of getting stuck.
	sim = _quiet_sim()
	var walker: Unit = sim.spawn("hobb", player, Vector2(3.5, 28.5))[0]
	_run(sim, 6.0)
	broken += _expect(walker.pos.y < 23.0, "a troop got stuck behind its own tower at %s" % [walker.pos])

	for each in _sims:
		each.clear()
	_sims.clear()
	print("New cards checked")
	return broken


## Three decks: saving one, switching to another, and battles always using the deck picked last.
func _check_decks() -> int:
	var first := BattleSim.starting_deck().duplicate()
	Progress.save_deck(Progress.active_deck(), first)
	var reversed := first.duplicate()
	reversed.reverse()
	Progress.select_deck(1)
	Progress.save_deck(1, reversed)
	var ok := BattleSim.starting_deck() == reversed
	Progress.select_deck(0)
	ok = ok and BattleSim.starting_deck() == first and Progress.decks()[1] == reversed
	print("Decks checked")
	return _expect(ok, "switching decks did not keep each deck")


## A battle with no bot and harmless towers, used to test one rule at a time without anything else getting in the way.
func _quiet_sim() -> BattleSim:
	var sim := BattleSim.new()
	sim.bot.enabled = false
	for unit in sim.units:
		unit.damage = 0.0
	_sims.append(sim)
	return sim


func _run(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds / sim.tick):
		sim.step()


func _expect(ok: bool, problem: String) -> int:
	if not ok:
		print("Broken file: " + problem)
	return 0 if ok else 1


## The Admin Mode card search finds cards by name, by tag, and by a picked category.
func _check_card_search() -> int:
	var cases := [
		[CardSearch.find("", "flying"), ["creeler", "pardoned", "cloud", "moth_choir"]],
		[CardSearch.find("the chain", "spell"), ["chain"]],
		[CardSearch.find("ranged troop", ""), ["spacefarer", "pardoned", "give_and_take"]],
		[CardSearch.find("air", ""), ["spacefarer", "pardoned", "give_and_take", "moth_choir"]],
		[CardSearch.find("legendary", "spell"), ["spiker"]],
	]
	for entry in cases:
		if entry[0] != entry[1]:
			print("Broken file: card search found %s instead of %s" % [entry[0], entry[1]])
			return 1
	# Neutralizing every card at once has to stop while enough playable cards are left for a hand.
	var admin: Node = load("res://scenes/admin.tscn").instantiate()
	add_child(admin)
	admin.call("_neutralize_shown", true)
	var left := BattleSim.available_cards().size()
	admin.call("_neutralize_shown", false)
	admin.queue_free()
	if left < int(Data.table("battle").deck.hand) or BattleSim.available_cards().size() <= left:
		print("Broken file: neutralizing everything left %d playable cards" % left)
		return 1
	print("Card search passed")
	return 0


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
