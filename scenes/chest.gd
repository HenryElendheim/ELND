extends Control
## Opens waiting chests one at a time. Tap the chest and it shakes while Ephrocity leaks out, longer for rarer chests.
## Its glow only turns to the rarity colour at the very last moment. A Legendary chest sets off a full containment breach.
## Then the cards come out one per tap, each popping in over a burst of light in its rarity colour.
## Rare cards flip in, Epic cards burst purple, and a Legendary card gets a white flash, spinning rays and a slam.
## A new card gets the codex stamp slammed onto it. Skipping, or reaching the end, shows every card the chest gave at once.
## Reduced motion skips the shaking, popping and spinning, while every card and colour still shows.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const WINE := Color("#A33B4C")
const TILE_SIZE := Vector2(300, 380)
const SUMMARY_TILE := Vector2(0, 250)
const RARITY_ORDER := ["legendary", "epic", "rare", "common"]

var _chest := ColorRect.new()
var _tile: CardTile
var _burst := Burst.new()
var _title: Label
var _detail: Label
var _stamp: Label
var _alarm := ColorRect.new()
var _flash := ColorRect.new()
var _skip: Button
var _summary: Control = null
var _opened := {}
var _reveal := -1
var _busy := false


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	for cover in [_alarm, _flash]:
		cover.set_anchors_preset(PRESET_FULL_RECT)
		cover.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(cover)
	_alarm.color = Color(0.7, 0, 0, 0)
	_flash.color = Color(1, 1, 1, 0)

	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 40)
	# The layout ignores taps so they reach this screen, and only the Skip button catches its own.
	column.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(column)
	_title = _centered(column, "TitleLabel")
	var holder := CenterContainer.new()
	holder.custom_minimum_size.y = 460
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(holder)
	_burst.custom_minimum_size = Vector2(460, 460)
	_burst.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(_burst)
	_chest.mouse_filter = MOUSE_FILTER_IGNORE
	_chest.custom_minimum_size = Vector2(360, 300)
	_chest.pivot_offset = _chest.custom_minimum_size / 2.0
	holder.add_child(_chest)
	_tile = CardTile.new()
	_tile.size_flags_horizontal = SIZE_SHRINK_CENTER
	_tile.custom_minimum_size = TILE_SIZE
	_tile.pivot_offset = TILE_SIZE / 2.0
	_tile.mouse_filter = MOUSE_FILTER_IGNORE
	_tile.visible = false
	holder.add_child(_tile)
	_detail = _centered(column, "HeadingLabel")
	_stamp = _centered(column, "HeadingLabel")
	_stamp.add_theme_color_override("font_color", WINE.lightened(0.3))
	_skip = Ui.button("Skip", _skip_to_end)
	_skip.size_flags_horizontal = SIZE_SHRINK_CENTER
	_skip.custom_minimum_size.x = 400
	column.add_child(_skip)
	_show_waiting()


func _centered(column: Container, variation: String) -> Label:
	var node := Ui.label("", variation)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(node)
	return node


## Shows the next closed chest, or goes back to the menu when none are left.
func _show_waiting() -> void:
	var waiting := Progress.chests_waiting()
	if waiting.is_empty():
		Nav.go(MENU_SCENE)
		return
	_opened = {}
	_reveal = -1
	_title.text = "%s chest" % String(waiting[0]).capitalize()
	_detail.text = "Tap to open"
	_stamp.text = ""
	_chest.color = Color("#2A2A33")
	_chest.rotation = 0.0
	_chest.visible = true
	_tile.visible = false
	_burst.strength = 0.0
	_burst.queue_redraw()
	_skip.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _busy and _summary == null:
		if _opened.is_empty():
			_open()
		else:
			_next_card()


## The build-up before the reveal. Rarer chests shake longer and harder, and Legendary ones go dark with alarm lights.
func _open() -> void:
	_busy = true
	_opened = Progress.open_next_chest()
	if _opened.is_empty():
		Nav.go(MENU_SCENE)
		return
	var rarity: String = _opened.rarity
	var chests := Data.table("chests")
	var colour := Color(chests.colours[rarity])
	var build_up := float(chests.build_up_seconds[rarity])
	_detail.text = ""
	if not Settings.reduced_motion():
		if rarity == "legendary":
			_title.text = "CONTAINMENT BREACH"
			var alarm := create_tween().set_loops(3)
			alarm.tween_property(_alarm, "color:a", 0.45, build_up / 6.0)
			alarm.tween_property(_alarm, "color:a", 0.0, build_up / 6.0)
		var shake := create_tween()
		var steps := int(build_up / 0.05)
		for i in steps:
			var strength := 0.04 + 0.12 * float(i) / steps
			shake.tween_property(_chest, "rotation", strength * (1 if i % 2 == 0 else -1), 0.05)
			shake.parallel().tween_property(_chest, "color", Color("#2A2A33").lerp(WINE, float(i) / steps), 0.05)
		await shake.finished
	_chest.rotation = 0.0
	_chest.color = colour
	Sfx.play("chest")
	_title.text = "%s chest" % rarity.capitalize()
	_buzz(400 if rarity in ["epic", "legendary"] else 120)
	_skip.visible = true
	_busy = false
	_next_card()


## Shows the next card from the chest, then the summary once every card has been seen.
func _next_card() -> void:
	_reveal += 1
	var cards: Array = _opened.cards
	if _reveal >= cards.size():
		_show_summary()
		return
	var drop: Dictionary = cards[_reveal]
	if drop.has("text"):
		_tile.visible = false
		_chest.visible = true
		_burst.strength = 0.0
		_detail.text = drop.text
		_stamp.text = ""
		_buzz(250)
		return
	_chest.visible = false
	var card: Dictionary = Data.table("cards").cards[drop.id]
	_detail.text = "%s  x%d\nLevel %d" % [card.name, drop.count, drop.level]
	_stamp.text = "NEW ANOMALY ACQUIRED" if drop.new else ("Level up" if drop.levelled else "")
	_tile.card_id = drop.id
	_tile.visible = true
	_tile.queue_redraw()
	var rarity := Progress.card_rarity(drop.id)
	_burst.colour = Color(Data.table("chests").colours.get(rarity, "#FFFFFF"))
	_burst.rays = {"common": 0, "rare": 8, "epic": 12, "legendary": 18}.get(rarity, 0)
	if rarity == "legendary":
		await _legendary_reveal()
	else:
		_pop_in(rarity)
	if _stamp.text != "":
		_slam(_stamp)
	if drop.new or drop.levelled:
		_buzz(150)


## A normal card pops up from small with a little overshoot. Rare cards flip in, and Epic ones hit with a bigger burst.
func _pop_in(rarity: String) -> void:
	_burst.strength = {"common": 0.4, "rare": 0.7, "epic": 1.0}.get(rarity, 0.4)
	Sfx.play("card" if rarity == "common" else "card_rare")
	if rarity == "epic":
		_buzz(200)
	if Settings.reduced_motion():
		_tile.scale = Vector2.ONE
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rarity == "common":
		_tile.scale = Vector2.ONE * 0.3
		tween.tween_property(_tile, "scale", Vector2.ONE, 0.25)
	else:
		_tile.scale = Vector2(0.0, 1.0)
		tween.tween_property(_tile, "scale", Vector2.ONE, 0.3 if rarity == "rare" else 0.4)
	_burst.strength = 0.0
	create_tween().tween_property(_burst, "strength", {"common": 0.4, "rare": 0.7, "epic": 1.0}.get(rarity, 0.4), 0.3)


## A Legendary card: the screen flashes white, golden rays spin up, then the card slams in bigger than life and settles,
## with a long buzz. Taps wait until it has landed.
func _legendary_reveal() -> void:
	_busy = true
	_title.text = "LEGENDARY"
	Sfx.play("legendary")
	_buzz(600)
	if Settings.reduced_motion():
		_burst.strength = 1.0
		_tile.scale = Vector2.ONE
		_busy = false
		return
	_tile.visible = false
	_flash.color.a = 0.0
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.9, 0.12)
	flash.tween_property(_flash, "color:a", 0.0, 0.5)
	var glow := create_tween()
	glow.tween_property(_burst, "strength", 1.0, 0.5)
	await get_tree().create_timer(0.35).timeout
	# Skipping during the build-up shows the summary instead, so the card stays hidden.
	if _summary != null:
		return
	_tile.visible = true
	_tile.scale = Vector2.ONE * 2.2
	_tile.rotation = -0.2
	var slam := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(_tile, "scale", Vector2.ONE, 0.45)
	slam.tween_property(_tile, "rotation", 0.0, 0.45)
	await slam.finished
	if _summary != null:
		return
	var wobble := create_tween()
	for i in 4:
		wobble.tween_property(_tile, "rotation", 0.05 * (1 if i % 2 == 0 else -1), 0.06)
	wobble.tween_property(_tile, "rotation", 0.0, 0.06)
	await wobble.finished
	_busy = false


## Slams a label down from big, as the codex stamp does.
func _slam(label: Label) -> void:
	if Settings.reduced_motion():
		return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 2.5
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(label, "scale", Vector2.ONE, 0.3)


func _skip_to_end() -> void:
	_show_summary()


## Every card the chest gave, rarest first, each with how many came and whether it is new or levelled up,
## then any extras such as evolutions. The tiles pop in one after another unless reduced motion is on.
func _show_summary() -> void:
	_busy = false
	_skip.visible = false
	_tile.visible = false
	_chest.visible = false
	_burst.strength = 0.0
	_burst.queue_redraw()
	_detail.text = ""
	_stamp.text = ""
	_title.text = ""
	var cards: Array = _opened.get("cards", [])
	var drops := cards.filter(func(drop: Dictionary) -> bool: return drop.has("id"))
	drops.sort_custom(_rarer_first)

	_summary = MarginContainer.new()
	_summary.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_summary.add_theme_constant_override("margin_" + side, Screen.SIDE_MARGIN)
	_summary.add_theme_constant_override("margin_top", Screen.TOP_MARGIN)
	_summary.add_theme_constant_override("margin_bottom", Screen.SIDE_MARGIN)
	add_child(_summary)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	_summary.add_child(column)
	var heading := Ui.label("%s chest" % String(_opened.get("rarity", "")).capitalize(), "TitleLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	DragScroll.attach(scroll)
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 24)
	scroll.add_child(list)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	list.add_child(grid)
	for i in drops.size():
		grid.add_child(_summary_entry(drops[i], i))
	for drop in cards:
		if drop.has("text"):
			list.add_child(Ui.label(drop.text, "HeadingLabel"))
	var done := Ui.button("Continue", _close_summary)
	done.custom_minimum_size.y = 130
	column.add_child(done)
	_buzz(120)


## One card in the summary: the tile, how many came, and NEW or its level. Legendary cards sit on a small golden glow.
func _summary_entry(drop: Dictionary, index: int) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var tile := CardTile.new(drop.id)
	tile.custom_minimum_size = SUMMARY_TILE
	tile.mouse_filter = MOUSE_FILTER_IGNORE
	tile.evolution = Progress.card_rarity(drop.id) == "legendary"
	box.add_child(tile)
	var line := "x%d  %s" % [drop.count, "NEW" if drop.new else ("Lv %d" % drop.level)]
	var label := Ui.label(line, "HeadingLabel" if drop.new or drop.levelled else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	if not Settings.reduced_motion():
		box.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.04 * index)
		tween.tween_property(box, "modulate:a", 1.0, 0.15)
	return box


func _rarer_first(a: Dictionary, b: Dictionary) -> bool:
	var first := RARITY_ORDER.find(Progress.card_rarity(a.id))
	var second := RARITY_ORDER.find(Progress.card_rarity(b.id))
	if first != second:
		return first < second
	return int(a.count) > int(b.count)


func _close_summary() -> void:
	if _summary != null:
		_summary.queue_free()
		_summary = null
	_show_waiting()


func _buzz(ms: int) -> void:
	if Settings.get_value("vibration"):
		Input.vibrate_handheld(ms)


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
