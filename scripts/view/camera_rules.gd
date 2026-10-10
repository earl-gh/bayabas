class_name CameraRules
extends Resource
## Follow-camera framing for the portrait game, MOBA style (Mobile Legends /
## League of Legends): a fairly narrow perspective lens looking down at
## `pitch_degrees`, the hero placed below the screen centre (look-ahead toward
## the enemy base) and a smooth, slightly lagging follow. Pure math on data from
## data/rules/camera_rules.tres.
##
## FOV is horizontal (keep-width) so the full lane width always fits the screen.

@export var pitch_degrees: float = 0.0
@export var hfov_degrees: float = 0.0
## Extra visible width (m) beyond the lane so the side walls are not clipped,
## also covering the small sideways follow.
@export var lane_margin: float = 0.0
## Camera target stops this far from each lane end (m), so the view never runs off the map.
@export var end_clamp: float = 0.0
## Metres the camera looks ahead of the hero toward the enemy base (hero sits low on screen).
@export var look_ahead: float = 0.0
## How fast the camera catches up (1/s). Higher = snappier.
@export var follow_rate: float = 0.0
## Fraction of the hero's sideways position the camera follows (0 = lane centred).
@export var side_follow: float = 0.0


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


## Where the camera aims: a bit ahead of the hero toward the enemy base (the view
## direction), a little of their sideways position, clamped near the lane ends.
func clamp_target(world_pos: Vector2, layout: MapLayout, flip: bool = false) -> Vector2:
	var ahead: float = look_ahead if flip else -look_ahead
	var limit: float = layout.lane_length / 2.0 - end_clamp
	return Vector2(world_pos.x * side_follow, clampf(world_pos.y + ahead, -limit, limit))


## Fraction of the remaining distance to cover this frame (frame-rate independent).
func follow_weight(delta: float) -> float:
	return 1.0 - exp(-follow_rate * delta)
