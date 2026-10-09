class_name MatchSim
extends RefCounted
## Authoritative match simulation. Never touches nodes, input devices or
## rendering; the same class runs on the server, in offline practice and in tests.
## Advances only through step(dt) and uses its own seeded RNG (no randf()).

signal player_died(id: int)
signal player_respawned(id: int)
signal player_death_delay_started(id: int)
## `by_id` is the reviving teammate, or -1 when the player touched their own base post.
signal player_revived(id: int, by_id: int)

## A team scored (`by_id` stood in the enemy base). A freeze follows.
signal point_scored(team: int, by_id: int)
signal set_won(team: int)
signal match_won(team: int)
## The freeze is over: everyone is back at their base at full HP.
signal point_reset
## New set: the teams swapped bases (and the walls were rebuilt).
signal sides_switched
signal wall_damaged(index: int)
signal wall_destroyed(index: int)
signal walls_rebuilt

const REVIVED_BY_POST: int = -1

enum Phase { PLAYING, POINT_FREEZE, MATCH_OVER }

var rules: GameRules
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## id -> state, in insertion order (stepping order is deterministic).
var players: Dictionary[int, PlayerState] = {}
## Wall columns (from the map layout). A column with hp <= 0 no longer blocks.
var walls: Array[MapLayout.WallSpec] = []
## Live weapon effects (projectiles, zones, shields).
var weapons: WeaponSystem = WeaponSystem.new()
## id -> WeaponDef, from rules.weapons.
var weapon_defs: Dictionary[StringName, WeaponDef] = {}
var score: MatchScore
var ball: RubberBall
var tricycle: Tricycle
var phase: Phase = Phase.PLAYING
## Seconds left in the freeze after a point.
var freeze_left: float = 0.0

var _inputs: Dictionary[int, PlayerInput] = {}
var _brains: Dictionary[int, DummyBrain] = {}
var _team_counts: Dictionary[int, int] = {}
var _boundaries: Array[Rect2] = []
## Which side team 0 defends this set (teams switch bases every set).
var _team0_side: int = MapLayout.SIDE_OWN
var _new_set_pending: bool = false


func _init(p_rules: GameRules, p_layout: MapLayout, seed_value: int) -> void:
	rules = p_rules
	layout = p_layout
	rng.seed = seed_value
	walls = layout.wall_columns()
	_boundaries = layout.boundary_rects()
	for def: WeaponDef in rules.weapons:
		weapon_defs[def.id] = def
	score = MatchScore.new(rules)
	ball = RubberBall.new(rules)
	tricycle = Tricycle.new(rules)


## Team 0 starts on the own (+Z) base, team 1 on the enemy (-Z) base; they swap
## every set.
func side_for_team(team: int) -> int:
	return _team0_side if team == 0 else -_team0_side


## Network mirror only: the server says which base team 0 defends now.
func set_team0_side(side: int) -> void:
	if side == _team0_side:
		return
	_team0_side = side
	for id: int in players:
		var spawn: Vector2 = players[id].spawn_position
		players[id].spawn_position = Vector2(spawn.x, -spawn.y)


## Client-side prediction: runs only the movement part of a tick for one player
## (walking, dash travel, pushes; walls and speed modifiers included). Skills,
## weapons and everything else stay server-side.
func predict_move(id: int, input: PlayerInput, dt: float) -> void:
	var state: PlayerState = players.get(id) as PlayerState
	if state == null or not state.alive or phase != Phase.PLAYING:
		return
	_move(state, input, dt)


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


## Equips two different weapons. Returns false (and changes nothing) for an
## unknown weapon or the same weapon twice; two of the same *type* is fine.
func set_loadout(id: int, first: StringName, second: StringName) -> bool:
	if not players.has(id) or first == second:
		return false
	if not weapon_defs.has(first) or not weapon_defs.has(second):
		return false
	var state: PlayerState = players[id]
	state.weapons = [first, second]
	state.weapon_cooldowns = [0.0, 0.0]
	state.aim_hold = [-1.0, -1.0]
	return true


## Respawn swap: only while dead (respawn timer running), as often as you like.
## A weapon you keep keeps its cooldown, so swapping away and back clears nothing.
func swap_loadout(id: int, first: StringName, second: StringName) -> bool:
	if not players.has(id) or players[id].alive:
		return false
	var state: PlayerState = players[id]
	var kept: Dictionary[StringName, float] = {}
	for slot: int in state.weapons.size():
		kept[state.weapons[slot]] = state.weapon_cooldowns[slot]
	if not set_loadout(id, first, second):
		return false
	for slot: int in state.weapons.size():
		state.weapon_cooldowns[slot] = kept.get(state.weapons[slot], 0.0) as float
	return true


## Two different random weapons (auto-fill when the pick timer runs out).
func random_loadout() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	var first: int = rng.randi_range(0, ids.size() - 1)
	var second: int = rng.randi_range(0, ids.size() - 2)
	if second >= first:
		second += 1
	return [ids[first], ids[second]]


## Gives every player a random character, no duplicates (seeded, so the server and
## replays agree). Purely cosmetic.
func assign_characters() -> void:
	var ids: Array[StringName] = []
	for character: CharacterDef in rules.characters:
		ids.append(character.id)
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var index: int = 0
	for id: int in players:
		players[id].character_id = ids[index % ids.size()]
		index += 1


## Living players that can be hit (not dead, not in the death delay).
func is_targetable(state: PlayerState) -> bool:
	return state.alive and not state.death_delay


func enemies_of(team: int) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for id: int in players:
		var state: PlayerState = players[id]
		if state.team != team and is_targetable(state):
			result.append(state)
	return result


func nearest_enemy(caster: PlayerState, max_range: float) -> PlayerState:
	var best: PlayerState = null
	var best_distance: float = max_range
	for target: PlayerState in enemies_of(caster.team):
		var distance: float = caster.position.distance_to(target.position)
		if distance <= best_distance:
			best_distance = distance
			best = target
	return best


## Status effect from a weapon. Hard CC also cancels a dash in progress.
func apply_effect(id: int, type: StatusEffects.Type, duration: float, magnitude: float) -> void:
	if not players.has(id) or not is_targetable(players[id]):
		return
	var state: PlayerState = players[id]
	state.effects.apply(type, duration, magnitude)
	if state.effects.is_hard_cc(type):
		state.dash_time_left = 0.0


## A training dummy: a normal player on `team` placed at `position`, driven by `brain`.
## It has no death delay and respawns at the same spot.
func add_dummy(id: int, team: int, position: Vector2, brain: DummyBrain) -> PlayerState:
	var state: PlayerState = add_player(id, team)
	state.position = position
	state.spawn_position = position
	state.death_delay_allowed = false
	_brains[id] = brain
	return state


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


## Applies damage. At 0 HP the player enters the death delay (once per respawn),
## otherwise dies and respawns after rules.respawn_time.
func damage(id: int, amount: int) -> void:
	if not players.has(id) or amount <= 0:
		return
	var state: PlayerState = players[id]
	if not state.alive:
		return
	if state.death_delay:
		if rules.death_delay_takes_damage:
			state.gray_hp -= amount
			if state.gray_hp <= 0.0:
				_die(state)
		return
	state.hp = maxi(0, state.hp - amount)
	if state.hp > 0:
		return
	if rules.death_delay_enabled and state.death_delay_allowed and not state.death_delay_used:
		_start_death_delay(state)
	else:
		_die(state)


## Immediate death (no death delay), e.g. for scripted or out-of-play kills.
func kill(id: int) -> void:
	if players.has(id) and players[id].alive:
		players[id].hp = 0
		_die(players[id])


func step(dt: float) -> void:
	if phase == Phase.MATCH_OVER:
		tick += 1
		return
	if phase == Phase.POINT_FREEZE:
		freeze_left -= dt
		if freeze_left <= 0.0:
			_end_freeze()
		tick += 1
		return
	for id: int in _brains:
		if players[id].alive:
			_inputs[id] = _brains[id].think(players[id])
	for id: int in players:
		var state: PlayerState = players[id]
		var input: PlayerInput = _inputs[id] if _inputs.has(id) else null
		if state.alive:
			_step_alive(state, input, dt)
		else:
			_step_dead(state, dt)
	weapons.step(self, dt)
	ball.step(self, dt)
	tricycle.step(self, dt)
	_check_base_captures(dt)
	tick += 1


func _step_alive(state: PlayerState, input: PlayerInput, dt: float) -> void:
	state.effects.step(dt)
	for slot: int in state.weapon_cooldowns.size():
		state.weapon_cooldowns[slot] = maxf(0.0, state.weapon_cooldowns[slot] - dt)
	state.dash_cooldown_left = maxf(0.0, state.dash_cooldown_left - dt)
	state.bookmark_cooldown_left = maxf(0.0, state.bookmark_cooldown_left - dt)
	_tick_boost(state, dt)
	# Skills fire on a fresh press only: holding a key through a cooldown does not
	# queue a cast for the moment it ends (no precasting).
	var previous: int = state.previous_buttons
	var just_pressed: int = input.buttons & ~previous if input != null else 0
	if input != null and state.can_act():
		if just_pressed & PlayerInput.BTN_DASH and state.dash_cooldown_left <= 0.0:
			_start_dash(state, input)
		elif just_pressed & PlayerInput.BTN_BOOKMARK and state.bookmark_ready():
			_use_bookmark(state)
	if input != null:
		_handle_weapon_buttons(state, input, dt)
		_handle_ball_button(state, input, previous, dt)
	_move(state, input, dt)
	if state.death_delay:
		_step_death_delay(state)


func _step_dead(state: PlayerState, dt: float) -> void:
	state.respawn_time_left -= dt
	if state.respawn_time_left <= 0.0:
		state.position = state.spawn_position
		state.facing = Vector2(0.0, -side_for_team(state.team))
		state.hp = rules.player_max_hp
		state.alive = true
		state.death_delay_used = false
		_clear_actions(state)
		player_respawned.emit(state.id)


func _die(state: PlayerState) -> void:
	state.alive = false
	state.death_delay = false
	state.gray_hp = 0.0
	state.respawn_time_left = rules.respawn_time
	_clear_actions(state)
	player_died.emit(state.id)


func _start_death_delay(state: PlayerState) -> void:
	state.death_delay = true
	state.death_delay_used = true
	state.gray_hp = rules.death_delay_gray_hp
	_clear_actions(state)
	player_death_delay_started.emit(state.id)


## After moving: gray HP running out is a real death; otherwise a touch can revive.
func _step_death_delay(state: PlayerState) -> void:
	if state.gray_hp <= 0.0:
		_die(state)
		return
	var post: Vector2 = layout.base_center(side_for_team(state.team))
	if state.position.distance_to(post) <= rules.post_touch_distance:
		_revive(state, REVIVED_BY_POST)
		return
	for id: int in players:
		var other: PlayerState = players[id]
		if other.team != state.team or other.id == state.id:
			continue
		if not other.alive or other.death_delay:
			continue
		if state.position.distance_to(other.position) <= rules.revive_touch_distance:
			_revive(state, other.id)
			return


## Back on their feet with the gray HP they had left (at least 1).
func _revive(state: PlayerState, by_id: int) -> void:
	state.death_delay = false
	state.hp = maxi(1, ceili(state.gray_hp))
	state.gray_hp = 0.0
	player_revived.emit(state.id, by_id)


## Dash, stumble, bookmark, status effects and weapon aiming end on death/respawn.
## Cooldowns keep running.
func _clear_actions(state: PlayerState) -> void:
	state.dash_time_left = 0.0
	state.stumble_time_left = 0.0
	state.boost_time_left = 0.0
	if state.mark_active:
		state.bookmark_cooldown_left = rules.bookmark_cooldown
	state.mark_active = false
	state.effects.clear()
	state.aim_hold = [-1.0, -1.0]


## Weapons cast on release: a fresh press starts aiming (only if the weapon is
## ready: no precasting during a cooldown), hold time counts up (cone snips) and
## release casts unless it was released over the cancel zone. Auto-aim is taken
## once at the press; hard CC or the death delay drops a held aim.
func _handle_weapon_buttons(state: PlayerState, input: PlayerInput, dt: float) -> void:
	var bits: Array[int] = [PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2]
	for slot: int in bits.size():
		var held: bool = input.is_pressed(bits[slot])
		var was_held: bool = (state.previous_buttons & bits[slot]) != 0
		if held and not was_held:
			if weapon_ready(state, slot):
				state.aim_hold[slot] = 0.0
				_lock_aim(state, slot)
			else:
				state.aim_hold[slot] = -1.0
		elif held and state.aim_hold[slot] >= 0.0:
			if state.death_delay or not state.effects.can_cast():
				state.aim_hold[slot] = -1.0
			else:
				state.aim_hold[slot] += dt
		elif not held and was_held and state.aim_hold[slot] >= 0.0:
			if not input.is_pressed(PlayerInput.BTN_AIM_CANCEL):
				_try_fire(state, slot, input.aim, state.aim_hold[slot])
			state.aim_hold[slot] = -1.0
	state.previous_buttons = input.buttons


## A weapon slot can start aiming: equipped, off cooldown, and casting allowed.
func weapon_ready(state: PlayerState, slot: int) -> bool:
	return (
		state.alive and not state.death_delay and state.effects.can_cast()
		and slot < state.weapons.size() and state.weapon_cooldowns[slot] <= 0.0
	)


## The aim a release would use: the stick if it is past the deadzone, otherwise the
## auto-aim locked at the press (or a live auto-aim if the slot is not held yet).
func resolved_aim(state: PlayerState, slot: int, stick: Vector2) -> Vector2:
	if stick.length() >= rules.aim_deadzone:
		return stick.limit_length(1.0)
	if state.aim_hold[slot] >= 0.0:
		return state.aim_lock[slot]
	return weapons.auto_aim(self, state, weapon_defs[state.weapons[slot]])


## The target a TARGETED weapon would throw at (locked at the press while held).
func resolved_target(state: PlayerState, slot: int) -> int:
	if state.aim_hold[slot] >= 0.0:
		return state.aim_target[slot]
	var target: PlayerState = nearest_enemy(state, weapon_defs[state.weapons[slot]].max_range)
	return target.id if target != null else -1


func _lock_aim(state: PlayerState, slot: int) -> void:
	var def: WeaponDef = weapon_defs[state.weapons[slot]]
	state.aim_lock[slot] = weapons.auto_aim(self, state, def)
	var target: PlayerState = nearest_enemy(state, def.max_range)
	state.aim_target[slot] = target.id if target != null else -1


func _try_fire(state: PlayerState, slot: int, stick: Vector2, hold_seconds: float) -> void:
	if not state.can_act() or not weapon_ready(state, slot):
		return
	var def: WeaponDef = weapon_defs[state.weapons[slot]]
	var aim: Vector2 = resolved_aim(state, slot, stick)
	if weapons.fire(self, state, def, aim, hold_seconds, state.aim_target[slot]):
		state.weapon_cooldowns[slot] = def.cooldown


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
		# the cooldown only starts once the player is back at the mark
		state.bookmark_cooldown_left = rules.bookmark_cooldown


func _move(state: PlayerState, input: PlayerInput, dt: float) -> void:
	if state.push_time_left > 0.0:
		_move_by(state, state.push_velocity * minf(dt, state.push_time_left))
		state.push_time_left = maxf(0.0, state.push_time_left - dt)
		return
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
	if input == null or not state.effects.can_move():
		return
	var move: Vector2 = input.move.limit_length(1.0)
	if move.length_squared() > 0.0:
		state.facing = move.normalized()
	var speed: float = rules.move_speed
	if state.boost_time_left > 0.0:
		speed *= 1.0 + rules.bookmark_speed_bonus
	speed *= state.effects.speed_multiplier(rules.polymorph_speed_scale)
	if ball.is_holder(state.id):
		speed *= rules.ball_holder_speed_scale
	if state.death_delay:
		speed *= rules.death_delay_move_speed_scale
		state.gray_hp -= rules.death_delay_drain_per_second * move.length() * dt
	_move_by(state, move * speed * dt)


## Moves by `delta` in sub-steps no longer than the player's radius so fast
## moves (dash, blink) can never tunnel through a wall.
func _move_by(state: PlayerState, delta: Vector2) -> void:
	var length: float = delta.length()
	if length <= 0.0:
		return
	var count: int = maxi(1, ceili(length / state.radius))
	var piece: Vector2 = delta / count
	var blocking: Array[Rect2] = _blocking_rects_for(state)
	for i: int in count:
		state.position = Collision.resolve(state.position + piece, state.radius, blocking)


## Slot 0 at the base post, then alternating +x / -x by spawn_spacing.
func _spawn_position(side: int, slot: int) -> Vector2:
	var base: Vector2 = layout.base_center(side)
	var offset: int = ceili(slot / 2.0)
	var direction: int = 1 if slot % 2 == 1 else -1
	return base + Vector2(direction * offset * rules.spawn_spacing, 0.0)


## What stops this player: the boundary walls plus every standing wall column on the
## OTHER team's side. A team walks straight through its own cardboard walls.
func _blocking_rects_for(state: PlayerState) -> Array[Rect2]:
	return blocking_rects_for_team(state.team)


## Lane edges plus the other team's standing wall columns (what stops `team`'s
## players and projectiles).
func blocking_rects_for_team(team: int) -> Array[Rect2]:
	var own_side: int = side_for_team(team)
	var rects: Array[Rect2] = []
	rects.append_array(_boundaries)
	for wall: MapLayout.WallSpec in walls:
		if wall.hp > 0 and wall.side != own_side:
			rects.append(wall.rect)
	return rects


# ---- walls ---------------------------------------------------------------------

## Index of the standing wall column at `point` that blocks `team`, or -1.
func wall_at_point(team: int, point: Vector2) -> int:
	var own_side: int = side_for_team(team)
	for index: int in walls.size():
		var wall: MapLayout.WallSpec = walls[index]
		if wall.hp > 0 and wall.side != own_side and wall.rect.has_point(point):
			return index
	return -1


## Standing enemy wall columns (for `team`) touched by a circle.
func walls_in_circle(team: int, center: Vector2, radius: float) -> Array[int]:
	var own_side: int = side_for_team(team)
	var result: Array[int] = []
	for index: int in walls.size():
		var wall: MapLayout.WallSpec = walls[index]
		if wall.hp <= 0 or wall.side == own_side:
			continue
		var closest: Vector2 = Vector2(
			clampf(center.x, wall.rect.position.x, wall.rect.end.x),
			clampf(center.y, wall.rect.position.y, wall.rect.end.y)
		)
		if closest.distance_to(center) <= radius:
			result.append(index)
	return result


func damage_wall(index: int, amount: int) -> void:
	var wall: MapLayout.WallSpec = walls[index]
	if wall.hp <= 0 or amount <= 0:
		return
	wall.hp = maxi(0, wall.hp - amount)
	wall_damaged.emit(index)
	if wall.hp == 0:
		wall_destroyed.emit(index)


# ---- knockback, ball, base -------------------------------------------------------

## Pushes a player by `offset` over `duration` (walls still stop them). Cancels a dash.
func push(id: int, offset: Vector2, duration: float) -> void:
	var state: PlayerState = players[id]
	state.dash_time_left = 0.0
	state.stumble_time_left = 0.0
	state.push_velocity = offset / maxf(duration, 0.001)
	state.push_time_left = duration


## Called after a teleport (ball blink): an active dash ends there.
func on_teleported(state: PlayerState) -> void:
	state.dash_time_left = 0.0


## Ball button: press (while holding the ball) starts aiming, release throws (cast on
## release, auto-aim locked at the press, cancel zone works). A fresh press while
## your own throw is flying blinks to it. Every fresh press opens the catch window.
func _handle_ball_button(state: PlayerState, input: PlayerInput, previous: int, dt: float) -> void:
	var held: bool = input.is_pressed(PlayerInput.BTN_BALL)
	var was_held: bool = (previous & PlayerInput.BTN_BALL) != 0
	if held and not was_held:
		state.ball_press_age = 0.0
	else:
		state.ball_press_age += dt
	if ball.is_holder(state.id):
		if held and not was_held:
			state.ball_aim_hold = 0.0
			state.ball_aim_lock = _ball_auto_aim(state)
		elif held and state.ball_aim_hold >= 0.0:
			state.ball_aim_hold += dt
		elif not held and was_held and state.ball_aim_hold >= 0.0:
			state.ball_aim_hold = -1.0
			if not input.is_pressed(PlayerInput.BTN_AIM_CANCEL) and state.can_act():
				var aim: Vector2 = input.aim if input.aim.length() >= rules.aim_deadzone else state.ball_aim_lock
				ball.throw(state, aim)
		return
	state.ball_aim_hold = -1.0
	if held and not was_held and ball.state == RubberBall.State.FLYING and state.can_act():
		ball.blink(self, state)


## The direction a ball throw would take now (for the aim preview): the stick past
## the deadzone, else the auto-aim locked at the press (or a live one before it).
func resolved_ball_aim(state: PlayerState, stick: Vector2) -> Vector2:
	if stick.length() >= rules.aim_deadzone:
		return stick.normalized()
	if state.ball_aim_hold >= 0.0:
		return state.ball_aim_lock
	return _ball_auto_aim(state)


func _ball_auto_aim(state: PlayerState) -> Vector2:
	var target: PlayerState = nearest_enemy(state, rules.ball_range)
	if target != null and target.position != state.position:
		return state.position.direction_to(target.position)
	return state.facing


## A living, uncontrolled player standing in the enemy base zone long enough scores.
func _check_base_captures(dt: float) -> void:
	for id: int in players:
		var state: PlayerState = players[id]
		if not state.alive or state.death_delay or not state.effects.can_cast():
			state.base_time = 0.0
			continue
		var enemy_base: Vector2 = layout.base_center(-side_for_team(state.team))
		if state.position.distance_to(enemy_base) > layout.base_radius:
			state.base_time = 0.0
			continue
		state.base_time += dt
		if state.base_time >= rules.base_capture_time:
			_score_point(state.team, id)
			return


func _score_point(team: int, by_id: int) -> void:
	var result: MatchScore.Result = score.award_point(team)
	point_scored.emit(team, by_id)
	if result == MatchScore.Result.MATCH:
		phase = Phase.MATCH_OVER
		set_won.emit(team)
		match_won.emit(team)
		return
	if result == MatchScore.Result.SET:
		_new_set_pending = true
		set_won.emit(team)
	phase = Phase.POINT_FREEZE
	freeze_left = rules.point_freeze_time


func _end_freeze() -> void:
	if _new_set_pending:
		_new_set_pending = false
		_team0_side = -_team0_side
		for id: int in players:
			var spawn: Vector2 = players[id].spawn_position
			players[id].spawn_position = Vector2(spawn.x, -spawn.y)
		for wall: MapLayout.WallSpec in walls:
			wall.hp = layout.wall_hp
		walls_rebuilt.emit()
		sides_switched.emit()
	_reset_round()
	phase = Phase.PLAYING
	point_reset.emit()


## Everyone back to their base at full HP, cooldowns and effects cleared; weapon
## objects, the ball and an active tricycle are removed. Walls persist.
func _reset_round() -> void:
	weapons.reset()
	ball.reset(rules)
	tricycle.cancel(rules)
	for id: int in players:
		var state: PlayerState = players[id]
		var was_dead: bool = not state.alive
		_clear_actions(state)
		state.position = state.spawn_position
		state.facing = Vector2(0.0, -side_for_team(state.team))
		state.hp = rules.player_max_hp
		state.alive = true
		state.death_delay = false
		state.death_delay_used = false
		state.gray_hp = 0.0
		state.respawn_time_left = 0.0
		state.dash_cooldown_left = 0.0
		state.bookmark_cooldown_left = 0.0
		for slot: int in state.weapon_cooldowns.size():
			state.weapon_cooldowns[slot] = 0.0
		state.push_time_left = 0.0
		state.base_time = 0.0
		state.ball_aim_hold = -1.0
		if was_dead:
			player_respawned.emit(id)
