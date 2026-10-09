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
## Death delay: at 0 HP a player (once per respawn) keeps walking with "gray HP" that
## drains while moving. A living teammate touching them, or the player touching their own
## base post, revives them with the gray HP they have left. Skills are off meanwhile.
@export var death_delay_enabled: bool = false
@export var death_delay_gray_hp: float = 0.0
## Gray HP lost per second at full stick (scaled by stick length; standing still is free).
@export var death_delay_drain_per_second: float = 0.0
@export var death_delay_move_speed_scale: float = 0.0
## Center-to-center distance at which a teammate's touch revives.
@export var revive_touch_distance: float = 0.0
## Distance to the own base post center at which touching it revives.
@export var post_touch_distance: float = 0.0
## Data toggle (GDD D8): can enemies damage a player in death delay? Default no.
@export var death_delay_takes_damage: bool = false
## Every weapon in the game (docs/GDD.md "Weapons"); each player equips two different ones.
@export var weapons: Array[WeaponDef] = []
## The six cosmetic characters, assigned at random with no duplicates.
@export var characters: Array[CharacterDef] = []
## Weapon pick time (match start and while waiting to respawn).
@export var weapon_pick_time: float = 0.0
## POLYMORPH: walk at this fraction of normal speed (no casting).
@export var polymorph_speed_scale: float = 0.0
## Aim stick shorter than this counts as "no aim" and the weapon auto-aims.
@export var aim_deadzone: float = 0.0
## A returning boomerang is caught when this close to its thrower.
@export var boomerang_catch_distance: float = 0.0
## Scoring (volleyball format): stand in the enemy base zone this long to score.
@export var base_capture_time: float = 0.0
## Freeze after a point before everyone is reset to their bases.
@export var point_freeze_time: float = 0.0
## A set is won at `set_points_to_win` with a lead of `set_win_by`, or at `set_point_cap`.
@export var set_points_to_win: int = 0
@export var set_win_by: int = 0
@export var set_point_cap: int = 0
## Sets needed to win the match (best of 3 = 2).
@export var match_sets_to_win: int = 0
## Rubber ball: spawns at the lane center this long after there is no ball.
@export var ball_spawn_interval: float = 0.0
@export var ball_range: float = 0.0
@export var ball_speed: float = 0.0
@export var ball_radius: float = 0.0
## The holder walks at this fraction of normal speed.
@export var ball_holder_speed_scale: float = 0.0
## KNOCKOUT duration on an enemy hit by the ball.
@export var ball_knockout_time: float = 0.0
@export var ball_wall_damage: int = 0
## An enemy who pressed the ball button this recently before contact catches it (D2).
@export var ball_catch_window: float = 0.0
## Tricycle: first crossing and the time between crossings.
@export var tricycle_first_time: float = 0.0
@export var tricycle_interval: float = 0.0
## Horn + lane marker this long before it drives in.
@export var tricycle_warning_time: float = 0.0
@export var tricycle_crossing_time: float = 0.0
## Push distance away from its path (D4), spread over `tricycle_push_time`.
@export var tricycle_knockback: float = 0.0
@export var tricycle_push_time: float = 0.0
@export var tricycle_length: float = 0.0
@export var tricycle_width: float = 0.0
## Practice-mode training dummies (two enemies and one ally).
@export var dummy_z: float = 0.0
@export var dummy_stand_x: float = 0.0
@export var dummy_patrol_x: float = 0.0
@export var dummy_patrol_range: float = 0.0
@export var dummy_patrol_speed_scale: float = 0.0
@export var dummy_ally_x: float = 0.0
@export var dummy_ally_z: float = 0.0


## Fixed simulation step in seconds (1 / tick_rate).
func tick_dt() -> float:
	return 1.0 / tick_rate
