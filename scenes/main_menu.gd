extends Screen
## The first screen after the splash. It shows trophies, arena, level and gold, and leads to everything else.

const BATTLE_SCENE := "res://scenes/battle.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"
const DECK_SCENE := "res://scenes/deck.tscn"
const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"
const STATS_SCENE := "res://scenes/stats.tscn"


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = add(Ui.label("ELND", "TitleLabel"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats: Label = add(Ui.label("Arena %d   %d trophies\nLevel %d   %d gold" % [Progress.arena(), Progress.trophies(), Progress.player_level(), Progress.gold()]))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(Ui.spacer(60))
	add(Ui.button("Battle", func() -> void: Nav.go(BATTLE_SCENE, {"mode": "battle"})))
	add(Ui.button("Defense", func() -> void: Nav.go(BATTLE_SCENE, {"mode": "defense"})))
	var waiting := Progress.chests_waiting().size()
	if waiting > 0:
		add(Ui.button("Open chests (%d)" % waiting, func() -> void: Nav.go(CHEST_SCENE)))
	add(Ui.button("Cards", func() -> void: Nav.go(DECK_SCENE)))
	add(Ui.button("Shop", func() -> void: Nav.go(SHOP_SCENE)))
	add(Ui.button("Stats", func() -> void: Nav.go(STATS_SCENE)))
	add(Ui.button("Settings", func() -> void: Nav.go(SETTINGS_SCENE)))
