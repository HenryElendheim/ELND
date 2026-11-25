extends Screen
## The first screen after the splash.

const BATTLE_SCENE := "res://scenes/battle.tscn"
const DECK_SCENE := "res://scenes/deck.tscn"
const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = add(Ui.label("ELND", "TitleLabel"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(Ui.spacer(80))
	add(Ui.button("Battle", func() -> void: Nav.go(BATTLE_SCENE)))
	add(Ui.button("Deck", func() -> void: Nav.go(DECK_SCENE)))
	add(Ui.button("Settings", func() -> void: Nav.go(SETTINGS_SCENE)))
