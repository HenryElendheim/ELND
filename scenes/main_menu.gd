extends Screen
## The first screen after the splash. Battle stays greyed out until the arena exists in the next milestone.

const SETTINGS_SCENE := "res://scenes/settings_menu.tscn"


func build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = add(Ui.label("ELND", "TitleLabel"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(Ui.spacer(80))
	var battle: Button = add(Ui.button("Battle", func() -> void: pass))
	battle.disabled = true
	add(Ui.button("Settings", func() -> void: Nav.go(SETTINGS_SCENE)))
