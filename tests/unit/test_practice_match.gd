extends GutTest

const PRACTICE_SCENE: PackedScene = preload("res://scenes/match/practice.tscn")
const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _practice() -> PracticeMatch:
	var practice: PracticeMatch = autofree(PRACTICE_SCENE.instantiate()) as PracticeMatch
	add_child(practice)
	return practice


func test_local_player_starts_at_own_base_seen_from_behind() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_eq(player.position, LAYOUT.base_center(MapLayout.SIDE_OWN))
	var camera: Camera3D = practice.get_node("%FollowCamera") as Camera3D
	assert_gt(camera.position.z, player.position.y - 0.001, "camera is behind the player (+Z side)")
	assert_eq(camera.rotation_degrees.y, 0.0)


func test_stick_moves_the_player_and_the_camera_follows() -> void:
	var practice: PracticeMatch = _practice()
	var start_z: float = practice.sim.players[PracticeMatch.LOCAL_ID].position.y
	practice.set_stick(Vector2(0.0, -1.0))
	for i: int in 30:
		practice.advance(DT)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_almost_eq(player.position.y, start_z - 5.0, 0.05)
	var capsule: Node3D = practice.get_node("%Actors").get_child(0) as Node3D
	assert_almost_eq(capsule.position.x, player.position.x, 0.0001)
	assert_almost_eq(capsule.position.z, player.position.y, 0.0001)
	var camera: Camera3D = practice.get_node("%FollowCamera") as Camera3D
	var target: Vector2 = CAMERA.clamp_target(player.position, LAYOUT)
	var offset: Vector3 = CAMERA.camera_offset(CAMERA.distance(LAYOUT.lane_width), false)
	assert_almost_eq(camera.position.z, target.y + offset.z, 0.01)
	assert_almost_eq(camera.position.y, offset.y, 0.01)


func test_releasing_the_stick_stops_the_player() -> void:
	var practice: PracticeMatch = _practice()
	practice.set_stick(Vector2(0.0, -1.0))
	practice.advance(DT)
	practice.set_stick(Vector2.ZERO)
	var before: Vector2 = practice.sim.players[PracticeMatch.LOCAL_ID].position
	for i: int in 10:
		practice.advance(DT)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].position, before)


func test_long_frames_are_capped_not_spiralling() -> void:
	var practice: PracticeMatch = _practice()
	practice.advance(10.0)
	assert_eq(practice.sim.tick, PracticeMatch.MAX_STEPS_PER_FRAME)
