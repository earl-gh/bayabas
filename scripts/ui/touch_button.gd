class_name TouchButton
extends Control
## Round skill button that reads raw touches, so it works while another finger
## holds the joystick (emulated mouse input only follows the first finger).
## Also reacts to the real mouse; ignores mouse events emulated from touch.

signal pressed

const READY_COLOR: Color = Color(0.14, 0.12, 0.2, 0.7)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const RIM_COLOR: Color = Color(1.0, 0.9, 0.6, 0.95)
const RIM_WIDTH: float = 5.0
const SHADOW_DROP: float = 5.0
const FONT_SIZE: int = 26
const SMALL_FONT_SIZE: int = 18
const TEXT_OUTLINE: int = 5
const COOLDOWN_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const ARC_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const ARC_WIDTH: float = 8.0
const ARC_POINTS: int = 48
## Slightly generous hit area (fraction of the radius).
const HIT_SLACK: float = 1.15
const NO_POINTER: int = -1
const MOUSE_POINTER: int = -2

@export var label_text: String = ""
## Small second line, e.g. the weapon type (ATK / CC / BLOCK).
@export var sub_text: String = ""
@export var sub_color: Color = Color(1.0, 1.0, 1.0, 0.8)
## Icons.draw id ("dash", "bato_light", ...); empty = text only.
@export var icon_id: StringName = &""

## 1.0 = just used, 0.0 = ready.
var cooldown_fraction: float = 0.0

## While locked (e.g. skills off in the death delay) the button is dimmed and ignores presses.
var locked: bool = false

var _pointer: int = NO_POINTER


## True if `local_point` (in this control's space) is on the round button.
static func hit_test(local_point: Vector2, button_size: Vector2) -> bool:
	var radius: float = minf(button_size.x, button_size.y) / 2.0
	return local_point.distance_to(button_size / 2.0) <= radius * HIT_SLACK


func set_cooldown(remaining: float, total: float) -> void:
	var fraction: float = 0.0
	if total > 0.0 and remaining > 0.0:
		fraction = clampf(remaining / total, 0.0, 1.0)
	if not is_equal_approx(fraction, cooldown_fraction):
		cooldown_fraction = fraction
		queue_redraw()


func set_locked(value: bool) -> void:
	if value != locked:
		locked = value
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == NO_POINTER and not locked and _hit(touch.position):
				_pointer = touch.index
				pressed.emit()
		elif touch.index == _pointer:
			_pointer = NO_POINTER
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == NO_POINTER and not locked and _hit(click.position):
				_pointer = MOUSE_POINTER
				pressed.emit()
		elif _pointer == MOUSE_POINTER:
			_pointer = NO_POINTER


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	draw_circle(center + Vector2(0.0, SHADOW_DROP), radius, SHADOW_COLOR)
	draw_circle(center, radius, READY_COLOR)
	draw_arc(center, radius - RIM_WIDTH / 2.0, 0.0, TAU, ARC_POINTS, RIM_COLOR, RIM_WIDTH)
	var font: Font = ThemeDB.fallback_font
	if icon_id != &"":
		Icons.draw(self, icon_id, center + Vector2(0.0, -radius * 0.18), radius * 0.95)
		_text(font, label_text, center + Vector2(0.0, radius * 0.5), SMALL_FONT_SIZE, TEXT_COLOR)
		if not sub_text.is_empty():
			_text(font, sub_text, center + Vector2(0.0, -radius * 0.68), SMALL_FONT_SIZE - 4, sub_color)
	else:
		var line_shift: float = 0.0 if sub_text.is_empty() else -FONT_SIZE * 0.3
		_text(font, label_text, center + Vector2(0.0, line_shift), FONT_SIZE, TEXT_COLOR)
		if not sub_text.is_empty():
			_text(font, sub_text, center + Vector2(0.0, FONT_SIZE * 0.6), SMALL_FONT_SIZE, sub_color)
	if locked or cooldown_fraction > 0.0:
		draw_circle(center, radius, COOLDOWN_COLOR)
	if cooldown_fraction > 0.0:
		draw_arc(center, radius - ARC_WIDTH, -PI / 2.0, -PI / 2.0 + TAU * cooldown_fraction, ARC_POINTS, ARC_COLOR, ARC_WIDTH)


## Centred text with a dark outline (readable over the street).
func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin: Vector2 = at + Vector2(-text_size.x / 2.0, font_size * 0.35)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_OUTLINE, Icons.OUTLINE)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _hit(viewport_position: Vector2) -> bool:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	return hit_test(local, size)
