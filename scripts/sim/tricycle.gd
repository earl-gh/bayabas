class_name Tricycle
extends RefCounted
## The tricycle (docs/GDD.md "Tricycle"): every `tricycle_interval` it honks,
## then drives across the lane's midline (z = 0) from a random side, pushing
## anyone it touches away from its path (D4: perpendicular, no damage).

signal warning_started(direction: int)
signal crossing_started(direction: int)
signal crossing_ended
signal pushed(id: int)

enum Phase { WAITING, WARNING, CROSSING }

var phase: Phase = Phase.WAITING
## Seconds until the next phase change.
var time_left: float = 0.0
## +1 drives toward +x, -1 toward -x.
var direction: int = 1
var position: Vector2 = Vector2.ZERO

var _hit_ids: Dictionary[int, bool] = {}


func _init(rules: GameRules) -> void:
	time_left = rules.tricycle_first_time - rules.tricycle_warning_time


## Seconds until it drives in (counting the warning), for the HUD.
func time_to_arrival(rules: GameRules) -> float:
	match phase:
		Phase.WAITING:
			return time_left + rules.tricycle_warning_time
		Phase.WARNING:
			return time_left
	return 0.0


## Practice/debug: honk now.
func call_now() -> void:
	if phase == Phase.WAITING:
		time_left = 0.0


## After a point: an active crossing is cancelled and the wait restarts.
func cancel(rules: GameRules) -> void:
	if phase != Phase.WAITING:
		phase = Phase.WAITING
		time_left = rules.tricycle_interval - rules.tricycle_warning_time
		crossing_ended.emit()


func step(sim: MatchSim, dt: float) -> void:
	var rules: GameRules = sim.rules
	time_left -= dt
	match phase:
		Phase.WAITING:
			if time_left <= 0.0:
				phase = Phase.WARNING
				time_left = rules.tricycle_warning_time
				direction = 1 if sim.rng.randi_range(0, 1) == 0 else -1
				warning_started.emit(direction)
		Phase.WARNING:
			if time_left <= 0.0:
				phase = Phase.CROSSING
				time_left = rules.tricycle_crossing_time
				position = Vector2(-direction * _half_path(sim), 0.0)
				_hit_ids.clear()
				crossing_started.emit(direction)
		Phase.CROSSING:
			position.x += direction * (2.0 * _half_path(sim) / rules.tricycle_crossing_time) * dt
			_push_players(sim)
			if time_left <= 0.0:
				phase = Phase.WAITING
				time_left = rules.tricycle_interval - rules.tricycle_warning_time
				crossing_ended.emit()


## It starts and ends fully outside the lane.
func _half_path(sim: MatchSim) -> float:
	return sim.layout.lane_width / 2.0 + sim.rules.tricycle_length


func _push_players(sim: MatchSim) -> void:
	var rules: GameRules = sim.rules
	for id: int in sim.players:
		var player: PlayerState = sim.players[id]
		if not player.alive or _hit_ids.has(id):
			continue
		var dx: float = absf(player.position.x - position.x)
		var dz: float = absf(player.position.y - position.y)
		if dx > rules.tricycle_length / 2.0 + player.radius or dz > rules.tricycle_width / 2.0 + player.radius:
			continue
		_hit_ids[id] = true
		var away: float = signf(player.position.y - position.y)
		if away == 0.0:
			away = 1.0 if sim.rng.randi_range(0, 1) == 0 else -1.0
		sim.push(id, Vector2(0.0, away * rules.tricycle_knockback), rules.tricycle_push_time)
		pushed.emit(id)
