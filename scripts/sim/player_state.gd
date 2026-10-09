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
