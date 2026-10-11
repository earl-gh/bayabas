extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const PHONE: float = 720.0 / 1280.0


func test_the_angle_and_lens_match_the_owners_reference() -> void:
	assert_eq(CAMERA.pitch_degrees, 56.0)
	assert_eq(CAMERA.vfov_degrees, 52.0, "vertical field of view")


func test_other_camera_numbers_come_from_data() -> void:
	assert_eq(CAMERA.visible_width, 19.0)
	assert_eq(CAMERA.end_clamp, 5.0)
	assert_eq(CAMERA.look_ahead, 2.5)


func test_distance_shows_the_visible_width_on_any_phone() -> void:
	for aspect: float in [0.46, PHONE, 0.75]:
		var distance: float = CAMERA.distance(aspect)
		var width: float = 2.0 * distance * tan(deg_to_rad(CAMERA.vfov_degrees / 2.0)) * aspect
		assert_almost_eq(width, CAMERA.visible_width, 0.001, "aspect %.2f" % aspect)
	assert_almost_eq(CAMERA.distance(PHONE), 34.63, 0.05)


func test_the_camera_is_far_and_high() -> void:
	var offset: Vector3 = CAMERA.camera_offset(CAMERA.distance(PHONE), false)
	assert_almost_eq(offset.y, 28.71, 0.1, "about 29 m up")
	assert_almost_eq(offset.length(), CAMERA.distance(PHONE), 0.001)


func test_aspect_is_kept_in_a_sane_range() -> void:
	assert_eq(CAMERA.distance(0.05), CAMERA.distance(CAMERA.min_aspect))
	assert_eq(CAMERA.distance(5.0), CAMERA.distance(CAMERA.max_aspect))


func test_offset_sits_behind_and_above_the_target() -> void:
	var offset: Vector3 = CAMERA.camera_offset(20.0, false)
	assert_almost_eq(offset.y, 20.0 * sin(deg_to_rad(CAMERA.pitch_degrees)), 0.001)
	var back: float = 20.0 * cos(deg_to_rad(CAMERA.pitch_degrees))
	assert_almost_eq(Vector2(offset.x, offset.z).length(), back, 0.001)
	assert_gt(offset.z, 0.0, "own side: camera behind on +Z, looking toward -Z")
	assert_gte(offset.x, 0.0, "never to the left of the hero")
	assert_almost_eq(rad_to_deg(atan2(offset.x, offset.z)), CAMERA.yaw_offset_degrees, 0.001)


func test_other_team_view_is_mirrored() -> void:
	var own: Vector3 = CAMERA.camera_offset(20.0, false)
	var other: Vector3 = CAMERA.camera_offset(20.0, true)
	assert_almost_eq(other.z, -own.z, 0.0001)
	assert_almost_eq(other.x, -own.x, 0.0001)
	assert_almost_eq(other.y, own.y, 0.0001)
	assert_eq(CAMERA.yaw_degrees(false), CAMERA.yaw_offset_degrees)
	assert_eq(CAMERA.yaw_degrees(true), CAMERA.yaw_offset_degrees + 180.0)


func test_target_looks_ahead_toward_the_enemy_and_is_clamped_near_the_ends() -> void:
	var limit: float = LAYOUT.lane_length / 2.0 - CAMERA.end_clamp
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 10.0), LAYOUT), Vector2(0.0, 7.5), "own side looks toward -Z")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 10.0), LAYOUT, true), Vector2(0.0, 12.5), "flipped looks toward +Z")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, LAYOUT.lane_length / 2.0 - 1.0), LAYOUT), Vector2(0.0, limit))
	assert_eq(CAMERA.clamp_target(Vector2(0.0, -LAYOUT.lane_length / 2.0 + 1.0), LAYOUT), Vector2(0.0, -limit))


func test_camera_follows_sideways_but_never_far_past_the_curb() -> void:
	var half_visible: float = CAMERA.visible_width / 2.0
	var room: float = LAYOUT.lane_width / 2.0 + CAMERA.edge_margin - half_visible
	if room <= 0.0:
		# the wide lens shows the whole lane across the screen: no sideways follow needed
		assert_eq(CAMERA.clamp_target(Vector2(1.0, 0.0), LAYOUT).x, 0.0, "centred on the lane")
		assert_gte(half_visible, LAYOUT.lane_width / 2.0, "the curbs are on screen")
		return
	assert_eq(CAMERA.clamp_target(Vector2(1.0, 0.0), LAYOUT).x, 1.0, "follows the hero")
	for x: float in [LAYOUT.lane_width / 2.0, -LAYOUT.lane_width / 2.0]:
		var shift: float = CAMERA.clamp_target(Vector2(x, 0.0), LAYOUT).x
		assert_lte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0 + CAMERA.edge_margin + 0.001)
		assert_gte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0, "the curb is on screen")


func test_follow_weight_is_frame_rate_independent() -> void:
	var one_step: float = CAMERA.follow_weight(0.1)
	var two_steps: float = 1.0 - pow(1.0 - CAMERA.follow_weight(0.05), 2.0)
	assert_almost_eq(one_step, two_steps, 0.0001)
	assert_eq(CAMERA.follow_weight(0.0), 0.0)


func test_the_follow_camera_uses_keep_height_and_the_data_angle() -> void:
	var camera: FollowCamera = autofree(FollowCamera.new()) as FollowCamera
	camera.rules = CAMERA
	camera.layout = LAYOUT
	add_child(camera)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_eq(camera.fov, CAMERA.vfov_degrees)
	camera.follow(Vector2.ZERO, false)
	assert_almost_eq(camera.rotation_degrees.x, -CAMERA.pitch_degrees, 0.001)
