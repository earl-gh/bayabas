class_name WeaponSystem
extends RefCounted
## Runs every weapon effect that outlives the cast tick: projectiles, delayed
## areas, traps, fields, shields and queued boomerangs. Owned by MatchSim; plain
## data and math, no nodes. Generic per WeaponDef.Shape, never per weapon.

## Max distance a projectile moves between hit checks (keeps fast ones from skipping targets).
const PROJECTILE_STEP: float = 0.25

enum ZoneKind { EXPLOSION, TRAP, SLOW_ZONE, FIELD }

## A cone weapon struck (instant, so the view gets a signal to flash it).
signal cone_struck(owner_id: int, def: WeaponDef, origin: Vector2, direction: Vector2)


class Projectile extends RefCounted:
	var id: int
	var owner_id: int
	var team: int
	var def: WeaponDef
	var position: Vector2
	var direction: Vector2
	var travelled: float = 0.0
	## TARGETED: homes on this player.
	var target_id: int = -1
	## BOOMERANG: false = going out, true = coming back.
	var returning: bool = false
	## BOUNCER: bounces done so far.
	var bounces: int = 0
	## Ids already hit (per direction for boomerangs, once for spinners).
	var hit_ids: Dictionary[int, bool] = {}


class Zone extends RefCounted:
	var id: int
	var owner_id: int
	var team: int
	var def: WeaponDef
	var kind: ZoneKind
	var center: Vector2
	var radius: float
	## EXPLOSION: until it lands. TRAP: until it expires. SLOW_ZONE / FIELD: until it ends.
	var time_left: float
	## TRAP: arming time left. FIELD: time to the next damage tick.
	var timer: float = 0.0


class Shield extends RefCounted:
	var id: int
	var team: int
	var center: Vector2
	## Unit vector along the wall.
	var along: Vector2
	var half_width: float
	var time_left: float


class PendingCone extends RefCounted:
	var owner_id: int
	var def: WeaponDef
	var direction: Vector2
	var time_left: float


class QueuedThrow extends RefCounted:
	var owner_id: int
	var def: WeaponDef
	var direction: Vector2
	var time_left: float


var projectiles: Array[Projectile] = []
var zones: Array[Zone] = []
var shields: Array[Shield] = []

var _cones: Array[PendingCone] = []
var _throws: Array[QueuedThrow] = []
var _next_id: int = 1


## Casts `def` for `caster`. `aim` is the world-space aim stick (length 0..1, zero
## = auto-aim). Returns false when nothing could be cast (e.g. no target in range),
## in which case no cooldown is spent.
func fire(sim: MatchSim, caster: PlayerState, def: WeaponDef, aim: Vector2, hold_seconds: float) -> bool:
	match def.shape:
		WeaponDef.Shape.TARGETED:
			var target: PlayerState = sim.nearest_enemy(caster, def.max_range)
			if target == null:
				return false
			var projectile: Projectile = _new_projectile(caster, def, caster.position.direction_to(target.position))
			projectile.target_id = target.id
		WeaponDef.Shape.CONE:
			var direction: Vector2 = aim_direction(sim, caster, def, aim)
			if def.delay > 0.0:
				var cone: PendingCone = PendingCone.new()
				cone.owner_id = caster.id
				cone.def = def
				cone.direction = direction
				cone.time_left = def.delay
				_cones.append(cone)
			else:
				_hit_cone(sim, caster, def, direction, def.snip_count(hold_seconds))
		WeaponDef.Shape.GROUND_AOE:
			var point: Vector2 = aim_point(sim, caster, def, aim)
			var travel: float = caster.position.distance_to(point) / def.speed if def.speed > 0.0 else 0.0
			_new_zone(caster, def, ZoneKind.EXPLOSION, point, def.radius, def.delay + travel)
		WeaponDef.Shape.TRAP:
			var trap: Zone = _new_zone(caster, def, ZoneKind.TRAP, aim_point(sim, caster, def, aim), def.trigger_radius, def.lifetime)
			trap.timer = def.arm_time
		WeaponDef.Shape.FIELD:
			var field: Zone = _new_zone(caster, def, ZoneKind.FIELD, aim_point(sim, caster, def, aim), def.radius, def.duration)
			field.timer = 0.0
		WeaponDef.Shape.BOOMERANG:
			var direction: Vector2 = aim_direction(sim, caster, def, aim)
			_new_projectile(caster, def, direction)
			for i: int in range(1, def.count):
				var queued: QueuedThrow = QueuedThrow.new()
				queued.owner_id = caster.id
				queued.def = def
				queued.direction = direction
				queued.time_left = def.interval * i
				_throws.append(queued)
		WeaponDef.Shape.SHIELD:
			var facing: Vector2 = aim_direction(sim, caster, def, aim)
			var shield: Shield = Shield.new()
			shield.id = _take_id()
			shield.team = caster.team
			shield.center = caster.position + facing * def.offset
			shield.along = facing.orthogonal()
			shield.half_width = def.width / 2.0
			shield.time_left = def.duration
			shields.append(shield)
		WeaponDef.Shape.BOUNCER, WeaponDef.Shape.SPINNER:
			_new_projectile(caster, def, aim_direction(sim, caster, def, aim))
	return true


func step(sim: MatchSim, dt: float) -> void:
	_step_throws(sim, dt)
	_step_cones(sim, dt)
	_step_projectiles(sim, dt)
	_step_zones(sim, dt)
	_step_shields(dt)


## Clears everything (e.g. between points).
func reset() -> void:
	projectiles.clear()
	zones.clear()
	shields.clear()
	_cones.clear()
	_throws.clear()


# ---- aiming -----------------------------------------------------------------

## Aim stick direction, or toward the nearest enemy in range, or the facing.
func aim_direction(sim: MatchSim, caster: PlayerState, def: WeaponDef, aim: Vector2) -> Vector2:
	if aim.length() >= sim.rules.aim_deadzone:
		return aim.normalized()
	var target: PlayerState = sim.nearest_enemy(caster, def.max_range)
	if target != null and target.position != caster.position:
		return caster.position.direction_to(target.position)
	return caster.facing


## Aimed point (stick length scales the range), or the nearest enemy in range,
## or straight ahead at full range.
func aim_point(sim: MatchSim, caster: PlayerState, def: WeaponDef, aim: Vector2) -> Vector2:
	if aim.length() >= sim.rules.aim_deadzone:
		return caster.position + aim.limit_length(1.0) * def.max_range
	var target: PlayerState = sim.nearest_enemy(caster, def.max_range)
	if target != null:
		return target.position
	return caster.position + caster.facing * def.max_range


# ---- per shape --------------------------------------------------------------

func _hit_cone(sim: MatchSim, caster: PlayerState, def: WeaponDef, direction: Vector2, hits: int) -> void:
	cone_struck.emit(caster.id, def, caster.position, direction)
	var half_angle: float = deg_to_rad(def.angle_degrees / 2.0)
	for target: PlayerState in sim.enemies_of(caster.team):
		var offset: Vector2 = target.position - caster.position
		if offset.length() > def.max_range + target.radius:
			continue
		if offset.length() > 0.001 and absf(direction.angle_to(offset)) > half_angle:
			continue
		for i: int in hits:
			_hit(sim, target, def)


func _step_cones(sim: MatchSim, dt: float) -> void:
	var still: Array[PendingCone] = []
	for cone: PendingCone in _cones:
		cone.time_left -= dt
		if cone.time_left > 0.0:
			still.append(cone)
			continue
		var caster: PlayerState = sim.players.get(cone.owner_id) as PlayerState
		if caster != null and caster.alive and not caster.death_delay:
			_hit_cone(sim, caster, cone.def, cone.direction, 1)
	_cones = still


func _step_throws(sim: MatchSim, dt: float) -> void:
	var still: Array[QueuedThrow] = []
	for queued: QueuedThrow in _throws:
		queued.time_left -= dt
		if queued.time_left > 0.0:
			still.append(queued)
			continue
		var caster: PlayerState = sim.players.get(queued.owner_id) as PlayerState
		if caster != null and caster.alive and not caster.death_delay:
			_new_projectile(caster, queued.def, queued.direction)
	_throws = still


func _step_projectiles(sim: MatchSim, dt: float) -> void:
	var still: Array[Projectile] = []
	for projectile: Projectile in projectiles:
		if _advance_projectile(sim, projectile, projectile.def.speed * dt):
			still.append(projectile)
	projectiles = still


## Moves a projectile in small steps; returns false once it is used up.
func _advance_projectile(sim: MatchSim, projectile: Projectile, distance: float) -> bool:
	var left: float = distance
	var blocking: Array[Rect2] = sim.blocking_rects_for_team(projectile.team)
	while left > 0.0:
		var move: float = minf(PROJECTILE_STEP, left)
		left -= move
		var previous: Vector2 = projectile.position
		if not _move_projectile(sim, projectile, move):
			return false
		if _blocked(projectile, previous, blocking):
			if projectile.def.shape == WeaponDef.Shape.BOOMERANG and not projectile.returning:
				projectile.position = previous
				_turn_back(projectile)
				continue
			return false
		if not _check_hits(sim, projectile):
			return false
	return true


## Steers and moves; returns false when the projectile has finished its flight.
func _move_projectile(sim: MatchSim, projectile: Projectile, move: float) -> bool:
	var def: WeaponDef = projectile.def
	match def.shape:
		WeaponDef.Shape.TARGETED:
			var target: PlayerState = sim.players.get(projectile.target_id) as PlayerState
			if target == null or not sim.is_targetable(target):
				return false
			projectile.direction = projectile.position.direction_to(target.position)
		WeaponDef.Shape.BOOMERANG:
			if projectile.returning:
				var thrower: PlayerState = sim.players.get(projectile.owner_id) as PlayerState
				if thrower == null or not thrower.alive:
					return false
				if projectile.position.distance_to(thrower.position) <= sim.rules.boomerang_catch_distance:
					return false
				projectile.direction = projectile.position.direction_to(thrower.position)
	projectile.position += projectile.direction * move
	projectile.travelled += move
	match def.shape:
		WeaponDef.Shape.BOOMERANG:
			if not projectile.returning and projectile.travelled >= def.max_range:
				_turn_back(projectile)
		WeaponDef.Shape.BOUNCER:
			var next_bounce: float = def.max_range * float(projectile.bounces + 1) / float(maxi(def.count, 1))
			if projectile.travelled >= next_bounce:
				projectile.bounces += 1
				_area_hit(sim, projectile.team, def, projectile.position, def.radius)
				if projectile.bounces >= def.count:
					return false
		WeaponDef.Shape.SPINNER:
			if projectile.travelled >= def.max_range:
				_check_hits(sim, projectile)
				return false
	return true


func _turn_back(projectile: Projectile) -> void:
	projectile.returning = true
	projectile.hit_ids.clear()


## Enemy walls, lane edges and enemy shields stop projectiles.
func _blocked(projectile: Projectile, previous: Vector2, blocking: Array[Rect2]) -> bool:
	for rect: Rect2 in blocking:
		if rect.has_point(projectile.position):
			return true
	for shield: Shield in shields:
		if shield.team == projectile.team:
			continue
		var a: Vector2 = shield.center - shield.along * shield.half_width
		var b: Vector2 = shield.center + shield.along * shield.half_width
		if Geometry2D.segment_intersects_segment(previous, projectile.position, a, b) != null:
			return true
	return false


## Returns false if the projectile is consumed by the hit.
func _check_hits(sim: MatchSim, projectile: Projectile) -> bool:
	var def: WeaponDef = projectile.def
	match def.shape:
		WeaponDef.Shape.TARGETED:
			var target: PlayerState = sim.players.get(projectile.target_id) as PlayerState
			if target != null and projectile.position.distance_to(target.position) <= def.projectile_radius + target.radius:
				_hit(sim, target, def)
				return false
		WeaponDef.Shape.BOOMERANG:
			for target: PlayerState in sim.enemies_of(projectile.team):
				if projectile.hit_ids.has(target.id):
					continue
				if projectile.position.distance_to(target.position) <= def.projectile_radius + target.radius:
					projectile.hit_ids[target.id] = true
					_hit(sim, target, def)
		WeaponDef.Shape.SPINNER:
			for target: PlayerState in sim.enemies_of(projectile.team):
				if projectile.hit_ids.has(target.id):
					continue
				if projectile.position.distance_to(target.position) <= def.radius + target.radius:
					projectile.hit_ids[target.id] = true
					_hit(sim, target, def)
	return true


func _step_zones(sim: MatchSim, dt: float) -> void:
	var still: Array[Zone] = []
	for zone: Zone in zones:
		if _step_zone(sim, zone, dt):
			still.append(zone)
	zones = still


## Returns false once the zone is gone.
func _step_zone(sim: MatchSim, zone: Zone, dt: float) -> bool:
	zone.time_left -= dt
	match zone.kind:
		ZoneKind.EXPLOSION:
			if zone.time_left <= 0.0:
				_area_hit(sim, zone.team, zone.def, zone.center, zone.radius)
				return false
		ZoneKind.TRAP:
			zone.timer -= dt
			if zone.timer <= 0.0 and _any_enemy_within(sim, zone.team, zone.center, zone.radius):
				zone.kind = ZoneKind.SLOW_ZONE
				zone.radius = zone.def.radius
				zone.time_left = zone.def.duration
				return true
			return zone.time_left > 0.0
		ZoneKind.SLOW_ZONE:
			for target: PlayerState in _enemies_within(sim, zone.team, zone.center, zone.radius):
				sim.apply_effect(target.id, zone.def.effect, zone.def.effect_duration, zone.def.effect_magnitude)
			return zone.time_left > 0.0
		ZoneKind.FIELD:
			zone.timer -= dt
			if zone.timer <= 0.0:
				zone.timer += zone.def.interval
				_area_hit(sim, zone.team, zone.def, zone.center, zone.radius)
			return zone.time_left > 0.0
	return true


func _step_shields(dt: float) -> void:
	var still: Array[Shield] = []
	for shield: Shield in shields:
		shield.time_left -= dt
		if shield.time_left > 0.0:
			still.append(shield)
	shields = still


# ---- helpers ----------------------------------------------------------------

func _area_hit(sim: MatchSim, team: int, def: WeaponDef, center: Vector2, radius: float) -> void:
	for target: PlayerState in _enemies_within(sim, team, center, radius):
		_hit(sim, target, def)


func _enemies_within(sim: MatchSim, team: int, center: Vector2, radius: float) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for target: PlayerState in sim.enemies_of(team):
		if center.distance_to(target.position) <= radius + target.radius:
			result.append(target)
	return result


func _any_enemy_within(sim: MatchSim, team: int, center: Vector2, radius: float) -> bool:
	return not _enemies_within(sim, team, center, radius).is_empty()


func _hit(sim: MatchSim, target: PlayerState, def: WeaponDef) -> void:
	if def.effect != StatusEffects.Type.NONE:
		sim.apply_effect(target.id, def.effect, def.effect_duration, def.effect_magnitude)
	if def.damage > 0:
		sim.damage(target.id, def.damage)


func _new_projectile(caster: PlayerState, def: WeaponDef, direction: Vector2) -> Projectile:
	var projectile: Projectile = Projectile.new()
	projectile.id = _take_id()
	projectile.owner_id = caster.id
	projectile.team = caster.team
	projectile.def = def
	projectile.position = caster.position
	projectile.direction = direction
	projectiles.append(projectile)
	return projectile


func _new_zone(caster: PlayerState, def: WeaponDef, kind: ZoneKind, center: Vector2, radius: float, time: float) -> Zone:
	var zone: Zone = Zone.new()
	zone.id = _take_id()
	zone.owner_id = caster.id
	zone.team = caster.team
	zone.def = def
	zone.kind = kind
	zone.center = center
	zone.radius = radius
	zone.time_left = time
	zones.append(zone)
	return zone


func _take_id() -> int:
	_next_id += 1
	return _next_id
