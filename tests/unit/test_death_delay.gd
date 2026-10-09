extends GutTest

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
## A mid-lane spot far from both base posts.
const MID: Vector2 = Vector2(0.0, 0.0)


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 5)


func _tick(sim: MatchSim, id: int, move: Vector2, buttons: int = 0) -> void:
	sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, buttons, sim.tick))
	sim.step(DT)


func _run(sim: MatchSim, id: int, move: Vector2, ticks: int) -> void:
	for i: int in ticks:
		_tick(sim, id, move)


## A player (team 0) in the death delay in mid-lane.
func _downed(sim: MatchSim, id: int = 1) -> PlayerState:
	var p: PlayerState = sim.add_player(id, 0)
	p.position = MID
	sim.damage(id, 100)
	return p


func test_death_delay_numbers_come_from_data() -> void:
	assert_true(RULES.death_delay_enabled)
	assert_eq(RULES.death_delay_gray_hp, 50.0)
	assert_eq(RULES.death_delay_drain_per_second, 8.0)
	assert_eq(RULES.death_delay_move_speed_scale, 1.0)
	assert_eq(RULES.revive_touch_distance, 1.0)
	assert_eq(RULES.post_touch_distance, 1.2)
	assert_false(RULES.death_delay_takes_damage)


func test_zero_hp_starts_the_delay_with_full_gray_hp() -> void:
	var sim: MatchSim = _sim()
	watch_signals(sim)
	var p: PlayerState = _downed(sim)
	assert_true(p.alive)
	assert_true(p.death_delay)
	assert_eq(p.hp, 0)
	assert_eq(p.gray_hp, 50.0)
	assert_true(p.death_delay_used)
	assert_signal_emitted_with_parameters(sim, "player_death_delay_started", [1])
	assert_signal_not_emitted(sim, "player_died")


func test_skills_are_disabled_during_the_delay() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_DASH)
	assert_eq(p.dash_time_left, 0.0)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	assert_false(p.mark_active)
	assert_eq(p.dash_cooldown_left, 0.0, "no cooldown spent")
	assert_false(p.can_act())


func test_starting_the_delay_cancels_active_effects() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = MID
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_BOOKMARK)
	assert_true(p.mark_active)
	sim.damage(1, 100)
	assert_false(p.mark_active)
	assert_eq(p.boost_time_left, 0.0)


func test_walking_drains_gray_hp_and_standing_still_does_not() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	_run(sim, 1, Vector2.ZERO, 60)
	assert_eq(p.gray_hp, 50.0, "no drain while standing still")
	_run(sim, 1, Vector2(0.0, -1.0), 30)
	assert_almost_eq(p.gray_hp, 50.0 - 8.0, 0.05, "8 per second at full stick")


func test_half_stick_drains_half_as_fast() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	_run(sim, 1, Vector2(0.0, -0.5), 30)
	assert_almost_eq(p.gray_hp, 50.0 - 4.0, 0.05)


func test_movement_speed_in_the_delay_uses_the_data_scale() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var start: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 30)
	assert_almost_eq(p.position.x - start.x, RULES.move_speed * RULES.death_delay_move_speed_scale, 0.05)


func test_gray_hp_running_out_is_a_real_death_then_a_full_respawn() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	watch_signals(sim)
	_run(sim, 1, Vector2(1.0, 0.0), 200)
	assert_false(p.alive)
	assert_false(p.death_delay)
	assert_signal_emitted_with_parameters(sim, "player_died", [1])
	_run(sim, 1, Vector2.ZERO, 305)
	assert_true(p.alive)
	assert_eq(p.hp, 100, "a respawn is full HP, not gray HP")
	assert_false(p.death_delay_used, "the delay is available again after a respawn")
	assert_signal_emitted_with_parameters(sim, "player_respawned", [1])


func test_teammate_touch_revives_with_the_gray_hp_left() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var ally: PlayerState = sim.add_player(2, 0)
	ally.position = Vector2(10.0, 0.0)
	_run(sim, 1, Vector2(1.0, 0.0), 30)
	var gray: float = p.gray_hp
	assert_almost_eq(gray, 42.0, 0.1)
	ally.position = p.position + Vector2(0.9, 0.0)
	watch_signals(sim)
	_tick(sim, 1, Vector2.ZERO)
	assert_false(p.death_delay)
	assert_true(p.alive)
	assert_eq(p.hp, ceili(gray))
	assert_signal_emitted_with_parameters(sim, "player_revived", [1, 2])


func test_walking_into_a_downed_teammate_also_revives() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var ally: PlayerState = sim.add_player(2, 0)
	ally.position = Vector2(4.0, 0.0)
	_run(sim, 2, Vector2(-1.0, 0.0), 60)
	assert_false(p.death_delay)
	assert_eq(p.hp, 50)


func test_only_a_living_teammate_close_enough_revives() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var far_ally: PlayerState = sim.add_player(2, 0)
	far_ally.position = p.position + Vector2(1.5, 0.0)
	var enemy: PlayerState = sim.add_player(3, 1)
	enemy.position = p.position + Vector2(0.5, 0.0)
	var downed_ally: PlayerState = sim.add_player(4, 0)
	downed_ally.position = p.position + Vector2(0.0, 0.5)
	sim.damage(4, 100)
	var dead_ally: PlayerState = sim.add_player(5, 0)
	dead_ally.position = p.position + Vector2(0.0, -0.5)
	sim.kill(5)
	sim.step(DT)
	assert_true(p.death_delay, "far ally, enemy, downed ally and dead ally cannot revive")


func test_touching_the_own_base_post_revives_without_help() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 22.0)
	sim.damage(1, 100)
	watch_signals(sim)
	_run(sim, 1, Vector2(0.0, 1.0), 60)
	assert_false(p.death_delay)
	assert_true(p.alive)
	assert_gt(p.hp, 40)
	assert_lt(p.hp, 51)
	assert_signal_emitted_with_parameters(sim, "player_revived", [1, MatchSim.REVIVED_BY_POST])


func test_the_other_teams_post_does_not_revive_but_their_own_does() -> void:
	var sim: MatchSim = _sim()
	var blue: PlayerState = sim.add_player(1, 0)
	blue.position = Vector2(0.0, -24.0)
	sim.damage(1, 100)
	_run(sim, 1, Vector2(0.0, -1.0), 10)
	assert_true(blue.death_delay, "the enemy post (z = -26) does not revive team 0")
	var red: PlayerState = sim.add_player(2, 1)
	red.position = Vector2(0.0, -23.0)
	sim.damage(2, 100)
	_run(sim, 2, Vector2(0.0, -1.0), 30)
	assert_false(red.death_delay, "team 1 revives at its own post")


func test_revived_players_can_use_skills_again() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var ally: PlayerState = sim.add_player(2, 0)
	ally.position = p.position + Vector2(0.5, 0.0)
	sim.step(DT)
	assert_false(p.death_delay)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	assert_gt(p.dash_time_left, 0.0)


func test_the_delay_triggers_only_once_per_respawn() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	var ally: PlayerState = sim.add_player(2, 0)
	ally.position = p.position + Vector2(0.5, 0.0)
	sim.step(DT)
	assert_eq(p.hp, 50)
	watch_signals(sim)
	sim.damage(1, 100)
	assert_false(p.alive, "second zero-HP is a real death")
	assert_signal_emitted_with_parameters(sim, "player_died", [1])
	assert_signal_not_emitted(sim, "player_death_delay_started")
	_run(sim, 1, Vector2.ZERO, 305)
	assert_true(p.alive)
	sim.damage(1, 100)
	assert_true(p.death_delay, "available again after the respawn")


func test_kill_during_the_delay_is_a_real_death() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	sim.kill(1)
	assert_false(p.alive)
	assert_false(p.death_delay)


func test_enemies_cannot_damage_a_player_in_the_delay_by_default() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = _downed(sim)
	sim.damage(1, 40)
	assert_true(p.death_delay)
	assert_eq(p.gray_hp, 50.0)


func test_damage_in_the_delay_is_a_data_toggle() -> void:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.death_delay_takes_damage = true
	var sim: MatchSim = MatchSim.new(rules, LAYOUT, 5)
	var p: PlayerState = sim.add_player(1, 0)
	p.position = MID
	sim.damage(1, 100)
	sim.damage(1, 20)
	assert_eq(p.gray_hp, 30.0)
	sim.damage(1, 30)
	assert_false(p.alive)


func test_the_delay_can_be_switched_off_by_data() -> void:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.death_delay_enabled = false
	var sim: MatchSim = MatchSim.new(rules, LAYOUT, 5)
	var p: PlayerState = sim.add_player(1, 0)
	sim.damage(1, 100)
	assert_false(p.alive)


func test_dummies_die_immediately_and_respawn_in_place() -> void:
	var sim: MatchSim = _sim()
	var spot: Vector2 = Vector2(-4.0, 8.0)
	var dummy: PlayerState = sim.add_dummy(9, 1, spot, DummyBrain.standing())
	watch_signals(sim)
	sim.damage(9, 100)
	assert_false(dummy.alive)
	assert_signal_not_emitted(sim, "player_death_delay_started")
	_run(sim, 9, Vector2.ZERO, 305)
	assert_true(dummy.alive)
	assert_eq(dummy.position, spot)


func test_standing_dummy_does_not_move() -> void:
	var sim: MatchSim = _sim()
	var dummy: PlayerState = sim.add_dummy(9, 1, Vector2(-4.0, 8.0), DummyBrain.standing())
	for i: int in 120:
		sim.step(DT)
	assert_eq(dummy.position, Vector2(-4.0, 8.0))


func test_patrolling_dummy_walks_back_and_forth_within_range_at_half_speed() -> void:
	var sim: MatchSim = _sim()
	var dummy: PlayerState = sim.add_dummy(9, 1, Vector2(4.0, 8.0), DummyBrain.patrolling(4.0, 3.0, 0.5))
	var min_x: float = dummy.position.x
	var max_x: float = dummy.position.x
	for i: int in 30:
		sim.step(DT)
	assert_almost_eq(absf(dummy.position.x - 4.0), RULES.move_speed * 0.5, 0.05, "half speed")
	for i: int in 600:
		sim.step(DT)
		min_x = minf(min_x, dummy.position.x)
		max_x = maxf(max_x, dummy.position.x)
	assert_gt(max_x, 6.8)
	assert_lt(min_x, 1.2)
	assert_lt(max_x, 7.2)
	assert_gt(min_x, 0.8)
	assert_almost_eq(dummy.position.y, 8.0, 0.0001)


func test_dummy_brain_flips_at_both_ends() -> void:
	var brain: DummyBrain = DummyBrain.patrolling(0.0, 3.0, 0.5)
	var state: PlayerState = PlayerState.new()
	state.position = Vector2(3.0, 0.0)
	assert_lt(brain.think(state).move.x, 0.0)
	state.position = Vector2(-3.0, 0.0)
	assert_gt(brain.think(state).move.x, 0.0)


func test_there_is_no_basic_attack_button() -> void:
	var bits: Array[int] = [
		PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2, PlayerInput.BTN_DASH,
		PlayerInput.BTN_BOOKMARK, PlayerInput.BTN_BALL,
	]
	var seen: int = 0
	for bit: int in bits:
		assert_eq(seen & bit, 0, "bit %d reused" % bit)
		seen |= bit
	assert_eq(seen, 31, "only weapons, dash, bookmark and ball exist")
