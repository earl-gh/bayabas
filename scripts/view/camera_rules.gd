class_name CameraRules
extends Resource
## The gameplay camera, copied from League of Legends: a far camera with a narrow
## field of view looking down at a steep, fixed angle (56 degree pitch, 30 degree
## vertical FOV), so perspective is flat and heroes keep their size across the
## lane. Only the camera DISTANCE is ours: it is derived so that `visible_width`
## metres of lane are on screen at the hero, whatever the phone's aspect ratio.
## Pure math on data from data/rules/camera_rules.tres.

## Pitch from horizontal, in degrees (League of Legends: 56).
@export var pitch_degrees: float = 0.0
## VERTICAL field of view, in degrees (League of Legends: 30).
@export var vfov_degrees: float = 0.0
## Metres of lane width visible at the hero (the camera distance follows from it).
@export var visible_width: float = 0.0
## How far past the lane edge (m) the view may reach when the hero is at the curb.
@export var edge_margin: float = 0.0
## Camera target stops this far from each lane end (m), so the view never runs off the map.
@export var end_clamp: float = 0.0
## Metres the camera looks ahead of the hero toward the enemy base.
@export var look_ahead: float = 0.0
## How fast the camera catches up (1/s). Higher = snappier.
@export var follow_rate: float = 0.0
## Fraction of the hero's sideways position the camera follows.
@export var side_follow: float = 0.0
## Aspect ratios (width / height) the distance is computed for are kept in this range.
@export var min_aspect: float = 0.0
@export var max_aspect: float = 0.0


## Camera distance from the target for a screen of `aspect` (width / height):
## visible width = 2 * d * tan(vfov / 2) * aspect.
func distance(aspect: float) -> float:
	var clamped: float = clampf(aspect, min_aspect, max_aspect)
	return visible_width / (2.0 * tan(deg_to_rad(vfov_degrees / 2.0)) * clamped)


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


## Where the camera aims: a little ahead of the hero toward the enemy base,
## following them sideways (clamped so the view stays near the lane), and clamped
## near the lane ends.
func clamp_target(world_pos: Vector2, layout: MapLayout, flip: bool = false) -> Vector2:
	var ahead: float = look_ahead if flip else -look_ahead
	var limit: float = layout.lane_length / 2.0 - end_clamp
	var side_limit: float = maxf(0.0, layout.lane_width / 2.0 + edge_margin - visible_width / 2.0)
	var x: float = clampf(world_pos.x * side_follow, -side_limit, side_limit)
	return Vector2(x, clampf(world_pos.y + ahead, -limit, limit))


## Fraction of the remaining distance to cover this frame (frame-rate independent).
func follow_weight(delta: float) -> float:
	return 1.0 - exp(-follow_rate * delta)
