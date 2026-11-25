extends Screen
## Your cards. Tap a card to put it in or take it out of your deck, which is saved whenever it has exactly the right
## number of cards. Each row shows the card's level and how many copies the next level needs, and wild cards can top it up.

const MENU_SCENE := "res://scenes/main_menu.tscn"

var _picked := []
var _count: Label
var _wild: Label
var _size := 8


func build() -> void:
	_size = int(Data.table("battle").deck.size)
	_picked = BattleSim.starting_deck().duplicate()
	add(Ui.label("Cards", "TitleLabel"))
	_count = add(Ui.label(""))
	_wild = add(Ui.label("", "MutedLabel"))
	for id in BattleSim.available_cards():
		add(_row(id))
	add(Ui.spacer(24))
	add(Ui.button("Back", go_back))
	_show_counts()


func _row(id: String) -> Control:
	var card: Dictionary = Data.table("cards").cards[id]
	var progress := Progress.card(id)
	var row := HBoxContainer.new()
	var pick := Ui.button("%s   %d" % [card.name.trim_prefix("The "), int(card.cost)], func() -> void: pass)
	pick.toggle_mode = true
	pick.button_pressed = id in _picked
	pick.toggled.connect(func(on: bool) -> void: _toggle(id, on))
	row.add_child(pick)
	var level := int(progress.level)
	var status := "Lv %d  max" % level if level >= Progress.max_card_level() else "Lv %d  %d/%d" % [level, progress.copies, Progress.copies_for_next(level)]
	var info := Ui.label(status, "MutedLabel")
	info.size_flags_horizontal = SIZE_FILL
	info.custom_minimum_size.x = 260
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)
	if Progress.wild_cards() > 0 and level < Progress.max_card_level():
		var wild := Ui.button("Wild", func() -> void: _use_wild(id))
		wild.size_flags_horizontal = SIZE_FILL
		row.add_child(wild)
	return row


func _toggle(id: String, on: bool) -> void:
	if on and not id in _picked:
		_picked.append(id)
	elif not on:
		_picked.erase(id)
	_show_counts()
	if _picked.size() == _size:
		Save.set_value("deck", _picked.duplicate())


func _use_wild(id: String) -> void:
	Progress.use_wild_cards(id)
	get_tree().reload_current_scene()


func _show_counts() -> void:
	_count.text = "%d of %d cards in your deck" % [_picked.size(), _size]
	_wild.text = "%d wild cards" % Progress.wild_cards()


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
