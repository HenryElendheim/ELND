class_name Unit
extends RefCounted
## One thing on the battlefield, which is either a troop, a building or a tower.
## Towers are units that never move, which means health, attacking and targeting work the same way for all of them.

enum Team { PLAYER, ENEMY }

var id := ""
var label := ""
var kind := "troop"
var team := Team.PLAYER
var level := 1

var pos := Vector2.ZERO
## Where the unit was one tick ago, so the screen can slide smoothly between ticks.
var prev_pos := Vector2.ZERO
var radius := 0.45

var max_hp := 1.0
var hp := 1.0
var damage := 0.0
var hit_speed := 1.0
var attack_range := 1.0
var ranged := false
var speed := 0.0
## Whether the unit flies right now, and whether its card flies at all. Being pulled down only changes the first.
var flying := false
var base_flying := false
## Seconds left of being pulled out of the air, as The Weight does.
var grounded_left := 0.0
## Effects that last a while, from custom powers: slow, haste or poison. Each has a key for the power that gave it,
## so the same power renews its effect instead of stacking it.
var timed := []
var targets := "ground"

var area := false
## How this unit's shots look when it attacks from range. Melee units leave it empty.
var projectile := {}
## Bigger than one when an ability makes the unit grow, which scales its health, damage and size.
var growth := 1.0
var abilities: Array[Ability] = []
## True for a unit played in its evolved form. Its evolution ability is also in abilities, and it has an ability button.
var evolved := false
var evolution: Ability = null
## The battle time when the evolution button can be used again.
var evolution_ready_at := 0.0
## Seconds left of Cuddle, which stops all attacks, and of Flatten, which stops anything targeting the unit.
var calm_left := 0.0
var hidden_left := 0.0
## Units from the same card play share a group number, so a swarm can react together.
var group := 0
## False for anomalies with no life in them, such as The Hanged One. Effects that drain, lure, heal or enrage skip them.
var living := true
## True for a copy made by The Clone. It is weaker, and some abilities treat it differently.
var is_clone := false
## Multiply health and damage on top of the level, which is how clones come out weaker. They can differ,
## so a clone can keep more of its health than its damage or the other way round.
var strength := 1.0
var damage_strength := 1.0
## The unit's level, growth and damage strength together. Abilities multiply their damage and healing by it,
## which means an ability scales with levels the same way normal hits do.
var power := 1.0

## How far the unit moved during the last tick, which tells others whether it is walking on or standing in the way.
var last_step := Vector2.ZERO
## Which way the unit is stepping around something in its path: 1 or -1, or 0 when nothing is in the way.
## It keeps the same side for a moment, which stops it from wobbling back and forth.
var steer_side := 0.0
var steer_until := 0.0
## The open spot around its goal the unit is heading for, worked out a few times a second instead of every tick.
## Null means it heads straight for the goal itself.
var approach_spot: Variant = null
var approach_goal: Unit = null
var approach_until := 0.0

var deploy_left := 0.0
var cooldown := 0.0
var awake := true
var target: Unit = null
var last_attacker: Unit = null
## The unit holding this one, such as a Creeler carrying it or a Gasket it lies in. A held unit cannot do anything.
var carrier: Unit = null
## How long the unit stays dazed once its carrier is gone.
var release_daze := 0.0
var stun_left := 0.0
## Units hit by the same casting of The Chain share a link group, and damage to one is copied to the others until link_until.
var link_group := 0
var link_until := -INF
## Extra health on top of the normal health bar that is used up first, such as Kardemosh's stolen skin.
var shield := 0.0
var spawn_time := 0.0
var last_attack_time := -INF
var last_kill_time := -INF
## Counts down the ticks of the white hit flash.
var flash := 0

# Short effects that abilities set again every tick. They go back to normal at the start of each tick,
# which means an effect simply stops once nothing keeps setting it.
var attack_speed := 1.0
var move_speed := 1.0
var damage_taken := 1.0
var can_attack := true
var dread := 0.0
var taunt_radius := 0.0
var goal_override: Variant = null
## True while the unit blinks, as The Individuals do. Together with stuns, this is when its eyes are closed.
var blinking := false
## The Devil In The Forest charming this troop right now, which makes it walk up close instead of shooting from afar.
var charmed_by: Unit = null
## True while The Danger Zone enrages the unit, and while The Spiker's field slows it, so the screen can show it.
var enraged := false
var slowed := false


func alive() -> bool:
	return hp > 0.0


## Towers count as buildings, which means troops that only attack buildings go for them.
func is_building() -> bool:
	return kind == "building" or is_tower()


## Spells are short-lived, invisible units that nobody can attack.
func is_spell() -> bool:
	return kind == "spell"


## The enemy core in Defense mode counts as a tower too.
func add_timed(key: String, kind: String, amount: float, until: float) -> void:
	for effect in timed:
		if effect.key == key and effect.kind == kind:
			effect.amount = amount
			effect.until = until
			return
	timed.append({"key": key, "kind": kind, "amount": amount, "until": until})


func is_tower() -> bool:
	return kind == "side" or kind == "main" or kind == "core"


## A living troop that is not held by anything, which is what drains, heals and rages work on.
func is_living_troop() -> bool:
	return kind == "troop" and living and alive() and carrier == null


## Stunned or blinking units have their eyes closed, which means sight-based effects such as The Devil's smile miss them.
func eyes_closed() -> bool:
	return stun_left > 0.0 or blinking


func reset_effects() -> void:
	attack_speed = 1.0
	move_speed = 1.0
	damage_taken = 1.0
	can_attack = true
	dread = 0.0
	taunt_radius = 0.0
	goal_override = null
	blinking = false
	charmed_by = null
	enraged = false
	slowed = false


## Reads the unit's numbers from its data entry. Health keeps the same share it had,
## which means changing max health in Admin Mode mid-match does not heal or kill anything.
func apply_stats(stats: Dictionary, battle: Dictionary) -> void:
	var levelled := pow(1.0 + float(battle.level_scaling.per_level), level - 1) * growth
	power = levelled * damage_strength
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = float(stats.get("health", 1)) * levelled * strength
	hp = max_hp * share
	damage = float(stats.get("damage", 0)) * power
	living = bool(stats.get("living", true))
	hit_speed = float(stats.get("hit_speed", battle.default_hit_speed))
	ranged = stats.get("attack", "ranged") == "ranged"
	attack_range = float(stats.get("range", battle.melee_range_tiles))
	speed = float(battle.speeds_tiles_per_second.get(stats.get("speed", ""), 0.0))
	base_flying = stats.get("movement", "ground") == "flying"
	flying = base_flying
	targets = stats.get("targets", "air_ground" if is_spell() else "ground")
	area = stats.get("area", false)
	projectile = stats.get("projectile", battle.default_projectile) if ranged else {}
	radius = float(stats.get("size", 0)) / 2.0 if stats.has("size") else float(stats.get("radius", battle.unit_radius_tiles))
	radius *= 1.0 + (growth - 1.0) / 2.0
