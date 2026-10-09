class_name MatchSim
extends RefCounted
## Authoritative match simulation. Never touches nodes, input devices or
## rendering; the same class runs on the server, in offline practice and in tests.
## Advances only through step(dt) and uses its own seeded RNG (no randf()).

var rules: GameRules
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## id -> state, in insertion order (stepping order is deterministic).
var players: Dictionary[int, PlayerState] = {}
## Wall columns (from the map layout). A column with hp <= 0 no longer blocks.
var walls: Array[MapLayout.WallSpec] = []

var _inputs: Dictionary[int, PlayerInput] = {}
var _team_counts: Dictionary[int, int] = {}
var _boundaries: Array[Rect2] = []


func _init(p_rules: GameRules, p_layout: MapLayout, seed_value: int) -> void:
	rules = p_rules
	layout = p_layout
	rng.seed = seed_value
	walls = layout.wall_columns()
	_boundaries = layout.boundary_rects()


## Team 0 starts on the own (+Z) base, team 1 on the enemy (-Z) base.
## Sides swap each set later (M3), so this is only the initial assignment.
func side_for_team(team: int) -> int:
	return MapLayout.SIDE_OWN if team == 0 else MapLayout.SIDE_ENEMY


func add_player(id: int, team: int) -> PlayerState:
	var slot: int = 0
	if _team_counts.has(team):
		slot = _team_counts[team]
	_team_counts[team] = slot + 1
	var side: int = side_for_team(team)
	var state: PlayerState = PlayerState.new()
	state.id = id
	state.team = team
	state.position = _spawn_position(side, slot)
	state.facing = Vector2(0.0, -side)
	state.hp = rules.player_max_hp
	state.alive = true
	state.radius = rules.player_radius
	players[id] = state
	return state


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


func step(dt: float) -> void:
	for id: int in players:
		var state: PlayerState = players[id]
		if not state.alive or not _inputs.has(id):
			continue
		var move: Vector2 = _inputs[id].move.limit_length(1.0)
		if move.length_squared() > 0.0:
			state.facing = move.normalized()
		state.position += move * rules.move_speed * dt
		state.position = Collision.resolve(state.position, state.radius, _blocking_rects())
	tick += 1


## Slot 0 at the base post, then alternating +x / -x by spawn_spacing.
func _spawn_position(side: int, slot: int) -> Vector2:
	var base: Vector2 = layout.base_center(side)
	var offset: int = ceili(slot / 2.0)
	var direction: int = 1 if slot % 2 == 1 else -1
	return base + Vector2(direction * offset * rules.spawn_spacing, 0.0)


## Boundary walls plus every wall column that is still standing.
func _blocking_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = _boundaries.duplicate()
	for wall: MapLayout.WallSpec in walls:
		if wall.hp > 0:
			rects.append(wall.rect)
	return rects
