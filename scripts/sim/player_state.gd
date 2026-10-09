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

## Death delay: at 0 HP the player keeps walking on draining "gray HP" (hp stays 0).
var death_delay: bool = false
var gray_hp: float = 0.0
## Set when the delay has been used; cleared on respawn (once per respawn).
var death_delay_used: bool = false
## Training dummies never get a death delay.
var death_delay_allowed: bool = true

## Cosmetic only (CharacterDef id).
var character_id: StringName = &""
## The two equipped weapon ids (slot 0 = weapon 1, slot 1 = weapon 2).
var weapons: Array[StringName] = []
var weapon_cooldowns: Array[float] = [0.0, 0.0]
## Seconds each weapon button has been held; -1 when not held.
var aim_hold: Array[float] = [-1.0, -1.0]
## Buttons from the previous tick, to see presses and releases.
var previous_buttons: int = 0
## Auto-aim taken once when a weapon button is pressed (stick-style vector), so a
## held aim never follows a moving enemy. TARGETED weapons lock a target id instead.
var aim_lock: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var aim_target: Array[int] = [-1, -1]
var effects: StatusEffects = StatusEffects.new()


## Bookmark can be used: off cooldown and not still out on a mark (its cooldown
## only starts once the player is back at the mark).
func bookmark_ready() -> bool:
	return bookmark_cooldown_left <= 0.0 and not mark_active


## Alive, not in death delay, and not mid-dash or stumbling: free to use skills.
func can_act() -> bool:
	return (
		alive and not death_delay and dash_time_left <= 0.0 and stumble_time_left <= 0.0
		and effects.can_cast()
	)
