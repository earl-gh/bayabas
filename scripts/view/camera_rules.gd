class_name CameraRules
extends Resource
## Follow-camera framing for the portrait game, MOBA style (Mobile Legends /
## League of Legends): a fairly narrow perspective lens looking down at
## `pitch_degrees`, the hero placed below the screen centre (look-ahead toward
## the enemy base) and a smooth, slightly lagging follow. Pure math on data from
## data/rules/camera_rules.tres.
##
## Close like Mobile Legends Brawl: about `lane_width + lane_margin` metres of
## width are visible (lane_margin is negative: less than the full lane), and the
## camera slides sideways with the hero, never showing more than `edge_margin`
## metres beyond the curb.

@export var pitch_degrees: float = 0.0
@export var hfov_degrees: float = 0.0
## Visible width = lane width + this (m). Negative = closer than the full lane.
@export var lane_margin: float = 0.0
## How far past the lane edge (m) the view may reach when the hero is at the curb.
@export var edge_margin: float = 0.0
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
## direction), following them sideways (clamped so the view stays near the lane),
## and clamped near the lane ends.
func clamp_target(world_pos: Vector2, layout: MapLayout, flip: bool = false) -> Vector2:
	var ahead: float = look_ahead if flip else -look_ahead
	var limit: float = layout.lane_length / 2.0 - end_clamp
	var side_limit: float = maxf(0.0, layout.lane_width / 2.0 + edge_margin - visible_width(layout.lane_width) / 2.0)
	var x: float = clampf(world_pos.x * side_follow, -side_limit, side_limit)
	return Vector2(x, clampf(world_pos.y + ahead, -limit, limit))


func visible_width(lane_width: float) -> float:
	return lane_width + lane_margin


## Fraction of the remaining distance to cover this frame (frame-rate independent).
func follow_weight(delta: float) -> float:
	return 1.0 - exp(-follow_rate * delta)
