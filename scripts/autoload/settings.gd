extends StoredDict
## Player settings. Every change is saved straight away and the look of the app is rebuilt to match.


func _init() -> void:
	path = "user://settings.json"
	defaults = {
		"theme": "dark",
		"high_contrast": false,
		"text_scale": 1.0,
		"reduced_motion": false,
		"damage_numbers": false,
		"vibration": true,
		"music_volume": 0.8,
		"effects_volume": 0.8,
		"bot_difficulty": "medium",
		"bot_reaction_time": 1.5,
		"bot_ephrocity_smarts": 0.5,
		"bot_counter_play": 0.5,
		"pure_balance": false,
		"admin_mode": false,
	}


func reduced_motion() -> bool:
	return get_value("reduced_motion")


func palette() -> Dictionary:
	return ThemeBuilder.palette(get_value("theme"), get_value("high_contrast"))


func _on_values_changed() -> void:
	var colors := palette()
	RenderingServer.set_default_clear_color(colors.bg)
	get_tree().root.theme = ThemeBuilder.build(colors, get_value("text_scale"))
	_apply_volume("Music", get_value("music_volume"))
	_apply_volume("Effects", get_value("effects_volume"))


## Sets the loudness of one audio bus, creating the bus the first time, which means sounds added later only need to pick a bus name.
func _apply_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_volume_db(bus, linear_to_db(volume))
