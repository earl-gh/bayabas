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


## Q = weapon 1, E = weapon 2 (held to aim with the mouse, released to cast).
static func weapon_key_held(slot: int) -> bool:
	return Input.is_physical_key_pressed(KEY_Q if slot == 0 else KEY_E)


## Escape or right mouse button while aiming with Q/E cancels the cast.
static func cancel_held() -> bool:
	return Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## Space = dash, F = bookmark (HANDOFF keyboard map; R arrives with the ball).
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
