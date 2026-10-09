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
