extends Control
## The battle screen. Pick a card from the hand, then tap your half of the arena to play it.
## The simulation runs on fixed ticks, and the screen only redraws between them.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"
## Caps how many ticks can run in one frame, which stops a slow frame from snowballing into a freeze.
const MAX_STEPS_PER_FRAME := 8
const RATE_NAMES := {2.0: "Double Ephrocity", 3.0: "Triple Ephrocity"}
const PHASE_NAMES := {"overtime": "Overtime", "tiebreaker": "Tiebreaker"}

var sim := BattleSim.new(Nav.params.get("mode", "battle"))
var speed := 1.0
## When Admin Mode picks a card here, taps drop that card for free on the chosen side instead of playing from the hand.
var spawn_card := ""
var spawn_team := Unit.Team.PLAYER

var _view := ArenaView.new()
var _meter := EphrocityMeter.new()
var _admin: AdminPanel
var _accumulator := 0.0
var _slot := -1
var _slot_buttons: Array[CardTile] = []
var _next_tile: CardTile
var _clock: Label
var _rate := 1.0
var _phase := "regular"
var _cores: Label
var _result_shown := false
var _confirm: PanelContainer = null
var _leaving := false
var _speed_before := 1.0
## The row of evolution ability buttons sits between the arena and the hand, on the right,
## which means it never covers the cards, the Ephrocity meter or the towers.
var _evo_row := HBoxContainer.new()
var _evo_units: Array[Unit] = []
## Says which card is the deck's evolution and how many more plays it needs, even while that card waits in the queue.
var _evo_status := Ui.label("", "MutedLabel")


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 64)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_child(Ui.button("Back", func() -> void: go_back()))
	_clock = Ui.label("", "HeadingLabel")
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_clock)
	_cores = Ui.label("", "HeadingLabel")
	_cores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cores.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_cores)
	if Settings.get_value("admin_mode"):
		_admin = AdminPanel.new(self, _view)
		top.add_child(Ui.button("Admin", func() -> void: _admin.visible = not _admin.visible))
	column.add_child(top)

	_view.sim = sim
	_view.touch_started.connect(_on_touch)
	_view.touch_moved.connect(_on_touch)
	_view.touch_ended.connect(_on_release)
	column.add_child(_view)
	_evo_row.alignment = BoxContainer.ALIGNMENT_END
	var evo_bar := HBoxContainer.new()
	evo_bar.custom_minimum_size.y = 110
	_evo_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_evo_status.add_theme_color_override("font_color", CardTile.EVOLUTION_GLOW)
	evo_bar.add_child(_evo_status)
	evo_bar.add_child(_evo_row)
	column.add_child(evo_bar)
	column.add_child(_build_hand())
	_meter.hand = sim.hands[Unit.Team.PLAYER]
	column.add_child(_meter)

	if _admin != null:
		_admin.visible = false
		add_child(_admin)
	Data.changed.connect(sim.refresh_stats)
	sim.use_progress()


## Four card tiles and a smaller tile for the card that comes in next.
func _build_hand() -> Control:
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	_next_tile = CardTile.new()
	_next_tile.size_flags_horizontal = SIZE_FILL
	_next_tile.custom_minimum_size = Vector2(120, 170)
	_next_tile.size_flags_vertical = SIZE_SHRINK_END
	_next_tile.disabled = true
	row.add_child(_next_tile)
	for slot in 4:
		var card := CardTile.new()
		card.toggle_mode = true
		card.button_group = group
		card.pressed.connect(func() -> void: _select(slot))
		_slot_buttons.append(card)
		row.add_child(card)
	return row


func _process(delta: float) -> void:
	_accumulator = minf(_accumulator + delta * speed, sim.tick * MAX_STEPS_PER_FRAME)
	while _accumulator >= sim.tick:
		sim.step()
		_accumulator -= sim.tick
	_view.blend = _accumulator / sim.tick
	_view.take_events(delta)
	_view.queue_redraw()
	_meter.queue_redraw()
	_refresh_hand()
	_refresh_evolutions()
	_announce_rate()
	var left := ceili(sim.seconds_left())
	if sim.mode == "defense":
		_clock.text = "Wave %d" % sim.waves.wave
		_cores.text = ""
	else:
		_clock.text = "Tiebreaker" if sim.phase() == "tiebreaker" else "%d:%02d" % [left / 60, left % 60]
		_cores.text = "%d : %d" % [sim.towers_lost(Unit.Team.ENEMY), sim.towers_lost(Unit.Team.PLAYER)]
	if sim.phase() != _phase:
		_phase = sim.phase()
		Nav.toast(PHASE_NAMES.get(_phase, ""))
	if sim.result != "" and not _result_shown:
		_show_result()


## Covers the arena with the outcome and the core count, plus buttons to play again or leave.
func _show_result() -> void:
	_result_shown = true
	var defense := sim.mode == "defense"
	var reached := sim.waves.wave - 1 if defense else 0
	if defense:
		Progress.record_defense(reached)
	else:
		Progress.record_match(sim.result)
	Stats.record_match(sim.mode, sim.result, sim.towers_lost(Unit.Team.ENEMY), sim.played_cards, BattleSim.starting_deck(), sim.time)
	var titles := {"player": "Victory", "enemy": "Run over" if defense else "Defeat", "draw": "Draw"}
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	panel.custom_minimum_size.x = 800
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Ui.label(titles[sim.result], "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var summary := "Waves survived: %d" % reached if defense else "Cores %d : %d" % [sim.towers_lost(Unit.Team.ENEMY), sim.towers_lost(Unit.Team.PLAYER)]
	var cores := Ui.label(summary)
	cores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(cores)
	column.add_child(Ui.button("Open chest", func() -> void: Nav.go(CHEST_SCENE)))
	column.add_child(Ui.button("Menu", func() -> void: go_back()))
	add_child(panel)
	# The result pops in with a small overshoot, unless reduced motion is on.
	if not Settings.reduced_motion():
		panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
		panel.scale = Vector2.ONE * 0.6
		panel.modulate.a = 0.0
		var pop := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(panel, "scale", Vector2.ONE, 0.35)
		pop.tween_property(panel, "modulate:a", 1.0, 0.2)
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(300)


## Shows each card's short name and cost, and dims the ones that cannot be paid for yet.
func _refresh_hand() -> void:
	var hand := sim.hands[Unit.Team.PLAYER]
	var cards := hand.in_hand()
	for slot in _slot_buttons.size():
		var card := _slot_buttons[slot]
		card.visible = slot < cards.size()
		if not card.visible:
			continue
		card.card_id = cards[slot]
		card.evolution = hand.evolution_ready(slot)
		card.cycles_left = hand.cycles_left(cards[slot])
		card.modulate.a = 1.0 if hand.can_afford(slot) else 0.5
		card.queue_redraw()
	_next_tile.card_id = hand.next_card()
	_next_tile.cycles_left = hand.cycles_left(hand.next_card())
	_evo_status.text = _evolution_status(hand)
	_next_tile.modulate.a = 0.6
	_next_tile.queue_redraw()


## For example "Hobb evolves in 1 play" or "Hobb evolution ready". Empty when the deck has no evolution.
static func _evolution_status(hand: Hand) -> String:
	if hand.evolutions.is_empty():
		return ""
	var id: String = hand.evolutions[0]
	var left := hand.cycles_left(id)
	if left == 0:
		return "%s evolution ready" % CardTile.short_name(id)
	return "%s evolves in %d %s" % [CardTile.short_name(id), left, "play" if left == 1 else "plays"]


## Keeps one button per evolved group of yours on the field. Each shows the troop, the cost, or the seconds of cooldown left,
## and is dimmed while it cannot be used.
func _refresh_evolutions() -> void:
	var current := sim.evolution_buttons(Unit.Team.PLAYER)
	if current != _evo_units:
		_evo_units = current
		for child in _evo_row.get_children():
			child.queue_free()
		for unit in _evo_units:
			var button := Ui.button("", func() -> void: _use_evolution(unit))
			button.size_flags_horizontal = SIZE_FILL
			button.custom_minimum_size.x = 220
			button.clip_text = true
			_evo_row.add_child(button)
	var buttons := _evo_row.get_children().filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	for i in mini(buttons.size(), _evo_units.size()):
		var unit := _evo_units[i]
		var button: Button = buttons[i]
		var wait := ceili(unit.evolution_ready_at - sim.time)
		var cost := sim.evolution_cost(unit)
		button.text = "%s\n%s" % [CardTile.short_name(unit.id), "%ds" % wait if wait > 0 else "%d" % cost]
		var hand := sim.hands[Unit.Team.PLAYER]
		button.modulate.a = 1.0 if sim.evolution_ready(unit) and (hand.infinite or hand.ephrocity >= cost) else 0.5


func _use_evolution(unit: Unit) -> void:
	if sim.activate_evolution(unit):
		Sfx.play("evolve")
		if Settings.get_value("vibration"):
			Input.vibrate_handheld(60)


## Tells the player when Ephrocity starts filling faster, with a short buzz if vibration is on.
func _announce_rate() -> void:
	var rate := sim.ephrocity_rate()
	if rate == _rate:
		return
	_rate = rate
	if RATE_NAMES.has(rate):
		Nav.banner(RATE_NAMES[rate])
		_meter.flash()
		if Settings.get_value("vibration"):
			Input.vibrate_handheld(200)


func _select(slot: int) -> void:
	_slot = slot if _slot_buttons[slot].button_pressed else -1
	_show_placing()


## Tells the arena which card is being placed, so it can cover the tiles that are not allowed in red.
func _show_placing() -> void:
	_view.placing_card = spawn_card if spawn_card != "" else (sim.hands[Unit.Team.PLAYER].cards[_slot] if _slot >= 0 else "")
	_view.placing_team = spawn_team if spawn_card != "" else Unit.Team.PLAYER


## While a finger is down, the preview follows it from tile to tile.
func _on_touch(tile: Vector2) -> void:
	_show_placing()
	_view.preview_at = BattleSim.snap(tile) if _view.placing_card != "" else null


## Lifting the finger places the card on the tile under it, or explains in the middle of the screen why it cannot go there.
func _on_release(tile: Vector2) -> void:
	_view.preview_at = null
	var at := BattleSim.snap(tile)
	if spawn_card != "":
		sim.spawn(spawn_card, spawn_team, at)
		return
	if _slot == -1:
		return
	var hand := sim.hands[Unit.Team.PLAYER]
	if not hand.can_afford(_slot):
		Nav.banner("Not enough Ephrocity")
	elif not sim.can_place(Unit.Team.PLAYER, at, BattleSim.is_spell_card(hand.cards[_slot])):
		Nav.banner("You can't place that here")
	elif sim.play(Unit.Team.PLAYER, _slot, at):
		Sfx.play("play")
		_slot_buttons[_slot].button_pressed = false
		_slot = -1
		_show_placing()



## Removes every troop and building but leaves the towers standing.
func clear_troops() -> void:
	for unit in sim.units:
		if not unit.is_tower():
			unit.hp = 0.0
	sim.drop_dead()


## Back during a match pauses it and asks first. A match that is left counts as cancelled: no win, no loss,
## no reputation and no chest. Once the match is over, Back simply goes to the menu.
func go_back() -> bool:
	if sim.result != "" or _leaving:
		Nav.go(MENU_SCENE)
	elif _confirm != null:
		_keep_playing()
	else:
		_ask_to_leave()
	return true


func _ask_to_leave() -> void:
	_speed_before = speed
	speed = 0.0
	_confirm = PanelContainer.new()
	_confirm.set_anchors_preset(PRESET_CENTER)
	_confirm.grow_horizontal = GROW_DIRECTION_BOTH
	_confirm.grow_vertical = GROW_DIRECTION_BOTH
	_confirm.custom_minimum_size.x = 860
	var column := VBoxContainer.new()
	_confirm.add_child(column)
	var title := Ui.label("Leave this match?", "HeadingLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := Ui.label("It will count as cancelled, not as a win or a loss.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	column.add_child(Ui.button("Leave", _leave))
	column.add_child(Ui.button("Keep playing", _keep_playing))
	add_child(_confirm)


func _keep_playing() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
	speed = _speed_before


## Freezes the battle straight away, so nothing can finish while the screen fades, and records the match as cancelled.
func _leave() -> void:
	_leaving = true
	speed = 0.0
	Stats.record_cancel(sim.mode)
	Nav.go(MENU_SCENE)


func _exit_tree() -> void:
	Data.changed.disconnect(sim.refresh_stats)
	sim.clear()
