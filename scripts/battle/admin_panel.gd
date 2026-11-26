class_name AdminPanel
extends PanelContainer
## The basic Admin Mode tools shown over the lower part of the battle screen:
## time controls, debug overlays, clearing the field, and live stat editing for every card and tower.

const SPEEDS := [[0.0, "Pause"], [0.25, "0.25x"], [0.5, "0.5x"], [1.0, "1x"], [2.0, "2x"]]
const SIDES := [[Unit.Team.PLAYER, "You"], [Unit.Team.ENEMY, "Enemy"]]
const OVERLAYS := [["Hitboxes", "show_hitboxes"], ["Attack ranges", "show_ranges"], ["Targeting lines", "show_targets"], ["FPS", "show_fps"]]

var _battle: Node
var _view: ArenaView


func _init(battle: Node, view: ArenaView) -> void:
	_battle = battle
	_view = view


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	anchor_top = 0.45
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	DragScroll.attach(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)

	var header := HBoxContainer.new()
	header.add_child(Ui.label("Admin Mode", "HeadingLabel"))
	var close := Ui.button("Close", hide)
	close.size_flags_horizontal = SIZE_FILL
	header.add_child(close)
	column.add_child(header)

	column.add_child(Ui.choice("Speed", SPEEDS, _battle.get("speed"), func(value: float) -> void: _battle.set("speed", value)))

	# The spawn tool drops any card anywhere for free, on either side, locked cards included.
	var troops := [["", "Off"]]
	for id in CardSearch.find("", ""):
		troops.append([id, CardTile.short_name(id)])
	column.add_child(Ui.label("Spawn tool", "MutedLabel"))
	column.add_child(Ui.strip(troops, "", func(id: String) -> void: _battle.set("spawn_card", id)))
	column.add_child(Ui.choice("Spawn for", SIDES, Unit.Team.PLAYER, func(team: int) -> void: _battle.set("spawn_team", team)))
	var sim: BattleSim = _battle.get("sim")
	column.add_child(Ui.toggle("Bot plays", true, func(on: bool) -> void: sim.bot.enabled = on))
	var hands: Array = sim.hands
	for side in SIDES:
		var hand: Hand = hands[side[0]]
		column.add_child(Ui.toggle("Endless Ephrocity: " + side[1], false, func(on: bool) -> void: hand.infinite = on))
	for overlay in OVERLAYS:
		column.add_child(Ui.toggle(overlay[0], _view.get(overlay[1]), func(on: bool) -> void: _view.set(overlay[1], on)))
	column.add_child(Ui.button("Clear troops", Callable(_battle, "clear_troops")))
	column.add_child(Ui.button("Give an Evolution Injection", _give_injection))

	column.add_child(Ui.label("Edits save by themselves and stay in normal games too, until you reset them.", "MutedLabel"))
	column.add_child(Ui.button("Export balance", func() -> void: Backup.export_balance(Nav.toast)))
	column.add_child(CardEditor.new())


func _give_injection() -> void:
	Progress.add_injection()
	Nav.toast("Injection added")
