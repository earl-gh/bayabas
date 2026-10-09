extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
const P := Tricycle.Phase


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 3)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func test_tricycle_numbers_come_from_data() -> void:
	assert_eq(RULES.tricycle_first_time, 120.0)
	assert_eq(RULES.tricycle_interval, 120.0)
	assert_eq(RULES.tricycle_warning_time, 2.0)
	assert_eq(RULES.tricycle_crossing_time, 3.0)
	assert_eq(RULES.tricycle_knockback, 8.0)


func test_warning_at_118_s_then_crossing_at_120_s_for_3_s() -> void:
	var sim: MatchSim = _sim()
	watch_signals(sim.tricycle)
	_wait(sim, 117.9)
	assert_eq(sim.tricycle.phase, P.WAITING)
	_wait(sim, 0.2)
	assert_eq(sim.tricycle.phase, P.WARNING)
	assert_signal_emitted(sim.tricycle, "warning_started")
	_wait(sim, 2.0)
	assert_eq(sim.tricycle.phase, P.CROSSING)
	_wait(sim, 3.0)
	assert_eq(sim.tricycle.phase, P.WAITING)
	assert_signal_emitted(sim.tricycle, "crossing_ended")
	assert_almost_eq(sim.tricycle.time_to_arrival(RULES), 120.0, 0.2, "next one in 120 s")


func test_it_drives_all_the_way_across_the_midline() -> void:
	var sim: MatchSim = _sim()
	sim.tricycle.call_now()
	_wait(sim, RULES.tricycle_warning_time + 0.05)
	var start_x: float = sim.tricycle.position.x
	assert_gt(absf(start_x), LAYOUT.lane_width / 2.0, "starts outside the lane")
	assert_eq(sim.tricycle.position.y, 0.0)
	_wait(sim, 2.9)
	assert_eq(signf(sim.tricycle.position.x), -signf(start_x), "ends on the other side")
	assert_gt(absf(sim.tricycle.position.x), LAYOUT.lane_width / 2.0, "and out of the lane")


func test_contact_pushes_8_m_away_from_its_path_without_damage() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = Vector2(0.0, 0.5)
	sim.tricycle.call_now()
	_wait(sim, RULES.tricycle_warning_time + RULES.tricycle_crossing_time + 0.5)
	assert_almost_eq(me.position.y, 8.5, 0.1, "pushed toward +Z, away from the midline")
	assert_almost_eq(me.position.x, 0.0, 0.001, "straight away from the path")
	assert_eq(me.hp, 100)


func test_pushed_once_per_crossing_and_walls_still_stop_the_push() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var wall_side: PlayerState = sim.add_player(2, 1)
	me.position = Vector2(-1.0, -0.4)
	wall_side.position = Vector2(1.0, 0.6)
	watch_signals(sim.tricycle)
	sim.tricycle.call_now()
	_wait(sim, RULES.tricycle_warning_time + RULES.tricycle_crossing_time + 0.5)
	assert_signal_emit_count(sim.tricycle, "pushed", 2)
	assert_almost_eq(me.position.y, -8.4, 0.1)
	# team 1 is blocked by the +Z walls (first one at z = 14 - 5 = 9 .. layer at 14)
	assert_lt(wall_side.position.y, 8.7, "8 m would pass z = 8.5; the push stops at the enemy wall")
