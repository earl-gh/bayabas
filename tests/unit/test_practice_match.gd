extends GutTest

const PRACTICE_SCENE: PackedScene = preload("res://scenes/match/practice.tscn")
const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _practice() -> PracticeMatch:
	var practice: PracticeMatch = _picking()
	practice.finish_pick()
	return practice


## A practice match still on its opening weapon pick.
func _picking() -> PracticeMatch:
	var practice: PracticeMatch = autofree(PRACTICE_SCENE.instantiate()) as PracticeMatch
	add_child(practice)
	return practice


func _pick_screen(practice: PracticeMatch) -> WeaponPickScreen:
	return practice.get_node("%PickScreen") as WeaponPickScreen


func _weapon_button(practice: PracticeMatch, slot: int) -> AimButton:
	return practice.hud.weapon_buttons[slot]


## Puts one enemy dummy straight ahead of the local player and the other far away.
func _enemy_ahead(practice: PracticeMatch, distance: float) -> PlayerState:
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	player.position = Vector2(0.0, 4.0)
	practice.sim.players[PracticeMatch.ENEMY_PATROL_ID].position = Vector2(7.0, -25.0)
	var enemy: PlayerState = practice.sim.players[PracticeMatch.ENEMY_STAND_ID]
	enemy.position = player.position + Vector2(0.0, -distance)
	return enemy


func test_local_player_starts_at_own_base_seen_from_behind() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_eq(player.position, LAYOUT.base_center(MapLayout.SIDE_OWN))
	var camera: Camera3D = practice.get_node("%FollowCamera") as Camera3D
	assert_gt(camera.position.z, player.position.y - 0.001, "camera is behind the player (+Z side)")
	assert_almost_eq(camera.rotation_degrees.y, CAMERA.yaw_offset_degrees, 0.001, "behind and to the right")


func test_stick_moves_the_player_and_the_camera_follows() -> void:
	var practice: PracticeMatch = _practice()
	var start_z: float = practice.sim.players[PracticeMatch.LOCAL_ID].position.y
	practice.set_stick(_toward_enemy(practice))
	for i: int in 30:
		practice.advance(DT)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_almost_eq(player.position.y, start_z - 5.0, 0.05)
	var capsule: Node3D = practice.get_node("%Actors").get_child(0) as Node3D
	assert_almost_eq(capsule.position.x, player.position.x, 0.0001)
	assert_almost_eq(capsule.position.z, player.position.y, 0.0001)
	var camera: FollowCamera = practice.get_node("%FollowCamera") as FollowCamera
	var lag: float = camera.position.z - camera.desired_position(player.position, false).z
	assert_between(lag, 0.0, 2.5, "eases after the hero, a little behind")
	practice.set_stick(Vector2.ZERO)
	for i: int in 60:
		practice.advance(DT)
	assert_almost_eq(camera.position.distance_to(camera.desired_position(player.position, false)), 0.0, 0.05, "then settles on them")


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


func test_hurt_button_path_and_no_health_panel_in_the_corner() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_eq(player.hp, 100)
	practice.hurt_local(30)
	assert_eq(player.hp, 70)
	assert_null(practice.get_node_or_null("%HpLabel"), "health lives over the character, not top-left")
	assert_null(practice.get_node_or_null("%PlayerCard"))


func test_zero_hp_starts_the_death_delay_with_gray_hp_and_locked_skills() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.players[PracticeMatch.LOCAL_ID].position = Vector2(0.0, 0.0)
	practice.hurt_local(100)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].gray_hp, 50.0)
	assert_true(practice.hud.delay_label.visible)
	assert_false(practice.hud.respawn_label.visible)
	assert_true((practice.get_node("%Actors").get_child(0) as Node3D).visible, "still on their feet")
	assert_true(practice.hud.dash_button.locked)
	assert_true(practice.hud.bookmark_button.locked)


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
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].hp, 50)
	assert_false(practice.hud.delay_label.visible)
	assert_false(practice.hud.dash_button.locked)


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
	var respawn: Label = practice.hud.respawn_label
	assert_false(respawn.visible)
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	practice.advance(0.0)
	assert_false(capsule.visible)
	assert_true(respawn.visible)
	assert_eq(respawn.text, "RESPAWN IN 10")
	for i: int in 305:
		practice.advance(DT)
	assert_true(capsule.visible)
	assert_false(respawn.visible)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].hp, 100)


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
	var dash: TouchButton = practice.hud.dash_button
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
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.advance(DT)
	var cooldown: float = player.dash_cooldown_left
	practice.advance(DT)
	assert_lt(player.dash_cooldown_left, cooldown, "cooldown runs, not re-triggered")


func test_skill_buttons_are_disabled_while_on_cooldown() -> void:
	var practice: PracticeMatch = _practice()
	var dash: TouchButton = practice.hud.dash_button
	var mark: TouchButton = practice.hud.bookmark_button
	_equip(practice, &"bato_light", &"papel_shield")
	practice.press_skill(PlayerInput.BTN_BOOKMARK)
	practice.advance(DT)
	assert_true(mark.locked, "out on the mark")
	assert_false(dash.locked)
	practice.aim_started(1)
	practice.aim_released(Vector2.ZERO, false, 1)
	for i: int in 3:
		practice.advance(DT)
	assert_true(_weapon_button(practice, 1).locked, "shield on cooldown")
	assert_false(_weapon_button(practice, 0).locked)
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.advance(DT)
	assert_true(dash.locked)


# ---- weapon pick ---------------------------------------------------------------

func test_match_waits_on_the_opening_weapon_pick() -> void:
	var practice: PracticeMatch = _picking()
	assert_true(practice.is_picking())
	assert_true(_pick_screen(practice).visible)
	practice.set_stick(Vector2(0.0, -1.0))
	for i: int in 30:
		practice.advance(DT)
	assert_eq(practice.sim.tick, 0, "sim paused while picking")


func test_touch_controls_are_off_under_the_pick_screen() -> void:
	var practice: PracticeMatch = _picking()
	assert_false(practice.controls_active())
	practice.finish_pick()
	assert_true(practice.controls_active())
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	assert_false(practice.controls_active(), "off again on the respawn swap screen")


func test_tapping_two_weapons_and_ready_sets_the_loadout() -> void:
	var practice: PracticeMatch = _picking()
	var screen: WeaponPickScreen = _pick_screen(practice)
	screen.tap(&"lata")
	screen.tap(&"trumpo")
	screen.press_ready()
	assert_false(practice.is_picking())
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].weapons, [&"lata", &"trumpo"] as Array[StringName])
	practice.advance(DT)
	assert_eq(practice.sim.tick, 1, "the match starts")
	assert_eq(_weapon_button(practice, 0).label_text, "Lata")
	assert_eq(_weapon_button(practice, 0).sub_text, "CC")


func test_pick_screen_groups_all_twelve_weapons() -> void:
	var practice: PracticeMatch = _picking()
	var buttons: Array[Node] = _pick_screen(practice).find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 13, "12 weapons + Ready")


func test_pick_timer_runs_out_and_auto_fills() -> void:
	var practice: PracticeMatch = _picking()
	_pick_screen(practice).tap(&"jacks")
	for i: int in 310:
		practice.advance(DT)
	assert_false(practice.is_picking())
	var weapons: Array[StringName] = practice.sim.players[PracticeMatch.LOCAL_ID].weapons
	assert_eq(weapons[0], &"jacks")
	assert_ne(weapons[1], &"jacks")
	assert_gt(practice.sim.tick, 0)


func test_dying_opens_the_swap_screen_with_your_weapons_then_respawn_closes_it() -> void:
	var practice: PracticeMatch = _practice()
	var weapons: Array[StringName] = practice.sim.players[PracticeMatch.LOCAL_ID].weapons.duplicate()
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	assert_true(practice.is_picking())
	assert_eq(_pick_screen(practice).pick.picks, weapons)
	practice.advance(DT)
	assert_eq(practice.sim.tick, 1, "the match keeps running while you swap")
	for i: int in 310:
		practice.advance(DT)
	assert_false(practice.is_picking())
	assert_true(practice.sim.players[PracticeMatch.LOCAL_ID].alive)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].weapons, weapons)


# ---- weapon buttons ------------------------------------------------------------

func _equip(practice: PracticeMatch, first: StringName, second: StringName) -> void:
	assert_true(practice.sim.set_loadout(PracticeMatch.LOCAL_ID, first, second))


func test_a_quick_tap_still_casts_with_auto_aim() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"bato_light", &"papel_shield")
	var enemy: PlayerState = _enemy_ahead(practice, 5.0)
	practice.aim_started(0)
	practice.aim_released(Vector2.ZERO, false, 0)
	practice.advance(DT)
	practice.advance(DT)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_gt(player.weapon_cooldowns[0], 3.9)
	for i: int in 30:
		practice.advance(DT)
	assert_eq(enemy.hp, 86)
	assert_gt(_weapon_button(practice, 0).cooldown_fraction, 0.0)


func test_drag_aim_points_the_cast_up_the_screen() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"gunting_heavy", &"papel_shield")
	var enemy: PlayerState = _enemy_ahead(practice, 2.5)
	practice.aim_started(0)
	practice.advance(DT)
	practice.aim_released(_toward_enemy(practice), false, 0)
	for i: int in 30:
		practice.advance(DT)
	assert_eq(enemy.hp, 76, "screen up is toward the enemy base")


func test_aiming_down_misses_the_enemy_ahead() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"gunting_heavy", &"papel_shield")
	var enemy: PlayerState = _enemy_ahead(practice, 2.5)
	practice.aim_started(0)
	practice.advance(DT)
	practice.aim_released(Vector2(0.0, 1.0), false, 0)
	for i: int in 30:
		practice.advance(DT)
	assert_eq(enemy.hp, 100)


func test_release_over_cancel_does_not_cast() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"bato_light", &"papel_shield")
	var enemy: PlayerState = _enemy_ahead(practice, 5.0)
	practice.aim_started(0)
	practice.advance(DT)
	practice.aim_released(Vector2.ZERO, true, 0)
	for i: int in 30:
		practice.advance(DT)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].weapon_cooldowns[0], 0.0)
	assert_eq(enemy.hp, 100)


func test_second_slot_casts_its_own_weapon() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"bato_light", &"papel_shield")
	_enemy_ahead(practice, 5.0)
	practice.aim_started(1)
	practice.aim_released(Vector2.ZERO, false, 1)
	practice.advance(DT)
	practice.advance(DT)
	assert_eq(practice.sim.weapons.shields.size(), 1)
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].weapon_cooldowns[0], 0.0)


func test_weapon_buttons_lock_in_the_death_delay_and_under_stun() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.apply_effect(PracticeMatch.LOCAL_ID, StatusEffects.Type.STUN, 1.0, 0.0)
	practice.advance(DT)
	assert_true(_weapon_button(practice, 0).locked)
	for i: int in 40:
		practice.advance(DT)
	assert_false(_weapon_button(practice, 0).locked)
	practice.sim.players[PracticeMatch.LOCAL_ID].position = Vector2.ZERO
	practice.hurt_local(100)
	assert_true(_weapon_button(practice, 1).locked)


func test_aim_button_drag_math() -> void:
	assert_eq(AimButton.aim_from_drag(Vector2(5.0, 5.0)), Vector2.ZERO, "tiny drag = tap = auto-aim")
	assert_almost_eq(AimButton.aim_from_drag(Vector2(0.0, -85.0)).y, -0.5, 0.001)
	assert_almost_eq(AimButton.aim_from_drag(Vector2(0.0, -900.0)).length(), 1.0, 0.001)


# ---- visuals -------------------------------------------------------------------

func test_projectiles_zones_and_shields_get_drawn_and_cleaned_up() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"tsinelas_heavy", &"papel_shield")
	_enemy_ahead(practice, 5.0)
	var fx: WeaponFxView = practice.get_node("%WeaponFx") as WeaponFxView
	practice.aim_started(0)
	practice.aim_released(Vector2.ZERO, false, 0)
	practice.aim_started(1)
	practice.aim_released(Vector2.ZERO, false, 1)
	practice.advance(DT)
	practice.advance(DT)
	assert_eq(fx.live_count(), 2, "one slipper and one paper wall")
	for i: int in 150:
		practice.advance(DT)
	assert_eq(fx.live_count(), 0)


func test_aim_indicator_shows_range_and_landing_circle() -> void:
	var sim: MatchSim = MatchSim.new(load("res://data/rules/game_rules.tres") as GameRules, LAYOUT, 1)
	var caster: PlayerState = sim.add_player(1, 0)
	caster.position = Vector2.ZERO
	var def: WeaponDef = sim.weapon_defs[&"bato_heavy"]
	var lines: Array[PackedVector2Array] = AimIndicator.outline(sim, caster, def, Vector2(0.0, -0.5), -1)
	assert_eq(lines.size(), 3, "range circle, aim line, landing circle")
	assert_almost_eq(lines[0][0].length(), def.max_range, 0.001)
	assert_almost_eq(lines[1][1].y, -4.0, 0.001, "half the stick = half the range")
	var cone: Array[PackedVector2Array] = AimIndicator.outline(sim, caster, sim.weapon_defs[&"gunting_light"], Vector2(1.0, 0.0))
	assert_eq(cone.size(), 2)


func test_every_player_gets_a_different_character_and_no_name_over_their_head() -> void:
	var practice: PracticeMatch = _practice()
	var seen: Dictionary[StringName, bool] = {}
	for id: int in practice.sim.players:
		var character: StringName = practice.sim.players[id].character_id
		assert_ne(character, &"")
		assert_false(seen.has(character))
		seen[character] = true
	for id: int in practice.sim.players:
		assert_eq(practice.overhead().text_for(id), "", "no name text over a healthy hero")


func test_status_effects_show_over_the_hero_in_words() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.apply_effect(PracticeMatch.ENEMY_STAND_ID, StatusEffects.Type.POLYMORPH, 2.0, 0.0)
	practice.advance(DT)
	var enemy_view: Node3D = practice.get_node("%Actors").get_child(1) as Node3D
	assert_eq(practice.overhead().text_for(PracticeMatch.ENEMY_STAND_ID), "Polymorphed")
	assert_true((enemy_view as KidModel).is_can(), "turned into a can")


# ---- respawn swap (D13: no limit while dead) ------------------------------------

func test_while_dead_weapons_can_be_swapped_again_and_again() -> void:
	var practice: PracticeMatch = _practice()
	var screen: WeaponPickScreen = _pick_screen(practice)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	practice.sim.set_loadout(PracticeMatch.LOCAL_ID, &"bato_light", &"lata")
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	screen.tap(&"bato_light")
	screen.tap(&"jacks")
	assert_eq(player.weapons, [&"lata", &"jacks"] as Array[StringName], "applied at once")
	for i: int in 120:
		practice.advance(DT)
	assert_true(practice.is_picking(), "no pick timer: stays open while dead")
	screen.tap(&"trumpo")
	assert_eq(player.weapons, [&"jacks", &"trumpo"] as Array[StringName])
	screen.tap(&"bola")
	assert_eq(player.weapons, [&"trumpo", &"bola"] as Array[StringName])


func test_done_closes_and_the_swap_button_reopens_while_dead() -> void:
	var practice: PracticeMatch = _practice()
	var screen: WeaponPickScreen = _pick_screen(practice)
	var swap: Button = practice.hud.swap_button
	practice.sim.kill(PracticeMatch.LOCAL_ID)
	practice.advance(DT)
	assert_false(swap.visible, "hidden under the open swap screen")
	screen.press_ready()
	practice.advance(DT)
	assert_false(practice.is_picking())
	assert_true(swap.visible)
	assert_true(practice.controls_active())
	practice.open_swap()
	assert_true(practice.is_picking())
	screen.press_ready()
	practice.open_swap()
	assert_true(practice.is_picking(), "as many times as you like")
	for i: int in 310:
		practice.advance(DT)
	assert_true(practice.sim.players[PracticeMatch.LOCAL_ID].alive)
	assert_false(practice.is_picking(), "respawning closes it")
	assert_false(swap.visible)
	practice.open_swap()
	assert_false(practice.is_picking(), "no swapping while alive")


# ---- M3: walls, scoring, ball, tricycle -----------------------------------------

func _score_point(practice: PracticeMatch) -> void:
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	player.position = LAYOUT.base_center(-practice.own_side())
	for i: int in 20:
		practice.advance(DT)


func _finish_freeze(practice: PracticeMatch) -> void:
	for i: int in 100:
		practice.advance(DT)


func test_walls_are_drawn_from_the_sim_and_disappear_when_broken() -> void:
	var practice: PracticeMatch = _practice()
	var walls: WallsView = practice.get_node("%Walls") as WallsView
	assert_eq(walls.standing_count(), 12)
	practice.sim.damage_wall(4, 1000)
	assert_eq(walls.standing_count(), 11)


func test_scoring_shows_a_banner_and_updates_the_scoreboard() -> void:
	var practice: PracticeMatch = _practice()
	assert_string_starts_with(practice.scoreboard().summary(), "YOU 0 - 0 THEM")
	_score_point(practice)
	assert_string_starts_with(practice.scoreboard().summary(), "YOU 1 - 0 THEM")
	assert_eq(practice.banner_text(), "BASE CAPTURED!")
	assert_string_contains(practice.hud.info_label.text, "Next round in")
	_finish_freeze(practice)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_eq(player.position, player.spawn_position, "back at base")


func test_new_set_turns_the_view_around_and_recolors_the_bases() -> void:
	var practice: PracticeMatch = _practice()
	var map: StreetMap = practice.get_node("%Map") as StreetMap
	assert_eq(map.base_color(MapLayout.SIDE_OWN), StreetMap.OWN_COLOR)
	for i: int in 5:
		_score_point(practice)
		_finish_freeze(practice)
	assert_eq(practice.own_side(), MapLayout.SIDE_ENEMY, "we defend the -Z base now")
	assert_eq(map.base_color(MapLayout.SIDE_ENEMY), StreetMap.OWN_COLOR, "our base is blue wherever it is")
	var camera: Camera3D = practice.get_node("%FollowCamera") as Camera3D
	assert_almost_eq(wrapf(camera.rotation_degrees.y - CAMERA.yaw_degrees(true), -180.0, 180.0), 0.0, 0.01, "own base still at the bottom of the screen")
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	var start_z: float = player.position.y
	practice.set_stick(_toward_enemy(practice))
	for i: int in 15:
		practice.advance(DT)
	assert_gt(player.position.y, start_z, "stick up still walks toward the enemy base (+Z now)")


func test_match_over_shows_play_again() -> void:
	var practice: PracticeMatch = _practice()
	var again: Button = practice.hud.again_button
	for i: int in 10:
		_score_point(practice)
		_finish_freeze(practice)
	assert_eq(practice.sim.phase, MatchSim.Phase.MATCH_OVER)
	assert_true(again.visible)
	assert_eq(practice.banner_text(), "VICTORY!")


func test_ball_button_throws_the_ball_at_a_dummy() -> void:
	var practice: PracticeMatch = _practice()
	var ball_button: AimButton = practice.hud.ball_button
	var enemy: PlayerState = _enemy_ahead(practice, 5.0)
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	practice.sim.ball.spawn_timer = 0.0
	player.position = Vector2(0.0, 0.0)
	enemy.position = Vector2(0.0, -5.0)
	practice.advance(DT)
	practice.advance(DT)
	assert_true(practice.sim.ball.is_holder(PracticeMatch.LOCAL_ID))
	practice.advance(DT)
	assert_eq(ball_button.label_text, "Throw")
	var neutrals: NeutralsView = practice.get_node("%Neutrals") as NeutralsView
	assert_true(neutrals.ball_visible())
	practice.aim_started(PracticeMatch.BALL_SLOT)
	practice.aim_released(Vector2.ZERO, false, PracticeMatch.BALL_SLOT)
	for i: int in 15:
		practice.advance(DT)
	assert_true(enemy.effects.has(StatusEffects.Type.KNOCKOUT))
	assert_eq(ball_button.label_text, "Catch")


func test_tricycle_test_button_brings_it_now() -> void:
	var practice: PracticeMatch = _practice()
	practice.hud.tricycle_button.pressed.emit()
	practice.advance(DT)
	assert_eq(practice.banner_text(), "TRICYCLE INCOMING!\nGet off the road!")
	for i: int in 70:
		practice.advance(DT)
	assert_true((practice.get_node("%Neutrals") as NeutralsView).tricycle_visible())



func test_damage_numbers_pop_up_and_fade() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.damage(PracticeMatch.ENEMY_STAND_ID, 14)
	assert_eq(practice.overhead().popup_count(), 1)
	for i: int in 40:
		practice.advance(DT)
	assert_eq(practice.overhead().popup_count(), 0, "gone after under a second")


func test_overhead_bars_use_ml_colours() -> void:
	var practice: PracticeMatch = _practice()
	var hud: OverheadHud = practice.overhead()
	assert_eq(hud.bar_color(practice.sim.players[PracticeMatch.LOCAL_ID]), OverheadHud.SELF_COLOR)
	assert_eq(hud.bar_color(practice.sim.players[PracticeMatch.ALLY_ID]), OverheadHud.ALLY_COLOR)
	assert_eq(hud.bar_color(practice.sim.players[PracticeMatch.ENEMY_STAND_ID]), OverheadHud.ENEMY_COLOR)


func test_minimap_puts_our_base_at_the_bottom_even_after_the_switch() -> void:
	var practice: PracticeMatch = _practice()
	var minimap: LaneMinimap = practice.hud.minimap
	var own_base: Vector2 = minimap.to_map(LAYOUT.base_center(practice.own_side()))
	var their_base: Vector2 = minimap.to_map(LAYOUT.base_center(-practice.own_side()))
	assert_gt(own_base.y, their_base.y)
	for i: int in 5:
		_score_point(practice)
		_finish_freeze(practice)
	own_base = minimap.to_map(LAYOUT.base_center(practice.own_side()))
	their_base = minimap.to_map(LAYOUT.base_center(-practice.own_side()))
	assert_gt(own_base.y, their_base.y, "still at the bottom")
	assert_lt(own_base.x, their_base.x, "slanted: our base bottom left, theirs top right")


func test_skill_buttons_show_cooldown_seconds() -> void:
	var practice: PracticeMatch = _practice()
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.advance(DT)
	var dash: TouchButton = practice.hud.dash_button
	assert_eq(ceili(dash.cooldown_seconds), 8)



func test_a_status_is_shown_as_words_and_clears() -> void:
	var practice: PracticeMatch = _practice()
	var hud: OverheadHud = practice.overhead()
	assert_eq(hud.text_for(PracticeMatch.ENEMY_STAND_ID), "")
	practice.sim.apply_effect(PracticeMatch.ENEMY_STAND_ID, StatusEffects.Type.STUN, 2.0, 0.0)
	assert_eq(hud.text_for(PracticeMatch.ENEMY_STAND_ID), "Stunned")
	practice.sim.players[PracticeMatch.ENEMY_STAND_ID].effects.clear()
	assert_eq(hud.text_for(PracticeMatch.ENEMY_STAND_ID), "")
	practice.sim.players[PracticeMatch.LOCAL_ID].position = Vector2(0.0, 0.0)
	practice.hurt_local(100)
	assert_eq(hud.text_for(PracticeMatch.LOCAL_ID), "Down")


func test_the_status_font_is_a_slanted_italic() -> void:
	var practice: PracticeMatch = _practice()
	var italic: FontVariation = practice.overhead()._italic
	assert_not_null(italic)
	assert_lt(italic.variation_transform.y.x, 0.0, "slanted")


func test_dash_and_mark_cooldown_bars_fill_as_they_recharge() -> void:
	var practice: PracticeMatch = _practice()
	var hud: OverheadHud = practice.overhead()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	assert_eq(hud.dash_fraction(player), 1.0)
	assert_eq(hud.mark_fraction(player), 1.0)
	practice.press_skill(PlayerInput.BTN_DASH)
	practice.advance(DT)
	assert_lt(hud.dash_fraction(player), 0.1, "just used")
	for i: int in 120:
		practice.advance(DT)
	assert_between(hud.dash_fraction(player), 0.4, 0.6, "about half way after 4 of 8 s")
	practice.press_skill(PlayerInput.BTN_BOOKMARK)
	practice.advance(DT)
	assert_true(player.mark_active)
	assert_between(hud.mark_fraction(player), 0.9, 1.0, "out on the mark: bonus time left, draining")
	for i: int in 135:
		practice.advance(DT)
	assert_false(player.mark_active)
	assert_lt(hud.mark_fraction(player), 0.1, "back at the mark: the 14 s cooldown starts")


func test_skill_buttons_are_art_with_only_the_type_tag() -> void:
	var practice: PracticeMatch = _practice()
	_equip(practice, &"papel_shield", &"bato_light")
	practice.advance(DT)
	var block: AimButton = _weapon_button(practice, 0)
	assert_eq(block.icon_id, &"papel_shield")
	assert_eq(block.sub_text, "BLK")
	assert_eq(_weapon_button(practice, 1).sub_text, "ATK")
	var guava: AimButton = practice.hud.ball_button
	assert_eq(guava.icon_id, &"ball")
	assert_eq(guava.sub_text, "", "no text on the guava, Dash or Mark buttons")
	assert_eq(practice.hud.dash_button.sub_text, "")


func test_eating_the_guava_heals_and_pops_a_green_number() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	player.position = Vector2.ZERO
	player.hp = 20
	practice.sim.ball.spawn_timer = 0.0
	practice.advance(DT)
	practice.advance(DT)
	assert_eq(player.hp, 70)
	assert_eq(practice.overhead().popup_count(), 1)


## The screen direction (stick or drag) that heads straight for the enemy base.
func _toward_enemy(practice: PracticeMatch) -> Vector2:
	var flip: bool = practice.own_side() == MapLayout.SIDE_ENEMY
	return LocalInput.to_screen(Vector2(0.0, -float(practice.own_side())), flip, CAMERA.yaw_offset_degrees)
