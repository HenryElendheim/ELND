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
	var waiting := Progress.chests_waiting().size()
	if waiting > 0:
		add(Ui.spacer(24))
		add(Ui.button("Open chests (%d)" % waiting, func() -> void: Nav.go(CHEST_SCENE)))
	_show_gold()


## A bought chest waits with the others, so the screen is rebuilt to show the Open chests button with the new count.
func _buy(rarity: String) -> void:
	if not Progress.buy_chest(rarity):
		Nav.banner("Not enough gold")
		return
	Nav.toast("%s chest bought" % rarity.capitalize())
	for child in content.get_children():
		child.queue_free()
	build()


func _show_gold() -> void:
	_gold.text = "%d gold" % Progress.gold()


func go_back() -> bool:
	Nav.go(MENU_SCENE)
	return true
