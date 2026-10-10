class_name FollowCamera
extends Camera3D
## Team-relative MOBA follow camera for the portrait lane. Own base is always at
## the bottom of the screen; the other team's view is rotated 180 degrees. Eases
## toward its target (CameraRules.follow_rate); snaps on the first frame and when
## the view flips (new set).

const SHAKE_DECAY: float = 1.4

@export var rules: CameraRules
@export var layout: MapLayout

## Screen-shake strength left (decays quickly); view only.
var _shake: float = 0.0
var _placed: bool = false
var _flip: bool = false


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = rules.hfov_degrees
	near = 1.0
	far = 120.0
	environment = StreetMap.make_environment()


## Where the camera wants to be for a hero at `world_pos`.
func desired_position(world_pos: Vector2, flip: bool) -> Vector3:
	var target: Vector2 = rules.clamp_target(world_pos, layout, flip)
	return Vector3(target.x, 0.0, target.y) + rules.camera_offset(rules.distance(layout.lane_width), flip)


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
