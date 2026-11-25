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
var flying := false
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
## Units hit by the same Chain share a link group, and damage to one is copied to the others until link_until.
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


func alive() -> bool:
	return hp > 0.0


## Towers count as buildings, which means troops that only attack buildings go for them.
func is_building() -> bool:
	return kind == "building" or is_tower()


## Spells are short-lived, invisible units that nobody can attack.
func is_spell() -> bool:
	return kind == "spell"


func is_tower() -> bool:
	return kind == "side" or kind == "main"


func reset_effects() -> void:
	attack_speed = 1.0
	move_speed = 1.0
	damage_taken = 1.0
	can_attack = true
	dread = 0.0
	taunt_radius = 0.0
	goal_override = null


## Reads the unit's numbers from its data entry. Health keeps the same share it had,
## which means changing max health in Admin Mode mid-match does not heal or kill anything.
func apply_stats(stats: Dictionary, battle: Dictionary) -> void:
	var scale := pow(1.0 + float(battle.level_scaling.per_level), level - 1) * growth
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = float(stats.get("health", 1)) * scale
	hp = max_hp * share
	damage = float(stats.get("damage", 0)) * scale
	hit_speed = float(stats.get("hit_speed", battle.default_hit_speed))
	ranged = stats.get("attack", "ranged") == "ranged"
	attack_range = float(stats.get("range", battle.melee_range_tiles))
	speed = float(battle.speeds_tiles_per_second.get(stats.get("speed", ""), 0.0))
	flying = stats.get("movement", "ground") == "flying"
	targets = stats.get("targets", "air_ground" if is_spell() else "ground")
	area = stats.get("area", false)
	projectile = stats.get("projectile", battle.default_projectile) if ranged else {}
	radius = float(stats.get("size", 0)) / 2.0 if stats.has("size") else float(stats.get("radius", battle.unit_radius_tiles))
	radius *= 1.0 + (growth - 1.0) / 2.0
