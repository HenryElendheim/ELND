extends Screen
## The Cards screen. Your deck sits at the top as two rows of four tiles, each with its level and copies bar,
## then the average Ephrocity cost and tower level, then the rest of your collection.
## Tap a card to open its details, with its stats, how it works and its Codex entry,
## and the buttons to add it, swap it in, take it out, switch its evolution or spend wild cards.
## The deck is saved whenever it has exactly the right number of cards.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const COLUMNS := 4

var _deck := []
var _size := 8
var _selected := ""
var _detail: CardDetail = null
## A collection card waiting to be swapped in. The next deck card tapped is the one it replaces.
var _swap_in := ""


func build() -> void:
	_size = int(Data.table("battle").deck.size)
	if _deck.is_empty():
		_deck = BattleSim.starting_deck().duplicate()
	add(Ui.label("Cards", "TitleLabel"))

	add(Ui.label("Deck  %d of %d" % [_deck.size(), _size], "HeadingLabel"))
	add(_grid(_deck))
	var costs := 0.0
	for id in _deck:
		costs += Hand.cost_of(id)
	var average := costs / maxf(_deck.size(), 1)
	add(Ui.label("Average cost %.1f     Towers level %d" % [average, Progress.tower_level()]))
	add(Ui.label("%d wild cards   %d injections   %d of 3 shards" % [Progress.wild_cards(), Progress.injections(), Progress.shards()], "MutedLabel"))

	var rest := BattleSim.available_cards().filter(func(id: String) -> bool: return not id in _deck)
	if not rest.is_empty():
		add(Ui.spacer(12))
		add(Ui.label("Collection", "HeadingLabel"))
		add(_grid(rest))
	add_back_button()


func _grid(ids: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	for id in ids:
		var tile := CardTile.new(id, true)
		tile.toggle_mode = true
		tile.set_pressed_no_signal(id == _selected)
		tile.evolution = id in Progress.deck_evolutions() and id in _deck
		tile.pressed.connect(func() -> void: _tapped(id))
		grid.add_child(tile)
	return grid


## The buttons for a card's details, which change with whether it is in the deck.
func _actions(id: String) -> Array:
	var actions := []
	if id in _deck:
		actions.append(["Take out of deck", _remove])
		if Progress.has_evolution(id):
			var on := id in Progress.deck_evolutions()
			actions.append(["Evolution off" if on else "Evolution on", func() -> void: _toggle_evolution(not on)])
	else:
		actions.append(["Add to deck" if _deck.size() < _size else "Swap into deck", _use])
	if not Progress.has_evolution(id) and Progress.injections() > 0 and id in Progress.evolvable_cards():
		actions.append(["Use an Evolution Injection", _inject])
	if Progress.wild_cards() > 0 and int(Progress.card(id).level) < Progress.max_card_level():
		actions.append(["Use wild cards", _wild])
	return actions


## Tapping a deck card while another card waits to be swapped in makes the swap. Any other tap opens the card's details.
func _tapped(id: String) -> void:
	if _swap_in != "" and id in _deck:
		_deck[_deck.find(id)] = _swap_in
		_swap_in = ""
		_selected = ""
		_save()
		_rebuild()
		return
	_selected = id
	_detail = CardDetail.new(id, _actions(id))
	add_child(_detail)


func _use() -> void:
	if _deck.size() < _size:
		_deck.append(_selected)
		_selected = ""
		_save()
	else:
		_swap_in = _selected
		Nav.toast("Tap a deck card to swap it out")
	_rebuild()


func _remove() -> void:
	_deck.erase(_selected)
	_selected = ""
	_rebuild()


func _toggle_evolution(on: bool) -> void:
	if not Progress.set_deck_evolution(_selected, on):
		Nav.toast("Only %d evolutions per deck" % int(Data.table("battle").evolution.max_per_deck))
	_rebuild()


func _inject() -> void:
	Progress.use_injection(_selected)
	_rebuild()


func _wild() -> void:
	Progress.use_wild_cards(_selected)
	_rebuild()


func _save() -> void:
	if _deck.size() == _size:
		Save.set_value("deck", _deck.duplicate())


## Rebuilds the whole screen from the current state, which keeps every label and tile in step after a change.
func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	build()


func go_back() -> bool:
	if _deck.size() != _size:
		Nav.toast("Your deck needs %d cards, so the last full deck is kept" % _size)
	Nav.go(MENU_SCENE)
	return true
