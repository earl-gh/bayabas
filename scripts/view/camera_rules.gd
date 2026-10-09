class_name CameraRules
extends Resource
## Follow-camera framing for the portrait game. Pure math on top of data from
## data/rules/camera_rules.tres.
##
## The camera looks down the lane at `pitch_degrees`. FOV is horizontal
## (keep-width) so the full lane width always fits the portrait screen.

@export var pitch_degrees: float = 0.0
@export var hfov_degrees: float = 0.0
## Extra visible width (m) beyond the lane so the side walls are not clipped.
@export var lane_margin: float = 0.0
## Camera target stops this far from each lane end (m), so the view never runs off the map.
@export var end_clamp: float = 0.0


## Distance from the target so the lane (plus margin) exactly fills the screen width.
func distance(lane_width: float) -> float:
	return (lane_width + lane_margin) / 2.0 / tan(deg_to_rad(hfov_degrees / 2.0))


## Camera position relative to the target. Own side (+Z, no flip) looks toward -Z,
## so the camera sits behind on the +Z side; the other team is mirrored.
func camera_offset(camera_distance: float, flip: bool) -> Vector3:
	var pitch: float = deg_to_rad(pitch_degrees)
	var back: float = camera_distance * cos(pitch)
	if flip:
		back = -back
	return Vector3(0.0, camera_distance * sin(pitch), back)


func yaw_degrees(flip: bool) -> float:
	return 180.0 if flip else 0.0


## The lane is centered on screen: only the Z position is followed, clamped near the ends.
func clamp_target(world_pos: Vector2, layout: MapLayout) -> Vector2:
	var limit: float = layout.lane_length / 2.0 - end_clamp
	return Vector2(0.0, clampf(world_pos.y, -limit, limit))
