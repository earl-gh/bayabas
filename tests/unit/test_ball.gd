extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
const S := RubberBall.State


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 3)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


## A sim with the ball already spawned and held by player 1 (team 0) at `at`.
func _holding(at: Vector2 = Vector2(0.0, 2.0)) -> MatchSim:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = Vector2.ZERO
	sim.ball.spawn_timer = 0.0
	sim.step(DT)
	sim.step(DT)
	assert_true(sim.ball.is_holder(1))
	me.position = at
	sim.step(DT)
	return sim


func _throw(sim: MatchSim, id: int, aim: Vector2) -> void:
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, 0, sim.tick))
	sim.step(DT)


func test_ball_numbers_come_from_data() -> void:
	assert_eq(RULES.ball_spawn_interval, 15.0)
	assert_eq(RULES.ball_range, 12.0)
	assert_eq(RULES.ball_holder_speed_scale, 0.9)
	assert_eq(RULES.ball_knockout_time, 3.0)
	assert_eq(RULES.ball_wall_damage, 60)
	assert_eq(RULES.ball_catch_window, 0.3)


func test_spawns_at_the_center_after_fifteen_seconds() -> void:
	var sim: MatchSim = _sim()
	_wait(sim, 14.9)
	assert_eq(sim.ball.state, S.NONE)
	_wait(sim, 0.2)
	assert_eq(sim.ball.state, S.GROUND)
	assert_eq(sim.ball.position, Vector2.ZERO)


func test_walk_over_it_to_pick_it_up_and_carry_it_slower() -> void:
	var sim: MatchSim = _holding(Vector2(0.0, 5.0))
	var me: PlayerState = sim.players[1]
	var start: Vector2 = me.position
	for i: int in 30:
		sim.set_input(1, PlayerInput.create(Vector2(1.0, 0.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
	assert_almost_eq(me.position.x - start.x, 4.5, 0.05, "90% speed")
	assert_eq(sim.ball.position, me.position)


func test_hit_enemy_is_knocked_out_and_the_ball_despawns() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_dummy(2, 1, Vector2(0.0, -4.0), DummyBrain.standing())
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_true(enemy.effects.has(StatusEffects.Type.KNOCKOUT))
	assert_false(enemy.can_act())
	assert_eq(sim.ball.state, S.NONE)
	assert_almost_eq(sim.ball.spawn_timer, 15.0, 0.6, "the timer restarts")


func test_auto_aim_targets_the_nearest_enemy_at_the_press() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_dummy(2, 1, Vector2(5.0, -3.0), DummyBrain.standing())
	_throw(sim, 1, Vector2.ZERO)
	_wait(sim, 0.6)
	assert_true(enemy.effects.has(StatusEffects.Type.KNOCKOUT))


func test_an_enemy_pressing_catch_just_before_contact_catches_it() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(0.0, -4.0)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0.0, -1.0), PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0.0, -1.0), 0, sim.tick))
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	sim.step(DT)
	# the ball needs about 0.3 s to fly the ~5.6 m; press catch 0.1 s in
	_wait(sim, 0.1)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	_wait(sim, 0.4)
	assert_true(sim.ball.is_holder(2), "caught")
	assert_false(enemy.effects.has(StatusEffects.Type.KNOCKOUT))


func test_pressing_catch_too_early_is_a_knockout() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(0.0, -10.0)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.8)
	assert_true(enemy.effects.has(StatusEffects.Type.KNOCKOUT))


func test_hitting_an_ally_passes_the_ball() -> void:
	var sim: MatchSim = _holding()
	sim.add_dummy(3, 0, Vector2(0.0, -4.0), DummyBrain.standing())
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_true(sim.ball.is_holder(3))


func test_an_enemy_wall_takes_60_and_the_ball_despawns() -> void:
	var sim: MatchSim = _holding(Vector2(0.0, -12.0))
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	var hit: Array[int] = []
	for index: int in sim.walls.size():
		if sim.walls[index].hp < LAYOUT.wall_hp:
			hit.append(index)
			assert_eq(sim.walls[index].hp, 240)
	assert_eq(hit.size(), 1)
	assert_eq(sim.ball.state, S.NONE)


func test_lane_edge_or_max_range_drops_it_on_the_ground() -> void:
	var sim: MatchSim = _holding(Vector2(0.0, 2.0))
	_throw(sim, 1, Vector2(1.0, 0.0))
	_wait(sim, 1.0)
	assert_eq(sim.ball.state, S.GROUND)
	assert_lt(sim.ball.position.x, LAYOUT.lane_width / 2.0)
	var other: MatchSim = _holding(Vector2(0.0, 2.0))
	_throw(other, 1, Vector2(0.0, -1.0))
	_wait(other, 1.0)
	assert_eq(other.ball.state, S.GROUND)
	assert_almost_eq(other.ball.position.y, 2.0 - 12.0, 0.3, "12 m")


func test_the_thrower_can_blink_to_the_flying_ball_once() -> void:
	var sim: MatchSim = _holding(Vector2(0.0, 2.0))
	var me: PlayerState = sim.players[1]
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.2)
	var ball_at: Vector2 = sim.ball.position
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	assert_almost_eq(me.position.y, ball_at.y, 1.0, "jumped to the ball")
	assert_false(sim.ball.can_blink)


func test_an_enemy_cannot_blink_to_your_throw() -> void:
	var sim: MatchSim = _holding(Vector2(0.0, 2.0))
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(5.0, -10.0)
	var start: Vector2 = enemy.position
	_throw(sim, 1, Vector2(0.0, -1.0))
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	assert_eq(enemy.position, start)


func test_going_down_drops_the_ball() -> void:
	var sim: MatchSim = _holding()
	sim.damage(1, 100)
	sim.step(DT)
	assert_eq(sim.ball.state, S.GROUND)


func test_a_point_removes_the_ball() -> void:
	var sim: MatchSim = _holding()
	var me: PlayerState = sim.players[1]
	me.position = LAYOUT.base_center(MapLayout.SIDE_ENEMY)
	_wait(sim, 4.0)
	assert_eq(sim.ball.state, S.NONE)
