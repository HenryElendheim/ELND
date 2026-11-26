extends Screen
## The settings screen. Every control is tied to one settings key, which means a change is saved and shown straight away.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const THEMES := [["dark", "Dark"], ["light", "Light"]]
const DIFFICULTIES := [["easy", "Easy"], ["medium", "Medium"], ["hard", "Hard"], ["custom", "Custom"]]
const ADMIN_TAPS := 7
const TAP_GAP_MS := 2000

var _custom := VBoxContainer.new()
var _taps := 0
var _last_tap := 0


func build() -> void:
	add(Ui.label("Settings", "TitleLabel"))

	_section("Display")
	_choice("Theme", "theme", THEMES)
	_toggle("High contrast", "high_contrast")
	_slider("Text size", "text_scale", 0.8, 1.6, 0.1)
	_toggle("Reduced motion", "reduced_motion")
	_toggle("Damage numbers", "damage_numbers")

	_section("Sound")
	_slider("Music", "music_volume", 0.0, 1.0, 0.05)
	_slider("Effects", "effects_volume", 0.0, 1.0, 0.05)
	_toggle("Vibration", "vibration")

	_section("Battle")
	_choice("Bot difficulty", "bot_difficulty", DIFFICULTIES, 4)
	# The custom sliders only show while Custom is picked, which keeps the screen short for everyone else.
	add(_custom)
	var ranges: Dictionary = Data.table("bot").custom_ranges
	_slider("Reaction time", "bot_reaction_time", ranges.reaction_time[0], ranges.reaction_time[1], 0.1, true, _custom)
	_slider("Saving up", "bot_ephrocity_smarts", ranges.ephrocity_smarts[0], ranges.ephrocity_smarts[1], 0.05, false, _custom)
	_slider("Counter-play", "bot_counter_play", ranges.counter_play[0], ranges.counter_play[1], 0.05, false, _custom)
	_show_custom()
	# Connecting a method of this screen, not a lambda, means Godot drops the connection when the screen closes.
	Settings.changed.connect(_show_custom)
	_toggle("Pure Balance", "pure_balance")

	_section("Your data")
	add(Ui.button("Export backup", func() -> void: Backup.export_to_device(Nav.toast)))
	add(Ui.button("Import backup", func() -> void: Backup.import_from_device(_after_import)))

	if Settings.get_value("admin_mode"):
		add(Ui.button("Admin tools", func() -> void: Nav.go("res://scenes/admin.tscn")))
	add(Ui.spacer(24))
	add(Ui.spacer(24))
	var version: Label = add(Ui.label("v%s" % ProjectSettings.get_setting("application/config/version"), "MutedLabel"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.mouse_filter = MOUSE_FILTER_STOP
	version.gui_input.connect(_on_version_input)


## Tapping the version number seven times in a row turns Admin Mode on or off.
## A pause of more than two seconds starts the count again.
func _on_version_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var now := Time.get_ticks_msec()
	_taps = _taps + 1 if now - _last_tap < TAP_GAP_MS else 1
	_last_tap = now
	if _taps < ADMIN_TAPS:
		return
	_taps = 0
	var on: bool = not Settings.get_value("admin_mode")
	Settings.set_value("admin_mode", on)
	Nav.toast("Admin Mode on" if on else "Admin Mode off")


func _show_custom() -> void:
	_custom.visible = Settings.get_value("bot_difficulty") == "custom"


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true


func _section(title: String) -> void:
	add(Ui.spacer(16))
	add(Ui.label(title, "HeadingLabel"))


func _toggle(text: String, key: String) -> void:
	add(Ui.toggle(text, Settings.get_value(key), func(value: bool) -> void: Settings.set_value(key, value)))


func _choice(text: String, key: String, options: Array, columns := 3) -> void:
	add(Ui.choice(text, options, Settings.get_value(key), func(value: Variant) -> void: Settings.set_value(key, value), columns))


## Adds a slider tied to a settings key, to the main column or to another box when one is given.
func _slider(text: String, key: String, min_value: float, max_value: float, step: float, seconds := false, box: Control = null) -> void:
	var node := Ui.slider(text, min_value, max_value, step, Settings.get_value(key), func(value: float) -> void: Settings.set_value(key, value), seconds)
	if box == null:
		add(node)
	else:
		box.add_child(node)


## After an import the screen is rebuilt, which means every control shows the restored values.
func _after_import(message: String) -> void:
	Nav.toast(message)
	if message == Backup.IMPORTED:
		get_tree().reload_current_scene()
