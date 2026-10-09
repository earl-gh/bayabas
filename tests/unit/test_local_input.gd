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
