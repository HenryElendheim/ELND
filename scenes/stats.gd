extends Screen
## The stats screen. Everything here is saved on the device and read from Stats.

const MENU_SCENE := "res://scenes/main_menu.tscn"


func build() -> void:
	var s := Stats.all()
	var cards: Dictionary = Data.table("cards").cards
	add(Ui.label("Stats", "TitleLabel"))

	_section("Results")
	_line("Games", s.get("games", 0))
	_results("All", s)
	for mode in s.get("by_mode", {}):
		_results(String(mode).capitalize(), s.by_mode[mode])
	for difficulty in s.get("by_difficulty", {}):
		_results("Bot " + String(difficulty), s.by_difficulty[difficulty])
	_line("Longest win streak", s.get("best_streak", 0))
	_line("Three core wins", s.get("three_cores", 0))
	_line("Highest trophies", s.get("highest_trophies", Progress.trophies()))
	var minutes := int(float(s.get("seconds", 0)) / 60.0)
	add(Ui.label("Play time: %d h %d min" % [minutes / 60, minutes % 60]))

	_section("Cards")
	var plays: Dictionary = s.get("card_plays", {})
	var favourite := Stats.top(plays)
	if favourite != "":
		add(Ui.label("Most played: %s (%d)" % [cards[favourite].name, int(plays[favourite])]))
	var games: Dictionary = s.get("card_games", {})
	var wins: Dictionary = s.get("card_wins", {})
	for id in games:
		if cards.has(id):
			add(Ui.label("%s: %d%% wins in %d games" % [cards[id].name, roundi(100.0 * float(wins.get(id, 0)) / float(games[id])), int(games[id])], "MutedLabel"))
	var deck := Stats.top(s.get("decks", {}))
	if deck != "":
		var names := PackedStringArray()
		for id in deck.split(","):
			if cards.has(id):
				names.append(CardTile.short_name(id))
		add(Ui.label("Favourite deck: " + ", ".join(names)))

	_section("Chests")
	for rarity in s.get("chests", {}):
		_line(String(rarity).capitalize() + " chests", s.chests[rarity])
	_line("Legendary cards pulled", s.get("legendaries_pulled", 0))

	_section("Defense")
	_line("Best wave", s.get("best_wave", 0))

	add_back_button()


func _section(title: String) -> void:
	add(Ui.spacer(12))
	add(Ui.label(title, "HeadingLabel"))


func _line(text: String, value: Variant) -> void:
	add(Ui.label("%s: %d" % [text, int(value)]))


## Wins, losses and the win rate for one group of results.
func _results(title: String, group: Dictionary) -> void:
	var won := int(group.get("wins", 0))
	var lost := int(group.get("losses", 0))
	var drawn := int(group.get("draws", 0))
	var played := maxi(won + lost + drawn, 1)
	add(Ui.label("%s: %d won, %d lost, %d drawn, %d%% win rate" % [title, won, lost, drawn, roundi(100.0 * won / played)], "MutedLabel"))


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
