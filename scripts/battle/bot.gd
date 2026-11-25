class_name Bot
extends RefCounted
## The opponent that plays the enemy hand. Every so often it looks at the field.
## If the player has troops on its half, it defends, and a bot with good counter-play picks the card that actually answers them.
## Otherwise it either backs up its own push with a supporting troop, or saves up and starts a new push in a random lane.
## How long it waits, how much it saves and how well it counters come from the difficulty in Settings and bot.json.

var enabled := true

var _team := Unit.Team.ENEMY
var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int) -> void:
	_rng.seed = rng_seed


## The difficulty knobs in use. Custom difficulty reads the sliders from Settings instead of a preset.
static func knobs() -> Dictionary:
	var bot := Data.table("bot")
	var difficulty: String = Settings.get_value("bot_difficulty")
	if difficulty == "custom":
		return {
			"reaction_time": Settings.get_value("bot_reaction_time"),
			"ephrocity_smarts": Settings.get_value("bot_ephrocity_smarts"),
			"counter_play": Settings.get_value("bot_counter_play"),
		}
	return bot.presets.get(difficulty, bot.presets[bot.default_difficulty])


## Builds the bot's deck. A random deck is just any cards. A synergy deck always has something that goes for towers
## and something that can hit flying troops, then fills up at random. A mixed deck is a synergy deck half of the time.
func pick_deck_for(available: Array, size: int, knob: Dictionary) -> Array:
	return pick_deck(available, size, knob, _rng)


static func pick_deck(available: Array, size: int, knob: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool := available.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var quality: String = knob.get("deck_quality", "mixed")
	var deck := []
	if quality == "synergy" or (quality == "mixed" and rng.randf() < 0.5):
		var cards: Dictionary = Data.table("cards").cards
		for need in ["towers", "air"]:
			for id in pool:
				if not id in deck and _fills(cards[id], need):
					deck.append(id)
					break
	for id in pool:
		if deck.size() >= size:
			break
		if not id in deck:
			deck.append(id)
	return deck


## Whether a card covers a need a good deck has: something that goes for towers, or something that can hit the air.
static func _fills(card: Dictionary, need: String) -> bool:
	if need == "towers":
		return card.get("targets") == "buildings"
	return card.get("targets") == "air_ground" or card.get("type") == "spell"


func think(sim: BattleSim) -> void:
	_wait -= sim.tick
	if not enabled or _wait > 0.0:
		return
	var knob := knobs()
	var placement: Dictionary = Data.table("bot").placement
	_wait = float(knob.reaction_time) * _rng.randf_range(0.7, 1.3)

	_use_evolutions(sim, float(knob.counter_play))
	var hand: Hand = sim.hands[_team]
	var affordable := []
	for slot in hand.in_hand().size():
		if hand.can_afford(slot):
			affordable.append(slot)
	if affordable.is_empty():
		return

	var threats := _threats(sim)
	if not threats.is_empty():
		var answer := _pick_counter(hand, affordable, threats, float(knob.counter_play))
		sim.play(_team, answer, _defend_spot(sim, threats[0], hand.cards[answer], placement))
		return

	var slot: int = affordable[_rng.randi() % affordable.size()]
	var leader := _own_push(sim)
	var smarts := float(knob.ephrocity_smarts)
	if leader != null and _rng.randf() < smarts:
		var behind := leader.pos - Vector2(0, float(placement.support_offset_tiles))
		if sim.play(_team, slot, behind):
			return
	# Saving up means waiting until Ephrocity is somewhere between the card's cost and full, and smarter bots wait longer.
	var full := float(Data.table("battle").ephrocity.max)
	if hand.ephrocity >= lerpf(Hand.cost_of(hand.cards[slot]), full, smarts):
		sim.play(_team, slot, _push_spot(placement))


## Presses the bot's evolution buttons when one of the player's troops is close, as often as its counter-play allows.
func _use_evolutions(sim: BattleSim, counter_play: float) -> void:
	for unit in sim.evolution_buttons(_team):
		if not sim.evolution_ready(unit) or _rng.randf() >= counter_play:
			continue
		for other in sim.units:
			if other.team != _team and other.kind == "troop" and other.alive() and other.pos.distance_to(unit.pos) <= float(Data.table("bot").placement.evolution_reach_tiles):
				sim.activate_evolution(unit)
				break


## Player troops on the bot's half, closest to the bot's towers first.
func _threats(sim: BattleSim) -> Array[Unit]:
	var river_top := float(Data.table("battle").arena.river_top)
	var found: Array[Unit] = []
	for unit in sim.units:
		if unit.team != _team and unit.kind == "troop" and unit.pos.y < river_top:
			found.append(unit)
	found.sort_custom(func(a: Unit, b: Unit) -> bool: return a.pos.y < b.pos.y)
	return found


## With a chance equal to its counter-play, the bot scores every card it can afford against the threats and plays the best one.
## Otherwise it just plays a random affordable card.
func _pick_counter(hand: Hand, affordable: Array, threats: Array[Unit], counter_play: float) -> int:
	if _rng.randf() >= counter_play:
		return affordable[_rng.randi() % affordable.size()]
	var best: int = affordable[0]
	var best_score := -INF
	for slot in affordable:
		var score := counter_score(Data.table("cards").cards[hand.cards[slot]], threats)
		if score > best_score:
			best = slot
			best_score = score
	return best


## How well a card answers a group of enemy troops. A card that cannot hit a flying threat is useless against it.
## Area and swarm cards are better against many small troops, and high damage is better against one big troop.
## Cheaper answers score a little higher, which means the bot does not waste Ephrocity.
static func counter_score(card: Dictionary, threats: Array[Unit]) -> float:
	var score := 0.0
	var flying := threats.any(func(t: Unit) -> bool: return t.flying)
	var hits_air: bool = card.get("targets") == "air_ground" and (card.get("attack") == "ranged" or card.get("movement") == "flying")
	if flying and not hits_air:
		return -100.0
	if card.get("targets") in ["buildings", "none"]:
		score -= 5.0
	var count := float(card.get("count", 1))
	var damage_per_second := float(card.get("damage", 0)) * count / maxf(float(card.get("hit_speed", 1.0)), 0.1)
	var biggest := 0.0
	for threat in threats:
		biggest = maxf(biggest, threat.max_hp)
	if threats.size() >= 3:
		score += 10.0 if card.get("area", false) or count > 1 else 0.0
	else:
		score += damage_per_second / 5.0 + float(card.get("health", 0)) / maxf(biggest, 1.0)
	return score - float(card.get("cost", 0))


## The bot's own troop that is furthest along toward the player's towers, if any is walking.
func _own_push(sim: BattleSim) -> Unit:
	var best: Unit = null
	for unit in sim.units:
		if unit.team == _team and unit.kind == "troop" and unit.deploy_left <= 0.0:
			if best == null or unit.pos.y > best.pos.y:
				best = unit
	return best


## Ranged cards defend from further back, which keeps them out of reach of melee troops.
func _defend_spot(sim: BattleSim, threat: Unit, card_id: String, placement: Dictionary) -> Vector2:
	var arena: Dictionary = Data.table("battle").arena
	var card: Dictionary = Data.table("cards").cards[card_id]
	var offset := float(placement.defend_offset_tiles)
	if card.get("attack") == "ranged":
		offset += float(card.get("range", 0)) / 2.0
	var spot := threat.pos - Vector2(0, offset)
	spot.y = clampf(spot.y, 1.0, float(arena.river_top) - 0.5)
	return spot if sim.can_place(_team, spot) else Vector2(threat.pos.x, 1.0)


## A spot at the back of a random lane, or sometimes right at the bridge for a faster push.
func _push_spot(placement: Dictionary) -> Vector2:
	var arena: Dictionary = Data.table("battle").arena
	var lanes: Array = arena.bridge_x
	var x := float(lanes[_rng.randi() % lanes.size()]) + _rng.randf_range(-1.0, 1.0)
	if _rng.randf() < float(placement.push_at_bridge_chance):
		return Vector2(x, float(arena.river_top) - float(placement.bridge_row_from_river))
	return Vector2(x, float(placement.push_row_from_back))
