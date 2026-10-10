class_name FollowCamera
extends Camera3D
## Team-relative gameplay camera, League of Legends style (see CameraRules): a far
## camera with a 30 degree vertical FOV at 56 degrees pitch. Own base is always at
## the bottom of the screen; the other team's view is rotated 180 degrees. Eases
## toward its target (CameraRules.follow_rate); snaps on the first frame and when
## the view flips (new set).

const SHAKE_DECAY: float = 1.4
const NEAR: float = 4.0
const FAR: float = 170.0

@export var rules: CameraRules
@export var layout: MapLayout

## Screen-shake strength left (decays quickly); view only.
var _shake: float = 0.0
var _placed: bool = false
var _flip: bool = false


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = rules.vfov_degrees
	near = NEAR
	far = FAR
	environment = StreetMap.make_environment()


## Current screen aspect (width / height); portrait phones are about 0.46 to 0.56.
func screen_aspect() -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return 0.5625
	var size: Vector2 = viewport.get_visible_rect().size
	return size.x / size.y if size.y > 0.0 else 0.5625


## Distance from the hero's ground point to the camera for this screen.
func distance() -> float:
	return rules.distance(screen_aspect())


## Where the camera wants to be for a hero at `world_pos`.
func desired_position(world_pos: Vector2, flip: bool) -> Vector3:
	var target: Vector2 = rules.clamp_target(world_pos, layout, flip)
	return Vector3(target.x, 0.0, target.y) + rules.camera_offset(distance(), flip)


## `delta` 0 snaps straight to the target.
func follow(world_pos: Vector2, flip: bool, delta: float = 0.0) -> void:
	var desired: Vector3 = desired_position(world_pos, flip)
	if not _placed or flip != _flip or delta <= 0.0:
		position = desired
	else:
		position = position.lerp(desired, rules.follow_weight(delta))
	_placed = true
	_flip = flip
	rotation_degrees = Vector3(-rules.pitch_degrees, rules.yaw_degrees(flip), 0.0)


## Kick the camera (a hit on you, a wall breaking). `strength` ~0.1 small, 0.4 big.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _shake <= 0.001:
		_shake = 0.0
		h_offset = 0.0
		v_offset = 0.0
		return
	h_offset = randf_range(-1.0, 1.0) * _shake
	v_offset = randf_range(-1.0, 1.0) * _shake
	_shake = maxf(0.0, _shake - delta * SHAKE_DECAY)
