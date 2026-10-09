extends GutTest

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 7)


## One tick with the given stick and buttons.
func _tick(sim: MatchSim, id: int, move: Vector2, buttons: int) -> void:
	sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, buttons, sim.tick))
	sim.step(DT)


func _run(sim: MatchSim, id: int, move: Vector2, ticks: int) -> void:
	for i: int in ticks:
		_tick(sim, id, move, 0)


func test_skill_numbers_come_from_data() -> void:
	assert_eq(RULES.dash_distance, 5.0)
	assert_eq(RULES.dash_duration, 0.2)
	assert_eq(RULES.dash_stumble, 0.4)
	assert_eq(RULES.dash_cooldown, 8.0)
	assert_eq(RULES.bookmark_blink, 4.0)
	assert_eq(RULES.bookmark_speed_bonus, 0.3)
	assert_eq(RULES.bookmark_boost_duration, 4.0)
	assert_eq(RULES.bookmark_cooldown, 14.0)


# ---- HP, death, respawn ----

func test_damage_reduces_hp() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	sim.damage(1, 30)
	assert_eq(p.hp, 70)
	assert_true(p.alive)


func test_overkill_clamps_to_zero_and_starts_the_death_delay() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	sim.damage(1, 500)
	assert_eq(p.hp, 0)
	assert_true(p.alive, "still on their feet during the death delay")
	assert_true(p.death_delay)
	assert_signal_emitted_with_parameters(sim, "player_death_delay_started", [1])
	assert_signal_not_emitted(sim, "player_died")


func test_kill_is_immediate_death() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	sim.kill(1)
	assert_false(p.alive)
	assert_false(p.death_delay)
	assert_signal_emitted_with_parameters(sim, "player_died", [1])


func test_damage_to_a_dead_or_unknown_player_is_ignored() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	sim.kill(1)
	watch_signals(sim)
	sim.damage(1, 10)
	sim.damage(99, 10)
	sim.damage(1, 0)
	assert_signal_not_emitted(sim, "player_died")
	assert_signal_not_emitted(sim, "player_death_delay_started")
	assert_eq(p.hp, 0)


func test_respawn_after_ten_seconds_at_own_base_with_full_hp() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_run(sim, 1, Vector2(1.0, 0.0), 5)
	sim.kill(1)
	watch_signals(sim)
	_run(sim, 1, Vector2.ZERO, 295)
	assert_false(p.alive, "still down just before 10 s")
	_run(sim, 1, Vector2.ZERO, 6)
	assert_true(p.alive)
	assert_eq(p.hp, 100)
	assert_eq(p.position, p.spawn_position)
	assert_signal_emitted_with_parameters(sim, "player_respawned", [1])


func test_other_team_respawns_at_its_own_base() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(2, 1)
	sim.kill(2)
	_run(sim, 2, Vector2.ZERO, 305)
	assert_true(p.alive)
	assert_eq(p.position, LAYOUT.base_center(MapLayout.SIDE_ENEMY))


func test_death_cancels_dash_and_bookmark_effects() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_BOOKMARK)
	assert_true(p.mark_active)
	sim.damage(1, 100)
	assert_false(p.mark_active)
	assert_eq(p.boost_time_left, 0.0)
	assert_eq(p.dash_time_left, 0.0)


# ---- Takbo (dash) ----

func test_dash_travels_five_meters_in_the_stick_direction() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 5)
	assert_almost_eq(p.position.y, start.y - 5.0, 0.05)
	assert_almost_eq(p.position.x, start.x, 0.001)


func test_dash_without_stick_goes_where_the_player_faces() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2.ZERO, 5)
	assert_almost_eq(p.position.y, start.y - 5.0, 0.05)


func test_stumble_after_dash_blocks_movement_then_it_recovers() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 6)
	var after_dash: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 10)
	assert_eq(p.position, after_dash, "can't move while stumbling")
	_run(sim, 1, Vector2(1.0, 0.0), 10)
	assert_gt(p.position.x, after_dash.x, "moving again after the stumble")


func test_cannot_use_skills_while_stumbling() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 7)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_BOOKMARK)
	assert_false(p.mark_active)


func test_dash_cooldown_is_eight_seconds() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(1.0, 0.0), PlayerInput.BTN_DASH)
	assert_almost_eq(p.dash_cooldown_left, 8.0, 0.001)
	_run(sim, 1, Vector2.ZERO, 60)
	_tick(sim, 1, Vector2(-1.0, 0.0), PlayerInput.BTN_DASH)
	assert_eq(p.dash_time_left, 0.0, "still on cooldown at 2 s")
	_run(sim, 1, Vector2.ZERO, 200)
	_tick(sim, 1, Vector2(-1.0, 0.0), PlayerInput.BTN_DASH)
	assert_gt(p.dash_time_left, 0.0, "ready again after 8 s")


func test_dash_stops_at_walls() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 21.0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 8)
	assert_almost_eq(p.position.y, 19.5 + p.radius, 0.05)


# ---- Bookmark ----

func test_bookmark_blinks_four_meters_and_leaves_a_mark() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	assert_almost_eq(p.position.y, start.y - 4.0, 0.01)
	assert_true(p.mark_active)
	assert_eq(p.mark_position, start)
	assert_almost_eq(p.bookmark_cooldown_left, 14.0, 0.001)


func test_bookmark_speed_bonus_is_thirty_percent() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	var before: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 30)
	assert_almost_eq(p.position.x - before.x, 5.0 * 1.3, 0.05)


func test_bookmark_returns_to_the_mark_after_four_seconds() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	_run(sim, 1, Vector2.ZERO, 110)
	assert_true(p.mark_active, "boost still running at ~3.7 s")
	_run(sim, 1, Vector2.ZERO, 15)
	assert_false(p.mark_active)
	assert_eq(p.position, start)


func test_bookmark_return_is_a_data_toggle() -> void:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.bookmark_returns = false
	var sim: MatchSim = MatchSim.new(rules, LAYOUT, 7)
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	_run(sim, 1, Vector2.ZERO, 130)
	assert_almost_eq(p.position.y, start.y - 4.0, 0.01, "stays where it blinked")


func test_bookmark_cooldown_is_fourteen_seconds() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	_run(sim, 1, Vector2.ZERO, 200)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	assert_false(p.mark_active, "still on cooldown at ~6.7 s")
	_run(sim, 1, Vector2.ZERO, 250)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	assert_true(p.mark_active, "ready after 14 s")


func test_bookmark_blink_stops_at_walls() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 21.0)
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_BOOKMARK)
	assert_almost_eq(p.position.y, 19.5 + p.radius, 0.05)
