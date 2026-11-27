extends Screen
## The Cards screen. At the top you pick one of your decks, and the one picked last is the one battles use.
## The deck sits below as two rows of four tiles, each with its level above it and its copies bar below,
## then the average Ephrocity cost and tower level, then your collection and the cards still locked,
## which you can sort and filter by cost, rarity, kind and more. Tapping the sort in use again flips its order.
## Tap a card to open its details, with its stats, how it works and its Codex entry,
## and the buttons to add it, swap it in, take it out, put it in the evolution slot or spend wild cards.
## Hold a deck card still for a moment to pick it up, then drop it on another deck card to swap them.
## Swiping that starts on a card still scrolls the list.
## The first place in the deck is the evolution slot. A card there whose evolution is unlocked is the deck's only evolution.
## A deck is saved whenever it has exactly the right number of cards.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const COLUMNS := 4
const SORTS := [["cost", "Cost"], ["rarity", "Rarity"], ["type", "Type"], ["name", "Name"], ["number", "ELND"]]
## How the picked sort says which way it goes, first for highest first and then for lowest first.
const ORDER_NAMES := {
	"cost": ["high first", "low first"],
	"rarity": ["rarest first", "commonest first"],
	"type": ["spells first", "troops first"],
	"name": ["Z first", "A first"],
	"number": ["high first", "low first"],
}
const TYPE_ORDER := ["troop", "building", "spell"]

var _deck := []
var _size := 8
var _selected := ""
var _detail: CardDetail = null
## A collection card waiting to be swapped in. The next deck card tapped is the one it replaces.
var _swap_in := ""
## The deck tiles on screen, so a card being carried knows which one it is over.
var _deck_tiles: Array[CardTile] = []
## The card being carried after a hold, the copy of it that follows the finger, and the deck place under it.
var _carrying := ""
## The sideways sort row, kept so a rebuild can put it back where it was scrolled to.
var _sort_row: ScrollContainer = null
var _ghost: CardTile = null
var _hover := -1


func build() -> void:
	_size = int(Data.table("battle").deck.size)
	if _deck.is_empty():
		_deck = BattleSim.valid_deck(Progress.decks()[Progress.active_deck()]).duplicate()
	add(Ui.label("Cards", "TitleLabel"))

	var choices := []
	for i in Progress.deck_slots():
		choices.append([i, "Deck %d" % (i + 1)])
	add(Ui.choice("Your decks. The one picked last is used in battle.", choices, Progress.active_deck(), _pick_deck, choices.size()))

	add(Ui.label("Deck  %d of %d" % [_deck.size(), _size], "HeadingLabel"))
	add(Ui.label("The first card sits in the evolution slot. If you have its evolution, it is the only evolution in your deck. Hold a card to move it.", "MutedLabel"))
	_deck_tiles.clear()
	add(_grid(_deck, true))
	var costs := 0.0
	for id in _deck:
		costs += Hand.cost_of(id)
	var average := costs / maxf(_deck.size(), 1)
	add(Ui.label("Average cost %.1f     Towers level %d" % [average, Progress.tower_level()]))

	add(Ui.spacer(12))
	add(Ui.label("Collection", "HeadingLabel"))
	add(Ui.label("Sort by", "MutedLabel"))
	_sort_row = add(Ui.strip(_sort_options(), Settings.get_value("collection_sort"), _on_sort)) as ScrollContainer
	add(_filter_row())
	var rest := _shown(BattleSim.available_cards().filter(func(id: String) -> bool: return not id in _deck))
	if rest.is_empty():
		add(Ui.label("No cards here.", "MutedLabel"))
	else:
		add(_grid(rest, false))

	var locked := _shown(_locked_cards())
	if not locked.is_empty():
		add(Ui.spacer(12))
		add(Ui.label("Locked", "HeadingLabel"))
		add(Ui.label("These turn up in chests once you reach their Lab or Site. The Foundation road on the Battle page shows where each one is.", "MutedLabel"))
		var grid := _new_grid()
		for id in locked:
			var tile := CardTile.new(id, true)
			tile.locked = true
			tile.enable_gestures()
			tile.tapped.connect(func() -> void: _peek(id))
			grid.add_child(tile)
		add(grid)


## The Filter button, which opens the filter view, with an X beside it while any filter is on.
func _filter_row() -> Control:
	var row := HBoxContainer.new()
	var picked := _picked_filters()
	var names := picked.map(func(tag: String) -> String: return CardSearch.category_name(tag))
	var text := "Filter" if picked.is_empty() else "Filter: %s" % ", ".join(names)
	var open := Ui.button(text, func() -> void: add_child(FilterPicker.new(_picked_filters(), _on_filters)))
	open.clip_text = true
	row.add_child(open)
	if not picked.is_empty():
		var clear := Ui.button("X", func() -> void: _on_filters([]))
		clear.size_flags_horizontal = SIZE_FILL
		clear.custom_minimum_size.x = 130
		row.add_child(clear)
	return row


static func _picked_filters() -> Array:
	var picked: Variant = Settings.get_value("collection_filters")
	return picked if picked is Array else []


func _on_filters(picked: Array) -> void:
	Settings.set_value("collection_filters", picked)
	_rebuild()


## The sort buttons. The one in use says which way it goes, such as "Cost: high first", and tapping it flips it.
static func _sort_options() -> Array:
	var current: String = Settings.get_value("collection_sort")
	var ways: Array = ORDER_NAMES.get(current, ["", ""])
	var way: String = ways[0 if Settings.get_value("collection_descending") else 1]
	return SORTS.map(func(option: Array) -> Array: return [option[0], "%s: %s" % [option[1], way] if option[0] == current else option[1]])


## Cards that fit the picked filters, in the picked order.
func _shown(ids: Array) -> Array:
	var picked := _picked_filters()
	var found := ids.filter(func(id: String) -> bool: return CardSearch.fits(id, picked))
	found.sort_custom(_before)
	return found


## Whether one card goes before another in the picked order. Highest first is simply lowest first turned around.
func _before(a: String, b: String) -> bool:
	return _ahead(b, a) if Settings.get_value("collection_descending") else _ahead(a, b)


## Lowest first in the picked order, with the card number deciding ties.
func _ahead(a: String, b: String) -> bool:
	var cards: Dictionary = Data.table("cards").cards
	var first: Dictionary = cards[a]
	var second: Dictionary = cards[b]
	var x := 0.0
	var y := 0.0
	match Settings.get_value("collection_sort"):
		"cost":
			x = float(first.cost)
			y = float(second.cost)
		"rarity":
			x = float(first.threat)
			y = float(second.threat)
		"type":
			x = TYPE_ORDER.find(first.type) * 100.0 + float(first.cost)
			y = TYPE_ORDER.find(second.type) * 100.0 + float(second.cost)
		"name":
			if first.name != second.name:
				return String(first.name).naturalnocasecmp_to(String(second.name)) < 0
		"number":
			x = float(first.number)
			y = float(second.number)
	if x != y:
		return x < y
	return int(first.number) < int(second.number)


## Picking a new sort starts with the highest first, apart from names, which start at A.
## Picking the sort already in use flips it.
func _on_sort(mode: String) -> void:
	if mode == Settings.get_value("collection_sort"):
		Settings.set_value("collection_descending", not Settings.get_value("collection_descending"))
	else:
		Settings.set_value("collection_sort", mode)
		Settings.set_value("collection_descending", mode != "name")
	_rebuild()


## Switches to another deck. A deck that is not full yet keeps its last full version.
func _pick_deck(index: int) -> void:
	if index == Progress.active_deck():
		return
	if _deck.size() != _size:
		Nav.toast("That deck was not full, so its last full version is kept")
	Progress.select_deck(index)
	_deck = BattleSim.valid_deck(Progress.decks()[index]).duplicate()
	_selected = ""
	_swap_in = ""
	_rebuild()


## Cards from later Labs and Sites. Neutralized cards stay hidden.
static func _locked_cards() -> Array:
	var cards: Dictionary = Data.table("cards").cards
	var found := []
	for id in cards:
		var card: Dictionary = cards[id]
		if BattleSim.is_collectable(card) and not card.get("neutralized", false) and int(card.get("unlock_arena", 1)) > Progress.arena():
			found.append(id)
	return found


## Opens a locked card's details with no buttons, since it cannot go in a deck yet.
func _peek(id: String) -> void:
	_detail = CardDetail.new(id, [])
	add_child(_detail)


func _new_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	return grid


func _grid(ids: Array, in_deck: bool) -> GridContainer:
	var grid := _new_grid()
	var evolutions := Progress.evolutions_in(_deck)
	for i in ids.size():
		var id: String = ids[i]
		var tile := CardTile.new(id, true)
		tile.enable_gestures()
		tile.set_pressed_no_signal(id == _selected)
		tile.evolution_slot = in_deck and i < Progress.evolution_slots()
		tile.evolution = id in evolutions
		tile.tapped.connect(func() -> void: _tapped(id))
		# Only deck cards can be held and moved. Collection cards go in with Add or Swap into deck.
		if in_deck:
			tile.held.connect(func() -> void: _pick_up(tile))
			_deck_tiles.append(tile)
		grid.add_child(tile)
	return grid


## Holding a card picks it up. A copy of it follows the finger until it is dropped.
func _pick_up(tile: CardTile) -> void:
	_carrying = tile.card_id
	Touch.holding = true
	_ghost = CardTile.new(_carrying)
	_ghost.top_level = true
	_ghost.mouse_filter = MOUSE_FILTER_IGNORE
	_ghost.size = tile.size * 0.9
	_ghost.global_position = tile.global_position
	_ghost.modulate.a = 0.85
	add_child(_ghost)
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(40)


## While a card is carried, it follows the finger, the deck card under it lights up, and letting go drops it there.
func _input(event: InputEvent) -> void:
	if _carrying == "" or Touch.cancelling:
		return
	if event is InputEventMouseMotion:
		_ghost.global_position = event.position - _ghost.size / 2.0
		_hover = _deck_place_at(event.position)
		for i in _deck_tiles.size():
			_deck_tiles[i].modulate = Color(1.35, 1.35, 1.35) if i == _hover else Color.WHITE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(_deck_place_at(event.position))
		get_viewport().set_input_as_handled()


func _deck_place_at(point: Vector2) -> int:
	for i in _deck_tiles.size():
		if _deck_tiles[i].get_global_rect().has_point(point):
			return i
	return -1


## Dropping on a deck card swaps the two. A deck card trades places, and a collection card takes that place in the deck.
## Dropping anywhere else puts the card back where it was.
func _drop(place: int) -> void:
	var id := _carrying
	_carrying = ""
	_hover = -1
	Touch.holding = false
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if place < 0 or place >= _deck.size() or _deck[place] == id:
		_rebuild()
		return
	var from := _deck.find(id)
	if from >= 0:
		_deck[from] = _deck[place]
	_deck[place] = id
	_save()
	_rebuild()


## The buttons for a card's details, which change with whether it is in the deck.
func _actions(id: String) -> Array:
	var actions := []
	if id in _deck:
		actions.append(["Remove", _remove])
		if Progress.has_evolution(id) and _deck.find(id) >= Progress.evolution_slots():
			actions.append(["Move to evolution slot", _to_evolution_slot])
	else:
		actions.append(["Add" if _deck.size() < _size else "Swap into deck", _use])
		if Progress.has_evolution(id):
			actions.append(["Put in evolution slot", _to_evolution_slot])
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


## A deck card trades places with the card in the evolution slot. A collection card takes the slot,
## and the card it replaces goes back to the collection, unless the deck still has room for it.
func _to_evolution_slot() -> void:
	var at := _deck.find(_selected)
	if at >= 0:
		_deck[at] = _deck[0]
		_deck[0] = _selected
	elif _deck.size() < _size:
		_deck.push_front(_selected)
	else:
		_deck[0] = _selected
	_selected = ""
	_save()
	_rebuild()


func _inject() -> void:
	Progress.use_injection(_selected)
	_rebuild()


## Spends wild cards on the card. When that levels it up, the level up celebration plays over the screen.
func _wild() -> void:
	var id := _selected
	var before := int(Progress.card(id).level)
	var gold := Progress.gold()
	Progress.use_wild_cards(id)
	_rebuild()
	var after := int(Progress.card(id).level)
	if after > before:
		add_child(LevelUp.new(id, before, after, Progress.gold() - gold))
	else:
		Nav.toast("Wild cards added to %s" % Data.table("cards").cards[id].name)


func _save() -> void:
	if _deck.size() == _size:
		Progress.save_deck(Progress.active_deck(), _deck)


## Rebuilds the whole screen from the current state, which keeps every label and tile in step after a change.
## The screen and the sort row stay scrolled where they were, so whatever was just tapped is still in view.
func _rebuild() -> void:
	var down := scroll_box.scroll_vertical
	var along := _sort_row.scroll_horizontal if is_instance_valid(_sort_row) else 0
	for child in content.get_children():
		child.queue_free()
	build()
	_restore_scroll.call_deferred(down, along)


func _restore_scroll(down: int, along: int) -> void:
	await get_tree().process_frame
	scroll_box.scroll_vertical = down
	if is_instance_valid(_sort_row):
		_sort_row.scroll_horizontal = along


## Leaving the screen never leaves a card stuck to the finger.
func _exit_tree() -> void:
	Touch.holding = false


func go_back() -> bool:
	if _deck.size() != _size:
		Nav.toast("Your deck needs %d cards, so the last full deck is kept" % _size)
	Nav.go(MENU_SCENE)
	return true
