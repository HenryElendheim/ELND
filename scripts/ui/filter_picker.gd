class_name FilterPicker
extends CanvasLayer
## The filter view for the collection, shown over everything. Search the filters by name, tap the ones you want,
## and press Apply. Filters in the same group mean any of them, such as troops or spells, and filters in different groups
## mean all of them at once, such as flying and legendary. Back leaves without changing anything, and Clear unpicks all.

var _picked: Array = []
var _on_apply: Callable
var _query := ""
var _list := VBoxContainer.new()


func _init(picked: Array, on_apply: Callable) -> void:
	_picked = picked.duplicate()
	_on_apply = on_apply
	layer = 50
	add_to_group(Pager.MODAL_GROUP)


func _ready() -> void:
	var cover := Panel.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.theme = Settings.current_theme
	var fill := StyleBoxFlat.new()
	fill.bg_color = Settings.palette().bg
	cover.add_theme_stylebox_override("panel", fill)
	add_child(cover)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Screen.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", Screen.TOP_MARGIN)
	cover.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var back := Ui.button("Back", queue_free)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Screen.BACK_SIZE
	column.add_child(back)
	column.add_child(Ui.label("Filter", "TitleLabel"))
	column.add_child(Ui.search("Search filters", _on_search))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	DragScroll.attach(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	column.add_child(scroll)
	var buttons := HBoxContainer.new()
	buttons.add_child(Ui.button("Clear", _clear))
	var apply := Ui.button("Apply", _apply)
	apply.custom_minimum_size.y = 130
	buttons.add_child(apply)
	column.add_child(buttons)
	_show()


func _on_search(text: String) -> void:
	_query = text.to_lower().strip_edges()
	_show()


## Every group with the filters that match the search, each a button that lights up while picked.
func _show() -> void:
	for child in _list.get_children():
		child.queue_free()
	var any := false
	for group in CardSearch.GROUPS:
		var tags: Array = group[1].filter(func(tag: String) -> bool: return _query == "" or CardSearch.category_name(tag).to_lower().contains(_query) or String(group[0]).to_lower().contains(_query))
		if tags.is_empty():
			continue
		any = true
		_list.add_child(Ui.label(group[0], "HeadingLabel"))
		var grid := GridContainer.new()
		grid.columns = 3
		for tag in tags:
			var button := Ui.button(CardSearch.category_name(tag), func() -> void: _toggle(tag))
			button.toggle_mode = true
			button.button_pressed = tag in _picked
			grid.add_child(button)
		_list.add_child(grid)
	if not any:
		_list.add_child(Ui.label("No filters match that search.", "MutedLabel"))


func _toggle(tag: String) -> void:
	if tag in _picked:
		_picked.erase(tag)
	else:
		_picked.append(tag)
	_show.call_deferred()


func _clear() -> void:
	_picked.clear()
	_show()


func _apply() -> void:
	_on_apply.call(_picked.duplicate())
	queue_free()
