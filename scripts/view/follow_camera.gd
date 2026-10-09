class_name FollowCamera
extends Camera3D
## Team-relative follow camera for the portrait lane. Own base is always at the
## bottom of the screen; the other team's view is rotated 180 degrees.

@export var rules: CameraRules
@export var layout: MapLayout


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = rules.hfov_degrees
	environment = GreyboxMap.make_environment()


func follow(world_pos: Vector2, flip: bool) -> void:
	var target: Vector2 = rules.clamp_target(world_pos, layout)
	var camera_distance: float = rules.distance(layout.lane_width)
	position = Vector3(target.x, 0.0, target.y) + rules.camera_offset(camera_distance, flip)
	rotation_degrees = Vector3(-rules.pitch_degrees, rules.yaw_degrees(flip), 0.0)
