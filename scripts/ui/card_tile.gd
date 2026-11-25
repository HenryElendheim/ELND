class_name CardTile
extends Button
## One card drawn as a tile: a frame in the card's rarity colour, its containment class colour inside with a big letter
## as placeholder art, the Ephrocity cost in a wine red drop at the top left and the short name along the bottom.
## Everything is drawn to fit the tile, which means a long name shrinks instead of stretching the screen.
## The same tile is used in the battle hand and on the Cards screen, where it can also show the level and copies bar.

const COST_FILL := Color("#722F37")
const COST_EDGE := Color("#A33B4C")
const EVOLUTION_GLOW := Color("#B46CFF")
const BAR_HEIGHT := 40.0

var card_id := ""
## Shows the level and the bar of copies toward the next level under the tile.
var show_progress := false
## Glows purple, which marks an evolution that is switched on or ready to come out.
var evolution := false


static func short_name(id: String) -> String:
	if id == "":
		return ""
	var card: Dictionary = Data.table("cards").cards[id]
	return card.get("short_name", String(card.name).trim_prefix("The "))


func _init(id := "", progress := false) -> void:
	card_id = id
	show_progress = progress
	flat = true
	text = ""
	clip_contents = true
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 230 + (BAR_HEIGHT + 8 if progress else 0))


func _draw() -> void:
	if card_id == "":
		return
	var cards := Data.table("cards")
	var card: Dictionary = cards.cards[card_id]
	var font := get_theme_default_font()
	var tile := Rect2(Vector2.ZERO, size - Vector2(0, BAR_HEIGHT + 8 if show_progress else 0))
	var rarity := Progress.card_rarity(card_id)
	var frame := Color(Data.table("chests").colours.get(rarity, "#9AA4B1"))
	var class_colour := Color(cards.classes.get(card.get("class", ""), "#8A8A8A"))

	if evolution:
		draw_rect(tile, EVOLUTION_GLOW)
	var body := tile.grow(-6.0 if evolution else 0.0)
	draw_rect(body, frame)
	var inner := body.grow(-7.0)
	draw_rect(inner, class_colour.darkened(0.55))

	# A big first letter stands in for the card art until real pixel art exists.
	var letter := short_name(card_id).left(1)
	var letter_size := int(inner.size.y * 0.5)
	_centred(font, letter, Vector2(inner.get_center().x, inner.position.y + inner.size.y * 0.55), letter_size, class_colour.lightened(0.25), inner.size.x)

	# The name sits on a dark band and shrinks to fit the width of the tile.
	var band := Rect2(inner.position.x, inner.end.y - inner.size.y * 0.24, inner.size.x, inner.size.y * 0.24)
	draw_rect(band, Color(0, 0, 0, 0.6))
	_centred(font, short_name(card_id), Vector2(band.get_center().x, band.get_center().y + band.size.y * 0.2), int(band.size.y * 0.55), Color.WHITE, band.size.x - 10)

	var radius := minf(inner.size.x, inner.size.y) * 0.17
	var drop := inner.position + Vector2(radius + 4, radius + 4)
	draw_circle(drop, radius, COST_FILL)
	draw_arc(drop, radius, 0, TAU, 24, COST_EDGE, 3.0)
	_centred(font, str(int(card.cost)), drop + Vector2(0, radius * 0.38), int(radius * 1.15), Color.WHITE, radius * 2)

	if button_pressed:
		draw_rect(tile, Color.WHITE, false, 6.0)
	if show_progress:
		_draw_progress(font, Rect2(0, tile.end.y + 8, size.x, BAR_HEIGHT))


## The level on the left and a bar filling toward the next level, or "Max" once the card is at the top level.
func _draw_progress(font: Font, bar: Rect2) -> void:
	var progress := Progress.card(card_id)
	var level := int(progress.level)
	var needed := Progress.copies_for_next(maxi(level, 1))
	var maxed := level >= Progress.max_card_level()
	var share := 1.0 if maxed else clampf(float(progress.copies) / float(needed), 0.0, 1.0)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), COST_EDGE if share < 1.0 else Color("#4CAF50"))
	var label := "Lv %d  %s" % [level, "Max" if maxed else "%d/%d" % [int(progress.copies), needed]]
	_centred(font, label, Vector2(bar.get_center().x, bar.get_center().y + bar.size.y * 0.25), int(bar.size.y * 0.62), Color.WHITE, bar.size.x - 8)


## Draws text centred on a point with a dark outline, shrinking the font until it fits the given width.
func _centred(font: Font, value: String, at: Vector2, font_size: int, colour: Color, max_width: float) -> void:
	var fitted := font_size
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	if width > max_width and width > 0.0:
		fitted = maxi(int(fitted * max_width / width), 8)
		width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	var spot := at - Vector2(width / 2.0, 0)
	draw_string_outline(font, spot, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, maxi(fitted / 8, 2), Color.BLACK)
	draw_string(font, spot, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, colour)
