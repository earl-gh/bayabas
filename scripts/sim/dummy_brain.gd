class_name DummyBrain
extends RefCounted
## Training-dummy behaviour for practice mode. Produces a PlayerInput each tick;
## dummies never use skills. Pure data in, input out, so it stays deterministic.

enum Mode { STAND, PATROL }

var mode: Mode = Mode.STAND
var origin_x: float = 0.0
var half_range: float = 0.0
## Stick magnitude while patrolling (1.0 = full speed).
var speed_scale: float = 1.0

var _direction: float = 1.0


static func standing() -> DummyBrain:
	return DummyBrain.new()


static func patrolling(p_origin_x: float, p_half_range: float, p_speed_scale: float) -> DummyBrain:
	var brain: DummyBrain = DummyBrain.new()
	brain.mode = Mode.PATROL
	brain.origin_x = p_origin_x
	brain.half_range = p_half_range
	brain.speed_scale = p_speed_scale
	return brain


func think(state: PlayerState) -> PlayerInput:
	if mode == Mode.STAND:
		return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 0)
	if state.position.x >= origin_x + half_range:
		_direction = -1.0
	elif state.position.x <= origin_x - half_range:
		_direction = 1.0
	return PlayerInput.create(Vector2(_direction * speed_scale, 0.0), Vector2.ZERO, 0, 0)
