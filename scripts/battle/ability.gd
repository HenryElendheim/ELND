class_name Ability
extends RefCounted
## Base for a card's special rule. Each ability is a small script in the abilities folder, named after its id in cards.json,
## and it only overrides the hooks it needs. The settings from cards.json arrive in params,
## which means every number can be tuned in the data file instead of in code.

var params := {}
var unit: Unit


## Builds the ability for a cards.json entry such as {"id": "munchies", "hungry_after": 8}.
## An id with no script yet gives null, which means that rule simply does nothing for now.
static func create(entry: Dictionary, owner: Unit) -> Ability:
	var path := "res://scripts/battle/abilities/%s.gd" % entry.id
	if not ResourceLoader.exists(path):
		return null
	var ability: Ability = load(path).new()
	ability.params = entry
	ability.unit = owner
	return ability


func number(key: String) -> float:
	return float(params.get(key, 0.0))


## Runs once when the unit enters the field, after all its abilities exist.
func on_spawn(_sim: BattleSim) -> void:
	pass


## Runs when the player presses this evolution's ability button.
func on_activate(_sim: BattleSim) -> void:
	pass


## Finds another ability on the same unit by its id, so an evolution can build on the card's normal ability.
func sibling(id: String) -> Ability:
	for ability in unit.abilities:
		if ability.params.get("id") == id:
			return ability
	return null


## Runs every tick before anyone moves, which is where abilities set speed changes and other short effects.
func tick(_sim: BattleSim) -> void:
	pass


## Lets the ability change damage this unit is about to deal.
func on_hit(_sim: BattleSim, _victim: Unit, amount: float) -> float:
	return amount


## Lets the ability react to damage this unit is about to take, and change it.
func on_hurt(_sim: BattleSim, _attacker: Unit, amount: float) -> float:
	return amount


## Lets the ability change how long a stun on this unit lasts. Returning zero means the stun does nothing.
func on_stunned(_sim: BattleSim, seconds: float) -> float:
	return seconds


## Runs when this unit's hit finishes off an enemy.
func on_kill(_sim: BattleSim, _victim: Unit) -> void:
	pass
