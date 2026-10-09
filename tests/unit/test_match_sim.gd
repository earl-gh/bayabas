extends GutTest

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim(seed_value: int = 1234) -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, seed_value)


func _run(sim: MatchSim, id: int, move: Vector2, ticks: int) -> void:
	for i: int in ticks:
		sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, 0, sim.tick))
		sim.step(DT)


func test_rules_match_gdd_core_numbers() -> void:
	assert_eq(RULES.tick_rate, 30)
	assert_almost_eq(RULES.tick_dt(), DT, 0.00001)
	assert_eq(RULES.player_max_hp, 100)
	assert_eq(RULES.move_speed, 5.0)
	assert_eq(RULES.respawn_time, 10.0)


func test_players_spawn_at_their_own_base_with_full_hp() -> void:
	var sim: MatchSim = _sim()
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 1)
	assert_eq(a.position, LAYOUT.base_center(MapLayout.SIDE_OWN))
	assert_eq(b.position, LAYOUT.base_center(MapLayout.SIDE_ENEMY))
	assert_eq(a.hp, 100)
	assert_true(a.alive)
	assert_eq(a.radius, 0.4)


func test_teammates_spawn_side_by_side() -> void:
	var sim: MatchSim = _sim()
	var first: PlayerState = sim.add_player(1, 0)
	var second: PlayerState = sim.add_player(2, 0)
	var third: PlayerState = sim.add_player(3, 0)
	assert_eq(first.position.y, second.position.y)
	var xs: Array[float] = [first.position.x, second.position.x, third.position.x]
	assert_eq(xs.size(), 3)
	assert_ne(second.position.x, first.position.x)
	assert_ne(third.position.x, second.position.x)
	assert_ne(third.position.x, first.position.x)


func test_full_stick_moves_at_move_speed() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_run(sim, 1, Vector2(0.0, -1.0), 30)
	assert_almost_eq(p.position.y, start.y - 5.0, 0.01)
	assert_almost_eq(p.position.x, start.x, 0.0001)


func test_diagonal_is_not_faster() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, -1.0), 30)
	assert_almost_eq(p.position.distance_to(start), 5.0, 0.01)


func test_half_stick_moves_half_speed() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_run(sim, 1, Vector2(0.0, -0.5), 30)
	assert_almost_eq(p.position.distance_to(start), 2.5, 0.01)


func test_no_input_means_no_movement() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 0))
	sim.step(DT)
	assert_eq(p.position, start)


func test_dead_players_do_not_move() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	sim.damage(1, 100)
	assert_false(p.alive)
	var start: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 10)
	assert_eq(p.position, start)


func test_tick_counts_steps() -> void:
	var sim: MatchSim = _sim()
	assert_eq(sim.tick, 0)
	for i: int in 7:
		sim.step(DT)
	assert_eq(sim.tick, 7)


func test_facing_follows_last_move_direction() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	assert_eq(p.facing, Vector2(0.0, -1.0), "own team faces the enemy")
	_run(sim, 1, Vector2(2.0, 0.0), 1)
	assert_eq(p.facing, Vector2(1.0, 0.0))
	_run(sim, 1, Vector2.ZERO, 1)
	assert_eq(p.facing, Vector2(1.0, 0.0), "no input keeps the facing")


func test_same_seed_and_inputs_give_identical_results() -> void:
	var a: MatchSim = _sim(99)
	var b: MatchSim = _sim(99)
	for sim: MatchSim in [a, b]:
		sim.add_player(1, 0)
		sim.add_player(2, 1)
		_run(sim, 1, Vector2(0.3, -0.9), 45)
		_run(sim, 2, Vector2(-0.5, 0.5), 45)
	assert_eq(a.players[1].position, b.players[1].position)
	assert_eq(a.players[2].position, b.players[2].position)
	assert_eq(a.rng.randi(), b.rng.randi())


func test_rng_is_seeded_and_differs_between_seeds() -> void:
	var a: MatchSim = _sim(1)
	var b: MatchSim = _sim(2)
	var seq_a: Array[int] = [a.rng.randi(), a.rng.randi(), a.rng.randi()]
	var seq_b: Array[int] = [b.rng.randi(), b.rng.randi(), b.rng.randi()]
	assert_ne(seq_a, seq_b)
	var again: MatchSim = _sim(1)
	var seq_again: Array[int] = [again.rng.randi(), again.rng.randi(), again.rng.randi()]
	assert_eq(seq_a, seq_again)


func test_player_input_button_bits() -> void:
	var input: PlayerInput = PlayerInput.create(
		Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_DASH | PlayerInput.BTN_BALL, 3
	)
	assert_true(input.is_pressed(PlayerInput.BTN_DASH))
	assert_true(input.is_pressed(PlayerInput.BTN_BALL))
	assert_false(input.is_pressed(PlayerInput.BTN_WEAPON_1))
	assert_false(input.is_pressed(PlayerInput.BTN_BOOKMARK))
	assert_eq(input.tick, 3)
