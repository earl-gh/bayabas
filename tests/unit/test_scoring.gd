extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 3)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


## Puts `player` on the enemy base post and waits for the point.
func _score(sim: MatchSim, player: PlayerState) -> void:
	player.position = LAYOUT.spawn_center(-sim.side_for_team(player.team))
	_wait(sim, RULES.base_capture_time + 0.1)


func _finish_freeze(sim: MatchSim) -> void:
	_wait(sim, RULES.point_freeze_time + 0.1)


# ---- MatchScore --------------------------------------------------------------

func test_scoring_numbers_come_from_data() -> void:
	assert_eq(RULES.base_capture_time, 2.0)
	assert_eq(RULES.point_freeze_time, 3.0)
	assert_eq(RULES.set_points_to_win, 5)
	assert_eq(RULES.set_win_by, 2)
	assert_eq(RULES.set_point_cap, 7)
	assert_eq(RULES.match_sets_to_win, 2)


func test_first_to_five_wins_the_set() -> void:
	var score: MatchScore = MatchScore.new(RULES)
	for i: int in 4:
		assert_eq(score.award_point(0), MatchScore.Result.POINT)
	assert_eq(score.award_point(0), MatchScore.Result.SET)
	assert_eq(score.sets, [1, 0] as Array[int])
	assert_eq(score.points, [0, 0] as Array[int])
	assert_eq(score.set_number, 2)


func test_win_by_two_until_the_cap_of_seven() -> void:
	var score: MatchScore = MatchScore.new(RULES)
	for i: int in 4:
		score.award_point(0)
		score.award_point(1)
	assert_eq(score.award_point(0), MatchScore.Result.POINT, "5-4 is not enough")
	assert_eq(score.award_point(1), MatchScore.Result.POINT, "5-5")
	assert_eq(score.award_point(1), MatchScore.Result.POINT, "5-6")
	assert_eq(score.award_point(0), MatchScore.Result.POINT, "6-6")
	assert_eq(score.award_point(1), MatchScore.Result.SET, "7 wins at the cap even 6-7")
	assert_eq(score.sets, [0, 1] as Array[int])


func test_best_of_three_sets() -> void:
	var score: MatchScore = MatchScore.new(RULES)
	for i: int in 5:
		score.award_point(1)
	for i: int in 5:
		score.award_point(0)
	for i: int in 4:
		score.award_point(0)
	assert_eq(score.award_point(0), MatchScore.Result.MATCH)
	assert_eq(score.winner, 0)
	assert_eq(score.sets, [2, 1] as Array[int])
	assert_eq(score.points, [5, 0] as Array[int], "the last set's points stay for the final screen")


# ---- base capture --------------------------------------------------------------

func test_standing_behind_the_enemy_inner_wall_for_two_seconds_scores() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	me.position = LAYOUT.spawn_center(MapLayout.SIDE_ENEMY) + Vector2(1.5, 0.0)
	_wait(sim, RULES.base_capture_time - 0.2)
	assert_eq(sim.score.points[0], 0, "not yet")
	_wait(sim, 0.4)
	assert_eq(sim.score.points[0], 1)
	assert_signal_emitted_with_parameters(sim, "point_scored", [0, 1])
	assert_eq(sim.phase, MatchSim.Phase.POINT_FREEZE)


func test_stepping_out_resets_the_capture_timer() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var base: Vector2 = LAYOUT.spawn_center(MapLayout.SIDE_ENEMY)
	me.position = base
	_wait(sim, RULES.base_capture_time - 0.5)
	me.position = base + Vector2(0.0, 10.0)
	sim.step(DT)
	me.position = base
	_wait(sim, RULES.base_capture_time - 0.5)
	assert_eq(sim.score.points[0], 0)


func test_own_base_does_not_score() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(1, 0)
	_wait(sim, 2.0)
	assert_eq(sim.score.points, [0, 0] as Array[int])


func test_cc_or_death_delay_in_the_base_does_not_score() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = LAYOUT.spawn_center(MapLayout.SIDE_ENEMY)
	sim.apply_effect(1, StatusEffects.Type.STUN, RULES.base_capture_time + 1.0, 0.0)
	_wait(sim, RULES.base_capture_time + 0.3)
	assert_eq(sim.score.points[0], 0, "stunned")
	sim.damage(1, 100)
	assert_true(me.death_delay)
	_wait(sim, RULES.base_capture_time + 0.3)
	assert_eq(sim.score.points[0], 0, "down")


# ---- freeze and reset ----------------------------------------------------------

func test_freeze_then_everyone_is_reset_at_full_hp_with_cooldowns_cleared() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var them: PlayerState = sim.add_player(2, 1)
	sim.set_loadout(1, &"bato_light", &"lata")
	me.weapon_cooldowns = [3.0, 9.0] as Array[float]
	me.dash_cooldown_left = 5.0
	them.hp = 40
	sim.apply_effect(2, StatusEffects.Type.SLOW, 10.0, 0.4)
	sim.kill(2)
	_score(sim, me)
	var frozen_at: Vector2 = me.position
	_wait(sim, 2.0)
	assert_eq(me.position, frozen_at, "nobody moves in the freeze")
	assert_eq(sim.phase, MatchSim.Phase.POINT_FREEZE)
	watch_signals(sim)
	_wait(sim, 1.2)
	assert_eq(sim.phase, MatchSim.Phase.PLAYING)
	assert_signal_emitted(sim, "point_reset")
	assert_eq(me.position, me.spawn_position)
	assert_eq(them.position, them.spawn_position)
	assert_true(them.alive, "the dead come back too")
	assert_eq(them.hp, 100)
	assert_false(them.effects.has(StatusEffects.Type.SLOW))
	assert_eq(me.weapon_cooldowns, [0.0, 0.0] as Array[float])
	assert_eq(me.dash_cooldown_left, 0.0)


func test_walls_persist_within_a_set() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.damage_wall(7, 1000)
	_score(sim, me)
	_finish_freeze(sim)
	assert_eq(sim.walls[7].hp, 0)


func test_a_new_set_switches_bases_and_rebuilds_the_walls() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var them: PlayerState = sim.add_player(2, 1)
	sim.damage_wall(0, 1000)
	sim.damage_wall(9, 50)
	watch_signals(sim)
	for i: int in 5:
		_score(sim, me)
		_finish_freeze(sim)
	assert_eq(sim.score.sets, [1, 0] as Array[int])
	assert_signal_emitted(sim, "set_won")
	assert_signal_emitted(sim, "sides_switched")
	assert_eq(sim.side_for_team(0), MapLayout.SIDE_ENEMY)
	assert_eq(sim.side_for_team(1), MapLayout.SIDE_OWN)
	assert_lt(me.position.y, 0.0, "team 0 now starts at the -Z base")
	assert_gt(them.position.y, 0.0)
	for wall: MapLayout.WallSpec in sim.walls:
		assert_eq(wall.hp, LAYOUT.wall_hp)
	_score(sim, me)
	assert_eq(sim.score.points[0], 1, "scoring now means reaching the +Z base")


func test_after_the_switch_team_walls_follow_their_new_side() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	for i: int in 5:
		_score(sim, me)
		_finish_freeze(sim)
	var blocking: Array[Rect2] = sim.blocking_rects_for_team(0)
	for wall: MapLayout.WallSpec in sim.walls:
		assert_eq(blocking.has(wall.rect), wall.side == MapLayout.SIDE_OWN, "team 0 is blocked by the +Z walls now")


func test_winning_two_sets_ends_the_match() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	for i: int in 10:
		_score(sim, me)
		_finish_freeze(sim)
	assert_eq(sim.phase, MatchSim.Phase.MATCH_OVER)
	assert_signal_emitted_with_parameters(sim, "match_won", [0])
	var at: Vector2 = me.position
	_wait(sim, 5.0)
	assert_eq(me.position, at, "nothing runs after the match")
