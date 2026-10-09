class_name RubberBall
extends RefCounted
## The neutral rubber ball (docs/GDD.md "Rubber ball"). One at a time: it spawns
## at the lane center, is picked up by walking over it, thrown as a skillshot,
## knocks out an enemy it hits (unless they catch it), passes to an ally, damages
## enemy walls, and drops when it hits the lane edge or reaches max range.
## Plain data + rules; MatchSim feeds it the ball button.

signal spawned
signal picked_up(id: int)
signal thrown(id: int)
signal knocked_out(id: int)
signal caught(id: int)
signal passed(id: int)
signal dropped
signal wall_hit(index: int)
signal blinked(id: int)

enum State { NONE, GROUND, HELD, FLYING }

const STEP: float = 0.25

var state: State = State.NONE
var position: Vector2 = Vector2.ZERO
var holder_id: int = -1
## While flying: who threw it and their team.
var thrower_id: int = -1
var team: int = -1
var direction: Vector2 = Vector2.ZERO
var travelled: float = 0.0
## The thrower may blink to it while it flies and has not hit anything yet (D3).
var can_blink: bool = false
## Counts down while there is no ball.
var spawn_timer: float = 0.0


func _init(rules: GameRules) -> void:
	spawn_timer = rules.ball_spawn_interval


## Back to "no ball", spawn timer restarted (after a point or a hit).
func reset(rules: GameRules) -> void:
	state = State.NONE
	holder_id = -1
	thrower_id = -1
	can_blink = false
	spawn_timer = rules.ball_spawn_interval


func is_holder(id: int) -> bool:
	return state == State.HELD and holder_id == id


func throw(caster: PlayerState, aim_direction: Vector2) -> void:
	state = State.FLYING
	thrower_id = caster.id
	team = caster.team
	holder_id = -1
	position = caster.position
	direction = aim_direction.normalized() if aim_direction != Vector2.ZERO else caster.facing
	travelled = 0.0
	can_blink = true
	thrown.emit(caster.id)


## The thrower jumps to the flying ball (once).
func blink(sim: MatchSim, caster: PlayerState) -> void:
	if state != State.FLYING or not can_blink or caster.id != thrower_id:
		return
	caster.position = position
	can_blink = false
	blinked.emit(caster.id)
	sim.on_teleported(caster)


func step(sim: MatchSim, dt: float) -> void:
	match state:
		State.NONE:
			spawn_timer -= dt
			if spawn_timer <= 0.0:
				state = State.GROUND
				position = sim.layout.lane_rect().get_center()
				spawned.emit()
		State.GROUND:
			for id: int in sim.players:
				var player: PlayerState = sim.players[id]
				if _can_hold(player) and player.position.distance_to(position) <= player.radius + sim.rules.ball_radius:
					_hold(player)
					picked_up.emit(id)
					return
		State.HELD:
			var holder: PlayerState = sim.players.get(holder_id) as PlayerState
			if holder == null or not _can_hold(holder):
				_drop_at(position)
			else:
				position = holder.position
		State.FLYING:
			_fly(sim, sim.rules.ball_speed * dt)


func _fly(sim: MatchSim, distance: float) -> void:
	var left: float = distance
	var blocking: Array[Rect2] = sim.blocking_rects_for_team(team)
	while left > 0.0 and state == State.FLYING:
		var move: float = minf(STEP, left)
		left -= move
		var previous: Vector2 = position
		position += direction * move
		travelled += move
		var wall: int = sim.wall_at_point(team, position)
		if wall >= 0:
			sim.damage_wall(wall, sim.rules.ball_wall_damage)
			wall_hit.emit(wall)
			reset(sim.rules)
			return
		var blocked: bool = sim.weapons.blocks_segment(team, previous, position)
		for rect: Rect2 in blocking:
			if rect.has_point(position):
				blocked = true
		if blocked:
			_drop_at(previous)
			return
		if _check_players(sim):
			return
		if travelled >= sim.rules.ball_range:
			_drop_at(position)
			return


## Returns true when the flight ended on a player.
func _check_players(sim: MatchSim) -> bool:
	for id: int in sim.players:
		var player: PlayerState = sim.players[id]
		if id == thrower_id or not sim.is_targetable(player):
			continue
		if player.position.distance_to(position) > player.radius + sim.rules.ball_radius:
			continue
		if player.team == team:
			_hold(player)
			passed.emit(id)
		elif player.ball_press_age <= sim.rules.ball_catch_window:
			_hold(player)
			caught.emit(id)
		else:
			sim.apply_effect(id, StatusEffects.Type.KNOCKOUT, sim.rules.ball_knockout_time, 0.0)
			reset(sim.rules)
			knocked_out.emit(id)
		return true
	return false


func _can_hold(player: PlayerState) -> bool:
	return player.alive and not player.death_delay


func _hold(player: PlayerState) -> void:
	state = State.HELD
	holder_id = player.id
	thrower_id = -1
	can_blink = false
	position = player.position


func _drop_at(point: Vector2) -> void:
	state = State.GROUND
	position = point
	holder_id = -1
	thrower_id = -1
	can_blink = false
	dropped.emit()
