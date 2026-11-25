class_name Projectile
extends RefCounted
## A shot from a ranged troop or a tower. It flies toward its target and deals the attacker's damage when it lands,
## which means what you see hitting is exactly when the damage happens. If the target dies first, the shot just fades.

var attacker: Unit
var target: Unit
var team := Unit.Team.PLAYER
var damage := 0.0
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
## How the shot looks and how fast it flies, straight from the data files: style, speed, size and colour.
var look := {}
