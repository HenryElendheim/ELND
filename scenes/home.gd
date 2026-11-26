extends Screen
## The Battle page of the main menu: where you stand, and the buttons to start playing.

const BATTLE_SCENE := "res://scenes/battle.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"
const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"
const ROAD_SCENE := "res://scenes/road.tscn"


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = add(Ui.label("ELND", "TitleLabel"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats: Label = add(Ui.label("%s   %d reputation\nLevel %d   %d gold" % [Progress.arena_name(Progress.arena()), Progress.reputation(), Progress.player_level(), Progress.gold()]))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(Ui.spacer(60))
	var battle: Button = add(Ui.button("Battle", func() -> void: Nav.go(BATTLE_SCENE, {"mode": "battle"})))
	battle.custom_minimum_size.y = 200
	add(Ui.button("Defense", func() -> void: Nav.go(BATTLE_SCENE, {"mode": "defense"})))
	var waiting := Progress.chests_waiting().size()
	if waiting > 0:
		add(Ui.button("Open chests (%d)" % waiting, func() -> void: Nav.go(CHEST_SCENE)))
	add(Ui.button("Foundation road", func() -> void: Nav.go(ROAD_SCENE)))
	add(Ui.spacer(40))
	add(Ui.button("Settings", func() -> void: Nav.go(SETTINGS_SCENE)))
