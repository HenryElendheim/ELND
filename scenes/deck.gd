extends Screen
## Pick which cards go into your deck. The deck is saved whenever it has exactly the right number of cards,
## which means leaving with too few or too many keeps the last full deck.

const MENU_SCENE := "res://scenes/main_menu.tscn"

var _picked := []
var _count: Label
var _size := 8


func build() -> void:
	_size = int(Data.table("battle").deck.size)
	_picked = BattleSim.starting_deck().duplicate()
	add(Ui.label("Deck", "TitleLabel"))
	_count = add(Ui.label(""))
	var grid := GridContainer.new()
	grid.columns = 2
	add(grid)
	var cards: Dictionary = Data.table("cards").cards
	for id in BattleSim.available_cards():
		var card := Ui.button("%s\n%d" % [cards[id].name.trim_prefix("The "), int(cards[id].cost)], func() -> void: pass)
		card.toggle_mode = true
		card.button_pressed = id in _picked
		card.custom_minimum_size.y = 150
		card.toggled.connect(func(on: bool) -> void: _toggle(id, on))
		grid.add_child(card)
	add(Ui.spacer(24))
	add(Ui.button("Back", go_back))
	_show_count()


func _toggle(id: String, on: bool) -> void:
	if on and not id in _picked:
		_picked.append(id)
	elif not on:
		_picked.erase(id)
	_show_count()
	if _picked.size() == _size:
		Save.set_value("deck", _picked.duplicate())


func _show_count() -> void:
	_count.text = "%d of %d cards" % [_picked.size(), _size]


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
