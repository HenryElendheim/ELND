extends Control
## Shows the word Elendheim for one second, then fades into the main menu.

const HOLD_TIME := 1.0
const NEXT_SCENE := "res://scenes/main_menu.tscn"


func _ready() -> void:
	var title := Ui.label("Elendheim", "SplashLabel")
	title.set_anchors_preset(PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)
	await get_tree().create_timer(HOLD_TIME).timeout
	Nav.go(NEXT_SCENE)
