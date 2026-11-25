extends Screen
## Admin Mode's progression and balance tools: give anything, open any chest, unlock everything,
## neutralize cards, swap whole balance setups, and reset progress. Only reachable with Admin Mode on.

const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"
const CONFIRM_MS := 3000

var _reset_asked_at := -CONFIRM_MS


func build() -> void:
	add(Ui.label("Admin tools", "TitleLabel"))

	_section("Give")
	_give("1000 gold", func() -> void: Progress.add_gold(1000))
	_give("1000 XP", func() -> void: Progress.add_xp(1000))
	_give("100 trophies", func() -> void: Save.set_value("trophies", Progress.trophies() + 100))
	_give("Take 100 trophies", func() -> void: Save.set_value("trophies", maxi(Progress.trophies() - 100, 0)))
	_give("10 wild cards", func() -> void: Save.set_value("wild_cards", Progress.wild_cards() + 10))
	_give("1 Evolution Injection", func() -> void: Progress.add_injection())
	_give("Every card one level up", _level_all)
	_give("Unlock everything", _unlock_everything)

	_section("Open a chest")
	for rarity in Data.table("chests").odds:
		add(Ui.button("%s chest" % String(rarity).capitalize(), func() -> void: _open(rarity)))

	_section("Neutralize")
	add(Ui.label("Neutralized cards leave every deck, the bot's included, until switched back.", "MutedLabel"))
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		add(Ui.toggle(cards[id].name, cards[id].get("neutralized", false), func(on: bool) -> void: _neutralize(id, on)))

	_section("Balance")
	add(Ui.button("Export balance", func() -> void: Backup.export_balance(Nav.toast)))
	add(Ui.button("Import balance", func() -> void: Backup.import_balance(Nav.toast)))
	add(Ui.button("Reset all balance to default", _reset_balance))

	_section("Progress")
	add(Ui.button("Reset progress", _reset_progress))
	add(Ui.spacer(24))
	add(Ui.button("Back", go_back))


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


## Unlocks every evolution and raises trophies to the arena that unlocks the last card.
func _unlock_everything() -> void:
	var top_arena := 1
	for id in Data.table("cards").cards:
		top_arena = maxi(top_arena, int(Data.table("cards").cards[id].get("unlock_arena", 1)))
	var needed := (top_arena - 1) * int(Data.table("progression").trophies.per_arena)
	Save.set_value("trophies", maxi(Progress.trophies(), needed))
	var all_evolutions := Progress.evolvable_cards()
	Save.set_value("evolutions", all_evolutions)


## Queues a chest of exactly this rarity and opens it straight away, which is how chest animations get tested.
func _open(rarity: String) -> void:
	Progress.queue_chest(rarity)
	var waiting := Progress.chests_waiting().duplicate()
	waiting.push_front(waiting.pop_back())
	Save.set_value("chests_waiting", waiting)
	Nav.go(CHEST_SCENE)


func _neutralize(id: String, on: bool) -> void:
	if on:
		Data.set_override("cards", ["cards", id, "neutralized"], true)
	else:
		Data.reset_override("cards", ["cards", id, "neutralized"])


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
