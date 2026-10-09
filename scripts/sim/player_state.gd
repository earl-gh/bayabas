class_name PlayerState
extends RefCounted
## Per-player simulation state. Plain data; MatchSim owns and mutates it.

var id: int = 0
var team: int = 0
## Position in the XZ plane (x, z). +Z is the own-base end of the lane.
var position: Vector2 = Vector2.ZERO
## Last non-zero move direction.
var facing: Vector2 = Vector2.ZERO
var hp: int = 0
var alive: bool = true
var radius: float = 0.0
## Where this player (re)spawns.
var spawn_position: Vector2 = Vector2.ZERO
var respawn_time_left: float = 0.0

var dash_time_left: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var stumble_time_left: float = 0.0
var dash_cooldown_left: float = 0.0

var bookmark_cooldown_left: float = 0.0
var boost_time_left: float = 0.0
var mark_active: bool = false
var mark_position: Vector2 = Vector2.ZERO


## Alive and not mid-dash or stumbling: free to move and use skills.
func can_act() -> bool:
	return alive and dash_time_left <= 0.0 and stumble_time_left <= 0.0
