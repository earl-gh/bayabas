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
	return practice.get_node("%%WeaponButton%d" % (slot + 1)) as AimButton


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
	practice.aim_released(Vector2(0.0, -1.0), false, 0)
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
	var lines: Array[PackedVector2Array] = AimIndicator.outline(sim, caster, def, Vector2(0.0, -0.5))
	assert_eq(lines.size(), 3, "range circle, aim line, landing circle")
	assert_almost_eq(lines[0][0].length(), def.max_range, 0.001)
	assert_almost_eq(lines[1][1].y, -4.0, 0.001, "half the stick = half the range")
	var cone: Array[PackedVector2Array] = AimIndicator.outline(sim, caster, sim.weapon_defs[&"gunting_light"], Vector2(1.0, 0.0))
	assert_eq(cone.size(), 2)


func test_every_player_gets_a_different_character_and_a_name_tag() -> void:
	var practice: PracticeMatch = _practice()
	var seen: Dictionary[StringName, bool] = {}
	for id: int in practice.sim.players:
		var character: StringName = practice.sim.players[id].character_id
		assert_ne(character, &"")
		assert_false(seen.has(character))
		seen[character] = true
	var tags: Array[Node] = practice.get_node("%Actors").find_children("*", "Label3D", true, false)
	assert_eq(tags.size(), 4)
	assert_string_starts_with((tags[0] as Label3D).text, "You (")


func test_status_effects_show_on_name_tags() -> void:
	var practice: PracticeMatch = _practice()
	practice.sim.apply_effect(PracticeMatch.ENEMY_STAND_ID, StatusEffects.Type.POLYMORPH, 2.0, 0.0)
	practice.advance(DT)
	var enemy_view: Node3D = practice.get_node("%Actors").get_child(1) as Node3D
	var tag: Label3D = enemy_view.find_children("*", "Label3D", true, false)[0] as Label3D
	assert_string_contains(tag.text, "POLYMORPH")
	assert_lt(enemy_view.scale.y, 1.0, "turned into a can")


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
	var swap: Button = practice.get_node("%SwapButton") as Button
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
