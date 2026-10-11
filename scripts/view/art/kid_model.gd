class_name KidModel
extends Node3D
## One of the six kids (docs/PROJECT.md 3.2) drawn as a pre-rendered sprite, like
## Clash of Clans does: every pose exists for 5 directions (toward the camera, 45
## degrees, side, away at 45 degrees, away) and the other three are mirrored. The
## sprites are cut from the sheets in assets/sprites/<kid>/ (tools/sprites/).
## Visual only: the hitbox and every number come from the sim. Poses are one frame
## each, so the motion is added in code (run bounce, idle breathing, hit flash).
## Origin at the feet. Kids with no sprite set yet use FALLBACK_SET.

const SPRITE_PATH: String = "res://assets/sprites/%s/%s_%s.png"
const FALLBACK_SET: StringName = &"junjun"
const DIRECTIONS: Array[String] = ["toward", "toward_right", "right", "away_right", "away"]
## World height of one sprite cell in metres (the kid fills about 85% of it).
## The kids are drawn a little bigger than life so they read through the wide lens.
const CELL_HEIGHT: float = 2.2
const GHOST_COLOR: Color = Color(0.55, 0.55, 0.62)
const HIT_COLOR: Color = Color(1.0, 0.55, 0.55)
const STRIDE: float = 1.6
const CAST_TIME: float = 0.38
## A tumble starts with the slightly falling pose, then the face-down one.
const STUMBLE_FALL_TIME: float = 0.18
const HIT_TIME: float = 0.28
## How long the knockout fall (top row) plays before the kid lies down.
const KO_FALL_TIME: float = 0.35
const SHADOW_SIZE: float = 1.1
## A direction only changes once the facing is this far (in direction steps of 45
## degrees) past the halfway point, and the left-right mirror only changes outside
## this many radians of straight toward / away: no flicker while moving.
const DIRECTION_HYSTERESIS: float = 0.25
const MIRROR_DEADZONE: float = 0.12
## The sim steps at 30 Hz but the screen draws faster: with no new position for this
## long the kid is standing still.
const STILL_AFTER: float = 0.2

static var _frames: Dictionary[String, Dictionary] = {}
static var _shadow_texture: GradientTexture2D

var character: CharacterDef
var team_color: Color = Color.WHITE
## A foot hit the ground (run cycle), for footstep sounds.
signal footstep

var _set: StringName = FALLBACK_SET
var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _can: MeshInstance3D
var _facing: Vector2 = Vector2(0.0, 1.0)
var _phase: float = 0.0
var _clock: float = 0.0
var _ghost: bool = false
var _cast_left: float = 0.0
var _cast_total: float = CAST_TIME
var _stumble_age: float = 0.0
var _hit_left: float = 0.0
var _ko_time: float = 0.0
var _move_blend: float = 0.0
var _last_step: int = 0
var _anim: String = "idle"
var _dir_index: int = 0
var _flipped: bool = false
var _stride_flip: bool = false  # the run frame has one foot forward: mirroring it each step swaps the foot
var _tracked_position: Vector2 = Vector2.INF
var _since_move: float = 0.0
var _ground_speed: float = 0.0
## Last pose name, for tests and debugging ("idle", "run", "cast", "ko", ...).
var pose: String = "idle"


## `team` is kept for callers; teams are told apart by the health bar, not the kid.
func setup(def: CharacterDef, team: Color, _ring_radius: float) -> void:
	character = def
	team_color = team
	_set = def.id if ResourceLoader.exists(SPRITE_PATH % [def.id, "idle", "toward"]) else FALLBACK_SET
	_build()
	_show_frame("idle", 0.0)


## Turns the kid to look along `facing` (world x/z).
func face(facing: Vector2) -> void:
	if facing.length_squared() > 0.0001:
		_facing = facing.normalized()
		rotation.y = atan2(-facing.x, -facing.y)


## Throwing arm swing (a weapon was cast).
func play_cast(duration: float = CAST_TIME) -> void:
	_cast_total = maxf(duration, CAST_TIME)
	_cast_left = _cast_total


## Flinch (took damage).
func play_hit() -> void:
	_hit_left = HIT_TIME


func is_can() -> bool:
	return _can.visible


func is_ghost() -> bool:
	return _ghost


func set_ghost(on: bool) -> void:
	_ghost = on


## Which sprite is showing ("idle", "run", "cast", "stun", "down", "ko_stagger", "ko_lying").
func current_animation() -> String:
	return _anim


## The ground speed in m/s from the kid's world position, held between sim ticks
## (the sim moves in 30 Hz steps, so most drawn frames see no movement). Feed it to
## `animate()` every frame.
func ground_speed(world_position: Vector2, delta: float) -> float:
	if _tracked_position == Vector2.INF:
		_tracked_position = world_position
	_since_move += delta
	if world_position != _tracked_position:
		_ground_speed = _tracked_position.distance_to(world_position) / maxf(_since_move, 0.001)
		_tracked_position = world_position
		_since_move = 0.0
	elif _since_move > STILL_AFTER:
		_ground_speed = 0.0
	return _ground_speed


## Per frame: `speed` is the ground speed in m/s.
func animate(delta: float, speed: float, state: PlayerState) -> void:
	_clock += delta
	_cast_left = maxf(0.0, _cast_left - delta)
	_hit_left = maxf(0.0, _hit_left - delta)
	var polymorphed: bool = state.effects.has(StatusEffects.Type.POLYMORPH)
	_sprite.visible = not polymorphed
	_shadow.visible = true
	_can.visible = polymorphed
	set_ghost(state.death_delay)
	if polymorphed:
		pose = "can"
		_can.rotation.z = sin(_clock * 10.0) * 0.1 * clampf(speed, 0.0, 1.0)
		_can.position.y = absf(sin(_clock * 10.0)) * 0.08 * clampf(speed, 0.0, 1.0)
		return
	_move_blend = move_toward(_move_blend, 1.0 if speed > 0.3 else 0.0, delta * 6.0)
	if speed > 0.3:
		_phase += delta * speed / STRIDE
		var step_index: int = int(floor(_phase * 2.0))
		if step_index != _last_step:
			_last_step = step_index
			footstep.emit()
	_stumble_age = _stumble_age + delta if state.stumble_time_left > 0.0 else 0.0
	var knocked_out: bool = state.effects.has(StatusEffects.Type.KNOCKOUT)
	_ko_time = _ko_time + delta if knocked_out else 0.0
	var bob: float = 0.0
	var squash: Vector2 = Vector2.ONE
	var anim: String = "idle"
	_stride_flip = false
	if knocked_out:
		pose = "ko"
		anim = "ko_stagger" if _ko_time < KO_FALL_TIME else "ko_lying"
	elif state.effects.has(StatusEffects.Type.AIRBORNE) or state.effects.has(StatusEffects.Type.BOUNCE):
		pose = "airborne"
		anim = "stun"
		squash = Vector2(1.0, 1.0 + sin(_clock * 12.0) * 0.06)
	elif state.effects.has(StatusEffects.Type.STUN):
		pose = "stunned"
		anim = "stun"
		squash = Vector2(1.0 + sin(_clock * 6.0) * 0.03, 1.0 - sin(_clock * 6.0) * 0.03)
	elif state.dash_time_left > 0.0:
		pose = "dash"
		anim = "run"
		squash = Vector2(1.18, 0.9)
	elif state.stumble_time_left > 0.0:
		pose = "stumble"
		anim = "ko_stagger" if _stumble_age < STUMBLE_FALL_TIME else "down"
	elif state.death_delay:
		pose = "down"
		anim = "ko_stagger"
		squash = Vector2(1.0, 1.0 + sin(_clock * 2.5) * 0.02)
	elif _cast_left > 0.0:
		pose = "cast"
		anim = "cast"
		var u: float = 1.0 - _cast_left / _cast_total
		squash = Vector2(1.0 + sin(u * PI) * 0.1, 1.0 - sin(u * PI) * 0.06)
	elif _move_blend > 0.5:
		pose = "run"
		anim = "run"
		_stride_flip = int(floor(_phase * 2.0)) % 2 == 1
		var t: float = _phase * TAU
		bob = absf(sin(t)) * 0.09
		squash = Vector2(1.0 - absf(sin(t)) * 0.03, 1.0 + absf(sin(t)) * 0.04)
	else:
		pose = "idle"
		squash = Vector2(1.0, 1.0 + sin(_clock * 2.2) * 0.015)
	_show_frame(anim, bob)
	_sprite.scale = Vector3(squash.x, squash.y, 1.0)
	_sprite.modulate = _tint()


func _tint() -> Color:
	if _ghost:
		return GHOST_COLOR
	if _hit_left > 0.0:
		return Color.WHITE.lerp(HIT_COLOR, _hit_left / HIT_TIME)
	return Color.WHITE


## Picks the sprite for `anim` and the view direction (mirrored for the left side).
func _show_frame(anim: String, bob: float) -> void:
	_anim = anim
	var angle: float = _view_angle()
	var steps: float = absf(angle) / (PI / 4.0)
	if absf(steps - float(_dir_index)) > 0.5 + DIRECTION_HYSTERESIS:
		_dir_index = clampi(int(round(steps)), 0, DIRECTIONS.size() - 1)
	var index: int = _dir_index
	if index == 0 or index == DIRECTIONS.size() - 1:
		_flipped = false
	elif absf(angle) > MIRROR_DEADZONE and absf(angle) < PI - MIRROR_DEADZONE:
		_flipped = angle < 0.0
	var frame: Dictionary = _frame(_set, anim, DIRECTIONS[index])
	var texture: Texture2D = frame["texture"] as Texture2D
	var size: Vector2 = texture.get_size()
	_sprite.texture = texture
	_sprite.pixel_size = CELL_HEIGHT / size.y
	# mirroring a side or diagonal view swings the body (or turns it around), so only the full front and back views swap feet
	_sprite.flip_h = _flipped != (_stride_flip and (index == 0 or index == DIRECTIONS.size() - 1))
	# the feet (bottom of the drawn pixels) sit on the origin
	var feet: float = frame["feet"] as float
	_sprite.offset = Vector2(0.0, feet - size.y * 0.5)
	_sprite.position.y = bob


## Angle of the kid's facing as seen from the camera: 0 = toward it, +90 = to the
## right of the screen, 180 = away. Without a camera (tests) the kid faces it.
func _view_angle() -> float:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return 0.0
	var right: Vector3 = camera.global_basis.x
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var look: Vector3 = Vector3(_facing.x, 0.0, _facing.y)
	return atan2(look.dot(right), -look.dot(forward))


static func _frame(set_id: StringName, anim: String, direction: String) -> Dictionary:
	var path: String = SPRITE_PATH % [set_id, anim, direction]
	if not _frames.has(path):
		var texture: Texture2D = load(path) as Texture2D
		var used: Rect2i = texture.get_image().get_used_rect()
		_frames[path] = {"texture": texture, "feet": float(used.end.y)}
	return _frames[path]


func _build() -> void:
	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * SHADOW_SIZE
	quad.orientation = PlaneMesh.FACE_Y
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _blob_texture()
	quad.material = material
	_shadow.mesh = quad
	_shadow.position.y = 0.04
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	add_child(_sprite)
	_can = MeshInstance3D.new()
	_can.mesh = Props.can_body()
	_can.scale = Vector3.ONE * 1.3
	_can.visible = false
	add_child(_can)
	LowPoly.add_outline(_can, 0.02)


static func _blob_texture() -> GradientTexture2D:
	if _shadow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.45), Color(0.0, 0.0, 0.0, 0.0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = gradient
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
		_shadow_texture.width = 64
		_shadow_texture.height = 64
	return _shadow_texture
