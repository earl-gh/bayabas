class_name GameRules
extends Resource
## Global gameplay numbers (docs/GDD.md "Core"). Values live in
## data/rules/game_rules.tres; nothing here is hardcoded.

@export var tick_rate: int = 0
@export var player_max_hp: int = 0
@export var move_speed: float = 0.0
@export var player_radius: float = 0.0
@export var respawn_time: float = 0.0
@export var spawn_spacing: float = 0.0
## Takbo (dash): distance over `dash_duration`, then a stumble where the player can't move or cast.
@export var dash_distance: float = 0.0
@export var dash_duration: float = 0.0
@export var dash_stumble: float = 0.0
@export var dash_cooldown: float = 0.0
## Bookmark: leave a mark, blink forward, get a speed bonus; when the boost ends the player returns to the mark.
@export var bookmark_blink: float = 0.0
@export var bookmark_speed_bonus: float = 0.0
@export var bookmark_boost_duration: float = 0.0
@export var bookmark_cooldown: float = 0.0
## Data toggle: return to the mark when the boost ends (GDD D7 default).
@export var bookmark_returns: bool = false


## Fixed simulation step in seconds (1 / tick_rate).
func tick_dt() -> float:
	return 1.0 / tick_rate
