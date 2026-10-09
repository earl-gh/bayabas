extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func _assigned(seed_value: int, count: int) -> Array[StringName]:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, seed_value)
	for id: int in count:
		sim.add_player(id + 1, id % 2)
	sim.assign_characters()
	var result: Array[StringName] = []
	for id: int in sim.players:
		result.append(sim.players[id].character_id)
	return result


func test_roster_has_the_six_characters() -> void:
	var ids: Array[StringName] = []
	for i: int in RULES.characters.size():
		var character: CharacterDef = RULES.characters[i]
		ids.append(character.id)
		assert_ne(character.display_name, "")
	assert_eq(ids, [&"junjun", &"ligaya", &"migo", &"toni", &"popoy", &"inday"] as Array[StringName])


func test_six_players_get_six_different_characters() -> void:
	var ids: Array[StringName] = _assigned(1, 6)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			assert_ne(ids[i], ids[j])


func test_fewer_players_never_share_a_character() -> void:
	for seed_value: int in 20:
		var ids: Array[StringName] = _assigned(seed_value, 4)
		assert_eq(ids.size(), 4)
		for i: int in ids.size():
			for j: int in range(i + 1, ids.size()):
				assert_ne(ids[i], ids[j])


func test_assignment_is_seeded() -> void:
	assert_eq(_assigned(42, 6), _assigned(42, 6))
	var differs: bool = false
	for seed_value: int in range(1, 10):
		if _assigned(seed_value, 6) != _assigned(42, 6):
			differs = true
	assert_true(differs, "different seeds shuffle differently")


func test_characters_never_change_gameplay_numbers() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 3)
	for id: int in 6:
		sim.add_player(id + 1, 0)
	sim.assign_characters()
	for id: int in sim.players:
		var state: PlayerState = sim.players[id]
		assert_eq(state.hp, RULES.player_max_hp)
		assert_eq(state.radius, RULES.player_radius)
