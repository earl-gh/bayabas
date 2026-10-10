extends GutTest


func test_combine_caps_length_at_one() -> void:
	assert_eq(LocalInput.combine(Vector2(1.0, 0.0), Vector2(1.0, 0.0)), Vector2(1.0, 0.0))
	assert_almost_eq(LocalInput.combine(Vector2(1.0, 0.0), Vector2(0.0, -1.0)).length(), 1.0, 0.0001)
	assert_eq(LocalInput.combine(Vector2(0.2, 0.0), Vector2.ZERO), Vector2(0.2, 0.0))


func test_other_team_stick_is_rotated_back() -> void:
	assert_eq(LocalInput.to_world(Vector2(0.5, -1.0), false), Vector2(0.5, -1.0))
	assert_eq(LocalInput.to_world(Vector2(0.5, -1.0), true), Vector2(-0.5, 1.0))


func test_keyboard_vector_is_zero_without_keys() -> void:
	assert_eq(LocalInput.keyboard_vector(), Vector2.ZERO)


func test_stick_from_offset_scales_and_caps() -> void:
	assert_eq(VirtualJoystick.stick_from_offset(Vector2(45.0, 0.0), 90.0, 0.1), Vector2(0.5, 0.0))
	assert_eq(VirtualJoystick.stick_from_offset(Vector2(0.0, -300.0), 90.0, 0.1), Vector2(0.0, -1.0))


func test_stick_deadzone() -> void:
	assert_eq(VirtualJoystick.stick_from_offset(Vector2(5.0, 0.0), 90.0, 0.1), Vector2.ZERO)
	assert_eq(VirtualJoystick.stick_from_offset(Vector2.ZERO, 90.0, 0.1), Vector2.ZERO)


func test_keyboard_buttons_is_zero_without_keys() -> void:
	assert_eq(LocalInput.keyboard_buttons(), 0)


func test_touch_button_hit_area_is_round() -> void:
	var size: Vector2 = Vector2(128.0, 128.0)
	assert_true(TouchButton.hit_test(Vector2(64.0, 64.0), size))
	assert_true(TouchButton.hit_test(Vector2(64.0, 5.0), size), "near the top edge")
	assert_false(TouchButton.hit_test(Vector2(2.0, 2.0), size), "corner is outside the circle")
	assert_false(TouchButton.hit_test(Vector2(300.0, 64.0), size))


func test_touch_button_cooldown_fraction() -> void:
	var button: TouchButton = autofree(TouchButton.new()) as TouchButton
	button.set_cooldown(4.0, 8.0)
	assert_eq(button.cooldown_fraction, 0.5)
	button.set_cooldown(0.0, 8.0)
	assert_eq(button.cooldown_fraction, 0.0)
	button.set_cooldown(9.0, 8.0)
	assert_eq(button.cooldown_fraction, 1.0)


func test_holding_one_skill_button_locks_every_other_one() -> void:
	var held: AimButton = autofree(AimButton.new()) as AimButton
	var other: AimButton = autofree(AimButton.new()) as AimButton
	var dash: TouchButton = autofree(TouchButton.new()) as TouchButton
	add_child(held)
	add_child(other)
	add_child(dash)
	assert_true(other.can_press())
	held._begin(Vector2.ZERO)
	assert_true(held.can_press(), "the held button itself stays usable")
	assert_false(other.can_press(), "no second weapon")
	assert_false(dash.can_press(), "no dash or mark either")
	held._finish(false)
	assert_true(other.can_press(), "free again after the release")
	assert_true(dash.can_press())


func test_dash_and_mark_are_dropped_while_a_skill_is_held() -> void:
	var input: MatchInput = MatchInput.new()
	input.aim_started(0)
	input.press_skill(PlayerInput.BTN_DASH)
	var built: PlayerInput = input.build(false, func(_slot: int) -> Vector2: return Vector2.ZERO, 1)
	assert_eq(built.buttons & PlayerInput.BTN_DASH, 0, "dash ignored while holding")
	assert_ne(built.buttons & PlayerInput.BTN_WEAPON_1, 0, "the held weapon is still sent")
	input.aim_released(Vector2.ZERO, false, 0)
	input.build(false, func(_slot: int) -> Vector2: return Vector2.ZERO, 2)
	input.press_skill(PlayerInput.BTN_DASH)
	built = input.build(false, func(_slot: int) -> Vector2: return Vector2.ZERO, 3)
	assert_ne(built.buttons & PlayerInput.BTN_DASH, 0, "dash works again after the release")


func test_the_settings_menu_pauses_the_controls() -> void:
	var hud: MatchHud = autofree(MatchHud.new()) as MatchHud
	add_child(hud)
	assert_false(hud.menu.visible)
	assert_not_null(hud.settings_button.texture_normal, "painted gear")
	hud.toggle_menu()
	assert_true(hud.menu.visible)
	assert_false(hud.controls_active(), "no casting through the menu")
	hud.toggle_menu()
	assert_true(hud.controls_active())


func test_one_thumb_controls_sit_in_the_corner_and_mirror_for_the_left_hand() -> void:
	var was_left: bool = Settings.left_handed
	var screen_root: Control = autofree(Control.new()) as Control
	screen_root.size = Vector2(720.0, 1280.0)
	add_child(screen_root)
	var hud: MatchHud = MatchHud.new()
	screen_root.add_child(hud)
	hud.layout_controls(false)
	var stick: Vector2 = hud.joystick.get_rect().get_center()
	var screen: Vector2 = hud.get_rect().size
	assert_gt(stick.x, screen.x * 0.7, "right hand: joystick where the basic attack usually is")
	assert_gt(stick.y, screen.y * 0.8)
	for button: Control in [hud.weapon_buttons[0], hud.weapon_buttons[1], hud.dash_button, hud.bookmark_button]:
		var distance: float = button.get_rect().get_center().distance_to(stick)
		assert_almost_eq(distance, MatchHud.ARC_RADIUS, 1.0, "in an arc around the joystick")
		assert_lt(button.get_rect().get_center().x, stick.x + 1.0, "on the inner side")
	hud.layout_controls(true)
	var mirrored: Vector2 = hud.joystick.get_rect().get_center()
	assert_almost_eq(mirrored.x, screen.x - stick.x, 1.0, "left hand: mirrored")
	assert_gt(hud.weapon_buttons[0].get_rect().get_center().x, mirrored.x, "skills arc to the right")
	Settings.left_handed = was_left


func test_the_menu_switches_handedness() -> void:
	var was_left: bool = Settings.left_handed
	var hud: MatchHud = autofree(MatchHud.new()) as MatchHud
	add_child(hud)
	hud.toggle_menu()
	hud.menu.left_button.pressed.emit()
	assert_true(Settings.left_handed)
	assert_true(hud.left_handed, "the HUD follows the setting")
	hud.menu.right_button.pressed.emit()
	assert_false(hud.left_handed)
	Settings.set_left_handed(was_left)
