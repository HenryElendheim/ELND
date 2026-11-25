extends Control
## The battle screen. For now it is a sandbox: pick a troop and a side, then tap the arena to drop it in.
## The simulation runs on fixed ticks, and the screen only redraws between them.

const MENU_SCENE := "res://scenes/main_menu.tscn"
## Caps how many ticks can run in one frame, which stops a slow frame from snowballing into a freeze.
const MAX_STEPS_PER_FRAME := 8

var sim := BattleSim.new()
var speed := 1.0

var _view := ArenaView.new()
var _admin: AdminPanel
var _accumulator := 0.0
var _card := ""
var _team := Unit.Team.PLAYER
var _side_button: Button


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 64)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_child(Ui.button("Back", go_back))
	_side_button = Ui.button("", _switch_side)
	top.add_child(_side_button)
	_show_side()
	if Settings.get_value("admin_mode"):
		_admin = AdminPanel.new(self, _view)
		top.add_child(Ui.button("Admin", func() -> void: _admin.visible = not _admin.visible))
	column.add_child(top)

	_view.sim = sim
	_view.tapped.connect(_on_tapped)
	column.add_child(_view)

	var troops := []
	var cards: Dictionary = Data.table("cards").cards
	for id in cards:
		if cards[id].get("type") == "troop":
			troops.append([id, cards[id].name.trim_prefix("The ")])
	_card = troops[0][0]
	column.add_child(Ui.strip(troops, _card, func(id: String) -> void: _card = id))

	if _admin != null:
		_admin.visible = false
		add_child(_admin)
	Data.changed.connect(sim.refresh_stats)


func _process(delta: float) -> void:
	_accumulator = minf(_accumulator + delta * speed, sim.tick * MAX_STEPS_PER_FRAME)
	while _accumulator >= sim.tick:
		sim.step()
		_accumulator -= sim.tick
	_view.blend = _accumulator / sim.tick
	_view.queue_redraw()


## Without Admin Mode each side can only place on its own half. Admin Mode allows any spot.
func _on_tapped(tile: Vector2) -> void:
	var arena: Dictionary = Data.table("battle").arena
	if tile.x < 0 or tile.y < 0 or tile.x > float(arena.width_tiles) or tile.y > float(arena.length_tiles):
		return
	var own_half := tile.y > float(arena.river_bottom) if _team == Unit.Team.PLAYER else tile.y < float(arena.river_top)
	if own_half or Settings.get_value("admin_mode"):
		sim.spawn(_card, _team, tile)


func _switch_side() -> void:
	_team = Unit.Team.ENEMY if _team == Unit.Team.PLAYER else Unit.Team.PLAYER
	_show_side()


func _show_side() -> void:
	_side_button.text = "Placing: You" if _team == Unit.Team.PLAYER else "Placing: Enemy"


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
