class_name CardDetail
extends CanvasLayer
## A card's details, shown over everything. Two pages you swipe between: Info, with its stats at your level,
## how it works and its evolution, and Codex, with its Foundation entry. Under them sit whatever buttons
## the screen that opened it hands over, such as adding the card to the deck. Back or Close shuts it.

const SPEED_NAMES := {0.75: "Slow", 1.0: "Medium", 1.5: "Fast"}
const TARGET_NAMES := {
	"ground": "Ground troops", "air_ground": "Air and ground", "buildings": "Buildings only",
	"attackers_only": "Only what attacks it", "mode": "Troops or buildings, by mood", "none": "Nothing",
}

var card_id := ""
var _actions: Array


## The actions are pairs of button text and what the button does, for example ["Add to deck", add].
func _init(id: String, actions: Array = []) -> void:
	card_id = id
	_actions = actions
	layer = 50
	add_to_group(Pager.MODAL_GROUP)


func _ready() -> void:
	var card: Dictionary = Data.table("cards").cards[card_id]
	var cover := Panel.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	margin.add_child(column)

	var header := HBoxContainer.new()
	var tile := CardTile.new(card_id)
	tile.size_flags_horizontal = Control.SIZE_FILL
	tile.custom_minimum_size = Vector2(230, 290)
	tile.disabled = true
	header.add_child(tile)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(Ui.label(card.name, "HeadingLabel"))
	title.add_child(Ui.label("%s   %s" % [Progress.card_rarity(card_id).capitalize(), String(card.get("type", "")).capitalize()]))
	var level := int(Progress.card(card_id).level)
	title.add_child(Ui.label("Level %d" % level if level > 0 else "Not yet acquired", "MutedLabel"))
	header.add_child(title)
	column.add_child(header)

	var pager := Pager.new()
	pager.add_page(_page(_info_lines(card)))
	pager.add_page(_page(_codex_lines(card)))
	column.add_child(pager.make_tabs(["Info", "Codex"], 100))
	column.add_child(pager)

	for action in _actions:
		column.add_child(Ui.button(action[0], func() -> void: _run(action[1])))
	column.add_child(Ui.button("Close", close))


func close() -> void:
	queue_free()


func _run(action: Callable) -> void:
	close()
	action.call()


## One scrolling page made of labels.
func _page(lines: Array) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for line in lines:
		box.add_child(Ui.label(line[0], line[1]))
	return scroll


## The Info page. Health and damage are shown at the player's own level, so they match what happens in battle.
func _info_lines(card: Dictionary) -> Array:
	var battle := Data.table("battle")
	var scale := pow(1.0 + float(battle.level_scaling.per_level), maxi(int(Progress.card(card_id).level), 1) - 1)
	var lines := [["Cost: %d Ephrocity" % int(card.cost), ""]]
	var type: String = card.get("type", "troop")
	if card.has("health"):
		lines.append(["Health: %d" % roundi(float(card.health) * scale), ""])
	if type == "building":
		lines.append(["Lasts: %d seconds" % int(card.get("lifetime", 0)), ""])
	if float(card.get("damage", 0)) > 0.0:
		var damage := "Damage: %d" % roundi(float(card.damage) * scale)
		if card.has("hit_speed"):
			damage += " every %.1f s" % float(card.hit_speed)
		lines.append([damage, ""])
	if type == "troop":
		var speed := float(battle.speeds_tiles_per_second.get(card.get("speed", ""), 0.0))
		lines.append(["Speed: %s" % SPEED_NAMES.get(speed, String(card.get("speed", "")).capitalize()), ""])
		lines.append(["Range: %s" % ("%.1f tiles" % float(card.range) if card.get("attack") == "ranged" else "Melee"), ""])
		lines.append(["Targets: %s" % TARGET_NAMES.get(card.get("targets", "ground"), ""), ""])
		lines.append(["Moves: %s" % String(card.get("movement", "ground")).capitalize(), ""])
	if int(card.get("count", 1)) > 1:
		lines.append(["Comes as a group of %d" % int(card.count), ""])
	if card.has("radius"):
		lines.append(["Area: %.1f tiles" % float(card.radius), ""])
	if card.has("how_it_works"):
		lines.append(["How it works", "HeadingLabel"])
		lines.append([card.how_it_works, ""])
	if card.has("evolution"):
		lines.append(["Evolution: %s" % card.evolution.name, "HeadingLabel"])
		lines.append([card.evolution.get("how_it_works", ""), ""])
		var status := "Unlocked" if Progress.has_evolution(card_id) else "Locked"
		lines.append(["%s. Needs %d cycle%s before it comes out evolved." % [status, Hand.cycles_needed(card_id), "" if Hand.cycles_needed(card_id) == 1 else "s"], "MutedLabel"])
	return lines


## The Codex page: the ELND number, class and threat, and the Foundation entry once the card is acquired.
func _codex_lines(card: Dictionary) -> Array:
	var lines := [["ELND-%03d" % int(card.number), "HeadingLabel"], ["Class %s   Threat %d/5" % [card["class"], int(card.threat)], ""]]
	if int(Progress.card(card_id).level) <= 0:
		lines.append(["This entry unlocks once the anomaly is acquired.", "MutedLabel"])
	else:
		lines.append([Data.table("codex").entries.get(card_id, ""), ""])
	return lines
