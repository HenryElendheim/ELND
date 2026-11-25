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
	squishy(node)
	return node


## Makes a control shrink a little while pressed and spring back when let go, unless reduced motion is on.
static func squishy(node: BaseButton) -> void:
	node.resized.connect(func() -> void: node.pivot_offset = node.size / 2.0)
	node.button_down.connect(func() -> void: _squish(node, 0.94))
	node.button_up.connect(func() -> void: _squish(node, 1.0))


static func _squish(node: Control, amount: float) -> void:
	if Settings.reduced_motion() or not node.is_inside_tree():
		node.scale = Vector2.ONE
		return
	var tween := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * amount, 0.12)


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


## A label with a grid of buttons below it, where exactly one is picked at a time.
## Options are pairs of a stored value and the text shown, for example ["dark", "Dark"].
## Long lists wrap onto more rows instead of squeezing the buttons.
static func choice(text: String, options: Array, current: Variant, on_change: Callable, columns := 3) -> Control:
	var buttons := GridContainer.new()
	buttons.columns = mini(options.size(), columns)
	_fill_choices(buttons, options, current, on_change, true)
	return _stack(text, buttons)


## The same kind of pick-one buttons in a single row that scrolls sideways, which suits long lists on small screens.
static func strip(options: Array, current: Variant, on_change: Callable) -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	scroll.add_child(row)
	_fill_choices(row, options, current, on_change, false)
	return scroll


static func _fill_choices(box: Container, options: Array, current: Variant, on_change: Callable, expand: bool) -> void:
	var group := ButtonGroup.new()
	for option in options:
		var node := button(option[1], func() -> void: on_change.call(option[0]))
		node.toggle_mode = true
		node.button_group = group
		node.button_pressed = option[0] == current
		if not expand:
			node.size_flags_horizontal = Control.SIZE_FILL
		box.add_child(node)


## A label with the current value, and a slider below it. Values show as a percentage, or as seconds when asked.
static func slider(text: String, min_value: float, max_value: float, step: float, value: float, on_change: Callable, seconds := false) -> Control:
	var node := HSlider.new()
	node.min_value = min_value
	node.max_value = max_value
	node.step = step
	node.value = value
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _stack(text, node)
	var title: Label = box.get_child(0)
	_show_value(title, text, value, seconds)
	node.value_changed.connect(func(v: float) -> void: _slid(title, text, v, on_change, seconds))
	return box


## A row with a label and a number box. The value is only used once it is confirmed and is a real number.
static func number(text: String, value: float, on_change: Callable) -> Control:
	var field := LineEdit.new()
	field.text = str(value)
	field.custom_minimum_size.x = 260
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	field.select_all_on_focus = true
	field.text_submitted.connect(func(entered: String) -> void: _number_entered(field, entered, on_change))
	field.focus_exited.connect(func() -> void: _number_entered(field, field.text, on_change))
	return _row(text, field)


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


static func _slid(title: Label, text: String, value: float, on_change: Callable, seconds: bool) -> void:
	_show_value(title, text, value, seconds)
	on_change.call(value)


static func _show_value(title: Label, text: String, value: float, seconds: bool) -> void:
	title.text = "%s: %.1f s" % [text, value] if seconds else "%s: %d%%" % [text, roundi(value * 100)]


static func _number_entered(field: LineEdit, entered: String, on_change: Callable) -> void:
	if entered.is_valid_float():
		on_change.call(entered.to_float())
	field.release_focus()


static func _on_off(value: bool) -> String:
	return "On" if value else "Off"
