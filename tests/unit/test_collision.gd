extends GutTest

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
const RECT: Rect2 = Rect2(0.0, 0.0, 4.0, 2.0)


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 1)


func _run(sim: MatchSim, id: int, move: Vector2, ticks: int) -> void:
	for i: int in ticks:
		sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, 0, sim.tick))
		sim.step(DT)


func test_push_out_leaves_a_free_circle_alone() -> void:
	assert_eq(Collision.push_out(Vector2(-3.0, 1.0), 0.5, RECT), Vector2(-3.0, 1.0))
	assert_eq(Collision.push_out(Vector2(-0.5, 1.0), 0.5, RECT), Vector2(-0.5, 1.0), "just touching")


func test_push_out_from_a_face() -> void:
	var result: Vector2 = Collision.push_out(Vector2(-0.2, 1.0), 0.5, RECT)
	assert_almost_eq(result.x, -0.5, 0.0001)
	assert_almost_eq(result.y, 1.0, 0.0001)


func test_push_out_from_a_corner_is_diagonal() -> void:
	var result: Vector2 = Collision.push_out(Vector2(-0.1, -0.1), 0.5, RECT)
	assert_almost_eq(result.distance_to(Vector2(0.0, 0.0)), 0.5, 0.0001)
	assert_lt(result.x, 0.0)
	assert_lt(result.y, 0.0)


func test_push_out_when_center_is_inside() -> void:
	# nearest face is the top (z = 0): 0.3 away vs 1.7 / 3.7 / 3.7
	var result: Vector2 = Collision.push_out(Vector2(2.0, 0.3), 0.5, RECT)
	assert_almost_eq(result.x, 2.0, 0.0001)
	assert_almost_eq(result.y, -0.5, 0.0001)


func test_player_stops_at_the_enemy_wall() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 0.0)
	_run(sim, 1, Vector2(0.0, -1.0), 200)
	# enemy layer nearest mid is centered at z = -14, 1 m thick: its near face is z = -13.5
	assert_almost_eq(p.position.y, -13.5 + p.radius, 0.05)


func test_a_team_walks_straight_through_its_own_walls() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_run(sim, 1, Vector2(0.0, -1.0), 110)
	# from the own base at z = 26, through the own layers at z = 19 and z = 14,
	# to the enemy wall's near face at z = -13.5
	assert_almost_eq(p.position.y, -13.5 + p.radius, 0.05)


func test_the_other_team_is_blocked_by_that_teams_walls_and_passes_its_own() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 1)
	_run(sim, 1, Vector2(0.0, 1.0), 110)
	# team 1 passes its own layers (z = -19, -14) and stops at team 0's wall face z = 13.5
	assert_almost_eq(p.position.y, 13.5 - p.radius, 0.05)


func test_player_cannot_leave_the_lane_sideways() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_run(sim, 1, Vector2(1.0, 0.0), 300)
	assert_almost_eq(p.position.x, LAYOUT.lane_width / 2.0 - p.radius, 0.05)
	_run(sim, 1, Vector2(-1.0, 0.0), 600)
	assert_almost_eq(p.position.x, -LAYOUT.lane_width / 2.0 + p.radius, 0.05)


func test_player_cannot_leave_through_the_end_wall() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_run(sim, 1, Vector2(0.0, 1.0), 300)
	assert_almost_eq(p.position.y, LAYOUT.lane_length / 2.0 - p.radius, 0.05)


func test_player_slides_along_an_enemy_wall() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 0.0)
	_run(sim, 1, Vector2(1.0, -1.0), 200)
	assert_almost_eq(p.position.y, -13.5 + p.radius, 0.05, "held back by the wall")
	assert_gt(p.position.x, 1.0, "but slid sideways along it")


func test_gaps_between_enemy_columns_are_too_narrow_to_pass() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	# the gap between the left and center column of the enemy layer nearest mid
	var gap_x: float = -LAYOUT.lane_width / 2.0 + LAYOUT.lane_width / 3.0
	p.position = Vector2(gap_x, -9.0)
	_run(sim, 1, Vector2(0.0, -1.0), 200)
	assert_gt(p.position.y, -14.0, "did not squeeze through")


func test_destroyed_enemy_column_opens_its_slot() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, 0.0)
	# walls are ordered side, layer, column: index 10 = enemy side, layer nearest mid, center
	sim.walls[10].hp = 0
	_run(sim, 1, Vector2(0.0, -1.0), 200)
	# now stopped by the enemy layer behind it (z = -19): near face z = -18.5
	assert_almost_eq(p.position.y, -18.5 + p.radius, 0.05)
