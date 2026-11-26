extends Screen
## Admin Mode's progression and balance tools: give anything, open any chest, unlock everything,
## neutralize cards, edit any card or tower, swap whole balance setups, and reset progress. Only reachable with Admin Mode on.

const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"
const CONFIRM_MS := 3000
const KEEP_PLAYABLE := "At least %d playable cards, one of them a troop, have to stay."

var _reset_asked_at := -CONFIRM_MS
var _query := ""
var _category := ""
var _found := Ui.label("", "MutedLabel")
var _results := VBoxContainer.new()
## The list stays empty until something is searched for, a category is picked, or Show all is pressed.
var _show_all := false
var _show_button: Button


func build() -> void:
	add(Ui.label("Admin tools", "TitleLabel"))
	_show_results()

	_section("Give")
	_give("1000 gold", func() -> void: Progress.add_gold(1000))
	_give("1000 XP", func() -> void: Progress.add_xp(1000))
	_give("100 reputation", func() -> void: Save.set_value("reputation", Progress.reputation() + 100))
	_give("Take 100 reputation", func() -> void: Save.set_value("reputation", maxi(Progress.reputation() - 100, 0)))
	_give("10 wild cards", func() -> void: Save.set_value("wild_cards", Progress.wild_cards() + 10))
	_give("1 Evolution Injection", func() -> void: Progress.add_injection())
	_give("Every card one level up", _level_all)
	_give("Unlock everything", _unlock_everything)

	_section("Open a chest")
	for rarity in Data.table("chests").odds.keys() + [Progress.INJECTION_CHEST]:
		add(Ui.button("%s chest" % String(rarity).capitalize(), func() -> void: _open(rarity)))

	_section("Neutralize")
	add(Ui.label("Neutralized cards leave every deck, the bot's included, until switched back. Search by name or by kind, such as flying, ranged or spell, or pick a category.", "MutedLabel"))
	add(Ui.search("Search cards", _on_search))
	add(Ui.strip(CardSearch.CATEGORIES, _category, _on_category))
	var bulk := HBoxContainer.new()
	bulk.add_child(Ui.button("Neutralize shown", func() -> void: _neutralize_shown(true)))
	bulk.add_child(Ui.button("Restore shown", func() -> void: _neutralize_shown(false)))
	add(bulk)
	_show_button = Ui.button("Show all", _toggle_show_all)
	add(_show_button)
	add(_found)
	add(_results)

	_section("Edit cards")
	add(CardEditor.new())

	_section("Balance")
	add(Ui.button("Export balance", func() -> void: Backup.export_balance(Nav.toast)))
	add(Ui.button("Import balance", func() -> void: Backup.import_balance(Nav.toast)))
	add(Ui.button("Reset all balance to default", _reset_balance))

	_section("Progress")
	add(Ui.button("Reset progress", _reset_progress))


func _section(title: String) -> void:
	add(Ui.spacer(12))
	add(Ui.label(title, "HeadingLabel"))


func _give(text: String, action: Callable) -> void:
	add(Ui.button(text, func() -> void: _do(action, text)))


func _do(action: Callable, text: String) -> void:
	action.call()
	Nav.toast(text + " done")


func _level_all() -> void:
	for id in Data.table("cards").cards:
		var card := Progress.card(id)
		Progress.add_copies(id, maxi(Progress.copies_for_next(maxi(int(card.level), 1)) - int(card.copies), 0))


## Unlocks every evolution and raises reputation to the arena that unlocks the last card.
func _unlock_everything() -> void:
	var top_arena := 1
	for id in Data.table("cards").cards:
		top_arena = maxi(top_arena, int(Data.table("cards").cards[id].get("unlock_arena", 1)))
	var needed := (top_arena - 1) * int(Data.table("progression").reputation.per_arena)
	Save.set_value("reputation", maxi(Progress.reputation(), needed))
	var all_evolutions := Progress.evolvable_cards()
	Save.set_value("evolutions", all_evolutions)


## Queues a chest of exactly this rarity and opens it straight away, which is how chest animations get tested.
func _open(rarity: String) -> void:
	Progress.queue_chest(rarity)
	var waiting := Progress.chests_waiting().duplicate()
	waiting.push_front(waiting.pop_back())
	Save.set_value("chests_waiting", waiting)
	Nav.go(CHEST_SCENE)


func _on_search(text: String) -> void:
	_query = text
	_show_results()


func _on_category(tag: String) -> void:
	_category = tag
	_show_results()


func _toggle_show_all() -> void:
	_show_all = not _show_all
	_show_button.text = "Hide all" if _show_all else "Show all"
	_show_results()


## Cards listed right now: none until something is searched for, a category is picked, or Show all is on.
func _listed() -> Array:
	if not _show_all and _query.strip_edges() == "" and _category == "":
		return []
	return CardSearch.find(_query, _category)


## Lists every card that fits the search, each with its tags and its own switch.
func _show_results() -> void:
	for child in _results.get_children():
		child.queue_free()
	var ids := _listed()
	if ids.is_empty() and not _show_all and _query.strip_edges() == "" and _category == "":
		_found.text = "Search, pick a category or press Show all to list cards."
		return
	var off := ids.filter(func(id: String) -> bool: return _is_neutralized(id)).size()
	_found.text = "Showing %d of %d cards, %d of them neutralized." % [ids.size(), Data.table("cards").cards.size(), off]
	for id in ids:
		var text := "%s\n%s" % [Data.table("cards").cards[id].name, CardSearch.describe(id)]
		_results.add_child(Ui.toggle(text, _is_neutralized(id), func(on: bool) -> void: _switch(id, on)))


func _switch(id: String, on: bool) -> void:
	if not _neutralize(id, on):
		Nav.toast(KEEP_PLAYABLE % _min_playable())
	_show_results()


func _neutralize_shown(on: bool) -> void:
	var count := 0
	var refused := false
	for id in _listed():
		if _is_neutralized(id) == on:
			continue
		if _neutralize(id, on):
			count += 1
		else:
			refused = true
	var done := "%s %d cards." % ["Neutralized" if on else "Restored", count]
	if refused:
		done += " " + KEEP_PLAYABLE % _min_playable()
	Nav.toast(done)
	_show_results()


static func _is_neutralized(id: String) -> bool:
	return bool(Data.table("cards").cards[id].get("neutralized", false))


## A hand needs this many cards, so battles always have something to play.
static func _min_playable() -> int:
	return int(Data.table("battle").deck.hand)


## Switches one card and returns true, unless taking it out would leave too few playable cards or no troops,
## which would leave battles and Defense waves with nothing to use.
static func _neutralize(id: String, on: bool) -> bool:
	if not on:
		Data.reset_override("cards", ["cards", id, "neutralized"])
		return true
	var rest := BattleSim.available_cards()
	rest.erase(id)
	var cards: Dictionary = Data.table("cards").cards
	var has_troop := rest.any(func(other: String) -> bool: return cards[other].type == "troop")
	if rest.size() < _min_playable() or not has_troop:
		return false
	Data.set_override("cards", ["cards", id, "neutralized"], true)
	return true


func _reset_balance() -> void:
	Data.replace_overrides({})
	Nav.toast("Balance back to default")


## Wiping progress asks for a second tap within a few seconds, which means it never happens by accident.
func _reset_progress() -> void:
	var now := Time.get_ticks_msec()
	if now - _reset_asked_at > CONFIRM_MS:
		_reset_asked_at = now
		Nav.toast("Tap again to wipe all progress")
		return
	Save.replace_all({})
	Nav.toast("Progress reset")


func go_back() -> bool:
	Nav.go(SETTINGS_SCENE)
	return true
