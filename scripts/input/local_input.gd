class_name LocalInput
extends RefCounted
## Turns local devices (keyboard, on-screen stick) into movement for PlayerInput.


## WASD / arrow keys. Up is -1 on Y (screen up = toward the enemy base).
static func keyboard_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y).limit_length(1.0)


## Space = dash, F = bookmark (HANDOFF keyboard map; Q/E/R arrive with weapons and the ball).
static func keyboard_buttons() -> int:
	var buttons: int = 0
	if Input.is_physical_key_pressed(KEY_SPACE):
		buttons |= PlayerInput.BTN_DASH
	if Input.is_physical_key_pressed(KEY_F):
		buttons |= PlayerInput.BTN_BOOKMARK
	return buttons


static func combine(a: Vector2, b: Vector2) -> Vector2:
	return (a + b).limit_length(1.0)


## Screen-relative stick to world movement. The other team's camera is rotated
## 180 degrees, so their stick is rotated back.
static func to_world(stick: Vector2, flip: bool) -> Vector2:
	return -stick if flip else stick
