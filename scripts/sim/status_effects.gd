class_name StatusEffects
extends RefCounted
## Status effects on one player (docs/GDD.md "Weapons"). An effect does not stack
## with itself: re-applying keeps the longer remaining time (so a new hard CC
## refreshes the duration) and, for SLOW, the stronger slow.

enum Type { NONE, STUN, SLOW, AIRBORNE, POLYMORPH, BOUNCE, KNOCKOUT }

## Effects that stop movement and casting.
const HARD_CC: Array[Type] = [Type.STUN, Type.AIRBORNE, Type.BOUNCE, Type.KNOCKOUT]

var _time_left: Dictionary[int, float] = {}
var _slow: float = 0.0


func apply(type: Type, duration: float, magnitude: float = 0.0) -> void:
	if type == Type.NONE or duration <= 0.0:
		return
	var current: float = _time_left[type] if _time_left.has(type) else 0.0
	_time_left[type] = maxf(current, duration)
	if type == Type.SLOW:
		_slow = maxf(_slow if current > 0.0 else 0.0, magnitude)


func step(dt: float) -> void:
	for type: int in _time_left.keys():
		_time_left[type] -= dt
		if _time_left[type] <= 0.0:
			_time_left.erase(type)
			if type == Type.SLOW:
				_slow = 0.0


func clear() -> void:
	_time_left.clear()
	_slow = 0.0


func has(type: Type) -> bool:
	return _time_left.has(type)


func time_left(type: Type) -> float:
	return _time_left[type] if _time_left.has(type) else 0.0


func is_hard_cc(type: Type) -> bool:
	return HARD_CC.has(type)


func can_move() -> bool:
	for type: Type in HARD_CC:
		if _time_left.has(type):
			return false
	return true


## Polymorph still lets you walk, but not cast.
func can_cast() -> bool:
	return can_move() and not _time_left.has(Type.POLYMORPH)


func speed_multiplier(polymorph_speed_scale: float) -> float:
	var multiplier: float = 1.0
	if _time_left.has(Type.SLOW):
		multiplier *= 1.0 - _slow
	if _time_left.has(Type.POLYMORPH):
		multiplier *= polymorph_speed_scale
	return multiplier


## Names of active effects, for HUD tags (e.g. "STUN").
func active_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for type: int in _time_left:
		names.append(Type.keys()[type])
	return names
