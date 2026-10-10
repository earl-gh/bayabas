class_name TouchButton
extends Control
## Round skill button that reads raw touches, so it works while another finger
## holds the joystick (emulated mouse input only follows the first finger).
## Also reacts to the real mouse; ignores mouse events emulated from touch.

signal pressed

## The skill button a finger is holding right now (drag-to-aim), if any: while it is held no
## other skill button can be pressed.
static var holder: TouchButton = null

const READY_COLOR: Color = Color(0.14, 0.12, 0.2, 0.7)
const FACE_ART: StringName = &"button_face"
## Painted per-skill buttons are named btn_<icon_id>.
const BUTTON_ART_PREFIX: String = "btn_"
## The painted art includes its drop shadow, so it is drawn a little past the hit circle.
const ART_OVERHANG: float = 1.06
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const RIM_COLOR: Color = Color(1.0, 0.9, 0.6, 0.95)
const RIM_WIDTH: float = 5.0
const SHADOW_DROP: float = 5.0
const FONT_SIZE: int = 26
const SMALL_FONT_SIZE: int = 18
const TAG_FONT_SIZE: int = 15
const TEXT_OUTLINE: int = 5
const COOLDOWN_FONT_SIZE: int = 34
const READY_FLASH_TIME: float = 0.45
const READY_GLOW: Color = Color(1.0, 0.9, 0.4)
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
## The weapon type tag (ATK / CC / BLK) shown under the art.
@export var sub_text: String = ""
@export var sub_color: Color = Color(1.0, 1.0, 1.0, 0.8)
## Icons.draw id ("dash", "bato_light", ...); empty = text only.
@export var icon_id: StringName = &""

## 1.0 = just used, 0.0 = ready.
var cooldown_fraction: float = 0.0
## Seconds left on the cooldown (drawn as a number).
var cooldown_seconds: float = 0.0
## A steady gold glow (e.g. you are holding the guava, throw it now).
var highlight: bool = false:
	set(value):
		if value != highlight:
			highlight = value
			queue_redraw()
## Brief glow when the skill becomes ready again.
var _ready_flash: float = 0.0

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
	if fraction == 0.0 and cooldown_fraction > 0.0:
		_ready_flash = READY_FLASH_TIME
	if not is_equal_approx(fraction, cooldown_fraction) or ceili(remaining) != ceili(cooldown_seconds):
		cooldown_fraction = fraction
		cooldown_seconds = maxf(remaining, 0.0)
		queue_redraw()


func _process(delta: float) -> void:
	if _ready_flash > 0.0:
		_ready_flash = maxf(0.0, _ready_flash - delta)
		queue_redraw()


## False while locked, or while a different skill button is being held.
func can_press() -> bool:
	return not locked and (holder == null or holder == self)


func _exit_tree() -> void:
	if holder == self:
		holder = null


func set_locked(value: bool) -> void:
	if value != locked:
		locked = value
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == NO_POINTER and can_press() and _hit(touch.position):
				_pointer = touch.index
				pressed.emit()
		elif touch.index == _pointer:
			_pointer = NO_POINTER
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == NO_POINTER and can_press() and _hit(click.position):
				_pointer = MOUSE_POINTER
				pressed.emit()
		elif _pointer == MOUSE_POINTER:
			_pointer = NO_POINTER


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	var button_art: Texture2D = Icons.art(StringName(BUTTON_ART_PREFIX + String(icon_id))) if icon_id != &"" else null
	var face: Texture2D = Icons.art(FACE_ART)
	if button_art != null:
		# the whole painted button: type-coloured face, cropped icon, rim (tools/art/make_buttons.py)
		draw_texture_rect(button_art, Rect2(center - Vector2(radius, radius) * ART_OVERHANG, Vector2(radius, radius) * 2.0 * ART_OVERHANG), false)
	elif face != null:
		draw_circle(center + Vector2(0.0, SHADOW_DROP), radius, SHADOW_COLOR)
		# painted gold rim and navy face (tools/art/make_assets.py)
		draw_texture_rect(face, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
	else:
		draw_circle(center + Vector2(0.0, SHADOW_DROP), radius, SHADOW_COLOR)
		draw_circle(center, radius, READY_COLOR)
		draw_arc(center, radius - RIM_WIDTH / 2.0, 0.0, TAU, ARC_POINTS, RIM_COLOR, RIM_WIDTH)
	if highlight:
		draw_arc(center, radius + 3.0, 0.0, TAU, ARC_POINTS, READY_GLOW, 7.0)
	var font: Font = ThemeDB.fallback_font
	if button_art != null:
		if not sub_text.is_empty():
			_tag(font, sub_text, center + Vector2(0.0, radius * 0.86), sub_color)
	elif icon_id != &"":
		# art only; a weapon adds just its type (ATK / CC / BLK) as a small tag
		var has_tag: bool = not sub_text.is_empty()
		Icons.draw(self, icon_id, center + Vector2(0.0, -radius * (0.14 if has_tag else 0.0)), radius * (1.15 if has_tag else 1.3))
		if has_tag:
			_tag(font, sub_text, center + Vector2(0.0, radius * 0.62), sub_color)
	else:
		var line_shift: float = 0.0 if sub_text.is_empty() else -FONT_SIZE * 0.3
		_text(font, label_text, center + Vector2(0.0, line_shift), FONT_SIZE, TEXT_COLOR)
		if not sub_text.is_empty():
			_text(font, sub_text, center + Vector2(0.0, FONT_SIZE * 0.6), SMALL_FONT_SIZE, sub_color)
	if locked or cooldown_fraction > 0.0:
		draw_circle(center, radius, COOLDOWN_COLOR)
	if cooldown_fraction > 0.0:
		draw_arc(center, radius - ARC_WIDTH, -PI / 2.0, -PI / 2.0 + TAU * cooldown_fraction, ARC_POINTS, ARC_COLOR, ARC_WIDTH)
		_text(font, "%d" % ceili(cooldown_seconds), center, COOLDOWN_FONT_SIZE, Color.WHITE)
	if _ready_flash > 0.0:
		var glow: Color = READY_GLOW
		glow.a = _ready_flash / READY_FLASH_TIME
		draw_arc(center, radius + 4.0 + 10.0 * (1.0 - glow.a), 0.0, TAU, ARC_POINTS, glow, 6.0)


## A small coloured pill with the weapon type in it.
func _tag(font: Font, text: String, at: Vector2, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE).x + 20.0
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.08, 0.14, 0.92)
	pill.border_color = color
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(12)
	draw_style_box(pill, Rect2(at - Vector2(width / 2.0, 11.0), Vector2(width, 22.0)))
	_text(font, text, at, TAG_FONT_SIZE, color)


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
