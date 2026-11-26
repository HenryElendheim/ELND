class_name PlaceReached
extends Celebration
## The celebration for reaching a new Lab or Site. The screen flashes, rays spin up behind the place's name,
## which slams down, and the anomalies that now turn up in chests pop in one after another.

const TILE_SIZE := Vector2(0, 230)

var _place := 1
var _name: Label
var _cards := GridContainer.new()
var _tiles: Array[CardTile] = []


func _init(place: int) -> void:
	super()
	_place = place


func build() -> void:
	burst.colour = ReputationBar.GOLD
	burst.rays = 20
	title.add_theme_color_override("font_color", ReputationBar.GOLD)
	_name = Ui.label(Progress.arena_name(_place), "TitleLabel")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(_name)
	var ids := _new_cards()
	line("New anomalies now turn up in chests:" if not ids.is_empty() else "No new anomalies here yet, but your chests keep growing.", "HeadingLabel")
	_cards.columns = 4
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_cards)
	for id in ids:
		var tile := CardTile.new(id)
		tile.custom_minimum_size = TILE_SIZE
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.add_child(tile)
		_tiles.append(tile)


func _new_cards() -> Array:
	var cards: Dictionary = Data.table("cards").cards
	var found := []
	for id in cards:
		if BattleSim.is_collectable(cards[id]) and int(cards[id].get("unlock_arena", 1)) == _place:
			found.append(id)
	return found


func play() -> void:
	title.text = "SITE REACHED" if Progress.arena_name(_place).begins_with("Site") else "LAB REACHED"
	for tile in _tiles:
		tile.modulate.a = 0.0
	Sfx.play("legendary")
	buzz(500)
	flash_screen(0.9)
	create_tween().tween_property(burst, "strength", 1.0, 0.5)
	slam(_name, 2.6)
	slam(title, 1.8)
	await get_tree().create_timer(0.5).timeout
	for tile in _tiles:
		if done:
			return
		tile.pivot_offset = tile.size / 2.0
		tile.scale = Vector2.ONE * 0.3
		var pop := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(tile, "scale", Vector2.ONE, 0.3)
		pop.tween_property(tile, "modulate:a", 1.0, 0.15)
		Sfx.play("card_rare")
		await get_tree().create_timer(0.22).timeout
	if not done:
		_end()


func finish() -> void:
	title.text = "SITE REACHED" if Progress.arena_name(_place).begins_with("Site") else "LAB REACHED"
	for tile in _tiles:
		tile.modulate.a = 1.0
		tile.scale = Vector2.ONE
