extends Screen
## The Shop. Gold is only ever spent here, on chests, and a bought chest waits with the others to be opened.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CHEST_SCENE := "res://scenes/chest.tscn"

var _gold: Label


func build() -> void:
	add(Ui.label("Shop", "TitleLabel"))
	_gold = add(Ui.label("", "HeadingLabel"))
	var prices: Dictionary = Data.table("economy").shop_prices
	for rarity in prices:
		add(Ui.button("%s chest   %d gold" % [String(rarity).capitalize(), int(prices[rarity])], func() -> void: _buy(rarity)))
	add(Ui.spacer(24))
	add(Ui.button("Open chests", func() -> void: Nav.go(CHEST_SCENE)))
	add(Ui.button("Back", go_back))
	_show_gold()


func _buy(rarity: String) -> void:
	Nav.toast("%s chest bought" % rarity.capitalize() if Progress.buy_chest(rarity) else "Not enough gold")
	_show_gold()


func _show_gold() -> void:
	_gold.text = "%d gold" % Progress.gold()


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
