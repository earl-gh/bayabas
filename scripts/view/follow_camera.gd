class_name FollowCamera
extends Camera3D
## Team-relative MOBA follow camera for the portrait lane. Own base is always at
## the bottom of the screen; the other team's view is rotated 180 degrees. Eases
## toward its target (CameraRules.follow_rate); snaps on the first frame and when
## the view flips (new set).

@export var rules: CameraRules
@export var layout: MapLayout

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
