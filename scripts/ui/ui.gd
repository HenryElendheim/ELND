class_name Ui
## Shared building blocks for screens, so each kind of control is made the same way everywhere.


static func label(text: String, variation := "") -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, on_press: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(on_press)
	return node


## A row with a label on the left and an On/Off button on the right.
## A plain button is used instead of a small switch, which means the whole word is a big touch target.
static func toggle(text: String, value: bool, on_change: Callable) -> Control:
	var knob := Button.new()
	knob.toggle_mode = true
	knob.button_pressed = value
	knob.custom_minimum_size.x = 220
	knob.text = _on_off(value)
	knob.toggled.connect(func(pressed: bool) -> void: _toggled(knob, pressed, on_change))
	return _row(text, knob)


## A label with a row of buttons below it, where exactly one is picked at a time.
## Options are pairs of a stored value and the text shown, for example ["dark", "Dark"].
static func choice(text: String, options: Array, current: Variant, on_change: Callable) -> Control:
	var buttons := HBoxContainer.new()
	var group := ButtonGroup.new()
	for option in options:
		var node := button(option[1], func() -> void: on_change.call(option[0]))
		node.toggle_mode = true
		node.button_group = group
		node.button_pressed = option[0] == current
		buttons.add_child(node)
	return _stack(text, buttons)


## A label with the current value shown as a percentage, and a slider below it.
static func slider(text: String, min_value: float, max_value: float, step: float, value: float, on_change: Callable) -> Control:
	var node := HSlider.new()
	node.min_value = min_value
	node.max_value = max_value
	node.step = step
	node.value = value
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _stack(text, node)
	var title: Label = box.get_child(0)
	_show_percent(title, text, value)
	node.value_changed.connect(func(v: float) -> void: _slid(title, text, v, on_change))
	return box


static func spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	return node


static func _row(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var title := label(text)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	row.add_child(control)
	return row


static func _stack(text: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(label(text))
	box.add_child(control)
	return box


static func _toggled(knob: Button, pressed: bool, on_change: Callable) -> void:
	knob.text = _on_off(pressed)
	on_change.call(pressed)


static func _slid(title: Label, text: String, value: float, on_change: Callable) -> void:
	_show_percent(title, text, value)
	on_change.call(value)


static func _show_percent(title: Label, text: String, value: float) -> void:
	title.text = "%s: %d%%" % [text, roundi(value * 100)]


static func _on_off(value: bool) -> String:
	return "On" if value else "Off"
