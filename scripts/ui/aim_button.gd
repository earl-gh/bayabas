class_name AimButton
extends TouchButton
## Weapon button with drag-to-aim. Press to start aiming, drag away from the
## button to aim (a tap or tiny drag = auto-aim), release to cast. Releasing over
## the cancel zone cancels. Reads raw touches like TouchButton, plus the real mouse.

signal aim_started
signal aim_released(aim: Vector2, cancelled: bool)

## Drag distance (in control pixels) that means full range.
const DRAG_RADIUS: float = 170.0
## Drags shorter than this fraction of DRAG_RADIUS count as a tap (auto-aim).
const TAP_DEADZONE: float = 0.2
const AIM_DOT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const AIM_RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const CANCEL_TINT: Color = Color(1.0, 0.3, 0.3, 0.9)

## Release over this control cancels the cast.
@export var cancel_zone: Control

## Screen-space aim, length 0..1 (zero = auto-aim). Y down is toward your own base.
var aim: Vector2 = Vector2.ZERO
var aiming: bool = false
var over_cancel: bool = false


## Drag offset (control pixels) to aim vector.
static func aim_from_drag(offset: Vector2) -> Vector2:
	var value: Vector2 = (offset / DRAG_RADIUS).limit_length(1.0)
	return Vector2.ZERO if value.length() < TAP_DEADZONE else value


func set_locked(value: bool) -> void:
	super.set_locked(value)
	if value and aiming:
		_finish(true)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == NO_POINTER and not locked and _hit(touch.position):
				_pointer = touch.index
				_begin(touch.position)
		elif touch.index == _pointer:
			_drag(touch.position)
			_finish(over_cancel)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _pointer:
			_drag(drag.position)
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == NO_POINTER and not locked and _hit(click.position):
				_pointer = MOUSE_POINTER
				_begin(click.position)
		elif _pointer == MOUSE_POINTER:
			_drag(click.position)
			_finish(over_cancel)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _pointer == MOUSE_POINTER and motion.device != InputEvent.DEVICE_ID_EMULATION:
			_drag(motion.position)


func _begin(viewport_position: Vector2) -> void:
	aiming = true
	aim = Vector2.ZERO
	over_cancel = false
	_drag(viewport_position)
	aim_started.emit()
	pressed.emit()


func _drag(viewport_position: Vector2) -> void:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	aim = aim_from_drag(local - size / 2.0)
	over_cancel = cancel_zone != null and cancel_zone.visible and _in_cancel_zone(viewport_position)
	queue_redraw()


func _in_cancel_zone(viewport_position: Vector2) -> bool:
	var local: Vector2 = cancel_zone.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return Rect2(Vector2.ZERO, cancel_zone.size).has_point(local)


func _finish(cancelled: bool) -> void:
	_pointer = NO_POINTER
	aiming = false
	var released_aim: Vector2 = aim
	aim = Vector2.ZERO
	over_cancel = false
	queue_redraw()
	aim_released.emit(released_aim, cancelled)


func _draw() -> void:
	super._draw()
	if not aiming:
		return
	var center: Vector2 = size / 2.0
	draw_arc(center, DRAG_RADIUS, 0.0, TAU, ARC_POINTS, AIM_RING_COLOR, 3.0)
	draw_circle(center + aim * DRAG_RADIUS, 22.0, CANCEL_TINT if over_cancel else AIM_DOT_COLOR)
