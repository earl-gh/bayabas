extends GutTest

const T := StatusEffects.Type


func test_apply_and_expire() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.STUN, 1.0)
	assert_true(fx.has(T.STUN))
	fx.step(0.6)
	assert_true(fx.has(T.STUN))
	fx.step(0.5)
	assert_false(fx.has(T.STUN))


func test_effects_do_not_stack_with_themselves_longest_wins() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.STUN, 2.0)
	fx.apply(T.STUN, 0.5)
	assert_almost_eq(fx.time_left(T.STUN), 2.0, 0.0001, "a shorter one doesn't cut it")
	fx.step(1.5)
	fx.apply(T.STUN, 2.0)
	assert_almost_eq(fx.time_left(T.STUN), 2.0, 0.0001, "a new hard CC refreshes the duration")


func test_slow_keeps_the_strongest_and_resets_when_it_ends() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.SLOW, 1.0, 0.3)
	fx.apply(T.SLOW, 1.0, 0.4)
	fx.apply(T.SLOW, 1.0, 0.2)
	assert_almost_eq(fx.speed_multiplier(0.5), 0.6, 0.0001)
	fx.step(1.1)
	assert_eq(fx.speed_multiplier(0.5), 1.0)
	fx.apply(T.SLOW, 1.0, 0.1)
	assert_almost_eq(fx.speed_multiplier(0.5), 0.9, 0.0001, "an old strong slow doesn't linger")


func test_hard_cc_blocks_moving_and_casting() -> void:
	for type: StatusEffects.Type in [T.STUN, T.AIRBORNE, T.BOUNCE, T.KNOCKOUT]:
		var fx: StatusEffects = StatusEffects.new()
		fx.apply(type, 1.0)
		assert_false(fx.can_move(), "%s stops movement" % T.keys()[type])
		assert_false(fx.can_cast())
		assert_true(fx.is_hard_cc(type))


func test_polymorph_walks_at_half_speed_but_cannot_cast() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.POLYMORPH, 2.0)
	assert_true(fx.can_move())
	assert_false(fx.can_cast())
	assert_almost_eq(fx.speed_multiplier(0.5), 0.5, 0.0001)
	assert_false(fx.is_hard_cc(T.POLYMORPH))


func test_slow_and_none_do_not_stop_anything() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.SLOW, 1.0, 0.4)
	fx.apply(T.NONE, 5.0)
	assert_true(fx.can_move())
	assert_true(fx.can_cast())
	assert_false(fx.has(T.NONE))


func test_clear_and_names() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.STUN, 1.0)
	assert_true(fx.display_names().has("Stunned"))
	fx.clear()
	assert_true(fx.can_move())
	assert_eq(fx.speed_multiplier(0.5), 1.0)


func test_a_new_status_overwrites_the_current_one() -> void:
	var fx: StatusEffects = StatusEffects.new()
	fx.apply(T.STUN, 2.0)
	fx.apply(T.SLOW, 1.0, 0.5)
	assert_eq(fx.active_names().size(), 1)
	assert_true(fx.has(T.SLOW))
	assert_false(fx.has(T.STUN))
	assert_true(fx.can_move(), "the stun is gone")
	fx.apply(T.SLOW, 3.0, 0.3)
	assert_almost_eq(fx.time_left(T.SLOW), 3.0, 0.001, "the same status keeps the longer time")
