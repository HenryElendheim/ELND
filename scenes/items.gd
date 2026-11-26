extends Screen
## Foundation items: everything you hold apart from cards, with how many you have and what each one is for.
## Gold, wild cards, Evolution Injections and their shards, the evolutions unlocked so far, chests waiting to be opened,
## and how many games until the next Injection chest. Each row has a small drawn badge in the item's colour.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"


## A small round badge with a letter in it, which stands in for item art until real art exists.
class Badge extends Control:
	var colour := Color.WHITE
	var letter := ""

	func _init(fill: Color, mark: String) -> void:
		colour = fill
		letter = mark
		custom_minimum_size = Vector2(120, 120)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size / 2.0
		var radius := minf(size.x, size.y) * 0.45
		draw_circle(middle, radius, colour.darkened(0.45))
		draw_arc(middle, radius, 0, TAU, 32, colour, 6.0)
		var font := get_theme_default_font()
		var font_size := int(radius)
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, middle + Vector2(-width / 2.0, font_size * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func build() -> void:
	add(Ui.label("Foundation items", "TitleLabel"))
	var colours: Dictionary = Data.table("chests").colours
	_row(Color("#F2C14E"), "G", "Gold", str(Progress.gold()), "Buys chests in the Shop. Won in battles and from player level ups.")
	_row(Color("#6FF2FF"), "W", "Wild cards", str(Progress.wild_cards()), "Level up any card. Copies of a card that is already at max level turn into wild cards.")
	_row(Color(colours.injection), "I", "Evolution Injections", str(Progress.injections()), "Unlock the evolution of any card you choose, from that card's details.")
	var per := int(Data.table("chests").injection_shards_per_injection)
	_row(Color(colours.injection).darkened(0.2), "S", "Injection Shards", "%d of %d" % [Progress.shards(), per], "%d shards make one Evolution Injection." % per)
	var unlocked := Progress.evolvable_cards().filter(func(id: String) -> bool: return Progress.has_evolution(id)).size()
	_row(CardTile.EVOLUTION_GLOW, "E", "Evolutions unlocked", "%d of %d" % [unlocked, Progress.evolvable_cards().size()], "Put an evolved card in your deck's evolution slot to play its evolution.")
	var waiting := Progress.chests_waiting().size()
	_row(Color(colours.rare), "C", "Chests waiting", str(waiting), "You get one after every game, and you can open them any time.")
	if waiting > 0:
		add(Ui.button("Open chests", func() -> void: Nav.go(CHEST_SCENE)))
	var next := Progress.games_to_injection_chest()
	_row(Color(colours.injection), "10", "Next Injection chest", "in %d game%s" % [next, "" if next == 1 else "s"], "Every %d games you finish, an Injection chest with an Evolution Injection is waiting." % Progress.injection_chest_every())


## One item: its badge, its name and count, and a line about what it does.
func _row(colour: Color, letter: String, title: String, count: String, about: String) -> void:
	add(Ui.spacer(12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.add_child(Badge.new(colour, letter))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	heading.add_child(Ui.label(title, "HeadingLabel"))
	var amount := Ui.label(count, "HeadingLabel")
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_color_override("font_color", colour.lightened(0.2))
	heading.add_child(amount)
	text.add_child(heading)
	text.add_child(Ui.label(about, "MutedLabel"))
	row.add_child(text)
	add(row)


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
