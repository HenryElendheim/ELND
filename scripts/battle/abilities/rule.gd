class_name Rule
extends Ability
## A power built in the Admin editor from three parts: when it happens, what it does, and who it happens to.
## For example every 3 seconds, deal 20 damage, to enemies within 2.5 tiles. A card can have several,
## and an evolution button can be one, with when set to the button. Every part and number lives in the card's data.
## The numbers: amount (damage, healing, shield, poison per second, tiles to push or pull, cards to spawn),
## share (how much slower or faster, or how much of a hit is stolen back), radius, seconds, every, below
## (the health share for low health), chance (from 0 to 1) and spawns (the card or token to spawn).

const WHEN := [
	["every", "Every few seconds"], ["always", "Always (an aura)"], ["on_hit", "When it hits"], ["on_hurt", "When it is hit"],
	["on_deploy", "When it is placed"], ["low_health", "Once at low health"], ["on_death", "When it dies"], ["button", "Its evolution button"],
]
const DO := [
	["damage", "Damage"], ["heal", "Heal"], ["stun", "Stun"], ["slow", "Slow"], ["haste", "Speed up"], ["shield", "Shield"],
	["knockback", "Knock back"], ["pull", "Pull in"], ["ground", "Pull flyers down"], ["poison", "Poison"], ["lifesteal", "Lifesteal"], ["spawn", "Spawn"],
]
const TO := [
	["target", "Its target"], ["self", "Itself"], ["attacker", "Whoever hit it"], ["enemies_near", "Enemies nearby"],
	["allies_near", "Allies nearby"], ["nearest_enemy", "Nearest enemy"], ["strongest_enemy", "Strongest enemy nearby"],
]
## What a new custom power starts as, before it is tuned.
const STARTER := {"id": "rule", "when": "every", "do": "damage", "to": "enemies_near", "amount": 20.0, "share": 0.3, "radius": 2.5, "seconds": 2.0, "every": 3.0, "below": 0.5, "chance": 1.0, "spawns": "broodling"}

var _wait := 0.0
var _deployed := false
var _low_done := false
## Stops a power that fires on a hit from setting itself off again with its own damage.
var _firing := false
var _rng := RandomNumberGenerator.new()


func on_spawn(_sim: BattleSim) -> void:
	_rng.seed = unit.group * 31 + 7
	_wait = number("every", 3.0)


func _when() -> String:
	return String(params.get("when", "every"))


func tick(sim: BattleSim) -> void:
	match _when():
		"every":
			_wait -= sim.tick
			if _wait <= 0.0:
				_wait = number("every", 3.0)
				fire(sim, null, 0.0)
		"always":
			fire(sim, null, 0.0)
		"on_deploy":
			if not _deployed:
				_deployed = true
				fire(sim, null, 0.0)
		"low_health":
			if not _low_done and unit.hp < unit.max_hp * number("below", 0.5):
				_low_done = true
				fire(sim, null, 0.0)


func on_hit(sim: BattleSim, victim: Unit, amount: float) -> float:
	if _when() == "on_hit":
		fire(sim, victim, amount)
	return amount


func on_hurt(sim: BattleSim, attacker: Unit, amount: float) -> float:
	if _when() == "on_hurt" and attacker != null:
		fire(sim, attacker, amount)
	return amount


func on_death(sim: BattleSim) -> void:
	if _when() == "on_death":
		fire(sim, null, 0.0)


func on_activate(sim: BattleSim) -> void:
	fire(sim, null, 0.0)


## Does the power once, to everyone it is aimed at. The other unit is whoever was hit, or whoever hit it,
## and the amount is how much that hit was for.
func fire(sim: BattleSim, other: Unit, hit: float) -> void:
	if _firing or _rng.randf() > number("chance", 1.0):
		return
	_firing = true
	var what := String(params.get("do", "damage"))
	for who in _targets(sim, other):
		_apply(sim, what, who, hit)
	_firing = false


func _targets(sim: BattleSim, other: Unit) -> Array[Unit]:
	var found: Array[Unit] = []
	var radius := number("radius", 2.5)
	match String(params.get("to", "enemies_near")):
		"self":
			found.append(unit)
		"target":
			var aim: Unit = other if other != null and other.team != unit.team else unit.target
			if aim != null and aim.alive():
				found.append(aim)
		"attacker":
			var hitter: Unit = other if other != null else unit.last_attacker
			if hitter != null and hitter.alive():
				found.append(hitter)
		"allies_near":
			for ally in sim.units:
				if ally != unit and ally.team == unit.team and ally.alive() and not ally.is_spell() and _near(ally, radius):
					found.append(ally)
		_:
			var enemies: Array[Unit] = []
			for enemy in sim.units:
				if enemy.team != unit.team and enemy.alive() and not enemy.is_spell() and enemy.carrier == null and _near(enemy, radius):
					enemies.append(enemy)
			match String(params.get("to", "enemies_near")):
				"nearest_enemy":
					enemies.sort_custom(func(a: Unit, b: Unit) -> bool: return unit.pos.distance_to(a.pos) < unit.pos.distance_to(b.pos))
					found.append_array(enemies.slice(0, 1))
				"strongest_enemy":
					enemies.sort_custom(func(a: Unit, b: Unit) -> bool: return a.hp > b.hp)
					found.append_array(enemies.slice(0, 1))
				_:
					found = enemies
	return found


func _near(other: Unit, radius: float) -> bool:
	return unit.pos.distance_to(other.pos) - other.radius <= radius


func _apply(sim: BattleSim, what: String, who: Unit, hit: float) -> void:
	var amount := number("amount", 20.0)
	var seconds := number("seconds", 2.0)
	var key := "%d" % get_instance_id()
	match what:
		"damage":
			sim.deal_damage(unit, who, amount * unit.power)
		"heal":
			if who.living:
				who.hp = minf(who.hp + amount * unit.power, who.max_hp)
		"stun":
			sim.stun(who, seconds)
		"slow":
			who.add_timed(key, "slow", number("share", 0.3), sim.time + seconds)
		"haste":
			who.add_timed(key, "haste", number("share", 0.3), sim.time + seconds)
		"shield":
			who.shield += amount * unit.power
		"knockback":
			sim.knock_back(who, unit.pos, amount)
		"pull":
			if not who.is_building():
				who.pos = who.pos.move_toward(unit.pos, minf(amount, maxf(who.pos.distance_to(unit.pos) - unit.radius - who.radius, 0.0)))
		"ground":
			if who.base_flying:
				who.grounded_left = maxf(who.grounded_left, seconds)
		"poison":
			who.add_timed(key, "poison", amount * unit.power, sim.time + seconds)
		"lifesteal":
			unit.hp = minf(unit.hp + hit * number("share", 0.3), unit.max_hp)
		"spawn":
			var card := String(params.get("spawns", ""))
			if Data.table("cards").cards.has(card):
				var count := maxi(roundi(amount), 1)
				var team := unit.team
				var level := unit.level
				var at := who.pos
				sim.later(func() -> void: _spawn(sim, card, count, team, level, at))


static func _spawn(sim: BattleSim, card: String, count: int, team: Unit.Team, level: int, at: Vector2) -> void:
	for i in count:
		for made in sim.spawn(card, team, at + Vector2.from_angle(TAU * i / count) * 0.5, level):
			made.deploy_left = 0.3
			made.spawn_time = sim.time + made.deploy_left


## A custom power in plain words, such as "Every 3 s: deals 20 damage to enemies within 2.5 tiles."
static func describe(p: Dictionary) -> String:
	var when := String(p.get("when", "every"))
	var start: String = {
		"every": "Every %s s" % _num(p.get("every", 3.0)), "always": "Always", "on_hit": "When it hits",
		"on_hurt": "When it is hit", "on_deploy": "When it is placed", "low_health": "Once below %s%% health" % _num(float(p.get("below", 0.5)) * 100.0),
		"on_death": "When it dies", "button": "Its button",
	}.get(when, "Every few seconds")
	var chance := float(p.get("chance", 1.0))
	if chance < 1.0:
		start += " (%s%% chance)" % _num(chance * 100.0)
	var amount := _num(p.get("amount", 20.0))
	var share := _num(float(p.get("share", 0.3)) * 100.0)
	var seconds := _num(p.get("seconds", 2.0))
	var action: String = {
		"damage": "deals %s damage to" % amount, "heal": "heals %s health on" % amount, "stun": "stuns for %s s" % seconds,
		"slow": "slows by %s%% for %s s" % [share, seconds], "haste": "speeds up by %s%% for %s s" % [share, seconds],
		"shield": "gives a %s shield to" % amount, "knockback": "knocks back %s tiles" % amount, "pull": "pulls in %s tiles" % amount,
		"ground": "pulls down flyers for %s s among" % seconds, "poison": "poisons for %s a second over %s s" % [amount, seconds],
		"lifesteal": "heals itself by %s%% of the hit from" % share, "spawn": "spawns %s %s at" % [amount, String(p.get("spawns", ""))],
	}.get(String(p.get("do", "damage")), "acts on")
	var radius := _num(p.get("radius", 2.5))
	var aim: String = {
		"target": "its target", "self": "itself", "attacker": "whoever hit it", "enemies_near": "enemies within %s tiles" % radius,
		"allies_near": "allies within %s tiles" % radius, "nearest_enemy": "the nearest enemy within %s tiles" % radius,
		"strongest_enemy": "the strongest enemy within %s tiles" % radius,
	}.get(String(p.get("to", "enemies_near")), "")
	return "%s: %s %s." % [start, action, aim]


static func _num(value: Variant) -> String:
	var v := float(value)
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else str(snappedf(v, 0.1))
