extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 3)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func _cast(sim: MatchSim, id: int, aim: Vector2) -> void:
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, PlayerInput.BTN_WEAPON_1, sim.tick))
	sim.step(DT)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, 0, sim.tick))
	sim.step(DT)


## The enemy-side (-Z) wall column straight ahead of x = 0 on the outer layer.
func _enemy_center_wall(sim: MatchSim) -> int:
	for index: int in sim.walls.size():
		var wall: MapLayout.WallSpec = sim.walls[index]
		if wall.side == MapLayout.SIDE_ENEMY and wall.layer == 1 and wall.column == 1:
			return index
	return -1


func test_wall_columns_have_150_hp_and_break_at_zero() -> void:
	var sim: MatchSim = _sim()
	var index: int = _enemy_center_wall(sim)
	assert_eq(sim.walls[index].hp, 150)
	watch_signals(sim)
	sim.damage_wall(index, 149)
	assert_signal_emitted(sim, "wall_damaged")
	assert_signal_not_emitted(sim, "wall_destroyed")
	sim.damage_wall(index, 5)
	assert_eq(sim.walls[index].hp, 0)
	assert_signal_emitted_with_parameters(sim, "wall_destroyed", [index])


func test_a_broken_column_opens_the_path() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var index: int = _enemy_center_wall(sim)
	var wall_z: float = sim.walls[index].rect.get_center().y
	me.position = Vector2(0.0, wall_z + 2.0)
	for i: int in 30:
		sim.set_input(1, PlayerInput.create(Vector2(0.0, -1.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
	assert_gt(me.position.y, wall_z, "blocked by the standing wall")
	sim.damage_wall(index, 300)
	for i: int in 30:
		sim.set_input(1, PlayerInput.create(Vector2(0.0, -1.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
	assert_lt(me.position.y, wall_z - 1.0, "walks through the gap")


func test_projectiles_damage_the_enemy_wall_they_hit() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.set_loadout(1, &"trumpo", &"papel_shield")
	var index: int = _enemy_center_wall(sim)
	me.position = Vector2(0.0, sim.walls[index].rect.end.y + 3.0)
	_cast(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 1.5)
	assert_eq(sim.walls[index].hp, LAYOUT.wall_hp - 10, "trumpo deals its 10 to the wall")


func test_area_attacks_damage_walls_in_the_circle() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.set_loadout(1, &"bato_heavy", &"papel_shield")
	var index: int = _enemy_center_wall(sim)
	var wall_z: float = sim.walls[index].rect.get_center().y
	me.position = Vector2(0.0, wall_z + 6.0)
	_cast(sim, 1, Vector2(0.0, -6.0) / 8.0)
	_wait(sim, 1.0)
	assert_eq(sim.walls[index].hp, LAYOUT.wall_hp - 22)


func test_cones_damage_walls_in_front() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.set_loadout(1, &"gunting_heavy", &"papel_shield")
	var index: int = _enemy_center_wall(sim)
	me.position = Vector2(0.0, sim.walls[index].rect.end.y + 1.5)
	_cast(sim, 1, Vector2(0.0, -1.0))
	_wait(sim, 1.0)
	assert_eq(sim.walls[index].hp, LAYOUT.wall_hp - 24)


func test_own_walls_never_take_damage_from_own_weapons() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.set_loadout(1, &"bato_heavy", &"papel_shield")
	me.position = Vector2(0.0, 17.0)
	_cast(sim, 1, Vector2(0.0, -1.0) * 0.25)
	_wait(sim, 1.0)
	for wall: MapLayout.WallSpec in sim.walls:
		assert_eq(wall.hp, 150)
