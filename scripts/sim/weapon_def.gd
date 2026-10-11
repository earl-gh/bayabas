class_name WeaponDef
extends Resource
## One weapon (docs/GDD.md "Weapons"). Every weapon is one generic `shape`
## executor plus numbers; no per-weapon scripts. Values live in data/weapons/*.tres.

enum Kind { ATTACK, CROWD_CONTROL, BLOCK, HEAL }
enum Shape {
	TARGETED,   ## projectile that homes on the nearest enemy in range
	CONE,       ## instant (or delayed) cone in the aim direction; light version snips 2-6 times by hold time
	GROUND_AOE, ## circle at the aimed point after a delay (plus travel time if speed > 0)
	TRAP,       ## placed; arms, then turns into a slow zone when an enemy steps near
	FIELD,      ## placed zone that ticks damage + effect for a while
	BOOMERANG,  ## out to range and back to the thrower, hits each enemy once per direction
	SHIELD,     ## wall in front of the thrower that blocks enemy projectiles
	BOUNCER,    ## skillshot that bounces `count` times evenly up to max range, AoE at each bounce
	SPINNER,    ## linear projectile that passes through enemies up to max range
	HEAL,       ## instant: tap heals the caster, a drag picks a teammate in that direction within max range
}

@export var id: StringName = &""
@export var display_name: String = ""
## Short button label.
@export var short_name: String = ""
## Street game it belongs to (weapon pick grouping).
@export var street_game: String = ""
@export var kind: Kind = Kind.ATTACK
@export var shape: Shape = Shape.TARGETED
@export var cooldown: float = 0.0
@export var max_range: float = 0.0
@export var damage: int = 0
## Area radius (AoE, trap/field zone, bounce AoE) or the pass-through hit radius (spinner).
@export var radius: float = 0.0
@export var angle_degrees: float = 0.0
## Wind-up before the effect lands (ground AoE, heavy cone).
@export var delay: float = 0.0
## Projectile speed in m/s (0 = instant).
@export var speed: float = 0.0
## Projectiles per cast (boomerang) or bounces (bouncer).
@export var count: int = 1
## Seconds between boomerangs, or between field damage ticks.
@export var interval: float = 0.0
## Zone / shield duration.
@export var duration: float = 0.0
## Trap: time before it can trigger; then it waits up to `lifetime` for an enemy.
@export var arm_time: float = 0.0
@export var trigger_radius: float = 0.0
@export var lifetime: float = 0.0
## Shield width and its distance in front of the thrower.
@export var width: float = 0.0
@export var offset: float = 0.0
## Projectile hit radius (targeted, boomerang, bouncer).
@export var projectile_radius: float = 0.0
@export var effect: StatusEffects.Type = StatusEffects.Type.NONE
@export var effect_duration: float = 0.0
## SLOW strength (0.4 = 40% slower).
@export var effect_magnitude: float = 0.0
## Cone snips: tap = min, +1 per `snip_hold_step` seconds held, up to max.
@export var snips_min: int = 1
@export var snips_max: int = 1
@export var snip_hold_step: float = 0.0
## HEAL: HP restored per cast.
@export var heal: int = 0
## How a SHIELD looks: &"" = a paper wall, &"soil" = a block of earth that rises and collapses.
@export var look: StringName = &""
## Seconds the caster cannot move after the cast (heavy attacks; 0 = can move while casting).
@export var cast_lock: float = 0.0


func deals_damage() -> bool:
	return damage > 0


func kind_label() -> String:
	match kind:
		Kind.ATTACK:
			return "ATK"
		Kind.CROWD_CONTROL:
			return "CC"
		Kind.HEAL:
			return "HEAL"
	return "BLK"


## Snips for a cone cast after holding the button for `hold_seconds`.
func snip_count(hold_seconds: float) -> int:
	if snips_max <= snips_min or snip_hold_step <= 0.0:
		return snips_min
	return clampi(snips_min + floori(hold_seconds / snip_hold_step), snips_min, snips_max)
