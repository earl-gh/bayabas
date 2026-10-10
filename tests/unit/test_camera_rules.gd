extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func test_camera_numbers_come_from_data() -> void:
	assert_eq(CAMERA.pitch_degrees, 50.0)
	assert_eq(CAMERA.hfov_degrees, 44.0)
	assert_eq(CAMERA.lane_margin, -4.0, "closer than the whole lane, like ML Brawl")
	assert_eq(CAMERA.end_clamp, 5.0)
	assert_eq(CAMERA.look_ahead, 3.0)


func test_distance_fits_lane_plus_margin_to_screen_width() -> void:
	var distance: float = CAMERA.distance(LAYOUT.lane_width)
	# visible width at the target = 2 * d * tan(hfov / 2) = lane + margin
	var visible_width: float = 2.0 * distance * tan(deg_to_rad(CAMERA.hfov_degrees / 2.0))
	assert_almost_eq(visible_width, LAYOUT.lane_width + CAMERA.lane_margin, 0.001)
	assert_almost_eq(distance, 14.85, 0.05)


func test_offset_sits_behind_and_above_the_target() -> void:
	var offset: Vector3 = CAMERA.camera_offset(20.0, false)
	assert_almost_eq(offset.y, 20.0 * sin(deg_to_rad(50.0)), 0.001)
	assert_almost_eq(offset.z, 20.0 * cos(deg_to_rad(50.0)), 0.001)
	assert_gt(offset.y, 0.0)
	assert_gt(offset.z, 0.0, "own side: camera behind on +Z, looking toward -Z")
	assert_eq(offset.x, 0.0)


func test_other_team_view_is_mirrored() -> void:
	var own: Vector3 = CAMERA.camera_offset(20.0, false)
	var other: Vector3 = CAMERA.camera_offset(20.0, true)
	assert_almost_eq(other.z, -own.z, 0.0001)
	assert_almost_eq(other.y, own.y, 0.0001)
	assert_eq(CAMERA.yaw_degrees(false), 0.0)
	assert_eq(CAMERA.yaw_degrees(true), 180.0)


func test_target_looks_ahead_toward_the_enemy_and_is_clamped_near_the_ends() -> void:
	var limit: float = LAYOUT.lane_length / 2.0 - CAMERA.end_clamp
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 10.0), LAYOUT), Vector2(0.0, 10.0 - 3.0), "own side looks toward -Z")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 10.0), LAYOUT, true), Vector2(0.0, 13.0), "flipped looks toward +Z")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 29.0), LAYOUT), Vector2(0.0, limit))
	assert_eq(CAMERA.clamp_target(Vector2(0.0, -29.0), LAYOUT), Vector2(0.0, -limit))


func test_camera_follows_sideways_but_never_far_past_the_curb() -> void:
	var half_visible: float = CAMERA.visible_width(LAYOUT.lane_width) / 2.0
	assert_eq(CAMERA.clamp_target(Vector2(1.5, 0.0), LAYOUT).x, 1.5, "follows the hero")
	for x: float in [LAYOUT.lane_width / 2.0, -LAYOUT.lane_width / 2.0]:
		var shift: float = CAMERA.clamp_target(Vector2(x, 0.0), LAYOUT).x
		assert_lte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0 + CAMERA.edge_margin + 0.001)
		assert_gte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0, "the curb is on screen")


func test_follow_weight_is_frame_rate_independent() -> void:
	var one_step: float = CAMERA.follow_weight(0.1)
	var two_steps: float = 1.0 - pow(1.0 - CAMERA.follow_weight(0.05), 2.0)
	assert_almost_eq(one_step, two_steps, 0.0001)
	assert_eq(CAMERA.follow_weight(0.0), 0.0)
