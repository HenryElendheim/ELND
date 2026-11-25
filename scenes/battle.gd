extends Control
## The battle screen. Pick a card from the hand, then tap your half of the arena to play it.
## The simulation runs on fixed ticks, and the screen only redraws between them.

const MENU_SCENE := "res://scenes/main_menu.tscn"
## Caps how many ticks can run in one frame, which stops a slow frame from snowballing into a freeze.
const MAX_STEPS_PER_FRAME := 8
const RATE_NAMES := {2.0: "Double Ephrocity", 3.0: "Triple Ephrocity"}

var sim := BattleSim.new()
var speed := 1.0
## When Admin Mode picks a card here, taps drop that card for free on the chosen side instead of playing from the hand.
var spawn_card := ""
var spawn_team := Unit.Team.PLAYER

var _view := ArenaView.new()
var _meter := EphrocityMeter.new()
var _admin: AdminPanel
var _accumulator := 0.0
var _slot := -1
var _slot_buttons: Array[Button] = []
var _next_label: Label
var _rate := 1.0


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
	top.add_child(Ui.button("Back", go_back))
	if Settings.get_value("admin_mode"):
		_admin = AdminPanel.new(self, _view)
		top.add_child(Ui.button("Admin", func() -> void: _admin.visible = not _admin.visible))
	column.add_child(top)

	_view.sim = sim
	_view.tapped.connect(_on_tapped)
	column.add_child(_view)
	column.add_child(_build_hand())
	_meter.hand = sim.hands[Unit.Team.PLAYER]
	column.add_child(_meter)

	if _admin != null:
		_admin.visible = false
		add_child(_admin)
	Data.changed.connect(sim.refresh_stats)


## Four card buttons and a small label for the card that comes in next.
func _build_hand() -> Control:
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for slot in 4:
		var card := Ui.button("", func() -> void: _select(slot))
		card.toggle_mode = true
		card.button_group = group
		card.custom_minimum_size.y = 150
		_slot_buttons.append(card)
		row.add_child(card)
	_next_label = Ui.label("", "MutedLabel")
	_next_label.size_flags_horizontal = SIZE_FILL
	_next_label.custom_minimum_size.x = 140
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_next_label)
	return row


func _process(delta: float) -> void:
	_accumulator = minf(_accumulator + delta * speed, sim.tick * MAX_STEPS_PER_FRAME)
	while _accumulator >= sim.tick:
		sim.step()
		_accumulator -= sim.tick
	_view.blend = _accumulator / sim.tick
	_view.queue_redraw()
	_meter.queue_redraw()
	_refresh_hand()
	_announce_rate()


## Shows each card's short name and cost, and dims the ones that cannot be paid for yet.
func _refresh_hand() -> void:
	var hand := sim.hands[Unit.Team.PLAYER]
	var cards := hand.in_hand()
	for slot in _slot_buttons.size():
		var card := _slot_buttons[slot]
		card.visible = slot < cards.size()
		if not card.visible:
			continue
		card.text = "%s\n%d" % [_short_name(cards[slot]), Hand.cost_of(cards[slot])]
		card.modulate.a = 1.0 if hand.can_afford(slot) else 0.5
	var next := hand.next_card()
	_next_label.text = "Next\n" + _short_name(next) if next != "" else ""


## Tells the player when Ephrocity starts filling faster, with a short buzz if vibration is on.
func _announce_rate() -> void:
	var rate := sim.ephrocity_rate()
	if rate == _rate:
		return
	_rate = rate
	if RATE_NAMES.has(rate):
		Nav.toast(RATE_NAMES[rate])
		if Settings.get_value("vibration"):
			Input.vibrate_handheld(200)


func _select(slot: int) -> void:
	_slot = slot if _slot_buttons[slot].button_pressed else -1


func _on_tapped(tile: Vector2) -> void:
	if spawn_card != "":
		sim.spawn(spawn_card, spawn_team, tile)
		return
	if _slot == -1:
		return
	var hand := sim.hands[Unit.Team.PLAYER]
	if not hand.can_afford(_slot):
		Nav.toast("Not enough Ephrocity")
	elif not sim.can_place(Unit.Team.PLAYER, tile):
		Nav.toast("You can only place on your side")
	elif sim.play(Unit.Team.PLAYER, _slot, tile):
		_slot_buttons[_slot].button_pressed = false
		_slot = -1


static func _short_name(card_id: String) -> String:
	return Data.table("cards").cards[card_id].name.trim_prefix("The ") if card_id != "" else ""


## Removes every troop and building but leaves the towers standing.
func clear_troops() -> void:
	for unit in sim.units:
		if not unit.is_tower():
			unit.hp = 0.0
	sim.drop_dead()


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true


func _exit_tree() -> void:
	Data.changed.disconnect(sim.refresh_stats)
	sim.clear()
