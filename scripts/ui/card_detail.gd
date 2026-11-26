class_name CardDetail
extends CanvasLayer
## A card's details, shown over everything. Two pages you swipe between: Info, with its stats at your level,
## how it works and its evolution, and Codex, with its Foundation entry. Under them sit whatever buttons
## the screen that opened it hands over, such as adding the card to the deck. Back or Close shuts it.

const SPEED_NAMES := {0.75: "Slow", 1.0: "Medium", 1.5: "Fast", 2.0: "Very fast"}
const TARGET_NAMES := {
	"ground": "Ground troops", "air_ground": "Air and ground", "buildings": "Buildings only",
	"attackers_only": "Only what attacks it", "mode": "Troops or buildings, by mood", "none": "Nothing",
	"living": "Living troops only",
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
	# This layer sits outside the normal screens, so it takes the app's theme directly to get the right sizes.
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
	margin.add_child(column)
	var back := Ui.button("Back", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Screen.BACK_SIZE
	column.add_child(back)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 32)
	var tile := CardTile.new(card_id)
	tile.size_flags_horizontal = Control.SIZE_FILL
	tile.custom_minimum_size = Vector2(300, 380)
	tile.disabled = true
	header.add_child(tile)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_child(Ui.label(card.name, "StatNumber"))
	var rarity := Progress.card_rarity(card_id)
	var rarity_label := Ui.label("%s %s" % [rarity.capitalize(), String(card.get("type", "")).capitalize()], "HeadingLabel")
	rarity_label.add_theme_color_override("font_color", Color(Data.table("chests").colours.get(rarity, "#FFFFFF")))
	title.add_child(rarity_label)
	var level := int(Progress.card(card_id).level)
	title.add_child(Ui.label("Level %d" % level if level > 0 else "Not yet acquired"))
	header.add_child(title)
	column.add_child(header)

	var pager := Pager.new()
	pager.add_page(_page(_info_lines(card)))
	pager.add_page(_page(_codex_lines(card)))
	column.add_child(pager.make_tabs(["Info", "Codex"], 120))
	column.add_child(pager)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	for action in _actions:
		var button := Ui.button(action[0], func() -> void: _run(action[1]))
		button.custom_minimum_size.y = 130
		buttons.add_child(button)
	column.add_child(buttons)


func close() -> void:
	queue_free()


func _run(action: Callable) -> void:
	close()
	action.call()


## One scrolling page. Each entry is either a line of text with its style, or a list of stats,
## which becomes a grid of boxes with a small name and a big value, two to a row.
func _page(entries: Array) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	DragScroll.attach(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)
	scroll.add_child(box)
	for entry in entries:
		if entry[0] is Array:
			box.add_child(_stat_grid(entry[0]))
		else:
			box.add_child(Ui.label(entry[0], entry[1]))
	return scroll


func _stat_grid(stats: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	for stat in stats:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "StatTile"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", 2)
		cell.add_child(inside)
		inside.add_child(Ui.label(stat[0], "MutedLabel"))
		inside.add_child(Ui.label(stat[1], "HeadingLabel"))
		grid.add_child(cell)
	return grid


## The Info page. Health and damage are shown at the player's own level, so they match what happens in battle.
func _info_lines(card: Dictionary) -> Array:
	var battle := Data.table("battle")
	var scale := pow(1.0 + float(battle.level_scaling.per_level), maxi(int(Progress.card(card_id).level), 1) - 1)
	var stats := [["Cost", "%d Ephrocity" % int(card.cost)]]
	var type: String = card.get("type", "troop")
	if card.has("health"):
		stats.append(["Health", str(roundi(float(card.health) * scale))])
	if type == "building":
		stats.append(["Lasts", "%d s" % int(card.get("lifetime", 0))])
	if float(card.get("damage", 0)) > 0.0:
		stats.append(["Damage", str(roundi(float(card.damage) * scale))])
		if card.has("hit_speed"):
			stats.append(["Hit speed", "%.1f s" % float(card.hit_speed)])
	if type == "troop":
		var speed := float(battle.speeds_tiles_per_second.get(card.get("speed", ""), 0.0))
		stats.append(["Speed", SPEED_NAMES.get(speed, String(card.get("speed", "")).capitalize())])
		stats.append(["Range", "%.1f tiles" % float(card.range) if card.get("attack") == "ranged" else "Melee"])
		stats.append(["Targets", TARGET_NAMES.get(card.get("targets", "ground"), "")])
		stats.append(["Moves", String(card.get("movement", "ground")).capitalize()])
	if int(card.get("count", 1)) > 1:
		stats.append(["Group of", str(int(card.count))])
	if card.has("radius"):
		stats.append(["Area", "%.1f tiles" % float(card.radius)])
	var lines := [[stats, ""]]
	if int(Progress.card(card_id).level) <= 0:
		lines.append(["Locked. It turns up in chests from %s." % Progress.arena_name(int(card.get("unlock_arena", 1))), "MutedLabel"])
	if card.has("how_it_works"):
		lines.append(["How it works", "HeadingLabel"])
		lines.append([CardText.fill(card_id, card.how_it_works, _level()), ""])
	if card.has("evolution"):
		lines.append(["Evolution: %s" % card.evolution.name, "HeadingLabel"])
		lines.append([CardText.fill(card_id, card.evolution.get("how_it_works", ""), _level()), ""])
		var status := "Unlocked" if Progress.has_evolution(card_id) else "Locked"
		lines.append(["%s. Needs %d cycle%s before it comes out evolved." % [status, Hand.cycles_needed(card_id), "" if Hand.cycles_needed(card_id) == 1 else "s"], "MutedLabel"])
	return lines


## The level the numbers in descriptions are shown at, which is the player's own level for the card, or 1 if not yet owned.
func _level() -> int:
	return maxi(int(Progress.card(card_id).level), 1)


## The Codex page: the ELND number, the Codex name when it differs from the card's, class, threat and tags,
## and the Foundation entry once the card is acquired.
func _codex_lines(card: Dictionary) -> Array:
	var facts := [["Number", "ELND-%03d" % int(card.number)]]
	if card.has("codex_name"):
		facts.append(["Codex name", String(card.codex_name)])
	facts.append_array([["Class", String(card["class"])], ["Threat", "%d of 5" % int(card.threat)], ["Rarity", Progress.card_rarity(card_id).capitalize()]])
	var tags: Array = Data.table("codex").get("tags", {}).get(card_id, [])
	if not tags.is_empty():
		facts.append(["Tags", ", ".join(tags)])
	var lines := [[facts, ""]]
	if int(Progress.card(card_id).level) <= 0:
		lines.append(["This entry unlocks once the anomaly is acquired.", "MutedLabel"])
	else:
		lines.append([Data.table("codex").entries.get(card_id, ""), ""])
	return lines
