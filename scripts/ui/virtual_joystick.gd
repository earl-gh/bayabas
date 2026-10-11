class_name VirtualJoystick
extends Control
## On-screen joystick: a fixed see-through circle with a knob that follows the
## finger. Put it over the area it should listen in. Handles real touches (multi-touch safe)
## and the real mouse; ignores mouse events emulated from touch.

signal changed(value: Vector2)

const MAX_RADIUS: float = 90.0
const DEADZONE: float = 0.1
const THUMB_RADIUS: float = 38.0
const NO_POINTER: int = -1
const MOUSE_POINTER: int = -2
const BASE_COLOR: Color = Color(0.1, 0.08, 0.14, 0.3)
const THUMB_COLOR: Color = Color(1.0, 0.75, 0.25, 0.95)
const THUMB_SHADE: Color = Color(0.75, 0.45, 0.1, 0.95)

var value: Vector2 = Vector2.ZERO
## Resting spot of the stick inside the zone (0..1 of its size).
var rest_fraction: Vector2 = Vector2(0.42, 0.72)

var _pointer: int = NO_POINTER
var _origin: Vector2 = Vector2.ZERO
var _thumb: Vector2 = Vector2.ZERO


## Offset from the stick origin to a normalized stick vector (length <= 1, with deadzone).
static func stick_from_offset(offset: Vector2, radius: float, deadzone: float) -> Vector2:
	var stick: Vector2 = (offset / radius).limit_length(1.0)
	if stick.length() < deadzone:
		return Vector2.ZERO
	return stick


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == NO_POINTER and _in_zone(touch.position):
				_begin(touch.index, touch.position)
		elif touch.index == _pointer:
			_end()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _pointer:
			_update(drag.position)
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == NO_POINTER and _in_zone(click.position):
				_begin(MOUSE_POINTER, click.position)
		elif _pointer == MOUSE_POINTER:
			_end()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.device != InputEvent.DEVICE_ID_EMULATION and _pointer == MOUSE_POINTER:
			_update(motion.position)


## Where the stick rests when nobody touches it (MOBA style: always visible).
func rest_position() -> Vector2:
	return size * rest_fraction


func _draw() -> void:
	# a plain see-through circle that never moves, and the knob that follows the finger
	var origin: Vector2 = rest_position()
	var thumb: Vector2 = origin if _pointer == NO_POINTER else _thumb
	draw_circle(origin, MAX_RADIUS, BASE_COLOR)
	draw_circle(thumb + Vector2(0.0, 4.0), THUMB_RADIUS, THUMB_SHADE)
	draw_circle(thumb, THUMB_RADIUS, THUMB_COLOR)
	draw_circle(thumb + Vector2(-10.0, -10.0), THUMB_RADIUS * 0.35, Color(1, 1, 1, 0.45))


func _to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _in_zone(viewport_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_to_local(viewport_position))


func _begin(pointer: int, viewport_position: Vector2) -> void:
	_pointer = pointer
	_origin = rest_position()
	_update(viewport_position)


func _update(viewport_position: Vector2) -> void:
	var offset: Vector2 = _to_local(viewport_position) - _origin
	value = stick_from_offset(offset, MAX_RADIUS, DEADZONE)
	_thumb = _origin + offset.limit_length(MAX_RADIUS)
	changed.emit(value)
	queue_redraw()


func _end() -> void:
	_pointer = NO_POINTER
	value = Vector2.ZERO
	changed.emit(value)
	queue_redraw()
