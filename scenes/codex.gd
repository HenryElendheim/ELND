extends Screen
## The in-game Codex. Each anomaly's Foundation entry unlocks once the player has the card,
## and locked entries only show their number so there is something to look forward to.

const MENU_SCENE := "res://scenes/main_menu.tscn"


func build() -> void:
	add(Ui.label("Codex", "TitleLabel"))
	var cards: Dictionary = Data.table("cards").cards
	var classes: Dictionary = Data.table("cards").classes
	var entries: Dictionary = Data.table("codex").entries
	var ids := cards.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(cards[a].number) < int(cards[b].number))
	for id in ids:
		var card: Dictionary = cards[id]
		var number := "ELND-%03d" % int(card.number)
		add(Ui.spacer(8))
		if int(Progress.card(id).level) <= 0:
			add(Ui.label("%s  Not yet acquired" % number, "MutedLabel"))
			continue
		var heading := Ui.label("%s  %s" % [number, card.name], "HeadingLabel")
		add(heading)
		var tag := Ui.label("Class %s   Threat %d/5" % [card["class"], int(card.threat)])
		tag.add_theme_color_override("font_color", Color(classes.get(card["class"], "#8A8A8A")))
		add(tag)
		add(Ui.label(entries.get(id, "")))
	add(Ui.spacer(24))
	add(Ui.button("Back", go_back))


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
