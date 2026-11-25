class_name Hand
extends RefCounted
## One side's cards and Ephrocity. The first four cards are the hand and the rest wait in a queue.
## A played card goes to the back of the queue and the front of the queue takes its slot,
## which means the deck cycles in a fixed order just like the design doc asks.

var cards: Array[String] = []
## Cards played with their evolution switched on, and how many times each has been cycled since it last came out evolved.
var evolutions: Array = []
var _cycles := {}
var ephrocity := 0.0
## Admin Mode can make Ephrocity endless for either side while testing.
var infinite := false

var _hand_size := 4
var _max := 10.0


func _init(deck: Array, battle: Dictionary, evolved_cards: Array = []) -> void:
	cards.assign(deck)
	evolutions = evolved_cards.duplicate()
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


## How many cycles a card needs before it comes out evolved. Cards that cost 5 or more need 2, the rest need 1.
static func cycles_needed(card_id: String) -> int:
	var rule: Dictionary = Data.table("battle").evolution.cycles_by_cost
	return int(rule.high) if cost_of(card_id) >= float(rule.from_cost) else int(rule.low)


## True when the card in a slot will come out evolved the next time it is played.
func evolution_ready(slot: int) -> bool:
	var card := cards[slot]
	return card in evolutions and int(_cycles.get(card, 0)) >= cycles_needed(card)


## Pays for the card in a slot and cycles it out. It returns the card that was played.
## An evolution card that has been cycled enough comes out evolved, and its count starts over.
## played_evolved tells the caller which way the last card came out.
var played_evolved := false


func play(slot: int) -> String:
	var card := cards[slot]
	played_evolved = evolution_ready(slot)
	if card in evolutions:
		_cycles[card] = 0 if played_evolved else int(_cycles.get(card, 0)) + 1
	if not infinite:
		ephrocity -= cost_of(card)
	if cards.size() > _hand_size:
		cards[slot] = cards[_hand_size]
		cards.remove_at(_hand_size)
		cards.append(card)
	return card


func regenerate(bars: float) -> void:
	ephrocity = _max if infinite else minf(ephrocity + bars, _max)
