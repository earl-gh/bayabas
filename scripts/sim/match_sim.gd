class_name MatchSim
extends RefCounted
## Authoritative match simulation. Never touches nodes, input devices or
## rendering; the same class runs on the server, in offline practice and in tests.
## Advances only through step(dt) and uses its own seeded RNG (no randf()).

signal player_died(id: int)
signal player_respawned(id: int)

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
	state.spawn_position = _spawn_position(side, slot)
	state.position = state.spawn_position
	state.facing = Vector2(0.0, -side)
	state.hp = rules.player_max_hp
	state.alive = true
	state.radius = rules.player_radius
	players[id] = state
	return state


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


## Applies damage. At 0 HP the player dies and respawns after rules.respawn_time.
func damage(id: int, amount: int) -> void:
	if not players.has(id) or amount <= 0:
		return
	var state: PlayerState = players[id]
	if not state.alive:
		return
	state.hp = maxi(0, state.hp - amount)
	if state.hp == 0:
		_die(state)


func step(dt: float) -> void:
	for id: int in players:
		var state: PlayerState = players[id]
		var input: PlayerInput = _inputs[id] if _inputs.has(id) else null
		if state.alive:
			_step_alive(state, input, dt)
		else:
			_step_dead(state, dt)
	tick += 1


func _step_alive(state: PlayerState, input: PlayerInput, dt: float) -> void:
	state.dash_cooldown_left = maxf(0.0, state.dash_cooldown_left - dt)
	state.bookmark_cooldown_left = maxf(0.0, state.bookmark_cooldown_left - dt)
	_tick_boost(state, dt)
	if input != null and state.can_act():
		if input.is_pressed(PlayerInput.BTN_DASH) and state.dash_cooldown_left <= 0.0:
			_start_dash(state, input)
		elif input.is_pressed(PlayerInput.BTN_BOOKMARK) and state.bookmark_cooldown_left <= 0.0:
			_use_bookmark(state)
	_move(state, input, dt)


func _step_dead(state: PlayerState, dt: float) -> void:
	state.respawn_time_left -= dt
	if state.respawn_time_left <= 0.0:
		state.position = state.spawn_position
		state.facing = Vector2(0.0, -side_for_team(state.team))
		state.hp = rules.player_max_hp
		state.alive = true
		_clear_actions(state)
		player_respawned.emit(state.id)


func _die(state: PlayerState) -> void:
	state.alive = false
	state.respawn_time_left = rules.respawn_time
	_clear_actions(state)
	player_died.emit(state.id)


## Dash, stumble and bookmark effects end on death/respawn. Cooldowns keep running.
func _clear_actions(state: PlayerState) -> void:
	state.dash_time_left = 0.0
	state.stumble_time_left = 0.0
	state.boost_time_left = 0.0
	state.mark_active = false


func _start_dash(state: PlayerState, input: PlayerInput) -> void:
	var direction: Vector2 = state.facing
	if input.move.length_squared() > 0.0:
		direction = input.move.normalized()
	state.dash_direction = direction
	state.facing = direction
	state.dash_time_left = rules.dash_duration
	state.dash_cooldown_left = rules.dash_cooldown


func _use_bookmark(state: PlayerState) -> void:
	state.mark_position = state.position
	state.mark_active = true
	state.boost_time_left = rules.bookmark_boost_duration
	state.bookmark_cooldown_left = rules.bookmark_cooldown
	_move_by(state, state.facing * rules.bookmark_blink)


func _tick_boost(state: PlayerState, dt: float) -> void:
	if state.boost_time_left <= 0.0:
		return
	state.boost_time_left -= dt
	if state.boost_time_left <= 0.0:
		state.boost_time_left = 0.0
		if state.mark_active and rules.bookmark_returns:
			state.position = state.mark_position
		state.mark_active = false


func _move(state: PlayerState, input: PlayerInput, dt: float) -> void:
	if state.dash_time_left > 0.0:
		var active: float = minf(dt, state.dash_time_left)
		_move_by(state, state.dash_direction * (rules.dash_distance / rules.dash_duration) * active)
		state.dash_time_left -= dt
		if state.dash_time_left <= 0.0:
			state.dash_time_left = 0.0
			state.stumble_time_left = rules.dash_stumble
		return
	if state.stumble_time_left > 0.0:
		state.stumble_time_left = maxf(0.0, state.stumble_time_left - dt)
		return
	if input == null:
		return
	var move: Vector2 = input.move.limit_length(1.0)
	if move.length_squared() > 0.0:
		state.facing = move.normalized()
	var speed: float = rules.move_speed
	if state.boost_time_left > 0.0:
		speed *= 1.0 + rules.bookmark_speed_bonus
	_move_by(state, move * speed * dt)


## Moves by `delta` in sub-steps no longer than the player's radius so fast
## moves (dash, blink) can never tunnel through a wall.
func _move_by(state: PlayerState, delta: Vector2) -> void:
	var length: float = delta.length()
	if length <= 0.0:
		return
	var count: int = maxi(1, ceili(length / state.radius))
	var piece: Vector2 = delta / count
	for i: int in count:
		state.position = Collision.resolve(state.position + piece, state.radius, _blocking_rects())


## Slot 0 at the base post, then alternating +x / -x by spawn_spacing.
func _spawn_position(side: int, slot: int) -> Vector2:
	var base: Vector2 = layout.base_center(side)
	var offset: int = ceili(slot / 2.0)
	var direction: int = 1 if slot % 2 == 1 else -1
	return base + Vector2(direction * offset * rules.spawn_spacing, 0.0)


## Boundary walls plus every wall column that is still standing.
func _blocking_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append_array(_boundaries)
	for wall: MapLayout.WallSpec in walls:
		if wall.hp > 0:
			rects.append(wall.rect)
	return rects
