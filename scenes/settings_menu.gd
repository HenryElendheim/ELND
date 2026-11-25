extends Screen
## The settings screen. Every control is tied to one settings key, which means a change is saved and shown straight away.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const THEMES := [["dark", "Dark"], ["light", "Light"]]
const DIFFICULTIES := [["easy", "Easy"], ["medium", "Medium"], ["hard", "Hard"]]


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
	_choice("Bot difficulty", "bot_difficulty", DIFFICULTIES)
	_toggle("Pure Balance", "pure_balance")

	_section("Your data")
	add(Ui.button("Export backup", func() -> void: Backup.export_to_device(Nav.toast)))
	add(Ui.button("Import backup", func() -> void: Backup.import_from_device(_after_import)))

	add(Ui.spacer(24))
	add(Ui.button("Back", go_back))
	add(Ui.spacer(24))
	var version: Label = add(Ui.label("v%s" % ProjectSettings.get_setting("application/config/version"), "MutedLabel"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true


func _section(title: String) -> void:
	add(Ui.spacer(16))
	add(Ui.label(title, "HeadingLabel"))


func _toggle(text: String, key: String) -> void:
	add(Ui.toggle(text, Settings.get_value(key), func(value: bool) -> void: Settings.set_value(key, value)))


func _choice(text: String, key: String, options: Array) -> void:
	add(Ui.choice(text, options, Settings.get_value(key), func(value: Variant) -> void: Settings.set_value(key, value)))


func _slider(text: String, key: String, min_value: float, max_value: float, step: float) -> void:
	add(Ui.slider(text, min_value, max_value, step, Settings.get_value(key), func(value: float) -> void: Settings.set_value(key, value)))


## After an import the screen is rebuilt, which means every control shows the restored values.
func _after_import(message: String) -> void:
	Nav.toast(message)
	if message == Backup.IMPORTED:
		get_tree().reload_current_scene()
