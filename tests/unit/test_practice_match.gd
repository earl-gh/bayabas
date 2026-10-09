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
	assert_almost_eq(camera.rotation_degrees.y, 0.0, 0.001)


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


func test_hp_label_and_hurt_button_path() -> void:
	var practice: PracticeMatch = _practice()
	var label: Label = practice.get_node("%HpLabel") as Label
	assert_eq(label.text, "HP 100 / 100")
	practice.hurt_local(30)
	assert_eq(label.text, "HP 70 / 100")


func test_zero_hp_starts_the_death_delay_with_gray_hp_and_locked_skills() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.players[PracticeMatch.LOCAL_ID].position = Vector2(0.0, 0.0)
	practice.hurt_local(100)
	assert_eq((practice.get_node("%HpLabel") as Label).text, "HP 0   GRAY 50")
	assert_true((practice.get_node("%DelayLabel") as Label).visible)
	assert_false((practice.get_node("%RespawnLabel") as Label).visible)
	assert_true((practice.get_node("%Actors").get_child(0) as Node3D).visible, "still on their feet")
	assert_true((practice.get_node("%DashButton") as TouchButton).locked)
	assert_true((practice.get_node("%BookmarkButton") as TouchButton).locked)


func test_skill_presses_do_nothing_in_the_death_delay() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	player.position = Vector2(0.0, 0.0)
	practice.hurt_local(100)
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.press_skill(PlayerInput.BTN_BOOKMARK)
	practice.advance(DT)
	assert_eq(player.dash_time_left, 0.0)
	assert_false(player.mark_active)
	assert_true(player.death_delay)


func test_touching_the_base_post_gets_you_up_again() -> void:
	var practice: PracticeMatch = _practice()
	# the local player spawns at their own base post
	practice.hurt_local(100)
	practice.advance(DT)
	assert_eq((practice.get_node("%HpLabel") as Label).text, "HP 50 / 100")
	assert_false((practice.get_node("%DelayLabel") as Label).visible)
	assert_false((practice.get_node("%DashButton") as TouchButton).locked)


func test_touching_the_ally_dummy_gets_you_up_again() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	var ally: PlayerState = practice.sim.players[PracticeMatch.ALLY_ID]
	player.position = ally.position + Vector2(0.5, 0.0)
	practice.hurt_local(100)
	practice.advance(DT)
	assert_false(player.death_delay)
	assert_eq(player.hp, 50)


func test_real_death_hides_the_player_and_shows_the_respawn_timer_then_recovers() -> void:
	var practice: PracticeMatch = _practice()
	var capsule: Node3D = practice.get_node("%Actors").get_child(0) as Node3D
	var respawn: Label = practice.get_node("%RespawnLabel") as Label
	assert_false(respawn.visible)
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	practice.advance(0.0)
	assert_false(capsule.visible)
	assert_true(respawn.visible)
	assert_eq(respawn.text, "Respawning in 10")
	for i: int in 305:
		practice.advance(DT)
	assert_true(capsule.visible)
	assert_false(respawn.visible)
	assert_eq((practice.get_node("%HpLabel") as Label).text, "HP 100 / 100")


func test_practice_has_two_enemy_dummies_and_one_ally() -> void:
	var practice: PracticeMatch = _practice()
	assert_eq(practice.sim.players.size(), 4)
	var stand: PlayerState = practice.sim.players[PracticeMatch.ENEMY_STAND_ID]
	var patrol: PlayerState = practice.sim.players[PracticeMatch.ENEMY_PATROL_ID]
	var ally: PlayerState = practice.sim.players[PracticeMatch.ALLY_ID]
	assert_eq(stand.team, 1)
	assert_eq(patrol.team, 1)
	assert_eq(ally.team, 0)
	var stand_start: Vector2 = stand.position
	var patrol_start: Vector2 = patrol.position
	for i: int in 45:
		practice.advance(DT)
	assert_eq(stand.position, stand_start, "one enemy stands still")
	assert_ne(patrol.position.x, patrol_start.x, "the other walks")
	assert_eq(ally.position, Vector2(0.0, 11.0))


func test_dash_button_starts_a_dash_and_shows_its_cooldown() -> void:
	var practice: PracticeMatch = _practice()
	var dash: TouchButton = practice.get_node("%DashButton") as TouchButton
	assert_eq(dash.cooldown_fraction, 0.0)
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.advance(DT)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_gt(player.dash_time_left, 0.0)
	assert_gt(dash.cooldown_fraction, 0.9)


func test_bookmark_button_blinks_the_player() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	var start_z: float = player.position.y
	practice.press_skill(PlayerInput.BTN_BOOKMARK)
	practice.advance(DT)
	assert_almost_eq(player.position.y, start_z - 4.0, 0.05)
	assert_true(player.mark_active)


func test_a_pressed_skill_is_sent_once() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	practice.press_skill(PlayerInput.BTN_BOOKMARK)
	practice.advance(DT)
	var cooldown: float = player.bookmark_cooldown_left
	practice.advance(DT)
	assert_lt(player.bookmark_cooldown_left, cooldown, "cooldown runs, not re-triggered")
