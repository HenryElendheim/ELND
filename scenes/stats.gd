extends Screen
## The stats screen. The overview shows the numbers that matter most as big tiles, with your favourite card.
## Advanced view lists everything else in short, striped rows with win rate bars, so it reads at a glance.

const MENU_SCENE := "res://scenes/main_menu.tscn"

var _advanced := false


func build() -> void:
	var s := Stats.all()
	add(Ui.label("Stats", "TitleLabel"))
	if float(s.get("games", 0)) <= 0.0:
		add(Ui.label("Play a match and your stats will show up here.", "MutedLabel"))
	if _advanced:
		_build_advanced(s)
	else:
		_build_overview(s)
	add(Ui.spacer(16))
	add(Ui.button("Simple view" if _advanced else "Advanced view", _switch))
	add_back_button()


func _switch() -> void:
	_advanced = not _advanced
	for child in content.get_children():
		child.queue_free()
	build()


## Six big numbers in two columns, then the favourite card and the total play time.
func _build_overview(s: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	add(grid)
	var all_games := float(s.get("games", 0))
	grid.add_child(_tile(str(int(all_games)), "Games"))
	grid.add_child(_tile("%d%%" % _rate(s), "Win rate"))
	grid.add_child(_tile(str(int(s.get("best_streak", 0))), "Best win streak"))
	grid.add_child(_tile(str(int(s.get("highest_trophies", Progress.trophies()))), "Highest trophies"))
	grid.add_child(_tile(str(int(s.get("three_cores", 0))), "Three core wins"))
	grid.add_child(_tile(str(int(s.get("best_wave", 0))), "Best Defense wave"))

	var plays: Dictionary = s.get("card_plays", {})
	var favourite := Stats.top(plays)
	if favourite != "" and Data.table("cards").cards.has(favourite):
		add(Ui.spacer(8))
		var row := HBoxContainer.new()
		var tile := CardTile.new(favourite)
		tile.size_flags_horizontal = SIZE_FILL
		tile.custom_minimum_size = Vector2(200, 250)
		tile.disabled = true
		row.add_child(tile)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(Ui.label("Favourite card", "MutedLabel"))
		words.add_child(Ui.label(Data.table("cards").cards[favourite].name, "HeadingLabel"))
		words.add_child(Ui.label("Played %d times" % int(plays[favourite])))
		row.add_child(words)
		add(row)
	add(Ui.spacer(8))
	add(_tile(_play_time(s), "Time played"))


## Everything else, in sections of striped rows.
func _build_advanced(s: Dictionary) -> void:
	var cards: Dictionary = Data.table("cards").cards
	var rows := _section("Results")
	_result_row(rows, "All matches", s)
	for mode in s.get("by_mode", {}):
		_result_row(rows, String(mode).capitalize(), s.by_mode[mode])
	for difficulty in s.get("by_difficulty", {}):
		_result_row(rows, "Bot: " + String(difficulty).capitalize(), s.by_difficulty[difficulty])

	var games: Dictionary = s.get("card_games", {})
	if not games.is_empty():
		rows = _section("Cards")
		var wins: Dictionary = s.get("card_wins", {})
		var plays: Dictionary = s.get("card_plays", {})
		var ids := games.keys().filter(func(id: String) -> bool: return cards.has(id))
		ids.sort_custom(func(a: String, b: String) -> bool: return float(games[a]) > float(games[b]))
		for id in ids:
			var rate := roundi(100.0 * float(wins.get(id, 0)) / maxf(float(games[id]), 1.0))
			_row(rows, CardTile.short_name(id), "%d%%" % rate, "%d games, played %d times" % [int(games[id]), int(plays.get(id, 0))], rate)

	var chests: Dictionary = s.get("chests", {})
	if not chests.is_empty():
		rows = _section("Chests opened")
		var colours: Dictionary = Data.table("chests").colours
		for rarity in colours:
			if chests.has(rarity):
				var line := _row(rows, String(rarity).capitalize(), str(int(chests[rarity])))
				line.get_child(0).get_child(0).get_child(0).add_theme_color_override("font_color", Color(colours[rarity]))
		_row(rows, "Legendary cards pulled", str(int(s.get("legendaries_pulled", 0))))

	rows = _section("Records")
	_row(rows, "Best win streak", str(int(s.get("best_streak", 0))))
	_row(rows, "Current streak", str(int(s.get("streak", 0))))
	_row(rows, "Highest trophies", str(int(s.get("highest_trophies", Progress.trophies()))))
	_row(rows, "Three core wins", str(int(s.get("three_cores", 0))))
	_row(rows, "Best Defense wave", str(int(s.get("best_wave", 0))))
	_row(rows, "Time played", _play_time(s))
	var count := float(s.get("games", 0))
	var average := float(s.get("seconds", 0)) / count if count > 0.0 else 0.0
	_row(rows, "Average match", "%d:%02d" % [int(average) / 60, int(average) % 60])


## A big number with a small caption under it, on a raised tile.
func _tile(number: String, caption: String) -> Control:
	var tile := PanelContainer.new()
	tile.theme_type_variation = "StatTile"
	tile.size_flags_horizontal = SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)
	var big := Ui.label(number, "StatNumber")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var small := Ui.label(caption, "MutedLabel")
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(small)
	return tile


## A section heading and the box its rows go into.
func _section(title: String) -> VBoxContainer:
	add(Ui.spacer(12))
	add(Ui.label(title, "HeadingLabel"))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	add(rows)
	return rows


## One row: the name on the left and the value on the right, with an optional smaller line under the name
## and an optional bar from 0 to 100. Every other row sits on a faint stripe, which keeps the eye on the right line.
func _row(rows: VBoxContainer, name_text: String, value: String, detail := "", bar := -1) -> PanelContainer:
	var stripe := PanelContainer.new()
	stripe.theme_type_variation = "Stripe" if rows.get_child_count() % 2 == 0 else "Plain"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	stripe.add_child(column)
	var line := HBoxContainer.new()
	line.add_child(Ui.label(name_text))
	var number := Ui.label(value, "HeadingLabel")
	number.size_flags_horizontal = SIZE_FILL
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(number)
	column.add_child(line)
	if detail != "":
		column.add_child(Ui.label(detail, "MutedLabel"))
	if bar >= 0:
		var meter := ProgressBar.new()
		meter.show_percentage = false
		meter.custom_minimum_size.y = 14
		meter.value = bar
		column.add_child(meter)
	rows.add_child(stripe)
	return stripe


func _result_row(rows: VBoxContainer, title: String, group: Dictionary) -> void:
	var won := int(group.get("wins", 0))
	var lost := int(group.get("losses", 0))
	var drawn := int(group.get("draws", 0))
	var rate := _rate(group)
	_row(rows, title, "%d%%" % rate, "%d won   %d lost   %d drawn" % [won, lost, drawn], rate)


static func _rate(group: Dictionary) -> int:
	var won := float(group.get("wins", 0))
	var played := won + float(group.get("losses", 0)) + float(group.get("draws", 0))
	return roundi(100.0 * won / played) if played > 0.0 else 0


static func _play_time(s: Dictionary) -> String:
	var minutes := int(float(s.get("seconds", 0)) / 60.0)
	return "%d h %d min" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
