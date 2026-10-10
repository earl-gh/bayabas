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


## A throw: the button held past the tap time (or dragged), then released.
func _throw(sim: MatchSim, id: int, aim: Vector2) -> void:
	for i: int in 9:
		sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, PlayerInput.BTN_BALL, sim.tick))
		sim.step(DT)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, 0, sim.tick))
	sim.step(DT)


## A tap: pressed and released at once, no drag.
func _tap(sim: MatchSim, id: int) -> void:
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	sim.step(DT)


func test_ball_numbers_come_from_data() -> void:
	assert_eq(RULES.ball_spawn_interval, 15.0)
	assert_eq(RULES.ball_range, 12.0)
	assert_eq(RULES.ball_holder_speed_scale, 0.9)
	assert_eq(RULES.ball_bite_heal_fraction, 0.25)
	assert_eq(RULES.ball_bites, 2)
	assert_eq(RULES.ball_hit_damage_fraction, 0.25)
	assert_eq(RULES.ball_bitten_damage_fraction, 0.125)
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


func test_a_whole_guava_hits_for_a_quarter_of_max_hp_and_despawns() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_dummy(2, 1, Vector2(0.0, -4.0), DummyBrain.standing())
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_eq(enemy.hp, 75)
	assert_false(enemy.effects.has(StatusEffects.Type.KNOCKOUT), "damage only")
	assert_eq(sim.ball.state, S.NONE)
	assert_almost_eq(sim.ball.spawn_timer, 15.0, 0.6, "the timer restarts")


func test_auto_aim_targets_the_nearest_enemy_at_the_press() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_dummy(2, 1, Vector2(5.0, -3.0), DummyBrain.standing())
	_throw(sim, 1, Vector2.ZERO)
	_wait(sim, 0.6)
	assert_eq(enemy.hp, 75)


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
	assert_eq(enemy.hp, 100, "caught, not hit")


func test_pressing_catch_too_early_is_a_hit() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(0.0, -10.0)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(2, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.8)
	assert_eq(enemy.hp, 75)


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
	var other: MatchSim = _holding(Vector2(0.0, 6.0))
	_throw(other, 1, Vector2(0.0, -1.0))
	_wait(other, 1.0)
	assert_eq(other.ball.state, S.GROUND)
	assert_almost_eq(other.ball.position.y, 6.0 - 12.0, 0.3, "12 m")


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


# ---- the guava is bitten and thrown ---------------------------------------------------

func test_walking_over_the_guava_does_not_heal() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = Vector2.ZERO
	me.hp = 30
	sim.ball.spawn_timer = 0.0
	sim.step(DT)
	sim.step(DT)
	assert_true(sim.ball.is_holder(1))
	assert_eq(me.hp, 30, "picking it up is not eating it")


func test_a_tap_bites_a_quarter_then_the_second_bite_eats_it_up() -> void:
	var sim: MatchSim = _holding()
	var me: PlayerState = sim.players[1]
	me.hp = 40
	watch_signals(sim)
	watch_signals(sim.ball)
	_tap(sim, 1)
	assert_eq(me.hp, 65)
	assert_eq(sim.ball.bites, 1)
	assert_true(sim.ball.is_holder(1), "still in hand")
	assert_signal_emitted_with_parameters(sim, "player_healed", [1, 25])
	assert_signal_emitted(sim.ball, "bitten")
	_tap(sim, 1)
	assert_eq(me.hp, 90)
	assert_eq(sim.ball.state, S.NONE, "eaten up")
	assert_signal_emitted(sim.ball, "eaten")
	assert_almost_eq(sim.ball.spawn_timer, 15.0, 0.3, "the next one is on its way")


func test_a_bitten_guava_hits_for_an_eighth() -> void:
	var sim: MatchSim = _holding()
	var enemy: PlayerState = sim.add_dummy(2, 1, Vector2(0.0, -4.0), DummyBrain.standing())
	_tap(sim, 1)
	assert_eq(sim.ball.bites, 1)
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_eq(enemy.hp, 100 - 13, "12.5 rounds to 13")
	assert_eq(sim.ball.state, S.NONE)


func test_dragging_throws_instead_of_biting() -> void:
	var sim: MatchSim = _holding()
	var me: PlayerState = sim.players[1]
	me.hp = 40
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0.0, -1.0), PlayerInput.BTN_BALL, sim.tick))
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0.0, -1.0), 0, sim.tick))
	sim.step(DT)
	assert_eq(sim.ball.state, S.FLYING)
	assert_eq(me.hp, 40, "no bite")


func test_a_long_press_without_a_drag_throws_at_the_auto_aim() -> void:
	var sim: MatchSim = _holding()
	sim.add_dummy(2, 1, Vector2(0.0, -4.0), DummyBrain.standing())
	_throw(sim, 1, Vector2.ZERO)
	assert_eq(sim.ball.state, S.FLYING)


func test_the_bites_survive_a_pass_and_a_drop() -> void:
	var sim: MatchSim = _holding()
	sim.add_dummy(3, 0, Vector2(0.0, -4.0), DummyBrain.standing())
	_tap(sim, 1)
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_true(sim.ball.is_holder(3))
	assert_eq(sim.ball.bites, 1, "still bitten")


func test_the_heal_stops_at_max_hp_and_skips_the_downed() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = Vector2.ZERO
	me.hp = 90
	assert_eq(sim.heal(1, 25), 10, "capped at max")
	assert_eq(sim.heal(1, 10), 0, "already full")
	me.hp = 40
	sim.damage(1, 40)
	assert_true(me.death_delay)
	assert_eq(sim.heal(1, 50), 0, "no healing while down")


func test_catching_or_receiving_the_guava_does_not_heal() -> void:
	var sim: MatchSim = _holding()
	var ally: PlayerState = sim.add_dummy(3, 0, Vector2(0.0, -4.0), DummyBrain.standing())
	ally.hp = 20
	_throw(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 0.5)
	assert_true(sim.ball.is_holder(3))
	assert_eq(ally.hp, 20, "a pass is not a pickup")
