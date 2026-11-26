extends Screen
## The Foundation road: every Lab and Site, with the last one at the top and the first at the bottom, with the reputation each one needs
## and the anomalies that turn up in chests from there on. Your place on the road is marked, and the screen opens on it.
## Cards from places you have not reached yet are drawn in grey. Tap any card to see what it does.
## Your place has a bar showing how close you are to the next one.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const COLUMNS := 4

var _detail: CardDetail = null


func build() -> void:
	add(Ui.label("Foundation road", "TitleLabel"))
	var here := Progress.arena()
	add(Ui.label("You are at %s with %d reputation. Win battles to earn more and rank up through the ELND Foundation." % [Progress.arena_name(here), Progress.reputation()], "MutedLabel"))
	var by_place := _cards_by_place()
	var marker: Control = null
	for place in range(Progress.arena_count(), 0, -1):
		add(Ui.spacer(24))
		var heading := Ui.label(Progress.arena_name(place), "HeadingLabel")
		if place == here:
			heading.add_theme_color_override("font_color", Settings.palette().accent)
			marker = heading
		add(heading)
		add(Ui.label(_status(place, here), "MutedLabel"))
		if place == here:
			add(ReputationBar.new(Progress.reputation()))
		var ids: Array = by_place.get(place, [])
		if ids.is_empty():
			add(Ui.label("No new anomalies here yet.", "MutedLabel"))
			continue
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		for id in ids:
			var tile := CardTile.new(id)
			tile.locked = place > here
			tile.enable_gestures()
			tile.tapped.connect(func() -> void: _open(id))
			grid.add_child(tile)
		add(grid)
	if marker != null:
		_scroll_to.call_deferred(marker)


## How far a place is: where you are, already reached, or how much reputation is still needed.
static func _status(place: int, here: int) -> String:
	var needed := Progress.reputation_for(place)
	if place == here:
		return "%d reputation. You are here." % needed
	if place < here:
		return "%d reputation. Reached." % needed
	return "%d reputation. %d more to go." % [needed, needed - Progress.reputation()]


## Every collectable card grouped by the place that unlocks it, in card number order. Neutralized cards stay hidden.
static func _cards_by_place() -> Dictionary:
	var cards: Dictionary = Data.table("cards").cards
	var groups := {}
	for id in cards:
		var card: Dictionary = cards[id]
		if BattleSim.is_collectable(card) and not card.get("neutralized", false):
			groups.get_or_add(int(card.get("unlock_arena", 1)), []).append(id)
	for place in groups:
		groups[place].sort_custom(func(a: String, b: String) -> bool: return int(cards[a].number) < int(cards[b].number))
	return groups


## Opens on your place on the road, a little above it so the cards just reached are in view.
func _scroll_to(node: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(node) and scroll_box != null:
		scroll_box.scroll_vertical = int(maxf(node.position.y - 200.0, 0.0))


func _open(id: String) -> void:
	_detail = CardDetail.new(id, [])
	add_child(_detail)


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
