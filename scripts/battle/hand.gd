class_name Hand
extends RefCounted
## One side's cards and Ephrocity. The first four cards are the hand and the rest wait in a queue.
## A played card goes to the back of the queue and the front of the queue takes its slot,
## which means the deck cycles in a fixed order just like the design doc asks.

var cards: Array[String] = []
var ephrocity := 0.0
## Admin Mode can make Ephrocity endless for either side while testing.
var infinite := false

var _hand_size := 4
var _max := 10.0


func _init(deck: Array, battle: Dictionary) -> void:
	cards.assign(deck)
	cards.shuffle()
	_hand_size = int(battle.deck.hand)
	_max = float(battle.ephrocity.max)
	ephrocity = float(battle.ephrocity.start)


func in_hand() -> Array:
	return cards.slice(0, _hand_size)


## The card that will come in next, or an empty string when the deck is too small to have one.
func next_card() -> String:
	return cards[_hand_size] if cards.size() > _hand_size else ""


static func cost_of(card_id: String) -> float:
	return float(Data.table("cards").cards[card_id].cost)


func can_afford(slot: int) -> bool:
	return infinite or ephrocity >= cost_of(cards[slot])


## Pays for the card in a slot and cycles it out. It returns the card that was played.
func play(slot: int) -> String:
	var card := cards[slot]
	if not infinite:
		ephrocity -= cost_of(card)
	if cards.size() > _hand_size:
		cards[slot] = cards[_hand_size]
		cards.remove_at(_hand_size)
		cards.append(card)
	return card


func regenerate(bars: float) -> void:
	ephrocity = _max if infinite else minf(ephrocity + bars, _max)
