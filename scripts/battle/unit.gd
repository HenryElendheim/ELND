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

var deploy_left := 0.0
var cooldown := 0.0
var awake := true
var target: Unit = null
var last_attacker: Unit = null
## Counts down the ticks of the white hit flash.
var flash := 0


func alive() -> bool:
	return hp > 0.0


func is_building() -> bool:
	return kind != "troop"


func is_tower() -> bool:
	return kind == "side" or kind == "main"


## Reads the unit's numbers from its data entry. Health keeps the same share it had,
## which means changing max health in Admin Mode mid-match does not heal or kill anything.
func apply_stats(stats: Dictionary, battle: Dictionary) -> void:
	var scale := pow(1.0 + float(battle.level_scaling.per_level), level - 1)
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = float(stats.get("health", 1)) * scale
	hp = max_hp * share
	damage = float(stats.get("damage", 0)) * scale
	hit_speed = float(stats.get("hit_speed", battle.default_hit_speed))
	ranged = stats.get("attack", "ranged") == "ranged"
	attack_range = float(stats.get("range", battle.melee_range_tiles))
	speed = float(battle.speeds_tiles_per_second.get(stats.get("speed", ""), 0.0))
	flying = stats.get("movement", "ground") == "flying"
	targets = stats.get("targets", "ground")
	radius = float(stats.get("size", 0)) / 2.0 if stats.has("size") else float(battle.unit_radius_tiles)
