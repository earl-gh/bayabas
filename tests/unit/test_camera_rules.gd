extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func test_camera_numbers_come_from_data() -> void:
	assert_eq(CAMERA.pitch_degrees, 55.0)
	assert_eq(CAMERA.hfov_degrees, 50.0)
	assert_eq(CAMERA.lane_margin, 2.0)
	assert_eq(CAMERA.end_clamp, 6.0)


func test_distance_fits_lane_plus_margin_to_screen_width() -> void:
	var distance: float = CAMERA.distance(LAYOUT.lane_width)
	# visible width at the target = 2 * d * tan(hfov / 2) = lane + margin
	var visible_width: float = 2.0 * distance * tan(deg_to_rad(CAMERA.hfov_degrees / 2.0))
	assert_almost_eq(visible_width, LAYOUT.lane_width + CAMERA.lane_margin, 0.001)
	assert_almost_eq(distance, 19.3, 0.05)


func test_offset_sits_behind_and_above_the_target() -> void:
	var offset: Vector3 = CAMERA.camera_offset(20.0, false)
	assert_almost_eq(offset.y, 20.0 * sin(deg_to_rad(55.0)), 0.001)
	assert_almost_eq(offset.z, 20.0 * cos(deg_to_rad(55.0)), 0.001)
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


func test_target_is_centered_and_clamped_near_the_ends() -> void:
	var limit: float = LAYOUT.lane_length / 2.0 - CAMERA.end_clamp
	assert_eq(CAMERA.clamp_target(Vector2(5.0, 10.0), LAYOUT), Vector2(0.0, 10.0))
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 29.0), LAYOUT), Vector2(0.0, limit))
	assert_eq(CAMERA.clamp_target(Vector2(0.0, -29.0), LAYOUT), Vector2(0.0, -limit))
